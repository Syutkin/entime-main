unit StageFinishReportBuilder;
{$mode objfpc}{$H+}
interface

uses ProtocolDocumentModel, StageFinishReportModel, StageFinishReportBackend;

const
  CompetitionTitleFontSize = 14;
  CategoryTitleFontSize = 10;

type
  TStageReportColumnWidths = array[TReportColumn] of single;

function StageReportColumnWidths(const Options: TStageReportOptions):
  TStageReportColumnWidths;
function BuildStageFinishReport(const Snapshot: TStageReportSnapshot):
  TPreparedStageReport;

function BuildProtocolReport(const Snapshot: TProtocolDocument): TPreparedStageReport;

implementation

uses Classes, SysUtils, Contnrs, ProtocolTableLayout, Variants, fpTTF,
  fpreport, ReportTextMetrics,
  ReportTemplateModel;

type
  TTemplateHeaderBand = class(TFPReportDataHeaderBand)
  public
    property KeepTogetherWithChildren;
  end;

  TPrintLine = record
    Category, Caption: string;
    Cells: TProtocolCells;
  end;

  TStageDocument = class
  private
    FReport: TFPReport;
    FData: TFPReportUserData;
    FLines: array of TPrintLine;
    FSnapshot: TProtocolDocument; // Only accessed synchronously while building.
    FWidths: TProtocolWidths;
    FTableFont: integer;
    FInSignatures: boolean;
    FTitle, FRace, FStage, FHeading, FStamp: string;
    procedure DataFirst(Sender: TObject);
    procedure SignaturesBeforePrint(Sender: TFPReportElement);
    procedure ResultHeadingBeforePrint(Sender: TFPReportElement);
    procedure Names(Sender: TObject; List: TStrings);
    procedure EOF(Sender: TObject; var IsEOF: boolean);
    procedure Value(Sender: TObject; const AValueName: string; var AValue: variant);
    procedure CreateLines;
    procedure CreateDesign;
    function AddTemplateBlock(Page: TFPReportPage;
      const Paragraphs: TReportParagraphs; Header: boolean;
      Width: single): TFPReportCustomBand;
  public
    constructor Create(OwnerReport: TFPReport; const S: TProtocolDocument);
    property Report: TFPReport read FReport;
  end;

type
  TProtocolReport = class(TPreparedStageReport)
  private
    FBuilders: TObjectList;
  public
    constructor Create(const S: TProtocolDocument);
    destructor Destroy; override;
  end;

constructor TProtocolReport.Create(const S: TProtocolDocument);
var
  Views: TProtocolDocuments;
  I: integer;
begin
  inherited Create;
  FBuilders := TObjectList.Create(True);
  Views := nil;
  try
    Views := ProtocolPrintViews(S);
    for I := 0 to High(Views) do FBuilders.Add(TStageDocument.Create(Report, Views[I]));
    Prepare;
  finally
    FreeProtocolDocuments(Views);
  end;
end;

destructor TProtocolReport.Destroy;
begin
  FBuilders.Free;
  inherited Destroy;
end;

function StageReportColumnWidths(const Options: TStageReportOptions):
TStageReportColumnWidths;
const
  Widths: array[TReportColumn] of single = (13, 11, 57, 36, 25, 23, 25);
var
  C: TReportColumn;
begin
  for C := Low(C) to High(C) do Result[C] := Widths[C];
  if Options.Orientation = roLandscape then
  begin
    Result[rcName] := Result[rcName] + 52;
    Result[rcTeam] := Result[rcTeam] + 35;
  end;
  if not Options.ShowPenalty then
  begin
    Result[rcName] := Result[rcName] + 14;
    Result[rcTeam] := Result[rcTeam] + 9;
    Result[rcPenalty] := 0;
  end;
end;

constructor TStageDocument.Create(OwnerReport: TFPReport; const S: TProtocolDocument);
var
  Text: TReportText;
  Lines: TStringList;
  W: single;
begin
  inherited Create;
  FReport := OwnerReport;
  FSnapshot := S;
  FWidths := ProtocolWidths(S);
  FTableFont := ProtocolFontSize(S);
  FTitle := S.Labels.Title;
  FRace := S.RaceName;
  if Trim(FRace) = '' then FRace := S.Labels.Competition;
  FHeading := S.Heading;
  W := 190;
  if S.Options.Landscape then W := 277;
  Text := TReportText.Create(nil);
  Lines := TStringList.Create;
  try
    Text.Wrap(FRace, W - 2, Lines, ReportBoldFont, CompetitionTitleFontSize);
    FRace := TrimRight(Lines.Text);
    Text.Wrap(FHeading, W - 2, Lines, ReportBoldFont);
    FHeading := TrimRight(Lines.Text);
  finally
    Lines.Free;
    Text.Free;
  end;
  FStamp := FormatDateTime('yyyy-mm-dd hh:nn:ss', S.FormedAt);
  FData := TFPReportUserData.Create(Report);
  FData.Name := 'data' + IntToStr(Report.ReportData.Count);
  FData.OnFirst := @DataFirst;
  FData.OnGetNames := @Names;
  FData.OnGetEOF := @EOF;
  FData.OnGetValue := @Value;
  Report.ReportData.AddReportData(FData);
  CreateLines;
  CreateDesign;
  FSnapshot := nil;
end;

procedure TStageDocument.CreateLines;
var
  I, J, K, N, MaxLines, GroupEnd: integer;
  C: integer;
  Text: TReportText;
  Lists: array of TStringList;
  Caption, Cat: string;
begin
  Text := TReportText.Create(nil);
  SetLength(Lists, Length(FWidths));
  for C := 0 to High(FWidths) do Lists[C] := TStringList.Create;
  try
    I := 0;
    while I < Length(FSnapshot.Rows) do
    begin
      Cat := FSnapshot.Rows[I].Category;
      GroupEnd := I;
      while (GroupEnd < Length(FSnapshot.Rows)) and
        (FSnapshot.Options.HideCategories or
          (FSnapshot.Rows[GroupEnd].Category = Cat)) do
        Inc(GroupEnd);
      Caption := Cat;
      if Caption = '' then Caption := FSnapshot.Labels.NoCategory;
      if FSnapshot.Options.HideCategories then
      begin
        Cat := 'ungrouped';
        Caption := '';
      end;
      N := 190;
      if FSnapshot.Options.Landscape then N := 277;
      Text.Wrap(Caption, N - 2, Lists[0], ReportBoldFont, CategoryTitleFontSize);
      Caption := TrimRight(Lists[0].Text);
      for J := I to GroupEnd - 1 do
      begin
        MaxLines := 1;
        for C := 0 to High(FWidths) do
        begin
          if FWidths[C] <= 0 then Continue;
          Text.Wrap(FSnapshot.Rows[J].Cells[C], FWidths[C] - 2 * FTableFont / 8,
            Lists[C], '', FTableFont, FTableFont / 8);
          if Lists[C].Count > MaxLines then MaxLines := Lists[C].Count;
        end;
        N := Length(FLines);
        SetLength(FLines, N + MaxLines);
        for K := 0 to MaxLines - 1 do
        begin
          FLines[N + K].Category := 'category:' + Cat;
          FLines[N + K].Caption := Caption;
          SetLength(FLines[N + K].Cells, Length(FWidths));
          for C := 0 to High(FWidths) do if K < Lists[C].Count then
              FLines[N + K].Cells[C] := Lists[C][K];
        end;
      end;
      I := GroupEnd;
    end;
  finally
    for C := 0 to High(FWidths) do Lists[C].Free;
    Text.Free;
  end;
end;

procedure TStageDocument.Names(Sender: TObject; List: TStrings);
var
  C: integer;
begin
  List.Add('title');
  List.Add('race');
  List.Add('stage');
  List.Add('heading');
  List.Add('stamp');
  List.Add('groupkey');
  List.Add('categorycaption');
  for C := 0 to High(FWidths) do List.Add('c' + IntToStr(Ord(C)));
end;

procedure TStageDocument.EOF(Sender: TObject; var IsEOF: boolean);
begin
  IsEOF := FData.RecNo > Length(FLines);
end;

procedure TStageDocument.Value(Sender: TObject; const AValueName: string;
  var AValue: variant);
var
  N, I: integer;
begin
  AValue := '';
  if AValueName = 'title' then AValue := FTitle
  else if AValueName = 'race' then AValue := FRace
  else if AValueName = 'stage' then AValue := FStage
  else if AValueName = 'heading' then AValue := FHeading
  else if AValueName = 'stamp' then AValue := FStamp
  else
  begin
    N := FData.RecNo - 1;
    if (N < 0) or (N >= Length(FLines)) then Exit;
    if AValueName = 'groupkey' then AValue := FLines[N].Category
    else if AValueName = 'categorycaption' then AValue := FLines[N].Caption
    else if (Length(AValueName) >= 2) and (AValueName[1] = 'c') and
      TryStrToInt(Copy(AValueName, 2, MaxInt), I) and (I >= 0) and
      (I < Length(FWidths)) then
      AValue := FLines[N].Cells[I];
  end;
end;

function Memo(B: TFPReportCustomBand; const Text: string; X, Y, W, H: single;
  Bold: boolean = False; Literal: boolean = False): TFPReportMemo;
begin
  Result := TFPReportMemo.Create(B);
  Result.Layout.Left := X;
  Result.Layout.Top := Y;
  Result.Layout.Width := W;
  Result.Layout.Height := H;
  Result.Text := Text;
  Result.Font.Name := ReportRegularFont;
  Result.Font.Size := 8;
  if Bold then Result.Font.Name := ReportBoldFont;
  if Literal then Result.Options := [moDisableExpressions];
  Result.WordOverflow := woSplit;
end;

function ColumnMemo(B: TFPReportCustomBand; const Text: string;
  X, Y, W, H: single; FontSize: integer = 8): TFPReportMemo;
var
  Measure: TReportText;
  Lines: TStringList;
begin
  Result := Memo(B, Text, X, Y, W, H, True, True);
  Result.Font.Size := FontSize;
  Result.TextAlignment.LeftMargin := FontSize / 8;
  Result.TextAlignment.RightMargin := FontSize / 8;
  Measure := TReportText.Create(nil);
  Lines := TStringList.Create;
  try
    Measure.Wrap(Text, W, Lines, ReportBoldFont, FontSize, FontSize / 8);
    Result.Text := TrimRight(Lines.Text);
  finally
    Lines.Free;
    Measure.Free;
  end;
end;

function TStageDocument.AddTemplateBlock(Page: TFPReportPage;
  const Paragraphs: TReportParagraphs; Header: boolean;
  Width: single): TFPReportCustomBand;
var
  Text: TReportText;
  Lines, RightLines: TStringList;
  P: TReportParagraph;
  I, N: integer;
  Previous, Band: TFPReportCustomBand;
  M: TFPReportMemo;
  H, CellWidth: single;
begin
  Text := TReportText.Create(nil);
  Lines := TStringList.Create;
  RightLines := TStringList.Create;
  Previous := nil;
  if Header then
  begin
    Previous := TTemplateHeaderBand.Create(Page);
    TTemplateHeaderBand(Previous).Data := FData;
    TTemplateHeaderBand(Previous).KeepTogetherWithChildren := False;
    Previous.Layout.Height := 0;
  end;
  try
    for P in Paragraphs do
    begin
      CellWidth := Width;
      if P.IsPair then CellWidth := Width / 2;
      Text.Wrap(P.Text, CellWidth - 2, Lines, '', P.FontSize);
      H := Text.LineHeight;
      N := Lines.Count;
      RightLines.Clear;
      if P.IsPair then
      begin
        Text.Wrap(P.RightText, CellWidth - 2, RightLines, '', P.RightFontSize);
        if Text.LineHeight > H then H := Text.LineHeight;
        if RightLines.Count > N then N := RightLines.Count;
      end;
      H := H + 1;
      for I := 0 to N - 1 do
      begin
        if Previous = nil then
        begin
          Band := TFPReportSummaryBand.Create(Page);
          TFPReportSummaryBand(Band).KeepTogetherWithChildren := False;
          TFPReportSummaryBand(Band).OnBeforePrint := @SignaturesBeforePrint;
        end
        else
        begin
          Band := TFPReportChildBand.Create(Page);
          Previous.ChildBand := TFPReportChildBand(Band);
        end;
        Band.Layout.Height := H;
        if I < Lines.Count then
        begin
          M := Memo(Band, Lines[I], 0, 0, CellWidth, H, False, True);
          M.Font.Size := P.FontSize;
          case P.Alignment of
            rpaLeft: M.TextAlignment.Horizontal := taLeftJustified;
            rpaRight: M.TextAlignment.Horizontal := taRightJustified;
            rpaCenter: M.TextAlignment.Horizontal := taCentered;
          end;
        end;
        if P.IsPair and (I < RightLines.Count) then
        begin
          M := Memo(Band, RightLines[I], CellWidth, 0, CellWidth, H, False, True);
          M.Font.Size := P.RightFontSize;
          case P.RightAlignment of
            rpaLeft: M.TextAlignment.Horizontal := taLeftJustified;
            rpaRight: M.TextAlignment.Horizontal := taRightJustified;
            rpaCenter: M.TextAlignment.Horizontal := taCentered;
          end;
        end;
        Previous := Band;
      end;
    end;
    Result := Previous;
  finally
    RightLines.Free;
    Lines.Free;
    Text.Free;
  end;
end;

procedure TStageDocument.DataFirst(Sender: TObject);
begin
  FInSignatures := False;
end;

procedure TStageDocument.SignaturesBeforePrint(Sender: TFPReportElement);
begin
  FInSignatures := True;
end;

procedure TStageDocument.ResultHeadingBeforePrint(Sender: TFPReportElement);
var
  N: integer;
begin
  Sender.Visible := not FInSignatures;
  if not Sender.Visible then Exit;
  FReport.ExpressionParser.Expression := 'InRepeatedGroupHeader';
  if not FReport.ExpressionParser.AsBoolean then Exit;
  // FPReport can repeat the previous group's cached heading at a page break
  // before it processes a category change. Inspect the current data row.
  N := FData.RecNo - 1;
  Sender.Visible := (N > 0) and (N < Length(FLines)) and
    (FLines[N].Category = FLines[N - 1].Category);
end;

procedure TStageDocument.CreateDesign;
var
  P: TFPReportPage;
  Header: TFPReportPageHeaderBand;
  Footer: TFPReportPageFooterBand;
  Group: TFPReportGroupHeaderBand;
  Body: TFPReportDataBand;
  ColumnsHeader, RaceHeader, ProtocolHeading: TFPReportChildBand;
  DataHeader: TFPReportCustomBand;
  C: integer;
  X, W, HeaderHeight, GroupHeight, LeafHeight, GroupWidth: single;
  LastColumn, K: integer;
  Measure: TReportText;
  Lines: TStringList;
  M: TFPReportMemo;
begin
  GroupHeight := 0;
  LeafHeight := 6;
  Measure := TReportText.Create(nil);
  Lines := TStringList.Create;
  try
    C := 0;
    while C < Length(FWidths) do
    begin
      LastColumn := ProtocolGroupEnd(FSnapshot, C);
      GroupWidth := 0;
      for K := C to LastColumn do GroupWidth := GroupWidth + FWidths[K];
      if LastColumn > C then
      begin
        Measure.Wrap(FSnapshot.Columns[C].GroupCaption, GroupWidth,
          Lines, ReportBoldFont, FTableFont, FTableFont / 8);
        if Lines.Count * 5 + 1 > GroupHeight then GroupHeight := Lines.Count * 5 + 1;
      end;
      C := LastColumn + 1;
    end;
    for C := 0 to High(FWidths) do
    begin
      Measure.Wrap(ProtocolColumnCaption(FSnapshot, C), FWidths[C],
        Lines, ReportBoldFont, FTableFont, FTableFont / 8);
      if Lines.Count * 5 + 1 > LeafHeight then LeafHeight := Lines.Count * 5 + 1;
    end;
  finally
    Lines.Free;
    Measure.Free;
  end;
  HeaderHeight := GroupHeight + LeafHeight;
  {$I ../../resources/reports/stage_finish.inc}
end;

function BuildProtocolReport(const Snapshot: TProtocolDocument): TPreparedStageReport;
begin
  if (Snapshot = nil) or (Length(Snapshot.Rows) = 0) then
    raise EArgumentException.Create('Report has no participants');
  Result := TProtocolReport.Create(Snapshot);
end;

function BuildStageFinishReport(
  const Snapshot: TStageReportSnapshot): TPreparedStageReport;
var
  D: TProtocolDocument;
begin
  if Snapshot = nil then raise EArgumentNilException.Create('Snapshot');
  D := StageProtocolDocument(Snapshot);
  try
    Result := BuildProtocolReport(D);
  finally
    D.Free;
  end;
end;

end.
