unit ReportTemplateFilesTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry;

type
  TReportTemplateFilesTests = class(TTestCase)
  private
    Dir: string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ShippedTemplatesUseOneSnapshotForEveryFormat;
    procedure CatalogueAndExternalUnicodePaths;
    procedure FrozenSnapshotAndExplicitReload;
    procedure InvalidFilesFailWithoutChangingSnapshot;
  end;

implementation

uses FileUtil, ReportTemplateFiles, HtmlReportTemplateReader, StageFinishReportModel,
  ReportTemplateModel, StageFinishReportBuilder, StageFinishReportBackend,
  StageFinishDocxWriter,
  StageFinishXlsxWriter, StageFieldNames, fpstypes, fpspreadsheet, zipper, DOM, XMLRead;

procedure WriteHtml(const Path, Text: string);
var
  F: TFileStream;
begin
  F := TFileStream.Create(Path, fmCreate);
  try
    if Text <> '' then F.WriteBuffer(Text[1], Length(Text));
  finally
    F.Free;
  end;
end;

procedure TReportTemplateFilesTests.SetUp;
begin
  Dir := GetTempFileName;
  DeleteFile(Dir);
  Dir := Dir + ' Шаблоны';
  ForceDirectories(Dir);
end;

procedure TReportTemplateFilesTests.TearDown;
begin
  DeleteDirectory(Dir, False);
end;

procedure TReportTemplateFilesTests.CatalogueAndExternalUnicodePaths;
var
  L: TStringList;
  S: TStageReportSnapshot;
  Path: string;
begin
  L := TStringList.Create;
  S := TStageReportSnapshot.Create;
  try
    ListReportTemplates(Dir + '/missing', L);
    AssertEquals(0, L.Count);
    WriteHtml(Dir + '/b.HTML', '{{RESULTS}}');
    WriteHtml(Dir + '/a.htm', '{{RESULTS}}');
    WriteHtml(Dir + '/ignore.txt', 'x');
    ForceDirectories(Dir + '/sub');
    WriteHtml(Dir + '/sub/a.htm', '<p>Внешний</p>{{RESULTS}}');
    ListReportTemplates(Dir, L);
    AssertEquals(2, L.Count);
    AssertEquals(ExpandFileName(Dir + '/a.htm'), L[0]);
    Path := ExpandFileName(Dir + '/sub/a.htm');
    PrepareReportTemplate(S, Path);
    AssertEquals('Внешний', S.Template.Header[0].Text);
    PrepareReportTemplate(S, '');
    AssertEquals(0, Length(S.Template.Header));
    AssertEquals(0, Length(S.Template.Footer));
  finally
    S.Free;
    L.Free;
  end;
end;

procedure TReportTemplateFilesTests.FrozenSnapshotAndExplicitReload;
var
  S: TStageReportSnapshot;
  Path: string;
begin
  S := TStageReportSnapshot.Create;
  Path := Dir + '/Подписи.html';
  try
    SetLength(S.Rows, 1);
    S.Rows[0].Number := 123;
    WriteHtml(Path, #239#187#191 + '<p>Первая</p>{{RESULTS}}');
    PrepareReportTemplate(S, Path);
    WriteHtml(Path, '<p>Вторая</p>{{RESULTS}}');
    AssertEquals('Первая', S.Template.Header[0].Text);
    PrepareReportTemplate(S, Path);
    AssertEquals('Вторая', S.Template.Header[0].Text);
    DeleteFile(Path);
    AssertEquals('Вторая', S.Template.Header[0].Text);
    AssertEquals(123, S.Rows[0].Number);
  finally
    S.Free;
  end;
end;

procedure TReportTemplateFilesTests.InvalidFilesFailWithoutChangingSnapshot;
var
  S: TStageReportSnapshot;
  Path: string;
  Failed: boolean;
  I: integer;
begin
  S := TStageReportSnapshot.Create;
  Path := Dir + '/bad.html';
  try
    for I := 0 to 2 do
    begin
      if I = 0 then WriteHtml(Path, 'no marker')
      else if I = 1 then WriteHtml(Path, #255)
      else
        DeleteFile(Path);
      Failed := False;
      try
        PrepareReportTemplate(S, Path);
      except
        on E: EReportTemplateError do Failed := Pos(Path, E.Message) > 0;
      end;
      AssertTrue('Filename and reason for each load failure', Failed);
      AssertEquals(0, Length(S.Template.Header));
    end;
  finally
    S.Free;
  end;
end;

procedure TReportTemplateFilesTests.ShippedTemplatesUseOneSnapshotForEveryFormat;
var
  Paths: TStringList;
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  T: TReportTemplate;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  Z: TUnZipper;
  Xml: TXMLDocument;
  I, J, K, Orientation: integer;
  Path, Base, PdfText, DocxText, Text, SourceRoot: string;
  P: TReportParagraph;

  procedure CheckParagraph(const Value: TReportParagraph);
  var
    Lines: TStringList;
    Line: string;
    Found: boolean;
    R: integer;
  begin
    Lines := TStringList.Create;
    try
      Lines.Text := Value.Text;
      if Value.IsPair then Lines.Text := Lines.Text + Value.RightText;
      for Line in Lines do if Line <> '' then
        begin
          AssertTrue('PDF: ' + Line, Pos(Line, PdfText) > 0);
          AssertTrue('DOCX: ' + Line, Pos(Line, DocxText) > 0);
          Found := False;
          for R := 0 to Sheet.GetLastRowIndex do
            if (Sheet.ReadAsText(R, 0) = Line) or (Sheet.ReadAsText(R, 3) = Line) then Found := True;
          AssertTrue('XLSX: ' + Line, Found);
        end;
    finally
      Lines.Free;
    end;
  end;

begin
  SourceRoot := GetEnvironmentVariable('ENTIME_ROOT');
  if SourceRoot = '' then SourceRoot := GetCurrentDir;
  Paths := TStringList.Create;
  S := TStageReportSnapshot.Create;
  D := nil;
  Book := nil;
  Z := nil;
  Xml := nil;
  try
    ListReportTemplates(SourceRoot + '/templates/reports', Paths);
    AssertEquals('Two external examples', 2, Paths.Count);
    SetLength(S.Rows, 4);
    S.Options := DefaultReportOptions;
    S.RaceName := 'Competition';
    S.StageName := 'Forest';
    S.FormedAt := EncodeDate(2026, 10, 31);
    for I := 0 to 3 do
    begin
      S.Rows[I].Number := I + 1;
      S.Rows[I].Name := 'FINISHER' + IntToStr(I + 1);
      S.Rows[I].Values[sfkResult] := '00:01:00.123';
      S.Rows[I].Values[sfkPlace] := IntToStr(I + 1);
      if I < 2 then S.Rows[I].Category := 'A'
      else
        S.Rows[I].Category := 'B';
    end;
    for I := 0 to Paths.Count - 1 do for Orientation := 0 to 1 do
      begin
        S.Options.Orientation := TReportOrientation(Orientation);
        S.Options.Language := TReportLanguage(Orientation);
        S.Options.ShowHeadings := I = 0;
        S.Options.ShowFooter := Orientation = 0;
        S.Options.ShowPenalty := I = 0;
        S.Labels := ReportLabels(S.Options.Language);
        S.Rows := SelectReportRows(S.Rows, S.Options);
        PrepareReportTemplate(S, Paths[I]);
        T := S.Template;
        Base := Dir + '/example' + IntToStr(I) + '-' + IntToStr(Orientation);
        D := BuildStageFinishReport(S);
        PdfText := '';
        for J := 0 to D.PageCount - 1 do PdfText := PdfText + D.PageText(J);
        D.WritePdf(Base + '.pdf');
        AssertTrue(SaveStageFinishDocx(S, Base + '.docx'));
        AssertTrue(SaveStageFinishXlsx(S, Base + '.xlsx'));
        Z := TUnZipper.Create;
        Z.FileName := Base + '.docx';
        Z.OutputPath := IncludeTrailingPathDelimiter(ExpandFileName(Dir + '/docx'));
        Z.UnZipAllFiles;
        FreeAndNil(Z);
        ReadXMLFile(Xml, Dir + '/docx/word/document.xml');
        DocxText := UTF8Encode(Xml.DocumentElement.TextContent);
        FreeAndNil(Xml);
        Book := TsWorkbook.Create;
        Book.ReadFromFile(Base + '.xlsx', sfOOXML);
        Sheet := Book.GetWorksheetByIndex(0);
        for P in T.Header do CheckParagraph(P);
        for P in T.Footer do CheckParagraph(P);
        for K := 1 to 4 do
        begin
          Text := 'FINISHER' + IntToStr(K);
          AssertTrue(Pos(Text, PdfText) > 0);
          AssertTrue(Pos(Text, DocxText) > 0);
        end;
        Path := GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR');
        if Path <> '' then
        begin
          for J := 0 to 2 do
          begin
            case J of
              0: Text := '.pdf';
              1: Text := '.docx';
              2: Text := '.xlsx';
            end;
            CopyFile(Base + Text, IncludeTrailingPathDelimiter(Path) + ExtractFileName(Base) + Text);
          end;
        end;
        FreeAndNil(Book);
        FreeAndNil(D);
      end;
  finally
    Xml.Free;
    Z.Free;
    Book.Free;
    D.Free;
    S.Free;
    Paths.Free;
  end;
end;

initialization
  RegisterTest(TReportTemplateFilesTests);
end.
