unit TransportStreamFramer;

{$mode ObjFPC}{$H+}

interface

const
  TRANSPORT_STREAM_MAX_MESSAGE_SIZE = 4096;

type
  TTransportFrameKind = (tfkTimingPacket, tfkFirmwareResponse, tfkDiagnostic);

  TTransportFrame = record
    Kind: TTransportFrameKind;
    Text: RawByteString;
  end;

  TTransportFrameArray = array of TTransportFrame;

  { TTransportStreamFramer }

  TTransportStreamFramer = class
  private
    FBuffer: RawByteString;
    FOverflowCount: cardinal;
    class procedure AddFrame(var AFrames: TTransportFrameArray;
      const AKind: TTransportFrameKind;
      const AText: RawByteString); static;
    class function FirstLineEnd(const AValue: RawByteString): integer; static;
    class function FindNextTimingStart(
      const AValue: RawByteString): integer; static;
    class procedure RemoveLeadingLineEnds(
      var AValue: RawByteString); static;
    procedure ExtractLine(var AFrames: TTransportFrameArray;
      const AKind: TTransportFrameKind; const ALineEndPosition: integer);
  public
    procedure Feed(const AChunk: RawByteString;
      out AFrames: TTransportFrameArray);
    procedure Reset;
    property OverflowCount: cardinal read FOverflowCount;
  end;

implementation

class procedure TTransportStreamFramer.AddFrame(
  var AFrames: TTransportFrameArray; const AKind: TTransportFrameKind;
  const AText: RawByteString);
var
  Index: integer;
begin
  if AText = '' then
    Exit;
  Index := Length(AFrames);
  SetLength(AFrames, Index + 1);
  AFrames[Index].Kind := AKind;
  AFrames[Index].Text := AText;
end;

class function TTransportStreamFramer.FirstLineEnd(
  const AValue: RawByteString): integer;
var
  CarriageReturnPosition, LineFeedPosition: integer;
begin
  CarriageReturnPosition := Pos(#13, AValue);
  LineFeedPosition := Pos(#10, AValue);
  if CarriageReturnPosition = 0 then
    Exit(LineFeedPosition);
  if LineFeedPosition = 0 then
    Exit(CarriageReturnPosition);
  if CarriageReturnPosition < LineFeedPosition then
    Result := CarriageReturnPosition
  else
    Result := LineFeedPosition;
end;

class function TTransportStreamFramer.FindNextTimingStart(
  const AValue: RawByteString): integer;
var
  Position: integer;
begin
  for Position := 2 to Length(AValue) do
    if (AValue[Position] in ['$', 'F']) and
      (Pos('#', Copy(AValue, Position, MaxInt)) > 0) then
      Exit(Position);
  Result := 0;
end;

class procedure TTransportStreamFramer.RemoveLeadingLineEnds(
  var AValue: RawByteString);
begin
  while (AValue <> '') and (AValue[1] in [#10, #13]) do
    Delete(AValue, 1, 1);
end;

procedure TTransportStreamFramer.ExtractLine(
  var AFrames: TTransportFrameArray; const AKind: TTransportFrameKind;
  const ALineEndPosition: integer);
var
  FrameKind: TTransportFrameKind;
  Line: RawByteString;
begin
  Line := Copy(FBuffer, 1, ALineEndPosition - 1);
  Delete(FBuffer, 1, ALineEndPosition);
  RemoveLeadingLineEnds(FBuffer);
  FrameKind := AKind;
  if Length(Line) > TRANSPORT_STREAM_MAX_MESSAGE_SIZE then
  begin
    FrameKind := tfkDiagnostic;
    Inc(FOverflowCount);
  end;
  AddFrame(AFrames, FrameKind, Line);
end;

procedure TTransportStreamFramer.Feed(const AChunk: RawByteString;
  out AFrames: TTransportFrameArray);
var
  FrameText: RawByteString;
  LineEndPosition, MessageStart, PacketEndPosition: integer;
begin
  AFrames := nil;
  if AChunk <> '' then
    FBuffer := FBuffer + AChunk;

  while FBuffer <> '' do
  begin
    RemoveLeadingLineEnds(FBuffer);
    if FBuffer = '' then
      Break;

    LineEndPosition := FirstLineEnd(FBuffer);
    if FBuffer[1] in ['$', 'F'] then
    begin
      PacketEndPosition := Pos('#', FBuffer);
      if (PacketEndPosition > 0) and
        ((LineEndPosition = 0) or
        (PacketEndPosition < LineEndPosition)) then
      begin
        FrameText := Copy(FBuffer, 1, PacketEndPosition);
        Delete(FBuffer, 1, PacketEndPosition);
        if Length(FrameText) > TRANSPORT_STREAM_MAX_MESSAGE_SIZE then
        begin
          Inc(FOverflowCount);
          AddFrame(AFrames, tfkDiagnostic, FrameText);
        end
        else
          AddFrame(AFrames, tfkTimingPacket, FrameText);
        Continue;
      end;
      if LineEndPosition > 0 then
      begin
        ExtractLine(AFrames, tfkDiagnostic, LineEndPosition);
        Continue;
      end;
    end
    else if FBuffer[1] in ['{', '['] then
    begin
      if LineEndPosition > 0 then
      begin
        ExtractLine(AFrames, tfkFirmwareResponse, LineEndPosition);
        Continue;
      end;
    end
    else
    begin
      if LineEndPosition > 0 then
      begin
        ExtractLine(AFrames, tfkDiagnostic, LineEndPosition);
        Continue;
      end;
      MessageStart := FindNextTimingStart(FBuffer);
      if MessageStart > 0 then
      begin
        AddFrame(AFrames, tfkDiagnostic,
          Copy(FBuffer, 1, MessageStart - 1));
        Delete(FBuffer, 1, MessageStart - 1);
        Continue;
      end;
    end;

    if Length(FBuffer) > TRANSPORT_STREAM_MAX_MESSAGE_SIZE then
    begin
      MessageStart := FindNextTimingStart(FBuffer);
      if MessageStart > 0 then
      begin
        AddFrame(AFrames, tfkDiagnostic,
          Copy(FBuffer, 1, MessageStart - 1));
        Delete(FBuffer, 1, MessageStart - 1);
      end
      else
      begin
        AddFrame(AFrames, tfkDiagnostic, FBuffer);
        FBuffer := '';
      end;
      Inc(FOverflowCount);
      if FBuffer <> '' then
        Continue;
    end;
    Break;
  end;
end;

procedure TTransportStreamFramer.Reset;
begin
  FBuffer := '';
  FOverflowCount := 0;
end;

end.
