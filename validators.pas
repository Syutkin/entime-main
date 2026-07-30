unit Validators;

{$mode ObjFPC}{$H+}

interface

function TryParseParticipantNumber(const AValue: string;
  out ANumber: integer): boolean;
function TryNormalizeTime(const AValue: string;
  out ANormalizedValue: string): boolean;
function TryNormalizeDuration(const AValue: string;
  out ANormalizedValue: string): boolean;

implementation

uses
  SysUtils;

function TryParseParticipantNumber(const AValue: string;
  out ANumber: integer): boolean;
begin
  ANumber := 0;
  Result := TryStrToInt(Trim(AValue), ANumber) and (ANumber > 0);
  if not Result then
    ANumber := 0;
end;

function TryParseDigits(const AValue: string; const AStartIndex,
  ADigitCount: integer; out ANumber: integer): boolean;
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

function TryNormalizeTime(const AValue: string;
  out ANormalizedValue: string): boolean;
var
  value: string;
  hours, minutes, seconds: integer;
begin
  Result := False;
  ANormalizedValue := '';
  value := Trim(AValue);

  if not (Length(value) in [5, 8, 12]) then
    Exit;

  if (value[3] <> ':') or
    (not TryParseDigits(value, 1, 2, hours)) or
    (not TryParseDigits(value, 4, 2, minutes)) or
    (hours > 23) or (minutes > 59) then
    Exit;

  if Length(value) >= 8 then
  begin
    if (value[6] <> ':') or
      (not TryParseDigits(value, 7, 2, seconds)) or
      (seconds > 59) then
      Exit;
  end;

  if Length(value) = 12 then
  begin
    if not (value[9] in ['.', ',']) or
      (not TryParseDigits(value, 10, 3, seconds)) then
      Exit;

    ANormalizedValue := Copy(value, 1, 8) + '.' + Copy(value, 10, 3);
  end
  else
    ANormalizedValue := value;

  Result := True;
end;

function TryNormalizeDuration(const AValue: string;
  out ANormalizedValue: string): boolean;
var
  value, hoursText: string;
  hours, hoursLength, minutes, seconds: integer;
begin
  Result := False;
  ANormalizedValue := '';
  value := Trim(AValue);

  // Формат ss: целое количество секунд от 1 до 59.
  if Length(value) in [1, 2] then
  begin
    if (not TryParseDigits(value, 1, Length(value), seconds)) or
      (seconds < 1) or (seconds > 59) then
      Exit;

    if Length(value) = 1 then
      value := '0' + value;
    ANormalizedValue := '00:00:' + value;
    Exit(True);
  end;

  // Формат mm:ss.
  if Length(value) = 5 then
  begin
    if (value[3] <> ':') or
      (not TryParseDigits(value, 1, 2, minutes)) or
      (not TryParseDigits(value, 4, 2, seconds)) or
      (minutes > 59) or (seconds > 59) then
      Exit;

    ANormalizedValue := '00:' + value;
    Exit(True);
  end;

  // Формат hh:mm:ss.
  hoursLength := Length(value) - 6;
  if (not (hoursLength in [1, 2])) or
    (value[hoursLength + 1] <> ':') or
    (value[hoursLength + 4] <> ':') then
    Exit;

  if (not TryParseDigits(value, 1, hoursLength, hours)) or
    (not TryParseDigits(value, hoursLength + 2, 2, minutes)) or
    (not TryParseDigits(value, hoursLength + 5, 2, seconds)) or
    (hours > 23) or (minutes > 59) or (seconds > 59) then
    Exit;

  hoursText := Copy(value, 1, hoursLength);
  if hoursLength = 1 then
    hoursText := '0' + hoursText;
  ANormalizedValue := hoursText + ':' +
    Copy(value, hoursLength + 2, 5);
  Result := True;
end;

end.
