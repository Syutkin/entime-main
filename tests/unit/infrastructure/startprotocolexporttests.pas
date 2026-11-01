unit StartProtocolExportTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry, ProtocolDocumentModel;

type
  TStartProtocolExportTests = class(TTestCase)
  private
    function Document(Count: integer; single: boolean = False;
      English: boolean = False): TProtocolDocument;
  published
    procedure ContinuousNumberListWithoutTeamSurvivesAllWriters;
    procedure WideWithoutTeamRepeatsOnlyParticipantColumns;
    procedure ContinuousNumberListRepeatsColumnsOnEveryPage;
    procedure CompletedCategoryHeadersAreNotRepeatedWithoutRows;
    procedure CategoryContinuationStillRepeatsHeader;
    procedure HidingTeamRedistributesFitWidthAcrossRemainingColumns;
    procedure NarrowXlsxWithoutTeamFillsPageWidth;
    procedure FitWidthKeepsThirtyTwoStagesTogether;
    procedure SeparateStagesStartNewPagesInAllFormats;
    procedure CategoryStartOrderSurvivesAllWriters;
    procedure ClockColumnsSurviveAllWriters;
    procedure WidePartsRepeatIdentifiersAndKeepEveryClock;
    procedure TemplatesSurroundResultsAndFlagsRemainIndependent;
    procedure CategoriesSharePagesAndHeadersRepeat;
  end;

implementation

uses Classes, SysUtils, StrUtils, StartReportModel, ProtocolTableLayout,
  StageFinishReportBuilder,
  StageFinishReportBackend, StageFinishPdfWriter, StageFinishDocxWriter,
  StageFinishXlsxWriter,
  ReportTemplateFiles, fpspreadsheet, fpstypes, xlsxooxml, zipper, FileUtil;

function TStartProtocolExportTests.Document(Count: integer; single: boolean;
  English: boolean): TProtocolDocument;
var
  S: TStartStageInfos;
  R: TStartReportRows;
  O: TStartReportOptions;
  I, J: integer;
begin
  O := DefaultStartReportOptions;
  if single then O.Mode := srmSingleStage;
  if English then O.View.Language := rlEnglish;
  SetLength(S, Count);
  SetLength(R, 2);
  for I := 0 to Count - 1 do
  begin
    S[I].Index := I + 1;
    S[I].Name := 'Stage ' + IntToStr(I + 1);
    S[I].IsActive := True;
  end;
  for J := 0 to 1 do
  begin
    R[J].Id := J + 1;
    R[J].Number := 123 - J;
    R[J].Name := 'Rider ' + IntToStr(J);
    R[J].Team := 'Team';
    R[J].Category := 'Category A';
    SetLength(R[J].Starts, Count);
    for I := 0 to Count - 1 do R[J].Starts[I] := '09:' + Format('%.2d', [I]) + ':00.123';
  end;
  R[1].Starts[0] := '00:00:00.000';
  Result := PrepareStartProtocol(R, S, O);
  Result.RaceName := 'Start race';
end;

procedure TStartProtocolExportTests.WideWithoutTeamRepeatsOnlyParticipantColumns;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
  V: TProtocolDocuments;
  B: TsWorkbook;
  Sheet: TsWorksheet;
  I: integer;
  Path: string;
begin
  SetLength(R, 1);
  R[0].Number := 123;
  R[0].Name := 'Rider';
  R[0].Category := 'Hidden category';
  SetLength(R[0].Starts, 32);
  SetLength(S, 32);
  for I := 0 to 31 do
  begin
    S[I].Index := I + 1;
    S[I].IsActive := True;
    R[0].Starts[I] := '09:' + Format('%.2d', [I]) + ':00.123';
  end;
  O := DefaultStartReportOptions;
  O.ShowTeam := False;
  O.Order := sroNumber;
  D := PrepareStartProtocol(R, S, O);
  V := nil;
  B := TsWorkbook.Create;
  Path := GetTempFileName;
  try
    V := ProtocolPrintViews(D);
    AssertTrue(Length(V) > 1);
    for I := 0 to High(V) do
    begin
      AssertEquals('123', V[I].Rows[0].Cells[0]);
      AssertEquals('Rider', V[I].Rows[0].Cells[1]);
      AssertTrue(V[I].Columns[2].StageIndex > 0);
      AssertTrue(V[I].Options.HideCategories);
    end;
    AssertTrue(SaveProtocolXlsx(D, Path));
    B.ReadFromFile(Path, sfOOXML);
    Sheet := B.GetWorksheetByIndex(0);
    AssertEquals(33, integer(Sheet.GetLastColIndex));
    AssertTrue(Sheet.PageLayout.HasRepeatedCols);
    AssertEquals(0, integer(Sheet.PageLayout.RepeatedCols.FirstIndex));
    AssertEquals(1, integer(Sheet.PageLayout.RepeatedCols.LastIndex));
    AssertTrue(Sheet.PageLayout.HasRepeatedRows);
    AssertEquals('№', Sheet.ReadAsText(Sheet.PageLayout.RepeatedRows.FirstIndex, 0));
    AssertTrue(Sheet.PageLayout.FitWidthToPages <> 1);
  finally
    DeleteFile(Path);
    B.Free;
    FreeProtocolDocuments(V);
    D.Free;
  end;
end;

procedure TStartProtocolExportTests.ContinuousNumberListRepeatsColumnsOnEveryPage;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
  P: TPreparedStageReport;
  I: integer;
  Text, AllText: string;
begin
  SetLength(R, 120);
  SetLength(S, 1);
  S[0].Index := 1;
  S[0].IsActive := True;
  for I := 0 to High(R) do
  begin
    R[I].Id := I + 1;
    R[I].Number := 120 - I;
    R[I].Name := 'ROW_' + Format('%.4d', [R[I].Number]);
    R[I].Category := 'CAT_' + IntToStr(I mod 2);
    SetLength(R[I].Starts, 1);
    R[I].Starts[0] := '09:00:00';
  end;
  O := DefaultStartReportOptions;
  O.Order := sroNumber;
  O.ShowTeam := False;
  D := PrepareStartProtocol(R, S, O);
  P := nil;
  try
    P := BuildProtocolReport(D);
    AssertTrue(P.PageCount > 1);
    AllText := '';
    for I := 0 to P.PageCount - 1 do
    begin
      Text := P.PageText(I);
      AssertTrue(Pos('ROW_', Text) > 0);
      AssertTrue(Pos('СУ 1', Text) > 0);
      AssertEquals(0, Pos('CAT_', Text));
      AssertEquals(0, Pos('Без категории', Text));
      AllText := AllText + Text;
    end;
    for I := 1 to 120 do AssertTrue(Pos('ROW_' + Format('%.4d', [I]), AllText) > 0);
  finally
    P.Free;
    D.Free;
  end;
end;

procedure TStartProtocolExportTests.ContinuousNumberListWithoutTeamSurvivesAllWriters;
var
  R: TStartReportRows;
  Stages: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
  P: TPreparedStageReport;
  B: TsWorkbook;
  Sheet: TsWorksheet;
  F: TStringList;
  Z: TUnZipper;
  Dir, Text: string;
  I, J, Count: integer;
begin
  SetLength(R, 3);
  SetLength(Stages, 1);
  Stages[0].Index := 1;
  Stages[0].IsActive := True;
  for I := 0 to 2 do
  begin
    R[I].Id := I + 1;
    R[I].Number := 30 - I * 10;
    R[I].Name := 'Rider';
    R[I].Team := 'TEAM_ONLY_TOKEN';
    R[I].Category := 'CATEGORY_' + IntToStr(I);
    SetLength(R[I].Starts, 1);
    R[I].Starts[0] := '09:00:00';
  end;
  O := DefaultStartReportOptions;
  O.Order := sroNumber;
  O.ShowTeam := False;
  D := PrepareStartProtocol(R, Stages, O);
  P := nil;
  B := TsWorkbook.Create;
  F := TStringList.Create;
  Dir := GetTempFileName;
  DeleteFile(Dir);
  ForceDirectories(Dir);
  try
    P := BuildProtocolReport(D);
    Text := P.PageText(0);
    AssertEquals(0, Pos('CATEGORY_', Text));
    AssertEquals(0, Pos('TEAM_ONLY_TOKEN', Text));
    AssertEquals(0, Pos('Без категории', Text));
    AssertTrue(Pos('СУ 1', Text) > 0);
    AssertTrue(SaveProtocolDocx(D, Dir + '/out.docx'));
    Z := TUnZipper.Create;
    try
      Z.FileName := Dir + '/out.docx';
      Z.OutputPath := Dir + '/unzip';
      Z.Examine;
      Z.UnZipAllFiles;
    finally
      Z.Free;
    end;
    F.LoadFromFile(Dir + '/unzip/word/document.xml');
    AssertEquals(0, Pos('CATEGORY_', F.Text));
    AssertEquals(0, Pos('TEAM_ONLY_TOKEN', F.Text));
    AssertEquals(0, Pos('Без категории', F.Text));
    AssertTrue(SaveProtocolXlsx(D, Dir + '/out.xlsx'));
    B.ReadFromFile(Dir + '/out.xlsx', sfOOXML);
    Sheet := B.GetWorksheetByIndex(0);
    AssertEquals(2, integer(Sheet.GetLastColIndex));
    Count := 0;
    for I := 0 to Sheet.GetLastRowIndex do
    begin
      for J := 0 to Sheet.GetLastColIndex do
      begin
        Text := Sheet.ReadAsText(I, J);
        AssertEquals(0, Pos('CATEGORY_', Text));
        AssertEquals(0, Pos('TEAM_ONLY_TOKEN', Text));
        AssertTrue(Text <> 'Без категории');
      end;
      if Sheet.ReadAsText(I, 1) = 'Rider' then
      begin
        Inc(Count);
        AssertEquals(IntToStr(Count * 10), Sheet.ReadAsText(I, 0));
      end;
    end;
    AssertEquals(3, Count);
  finally
    F.Free;
    B.Free;
    P.Free;
    D.Free;
    DeleteDirectory(Dir, False);
  end;
end;

procedure TStartProtocolExportTests.CompletedCategoryHeadersAreNotRepeatedWithoutRows;
var
  D: TProtocolDocument;
  P: TPreparedStageReport;
  FirstCount, Orientation, I, J, Page: integer;
  Text, Category, Token: string;
begin
  for Orientation := 0 to 1 do for FirstCount := 15 to 55 do
    begin
      D := Document(6);
      D.Options.Landscape := Orientation = 1;
      P := nil;
      try
        SetLength(D.Rows, FirstCount + 12);
        for I := 0 to High(D.Rows) do
        begin
          Category := 'CATEGORY_A';
          Token := 'ROW_A_';
          if I >= FirstCount then
          begin
            Category := 'CATEGORY_B';
            Token := 'ROW_B_';
          end;
          D.Rows[I].Id := I + 1;
          D.Rows[I].Number := I + 1;
          D.Rows[I].Category := Category;
          SetLength(D.Rows[I].Cells, 9);
          D.Rows[I].Cells[0] := IntToStr(I + 1);
          D.Rows[I].Cells[1] := Token + Format('%.4d', [I + 1]);
          D.Rows[I].Cells[2] := 'Team';
          for J := 3 to 8 do D.Rows[I].Cells[J] := '09:00:00';
        end;
        P := BuildProtocolReport(D);
        for Page := 0 to P.PageCount - 1 do
        begin
          Text := P.PageText(Page);
          if Pos('ROW_A_', Text) > 0 then
            AssertTrue('A rows must have their category header',
              Pos('CATEGORY_A', Text) > 0);
          if Pos('ROW_B_', Text) > 0 then
            AssertTrue('B rows must have their category header',
              Pos('CATEGORY_B', Text) > 0);
          if Pos('CATEGORY_A', Text) > 0 then
            AssertTrue(Format(
              'Completed A must not have an orphan header: orientation %d, first count %d, page %d',
              [Orientation, FirstCount, Page + 1]), Pos('ROW_A_', Text) > 0);
          if Pos('CATEGORY_B', Text) > 0 then
            AssertTrue('New B header must stay with a row', Pos('ROW_B_', Text) > 0);
        end;
      finally
        P.Free;
        D.Free;
      end;
    end;
end;

procedure TStartProtocolExportTests.CategoryContinuationStillRepeatsHeader;
var
  D: TProtocolDocument;
  P: TPreparedStageReport;
  I, Page, Total: integer;
  Text: string;
begin
  D := Document(1);
  P := nil;
  try
    SetLength(D.Rows, 120);
    for I := 0 to High(D.Rows) do
    begin
      D.Rows[I].Category := 'CONTINUING_CATEGORY';
      SetLength(D.Rows[I].Cells, 4);
      D.Rows[I].Cells[0] := IntToStr(I + 1);
      D.Rows[I].Cells[1] := 'CONT_ROW_' + Format('%.4d', [I + 1]);
      D.Rows[I].Cells[2] := 'Team';
      D.Rows[I].Cells[3] := '09:00:00';
    end;
    P := BuildProtocolReport(D);
    AssertTrue(P.PageCount > 1);
    Total := 0;
    for Page := 0 to P.PageCount - 1 do
    begin
      Text := P.PageText(Page);
      AssertTrue(Pos('CONT_ROW_', Text) > 0);
      AssertTrue('Real continuation must have its category header',
        Pos('CONTINUING_CATEGORY', Text) > 0);
      AssertTrue(Pos('Stage 1', Text) > 0);
      while Pos('CONT_ROW_', Text) > 0 do
      begin
        Delete(Text, 1, Pos('CONT_ROW_', Text) + Length('CONT_ROW_') - 1);
        Inc(Total);
      end;
    end;
    AssertEquals(120, Total);
  finally
    P.Free;
    D.Free;
  end;
end;

procedure TStartProtocolExportTests.
HidingTeamRedistributesFitWidthAcrossRemainingColumns;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  WithTeam, WithoutTeam: TProtocolDocument;
  A, B: TProtocolDocuments;
  Count, Orientation, I: integer;
  Available, Total: single;
begin
  SetLength(R, 1);
  R[0].Number := 123;
  R[0].Name := 'Rider';
  R[0].Team := 'Team';
  O := DefaultStartReportOptions;
  O.FitToWidth := True;
  for Count in [1, 4, 7, 8, 32] do for Orientation := 0 to 1 do
    begin
      SetLength(S, Count);
      SetLength(R[0].Starts, Count);
      for I := 0 to Count - 1 do
      begin
        S[I].Index := I + 1;
        S[I].IsActive := True;
        R[0].Starts[I] := '09:00:00.123';
      end;
      O.View.Orientation := TReportOrientation(Orientation);
      O.ShowTeam := True;
      WithTeam := PrepareStartProtocol(R, S, O);
      WithoutTeam := nil;
      A := nil;
      B := nil;
      try
        O.ShowTeam := False;
        WithoutTeam := PrepareStartProtocol(R, S, O);
        A := ProtocolPrintViews(WithTeam);
        B := ProtocolPrintViews(WithoutTeam);
        AssertEquals(1, Length(A));
        AssertEquals(1, Length(B));
        AssertTrue('Free team width must enlarge stage columns', B[0].Columns[2].Width >
          A[0].Columns[3].Width);
        AssertTrue(B[0].Columns[1].Width > A[0].Columns[1].Width);
        Available := 190;
        if Orientation = 1 then Available := 277;
        Total := 0;
        for I := 0 to High(A[0].Columns) do Total := Total + A[0].Columns[I].Width;
        AssertEquals(Available, Total, 0.01);
        Total := 0;
        for I := 0 to High(B[0].Columns) do Total := Total + B[0].Columns[I].Width;
        AssertEquals(Available, Total, 0.01);
        AssertTrue(ProtocolFontSize(B[0]) >= ProtocolFontSize(A[0]));
        AssertTrue(ProtocolFontSize(B[0]) <= 8);
        if (Count = 7) and (Orientation = 0) then
          AssertTrue('Less shrinking must improve the font too', ProtocolFontSize(
            B[0]) > ProtocolFontSize(A[0]));
        AssertEquals('09:00:00.123', B[0].Rows[0].Cells[2]);
      finally
        FreeProtocolDocuments(A);
        FreeProtocolDocuments(B);
        WithTeam.Free;
        WithoutTeam.Free;
      end;
    end;
end;

procedure TStartProtocolExportTests.NarrowXlsxWithoutTeamFillsPageWidth;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  I: integer;
  Total: single;
  Path: string;
begin
  SetLength(R, 1);
  R[0].Number := 123;
  R[0].Name := 'Rider';
  SetLength(R[0].Starts, 4);
  SetLength(S, 4);
  for I := 0 to 3 do
  begin
    S[I].Index := I + 1;
    S[I].IsActive := True;
    R[0].Starts[I] := '09:00:00';
  end;
  O := DefaultStartReportOptions;
  O.FitToWidth := True;
  O.ShowTeam := False;
  D := PrepareStartProtocol(R, S, O);
  Book := TsWorkbook.Create;
  Path := GetTempFileName;
  try
    AssertTrue(SaveProtocolXlsx(D, Path));
    Book.ReadFromFile(Path, sfOOXML);
    Sheet := Book.GetWorksheetByIndex(0);
    Total := 0;
    for I := 0 to Sheet.GetLastColIndex do Total := Total + Sheet.GetColWidth(I, suMillimeters);
    AssertEquals(190.0, Total, 1.0);
    AssertTrue(Sheet.GetColWidth(2, suMillimeters) > 25);
    AssertEquals(1, Sheet.PageLayout.FitWidthToPages);
  finally
    DeleteFile(Path);
    Book.Free;
    D.Free;
  end;
end;

procedure TStartProtocolExportTests.FitWidthKeepsThirtyTwoStagesTogether;
var
  D: TProtocolDocument;
  V: TProtocolDocuments;
  P: TPreparedStageReport;
  W: single;
  I: integer;
  B: TsWorkbook;
  Path: string;
begin
  D := Document(32);
  D.Options.FitToWidth := True;
  V := nil;
  P := nil;
  B := TsWorkbook.Create;
  Path := GetTempFileName;
  try
    V := ProtocolPrintViews(D);
    AssertEquals(1, Length(V));
    AssertEquals(35, Length(V[0].Columns));
    W := 0;
    for I := 0 to High(V[0].Columns) do W := W + V[0].Columns[I].Width;
    AssertTrue(W <= 190.01);
    AssertTrue(ProtocolFontSize(V[0]) < 8);
    P := BuildProtocolReport(D);
    AssertEquals(1, P.PageCount);
    AssertTrue(Pos('09:31:00.123', P.PageText(0)) > 0);
    AssertTrue(SaveProtocolXlsx(D, Path));
    B.ReadFromFile(Path, sfOOXML);
    AssertEquals(1, B.GetWorksheetByIndex(0).PageLayout.FitWidthToPages);
  finally
    B.Free;
    DeleteFile(Path);
    P.Free;
    FreeProtocolDocuments(V);
    D.Free;
  end;
end;

procedure TStartProtocolExportTests.SeparateStagesStartNewPagesInAllFormats;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
  P: TPreparedStageReport;
  B: TsWorkbook;
  Z: TUnZipper;
  F: TStringList;
  Dir, Text: string;
  I: integer;
begin
  SetLength(R, 1);
  R[0].Number := 123;
  R[0].Name := 'Rider';
  R[0].Category := 'A';
  SetLength(R[0].Starts, 3);
  SetLength(S, 3);
  for I := 0 to 2 do
  begin
    S[I].Index := 1 + I * 2;
    S[I].IsActive := True;
    S[I].Name := 'Stage ' + IntToStr(S[I].Index);
    R[0].Starts[I] := '09:00:0' + IntToStr(I) + '.123';
  end;
  O := DefaultStartReportOptions;
  O.Mode := srmSingleStage;
  O.AllSingleStages := True;
  D := PrepareStartProtocol(R, S, O);
  D.RaceName := 'Batch race';
  D.FormedAt := 42;
  P := nil;
  B := TsWorkbook.Create;
  F := TStringList.Create;
  Dir := GetTempFileName;
  DeleteFile(Dir);
  ForceDirectories(Dir);
  try
    PrepareProtocolTemplate(D, GetEnvironmentVariable('ENTIME_ROOT') +
      '/templates/reports/finish-signatures.html');
    P := BuildProtocolReport(D);
    AssertEquals(3, P.PageCount);
    for I := 0 to 2 do
    begin
      Text := P.PageText(I);
      AssertTrue(Pos('Stage ' + IntToStr(S[I].Index), Text) > 0);
      AssertTrue(Pos('Batch race', Text) > 0);
      AssertTrue(Pos('Главный судья', Text) > 0);
    end;
    AssertTrue(SaveProtocolDocx(D, Dir + '/batch.docx'));
    Z := TUnZipper.Create;
    try
      Z.FileName := Dir + '/batch.docx';
      Z.OutputPath := Dir + '/unzip';
      Z.Examine;
      Z.UnZipAllFiles;
    finally
      Z.Free;
    end;
    F.LoadFromFile(Dir + '/unzip/word/document.xml');
    Text := F.Text;
    I := 0;
    while Pos('<w:sectPr>', Text) > 0 do
    begin
      Delete(Text, 1, Pos('<w:sectPr>', Text) + Length('<w:sectPr>') - 1);
      Inc(I);
    end;
    AssertEquals(3, I);
    AssertTrue(SaveProtocolXlsx(D, Dir + '/batch.xlsx'));
    B.ReadFromFile(Dir + '/batch.xlsx', sfOOXML);
    AssertEquals(3, B.GetWorksheetCount);
    AssertEquals('СУ 3', B.GetWorksheetByIndex(1).Name);
  finally
    F.Free;
    B.Free;
    P.Free;
    D.Free;
    DeleteDirectory(Dir, False);
  end;
end;

procedure TStartProtocolExportTests.CategoryStartOrderSurvivesAllWriters;
var
  R: TStartReportRows;
  Stages: TStartStageInfos;
  D: TProtocolDocument;
  P: TPreparedStageReport;
  B: TsWorkbook;
  Sheet: TsWorksheet;
  Z: TUnZipper;
  F: TStringList;
  Dir, Text: string;
  I, Early, Late: integer;
begin
  SetLength(R, 2);
  SetLength(Stages, 1);
  Stages[0].Index := 1;
  Stages[0].IsActive := True;
  R[0].Category := 'A-late';
  R[1].Category := 'Z-early';
  for I := 0 to 1 do
  begin
    R[I].Number := I + 1;
    R[I].Name := 'Rider';
    SetLength(R[I].Starts, 1);
  end;
  R[0].Starts[0] := '10:00:00';
  R[1].Starts[0] := '09:00:00';
  D := PrepareStartProtocol(R, Stages, DefaultStartReportOptions);
  P := nil;
  B := TsWorkbook.Create;
  F := TStringList.Create;
  Dir := GetTempFileName;
  DeleteFile(Dir);
  ForceDirectories(Dir);
  try
    P := BuildProtocolReport(D);
    Text := P.PageText(0);
    AssertTrue(Pos('Z-early', Text) < Pos('A-late', Text));
    AssertTrue(SaveProtocolDocx(D, Dir + '/start.docx'));
    Z := TUnZipper.Create;
    try
      Z.FileName := Dir + '/start.docx';
      Z.OutputPath := Dir + '/unzip';
      Z.Examine;
      Z.UnZipAllFiles;
    finally
      Z.Free;
    end;
    F.LoadFromFile(Dir + '/unzip/word/document.xml');
    AssertTrue(Pos('>Z-early<', F.Text) < Pos('>A-late<', F.Text));
    AssertTrue(SaveProtocolXlsx(D, Dir + '/start.xlsx'));
    B.ReadFromFile(Dir + '/start.xlsx', sfOOXML);
    Sheet := B.GetWorksheetByIndex(0);
    Early := -1;
    Late := -1;
    for I := 0 to Sheet.GetLastRowIndex do
    begin
      if Sheet.ReadAsText(I, 0) = 'Z-early' then Early := I;
      if Sheet.ReadAsText(I, 0) = 'A-late' then Late := I;
    end;
    AssertTrue(Early >= 0);
    AssertTrue(Late > Early);
  finally
    F.Free;
    B.Free;
    P.Free;
    D.Free;
    DeleteDirectory(Dir, False);
  end;
end;

procedure TStartProtocolExportTests.ClockColumnsSurviveAllWriters;
var
  D: TProtocolDocument;
  P: TPreparedStageReport;
  B: TsWorkbook;
  S: TsWorksheet;
  F: TStringList;
  Z: TUnZipper;
  Dir, Text: string;
  Mode, I, J, K: integer;
  Found: boolean;
begin
  Dir := GetTempFileName;
  DeleteFile(Dir);
  ForceDirectories(Dir);
  F := TStringList.Create;
  B := TsWorkbook.Create;
  try
    for Mode := 0 to 1 do
    begin
      D := Document(1, Mode = 1, Mode = 1);
      P := nil;
      try
        P := BuildProtocolReport(D);
        Text := P.PageText(0);
        AssertTrue(Pos('09:00:00.123', Text) > 0);
        AssertTrue(Pos('00:00:00.000', Text) > 0);
        AssertEquals(0, Pos('Результат', Text));
        AssertEquals(0, Pos('Status', Text));
        AssertTrue(SaveStageFinishPdf(P, Dir + '/start.pdf'));
        AssertTrue(FileSize(Dir + '/start.pdf') > 1000);
        AssertTrue(SaveProtocolDocx(D, Dir + '/start.docx'));
        Z := TUnZipper.Create;
        try
          Z.FileName := Dir + '/start.docx';
          Z.OutputPath := Dir + '/unzip';
          Z.Examine;
          Z.UnZipAllFiles;
        finally
          Z.Free;
        end;
        F.LoadFromFile(Dir + '/unzip/word/document.xml');
        AssertTrue(Pos('09:00:00.123', F.Text) > 0);
        AssertTrue(Pos('00:00:00.000', F.Text) > 0);
        AssertEquals(0, Pos('>Result<', F.Text));
        AssertTrue(SaveProtocolXlsx(D, Dir + '/start.xlsx'));
        B.ReadFromFile(Dir + '/start.xlsx', sfOOXML);
        S := B.GetWorksheetByIndex(0);
        for K := 0 to 1 do
        begin
          Found := False;
          for I := 0 to S.GetLastRowIndex do for J := 0 to S.GetLastColIndex do
              if S.ReadAsText(I, J) = D.Rows[K].Cells[3] then
              begin
                AssertEquals(Ord(cctUTF8String), Ord(S.FindCell(I, J)^.ContentType));
                Found := True;
              end;
          AssertTrue(Found);
        end;
      finally
        P.Free;
        D.Free;
      end;
    end;
  finally
    B.Free;
    F.Free;
    DeleteDirectory(Dir, False);
  end;
end;

procedure TStartProtocolExportTests.WidePartsRepeatIdentifiersAndKeepEveryClock;
var
  D: TProtocolDocument;
  V: TProtocolDocuments;
  P: TPreparedStageReport;
  Seen: array[1..32] of integer;
  Count, Orient, I, J, K: integer;
  Text: string;
begin
  for Count in [1, 8, 32] do for Orient := 0 to 1 do
    begin
      D := Document(Count);
      D.Options.Landscape := Orient = 1;
      V := nil;
      P := nil;
      FillChar(Seen, SizeOf(Seen), 0);
      try
        V := ProtocolPrintViews(D);
        for I := 0 to High(V) do
        begin
          AssertEquals('122', V[I].Rows[0].Cells[0]);
          AssertEquals('123', V[I].Rows[1].Cells[0]);
          for J := 0 to High(V[I].Columns) do
          begin
            K := V[I].Columns[J].StageIndex;
            if K > 0 then
            begin
              Inc(Seen[K]);
              AssertEquals('09:' + Format('%.2d', [K - 1]) + ':00.123',
                V[I].Rows[1].Cells[J]);
            end;
          end;
        end;
        for I := 1 to Count do AssertEquals(1, Seen[I]);
        P := BuildProtocolReport(D);
        Text := '';
        for I := 0 to P.PageCount - 1 do Text := Text + P.PageText(I);
        AssertTrue(Pos('09:' + Format('%.2d', [Count - 1]) + ':00.123', Text) > 0);
        AssertEquals(0, Pos('продолжение', LowerCase(Text)));
      finally
        P.Free;
        FreeProtocolDocuments(V);
        D.Free;
      end;
    end;
end;

procedure TStartProtocolExportTests.TemplatesSurroundResultsAndFlagsRemainIndependent;
var
  D: TProtocolDocument;
  P: TPreparedStageReport;
  Text, Name: string;
  I, T: integer;
begin
  for T := 0 to 1 do
  begin
    Name := 'finish-club.html';
    if T = 1 then Name := 'finish-signatures.html';
    D := Document(1);
    P := nil;
    try
      PrepareProtocolTemplate(D, GetEnvironmentVariable('ENTIME_ROOT') +
        '/templates/reports/' + Name);
      P := BuildProtocolReport(D);
      Text := P.PageText(0);
      AssertTrue(Pos('Главный судья', Text) > Pos('09:00:00.123', Text));
      AssertTrue(Pos('Start race', Text) > 0);
      P.Free;
      P := nil;
      D.Options.ShowHeadings := False;
      D.Options.ShowHeader := False;
      D.Options.ShowFooter := False;
      P := BuildProtocolReport(D);
      Text := '';
      for I := 0 to P.PageCount - 1 do Text := Text + P.PageText(I);
      AssertEquals(0, Pos('Start race', Text));
      AssertEquals(0, Pos('Общий стартовый протокол', Text));
      AssertTrue(Pos('Главный судья', Text) > 0);
      AssertTrue(Pos('09:00:00.123', Text) > 0);
    finally
      P.Free;
      D.Free;
    end;
  end;
end;

procedure TStartProtocolExportTests.CategoriesSharePagesAndHeadersRepeat;
var
  D: TProtocolDocument;
  P: TPreparedStageReport;
  Text: string;
  I: integer;
begin
  D := Document(1);
  P := nil;
  try
    D.Rows[1].Category := 'Category B';
    P := BuildProtocolReport(D);
    AssertEquals(1, P.PageCount);
    Text := P.PageText(0);
    AssertTrue(Pos('Category A', Text) > 0);
    AssertTrue(Pos('Category B', Text) > 0);
    P.Free;
    P := nil;
    SetLength(D.Rows, 100);
    for I := 2 to High(D.Rows) do
    begin
      D.Rows[I].Category := 'Category B';
      D.Rows[I].Cells := Copy(D.Rows[1].Cells);
    end;
    P := BuildProtocolReport(D);
    AssertTrue(P.PageCount > 1);
    for I := 0 to P.PageCount - 1 do
    begin
      Text := P.PageText(I);
      AssertTrue(Pos('Stage 1', Text) > 0);
      AssertEquals(0, Pos('продолжение', LowerCase(Text)));
    end;
  finally
    P.Free;
    D.Free;
  end;
end;

initialization
  RegisterTest(TStartProtocolExportTests);
end.
