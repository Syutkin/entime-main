unit ResultsImportPreviewService;
{$mode objfpc}{$H+}
interface

uses SysUtils, CompetitionDbContext, StageModel, CompetitionImportService,
  ResultsImportComparison;

type
  EImportPreviewBusy = class(Exception);
  TImportApplyState = (iasApplied, iasNoChanges, iasNeedsReview);

  TImportApplyOutcome = record
    State: TImportApplyState;
    WrittenFields, CreatedParticipants, ChangedParticipants: integer;
  end;

  TResultsImportPreviewService = class
  private
    class function BuildInternal(const APlan: TResultsImportPlan;
      const AContext: TCompetitionDbContext; const AStages: TStages;
      const AStageIndex: integer): TResultsImportComparison; static;
  public
    class function Build(const APlan: TResultsImportPlan;
      const AContext: TCompetitionDbContext; const AStages: TStages;
      const AStageIndex: integer): TResultsImportComparison; static;
    class function IsCurrent(const AComparison: TResultsImportComparison;
      const APlan: TResultsImportPlan; const AContext: TCompetitionDbContext;
      const AStages: TStages): boolean; static;
    class function Apply(const AComparison: TResultsImportComparison;
      const APlan: TResultsImportPlan; const AContext: TCompetitionDbContext;
      const AStages: TStages;
      const ABackupCreated, AContinueWithoutBackup: boolean): TImportApplyOutcome;
      static;
  end;

implementation

uses DB, SQLDB, ResultsCsvParser, ParticipantStatus, CompetitionImportRepository,
  CompetitionResultsService;

function ConfigurationSignature(const AStages: TStages): string;
var
  I: integer;
begin
  Result := IntToStr(AStages.Count);
  for I := 1 to AStages.Count do
    Result := Result + '|' + IntToStr(Ord(AStages[I].isActive)) +
      ':' + IntToStr(Length(AStages[I].Name)) + ':' + AStages[I].Name;
end;

class function TResultsImportPreviewService.BuildInternal(
  const APlan: TResultsImportPlan; const AContext: TCompetitionDbContext;
  const AStages: TStages; const AStageIndex: integer): TResultsImportComparison;
var
  I: integer;
  Item: TResultImportItem;
  P: TImportParticipant;
  Field: TImportField;
  Fields: TImportFields;
  Values: TImportValues;
  Q: TSQLQuery;
  OwnTransaction: boolean;
begin
  if APlan = nil then raise EArgumentNilException.Create('Import plan');
  if AContext = nil then raise EArgumentNilException.Create('Database context');
  if AStages = nil then raise EArgumentNilException.Create('Stages');
  if not AContext.Connection.Connected then
    raise EDatabaseError.Create('Competition database is closed');
  if not AStages.IsActiveIndex(AStageIndex) then
    raise EArgumentOutOfRangeException.Create('Import stage is not active');
  Result := TResultsImportComparison.Create;
  try
    Result.StageIndex := AStageIndex;
    Result.StageSignature := ConfigurationSignature(AStages);
    Result.SessionGeneration := AContext.SessionGeneration;
    Result.ContextIdentity := AContext.Identity;
    case APlan.ImportFormat of
      crifStart: Fields := [ifStart, ifCorrection, ifStatus];
      crifFinish: Fields := [ifFinish, ifStatus];
      else
        Fields := [Low(TImportField)..High(TImportField)];
    end;
    for I := 0 to APlan.ItemCount - 1 do
    begin
      Item := APlan.Items[I];
      for Field := Low(TImportField) to High(TImportField) do
        Values[Field] := TImportValue.Null;
      Values[ifStart] := TImportValue.Value(Item.StartTime);
      Values[ifFinish] := TImportValue.Value(Item.FinishTime);
      Values[ifPenalty] := TImportValue.Value(Item.Penalty);
      if Item.HasCorrection then Values[ifCorrection] :=
          TImportValue.Value(IntToStr(Item.Correction));
      if Item.HasStatus then Values[ifStatus] :=
          TImportValue.Value(ParticipantStatusToDbValue(Item.Status));
      P := Result.Add(0, Item.ParticipantNumber, Item.SourceRowNumber, '');
      for Field in Fields do P.AddField(Field, TImportValue.Null, Values[Field]);
    end;
    OwnTransaction := not AContext.Transaction.Active;
    Q := AContext.CreateQuery(nil);
    try
      if OwnTransaction then AContext.Transaction.StartTransaction;
      try
        TCompetitionImportRepository.ReadPreviewRows(Q, Result, AStages.Count);
      finally
        Q.Close;
        if OwnTransaction and AContext.Transaction.Active then
          AContext.Transaction.Rollback;
      end;
    finally
      Q.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

class function TResultsImportPreviewService.Build(const APlan: TResultsImportPlan;
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const AStageIndex: integer): TResultsImportComparison;
begin
  if (AContext <> nil) and AContext.UnitOfWorkActive then
    raise EImportPreviewBusy.Create('Wait for the current database operation');
  Result := BuildInternal(APlan, AContext, AStages, AStageIndex);
end;

function SameSession(const C: TResultsImportComparison;
  const Context: TCompetitionDbContext; const Stages: TStages): boolean;
begin
  Result := (C <> nil) and (Context <> nil) and (Stages <> nil) and
    Context.Connection.Connected and (C.ContextIdentity = Context.Identity) and
    (C.SessionGeneration = Context.SessionGeneration) and
    Stages.IsActiveIndex(C.StageIndex) and (C.StageSignature =
    ConfigurationSignature(Stages));
end;

function MatchesSnapshot(const Expected, Actual: TResultsImportComparison): boolean;
var
  I: integer;
  Field: TImportField;
  P, Fresh: TImportParticipant;
begin
  Result := False;
  if Expected.Count <> Actual.Count then Exit;
  for I := 0 to Expected.Count - 1 do
  begin
    P := Expected[I];
    Fresh := Actual[I];
    if (P.Selected = []) and not P.CreateSelected then Continue;
    if (P.Id <> Fresh.Id) or (P.Number <> Fresh.Number) then Exit;
    for Field in P.Selected do
      if not (Field in Fresh.Fields) or not
        P.Current[Field].Equivalent(Fresh.Current[Field], Field) or not
        P.Proposed[Field].Equivalent(Fresh.Proposed[Field], Field) then Exit;
  end;
  Result := True;
end;

class function TResultsImportPreviewService.IsCurrent(
  const AComparison: TResultsImportComparison; const APlan: TResultsImportPlan;
  const AContext: TCompetitionDbContext; const AStages: TStages): boolean;
var
  Fresh: TResultsImportComparison;
begin
  if (AContext <> nil) and AContext.UnitOfWorkActive then
    raise EImportPreviewBusy.Create('Wait for the current database operation');
  if not SameSession(AComparison, AContext, AStages) then Exit(False);
  Fresh := BuildInternal(APlan, AContext, AStages, AComparison.StageIndex);
  try
    Result := MatchesSnapshot(AComparison, Fresh);
  finally
    Fresh.Free;
  end;
end;

class function TResultsImportPreviewService.Apply(
  const AComparison: TResultsImportComparison; const APlan: TResultsImportPlan;
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const ABackupCreated, AContinueWithoutBackup: boolean): TImportApplyOutcome;
var
  Work: TCompetitionUnitOfWork;
  Fresh: TResultsImportComparison;
  Q: TSQLQuery;
begin
  if AComparison = nil then raise EArgumentNilException.Create('Import comparison');
  Result := Default(TImportApplyOutcome);
  Result.State := iasNoChanges;
  if not AComparison.HasSelection then Exit;
  if not ABackupCreated and not AContinueWithoutBackup then
    raise EArgumentException.Create('Results import requires a backup decision');
  if (AContext <> nil) and AContext.UnitOfWorkActive then
    raise EImportPreviewBusy.Create('Wait for the current database operation');
  Result.State := iasNeedsReview;
  if not SameSession(AComparison, AContext, AStages) then Exit;
  Work := AContext.BeginUnitOfWork;
  try
    // Validation and writes share one transaction. No GUI calls are made here.
    Fresh := BuildInternal(APlan, AContext, AStages, AComparison.StageIndex);
    try
      if not MatchesSnapshot(AComparison, Fresh) then Exit;
    finally
      Fresh.Free;
    end;
    Q := AContext.CreateQuery(nil);
    try
      TCompetitionImportRepository.WritePreviewRows(Q, AComparison);
    finally
      Q.Free;
    end;
    if APlan.ImportFormat = crifFullStage then
      TParticipantStatusService.RecalculateAllInCurrentTransaction(AContext, AStages);
    TResultCalculationService.RecalculateAllInCurrentTransaction(AContext,
      AStages, True);
    Work.Commit;
    Result.State := iasApplied;
    Result.WrittenFields := AComparison.SelectedFieldCount;
    Result.CreatedParticipants := AComparison.CreationCount;
    Result.ChangedParticipants := AComparison.SelectedParticipantCount;
    AComparison.ClearSelection;
  finally
    Work.Free;
  end;
end;

end.
