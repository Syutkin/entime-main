unit Validators;

{$mode ObjFPC}{$H+}

interface

function TryParseParticipantNumber(const AValue: string; out ANumber: integer): boolean;
function TryNormalizeTime(const AValue: string; out ANormalizedValue: string): boolean;
function TryNormalizeDuration(const AValue: string;
  out ANormalizedValue: string): boolean;

implementation

uses
  SysUtils;

function TryParseParticipantNumber(const AValue: string; out ANumber: integer): boolean;
begin
  ANumber := 0;
  Result := TryStrToInt(Trim(AValue), ANumber) and (ANumber > 0);
  if not Result then
    ANumber := 0;
end;

function TryParseDigits(const AValue: string; const AStartIndex, ADigitCount: integer;
  out ANumber: integer): boolean;
var
  i: integer;
begin
  ANumber := 0;
  for i := AStartIndex to AStartIndex + ADigitCount - 1 do
  begin
    if not (AValue[i] in ['0'..'9']) then
      Exit(False);
    ANumber := ANumber * 10 + Ord(AValue[i]) - Ord('0');
  end;
  Result := True;
end;

function TryNormalizeTime(const AValue: string; out ANormalizedValue: string): boolean;
var
  Value: string;
  hours, minutes, seconds: integer;
begin
  Result := False;
  ANormalizedValue := '';
  Value := Trim(AValue);

  if (Length(Value) <> 5) and (Length(Value) <> 8) and (Length(Value) <> 12) then
    Exit;

  if (Value[3] <> ':') or (not TryParseDigits(Value, 1, 2, hours)) or
    (not TryParseDigits(Value, 4, 2, minutes)) or (hours > 23) or (minutes > 59) then
    Exit;

  if Length(Value) >= 8 then
  begin
    if (Value[6] <> ':') or (not TryParseDigits(Value, 7, 2, seconds)) or
      (seconds > 59) then
      Exit;
  end;

  if Length(Value) = 12 then
  begin
    if not (Value[9] in ['.', ',']) or
      (not TryParseDigits(Value, 10, 3, seconds)) then
      Exit;

    ANormalizedValue := Copy(Value, 1, 8) + '.' + Copy(Value, 10, 3);
  end
  else
    ANormalizedValue := Value;

  Result := True;
end;

function TryNormalizeDuration(const AValue: string;
  out ANormalizedValue: string): boolean;
var
  Value, hoursText: string;
  hours, hoursLength, minutes, seconds: integer;
begin
  Result := False;
  ANormalizedValue := '';
  Value := Trim(AValue);

  // Формат ss: целое количество секунд от 1 до 59.
  if (Length(Value) = 1) or (Length(Value) = 2) then
  begin
    if (not TryParseDigits(Value, 1, Length(Value), seconds)) or
      (seconds < 1) or (seconds > 59) then
      Exit;

    if Length(Value) = 1 then
      Value := '0' + Value;
    ANormalizedValue := '00:00:' + Value;
    Exit(True);
  end;

  // Формат mm:ss.
  if Length(Value) = 5 then
  begin
    if (Value[3] <> ':') or (not TryParseDigits(Value, 1, 2, minutes)) or
      (not TryParseDigits(Value, 4, 2, seconds)) or (minutes > 59) or
      (seconds > 59) then
      Exit;

    ANormalizedValue := '00:' + Value;
    Exit(True);
  end;

  // Формат hh:mm:ss.
  hoursLength := Length(Value) - 6;
  if ((hoursLength <> 1) and (hoursLength <> 2)) or
    (Value[hoursLength + 1] <> ':') or (Value[hoursLength + 4] <> ':') then
    Exit;

  if (not TryParseDigits(Value, 1, hoursLength, hours)) or
    (not TryParseDigits(Value, hoursLength + 2, 2, minutes)) or
    (not TryParseDigits(Value, hoursLength + 5, 2, seconds)) or
    (hours > 23) or (minutes > 59) or (seconds > 59) then
    Exit;

  hoursText := Copy(Value, 1, hoursLength);
  if hoursLength = 1 then
    hoursText := '0' + hoursText;
  ANormalizedValue := hoursText + ':' + Copy(Value, hoursLength + 2, 5);
  Result := True;
end;

end.
