unit StartLabelTemplates;
{$mode objfpc}{$H+}
interface

uses SysUtils, StartLabelModel;

type
  EStartLabelTemplate = class(Exception);
  EStartLabelTemplateMissing = class(EStartLabelTemplate);

  TStartLabelTemplate = record
    Name, FileName: string;
    Paper: TStartLabelPaper;
  end;

function ReadStartLabelTemplate(const FileName: string): TStartLabelTemplate;
procedure WriteStartLabelTemplate(const FileName, Name: string;
  const Paper: TStartLabelPaper);
function SameStartLabelTemplatePaper(const A, B: TStartLabelPaper): boolean;

implementation

uses IniFiles, Math, StartLabelSettings, i18n;

const
  Section = 'StartLabels';

procedure Invalid(const FileName, Key: string);
begin
  raise EStartLabelTemplate.Create(FileName + ': ' + Format(
    rsLabelTemplateInvalidField, [Key]));
end;

procedure Validate(const FileName: string; const Paper: TStartLabelPaper);
var
  P: TStartLabelPaper;
  G: TStartLabelGrid;
  E: TStartLabelPaperError;
begin
  P := Paper;
  P.FirstSlot := 1;
  if (P.Width <= 0) or (P.Width > StartLabelPageWidth) then
    Invalid(FileName, 'Width');
  if (P.Height <= 0) or (P.Height > StartLabelPageHeight) then
    Invalid(FileName, 'Height');
  if (P.MinFontSize < 1) or (P.MinFontSize > 36) then Invalid(FileName, 'MinFontSize');
  if (P.FontSize < P.MinFontSize) or (P.FontSize > 36) then
    Invalid(FileName, 'FontSize');
  if not (P.StartColumns in [1, 2]) then Invalid(FileName, 'StartColumns');
  E := CheckStartLabelPaper(P, G);
  if E <> lpeNone then Invalid(FileName,
      'Width/Height/Left/Right/Top/Bottom/GapX/GapY/Padding');
end;

function ReadStartLabelTemplate(const FileName: string): TStartLabelTemplate;
var
  I: TMemIniFile;
  S: string;

  function Required(const Key: string): string;
  begin
    if not I.ValueExists(Section, Key) then Invalid(FileName, Key);
    Result := Trim(I.ReadString(Section, Key, ''));
  end;

  function MM(const Key: string): integer;
  var
    V: double;
    F: TFormatSettings;
  begin
    F := DefaultFormatSettings;
    F.DecimalSeparator := '.';
    if not TryStrToFloat(Required(Key), V, F) then Invalid(FileName, Key);
    if IsNan(V) or IsInfinite(V) or (V < 0) or (V > 297) then Invalid(FileName, Key);
    if Abs(V * StartLabelUnitsPerMM - Round(V * StartLabelUnitsPerMM)) > 0.000001 then
      Invalid(FileName, Key);
    Result := Round(V * StartLabelUnitsPerMM);
  end;

  function Number(const Key: string): integer;
  begin
    if not TryStrToInt(Required(Key), Result) then Invalid(FileName, Key);
  end;

begin
  Result := Default(TStartLabelTemplate);
  if not FileExists(FileName) then
    raise EStartLabelTemplateMissing.Create(FileName + ': ' +
      rsLabelTemplateMissingFile);
  I := TMemIniFile.Create(FileName);
  try
    Result.FileName := FileName;
    Result.Name := Trim(I.ReadString(Section, 'Name', ''));
    if Result.Name = '' then Result.Name := ChangeFileExt(ExtractFileName(FileName), '');
    Result.Paper.Width := MM('Width');
    Result.Paper.Height := MM('Height');
    Result.Paper.Left := MM('Left');
    Result.Paper.Right := MM('Right');
    Result.Paper.Top := MM('Top');
    Result.Paper.Bottom := MM('Bottom');
    Result.Paper.GapX := MM('GapX');
    Result.Paper.GapY := MM('GapY');
    Result.Paper.Padding := MM('Padding');
    Result.Paper.FontSize := Number('FontSize');
    Result.Paper.MinFontSize := Number('MinFontSize');
    Result.Paper.StartColumns := Number('StartColumns');
    Result.Paper.FirstSlot := 1;
    S := LowerCase(Required('DrawBorders'));
    if (S = 'true') or (S = '1') or (S = 'yes') then Result.Paper.DrawBorders := True
    else if (S = 'false') or (S = '0') or (S = 'no') then
      Result.Paper.DrawBorders := False
    else
      Invalid(FileName, 'DrawBorders');
    Validate(FileName, Result.Paper);
  finally
    I.Free;
  end;
end;

procedure WriteStartLabelTemplate(const FileName, Name: string;
  const Paper: TStartLabelPaper);
var
  I: TMemIniFile;
begin
  Validate(FileName, Paper);
  if Trim(Name) = '' then Invalid(FileName, 'Name');
  SaveStartLabelPaper(FileName, Paper);
  I := TMemIniFile.Create(FileName);
  try
    I.WriteString(Section, 'Name', Trim(Name));
    I.UpdateFile;
  finally
    I.Free;
  end;
end;

function SameStartLabelTemplatePaper(const A, B: TStartLabelPaper): boolean;
var
  X, Y: TStartLabelPaper;
begin
  X := A;
  Y := B;
  X.FirstSlot := 1;
  Y.FirstSlot := 1;
  Result := SameStartLabelPaper(X, Y);
end;

end.
