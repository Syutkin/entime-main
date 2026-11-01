unit StageFinishReportBuilderTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry;

type
  TStageFinishReportBuilderTests = class(TTestCase)
  published
    procedure CenterAlignmentInPreviewAndPairedCells;
    procedure BodyAndPageHeadingsSwitchIndependently;
    procedure PairedSignaturesShareOneDocumentBand;
    procedure HeaderIsOptionalAndRaceFollowsTemplate;
    procedure TemplateBlocksAreOnceAndInOrder;
    procedure LongTemplateParagraphsFlowWithoutLoss;
    procedure TemplateFormattingAndOptions;
    procedure MultipleCategoriesAndEveryRiderSurvivePagination;
    procedure VeryLongRowContinuesWithoutLosingText;
    procedure LandscapeAndLiteralUserText;
    procedure LongCyrillicWordRemainsValidAndComplete;
    procedure StatusesAndWrappedNamesRemainInTheDocument;
    procedure LongHeadingsAreRenderedInFull;
    procedure FooterAndPenaltyCanBeHiddenIndependently;
    procedure EachCategoryPrecedesItsColumnHeadingsAndResults;
  end;

implementation

uses ReportTemplateModel, fpreport, StageFinishReportModel, StageFinishReportBuilder,
  StageFinishReportBackend, StageFieldNames;

function Sample(Count: integer): TStageReportSnapshot;
var
  I: integer;
begin
  Result := TStageReportSnapshot.Create;
  Result.Options := DefaultReportOptions;
  Result.Labels := ReportLabels(rlRussian);
  Result.FormedAt := EncodeDate(2026, 10, 31);
  Result.RaceName := 'Тестовое соревнование';
  Result.StageName := 'Лес';
  SetLength(Result.Rows, Count);
  for I := 0 to Count - 1 do
  begin
    Result.Rows[I].Number := I + 1;
    Result.Rows[I].Name := 'RIDERTOKEN' + Format('%.4d', [I + 1]);
    if I < Count div 2 then Result.Rows[I].Category := 'Категория A'
    else
      Result.Rows[I].Category := 'Категория B';
    Result.Rows[I].Values[sfkPlace] := IntToStr(I + 1);
    Result.Rows[I].Values[sfkResult] := '01:02:03.456';
  end;
  Result.Rows := SelectReportRows(Result.Rows, Result.Options);
end;

procedure Artifact(D: TPreparedStageReport; const Name: string);
var
  Dir: string;
begin
  Dir := GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR');
  if Dir <> '' then D.WritePdf(IncludeTrailingPathDelimiter(Dir) + Name + '.pdf');
end;

function Build(S: TStageReportSnapshot): TPreparedStageReport;
begin
  Result := BuildStageFinishReport(S);
end;

function Occurs(const Needle, Text: string): integer;
var
  S: string;
  P: integer;
begin
  Result := 0;
  S := Text;
  repeat
    P := Pos(Needle, S);
    if P = 0 then Exit;
    Inc(Result);
    Delete(S, 1, P + Length(Needle) - 1);
  until False;
end;

procedure TStageFinishReportBuilderTests.
MultipleCategoriesAndEveryRiderSurvivePagination;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  Text, Page: string;
  I: integer;
begin
  S := Sample(150);
  D := nil;
  try
    D := Build(S);
    AssertTrue(D.PageCount > 2);
    Text := '';
    for I := 0 to D.PageCount - 1 do
    begin
      Page := D.PageText(I);
      Text := Text + Page;
      AssertEquals('Continuation label is redundant', 0, Occurs(
        'продолжение', Page));
      AssertTrue('Category headings still repeat', Pos('Категория ', Page) > 0);
      AssertTrue(Pos('Финишный протокол', Page) > 0);
      AssertTrue(Pos('Участник', Page) > 0);
      AssertTrue(Pos('Страница ' + IntToStr(I + 1) + ' из ' +
        IntToStr(D.PageCount), Page) > 0);
      AssertTrue('Every category header must accompany data',
        Pos('RIDERTOKEN', Page) > 0);
    end;
    for I := 1 to 150 do AssertEquals('Rider ' + IntToStr(I), 1,
        Occurs('RIDERTOKEN' + Format('%.4d', [I]), Text));
    AssertEquals(0, Pos('продолжение', Text));
    D.WritePdf(IncludeTrailingPathDelimiter(GetTempDir) + 'entime-report-pages.pdf');
    Artifact(D, 'finish-multiple-categories');
    FreeAndNil(D);
    S.Options.Language := rlEnglish;
    S.Labels := ReportLabels(rlEnglish);
    D := Build(S);
    for I := 0 to D.PageCount - 1 do
    begin
      Page := D.PageText(I);
      AssertEquals(0, Pos('continued', Page));
      AssertTrue(Pos('Participant', Page) > 0);
      AssertTrue(Pos('Категория ', Page) > 0);
    end;
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.VeryLongRowContinuesWithoutLosingText;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  Text, Name: string;
  I: integer;
begin
  S := Sample(1);
  D := nil;
  Name := '';
  for I := 1 to 350 do Name := Name + 'WORD' + Format('%.4d', [I]) + ' ';
  S.Rows[0].Cells[rcName] := Name;
  S.Rows[0].Name := Name;
  try
    D := Build(S);
    AssertTrue(D.PageCount > 1);
    Text := '';
    for I := 0 to D.PageCount - 1 do Text := Text + D.PageText(I);
    for I := 1 to 350 do AssertEquals(1, Occurs('WORD' + Format('%.4d', [I]), Text));
    Artifact(D, 'finish-long-row');
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.LandscapeAndLiteralUserText;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  Text: string;
begin
  S := Sample(1);
  S.Options.Orientation := roLandscape;
  S.Options.Language := rlEnglish;
  S.Labels := ReportLabels(rlEnglish);
  S.Rows[0].Cells[rcName] := 'Иван [PageNo] <b>Rider</b>';
  S.RaceName := 'Гонка [x]';
  D := nil;
  try
    D := Build(S);
    Text := D.PageText(0);
    AssertTrue('Literal expression: ' + Text, Pos('[PageNo]', Text) > 0);
    AssertTrue('Literal markup: ' + Text, Pos('<b>Rider</b>', Text) > 0);
    AssertTrue('Literal race: ' + Text, Pos('Гонка [x]', Text) > 0);
    AssertEquals(1, Ord(D.RuntimePage(0).Orientation));
    Artifact(D, 'finish-landscape-english');
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.LongCyrillicWordRemainsValidAndComplete;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  Name, Text: string;
  I, J: integer;
  P: TFPReportCustomPage;
  B: TFPReportCustomBand;
begin
  S := Sample(1);
  D := nil;
  Name := '';
  for I := 1 to 500 do Name := Name + 'Жю';
  S.Rows[0].Cells[rcName] := Name;
  try
    D := Build(S);
    Text := '';
    for I := 0 to D.PageCount - 1 do
    begin
      P := D.RuntimePage(I);
      for J := 0 to P.BandCount - 1 do
      begin
        B := P.Bands[J];
        if B is TFPReportDataBand then
          Text := Text + TFPReportMemo(B.Child[Ord(rcName)]).Text;
      end;
    end;
    AssertEquals(Name, Text);
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.StatusesAndWrappedNamesRemainInTheDocument;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  Text, Cell: string;
  I: integer;
  Codes: integer;
  B: TFPReportCustomBand;
begin
  S := Sample(8);
  D := nil;
  S.Rows[0].Name :=
    'Александр Сергеевич Оченьдлиннаяфамилия';
  S.Rows[0].Team :=
    'Спортивная команда с длинным названием';
  S.Rows[0].Values[sfkPenalty] := '00:00:00.000';
  S.Rows[0].Values[sfkDiffLeader] := '+01:02:03.456';
  S.Rows[1].Values[sfkStatus] := '1';
  S.Rows[2].Values[sfkStatus] := '2';
  S.Rows[3].GlobalStatus := '3';
  S.Rows[4].Values[sfkPlace] := '';
  S.Rows[5].Values[sfkResult] := '';
  S.Rows[6].Values[sfkResult] := 'bad';
  S.Rows[7].Category := '';
  S.Rows := SelectReportRows(S.Rows, S.Options);
  try
    D := Build(S);
    Text := D.PageText(0);
    AssertTrue(Pos('DNS', Text) > 0);
    AssertTrue(Pos('DNF', Text) > 0);
    AssertTrue(Pos('DSQ', Text) > 0);
    AssertTrue(Pos('Без категории', Text) > 0);
    AssertEquals(0, Pos('Статус', Text));
    Codes := 0;
    for I := 0 to D.RuntimePage(0).BandCount - 1 do
    begin
      B := D.RuntimePage(0).Bands[I];
      if not (B is TFPReportDataBand) then Continue;
      AssertEquals('Seven columns including the penalty', 7, B.ChildCount);
      Cell := TFPReportMemo(B.Child[Ord(rcResult)]).Text;
      if (Cell = 'DNS') or (Cell = 'DNF') or (Cell = 'DSQ') then Inc(Codes);
    end;
    AssertEquals('DNS/DNF/DSQ must appear in the result cells', 3, Codes);
    Artifact(D, 'finish-statuses-portrait');
    D.Free;
    D := nil;
    S.Options.Orientation := roLandscape;
    D := Build(S);
    Artifact(D, 'finish-statuses-landscape');
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.LongHeadingsAreRenderedInFull;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  Text: string;
  I, J, K: integer;
  P: TFPReportCustomPage;
  B: TFPReportCustomBand;
  M: TFPReportMemo;
begin
  S := Sample(1);
  D := nil;
  S.RaceName := '';
  S.StageName := '';
  for I := 1 to 40 do
  begin
    S.RaceName := S.RaceName + 'RACE' + Format('%.4d', [I]) + ' ';
    S.StageName := S.StageName + 'STAGE' + Format('%.4d', [I]) + ' ';
  end;
  S.Rows[0].Category := S.RaceName;
  try
    D := Build(S);
    Text := '';
    P := D.RuntimePage(0);
    for I := 0 to P.BandCount - 1 do
    begin
      B := P.Bands[I];
      for J := 0 to B.ChildCount - 1 do if B.Child[J] is TFPReportMemo then
        begin
          M := TFPReportMemo(B.Child[J]);
          for K := 0 to M.TextBlockList.Count - 1 do
            Text := Text + M.TextBlockList[K].Text;
        end;
    end;
    AssertEquals(2, Occurs('RACE0040', Text));
    AssertEquals(2, Occurs('STAGE0040', Text));
    Artifact(D, 'finish-long-headings');
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.FooterAndPenaltyCanBeHiddenIndependently;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  Orientation, FooterOn, PenaltyOn, I, J, Columns, FooterCount: integer;
  Text: string;
  B: TFPReportCustomBand;
begin
  S := Sample(150);
  D := nil;
  S.Rows[0].Cells[rcPenalty] := 'PEN42';
  try
    AssertTrue(S.Options.ShowFooter);
    AssertTrue(S.Options.ShowPenalty);
    for Orientation := 0 to 1 do for FooterOn := 0 to 1 do for PenaltyOn := 0 to 1 do
        begin
          S.Options.Orientation := TReportOrientation(Orientation);
          S.Options.Language := TReportLanguage(Orientation);
          S.Labels := ReportLabels(S.Options.Language);
          S.Options.ShowFooter := FooterOn = 1;
          S.Options.ShowPenalty := PenaltyOn = 1;
          D := Build(S);
          Text := '';
          AssertTrue(D.PageCount > 1);
          Columns := 6 + PenaltyOn;
          for I := 0 to D.PageCount - 1 do
          begin
            Text := Text + D.PageText(I);
            FooterCount := 0;
            for J := 0 to D.RuntimePage(I).BandCount - 1 do
            begin
              B := D.RuntimePage(I).Bands[J];
              if B is TFPReportPageFooterBand then Inc(FooterCount);
              if B is TFPReportDataBand then AssertEquals(Columns, B.ChildCount);
            end;
            AssertEquals('Footer bands are created only when enabled',
              FooterOn, FooterCount);
          end;
          AssertEquals(0, Pos('Статус', Text));
          AssertEquals(0, Pos('Status', Text));
          if FooterOn = 0 then
          begin
            AssertEquals(0, Pos('2026-10-31', Text));
            AssertEquals(0, Pos(S.Labels.Page + ' ', Text));
          end
          else
            AssertTrue(Pos(S.Labels.Page + ' ', Text) > 0);
          if PenaltyOn = 0 then
          begin
            AssertEquals(0, Pos(S.Labels.Columns[rcPenalty], Text));
            AssertEquals(0, Pos('PEN42', Text));
          end
          else
          begin
            AssertTrue(Pos(S.Labels.Columns[rcPenalty], Text) > 0);
            AssertEquals(1, Occurs('PEN42', Text));
          end;
          for I := 1 to 150 do
            AssertEquals(1, Occurs('RIDERTOKEN' + Format('%.4d', [I]), Text));
          Artifact(D, 'finish-options-' + IntToStr(Orientation) +
            '-' + IntToStr(FooterOn) + '-' + IntToStr(PenaltyOn));
          FreeAndNil(D);
        end;
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.EachCategoryPrecedesItsColumnHeadingsAndResults;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  Text: string;
  A, B: integer;
begin
  S := Sample(4);
  D := nil;
  try
    D := Build(S);
    AssertEquals(1, D.PageCount);
    Text := D.PageText(0);
    A := Pos('Категория A' + LineEnding, Text);
    B := Pos('Категория B' + LineEnding, Text);
    AssertTrue('Category captions have no participant counts', (A > 0) and (B > A));
    AssertEquals('Column headings appear for both categories', 2,
      Occurs('Место' + LineEnding, Text));
    AssertTrue(A < Pos('Место' + LineEnding, Text));
    AssertTrue(Pos('Место' + LineEnding, Text) < Pos('RIDERTOKEN0001', Text));
    Delete(Text, 1, B - 1);
    AssertTrue(Pos('Место' + LineEnding, Text) > 1);
    AssertTrue(Pos('Место' + LineEnding, Text) < Pos('RIDERTOKEN0003', Text));
    Artifact(D, 'finish-category-headings');
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.TemplateBlocksAreOnceAndInOrder;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  T: TReportTemplate;
  Text: string;
  I: integer;
begin
  S := Sample(150);
  D := nil;
  SetLength(T.Header, 1);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('ШАПКА [PageNo] <&>', 14, rpaRight);
  T.Footer[0] := ReportParagraph('ПОДПИСЬ', 12);
  S.Template := T;
  try
    D := Build(S);
    Text := '';
    for I := 0 to D.PageCount - 1 do Text := Text + D.PageText(I);
    AssertEquals(1, Occurs(T.Header[0].Text, Text));
    AssertEquals(1, Occurs('ПОДПИСЬ', Text));
    AssertTrue(Pos('ШАПКА', Text) < Pos(S.RaceName, Text));
    AssertTrue(Pos(S.Labels.Title, Text) < Pos('ШАПКА', Text));
    AssertTrue(Pos('ШАПКА', Text) < Pos('Категория A', Text));
    AssertTrue(Pos('RIDERTOKEN0150', Text) < Pos('ПОДПИСЬ', Text));
    Artifact(D, 'html-template-order');
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.LongTemplateParagraphsFlowWithoutLoss;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  T: TReportTemplate;
  Text, V: string;
  I, J, K: integer;
  B: TFPReportCustomBand;
  PageWidth: single;
begin
  S := Sample(4);
  D := nil;
  SetLength(T.Header, 1);
  SetLength(T.Footer, 1);
  V := '';
  for I := 1 to 180 do V := V + 'HEADER' + Format('%.4d', [I]) + #10;
  T.Header[0] := ReportParagraph(V, 12);
  V := '';
  for I := 1 to 180 do V := V + 'FOOTER' + Format('%.4d', [I]) + #10;
  T.Footer[0] := ReportParagraph(V, 12, rpaRight);
  S.Template := T;
  try
    for J := 0 to 1 do
    begin
      S.Options.Orientation := TReportOrientation(J);
      D := Build(S);
      AssertTrue(D.PageCount > 4);
      Text := '';
      PageWidth := 210;
      if J = 1 then PageWidth := 297;
      for I := 0 to D.PageCount - 1 do
      begin
        Text := Text + D.PageText(I);
        for K := 0 to D.RuntimePage(I).BandCount - 1 do
        begin
          B := D.RuntimePage(I).Bands[K];
          AssertTrue('Document bands remain inside the page',
            B.RTLayout.Left + B.RTLayout.Width <= PageWidth + 0.1);
        end;
      end;
      AssertEquals('Race name occurs once after the complete custom header', 1,
        Occurs(S.RaceName, Text));
      AssertTrue(Pos('HEADER0180', Text) < Pos(S.RaceName, Text));
      AssertEquals('No category heading on signature-only pages', 0,
        Pos('Категория', D.PageText(D.PageCount - 1)));
      for I := 1 to 180 do
      begin
        AssertEquals(1, Occurs('HEADER' + Format('%.4d', [I]), Text));
        AssertEquals(1, Occurs('FOOTER' + Format('%.4d', [I]), Text));
      end;
      for I := 1 to 4 do AssertEquals(1, Occurs('RIDERTOKEN' +
          Format('%.4d', [I]), Text));
      Artifact(D, 'html-template-long-' + IntToStr(J));
      FreeAndNil(D);
    end;
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.TemplateFormattingAndOptions;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  T: TReportTemplate;
  I, J, K, A, B, C: integer;
  Text: string;
  Band: TFPReportCustomBand;
  M: TFPReportMemo;
  Found: boolean;
begin
  S := Sample(2);
  D := nil;
  SetLength(T.Header, 2);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('Текст' + #10#10 +
    'Вторая строка', 18, rpaRight);
  T.Header[1] := ReportParagraph('');
  T.Footer[0] := ReportParagraph('=подпись', 6);
  S.Template := T;
  try
    for A := 0 to 1 do for B := 0 to 1 do for C := 0 to 1 do
        begin
          S.Options.ShowHeadings := A = 1;
          S.Options.ShowFooter := B = 1;
          S.Options.ShowPenalty := C = 1;
          D := Build(S);
          Text := '';
          Found := False;
          for I := 0 to D.PageCount - 1 do
          begin
            Text := Text + D.PageText(I);
            for J := 0 to D.RuntimePage(I).BandCount - 1 do
            begin
              Band := D.RuntimePage(I).Bands[J];
              for K := 0 to Band.ChildCount - 1 do if Band.Child[K] is TFPReportMemo then
                begin
                  M := TFPReportMemo(Band.Child[K]);
                  if M.Text = 'Текст' then
                  begin
                    Found := True;
                    AssertEquals(18, Round(M.Font.Size));
                    AssertEquals(Ord(taRightJustified), Ord(M.TextAlignment.Horizontal));
                  end;
                end;
            end;
          end;
          AssertTrue(Found);
          AssertTrue(Pos('=подпись', Text) > 0);
          AssertTrue(Pos('Вторая строка', Text) > 0);
          AssertEquals(A, Ord(Pos(S.RaceName, Text) > 0));
          AssertTrue(Pos(S.Labels.Title, Text) > 0);
          FreeAndNil(D);
        end;
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.HeaderIsOptionalAndRaceFollowsTemplate;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  T: TReportTemplate;
  Text: string;
  I, J: integer;
  B: TFPReportCustomBand;
begin
  S := Sample(150);
  D := nil;
  SetLength(T.Header, 1);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('CUSTOMHEADER');
  T.Footer[0] := ReportParagraph('CUSTOMFOOTER');
  S.Template := T;
  try
    AssertTrue(S.Options.ShowHeadings);
    S.Options.ShowHeadings := False;
    S.Options.ShowHeader := False;
    S.Options.ShowFooter := False;
    D := Build(S);
    Text := '';
    for I := 0 to D.PageCount - 1 do
    begin
      Text := Text + D.PageText(I);
      for J := 0 to D.RuntimePage(I).BandCount - 1 do
        AssertFalse(D.RuntimePage(I).Bands[J] is TFPReportPageHeaderBand);
    end;
    AssertEquals(0, Pos(S.Labels.Title, Text));
    AssertEquals(0, Occurs(S.RaceName, Text));
    AssertTrue(Pos('CUSTOMHEADER', Text) < Pos('RIDERTOKEN0001', Text));
    AssertTrue(Pos('RIDERTOKEN0150', Text) < Pos('CUSTOMFOOTER', Text));
    FreeAndNil(D);
    S.Options.ShowHeadings := True;
    S.Options.ShowHeader := True;
    D := Build(S);
    for I := 0 to D.PageCount - 1 do
    begin
      AssertTrue(Pos(S.Labels.Title, D.PageText(I)) > 0);
      B := D.RuntimePage(I).Bands[0];
      AssertTrue(B is TFPReportPageHeaderBand);
      AssertEquals(1, B.ChildCount);
      AssertEquals(8, TFPReportMemo(B.Child[0]).Font.Size);
      AssertEquals(ReportRegularFont, TFPReportMemo(B.Child[0]).Font.Name);
      AssertTrue(flBottom in TFPReportMemo(B.Child[0]).Frame.Lines);
    end;
    Artifact(D, 'html-upper-header');
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.PairedSignaturesShareOneDocumentBand;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  T: TReportTemplate;
  I, J, K, N: integer;
  B: TFPReportCustomBand;
  M: TFPReportMemo;
  Found: boolean;
  LeftText, RightText, AllText: string;
begin
  S := Sample(150);
  D := nil;
  SetLength(T.Footer, 1);
  T.Footer[0] := ReportParagraphPair(ReportParagraph('JUDGETOKEN', 12),
    ReportParagraph('SECRETARYTOKEN', 10, rpaRight));
  S.Template := T;
  try
    D := Build(S);
    Found := False;
    for I := 0 to D.PageCount - 1 do for J := 0 to D.RuntimePage(I).BandCount - 1 do
      begin
        B := D.RuntimePage(I).Bands[J];
        N := 0;
        for K := 0 to B.ChildCount - 1 do if B.Child[K] is TFPReportMemo then
          begin
            M := TFPReportMemo(B.Child[K]);
            if M.Text = 'JUDGETOKEN' then Inc(N);
            if M.Text = 'SECRETARYTOKEN' then Inc(N);
          end;
        if N = 2 then Found := True;
      end;
    AssertTrue('Both signatures occupy the same report row', Found);
    Artifact(D, 'paired-signatures');
    FreeAndNil(D);
    LeftText := '';
    RightText := '';
    for I := 1 to 80 do LeftText := LeftText + 'LEFT' + Format('%.4d', [I]) + #10;
    for I := 1 to 180 do RightText := RightText + 'RIGHT' + Format('%.4d', [I]) + #10;
    T.Footer[0] := ReportParagraphPair(ReportParagraph(LeftText, 10),
      ReportParagraph(RightText, 14, rpaRight));
    S.Template := T;
    D := Build(S);
    AssertTrue(D.PageCount > 4);
    AllText := '';
    for I := 0 to D.PageCount - 1 do AllText := AllText + D.PageText(I);
    for I := 1 to 80 do AssertEquals(1, Occurs('LEFT' + Format('%.4d', [I]), AllText));
    for I := 1 to 180 do AssertEquals(1, Occurs('RIGHT' + Format('%.4d', [I]), AllText));
    Artifact(D, 'paired-signatures-long');
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.BodyAndPageHeadingsSwitchIndependently;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  H, B: integer;
  Text: string;
begin
  S := Sample(4);
  D := nil;
  try
    for H := 0 to 1 do for B := 0 to 1 do
      begin
        S.Options.ShowHeader := H = 1;
        S.Options.ShowHeadings := B = 1;
        D := Build(S);
        Text := D.PageText(0);
        AssertEquals(H + B, Occurs(S.Labels.Title, Text));
        AssertEquals(B, Occurs(S.RaceName, Text));
        FreeAndNil(D);
      end;
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TStageFinishReportBuilderTests.CenterAlignmentInPreviewAndPairedCells;
var
  S: TStageReportSnapshot;
  D: TPreparedStageReport;
  T: TReportTemplate;
  I, J, K, Found: integer;
  B: TFPReportCustomBand;
  M: TFPReportMemo;
begin
  S := Sample(2);
  D := nil;
  SetLength(T.Header, 1);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('CENTERWHOLE', 14, rpaCenter);
  T.Footer[0] := ReportParagraphPair(ReportParagraph('CENTERLEFT', 10, rpaCenter),
    ReportParagraph('CENTERRIGHT', 12, rpaCenter));
  S.Template := T;
  try
    D := Build(S);
    Found := 0;
    for I := 0 to D.PageCount - 1 do for J := 0 to D.RuntimePage(I).BandCount - 1 do
      begin
        B := D.RuntimePage(I).Bands[J];
        for K := 0 to B.ChildCount - 1 do if B.Child[K] is TFPReportMemo then
          begin
            M := TFPReportMemo(B.Child[K]);
            if Pos('CENTER', M.Text) = 1 then
            begin
              Inc(Found);
              AssertEquals(Ord(taCentered), Ord(M.TextAlignment.Horizontal));
            end;
          end;
      end;
    AssertEquals('Whole paragraph and both paired cells are centered', 3, Found);
    Artifact(D, 'template-center');
  finally
    D.Free;
    S.Free;
  end;
end;

initialization
  RegisterTest(TStageFinishReportBuilderTests);
end.
