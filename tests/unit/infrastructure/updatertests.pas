unit UpdaterTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Updater, HttpTransport,
  FakeHttpTransport;

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
    procedure CurrentCodebergJson_UsesTagAndHtmlUrl;
    procedure ReleaseJson_IgnoresNameAndNormalizesTag;
    procedure ReleaseJson_MissingTagFails;
    procedure ReleaseJson_NonStringTagFails;
    procedure ReleaseJson_InvalidTagFails;
    procedure ReleaseJson_MissingHtmlUrlFails;
    procedure ReleaseJson_NonStringHtmlUrlFails;
    procedure ReleaseJson_EmptyHtmlUrlFails;
    procedure ReleaseJson_NonObjectFails;
    procedure ReleaseJson_MalformedJsonFails;
    procedure SharedTransport_BuildsRequestAndPreservesJsonContract;
    procedure SharedTransport_MapsHttpAndTransportFailures;
    procedure SharedTransport_CancelForwardsToActiveRequest;
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

const
  CURRENT_CODEBERG_RELEASE_JSON =
    '{"id":11256131,' +
    '"tag_name":"0.8.2",' +
    '"target_commitish":"master",' +
    '"name":"0.8.2",' +
    '"body":"### Added\\r\\n\\r\\n' +
      '- Добавлено журналирование основных действий приложения в файл и интерфейс.' +
      '\\r\\n\\r\\n### Fixed\\r\\n\\r\\n' +
      '- Исправлена возможная задержка запуска приложения при отсутствии интернета.' +
      '\\r\\n",' +
    '"url":"https://codeberg.org/api/v1/repos/Syutkin/entime/releases/11256131",' +
    '"html_url":"https://codeberg.org/Syutkin/entime/releases/tag/0.8.2",' +
    '"tarball_url":"https://codeberg.org/Syutkin/entime/archive/0.8.2.tar.gz",' +
    '"zipball_url":"https://codeberg.org/Syutkin/entime/archive/0.8.2.zip",' +
    '"hide_archive_links":true,' +
    '"upload_url":"https://codeberg.org/api/v1/repos/Syutkin/entime/releases/11256131/assets",' +
    '"draft":false,"prerelease":false,' +
    '"created_at":"2026-08-03T00:24:05+02:00",' +
    '"published_at":"2026-08-03T00:24:05+02:00",' +
    '"author":{' +
      '"id":4660,"login":"Syutkin","login_name":"",' +
      '"source_id":0,"full_name":"",' +
      '"email":"syutkin@noreply.codeberg.org",' +
      '"avatar_url":"https://codeberg.org/avatars/f3fe709089bb419e5aa27c4595b9e476",' +
      '"html_url":"https://codeberg.org/Syutkin",' +
      '"language":"","is_admin":false,' +
      '"last_login":"0001-01-01T00:00:00Z",' +
      '"created":"2019-12-17T10:51:34+01:00",' +
      '"restricted":false,"active":false,"prohibit_login":false,' +
      '"location":"","pronouns":"","website":"",' +
      '"description":"","visibility":"public",' +
      '"followers_count":0,"following_count":0,' +
      '"starred_repos_count":0,"username":"Syutkin"' +
    '},' +
    '"assets":[{' +
      '"id":1741619,' +
      '"name":"Entime-0.8.2-win-x64.zip",' +
      '"size":8461713,' +
      '"download_count":1,' +
      '"created_at":"2026-08-03T00:33:09+02:00",' +
      '"uuid":"544f3f2b-7cb0-449b-a983-73838cc24d97",' +
      '"browser_download_url":' +
        '"https://codeberg.org/Syutkin/entime/releases/download/0.8.2/Entime-0.8.2-win-x64.zip",' +
      '"type":"attachment"' +
    '},{' +
      '"id":1741616,' +
      '"name":"Entime-0.8.2-win-x64.zip.sha256",' +
      '"size":90,' +
      '"download_count":0,' +
      '"created_at":"2026-08-03T00:33:08+02:00",' +
      '"uuid":"448eb321-024b-4275-be98-3d43cb014da6",' +
      '"browser_download_url":' +
        '"https://codeberg.org/Syutkin/entime/releases/download/0.8.2/Entime-0.8.2-win-x64.zip.sha256",' +
      '"type":"attachment"' +
    '}],' +
    '"archive_download_count":{"zip":0,"tar_gz":0}' +
    '}';

var
  FakeResult: TUpdateCheckResult;
  FakeCheckCount: integer;
  FakeCancelCount: integer;
  FakeShouldBlock: boolean;
  FakeStartedEvent: PRTLEvent;
  FakeReleaseEvent: PRTLEvent;

type
  TBlockingUpdateTransportFactory = class;

  TBlockingUpdateTransport = class(TInterfacedObject, IHttpTransport)
  private
    FOwner: TBlockingUpdateTransportFactory;
  public
    constructor Create(const AOwner: TBlockingUpdateTransportFactory);
    function Execute(const ARequest: THttpRequest): THttpResponse;
    procedure Cancel;
  end;

  TBlockingUpdateTransportFactory = class(TInterfacedObject,
    IHttpTransportFactory)
  private
    FLock: TRTLCriticalSection;
    FStarted: PRTLEvent;
    FRelease: PRTLEvent;
    FCancelCount: integer;
    FExecuteCount: integer;
  public
    constructor Create;
    destructor Destroy; override;
    function CreateTransport: IHttpTransport;
    function WaitForRequest(const ATimeoutMs: cardinal): boolean;
    procedure RecordCancel;
    function CancelCount: integer;
  end;

  TFakeUpdateChecker = class(TInterfacedObject, IUpdateChecker)
  public
    function CheckForUpdates(const ACurrentVersion: string): TUpdateCheckResult;
    procedure Cancel;
  end;

constructor TBlockingUpdateTransport.Create(
  const AOwner: TBlockingUpdateTransportFactory);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TBlockingUpdateTransport.Execute(
  const ARequest: THttpRequest): THttpResponse;
begin
  EnterCriticalSection(FOwner.FLock);
  try
    Inc(FOwner.FExecuteCount);
  finally
    LeaveCriticalSection(FOwner.FLock);
  end;
  RTLEventSetEvent(FOwner.FStarted);
  RTLEventWaitFor(FOwner.FRelease);
  Result := Default(THttpResponse);
  Result.ErrorKind := hekCancelled;
  Result.ErrorMessage := 'cancelled';
end;

procedure TBlockingUpdateTransport.Cancel;
begin
  FOwner.RecordCancel;
end;

constructor TBlockingUpdateTransportFactory.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FStarted := RTLEventCreate;
  FRelease := RTLEventCreate;
end;

destructor TBlockingUpdateTransportFactory.Destroy;
begin
  RTLEventSetEvent(FRelease);
  RTLEventDestroy(FStarted);
  RTLEventDestroy(FRelease);
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TBlockingUpdateTransportFactory.CreateTransport: IHttpTransport;
begin
  Result := TBlockingUpdateTransport.Create(Self);
end;

function TBlockingUpdateTransportFactory.WaitForRequest(
  const ATimeoutMs: cardinal): boolean;
begin
  RTLEventWaitFor(FStarted, ATimeoutMs);
  EnterCriticalSection(FLock);
  try
    Result := FExecuteCount > 0;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TBlockingUpdateTransportFactory.RecordCancel;
begin
  EnterCriticalSection(FLock);
  try
    Inc(FCancelCount);
  finally
    LeaveCriticalSection(FLock);
  end;
  RTLEventSetEvent(FRelease);
end;

function TBlockingUpdateTransportFactory.CancelCount: integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FCancelCount;
  finally
    LeaveCriticalSection(FLock);
  end;
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
  FakeResult.ReleaseUrl := 'https://codeberg.org/Syutkin/entime/releases/tag/0.8.1';
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
  FCompletedResult.ReleaseUrl := '';
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

procedure TUpdaterTests.CurrentCodebergJson_UsesTagAndHtmlUrl;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse(
      '0.8.1.229', CURRENT_CODEBERG_RELEASE_JSON);
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsUpdateAvailable), Ord(checkResult.Status));
  AssertEquals('0.8.2', checkResult.LastVersion);
  AssertEquals('https://codeberg.org/Syutkin/entime/releases/tag/0.8.2',
    checkResult.ReleaseUrl);
  AssertEquals('', checkResult.ErrorMessage);
end;

procedure TUpdaterTests.ReleaseJson_IgnoresNameAndNormalizesTag;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse('0.8.2',
      '{"tag_name":"v0.8.3","name":"Entime release 0.8.3",' +
      '"html_url":"https://codeberg.org/Syutkin/entime/releases/tag/v0.8.3"}');
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsUpdateAvailable), Ord(checkResult.Status));
  AssertEquals('0.8.3', checkResult.LastVersion);
  AssertEquals('https://codeberg.org/Syutkin/entime/releases/tag/v0.8.3',
    checkResult.ReleaseUrl);
end;

procedure TUpdaterTests.ReleaseJson_MissingTagFails;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse('0.8.1',
      '{"name":"0.8.2","html_url":"https://codeberg.org/release"}');
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsFailed), Ord(checkResult.Status));
  AssertTrue(Pos('tag_name', checkResult.ErrorMessage) > 0);
  AssertEquals('', checkResult.LastVersion);
  AssertEquals('', checkResult.ReleaseUrl);
end;

procedure TUpdaterTests.ReleaseJson_NonStringTagFails;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse('0.8.1',
      '{"tag_name":802,"html_url":"https://codeberg.org/release"}');
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsFailed), Ord(checkResult.Status));
  AssertTrue(Pos('tag_name', checkResult.ErrorMessage) > 0);
end;

procedure TUpdaterTests.ReleaseJson_InvalidTagFails;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse('0.8.1',
      '{"tag_name":"Entime 0.8.2",' +
      '"html_url":"https://codeberg.org/release"}');
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsFailed), Ord(checkResult.Status));
  AssertTrue(Pos('tag_name', checkResult.ErrorMessage) > 0);
end;

procedure TUpdaterTests.ReleaseJson_MissingHtmlUrlFails;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse('0.8.1',
      '{"tag_name":"0.8.2","name":"0.8.2"}');
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsFailed), Ord(checkResult.Status));
  AssertTrue(Pos('html_url', checkResult.ErrorMessage) > 0);
end;

procedure TUpdaterTests.ReleaseJson_NonStringHtmlUrlFails;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse('0.8.1',
      '{"tag_name":"0.8.2","html_url":802}');
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsFailed), Ord(checkResult.Status));
  AssertTrue(Pos('html_url', checkResult.ErrorMessage) > 0);
end;

procedure TUpdaterTests.ReleaseJson_EmptyHtmlUrlFails;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse('0.8.1',
      '{"tag_name":"0.8.2","html_url":"  "}');
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsFailed), Ord(checkResult.Status));
  AssertTrue(Pos('html_url', checkResult.ErrorMessage) > 0);
end;

procedure TUpdaterTests.ReleaseJson_NonObjectFails;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse('0.8.1', '[]');
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsFailed), Ord(checkResult.Status));
  AssertTrue(Pos('JSON object', checkResult.ErrorMessage) > 0);
end;

procedure TUpdaterTests.ReleaseJson_MalformedJsonFails;
var
  checker: TUpdater;
  checkResult: TUpdateCheckResult;
begin
  checker := TUpdater.Create;
  try
    checkResult := checker.EvaluateReleaseResponse('0.8.1', '{broken json');
  finally
    checker.Free;
  end;

  AssertEquals(Ord(ucsFailed), Ord(checkResult.Status));
  AssertTrue(checkResult.ErrorMessage <> '');
  AssertEquals('', checkResult.LastVersion);
  AssertEquals('', checkResult.ReleaseUrl);
end;

procedure TUpdaterTests.SharedTransport_BuildsRequestAndPreservesJsonContract;
var
  CheckResult: TUpdateCheckResult;
  Factory: IHttpTransportFactory;
  FactoryObject: TFakeHttpTransportFactory;
  Response: THttpResponse;
  UpdaterObject: TUpdater;
begin
  FactoryObject := TFakeHttpTransportFactory.Create;
  Factory := FactoryObject;
  Response := Default(THttpResponse);
  Response.Completed := True;
  Response.StatusCode := 200;
  Response.StatusText := 'OK';
  Response.Body := CURRENT_CODEBERG_RELEASE_JSON;
  FactoryObject.QueueResponse(Response);
  UpdaterObject := TUpdater.Create(Factory);
  try
    CheckResult := UpdaterObject.CheckForUpdates('0.8.1.229');

    AssertEquals(Ord(ucsUpdateAvailable), Ord(CheckResult.Status));
    AssertEquals('0.8.2', CheckResult.LastVersion);
    AssertEquals(1, FactoryObject.TransportCount);
    AssertEquals(1, FactoryObject.Transports[0].RequestCount);
    AssertEquals(Ord(hmGet),
      Ord(FactoryObject.Transports[0].Requests[0].Method));
    AssertEquals(
      'https://codeberg.org/api/v1/repos/syutkin/entime/releases/latest',
      FactoryObject.Transports[0].Requests[0].Url);
    AssertEquals(UPDATE_HTTP_TIMEOUT_MS,
      FactoryObject.Transports[0].Requests[0].ConnectTimeoutMs);
    AssertEquals(UPDATE_HTTP_TIMEOUT_MS,
      FactoryObject.Transports[0].Requests[0].ReadTimeoutMs);
  finally
    UpdaterObject.Free;
  end;
end;

procedure TUpdaterTests.SharedTransport_MapsHttpAndTransportFailures;
var
  CheckResult: TUpdateCheckResult;
  Factory: IHttpTransportFactory;
  FactoryObject: TFakeHttpTransportFactory;
  Response: THttpResponse;
  UpdaterObject: TUpdater;
begin
  FactoryObject := TFakeHttpTransportFactory.Create;
  Factory := FactoryObject;
  Response := Default(THttpResponse);
  Response.Completed := True;
  Response.StatusCode := 503;
  Response.StatusText := 'Service Unavailable';
  FactoryObject.QueueResponse(Response);
  UpdaterObject := TUpdater.Create(Factory);
  try
    CheckResult := UpdaterObject.CheckForUpdates('0.8.1');
    AssertEquals(Ord(ucsFailed), Ord(CheckResult.Status));
    AssertTrue(Pos('503', CheckResult.ErrorMessage) > 0);
  finally
    UpdaterObject.Free;
  end;

  FactoryObject := TFakeHttpTransportFactory.Create;
  Factory := FactoryObject;
  Response := Default(THttpResponse);
  Response.ErrorKind := hekTimeout;
  Response.ErrorMessage := 'HTTP request timed out';
  FactoryObject.QueueResponse(Response);
  UpdaterObject := TUpdater.Create(Factory);
  try
    CheckResult := UpdaterObject.CheckForUpdates('0.8.1');
    AssertEquals(Ord(ucsFailed), Ord(CheckResult.Status));
    AssertEquals('HTTP request timed out', CheckResult.ErrorMessage);
  finally
    UpdaterObject.Free;
  end;
end;

procedure TUpdaterTests.SharedTransport_CancelForwardsToActiveRequest;
var
  Checker: IUpdateChecker;
  Factory: IHttpTransportFactory;
  FactoryObject: TBlockingUpdateTransportFactory;
  Worker: TUpdateCheckThread;
begin
  FactoryObject := TBlockingUpdateTransportFactory.Create;
  Factory := FactoryObject;
  Checker := TUpdater.Create(Factory);
  Worker := TUpdateCheckThread.Create(Checker, '0.8.1', nil);
  try
    Worker.Start;
    AssertTrue(FactoryObject.WaitForRequest(1000));

    Worker.Cancel;
    Worker.WaitFor;

    AssertEquals(1, FactoryObject.CancelCount);
    AssertEquals(Ord(ucsCancelled), Ord(Worker.CheckResult.Status));
  finally
    Worker.Free;
    Checker := nil;
  end;
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
      AssertEquals(FakeResult.ReleaseUrl, worker.CheckResult.ReleaseUrl);
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
