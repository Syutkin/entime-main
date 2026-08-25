unit TimingProtocol;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils;

const
  TIMING_CORRECTION_LIMIT_MS = 60000;
  TIMING_LOG_VALUE_MAX_LENGTH = 160;

type
  TTimingPacketKind = (tpkStart, tpkFinish);

  TTimingPacket = record
    Kind: TTimingPacketKind;
    EventTime: TDateTime;
    HasCorrection: boolean;
    CorrectionMs: integer;
    RawText: string;
  end;

  TTimingPacketParseError = (
    tppeNone,
    tppeUnknownHeader,
    tppeMissingTerminator,
    tppeInvalidFieldCount,
    tppeInvalidTime,
    tppeInvalidCorrection,
    tppeUnexpectedData
  );

function TryParseTimingPacket(const ARawPacket: string;
  out APacket: TTimingPacket;
  out AError: TTimingPacketParseError): boolean;
function TimingPacketParseErrorCode(
  const AError: TTimingPacketParseError): string;
function TimingPacketLogValue(const AValue: string): string;

implementation

const
  START_HEADER = '$';
  FINISH_HEADER = 'F';
  PACKET_TERMINATOR = '#';

function IsAsciiDigit(const AValue: char): boolean;
begin
  Result := (AValue >= '0') and (AValue <= '9');
end;

function HasTimeStructure(const AValue: string): boolean;
var
  i: integer;
begin
  Result := (Length(AValue) = 8) or (Length(AValue) = 12);
  if not Result then
    Exit;

  Result := (AValue[3] = ':') and (AValue[6] = ':');
  if not Result then
    Exit;

  for i := 1 to 8 do
    if (i <> 3) and (i <> 6) and not IsAsciiDigit(AValue[i]) then
      Exit(False);

  if Length(AValue) = 12 then
  begin
    Result := AValue[9] = ',';
    if not Result then
      Exit;
    for i := 10 to 12 do
      if not IsAsciiDigit(AValue[i]) then
        Exit(False);
  end;
end;

function TryParseProtocolTime(const AValue: string;
  out ATime: TDateTime): boolean;
var
  formatSettings: TFormatSettings;
begin
  ATime := 0;
  if not HasTimeStructure(AValue) then
    Exit(False);

  formatSettings := DefaultFormatSettings;
  formatSettings.TimeSeparator := ':';
  formatSettings.DecimalSeparator := ',';
  Result := TryStrToTime(AValue, ATime, formatSettings);
end;

function HasCorrectionStructure(const AValue: string): boolean;
var
  firstSignificantDigit, i, firstDigit: integer;
begin
  Result := AValue <> '';
  if not Result then
    Exit;

  firstDigit := 1;
  if AValue[1] in ['+', '-'] then
    firstDigit := 2;
  if firstDigit > Length(AValue) then
    Exit(False);

  for i := firstDigit to Length(AValue) do
    if not IsAsciiDigit(AValue[i]) then
      Exit(False);

  firstSignificantDigit := firstDigit;
  while (firstSignificantDigit < Length(AValue)) and
    (AValue[firstSignificantDigit] = '0') do
    Inc(firstSignificantDigit);
  Result := Length(AValue) - firstSignificantDigit + 1 <= 5;
end;

procedure InitializePacket(out APacket: TTimingPacket;
  const ARawPacket: string);
begin
  APacket.Kind := tpkStart;
  APacket.EventTime := 0;
  APacket.HasCorrection := False;
  APacket.CorrectionMs := 0;
  APacket.RawText := ARawPacket;
end;

function TryParseStartPacket(const ABody: string;
  var APacket: TTimingPacket;
  out AError: TTimingPacketParseError): boolean;
var
  delimiterPosition: integer;
  correctionText, timeText: string;
begin
  Result := False;
  APacket.Kind := tpkStart;
  delimiterPosition := Pos(';', ABody);

  if delimiterPosition = 0 then
    timeText := ABody
  else
  begin
    if Pos(';', Copy(ABody, delimiterPosition + 1, MaxInt)) > 0 then
    begin
      AError := tppeInvalidFieldCount;
      Exit;
    end;
    timeText := Copy(ABody, 1, delimiterPosition - 1);
    correctionText := Copy(ABody, delimiterPosition + 1, MaxInt);
    if not HasCorrectionStructure(correctionText) or
      not TryStrToInt(correctionText, APacket.CorrectionMs) or
      (APacket.CorrectionMs < -TIMING_CORRECTION_LIMIT_MS) or
      (APacket.CorrectionMs > TIMING_CORRECTION_LIMIT_MS) then
    begin
      AError := tppeInvalidCorrection;
      Exit;
    end;
    APacket.HasCorrection := True;
  end;

  if not TryParseProtocolTime(timeText, APacket.EventTime) then
  begin
    AError := tppeInvalidTime;
    Exit;
  end;

  AError := tppeNone;
  Result := True;
end;

function TryParseFinishPacket(const ABody: string;
  var APacket: TTimingPacket;
  out AError: TTimingPacketParseError): boolean;
begin
  Result := False;
  APacket.Kind := tpkFinish;
  if Pos(';', ABody) > 0 then
  begin
    AError := tppeInvalidFieldCount;
    Exit;
  end;
  if not TryParseProtocolTime(ABody, APacket.EventTime) then
  begin
    AError := tppeInvalidTime;
    Exit;
  end;

  AError := tppeNone;
  Result := True;
end;

function TryParseTimingPacket(const ARawPacket: string;
  out APacket: TTimingPacket;
  out AError: TTimingPacketParseError): boolean;
var
  body: string;
  terminatorPosition: integer;
begin
  InitializePacket(APacket, ARawPacket);
  Result := False;
  AError := tppeNone;

  terminatorPosition := Pos(PACKET_TERMINATOR, ARawPacket);
  if terminatorPosition = 0 then
  begin
    AError := tppeMissingTerminator;
    Exit;
  end;
  if terminatorPosition <> Length(ARawPacket) then
  begin
    AError := tppeUnexpectedData;
    Exit;
  end;
  if Length(ARawPacket) < 2 then
  begin
    AError := tppeUnknownHeader;
    Exit;
  end;

  body := Copy(ARawPacket, 2, Length(ARawPacket) - 2);
  case ARawPacket[1] of
    START_HEADER:
      Result := TryParseStartPacket(body, APacket, AError);
    FINISH_HEADER:
      Result := TryParseFinishPacket(body, APacket, AError);
    else
    begin
      AError := tppeUnknownHeader;
      Result := False;
    end;
  end;
end;

function TimingPacketParseErrorCode(
  const AError: TTimingPacketParseError): string;
begin
  case AError of
    tppeNone: Result := 'none';
    tppeUnknownHeader: Result := 'unknown_header';
    tppeMissingTerminator: Result := 'missing_terminator';
    tppeInvalidFieldCount: Result := 'invalid_field_count';
    tppeInvalidTime: Result := 'invalid_time';
    tppeInvalidCorrection: Result := 'invalid_correction';
    tppeUnexpectedData: Result := 'unexpected_data';
  end;
end;

function TimingPacketLogValue(const AValue: string): string;
var
  encodedValue: string;
  i: integer;
begin
  Result := '';
  for i := 1 to Length(AValue) do
  begin
    case AValue[i] of
      #9: encodedValue := '\t';
      #10: encodedValue := '\n';
      #13: encodedValue := '\r';
      '\': encodedValue := '\\';
    else
      if (Ord(AValue[i]) >= 32) and (Ord(AValue[i]) <= 126) then
        encodedValue := AValue[i]
      else
        encodedValue := '\x' + IntToHex(Ord(AValue[i]), 2);
    end;

    if Length(Result) + Length(encodedValue) >
      TIMING_LOG_VALUE_MAX_LENGTH - 3 then
      Exit(Result + '...');
    Result := Result + encodedValue;
  end;
end;

end.
