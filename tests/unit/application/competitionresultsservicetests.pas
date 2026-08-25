unit CompetitionResultsServiceTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, DB, SQLDB, DbSql, StageModel,
  ParticipantStatus, CompetitionResultsService, AppLogger;

type
  TCompetitionResultsServiceTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FQuery: TSQLQuery;
    FUiQuery: TSQLQuery;
    FStages: TStages;
    FLogEntryReceived: boolean;
    FLastLogEntry: TAppLogEntry;
    procedure CreateSchema;
    procedure ExecSql(const ASql: string);
    procedure ReceiveLogEntry(const AEntry: TAppLogEntry);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure RecalculateAll_UsesOwnQueriesAndPreservesUiDataset;
    procedure ClearResults_ClearsCalculatedAndStageValues;
    procedure SetStageStatus_RecalculatesGlobalStatusAndResults;
    procedure SetDsq_RecalculatesAllResults;
    procedure ClearStageAndGlobalStatus_RecalculatesResults;
    procedure RecalculateAll_ReturnsProcessedAndChangedCounts;
    procedure RecalculateSumResults_LogsDurationOfOneDay;
    procedure SetStatus_CalculationFailureRollsBackStatus;
    procedure StartListQueries_UseOwnedQueryAndReturnOrderedCategories;
    procedure StartListGeneration_AssignsTimesAndActivatesStageAtomically;
    procedure StageValueCommands_UseOwnedQueryAndRecalculateAtomically;
  end;

implementation

procedure TCompetitionResultsServiceTests.SetUp;
begin
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FQuery := FContext.CreateQuery(nil);
  FUiQuery := FContext.CreateQuery(nil);
  FContext.RegisterUiQuery(FUiQuery);
  FStages := TStages.Create(2);
  FLogEntryReceived := False;
  FLastLogEntry.MessageText := '';
  SetAppLogEvent(@ReceiveLogEntry);
  CreateSchema;
end;

procedure TCompetitionResultsServiceTests.TearDown;
begin
  SetAppLogEvent(nil);
  FStages.Free;
  FUiQuery.Free;
  FQuery.Free;
  FContext.Free;
end;

procedure TCompetitionResultsServiceTests.ReceiveLogEntry(
  const AEntry: TAppLogEntry);
begin
  FLogEntryReceived := True;
  FLastLogEntry := AEntry;
end;

procedure TCompetitionResultsServiceTests.CreateSchema;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, 2,
      'A', 'B', 'C', 'D', 'E', 'Test race');
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
end;

procedure TCompetitionResultsServiceTests.ExecSql(const ASql: string);
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    FQuery.Close;
    FQuery.SQL.Text := ASql;
    FQuery.ExecSQL;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
end;

procedure TCompetitionResultsServiceTests.
  RecalculateAll_UsesOwnQueriesAndPreservesUiDataset;
begin
  ExecSql(
    'INSERT INTO main (number, name, starttime1, finishtime1) VALUES ' +
    '(101, ''Runner'', ''10:00:00.000'', ''10:10:00.000'');');
  FUiQuery.SQL.Text := 'SELECT number, name FROM main ORDER BY number;';
  FUiQuery.Open;

  TResultCalculationService.RecalculateAll(FContext, FStages);

  AssertTrue('Service must not close the UI dataset', FUiQuery.Active);
  AssertEquals('SELECT number, name FROM main ORDER BY number;',
    Trim(FUiQuery.SQL.Text));

  FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT result1, sumresult, sumstages, place1, sumplace, thruplace ' +
    'FROM main WHERE number = 101;';
  FQuery.Open;
  AssertEquals('00:10:00.000', FQuery.FieldByName('result1').AsString);
  AssertEquals('00:10:00.000', FQuery.FieldByName('sumresult').AsString);
  AssertEquals(1, FQuery.FieldByName('sumstages').AsInteger);
  AssertEquals(1, FQuery.FieldByName('place1').AsInteger);
  AssertEquals(1, FQuery.FieldByName('sumplace').AsInteger);
  AssertEquals(1, FQuery.FieldByName('thruplace').AsInteger);
end;

procedure TCompetitionResultsServiceTests.
  ClearResults_ClearsCalculatedAndStageValues;
begin
  ExecSql(
    'INSERT INTO main (number, starttime1, correction1, finishtime1, ' +
    'penalty1, result1, diffleader1, place1, status1, sumresult, ' +
    'sumplace, sumdiffleader, thrudiff, thruplace, status) VALUES ' +
    '(102, ''10:00:00.000'', 50, ''10:10:00.000'', ''00:00:05.000'', ' +
    '''00:10:05.050'', ''00:00:05.050'', 2, ''2'', ''00:10:05.050'', ' +
    '2, ''00:00:05.050'', ''00:00:05.050'', 2, ''2'');');

  TResultCalculationService.ClearResults(FContext, FStages.Count);

  FQuery.SQL.Text :=
    'SELECT starttime1, correction1, finishtime1, penalty1, result1, ' +
    'status1, sumresult, sumplace, status FROM main WHERE number = 102;';
  FQuery.Open;
  AssertEquals('10:00:00.000',
    FQuery.FieldByName('starttime1').AsString);
  AssertTrue(FQuery.FieldByName('correction1').IsNull);
  AssertTrue(FQuery.FieldByName('finishtime1').IsNull);
  AssertTrue(FQuery.FieldByName('penalty1').IsNull);
  AssertTrue(FQuery.FieldByName('result1').IsNull);
  AssertTrue(FQuery.FieldByName('status1').IsNull);
  AssertTrue(FQuery.FieldByName('sumresult').IsNull);
  AssertTrue(FQuery.FieldByName('sumplace').IsNull);
  AssertTrue(FQuery.FieldByName('status').IsNull);
end;

procedure TCompetitionResultsServiceTests.
  SetStageStatus_RecalculatesGlobalStatusAndResults;
var
  Outcome: TParticipantStatusOutcome;
begin
  ExecSql(
    'INSERT INTO main (number, starttime1, finishtime1) VALUES ' +
    '(103, ''10:00:00.000'', ''10:10:00.000'');');

  Outcome := TParticipantStatusService.SetStatus(FContext, FStages,
    103, 1, psDNS);

  AssertEquals(Ord(psNone), Ord(Outcome.PreviousStatus));
  AssertTrue(Outcome.Changed);
  FQuery.SQL.Text :=
    'SELECT status, status1, result1, sumresult FROM main ' +
    'WHERE number = 103;';
  FQuery.Open;
  AssertEquals('1', FQuery.FieldByName('status').AsString);
  AssertEquals('1', FQuery.FieldByName('status1').AsString);
  AssertEquals('DNS', FQuery.FieldByName('result1').AsString);
  AssertEquals('DNS', FQuery.FieldByName('sumresult').AsString);
end;

procedure TCompetitionResultsServiceTests.SetDsq_RecalculatesAllResults;
var
  Outcome: TParticipantStatusOutcome;
begin
  ExecSql(
    'INSERT INTO main (number, starttime1, finishtime1) VALUES ' +
    '(104, ''10:00:00.000'', ''10:10:00.000'');');

  Outcome := TParticipantStatusService.SetStatus(FContext, FStages,
    104, 1, psDSQ);

  AssertTrue(Outcome.Changed);
  FQuery.SQL.Text :=
    'SELECT status, result1, sumresult FROM main WHERE number = 104;';
  FQuery.Open;
  AssertEquals('3', FQuery.FieldByName('status').AsString);
  AssertEquals('DSQ', FQuery.FieldByName('result1').AsString);
  AssertEquals('DSQ', FQuery.FieldByName('sumresult').AsString);
end;

procedure TCompetitionResultsServiceTests.
  ClearStageAndGlobalStatus_RecalculatesResults;
begin
  ExecSql(
    'INSERT INTO main (number, status, status1, result1) VALUES ' +
    '(105, ''1'', ''1'', ''DNS'');');

  TParticipantStatusService.ClearStatus(FContext, FStages, 105, 1,
    pcscStageAndGlobal);

  FQuery.SQL.Text :=
    'SELECT status, status1, result1, sumresult FROM main ' +
    'WHERE number = 105;';
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('status').IsNull);
  AssertTrue(FQuery.FieldByName('status1').IsNull);
  AssertTrue(FQuery.FieldByName('result1').IsNull);
  AssertTrue(FQuery.FieldByName('sumresult').IsNull);
end;

procedure TCompetitionResultsServiceTests.
  RecalculateAll_ReturnsProcessedAndChangedCounts;
var
  Outcome: TStatusRecalculationOutcome;
begin
  ExecSql(
    'INSERT INTO main (number, status, status1) VALUES ' +
    '(106, NULL, ''1''), (107, ''3'', NULL);');

  Outcome := TParticipantStatusService.RecalculateAll(FContext, FStages);

  AssertEquals(2, Outcome.ProcessedCount);
  AssertEquals(1, Outcome.ChangedCount);
  FQuery.SQL.Text :=
    'SELECT status FROM main WHERE number = 106;';
  FQuery.Open;
  AssertEquals('1', FQuery.FieldByName('status').AsString);
end;

procedure TCompetitionResultsServiceTests.
  RecalculateSumResults_LogsDurationOfOneDay;
begin
  FStages[2].isActive := True;
  ExecSql(
    'INSERT INTO main (number, result1, result2, sumresult) VALUES ' +
    '(109, ''12:00:00.000'', ''12:00:00.000'', ''previous'');');

  TResultCalculationService.RecalculateSumResults(FContext, FStages);

  AssertTrue('A sum duration of 24 hours must be logged', FLogEntryReceived);
  AssertEquals(Ord(allWarning), Ord(FLastLogEntry.Level));
  AssertEquals(Ord(alvDetails), Ord(FLastLogEntry.View));
  AssertEquals(Ord(alsResults), Ord(FLastLogEntry.Source));
  AssertTrue('Log message must identify the participant',
    Pos('109', FLastLogEntry.MessageText) > 0);
  AssertTrue('Log message must explain the 24-hour limit',
    Pos('24', FLastLogEntry.MessageText) > 0);

  FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT sumresult, sumstages FROM main WHERE number = 109;';
  FQuery.Open;
  AssertEquals('Calculation must continue after the warning',
    '00:00:00.000', FQuery.FieldByName('sumresult').AsString);
  AssertEquals('Calculated stage count must be retained',
    2, FQuery.FieldByName('sumstages').AsInteger);
end;

procedure TCompetitionResultsServiceTests.
  SetStatus_CalculationFailureRollsBackStatus;
begin
  ExecSql('INSERT INTO main (number) VALUES (108);');
  FStages.Resize(3);
  FStages[3].isActive := True;

  try
    TParticipantStatusService.SetStatus(FContext, FStages, 108, 1, psDNS);
    Fail('Missing stage columns must fail status calculation');
  except
    on E: EDatabaseError do
      AssertTrue(E.Message <> '');
  end;

  FQuery.SQL.Text :=
    'SELECT status, status1 FROM main WHERE number = 108;';
  FQuery.Open;
  AssertTrue('Global status must be rolled back',
    FQuery.FieldByName('status').IsNull);
  AssertTrue('Stage status must be rolled back',
    FQuery.FieldByName('status1').IsNull);
end;

procedure TCompetitionResultsServiceTests.
  StartListQueries_UseOwnedQueryAndReturnOrderedCategories;
var
  Categories: TStringList;
begin
  ExecSql(
    'INSERT INTO main (number, category, starttime1, finishtime1) VALUES ' +
    '(201, ''Late'', ''10:20:00.000'', NULL), ' +
    '(202, ''Early'', ''10:00:00.000'', ''10:15:00.000''), ' +
    '(203, ''Late'', ''10:10:00.000'', NULL);');
  FUiQuery.SQL.Text := 'SELECT number FROM main ORDER BY number;';
  FUiQuery.Open;
  Categories := TStringList.Create;
  try
    TCompetitionStartListService.LoadCategories(FContext, 1,
      FStages.Count, Categories);

    AssertEquals(2, Categories.Count);
    AssertEquals('Early', Categories[0]);
    AssertEquals('Late', Categories[1]);
    AssertTrue(TCompetitionStartListService.HasFinishes(FContext, 1,
      FStages.Count));
    AssertFalse(TCompetitionStartListService.HasFinishes(FContext, 2,
      FStages.Count));
    AssertTrue('Read service must preserve UI datasets', FUiQuery.Active);
  finally
    Categories.Free;
  end;
end;

procedure TCompetitionResultsServiceTests.
  StartListGeneration_AssignsTimesAndActivatesStageAtomically;
var
  Categories: TStringList;
  Generation: TStartListGeneration;
begin
  ExecSql(
    'INSERT INTO main (number, name, category, status) VALUES ' +
    '(301, ''Zulu'', ''First'', NULL), ' +
    '(302, ''Alpha'', ''First'', NULL), ' +
    '(303, ''Middle'', ''Second'', NULL);');
  FUiQuery.SQL.Text := 'SELECT number FROM main ORDER BY number;';
  FUiQuery.Open;
  Categories := TStringList.Create;
  try
    Categories.Add('First');
    Categories.Add('Second');
    Generation := Default(TStartListGeneration);
    Generation.StageIndex := 2;
    Generation.StartTime := EncodeTime(10, 0, 0, 0);
    Generation.DelayBetweenRacersSeconds := 30;
    Generation.DelayBetweenCategoriesMinutes := 2;
    Generation.SortBy := 2;
    Generation.IncludeDNS := True;
    Generation.IncludeDNF := True;
    Generation.ActivateStage := True;

    TCompetitionStartListService.GenerateStartTimes(
      FContext, FStages, Categories, Generation);

    AssertTrue('Generation must preserve registered UI datasets',
      FUiQuery.Active);
    AssertTrue(TConfigSql.GetBool(FQuery, 'stage2', False));
    FQuery.Close;
    FQuery.SQL.Text :=
      'SELECT number, starttime2 FROM main ORDER BY number;';
    FQuery.Open;
    AssertEquals(301, FQuery.FieldByName('number').AsInteger);
    AssertEquals('10:00:30', FQuery.FieldByName('starttime2').AsString);
    FQuery.Next;
    AssertEquals(302, FQuery.FieldByName('number').AsInteger);
    AssertEquals('10:00:00', FQuery.FieldByName('starttime2').AsString);
    FQuery.Next;
    AssertEquals(303, FQuery.FieldByName('number').AsInteger);
    AssertEquals('10:03:00', FQuery.FieldByName('starttime2').AsString);
  finally
    Categories.Free;
  end;
end;

procedure TCompetitionResultsServiceTests.
  StageValueCommands_UseOwnedQueryAndRecalculateAtomically;
var
  Outcome: TParticipantStageValueOutcome;
begin
  ExecSql(
    'INSERT INTO main (number, starttime1, finishtime1) VALUES ' +
    '(204, ''10:00:00.000'', ''10:10:00.000'');');
  FUiQuery.SQL.Text := 'SELECT number FROM main ORDER BY number;';
  FUiQuery.Open;

  TParticipantStageService.SaveCorrection(FContext, FStages, 204, 1, 250);
  Outcome := TParticipantStageService.SaveStartTime(FContext, FStages,
    204, 1, '10:01:00.000');

  AssertEquals('10:00:00.000', Outcome.PreviousValue);
  AssertEquals('10:01:00.000', Outcome.CurrentValue);
  AssertTrue(Outcome.Changed);
  AssertTrue('Write service must preserve UI datasets', FUiQuery.Active);
  FQuery.SQL.Text :=
    'SELECT starttime1, correction1, result1 FROM main WHERE number = 204;';
  FQuery.Open;
  AssertEquals('10:01:00.000', FQuery.FieldByName('starttime1').AsString);
  AssertEquals(250, FQuery.FieldByName('correction1').AsInteger);
  AssertEquals('00:09:00.250', FQuery.FieldByName('result1').AsString);
end;

initialization
  RegisterTest(TCompetitionResultsServiceTests);

end.
