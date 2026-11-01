unit StartLabelTemplateTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry, StartLabelModel;

type
  TStartLabelTemplateTests = class(TTestCase)
  private
    Path: string;
    procedure Change(const Key, Value: string; Delete: boolean = False);
    procedure Reject(const Key, Value: string; Delete: boolean = False);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ThousandthsPreserveExactSheetAndRoundTrip;
    procedure FullRoundTripAndInvariantDecimals;
    procedure OptionalNameAndUnknownKeys;
    procedure RequiredFieldsAreNotDefaulted;
    procedure InvalidValuesAreRejected;
    procedure InvalidWriteDoesNotChangeFile;
    procedure ComparisonIgnoresOnlyFirstSlot;
    procedure BundledFormatsBuildDocuments;
  end;

implementation

uses IniFiles, StartLabelTemplates, StartLabelReportBuilder;

procedure TStartLabelTemplateTests.SetUp;
begin
  Path := GetTempFileName;
  DeleteFile(Path);
  WriteStartLabelTemplate(Path, 'Бумага × тест', DefaultStartLabelPaper);
end;

procedure TStartLabelTemplateTests.TearDown;
begin
  DeleteFile(Path);
end;

procedure TStartLabelTemplateTests.Change(const Key, Value: string; Delete: boolean);
var
  I: TMemIniFile;
begin
  I := TMemIniFile.Create(Path);
  try
    if Delete then I.DeleteKey('StartLabels', Key)
    else
      I.WriteString('StartLabels', Key, Value);
    I.UpdateFile;
  finally
    I.Free;
  end;
end;

procedure TStartLabelTemplateTests.Reject(const Key, Value: string; Delete: boolean);
var
  R: TStartLabelTemplate;
begin
  WriteStartLabelTemplate(Path, 'Test', DefaultStartLabelPaper);
  Change(Key, Value, Delete);
  try
    R := ReadStartLabelTemplate(Path);
    Fail('Accepted invalid ' + Key + '=' + Value + ' ' + R.Name);
  except
    on E: EStartLabelTemplate do
    begin
      AssertTrue('Error contains path', Pos(Path, E.Message) > 0);
      AssertTrue('Error contains key', Pos(Key, E.Message) > 0);
    end;
  end;
end;

procedure TStartLabelTemplateTests.ThousandthsPreserveExactSheetAndRoundTrip;
var
  R, Saved: TStartLabelTemplate;
  L: TStartLabelLayout;
  I: TMemIniFile;
begin
  Change('Height', '37.125');
  Change('Top', '0');
  Change('Bottom', '0');
  R := ReadStartLabelTemplate(Path);
  AssertEquals(37125, R.Paper.Height);
  L := PlaceStartLabels(25, R.Paper);
  AssertEquals(24, L.Grid.Capacity);
  AssertEquals(2, L.PageCount);
  AssertEquals(297000, L.Placements[23].Y + L.Placements[23].Height);
  WriteStartLabelTemplate(Path, R.Name, R.Paper);
  Saved := ReadStartLabelTemplate(Path);
  AssertTrue(SameStartLabelPaper(R.Paper, Saved.Paper));
  I := TMemIniFile.Create(Path);
  try
    AssertEquals('37.125', I.ReadString('StartLabels', 'Height', ''));
    AssertEquals('70', I.ReadString('StartLabels', 'Width', ''));
    AssertEquals('0', I.ReadString('StartLabels', 'Top', ''));
  finally
    I.Free;
  end;
end;

procedure TStartLabelTemplateTests.FullRoundTripAndInvariantDecimals;
var
  P: TStartLabelPaper;
  R: TStartLabelTemplate;
  F: TFormatSettings;
  I: TMemIniFile;
begin
  P := DefaultStartLabelPaper;
  P.Left := 1250;
  P.Right := 2370;
  P.GapX := 500;
  P.GapY := 250;
  P.Padding := 1230;
  P.Top := 1260;
  P.Bottom := 3490;
  P.FontSize := 12;
  P.MinFontSize := 5;
  P.StartColumns := 2;
  P.DrawBorders := True;
  P.FirstSlot := 2;
  F := DefaultFormatSettings;
  DefaultFormatSettings.DecimalSeparator := ',';
  try
    WriteStartLabelTemplate(Path, 'Лист — 24 наклейки', P);
    R := ReadStartLabelTemplate(Path);
    AssertEquals('Лист — 24 наклейки', R.Name);
    AssertEquals(Path, R.FileName);
    AssertTrue(SameStartLabelTemplatePaper(P, R.Paper));
    AssertEquals(1, R.Paper.FirstSlot);
    I := TMemIniFile.Create(Path);
    try
      AssertEquals('1.25', I.ReadString('StartLabels', 'Left', ''));
      AssertFalse(I.ValueExists('StartLabels', 'FirstSlot'));
    finally
      I.Free;
    end;
  finally
    DefaultFormatSettings := F;
  end;
end;

procedure TStartLabelTemplateTests.OptionalNameAndUnknownKeys;
var
  R: TStartLabelTemplate;
begin
  Change('Name', '', True);
  Change('FirstSlot', '999');
  Change('Future', 'something');
  R := ReadStartLabelTemplate(Path);
  AssertEquals(ChangeFileExt(ExtractFileName(Path), ''), R.Name);
  AssertEquals(1, R.Paper.FirstSlot);
  Change('Name', '   ');
  R := ReadStartLabelTemplate(Path);
  AssertEquals(ChangeFileExt(ExtractFileName(Path), ''), R.Name);
  Change('DrawBorders', '0');
  R := ReadStartLabelTemplate(Path);
  AssertFalse(R.Paper.DrawBorders);
  Change('DrawBorders', 'true');
  R := ReadStartLabelTemplate(Path);
  AssertTrue(R.Paper.DrawBorders);
end;

procedure TStartLabelTemplateTests.RequiredFieldsAreNotDefaulted;
const
  Keys: array[0..12] of string = ('Width', 'Height', 'Left', 'Right', 'Top',
    'Bottom', 'GapX', 'GapY', 'Padding', 'FontSize', 'MinFontSize',
    'StartColumns', 'DrawBorders');
var
  K: string;
begin
  for K in Keys do Reject(K, '', True);
end;

procedure TStartLabelTemplateTests.InvalidValuesAreRejected;
begin
  Reject('Width', 'broken');
  Reject('Width', '70.0001');
  Reject('Width', '211');
  Reject('Left', '1,25');
  Reject('Left', 'nan');
  Reject('Left', 'inf');
  Reject('Left', '0.0001');
  Reject('FontSize', '37');
  Reject('FontSize', '5');
  Reject('MinFontSize', '0');
  Reject('StartColumns', '3');
  Reject('DrawBorders', 'wat');
  Change('Width', '70.00');
end;

procedure TStartLabelTemplateTests.InvalidWriteDoesNotChangeFile;
var
  P: TStartLabelPaper;
  R: TStartLabelTemplate;
begin
  P := DefaultStartLabelPaper;
  P.FontSize := 37;
  try
    WriteStartLabelTemplate(Path, 'Invalid', P);
    Fail('Invalid write accepted');
  except
    on E: EStartLabelTemplate do ;
  end;
  R := ReadStartLabelTemplate(Path);
  AssertEquals('Бумага × тест', R.Name);
end;

procedure TStartLabelTemplateTests.BundledFormatsBuildDocuments;
const
  Files: array[0..5] of string = ('70x37.125.ini', '70x49.5.ini',
    '70x36.ini', '70x32.ini', '64x34.ini', '64x30.ini');
  Widths: array[0..5] of integer = (70000, 70000, 70000, 70000, 64000, 64000);
  Heights: array[0..5] of integer = (37125, 49500, 36000, 32000, 34000, 30000);
  Rows: array[0..5] of integer = (8, 6, 8, 9, 8, 9);
  Sides: array[0..5] of integer = (0, 0, 0, 0, 9000, 9000);
  Ends: array[0..5] of integer = (0, 0, 4500, 4500, 12500, 13500);
var
  N, I: integer;
  R: TStartLabelTemplate;
  G: TStartLabelGrid;
  Cards: TStartLabelCards;
  D: TStartLabelReport;
  Pdf: string;
begin
  SetLength(Cards, 1);
  Cards[0].Title := '123 Участник';
  SetLength(Cards[0].Entries, 6);
  for I := 0 to 5 do
  begin
    Cards[0].Entries[I].StageIndex := I + 1;
    Cards[0].Entries[I].Time := '10:12:34.567';
  end;
  for N := 0 to High(Files) do
  begin
    R := ReadStartLabelTemplate(IncludeTrailingPathDelimiter(
      GetEnvironmentVariable('ENTIME_ROOT')) + 'templates/labels/' + Files[N]);
    AssertEquals(Ord(lpeNone), Ord(CheckStartLabelPaper(R.Paper, G)));
    AssertEquals(3, G.Columns);
    AssertEquals(Rows[N], G.Rows);
    AssertEquals(3 * Rows[N], G.Capacity);
    AssertEquals(Widths[N], R.Paper.Width);
    AssertEquals(Heights[N], R.Paper.Height);
    AssertEquals(Sides[N], R.Paper.Left);
    AssertEquals(Sides[N], R.Paper.Right);
    AssertEquals(Ends[N], R.Paper.Top);
    AssertEquals(R.Paper.Top, R.Paper.Bottom);
    AssertEquals(0, R.Paper.GapX);
    AssertEquals(0, R.Paper.GapY);
    D := BuildStartLabelReport(Cards, R.Paper);
    try
      AssertEquals(1, D.PageCount);
      AssertEquals(0, D.OverflowCount);
      Pdf := Path + '.pdf';
      D.WritePdf(Pdf);
      AssertTrue(FileExists(Pdf));
    finally
      D.Free;
      DeleteFile(Pdf);
    end;
  end;
end;

procedure TStartLabelTemplateTests.ComparisonIgnoresOnlyFirstSlot;
var
  A, B: TStartLabelPaper;
begin
  A := DefaultStartLabelPaper;
  B := A;
  B.FirstSlot := 20;
  AssertTrue(SameStartLabelTemplatePaper(A, B));
  B.StartColumns := 2;
  AssertFalse(SameStartLabelTemplatePaper(A, B));
  B := A;
  B.DrawBorders := True;
  AssertFalse(SameStartLabelTemplatePaper(A, B));
end;

initialization
  RegisterTest(TStartLabelTemplateTests);
end.
