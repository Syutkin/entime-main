unit StartLabelReportBuilder;
{$mode objfpc}{$H+}
interface

uses SysUtils, StartLabelModel, StageFinishReportBackend;

type
  EStartLabelsDoNotFit = class(Exception)
  public
    Count: integer;
    constructor Create(ACount: integer);
  end;

  TStartLabelReport = class(TPreparedStageReport)
  private
    FTableFontSize, FOverflowCount: integer;
  public
    procedure WritePdf(const FileName: string); override;
    property TableFontSize: integer read FTableFontSize;
    property OverflowCount: integer read FOverflowCount;
  end;

function BuildStartLabelReport(const Cards: TStartLabelCards;
  const Paper: TStartLabelPaper; AllowOverflow: boolean = False): TStartLabelReport;

implementation

uses Classes, fpreport, fpTTF, ReportTextMetrics, Math;

const
  StartBlockGap = 2; // millimetres between the two SU/time blocks

type
  TLabelTextLayout = record
    Header: string;
    HeaderHeight, RowHeight, StageWidth, BlockWidth: single;
    RowsPerColumn: integer;
    Fits: boolean;
  end;
  TLabelTextLayouts = array of TLabelTextLayout;

function TextWidth(const S, Face: string; Size: integer): single;
begin
  Result := gTTFontCache.FindFont(Face).TextWidth(S, Size) * 25.4 / gTTFontCache.DPI;
end;

function CharactersFit(const S: string; Width: single; Size: integer): boolean;
var
  I, N: integer;
begin
  I := 1;
  while I <= Length(S) do
  begin
    N := 1;
    while (I + N <= Length(S)) and ((Ord(S[I + N]) and $C0) = $80) do Inc(N);
    if not (S[I] in [#10, #13]) and (TextWidth(Copy(S, I, N), ReportBoldFont, Size) >
      Width) then Exit(False);
    Inc(I, N);
  end;
  Result := True;
end;

function ClippedLine(const S, Face: string; Width: single; Size: integer): string;
var
  I, N: integer;
begin
  Result := '';
  I := 1;
  while (I <= Length(S)) and not (S[I] in [#10, #13]) do
  begin
    N := 1;
    while (I + N <= Length(S)) and ((Ord(S[I + N]) and $C0) = $80) do Inc(N);
    if TextWidth(Copy(S, 1, I + N - 1), Face, Size) > Width then Break;
    Inc(I, N);
  end;
  Result := Copy(S, 1, I - 1);
end;

function MeasureCard(const Card: TStartLabelCard; const Paper: TStartLabelPaper;
  Size: integer; out Layout: TLabelTextLayout): boolean;
var
  M: TReportText;
  Lines: TStringList;
  InnerWidth, InnerHeight: single;
  E: TStartLabelEntry;
  HeaderFits: boolean;
begin
  Result := False;
  Layout := Default(TLabelTextLayout);
  InnerWidth := (Paper.Width - 2 * Paper.Padding) / StartLabelUnitsPerMM;
  InnerHeight := (Paper.Height - 2 * Paper.Padding) / StartLabelUnitsPerMM;
  Layout.BlockWidth := (InnerWidth - (Paper.StartColumns - 1) * StartBlockGap) /
    Paper.StartColumns;
  Layout.RowsPerColumn := (Length(Card.Entries) + Paper.StartColumns - 1) div
    Paper.StartColumns;
  Layout.StageWidth := TextWidth('32', ReportRegularFont, Size) + 1;
  HeaderFits := CharactersFit(Card.Title, InnerWidth, Size + 2);
  Result := HeaderFits;
  for E in Card.Entries do
    if (TextWidth(E.Time, ReportRegularFont, Size) > Layout.BlockWidth -
      Layout.StageWidth) or (TextWidth(IntToStr(E.StageIndex), ReportRegularFont, Size) >
      Layout.StageWidth) then
      Result := False;
  M := TReportText.Create(nil);
  Lines := TStringList.Create;
  try
    if HeaderFits then
    begin
      M.Wrap(Card.Title, InnerWidth, Lines, ReportBoldFont, Size + 2, 0);
      Layout.Header := TrimRight(Lines.Text);
    end
    else
    begin
      M.Wrap('M', Max(InnerWidth, 10), Lines, ReportBoldFont, Size + 2, 0);
      Layout.Header := ClippedLine(Card.Title, ReportBoldFont, InnerWidth, Size + 2);
    end;
    Layout.HeaderHeight := Max(1, Lines.Count) * M.LineHeight + 0.1;
    M.Wrap('32', Max(InnerWidth, 10), Lines, ReportRegularFont, Size, 0);
    Layout.RowHeight := M.LineHeight + 0.3;
    Result := Result and (Layout.HeaderHeight + 1 + Layout.RowsPerColumn *
      Layout.RowHeight <= InnerHeight);
  finally
    Lines.Free;
    M.Free;
  end;
end;

function AddMemo(B: TFPReportTitleBand; const Text: string; X, Y, W, H: single;
  Size: integer; Bold: boolean): TFPReportMemo;
var
  V: TFPReportVariable;
begin
  Result := TFPReportMemo.Create(B);
  Result.Layout.Left := X;
  Result.Layout.Top := Y;
  Result.Layout.Width := W;
  Result.Layout.Height := H;
  Result.Text := Text;
  Result.Options := [moDisableExpressions];
  // FPReport's cache parses bracketed expressions even for literal memos.
  // Supplying such text as a variable keeps participant data out of the parser.
  if (Pos('[', Text) > 0) or (Pos(']', Text) > 0) then
  begin
    V := B.Report.Variables.AddVariable('LabelText' +
      IntToStr(B.Report.Variables.Count));
    V.AsString := Text;
    Result.Text := '[' + V.Name + ']';
    Result.Options := [];
  end;
  Result.Font.Name := ReportRegularFont;
  if Bold then Result.Font.Name := ReportBoldFont;
  Result.Font.Size := Size;
  Result.TextAlignment.LeftMargin := 0;
  Result.TextAlignment.RightMargin := 0;
  Result.TextAlignment.TopMargin := 0;
  Result.TextAlignment.BottomMargin := 0;
  if Bold then Result.TextAlignment.Horizontal := taCentered;
end;

constructor EStartLabelsDoNotFit.Create(ACount: integer);
begin
  inherited Create('Labels do not fit: ' + IntToStr(ACount));
  Count := ACount;
end;

procedure TStartLabelReport.WritePdf(const FileName: string);
begin
  if FOverflowCount > 0 then raise EStartLabelsDoNotFit.Create(FOverflowCount);
  inherited WritePdf(FileName);
end;

function BuildStartLabelReport(const Cards: TStartLabelCards;
  const Paper: TStartLabelPaper; AllowOverflow: boolean): TStartLabelReport;
var
  L: TStartLabelLayout;
  Texts: TLabelTextLayouts;
  I, J, Size, PageIndex, OverflowCount: integer;
  Fits: boolean;
  Page: TFPReportPage;
  Band: TFPReportTitleBand;
  X, Y, W, RowX, RowY, RightEdge, BottomEdge: single;
  Frame: TFPReportMemo;

  procedure ContentMemo(const Text: string; X, Y, W, H: single;
    FontSize: integer; Bold: boolean);
  var
    Value: string;
    M: TFPReportMemo;
  begin
    W := Min(W, RightEdge - X);
    H := Min(H, BottomEdge - Y);
    if (W <= 0) or (H <= 0) then Exit;
    Value := Text;
    if not Bold and not Texts[I].Fits then
      Value := ClippedLine(Value, ReportRegularFont, W, FontSize);
    M := AddMemo(Band, Value, X, Y, W, H, FontSize, Bold);
    if not Texts[I].Fits then M.CullThreshold := 100;
  end;

begin
  if Length(Cards) = 0 then raise EArgumentException.Create(
      'Labels have no participants');
  L := PlaceStartLabels(Length(Cards), Paper);
  LoadReportFonts;
  Texts := nil;
  SetLength(Texts, Length(Cards));
  OverflowCount := 0;
  Size := Paper.FontSize;
  while Size >= Paper.MinFontSize do
  begin
    OverflowCount := 0;
    for I := 0 to High(Cards) do
    begin
      Fits := MeasureCard(Cards[I], Paper, Size, Texts[I]);
      Texts[I].Fits := Fits;
      if not Fits then Inc(OverflowCount);
    end;
    if (OverflowCount = 0) or (Size = Paper.MinFontSize) then Break;
    Dec(Size);
  end;
  if (OverflowCount > 0) and not AllowOverflow then
    raise EStartLabelsDoNotFit.Create(OverflowCount);
  Result := TStartLabelReport.Create;
  try
    Result.FTableFontSize := Size;
    Result.FOverflowCount := OverflowCount;
    PageIndex := -1;
    Band := nil;
    for I := 0 to High(Cards) do
    begin
      if L.Placements[I].Page <> PageIndex then
      begin
        PageIndex := L.Placements[I].Page;
        Page := TFPReportPage.Create(Result.Report);
        Page.PageSize.PaperName := 'A4';
        Page.Margins.Left := 0;
        Page.Margins.Right := 0;
        Page.Margins.Top := 0;
        Page.Margins.Bottom := 0;
        Page.Font.Name := ReportRegularFont;
        Band := TFPReportTitleBand.Create(Page);
        Band.Layout.Height := 297;
      end;
      X := (L.Placements[I].X + Paper.Padding) / StartLabelUnitsPerMM;
      Y := (L.Placements[I].Y + Paper.Padding) / StartLabelUnitsPerMM;
      W := (Paper.Width - 2 * Paper.Padding) / StartLabelUnitsPerMM;
      RightEdge := X + W;
      BottomEdge := (L.Placements[I].Y + Paper.Height - Paper.Padding) /
        StartLabelUnitsPerMM;
      ContentMemo(Texts[I].Header, X, Y, W, Texts[I].HeaderHeight, Size + 2, True);
      Y := Y + Texts[I].HeaderHeight + 1;
      for J := 0 to High(Cards[I].Entries) do
      begin
        RowX := X + (J div Texts[I].RowsPerColumn) *
          (Texts[I].BlockWidth + StartBlockGap);
        RowY := Y + (J mod Texts[I].RowsPerColumn) * Texts[I].RowHeight;
        ContentMemo(IntToStr(Cards[I].Entries[J].StageIndex), RowX, RowY,
          Texts[I].StageWidth, Texts[I].RowHeight, Size, False);
        ContentMemo(Cards[I].Entries[J].Time, RowX + Texts[I].StageWidth, RowY,
          Texts[I].BlockWidth - Texts[I].StageWidth, Texts[I].RowHeight, Size, False);
      end;
      if Paper.DrawBorders or not Texts[I].Fits then
      begin
        Frame := AddMemo(Band, '', L.Placements[I].X / StartLabelUnitsPerMM +
          0.1, L.Placements[I].Y / StartLabelUnitsPerMM + 0.1,
          Paper.Width / StartLabelUnitsPerMM - 0.2, Paper.Height /
          StartLabelUnitsPerMM - 0.2, Size, False);
        Frame.Frame.Lines := [flTop, flLeft, flRight, flBottom];
        Frame.Frame.Color := clBlack;
        if not Texts[I].Fits then Frame.Frame.Color := clRed;
        Frame.Frame.Width := 1;
      end;
    end;
    Result.Prepare;
  except
    Result.Free;
    raise;
  end;
end;

end.
