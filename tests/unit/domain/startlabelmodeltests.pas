unit StartLabelModelTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  TStartLabelModelTests = class(TTestCase)
  published
    procedure AllRidersAndActiveStageNumbersArePreserved;
    procedure DefaultGridAndExactPageBoundaries;
    procedure FractionalGridAndGapsStayInsidePaper;
    procedure FirstSlotSkipsOnlyFirstPage;
    procedure InvalidPaperAndFontAreRejected;
    procedure EmptyAndSingleCellSheets;
  end;

implementation

uses SysUtils, StartLabelModel, StartReportModel;

procedure TStartLabelModelTests.AllRidersAndActiveStageNumbersArePreserved;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  C: TStartLabelCards;
begin
  SetLength(S, 4);
  S[0].Index := 8;
  S[0].IsActive := True;
  S[1].Index := 2;
  S[1].IsActive := False;
  S[2].Index := 1;
  S[2].IsActive := True;
  S[3].Index := 32;
  S[3].IsActive := True;
  SetLength(R, 3);
  R[0].Id := 4;
  R[0].Number := 123;
  R[0].Name := 'Иван Петров';
  SetLength(R[0].Starts, 4);
  R[0].Starts[0] := ' 09:12:34.567 ';
  R[0].Starts[1] := 'inactive';
  R[0].Starts[2] := '00:00:00.000';
  R[0].Starts[3] := '0';
  R[1].Id := 2;
  R[1].Number := 9;
  R[1].Name := 'Без стартов';
  R[2].Id := 1;
  R[2].Number := 9;
  R[2].Name := 'Первый';
  C := PrepareStartLabels(R, S);
  AssertEquals(3, Length(C));
  AssertEquals(1, C[0].Id);
  AssertEquals(2, C[1].Id);
  AssertEquals('123 Иван Петров', C[2].Title);
  AssertEquals(3, Length(C[2].Entries));
  AssertEquals(1, C[2].Entries[0].StageIndex);
  AssertEquals(8, C[2].Entries[1].StageIndex);
  AssertEquals(32, C[2].Entries[2].StageIndex);
  AssertEquals('00:00:00.000', C[2].Entries[0].Time);
  AssertEquals('09:12:34.567', C[2].Entries[1].Time);
  AssertEquals('0', C[2].Entries[2].Time);
  AssertEquals('—', C[1].Entries[0].Time);
  AssertEquals(0, Length(R[1].Starts));
end;

procedure TStartLabelModelTests.DefaultGridAndExactPageBoundaries;
var
  P: TStartLabelPaper;
  L: TStartLabelLayout;
  I: integer;
begin
  P := DefaultStartLabelPaper;
  L := PlaceStartLabels(24, P);
  AssertEquals(3, L.Grid.Columns);
  AssertEquals(8, L.Grid.Rows);
  AssertEquals(24, L.Grid.Capacity);
  AssertEquals(1, L.PageCount);
  L := PlaceStartLabels(25, P);
  AssertEquals(2, L.PageCount);
  AssertEquals(0, L.Placements[24].Column);
  AssertEquals(0, L.Placements[24].Row);
  AssertEquals(1, L.Placements[24].Page);
  for I := 0 to High(L.Placements) do
  begin
    AssertEquals(I, L.Placements[I].CardIndex);
    AssertEquals(P.Left + L.Placements[I].Column * P.Width, L.Placements[I].X);
  end;
end;

procedure TStartLabelModelTests.FractionalGridAndGapsStayInsidePaper;
var
  P: TStartLabelPaper;
  L: TStartLabelLayout;
  I, J: integer;
begin
  P := DefaultStartLabelPaper;
  P.Width := 63500;
  P.Height := 29600;
  P.Left := 7250;
  P.Right := 7250;
  P.Top := 10000;
  P.Bottom := 10000;
  P.GapX := 2500;
  P.GapY := 900;
  L := PlaceStartLabels(100, P);
  AssertEquals(3, L.Grid.Columns);
  AssertEquals(9, L.Grid.Rows);
  AssertEquals(4, L.PageCount);
  for I := 0 to High(L.Placements) do with L.Placements[I] do
    begin
      AssertTrue(X >= P.Left);
      AssertTrue(Y >= P.Top);
      AssertTrue(X + Width <= StartLabelPageWidth - P.Right);
      AssertTrue(Y + Height <= StartLabelPageHeight - P.Bottom);
      for J := 0 to I - 1 do if L.Placements[J].Page = Page then
          AssertTrue((X >= L.Placements[J].X + Width) or
            (Y >= L.Placements[J].Y + Height));
    end;
  P.Width := 70000;
  P.Left := 0;
  P.Right := 10;
  P.GapX := 0;
  L := PlaceStartLabels(1, P);
  AssertEquals('0.01 mm must not be rounded away', 2, L.Grid.Columns);
end;

procedure TStartLabelModelTests.FirstSlotSkipsOnlyFirstPage;
var
  P: TStartLabelPaper;
  L: TStartLabelLayout;
begin
  P := DefaultStartLabelPaper;
  P.FirstSlot := 24;
  L := PlaceStartLabels(25, P);
  AssertEquals(2, L.PageCount);
  AssertEquals(7, L.Placements[0].Row);
  AssertEquals(2, L.Placements[0].Column);
  AssertEquals(1, L.Placements[1].Page);
  AssertEquals(0, L.Placements[1].Row);
  AssertEquals(0, L.Placements[1].Column);
  P.FirstSlot := 5;
  L := PlaceStartLabels(21, P);
  AssertEquals(2, L.PageCount);
  AssertEquals(1, L.Placements[0].Row);
  AssertEquals(1, L.Placements[0].Column);
end;

procedure TStartLabelModelTests.InvalidPaperAndFontAreRejected;
var
  P: TStartLabelPaper;
  G: TStartLabelGrid;
begin
  P := DefaultStartLabelPaper;
  P.Width := 1;
  P.Height := 1;
  P.Top := 0;
  P.Bottom := 0;
  P.Padding := 0;
  AssertEquals(Ord(lpeSize), Ord(CheckStartLabelPaper(P, G)));
  P := DefaultStartLabelPaper;
  P.Width := 0;
  AssertEquals(Ord(lpeSize), Ord(CheckStartLabelPaper(P, G)));
  P := DefaultStartLabelPaper;
  P.Left := -10;
  AssertEquals(Ord(lpeMargins), Ord(CheckStartLabelPaper(P, G)));
  P := DefaultStartLabelPaper;
  P.GapY := -10;
  AssertEquals(Ord(lpeGaps), Ord(CheckStartLabelPaper(P, G)));
  P := DefaultStartLabelPaper;
  P.Padding := P.Height;
  AssertEquals(Ord(lpePadding), Ord(CheckStartLabelPaper(P, G)));
  P := DefaultStartLabelPaper;
  P.MinFontSize := P.FontSize + 1;
  AssertEquals(Ord(lpeFont), Ord(CheckStartLabelPaper(P, G)));
  P := DefaultStartLabelPaper;
  P.Left := 180000;
  AssertEquals(Ord(lpeNoSpace), Ord(CheckStartLabelPaper(P, G)));
  P := DefaultStartLabelPaper;
  P.FirstSlot := 25;
  AssertEquals(Ord(lpeFirstSlot), Ord(CheckStartLabelPaper(P, G)));
  P := DefaultStartLabelPaper;
  P.StartColumns := 3;
  AssertEquals(Ord(lpeStartColumns), Ord(CheckStartLabelPaper(P, G)));
  P.StartColumns := 0;
  AssertEquals(Ord(lpeStartColumns), Ord(CheckStartLabelPaper(P, G)));
end;

procedure TStartLabelModelTests.EmptyAndSingleCellSheets;
var
  P: TStartLabelPaper;
  L: TStartLabelLayout;
begin
  P := DefaultStartLabelPaper;
  L := PlaceStartLabels(0, P);
  AssertEquals(0, L.PageCount);
  AssertEquals(0, Length(L.Placements));
  P.Width := 210000;
  P.Height := 297000;
  P.Top := 0;
  P.Bottom := 0;
  L := PlaceStartLabels(3, P);
  AssertEquals(1, L.Grid.Capacity);
  AssertEquals(3, L.PageCount);
end;

initialization
  RegisterTest(TStartLabelModelTests);
end.
