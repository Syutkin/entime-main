unit LazSerialTimingConnection;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, LazSerial, SerialTimingTransport;

type
  { TLazSerialTimingConnection }

  TLazSerialTimingConnection = class(TInterfacedObject,
    ISerialTimingConnection)
  private
    FOnDataAvailable: TNotifyEvent;
    FSerial: TLazSerial;
    function GetActive: boolean;
    function GetDeviceId: string;
    function GetLastErrorCode: integer;
    function GetLastErrorMessage: string;
    function GetOnDataAvailable: TNotifyEvent;
    procedure SerialDataAvailable(Sender: TObject);
    procedure SetOnDataAvailable(const AHandler: TNotifyEvent);
  public
    constructor Create(const ASerial: TLazSerial);
    destructor Destroy; override;
    function ReadData: rawbytestring;
    function WriteData(const AData: rawbytestring): integer;
  end;

implementation

constructor TLazSerialTimingConnection.Create(const ASerial: TLazSerial);
begin
  inherited Create;
  if not Assigned(ASerial) then
    raise EArgumentNilException.Create('ASerial');
  FSerial := ASerial;
  FSerial.OnRxData := @SerialDataAvailable;
end;

destructor TLazSerialTimingConnection.Destroy;
begin
  if Assigned(FSerial) then
    FSerial.OnRxData := nil;
  FOnDataAvailable := nil;
  FSerial := nil;
  inherited Destroy;
end;

function TLazSerialTimingConnection.GetActive: boolean;
begin
  Result := FSerial.Active;
end;

function TLazSerialTimingConnection.GetDeviceId: string;
begin
  Result := FSerial.Device;
end;

function TLazSerialTimingConnection.GetLastErrorCode: integer;
begin
  Result := FSerial.SynSer.LastError;
end;

function TLazSerialTimingConnection.GetLastErrorMessage: string;
begin
  Result := FSerial.SynSer.LastErrorDesc;
end;

function TLazSerialTimingConnection.GetOnDataAvailable: TNotifyEvent;
begin
  Result := FOnDataAvailable;
end;

procedure TLazSerialTimingConnection.SetOnDataAvailable(const AHandler: TNotifyEvent);
begin
  FOnDataAvailable := AHandler;
end;

procedure TLazSerialTimingConnection.SerialDataAvailable(Sender: TObject);
var
  Handler: TNotifyEvent;
begin
  Handler := FOnDataAvailable;
  if Assigned(Handler) then
    Handler(Self);
end;

function TLazSerialTimingConnection.ReadData: rawbytestring;
begin
  Result := rawbytestring(FSerial.ReadData);
end;

function TLazSerialTimingConnection.WriteData(const AData: rawbytestring): integer;
begin
  Result := FSerial.WriteData(string(AData));
end;

end.
