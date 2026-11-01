unit OverallFinishReportModelTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  TOverallFinishReportModelTests = class(TTestCase)
  published
    procedure StageNamesNeedNoPrefixAndEmptyNamesUseIndex;
    procedure PartialResultsOrderBySavedCompletedStages;
    procedure EqualCompletedStagesOrderBySavedTimeThenNumber;
    procedure SavedTotalsAreNotValidatedAgainstStages;
    procedure NullEmptyAndZeroDisplayDifferently;
    procedure AllStagesAndColumnChoices;
    procedure CategoriesAndPlacesRemainSaved;
    procedure StageStatusesDoNotReplaceGlobalResults;
    procedure EmptySelectionAndIncompleteFilter;
  end;

implementation

uses SysUtils, OverallFinishReportModel, ProtocolDocumentModel, StageFinishReportModel;

function Rider(N: integer; const Cat, Place, Time: string): TOverallReportRow;
begin
  Result := Default(TOverallReportRow);
  Result.Id := N;
  Result.Number := N;
  Result.Name := 'Rider ' + IntToStr(N);
  Result.Category := Cat;
  Result.Place := Place;
  Result.ResultValue := Time;
end;

procedure TOverallFinishReportModelTests.SavedTotalsAreNotValidatedAgainstStages;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultOverallReportOptions;
  O.Detailed := False;
  SetLength(R, 1);
  R[0] := Rider(123, 'A', '7', '00:10:00.123');
  R[0].Gap := '+1 СУ';
  SetLength(S, 2);
  S[0].Index := 1;
  S[1].Index := 8;
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals('7', D.Rows[0].Cells[0]);
    AssertEquals('10:00.123', D.Rows[0].Cells[4]);
    AssertEquals('+1 СУ', D.Rows[0].Cells[5]);
    AssertEquals('Общий финишный протокол', D.Heading);
  finally
    D.Free;
  end;
end;

procedure TOverallFinishReportModelTests.NullEmptyAndZeroDisplayDifferently;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultOverallReportOptions;
  O.Detailed := False;
  SetLength(R, 2);
  R[0] := Rider(1, 'A', '', '');
  R[1] := Rider(2, 'A', '0', '00:00:00.000');
  R[1].Gap := '0';
  S := nil;
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals('0', D.Rows[0].Cells[0]);
    AssertEquals('00:00.000', D.Rows[0].Cells[4]);
    AssertEquals('0', D.Rows[0].Cells[5]);
    AssertEquals('Нет результата', D.Rows[1].Cells[4]);
    AssertEquals('—', D.Rows[1].Cells[0]);
  finally
    D.Free;
  end;
end;

procedure TOverallFinishReportModelTests.AllStagesAndColumnChoices;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  D: TProtocolDocument;
  I, M, Count: integer;
begin
  SetLength(S, 32);
  SetLength(R, 1);
  R[0] := Rider(9, 'A', '1', '00:32:00.000');
  SetLength(R[0].Stages, 32);
  for I := 0 to 31 do
  begin
    S[I].Index := I + 1;
    S[I].Name := 'Stage ' + IntToStr(I + 1);
    R[0].Stages[I].ResultValue := '00:01:00.000';
  end;
  for M := 0 to 7 do
  begin
    O := DefaultOverallReportOptions;
    O.StagePlaces := (M and 1) <> 0;
    O.StageGaps := (M and 2) <> 0;
    O.StagePenalties := (M and 4) <> 0;
    Count := 1 + Ord(O.StagePlaces) + Ord(O.StageGaps) + Ord(O.StagePenalties);
    D := PrepareOverallProtocol(R, S, O);
    try
      AssertEquals(6 + 32 * Count, Length(D.Columns));
      AssertEquals('Итог', D.Columns[High(D.Columns) - 1].Caption);
      AssertEquals(Length(D.Columns), Length(D.Rows[0].Cells));
      AssertEquals(1, D.Columns[4].StageIndex);
      AssertEquals(32, D.Columns[4 + 31 * Count].StageIndex);
    finally
      D.Free;
    end;
  end;
end;

procedure TOverallFinishReportModelTests.CategoriesAndPlacesRemainSaved;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultOverallReportOptions;
  O.Detailed := False;
  SetLength(R, 3);
  R[0] := Rider(1, '', '1', '00:01:00.000');
  R[1] := Rider(123, 'A', '5', '00:02:00.000');
  R[2] := Rider(9, 'A', '2', '00:01:00.000');
  S := nil;
  O.Display.AllCategories := False;
  SetLength(O.Display.Categories, 1);
  O.Display.Categories[0] := 'A';
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals(2, Length(D.Rows));
    AssertEquals(9, D.Rows[0].Number);
    AssertEquals('5', D.Rows[1].Cells[0]);
  finally
    D.Free;
  end;
end;

procedure TOverallFinishReportModelTests.StageStatusesDoNotReplaceGlobalResults;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultOverallReportOptions;
  SetLength(S, 2);
  S[0].Index := 1;
  S[1].Index := 3;
  SetLength(R, 1);
  R[0] := Rider(123, 'A', '', 'DSQ');
  SetLength(R[0].Stages, 2);
  R[0].Stages[0].ResultValue := '00:01:00.000';
  R[0].Stages[1].Status := '2';
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals('01:00.000', D.Rows[0].Cells[4]);
    AssertEquals('DNF', D.Rows[0].Cells[5]);
    AssertEquals('DSQ', D.Rows[0].Cells[6]);
  finally
    D.Free;
  end;
  R[0].ResultValue := 'saved text';
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals('saved text', D.Rows[0].Cells[6]);
  finally
    D.Free;
  end;
end;

procedure TOverallFinishReportModelTests.EmptySelectionAndIncompleteFilter;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultOverallReportOptions;
  O.Display.IncludeIncomplete := False;
  SetLength(R, 3);
  R[0] := Rider(1, 'A', '', '');
  R[1] := Rider(2, 'A', '', 'DNF');
  R[2] := Rider(3, 'A', '', '00:01:00.000');
  S := nil;
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals(2, Length(D.Rows));
  finally
    D.Free;
  end;
  O.Display.AllCategories := False;
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals(0, Length(D.Rows));
  finally
    D.Free;
  end;
end;

procedure TOverallFinishReportModelTests.StageNamesNeedNoPrefixAndEmptyNamesUseIndex;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultOverallReportOptions;
  SetLength(R, 1);
  R[0] := Rider(123, 'A', '1', '00:01:00.000');
  SetLength(S, 3);
  S[0].Index := 1;
  S[0].Name := 'Старт 1';
  S[1].Index := 2;
  S[1].Name := '  ';
  S[2].Index := 3;
  S[2].Name := 'СУ 3';
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals('Старт 1', D.Columns[4].GroupCaption);
    AssertEquals('СУ 2', D.Columns[5].GroupCaption);
    AssertEquals('СУ 3', D.Columns[6].GroupCaption);
  finally
    D.Free;
  end;
  O.Display.Language := rlEnglish;
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals('Stage 2', D.Columns[5].GroupCaption);
    AssertEquals('Старт 1', D.Columns[4].GroupCaption);
  finally
    D.Free;
  end;
end;

procedure TOverallFinishReportModelTests.PartialResultsOrderBySavedCompletedStages;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultOverallReportOptions;
  O.Detailed := False;
  S := nil;
  SetLength(R, 5);
  R[0] := Rider(1, 'A', '', '00:05:00.000');
  R[0].CompletedStages := '10';
  R[0].Gap := '+2 СУ';
  R[1] := Rider(123, 'A', '', '00:06:00.000');
  R[1].CompletedStages := '11';
  R[1].Gap := '+1 СУ';
  R[2] := Rider(9, 'A', '', '00:01:00.000');
  R[2].CompletedStages := '2';
  R[2].Gap := '+10 СУ';
  R[3] := Rider(2, 'A', '', '00:00:00.000');
  R[4] := Rider(77, 'A', '5', '00:07:00.000');
  R[4].CompletedStages := '0';
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals(77, D.Rows[0].Number);
    AssertEquals(123, D.Rows[1].Number);
    AssertEquals('+1 СУ', D.Rows[1].Cells[5]);
    AssertEquals(1, D.Rows[2].Number);
    AssertEquals(9, D.Rows[3].Number);
    AssertEquals(2, D.Rows[4].Number);
    AssertEquals('5', D.Rows[0].Cells[0]);
  finally
    D.Free;
  end;
end;

procedure TOverallFinishReportModelTests.EqualCompletedStagesOrderBySavedTimeThenNumber;
var
  R: TOverallReportRows;
  S: TOverallStageInfos;
  O: TOverallReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultOverallReportOptions;
  O.Detailed := False;
  S := nil;
  SetLength(R, 5);
  R[0] := Rider(1, 'A', '', '00:06:00.000');
  R[0].CompletedStages := '3';
  R[1] := Rider(123, 'A', '', '00:04:00.250');
  R[1].CompletedStages := '3';
  R[2] := Rider(456, 'A', '', '00:04:00.125');
  R[2].CompletedStages := '3';
  R[3] := Rider(999, 'A', '', '00:04:00.125');
  R[3].CompletedStages := '3';
  R[4] := Rider(7, 'A', '', '00:00:01.000');
  R[4].CompletedStages := '2';
  D := PrepareOverallProtocol(R, S, O);
  try
    AssertEquals(456, D.Rows[0].Number);
    AssertEquals(999, D.Rows[1].Number);
    AssertEquals(123, D.Rows[2].Number);
    AssertEquals(1, D.Rows[3].Number);
    AssertEquals(7, D.Rows[4].Number);
    AssertEquals('04:00.125', D.Rows[0].Cells[4]);
  finally
    D.Free;
  end;
end;

initialization
  RegisterTest(TOverallFinishReportModelTests);
end.
