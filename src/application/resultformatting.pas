unit ResultFormatting;

{$mode ObjFPC}{$H+}

interface

uses
  DB;

function HideLeadingZeroHour(const AField: TField;
  const AEnabled: boolean): string; overload;
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

function HideLeadingZeroHour(const AField: TField;
  const AEnabled: boolean): string;
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
  Delete(ATime, 1, Length(ATime) - 9);
  if Pos('0', ATime) = 1 then
    Delete(ATime, 1, 1);
  Result := Format('%9s', [ATime]);
end;

function FormatDiff(ADiff: string; const ADiffSign: string): string;
begin
  if ADiff <> '' then
  begin
    if StrToInt(Copy(ADiff, 1, 2)) > 0 then
      Result := Copy(ADiff, 2, 7)
    else if StrToInt(Copy(ADiff, 4, 2)) > 9 then
      Result := Copy(ADiff, 4, 7)
    else if StrToInt(Copy(ADiff, 4, 2)) > 0 then
      Result := ADiffSign + Copy(ADiff, 5, 6)
    else
    begin
      Delete(ADiff, 1, Length(ADiff) - 6);
      if Pos('0', ADiff) = 1 then
        Delete(ADiff, 1, 1);
      Result := ADiffSign + Format('%6s', [ADiff]);
    end;
  end
  else
    Result := ADiffSign + Format('%6s', [ADiff]);
end;

function FormatPlace(const APlace: integer): string;
begin
  Result := FormatNumber(APlace);
end;

function FormatLEDLine(const ANumber: integer; const ATime, ADiff: string;
  const APlace: integer; const ADiffSign: string): string;
begin
  Result := FormatNumber(ANumber) + ' ' + FormatTime(ATime) + ' ' +
    FormatDiff(ADiff, ADiffSign) + ' ' + FormatPlace(APlace);
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
