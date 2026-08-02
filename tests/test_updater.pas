unit test_updater;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, updater;

type
  TUpdaterTests = class(TTestCase)
  private
    FController: TUpdateCheckController;
    FCompletionCount: integer;
    FCompletedMode: TUpdateCheckMode;
    FCompletedResult: TUpdateCheckResult;
    procedure UpdateCompleted(Sender: TObject; AMode: TUpdateCheckMode;
      const AResult: TUpdateCheckResult);
    procedure WaitForCompletion;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure VersionComparisonRecognizesNewerVersions;
    procedure WorkerPropagatesEveryCheckerResult;
    procedure AutomaticCheckDoesNotStartWhenDisabled;
    procedure AutomaticCheckDoesNotStartBeforeInterval;
    procedure AutomaticCheckStartsWhenDue;
    procedure ManualCheckIgnoresAutomaticSettings;
    procedure ActiveCheckRejectsSecondStart;
    procedure CancelStopsActiveCheckWithoutCompletionCallback;
    procedure OnlySuccessfulChecksAdvanceTheSchedule;
    procedure AutomaticPresentationIsSilentForUpToDateAndFailure;
    procedure ManualPresentationReportsUpToDateAndFailure;
  end;

implementation

var
  FakeResult: TUpdateCheckResult;
  FakeCheckCount: integer;
  FakeCancelCount: integer;
  FakeShouldBlock: boolean;
  FakeStartedEvent: PRTLEvent;
  FakeReleaseEvent: PRTLEvent;

type
  TFakeUpdateChecker = class(TInterfacedObject, IUpdateChecker)
  public
    function CheckForUpdates(const ACurrentVersion: string): TUpdateCheckResult;
    procedure Cancel;
  end;

function CreateFakeUpdateChecker: IUpdateChecker;
begin
  Result := TFakeUpdateChecker.Create;
end;

function TFakeUpdateChecker.CheckForUpdates(
  const ACurrentVersion: string): TUpdateCheckResult;
begin
  InterlockedIncrement(FakeCheckCount);
  RTLEventSetEvent(FakeStartedEvent);
  if FakeShouldBlock then
    RTLEventWaitFor(FakeReleaseEvent);
  Result := FakeResult;
end;

procedure TFakeUpdateChecker.Cancel;
begin
  InterlockedIncrement(FakeCancelCount);
  RTLEventSetEvent(FakeReleaseEvent);
end;

procedure TUpdaterTests.SetUp;
begin
  inherited SetUp;
  FakeResult.Status := ucsUpToDate;
  FakeResult.LastVersion := '0.8.1';
  FakeResult.ErrorMessage := '';
  FakeCheckCount := 0;
  FakeCancelCount := 0;
  FakeShouldBlock := False;
  FakeStartedEvent := RTLEventCreate;
  FakeReleaseEvent := RTLEventCreate;
  FController := TUpdateCheckController.Create(
    @CreateFakeUpdateChecker, @UpdateCompleted);
  FCompletionCount := 0;
  FCompletedMode := ucmAutomatic;
  FCompletedResult.Status := ucsCancelled;
  FCompletedResult.LastVersion := '';
  FCompletedResult.ErrorMessage := '';
end;

procedure TUpdaterTests.TearDown;
begin
  RTLEventSetEvent(FakeReleaseEvent);
  FController.Cancel;
  FController.Free;
  RTLEventDestroy(FakeStartedEvent);
  RTLEventDestroy(FakeReleaseEvent);
  inherited TearDown;
end;

procedure TUpdaterTests.UpdateCompleted(Sender: TObject;
  AMode: TUpdateCheckMode; const AResult: TUpdateCheckResult);
begin
  Inc(FCompletionCount);
  FCompletedMode := AMode;
  FCompletedResult := AResult;
end;

procedure TUpdaterTests.WaitForCompletion;
var
  deadline: QWord;
begin
  deadline := GetTickCount64 + 2000;
  while (FCompletionCount = 0) and (GetTickCount64 < deadline) do
  begin
    CheckSynchronize(10);
    Sleep(1);
  end;
  AssertEquals('Update check did not complete in time', 1, FCompletionCount);
end;

procedure TUpdaterTests.VersionComparisonRecognizesNewerVersions;
begin
  AssertTrue(IsNewerVersion('0.8.1', '0.8.2'));
  AssertTrue(IsNewerVersion('0.8.1.145', '0.8.2'));
  AssertTrue(IsNewerVersion('0.8.1', '0.9.0'));
  AssertTrue(IsNewerVersion('0.8.1', '1.0.0'));
  AssertFalse(IsNewerVersion('0.8.1', '0.8.1'));
  AssertFalse(IsNewerVersion('0.8.1.145', '0.8.1'));
  AssertFalse(IsNewerVersion('0.8.1', '0.8.0'));
  AssertFalse(IsNewerVersion('', '0.8.2'));
  AssertFalse(IsNewerVersion('0.8.1', 'invalid'));
end;

procedure TUpdaterTests.WorkerPropagatesEveryCheckerResult;
const
  statuses: array[0..3] of TUpdateCheckStatus = (
    ucsUpdateAvailable,
    ucsUpToDate,
    ucsFailed,
    ucsCancelled
  );
var
  status: TUpdateCheckStatus;
  worker: TUpdateCheckThread;
begin
  for status in statuses do
  begin
    FakeResult.Status := status;
    worker := TUpdateCheckThread.Create(
      CreateFakeUpdateChecker, '0.8.1', nil);
    try
      worker.Start;
      worker.WaitFor;
      AssertEquals(Ord(status), Ord(worker.CheckResult.Status));
      AssertEquals(FakeResult.LastVersion, worker.CheckResult.LastVersion);
      AssertEquals(FakeResult.ErrorMessage, worker.CheckResult.ErrorMessage);
    finally
      worker.Free;
    end;
  end;
  AssertEquals(4, FakeCheckCount);
end;

procedure TUpdaterTests.AutomaticCheckDoesNotStartWhenDisabled;
begin
  AssertFalse(FController.StartAutomatic(
    '0.8.1', False, -1, 0, Now));
  AssertFalse(FController.Busy);
  AssertEquals(0, FakeCheckCount);
end;

procedure TUpdaterTests.AutomaticCheckDoesNotStartBeforeInterval;
var
  nowValue: TDateTime;
begin
  nowValue := EncodeDate(2026, 7, 31);
  AssertFalse(FController.StartAutomatic(
    '0.8.1', True, 7, nowValue - 1, nowValue));
  AssertFalse(FController.Busy);
  AssertEquals(0, FakeCheckCount);
end;

procedure TUpdaterTests.AutomaticCheckStartsWhenDue;
var
  nowValue: TDateTime;
begin
  nowValue := EncodeDate(2026, 7, 31);
  AssertTrue(FController.StartAutomatic(
    '0.8.1', True, 7, nowValue - 8, nowValue));
  WaitForCompletion;
  AssertEquals(1, FakeCheckCount);
  AssertEquals(Ord(ucmAutomatic), Ord(FCompletedMode));
end;

procedure TUpdaterTests.ManualCheckIgnoresAutomaticSettings;
begin
  AssertTrue(FController.StartManual('0.8.1'));
  WaitForCompletion;
  AssertEquals(1, FakeCheckCount);
  AssertEquals(Ord(ucmManual), Ord(FCompletedMode));
end;

procedure TUpdaterTests.ActiveCheckRejectsSecondStart;
begin
  FakeShouldBlock := True;
  AssertTrue(FController.StartManual('0.8.1'));
  RTLEventWaitFor(FakeStartedEvent, 1000);
  AssertTrue(FController.Busy);
  AssertFalse(FController.StartManual('0.8.1'));
  AssertFalse(FController.StartAutomatic('0.8.1', True, -1, 0, Now));
  AssertEquals(1, FakeCheckCount);

  RTLEventSetEvent(FakeReleaseEvent);
  WaitForCompletion;
  AssertFalse(FController.Busy);
end;

procedure TUpdaterTests.CancelStopsActiveCheckWithoutCompletionCallback;
begin
  FakeShouldBlock := True;
  AssertTrue(FController.StartManual('0.8.1'));
  RTLEventWaitFor(FakeStartedEvent, 1000);

  FController.Cancel;

  AssertFalse(FController.Busy);
  AssertEquals(1, FakeCancelCount);
  CheckSynchronize(10);
  AssertEquals(0, FCompletionCount);
end;

procedure TUpdaterTests.OnlySuccessfulChecksAdvanceTheSchedule;
begin
  AssertTrue(UpdateCheckSucceeded(ucsUpdateAvailable));
  AssertTrue(UpdateCheckSucceeded(ucsUpToDate));
  AssertFalse(UpdateCheckSucceeded(ucsFailed));
  AssertFalse(UpdateCheckSucceeded(ucsCancelled));
end;

procedure TUpdaterTests.AutomaticPresentationIsSilentForUpToDateAndFailure;
begin
  AssertEquals(Ord(ucnNone), Ord(UpdateCheckNotification(
    ucmAutomatic, ucsUpToDate)));
  AssertEquals(Ord(ucnNone), Ord(UpdateCheckNotification(
    ucmAutomatic, ucsFailed)));
  AssertEquals(Ord(ucnUpdateAvailable), Ord(UpdateCheckNotification(
    ucmAutomatic, ucsUpdateAvailable)));
end;

procedure TUpdaterTests.ManualPresentationReportsUpToDateAndFailure;
begin
  AssertEquals(Ord(ucnUpToDate), Ord(UpdateCheckNotification(
    ucmManual, ucsUpToDate)));
  AssertEquals(Ord(ucnFailure), Ord(UpdateCheckNotification(
    ucmManual, ucsFailed)));
  AssertEquals(Ord(ucnUpdateAvailable), Ord(UpdateCheckNotification(
    ucmManual, ucsUpdateAvailable)));
end;

initialization
  RegisterTest(TUpdaterTests);

end.
