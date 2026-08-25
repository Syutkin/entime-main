unit BleTimingTransportTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  FPCUnit,
  TestRegistry,
  LazBleTypes,
  LazBleBackend,
  LazBleOperation,
  LazBleClient,
  LazBleFacade,
  LazBleNus,
  TimingProtocol,
  TimingMark,
  TimingTransport,
  TransportStreamProcessor,
  BleTimingTransport,
  FakeLazBleBackend;

type
  TBleTimingTransportTests = class;

  TNotificationThread = class(TThread)
  private
    FBackend: TFakeLazBleBackend;
    FCompletedEvent: PRTLEvent;
    FEvent: TLazBleBackendEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(const ABackend: TFakeLazBleBackend;
      const AEvent: TLazBleBackendEvent);
    destructor Destroy; override;
    procedure WaitForEmission;
  end;

  TBleTimingTransportTests = class(TTestCase)
  private
    FBackend: ILazBleBackend;
    FBackendObject: TFakeLazBleBackend;
    FInput: TBleTimingTransport;
    FInputProcessor: TTransportStreamProcessor;
    FSerialProcessor: TTransportStreamProcessor;
    FPackets: array of TTimingPacket;
    FSources: array of TTimingMarkSource;
    FRejectedCount: Integer;
    FLastCallbackThreadId: TThreadID;
    FSubscriptionId: TBleSubscriptionId;
    procedure PacketReceived(Sender: TObject; const APacket: TTimingPacket;
      const ASource: TTimingMarkSource);
    procedure DataReceived(Sender: TObject; const AData: RawByteString;
      const ASource: TTimingMarkSource);
    procedure SerialPacketReceived(Sender: TObject;
      const APacket: TTimingPacket; const ASource: TTimingMarkSource);
    procedure PacketRejected(Sender: TObject;
      const ARejected: TTransportStreamRejected);
    procedure ConnectInput;
    procedure CompleteConnection(const ASubscriptionId: TBleSubscriptionId);
    function NotificationEvent(const AValue: RawByteString):
      TLazBleBackendEvent;
    procedure EmitNotification(const AValue: RawByteString);
    procedure DisconnectInput;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure NotificationsAreDecodedAndTaggedWithDevice;
    procedure SerialAndBleUseIndependentDecoders;
    procedure BleDisconnectDoesNotResetSerialDecoder;
    procedure RejectedPacketDoesNotBlockFollowingPacket;
    procedure DisconnectDropsIncompletePacket;
    procedure BackgroundNotificationIsDeliveredOnMainThread;
    procedure QueuedNotificationIsIgnoredAfterDestroy;
    procedure ExternalClientRemainsOwnedByItsFacade;
    procedure RecreatedExternalClientReceivesNusProfile;
    procedure ChangingDeviceReconfiguresProfileAndSource;
    procedure SendAsync_WritesToNusRx;
    procedure SendAsync_WhenDisconnectedReturnsFailure;
  end;

implementation

type
  TBleClientAccess = class(TBleClient);

constructor TNotificationThread.Create(const ABackend: TFakeLazBleBackend;
  const AEvent: TLazBleBackendEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FBackend := ABackend;
  FCompletedEvent := RTLEventCreate;
  FEvent := AEvent;
  FEvent.Value := Copy(AEvent.Value);
end;

procedure TNotificationThread.Execute;
begin
  try
    FBackend.EmitProgress(FEvent);
  finally
    RTLEventSetEvent(FCompletedEvent);
  end;
end;

destructor TNotificationThread.Destroy;
begin
  WaitFor;
  RTLEventDestroy(FCompletedEvent);
  inherited Destroy;
end;

procedure TNotificationThread.WaitForEmission;
begin
  RTLEventWaitFor(FCompletedEvent);
end;

procedure TBleTimingTransportTests.SetUp;
begin
  inherited SetUp;
  FBackendObject := TFakeLazBleBackend.Create;
  FBackend := FBackendObject;
  FInput := TBleTimingTransport.Create(FBackend);
  FInputProcessor := TTransportStreamProcessor.Create;
  FInputProcessor.OnTimingPacket := @PacketReceived;
  FInputProcessor.OnRejected := @PacketRejected;
  FInput.OnData := @DataReceived;
  FSerialProcessor := TTransportStreamProcessor.Create;
  FSerialProcessor.OnTimingPacket := @SerialPacketReceived;
  FSubscriptionId := 41;
  ConnectInput;
end;

procedure TBleTimingTransportTests.TearDown;
begin
  FSerialProcessor.Free;
  FSerialProcessor := nil;
  FInputProcessor.Free;
  FInputProcessor := nil;
  FInput.Free;
  FInput := nil;
  FBackend := nil;
  FBackendObject := nil;
  inherited TearDown;
end;

procedure TBleTimingTransportTests.SerialPacketReceived(Sender: TObject;
  const APacket: TTimingPacket; const ASource: TTimingMarkSource);
var
  Index: Integer;
begin
  AssertSame(FSerialProcessor, Sender);
  Index := Length(FPackets);
  SetLength(FPackets, Index + 1);
  SetLength(FSources, Index + 1);
  FPackets[Index] := APacket;
  FSources[Index] := ASource;
end;

procedure TBleTimingTransportTests.PacketReceived(Sender: TObject;
  const APacket: TTimingPacket; const ASource: TTimingMarkSource);
var
  Index: Integer;
begin
  AssertSame(FInputProcessor, Sender);
  Index := Length(FPackets);
  SetLength(FPackets, Index + 1);
  SetLength(FSources, Index + 1);
  FPackets[Index] := APacket;
  FSources[Index] := ASource;
  FLastCallbackThreadId := GetCurrentThreadId;
end;

procedure TBleTimingTransportTests.DataReceived(Sender: TObject;
  const AData: RawByteString; const ASource: TTimingMarkSource);
begin
  AssertSame(FInput, Sender);
  FInputProcessor.Feed(AData, ASource, Now);
end;

procedure TBleTimingTransportTests.PacketRejected(Sender: TObject;
  const ARejected: TTransportStreamRejected);
begin
  AssertSame(FInputProcessor, Sender);
  AssertTrue(ARejected.RawText <> '');
  AssertEquals(Ord(tmskBle), Ord(ARejected.Source.Kind));
  Inc(FRejectedCount);
  FLastCallbackThreadId := GetCurrentThreadId;
end;

procedure TBleTimingTransportTests.ConnectInput;
begin
  FInput.ConnectAsync('ENTime-1');
  CompleteConnection(FSubscriptionId);
  AssertEquals(Ord(lbcstReady), Ord(FInput.State));
end;

procedure TBleTimingTransportTests.CompleteConnection(
  const ASubscriptionId: TBleSubscriptionId);
var
  BackendEvent: TLazBleBackendEvent;
  Command: TLazBleBackendCommand;
  OperationId: TBleOperationId;
begin
  Command := FBackendObject.Commands[FBackendObject.CommandCount - 1];
  OperationId := FBackendObject.OperationIds[
    FBackendObject.CommandCount - 1];
  AssertEquals(Ord(lbckConnect), Ord(Command.Kind));

  BackendEvent := Default(TLazBleBackendEvent);
  BackendEvent.Kind := lbekConnected;
  BackendEvent.OperationId := OperationId;
  BackendEvent.DeviceId := Command.DeviceId;
  BackendEvent.Generation := Command.Generation;
  AssertTrue(FBackendObject.EmitProgress(BackendEvent));

  Command := FBackendObject.Commands[FBackendObject.CommandCount - 1];
  OperationId := FBackendObject.OperationIds[
    FBackendObject.CommandCount - 1];
  AssertEquals(Ord(lbckDiscoverServices), Ord(Command.Kind));
  BackendEvent := Default(TLazBleBackendEvent);
  BackendEvent.Kind := lbekServicesDiscovered;
  BackendEvent.OperationId := OperationId;
  BackendEvent.DeviceId := Command.DeviceId;
  BackendEvent.Generation := Command.Generation;
  SetLength(BackendEvent.Services, 1);
  BackendEvent.Services[0].Uuid := NusServiceUuid;
  SetLength(BackendEvent.Services[0].Characteristics, 2);
  BackendEvent.Services[0].Characteristics[0].Uuid :=
    NusRxCharacteristicUuid;
  BackendEvent.Services[0].Characteristics[0].Properties :=
    [lbgcpWriteCommand];
  BackendEvent.Services[0].Characteristics[1].Uuid :=
    NusTxCharacteristicUuid;
  BackendEvent.Services[0].Characteristics[1].Properties := [lbgcpNotify];
  AssertTrue(FBackendObject.EmitProgress(BackendEvent));

  Command := FBackendObject.Commands[FBackendObject.CommandCount - 1];
  OperationId := FBackendObject.OperationIds[
    FBackendObject.CommandCount - 1];
  AssertEquals(Ord(lbckSubscribe), Ord(Command.Kind));
  BackendEvent := Default(TLazBleBackendEvent);
  BackendEvent.Kind := lbekSubscribed;
  BackendEvent.OperationId := OperationId;
  BackendEvent.SubscriptionId := ASubscriptionId;
  BackendEvent.DeviceId := Command.DeviceId;
  BackendEvent.Generation := Command.Generation;
  AssertTrue(FBackendObject.EmitProgress(BackendEvent));
  AssertTrue(FBackendObject.CompleteOperation(OperationId,
    lbekOperationSucceeded));
end;

function TBleTimingTransportTests.NotificationEvent(
  const AValue: RawByteString): TLazBleBackendEvent;
var
  Index: Integer;
begin
  Result := Default(TLazBleBackendEvent);
  Result.Kind := lbekNotification;
  Result.OperationId := InvalidBleOperationId;
  Result.SubscriptionId := FSubscriptionId;
  Result.DeviceId := FInput.DeviceId;
  Result.Generation := FBackendObject.Commands[
    FBackendObject.CommandCount - 1].Generation;
  SetLength(Result.Value, Length(AValue));
  for Index := 1 to Length(AValue) do
    Result.Value[Index - 1] := Byte(AValue[Index]);
end;

procedure TBleTimingTransportTests.EmitNotification(const AValue: RawByteString);
var
  BackendEvent: TLazBleBackendEvent;
begin
  BackendEvent := NotificationEvent(AValue);
  AssertTrue(FBackendObject.EmitProgress(BackendEvent));
end;

procedure TBleTimingTransportTests.DisconnectInput;
var
  BackendEvent: TLazBleBackendEvent;
  Command: TLazBleBackendCommand;
  OperationId: TBleOperationId;
begin
  FInput.DisconnectAsync;
  Command := FBackendObject.Commands[FBackendObject.CommandCount - 1];
  OperationId := FBackendObject.OperationIds[
    FBackendObject.CommandCount - 1];
  AssertEquals(Ord(lbckDisconnect), Ord(Command.Kind));
  BackendEvent := Default(TLazBleBackendEvent);
  BackendEvent.Kind := lbekDisconnected;
  BackendEvent.OperationId := OperationId;
  BackendEvent.DeviceId := Command.DeviceId;
  BackendEvent.Generation := Command.Generation;
  AssertTrue(FBackendObject.EmitProgress(BackendEvent));
  AssertTrue(FBackendObject.CompleteOperation(OperationId,
    lbekOperationSucceeded));
  AssertEquals(Ord(lbcstDisconnected), Ord(FInput.State));
  FInputProcessor.Reset;
end;

procedure TBleTimingTransportTests.NotificationsAreDecodedAndTaggedWithDevice;
begin
  EmitNotification('$01:02');
  EmitNotification(':03,004;5#F02:03:04,005#');

  AssertEquals(2, Length(FPackets));
  AssertEquals(Ord(tpkStart), Ord(FPackets[0].Kind));
  AssertEquals('$01:02:03,004;5#', FPackets[0].RawText);
  AssertEquals(Ord(tpkFinish), Ord(FPackets[1].Kind));
  AssertEquals('F02:03:04,005#', FPackets[1].RawText);
  AssertEquals(Ord(tmskBle), Ord(FSources[0].Kind));
  AssertEquals('ENTime-1', FSources[0].DeviceId);
  AssertEquals('ENTime-1', FSources[1].DeviceId);
end;

procedure TBleTimingTransportTests.SerialAndBleUseIndependentDecoders;
begin
  FSerialProcessor.Feed('$01:02', TTimingMarkSource.Serial('COM1'), Now);
  EmitNotification('F03:04');

  AssertEquals(0, Length(FPackets));

  FSerialProcessor.Feed(':03,004;5#',
    TTimingMarkSource.Serial('COM1'), Now);
  EmitNotification(':05,006#');

  AssertEquals(2, Length(FPackets));
  AssertEquals('$01:02:03,004;5#', FPackets[0].RawText);
  AssertEquals(Ord(tmskSerial), Ord(FSources[0].Kind));
  AssertEquals('COM1', FSources[0].DeviceId);
  AssertEquals('F03:04:05,006#', FPackets[1].RawText);
  AssertEquals(Ord(tmskBle), Ord(FSources[1].Kind));
  AssertEquals('ENTime-1', FSources[1].DeviceId);
end;

procedure TBleTimingTransportTests.BleDisconnectDoesNotResetSerialDecoder;
begin
  FSerialProcessor.Feed('$05:06', TTimingMarkSource.Serial('COM1'), Now);
  EmitNotification('F03:04');

  DisconnectInput;
  FSerialProcessor.Feed(':07,008#',
    TTimingMarkSource.Serial('COM1'), Now);

  AssertEquals(1, Length(FPackets));
  AssertEquals('$05:06:07,008#', FPackets[0].RawText);
  AssertEquals(Ord(tmskSerial), Ord(FSources[0].Kind));
  AssertEquals('COM1', FSources[0].DeviceId);
end;

procedure TBleTimingTransportTests.RejectedPacketDoesNotBlockFollowingPacket;
begin
  EmitNotification('$invalid#F12:34:56,789#');

  AssertEquals(1, FRejectedCount);
  AssertEquals(1, Length(FPackets));
  AssertEquals(Ord(tpkFinish), Ord(FPackets[0].Kind));
end;

procedure TBleTimingTransportTests.DisconnectDropsIncompletePacket;
begin
  EmitNotification('$01:02');
  DisconnectInput;

  Inc(FSubscriptionId);
  FInput.ConnectAsync('ENTime-1');
  CompleteConnection(FSubscriptionId);
  EmitNotification(':03#F03:04:05#');

  AssertEquals(1, Length(FPackets));
  AssertEquals(Ord(tpkFinish), Ord(FPackets[0].Kind));
  AssertEquals('F03:04:05#', FPackets[0].RawText);
end;

procedure TBleTimingTransportTests.BackgroundNotificationIsDeliveredOnMainThread;
var
  NotificationThread: TNotificationThread;
begin
  NotificationThread := TNotificationThread.Create(FBackendObject,
    NotificationEvent('F12:34:56#'));
  try
    NotificationThread.Start;
    NotificationThread.WaitForEmission;
    AssertEquals(0, Length(FPackets));
    CheckSynchronize;
    AssertEquals(1, Length(FPackets));
    AssertEquals(MainThreadID, FLastCallbackThreadId);
  finally
    NotificationThread.Free;
  end;
end;

procedure TBleTimingTransportTests.QueuedNotificationIsIgnoredAfterDestroy;
var
  NotificationThread: TNotificationThread;
begin
  NotificationThread := TNotificationThread.Create(FBackendObject,
    NotificationEvent('F12:34:56#'));
  try
    NotificationThread.Start;
    NotificationThread.WaitForEmission;
    FInput.Free;
    FInput := nil;
    CheckSynchronize;

    AssertEquals(0, Length(FPackets));
  finally
    NotificationThread.Free;
  end;
end;

procedure TBleTimingTransportTests.ExternalClientRemainsOwnedByItsFacade;
var
  Adapter: TBleTimingTransport;
  Backend: ILazBleBackend;
  BackendObject: TFakeLazBleBackend;
  Ble: TLazBle;
  Client: TBleClient;
begin
  BackendObject := TFakeLazBleBackend.Create;
  Backend := BackendObject;
  Ble := TLazBle.Create(Backend);
  Adapter := nil;
  try
    Client := Ble.CreateClient('external-device');
    Adapter := TBleTimingTransport.Create;
    Adapter.HandleDeviceChanged(Client.DeviceId);
    Adapter.ConfigureClient(Client);

    Adapter.Free;
    Adapter := nil;

    AssertSame(Client, Ble.FindClient('external-device'));
    AssertEquals(0, BackendObject.CommandCount);
  finally
    Adapter.Free;
    Ble.Free;
    Backend := nil;
  end;
end;

procedure TBleTimingTransportTests.RecreatedExternalClientReceivesNusProfile;
var
  Adapter: TBleTimingTransport;
  Backend: ILazBleBackend;
  BackendObject: TFakeLazBleBackend;
  Ble: TLazBle;
  Client: TBleClient;
begin
  BackendObject := TFakeLazBleBackend.Create;
  Backend := BackendObject;
  Ble := TLazBle.Create(Backend);
  Adapter := TBleTimingTransport.Create;
  try
    Client := Ble.CreateClient('external-device');
    Adapter.ConfigureClient(Client);
    AssertEquals(1, TBleClientAccess(Client).ProfileCount);

    Ble.RemoveClient(Client);
    Client := Ble.CreateClient('external-device');
    Adapter.ConfigureClient(Client);

    AssertEquals('A recreated client must receive a new NUS profile',
      1, TBleClientAccess(Client).ProfileCount);
  finally
    Adapter.Free;
    Ble.Free;
    Backend := nil;
  end;
end;

procedure TBleTimingTransportTests.ChangingDeviceReconfiguresProfileAndSource;
begin
  DisconnectInput;

  Inc(FSubscriptionId);
  FInput.ConnectAsync('ENTime-2');
  CompleteConnection(FSubscriptionId);
  EmitNotification('F12:34:56#');

  AssertEquals(1, Length(FPackets));
  AssertEquals('ENTime-2', FSources[0].DeviceId);
end;

procedure TBleTimingTransportTests.SendAsync_WritesToNusRx;
var
  Command: TLazBleBackendCommand;
  Operation: ITimingSendOperation;
begin
  AssertEquals(Ord(ttkBle), Ord(FInput.Kind));
  AssertEquals(Ord(ttsConnected), Ord(FInput.TransportState));
  Operation := FInput.SendAsync('T123');
  Command := FBackendObject.Commands[FBackendObject.CommandCount - 1];

  AssertEquals(Ord(tssPending), Ord(Operation.State));
  AssertEquals(Ord(lbckWrite), Ord(Command.Kind));
  AssertEquals(NusServiceUuid, Command.ServiceUuid);
  AssertEquals(NusRxCharacteristicUuid, Command.CharacteristicUuid);
  AssertEquals(4, Length(Command.Value));
  AssertEquals(Ord('T'), Command.Value[0]);
end;

procedure TBleTimingTransportTests.SendAsync_WhenDisconnectedReturnsFailure;
var
  CommandCountBefore: integer;
  Operation: ITimingSendOperation;
begin
  DisconnectInput;
  AssertEquals(Ord(ttsDisconnected), Ord(FInput.TransportState));
  CommandCountBefore := FBackendObject.CommandCount;

  Operation := FInput.SendAsync('T123');

  AssertEquals(Ord(tssFailed), Ord(Operation.State));
  AssertEquals(CommandCountBefore, FBackendObject.CommandCount);
end;

initialization
  RegisterTest(TBleTimingTransportTests);

end.
