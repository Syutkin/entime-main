unit StartLabelSettingsTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  TStartLabelSettingsTests = class(TTestCase)
  published
    procedure FractionalPaperUsesOwnSectionAndResetsFirstSlot;
    procedure InvalidAndMissingSettingsUseDefaults;
    procedure StartColumnsRoundTripAndLegacyDefault;
  end;

implementation

uses SysUtils, IniFiles, StartLabelModel, StartLabelSettings;

procedure TStartLabelSettingsTests.StartColumnsRoundTripAndLegacyDefault;
var
  P, Q: TStartLabelPaper;
  F: string;
  Ini: TMemIniFile;
begin
  F := GetTempFileName;
  try
    P := DefaultStartLabelPaper;
    AssertEquals(1, P.StartColumns);
    P.StartColumns := 2;
    SaveStartLabelPaper(F, P);
    Q := LoadStartLabelPaper(F);
    AssertEquals(2, Q.StartColumns);
    P.StartColumns := 1;
    SaveStartLabelPaper(F, P);
    Q := LoadStartLabelPaper(F);
    AssertEquals(1, Q.StartColumns);
    Ini := TMemIniFile.Create(F);
    try
      Ini.DeleteKey('StartLabels', 'StartColumns');
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    Q := LoadStartLabelPaper(F);
    AssertEquals(1, Q.StartColumns);
    Ini := TMemIniFile.Create(F);
    try
      Ini.WriteInteger('StartLabels', 'StartColumns', 3);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    Q := LoadStartLabelPaper(F);
    AssertEquals(1, Q.StartColumns);
  finally
    DeleteFile(F);
  end;
end;

procedure TStartLabelSettingsTests.FractionalPaperUsesOwnSectionAndResetsFirstSlot;
var
  P, Q: TStartLabelPaper;
  F: string;
  Ini: TMemIniFile;
begin
  F := GetTempFileName;
  try
    Ini := TMemIniFile.Create(F);
    try
      Ini.WriteString('General', 'Untouched', 'value');
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    P := DefaultStartLabelPaper;
    P.Width := 63500;
    P.Height := 29600;
    P.Left := 7000;
    P.Right := 7000;
    P.GapX := 2500;
    P.GapY := 900;
    P.Padding := 1234;
    P.FontSize := 10;
    P.MinFontSize := 7;
    P.DrawBorders := True;
    P.FirstSlot := 5;
    SaveStartLabelPaper(F, P);
    Q := LoadStartLabelPaper(F);
    AssertEquals(63500, Q.Width);
    AssertEquals(29600, Q.Height);
    AssertEquals(1234, Q.Padding);
    AssertEquals(7000, Q.Left);
    AssertEquals(2500, Q.GapX);
    AssertEquals(900, Q.GapY);
    AssertEquals(10, Q.FontSize);
    AssertEquals(7, Q.MinFontSize);
    AssertTrue(Q.DrawBorders);
    AssertEquals(1, Q.FirstSlot);
    Ini := TMemIniFile.Create(F);
    try
      AssertEquals('value', Ini.ReadString('General', 'Untouched', ''));
      AssertEquals('63.5', Ini.ReadString('StartLabels', 'Width', ''));
      AssertEquals('7', Ini.ReadString('StartLabels', 'Left', ''));
      AssertEquals('1.234', Ini.ReadString('StartLabels', 'Padding', ''));
      AssertTrue(Ini.SectionExists('StartLabels'));
      AssertFalse(Ini.ValueExists('StartLabels', 'FirstSlot'));
    finally
      Ini.Free;
    end;
  finally
    DeleteFile(F);
  end;
end;

procedure TStartLabelSettingsTests.InvalidAndMissingSettingsUseDefaults;
var
  F: string;
  P, Q: TStartLabelPaper;
  Ini: TMemIniFile;
begin
  F := GetTempFileName;
  DeleteFile(F);
  try
    Q := LoadStartLabelPaper(F);
    AssertEquals(70000, Q.Width);
    AssertEquals(1, Q.FirstSlot);
    Ini := TMemIniFile.Create(F);
    try
      Ini.WriteString('StartLabels', 'Width', 'broken');
      Ini.UpdateFile;
      Q := LoadStartLabelPaper(F);
      AssertEquals(70000, Q.Width);
      Ini.WriteString('StartLabels', 'Width', '63.50');
      Ini.WriteString('StartLabels', 'Height', '37.00');
      Ini.UpdateFile;
      Q := LoadStartLabelPaper(F);
      AssertEquals('Legacy hundredths remain millimetres', 63500, Q.Width);
      AssertEquals(37000, Q.Height);
      Ini.WriteInteger('StartLabels', 'MinFontSize', 99);
      Ini.UpdateFile;
      Q := LoadStartLabelPaper(F);
      AssertEquals(70000, Q.Width);
      AssertEquals(6, Q.MinFontSize);
    finally
      Ini.Free;
    end;
    P := DefaultStartLabelPaper;
    P.Height := 0;
    try
      SaveStartLabelPaper(F, P);
      Fail('Invalid paper must not replace valid settings');
    except
      on E: EStartLabelPaper do ;
    end;
  finally
    DeleteFile(F);
  end;
end;

initialization
  RegisterTest(TStartLabelSettingsTests);
end.
