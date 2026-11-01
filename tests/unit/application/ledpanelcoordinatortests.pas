unit LedPanelCoordinatorTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, HttpTransport,
  LedPanelCoordinator;

type
  TLedPanelCoordinatorTests = class(TTestCase)
  private
    FCallbackCount: integer;
    FCallbackThreadId: TThreadID;
    procedure Completed(Sender: TObject; const ADelivery: TLedPanelDeliveryResult);
    procedure WaitForCallbacks(const ACount: integer);
  published
    procedure Queue_RunsOutsideUiAndKeepsOnlyLastWaitingValue;
    procedure Shutdown_CancelsActiveAndSuppressesCallbacks;
  end;

implementation

type
  TBlockingTransportFactory = class;

  TBlockingTransport = class(TInterfacedObject, IHttpTransport)
  private
    FOwner: TBlockingTransportFactory;
  public
    constructor Create(const AOwner: TBlockingTransportFactory);
    function Execute(const ARequest: THttpRequest): THttpResponse;
    procedure Cancel;
  end;

  TBlockingTransportFactory = class(TInterfacedObject,
    IHttpTransportFactory)
  private
    FLock: TRTLCriticalSection;
    FStarted: PRTLEvent;
    FRelease: PRTLEvent;
    FUrls: array of string;
    FBodies: array of rawbytestring;
    FExecuteThreadId: TThreadID;
    FCancelCount: integer;
    function ExecuteRequest(const ARequest: THttpRequest): THttpResponse;
  public
    constructor Create;
    destructor Destroy; override;
    function CreateTransport: IHttpTransport;
    function WaitForFirst(const ATimeoutMs: cardinal): boolean;
    procedure ReleaseFirst;
    function ExecuteCount: integer;
    function BodyAt(const AIndex: integer): string;
    function ExecuteThreadId: TThreadID;
    function CancelCount: integer;
  end;

constructor TBlockingTransport.Create(const AOwner: TBlockingTransportFactory);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TBlockingTransport.Execute(const ARequest: THttpRequest): THttpResponse;
begin
  Result := FOwner.ExecuteRequest(ARequest);
end;

procedure TBlockingTransport.Cancel;
begin
  EnterCriticalSection(FOwner.FLock);
  try
    Inc(FOwner.FCancelCount);
  finally
    LeaveCriticalSection(FOwner.FLock);
  end;
  FOwner.ReleaseFirst;
end;

constructor TBlockingTransportFactory.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FStarted := RTLEventCreate;
  FRelease := RTLEventCreate;
end;

destructor TBlockingTransportFactory.Destroy;
begin
  RTLEventSetEvent(FRelease);
  RTLEventDestroy(FStarted);
  RTLEventDestroy(FRelease);
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TBlockingTransportFactory.CreateTransport: IHttpTransport;
begin
  Result := TBlockingTransport.Create(Self);
end;

function TBlockingTransportFactory.ExecuteRequest(
  const ARequest: THttpRequest): THttpResponse;
var
  Index: integer;
begin
  EnterCriticalSection(FLock);
  try
    Index := Length(FUrls);
    SetLength(FUrls, Index + 1);
    SetLength(FBodies, Index + 1);
    FUrls[Index] := ARequest.Url;
    FBodies[Index] := ARequest.Body;
    FExecuteThreadId := GetCurrentThreadID;
  finally
    LeaveCriticalSection(FLock);
  end;
  RTLEventSetEvent(FStarted);
  if Index = 0 then
    RTLEventWaitFor(FRelease);
  Result := Default(THttpResponse);
  Result.Completed := True;
  Result.StatusCode := 204;
end;

function TBlockingTransportFactory.WaitForFirst(const ATimeoutMs: cardinal): boolean;
begin
  RTLEventWaitFor(FStarted, ATimeoutMs);
  Result := ExecuteCount > 0;
end;

procedure TBlockingTransportFactory.ReleaseFirst;
begin
  RTLEventSetEvent(FRelease);
end;

function TBlockingTransportFactory.ExecuteCount: integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := Length(FUrls);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TBlockingTransportFactory.BodyAt(const AIndex: integer): string;
begin
  EnterCriticalSection(FLock);
  try
    Result := string(FBodies[AIndex]);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TBlockingTransportFactory.ExecuteThreadId: TThreadID;
begin
  EnterCriticalSection(FLock);
  try
    Result := FExecuteThreadId;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TBlockingTransportFactory.CancelCount: integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FCancelCount;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TLedPanelCoordinatorTests.Completed(Sender: TObject;
  const ADelivery: TLedPanelDeliveryResult);
begin
  Inc(FCallbackCount);
  FCallbackThreadId := GetCurrentThreadID;
end;

procedure TLedPanelCoordinatorTests.WaitForCallbacks(const ACount: integer);
var
  StartedAt: QWord;
begin
  StartedAt := GetTickCount64;
  while (FCallbackCount < ACount) and (GetTickCount64 - StartedAt < 3000) do
  begin
    CheckSynchronize(10);
    Sleep(1);
  end;
  AssertEquals(ACount, FCallbackCount);
end;

procedure TLedPanelCoordinatorTests.
Queue_RunsOutsideUiAndKeepsOnlyLastWaitingValue;
var
  Coordinator: TLedPanelCoordinator;
  Factory: IHttpTransportFactory;
  FactoryObject: TBlockingTransportFactory;
begin
  FCallbackCount := 0;
  FactoryObject := TBlockingTransportFactory.Create;
  Factory := FactoryObject;
  Coordinator := TLedPanelCoordinator.Create(Factory);
  try
    Coordinator.OnCompleted := @Completed;
    AssertTrue(Coordinator.EnqueueTest('panel.local', 'first', '', ''));
    AssertTrue(FactoryObject.WaitForFirst(1000));
    AssertTrue(Coordinator.EnqueueTest('panel.local', 'second', '', ''));
    AssertTrue(Coordinator.EnqueueTest('panel.local', 'third', '', ''));
    AssertEquals(1, Coordinator.PendingCount);
    FactoryObject.ReleaseFirst;
    WaitForCallbacks(2);

    AssertEquals(2, FactoryObject.ExecuteCount);
    AssertTrue(Pos('singleline=first', FactoryObject.BodyAt(0)) > 0);
    AssertTrue(Pos('singleline=third', FactoryObject.BodyAt(1)) > 0);
    AssertTrue(FactoryObject.ExecuteThreadId <> MainThreadID);
    AssertEquals(MainThreadID, FCallbackThreadId);
  finally
    Coordinator.Free;
  end;
end;

procedure TLedPanelCoordinatorTests.
Shutdown_CancelsActiveAndSuppressesCallbacks;
var
  Coordinator: TLedPanelCoordinator;
  Factory: IHttpTransportFactory;
  FactoryObject: TBlockingTransportFactory;
begin
  FCallbackCount := 0;
  FactoryObject := TBlockingTransportFactory.Create;
  Factory := FactoryObject;
  Coordinator := TLedPanelCoordinator.Create(Factory);
  Coordinator.OnCompleted := @Completed;
  AssertTrue(Coordinator.EnqueueTest('panel.local', 'active', '', ''));
  AssertTrue(FactoryObject.WaitForFirst(1000));
  Coordinator.Shutdown;
  CheckSynchronize(100);
  AssertEquals(1, FactoryObject.CancelCount);
  AssertEquals(0, FCallbackCount);
  Coordinator.Free;
end;

initialization
  RegisterTest(TLedPanelCoordinatorTests);

end.
