unit StartLabelSettings;
{$mode objfpc}{$H+}
interface

uses StartLabelModel;

function LoadStartLabelPaper(const IniName: string): TStartLabelPaper;
procedure SaveStartLabelPaper(const IniName: string; const Paper: TStartLabelPaper);

implementation

uses SysUtils, IniFiles, Math;

const
  Section = 'StartLabels';

function Millimetres(Ini: TCustomIniFile; const Key: string; Default: integer): integer;
var
  S: string;
  V: double;
  F: TFormatSettings;
begin
  Result := Default;
  if not Ini.ValueExists(Section, Key) then Exit;
  F := DefaultFormatSettings;
  F.DecimalSeparator := '.';
  S := Ini.ReadString(Section, Key, '');
  if not TryStrToFloat(S, V, F) then Exit(-1);
  if IsNan(V) or IsInfinite(V) or (V < 0) or (V > 297) then Exit(-1);
  Result := Round(V * StartLabelUnitsPerMM);
end;

function LoadStartLabelPaper(const IniName: string): TStartLabelPaper;
var
  Ini: TMemIniFile;
  G: TStartLabelGrid;
begin
  Result := DefaultStartLabelPaper;
  if IniName = '' then Exit;
  Ini := TMemIniFile.Create(IniName);
  try
    Result.Width := Millimetres(Ini, 'Width', Result.Width);
    Result.Height := Millimetres(Ini, 'Height', Result.Height);
    Result.Left := Millimetres(Ini, 'Left', Result.Left);
    Result.Right := Millimetres(Ini, 'Right', Result.Right);
    Result.Top := Millimetres(Ini, 'Top', Result.Top);
    Result.Bottom := Millimetres(Ini, 'Bottom', Result.Bottom);
    Result.GapX := Millimetres(Ini, 'GapX', Result.GapX);
    Result.GapY := Millimetres(Ini, 'GapY', Result.GapY);
    Result.Padding := Millimetres(Ini, 'Padding', Result.Padding);
    Result.FontSize := Ini.ReadInteger(Section, 'FontSize', Result.FontSize);
    Result.MinFontSize := Ini.ReadInteger(Section, 'MinFontSize', Result.MinFontSize);
    Result.StartColumns := Ini.ReadInteger(Section, 'StartColumns', Result.StartColumns);
    Result.DrawBorders := Ini.ReadBool(Section, 'DrawBorders', Result.DrawBorders);
    if CheckStartLabelPaper(Result, G) <> lpeNone then Result := DefaultStartLabelPaper;
  finally
    Ini.Free;
  end;
end;

procedure SaveStartLabelPaper(const IniName: string; const Paper: TStartLabelPaper);
var
  Ini: TMemIniFile;
  P: TStartLabelPaper;
  G: TStartLabelGrid;
  E: TStartLabelPaperError;
  F: TFormatSettings;

  procedure WriteMM(const Key: string; Value: integer);
  begin
    Ini.WriteString(Section, Key, FormatFloat('0.###', Value / StartLabelUnitsPerMM, F));
  end;

begin
  P := Paper;
  P.FirstSlot := 1;
  E := CheckStartLabelPaper(P, G);
  if E <> lpeNone then raise EStartLabelPaper.Create(E);
  if IniName = '' then Exit;
  F := DefaultFormatSettings;
  F.DecimalSeparator := '.';
  Ini := TMemIniFile.Create(IniName);
  try
    WriteMM('Width', P.Width);
    WriteMM('Height', P.Height);
    WriteMM('Left', P.Left);
    WriteMM('Right', P.Right);
    WriteMM('Top', P.Top);
    WriteMM('Bottom', P.Bottom);
    WriteMM('GapX', P.GapX);
    WriteMM('GapY', P.GapY);
    WriteMM('Padding', P.Padding);
    Ini.WriteInteger(Section, 'FontSize', P.FontSize);
    Ini.WriteInteger(Section, 'MinFontSize', P.MinFontSize);
    Ini.WriteInteger(Section, 'StartColumns', P.StartColumns);
    Ini.WriteBool(Section, 'DrawBorders', P.DrawBorders);
    Ini.DeleteKey(Section, 'FirstSlot');
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

end.
