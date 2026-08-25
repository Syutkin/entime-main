unit LedPanelCoordinator;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, HttpTransport, CompetitionFinishService,
  LedPanelClient;

type
  TLedPanelDeliveryResult = record
    IsTest: Boolean;
    Outcome: TFinishNotificationOutcome;
  end;

  TLedPanelCompletedEvent = procedure(Sender: TObject;
    const ADelivery: TLedPanelDeliveryResult) of object;

  TLedPanelCoordinator = class;

  TLedPanelWorker = class(TThread)
  private
    FOwner: TLedPanelCoordinator;
  protected
    procedure Execute; override;
  public
    constructor Create(const AOwner: TLedPanelCoordinator);
  end;

  TLedPanelCoordinator = class
  private type
    TQueueItem = record
      IsTest: Boolean;
      Request: THttpRequest;
    end;
    TDeliveryArray = array of TLedPanelDeliveryResult;
  private
    FFactory: IHttpTransportFactory;
    FLock: TRTLCriticalSection;
    FWorkEvent: PRTLEvent;
    FWorker: TLedPanelWorker;
    FPending: TQueueItem;
    FHasPending: Boolean;
    FClosing: Boolean;
    FActiveTransport: IHttpTransport;
    FDeliveries: TDeliveryArray;
    FOnCompleted: TLedPanelCompletedEvent;
    function EnqueueRequest(const ARequest: THttpRequest;
      const AIsTest: Boolean): Boolean;
    function TakePending(out AItem: TQueueItem): Boolean;
    function IsClosing: Boolean;
    procedure ExecuteItem(const AItem: TQueueItem);
    procedure QueueDelivery(const ADelivery: TLedPanelDeliveryResult);
    procedure DeliverNext;
    function GetPendingCount: Integer;
  public
    constructor Create(const AFactory: IHttpTransportFactory);
    destructor Destroy; override;
    function EnqueueFinish(const AResult: TFinishResult;
      const AAddress: string): Boolean;
    function EnqueueTest(const AAddress, ASingleLine, AUpperLine,
      ABottomLine: string): Boolean;
    procedure Shutdown;
    property PendingCount: Integer read GetPendingCount;
    property OnCompleted: TLedPanelCompletedEvent read FOnCompleted
      write FOnCompleted;
  end;

implementation

constructor TLedPanelWorker.Create(const AOwner: TLedPanelCoordinator);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

procedure TLedPanelWorker.Execute;
var
  Item: TLedPanelCoordinator.TQueueItem;
begin
  while not Terminated do
  begin
    if FOwner.TakePending(Item) then
      FOwner.ExecuteItem(Item)
    else
    begin
      if FOwner.IsClosing then
        Exit;
      RTLEventWaitFor(FOwner.FWorkEvent);
    end;
  end;
end;

constructor TLedPanelCoordinator.Create(
  const AFactory: IHttpTransportFactory);
begin
  inherited Create;
  if not Assigned(AFactory) then
    raise EArgumentNilException.Create('AFactory');
  FFactory := AFactory;
  InitCriticalSection(FLock);
  FWorkEvent := RTLEventCreate;
  FWorker := TLedPanelWorker.Create(Self);
  try
    FWorker.Start;
  except
    FreeAndNil(FWorker);
    RTLEventDestroy(FWorkEvent);
    DoneCriticalSection(FLock);
    raise;
  end;
end;

destructor TLedPanelCoordinator.Destroy;
begin
  Shutdown;
  FreeAndNil(FWorker);
  RTLEventDestroy(FWorkEvent);
  DoneCriticalSection(FLock);
  FFactory := nil;
  inherited Destroy;
end;

function TLedPanelCoordinator.EnqueueFinish(const AResult: TFinishResult;
  const AAddress: string): Boolean;
var
  Request: THttpRequest;
begin
  Result := TLedPanelClient.TryBuildFinishRequest(AResult, AAddress,
    Request) and EnqueueRequest(Request, False);
end;

function TLedPanelCoordinator.EnqueueTest(const AAddress, ASingleLine,
  AUpperLine, ABottomLine: string): Boolean;
var
  Request: THttpRequest;
begin
  Result := TLedPanelClient.TryBuildTestRequest(AAddress, ASingleLine,
    AUpperLine, ABottomLine, Request) and EnqueueRequest(Request, True);
end;

function TLedPanelCoordinator.EnqueueRequest(const ARequest: THttpRequest;
  const AIsTest: Boolean): Boolean;
begin
  Result := False;
  EnterCriticalSection(FLock);
  try
    if FClosing then
      Exit;
    FPending := Default(TQueueItem);
    FPending.Request := CloneHttpRequest(ARequest);
    FPending.IsTest := AIsTest;
    FHasPending := True;
    RTLEventSetEvent(FWorkEvent);
    Result := True;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TLedPanelCoordinator.TakePending(out AItem: TQueueItem): Boolean;
begin
  Result := False;
  AItem := Default(TQueueItem);
  EnterCriticalSection(FLock);
  try
    if FClosing or not FHasPending then
    begin
      RTLEventResetEvent(FWorkEvent);
      Exit;
    end;
    AItem := FPending;
    FPending := Default(TQueueItem);
    FHasPending := False;
    RTLEventResetEvent(FWorkEvent);
    Result := True;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TLedPanelCoordinator.IsClosing: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := FClosing;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TLedPanelCoordinator.ExecuteItem(const AItem: TQueueItem);
var
  Delivery: TLedPanelDeliveryResult;
  Transport: IHttpTransport;
begin
  if IsClosing then
    Exit;
  Transport := FFactory.CreateTransport;
  EnterCriticalSection(FLock);
  try
    if FClosing then
      Exit;
    FActiveTransport := Transport;
  finally
    LeaveCriticalSection(FLock);
  end;
  try
    Delivery := Default(TLedPanelDeliveryResult);
    Delivery.IsTest := AItem.IsTest;
    Delivery.Outcome := TLedPanelClient.Send(AItem.Request, Transport);
  finally
    EnterCriticalSection(FLock);
    try
      FActiveTransport := nil;
    finally
      LeaveCriticalSection(FLock);
    end;
    Transport := nil;
  end;
  if not IsClosing then
    QueueDelivery(Delivery);
end;

procedure TLedPanelCoordinator.QueueDelivery(
  const ADelivery: TLedPanelDeliveryResult);
begin
  EnterCriticalSection(FLock);
  try
    if FClosing then
      Exit;
    SetLength(FDeliveries, Length(FDeliveries) + 1);
    FDeliveries[High(FDeliveries)] := ADelivery;
  finally
    LeaveCriticalSection(FLock);
  end;
  TThread.ForceQueue(FWorker, @DeliverNext);
end;

procedure TLedPanelCoordinator.DeliverNext;
var
  Delivery: TLedPanelDeliveryResult;
  Index: Integer;
begin
  Delivery := Default(TLedPanelDeliveryResult);
  EnterCriticalSection(FLock);
  try
    if FClosing or (Length(FDeliveries) = 0) then
      Exit;
    Delivery := FDeliveries[0];
    for Index := 1 to High(FDeliveries) do
      FDeliveries[Index - 1] := FDeliveries[Index];
    SetLength(FDeliveries, Length(FDeliveries) - 1);
  finally
    LeaveCriticalSection(FLock);
  end;
  if Assigned(FOnCompleted) then
    FOnCompleted(Self, Delivery);
end;

function TLedPanelCoordinator.GetPendingCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := Ord(FHasPending);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TLedPanelCoordinator.Shutdown;
var
  ActiveTransport: IHttpTransport;
begin
  if not Assigned(FWorker) then
    Exit;
  EnterCriticalSection(FLock);
  try
    FClosing := True;
    FHasPending := False;
    FPending := Default(TQueueItem);
    FOnCompleted := nil;
    ActiveTransport := FActiveTransport;
  finally
    LeaveCriticalSection(FLock);
  end;
  FWorker.Terminate;
  RTLEventSetEvent(FWorkEvent);
  if Assigned(ActiveTransport) then
    ActiveTransport.Cancel;
  TThread.RemoveQueuedEvents(FWorker, @DeliverNext);
  FWorker.WaitFor;
  TThread.RemoveQueuedEvents(FWorker, @DeliverNext);
  EnterCriticalSection(FLock);
  try
    FActiveTransport := nil;
    FDeliveries := nil;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

end.
