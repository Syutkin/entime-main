unit StageFinishReportModelTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry;

type
  TStageFinishReportModelTests = class(TTestCase)
  published
    procedure CategoriesAndSavedPlacesHaveStableOrder;
    procedure StatusPriorityAndIncompleteSelection;
    procedure TimesKeepHoursSignMillisecondsAndZeroPenalty;
    procedure StageChoiceAndFrozenLabels;
  end;

implementation

uses StageFinishReportModel, StageModel, StageFieldNames;

function Rider(N: integer; const Cat, Place, Time, Status: string): TStageReportRow;
begin
  Result := Default(TStageReportRow);
  Result.Number := N;
  Result.Category := Cat;
  Result.Name := 'Rider ' + IntToStr(N);
  Result.Values[sfkPlace] := Place;
  Result.Values[sfkResult] := Time;
  Result.Values[sfkStatus] := Status;
end;

procedure TStageFinishReportModelTests.CategoriesAndSavedPlacesHaveStableOrder;
var
  Rows, OutRows: TStageReportRows;
  O: TStageReportOptions;
  C: TReportCategories;
begin
  O := DefaultReportOptions;
  SetLength(Rows, 6);
  Rows[0] := Rider(7, '', '1', '00:01:00.123', '');
  Rows[1] := Rider(30, 'A', '2', '00:02:00.123', '');
  Rows[2] := Rider(9, 'A', '1', '00:01:00.123', '');
  Rows[3] := Rider(8, 'A', '1', '00:01:00.123', '');
  Rows[4] := Rider(4, 'a', '', '00:01:00.123', '');
  Rows[5] := Rider(3, 'A', '', '00:01:00.123', '');
  OutRows := SelectReportRows(Rows, O);
  AssertEquals(8, OutRows[0].Number);
  AssertEquals(9, OutRows[1].Number);
  AssertEquals('1', OutRows[1].Cells[rcPlace]);
  AssertEquals(30, OutRows[2].Number);
  AssertEquals(3, OutRows[3].Number);
  AssertEquals('—', OutRows[3].Cells[rcPlace]);
  AssertEquals('01:00.123', OutRows[3].Cells[rcResult]);
  AssertEquals(4, OutRows[4].Number);
  AssertEquals(7, OutRows[5].Number);
  C := ReportCategories(Rows);
  AssertEquals(3, Length(C));
  AssertEquals('', C[2]);
  O.AllCategories := False;
  SetLength(O.Categories, 1);
  O.Categories[0] := 'a';
  OutRows := SelectReportRows(Rows, O);
  AssertEquals(1, Length(OutRows));
  AssertEquals(4, OutRows[0].Number);
  O.Categories := nil;
  OutRows := SelectReportRows(Rows, O);
  AssertEquals(0, Length(OutRows));
end;

procedure TStageFinishReportModelTests.StatusPriorityAndIncompleteSelection;
var
  Rows, R: TStageReportRows;
  O: TStageReportOptions;
begin
  SetLength(Rows, 7);
  O := DefaultReportOptions;
  O.IncludeIncomplete := False;
  Rows[0] := Rider(1, 'A', '1', '00:01:00.000', '');
  Rows[0].GlobalStatus := '2';
  Rows[1] := Rider(2, 'A', '2', '00:01:01.000', '');
  Rows[1].GlobalStatus := '3';
  Rows[2] := Rider(3, 'A', '3', '00:01:02.000', '1');
  Rows[3] := Rider(4, 'A', '4', '00:01:03.000', '2');
  Rows[4] := Rider(5, 'A', '5', '00:01:04.000', '3');
  Rows[5] := Rider(6, 'A', '', 'bad', '');
  Rows[6] := Rider(7, 'A', '', '', '99');
  R := SelectReportRows(Rows, O);
  AssertEquals(5, Length(R));
  AssertEquals('01:00.000', R[0].Cells[rcResult]);
  AssertEquals('DNS', R[1].Cells[rcResult]);
  AssertEquals('DNF', R[2].Cells[rcResult]);
  AssertEquals(2, R[3].Number);
  AssertEquals('DSQ', R[3].Cells[rcResult]);
  AssertEquals('—', R[3].Cells[rcPlace]);
  AssertEquals('—', R[3].Cells[rcGap]);
  O.IncludeIncomplete := True;
  R := SelectReportRows(Rows, O);
  AssertEquals(7, Length(R));
  AssertEquals('Проверьте данные', R[5].Cells[rcResult]);
  AssertEquals('Проверьте данные', R[6].Cells[rcResult]);
  Rows[5].Values[sfkResult] := '';
  R := SelectReportRows(Rows, O);
  AssertEquals('Нет результата', R[5].Cells[rcResult]);
end;

procedure TStageFinishReportModelTests.TimesKeepHoursSignMillisecondsAndZeroPenalty;
var
  Rows, R: TStageReportRows;
  O: TStageReportOptions;
begin
  O := DefaultReportOptions;
  SetLength(Rows, 2);
  Rows[0] := Rider(123, 'A', '1', '01:02:03.456', '');
  Rows[0].Values[sfkPenalty] := '00:00:00.000';
  Rows[0].Values[sfkDiffLeader] := '-01:02:03.456';
  Rows[1] := Rider(9, 'A', '2', '00:00:00.000', '');
  R := SelectReportRows(Rows, O);
  AssertEquals('01:02:03.456', R[0].Cells[rcResult]);
  AssertEquals('-01:02:03.456', R[0].Cells[rcGap]);
  AssertEquals('00:00.000', R[0].Cells[rcPenalty]);
  AssertEquals('00:00.000', R[1].Cells[rcResult]);
  AssertEquals('—', R[1].Cells[rcPenalty]);
  AssertEquals('123', R[0].Cells[rcNumber]);
end;

procedure TStageFinishReportModelTests.StageChoiceAndFrozenLabels;
var
  S: TStages;
  O: TStageReportOptions;
  L: TReportLabels;
begin
  S := TStages.Create(32);
  try
    S[32].isActive := False;
    AssertEquals(32, DefaultReportStage(S, 32));
    AssertEquals(1, DefaultReportStage(S, 99));
    S[1].isActive := False;
    AssertEquals(1, DefaultReportStage(S, 0));
  finally
    S.Free;
  end;
  AssertEquals('There is no separate status column', 7, Ord(High(TReportColumn)) + 1);
  O := DefaultReportOptions;
  AssertTrue(O.IncludeIncomplete);
  AssertTrue(O.AllCategories);
  L := ReportLabels(rlEnglish);
  AssertEquals('Finish protocol', L.Title);
  AssertEquals('Place', L.Columns[rcPlace]);
  AssertEquals('No category', L.NoCategory);
  AssertEquals('Finish protocol', L.Title);
end;

initialization
  RegisterTest(TStageFinishReportModelTests);
end.
