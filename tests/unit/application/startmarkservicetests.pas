unit StartMarkServiceTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, FPCUnit, TestRegistry, TimingMark, StartMark,
  StartMarkMatcher, StartMarkService;

type
  { TFakeStartMarkPersistence }

  TFakeStartMarkPersistence = class(TInterfacedObject,
    IStartMarkPersistence)
  private
    FInsertCount: integer;
    FHideWorkQueueCount: integer;
    FHideWorkQueueResult: integer;
    FLastUpdated: TStartMark;
    FUpdateCount: integer;
  public
    function Insert(const AMark: TStartMark): TStartMark;
    function TryLoadById(const AMarkId: int64;
      out AMark: TStartMark): boolean;
    function HideWorkQueue: integer;
    procedure Update(const AMark: TStartMark);
    property InsertCount: integer read FInsertCount;
    property HideWorkQueueCount: integer read FHideWorkQueueCount;
    property HideWorkQueueResult: integer read FHideWorkQueueResult
      write FHideWorkQueueResult;
    property LastUpdated: TStartMark read FLastUpdated;
    property UpdateCount: integer read FUpdateCount;
  end;

  { TFakeStartMarkCandidateProvider }

  TFakeStartMarkCandidateProvider = class(TInterfacedObject,
    IStartMarkCandidateProvider)
  private
    FCandidates: TStartMarkCandidateArray;
    FCallCount: integer;
    FLastStageIndex: integer;
  public
    procedure LoadCandidates(const AStageIndex: integer;
      out ACandidates: TStartMarkCandidateArray);
    property Candidates: TStartMarkCandidateArray read FCandidates
      write FCandidates;
    property CallCount: integer read FCallCount;
    property LastStageIndex: integer read FLastStageIndex;
  end;

  { TFakeStartMarkApplyPort }

  TFakeStartMarkApplyPort = class(TInterfacedObject, IStartMarkApplyPort)
  private
    FCallCount: integer;
    FLastRequest: TStartMarkApplyRequest;
    FNextDiagnostic: string;
    FNextFailure: TStartMarkApplyFailure;
  public
    function TryApply(const ARequest: TStartMarkApplyRequest;
      out AFailure: TStartMarkApplyFailure;
      out ADiagnostic: string): boolean;
    property CallCount: integer read FCallCount;
    property LastRequest: TStartMarkApplyRequest read FLastRequest;
    property NextDiagnostic: string read FNextDiagnostic write FNextDiagnostic;
    property NextFailure: TStartMarkApplyFailure read FNextFailure
      write FNextFailure;
  end;

  { TStartMarkServiceTests }

  TStartMarkServiceTests = class(TTestCase)
  private
    FApplyPort: TFakeStartMarkApplyPort;
    FApplyPortInterface: IStartMarkApplyPort;
    FProvider: TFakeStartMarkCandidateProvider;
    FProviderInterface: IStartMarkCandidateProvider;
    FPersistence: TFakeStartMarkPersistence;
    FPersistenceInterface: IStartMarkPersistence;
    FService: TStartMarkService;
    FChangedCount: integer;
    FChangedMarkId: int64;
    function MarkAt(const ATime: TDateTime;
      const AHasCorrection: boolean = True): TStartMark;
    procedure MarkChanged(Sender: TObject; const AMarkId: int64);
    procedure RaisingMarkChanged(Sender: TObject; const AMarkId: int64);
    procedure SetCandidates(const AValues: array of TStartMarkCandidate);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Receive_ManualModeStoresNearestProposalWithoutApplying;
    procedure Receive_NoMatchLeavesMarkPending;
    procedure Receive_AmbiguousMatchCreatesConflict;
    procedure Receive_AutomaticModeAppliesUniqueCorrectedMark;
    procedure Receive_AutomaticModeWithoutCorrectionCreatesConflict;
    procedure Receive_AutomaticModeDoesNotOverwriteExistingCorrection;
    procedure Receive_AutomaticModeMissingParticipantCreatesConflict;
    procedure Receive_NewMarkIsStoredBeforeAutomaticApply;
    procedure Receive_AlreadyAppliedMarkIsIdempotent;
    procedure SetParticipantNumber_LoadsAndPersistsDraftWithoutApplying;
    procedure HideWorkQueue_DelegatesToPersistence;
    procedure ApplyManualById_LoadsCurrentMarkBeforeApplying;
    procedure ApplyManual_ReplacesProposalAndCanUseDifferentStage;
    procedure ApplyManual_ApplicationErrorMarksError;
    procedure ApplyManual_AlreadyAppliedMarkIsIdempotent;
    procedure Receive_NotifiesAfterPersistence;
    procedure ObserverError_DoesNotFailPersistedChange;
  end;

implementation

function TFakeStartMarkPersistence.Insert(
  const AMark: TStartMark): TStartMark;
begin
  Inc(FInsertCount);
  Result := AMark;
  Result.Id := 73;
end;

function TFakeStartMarkPersistence.TryLoadById(const AMarkId: int64;
  out AMark: TStartMark): boolean;
begin
  AMark := FLastUpdated;
  AMark.Id := AMarkId;
  Result := AMarkId > 0;
end;

function TFakeStartMarkPersistence.HideWorkQueue: integer;
begin
  Inc(FHideWorkQueueCount);
  Result := FHideWorkQueueResult;
end;

procedure TFakeStartMarkPersistence.Update(const AMark: TStartMark);
begin
  Inc(FUpdateCount);
  FLastUpdated := AMark;
end;

procedure TFakeStartMarkCandidateProvider.LoadCandidates(
  const AStageIndex: integer; out ACandidates: TStartMarkCandidateArray);
var
  Index: integer;
begin
  Inc(FCallCount);
  FLastStageIndex := AStageIndex;
  SetLength(ACandidates, Length(FCandidates));
  for Index := 0 to High(FCandidates) do
    ACandidates[Index] := FCandidates[Index];
end;

function TFakeStartMarkApplyPort.TryApply(
  const ARequest: TStartMarkApplyRequest;
  out AFailure: TStartMarkApplyFailure;
  out ADiagnostic: string): boolean;
begin
  Inc(FCallCount);
  FLastRequest := ARequest;
  AFailure := FNextFailure;
  ADiagnostic := FNextDiagnostic;
  Result := FNextFailure = smafNone;
end;

procedure TStartMarkServiceTests.SetUp;
begin
  inherited SetUp;
  FProvider := TFakeStartMarkCandidateProvider.Create;
  FProviderInterface := FProvider;
  FApplyPort := TFakeStartMarkApplyPort.Create;
  FApplyPortInterface := FApplyPort;
  FPersistence := TFakeStartMarkPersistence.Create;
  FPersistenceInterface := FPersistence;
  FService := TStartMarkService.Create(FProviderInterface,
    FApplyPortInterface, FPersistenceInterface);
end;

procedure TStartMarkServiceTests.TearDown;
begin
  FService.Free;
  FService := nil;
  FPersistenceInterface := nil;
  FPersistence := nil;
  FApplyPortInterface := nil;
  FApplyPort := nil;
  FProviderInterface := nil;
  FProvider := nil;
  inherited TearDown;
end;

procedure TStartMarkServiceTests.Receive_NewMarkIsStoredBeforeAutomaticApply;
var
  Mark: TStartMark;
  Result: TStartMarkReceiveResult;
begin
  Mark := MarkAt(EncodeTime(10, 0, 0, 0));
  Mark.Id := 0;
  SetCandidates([TStartMarkCandidate.Create(17, 2,
    EncodeTime(10, 0, 1, 0))]);

  Result := FService.Receive(Mark, 3, True,
    EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertEquals(1, FPersistence.InsertCount);
  AssertEquals(73, FApplyPort.LastRequest.MarkId);
  AssertEquals(73, Result.Mark.Id);
  AssertEquals(Ord(smsApplied), Ord(Result.Mark.Status));
end;

function TStartMarkServiceTests.MarkAt(const ATime: TDateTime;
  const AHasCorrection: boolean): TStartMark;
begin
  Result := TStartMark.FromTimingMark(TTimingMark.Start(ATime,
    AHasCorrection, 125, TTimingMarkSource.Serial('COM1'),
    EncodeDateTime(2026, 8, 13, 10, 0, 1, 0)), 2);
  Result.Id := 42;
end;

procedure TStartMarkServiceTests.SetCandidates(
  const AValues: array of TStartMarkCandidate);
var
  Index: integer;
begin
  SetLength(FProvider.FCandidates, Length(AValues));
  for Index := 0 to High(AValues) do
    FProvider.FCandidates[Index] := AValues[Index];
end;

procedure TStartMarkServiceTests.MarkChanged(Sender: TObject;
  const AMarkId: int64);
begin
  Inc(FChangedCount);
  FChangedMarkId := AMarkId;
end;

procedure TStartMarkServiceTests.RaisingMarkChanged(Sender: TObject;
  const AMarkId: int64);
begin
  Inc(FChangedCount);
  FChangedMarkId := AMarkId;
  raise Exception.Create('journal refresh failed');
end;

procedure TStartMarkServiceTests.Receive_NotifiesAfterPersistence;
var
  Mark: TStartMark;
begin
  FService.OnChanged := @MarkChanged;
  Mark := MarkAt(EncodeTime(10, 0, 0, 0));
  Mark.Id := 0;

  FService.Receive(Mark, 3, False,
    EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertEquals(1, FPersistence.InsertCount);
  AssertEquals(1, FChangedCount);
  AssertEquals(73, FChangedMarkId);
end;

procedure TStartMarkServiceTests.ObserverError_DoesNotFailPersistedChange;
begin
  FService.OnChanged := @RaisingMarkChanged;

  FService.SetParticipantNumber(42, True, 19);

  AssertEquals(1, FPersistence.UpdateCount);
  AssertEquals(19, FPersistence.LastUpdated.ParticipantNumber);
  AssertEquals(1, FChangedCount);
  AssertEquals(42, FChangedMarkId);
end;

procedure TStartMarkServiceTests.
  HideWorkQueue_DelegatesToPersistence;
begin
  FPersistence.HideWorkQueueResult := 3;

  AssertEquals(3, FService.HideWorkQueue);

  AssertEquals(1, FPersistence.HideWorkQueueCount);
  AssertEquals(0, FApplyPort.CallCount);
end;

procedure TStartMarkServiceTests.
  Receive_ManualModeStoresNearestProposalWithoutApplying;
var
  Result: TStartMarkReceiveResult;
begin
  SetCandidates([TStartMarkCandidate.Create(17, 2,
    EncodeTime(10, 0, 2, 0))]);

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 0, 0)), 3,
    False, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertTrue(Result.HasMatch);
  AssertEquals(Ord(smmMatched), Ord(Result.Match.Status));
  AssertEquals(2000, Result.Match.DeltaMs);
  AssertEquals(2, FProvider.LastStageIndex);
  AssertTrue(Result.Mark.HasParticipantNumber);
  AssertEquals(17, Result.Mark.ParticipantNumber);
  AssertTrue(Result.Mark.HasMatchDeltaMs);
  AssertEquals(2000, Result.Mark.MatchDeltaMs);
  AssertEquals(Ord(smsPending), Ord(Result.Mark.Status));
  AssertFalse(Result.Mark.HasAssignmentMode);
  AssertEquals(0, FApplyPort.CallCount);
end;

procedure TStartMarkServiceTests.Receive_NoMatchLeavesMarkPending;
var
  Result: TStartMarkReceiveResult;
begin
  SetCandidates([TStartMarkCandidate.Create(17, 2,
    EncodeTime(10, 0, 10, 0))]);

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 0, 0)), 3,
    True, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertTrue(Result.HasMatch);
  AssertEquals(Ord(smmNoMatch), Ord(Result.Match.Status));
  AssertEquals(Ord(smsPending), Ord(Result.Mark.Status));
  AssertFalse(Result.Mark.HasParticipantNumber);
  AssertFalse(Result.Mark.HasMatchDeltaMs);
  AssertEquals(0, FApplyPort.CallCount);
end;

procedure TStartMarkServiceTests.Receive_AmbiguousMatchCreatesConflict;
var
  Result: TStartMarkReceiveResult;
begin
  SetCandidates([
    TStartMarkCandidate.Create(17, 2, EncodeTime(9, 59, 59, 0)),
    TStartMarkCandidate.Create(18, 2, EncodeTime(10, 0, 1, 0))]);

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 0, 0)), 3,
    True, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertEquals(Ord(smmAmbiguous), Ord(Result.Match.Status));
  AssertEquals(Ord(smsConflict), Ord(Result.Mark.Status));
  AssertTrue(Result.Mark.HasMatchDeltaMs);
  AssertEquals(1000, Result.Mark.MatchDeltaMs);
  AssertEquals('ambiguous', Result.Mark.Diagnostic);
  AssertEquals(0, FApplyPort.CallCount);
end;

procedure TStartMarkServiceTests.
  Receive_AutomaticModeAppliesUniqueCorrectedMark;
var
  AppliedAt: TDateTime;
  Result: TStartMarkReceiveResult;
begin
  AppliedAt := EncodeDateTime(2026, 8, 13, 10, 0, 3, 0);
  SetCandidates([TStartMarkCandidate.Create(17, 2,
    EncodeTime(10, 0, 2, 0))]);

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 0, 0)), 3,
    True, AppliedAt);

  AssertEquals(Ord(smsApplied), Ord(Result.Mark.Status));
  AssertEquals(Ord(smamAutomatic), Ord(Result.Mark.AssignmentMode));
  AssertEquals(2, Result.Mark.AppliedStageIndex);
  AssertEquals(17, Result.Mark.ParticipantNumber);
  AssertEquals(AppliedAt, Result.Mark.AppliedAt);
  AssertEquals(Ord(smafNone), Ord(Result.ApplyFailure));
  AssertEquals(1, FApplyPort.CallCount);
  AssertEquals(42, FApplyPort.LastRequest.MarkId);
  AssertEquals(17, FApplyPort.LastRequest.ParticipantNumber);
  AssertEquals(2, FApplyPort.LastRequest.StageIndex);
  AssertEquals(125, FApplyPort.LastRequest.CorrectionMs);
  AssertEquals(Ord(smamAutomatic),
    Ord(FApplyPort.LastRequest.AssignmentMode));
  AssertFalse(FApplyPort.LastRequest.OverwriteExistingCorrection);
end;

procedure TStartMarkServiceTests.
  Receive_AutomaticModeWithoutCorrectionCreatesConflict;
var
  Result: TStartMarkReceiveResult;
begin
  SetCandidates([TStartMarkCandidate.Create(17, 2,
    EncodeTime(10, 0, 1, 0))]);

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 0, 0), False),
    3, True, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertEquals(Ord(smafCorrectionMissing), Ord(Result.ApplyFailure));
  AssertEquals(Ord(smsConflict), Ord(Result.Mark.Status));
  AssertEquals('correction_missing', Result.Mark.Diagnostic);
  AssertEquals(0, FApplyPort.CallCount);
end;

procedure TStartMarkServiceTests.
  Receive_AutomaticModeDoesNotOverwriteExistingCorrection;
var
  Result: TStartMarkReceiveResult;
begin
  FApplyPort.NextFailure := smafExistingCorrection;
  SetCandidates([TStartMarkCandidate.Create(17, 2,
    EncodeTime(10, 0, 1, 0))]);

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 0, 0)), 3,
    True, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertEquals(Ord(smafExistingCorrection), Ord(Result.ApplyFailure));
  AssertEquals(Ord(smsConflict), Ord(Result.Mark.Status));
  AssertEquals('existing_correction', Result.Mark.Diagnostic);
  AssertFalse(FApplyPort.LastRequest.OverwriteExistingCorrection);
end;

procedure TStartMarkServiceTests.
  Receive_AutomaticModeMissingParticipantCreatesConflict;
var
  Result: TStartMarkReceiveResult;
begin
  FApplyPort.NextFailure := smafParticipantNotFound;
  SetCandidates([TStartMarkCandidate.Create(17, 2,
    EncodeTime(10, 0, 1, 0))]);

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 0, 0)), 3,
    True, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertEquals(Ord(smafParticipantNotFound), Ord(Result.ApplyFailure));
  AssertEquals(Ord(smsConflict), Ord(Result.Mark.Status));
  AssertEquals('participant_not_found', Result.Mark.Diagnostic);
end;

procedure TStartMarkServiceTests.Receive_AlreadyAppliedMarkIsIdempotent;
var
  Mark: TStartMark;
  Result: TStartMarkReceiveResult;
begin
  Mark := MarkAt(EncodeTime(10, 0, 0, 0));
  AssertTrue(Mark.TryApply(17, 2, smamAutomatic,
    EncodeDateTime(2026, 8, 13, 10, 0, 3, 0)));

  Result := FService.Receive(Mark, 3, True,
    EncodeDateTime(2026, 8, 13, 10, 0, 4, 0));

  AssertFalse(Result.HasMatch);
  AssertEquals(Ord(smsApplied), Ord(Result.Mark.Status));
  AssertEquals(17, Result.Mark.ParticipantNumber);
  AssertEquals(0, FProvider.CallCount);
  AssertEquals(0, FApplyPort.CallCount);
end;

procedure TStartMarkServiceTests.
  SetParticipantNumber_LoadsAndPersistsDraftWithoutApplying;
var
  Mark: TStartMark;
begin
  FPersistence.FLastUpdated := MarkAt(EncodeTime(10, 0, 0, 0));

  Mark := FService.SetParticipantNumber(42, True, 23);

  AssertTrue(Mark.HasParticipantNumber);
  AssertEquals(23, Mark.ParticipantNumber);
  AssertEquals(Ord(smsPending), Ord(Mark.Status));
  AssertFalse(Mark.HasAssignmentMode);
  AssertFalse(Mark.HasAppliedStageIndex);
  AssertEquals(1, FPersistence.UpdateCount);
  AssertEquals(23, FPersistence.LastUpdated.ParticipantNumber);
  AssertEquals(0, FApplyPort.CallCount);
end;

procedure TStartMarkServiceTests.
  ApplyManualById_LoadsCurrentMarkBeforeApplying;
var
  AppliedAt: TDateTime;
  Mark: TStartMark;
  Result: TStartMarkApplyResult;
begin
  AppliedAt := EncodeDateTime(2026, 8, 14, 10, 0, 0, 0);
  Mark := MarkAt(EncodeTime(10, 0, 0, 0));
  Mark.Id := 42;
  Mark.SetParticipantNumber(True, 23);
  FPersistence.FLastUpdated := Mark;

  Result := FService.ApplyManualById(42, 23, 4, False, AppliedAt);

  AssertTrue(Result.Applied);
  AssertEquals(1, FApplyPort.CallCount);
  AssertEquals(42, FApplyPort.LastRequest.MarkId);
  AssertEquals(23, FApplyPort.LastRequest.ParticipantNumber);
  AssertEquals(4, FApplyPort.LastRequest.StageIndex);
end;

procedure TStartMarkServiceTests.
  ApplyManual_ReplacesProposalAndCanUseDifferentStage;
var
  AppliedAt: TDateTime;
  Mark: TStartMark;
  Result: TStartMarkApplyResult;
begin
  AppliedAt := EncodeDateTime(2026, 8, 13, 10, 0, 3, 0);
  Mark := MarkAt(EncodeTime(10, 0, 0, 0));
  Mark.HasMatchDeltaMs := True;
  Mark.MatchDeltaMs := 2000;
  Mark.SuggestParticipant(17);

  Result := FService.ApplyManual(Mark, 23, 4, True, AppliedAt);

  AssertTrue(Result.Applied);
  AssertEquals(Ord(smsApplied), Ord(Result.Mark.Status));
  AssertEquals(2, Result.Mark.StageIndex);
  AssertEquals(4, Result.Mark.AppliedStageIndex);
  AssertEquals(23, Result.Mark.ParticipantNumber);
  AssertFalse(Result.Mark.HasMatchDeltaMs);
  AssertEquals(Ord(smamManual), Ord(Result.Mark.AssignmentMode));
  AssertEquals(23, FApplyPort.LastRequest.ParticipantNumber);
  AssertFalse(FApplyPort.LastRequest.HasMatchDeltaMs);
  AssertEquals(4, FApplyPort.LastRequest.StageIndex);
  AssertTrue(FApplyPort.LastRequest.OverwriteExistingCorrection);
end;

procedure TStartMarkServiceTests.ApplyManual_ApplicationErrorMarksError;
var
  Mark: TStartMark;
  Result: TStartMarkApplyResult;
begin
  FApplyPort.NextFailure := smafApplicationError;
  FApplyPort.NextDiagnostic := 'database unavailable';
  Mark := MarkAt(EncodeTime(10, 0, 0, 0));
  Mark.MarkConflict('ambiguous');

  Result := FService.ApplyManual(Mark, 23, 2, False,
    EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertFalse(Result.Applied);
  AssertEquals(Ord(smafApplicationError), Ord(Result.ApplyFailure));
  AssertEquals(Ord(smsError), Ord(Result.Mark.Status));
  AssertEquals('database unavailable', Result.Mark.Diagnostic);
end;

procedure TStartMarkServiceTests.ApplyManual_AlreadyAppliedMarkIsIdempotent;
var
  AppliedAt: TDateTime;
  Mark: TStartMark;
  Result: TStartMarkApplyResult;
begin
  AppliedAt := EncodeDateTime(2026, 8, 13, 10, 0, 3, 0);
  Mark := MarkAt(EncodeTime(10, 0, 0, 0));
  AssertTrue(Mark.TryApply(17, 2, smamManual, AppliedAt));

  Result := FService.ApplyManual(Mark, 23, 4, True,
    AppliedAt + OneSecond);

  AssertTrue(Result.Applied);
  AssertEquals(17, Result.Mark.ParticipantNumber);
  AssertEquals(2, Result.Mark.AppliedStageIndex);
  AssertEquals(AppliedAt, Result.Mark.AppliedAt);
  AssertEquals(0, FApplyPort.CallCount);
end;

initialization
  RegisterTest(TStartMarkServiceTests);

end.
