unit ResultFormatting;

{$mode ObjFPC}{$H+}

interface

uses
  DB;

function HideLeadingZeroHour(const AField: TField; const AEnabled: boolean): string;
  overload;
function HideLeadingZeroHour(const ATime: string): string; overload;
function FormatNumber(const ANumber: integer): string;
function FormatTime(ATime: string): string;
function FormatDiff(ADiff: string; const ADiffSign: string = ' '): string;
function FormatPlace(const APlace: integer): string;
function FormatLEDLine(const ANumber: integer; const ATime, ADiff: string;
  const APlace: integer; const ADiffSign: string = ' '): string;
function CheckPenaltyInput(const AKey: char): char;

implementation

uses
  SysUtils;

function HideLeadingZeroHour(const AField: TField; const AEnabled: boolean): string;
var
  timeValue, oneHour: TDateTime;
  formatSettings: TFormatSettings;
begin
  Result := AField.AsString;
  if not AEnabled or (Result = '') then
    Exit;

  formatSettings := DefaultFormatSettings;
  formatSettings.TimeSeparator := ':';
  formatSettings.DecimalSeparator := '.';
  formatSettings.ShortTimeFormat := 'hh:nn:ss.zzz';
  if TryStrToTime(Result, timeValue, formatSettings) then
  begin
    oneHour := EncodeTime(1, 0, 0, 0);
    if timeValue < oneHour then
      Result := FormatDateTime('nn:ss.zzz', timeValue);
  end;
end;

function HideLeadingZeroHour(const ATime: string): string;
begin
  Result := ATime;
  if Pos('00:', Result) = 1 then
    Delete(Result, 1, 3);
end;

function FormatNumber(const ANumber: integer): string;
begin
  Result := Format('%3d', [ANumber]);
end;

function FormatTime(ATime: string): string;
begin
  while Copy(ATime, 1, 3) = '00:' do
    Delete(ATime, 1, 3);
  while (Length(ATime) > 1) and (ATime[1] = '0') and (ATime[2] in ['0'..'9']) do
    Delete(ATime, 1, 1);
  Result := ATime;
end;

function FormatDiff(ADiff: string; const ADiffSign: string): string;
begin
  if ADiff <> '' then
    Result := ADiffSign + FormatTime(ADiff)
  else
    Result := ADiffSign + Format('%6s', [ADiff]);
end;

function FormatPlace(const APlace: integer): string;
begin
  Result := FormatNumber(APlace);
end;

function PadLeft(const AValue: string; const AWidth: integer): string;
begin
  Result := AValue;
  if Length(Result) < AWidth then
    Result := StringOfChar(' ', AWidth - Length(Result)) + Result;
end;

function FitFraction(const AValue: string; const AWidth: integer): string;
var
  DecimalIndex, KeepLength: integer;
begin
  Result := AValue;
  DecimalIndex := Pos('.', Result);
  if (Length(Result) <= AWidth) or (DecimalIndex = 0) then Exit;
  KeepLength := AWidth;
  // Never shorten the integer part, even if it exceeds the nominal field.
  if KeepLength < DecimalIndex - 1 then KeepLength := DecimalIndex - 1;
  SetLength(Result, KeepLength);
  if (Result <> '') and (Result[Length(Result)] = '.') then
    Delete(Result, Length(Result), 1);
end;

function FormatLedDifference(const ADiff, ADiffSign: string): string;
var
  Value, Prefix: string;
  FirstColon, ValueWidth: integer;
  HasHours: boolean;
begin
  if ADiff = '' then Exit(FormatDiff(ADiff, ADiffSign));
  Value := FormatTime(ADiff);
  Prefix := ADiffSign;
  FirstColon := Pos(':', Value);
  HasHours := (FirstColon > 0) and
    (Pos(':', Copy(Value, FirstColon + 1, MaxInt)) > 0);
  // Preserve the old padding of short differences; larger values use its space.
  if (Prefix = ' ') and (HasHours or ((Length(Value) > 1) and
    (Value[2] in ['0'..'9']))) then
    Prefix := '';
  ValueWidth := 7 - Length(Prefix);
  Result := Prefix + PadLeft(FitFraction(Value, ValueWidth), ValueWidth);
end;

function FormatLEDLine(const ANumber: integer; const ATime, ADiff: string;
  const APlace: integer; const ADiffSign: string): string;
const
  // 160 pixels at 6 pixels per glyph, including the inter-character gap.
  MAX_LINE_LENGTH = 26;
var
  Number, Time, Difference, Place: string;
  TimeWidth, Overflow: integer;
begin
  Number := FormatNumber(ANumber);
  Place := FormatPlace(APlace);
  Difference := FormatLedDifference(ADiff, ADiffSign);
  TimeWidth := MAX_LINE_LENGTH - Length(Number) - Length(Place) -
    Length(Difference) - 3;
  if TimeWidth > 9 then TimeWidth := 9;
  if TimeWidth < 0 then TimeWidth := 0;
  // The result keeps its minute component, as in the original LED layout.
  Time := HideLeadingZeroHour(ATime);
  while (Length(Time) > 1) and (Time[1] = '0') and (Time[2] in ['0'..'9']) do
    Delete(Time, 1, 1);
  Time := PadLeft(FitFraction(Time, TimeWidth), TimeWidth);
  Overflow := Length(Number) + Length(Time) + Length(Difference) +
    Length(Place) + 3 - MAX_LINE_LENGTH;
  while (Overflow > 0) and (Number <> '') and (Number[1] = ' ') do
  begin
    Delete(Number, 1, 1);
    Dec(Overflow);
  end;
  while (Overflow > 0) and (Place <> '') and (Place[1] = ' ') do
  begin
    Delete(Place, 1, 1);
    Dec(Overflow);
  end;
  Result := Number + ' ' + Time + ' ' + Difference + ' ' + Place;
end;

function CheckPenaltyInput(const AKey: char): char;
begin
  Result := AKey;
  case AKey of
    '0'..'9': ;
    #8: ;
    ',', '.', '/', '\', ':', '*', '-', '+', '?': Result := ':';
    else
      Result := #0;
  end;
end;

end.
