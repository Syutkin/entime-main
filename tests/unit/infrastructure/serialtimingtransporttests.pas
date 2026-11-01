unit SerialTimingTransportTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, FPCUnit, TestRegistry, TimingMark, TimingTransport,
  SerialTimingTransport;

type
  TFakeSerialTimingConnection = class(TInterfacedObject,
    ISerialTimingConnection)
  private
    FActive: boolean;
    FDeviceId: string;
    FLastErrorCode: integer;
    FLastErrorMessage: string;
    FLastWritten: rawbytestring;
    FOnDataAvailable: TNotifyEvent;
    FWriteCount: integer;
    function GetActive: boolean;
    function GetDeviceId: string;
    function GetLastErrorCode: integer;
    function GetLastErrorMessage: string;
    function GetOnDataAvailable: TNotifyEvent;
    procedure SetOnDataAvailable(const AHandler: TNotifyEvent);
  public
    function ReadData: rawbytestring;
    function WriteData(const AData: rawbytestring): integer;
    property Active: boolean read FActive write FActive;
    property DeviceId: string read FDeviceId write FDeviceId;
    property LastErrorCode: integer read FLastErrorCode write FLastErrorCode;
    property LastErrorMessage: string read FLastErrorMessage write FLastErrorMessage;
    property LastWritten: rawbytestring read FLastWritten;
    property OnDataAvailable: TNotifyEvent read FOnDataAvailable;
    property WriteCount: integer read FWriteCount;
  end;

  TSerialTimingTransportTests = class(TTestCase)
  private
    FConnection: TFakeSerialTimingConnection;
    FConnectionInterface: ISerialTimingConnection;
    FData: rawbytestring;
    FSource: TTimingMarkSource;
    FTransport: TSerialTimingTransport;
    FTransportInterface: ITimingTransport;
    procedure DataReceived(Sender: TObject; const AData: rawbytestring;
      const ASource: TTimingMarkSource);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SendAsync_WritesToConnectedSerialPort;
    procedure SendAsync_ReportsDisconnectedAndWriteErrors;
    procedure IncomingData_IsTaggedWithCurrentSerialDevice;
  end;

implementation

function TFakeSerialTimingConnection.GetActive: boolean;
begin
  Result := FActive;
end;

function TFakeSerialTimingConnection.GetDeviceId: string;
begin
  Result := FDeviceId;
end;

function TFakeSerialTimingConnection.GetLastErrorCode: integer;
begin
  Result := FLastErrorCode;
end;

function TFakeSerialTimingConnection.GetLastErrorMessage: string;
begin
  Result := FLastErrorMessage;
end;

function TFakeSerialTimingConnection.GetOnDataAvailable: TNotifyEvent;
begin
  Result := FOnDataAvailable;
end;

procedure TFakeSerialTimingConnection.SetOnDataAvailable(const AHandler: TNotifyEvent);
begin
  FOnDataAvailable := AHandler;
end;

function TFakeSerialTimingConnection.ReadData: rawbytestring;
begin
  Result := 'serial-input';
end;

function TFakeSerialTimingConnection.WriteData(const AData: rawbytestring): integer;
begin
  Inc(FWriteCount);
  FLastWritten := AData;
  Result := Length(AData);
end;

procedure TSerialTimingTransportTests.SetUp;
begin
  inherited SetUp;
  FConnection := TFakeSerialTimingConnection.Create;
  FConnection.DeviceId := 'COM11';
  FConnection.Active := True;
  FConnectionInterface := FConnection;
  FTransport := TSerialTimingTransport.Create(FConnectionInterface);
  FTransportInterface := FTransport;
  FTransport.OnData := @DataReceived;
end;

procedure TSerialTimingTransportTests.TearDown;
begin
  FTransportInterface := nil;
  FTransport := nil;
  FConnectionInterface := nil;
  FConnection := nil;
  inherited TearDown;
end;

procedure TSerialTimingTransportTests.DataReceived(Sender: TObject;
  const AData: rawbytestring; const ASource: TTimingMarkSource);
begin
  AssertSame(FTransport, Sender);
  FData := AData;
  FSource := ASource;
end;

procedure TSerialTimingTransportTests.SendAsync_WritesToConnectedSerialPort;
var
  Operation: ITimingSendOperation;
begin
  Operation := FTransport.SendAsync('T123');

  AssertEquals(Ord(ttkSerial), Ord(FTransport.Kind));
  AssertEquals(Ord(ttsConnected), Ord(FTransport.TransportState));
  AssertEquals(Ord(tssSucceeded), Ord(Operation.State));
  AssertEquals(1, FConnection.WriteCount);
  AssertEquals('T123', string(FConnection.LastWritten));
  AssertEquals('COM11', Operation.Source.DeviceId);
end;

procedure TSerialTimingTransportTests.
SendAsync_ReportsDisconnectedAndWriteErrors;
var
  Operation: ITimingSendOperation;
begin
  FConnection.Active := False;
  Operation := FTransport.SendAsync('T1');
  AssertEquals(Ord(ttsDisconnected), Ord(FTransport.TransportState));
  AssertEquals(Ord(tssFailed), Ord(Operation.State));
  AssertEquals(0, FConnection.WriteCount);

  FConnection.Active := True;
  FConnection.LastErrorCode := 5;
  FConnection.LastErrorMessage := 'write failed';
  Operation := FTransport.SendAsync('T2');
  AssertEquals(Ord(tssFailed), Ord(Operation.State));
  AssertEquals(5, Operation.ErrorCode);
  AssertEquals('write failed', Operation.ErrorMessage);
end;

procedure TSerialTimingTransportTests.
IncomingData_IsTaggedWithCurrentSerialDevice;
begin
  FConnection.OnDataAvailable(FConnection);

  AssertEquals('serial-input', string(FData));
  AssertEquals(Ord(tmskSerial), Ord(FSource.Kind));
  AssertEquals('COM11', FSource.DeviceId);
end;

initialization
  RegisterTest(TSerialTimingTransportTests);

end.
