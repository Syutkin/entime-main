unit TelegramNotificationCoordinatorTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpcunit, testregistry, HttpTransport,
  CompetitionFinishService, TelegramNotificationCoordinator;

type
  TTelegramNotificationCoordinatorTests = class(TTestCase)
  private
    FCallbackCount: Integer;
    FCallbackThreadId: TThreadID;
    FLastDelivery: TTelegramDeliveryResult;
    FDroppedCount: Integer;
    FLastDropped: TTelegramQueueItemInfo;
    procedure Completed(Sender: TObject;
      const ADelivery: TTelegramDeliveryResult);
    procedure Dropped(Sender: TObject;
      const AItem: TTelegramQueueItemInfo);
    procedure WaitForCallbacks(const ACount: Integer;
      const ATimeoutMs: QWord = 5000);
  published
    procedure RetryPolicy_InvalidValuesUseDefaults;
    procedure DisabledRetries_PerformsOneBackgroundAttempt;
    procedure EnabledRetries_RetriesNetworkAndRetryableStatuses;
    procedure EnabledRetries_DoesNotRetryOtherClientErrors;
    procedure Queue_IsSequentialFifo;
    procedure Queue_OverflowDropsOldestWaitingItem;
    procedure Shutdown_CancelsRetryDelayAndSuppressesCallbacks;
  end;

implementation

type
  TControlledTransportFactory = class;

  TControlledTransport = class(TInterfacedObject, IHttpTransport)
  private
    FOwner: TControlledTransportFactory;
  public
    constructor Create(const AOwner: TControlledTransportFactory);
    function Execute(const ARequest: THttpRequest): THttpResponse;
    procedure Cancel;
  end;

  TControlledTransportFactory = class(TInterfacedObject,
    IHttpTransportFactory)
  private
    FLock: TRTLCriticalSection;
    FResponses: array of THttpResponse;
    FUrls: array of string;
    FExecuteCount: Integer;
    FExecuteThreadId: TThreadID;
    FBlockFirst: Boolean;
    FStartedEvent: PRTLEvent;
    FReleaseEvent: PRTLEvent;
    function ExecuteRequest(const ARequest: THttpRequest): THttpResponse;
  public
    constructor Create;
    destructor Destroy; override;
    function CreateTransport: IHttpTransport;
    procedure QueueResponse(const AResponse: THttpResponse);
    procedure BlockFirstRequest;
    procedure ReleaseFirstRequest;
    function WaitForRequest(const ATimeoutMs: Cardinal): Boolean;
    function ExecuteCount: Integer;
    function ExecuteThreadId: TThreadID;
    function UrlAt(const AIndex: Integer): string;
  end;

function SuccessfulResponse: THttpResponse;
begin
  Result := Default(THttpResponse);
  Result.Completed := True;
  Result.StatusCode := 200;
  Result.StatusText := 'OK';
end;

function StatusResponse(const AStatusCode: Integer): THttpResponse;
begin
  Result := Default(THttpResponse);
  Result.Completed := True;
  Result.StatusCode := AStatusCode;
  Result.StatusText := 'HTTP error';
end;

function NetworkErrorResponse: THttpResponse;
begin
  Result := Default(THttpResponse);
  Result.ErrorKind := hekNetwork;
  Result.ErrorMessage := 'network unavailable';
end;

function TimeoutResponse: THttpResponse;
begin
  Result := Default(THttpResponse);
  Result.ErrorKind := hekTimeout;
  Result.ErrorMessage := 'request timed out';
end;

function NotificationResult(const ANumber: Integer): TFinishResult;
begin
  Result := Default(TFinishResult);
  Result.ParticipantNumber := ANumber;
  Result.ResultValue := '00:01:00.000';
  Result.Place := 1;
end;

procedure TTelegramNotificationCoordinatorTests.
  RetryPolicy_InvalidValuesUseDefaults;
var
  Policy: TTelegramRetryPolicy;
begin
  Policy := TTelegramRetryPolicy.Create(True, 0, 301);
  AssertTrue(Policy.Enabled);
  AssertEquals(TELEGRAM_RETRY_DEFAULT_COUNT, Policy.RetryCount);
  AssertEquals(TELEGRAM_RETRY_DEFAULT_DELAY_SECONDS, Policy.DelaySeconds);
end;

constructor TControlledTransport.Create(
  const AOwner: TControlledTransportFactory);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TControlledTransport.Execute(
  const ARequest: THttpRequest): THttpResponse;
begin
  Result := FOwner.ExecuteRequest(ARequest);
end;

procedure TControlledTransport.Cancel;
begin
  FOwner.ReleaseFirstRequest;
end;

constructor TControlledTransportFactory.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FStartedEvent := RTLEventCreate;
  FReleaseEvent := RTLEventCreate;
end;

destructor TControlledTransportFactory.Destroy;
begin
  RTLEventSetEvent(FReleaseEvent);
  RTLEventDestroy(FStartedEvent);
  RTLEventDestroy(FReleaseEvent);
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TControlledTransportFactory.CreateTransport: IHttpTransport;
begin
  Result := TControlledTransport.Create(Self);
end;

procedure TControlledTransportFactory.QueueResponse(
  const AResponse: THttpResponse);
var
  Index: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Index := Length(FResponses);
    SetLength(FResponses, Index + 1);
    FResponses[Index] := CloneHttpResponse(AResponse);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TControlledTransportFactory.BlockFirstRequest;
begin
  FBlockFirst := True;
end;

procedure TControlledTransportFactory.ReleaseFirstRequest;
begin
  RTLEventSetEvent(FReleaseEvent);
end;

function TControlledTransportFactory.WaitForRequest(
  const ATimeoutMs: Cardinal): Boolean;
begin
  RTLEventWaitFor(FStartedEvent, ATimeoutMs);
  Result := ExecuteCount > 0;
end;

function TControlledTransportFactory.ExecuteRequest(
  const ARequest: THttpRequest): THttpResponse;
var
  Index, ResponseIndex: Integer;
  ShouldBlock: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Index := FExecuteCount;
    Inc(FExecuteCount);
    FExecuteThreadId := GetCurrentThreadID;
    SetLength(FUrls, Length(FUrls) + 1);
    FUrls[High(FUrls)] := ARequest.Url;
    ShouldBlock := FBlockFirst and (Index = 0);
  finally
    LeaveCriticalSection(FLock);
  end;
  RTLEventSetEvent(FStartedEvent);
  if ShouldBlock then
    RTLEventWaitFor(FReleaseEvent);

  EnterCriticalSection(FLock);
  try
    if Length(FResponses) = 0 then
      Exit(SuccessfulResponse);
    Result := CloneHttpResponse(FResponses[0]);
    for ResponseIndex := 1 to High(FResponses) do
      FResponses[ResponseIndex - 1] := FResponses[ResponseIndex];
    SetLength(FResponses, Length(FResponses) - 1);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TControlledTransportFactory.ExecuteCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FExecuteCount;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TControlledTransportFactory.ExecuteThreadId: TThreadID;
begin
  EnterCriticalSection(FLock);
  try
    Result := FExecuteThreadId;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TControlledTransportFactory.UrlAt(const AIndex: Integer): string;
begin
  EnterCriticalSection(FLock);
  try
    Result := FUrls[AIndex];
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TTelegramNotificationCoordinatorTests.Completed(Sender: TObject;
  const ADelivery: TTelegramDeliveryResult);
begin
  Inc(FCallbackCount);
  FCallbackThreadId := GetCurrentThreadID;
  FLastDelivery := ADelivery;
end;

procedure TTelegramNotificationCoordinatorTests.Dropped(Sender: TObject;
  const AItem: TTelegramQueueItemInfo);
begin
  Inc(FDroppedCount);
  FLastDropped := AItem;
end;

procedure TTelegramNotificationCoordinatorTests.WaitForCallbacks(
  const ACount: Integer; const ATimeoutMs: QWord);
var
  StartedAt: QWord;
begin
  StartedAt := GetTickCount64;
  while (FCallbackCount < ACount) and
    (GetTickCount64 - StartedAt < ATimeoutMs) do
  begin
    CheckSynchronize(10);
    Sleep(1);
  end;
  AssertEquals('Timed out waiting for Telegram callback', ACount,
    FCallbackCount);
end;

procedure TTelegramNotificationCoordinatorTests.
  DisabledRetries_PerformsOneBackgroundAttempt;
var
  Coordinator: TTelegramNotificationCoordinator;
  FactoryIntf: IHttpTransportFactory;
  FactoryObject: TControlledTransportFactory;
begin
  FCallbackCount := 0;
  FactoryObject := TControlledTransportFactory.Create;
  FactoryIntf := FactoryObject;
  FactoryObject.QueueResponse(NetworkErrorResponse);
  FactoryObject.QueueResponse(SuccessfulResponse);
  Coordinator := TTelegramNotificationCoordinator.Create(FactoryIntf);
  try
    Coordinator.OnCompleted := @Completed;
    AssertTrue(Coordinator.EnqueueResult(NotificationResult(1),
      'https://example.invalid/token', TTelegramRetryPolicy.Disabled));
    WaitForCallbacks(1);
    AssertEquals(1, FactoryObject.ExecuteCount);
    AssertTrue('HTTP execute must run outside the UI thread',
      FactoryObject.ExecuteThreadId <> MainThreadID);
    AssertEquals('Completion must be delivered on the UI thread',
      MainThreadID, FCallbackThreadId);
    AssertFalse(FLastDelivery.Outcome.Success);
  finally
    Coordinator.Free;
  end;
end;

procedure TTelegramNotificationCoordinatorTests.
  EnabledRetries_RetriesNetworkAndRetryableStatuses;
var
  Coordinator: TTelegramNotificationCoordinator;
  FactoryIntf: IHttpTransportFactory;
  FactoryObject: TControlledTransportFactory;
begin
  FCallbackCount := 0;
  FactoryObject := TControlledTransportFactory.Create;
  FactoryIntf := FactoryObject;
  FactoryObject.QueueResponse(NetworkErrorResponse);
  FactoryObject.QueueResponse(TimeoutResponse);
  FactoryObject.QueueResponse(StatusResponse(408));
  FactoryObject.QueueResponse(StatusResponse(429));
  FactoryObject.QueueResponse(StatusResponse(500));
  FactoryObject.QueueResponse(SuccessfulResponse);
  Coordinator := TTelegramNotificationCoordinator.Create(FactoryIntf);
  try
    Coordinator.OnCompleted := @Completed;
    AssertTrue(Coordinator.EnqueueResult(NotificationResult(2),
      'https://example.invalid/token',
      TTelegramRetryPolicy.Create(True, 5, 1)));
    WaitForCallbacks(1, 7000);
    AssertEquals(6, FactoryObject.ExecuteCount);
    AssertEquals(6, FLastDelivery.AttemptCount);
    AssertTrue(FLastDelivery.Outcome.Success);
  finally
    Coordinator.Free;
  end;
end;

procedure TTelegramNotificationCoordinatorTests.
  EnabledRetries_DoesNotRetryOtherClientErrors;
var
  Coordinator: TTelegramNotificationCoordinator;
  FactoryIntf: IHttpTransportFactory;
  FactoryObject: TControlledTransportFactory;
begin
  FCallbackCount := 0;
  FactoryObject := TControlledTransportFactory.Create;
  FactoryIntf := FactoryObject;
  FactoryObject.QueueResponse(StatusResponse(400));
  FactoryObject.QueueResponse(SuccessfulResponse);
  Coordinator := TTelegramNotificationCoordinator.Create(FactoryIntf);
  try
    Coordinator.OnCompleted := @Completed;
    AssertTrue(Coordinator.EnqueueResult(NotificationResult(3),
      'https://example.invalid/token',
      TTelegramRetryPolicy.Create(True, 2, 1)));
    WaitForCallbacks(1);
    AssertEquals(1, FactoryObject.ExecuteCount);
  finally
    Coordinator.Free;
  end;
end;

procedure TTelegramNotificationCoordinatorTests.Queue_IsSequentialFifo;
var
  Coordinator: TTelegramNotificationCoordinator;
  FactoryIntf: IHttpTransportFactory;
  FactoryObject: TControlledTransportFactory;
  Index: Integer;
begin
  FCallbackCount := 0;
  FactoryObject := TControlledTransportFactory.Create;
  FactoryIntf := FactoryObject;
  FactoryObject.BlockFirstRequest;
  Coordinator := TTelegramNotificationCoordinator.Create(FactoryIntf);
  try
    Coordinator.OnCompleted := @Completed;
    for Index := 1 to 3 do
      AssertTrue(Coordinator.EnqueueResult(NotificationResult(Index),
        'https://example.invalid/token', TTelegramRetryPolicy.Disabled));
    AssertTrue(FactoryObject.WaitForRequest(1000));
    FactoryObject.ReleaseFirstRequest;
    WaitForCallbacks(3);
    AssertTrue(Pos('number=1', FactoryObject.UrlAt(0)) > 0);
    AssertTrue(Pos('number=2', FactoryObject.UrlAt(1)) > 0);
    AssertTrue(Pos('number=3', FactoryObject.UrlAt(2)) > 0);
  finally
    Coordinator.Free;
  end;
end;

procedure TTelegramNotificationCoordinatorTests.
  Queue_OverflowDropsOldestWaitingItem;
var
  Coordinator: TTelegramNotificationCoordinator;
  FactoryIntf: IHttpTransportFactory;
  FactoryObject: TControlledTransportFactory;
  Index: Integer;
begin
  FCallbackCount := 0;
  FDroppedCount := 0;
  FactoryObject := TControlledTransportFactory.Create;
  FactoryIntf := FactoryObject;
  FactoryObject.BlockFirstRequest;
  Coordinator := TTelegramNotificationCoordinator.Create(FactoryIntf);
  try
    Coordinator.OnCompleted := @Completed;
    Coordinator.OnDropped := @Dropped;
    AssertTrue(Coordinator.EnqueueResult(NotificationResult(0),
      'https://example.invalid/token', TTelegramRetryPolicy.Disabled));
    AssertTrue(FactoryObject.WaitForRequest(1000));
    for Index := 1 to 101 do
      AssertTrue(Coordinator.EnqueueResult(NotificationResult(Index),
        'https://example.invalid/token', TTelegramRetryPolicy.Disabled));
    CheckSynchronize(100);
    AssertEquals(1, FDroppedCount);
    AssertEquals(1, FLastDropped.ParticipantNumber);
    AssertEquals(100, Coordinator.PendingCount);
    FactoryObject.ReleaseFirstRequest;
    WaitForCallbacks(101);
    AssertEquals(101, FactoryObject.ExecuteCount);
    AssertTrue(Pos('number=2', FactoryObject.UrlAt(1)) > 0);
    AssertTrue(Pos('number=101', FactoryObject.UrlAt(100)) > 0);
  finally
    Coordinator.Free;
  end;
end;

procedure TTelegramNotificationCoordinatorTests.
  Shutdown_CancelsRetryDelayAndSuppressesCallbacks;
var
  Coordinator: TTelegramNotificationCoordinator;
  FactoryIntf: IHttpTransportFactory;
  FactoryObject: TControlledTransportFactory;
  StartedAt: QWord;
begin
  FCallbackCount := 0;
  FactoryObject := TControlledTransportFactory.Create;
  FactoryIntf := FactoryObject;
  FactoryObject.QueueResponse(NetworkErrorResponse);
  Coordinator := TTelegramNotificationCoordinator.Create(FactoryIntf);
  Coordinator.OnCompleted := @Completed;
  AssertTrue(Coordinator.EnqueueResult(NotificationResult(4),
    'https://example.invalid/token',
    TTelegramRetryPolicy.Create(True, 2, 1)));
  AssertTrue(FactoryObject.WaitForRequest(1000));
  StartedAt := GetTickCount64;
  Coordinator.Shutdown;
  AssertTrue('Shutdown did not cancel retry delay',
    GetTickCount64 - StartedAt < 500);
  CheckSynchronize(100);
  AssertEquals(0, FCallbackCount);
  AssertEquals(1, FactoryObject.ExecuteCount);
  Coordinator.Free;
end;

initialization
  RegisterTest(TTelegramNotificationCoordinatorTests);

end.
