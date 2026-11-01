unit StageFinishXlsxWriter;
{$mode objfpc}{$H+}
interface

uses ProtocolDocumentModel, StageFinishReportModel, StageFinishReportFiles;

function SaveStageFinishXlsx(const Snapshot: TStageReportSnapshot;
  const Target: string; Files: TStageReportFiles = nil): boolean;

function SaveProtocolXlsx(const Snapshot: TProtocolDocument;
  const Target: string; Files: TStageReportFiles = nil): boolean;

implementation

uses Classes, SysUtils, ProtocolTableLayout, ReportTemplateModel,
  ReportTextMetrics, fpspreadsheet,
  fpstypes, xlsxooxml, StageFinishReportBuilder, StageFinishReportBackend;

type
  TXlsxOutput = class
    Snapshot: TProtocolDocument;
    procedure WriteFile(const Path: string);
  end;

procedure TXlsxOutput.WriteFile(const Path: string);
var
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  Widths: TProtocolWidths;
  Row, Col, Columns, GroupEnd, Number, BoldFont, TitleFont, CategoryFont: integer;
  Race, Heading, Category, Text: string;
  Template: TReportTemplate;
  Wide: boolean;
  Available, Used, GroupWidth: single;
  FirstCol, LastCol, RepeatCount: integer;
  Views: TProtocolDocuments;
  View: TProtocolDocument;
  Master: TProtocolDocument;

  procedure HeadingRow(const Value: string; Font: integer);
  begin
    Sheet.WriteText(Row, 0, Value);
    Sheet.WriteFont(Row, 0, Font);
    Sheet.MergeCells(Row, 0, Row, Columns - 1);
    Sheet.WriteWordwrap(Row, 0, True);
    Inc(Row);
  end;

  procedure TemplateRows(const Paragraphs: TReportParagraphs);
  var
    Value: TReportParagraph;
    Lines, RightLines: TStringList;
    Measure: TReportText;
    Line: string;
    W, LeftWidth, RightWidth, H: single;
    K, N, SplitColumn, ColumnIndex: integer;
    Column: integer;

    procedure WritePart(const Text: string; Size: integer;
      Alignment: TReportParagraphAlignment; First, Last: integer);
    begin
      Sheet.WriteText(Row, First, Text);
      Sheet.WriteFont(Row, First, Book.AddFont(ReportFontFamily, Size, [], scBlack));
      Sheet.MergeCells(Row, First, Row, Last);
      Sheet.WriteWordwrap(Row, First, True);
      case Alignment of
        rpaLeft: Sheet.WriteHorAlignment(Row, First, haLeft);
        rpaRight: Sheet.WriteHorAlignment(Row, First, haRight);
        rpaCenter: Sheet.WriteHorAlignment(Row, First, haCenter);
      end;
    end;

  begin
    W := 0;
    LeftWidth := 0;
    SplitColumn := Columns div 2;
    ColumnIndex := 0;
    for Column := 0 to High(Widths) do if Widths[Column] > 0 then
      begin
        W := W + Widths[Column];
        if ColumnIndex < SplitColumn then LeftWidth := LeftWidth + Widths[Column];
        Inc(ColumnIndex);
      end;
    RightWidth := W - LeftWidth;
    Measure := TReportText.Create(nil);
    Lines := TStringList.Create;
    RightLines := TStringList.Create;
    try
      for Value in Paragraphs do
      begin
        if Value.IsPair then Measure.Wrap(Value.Text, LeftWidth - 2,
            Lines, '', Value.FontSize)
        else
          Measure.Wrap(Value.Text, W - 2, Lines, '', Value.FontSize);
        H := Measure.LineHeight;
        N := Lines.Count;
        RightLines.Clear;
        if Value.IsPair then
        begin
          Measure.Wrap(Value.RightText, RightWidth - 2, RightLines,
            '', Value.RightFontSize);
          if Measure.LineHeight > H then H := Measure.LineHeight;
          if RightLines.Count > N then N := RightLines.Count;
        end;
        for K := 0 to N - 1 do
        begin
          Line := '';
          if K < Lines.Count then Line := Lines[K];
          if Value.IsPair then
            WritePart(Line, Value.FontSize, Value.Alignment, 0, SplitColumn - 1)
          else
            WritePart(Line, Value.FontSize, Value.Alignment, 0, Columns - 1);
          if Value.IsPair then
          begin
            Line := '';
            if K < RightLines.Count then Line := RightLines[K];
            WritePart(Line, Value.RightFontSize, Value.RightAlignment,
              SplitColumn, Columns - 1);
          end;
          Sheet.WriteRowHeight(Row, H + 1, suMillimeters);
          Inc(Row);
        end;
      end;
    finally
      RightLines.Free;
      Lines.Free;
      Measure.Free;
    end;
  end;

  function TableHeaderHeight(Grouped: boolean): single;
  var
    M: TReportText;
    L: TStringList;
    First, Last, K: integer;
    W: single;
    Text: string;
  begin
    Result := 5;
    M := TReportText.Create(nil);
    L := TStringList.Create;
    try
      First := 0;
      while First < Length(Widths) do
      begin
        Last := First;
        Text := ProtocolColumnCaption(Snapshot, First);
        if Grouped then
        begin
          Last := ProtocolGroupEnd(Snapshot, First);
          Text := Snapshot.Columns[First].GroupCaption;
        end;
        W := 0;
        for K := First to Last do W := W + Widths[K];
        M.Wrap(Text, W - 2, L, ReportBoldFont);
        if M.LineHeight * L.Count + 1 > Result then Result := M.LineHeight * L.Count + 1;
        First := Last + 1;
      end;
    finally
      L.Free;
      M.Free;
    end;
  end;

  procedure PageHeader;
  var
    Measure: TReportText;
    Lines: TStringList;
    Column: integer;
    W, H: single;
  begin
    if not Snapshot.Options.ShowHeader then Exit;
    W := 0;
    for Column := 0 to High(Widths) do W := W + Widths[Column];
    Measure := TReportText.Create(nil);
    Lines := TStringList.Create;
    try
      Measure.Wrap(Heading, W - 2, Lines, '', 8);
      Sheet.PageLayout.Headers[1] :=
        '&L&"' + ReportFontFamily + ',Regular"&8&K808080' +
        StringReplace(TrimRight(Lines.Text), '&', '&&', [rfReplaceAll]);
      H := Sheet.PageLayout.HeaderMargin + Measure.LineHeight * Lines.Count + 1;
      if H > Sheet.PageLayout.TopMargin then Sheet.PageLayout.TopMargin := H;
    finally
      Lines.Free;
      Measure.Free;
    end;
  end;

  procedure WriteSheet;
  var
    C, I, J, K, HeaderFirstRow: integer;
  begin
    Template := Snapshot.Template;
    Book.SetDefaultFont(ReportFontFamily, 8);
    BoldFont := Book.AddFont(ReportFontFamily, 8, [fssBold], scBlack);
    TitleFont := Book.AddFont(ReportFontFamily, CompetitionTitleFontSize,
      [fssBold], scBlack);
    CategoryFont := Book.AddFont(ReportFontFamily, CategoryTitleFontSize,
      [fssBold], scBlack);
    Text := Snapshot.SheetName;
    if Text = '' then Text := Snapshot.Labels.Title;
    Sheet := Book.AddWorksheet(Text);
    Widths := ProtocolWidths(Snapshot);
    Available := 190;
    if Snapshot.Options.Landscape then Available := 277;
    Used := 0;
    for C := 0 to High(Widths) do Used := Used + Widths[C];
    // Wide sheets use native print scaling. Narrow fitted tables fill the page
    // by expanding their columns while keeping the regular font size.
    if Snapshot.Options.FitToWidth and (Used < Available) then
      FitProtocolWidths(Widths, Available);
    Columns := 0;
    for C := 0 to High(Widths) do if Widths[C] > 0 then
      begin
        Sheet.WriteColWidth(Columns, Widths[C], suMillimeters);
        Inc(Columns);
      end;
    Race := Snapshot.RaceName;
    if Trim(Race) = '' then Race := Snapshot.Labels.Competition;
    Heading := Snapshot.Heading;
    Row := 0;
    TemplateRows(Template.Header);
    if Snapshot.Options.ShowHeadings then
    begin
      HeadingRow(Race, TitleFont);
      HeadingRow(Heading, BoldFont);
    end;
    I := 0;
    while I < Length(Snapshot.Rows) do
    begin
      Category := Snapshot.Rows[I].Category;
      GroupEnd := I + 1;
      while (GroupEnd < Length(Snapshot.Rows)) and
        (Snapshot.Options.HideCategories or (Snapshot.Rows[GroupEnd].Category =
          Category)) do
        Inc(GroupEnd);
      if not Snapshot.Options.HideCategories then
      begin
        if Category = '' then Category := Snapshot.Labels.NoCategory;
        HeadingRow(Category, CategoryFont);
      end;
      HeaderFirstRow := Row;
      if ProtocolHasGroupedHeaders(Snapshot) then
      begin
        C := 0;
        while C < Length(Widths) do
        begin
          LastCol := ProtocolGroupEnd(Snapshot, C);
          Sheet.WriteText(Row, C, Snapshot.Columns[C].GroupCaption);
          Sheet.WriteFont(Row, C, BoldFont);
          Sheet.WriteWordwrap(Row, C, True);
          if LastCol > C then Sheet.MergeCells(Row, C, Row, LastCol);
          C := LastCol + 1;
        end;
        Sheet.WriteRowHeight(Row, TableHeaderHeight(True), suMillimeters);
        Inc(Row);
      end;
      Col := 0;
      for C := 0 to High(Widths) do if Widths[C] > 0 then
        begin
          Sheet.WriteText(Row, Col, ProtocolColumnCaption(Snapshot, C));
          Sheet.WriteFont(Row, Col, BoldFont);
          if Snapshot.Columns[C].Role = pcrNumber then
            Sheet.WriteHorAlignment(Row, Col, haCenter);
          Sheet.WriteWordwrap(Row, Col, True);
          Inc(Col);
        end;
      Sheet.WriteRowHeight(Row, TableHeaderHeight(False), suMillimeters);
      Inc(Row);
      if Snapshot.Options.HideCategories then
        Sheet.PageLayout.SetRepeatedRows(HeaderFirstRow, Row - 1);
      for J := I to GroupEnd - 1 do
      begin
        Col := 0;
        for C := 0 to High(Widths) do if Widths[C] > 0 then
          begin
            Text := Snapshot.Rows[J].Cells[C];
            if (Snapshot.Columns[C].Role = pcrNumber) and TryStrToInt(Text, Number) then
              Sheet.WriteNumber(Row, Col, Number)
            else
              Sheet.WriteText(Row, Col, Text);
            // Preserve the saved display strings, including full time precision and
            // literal user text. Wrapping and subsequent edits belong to the editor.
            Sheet.WriteWordwrap(Row, Col, True);
            Sheet.WriteVertAlignment(Row, Col, vaTop);
            if Snapshot.Columns[C].Role = pcrNumber then
              Sheet.WriteHorAlignment(Row, Col, haCenter);
            Inc(Col);
          end;
        Inc(Row);
      end;
      I := GroupEnd;
    end;
    TemplateRows(Template.Footer);
    Sheet.PageLayout.PageWidth := 210;
    Sheet.PageLayout.PageHeight := 297;
    if Snapshot.Options.Landscape then
      Sheet.PageLayout.Orientation := spoLandscape
    else
      Sheet.PageLayout.Orientation := spoPortrait;
    Sheet.PageLayout.LeftMargin := 10;
    Sheet.PageLayout.RightMargin := 10;
    Sheet.PageLayout.TopMargin := 10;
    Sheet.PageLayout.BottomMargin := 10;
    Sheet.PageLayout.FooterMargin := 5;
    Sheet.PageLayout.HeaderMargin := 5;
    Sheet.PageLayout.FitWidthToPages := 1;
    Sheet.PageLayout.FitHeightToPages := 0;
    Used := 0;
    for C := 0 to High(Widths) do Used := Used + Widths[C];
    Wide := Used > Available;
    if Wide and not Snapshot.Options.FitToWidth then
    begin
      // Clear the stored fit limits too: the OOXML writer uses them for sheetPr.
      Sheet.PageLayout.FitWidthToPages := 0;
      Sheet.PageLayout.FitHeightToPages := 0;
      Sheet.PageLayout.ScalingFactor := 100;
      RepeatCount := 0;
      while (RepeatCount < 3) and (RepeatCount < Length(Widths)) and
        (Snapshot.Columns[RepeatCount].StageIndex = 0) do Inc(RepeatCount);
      if RepeatCount > 0 then Sheet.PageLayout.SetRepeatedCols(0, RepeatCount - 1);
      Used := 0;
      FirstCol := 0;
      while FirstCol < Length(Widths) do
      begin
        LastCol := FirstCol;
        if Snapshot.Columns[FirstCol].StageIndex > 0 then
          while (LastCol < High(Widths)) and
            (Snapshot.Columns[LastCol + 1].StageIndex =
              Snapshot.Columns[FirstCol].StageIndex) do
            Inc(LastCol)
        else if FirstCol > 3 then LastCol := High(Widths);
        GroupWidth := 0;
        for K := FirstCol to LastCol do GroupWidth := GroupWidth + Widths[K];
        if (Used + GroupWidth > Available) and (FirstCol >= RepeatCount) then
        begin
          Sheet.AddPageBreakToCol(FirstCol);
          Used := 0;
          for K := 0 to RepeatCount - 1 do Used := Used + Widths[K];
        end;
        Used := Used + GroupWidth;
        FirstCol := LastCol + 1;
      end;
    end;
    PageHeader;
    Sheet.PageLayout.AddPrintRange(0, 0, Row - 1, Columns - 1);
    if Snapshot.Options.ShowFooter then
      Sheet.PageLayout.Footers[1] :=
        '&L' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Snapshot.FormedAt) +
        '&R' + Snapshot.Labels.Page + ' &P ' + Snapshot.Labels.OfPages + ' &N'
    else
      Sheet.PageLayout.Footers[1] := '';
  end;

begin
  Master := Snapshot;
  Views := nil;
  Book := TsWorkbook.Create;
  try
    if Length(Master.Sections) > 0 then
    begin
      Views := ProtocolPrintViews(Master);
      for View in Views do
      begin
        Snapshot := View;
        WriteSheet;
      end;
    end
    else
      WriteSheet;
    Book.WriteToFile(Path, sfOOXML, True);
  finally
    Snapshot := Master;
    FreeProtocolDocuments(Views);
    Book.Free;
  end;
end;

function SaveProtocolXlsx(const Snapshot: TProtocolDocument;
  const Target: string; Files: TStageReportFiles): boolean;
var
  Output: TXlsxOutput;
begin
  Result := False;
  if Target = '' then Exit;
  if Snapshot = nil then raise EArgumentNilException.Create('Snapshot');
  if Length(Snapshot.Rows) = 0 then
    raise EArgumentException.Create('Report has no participants');
  Output := TXlsxOutput.Create;
  try
    Output.Snapshot := Snapshot;
    Result := SaveStageReportFile(Target, @Output.WriteFile, Files);
  finally
    Output.Free;
  end;
end;

function SaveStageFinishXlsx(const Snapshot: TStageReportSnapshot;
  const Target: string; Files: TStageReportFiles): boolean;
var
  D: TProtocolDocument;
begin
  if Snapshot = nil then raise EArgumentNilException.Create('Snapshot');
  D := StageProtocolDocument(Snapshot);
  try
    Result := SaveProtocolXlsx(D, Target, Files);
  finally
    D.Free;
  end;
end;

end.
