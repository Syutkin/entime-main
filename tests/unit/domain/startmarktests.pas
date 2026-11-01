unit StartMarkTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, FPCUnit, TestRegistry, TimingMark, StartMark;

type
  TStartMarkTests = class(TTestCase)
  published
    procedure FromTimingMark_InitializesPendingStart;
    procedure FromTimingMark_RejectsFinish;
    procedure FromTimingMark_RejectsInvalidStage;
    procedure TryApply_FromPendingStoresAssignmentAndAppliedStage;
    procedure TryApply_FromConflictAllowsManualResolution;
    procedure TryApply_AutomaticRejectsDifferentStage;
    procedure TryApply_WhenAlreadyAppliedIsIdempotent;
    procedure SuggestParticipant_StoresProposalWithoutApplying;
    procedure SetParticipantNumber_UpdatesAndClearsManualDraft;
    procedure Hide_AllowsOnlyWorkQueueStatuses;
    procedure StateTransitions_RejectInvalidChanges;
  end;

implementation

procedure TStartMarkTests.FromTimingMark_InitializesPendingStart;
var
  Input: TTimingMark;
  Mark: TStartMark;
begin
  Input := TTimingMark.Start(EncodeTime(8, 1, 2, 3), True, 21,
    TTimingMarkSource.Ble('ENTime-3'), EncodeDateTime(2026, 8, 13, 8, 1, 3, 4));

  Mark := TStartMark.FromTimingMark(Input, 4);

  AssertEquals(0, Mark.Id);
  AssertEquals(4, Mark.StageIndex);
  AssertFalse(Mark.HasAppliedStageIndex);
  AssertEquals(Input.EventTime, Mark.EventTime);
  AssertTrue(Mark.HasCorrection);
  AssertEquals(21, Mark.CorrectionMs);
  AssertFalse(Mark.HasParticipantNumber);
  AssertFalse(Mark.HasMatchDeltaMs);
  AssertEquals(Ord(tmskBle), Ord(Mark.Source.Kind));
  AssertEquals('ENTime-3', Mark.Source.DeviceId);
  AssertEquals(Input.ReceivedAt, Mark.ReceivedAt);
  AssertFalse(Mark.HasAssignmentMode);
  AssertEquals(Ord(smsPending), Ord(Mark.Status));
  AssertFalse(Mark.HasAppliedAt);
  AssertEquals('', Mark.Diagnostic);
end;

procedure TStartMarkTests.TryApply_FromPendingStoresAssignmentAndAppliedStage;
var
  AppliedAt: TDateTime;
  Mark: TStartMark;
begin
  AppliedAt := EncodeDateTime(2026, 8, 13, 10, 2, 3, 4);
  Mark := TStartMark.FromTimingMark(TTimingMark.Start(
    EncodeTime(10, 2, 1, 0), True, 125, TTimingMarkSource.Serial('COM1'),
    AppliedAt - OneSecond), 2);

  AssertTrue(Mark.TryApply(17, 3, smamManual, AppliedAt));

  AssertEquals(2, Mark.StageIndex);
  AssertTrue(Mark.HasAppliedStageIndex);
  AssertEquals(3, Mark.AppliedStageIndex);
  AssertTrue(Mark.HasParticipantNumber);
  AssertEquals(17, Mark.ParticipantNumber);
  AssertTrue(Mark.HasAssignmentMode);
  AssertEquals(Ord(smamManual), Ord(Mark.AssignmentMode));
  AssertEquals(Ord(smsApplied), Ord(Mark.Status));
  AssertTrue(Mark.HasAppliedAt);
  AssertEquals(AppliedAt, Mark.AppliedAt);
  AssertEquals('', Mark.Diagnostic);
end;

procedure TStartMarkTests.TryApply_FromConflictAllowsManualResolution;
var
  Mark: TStartMark;
begin
  Mark := TStartMark.FromTimingMark(TTimingMark.Start(
    EncodeTime(10, 2, 1, 0), True, 125, TTimingMarkSource.Ble('device'), Now), 2);
  Mark.MarkConflict('ambiguous');

  AssertTrue(Mark.TryApply(17, 2, smamManual, Now));
  AssertEquals(Ord(smsApplied), Ord(Mark.Status));
  AssertEquals('', Mark.Diagnostic);
end;

procedure TStartMarkTests.TryApply_AutomaticRejectsDifferentStage;
var
  Mark: TStartMark;
begin
  Mark := TStartMark.FromTimingMark(TTimingMark.Start(
    EncodeTime(10, 2, 1, 0), True, 125, TTimingMarkSource.Ble('device'), Now), 2);

  try
    Mark.TryApply(17, 3, smamAutomatic, Now);
    Fail('Automatic assignment must use the stage captured on receipt.');
  except
    on E: EArgumentException do
      AssertTrue(Pos('automatic', LowerCase(E.Message)) > 0);
  end;

  AssertEquals(Ord(smsPending), Ord(Mark.Status));
  AssertFalse(Mark.HasAppliedStageIndex);
  AssertFalse(Mark.HasParticipantNumber);
end;

procedure TStartMarkTests.TryApply_WhenAlreadyAppliedIsIdempotent;
var
  FirstAppliedAt: TDateTime;
  Mark: TStartMark;
begin
  FirstAppliedAt := EncodeDateTime(2026, 8, 13, 10, 2, 3, 4);
  Mark := TStartMark.FromTimingMark(TTimingMark.Start(
    EncodeTime(10, 2, 1, 0), True, 125, TTimingMarkSource.Serial('COM1'),
    FirstAppliedAt - OneSecond), 2);
  AssertTrue(Mark.TryApply(17, 2, smamAutomatic, FirstAppliedAt));

  AssertFalse(Mark.TryApply(99, 4, smamManual, FirstAppliedAt + OneHour));

  AssertEquals(17, Mark.ParticipantNumber);
  AssertEquals(2, Mark.AppliedStageIndex);
  AssertEquals(Ord(smamAutomatic), Ord(Mark.AssignmentMode));
  AssertEquals(FirstAppliedAt, Mark.AppliedAt);
end;

procedure TStartMarkTests.SuggestParticipant_StoresProposalWithoutApplying;
var
  Mark: TStartMark;
begin
  Mark := TStartMark.FromTimingMark(TTimingMark.Start(
    EncodeTime(10, 2, 1, 0), True, 125, TTimingMarkSource.Serial('COM1'), Now), 2);

  Mark.HasMatchDeltaMs := True;
  Mark.MatchDeltaMs := 1250;
  Mark.SuggestParticipant(17);

  AssertTrue(Mark.HasParticipantNumber);
  AssertEquals(17, Mark.ParticipantNumber);
  AssertTrue(Mark.HasMatchDeltaMs);
  AssertEquals(1250, Mark.MatchDeltaMs);
  AssertEquals(Ord(smsPending), Ord(Mark.Status));
  AssertFalse(Mark.HasAssignmentMode);
  AssertFalse(Mark.HasAppliedStageIndex);
  AssertFalse(Mark.HasAppliedAt);
end;

procedure TStartMarkTests.SetParticipantNumber_UpdatesAndClearsManualDraft;
var
  Mark: TStartMark;
begin
  Mark := TStartMark.FromTimingMark(TTimingMark.Start(
    EncodeTime(10, 2, 1, 0), True, 125, TTimingMarkSource.Serial('COM1'), Now), 2);
  Mark.MarkConflict('ambiguous');

  Mark.SetParticipantNumber(True, 23);

  AssertTrue(Mark.HasParticipantNumber);
  AssertEquals(23, Mark.ParticipantNumber);
  AssertFalse(Mark.HasMatchDeltaMs);
  AssertEquals(Ord(smsConflict), Ord(Mark.Status));
  AssertEquals('ambiguous', Mark.Diagnostic);

  Mark.SetParticipantNumber(False, 0);

  AssertFalse(Mark.HasParticipantNumber);
  AssertEquals(0, Mark.ParticipantNumber);
  AssertEquals(Ord(smsConflict), Ord(Mark.Status));
  AssertEquals('ambiguous', Mark.Diagnostic);
end;

procedure TStartMarkTests.Hide_AllowsOnlyWorkQueueStatuses;
var
  Applied, Conflict, Pending: TStartMark;
begin
  Pending := TStartMark.FromTimingMark(TTimingMark.Start(
    EncodeTime(10, 2, 1, 0), True, 125, TTimingMarkSource.Serial('COM1'), Now), 2);
  Conflict := Pending;
  Conflict.MarkConflict('ambiguous');
  Applied := Pending;
  AssertTrue(Applied.TryApply(17, 2, smamManual, Now));

  Pending.Hide;
  Conflict.Hide;

  AssertEquals(Ord(smsHidden), Ord(Pending.Status));
  AssertEquals(Ord(smsHidden), Ord(Conflict.Status));
  try
    Applied.Hide;
    Fail('An applied mark must not be hidden from the work queue.');
  except
    on E: EInvalidOp do
      AssertTrue(Pos('applied', LowerCase(E.Message)) > 0);
  end;
  AssertEquals(Ord(smsApplied), Ord(Applied.Status));
end;

procedure TStartMarkTests.StateTransitions_RejectInvalidChanges;
var
  Mark: TStartMark;
begin
  Mark := TStartMark.FromTimingMark(TTimingMark.Start(
    EncodeTime(10, 2, 1, 0), False, 0, TTimingMarkSource.Serial('COM1'), Now), 2);
  Mark.Hide;
  AssertEquals(Ord(smsHidden), Ord(Mark.Status));
  try
    Mark.MarkConflict('ambiguous');
    Fail('A hidden start mark must not become a conflict.');
  except
    on E: EInvalidOp do
      AssertTrue(Pos('hidden', LowerCase(E.Message)) > 0);
  end;

  try
    Mark.TryApply(17, 2, smamManual, Now);
    Fail('A hidden start mark must not be applied.');
  except
    on E: EInvalidOp do
      AssertTrue(Pos('hidden', LowerCase(E.Message)) > 0);
  end;
end;

procedure TStartMarkTests.FromTimingMark_RejectsFinish;
var
  Input: TTimingMark;
begin
  Input := TTimingMark.Finish(EncodeTime(8, 1, 2, 3),
    TTimingMarkSource.Serial('COM1'), Now);
  try
    TStartMark.FromTimingMark(Input, 1);
    Fail('Finish mark must not be converted to TStartMark.');
  except
    on E: EArgumentException do
      AssertTrue(Pos('start', LowerCase(E.Message)) > 0);
  end;
end;

procedure TStartMarkTests.FromTimingMark_RejectsInvalidStage;
var
  Input: TTimingMark;
begin
  Input := TTimingMark.Start(EncodeTime(8, 1, 2, 3), False, 0,
    TTimingMarkSource.Serial('COM1'), Now);
  try
    TStartMark.FromTimingMark(Input, 0);
    Fail('Non-positive stage must be rejected.');
  except
    on E: EArgumentOutOfRangeException do
      AssertTrue(Pos('stage', LowerCase(E.Message)) > 0);
  end;
end;

initialization
  RegisterTest(TStartMarkTests);

end.
