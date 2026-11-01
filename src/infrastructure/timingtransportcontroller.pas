unit TimingTransportController;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, TimingMark, TimingTransport;

type
  { TTimingTransportController routes only the selected transport. }

  TTimingTransportController = class
  private
    FActiveKind: TTimingTransportKind;
    FBleTransport: ITimingTransport;
    FOnData: TTimingTransportDataEvent;
    FSerialTransport: ITimingTransport;
    function ActiveTransport: ITimingTransport;
    procedure SetActiveKind(const AValue: TTimingTransportKind);
    procedure TransportDataReceived(Sender: TObject; const AData: rawbytestring;
      const ASource: TTimingMarkSource);
  public
    constructor Create(const ASerialTransport, ABleTransport: ITimingTransport);
    destructor Destroy; override;
    function SendAsync(const AData: rawbytestring): ITimingSendOperation;
    property ActiveKind: TTimingTransportKind read FActiveKind write SetActiveKind;
    property OnData: TTimingTransportDataEvent read FOnData write FOnData;
  end;

implementation

constructor TTimingTransportController.Create(
  const ASerialTransport, ABleTransport: ITimingTransport);
begin
  inherited Create;
  if not Assigned(ASerialTransport) then
    raise EArgumentNilException.Create('ASerialTransport');
  if not Assigned(ABleTransport) then
    raise EArgumentNilException.Create('ABleTransport');
  if ASerialTransport.Kind <> ttkSerial then
    raise EArgumentException.Create('ASerialTransport must be serial');
  if ABleTransport.Kind <> ttkBle then
    raise EArgumentException.Create('ABleTransport must be BLE');

  FSerialTransport := ASerialTransport;
  FBleTransport := ABleTransport;
  FSerialTransport.OnData := @TransportDataReceived;
  FBleTransport.OnData := @TransportDataReceived;
  FActiveKind := ttkSerial;
end;

destructor TTimingTransportController.Destroy;
begin
  if Assigned(FSerialTransport) then
    FSerialTransport.OnData := nil;
  if Assigned(FBleTransport) then
    FBleTransport.OnData := nil;
  FOnData := nil;
  FSerialTransport := nil;
  FBleTransport := nil;
  inherited Destroy;
end;

function TTimingTransportController.ActiveTransport: ITimingTransport;
begin
  case FActiveKind of
    ttkSerial: Result := FSerialTransport;
    ttkBle: Result := FBleTransport;
  end;
end;

procedure TTimingTransportController.SetActiveKind(const AValue: TTimingTransportKind);
begin
  FActiveKind := AValue;
end;

function TTimingTransportController.SendAsync(const AData: rawbytestring):
ITimingSendOperation;
var
  Transport: ITimingTransport;
begin
  Transport := ActiveTransport;
  if not Transport.Connected then
    Exit(TTimingSendOperation.Failed(Transport.Source,
      'Selected timing transport is not connected'));
  Result := Transport.SendAsync(AData);
end;

procedure TTimingTransportController.TransportDataReceived(Sender: TObject;
  const AData: rawbytestring; const ASource: TTimingMarkSource);
var
  Handler: TTimingTransportDataEvent;
begin
  case FActiveKind of
    ttkSerial: if ASource.Kind <> tmskSerial then Exit;
    ttkBle: if ASource.Kind <> tmskBle then Exit;
  end;
  Handler := FOnData;
  if Assigned(Handler) then
    Handler(Self, AData, ASource);
end;

end.
