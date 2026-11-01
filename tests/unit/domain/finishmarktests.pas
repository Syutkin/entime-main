unit FinishMarkTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, FPCUnit, TestRegistry, TimingMark, FinishMark;

type
  TFinishMarkTests = class(TTestCase)
  published
    procedure FromTimingMark_InitializesPendingFinish;
    procedure FromTimingMark_RejectsStart;
    procedure SetParticipantNumber_UpdatesAndClearsManualDraft;
    procedure TryApply_FromPendingStoresManualAssignment;
    procedure TryApply_WhenAlreadyAppliedIsIdempotent;
    procedure MarkIgnoredDebounce_PreservesDiagnostic;
    procedure StateTransitions_RejectInvalidChanges;
  end;

implementation

procedure TFinishMarkTests.SetParticipantNumber_UpdatesAndClearsManualDraft;
var
  Mark: TFinishMark;
begin
  Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
    EncodeTime(9, 2, 3, 4), TTimingMarkSource.Serial('COM9'), Now), 2);

  Mark.SetParticipantNumber(True, 31);
  AssertTrue(Mark.HasParticipantNumber);
  AssertEquals(31, Mark.ParticipantNumber);
  AssertFalse(Mark.HasAssignmentMode);
  AssertEquals(Ord(fmsPending), Ord(Mark.Status));

  Mark.SetParticipantNumber(False, 0);
  AssertFalse(Mark.HasParticipantNumber);
  AssertEquals(0, Mark.ParticipantNumber);
end;

procedure TFinishMarkTests.FromTimingMark_InitializesPendingFinish;
var
  Input: TTimingMark;
  Mark: TFinishMark;
begin
  Input := TTimingMark.Finish(EncodeTime(9, 2, 3, 4),
    TTimingMarkSource.Serial('COM9'), EncodeDateTime(2026, 8, 13, 9, 2, 4, 5));

  Mark := TFinishMark.FromTimingMark(Input, 2);

  AssertEquals(0, Mark.Id);
  AssertEquals(2, Mark.StageIndex);
  AssertEquals(Input.EventTime, Mark.EventTime);
  AssertFalse(Mark.HasParticipantNumber);
  AssertEquals(Ord(tmskSerial), Ord(Mark.Source.Kind));
  AssertEquals('COM9', Mark.Source.DeviceId);
  AssertEquals(Input.ReceivedAt, Mark.ReceivedAt);
  AssertFalse(Mark.HasAssignmentMode);
  AssertEquals(Ord(fmsPending), Ord(Mark.Status));
  AssertFalse(Mark.HasAppliedAt);
  AssertEquals('', Mark.Diagnostic);
end;

procedure TFinishMarkTests.TryApply_FromPendingStoresManualAssignment;
var
  AppliedAt: TDateTime;
  Mark: TFinishMark;
begin
  AppliedAt := EncodeDateTime(2026, 8, 13, 9, 3, 4, 5);
  Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
    EncodeTime(9, 2, 3, 4), TTimingMarkSource.Serial('COM9'),
    AppliedAt - OneSecond), 2);

  AssertTrue(Mark.TryApply(31, AppliedAt));

  AssertTrue(Mark.HasParticipantNumber);
  AssertEquals(31, Mark.ParticipantNumber);
  AssertTrue(Mark.HasAssignmentMode);
  AssertEquals(Ord(fmamManual), Ord(Mark.AssignmentMode));
  AssertEquals(Ord(fmsApplied), Ord(Mark.Status));
  AssertTrue(Mark.HasAppliedAt);
  AssertEquals(AppliedAt, Mark.AppliedAt);
  AssertEquals('', Mark.Diagnostic);
end;

procedure TFinishMarkTests.TryApply_WhenAlreadyAppliedIsIdempotent;
var
  FirstAppliedAt: TDateTime;
  Mark: TFinishMark;
begin
  FirstAppliedAt := EncodeDateTime(2026, 8, 13, 9, 3, 4, 5);
  Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
    EncodeTime(9, 2, 3, 4), TTimingMarkSource.Ble('device'),
    FirstAppliedAt - OneSecond), 2);
  AssertTrue(Mark.TryApply(31, FirstAppliedAt));

  AssertFalse(Mark.TryApply(99, FirstAppliedAt + OneHour));

  AssertEquals(31, Mark.ParticipantNumber);
  AssertEquals(FirstAppliedAt, Mark.AppliedAt);
end;

procedure TFinishMarkTests.MarkIgnoredDebounce_PreservesDiagnostic;
var
  Mark: TFinishMark;
begin
  Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
    EncodeTime(9, 2, 3, 4), TTimingMarkSource.Ble('device'), Now), 2);

  Mark.MarkIgnoredDebounce('within debounce interval');

  AssertEquals(Ord(fmsIgnoredDebounce), Ord(Mark.Status));
  AssertEquals('within debounce interval', Mark.Diagnostic);
  AssertFalse(Mark.HasParticipantNumber);
  AssertFalse(Mark.HasAppliedAt);
end;

procedure TFinishMarkTests.StateTransitions_RejectInvalidChanges;
var
  Mark: TFinishMark;
begin
  Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
    EncodeTime(9, 2, 3, 4), TTimingMarkSource.Serial('COM9'), Now), 2);
  Mark.MarkIgnoredDebounce('within debounce interval');
  try
    Mark.TryApply(31, Now);
    Fail('An ignored finish mark must not be applied.');
  except
    on E: EInvalidOp do
      AssertTrue(Pos('ignored_debounce', LowerCase(E.Message)) > 0);
  end;

  Mark.Hide;
  AssertEquals(Ord(fmsHidden), Ord(Mark.Status));
  AssertEquals('within debounce interval', Mark.Diagnostic);
end;

procedure TFinishMarkTests.FromTimingMark_RejectsStart;
var
  Input: TTimingMark;
begin
  Input := TTimingMark.Start(EncodeTime(9, 2, 3, 4), False, 0,
    TTimingMarkSource.Ble('device'), Now);
  try
    TFinishMark.FromTimingMark(Input, 1);
    Fail('Start mark must not be converted to TFinishMark.');
  except
    on E: EArgumentException do
      AssertTrue(Pos('finish', LowerCase(E.Message)) > 0);
  end;
end;

initialization
  RegisterTest(TFinishMarkTests);

end.
