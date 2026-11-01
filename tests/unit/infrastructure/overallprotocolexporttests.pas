unit OverallProtocolExportTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry, ProtocolDocumentModel;

type
  TOverallProtocolExportTests = class(TTestCase)
  private
    function Document(Count: integer; Detailed: boolean = True;
      Extras: boolean = True; FitToWidth: boolean = False): TProtocolDocument;
  published
    procedure CategoriesSharePagesWithoutStageSuffixes;
    procedure ResultOnlyHeadersUseStageNamesInAllFormats;
    procedure PlaceHeadersKeepWholeWord;
    procedure PartsKeepEveryStageAndRepeatSavedIdentifiers;
    procedure WidthBoundariesAndLandscape;
    procedure PdfIncludesLastStageAndTemplateOnlyOnce;
    procedure DocxHasAllStagesAndNoSyntheticStageZero;
    procedure XlsxRemainsWideAndPrintable;
    procedure FitWidthKeepsAllStageColumnsAndExports;
  end;

implementation

uses Classes, SysUtils, StrUtils, DOM, XMLRead, OverallFinishReportModel,
  StageFinishReportModel,
  ProtocolTableLayout, StageFinishReportBuilder, StageFinishReportBackend,
  StageFinishPdfWriter, StageFinishDocxWriter, StageFinishXlsxWriter,
  ReportTemplateModel, fpspreadsheet, fpstypes, xlsxooxml, zipper, FileUtil;

function TOverallProtocolExportTests.Document(Count: integer;
  Detailed: boolean; Extras: boolean; FitToWidth: boolean): TProtocolDocument;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  I, J: integer;
  T: TReportTemplate;
begin
  O := DefaultOverallReportOptions;
  O.Detailed := Detailed;
  O.StagePlaces := Extras;
  O.StageGaps := Extras;
  O.StagePenalties := Extras;
  O.FitToWidth := FitToWidth;
  SetLength(S, Count);
  SetLength(R, 2);
  for I := 0 to Count - 1 do
  begin
    S[I].Index := I + 1;
    S[I].Name := 'Лесной участок ' + IntToStr(I + 1);
  end;
  for J := 0 to 1 do
  begin
    R[J].Id := J + 1;
    R[J].Number := 123 - J;
    R[J].Name := 'Участник ' + IntToStr(J);
    R[J].Team := 'Команда';
    R[J].Category := 'A';
    R[J].Place := IntToStr(J + 5);
    R[J].ResultValue := '01:02:03.456';
    SetLength(R[J].Stages, Count);
    for I := 0 to Count - 1 do
    begin
      R[J].Stages[I].ResultValue := '00:01:' + Format('%.2d', [I]) + '.123';
      R[J].Stages[I].Penalty := '00:00:00.000';
    end;
  end;
  Result := PrepareOverallProtocol(R, S, O);
  Result.RaceName := 'Race';
  T := Default(TReportTemplate);
  SetLength(T.Header, 1);
  T.Header[0].Text := 'UNIQUE HEADER';
  T.Header[0].FontSize := 10;
  SetLength(T.Footer, 1);
  T.Footer[0].Text := 'UNIQUE FOOTER';
  T.Footer[0].FontSize := 10;
  Result.Template := T;
end;

procedure TOverallProtocolExportTests.FitWidthKeepsAllStageColumnsAndExports;
var
  D: TProtocolDocument;
  V: TProtocolDocuments;
  P: TPreparedStageReport;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  Count, Orientation, I, J: integer;
  Width, Available: single;
  Dir: string;
  Found: boolean;
begin
  Dir := GetTempFileName;
  DeleteFile(Dir);
  ForceDirectories(Dir);
  try
    for Count in [1, 8, 32] do for Orientation := 0 to 1 do
      begin
        D := Document(Count, True, True, True);
        V := nil;
        P := nil;
        Book := TsWorkbook.Create;
        try
          D.Options.Landscape := Orientation = 1;
          AssertTrue(D.Options.FitToWidth);
          V := ProtocolPrintViews(D);
          AssertEquals(1, Length(V));
          AssertEquals(6 + Count * 4, Length(V[0].Columns));
          AssertEquals('123', V[0].Rows[0].Cells[1]);
          AssertEquals('01:02:03.456', V[0].Rows[0].Cells[High(D.Columns) - 1]);
          Width := 0;
          for I := 0 to High(V[0].Columns) do Width := Width + V[0].Columns[I].Width;
          Available := 190;
          if Orientation = 1 then Available := 277;
          AssertEquals(Available, Width, 0.01);
          AssertTrue(ProtocolFontSize(V[0]) > 0);
          AssertTrue(ProtocolFontSize(V[0]) <= 8);
          P := BuildProtocolReport(D);
          AssertEquals(1, P.PageCount);
          AssertTrue(SaveStageFinishPdf(P, Dir + '/fit.pdf'));
          AssertTrue(SaveProtocolDocx(D, Dir + '/fit.docx'));
          AssertTrue(SaveProtocolXlsx(D, Dir + '/fit.xlsx'));
          Book.ReadFromFile(Dir + '/fit.xlsx', sfOOXML);
          Sheet := Book.GetWorksheetByIndex(0);
          AssertEquals(Length(D.Columns) - 1, integer(Sheet.GetLastColIndex));
          AssertEquals(1, Sheet.PageLayout.FitWidthToPages);
          AssertEquals(0, Sheet.PageLayout.FitHeightToPages);
          Found := False;
          for I := 0 to Sheet.GetLastRowIndex do for J := 0 to Sheet.GetLastColIndex do
              if Sheet.ReadAsText(I, J) = '01:' + Format('%.2d', [Count - 1]) + '.123' then
                Found := True;
          AssertTrue('Last stage result is retained', Found);
        finally
          Book.Free;
          P.Free;
          FreeProtocolDocuments(V);
          D.Free;
        end;
      end;
  finally
    DeleteDirectory(Dir, False);
  end;
end;

procedure TOverallProtocolExportTests.PartsKeepEveryStageAndRepeatSavedIdentifiers;
var
  D: TProtocolDocument;
  V: TProtocolDocuments;
  Seen: array[1..32] of integer;
  I, J, K: integer;
  W: single;
  T: TReportTemplate;
begin
  D := Document(32);
  V := nil;
  FillChar(Seen, SizeOf(Seen), 0);
  try
    V := ProtocolPrintViews(D);
    AssertTrue(Length(V) > 1);
    for I := 0 to High(V) do
    begin
      W := 0;
      AssertEquals(2, Length(V[I].Rows));
      AssertEquals('123', V[I].Rows[0].Cells[1]);
      for J := 0 to High(V[I].Columns) do
      begin
        W := W + V[I].Columns[J].Width;
        K := V[I].Columns[J].StageIndex;
        if K > 0 then Inc(Seen[K]);
      end;
      AssertTrue('part width', W <= 190.01);
      T := V[I].Template;
      AssertEquals(Ord(I = 0), Length(T.Header));
      AssertEquals(Ord(I = High(V)), Length(T.Footer));
    end;
    for I := 1 to 32 do AssertEquals('Each of four stage fields appears once',
        4, Seen[I]);
  finally
    FreeProtocolDocuments(V);
    D.Free;
  end;
end;

procedure TOverallProtocolExportTests.WidthBoundariesAndLandscape;
var
  D: TProtocolDocument;
  V: TProtocolDocuments;
  Portrait: integer;
  W: single;
  I: integer;
begin
  D := Document(8);
  try
    V := ProtocolPrintViews(D);
    Portrait := Length(V);
    FreeProtocolDocuments(V);
    D.Options.Landscape := True;
    V := ProtocolPrintViews(D);
    try
      AssertTrue(Length(V) < Portrait);
    finally
      FreeProtocolDocuments(V);
    end;
  finally
    D.Free;
  end;
  D := Document(1, False);
  try
    V := ProtocolPrintViews(D);
    try
      AssertEquals(1, Length(V));
      W := 0;
      for I := 0 to High(V[0].Columns) do W := W + V[0].Columns[I].Width;
      AssertTrue(W <= 190.01);
    finally
      FreeProtocolDocuments(V);
    end;
  finally
    D.Free;
  end;
end;

procedure TOverallProtocolExportTests.PdfIncludesLastStageAndTemplateOnlyOnce;
var
  D: TProtocolDocument;
  P: TPreparedStageReport;
  Text: string;
  I: integer;
begin
  D := Document(8);
  P := nil;
  try
    P := BuildProtocolReport(D);
    Text := '';
    for I := 0 to P.PageCount - 1 do Text := Text + P.PageText(I);
    AssertTrue(P.PageCount > 1);
    AssertTrue(Pos('01:07.123', Text) > 0);
    AssertTrue(Pos('UNIQUE HEADER', Text) > 0);
    AssertEquals(Pos('UNIQUE HEADER', Text), RPos('UNIQUE HEADER', Text));
    AssertEquals(Pos('UNIQUE FOOTER', Text), RPos('UNIQUE FOOTER', Text));
  finally
    P.Free;
    D.Free;
  end;
end;

procedure TOverallProtocolExportTests.DocxHasAllStagesAndNoSyntheticStageZero;
var
  D: TProtocolDocument;
  Dir, Target: string;
  F: TStringList;
  Z: TUnZipper;
begin
  Dir := GetTempFileName;
  DeleteFile(Dir);
  ForceDirectories(Dir);
  D := Document(8);
  F := TStringList.Create;
  try
    Target := Dir + '/out.docx';
    AssertTrue(SaveProtocolDocx(D, Target));
    Z := TUnZipper.Create;
    try
      Z.FileName := Target;
      Z.OutputPath := Dir + '/unzip';
      Z.Examine;
      Z.UnZipAllFiles;
    finally
      Z.Free;
    end;
    F.LoadFromFile(Dir + '/unzip/word/document.xml');
    AssertTrue(Pos('01:07.123', F.Text) > 0);
    AssertTrue(Pos('СУ 0', F.Text) = 0);
    AssertTrue(Pos('UNIQUE FOOTER', F.Text) > 0);
    AssertTrue('Stage headers span their columns', Pos(
      'w:gridSpan w:val="4"', F.Text) > 0);
  finally
    F.Free;
    D.Free;
    DeleteDirectory(Dir, False);
  end;
end;

procedure TOverallProtocolExportTests.XlsxRemainsWideAndPrintable;
var
  D: TProtocolDocument;
  Path: string;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  I, J: integer;
  Found: boolean;
  Z: TUnZipper;
  XML: TXMLDocument;
  Node: TDOMNode;
  Folder: string;
begin
  D := Document(32);
  Book := TsWorkbook.Create;
  Path := GetTempFileName;
  try
    AssertTrue(SaveProtocolXlsx(D, Path));
    Book.ReadFromFile(Path, sfOOXML);
    Sheet := Book.GetWorksheetByIndex(0);
    AssertEquals(133, integer(Sheet.GetLastColIndex));
    AssertTrue('wide sheet must not shrink onto one page',
      Sheet.PageLayout.FitWidthToPages <> 1);
    AssertTrue(Sheet.PageLayout.HasRepeatedCols);
    Folder := Path + '-unpacked';
    Z := TUnZipper.Create;
    try
      Z.FileName := Path;
      Z.OutputPath := Folder;
      Z.Examine;
      Z.UnZipAllFiles;
    finally
      Z.Free;
    end;
    XML := nil;
    try
      ReadXMLFile(XML, Folder + '/xl/worksheets/sheet1.xml');
      Node := XML.DocumentElement.FindNode('sheetPr');
      if Node <> nil then Node := Node.FindNode('pageSetUpPr');
      if Node <> nil then AssertTrue('Wide table must not request fitToPage in OOXML',
          TDOMElement(Node).GetAttribute('fitToPage') <> '1');
    finally
      XML.Free;
      DeleteDirectory(Folder, False);
    end;
    Found := False;
    for I := 0 to Sheet.GetLastRowIndex do for J := 0 to Sheet.GetLastColIndex do
        if Sheet.ReadAsText(I, J) = '01:31.123' then Found := True;
    AssertTrue(Found);
  finally
    Book.Free;
    D.Free;
    DeleteFile(Path);
  end;
end;

procedure TOverallProtocolExportTests.CategoriesSharePagesWithoutStageSuffixes;
var
  D: TProtocolDocument;
  V: TProtocolDocuments;
  P: TPreparedStageReport;
  I: integer;
  Text: string;
begin
  D := Document(8);
  D.Rows[1].Category := 'B';
  V := nil;
  P := nil;
  try
    V := ProtocolPrintViews(D);
    for I := 0 to High(V) do
    begin
      AssertEquals(2, Length(V[I].Rows));
      AssertEquals('A', V[I].Rows[0].Category);
      AssertEquals('B', V[I].Rows[1].Category);
    end;
    P := BuildProtocolReport(D);
    Text := P.PageText(0);
    AssertTrue(Pos('A' + LineEnding, Text) > 0);
    AssertTrue('Next category should use free space', Pos('B' + LineEnding, Text) > 0);
  finally
    P.Free;
    FreeProtocolDocuments(V);
    D.Free;
  end;
end;

procedure TOverallProtocolExportTests.PlaceHeadersKeepWholeWord;
var
  D: TProtocolDocument;
  P: TPreparedStageReport;
  Text: string;
begin
  D := Document(8);
  P := nil;
  try
    P := BuildProtocolReport(D);
    Text := P.PageText(0);
    AssertTrue('Place caption must fit without splitting its letters',
      Pos('Место' + LineEnding, Text) > 0);
  finally
    P.Free;
    D.Free;
  end;
end;

procedure TOverallProtocolExportTests.ResultOnlyHeadersUseStageNamesInAllFormats;
var
  D: TProtocolDocument;
  P: TPreparedStageReport;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  I, J: integer;
  Dir, Text: string;
  Z: TUnZipper;
  F: TStringList;
begin
  D := Document(2, True, False);
  P := nil;
  Book := TsWorkbook.Create;
  F := TStringList.Create;
  Dir := GetTempFileName;
  DeleteFile(Dir);
  ForceDirectories(Dir);
  try
    P := BuildProtocolReport(D);
    Text := P.PageText(0);
    AssertEquals('No redundant result caption in PDF', 0,
      Pos('Результат', Text));
    AssertTrue(SaveProtocolDocx(D, Dir + '/test.docx'));
    Z := TUnZipper.Create;
    try
      Z.FileName := Dir + '/test.docx';
      Z.OutputPath := Dir + '/unzip';
      Z.Examine;
      Z.UnZipAllFiles;
    finally
      Z.Free;
    end;
    F.LoadFromFile(Dir + '/unzip/word/document.xml');
    AssertEquals('No redundant result caption in DOCX', 0,
      Pos('>Результат<', F.Text));
    AssertTrue(SaveProtocolXlsx(D, Dir + '/test.xlsx'));
    Book.ReadFromFile(Dir + '/test.xlsx', sfOOXML);
    Sheet := Book.GetWorksheetByIndex(0);
    for I := 0 to Sheet.GetLastRowIndex do for J := 0 to Sheet.GetLastColIndex do
        AssertTrue('No redundant result caption in XLSX', Sheet.ReadAsText(
          I, J) <> 'Результат');
  finally
    F.Free;
    Book.Free;
    P.Free;
    D.Free;
    DeleteDirectory(Dir, False);
  end;
end;

initialization
  RegisterTest(TOverallProtocolExportTests);
end.
