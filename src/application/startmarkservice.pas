unit StartMarkService;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, StartMark, StartMarkMatcher;

type
  TStartMarkChangedEvent = procedure(Sender: TObject;
    const AMarkId: int64) of object;

  TStartMarkApplyFailure = (smafNone, smafCorrectionMissing,
    smafParticipantNotFound, smafExistingCorrection,
    smafApplicationError);

  { TStartMarkApplyRequest }

  TStartMarkApplyRequest = record
    MarkId: int64;
    ParticipantNumber: integer;
    StageIndex: integer;
    CorrectionMs: integer;
    HasMatchDeltaMs: boolean;
    MatchDeltaMs: integer;
    AssignmentMode: TStartMarkAssignmentMode;
    OverwriteExistingCorrection: boolean;
    AppliedAt: TDateTime;
  end;

  { IStartMarkCandidateProvider }

  IStartMarkCandidateProvider = interface
    ['{468E7185-D4D9-4991-B9E0-07BA168121CA}']
    procedure LoadCandidates(const AStageIndex: integer;
      out ACandidates: TStartMarkCandidateArray);
  end;

  { IStartMarkApplyPort }

  IStartMarkApplyPort = interface
    ['{489056E9-7A31-4A80-AAB2-A892F611A1DE}']
    function TryApply(const ARequest: TStartMarkApplyRequest;
      out AFailure: TStartMarkApplyFailure;
      out ADiagnostic: string): boolean;
  end;

  { IStartMarkPersistence }

  IStartMarkPersistence = interface
    ['{99472A1C-C05C-4F36-A097-32816B226EB7}']
    function Insert(const AMark: TStartMark): TStartMark;
    function TryLoadById(const AMarkId: int64;
      out AMark: TStartMark): boolean;
    function HideWorkQueue: integer;
    procedure Update(const AMark: TStartMark);
  end;

  { TStartMarkApplyResult }

  TStartMarkApplyResult = record
    Mark: TStartMark;
    Applied: boolean;
    ApplyFailure: TStartMarkApplyFailure;
  end;

  { TStartMarkReceiveResult }

  TStartMarkReceiveResult = record
    Mark: TStartMark;
    HasMatch: boolean;
    Match: TStartMarkMatch;
    ApplyFailure: TStartMarkApplyFailure;
  end;

  { TStartMarkService }

  TStartMarkService = class
  private
    FApplyPort: IStartMarkApplyPort;
    FCandidateProvider: IStartMarkCandidateProvider;
    FPersistence: IStartMarkPersistence;
    FOnChanged: TStartMarkChangedEvent;
    procedure NotifyChanged(const AMarkId: int64);
    function Apply(const AMark: TStartMark;
      const AParticipantNumber, AStageIndex: integer;
      const AAssignmentMode: TStartMarkAssignmentMode;
      const AOverwriteExistingCorrection: boolean;
      const AAppliedAt: TDateTime): TStartMarkApplyResult;
  public
    constructor Create(const ACandidateProvider: IStartMarkCandidateProvider;
      const AApplyPort: IStartMarkApplyPort;
      const APersistence: IStartMarkPersistence);
    function Receive(const AMark: TStartMark;
      const AToleranceSeconds: integer;
      const AAutomaticApply: boolean;
      const AAppliedAt: TDateTime): TStartMarkReceiveResult;
    function SetParticipantNumber(const AMarkId: int64;
      const AHasParticipantNumber: boolean;
      const AParticipantNumber: integer): TStartMark;
    function TryLoad(const AMarkId: int64; out AMark: TStartMark): boolean;
    function HideWorkQueue: integer;
    function ApplyManualById(const AMarkId: int64;
      const AParticipantNumber, AStageIndex: integer;
      const AOverwriteExistingCorrection: boolean;
      const AAppliedAt: TDateTime): TStartMarkApplyResult;
    function ApplyManual(const AMark: TStartMark;
      const AParticipantNumber, AStageIndex: integer;
      const AOverwriteExistingCorrection: boolean;
      const AAppliedAt: TDateTime): TStartMarkApplyResult;
    property OnChanged: TStartMarkChangedEvent read FOnChanged
      write FOnChanged;
  end;

function StartMarkApplyFailureCode(
  const AFailure: TStartMarkApplyFailure): string;

implementation

function StartMarkApplyFailureCode(
  const AFailure: TStartMarkApplyFailure): string;
begin
  case AFailure of
    smafNone: Result := '';
    smafCorrectionMissing: Result := 'correction_missing';
    smafParticipantNotFound: Result := 'participant_not_found';
    smafExistingCorrection: Result := 'existing_correction';
    smafApplicationError: Result := 'application_error';
  end;
end;

constructor TStartMarkService.Create(
  const ACandidateProvider: IStartMarkCandidateProvider;
  const AApplyPort: IStartMarkApplyPort;
  const APersistence: IStartMarkPersistence);
begin
  inherited Create;
  if not Assigned(ACandidateProvider) then
    raise EArgumentNilException.Create('Candidate provider is required.');
  if not Assigned(AApplyPort) then
    raise EArgumentNilException.Create('Apply port is required.');
  if not Assigned(APersistence) then
    raise EArgumentNilException.Create('Persistence is required.');
  FCandidateProvider := ACandidateProvider;
  FApplyPort := AApplyPort;
  FPersistence := APersistence;
end;

procedure TStartMarkService.NotifyChanged(const AMarkId: int64);
begin
  if not Assigned(FOnChanged) then
    Exit;
  try
    FOnChanged(Self, AMarkId);
  except
    { A presentation observer must not turn a persisted change into a
      reported application failure. }
  end;
end;

function TStartMarkService.Apply(const AMark: TStartMark;
  const AParticipantNumber, AStageIndex: integer;
  const AAssignmentMode: TStartMarkAssignmentMode;
  const AOverwriteExistingCorrection: boolean;
  const AAppliedAt: TDateTime): TStartMarkApplyResult;
var
  Diagnostic: string;
  Failure: TStartMarkApplyFailure;
  Request: TStartMarkApplyRequest;
  ValidatedMark: TStartMark;
begin
  Result := Default(TStartMarkApplyResult);
  Result.Mark := AMark;
  if AMark.Status = smsApplied then
  begin
    Result.Applied := True;
    Exit;
  end;

  if Result.Mark.Id = 0 then
    Result.Mark := FPersistence.Insert(Result.Mark);

  if Result.Mark.HasMatchDeltaMs and
    ((not Result.Mark.HasParticipantNumber) or
    (Result.Mark.ParticipantNumber <> AParticipantNumber)) then
  begin
    Result.Mark.HasMatchDeltaMs := False;
    Result.Mark.MatchDeltaMs := 0;
  end;

  if not Result.Mark.HasCorrection then
  begin
    Result.ApplyFailure := smafCorrectionMissing;
    Result.Mark.MarkConflict(
      StartMarkApplyFailureCode(Result.ApplyFailure));
    FPersistence.Update(Result.Mark);
    Exit;
  end;

  { Validate every domain transition before crossing the transactional port. }
  ValidatedMark := Result.Mark;
  ValidatedMark.TryApply(AParticipantNumber, AStageIndex,
    AAssignmentMode, AAppliedAt);

  Request := Default(TStartMarkApplyRequest);
  Request.MarkId := Result.Mark.Id;
  Request.ParticipantNumber := AParticipantNumber;
  Request.StageIndex := AStageIndex;
  Request.CorrectionMs := Result.Mark.CorrectionMs;
  Request.HasMatchDeltaMs := Result.Mark.HasMatchDeltaMs;
  Request.MatchDeltaMs := Result.Mark.MatchDeltaMs;
  Request.AssignmentMode := AAssignmentMode;
  Request.OverwriteExistingCorrection := AOverwriteExistingCorrection;
  Request.AppliedAt := AAppliedAt;

  Failure := smafNone;
  Diagnostic := '';
  if FApplyPort.TryApply(Request, Failure, Diagnostic) then
  begin
    Result.Mark := ValidatedMark;
    Result.Applied := True;
    Exit;
  end;

  if Failure = smafNone then
    Failure := smafApplicationError;
  Result.ApplyFailure := Failure;
  if Diagnostic = '' then
    Diagnostic := StartMarkApplyFailureCode(Failure);

  if Failure = smafApplicationError then
    Result.Mark.MarkError(Diagnostic)
  else
    Result.Mark.MarkConflict(Diagnostic);
  FPersistence.Update(Result.Mark);
end;

function TStartMarkService.Receive(const AMark: TStartMark;
  const AToleranceSeconds: integer; const AAutomaticApply: boolean;
  const AAppliedAt: TDateTime): TStartMarkReceiveResult;
var
  ApplyResult: TStartMarkApplyResult;
  Candidates: TStartMarkCandidateArray;
  Changed: boolean;
begin
  Changed := False;
  Result := Default(TStartMarkReceiveResult);
  Result.Mark := AMark;
  if AMark.Status <> smsPending then
    Exit;

  if Result.Mark.Id = 0 then
  begin
    Result.Mark := FPersistence.Insert(Result.Mark);
    Changed := True;
  end;

  FCandidateProvider.LoadCandidates(Result.Mark.StageIndex, Candidates);
  Result.Match := TStartMarkMatcher.Match(Result.Mark, Candidates,
    AToleranceSeconds);
  Result.HasMatch := True;

  case Result.Match.Status of
    smmNoMatch:
      begin
        if Changed then
          NotifyChanged(Result.Mark.Id);
        Exit;
      end;
    smmAmbiguous:
      begin
        Result.Mark.HasMatchDeltaMs := Result.Match.HasDeltaMs;
        Result.Mark.MatchDeltaMs := Result.Match.DeltaMs;
        Result.Mark.MarkConflict(Result.Match.Reason);
        FPersistence.Update(Result.Mark);
        NotifyChanged(Result.Mark.Id);
        Exit;
      end;
    smmMatched:
      begin
        Result.Mark.HasMatchDeltaMs := Result.Match.HasDeltaMs;
        Result.Mark.MatchDeltaMs := Result.Match.DeltaMs;
        Result.Mark.SuggestParticipant(Result.Match.ParticipantNumber);
        FPersistence.Update(Result.Mark);
        Changed := True;
      end;
  end;

  if not AAutomaticApply then
  begin
    if Changed then
      NotifyChanged(Result.Mark.Id);
    Exit;
  end;

  ApplyResult := Apply(Result.Mark, Result.Match.ParticipantNumber,
    Result.Mark.StageIndex, smamAutomatic, False, AAppliedAt);
  Result.Mark := ApplyResult.Mark;
  Result.ApplyFailure := ApplyResult.ApplyFailure;
  NotifyChanged(Result.Mark.Id);
end;

function TStartMarkService.ApplyManual(const AMark: TStartMark;
  const AParticipantNumber, AStageIndex: integer;
  const AOverwriteExistingCorrection: boolean;
  const AAppliedAt: TDateTime): TStartMarkApplyResult;
begin
  Result := Apply(AMark, AParticipantNumber, AStageIndex, smamManual,
    AOverwriteExistingCorrection, AAppliedAt);
  NotifyChanged(Result.Mark.Id);
end;

function TStartMarkService.SetParticipantNumber(const AMarkId: int64;
  const AHasParticipantNumber: boolean;
  const AParticipantNumber: integer): TStartMark;
begin
  if not FPersistence.TryLoadById(AMarkId, Result) then
    raise EArgumentException.CreateFmt(
      'Start mark %d was not found.', [AMarkId]);
  Result.SetParticipantNumber(AHasParticipantNumber, AParticipantNumber);
  FPersistence.Update(Result);
  NotifyChanged(Result.Id);
end;

function TStartMarkService.TryLoad(const AMarkId: int64;
  out AMark: TStartMark): boolean;
begin
  Result := FPersistence.TryLoadById(AMarkId, AMark);
end;

function TStartMarkService.HideWorkQueue: integer;
begin
  Result := FPersistence.HideWorkQueue;
  if Result > 0 then
    NotifyChanged(0);
end;

function TStartMarkService.ApplyManualById(const AMarkId: int64;
  const AParticipantNumber, AStageIndex: integer;
  const AOverwriteExistingCorrection: boolean;
  const AAppliedAt: TDateTime): TStartMarkApplyResult;
var
  Mark: TStartMark;
begin
  if not TryLoad(AMarkId, Mark) then
    raise EArgumentException.CreateFmt(
      'Start mark %d was not found.', [AMarkId]);
  Result := Apply(Mark, AParticipantNumber, AStageIndex, smamManual,
    AOverwriteExistingCorrection, AAppliedAt);
  NotifyChanged(Result.Mark.Id);
end;

end.
