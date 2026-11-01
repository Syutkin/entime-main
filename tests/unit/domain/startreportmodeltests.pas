unit StartReportModelTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  TStartReportModelTests = class(TTestCase)
  published
    procedure AllSingleStagesKeepSeparateActiveSections;
    procedure FitWidthIsLimitedToOverallMode;
    procedure CategoriesFollowEarliestStartRatherThanNameOrFirstRow;
    procedure NumberOrderIsContinuousAndCategoryFilterStillWorks;
    procedure TeamColumnCanBeHiddenInBothModesAndBatch;
    procedure EqualAndMissingCategoryStartsRemainStable;
    procedure OverallUsesOnlyActiveStagesAndFullClock;
    procedure SingleRequiresActiveStage;
    procedure TimeAndNumberOrdersUseChosenStage;
    procedure EqualClockPrecisionUsesNumberTieBreak;
    procedure MissingFilterKeepsPartialAssignmentsAndZero;
    procedure CategoryFiltersAndSourcesRemainUnchanged;
    procedure ThirtyTwoStagesAndUnknownText;
  end;

implementation

uses SysUtils, StartReportModel, ProtocolDocumentModel;

function Stages: TStartStageInfos;
begin
  Result := nil;
  SetLength(Result, 3);
  Result[0].Index := 1;
  Result[0].Name := 'Старт 1';
  Result[0].IsActive := True;
  Result[1].Index := 3;
  Result[1].IsActive := True;
  Result[2].Index := 8;
  Result[2].Name := 'Hidden';
end;

function Rider(N: integer; const A, B: string): TStartReportRow;
begin
  Result := Default(TStartReportRow);
  Result.Id := N;
  Result.Number := N;
  Result.Name := 'Rider ' + IntToStr(N);
  Result.Category := 'A';
  SetLength(Result.Starts, 3);
  Result.Starts[0] := A;
  Result.Starts[1] := B;
  Result.Starts[2] := '23:59:00';
end;

procedure TStartReportModelTests.AllSingleStagesKeepSeparateActiveSections;
var
  R: TStartReportRows;
  O: TStartReportOptions;
  D: TProtocolDocument;
begin
  SetLength(R, 2);
  R[0] := Rider(123, '09:00:00', '');
  R[1] := Rider(9, '', '08:00:00');
  O := DefaultStartReportOptions;
  O.Mode := srmSingleStage;
  O.AllSingleStages := True;
  O.View.StageIndex := 0;
  O.View.IncludeMissing := False;
  D := PrepareStartProtocol(R, Stages, O);
  try
    AssertEquals(2, Length(D.Sections));
    AssertEquals(2, Length(D.Rows));
    AssertEquals('Стартовый протокол — Старт 1',
      D.Sections[0].Heading);
    AssertEquals('Стартовый протокол — СУ 3',
      D.Sections[1].Heading);
    AssertEquals(123, D.Sections[0].Rows[0].Number);
    AssertEquals(9, D.Sections[1].Rows[0].Number);
    AssertEquals('08:00:00', D.Sections[1].Rows[0].Cells[3]);
    AssertEquals(4, Length(D.Sections[0].Columns));
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.FitWidthIsLimitedToOverallMode;
var
  R: TStartReportRows;
  O: TStartReportOptions;
  D: TProtocolDocument;
begin
  SetLength(R, 1);
  R[0] := Rider(1, '09:00:00', '08:00:00');
  O := DefaultStartReportOptions;
  O.FitToWidth := True;
  D := PrepareStartProtocol(R, Stages, O);
  try
    AssertTrue(D.Options.FitToWidth);
  finally
    D.Free;
  end;
  O.Mode := srmSingleStage;
  O.ShowTeam := False;
  D := PrepareStartProtocol(R, Stages, O);
  try
    AssertFalse(D.Options.FitToWidth);
    AssertEquals(154.0, D.Columns[1].Width, 0.01);
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.CategoriesFollowEarliestStartRatherThanNameOrFirstRow;
var
  R: TStartReportRows;
  O: TStartReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultStartReportOptions;
  SetLength(R, 5);
  R[0] := Rider(1, '11:00:00', '');
  R[0].Category := 'A';
  R[1] := Rider(2, '12:00:00', '');
  R[1].Category := 'Z';
  R[2] := Rider(3, '08:00:00', '');
  R[2].Category := 'Z';
  R[3] := Rider(4, '09:00:00', '');
  R[3].Category := 'B';
  R[4] := Rider(5, '07:00:00', '');
  R[4].Category := '';
  D := PrepareStartProtocol(R, Stages, O);
  try
    AssertEquals('', D.Rows[0].Category);
    AssertEquals('Z', D.Rows[1].Category);
    AssertEquals(3, D.Rows[1].Number);
    AssertEquals(2, D.Rows[2].Number);
    AssertEquals('B', D.Rows[3].Category);
    AssertEquals('A', D.Rows[4].Category);
    AssertEquals('11:00:00', R[0].Starts[0]);
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.NumberOrderIsContinuousAndCategoryFilterStillWorks;
var
  R: TStartReportRows;
  O: TStartReportOptions;
  D: TProtocolDocument;
  Mode: TStartReportMode;
begin
  O := DefaultStartReportOptions;
  O.Order := sroNumber;
  O.SortStageIndex := 3;
  SetLength(R, 4);
  R[0] := Rider(123, '06:00:00', '11:00:00');
  R[0].Category := 'A';
  R[1] := Rider(9, '10:00:00', '09:00:00');
  R[1].Category := 'Z';
  R[2] := Rider(8, '12:00:00', '10:00:00');
  R[2].Category := 'Z';
  R[3] := Rider(9, '', '');
  R[3].Category := 'A';
  R[3].Id := 100;
  for Mode := Low(Mode) to High(Mode) do
  begin
    O.Mode := Mode;
    D := PrepareStartProtocol(R, Stages, O);
    try
      AssertTrue(D.Options.HideCategories);
      AssertEquals(8, D.Rows[0].Number);
      AssertEquals(9, D.Rows[1].Id);
      AssertEquals(100, D.Rows[2].Id);
      AssertEquals(123, D.Rows[3].Number);
    finally
      D.Free;
    end;
  end;
  O.View.AllCategories := False;
  SetLength(O.View.Categories, 1);
  O.View.Categories[0] := 'A';
  D := PrepareStartProtocol(R, Stages, O);
  try
    AssertEquals(2, Length(D.Rows));
    AssertEquals(100, D.Rows[0].Id);
    AssertEquals(123, D.Rows[1].Number);
  finally
    D.Free;
  end;
  O.Order := sroTime;
  D := PrepareStartProtocol(R, Stages, O);
  try
    AssertFalse(D.Options.HideCategories);
  finally
    D.Free;
  end;
  AssertEquals('Z', R[1].Category);
end;

procedure TStartReportModelTests.TeamColumnCanBeHiddenInBothModesAndBatch;
var
  R: TStartReportRows;
  O: TStartReportOptions;
  D: TProtocolDocument;
  Mode: TStartReportMode;
  I: integer;
begin
  SetLength(R, 1);
  R[0] := Rider(123, '09:00:00.123', '10:00:00');
  R[0].Team := 'TEAM_TOKEN';
  O := DefaultStartReportOptions;
  AssertTrue(O.ShowTeam);
  O.ShowTeam := False;
  for Mode := Low(Mode) to High(Mode) do
  begin
    O.Mode := Mode;
    D := PrepareStartProtocol(R, Stages, O);
    try
      AssertEquals(3 + Ord(Mode = srmAllStages), Length(D.Columns));
      AssertEquals('09:00:00.123', D.Rows[0].Cells[2]);
      for I := 0 to High(D.Rows[0].Cells) do
        AssertTrue(D.Rows[0].Cells[I] <> 'TEAM_TOKEN');
    finally
      D.Free;
    end;
  end;
  O.AllSingleStages := True;
  D := PrepareStartProtocol(R, Stages, O);
  try
    AssertEquals(2, Length(D.Sections));
    AssertEquals(3, Length(D.Sections[0].Columns));
    AssertEquals(3, Length(D.Sections[1].Rows[0].Cells));
  finally
    D.Free;
  end;
  AssertEquals('TEAM_TOKEN', R[0].Team);
end;

procedure TStartReportModelTests.EqualAndMissingCategoryStartsRemainStable;
var
  R: TStartReportRows;
  O: TStartReportOptions;
  D: TProtocolDocument;
begin
  O := DefaultStartReportOptions;
  SetLength(R, 4);
  R[0] := Rider(1, '', '');
  R[0].Category := 'B';
  R[1] := Rider(2, '09:00:00.000', '');
  R[1].Category := 'Z';
  R[2] := Rider(3, '09:00:00', '');
  R[2].Category := 'A';
  R[3] := Rider(4, '', '');
  R[3].Category := '';
  D := PrepareStartProtocol(R, Stages, O);
  try
    AssertEquals('A', D.Rows[0].Category);
    AssertEquals('Z', D.Rows[1].Category);
    AssertEquals('B', D.Rows[2].Category);
    AssertEquals('', D.Rows[3].Category);
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.OverallUsesOnlyActiveStagesAndFullClock;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
begin
  S := Stages;
  O := DefaultStartReportOptions;
  SetLength(R, 1);
  R[0] := Rider(123, '09:00:00', '00:00:00.123');
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(5, Length(D.Columns));
    AssertEquals('Старт 1', D.Columns[3].GroupCaption);
    AssertEquals('СУ 3', D.Columns[4].GroupCaption);
    AssertEquals('09:00:00', D.Rows[0].Cells[3]);
    AssertEquals('00:00:00.123', D.Rows[0].Cells[4]);
    AssertEquals('Общий стартовый протокол', D.Heading);
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.SingleRequiresActiveStage;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
begin
  S := Stages;
  SetLength(R, 1);
  R[0] := Rider(9, '09:00:00', '00:00:00.000');
  O := DefaultStartReportOptions;
  O.Mode := srmSingleStage;
  O.View.StageIndex := 8;
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(0, Length(D.Rows));
  finally
    D.Free;
  end;
  O.View.StageIndex := 3;
  O.View.Language := rlEnglish;
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(4, Length(D.Columns));
    AssertEquals('Start protocol — Stage 3', D.Heading);
    AssertEquals('Start', D.Columns[3].Caption);
    AssertEquals('00:00:00.000', D.Rows[0].Cells[3]);
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.TimeAndNumberOrdersUseChosenStage;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
begin
  S := Stages;
  O := DefaultStartReportOptions;
  SetLength(R, 4);
  R[0] := Rider(123, '09:00:00.250', '00:00:00');
  R[1] := Rider(9, '09:00:00.125', '18:00:00');
  R[2] := Rider(456, '09:00:00.125', '17:00:00');
  R[3] := Rider(13, '', '');
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(9, D.Rows[0].Number);
    AssertEquals(456, D.Rows[1].Number);
    AssertEquals(123, D.Rows[2].Number);
    AssertEquals(13, D.Rows[3].Number);
  finally
    D.Free;
  end;
  O.SortStageIndex := 3;
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(123, D.Rows[0].Number);
    AssertEquals(456, D.Rows[1].Number);
    AssertEquals(9, D.Rows[2].Number);
  finally
    D.Free;
  end;
  O.Order := sroNumber;
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(9, D.Rows[0].Number);
    AssertEquals(13, D.Rows[1].Number);
  finally
    D.Free;
  end;
  O.Mode := srmSingleStage;
  O.View.StageIndex := 3;
  O.SortStageIndex := 1;
  O.Order := sroTime;
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(123, D.Rows[0].Number);
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.EqualClockPrecisionUsesNumberTieBreak;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
begin
  S := Stages;
  O := DefaultStartReportOptions;
  SetLength(R, 3);
  R[0] := Rider(123, '09:00:00', '');
  R[1] := Rider(9, '09:00:00.000', '');
  R[2] := Rider(8, '09:00:00.0', '');
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(8, D.Rows[0].Number);
    AssertEquals(9, D.Rows[1].Number);
    AssertEquals(123, D.Rows[2].Number);
    AssertEquals('09:00:00.0', D.Rows[0].Cells[3]);
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.MissingFilterKeepsPartialAssignmentsAndZero;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
begin
  S := Stages;
  O := DefaultStartReportOptions;
  O.View.IncludeMissing := False;
  SetLength(R, 5);
  R[0] := Rider(1, '00:00:00.000', '');
  R[1] := Rider(2, '0', '');
  R[2] := Rider(3, '', '');
  R[3] := Rider(4, '', '');
  R[4] := Rider(5, '', '10:00:00');
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(3, Length(D.Rows));
    AssertEquals(1, D.Rows[0].Number);
    AssertEquals('0', D.Rows[1].Cells[3]);
    AssertEquals(5, D.Rows[2].Number);
    AssertEquals('—', D.Rows[2].Cells[3]);
  finally
    D.Free;
  end;
  O.Mode := srmSingleStage;
  O.View.StageIndex := 1;
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(2, Length(D.Rows));
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.CategoryFiltersAndSourcesRemainUnchanged;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
  Cats: TReportCategories;
begin
  S := Stages;
  O := DefaultStartReportOptions;
  SetLength(R, 3);
  R[0] := Rider(123, '09:00:00', '');
  R[1] := Rider(9, '08:00:00', '');
  R[1].Category := '';
  R[2] := Rider(17, '07:00:00', '');
  R[2].Category := 'a';
  Cats := StartReportCategories(R);
  AssertEquals(3, Length(Cats));
  AssertEquals('', Cats[2]);
  O.View.AllCategories := False;
  SetLength(O.View.Categories, 1);
  O.View.Categories[0] := 'A';
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(1, Length(D.Rows));
    D.Rows[0].Cells[3] := 'changed';
    AssertEquals('09:00:00', R[0].Starts[0]);
    AssertEquals(123, R[0].Number);
  finally
    D.Free;
  end;
  O.View.Categories := nil;
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(0, Length(D.Rows));
  finally
    D.Free;
  end;
end;

procedure TStartReportModelTests.ThirtyTwoStagesAndUnknownText;
var
  R: TStartReportRows;
  S: TStartStageInfos;
  O: TStartReportOptions;
  D: TProtocolDocument;
  I: integer;
begin
  O := DefaultStartReportOptions;
  SetLength(S, 32);
  SetLength(R, 1);
  R[0] := Rider(9, '', '');
  SetLength(R[0].Starts, 32);
  for I := 0 to 31 do
  begin
    S[I].Index := I + 1;
    S[I].IsActive := True;
    R[0].Starts[I] := '09:00:00.123';
  end;
  R[0].Starts[31] := 'saved text';
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(35, Length(D.Columns));
    AssertEquals(32, D.Columns[34].StageIndex);
    AssertEquals('saved text', D.Rows[0].Cells[34]);
  finally
    D.Free;
  end;
  for I := 0 to 31 do S[I].IsActive := False;
  D := PrepareStartProtocol(R, S, O);
  try
    AssertEquals(0, Length(D.Rows));
  finally
    D.Free;
  end;
end;

initialization
  RegisterTest(TStartReportModelTests);
end.
