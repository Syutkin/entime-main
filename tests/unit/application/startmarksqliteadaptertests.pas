unit StartMarkSqliteAdapterTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, FPCUnit, TestRegistry, SQLDB, CompetitionDbContext,
  CompetitionSchemaMigrator, StageModel, TimingMark, StartMark,
  StartMarkService, StartMarkSqliteAdapters;

type
  { TStartMarkSqliteAdapterTests }

  TStartMarkSqliteAdapterTests = class(TTestCase)
  private
    FApplyPort: IStartMarkApplyPort;
    FCandidateProvider: IStartMarkCandidateProvider;
    FContext: TCompetitionDbContext;
    FPersistence: IStartMarkPersistence;
    FQuery: TSQLQuery;
    FService: TStartMarkService;
    FStages: TStages;
    function MarkAt(const ATime: TDateTime;
      const AStageIndex: integer = 1): TStartMark;
    procedure ExecSql(const ASql: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Receive_ManualModePersistsMatchedProposal;
    procedure Receive_AutomaticModeAtomicallyAppliesAndRecalculates;
    procedure Receive_AutomaticModePreservesExistingCorrectionAsConflict;
    procedure ApplyManual_CanAtomicallyApplyToDifferentStage;
    procedure Receive_CalculationFailureRollsBackCorrectionAndMarksError;
  end;

implementation

procedure TStartMarkSqliteAdapterTests.SetUp;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  inherited SetUp;
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FQuery := FContext.CreateQuery(nil);
  FStages := TStages.Create(2);
  FStages[2].isActive := True;
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, 2,
      'A', 'B', 'C', 'D', 'E', 'Start mark adapter test');
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
  FPersistence := TSqliteStartMarkPersistence.Create(FContext);
  FCandidateProvider := TSqliteStartMarkCandidateProvider.Create(
    FContext, FStages);
  FApplyPort := TSqliteStartMarkApplyPort.Create(FContext, FStages);
  FService := TStartMarkService.Create(FCandidateProvider, FApplyPort,
    FPersistence);
end;

procedure TStartMarkSqliteAdapterTests.TearDown;
begin
  FService.Free;
  FService := nil;
  FApplyPort := nil;
  FCandidateProvider := nil;
  FPersistence := nil;
  FStages.Free;
  FQuery.Free;
  FContext.Free;
  inherited TearDown;
end;

procedure TStartMarkSqliteAdapterTests.ExecSql(const ASql: string);
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

function TStartMarkSqliteAdapterTests.MarkAt(const ATime: TDateTime;
  const AStageIndex: integer): TStartMark;
begin
  Result := TStartMark.FromTimingMark(TTimingMark.Start(ATime, True, 15,
    TTimingMarkSource.Serial('COM7'),
    EncodeDateTime(2026, 8, 13, 10, 0, 1, 123)), AStageIndex);
end;

procedure TStartMarkSqliteAdapterTests.
  Receive_ManualModePersistsMatchedProposal;
var
  Result: TStartMarkReceiveResult;
begin
  ExecSql('INSERT INTO main (number, starttime1) VALUES ' +
    '(101, ''10:00:02.000'');');

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 0, 0)), 3,
    False, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertTrue(Result.Mark.Id > 0);
  AssertEquals(Ord(smsPending), Ord(Result.Mark.Status));
  AssertEquals(101, Result.Mark.ParticipantNumber);
  FQuery.SQL.Text :=
    'SELECT participant_number, status FROM start_marks WHERE id = :ID;';
  FQuery.ParamByName('ID').AsLargeInt := Result.Mark.Id;
  FQuery.Open;
  AssertEquals(101, FQuery.FieldByName('participant_number').AsInteger);
  AssertEquals('pending', FQuery.FieldByName('status').AsString);
end;

procedure TStartMarkSqliteAdapterTests.
  Receive_AutomaticModeAtomicallyAppliesAndRecalculates;
var
  AppliedAt: TDateTime;
  Result: TStartMarkReceiveResult;
begin
  ExecSql('INSERT INTO main ' +
    '(number, category, starttime1, finishtime1) VALUES ' +
    '(102, ''A'', ''10:00:00.000'', ''10:10:00.000'');');
  AppliedAt := EncodeDateTime(2026, 8, 13, 10, 0, 3, 456);

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 1, 0)), 3,
    True, AppliedAt);

  AssertEquals(Ord(smsApplied), Ord(Result.Mark.Status));
  FQuery.SQL.Text :=
    'SELECT m.correction1, m.result1, s.stage_index, ' +
    's.applied_stage_index, s.participant_number, s.assignment_mode, ' +
    's.status FROM main m JOIN start_marks s ' +
    'ON s.id = :ID WHERE m.number = 102;';
  FQuery.ParamByName('ID').AsLargeInt := Result.Mark.Id;
  FQuery.Open;
  AssertEquals(15, FQuery.FieldByName('correction1').AsInteger);
  AssertEquals('00:10:00.015', FQuery.FieldByName('result1').AsString);
  AssertEquals(1, FQuery.FieldByName('stage_index').AsInteger);
  AssertEquals(1, FQuery.FieldByName('applied_stage_index').AsInteger);
  AssertEquals(102, FQuery.FieldByName('participant_number').AsInteger);
  AssertEquals('automatic', FQuery.FieldByName('assignment_mode').AsString);
  AssertEquals('applied', FQuery.FieldByName('status').AsString);
end;

procedure TStartMarkSqliteAdapterTests.
  Receive_AutomaticModePreservesExistingCorrectionAsConflict;
var
  Result: TStartMarkReceiveResult;
begin
  ExecSql('INSERT INTO main (number, starttime1, correction1) VALUES ' +
    '(103, ''10:00:00.000'', 5);');

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 1, 0)), 3,
    True, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertEquals(Ord(smafExistingCorrection), Ord(Result.ApplyFailure));
  AssertEquals(Ord(smsConflict), Ord(Result.Mark.Status));
  FQuery.SQL.Text :=
    'SELECT m.correction1, s.status, s.diagnostic ' +
    'FROM main m JOIN start_marks s ON s.id = :ID ' +
    'WHERE m.number = 103;';
  FQuery.ParamByName('ID').AsLargeInt := Result.Mark.Id;
  FQuery.Open;
  AssertEquals(5, FQuery.FieldByName('correction1').AsInteger);
  AssertEquals('conflict', FQuery.FieldByName('status').AsString);
  AssertEquals('existing_correction',
    FQuery.FieldByName('diagnostic').AsString);
end;

procedure TStartMarkSqliteAdapterTests.
  ApplyManual_CanAtomicallyApplyToDifferentStage;
var
  Applied: TStartMarkApplyResult;
  Received: TStartMarkReceiveResult;
begin
  ExecSql('INSERT INTO main ' +
    '(number, category, starttime1, starttime2, finishtime2) VALUES ' +
    '(104, ''A'', ''10:00:00.000'', ''11:00:00.000'', ' +
    '''11:10:00.000'');');
  Received := FService.Receive(MarkAt(EncodeTime(10, 0, 1, 0)), 3,
    False, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  Applied := FService.ApplyManual(Received.Mark, 104, 2, False,
    EncodeDateTime(2026, 8, 13, 10, 0, 4, 0));

  AssertTrue(Applied.Applied);
  AssertEquals(1, Applied.Mark.StageIndex);
  AssertEquals(2, Applied.Mark.AppliedStageIndex);
  FQuery.SQL.Text :=
    'SELECT m.correction1, m.correction2, s.stage_index, ' +
    's.applied_stage_index, s.assignment_mode, s.status ' +
    'FROM main m JOIN start_marks s ON s.id = :ID ' +
    'WHERE m.number = 104;';
  FQuery.ParamByName('ID').AsLargeInt := Applied.Mark.Id;
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('correction1').IsNull);
  AssertEquals(15, FQuery.FieldByName('correction2').AsInteger);
  AssertEquals(1, FQuery.FieldByName('stage_index').AsInteger);
  AssertEquals(2, FQuery.FieldByName('applied_stage_index').AsInteger);
  AssertEquals('manual', FQuery.FieldByName('assignment_mode').AsString);
  AssertEquals('applied', FQuery.FieldByName('status').AsString);
end;

procedure TStartMarkSqliteAdapterTests.
  Receive_CalculationFailureRollsBackCorrectionAndMarksError;
var
  Result: TStartMarkReceiveResult;
begin
  ExecSql('INSERT INTO main ' +
    '(number, category, starttime1, finishtime1) VALUES ' +
    '(105, ''A'', ''10:00:00.000'', ''10:10:00.000'');');
  ExecSql('CREATE TRIGGER fail_start_mark_result ' +
    'BEFORE UPDATE OF result1 ON main WHEN NEW.number = 105 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced start mark calculation failure''); END;');

  Result := FService.Receive(MarkAt(EncodeTime(10, 0, 1, 0)), 3,
    True, EncodeDateTime(2026, 8, 13, 10, 0, 3, 0));

  AssertEquals(Ord(smafApplicationError), Ord(Result.ApplyFailure));
  AssertEquals(Ord(smsError), Ord(Result.Mark.Status));
  FQuery.SQL.Text :=
    'SELECT m.correction1, s.applied_stage_index, ' +
    's.assignment_mode, s.status, s.diagnostic ' +
    'FROM main m JOIN start_marks s ON s.id = :ID ' +
    'WHERE m.number = 105;';
  FQuery.ParamByName('ID').AsLargeInt := Result.Mark.Id;
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('correction1').IsNull);
  AssertTrue(FQuery.FieldByName('applied_stage_index').IsNull);
  AssertTrue(FQuery.FieldByName('assignment_mode').IsNull);
  AssertEquals('error', FQuery.FieldByName('status').AsString);
  AssertTrue(Pos('forced start mark calculation failure',
    FQuery.FieldByName('diagnostic').AsString) > 0);
end;

initialization
  RegisterTest(TStartMarkSqliteAdapterTests);

end.
