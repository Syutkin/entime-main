unit SerialTimingTransport;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, TimingMark, TimingTransport;

type
  ISerialTimingConnection = interface
    ['{78B2516E-80FC-422D-B71D-260821617AB8}']
    function GetActive: boolean;
    function GetDeviceId: string;
    function GetLastErrorCode: integer;
    function GetLastErrorMessage: string;
    function GetOnDataAvailable: TNotifyEvent;
    procedure SetOnDataAvailable(const AHandler: TNotifyEvent);
    function ReadData: RawByteString;
    function WriteData(const AData: RawByteString): integer;
    property Active: boolean read GetActive;
    property DeviceId: string read GetDeviceId;
    property LastErrorCode: integer read GetLastErrorCode;
    property LastErrorMessage: string read GetLastErrorMessage;
    property OnDataAvailable: TNotifyEvent read GetOnDataAvailable
      write SetOnDataAvailable;
  end;

  { TSerialTimingTransport }

  TSerialTimingTransport = class(TInterfacedObject, ITimingTransport)
  private
    FConnection: ISerialTimingConnection;
    FOnData: TTimingTransportDataEvent;
    procedure ConnectionDataAvailable(Sender: TObject);
    function GetConnected: boolean;
    function GetKind: TTimingTransportKind;
    function GetOnData: TTimingTransportDataEvent;
    function GetSource: TTimingMarkSource;
    function GetTransportState: TTimingTransportState;
    procedure SetOnData(const AHandler: TTimingTransportDataEvent);
  public
    constructor Create(const AConnection: ISerialTimingConnection);
    destructor Destroy; override;
    function SendAsync(const AData: RawByteString): ITimingSendOperation;
    property Connected: boolean read GetConnected;
    property Kind: TTimingTransportKind read GetKind;
    property OnData: TTimingTransportDataEvent read GetOnData write SetOnData;
    property Source: TTimingMarkSource read GetSource;
    property TransportState: TTimingTransportState read GetTransportState;
  end;

implementation

constructor TSerialTimingTransport.Create(
  const AConnection: ISerialTimingConnection);
begin
  inherited Create;
  if not Assigned(AConnection) then
    raise EArgumentNilException.Create('AConnection');
  FConnection := AConnection;
  FConnection.OnDataAvailable := @ConnectionDataAvailable;
end;

destructor TSerialTimingTransport.Destroy;
begin
  if Assigned(FConnection) then
    FConnection.OnDataAvailable := nil;
  FOnData := nil;
  FConnection := nil;
  inherited Destroy;
end;

function TSerialTimingTransport.GetConnected: boolean;
begin
  Result := FConnection.Active;
end;

function TSerialTimingTransport.GetKind: TTimingTransportKind;
begin
  Result := ttkSerial;
end;

function TSerialTimingTransport.GetOnData: TTimingTransportDataEvent;
begin
  Result := FOnData;
end;

function TSerialTimingTransport.GetSource: TTimingMarkSource;
begin
  Result := TTimingMarkSource.Serial(FConnection.DeviceId);
end;

function TSerialTimingTransport.GetTransportState: TTimingTransportState;
begin
  if GetConnected then
    Result := ttsConnected
  else
    Result := ttsDisconnected;
end;

procedure TSerialTimingTransport.SetOnData(
  const AHandler: TTimingTransportDataEvent);
begin
  FOnData := AHandler;
end;

procedure TSerialTimingTransport.ConnectionDataAvailable(Sender: TObject);
var
  Data: RawByteString;
  Handler: TTimingTransportDataEvent;
begin
  Data := FConnection.ReadData;
  if Data = '' then
    Exit;
  Handler := FOnData;
  if Assigned(Handler) then
    Handler(Self, Data, GetSource);
end;

function TSerialTimingTransport.SendAsync(
  const AData: RawByteString): ITimingSendOperation;
var
  ErrorCode: integer;
  ErrorMessage: string;
  TransportSource: TTimingMarkSource;
begin
  TransportSource := GetSource;
  if not GetConnected then
    Exit(TTimingSendOperation.Failed(TransportSource,
      'Serial timing transport is not connected'));
  try
    FConnection.WriteData(AData);
    ErrorCode := FConnection.LastErrorCode;
    if ErrorCode = 0 then
      Exit(TTimingSendOperation.Succeeded(TransportSource));
    ErrorMessage := FConnection.LastErrorMessage;
    if ErrorMessage = '' then
      ErrorMessage := 'Serial write failed';
    Result := TTimingSendOperation.Failed(TransportSource, ErrorMessage,
      ErrorCode);
  except
    on E: Exception do
      Result := TTimingSendOperation.Failed(TransportSource, E.Message);
  end;
end;

end.
