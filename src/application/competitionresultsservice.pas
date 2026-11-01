unit CompetitionResultsService;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, DB, SQLDB, DbSql, StageModel, ParticipantStatus;

type
  TParticipantClearStatusCommand =
    (pcscStageAndGlobal, pcscGlobalOnly, pcscStageOnly);

  TParticipantStatusOutcome = record
    PreviousStatus: TParticipantStatus;
    Changed: boolean;
  end;

  TStatusRecalculationOutcome = record
    ProcessedCount: integer;
    ChangedCount: integer;
  end;

  TStartListGeneration = record
    StageIndex: integer;
    StartTime: TDateTime;
    DelayBetweenRacersSeconds: integer;
    DelayBetweenCategoriesMinutes: integer;
    SortBy: integer;
    IncludeDNS: boolean;
    IncludeDNF: boolean;
    IncludeDSQ: boolean;
    ActivateStage: boolean;
  end;

  TParticipantStageValueOutcome = record
    PreviousValue: string;
    CurrentValue: string;
    Changed: boolean;
  end;

  TResultCalculationService = record
  private
    class procedure RecalculateStageResultsCore(const AQuery: TSQLQuery;
      const AStages: TStages; const AChangedStages: array of integer;
      const APreserveFinish: boolean = False); static;
    class function RecalculateSumResultsCore(
      const AReadQuery, AWriteQuery: TSQLQuery; const AStages: TStages): integer;
      static;
    class procedure RecalculateThruResultsCore(const AQuery: TSQLQuery); static;
    class procedure RecalculateCore(const AContext: TCompetitionDbContext;
      const AStages: TStages; const AChangedStages: array of integer;
      const APreserveFinish: boolean = False); static;
  public
    class procedure RecalculateAll(const AContext: TCompetitionDbContext;
      const AStages: TStages); static;
    class procedure RecalculateAllInCurrentTransaction(
      const AContext: TCompetitionDbContext; const AStages: TStages;
      const APreserveFinish: boolean = False); static;
    // Stage indices are deduplicated; inactive stages retain their stored data.
    // Summary and through standings still include all active stages.
    class procedure RecalculateStages(const AContext: TCompetitionDbContext;
      const AStages: TStages; const AChangedStages: array of integer); static;
    class procedure RecalculateStagesInCurrentTransaction(
      const AContext: TCompetitionDbContext; const AStages: TStages;
      const AChangedStages: array of integer); static;
    class procedure RecalculateSumResults(const AContext: TCompetitionDbContext;
      const AStages: TStages); static;
    class procedure ClearResults(const AContext: TCompetitionDbContext;
      const AStageCount: integer); static;
  end;

  TParticipantStatusService = record
  private
    class function RecalculateParticipant(const AQuery: TSQLQuery;
      const AStages: TStages; const AParticipantNumber: integer): boolean; static;
    class function RecalculateAllCore(const AContext: TCompetitionDbContext;
      const AStages: TStages): TStatusRecalculationOutcome; static;
  public
    class function SetStatus(const AContext: TCompetitionDbContext;
      const AStages: TStages; const AParticipantNumber, AStageIndex: integer;
      const AStatus: TParticipantStatus): TParticipantStatusOutcome; static;
    class procedure ClearStatus(const AContext: TCompetitionDbContext;
      const AStages: TStages; const AParticipantNumber, AStageIndex: integer;
      const ACommand: TParticipantClearStatusCommand); static;
    class function RecalculateAll(const AContext: TCompetitionDbContext;
      const AStages: TStages): TStatusRecalculationOutcome; static;
    class function RecalculateAllInCurrentTransaction(
      const AContext: TCompetitionDbContext;
      const AStages: TStages): TStatusRecalculationOutcome; static;
  end;

  TCompetitionStartListService = record
  public
    class procedure LoadCategories(const AContext: TCompetitionDbContext;
      const AStageIndex, AStageCount: integer; const ACategories: TStrings); static;
    class function HasFinishes(const AContext: TCompetitionDbContext;
      const AStageIndex, AStageCount: integer): boolean; static;
    class procedure GenerateStartTimes(const AContext: TCompetitionDbContext;
      const AStages: TStages; const ACategories: TStrings;
      const AGeneration: TStartListGeneration); static;
  end;

  TParticipantEditService = record
  public
    class procedure ApplyChanges(const AContext: TCompetitionDbContext;
      const AQuery: TSQLQuery; const AStages: TStages); static;
    class procedure ApplyChangesKeepingInput(const AContext: TCompetitionDbContext;
      const AQuery: TSQLQuery; const AStages: TStages); static;
  end;

  TParticipantStageService = record
  public
    class procedure SaveCorrection(const AContext: TCompetitionDbContext;
      const AStages: TStages;
      const AParticipantNumber, AStageIndex, ACorrection: integer); static;
    class function SaveStartTime(const AContext: TCompetitionDbContext;
      const AStages: TStages; const AParticipantNumber, AStageIndex: integer;
      const AStartTime: string): TParticipantStageValueOutcome; static;
  end;

implementation

uses
  DateUtils, i18n, ParticipantStageData, AppLogger;

class procedure TParticipantEditService.ApplyChangesKeepingInput(
  const AContext: TCompetitionDbContext; const AQuery: TSQLQuery;
  const AStages: TStages);
var
  Pending: TMemoryStream;
  CurrentNumber: integer;
begin
  if AQuery = nil then raise EArgumentNilException.Create('Participant query');
  // SQLDB's packet includes the original values and the complete change log,
  // so even a failed calculation after ApplyUpdates can restore every edit.
  if AQuery.State in [dsEdit, dsInsert] then AQuery.Post;
  CurrentNumber := AQuery.FieldByName('number').AsInteger;
  Pending := TMemoryStream.Create;
  AQuery.DisableControls;
  try
    AQuery.SaveToStream(Pending);
    AQuery.Locate('number', CurrentNumber, []);
    try
      ApplyChanges(AContext, AQuery, AStages);
    except
      AQuery.Close;
      Pending.Position := 0;
      AQuery.LoadFromStream(Pending);
      AQuery.Locate('number', CurrentNumber, []);
      raise;
    end;
  finally
    AQuery.EnableControls;
    Pending.Free;
  end;
end;

class procedure TParticipantEditService.ApplyChanges(
  const AContext: TCompetitionDbContext; const AQuery: TSQLQuery;
  const AStages: TStages);
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AQuery = nil then
    raise EArgumentNilException.Create('AQuery');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  try
    if AQuery.State in [dsEdit, dsInsert] then
      AQuery.Post;
    UnitOfWork := AContext.BeginUnitOfWork;
    try
      AQuery.ApplyUpdates;
      TResultCalculationService.RecalculateAllInCurrentTransaction(
        AContext, AStages);
      UnitOfWork.Commit;
    finally
      UnitOfWork.Free;
    end;
  except
    if AQuery.Active and (AQuery.ChangeCount > 0) then
      AQuery.CancelUpdates;
    raise;
  end;
end;

class procedure TParticipantStageService.SaveCorrection(
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const AParticipantNumber, AStageIndex, ACorrection: integer);
var
  Query: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  Query := AContext.CreateQuery(nil);
  UnitOfWork := nil;
  try
    UnitOfWork := AContext.BeginUnitOfWork;
    TMainSql.ExecUpdateCorrection(Query, AStageIndex, ACorrection,
      AParticipantNumber, AStages.Count);
    TResultCalculationService.RecalculateStagesInCurrentTransaction(
      AContext, AStages, [AStageIndex]);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Query.Free;
  end;
end;

class function TParticipantStageService.SaveStartTime(
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const AParticipantNumber, AStageIndex: integer;
  const AStartTime: string): TParticipantStageValueOutcome;
var
  Query: TSQLQuery;
  StageData: TParticipantStageData;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  Result.PreviousValue := '';
  Result.CurrentValue := AStartTime;
  Query := AContext.CreateQuery(nil);
  UnitOfWork := nil;
  try
    if TMainSql.TryLoadParticipantStageData(Query, AParticipantNumber,
      AStageIndex, AStages.Count, StageData) then
      Result.PreviousValue := StageData.StartTime;
    UnitOfWork := AContext.BeginUnitOfWork;
    TMainSql.ExecUpdateStartTimeForNumber(Query, AStageIndex, AStartTime,
      AParticipantNumber, AStages.Count);
    TResultCalculationService.RecalculateStagesInCurrentTransaction(
      AContext, AStages, [AStageIndex]);
    UnitOfWork.Commit;
    Result.Changed := Result.PreviousValue <> Result.CurrentValue;
  finally
    UnitOfWork.Free;
    Query.Free;
  end;
end;

class procedure TCompetitionStartListService.LoadCategories(
  const AContext: TCompetitionDbContext; const AStageIndex, AStageCount: integer;
  const ACategories: TStrings);
var
  Query: TSQLQuery;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if ACategories = nil then
    raise EArgumentNilException.Create('ACategories');
  Query := AContext.CreateQuery(nil);
  try
    TMainSql.LoadCategoriesOrderedByStartTime(Query, AStageIndex,
      AStageCount, ACategories);
  finally
    Query.Free;
  end;
end;

class function TCompetitionStartListService.HasFinishes(
  const AContext: TCompetitionDbContext;
  const AStageIndex, AStageCount: integer): boolean;
var
  Query: TSQLQuery;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  Query := AContext.CreateQuery(nil);
  try
    Result := TMainSql.GetFinishCount(Query, AStageIndex, AStageCount) > 0;
  finally
    Query.Free;
  end;
end;

class procedure TCompetitionStartListService.GenerateStartTimes(
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const ACategories: TStrings; const AGeneration: TStartListGeneration);
var
  CategoryIndex, ParticipantNumber: integer;
  CurrentStartTime: TDateTime;
  ReadQuery, WriteQuery: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  if ACategories = nil then
    raise EArgumentNilException.Create('ACategories');
  if not AStages.IsValidIndex(AGeneration.StageIndex) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index %d is outside the competition range.', [AGeneration.StageIndex]);
  if not (AGeneration.SortBy in [0..4]) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Unsupported start-list sort mode: %d.', [AGeneration.SortBy]);
  if (AGeneration.DelayBetweenRacersSeconds < 0) or
    (AGeneration.DelayBetweenCategoriesMinutes < 0) then
    raise EArgumentOutOfRangeException.Create(
      'Start-list delays must not be negative.');

  CurrentStartTime := AGeneration.StartTime;
  ReadQuery := AContext.CreateQuery(nil);
  WriteQuery := AContext.CreateQuery(nil);
  UnitOfWork := nil;
  try
    UnitOfWork := AContext.BeginUnitOfWork;
    TMainSql.ExecResetStartTime(WriteQuery, AGeneration.StageIndex,
      AStages.Count);
    for CategoryIndex := 0 to ACategories.Count - 1 do
    begin
      TStartlistSql.ConfigureNumbersForCategory(ReadQuery,
        AGeneration.SortBy, AGeneration.IncludeDNS,
        AGeneration.IncludeDNF, AGeneration.IncludeDSQ,
        ACategories[CategoryIndex]);
      ReadQuery.Open;
      try
        while not ReadQuery.EOF do
        begin
          ParticipantNumber := ReadQuery.Fields[0].AsInteger;
          ReadQuery.Next;
          TMainSql.ExecUpdateStartTime(WriteQuery,
            AGeneration.StageIndex,
            FormatDateTime('hh:nn:ss', CurrentStartTime),
            ParticipantNumber, AStages.Count);
          CurrentStartTime := IncSecond(CurrentStartTime,
            AGeneration.DelayBetweenRacersSeconds);
        end;
      finally
        ReadQuery.Close;
      end;
      CurrentStartTime := IncMinute(CurrentStartTime,
        AGeneration.DelayBetweenCategoriesMinutes);
    end;
    if AGeneration.ActivateStage then
      TConfigSql.ExecUpsertByKey(WriteQuery,
        'stage' + IntToStr(AGeneration.StageIndex), BoolToStr(True, True));
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    WriteQuery.Free;
    ReadQuery.Free;
  end;
end;

class procedure TResultCalculationService.RecalculateStageResultsCore(
  const AQuery: TSQLQuery; const AStages: TStages;
  const AChangedStages: array of integer; const APreserveFinish: boolean);
var
  I, StageIndex: integer;
  Changed: array of boolean;
begin
  SetLength(Changed, AStages.Count + 1);
  for I := 0 to High(AChangedStages) do
  begin
    StageIndex := AChangedStages[I];
    if not AStages.IsValidIndex(StageIndex) then
      raise EArgumentOutOfRangeException.CreateFmt(
        'Stage %d is outside the competition range.', [StageIndex]);
    Changed[StageIndex] := True;
  end;
  try
    for StageIndex := 1 to AStages.Count do
      if Changed[StageIndex] and AStages[StageIndex].isActive then
        TResultsSql.ExecCalculateStage(AQuery, StageIndex, AStages.Count,
          APreserveFinish);
  except
    on E: Exception do
      raise EDatabaseError.CreateFmt(rsStageResultsCalculationError, [E.Message]);
  end;
end;

class function TResultCalculationService.RecalculateSumResultsCore(
  const AReadQuery, AWriteQuery: TSQLQuery; const AStages: TStages): integer;
const
  OneDay: TDateTime = 1.0;
var
  ActiveStages: TStageIndexArray;
  ClearStatus: boolean;
  StageOffset, SumStages: integer;
  SumResult, TimeText: string;
  SumRow: TSumCalculationRow;
  SumTime, ParsedTime: TDateTime;
  UpdatePrepared: boolean;
begin
  Result := 0;
  UpdatePrepared := False;
  ActiveStages := AStages.ActiveIndices;
  try
    try
      TResultsSql.OpenSumCalculation(AReadQuery, ActiveStages, AStages.Count);
      TResultsSql.PrepareSumResultUpdate(AWriteQuery);
      UpdatePrepared := True;
      while TResultsSql.HasCurrentSumCalculationRow(AReadQuery) do
      begin
        SumRow := TResultsSql.ReadSumCalculationRow(AReadQuery,
          ActiveStages, AStages.Count);
        SumTime := 0;
        SumStages := 0;
        for StageOffset := Low(ActiveStages) to High(ActiveStages) do
        begin
          TimeText := SumRow.StageResults[StageOffset - Low(ActiveStages)];
          if TimeText <> '' then
          begin
            TimeText := StringReplace(TimeText, '.',
              DefaultFormatSettings.DecimalSeparator, [rfReplaceAll]);
            if TryStrToTime(TimeText, ParsedTime) then
            begin
              SumTime := SumTime + ParsedTime;
              Inc(SumStages);
            end;
          end;
        end;

        SumResult := '';
        ClearStatus := False;
        if SumRow.Status = psDSQ then
          SumResult := ParticipantStatusToToken(psDSQ)
        else if SumTime <> 0 then
        begin
          if SumTime >= OneDay then
            AppLog(Format(rsSumDurationLimitExceeded,
              [SumRow.ParticipantNumber]), allWarning, alvDetails, alsResults);
          SumResult := FormatDateTime('hh:nn:ss.zzz', SumTime);
          ClearStatus := True;
        end
        else if SumRow.Status = psDNF then
          SumResult := ParticipantStatusToToken(psDNF)
        else if SumRow.Status = psDNS then
          SumResult := ParticipantStatusToToken(psDNS);

        TResultsSql.ExecPreparedSumResult(AWriteQuery,
          SumRow.ParticipantNumber, SumResult, SumStages, ClearStatus);
        Inc(Result);
        TResultsSql.NextSumCalculationRow(AReadQuery);
      end;
      TResultsSql.FinishPreparedSumResultUpdate(AWriteQuery);
      UpdatePrepared := False;
      TResultsSql.CloseSumCalculation(AReadQuery);
      TResultsSql.FinishSumCalculation(AWriteQuery, ActiveStages,
        AStages.Count, rsSU);
    except
      on E: Exception do
        raise EDatabaseError.CreateFmt(rsSumResultsCalculationError,
          [E.Message]);
    end;
  finally
    if UpdatePrepared then
      TResultsSql.FinishPreparedSumResultUpdate(AWriteQuery);
    TResultsSql.CloseSumCalculation(AReadQuery);
  end;
end;

class procedure TResultCalculationService.RecalculateThruResultsCore(
  const AQuery: TSQLQuery);
begin
  try
    TResultsSql.ExecCalculateThru(AQuery, rsSU);
  except
    on E: Exception do
      raise EDatabaseError.CreateFmt(rsThruResultsCalculationError, [E.Message]);
  end;
end;

class procedure TResultCalculationService.RecalculateCore(
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const AChangedStages: array of integer; const APreserveFinish: boolean);
var
  ReadQuery, WriteQuery: TSQLQuery;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');

  ReadQuery := AContext.CreateQuery(nil);
  WriteQuery := AContext.CreateQuery(nil);
  try
    RecalculateStageResultsCore(WriteQuery, AStages, AChangedStages, APreserveFinish);
    RecalculateSumResultsCore(ReadQuery, WriteQuery, AStages);
    RecalculateThruResultsCore(WriteQuery);
  finally
    WriteQuery.Free;
    ReadQuery.Free;
  end;
end;

class procedure TResultCalculationService.RecalculateAll(
  const AContext: TCompetitionDbContext; const AStages: TStages);
begin
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  RecalculateStages(AContext, AStages, AStages.ActiveIndices);
end;

class procedure TResultCalculationService.RecalculateStages(
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const AChangedStages: array of integer);
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  UnitOfWork := nil;
  try
    UnitOfWork := AContext.BeginUnitOfWork;
    RecalculateCore(AContext, AStages, AChangedStages);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
end;

class procedure TResultCalculationService.RecalculateAllInCurrentTransaction(
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const APreserveFinish: boolean);
begin
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  RecalculateCore(AContext, AStages, AStages.ActiveIndices, APreserveFinish);
end;

class procedure TResultCalculationService.RecalculateStagesInCurrentTransaction(
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const AChangedStages: array of integer);
begin
  RecalculateCore(AContext, AStages, AChangedStages);
end;

class procedure TResultCalculationService.RecalculateSumResults(
  const AContext: TCompetitionDbContext; const AStages: TStages);
var
  ReadQuery, WriteQuery: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  ReadQuery := AContext.CreateQuery(nil);
  WriteQuery := AContext.CreateQuery(nil);
  UnitOfWork := nil;
  try
    UnitOfWork := AContext.BeginUnitOfWork;
    RecalculateSumResultsCore(ReadQuery, WriteQuery, AStages);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    WriteQuery.Free;
    ReadQuery.Free;
  end;
end;

class procedure TResultCalculationService.ClearResults(
  const AContext: TCompetitionDbContext; const AStageCount: integer);
var
  Query: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  Query := AContext.CreateQuery(nil);
  UnitOfWork := nil;
  try
    UnitOfWork := AContext.BeginUnitOfWork;
    TResultsSql.ExecClearResults(Query, AStageCount);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Query.Free;
  end;
end;

class function TParticipantStatusService.RecalculateParticipant(
  const AQuery: TSQLQuery;
  const AStages: TStages; const AParticipantNumber: integer): boolean;
var
  CurrentStatus, DesiredStatus: TParticipantStatus;
  StageStatuses: TParticipantStatusArray;
begin
  Result := False;
  if not TMainSql.LoadStatuses(AQuery, AParticipantNumber, AStages.Count,
    CurrentStatus, StageStatuses) then
    Exit;
  DesiredStatus := DeriveGlobalParticipantStatus(CurrentStatus,
    StageStatuses, AStages.ActiveIndices);
  Result := CurrentStatus <> DesiredStatus;
  if Result then
    TMainSql.ExecUpdateGlobalStatus(AQuery, DesiredStatus,
      IntToStr(AParticipantNumber));
end;

class function TParticipantStatusService.SetStatus(
  const AContext: TCompetitionDbContext;
  const AStages: TStages; const AParticipantNumber, AStageIndex: integer;
  const AStatus: TParticipantStatus): TParticipantStatusOutcome;
var
  CurrentGlobalStatus: TParticipantStatus;
  Query: TSQLQuery;
  StageData: TParticipantStageData;
  StageStatuses: TParticipantStatusArray;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  if AStatus = psNone then
    raise EArgumentException.Create('A participant status is required.');
  if (AStatus <> psDSQ) and (not AStages.IsActiveIndex(AStageIndex)) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage %d is not an active competition stage.', [AStageIndex]);

  Result.PreviousStatus := psNone;
  Result.Changed := False;
  Query := AContext.CreateQuery(nil);
  UnitOfWork := nil;
  try
    UnitOfWork := AContext.BeginUnitOfWork;
    if AStatus = psDSQ then
    begin
      if TMainSql.LoadStatuses(Query, AParticipantNumber, AStages.Count,
        CurrentGlobalStatus, StageStatuses) then
        Result.PreviousStatus := CurrentGlobalStatus;
      TMainSql.ExecUpdateOnlyGlobalStatusDsq(Query,
        IntToStr(AParticipantNumber));
    end
    else
    begin
      if TMainSql.TryLoadParticipantStageData(Query, AParticipantNumber,
        AStageIndex, AStages.Count, StageData) then
        Result.PreviousStatus := StageData.Status;
      TMainSql.ExecUpdateStageStatus(Query, AStageIndex, AStatus,
        IntToStr(AParticipantNumber), AStages.Count);
      RecalculateParticipant(Query, AStages, AParticipantNumber);
    end;
    if AStatus = psDSQ then
      TResultCalculationService.RecalculateAllInCurrentTransaction(AContext, AStages)
    else
      TResultCalculationService.RecalculateStagesInCurrentTransaction(
        AContext, AStages, [AStageIndex]);
    UnitOfWork.Commit;
    Result.Changed := Result.PreviousStatus <> AStatus;
  finally
    UnitOfWork.Free;
    Query.Free;
  end;
end;

class procedure TParticipantStatusService.ClearStatus(
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const AParticipantNumber, AStageIndex: integer;
  const ACommand: TParticipantClearStatusCommand);
var
  PreviousGlobalStatus: TParticipantStatus;
  StageStatuses: TParticipantStatusArray;
  Query: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  if (ACommand <> pcscGlobalOnly) and (not AStages.IsActiveIndex(AStageIndex)) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage %d is not an active competition stage.', [AStageIndex]);

  Query := AContext.CreateQuery(nil);
  UnitOfWork := nil;
  try
    UnitOfWork := AContext.BeginUnitOfWork;
    PreviousGlobalStatus := psNone;
    TMainSql.LoadStatuses(Query, AParticipantNumber, AStages.Count,
      PreviousGlobalStatus, StageStatuses);
    if ACommand = pcscGlobalOnly then
    begin
      TMainSql.ExecClearOnlyGlobalStatus(Query, IntToStr(AParticipantNumber));
    end
    else
    begin
      case ACommand of
        pcscStageAndGlobal:
          TMainSql.ExecClearStatusAllForStage(Query, AStageIndex,
            IntToStr(AParticipantNumber), AStages.Count);
        pcscStageOnly:
          TMainSql.ExecClearStageStatus(Query, AStageIndex,
            IntToStr(AParticipantNumber), AStages.Count);
        else
          raise EArgumentException.Create('Unsupported clear status command.');
      end;
    end;
    RecalculateParticipant(Query, AStages, AParticipantNumber);
    if (ACommand = pcscGlobalOnly) or (PreviousGlobalStatus = psDSQ) then
      TResultCalculationService.RecalculateAllInCurrentTransaction(AContext, AStages)
    else
      TResultCalculationService.RecalculateStagesInCurrentTransaction(
        AContext, AStages, [AStageIndex]);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Query.Free;
  end;
end;

class function TParticipantStatusService.RecalculateAllCore(
  const AContext: TCompetitionDbContext;
  const AStages: TStages): TStatusRecalculationOutcome;
var
  ActiveStageIndexes: TStageIndexArray;
  DesiredStatuses: array of TParticipantStatus;
  Index: integer;
  Query: TSQLQuery;
  Rows: TParticipantStatusRows;
  UpdatesPrepared: boolean;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  Result.ProcessedCount := 0;
  Result.ChangedCount := 0;
  Rows := nil;
  DesiredStatuses := nil;
  Query := AContext.CreateQuery(nil);
  UpdatesPrepared := False;
  try
    ActiveStageIndexes := AStages.ActiveIndices;
    TMainSql.LoadAllStatuses(Query, AStages.Count, ActiveStageIndexes, Rows);
    Result.ProcessedCount := Length(Rows);
    SetLength(DesiredStatuses, Length(Rows));
    for Index := 0 to High(Rows) do
    begin
      DesiredStatuses[Index] :=
        DeriveGlobalParticipantStatus(Rows[Index].GlobalStatus,
        Rows[Index].StageStatuses, ActiveStageIndexes);
      if DesiredStatuses[Index] <> Rows[Index].GlobalStatus then
        Inc(Result.ChangedCount);
    end;

    if Result.ChangedCount > 0 then
    begin
      TMainSql.PrepareGlobalStatusUpdates(Query);
      UpdatesPrepared := True;
      for Index := 0 to High(Rows) do
        if DesiredStatuses[Index] <> Rows[Index].GlobalStatus then
          TMainSql.ExecPreparedGlobalStatusUpdate(Query,
            DesiredStatuses[Index], Rows[Index].Number);
      TMainSql.FinishPreparedGlobalStatusUpdates(Query);
      UpdatesPrepared := False;
    end;
  finally
    if UpdatesPrepared then
      TMainSql.FinishPreparedGlobalStatusUpdates(Query);
    Query.Free;
  end;
end;

class function TParticipantStatusService.RecalculateAll(
  const AContext: TCompetitionDbContext;
  const AStages: TStages): TStatusRecalculationOutcome;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  UnitOfWork := AContext.BeginUnitOfWork;
  try
    Result := RecalculateAllCore(AContext, AStages);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
end;

class function TParticipantStatusService.RecalculateAllInCurrentTransaction(
  const AContext: TCompetitionDbContext;
  const AStages: TStages): TStatusRecalculationOutcome;
begin
  Result := RecalculateAllCore(AContext, AStages);
end;

end.
