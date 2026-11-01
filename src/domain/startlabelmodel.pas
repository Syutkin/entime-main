unit StartLabelModel;
{$mode objfpc}{$H+}
interface

uses SysUtils, StartReportModel;

const
  StartLabelUnitsPerMM = 1000;
  StartLabelPageWidth = 210 * StartLabelUnitsPerMM;
  StartLabelPageHeight = 297 * StartLabelUnitsPerMM;

type
  // All physical dimensions are thousandths of a millimetre.
  TStartLabelPaper = record
    Width, Height, Left, Right, Top, Bottom, GapX, GapY, Padding: integer;
    FontSize, MinFontSize, FirstSlot, StartColumns: integer;
    DrawBorders: boolean;
  end;
  TStartLabelPaperError = (lpeNone, lpeSize, lpeMargins, lpeGaps,
    lpePadding, lpeFont, lpeNoSpace, lpeFirstSlot, lpeStartColumns);

  EStartLabelPaper = class(Exception)
  public
    Reason: TStartLabelPaperError;
    constructor Create(AReason: TStartLabelPaperError);
  end;

  TStartLabelGrid = record
    Columns, Rows, Capacity: integer;
  end;

  TStartLabelEntry = record
    StageIndex: integer;
    Time: string;
  end;
  TStartLabelEntries = array of TStartLabelEntry;

  TStartLabelCard = record
    Id, Number: integer;
    Title: string;
    Entries: TStartLabelEntries;
  end;
  TStartLabelCards = array of TStartLabelCard;

  TStartLabelPlacement = record
    CardIndex, Page, Row, Column, X, Y, Width, Height: integer;
  end;
  TStartLabelPlacements = array of TStartLabelPlacement;

  TStartLabelLayout = record
    Grid: TStartLabelGrid;
    PageCount: integer;
    Placements: TStartLabelPlacements;
  end;

function DefaultStartLabelPaper: TStartLabelPaper;
function SameStartLabelPaper(const A, B: TStartLabelPaper): boolean;
function CheckStartLabelPaper(const P: TStartLabelPaper;
  out Grid: TStartLabelGrid): TStartLabelPaperError;
function PlaceStartLabels(Count: integer; const P: TStartLabelPaper): TStartLabelLayout;
function PrepareStartLabels(const Rows: TStartReportRows;
  const Stages: TStartStageInfos): TStartLabelCards;

implementation

function SameStartLabelPaper(const A, B: TStartLabelPaper): boolean;
begin
  Result := (A.Width = B.Width) and (A.Height = B.Height) and
    (A.Left = B.Left) and (A.Right = B.Right) and (A.Top = B.Top) and
    (A.Bottom = B.Bottom) and (A.GapX = B.GapX) and (A.GapY = B.GapY) and
    (A.Padding = B.Padding) and (A.FontSize = B.FontSize) and
    (A.MinFontSize = B.MinFontSize) and (A.FirstSlot = B.FirstSlot) and
    (A.StartColumns = B.StartColumns) and (A.DrawBorders = B.DrawBorders);
end;

constructor EStartLabelPaper.Create(AReason: TStartLabelPaperError);
begin
  inherited Create('Invalid label paper: ' + IntToStr(Ord(AReason)));
  Reason := AReason;
end;

function DefaultStartLabelPaper: TStartLabelPaper;
begin
  Result := Default(TStartLabelPaper);
  Result.Width := 70000;
  Result.Height := 37000;
  Result.Top := 500;
  Result.Bottom := 500;
  Result.Padding := 2000;
  Result.FontSize := 9;
  Result.MinFontSize := 6;
  Result.FirstSlot := 1;
  Result.StartColumns := 1;
end;

function CheckStartLabelPaper(const P: TStartLabelPaper;
  out Grid: TStartLabelGrid): TStartLabelPaperError;
begin
  Grid := Default(TStartLabelGrid);
  if (P.Width <= 0) or (P.Height <= 0) or (P.Width > StartLabelPageWidth) or
    (P.Height > StartLabelPageHeight) then
    Exit(lpeSize);
  if (P.Left < 0) or (P.Right < 0) or (P.Top < 0) or (P.Bottom < 0) or
    (int64(P.Left) + P.Right >= StartLabelPageWidth) or
    (int64(P.Top) + P.Bottom >= StartLabelPageHeight) then
    Exit(lpeMargins);
  if (P.GapX < 0) or (P.GapY < 0) or (P.GapX > StartLabelPageWidth) or
    (P.GapY > StartLabelPageHeight) then
    Exit(lpeGaps);
  if (P.Padding < 0) or (int64(P.Padding) * 2 >= P.Width) or
    (int64(P.Padding) * 2 >= P.Height) then Exit(lpePadding);
  if (P.MinFontSize < 1) or (P.FontSize < P.MinFontSize) or (P.FontSize > 72) then
    Exit(lpeFont);
  if not (P.StartColumns in [1, 2]) then Exit(lpeStartColumns);
  Grid.Columns := (StartLabelPageWidth - P.Left - P.Right + P.GapX) div
    (P.Width + P.GapX);
  Grid.Rows := (StartLabelPageHeight - P.Top - P.Bottom + P.GapY) div
    (P.Height + P.GapY);
  if int64(Grid.Columns) * Grid.Rows > High(integer) then Exit(lpeSize);
  Grid.Capacity := Grid.Columns * Grid.Rows;
  if Grid.Capacity = 0 then Exit(lpeNoSpace);
  if (P.FirstSlot < 1) or (P.FirstSlot > Grid.Capacity) then Exit(lpeFirstSlot);
  Result := lpeNone;
end;

function PlaceStartLabels(Count: integer; const P: TStartLabelPaper): TStartLabelLayout;
var
  E: TStartLabelPaperError;
  I: integer;
  Slot: int64;
begin
  Result := Default(TStartLabelLayout);
  E := CheckStartLabelPaper(P, Result.Grid);
  if E <> lpeNone then raise EStartLabelPaper.Create(E);
  if Count < 0 then raise EArgumentOutOfRangeException.Create('Label count');
  if Count = 0 then Exit;
  Result.PageCount := (int64(P.FirstSlot) - 1 + Count + Result.Grid.Capacity - 1) div
    Result.Grid.Capacity;
  SetLength(Result.Placements, Count);
  for I := 0 to Count - 1 do with Result.Placements[I] do
    begin
      Slot := int64(P.FirstSlot) - 1 + I;
      CardIndex := I;
      Page := Slot div Result.Grid.Capacity;
      Row := (Slot mod Result.Grid.Capacity) div Result.Grid.Columns;
      Column := Slot mod Result.Grid.Columns;
      X := P.Left + Column * (P.Width + P.GapX);
      Y := P.Top + Row * (P.Height + P.GapY);
      Width := P.Width;
      Height := P.Height;
    end;
end;

function CompareCards(const A, B: TStartLabelCard): integer;
begin
  if A.Number < B.Number then Exit(-1);
  if A.Number > B.Number then Exit(1);
  if A.Id < B.Id then Exit(-1);
  if A.Id > B.Id then Exit(1);
  Result := 0;
end;

procedure SortCards(var Cards: TStartLabelCards; L, R: integer);
var
  I, J: integer;
  Pivot, Temp: TStartLabelCard;
begin
  I := L;
  J := R;
  Pivot := Cards[(L + R) div 2];
  repeat
    while CompareCards(Cards[I], Pivot) < 0 do Inc(I);
    while CompareCards(Cards[J], Pivot) > 0 do Dec(J);
    if I <= J then
    begin
      Temp := Cards[I];
      Cards[I] := Cards[J];
      Cards[J] := Temp;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if L < J then SortCards(Cards, L, J);
  if I < R then SortCards(Cards, I, R);
end;

function PrepareStartLabels(const Rows: TStartReportRows;
  const Stages: TStartStageInfos): TStartLabelCards;
var
  I, J, K, N: integer;
  Slots: array of integer;
  Temp: integer;
  Value: string;
begin
  Slots := nil;
  for I := 0 to High(Stages) do if Stages[I].IsActive then
    begin
      N := Length(Slots);
      SetLength(Slots, N + 1);
      Slots[N] := I;
    end;
  for I := 1 to High(Slots) do
  begin
    Temp := Slots[I];
    J := I - 1;
    while (J >= 0) and (Stages[Slots[J]].Index > Stages[Temp].Index) do
    begin
      Slots[J + 1] := Slots[J];
      Dec(J);
    end;
    Slots[J + 1] := Temp;
  end;
  Result := nil;
  SetLength(Result, Length(Rows));
  for I := 0 to High(Rows) do
  begin
    Result[I].Id := Rows[I].Id;
    Result[I].Number := Rows[I].Number;
    Result[I].Title := IntToStr(Rows[I].Number) + ' ' + Rows[I].Name;
    SetLength(Result[I].Entries, Length(Slots));
    for J := 0 to High(Slots) do
    begin
      K := Slots[J];
      Value := '';
      if K < Length(Rows[I].Starts) then Value := Trim(Rows[I].Starts[K]);
      if Value = '' then Value := '—';
      Result[I].Entries[J].StageIndex := Stages[K].Index;
      Result[I].Entries[J].Time := Value;
    end;
  end;
  if Length(Result) > 1 then SortCards(Result, 0, High(Result));
end;

end.
