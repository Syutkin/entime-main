unit StageFinishDocxWriter;
{$mode objfpc}{$H+}
interface

uses ProtocolDocumentModel, StageFinishReportModel, StageFinishReportFiles;

function SaveStageFinishDocx(const Snapshot: TStageReportSnapshot;
  const Target: string; Files: TStageReportFiles = nil): boolean;

function SaveProtocolDocx(const Snapshot: TProtocolDocument;
  const Target: string; Files: TStageReportFiles = nil): boolean;

implementation

uses Classes, SysUtils, ProtocolTableLayout, fpvectorial, docxvectorialwriter,
  fpvutils, FPImage,
  ReportTemplateModel, StageFinishReportBuilder, StageFinishReportBackend;

type
  TDocxOutput = class
    Snapshot: TProtocolDocument;
    procedure WriteFile(const Path: string);
  end;

procedure TDocxOutput.WriteFile(const Path: string);
var
  LastColumn, K: integer;
  GroupWidth: single;
  Master: TProtocolDocument;
  Views: TProtocolDocuments;
  V, TableFont: integer;
  Separate: boolean;
  Doc: TvVectorialDocument;
  Page: TvTextPageSequence;
  BodyStyle, BoldStyle, TitleStyle, HeadingStyle, ProtocolStyle, CategoryStyle: TvStyle;
  P: TvParagraph;
  FooterLeftStyle, FooterRightStyle: TvStyle;
  TemplateStyles: array[6..36, TReportParagraphAlignment] of TvStyle;
  Template: TReportTemplate;
  Table: TvTable;
  Row: TvTableRow;
  Cell: TvTableCell;
  Widths: TProtocolWidths;
  C: integer;
  I, J, GroupEnd: integer;
  Race, Heading, Category: string;

  function Style(const Name: string; Size: integer; Bold: boolean): TvStyle;
  begin
    Result := Doc.AddStyle;
    Result.Name := Name;
    Result.Kind := vskTextBody;
    Result.Font.Name := ReportFontFamily;
    Result.Font.Size := Size;
    Result.Font.Bold := Bold;
    Result.MarginTop := 0;
    Result.MarginBottom := 0;
    Result.SetElements := [spbfFontName, spbfFontSize, spbfFontBold,
      sseMarginTop, sseMarginBottom];
  end;

  function TwoColumnTable(Parent: TvRichText): TvTable;
  var
    W: single;
  begin
    Result := Parent.AddTable;
    Result.PreferredWidth := Dimension(100, dimPercent);
    Result.ColWidthsUnits := dimMillimeter;
    W := (Page.Width - Page.MarginLeft - Page.MarginRight) / 2;
    Result.AddColWidth(W);
    Result.AddColWidth(W);
    Result.CellSpacingLeft := 0;
    Result.CellSpacingRight := 0;
    Result.CellSpacingTop := 0;
    Result.CellSpacingBottom := 0;
    Result.Borders.Left.LineType := tbtDefault;
    Result.Borders.Right.LineType := tbtDefault;
    Result.Borders.Top.LineType := tbtDefault;
    Result.Borders.Bottom.LineType := tbtDefault;
    Result.Borders.InsideHoriz.LineType := tbtDefault;
    Result.Borders.InsideVert.LineType := tbtDefault;
  end;

  procedure PageFooter;
  var
    FooterTable: TvTable;
    FooterRow: TvTableRow;
    FooterCell: TvTableCell;
  begin
    if FooterLeftStyle = nil then
    begin
      FooterLeftStyle := Style('Footer date', 8, False);
      FooterLeftStyle.Alignment := vsaLeft;
      Include(FooterLeftStyle.SetElements, spbfAlignment);
      FooterRightStyle := Style('Footer page number', 8, False);
      FooterRightStyle.Alignment := vsaRight;
      Include(FooterRightStyle.SetElements, spbfAlignment);
    end;
    FooterTable := TwoColumnTable(Page.Footer);
    FooterRow := FooterTable.AddRow;
    FooterCell := FooterRow.AddCell;
    FooterCell.SpacingLeft := 0;
    FooterCell.SpacingRight := 0;
    P := FooterCell.AddParagraph;
    P.Style := FooterLeftStyle;
    P.AddText(FormatDateTime('yyyy-mm-dd hh:nn:ss', Snapshot.FormedAt));
    FooterCell := FooterRow.AddCell;
    FooterCell.SpacingLeft := 0;
    FooterCell.SpacingRight := 0;
    P := FooterCell.AddParagraph;
    P.Style := FooterRightStyle;
    P.AddText(Snapshot.Labels.Page + ' ');
    P.AddField(vfkPage);
    P.AddText(' ' + Snapshot.Labels.OfPages + ' ');
    P.AddField(vfkNumPages);
  end;

  function TemplateStyle(Size: integer; Alignment: TReportParagraphAlignment): TvStyle;
  var
    Suffix: string;
  begin
    Result := TemplateStyles[Size, Alignment];
    if Result <> nil then Exit;
    case Alignment of
      rpaLeft: Suffix := 'left';
      rpaRight: Suffix := 'right';
      rpaCenter: Suffix := 'center';
    end;
    Result := Style('Template ' + IntToStr(Size) + ' ' + Suffix, Size, False);
    case Alignment of
      rpaLeft: Result.Alignment := vsaLeft;
      rpaRight: Result.Alignment := vsaRight;
      rpaCenter: Result.Alignment := vsaCenter;
    end;
    Include(Result.SetElements, spbfAlignment);
    TemplateStyles[Size, Alignment] := Result;
  end;

  procedure TemplateParagraphs(const Paragraphs: TReportParagraphs);
  var
    Value: TReportParagraph;
    PairTable: TvTable;
    PairRow: TvTableRow;
    PairCell: TvTableCell;
    W: single;
  begin
    for Value in Paragraphs do
    begin
      if Value.IsPair then
      begin
        // Word merges adjacent tables. Keep signatures separate from result borders.
        if (Page.GetEntitiesCount > 0) and
          (Page.GetEntity(Page.GetEntitiesCount - 1) = Table) then
        begin
          P := Page.AddParagraph;
          P.Style := BodyStyle;
        end;
        PairTable := TwoColumnTable(Page.MainText);
        W := (Page.Width - Page.MarginLeft - Page.MarginRight) / 2;
        PairRow := PairTable.AddRow;
        PairRow.AllowSplitAcrossPage := True;
        PairCell := PairRow.AddCell;
        PairCell.PreferredWidth := Dimension(W, dimMillimeter);
        P := PairCell.AddParagraph;
        P.Style := TemplateStyle(Value.FontSize, Value.Alignment);
        P.AddText(Value.Text);
        PairCell := PairRow.AddCell;
        PairCell.PreferredWidth := Dimension(W, dimMillimeter);
        P := PairCell.AddParagraph;
        P.Style := TemplateStyle(Value.RightFontSize, Value.RightAlignment);
        P.AddText(Value.RightText);
      end
      else
      begin
        P := Page.AddParagraph;
        P.Style := TemplateStyle(Value.FontSize, Value.Alignment);
        P.AddText(Value.Text);
      end;
    end;
  end;

  procedure AddCell(const Text: string; AStyle: TvStyle; Width: single);
  begin
    Cell := Row.AddCell;
    Cell.PreferredWidth := Dimension(Width, dimMillimeter);
    P := Cell.AddParagraph;
    P.Style := AStyle;
    P.AddText(Text);
  end;

  procedure BeginSection;
  begin
    Page := Doc.AddTextPageSequence;
    Page.Width := 210;
    Page.Height := 297;
    if Snapshot.Options.Landscape then
    begin
      Page.Width := 297;
      Page.Height := 210;
    end;
    Page.SetPageMargin(10);
    Doc.Width := Page.Width;
    Doc.Height := Page.Height;
    Race := Snapshot.RaceName;
    if Trim(Race) = '' then Race := Snapshot.Labels.Competition;
    Heading := Snapshot.Heading;
    if Snapshot.Options.ShowHeader then
    begin
      P := Page.Header.AddParagraph;
      P.Style := HeadingStyle;
      P.AddText(Heading);
    end;
    if Snapshot.Options.ShowFooter then PageFooter;
    TemplateParagraphs(Template.Header);
    if Snapshot.Options.ShowHeadings then
    begin
      P := Page.AddParagraph;
      P.Style := TitleStyle;
      P.AddText(Race);
      P := Page.AddParagraph;
      P.Style := ProtocolStyle;
      P.AddText(Heading);
    end;
  end;

begin
  FillChar(TemplateStyles, SizeOf(TemplateStyles), 0);
  FooterLeftStyle := nil;
  FooterRightStyle := nil;
  Master := Snapshot;
  Views := nil;
  Template := Snapshot.Template;
  Table := nil;
  Doc := TvVectorialDocument.Create;
  try
    Views := ProtocolPrintViews(Master);
    Separate := Length(Master.Sections) > 0;
    TableFont := ProtocolFontSize(Views[0]);
    BodyStyle := Style('Protocol body', TableFont, False);
    BoldStyle := Style('Protocol heading', TableFont, True);
    TitleStyle := Style('Competition title', CompetitionTitleFontSize, True);
    TitleStyle.MarginBottom := 2;
    ProtocolStyle := Style('Protocol title', 8, True);
    ProtocolStyle.MarginBottom := 2;
    HeadingStyle := Style('Protocol header', 8, False);
    HeadingStyle.MarginBottom := 2;
    HeadingStyle.Font.Color := colGray;
    Include(HeadingStyle.SetElements, spbfFontColor);
    CategoryStyle := Style('Category title', CategoryTitleFontSize, True);
    CategoryStyle.MarginTop := 3;
    CategoryStyle.MarginBottom := 1;
    if not Separate then BeginSection;
    for V := 0 to High(Views) do
    begin
      Snapshot := Views[V];
      if Separate then
      begin
        Template := Snapshot.Template;
        BeginSection;
      end;
      Widths := ProtocolWidths(Snapshot);
      I := 0;
      while I < Length(Snapshot.Rows) do
      begin
        Category := Snapshot.Rows[I].Category;
        GroupEnd := I + 1;
        while (GroupEnd < Length(Snapshot.Rows)) and
          (Snapshot.Options.HideCategories or
            (Snapshot.Rows[GroupEnd].Category = Category)) do
          Inc(GroupEnd);
        if not Snapshot.Options.HideCategories then
        begin
          if Category = '' then Category := Snapshot.Labels.NoCategory;
          P := Page.AddParagraph;
          P.Style := CategoryStyle;
          P.AddText(Category);
        end;
        Table := Page.AddTable;
        Table.PreferredWidth := Dimension(100, dimPercent);
        Table.ColWidthsUnits := dimMillimeter;
        Table.CellSpacingLeft := TableFont / 8;
        Table.CellSpacingRight := TableFont / 8;
        Table.CellSpacingTop := 0.5 * TableFont / 8;
        Table.CellSpacingBottom := 0.5 * TableFont / 8;
        for C := 0 to High(Widths) do if Widths[C] > 0 then Table.AddColWidth(Widths[C]);
        if ProtocolHasGroupedHeaders(Snapshot) then
        begin
          Row := Table.AddRow;
          Row.Header := True;
          C := 0;
          while C < Length(Widths) do
          begin
            LastColumn := ProtocolGroupEnd(Snapshot, C);
            GroupWidth := 0;
            for K := C to LastColumn do GroupWidth := GroupWidth + Widths[K];
            AddCell(Snapshot.Columns[C].GroupCaption, BoldStyle, GroupWidth);
            Cell.SpannedCols := LastColumn - C + 1;
            C := LastColumn + 1;
          end;
        end;
        Row := Table.AddRow;
        Row.Header := True;
        for C := 0 to High(Widths) do if Widths[C] > 0 then
            AddCell(ProtocolColumnCaption(Snapshot, C), BoldStyle, Widths[C]);
        for J := I to GroupEnd - 1 do
        begin
          Row := Table.AddRow;
          Row.AllowSplitAcrossPage := True;
          for C := 0 to High(Widths) do if Widths[C] > 0 then
              AddCell(Snapshot.Rows[J].Cells[C], BodyStyle, Widths[C]);
        end;
        I := GroupEnd;
      end;
      if Separate then TemplateParagraphs(Template.Footer);
    end;
    Snapshot := Master;
    if not Separate then TemplateParagraphs(Template.Footer);
    // FPVectorial writes actual paragraphs and tables; the editor controls wrapping
    // and pagination. Never export FPReport's already split drawing fragments.
    Doc.WriteToFile(Path, vfDOCX);
  finally
    Snapshot := Master;
    FreeProtocolDocuments(Views);
    Doc.Free;
  end;
end;

function SaveProtocolDocx(const Snapshot: TProtocolDocument;
  const Target: string; Files: TStageReportFiles): boolean;
var
  Output: TDocxOutput;
begin
  Result := False;
  if Target = '' then Exit;
  if Snapshot = nil then raise EArgumentNilException.Create('Snapshot');
  if Length(Snapshot.Rows) = 0 then
    raise EArgumentException.Create('Report has no participants');
  Output := TDocxOutput.Create;
  try
    Output.Snapshot := Snapshot;
    Result := SaveStageReportFile(Target, @Output.WriteFile, Files);
  finally
    Output.Free;
  end;
end;

function SaveStageFinishDocx(const Snapshot: TStageReportSnapshot;
  const Target: string; Files: TStageReportFiles): boolean;
var
  D: TProtocolDocument;
begin
  if Snapshot = nil then raise EArgumentNilException.Create('Snapshot');
  D := StageProtocolDocument(Snapshot);
  try
    Result := SaveProtocolDocx(D, Target, Files);
  finally
    D.Free;
  end;
end;

end.
