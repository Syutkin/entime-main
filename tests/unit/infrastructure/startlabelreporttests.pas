unit StartLabelReportTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  TStartLabelReportTests = class(TTestCase)
  published
    procedure A4PagesKeepSlotsAndLiteralContents;
    procedure BordersOnlySurroundFilledLabels;
    procedure UniformFontShrinksAndRejectsOverflow;
    procedure EveryCardAndLastStageSurvivePdf;
    procedure TwoColumnsFillDownThenAcrossWithoutChangingHeaderOrSheet;
    procedure TwoColumnsFitMoreRowsButRespectFullTimeWidth;
    procedure OverflowPreviewClipsCardsAndRefusesPdf;
    procedure HeaderLinesAreCenteredAcrossWholeLabel;
  end;

implementation

uses Classes, SysUtils, StartLabelModel, StartLabelReportBuilder,
  StageFinishPdfWriter, StageFinishReportBackend, fpreport, StrUtils;

function Cards(N: integer; Stages: integer = 3): TStartLabelCards;
var
  I, J: integer;
begin
  Result := nil;
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    Result[I].Id := I + 1;
    Result[I].Number := I + 1;
    Result[I].Title := IntToStr(I + 1) + ' Иван [Иванов]';
    SetLength(Result[I].Entries, Stages);
    for J := 0 to Stages - 1 do
    begin
      Result[I].Entries[J].StageIndex := J + 1;
      Result[I].Entries[J].Time := '09:12:34.567';
    end;
  end;
end;

procedure TStartLabelReportTests.HeaderLinesAreCenteredAcrossWholeLabel;
var
  P: TStartLabelPaper;
  C: TStartLabelCards;
  D: TStartLabelReport;
  M: TFPReportMemo;
  B: TFPTextBlock;
  I, Columns: integer;
begin
  P := DefaultStartLabelPaper;
  P.Width := 70000;
  P.Height := 85000;
  C := Cards(1);
  C[0].Title :=
    '123 Очень длинное имя участника для переноса';
  for Columns := 1 to 2 do
  begin
    P.StartColumns := Columns;
    D := BuildStartLabelReport(C, P);
    try
      M := TFPReportMemo(D.RuntimePage(0).Bands[0].Child[0]);
      AssertTrue('Wrapped header has multiple lines', M.TextBlockList.Count > 1);
      for I := 0 to M.TextBlockList.Count - 1 do
      begin
        B := M.TextBlockList[I];
        AssertEquals('Every line uses the whole label width',
          (M.Layout.Width - B.Width) / 2, B.Pos.Left, 0.01);
      end;
    finally
      D.Free;
    end;
  end;
end;

procedure TStartLabelReportTests.OverflowPreviewClipsCardsAndRefusesPdf;
var
  P: TStartLabelPaper;
  D: TStartLabelReport;
  C: TStartLabelCards;
  B: TFPReportCustomBand;
  I, Slot, Frames: integer;
  E: TFPReportElement;
  Path: string;

  procedure CheckVisibleText(const Report: TStartLabelReport);
  var
    A, K: integer;
    Band: TFPReportCustomBand;
    M: TFPReportMemo;
    T: TFPTextBlock;
  begin
    Band := Report.RuntimePage(0).Bands[0];
    for A := 0 to Band.ChildCount - 1 do if Band.Child[A] is TFPReportMemo then
      begin
        M := TFPReportMemo(Band.Child[A]);
        for K := 0 to M.TextBlockList.Count - 1 do
        begin
          T := M.TextBlockList[K];
          AssertTrue('Visible text fits clipped width', T.Pos.Left +
            T.Width <= M.Layout.Width + 0.01);
          AssertTrue('Visible text fits clipped height', T.Pos.Top +
            T.Height + T.Descender <= M.Layout.Height + 0.01);
        end;
      end;
  end;

begin
  P := DefaultStartLabelPaper;
  P.Height := 18000;
  C := Cards(3, 20);
  SetLength(C[1].Entries, 1);
  D := BuildStartLabelReport(C, P, True);
  Path := GetTempFileName;
  try
    AssertEquals(2, D.OverflowCount);
    AssertEquals(P.MinFontSize, D.TableFontSize);
    AssertEquals(1, D.PageCount);
    B := D.RuntimePage(0).Bands[0];
    Frames := 0;
    for I := 0 to B.ChildCount - 1 do
    begin
      E := B.Child[I];
      Slot := Trunc(E.Layout.Left / (P.Width / StartLabelUnitsPerMM));
      AssertTrue('Text stays inside its label', E.Layout.Left +
        E.Layout.Width <= (Slot + 1) * P.Width / StartLabelUnitsPerMM + 0.01);
      AssertTrue(E.Layout.Top + E.Layout.Height <= P.Top / StartLabelUnitsPerMM +
        P.Height / StartLabelUnitsPerMM + 0.01);
      if E.Frame.Color = clRed then Inc(Frames);
    end;
    AssertEquals(2, Frames);
    CheckVisibleText(D);
    try
      SaveStageFinishPdf(D, Path);
      Fail('A clipped preview must not be exported');
    except
      on E: EStartLabelsDoNotFit do ;
    end;
  finally
    D.Free;
    DeleteFile(Path);
  end;
  P.Width := 4500;
  P.Height := 37000;
  P.Padding := 2000;
  D := BuildStartLabelReport(C, P, True);
  try
    AssertEquals(3, D.OverflowCount);
    AssertEquals(1, D.PageCount);
    CheckVisibleText(D);
  finally
    D.Free;
  end;
end;

procedure TStartLabelReportTests.
TwoColumnsFillDownThenAcrossWithoutChangingHeaderOrSheet;
var
  P: TStartLabelPaper;
  D: TStartLabelReport;
  C: TStartLabelCards;
  B: TFPReportCustomBand;
  Count, J, Rows: integer;
  First, Entry: TFPReportMemo;
begin
  P := DefaultStartLabelPaper;
  P.Width := 105000;
  P.Height := 148000;
  P.StartColumns := 2;
  for Count in [0, 1, 2, 3, 5, 32] do
  begin
    C := Cards(1, Count);
    for J := 0 to Count - 1 do C[0].Entries[J].StageIndex := J + 1;
    D := BuildStartLabelReport(C, P);
    try
      AssertEquals(1, D.PageCount);
      B := D.RuntimePage(0).Bands[0];
      AssertEquals(1 + Count * 2, B.ChildCount);
      AssertEquals(101.0, B.Child[0].Layout.Width, 0.01);
      Rows := (Count + 1) div 2;
      if Count = 0 then Continue;
      First := TFPReportMemo(B.Child[1]);
      for J := 0 to Count - 1 do
      begin
        Entry := TFPReportMemo(B.Child[1 + J * 2]);
        AssertEquals(IntToStr(J + 1), Entry.Text);
        AssertEquals('09:12:34.567', TFPReportMemo(B.Child[2 + J * 2]).Text);
        if J < Rows then AssertEquals(First.Layout.Left, Entry.Layout.Left, 0.01)
        else
        begin
          AssertTrue('Right block follows the left block', Entry.Layout.Left >
            First.Layout.Left);
          AssertEquals(TFPReportMemo(B.Child[1 + (J - Rows) * 2]).Layout.Top,
            Entry.Layout.Top, 0.01);
        end;
        if (J > 0) and (J mod Rows <> 0) then
          AssertTrue(Entry.Layout.Top > B.Child[1 + (J - 1) * 2].Layout.Top);
      end;
    finally
      D.Free;
    end;
  end;
end;

procedure TStartLabelReportTests.TwoColumnsFitMoreRowsButRespectFullTimeWidth;
var
  P: TStartLabelPaper;
  D: TStartLabelReport;
  C: TStartLabelCards;
begin
  P := DefaultStartLabelPaper;
  P.Width := 105000;
  P.Height := 70000;
  C := Cards(2, 32);
  try
    D := BuildStartLabelReport(C, P);
    D.Free;
    Fail('One block cannot fit 32 rows');
  except
    on E: EStartLabelsDoNotFit do ;
  end;
  P.StartColumns := 2;
  D := BuildStartLabelReport(C, P);
  try
    AssertTrue(D.TableFontSize >= P.MinFontSize);
    AssertEquals(1, D.PageCount);
  finally
    D.Free;
  end;
  P.Width := 30000;
  P.Height := 85000;
  C := Cards(1);
  C[0].Title := '1 A';
  try
    D := BuildStartLabelReport(C, P);
    D.Free;
    Fail('Full time cannot fit in a narrow block');
  except
    on E: EStartLabelsDoNotFit do ;
  end;
  P.StartColumns := 1;
  D := BuildStartLabelReport(C, P);
  D.Free;
end;

procedure TStartLabelReportTests.A4PagesKeepSlotsAndLiteralContents;
var
  P: TStartLabelPaper;
  D: TStartLabelReport;
  C: TStartLabelCards;
  I: integer;
  S: string;
  Page: TFPReportCustomPage;
  B: TFPReportCustomBand;
begin
  P := DefaultStartLabelPaper;
  P.FirstSlot := 24;
  C := Cards(26);
  D := BuildStartLabelReport(C, P);
  try
    AssertEquals(3, D.PageCount);
    AssertEquals(9, D.TableFontSize);
    S := D.PageText(0);
    AssertTrue(Pos('1 Иван [Иванов]', S) > 0);
    AssertEquals(0, Pos('2 Иван [Иванов]', S));
    AssertTrue(Pos('26 Иван [Иванов]', D.PageText(2)) > 0);
    for I := 0 to D.PageCount - 1 do
    begin
      Page := D.RuntimePage(I);
      AssertEquals(210.0, Page.PageSize.Width, 0.01);
      AssertEquals(297.0, Page.PageSize.Height, 0.01);
    end;
    Page := D.RuntimePage(0);
    B := Page.Bands[0];
    AssertTrue(B.ChildCount > 0);
    AssertEquals(140.0 + P.Padding / StartLabelUnitsPerMM, B.Child[0].Layout.Left, 0.02);
    AssertEquals(259.5 + P.Padding / StartLabelUnitsPerMM, B.Child[0].Layout.Top, 0.02);
    AssertEquals(ReportBoldFont, TFPReportMemo(B.Child[0]).Font.Name);
  finally
    D.Free;
  end;
end;

procedure TStartLabelReportTests.BordersOnlySurroundFilledLabels;
var
  P: TStartLabelPaper;
  D: TStartLabelReport;
  C: TStartLabelCards;
  I, J, K, N: integer;
  Page: TFPReportCustomPage;
begin
  P := DefaultStartLabelPaper;
  P.FirstSlot := 24;
  C := Cards(2);
  for K := 0 to 1 do
  begin
    P.DrawBorders := K = 1;
    D := BuildStartLabelReport(C, P);
    try
      N := 0;
      for I := 0 to D.PageCount - 1 do
      begin
        Page := D.RuntimePage(I);
        for J := 0 to Page.Bands[0].ChildCount - 1 do
          if Page.Bands[0].Child[J].Frame.Lines <> [] then Inc(N);
      end;
      AssertEquals(K * 2, N);
    finally
      D.Free;
    end;
  end;
end;

procedure TStartLabelReportTests.UniformFontShrinksAndRejectsOverflow;
var
  P: TStartLabelPaper;
  D: TStartLabelReport;
  C: TStartLabelCards;
begin
  P := DefaultStartLabelPaper;
  P.Width := 70000;
  P.Height := 85000;
  C := Cards(2, 20);
  C[1].Title := '2 Очень длинное имя участника с переносом';
  D := BuildStartLabelReport(C, P);
  try
    AssertTrue(D.TableFontSize < 9);
    AssertTrue(D.TableFontSize >= 6);
    AssertEquals(1, D.PageCount);
  finally
    D.Free;
  end;
  P.Height := 12000;
  try
    D := BuildStartLabelReport(C, P);
    D.Free;
    Fail('Overflow must be reported');
  except
    on E: EStartLabelsDoNotFit do AssertEquals(2, E.Count);
  end;
  P.Height := 37000;
  P.Width := 4500;
  P.Padding := 2000;
  try
    D := BuildStartLabelReport(C, P);
    D.Free;
    Fail('Tiny width must be rejected');
  except
    on E: EStartLabelsDoNotFit do ;
  end;
  try
    D := BuildStartLabelReport(nil, DefaultStartLabelPaper);
    D.Free;
    Fail('No empty PDF');
  except
    on E: EArgumentException do ;
  end;
end;

procedure TStartLabelReportTests.EveryCardAndLastStageSurvivePdf;
var
  P: TStartLabelPaper;
  D: TStartLabelReport;
  C: TStartLabelCards;
  Path, S, Text: string;
  I: integer;
  F: TFileStream;
  Head: array[0..4] of char;
begin
  P := DefaultStartLabelPaper;
  P.Width := 105000;
  P.Height := 148000;
  C := Cards(5, 32);
  C[4].Entries[31].Time := '00:00:00.000';
  Path := GetTempFileName;
  D := BuildStartLabelReport(C, P);
  try
    AssertEquals(2, D.PageCount);
    Text := '';
    for I := 0 to D.PageCount - 1 do Text := Text + D.PageText(I);
    for I := 1 to 5 do
    begin
      S := IntToStr(I) + ' Иван [Иванов]';
      AssertTrue(Pos(S, Text) > 0);
      AssertEquals(Pos(S, Text), RPos(S, Text));
    end;
    AssertTrue(Pos('32' + LineEnding, Text) > 0);
    AssertTrue(Pos('00:00:00.000', Text) > 0);
    AssertTrue(SaveStageFinishPdf(D, Path));
    F := TFileStream.Create(Path, fmOpenRead);
    try
      F.ReadBuffer(Head, 5);
      AssertEquals('%PDF-', string(Head));
    finally
      F.Free;
    end;
  finally
    D.Free;
    DeleteFile(Path);
  end;
end;

initialization
  RegisterTest(TStartLabelReportTests);
end.
