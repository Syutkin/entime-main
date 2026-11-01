unit BleTimingTransport;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  LazBleTypes,
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

  TBleTimingTransport = class(TInterfacedObject, ITimingTransport)
  private
    FBle: TLazBle;
    FClient: TBleClient;
    FProfile: TNusProfile;
    FShutdownOperation: IBleOperation;
    FDeviceId: string;
    FState: TLazBleClientState;
    FShuttingDown: boolean;
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
    procedure ProfileDataReceived(Sender: TObject; const ADeviceId: string;
      const AValue: TBytes);
    procedure ClientStateChanged(Sender: TObject; const AState: TLazBleClientState);
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
    { The client and its profiles remain owned by LazBle. }
    procedure ReleaseClient;
    procedure Detach;
    procedure HandleDeviceChanged(const ADeviceId: string);
    procedure HandleStateChanged(const AState: TLazBleClientState);
    function ScanAsync(const AAdapterId: string;
      const ATimeoutMs: cardinal): IBleScanOperation;
    function ConnectAsync(const ADeviceId: string): IBleOperation;
    function DisconnectAsync: IBleOperation;
    function SendAsync(const AData: rawbytestring): ITimingSendOperation;
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

constructor TBleTimingTransport.Create;
begin
  inherited Create;
  Initialize;
end;

procedure TBleTimingTransport.Initialize;
begin
  FState := lbcstDisconnected;
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
  Detach;
  if Assigned(FBle) then
  begin
    { This facade exists only for an injected backend. Normal GUI ownership is
      external and is shut down asynchronously before releasing the transport. }
    ShutdownAsync;
    while FShutdownOperation.State = lbopPending do
      CheckSynchronize(10);
    ReleaseClient;
    FBle.Free;
  end
  else
    ReleaseClient;
  FShutdownOperation := nil;
  FProfile := nil;
  FClient := nil;
  FBle := nil;
  FOnStateChanged := nil;
  FOnData := nil;
  inherited Destroy;
end;

function TBleTimingTransport.GetConnected: boolean;
begin
  Result := not FShuttingDown and (FState = lbcstReady);
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

procedure TBleTimingTransport.SetOnData(const AHandler: TTimingTransportDataEvent);
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
  LazBleRequireMainThread;
  if not Assigned(AClient) then
    raise EArgumentNilException.Create('AClient');
  if FShuttingDown then
    raise EInvalidOperation.Create('BLE timing input is shutting down');
  if FClient = AClient then Exit;
  if Assigned(FClient) then
    raise EInvalidOperation.Create('ReleaseClient must precede client replacement');

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
  if Assigned(FClient) then
    raise EInvalidOperation.Create('ReleaseClient must precede a device change');
  FProfile := nil;
  FDeviceId := ADeviceId;
  FState := lbcstDisconnected;
end;

procedure TBleTimingTransport.HandleStateChanged(const AState: TLazBleClientState);
begin
  DeliverState(AState);
end;

procedure TBleTimingTransport.ProfileDataReceived(Sender: TObject;
  const ADeviceId: string; const AValue: TBytes);
begin
  if Sender <> FProfile then Exit;
  DeliverData(ADeviceId, AValue);
end;

procedure TBleTimingTransport.ClientStateChanged(Sender: TObject;
  const AState: TLazBleClientState);
begin
  if Sender <> FClient then Exit;
  DeliverState(AState);
end;

procedure TBleTimingTransport.DeliverData(const ADeviceId: string;
  const AValue: TBytes);
var
  Chunk: rawbytestring;
  Handler: TTimingTransportDataEvent;
begin
  LazBleRequireMainThread;
  if FShuttingDown or (ADeviceId <> FDeviceId) or (Length(AValue) = 0) then
    Exit;
  Chunk := '';
  SetLength(Chunk, Length(AValue));
  Move(AValue[0], Chunk[1], Length(AValue));
  AppLog(Format('BLE NUS notification received bytes=%d payload=%s',
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
  LazBleRequireMainThread;
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

procedure TBleTimingTransport.ReleaseClient;
begin
  LazBleRequireMainThread;
  DetachClientCallbacks;
  FProfile := nil;
  FClient := nil;
  FState := lbcstDisconnected;
end;

procedure TBleTimingTransport.Detach;
begin
  LazBleRequireMainThread;
  FShuttingDown := True;
  DetachClientCallbacks;
  FOnData := nil;
  FOnStateChanged := nil;
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
  const ATimeoutMs: cardinal): IBleScanOperation;
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

function TBleTimingTransport.SendAsync(const AData: rawbytestring):
ITimingSendOperation;
var
  BleOperation: IBleOperation;
  Bytes: TBytes;
  Index: integer;
  TransportSource: TTimingMarkSource;
begin
  TransportSource := GetSource;
  if not GetConnected or not Assigned(FProfile) or not FProfile.Ready then
    Exit(TTimingSendOperation.Failed(TransportSource,
      'BLE timing transport is not connected'));
  Bytes := nil;
  SetLength(Bytes, Length(AData));
  for Index := 1 to Length(AData) do
    Bytes[Index - 1] := byte(AData[Index]);
  BleOperation := FProfile.SendAsync(Bytes);
  Result := TBleTimingSendOperation.Create(BleOperation, TransportSource);
end;

function TBleTimingTransport.ShutdownAsync: IBleOperation;
begin
  EnsureOwnedFacade;
  if Assigned(FShutdownOperation) then
    Exit(FShutdownOperation);
  Detach;
  FShutdownOperation := FBle.ShutdownAsync;
  Result := FShutdownOperation;
end;

end.
