unit StageFinishReportBackendTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry;

type
  TStageFinishReportBackendTests = class(TTestCase)
  published
    procedure PreparedPagesExportWithSystemCyrillicFont;
    procedure InstalledRegularAndBoldFontsSupportCyrillic;
    procedure UnknownPaperFailsBeforePagination;
    procedure RepeatedLoadingKeepsTheSameFontFaces;
  end;

implementation

uses StageFinishReportBackend, fpreport, fpTTF;

procedure TStageFinishReportBackendTests.PreparedPagesExportWithSystemCyrillicFont;
var
  D: TPreparedStageReport;
  P: TFPReportPage;
  B: TFPReportTitleBand;
  M: TFPReportMemo;
  I: integer;
  Path: string;
  F: TFileStream;
  Header: array[0..4] of char;
begin
  D := TPreparedStageReport.Create;
  try
    for I := 1 to 2 do
    begin
      P := TFPReportPage.Create(D.Report);
      P.PageSize.PaperName := 'A4';
      P.Font.Name := ReportRegularFont;
      B := TFPReportTitleBand.Create(P);
      B.Layout.Height := 30;
      M := TFPReportMemo.Create(B);
      M.Layout.Width := 180;
      M.Layout.Height := 20;
      M.Text := 'Финишный протокол — Иван Иванов';
    end;
    D.Prepare;
    AssertEquals(2, D.PageCount);
    Path := GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR');
    if Path = '' then Path := GetTempDir;
    Path := IncludeTrailingPathDelimiter(Path) + 'entime-report-probe.pdf';
    D.WritePdf(Path);
    F := TFileStream.Create(Path, fmOpenRead);
    try
      F.ReadBuffer(Header, 5);
      AssertEquals('%PDF-', string(Header));
    finally
      F.Free;
    end;
    AssertEquals('PDF export must retain the prepared pages', 2, D.PageCount);
  finally
    D.Free;
  end;
end;

procedure TStageFinishReportBackendTests.InstalledRegularAndBoldFontsSupportCyrillic;
var
  Regular, Bold: TFPFontCacheItem;
begin
  LoadReportFonts;
  Regular := gTTFontCache.Find(ReportRegularFont);
  Bold := gTTFontCache.Find(ReportBoldFont);
  AssertTrue('System regular face is available', Regular <> nil);
  AssertTrue('System bold face is available', Bold <> nil);
  AssertTrue(FileExists(Regular.FileName));
  AssertTrue(FileExists(Bold.FileName));
  AssertFalse(Regular.IsBold);
  AssertTrue(Bold.IsBold);
  AssertFalse(Regular.IsItalic);
  AssertFalse(Bold.IsItalic);
  AssertEquals(ReportFontFamily, Regular.FamilyName);
  AssertEquals(ReportFontFamily, Bold.FamilyName);
  AssertTrue('Regular Cyrillic Ж', Regular.FontData.GetGlyphIndex($0416) > 0);
  AssertTrue('Bold Cyrillic я', Bold.FontData.GetGlyphIndex($044F) > 0);
  AssertEquals('No project font resource is required', 0, Pos(
    '/resources/fonts/', Regular.FileName));
end;

procedure TStageFinishReportBackendTests.UnknownPaperFailsBeforePagination;
var
  D: TPreparedStageReport;
  P: TFPReportPage;
begin
  D := TPreparedStageReport.Create;
  try
    P := TFPReportPage.Create(D.Report);
    P.PageSize.PaperName := 'unknown';
    try
      D.Prepare;
      Fail('Unknown paper must fail before pagination');
    except
      on E: EArgumentException do ;
    end;
  finally
    D.Free;
  end;
end;

procedure TStageFinishReportBackendTests.RepeatedLoadingKeepsTheSameFontFaces;
var
  Regular, Bold: TFPFontCacheItem;
  Count: integer;
begin
  LoadReportFonts;
  Regular := gTTFontCache.Find(ReportRegularFont);
  Bold := gTTFontCache.Find(ReportBoldFont);
  Count := gTTFontCache.Count;
  LoadReportFonts;
  AssertSame(Regular, gTTFontCache.Find(ReportRegularFont));
  AssertSame(Bold, gTTFontCache.Find(ReportBoldFont));
  AssertEquals('Do not reload fonts on every report', Count, gTTFontCache.Count);
end;

initialization
  RegisterTest(TStageFinishReportBackendTests);
end.
