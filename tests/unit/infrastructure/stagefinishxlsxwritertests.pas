unit StageFinishXlsxWriterTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry, StageFinishReportModel;

type
  TStageFinishXlsxWriterTests = class(TTestCase)
  private
    S: TStageReportSnapshot;
    Dir, Target: string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure CenterAlignmentRoundTripsForParagraphsAndCells;
    procedure LongPairedColumnsRetainAllText;
    procedure PairedSignaturesUseTheSameWorksheetRow;
    procedure OptionalPageHeaderAndBodyOrder;
    procedure TemplateRowsKeepTextFormattingAndPrintRange;
    procedure LongTemplateTextIsWrappedWithoutLoss;
    procedure SavedRowsRoundTripAsEditableCells;
    procedure OrientationFooterAndPenaltyOptions;
    procedure FailedReplacementPreservesTargetAndAllowsRetry;
    procedure InvalidSnapshotAndEmptyPathPreserveTarget;
  end;

implementation

uses ReportTemplateModel, StageFinishXlsxWriter, StageFinishReportFiles,
  StageFinishReportBackend, StageFieldNames,
  fpspreadsheet, fpstypes, xlsxooxml, FileUtil;

type
  TLockedFiles = class(TStageReportFiles)
    procedure Replace(const Temp, Target: string); override;
  end;

procedure TLockedFiles.Replace(const Temp, Target: string);
begin
  raise EInOutError.Create('Destination locked');
end;

function FindRow(Sheet: TsWorksheet; Col: integer; const Text: string): integer;
var
  R: integer;
begin
  Result := -1;
  for R := 0 to Sheet.GetLastRowIndex do
    if Sheet.ReadAsText(R, Col) = Text then Exit(R);
end;

function Contents(const Path: string): string;
var
  F: TStringList;
begin
  F := TStringList.Create;
  try
    F.LoadFromFile(Path);
    Result := F.Text;
  finally
    F.Free;
  end;
end;

procedure TStageFinishXlsxWriterTests.SetUp;
var
  I: integer;
begin
  Dir := GetTempFileName;
  DeleteFile(Dir);
  Dir := Dir + ' Протокол';
  ForceDirectories(Dir);
  Target := Dir + DirectorySeparator + 'Финиш.xlsx';
  S := TStageReportSnapshot.Create;
  S.Options := DefaultReportOptions;
  S.Labels := ReportLabels(rlRussian);
  S.RaceName := 'Гонка <&> [PageNo]';
  S.StageName := 'Лес';
  S.FormedAt := EncodeDate(2026, 10, 31);
  SetLength(S.Rows, 150);
  for I := 0 to High(S.Rows) do
  begin
    S.Rows[I].Number := I + 1;
    S.Rows[I].Name := 'Участник' + Format('%.4d', [I + 1]);
    S.Rows[I].Team := 'Команда & клуб';
    if I < 70 then S.Rows[I].Category := 'Категория A'
    else if I < 140 then S.Rows[I].Category := 'Категория B';
    S.Rows[I].Values[sfkResult] := '01:02:03.456';
    S.Rows[I].Values[sfkPlace] := IntToStr(I + 1);
    S.Rows[I].Values[sfkPenalty] := '00:00:05.000';
  end;
  S.Rows[0].Name := StringOfChar('X', 900) + 'Жю [PageNo] <&>';
  S.Rows[1].Name := '=1+1';
  S.Rows[2].Values[sfkStatus] := '1';
  S.Rows[3].Values[sfkStatus] := '2';
  S.Rows[4].GlobalStatus := '3';
  S.Rows := SelectReportRows(S.Rows, S.Options);
end;

procedure TStageFinishXlsxWriterTests.TearDown;
begin
  S.Free;
  DeleteDirectory(Dir, False);
end;

procedure TStageFinishXlsxWriterTests.SavedRowsRoundTripAsEditableCells;
var
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  I, R, Found: integer;
begin
  AssertTrue(SaveStageFinishXlsx(S, Target));
  Book := TsWorkbook.Create;
  try
    Book.ReadFromFile(Target, sfOOXML);
    AssertEquals(1, Book.GetWorksheetCount);
    Sheet := Book.GetWorksheetByIndex(0);
    AssertEquals('Use the system report font', ReportFontFamily,
      Book.GetDefaultFont.FontName);
    AssertEquals(S.RaceName, Sheet.ReadAsText(0, 0));
    AssertEquals(6, integer(Sheet.GetLastColIndex));
    Found := 0;
    for I := 0 to High(S.Rows) do
    begin
      R := FindRow(Sheet, Ord(rcName), S.Rows[I].Cells[rcName]);
      AssertTrue('Complete rider ' + IntToStr(I), R >= 0);
      Inc(Found);
      AssertEquals('Rider number is numeric', Ord(cctNumber), Ord(
        Sheet.FindCell(R, Ord(rcNumber))^.ContentType));
      AssertEquals(double(S.Rows[I].Number), Sheet.ReadAsNumber(R, Ord(rcNumber)));
      AssertEquals(S.Rows[I].Cells[rcResult], Sheet.ReadAsText(R, Ord(rcResult)));
      AssertEquals(S.Rows[I].Cells[rcPenalty], Sheet.ReadAsText(R, Ord(rcPenalty)));
      AssertEquals('User text stays literal', '', Sheet.ReadFormula(R, Ord(rcName)));
    end;
    AssertEquals(150, Found);
    for I := 0 to 2 do
    begin
      case I of
        0: R := FindRow(Sheet, 0, 'Категория A');
        1: R := FindRow(Sheet, 0, 'Категория B');
        2: R := FindRow(Sheet, 0, 'Без категории');
      end;
      AssertTrue('Category without participant count', R >= 0);
      AssertEquals('Column headings follow each category', S.Labels.Columns[rcName],
        Sheet.ReadAsText(R + 1, Ord(rcName)));
      AssertEquals('Results immediately follow the headings', Ord(cctNumber),
        Ord(Sheet.FindCell(R + 2, Ord(rcNumber))^.ContentType));
    end;
    AssertTrue(FindRow(Sheet, Ord(rcResult), 'DNS') >= 0);
    AssertTrue(FindRow(Sheet, Ord(rcResult), 'DNF') >= 0);
    AssertTrue(FindRow(Sheet, Ord(rcResult), 'DSQ') >= 0);
    R := FindRow(Sheet, Ord(rcName), '=1+1');
    Sheet.WriteText(R, Ord(rcName), 'Исправлено вручную');
    Book.WriteToFile(Target, sfOOXML, True);
  finally
    Book.Free;
  end;
  Book := TsWorkbook.Create;
  try
    Book.ReadFromFile(Target, sfOOXML);
    AssertTrue(FindRow(Book.GetWorksheetByIndex(0), Ord(rcName),
      'Исправлено вручную') >= 0);
  finally
    Book.Free;
  end;
  AssertEquals('Source snapshot stays intact', 900 + Length('Жю [PageNo] <&>'),
    Length(S.Rows[0].Name));
end;

procedure TStageFinishXlsxWriterTests.OrientationFooterAndPenaltyOptions;
var
  O, F, P: integer;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  Footer, Path: string;
begin
  for O := 0 to 1 do for F := 0 to 1 do for P := 0 to 1 do
      begin
        S.Options.Orientation := TReportOrientation(O);
        S.Options.ShowFooter := F = 1;
        S.Options.ShowPenalty := P = 1;
        S.Options.Language := TReportLanguage(O);
        S.Labels := ReportLabels(S.Options.Language);
        AssertTrue(SaveStageFinishXlsx(S, Target));
        Book := TsWorkbook.Create;
        try
          Book.ReadFromFile(Target, sfOOXML);
          Sheet := Book.GetWorksheetByIndex(0);
          AssertEquals('Column count', 5 + P, integer(Sheet.GetLastColIndex));
          AssertEquals(P = 1, FindRow(Sheet, Ord(rcPenalty), S.Labels.Columns[rcPenalty]) >= 0);
          AssertEquals(Ord(TsPageOrientation(O)), Ord(Sheet.PageLayout.Orientation));
          AssertEquals(1, Sheet.PageLayout.FitWidthToPages);
          AssertEquals(0, Sheet.PageLayout.FitHeightToPages);
          Footer := Sheet.PageLayout.Footers[1];
          if F = 0 then AssertEquals('', Footer)
          else
          begin
            AssertTrue(Pos('2026-10-31 00:00:00', Footer) > 0);
            AssertTrue(Pos('&P', Footer) > 0);
            AssertTrue(Pos('&N', Footer) > 0);
          end;
          AssertFalse(Sheet.PageLayout.HasRepeatedRows);
          AssertTrue(Pos(S.Labels.Title, Sheet.PageLayout.Headers[1]) > 0);
          AssertEquals(1, Sheet.PageLayout.NumPrintRanges);
        finally
          Book.Free;
        end;
        Path := GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR');
        if Path <> '' then CopyFile(Target, Path + '/finish-xlsx-' + IntToStr(O) +
            '-' + IntToStr(F) + '-' + IntToStr(P) + '.xlsx');
      end;
end;

procedure TStageFinishXlsxWriterTests.FailedReplacementPreservesTargetAndAllowsRetry;
var
  Files: TLockedFiles;
  Old: TStringList;
  Raised: boolean;
  R: TSearchRec;
  N: integer;
begin
  Old := TStringList.Create;
  try
    Old.Text := 'old workbook';
    Old.SaveToFile(Target);
  finally
    Old.Free;
  end;
  Files := TLockedFiles.Create;
  Raised := False;
  try
    try
      SaveStageFinishXlsx(S, Target, Files);
    except
      on E: EInOutError do Raised := True;
    end;
  finally
    Files.Free;
  end;
  AssertTrue(Raised);
  AssertEquals('old workbook' + LineEnding, Contents(Target));
  N := 0;
  if FindFirst(Dir + '/*', faAnyFile, R) = 0 then
  begin
    repeat
      if (R.Name <> '.') and (R.Name <> '..') then Inc(N);
    until FindNext(R) <> 0;
    FindClose(R);
  end;
  AssertEquals('No temporary files left', 1, N);
  AssertTrue(SaveStageFinishXlsx(S, Target));
end;

procedure TStageFinishXlsxWriterTests.InvalidSnapshotAndEmptyPathPreserveTarget;
var
  Raised: boolean;
  Old: TStringList;
begin
  AssertFalse(SaveStageFinishXlsx(S, ''));
  AssertFalse(FileExists(Target));
  Old := TStringList.Create;
  try
    Old.Text := 'old workbook';
    Old.SaveToFile(Target);
  finally
    Old.Free;
  end;
  Raised := False;
  try
    SaveStageFinishXlsx(nil, Target);
  except
    on E: EArgumentNilException do Raised := True;
  end;
  AssertTrue(Raised);
  AssertEquals('old workbook' + LineEnding, Contents(Target));
  S.Rows := nil;
  Raised := False;
  try
    SaveStageFinishXlsx(S, Target);
  except
    on E: EArgumentException do Raised := True;
  end;
  AssertTrue(Raised);
  AssertEquals('old workbook' + LineEnding, Contents(Target));
end;

procedure TStageFinishXlsxWriterTests.TemplateRowsKeepTextFormattingAndPrintRange;
var
  T: TReportTemplate;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  A, P, R, Last: integer;
  R1, C1, R2, C2: cardinal;
begin
  SetLength(T.Header, 2);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('ШАПКА [PageNo]' + #10#10 + 'Вторая', 14, rpaRight);
  T.Header[1] := ReportParagraph('');
  T.Footer[0] := ReportParagraph('=ПОДПИСЬ <&>', 12);
  S.Template := T;
  for A := 0 to 1 do for P := 0 to 1 do
    begin
      S.Options.ShowHeadings := A = 1;
      S.Options.ShowPenalty := P = 1;
      S.Options.ShowFooter := False;
      S.Options.Orientation := TReportOrientation(A);
      AssertTrue(SaveStageFinishXlsx(S, Target));
      Book := TsWorkbook.Create;
      try
        Book.ReadFromFile(Target, sfOOXML);
        Sheet := Book.GetWorksheetByIndex(0);
        R := FindRow(Sheet, 0, 'ШАПКА [PageNo]');
        AssertEquals(0, R);
        AssertEquals(14, Round(Sheet.ReadCellFont(Sheet.FindCell(R, 0)).Size));
        AssertEquals(Ord(haRight), Ord(Sheet.ReadHorAlignment(Sheet.FindCell(R, 0))));
        AssertEquals('', Sheet.ReadAsText(R + 1, 0));
        AssertEquals('Вторая', Sheet.ReadAsText(R + 2, 0));
        AssertTrue(Sheet.FindMergedRange(Sheet.FindCell(R, 0), R1, C1, R2, C2));
        AssertEquals(5 + P, integer(C2));
        AssertFalse(Sheet.PageLayout.HasRepeatedRows);
        AssertEquals('', Sheet.PageLayout.Footers[1]);
        Last := FindRow(Sheet, 0, '=ПОДПИСЬ <&>');
        AssertTrue(Last > FindRow(Sheet, 2, 'Участник0150'));
        AssertEquals('', Sheet.ReadFormula(Last, 0));
        AssertEquals(Last, integer(Sheet.PageLayout.PrintRange[0].Row2));
        AssertEquals(A = 1, FindRow(Sheet, 0, S.RaceName) >= 0);
        if (A = 1) and (P = 0) and (GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') <> '') then
          CopyFile(Target, GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') +
            '/html-template.xlsx');
      finally
        Book.Free;
      end;
    end;
end;

procedure TStageFinishXlsxWriterTests.LongTemplateTextIsWrappedWithoutLoss;
var
  T: TReportTemplate;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  I, J, R, Start: integer;
  V, Text: string;
begin
  V := '';
  for I := 1 to 600 do V := V + 'Жю';
  SetLength(T.Header, 1);
  T.Header[0] := ReportParagraph(V, 36);
  S.Template := T;
  for J := 0 to 1 do
  begin
    S.Options.Orientation := TReportOrientation(J);
    AssertTrue(SaveStageFinishXlsx(S, Target));
    Book := TsWorkbook.Create;
    try
      Book.ReadFromFile(Target, sfOOXML);
      Sheet := Book.GetWorksheetByIndex(0);
      Start := 0;
      R := FindRow(Sheet, 0, S.RaceName);
      Text := '';
      AssertTrue(R > Start + 1);
      for I := Start to R - 1 do
      begin
        Text := Text + Sheet.ReadAsText(I, 0);
        AssertTrue('Large font is not clipped', Sheet.GetRowHeight(I, suPoints) > 36);
      end;
      AssertEquals(V, Text);
    finally
      Book.Free;
    end;
  end;
end;

procedure TStageFinishXlsxWriterTests.OptionalPageHeaderAndBodyOrder;
var
  T: TReportTemplate;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  H, BodyOn: integer;
begin
  SetLength(T.Header, 1);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('CUSTOMHEADER');
  T.Footer[0] := ReportParagraph('CUSTOMFOOTER');
  S.Template := T;
  S.StageName := 'Literal &P &N';
  for H := 0 to 1 do for BodyOn := 0 to 1 do
    begin
      S.Options.ShowHeader := H = 1;
      S.Options.ShowHeadings := BodyOn = 1;
      S.Options.ShowFooter := False;
      AssertTrue(SaveStageFinishXlsx(S, Target));
      Book := TsWorkbook.Create;
      try
        Book.ReadFromFile(Target, sfOOXML);
        Sheet := Book.GetWorksheetByIndex(0);
        AssertEquals('CUSTOMHEADER', Sheet.ReadAsText(0, 0));
        AssertEquals(BodyOn = 1, FindRow(Sheet, 0, S.RaceName) >= 0);
        AssertEquals(BodyOn = 1, Pos(S.Labels.Title, Sheet.ReadAsText(2, 0)) > 0);
        AssertTrue(FindRow(Sheet, 0, 'CUSTOMFOOTER') > FindRow(Sheet, 2, 'Участник0150'));
        AssertEquals(H = 1, Pos(S.Labels.Title, Sheet.PageLayout.Headers[1]) > 0);
        if H = 1 then AssertTrue(Pos('Literal &&P &&N', Sheet.PageLayout.Headers[1]) > 0);
        AssertEquals('', Sheet.PageLayout.Footers[1]);
        AssertFalse(Sheet.PageLayout.HasRepeatedRows);
      finally
        Book.Free;
      end;
    end;
end;

procedure TStageFinishXlsxWriterTests.PairedSignaturesUseTheSameWorksheetRow;
var
  T: TReportTemplate;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  O, P, R: integer;
  A, B, C, D: cardinal;
begin
  SetLength(T.Footer, 1);
  T.Footer[0] := ReportParagraphPair(ReportParagraph('JUDGETOKEN', 12),
    ReportParagraph('=SECRETARYTOKEN', 10, rpaRight));
  S.Template := T;
  for O := 0 to 1 do for P := 0 to 1 do
    begin
      S.Options.Orientation := TReportOrientation(O);
      S.Options.ShowPenalty := P = 1;
      AssertTrue(SaveStageFinishXlsx(S, Target));
      Book := TsWorkbook.Create;
      try
        Book.ReadFromFile(Target, sfOOXML);
        Sheet := Book.GetWorksheetByIndex(0);
        R := FindRow(Sheet, 0, 'JUDGETOKEN');
        AssertTrue(R >= 0);
        AssertEquals('=SECRETARYTOKEN', Sheet.ReadAsText(R, 3));
        AssertEquals('', Sheet.ReadFormula(R, 3));
        AssertTrue(Sheet.FindMergedRange(Sheet.FindCell(R, 0), A, B, C, D));
        AssertEquals(2, integer(D));
        AssertTrue(Sheet.FindMergedRange(Sheet.FindCell(R, 3), A, B, C, D));
        AssertEquals(5 + P, integer(D));
        AssertEquals(Ord(haRight), Ord(Sheet.ReadHorAlignment(Sheet.FindCell(R, 3))));
      finally
        Book.Free;
      end;
    end;
  if GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') <> '' then
    CopyFile(Target, GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') +
      '/paired-signatures.xlsx');
end;

procedure TStageFinishXlsxWriterTests.LongPairedColumnsRetainAllText;
var
  T: TReportTemplate;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  L, R, OutL, OutR: string;
  I, First: integer;
  A, B, C, D: cardinal;
begin
  L := '';
  R := '';
  for I := 1 to 100 do L := L + 'Жю';
  for I := 1 to 400 do R := R + 'ДлиннаяСтрока';
  SetLength(T.Footer, 1);
  T.Footer[0] := ReportParagraphPair(ReportParagraph(L, 12), ReportParagraph(R, 14, rpaRight));
  S.Template := T;
  AssertTrue(SaveStageFinishXlsx(S, Target));
  Book := TsWorkbook.Create;
  try
    Book.ReadFromFile(Target, sfOOXML);
    Sheet := Book.GetWorksheetByIndex(0);
    First := FindRow(Sheet, 2, 'Участник0150') + 1;
    OutL := '';
    OutR := '';
    for I := First to Sheet.GetLastRowIndex do
    begin
      OutL := OutL + Sheet.ReadAsText(I, 0);
      OutR := OutR + Sheet.ReadAsText(I, 3);
      AssertTrue(Sheet.FindMergedRange(Sheet.FindCell(I, 0), A, B, C, D));
      AssertEquals(2, integer(D));
      AssertTrue(Sheet.FindMergedRange(Sheet.FindCell(I, 3), A, B, C, D));
      AssertEquals(6, integer(D));
      AssertTrue(Sheet.GetRowHeight(I, suPoints) > 14);
    end;
    AssertEquals(L, OutL);
    AssertEquals(R, OutR);
  finally
    Book.Free;
  end;
end;

procedure TStageFinishXlsxWriterTests.CenterAlignmentRoundTripsForParagraphsAndCells;
var
  T: TReportTemplate;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  O, P, R, I: integer;
begin
  SetLength(T.Header, 1);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('CENTERWHOLE', 14, rpaCenter);
  T.Footer[0] := ReportParagraphPair(ReportParagraph('CENTERLEFT', 10, rpaCenter),
    ReportParagraph('CENTERRIGHT', 12, rpaCenter));
  S.Template := T;
  SetLength(S.Rows, 2);
  for I := 0 to 1 do S.Rows[I].Cells[rcName] := 'Participant ' + IntToStr(I + 1);
  for O := 0 to 1 do for P := 0 to 1 do
    begin
      S.Options.Orientation := TReportOrientation(O);
      S.Options.ShowPenalty := P = 1;
      AssertTrue(SaveStageFinishXlsx(S, Target));
      Book := TsWorkbook.Create;
      try
        Book.ReadFromFile(Target, sfOOXML);
        Sheet := Book.GetWorksheetByIndex(0);
        R := FindRow(Sheet, 0, 'CENTERWHOLE');
        AssertTrue(R >= 0);
        AssertEquals(Ord(haCenter), Ord(Sheet.ReadHorAlignment(Sheet.FindCell(R, 0))));
        R := FindRow(Sheet, 0, 'CENTERLEFT');
        AssertTrue(R >= 0);
        AssertEquals('CENTERRIGHT', Sheet.ReadAsText(R, 3));
        AssertEquals(Ord(haCenter), Ord(Sheet.ReadHorAlignment(Sheet.FindCell(R, 0))));
        AssertEquals(Ord(haCenter), Ord(Sheet.ReadHorAlignment(Sheet.FindCell(R, 3))));
      finally
        Book.Free;
      end;
    end;
  if GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') <> '' then
    CopyFile(Target, GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') +
      '/template-center.xlsx');
end;

initialization
  RegisterTest(TStageFinishXlsxWriterTests);
end.
