unit TransportStreamProcessor;

{$mode ObjFPC}{$H+}

interface

uses
  TimingProtocol, TimingMark, FirmwareResponseProtocol,
  TransportStreamFramer;

type
  TTransportStreamRejectedKind = (tsrkTimingPacket,
    tsrkFirmwareResponse, tsrkDiagnostic);

  TTransportStreamRejected = record
    Kind: TTransportStreamRejectedKind;
    RawText: string;
    Source: TTimingMarkSource;
    TimingError: TTimingPacketParseError;
    FirmwareError: TFirmwareResponseParseError;
  end;

  TTransportTimingPacketEvent = procedure(Sender: TObject;
    const APacket: TTimingPacket;
    const ASource: TTimingMarkSource) of object;
  TTransportFirmwareResponseEvent = procedure(Sender: TObject;
    const AResponse: TFirmwareResponse) of object;
  TTransportStreamRejectedEvent = procedure(Sender: TObject;
    const ARejected: TTransportStreamRejected) of object;

  { TTransportStreamProcessor }

  TTransportStreamProcessor = class
  private
    FFirmwareParser: TFirmwareResponseParser;
    FFramer: TTransportStreamFramer;
    FOnFirmwareResponse: TTransportFirmwareResponseEvent;
    FOnRejected: TTransportStreamRejectedEvent;
    FOnTimingPacket: TTransportTimingPacketEvent;
    procedure ProcessFirmwareResponse(const ARawJson: string;
      const ASource: TTimingMarkSource; const AReceivedAt: TDateTime);
    procedure ProcessTimingPacket(const ARawPacket: string;
      const ASource: TTimingMarkSource);
    procedure Reject(const AKind: TTransportStreamRejectedKind;
      const ARawText: string; const ASource: TTimingMarkSource;
      const ATimingError: TTimingPacketParseError = tppeNone;
      const AFirmwareError: TFirmwareResponseParseError = frpeNone);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Feed(const AChunk: RawByteString;
      const ASource: TTimingMarkSource; const AReceivedAt: TDateTime);
    procedure Reset;
    property OnFirmwareResponse: TTransportFirmwareResponseEvent
      read FOnFirmwareResponse write FOnFirmwareResponse;
    property OnRejected: TTransportStreamRejectedEvent read FOnRejected
      write FOnRejected;
    property OnTimingPacket: TTransportTimingPacketEvent read FOnTimingPacket
      write FOnTimingPacket;
  end;

function TransportStreamRejectedCode(
  const ARejected: TTransportStreamRejected): string;

implementation

function TransportStreamRejectedCode(
  const ARejected: TTransportStreamRejected): string;
begin
  case ARejected.Kind of
    tsrkTimingPacket:
      Result := 'timing_' + TimingPacketParseErrorCode(ARejected.TimingError);
    tsrkFirmwareResponse:
      Result := 'firmware_' +
        FirmwareResponseParseErrorCode(ARejected.FirmwareError);
    tsrkDiagnostic: Result := 'diagnostic';
  end;
end;

constructor TTransportStreamProcessor.Create;
begin
  inherited Create;
  FFramer := TTransportStreamFramer.Create;
  FFirmwareParser := TFirmwareResponseParser.Create;
end;

destructor TTransportStreamProcessor.Destroy;
begin
  FOnTimingPacket := nil;
  FOnFirmwareResponse := nil;
  FOnRejected := nil;
  FFirmwareParser.Free;
  FFramer.Free;
  inherited Destroy;
end;

procedure TTransportStreamProcessor.Feed(const AChunk: RawByteString;
  const ASource: TTimingMarkSource; const AReceivedAt: TDateTime);
var
  Frames: TTransportFrameArray;
  Index: integer;
begin
  if AChunk = '' then
    Exit;
  FFramer.Feed(AChunk, Frames);
  for Index := 0 to High(Frames) do
    case Frames[Index].Kind of
      tfkTimingPacket:
        ProcessTimingPacket(string(Frames[Index].Text), ASource);
      tfkFirmwareResponse:
        ProcessFirmwareResponse(string(Frames[Index].Text), ASource,
          AReceivedAt);
      tfkDiagnostic:
        Reject(tsrkDiagnostic, string(Frames[Index].Text), ASource);
    end;
end;

procedure TTransportStreamProcessor.ProcessFirmwareResponse(
  const ARawJson: string; const ASource: TTimingMarkSource;
  const AReceivedAt: TDateTime);
var
  Error: TFirmwareResponseParseError;
  Handler: TTransportFirmwareResponseEvent;
  Response: TFirmwareResponse;
begin
  if FFirmwareParser.TryParse(ARawJson, ASource, AReceivedAt,
    Response, Error) then
  begin
    Handler := FOnFirmwareResponse;
    if Assigned(Handler) then
      Handler(Self, Response);
  end
  else
    Reject(tsrkFirmwareResponse, ARawJson, ASource, tppeNone, Error);
end;

procedure TTransportStreamProcessor.ProcessTimingPacket(
  const ARawPacket: string; const ASource: TTimingMarkSource);
var
  Error: TTimingPacketParseError;
  Handler: TTransportTimingPacketEvent;
  Packet: TTimingPacket;
begin
  if TryParseTimingPacket(ARawPacket, Packet, Error) then
  begin
    Handler := FOnTimingPacket;
    if Assigned(Handler) then
      Handler(Self, Packet, ASource);
  end
  else
    Reject(tsrkTimingPacket, ARawPacket, ASource, Error);
end;

procedure TTransportStreamProcessor.Reject(
  const AKind: TTransportStreamRejectedKind; const ARawText: string;
  const ASource: TTimingMarkSource;
  const ATimingError: TTimingPacketParseError;
  const AFirmwareError: TFirmwareResponseParseError);
var
  Handler: TTransportStreamRejectedEvent;
  Rejected: TTransportStreamRejected;
begin
  Rejected := Default(TTransportStreamRejected);
  Rejected.Kind := AKind;
  Rejected.RawText := ARawText;
  Rejected.Source := ASource;
  Rejected.TimingError := ATimingError;
  Rejected.FirmwareError := AFirmwareError;
  Handler := FOnRejected;
  if Assigned(Handler) then
    Handler(Self, Rejected);
end;

procedure TTransportStreamProcessor.Reset;
begin
  FFramer.Reset;
end;

end.
