unit DataLayerSplitTests;

{$mode ObjFPC}{$H+}

interface

uses
  fpcunit, testregistry, ConfigRepository, CompetitionSchemaMigrator,
  StartMarkRepository, FinishMarkRepository, CompetitionQueryProvider,
  ParticipantRepository,
  StageResultRepository, ResultCalculationRepository,
  CompetitionImportRepository;

type
  TDataLayerSplitTests = class(TTestCase)
  published
    procedure ConfigApi_IsAvailableWithoutDbSqlFacade;
    procedure SchemaApi_IsAvailableWithoutDbSqlFacade;
    procedure StartMarkApi_IsAvailableWithoutDbSqlFacade;
    procedure FinishMarkApi_IsAvailableWithoutDbSqlFacade;
    procedure QueryProviderApi_IsAvailableWithoutDbSqlFacade;
    procedure ParticipantApi_IsAvailableWithoutDbSqlFacade;
    procedure StageResultApi_IsAvailableWithoutDbSqlFacade;
    procedure ResultCalculationApi_IsAvailableWithoutDbSqlFacade;
    procedure CompetitionImportApi_IsAvailableWithoutDbSqlFacade;
  end;

implementation

procedure TDataLayerSplitTests.ConfigApi_IsAvailableWithoutDbSqlFacade;
begin
  AssertEquals(
    'INSERT INTO config (key, value) VALUES (:KEY, :VALUE) ' +
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value;',
    TConfigSql.UpsertByKey);
end;

procedure TDataLayerSplitTests.SchemaApi_IsAvailableWithoutDbSqlFacade;
begin
  AssertEquals('Begin Transaction', TSchemaSql.BeginTransaction);
  AssertEquals('End Transaction', TSchemaSql.EndTransaction);
end;

procedure TDataLayerSplitTests.StartMarkApi_IsAvailableWithoutDbSqlFacade;
begin
  AssertEquals(
    'SELECT * FROM start_marks ORDER BY received_at DESC, id DESC;',
    TStartMarkSql.SelectJournal);
end;

procedure TDataLayerSplitTests.FinishMarkApi_IsAvailableWithoutDbSqlFacade;
begin
  AssertEquals(
    'SELECT * FROM finish_marks ORDER BY received_at, id;',
    TFinishMarkSql.SelectAll);
end;

procedure TDataLayerSplitTests.QueryProviderApi_IsAvailableWithoutDbSqlFacade;
begin
  AssertTrue(Pos('SELECT category, sumplace, number, name',
    TDatasetSql.ResultStageSum([1])) = 1);
  AssertTrue(Pos('ORDER BY number ASC',
    TStartlistSql.SelectNumbersForCategory(STARTLIST_SORT_BY_NUMBER_ASC,
      False, False, False)) > 0);
end;

procedure TDataLayerSplitTests.ParticipantApi_IsAvailableWithoutDbSqlFacade;
begin
  AssertEquals('SELECT number FROM main WHERE number IS NOT NULL;',
    TParticipantRepository.SelectNumbers);
  AssertEquals('SELECT number FROM main WHERE status NOTNULL;',
    TParticipantRepository.SelectStatusAll);
end;

procedure TDataLayerSplitTests.StageResultApi_IsAvailableWithoutDbSqlFacade;
begin
  AssertEquals('UPDATE main SET starttime2 = NULL;',
    TStageResultRepository.ResetStartTime(2));
  AssertTrue(Pos('status2 NOTNULL',
    TStageResultRepository.SelectStatusByStage(2)) > 0);
end;

procedure TDataLayerSplitTests.ResultCalculationApi_IsAvailableWithoutDbSqlFacade;
begin
  AssertEquals('UPDATE main SET sumplace = NULL, sumdiffleader = NULL;',
    TResultCalculationRepository.ResetSumPlaceAndDiff);
  AssertTrue(Pos('result3',
    TResultCalculationRepository.SelectForSumCalculation([1, 3])) > 0);
end;

procedure TDataLayerSplitTests.CompetitionImportApi_IsAvailableWithoutDbSqlFacade;
begin
  AssertTrue(Pos('INSERT INTO main',
    TCompetitionImportRepository.UpsertParticipantRowStatement(2)) > 0);
  AssertTrue(Pos(':STARTTIME2',
    TCompetitionImportRepository.UpsertParticipantRowStatement(2)) > 0);
  AssertTrue(Pos('finishtime2',
    TCompetitionImportRepository.UpsertStageResultRowStatement(
      srifFinish, 2, 2)) > 0);
end;

initialization
  RegisterTest(TDataLayerSplitTests);

end.
