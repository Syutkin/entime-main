unit BleTimingTransport;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  LazBleBackend,
  LazBleOperation,
  LazBleClient,
  LazBleFacade,
  LazBleNus,
  TimingProtocol,
  TimingMark,
  TimingTransport;

type
  TBleTimingStateChangedEvent = procedure(Sender: TObject;
    const AState: TLazBleClientState) of object;

  TBleTimingTransport = class;

  IBleTimingDeliveryTarget = interface
    ['{65307D01-0FC7-4815-87E8-D23273CC39CD}']
    function CaptureGeneration: QWord;
    function NextGeneration: QWord;
    procedure Detach;
    procedure DeliverData(const AGeneration: QWord;
      const ADeviceId: string; const AValue: TBytes);
    procedure DeliverState(const AGeneration: QWord;
      const AState: TLazBleClientState);
  end;

  TBleTimingTransport = class(TInterfacedObject, ITimingTransport)
  private
    FBle: TLazBle;
    FClient: TBleClient;
    FProfile: TNusProfile;
    FDeliveryTarget: IBleTimingDeliveryTarget;
    FShutdownOperation: IBleOperation;
    FDeviceId: string;
    FState: TLazBleClientState;
    FShuttingDown: Boolean;
    FOnStateChanged: TBleTimingStateChangedEvent;
    FOnData: TTimingTransportDataEvent;
    function GetConnected: boolean;
    function GetKind: TTimingTransportKind;
    function GetOnData: TTimingTransportDataEvent;
    function GetSource: TTimingMarkSource;
    function GetTransportState: TTimingTransportState;
    function GetState: TLazBleClientState;
    procedure Initialize;
    procedure EnsureOwnedFacade;
    procedure ProfileDataReceived(Sender: TObject;
      const ADeviceId: string; const AValue: TBytes);
    procedure ClientStateChanged(Sender: TObject;
      const AState: TLazBleClientState);
    procedure QueueData(const ADeviceId: string; const AValue: TBytes);
    procedure QueueState(const AState: TLazBleClientState);
    procedure DeliverData(const ADeviceId: string; const AValue: TBytes);
    procedure DeliverState(const AState: TLazBleClientState);
    procedure DetachClientCallbacks;
    procedure ReleaseDisconnectedClient;
    procedure SetOnData(const AHandler: TTimingTransportDataEvent);
  public
    constructor Create; overload;
    constructor Create(const ABackend: ILazBleBackend); overload;
    destructor Destroy; override;
    procedure ConfigureClient(const AClient: TBleClient);
    procedure HandleDeviceChanged(const ADeviceId: string);
    procedure HandleStateChanged(const AState: TLazBleClientState);
    function ScanAsync(const AAdapterId: string;
      const ATimeoutMs: Cardinal): IBleScanOperation;
    function ConnectAsync(const ADeviceId: string): IBleOperation;
    function DisconnectAsync: IBleOperation;
    function SendAsync(const AData: RawByteString): ITimingSendOperation;
    function ShutdownAsync: IBleOperation;
    property DeviceId: string read FDeviceId;
    property State: TLazBleClientState read GetState;
    property OnStateChanged: TBleTimingStateChangedEvent
      read FOnStateChanged write FOnStateChanged;
    property Connected: boolean read GetConnected;
    property Kind: TTimingTransportKind read GetKind;
    property OnData: TTimingTransportDataEvent read GetOnData write SetOnData;
    property Source: TTimingMarkSource read GetSource;
    property TransportState: TTimingTransportState read GetTransportState;
  end;

implementation

uses
  AppLogger;

type
  { TBleTimingSendOperation }

  TBleTimingSendOperation = class(TInterfacedObject, ITimingSendOperation)
  private
    FBleOperation: IBleOperation;
    FOnCompleted: TTimingSendCompletedEvent;
    FSource: TTimingMarkSource;
    procedure BleCompleted(Sender: TObject);
    function GetErrorCode: integer;
    function GetErrorMessage: string;
    function GetOnCompleted: TTimingSendCompletedEvent;
    function GetSource: TTimingMarkSource;
    function GetState: TTimingSendState;
    procedure SetOnCompleted(const AHandler: TTimingSendCompletedEvent);
  public
    constructor Create(const AOperation: IBleOperation;
      const ASource: TTimingMarkSource);
    destructor Destroy; override;
  end;

  TBleTimingDeliveryTarget = class(TInterfacedObject,
    IBleTimingDeliveryTarget)
  private
    FLock: TRTLCriticalSection;
    FOwner: TBleTimingTransport;
    FGeneration: QWord;
  public
    constructor Create(const AOwner: TBleTimingTransport);
    destructor Destroy; override;
    function CaptureGeneration: QWord;
    function NextGeneration: QWord;
    procedure Detach;
    procedure DeliverData(const AGeneration: QWord;
      const ADeviceId: string; const AValue: TBytes);
    procedure DeliverState(const AGeneration: QWord;
      const AState: TLazBleClientState);
  end;

  TQueuedBleDataDelivery = class
  private
    FTarget: IBleTimingDeliveryTarget;
    FGeneration: QWord;
    FDeviceId: string;
    FValue: TBytes;
  public
    constructor Create(const ATarget: IBleTimingDeliveryTarget;
      const AGeneration: QWord; const ADeviceId: string;
      const AValue: TBytes);
    procedure Deliver;
  end;

  TQueuedBleStateDelivery = class
  private
    FTarget: IBleTimingDeliveryTarget;
    FGeneration: QWord;
    FState: TLazBleClientState;
  public
    constructor Create(const ATarget: IBleTimingDeliveryTarget;
      const AGeneration: QWord; const AState: TLazBleClientState);
    procedure Deliver;
  end;

constructor TBleTimingSendOperation.Create(const AOperation: IBleOperation;
  const ASource: TTimingMarkSource);
begin
  inherited Create;
  if not Assigned(AOperation) then
    raise EArgumentNilException.Create('AOperation');
  FBleOperation := AOperation;
  FSource := ASource;
  FBleOperation.OnCompleted := @BleCompleted;
end;

destructor TBleTimingSendOperation.Destroy;
begin
  if Assigned(FBleOperation) then
    FBleOperation.OnCompleted := nil;
  FOnCompleted := nil;
  FBleOperation := nil;
  inherited Destroy;
end;

procedure TBleTimingSendOperation.BleCompleted(Sender: TObject);
var
  Handler: TTimingSendCompletedEvent;
  KeepAlive: ITimingSendOperation;
begin
  KeepAlive := Self;
  Handler := FOnCompleted;
  if Assigned(Handler) then
    Handler(Self);
end;

function TBleTimingSendOperation.GetErrorCode: integer;
begin
  Result := FBleOperation.ErrorCode;
end;

function TBleTimingSendOperation.GetErrorMessage: string;
begin
  Result := FBleOperation.ErrorMessage;
end;

function TBleTimingSendOperation.GetOnCompleted: TTimingSendCompletedEvent;
begin
  Result := FOnCompleted;
end;

function TBleTimingSendOperation.GetSource: TTimingMarkSource;
begin
  Result := FSource;
end;

function TBleTimingSendOperation.GetState: TTimingSendState;
begin
  case FBleOperation.State of
    lbopPending: Result := tssPending;
    lbopSucceeded: Result := tssSucceeded;
  else
    Result := tssFailed;
  end;
end;

procedure TBleTimingSendOperation.SetOnCompleted(
  const AHandler: TTimingSendCompletedEvent);
begin
  FOnCompleted := AHandler;
  if Assigned(FOnCompleted) and (GetState <> tssPending) then
    FOnCompleted(Self);
end;

constructor TBleTimingDeliveryTarget.Create(const AOwner: TBleTimingTransport);
begin
  inherited Create;
  InitCriticalSection(FLock);
  FOwner := AOwner;
  FGeneration := 1;
end;

destructor TBleTimingDeliveryTarget.Destroy;
begin
  EnterCriticalSection(FLock);
  try
    FOwner := nil;
  finally
    LeaveCriticalSection(FLock);
  end;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TBleTimingDeliveryTarget.CaptureGeneration: QWord;
begin
  EnterCriticalSection(FLock);
  try
    Result := FGeneration;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TBleTimingDeliveryTarget.NextGeneration: QWord;
begin
  EnterCriticalSection(FLock);
  try
    Inc(FGeneration);
    Result := FGeneration;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TBleTimingDeliveryTarget.Detach;
begin
  EnterCriticalSection(FLock);
  try
    Inc(FGeneration);
    FOwner := nil;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TBleTimingDeliveryTarget.DeliverData(const AGeneration: QWord;
  const ADeviceId: string; const AValue: TBytes);
var
  Owner: TBleTimingTransport;
begin
  EnterCriticalSection(FLock);
  try
    if AGeneration = FGeneration then
      Owner := FOwner
    else
      Owner := nil;
  finally
    LeaveCriticalSection(FLock);
  end;
  if Assigned(Owner) then
    Owner.DeliverData(ADeviceId, AValue);
end;

procedure TBleTimingDeliveryTarget.DeliverState(const AGeneration: QWord;
  const AState: TLazBleClientState);
var
  Owner: TBleTimingTransport;
begin
  EnterCriticalSection(FLock);
  try
    if AGeneration = FGeneration then
      Owner := FOwner
    else
      Owner := nil;
  finally
    LeaveCriticalSection(FLock);
  end;
  if Assigned(Owner) then
    Owner.DeliverState(AState);
end;

constructor TQueuedBleDataDelivery.Create(
  const ATarget: IBleTimingDeliveryTarget; const AGeneration: QWord;
  const ADeviceId: string; const AValue: TBytes);
begin
  inherited Create;
  FTarget := ATarget;
  FGeneration := AGeneration;
  FDeviceId := ADeviceId;
  FValue := Copy(AValue);
end;

procedure TQueuedBleDataDelivery.Deliver;
begin
  try
    FTarget.DeliverData(FGeneration, FDeviceId, FValue);
  finally
    Free;
  end;
end;

constructor TQueuedBleStateDelivery.Create(
  const ATarget: IBleTimingDeliveryTarget; const AGeneration: QWord;
  const AState: TLazBleClientState);
begin
  inherited Create;
  FTarget := ATarget;
  FGeneration := AGeneration;
  FState := AState;
end;

procedure TQueuedBleStateDelivery.Deliver;
begin
  try
    FTarget.DeliverState(FGeneration, FState);
  finally
    Free;
  end;
end;

constructor TBleTimingTransport.Create;
begin
  inherited Create;
  Initialize;
end;

procedure TBleTimingTransport.Initialize;
begin
  FState := lbcstDisconnected;
  FDeliveryTarget := TBleTimingDeliveryTarget.Create(Self);
end;

constructor TBleTimingTransport.Create(const ABackend: ILazBleBackend);
begin
  inherited Create;
  if not Assigned(ABackend) then
    raise EArgumentNilException.Create('ABackend');
  Initialize;
  FBle := TLazBle.Create(ABackend);
end;

destructor TBleTimingTransport.Destroy;
begin
  if Assigned(FDeliveryTarget) then
    FDeliveryTarget.Detach;
  DetachClientCallbacks;
  if Assigned(FBle) then
  begin
    if not FShuttingDown then
      FShutdownOperation := FBle.ShutdownAsync;
    FBle.Free;
  end;
  FShutdownOperation := nil;
  FProfile := nil;
  FClient := nil;
  FBle := nil;
  FDeliveryTarget := nil;
  FOnStateChanged := nil;
  FOnData := nil;
  inherited Destroy;
end;

function TBleTimingTransport.GetConnected: boolean;
begin
  Result := FState = lbcstReady;
end;

function TBleTimingTransport.GetKind: TTimingTransportKind;
begin
  Result := ttkBle;
end;

function TBleTimingTransport.GetOnData: TTimingTransportDataEvent;
begin
  Result := FOnData;
end;

function TBleTimingTransport.GetSource: TTimingMarkSource;
begin
  Result := TTimingMarkSource.Ble(FDeviceId);
end;

function TBleTimingTransport.GetTransportState: TTimingTransportState;
begin
  case FState of
    lbcstConnecting, lbcstAttachingProfiles, lbcstWaitingToReconnect:
      Result := ttsConnecting;
    lbcstReady: Result := ttsConnected;
    lbcstDisconnecting: Result := ttsDisconnecting;
    lbcstError: Result := ttsError;
  else
    Result := ttsDisconnected;
  end;
end;

procedure TBleTimingTransport.SetOnData(
  const AHandler: TTimingTransportDataEvent);
begin
  FOnData := AHandler;
end;

function TBleTimingTransport.GetState: TLazBleClientState;
begin
  Result := FState;
end;

procedure TBleTimingTransport.EnsureOwnedFacade;
begin
  if not Assigned(FBle) then
    raise EInvalidOperation.Create(
      'This operation is only available to the injected-backend test harness');
end;

procedure TBleTimingTransport.ConfigureClient(const AClient: TBleClient);
var
  Profile: TNusProfile;
begin
  if not Assigned(AClient) then
    raise EArgumentNilException.Create('AClient');

  Profile := TNusProfile.Create;
  try
    Profile.OnData := @ProfileDataReceived;
    AClient.AddProfile(Profile);
    FClient := AClient;
    FProfile := Profile;
    FDeviceId := AClient.DeviceId;
    FState := AClient.State;
  except
    Profile.OnData := nil;
    Profile.Free;
    raise;
  end;
end;

procedure TBleTimingTransport.HandleDeviceChanged(const ADeviceId: string);
begin
  if SameText(FDeviceId, ADeviceId) then
    Exit;
  FDeliveryTarget.NextGeneration;
  FClient := nil;
  FProfile := nil;
  FDeviceId := ADeviceId;
  FState := lbcstDisconnected;
end;

procedure TBleTimingTransport.HandleStateChanged(
  const AState: TLazBleClientState);
begin
  DeliverState(AState);
end;

procedure TBleTimingTransport.ProfileDataReceived(Sender: TObject;
  const ADeviceId: string; const AValue: TBytes);
begin
  QueueData(ADeviceId, AValue);
end;

procedure TBleTimingTransport.ClientStateChanged(Sender: TObject;
  const AState: TLazBleClientState);
begin
  QueueState(AState);
end;

procedure TBleTimingTransport.QueueData(const ADeviceId: string;
  const AValue: TBytes);
var
  Delivery: TQueuedBleDataDelivery;
  Generation: QWord;
begin
  if not Assigned(FDeliveryTarget) then
    Exit;
  Generation := FDeliveryTarget.CaptureGeneration;
  Delivery := TQueuedBleDataDelivery.Create(FDeliveryTarget, Generation,
    ADeviceId, AValue);
  TThread.Queue(nil, @Delivery.Deliver);
end;

procedure TBleTimingTransport.QueueState(const AState: TLazBleClientState);
var
  Delivery: TQueuedBleStateDelivery;
  Generation: QWord;
begin
  if not Assigned(FDeliveryTarget) then
    Exit;
  Generation := FDeliveryTarget.CaptureGeneration;
  Delivery := TQueuedBleStateDelivery.Create(FDeliveryTarget, Generation,
    AState);
  TThread.Queue(nil, @Delivery.Deliver);
end;

procedure TBleTimingTransport.DeliverData(const ADeviceId: string;
  const AValue: TBytes);
var
  Chunk: RawByteString;
  Handler: TTimingTransportDataEvent;
begin
  if FShuttingDown or (ADeviceId <> FDeviceId) or
    (Length(AValue) = 0) then
    Exit;
  Chunk := '';
  SetLength(Chunk, Length(AValue));
  Move(AValue[0], Chunk[1], Length(AValue));
  AppLog(Format(
    'BLE NUS notification received bytes=%d payload=%s',
    [Length(AValue), TimingPacketLogValue(string(Chunk))]), allTrace,
    alvNone, alsBle);
  Handler := FOnData;
  if Assigned(Handler) then
    Handler(Self, Chunk, GetSource);
end;

procedure TBleTimingTransport.DeliverState(const AState: TLazBleClientState);
var
  Handler: TBleTimingStateChangedEvent;
begin
  if FShuttingDown then
    Exit;
  FState := AState;
  Handler := FOnStateChanged;
  if Assigned(Handler) then
    Handler(Self, AState);
end;

procedure TBleTimingTransport.DetachClientCallbacks;
begin
  if Assigned(FProfile) then
    FProfile.OnData := nil;
  if Assigned(FBle) and Assigned(FClient) then
    FClient.OnStateChanged := nil;
end;

procedure TBleTimingTransport.ReleaseDisconnectedClient;
begin
  if not Assigned(FClient) then
    Exit;
  if FClient.State <> lbcstDisconnected then
    raise EInvalidOperation.Create(
      'The current BLE timing device must be disconnected first');
  DetachClientCallbacks;
  FProfile := nil;
  FBle.RemoveClient(FClient);
  FClient := nil;
  FDeviceId := '';
  FState := lbcstDisconnected;
end;

function TBleTimingTransport.ScanAsync(const AAdapterId: string;
  const ATimeoutMs: Cardinal): IBleScanOperation;
begin
  EnsureOwnedFacade;
  if FShuttingDown then
    raise EInvalidOperation.Create('BLE timing input is shutting down');
  Result := FBle.ScanAsync(AAdapterId, ATimeoutMs);
end;

function TBleTimingTransport.ConnectAsync(const ADeviceId: string): IBleOperation;
var
  Client: TBleClient;
begin
  EnsureOwnedFacade;
  if FShuttingDown then
    raise EInvalidOperation.Create('BLE timing input is shutting down');
  if Trim(ADeviceId) = '' then
    raise EArgumentException.Create('ADeviceId must not be empty');

  if Assigned(FClient) and not SameText(FDeviceId, ADeviceId) then
    ReleaseDisconnectedClient;
  FDeliveryTarget.NextGeneration;

  if not Assigned(FClient) then
  begin
    Client := FBle.CreateClient(ADeviceId);
    try
      HandleDeviceChanged(ADeviceId);
      Client.OnStateChanged := @ClientStateChanged;
      ConfigureClient(Client);
    except
      Client.OnStateChanged := nil;
      FProfile := nil;
      FBle.RemoveClient(Client);
      FClient := nil;
      FDeviceId := '';
      raise;
    end;
  end;
  Result := FClient.ConnectAsync;
end;

function TBleTimingTransport.DisconnectAsync: IBleOperation;
begin
  EnsureOwnedFacade;
  if FShuttingDown then
    raise EInvalidOperation.Create('BLE timing input is shutting down');
  if not Assigned(FClient) then
    raise EInvalidOperation.Create('BLE timing device is not selected');
  Result := FClient.DisconnectAsync;
end;

function TBleTimingTransport.SendAsync(
  const AData: RawByteString): ITimingSendOperation;
var
  BleOperation: IBleOperation;
  Bytes: TBytes;
  Index: integer;
  TransportSource: TTimingMarkSource;
begin
  TransportSource := GetSource;
  if not GetConnected or not Assigned(FProfile) then
    Exit(TTimingSendOperation.Failed(TransportSource,
      'BLE timing transport is not connected'));
  Bytes := nil;
  SetLength(Bytes, Length(AData));
  for Index := 1 to Length(AData) do
    Bytes[Index - 1] := Byte(AData[Index]);
  BleOperation := FProfile.SendAsync(Bytes);
  Result := TBleTimingSendOperation.Create(BleOperation, TransportSource);
end;

function TBleTimingTransport.ShutdownAsync: IBleOperation;
begin
  EnsureOwnedFacade;
  if Assigned(FShutdownOperation) then
    Exit(FShutdownOperation);
  FShuttingDown := True;
  FDeliveryTarget.NextGeneration;
  DetachClientCallbacks;
  FShutdownOperation := FBle.ShutdownAsync;
  Result := FShutdownOperation;
end;

end.
