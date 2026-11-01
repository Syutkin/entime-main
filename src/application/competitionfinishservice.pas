unit CompetitionFinishService;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, DB, SQLDB, DbSql, StageModel, FinishMark, HttpTransport;

const
  TELEGRAM_CONNECT_TIMEOUT_MS = 3000;
  TELEGRAM_READ_TIMEOUT_MS = 5000;

type
  TFinishTrackPolicy = (ftpRequireOnTrack, ftpAllowNotOnTrack);
  TFinishOverwritePolicy = (fopRejectExisting, fopOverwriteExisting);
  TFinishFailureKind = (ffkNone, ffkParticipantMissing, ffkNotOnTrack,
    ffkExistingResult, ffkDatabase, ffkFinishMarkMissing,
    ffkFinishMarkNotPending);

  TFinishInspection = record
    ParticipantExists: boolean;
    IsOnTrack: boolean;
    HasExistingResult: boolean;
  end;

  TFinishRequest = record
    MarkId: int64;
    ParticipantNumber: integer;
    StageIndex: integer;
    FinishTime: string;
    TrackPolicy: TFinishTrackPolicy;
    OverwritePolicy: TFinishOverwritePolicy;
    AppliedAt: TDateTime;
    class function Create(const AParticipantNumber, AStageIndex: integer;
      const AFinishTime: string; const ATrackPolicy: TFinishTrackPolicy;
      const AOverwritePolicy: TFinishOverwritePolicy): TFinishRequest; static;
    class function CreateForMark(const AMarkId: int64;
      const AParticipantNumber: integer; const ATrackPolicy: TFinishTrackPolicy;
      const AOverwritePolicy: TFinishOverwritePolicy;
      const AAppliedAt: TDateTime): TFinishRequest; static;
  end;

  TFinishResult = record
    ParticipantNumber: integer;
    ParticipantName: string;
    Category: string;
    StageIndex: integer;
    FinishTime: string;
    ResultValue: string;
    Place: integer;
    Difference: string;
    PreviousLeaderNumber: integer;
    PreviousLeaderResult: string;
  end;

  TFinishRequests = array of TFinishRequest;
  TFinishResults = array of TFinishResult;

  TFinishFailure = record
    Kind: TFinishFailureKind;
    SafeMessage: string;
  end;

  TFinishNotificationOutcome = record
    Success: boolean;
    SafeErrorMessage: string;
    RequestParameterCount: integer;
    ResponseStatusCode: integer;
    ResponseStatusText: string;
    ResponseHeaderCount: integer;
    ResponseSize: int64;
    TransportErrorKind: THttpErrorKind;
  end;

  TFinishService = record
  private
    class procedure InitializeResult(out AResult: TFinishResult); static;
    class procedure InitializeFailure(out AFailure: TFinishFailure); static;
    class procedure SetFailure(out AFailure: TFinishFailure;
      const AKind: TFinishFailureKind; const AMessage: string); static;
  public
    class function Inspect(const AContext: TCompetitionDbContext;
      const AStages: TStages; const AParticipantNumber, AStageIndex: integer):
      TFinishInspection; static;
    // All approved requests commit together; results describe the final batch state.
    class function TrySaveBatch(const AContext: TCompetitionDbContext;
      const AStages: TStages; const ARequests: array of TFinishRequest;
      out AResults: TFinishResults; out AFailure: TFinishFailure;
      out AFailedIndex: integer): boolean; static;
    class function TrySave(const AContext: TCompetitionDbContext;
      const AStages: TStages; const ARequest: TFinishRequest;
      out AResult: TFinishResult; out AFailure: TFinishFailure): boolean; static;
  end;

  TTelegramResultNotifier = record
  private
    class function RedactError(const AMessage, AUrl, AEndpoint: string): string;
      static;
  public
    class function BuildRequest(const AResult: TFinishResult;
      const AEndpoint: string): THttpRequest; static;
    class function BuildRequest(const AEndpoint: string;
      const AFields: THttpFormFields): THttpRequest; static;
    class function Send(const ARequest: THttpRequest; const AEndpoint: string;
      const ATransport: IHttpTransport): TFinishNotificationOutcome; static;
    class function Notify(const AResult: TFinishResult; const AEndpoint: string;
      const ATransport: IHttpTransport): TFinishNotificationOutcome; static;
  end;

implementation

uses
  i18n, CompetitionResultsService, ResultFormatting;

procedure InitializeNotificationOutcome(out AOutcome: TFinishNotificationOutcome);
begin
  AOutcome.Success := False;
  AOutcome.SafeErrorMessage := '';
  AOutcome.RequestParameterCount := 0;
  AOutcome.ResponseStatusCode := 0;
  AOutcome.ResponseStatusText := '';
  AOutcome.ResponseHeaderCount := 0;
  AOutcome.ResponseSize := 0;
  AOutcome.TransportErrorKind := hekNone;
end;

class function TFinishRequest.Create(const AParticipantNumber, AStageIndex: integer;
  const AFinishTime: string; const ATrackPolicy: TFinishTrackPolicy;
  const AOverwritePolicy: TFinishOverwritePolicy): TFinishRequest;
begin
  Result := Default(TFinishRequest);
  Result.ParticipantNumber := AParticipantNumber;
  Result.StageIndex := AStageIndex;
  Result.FinishTime := AFinishTime;
  Result.TrackPolicy := ATrackPolicy;
  Result.OverwritePolicy := AOverwritePolicy;
end;

class function TFinishRequest.CreateForMark(const AMarkId: int64;
  const AParticipantNumber: integer; const ATrackPolicy: TFinishTrackPolicy;
  const AOverwritePolicy: TFinishOverwritePolicy;
  const AAppliedAt: TDateTime): TFinishRequest;
begin
  if AMarkId < 1 then
    raise EArgumentOutOfRangeException.Create('Finish mark ID must be positive.');
  if AParticipantNumber < 1 then
    raise EArgumentOutOfRangeException.Create(
      'Participant number must be positive.');
  if AAppliedAt <= 0 then
    raise EArgumentOutOfRangeException.Create(
      'AppliedAt must be a valid date and time.');
  Result := Default(TFinishRequest);
  Result.MarkId := AMarkId;
  Result.ParticipantNumber := AParticipantNumber;
  Result.TrackPolicy := ATrackPolicy;
  Result.OverwritePolicy := AOverwritePolicy;
  Result.AppliedAt := AAppliedAt;
end;

class procedure TFinishService.InitializeResult(out AResult: TFinishResult);
begin
  AResult.ParticipantNumber := 0;
  AResult.ParticipantName := '';
  AResult.Category := '';
  AResult.StageIndex := 0;
  AResult.FinishTime := '';
  AResult.ResultValue := '';
  AResult.Place := 0;
  AResult.Difference := '';
  AResult.PreviousLeaderNumber := 0;
  AResult.PreviousLeaderResult := '';
end;

class procedure TFinishService.InitializeFailure(out AFailure: TFinishFailure);
begin
  AFailure.Kind := ffkNone;
  AFailure.SafeMessage := '';
end;

class procedure TFinishService.SetFailure(out AFailure: TFinishFailure;
  const AKind: TFinishFailureKind; const AMessage: string);
begin
  AFailure.Kind := AKind;
  AFailure.SafeMessage := AMessage;
end;

class function TFinishService.Inspect(const AContext: TCompetitionDbContext;
  const AStages: TStages; const AParticipantNumber, AStageIndex: integer):
TFinishInspection;
var
  ParticipantCategory, ParticipantName: string;
  Query: TSQLQuery;
  StageData: TParticipantStageData;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  if not AStages.IsActiveIndex(AStageIndex) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage %d is not an active competition stage.', [AStageIndex]);

  Result.ParticipantExists := False;
  Result.IsOnTrack := False;
  Result.HasExistingResult := False;
  ParticipantName := '';
  ParticipantCategory := '';
  Query := AContext.CreateQuery(nil);
  try
    Result.ParticipantExists :=
      TMainSql.TryLoadIdentity(Query, AParticipantNumber, ParticipantName,
      ParticipantCategory);
    if not Result.ParticipantExists then
      Exit;
    Result.IsOnTrack := TMainSql.IsParticipantOnTrack(Query, AStageIndex,
      AParticipantNumber, AStages.Count);
    if TMainSql.TryLoadParticipantStageData(Query, AParticipantNumber,
      AStageIndex, AStages.Count, StageData) then
      Result.HasExistingResult := StageData.ResultValue <> '';
  finally
    Query.Free;
  end;
end;

class function TFinishService.TrySave(const AContext: TCompetitionDbContext;
  const AStages: TStages; const ARequest: TFinishRequest;
  out AResult: TFinishResult; out AFailure: TFinishFailure): boolean;
var
  Results: TFinishResults;
  FailedIndex: integer;
begin
  InitializeResult(AResult);
  Result := TrySaveBatch(AContext, AStages, [ARequest], Results,
    AFailure, FailedIndex);
  if Result then
    AResult := Results[0];
end;

class function TFinishService.TrySaveBatch(const AContext: TCompetitionDbContext;
  const AStages: TStages; const ARequests: array of TFinishRequest;
  out AResults: TFinishResults; out AFailure: TFinishFailure;
  out AFailedIndex: integer): boolean;
var
  AppliedMark, StoredMark: TFinishMark;
  CheckedStages, ChangedStages: TStageIndexArray;
  CurrentStageData, LeaderStageData: TParticipantStageData;
  ARequest, EffectiveRequest: TFinishRequest;
  HasStoredMark: boolean;
  I, J: integer;
  ParticipantCategory, ParticipantName: string;
  PendingResult: TFinishResult;
  PendingResults: TFinishResults;
  Query: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Result := False;
  AResults := nil;
  AFailedIndex := -1;
  InitializeFailure(AFailure);
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  if Length(ARequests) = 0 then
    Exit(True);
  for I := 0 to High(ARequests) do
    if (ARequests[I].MarkId = 0) and not AStages.IsActiveIndex(
      ARequests[I].StageIndex) then
      raise EArgumentOutOfRangeException.CreateFmt(
        'Stage %d is not an active competition stage.', [ARequests[I].StageIndex]);

  Query := AContext.CreateQuery(nil);
  UnitOfWork := nil;
  CheckedStages := nil;
  SetLength(PendingResults, Length(ARequests));
  SetLength(ChangedStages, Length(ARequests));
  try
    try
      UnitOfWork := AContext.BeginUnitOfWork;
      for I := 0 to High(ARequests) do
      begin
        AFailedIndex := I;
        ARequest := ARequests[I];
        EffectiveRequest := ARequest;
        HasStoredMark := ARequest.MarkId > 0;
        InitializeResult(PendingResult);
        if HasStoredMark then
        begin
          Query.SQL.Text := 'SELECT * FROM finish_marks WHERE id = :ID;';
          Query.ParamByName('ID').AsLargeInt := ARequest.MarkId;
          Query.Open;
          if not TFinishMarkSql.TryReadCurrent(Query, StoredMark) then
          begin
            Query.Close;
            SetFailure(AFailure, ffkFinishMarkMissing,
              Format('Finish mark %d was not found.', [ARequest.MarkId]));
            Exit;
          end;
          Query.Close;
          if StoredMark.Status <> fmsPending then
          begin
            SetFailure(AFailure, ffkFinishMarkNotPending,
              Format('Finish mark %d is not pending.', [ARequest.MarkId]));
            Exit;
          end;
          if (ARequest.StageIndex > 0) and
            ((ARequest.StageIndex <> StoredMark.StageIndex) or
            (ARequest.FinishTime <> FormatDateTime('hh:nn:ss.zzz',
            StoredMark.EventTime))) then
            raise EDatabaseError.CreateFmt('Finish mark %d changed after confirmation.',
              [StoredMark.Id]);
          EffectiveRequest.StageIndex := StoredMark.StageIndex;
          EffectiveRequest.FinishTime :=
            FormatDateTime('hh:nn:ss.zzz', StoredMark.EventTime);
        end;

        if not AStages.IsActiveIndex(EffectiveRequest.StageIndex) then
          raise EArgumentOutOfRangeException.CreateFmt(
            'Stage %d is not an active competition stage.',
            [EffectiveRequest.StageIndex]);

        if not TMainSql.TryLoadIdentity(Query,
          EffectiveRequest.ParticipantNumber, ParticipantName,
          ParticipantCategory) then
        begin
          SetFailure(AFailure, ffkParticipantMissing,
            Format('Participant %d was not found.',
            [EffectiveRequest.ParticipantNumber]));
          Exit;
        end;

        if (EffectiveRequest.TrackPolicy = ftpRequireOnTrack) and
          (not TMainSql.IsParticipantOnTrack(Query,
          EffectiveRequest.StageIndex, EffectiveRequest.ParticipantNumber,
          AStages.Count)) then
        begin
          SetFailure(AFailure, ffkNotOnTrack,
            Format('Participant %d is not on stage %d.',
            [EffectiveRequest.ParticipantNumber,
            EffectiveRequest.StageIndex]));
          Exit;
        end;

        if TMainSql.TryLoadParticipantStageData(Query,
          EffectiveRequest.ParticipantNumber, EffectiveRequest.StageIndex,
          AStages.Count, CurrentStageData) and
          (CurrentStageData.ResultValue <> '') and
          (EffectiveRequest.OverwritePolicy = fopRejectExisting) then
        begin
          SetFailure(AFailure, ffkExistingResult,
            Format('Participant %d already has a result on stage %d.',
            [EffectiveRequest.ParticipantNumber,
            EffectiveRequest.StageIndex]));
          Exit;
        end;

        // A previous request in this batch may have filled the same result.
        if EffectiveRequest.OverwritePolicy = fopRejectExisting then
          for J := 0 to I - 1 do
            if (PendingResults[J].ParticipantNumber =
              EffectiveRequest.ParticipantNumber) and
              (PendingResults[J].StageIndex = EffectiveRequest.StageIndex) then
            begin
              SetFailure(AFailure, ffkExistingResult,
                Format('Participant %d already has a finish in this batch.',
                [EffectiveRequest.ParticipantNumber]));
              Exit;
            end;

        PendingResult.ParticipantNumber := EffectiveRequest.ParticipantNumber;
        PendingResult.ParticipantName := ParticipantName;
        PendingResult.Category := ParticipantCategory;
        PendingResult.StageIndex := EffectiveRequest.StageIndex;
        PendingResult.FinishTime := EffectiveRequest.FinishTime;
        if TMainSql.TryLoadCategoryLeaderStageData(Query,
          EffectiveRequest.StageIndex, ParticipantCategory,
          PendingResult.PreviousLeaderNumber, LeaderStageData,
          AStages.Count) then
          PendingResult.PreviousLeaderResult := LeaderStageData.ResultValue;

        SetLength(CheckedStages, 1);
        CheckedStages[0] := EffectiveRequest.StageIndex;
        ChangedStages[I] := EffectiveRequest.StageIndex;
        TMainSql.ExecUpdateFinishForCheckedStages(Query, CheckedStages,
          EffectiveRequest.FinishTime, EffectiveRequest.ParticipantNumber,
          AStages.Count);
        if HasStoredMark then
        begin
          AppliedMark := StoredMark;
          if not AppliedMark.TryApply(EffectiveRequest.ParticipantNumber,
            EffectiveRequest.AppliedAt) then
            raise EDatabaseError.CreateFmt(
              'Finish mark %d could not be applied.', [StoredMark.Id]);
          TFinishMarkSql.ExecUpdate(Query, AppliedMark);
        end;
        PendingResults[I] := PendingResult;
      end;

      // Dialogs and external notifications belong outside this transaction.
      AFailedIndex := -1;
      TResultCalculationService.RecalculateStagesInCurrentTransaction(
        AContext, AStages, ChangedStages);
      for I := 0 to High(PendingResults) do
      begin
        PendingResult := PendingResults[I];
        if not TMainSql.TryLoadParticipantStageData(Query,
          PendingResult.ParticipantNumber, PendingResult.StageIndex,
          AStages.Count, CurrentStageData) then
          raise EDatabaseError.CreateFmt(
            'Saved participant %d could not be loaded.',
            [PendingResult.ParticipantNumber]);
        PendingResult.ResultValue := CurrentStageData.ResultValue;
        if CurrentStageData.HasPlace then
          PendingResult.Place := CurrentStageData.Place;
        if (PendingResult.Place = 1) and
          (PendingResult.PreviousLeaderNumber > 0) then
        begin
          if TMainSql.TryLoadParticipantStageData(Query,
            PendingResult.PreviousLeaderNumber, PendingResult.StageIndex,
            AStages.Count, LeaderStageData) then
            PendingResult.Difference := LeaderStageData.DiffLeader;
        end
        else
          PendingResult.Difference := CurrentStageData.DiffLeader;
        PendingResults[I] := PendingResult;
      end;
      UnitOfWork.Commit;
      AResults := PendingResults;
      Result := True;
    except
      on E: Exception do
        SetFailure(AFailure, ffkDatabase, E.Message);
    end;
  finally
    UnitOfWork.Free;
    Query.Free;
  end;
end;

class function TTelegramResultNotifier.RedactError(
  const AMessage, AUrl, AEndpoint: string): string;
begin
  Result := AMessage;
  if AUrl <> '' then
    Result := StringReplace(Result, AUrl, '[redacted]',
      [rfReplaceAll, rfIgnoreCase]);
  if AEndpoint <> '' then
    Result := StringReplace(Result, AEndpoint, '[redacted]',
      [rfReplaceAll, rfIgnoreCase]);
end;

class function TTelegramResultNotifier.BuildRequest(const AResult: TFinishResult;
  const AEndpoint: string): THttpRequest;
var
  Difference: string;
  Fields: THttpFormFields;

  procedure AddField(const AName, AValue: string);
  var
    Index: integer;
  begin
    Index := Length(Fields);
    SetLength(Fields, Index + 1);
    Fields[Index] := HttpFormField(AName, AValue);
  end;

begin
  Difference := '';
  if (AResult.Place = 1) and (AResult.PreviousLeaderNumber > 0) then
    Difference := FormatDiff(AResult.Difference, '-')
  else if AResult.Place <> 1 then
    Difference := FormatDiff(AResult.Difference, '');

  Fields := nil;
  AddField('number', IntToStr(AResult.ParticipantNumber));
  if AResult.ParticipantName <> '' then
    AddField('name', AResult.ParticipantName);
  if AResult.Category <> '' then
    AddField('category', AResult.Category);
  if AResult.ResultValue <> '' then
    AddField('result', FormatTime(AResult.ResultValue));
  if Difference <> '' then
    AddField('diff', Difference);
  AddField('place', IntToStr(AResult.Place));
  Result := BuildRequest(AEndpoint, Fields);
end;

class function TTelegramResultNotifier.BuildRequest(const AEndpoint: string;
  const AFields: THttpFormFields): THttpRequest;
begin
  Result := BuildHttpGetRequest(AEndpoint, AFields, TELEGRAM_CONNECT_TIMEOUT_MS,
    TELEGRAM_READ_TIMEOUT_MS);
end;

class function TTelegramResultNotifier.Send(const ARequest: THttpRequest;
  const AEndpoint: string; const ATransport: IHttpTransport):
TFinishNotificationOutcome;
var
  Index: integer;
  QuerySuffix: string;
  Response: THttpResponse;
begin
  InitializeNotificationOutcome(Result);
  if Copy(ARequest.Url, 1, Length(AEndpoint)) = AEndpoint then
  begin
    QuerySuffix := Copy(ARequest.Url, Length(AEndpoint) + 1, MaxInt);
    if (QuerySuffix <> '') and (QuerySuffix[1] in ['?', '&']) then
      Delete(QuerySuffix, 1, 1);
    if QuerySuffix <> '' then
    begin
      Result.RequestParameterCount := 1;
      for Index := 1 to Length(QuerySuffix) do
        if QuerySuffix[Index] = '&' then
          Inc(Result.RequestParameterCount);
    end;
  end;
  if (AEndpoint = '') or not Assigned(ATransport) then
  begin
    Result.SafeErrorMessage := rsHTTPRequestNotStarted;
    Exit;
  end;

  try
    Response := ATransport.Execute(ARequest);
    Result.ResponseStatusCode := Response.StatusCode;
    Result.ResponseStatusText := Response.StatusText;
    Result.ResponseHeaderCount := Length(Response.Headers);
    Result.ResponseSize := Length(Response.Body);
    Result.TransportErrorKind := Response.ErrorKind;
    Result.Success := Response.Completed and (Response.ErrorKind = hekNone) and
      IsHttpSuccessStatus(Response.StatusCode);
    if Result.Success then
      Exit;
    if Response.ErrorKind <> hekNone then
      Result.SafeErrorMessage :=
        RedactError(Response.ErrorMessage, ARequest.Url, AEndpoint)
    else
      Result.SafeErrorMessage :=
        IntToStr(Response.StatusCode) + ' ' + Response.StatusText;
    if Result.SafeErrorMessage = '' then
      Result.SafeErrorMessage := rsHTTPRequestNotStarted;
  except
    on E: Exception do
      Result.SafeErrorMessage := RedactError(E.Message, ARequest.Url, AEndpoint);
  end;
end;

class function TTelegramResultNotifier.Notify(const AResult: TFinishResult;
  const AEndpoint: string; const ATransport: IHttpTransport):
TFinishNotificationOutcome;
begin
  Result := Send(BuildRequest(AResult, AEndpoint), AEndpoint, ATransport);
end;

end.
