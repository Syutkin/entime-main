unit TimingTransportControllerTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, FPCUnit, TestRegistry, TimingMark, TimingTransport,
  TimingTransportController;

type
  TFakeTimingTransport = class(TInterfacedObject, ITimingTransport)
  private
    FConnected: boolean;
    FLastData: rawbytestring;
    FOnData: TTimingTransportDataEvent;
    FSendCount: integer;
    FSource: TTimingMarkSource;
    function GetConnected: boolean;
    function GetKind: TTimingTransportKind;
    function GetOnData: TTimingTransportDataEvent;
    function GetSource: TTimingMarkSource;
    function GetTransportState: TTimingTransportState;
    procedure SetOnData(const AHandler: TTimingTransportDataEvent);
  public
    constructor Create(const ASource: TTimingMarkSource);
    procedure Emit(const AData: rawbytestring);
    function SendAsync(const AData: rawbytestring): ITimingSendOperation;
    property Connected: boolean read FConnected write FConnected;
    property LastData: rawbytestring read FLastData;
    property SendCount: integer read FSendCount;
  end;

  { TTimingTransportControllerTests }

  TTimingTransportControllerTests = class(TTestCase)
  private
    FBle: TFakeTimingTransport;
    FController: TTimingTransportController;
    FDataCount: integer;
    FLastData: rawbytestring;
    FLastSource: TTimingMarkSource;
    FSerial: TFakeTimingTransport;
    procedure DataReceived(Sender: TObject; const AData: rawbytestring;
      const ASource: TTimingMarkSource);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SendAsync_UsesOnlySelectedConnectedTransport;
    procedure SendAsync_DoesNotFallbackWhenSelectedTransportDisconnected;
    procedure IncomingData_ForwardsOnlySelectedTransport;
  end;

implementation

constructor TFakeTimingTransport.Create(const ASource: TTimingMarkSource);
begin
  inherited Create;
  FSource := ASource;
  FConnected := True;
end;

function TFakeTimingTransport.GetConnected: boolean;
begin
  Result := FConnected;
end;

function TFakeTimingTransport.GetKind: TTimingTransportKind;
begin
  if FSource.Kind = tmskSerial then
    Result := ttkSerial
  else
    Result := ttkBle;
end;

function TFakeTimingTransport.GetOnData: TTimingTransportDataEvent;
begin
  Result := FOnData;
end;

function TFakeTimingTransport.GetSource: TTimingMarkSource;
begin
  Result := FSource;
end;

function TFakeTimingTransport.GetTransportState: TTimingTransportState;
begin
  if FConnected then
    Result := ttsConnected
  else
    Result := ttsDisconnected;
end;

procedure TFakeTimingTransport.SetOnData(const AHandler: TTimingTransportDataEvent);
begin
  FOnData := AHandler;
end;

procedure TFakeTimingTransport.Emit(const AData: rawbytestring);
begin
  if Assigned(FOnData) then
    FOnData(Self, AData, FSource);
end;

function TFakeTimingTransport.SendAsync(const AData: rawbytestring):
ITimingSendOperation;
begin
  Inc(FSendCount);
  FLastData := AData;
  Result := TTimingSendOperation.Succeeded(FSource);
end;

procedure TTimingTransportControllerTests.SetUp;
var
  BleInterface, SerialInterface: ITimingTransport;
begin
  inherited SetUp;
  FSerial := TFakeTimingTransport.Create(TTimingMarkSource.Serial('COM7'));
  FBle := TFakeTimingTransport.Create(TTimingMarkSource.Ble('device-7'));
  SerialInterface := FSerial;
  BleInterface := FBle;
  FController := TTimingTransportController.Create(SerialInterface, BleInterface);
  FController.OnData := @DataReceived;
end;

procedure TTimingTransportControllerTests.TearDown;
begin
  FController.Free;
  FController := nil;
  FSerial := nil;
  FBle := nil;
  inherited TearDown;
end;

procedure TTimingTransportControllerTests.DataReceived(Sender: TObject;
  const AData: rawbytestring; const ASource: TTimingMarkSource);
begin
  AssertSame(FController, Sender);
  Inc(FDataCount);
  FLastData := AData;
  FLastSource := ASource;
end;

procedure TTimingTransportControllerTests.
SendAsync_UsesOnlySelectedConnectedTransport;
var
  Operation: ITimingSendOperation;
begin
  FController.ActiveKind := ttkSerial;
  Operation := FController.SendAsync('serial-command');
  AssertEquals(Ord(tssSucceeded), Ord(Operation.State));
  AssertEquals(1, FSerial.SendCount);
  AssertEquals(0, FBle.SendCount);
  AssertEquals('serial-command', string(FSerial.LastData));

  FController.ActiveKind := ttkBle;
  Operation := FController.SendAsync('ble-command');
  AssertEquals(Ord(tssSucceeded), Ord(Operation.State));
  AssertEquals(1, FSerial.SendCount);
  AssertEquals(1, FBle.SendCount);
  AssertEquals('ble-command', string(FBle.LastData));
end;

procedure TTimingTransportControllerTests.
SendAsync_DoesNotFallbackWhenSelectedTransportDisconnected;
var
  Operation: ITimingSendOperation;
begin
  FController.ActiveKind := ttkBle;
  FBle.Connected := False;

  Operation := FController.SendAsync('command');

  AssertEquals(Ord(tssFailed), Ord(Operation.State));
  AssertTrue(Pos('not connected', LowerCase(Operation.ErrorMessage)) > 0);
  AssertEquals(0, FBle.SendCount);
  AssertEquals(0, FSerial.SendCount);
end;

procedure TTimingTransportControllerTests.
IncomingData_ForwardsOnlySelectedTransport;
begin
  FController.ActiveKind := ttkSerial;
  FBle.Emit('ignored-ble');
  FSerial.Emit('serial-data');

  AssertEquals(1, FDataCount);
  AssertEquals('serial-data', string(FLastData));
  AssertEquals(Ord(tmskSerial), Ord(FLastSource.Kind));

  FController.ActiveKind := ttkBle;
  FSerial.Emit('ignored-serial');
  FBle.Emit('ble-data');

  AssertEquals(2, FDataCount);
  AssertEquals('ble-data', string(FLastData));
  AssertEquals(Ord(tmskBle), Ord(FLastSource.Kind));
end;

initialization
  RegisterTest(TTimingTransportControllerTests);

end.
