unit DbSqlTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, DB, sqlite3conn, sqldb, DbSql,
  ParticipantStatus, ParticipantRepository, StageResultRepository,
  ResultCalculationRepository, CompetitionImportRepository, SqlValueHelpers,
  StartItemModel, StageConfig, ParticipantStageData;

type
  TDbSqlTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    procedure AssertTableExists(const ATableName: string);
    procedure AssertConfigValue(const AKey, AExpectedValue: string);
    procedure AssertColumnExists(const ATableName, AColumnName: string;
      const AExpected: boolean);
    procedure AssertColumnType(const ATableName, AColumnName,
      AExpectedType: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ExecCreateTables_OutsideSourceTree_UsesEmbeddedSchema;
    procedure ExecCreateTables_InMemoryDatabase_CreatesSchemaAndDefaults;
    procedure ExecCreateTables_CreatesVersionedSchemasAtSupportedBounds;
    procedure SchemaInspection_ReadsCapacityAndConfiguredValuesWithoutWrites;
    procedure SchemaInspection_MissingKeysReturnUnversionedDefaultsWithoutWrites;
    procedure SchemaInspection_RejectsInvalidConfiguredValues;
    procedure DetectStageCapacity_RejectsMalformedSchemas;
    procedure EnsureStageCapacity_AddsCompleteStagesAndPreservesData;
    procedure EnsureStageCapacity_ExpandsEightToTwelveAndPreservesData;
    procedure EnsureStageCapacity_SecondRunIsIdempotent;
    procedure ConfiguredStageCount_SoftReductionPreservesHigherStageData;
    procedure AddStageColumns_CompletesPartialStageAndIsIdempotent;
    procedure EnsureStageCapacity_AllChangesCanBeRolledBackTogether;
    procedure EnsureStartMarksTable_CreatesEmptyTableAndIndexes;
    procedure EnsureStartMarksTable_IsIdempotent;
    procedure EnsureFinishMarksTable_CreatesEmptyTableAndIndexes;
    procedure EnsureFinishMarksTable_IsIdempotent;
    procedure PublicFacade_DelegatesToSplitRepositories;
  end;

  TConfigSqlTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    // Test-only helper: inserts or updates a config value through TConfigSql API.
    procedure UpsertConfig(const AKey, AValue: string);
    // Test-only helper: creates a fresh in-memory schema for each test.
    procedure CreateSchema;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ExecUpsertByKey_InsertsNewKey;
    procedure ExecUpsertByKey_UpdatesExistingKey;
    procedure UpsertByKey_ReturnsExecutableSqlForInsertAndUpdate;
    procedure LoadAll_ReturnsTypedSnapshot;
    procedure GetString_ReturnsStoredValue;
    procedure GetString_ReturnsDefault_WhenKeyMissing;
    procedure GetString_ReturnsDefault_WhenValueEmpty;
    procedure GetInteger_ReturnsStoredValue;
    procedure GetInteger_UsesDefault_ForMissingInvalidOrEmptyValue;
    procedure GetBool_ParsesTrueValues;
    procedure GetBool_ParsesFalseValues;
    procedure GetBool_UsesDefault_ForInvalidOrEmpty;
    procedure GetBool_UsesDefault_WhenKeyMissing;
  end;

  TParticipantAndStageResultRepositoryTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    // Test-only helper: creates fresh in-memory schema for participant and stage-result repository tests.
    procedure CreateSchema;
    // Test-only helper: executes mutating SQL and commits transaction.
    procedure ExecSql(const ASql: string);
    // Test-only helper: executes formatted mutating SQL and commits transaction.
    procedure ExecSqlFmt(const AFormat: string; const AArgs: array of const);
    // Test-only helper: inserts minimal row into main table for arrange step.
    procedure InsertMainRow(const ANumber: integer; const ACategory: string = 'elite';
      const AName: string = 'Rider');
    // Test-only helper: opens main row by number for assertions.
    procedure OpenMainByNumber(const ANumber: integer);
    // Test-only helper: asserts current opened row field equals expected string value.
    procedure AssertFieldEquals(const AFieldName, AExpected: string);
    // Test-only helper: asserts current opened row field equals expected integer value.
    procedure AssertFieldEqualsInt(const AFieldName: string;
      const AExpected: integer);
    // Test-only helper: asserts current opened row field is SQL NULL.
    procedure AssertFieldNull(const AFieldName: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure OpenByNumber_ReturnsTrueForExistingAndFalseForMissing;
    procedure OpenByCategoryLeader_ReturnsLeaderAndReturnsFalseWhenMissing;
    procedure TryGetNumberByStartTimeBetween_ReturnsMatchAndNoMatch;
    procedure GetFinishCount_CountsOnlyNonEmptyFinishTimes;
    procedure GetPenaltyGroupsCount_CountsDistinctPenaltyCombinations;
    procedure LoadCategories_ReturnsSortedDistinctNonEmptyValues;
    procedure ExecUpdateStartTimeForNumber_SetsStartAndClearsStageStatus;
    procedure ExecUpdateCorrection_SetsCorrectionValue;
    procedure ExecUpdateCorrection_DoesNotCommitTransaction;
    procedure ExecUpdateFinishForCheckedStages_UpdatesSpecifiedStages;
    procedure ExecUpdateFinishForCheckedStages_EmptyStages_NoChanges;
    procedure ExecUpdateStageStatus_SetsStageResultAndClearsPlaceDiff;
    procedure ExecUpdateOnlyGlobalStatusDsq_SetsStatusTo3;
    procedure ExecUpdateGlobalStatus_SetsTypedValueAndClearsNone;
    procedure ExecClearOnlyGlobalStatus_ClearsGlobalStatus;
    procedure ExecClearStageStatus_ClearsOnlyStageFields;
    procedure ExecClearStatusAllForStage_ClearsStageAndGlobalStatus;
    procedure SelectAll_ReturnsInsertedRows;
    procedure SelectNumbers_ReturnsOnlyParticipantNumbers;
    procedure ResetStartTime_ClearsStageStartTimeForAllRows;
    procedure UpdateStartTime_SetsStageStartTimeForSpecificNumber;
    procedure SelectMinStartTime_ReturnsEarliestNonNullStartTime;
    procedure SelectMaxNumber_ReturnsMaximumNumber;
    procedure IsParticipantOnTrack_ReturnsCurrentStageState;
    procedure SelectCategoryGrouped_ReturnsDistinctCategories;
    procedure SelectCategoryGroupedOrderedByStartTime_OrdersByStageStartTime;
    procedure SelectCategoryResults_FiltersByCategoryAndSorts;
    procedure SelectCategoryResults_RejectsSqlFragments;
    procedure StageWriteError_IncludesOperationParticipantAndStageOnly;
    procedure SelectStatusAll_ReturnsOnlyRowsWithGlobalStatus;
    procedure SelectStatusByStage_ReturnsOnlyRowsWithStageStatus;
    procedure ExportFinishTime_ReturnsRequestedStageColumns;
    procedure TryLoadParticipantStageData_MapsFieldsToTypedModel;
  end;

  TDatasetSqlTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    // Test-only helper: creates base schema in fresh in-memory database.
    procedure CreateSchema;
    // Test-only helper: executes mutating SQL and commits transaction.
    procedure ExecSql(const ASql: string);
    // Test-only helper: executes formatted mutating SQL and commits transaction.
    procedure ExecSqlFmt(const AFormat: string; const AArgs: array of const);
    // Test-only helper: inserts minimal row into main table for arrange step.
    procedure InsertMainRow(const ANumber: integer; const ACategory: string = 'elite';
      const AName: string = 'Rider');
    // Test-only helper: opens query for assertions.
    procedure OpenBySql(const ASql: string);
    // Test-only helper: counts rows for a select SQL.
    function CountRows(const ASql: string): integer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure CorrectionPending_ReturnsOnlyRowsWithStartAndWithoutCorrectionOrStageStatus;
    procedure TrackStatus_ReturnsStartedRowsWithoutFinishAndWithoutStageStatus;
    procedure ResultStage_ReturnsRowsWithResultAndResolvesGlobalDSQStatus;
    procedure ResultStageTotal_ReturnsOnlyRowsWithSumResultOrderedByStatusThenThruPlace;
    procedure ResultStageSum_ReturnsOnlyRowsWithSumResultOrderedByCategoryStatusStagesAndPlace;
    procedure ResultStageSum_UsesActiveSparseStageIndexes;
    procedure MainParticipants_SelectsOnlyActiveSparseStageFields;
    procedure ConfigureQueries_SetsEditableAndReadOnlyRoles;
    procedure ConfigureCategoryStageResults_BindsCategoryParameter;
  end;

  TSchemaSqlStatementTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;
    FDbFilePath: string;

    procedure CreateSchema;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure BeginAndEndTransaction_AreExecutableStatements;
    procedure CreateBackup_CreatesUsableCopyAndAppliesBusyTimeout;
  end;

  TStartlistSqlTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    procedure CreateSchema;
    procedure ExecSql(const ASql: string);
    procedure ExecSqlFmt(const AFormat: string; const AArgs: array of const);
    procedure InsertMainRow(const ANumber: integer; const ACategory: string = 'elite';
      const AName: string = 'Rider');
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SelectNumbersForCategory_SortsByNumberAndName;
    procedure SelectNumbersForCategory_ResultMode_RespectsIncludeFlags;
    procedure SelectNumbersForCategory_ResultMode_ExcludesNullResultFromOtherCategory;
  end;

  TResultCalculationRepositoryTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    procedure CreateSchema;
    procedure ExecSql(const ASql: string);
    procedure ExecSqlWithStageCaption(const ASql, ACaption: string);
    procedure ExecSqlFmt(const AFormat: string; const AArgs: array of const);
    procedure InsertMainRow(const ANumber: integer; const ACategory: string = 'elite';
      const AName: string = 'Rider');
    procedure OpenMainByNumber(const ANumber: integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SelectForSumCalculation_ReturnsOnlyRequestedStageResults;
    procedure UpdateStageResult_HandlesStatusesAndTimeCalculations;
    procedure UpdateSumResult_UpdatesValuesAndPreservesStatusConditionally;
    procedure ResetStagePlaceAndDiff_AndUpsertStagePlace_AssignsPlaces;
    procedure ResetStageDiffLeader_AndUpsertStageDiffLeader_SetsLeaderDiff;
    procedure ResetSumPlaceAndDiff_AndUpsertSumPlaceOnlyFullStages_AssignsSumPlace;
    procedure ResetSumDiffLeader_AndUpsertSumDiffLeader_SetsSumDiff;
    procedure UpsertSumDiffByStages_SetsStageGapText;
    procedure ResetThru_AndUpsertThruPlace_AssignsThruPlace;
    procedure UpsertThruDiff_AndUpsertThruDiffByStages_SetsThruDiff;
    procedure UpsertThruDiffByStages_UnfinishedRaceWithEqualStages_PreservesTimeDiff;
    procedure ClearResultsPrefixStageSuffix_ClearsResultsColumns;
  end;

  TCompetitionImportRepositoryTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    procedure CreateSchema;
    procedure ExecSql(const ASql: string);
    procedure ExecSqlFmt(const AFormat: string; const AArgs: array of const);
    procedure InsertMainRow(const ANumber: integer; const ACategory: string = 'elite';
      const AName: string = 'Rider');
    procedure OpenMainByNumber(const ANumber: integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ParticipantUpsert_ParametersPreserveSqlSensitiveCharacters;
    procedure BindParticipantRowParameters_MapsModelToQueryParams;
    procedure PreparedParticipantRows_ImportAndUpsertRows;
    procedure ApplyStageDefinitions_ReplacesActiveSetAndPreservesHiddenNames;
    procedure ApplyStageDefinitions_EmptyListPreservesConfiguration;
    procedure PreparedFullStageResultRows_ImportAndUpsertValues;
    procedure PreparedStartResultRows_PreserveNullsAndSelectedStage;
    procedure PreparedFinishResultRows_PreserveNullStatusAndSelectedStage;
  end;

  TSqlSafetyTests = class(TTestCase)
  published
    procedure RequireStageIndex_RejectsOutsideConfiguredRange;
    procedure DynamicSqlBuilders_RejectStageAboveConfiguredCount;
    procedure SqlIdentifierCsv_QuotesIdentifiersAndRejectsFragments;
  end;

implementation

procedure TDbSqlTests.SetUp;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FConnection.DatabaseName := ':memory:';
  FConnection.Transaction := FTransaction;
  FConnection.Open;

  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;
end;

procedure TDbSqlTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TDbSqlTests.AssertTableExists(const ATableName: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = :NAME;';
  FQuery.ParamByName('NAME').AsString := ATableName;
  FQuery.Open;
  AssertFalse(Format('Table "%s" was not created.', [ATableName]), FQuery.EOF);
  AssertEquals(ATableName, FQuery.Fields[0].AsString);
  FQuery.Close;
end;

procedure TDbSqlTests.AssertConfigValue(const AKey, AExpectedValue: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT value FROM config WHERE key = :KEY;';
  FQuery.ParamByName('KEY').AsString := AKey;
  FQuery.Open;
  AssertFalse(Format('Config key "%s" was not found.', [AKey]), FQuery.EOF);
  AssertEquals(AExpectedValue, FQuery.FieldByName('value').AsString);
  FQuery.Close;
end;

procedure TDbSqlTests.AssertColumnExists(const ATableName, AColumnName: string;
  const AExpected: boolean);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT 1 FROM pragma_table_info(:TABLE_NAME) WHERE name = :COLUMN_NAME;';
  FQuery.ParamByName('TABLE_NAME').AsString := ATableName;
  FQuery.ParamByName('COLUMN_NAME').AsString := AColumnName;
  FQuery.Open;
  if AExpected then
    AssertFalse(Format('Column "%s.%s" was not created.', [ATableName, AColumnName]), FQuery.EOF)
  else
    AssertTrue(Format('Column "%s.%s" should not exist.', [ATableName, AColumnName]), FQuery.EOF);
  FQuery.Close;
end;

procedure TDbSqlTests.AssertColumnType(const ATableName, AColumnName,
  AExpectedType: string);
begin
  FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT type FROM pragma_table_info(:TABLE_NAME) WHERE name = :COLUMN_NAME;';
  FQuery.ParamByName('TABLE_NAME').AsString := ATableName;
  FQuery.ParamByName('COLUMN_NAME').AsString := AColumnName;
  FQuery.Open;
  AssertFalse(Format('Column "%s.%s" was not found.',
    [ATableName, AColumnName]), FQuery.EOF);
  AssertEquals(AExpectedType, UpperCase(FQuery.FieldByName('type').AsString));
  FQuery.Close;
end;

procedure TDbSqlTests.ExecCreateTables_OutsideSourceTree_UsesEmbeddedSchema;
var
  OriginalDirectory: string;
  TemporaryDirectory: string;
begin
  OriginalDirectory := GetCurrentDir;
  TemporaryDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'entime-embedded-schema-' + IntToStr(GetTickCount64);
  ForceDirectories(TemporaryDirectory);
  try
    AssertTrue('Could not enter temporary directory.',
      SetCurrentDir(TemporaryDirectory));
    FTransaction.Active := True;
    TSchemaSql.ExecCreateTables(FConnection, DEFAULT_STAGE_COUNT,
      'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Embedded schema test');

    AssertTableExists('main');
    AssertTableExists('config');
    AssertTableExists('start_marks');
    AssertTableExists('finish_marks');
  finally
    SetCurrentDir(OriginalDirectory);
    RemoveDir(TemporaryDirectory);
  end;
end;

procedure TDbSqlTests.ExecCreateTables_InMemoryDatabase_CreatesSchemaAndDefaults;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, DEFAULT_STAGE_COUNT,
    'Cat "A"; DROP TABLE main; --', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');

  AssertTableExists('main');
  AssertTableExists('start');
  AssertTableExists('config');
  AssertTableExists('start_marks');
  AssertTableExists('finish_marks');

  FQuery.SQL.Text :=
    'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = ''sumdays'';';
  FQuery.Open;
  AssertTrue('Legacy sumdays table should not be created.', FQuery.EOF);
  FQuery.Close;

  AssertConfigValue('activestage', '1');
  AssertConfigValue('stagecount', IntToStr(DEFAULT_STAGE_COUNT));
  AssertConfigValue('schema_version',
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  AssertConfigValue('stage1', 'True');
  AssertConfigValue('catname1', 'Cat "A"; DROP TABLE main; --');
  AssertConfigValue('catname5', 'Cat E');
  AssertConfigValue('racename', 'Race One');

  AssertColumnExists('main', 'starttime1', True);
  AssertColumnExists('main', 'starttime2', False);
  AssertColumnExists('main', 'sumplace', True);
  AssertColumnExists('start_marks', 'match_delta_ms', True);
  AssertColumnExists('finish_marks', 'participant_number', True);
  AssertColumnExists('finish_marks', 'assignment_mode', True);
  AssertColumnExists('finish_marks', 'applied_at', True);
  AssertColumnType('start', 'starttime', 'VARCHAR');
  AssertColumnType('start', 'automaticstarttime', 'VARCHAR');
  AssertColumnType('start', 'automaticphonetime', 'VARCHAR');
  AssertColumnType('start', 'manualstarttime', 'VARCHAR');
  AssertColumnType('start', 'finishtime', 'VARCHAR');
  AssertColumnType('start_marks', 'event_time', 'VARCHAR');
  AssertColumnType('start_marks', 'source_kind', 'VARCHAR');
  AssertColumnType('start_marks', 'source_device_id', 'VARCHAR');
  AssertColumnType('start_marks', 'received_at', 'VARCHAR');
  AssertColumnType('start_marks', 'assignment_mode', 'VARCHAR');
  AssertColumnType('start_marks', 'status', 'VARCHAR');
  AssertColumnType('start_marks', 'applied_at', 'VARCHAR');
  AssertColumnType('start_marks', 'diagnostic', 'TEXT');
  AssertColumnType('finish_marks', 'event_time', 'VARCHAR');
  AssertColumnType('finish_marks', 'source_kind', 'VARCHAR');
  AssertColumnType('finish_marks', 'source_device_id', 'VARCHAR');
  AssertColumnType('finish_marks', 'received_at', 'VARCHAR');
  AssertColumnType('finish_marks', 'assignment_mode', 'VARCHAR');
  AssertColumnType('finish_marks', 'status', 'VARCHAR');
  AssertColumnType('finish_marks', 'applied_at', 'VARCHAR');
  AssertColumnType('finish_marks', 'diagnostic', 'TEXT');
end;

procedure TDbSqlTests.EnsureStartMarksTable_CreatesEmptyTableAndIndexes;
begin
  FTransaction.Active := True;

  TSchemaSql.EnsureStartMarksTable(FQuery);

  AssertTableExists('start_marks');
  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM start_marks;';
  FQuery.Open;
  AssertEquals(0, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT COUNT(*) AS cnt FROM sqlite_master ' +
    'WHERE type = ''index'' AND name IN ' +
    '(''idx_start_marks_status_received_at'', ' +
    '''idx_start_marks_stage_event_time'');';
  FQuery.Open;
  AssertEquals(2, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;
end;

procedure TDbSqlTests.EnsureStartMarksTable_IsIdempotent;
begin
  FTransaction.Active := True;
  TSchemaSql.EnsureStartMarksTable(FQuery);
  FQuery.SQL.Text :=
    'INSERT INTO start_marks ' +
    '(stage_index, event_time, source_kind, source_device_id, ' +
    'received_at, status) VALUES ' +
    '(2, ''10:00:00.000'', ''serial'', ''COM7'', ' +
    '''2026-08-13T10:00:01.000'', ''pending'');';
  FQuery.ExecSQL;

  TSchemaSql.EnsureStartMarksTable(FQuery);

  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM start_marks;';
  FQuery.Open;
  AssertEquals(1, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;
end;

procedure TDbSqlTests.EnsureFinishMarksTable_CreatesEmptyTableAndIndexes;
begin
  FTransaction.Active := True;

  TSchemaSql.EnsureFinishMarksTable(FQuery);

  AssertTableExists('finish_marks');
  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM finish_marks;';
  FQuery.Open;
  AssertEquals(0, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT COUNT(*) AS cnt FROM sqlite_master ' +
    'WHERE type = ''index'' AND name IN ' +
    '(''idx_finish_marks_status_received_at'', ' +
    '''idx_finish_marks_stage_event_time'');';
  FQuery.Open;
  AssertEquals(2, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;
end;

procedure TDbSqlTests.EnsureFinishMarksTable_IsIdempotent;
begin
  FTransaction.Active := True;
  TSchemaSql.EnsureFinishMarksTable(FQuery);
  FQuery.SQL.Text :=
    'INSERT INTO finish_marks ' +
    '(stage_index, event_time, source_kind, source_device_id, ' +
    'received_at, status) VALUES ' +
    '(2, ''10:00:00.000'', ''ble'', ''ENTime-7'', ' +
    '''2026-08-15T10:00:01.000'', ''pending'');';
  FQuery.ExecSQL;

  TSchemaSql.EnsureFinishMarksTable(FQuery);

  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM finish_marks;';
  FQuery.Open;
  AssertEquals(1, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;
end;

procedure TDbSqlTests.ExecCreateTables_CreatesVersionedSchemasAtSupportedBounds;
const
  STAGE_COUNTS: array[0..3] of integer = (
    MIN_STAGE_COUNT,
    8,
    12,
    MAX_SUPPORTED_STAGE_COUNT
  );
var
  StageCount: integer;
  Connection: TSQLite3Connection;
  Transaction: TSQLTransaction;
  Query: TSQLQuery;
begin
  for StageCount in STAGE_COUNTS do
  begin
    Connection := TSQLite3Connection.Create(nil);
    Transaction := TSQLTransaction.Create(nil);
    Query := TSQLQuery.Create(nil);
    try
      Connection.DatabaseName := ':memory:';
      Connection.Transaction := Transaction;
      Transaction.Database := Connection;
      Query.DataBase := Connection;
      Query.Transaction := Transaction;
      Connection.Open;
      Transaction.Active := True;

      TSchemaSql.ExecCreateTables(Connection, StageCount,
        'A', 'B', 'C', 'D', 'E', 'Versioned race');

      AssertEquals(StageCount, TSchemaSql.DetectStageCapacity(Query));
      AssertEquals(StageCount,
        TSchemaSql.LoadConfiguredStageCount(Query));
      AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION,
        TSchemaSql.LoadSchemaVersion(Query));
      AssertEquals('1', TConfigSql.GetString(Query, 'activestage', ''));
      AssertTrue(TConfigSql.GetBool(Query, 'stage1', False));

      Query.SQL.Text :=
        'SELECT COUNT(*) AS cnt FROM pragma_table_info(''main'') ' +
        'WHERE name IN (:START_COLUMN, :STATUS_COLUMN);';
      Query.ParamByName('START_COLUMN').AsString :=
        'starttime' + IntToStr(StageCount);
      Query.ParamByName('STATUS_COLUMN').AsString :=
        'status' + IntToStr(StageCount);
      Query.Open;
      AssertEquals(2, Query.FieldByName('cnt').AsInteger);
      Query.Close;
    finally
      Query.Free;
      Transaction.Free;
      Connection.Free;
    end;
  end;
end;

procedure TDbSqlTests.SchemaInspection_ReadsCapacityAndConfiguredValuesWithoutWrites;
var
  ConfigRowCountBefore: integer;
  ConfigRowCountAfter: integer;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 3,
    'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Race One');
  TConfigSql.ExecUpsertByKey(FQuery, 'schema_version', '5');

  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM config;';
  FQuery.Open;
  ConfigRowCountBefore := FQuery.FieldByName('cnt').AsInteger;
  FQuery.Close;

  AssertEquals(3, TSchemaSql.DetectStageCapacity(FQuery));
  AssertEquals(3, TSchemaSql.LoadConfiguredStageCount(FQuery));
  AssertEquals(5, TSchemaSql.LoadSchemaVersion(FQuery));

  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM config;';
  FQuery.Open;
  ConfigRowCountAfter := FQuery.FieldByName('cnt').AsInteger;
  FQuery.Close;
  AssertEquals('Schema inspection must not change config rows',
    ConfigRowCountBefore, ConfigRowCountAfter);
end;

procedure TDbSqlTests.SchemaInspection_MissingKeysReturnUnversionedDefaultsWithoutWrites;
var
  ConfigRowCountBefore: integer;
  ConfigRowCountAfter: integer;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8,
    'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Legacy race');
  FQuery.SQL.Text :=
    'DELETE FROM config WHERE key IN (''stagecount'', ''schema_version'');';
  FQuery.ExecSQL;

  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM config;';
  FQuery.Open;
  ConfigRowCountBefore := FQuery.FieldByName('cnt').AsInteger;
  FQuery.Close;

  AssertEquals(8, TSchemaSql.DetectStageCapacity(FQuery));
  AssertEquals(0, TSchemaSql.LoadConfiguredStageCount(FQuery));
  AssertEquals(0, TSchemaSql.LoadSchemaVersion(FQuery));

  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM config;';
  FQuery.Open;
  ConfigRowCountAfter := FQuery.FieldByName('cnt').AsInteger;
  FQuery.Close;
  AssertEquals('Inspection of an unversioned schema must remain read-only',
    ConfigRowCountBefore, ConfigRowCountAfter);
end;

procedure TDbSqlTests.SchemaInspection_RejectsInvalidConfiguredValues;
var
  StageCountRejected: boolean;
  VersionRejected: boolean;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 2,
    'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Race One');
  TConfigSql.ExecUpsertByKey(FQuery, 'stagecount', 'not-a-number');
  TConfigSql.ExecUpsertByKey(FQuery, 'schema_version', '-1');

  StageCountRejected := False;
  try
    TSchemaSql.LoadConfiguredStageCount(FQuery);
  except
    on E: ECompetitionSchemaError do
      StageCountRejected := True;
  end;
  VersionRejected := False;
  try
    TSchemaSql.LoadSchemaVersion(FQuery);
  except
    on E: ECompetitionSchemaError do
      VersionRejected := True;
  end;

  AssertTrue('Invalid non-empty stagecount must be rejected',
    StageCountRejected);
  AssertTrue('Negative schema_version must be rejected', VersionRejected);
end;

procedure TDbSqlTests.DetectStageCapacity_RejectsMalformedSchemas;

  function CompleteStageColumns(const StageIndex: integer): string;
  begin
    Result := Format(
      '"starttime%d" VARCHAR, "correction%d" INTEGER, ' +
      '"finishtime%d" VARCHAR, "penalty%d" VARCHAR, ' +
      '"result%d" VARCHAR, "diffleader%d" VARCHAR, ' +
      '"place%d" INTEGER, "status%d" VARCHAR',
      [StageIndex, StageIndex, StageIndex, StageIndex,
      StageIndex, StageIndex, StageIndex, StageIndex]);
  end;

  procedure RecreateMain(const ColumnsSql: string);
  begin
    FQuery.Close;
    FQuery.SQL.Text := 'DROP TABLE IF EXISTS main;';
    FQuery.ExecSQL;
    FQuery.SQL.Text := 'CREATE TABLE main (' + ColumnsSql + ');';
    FQuery.ExecSQL;
  end;

  procedure AssertDetectionRejected(const MessageText: string);
  var
    Rejected: boolean;
  begin
    Rejected := False;
    try
      TSchemaSql.DetectStageCapacity(FQuery);
    except
      on E: ECompetitionSchemaError do
        Rejected := True;
    end;
    AssertTrue(MessageText, Rejected);
  end;

begin
  FTransaction.Active := True;

  RecreateMain(
    '"starttime1" VARCHAR, "correction1" INTEGER, ' +
    '"finishtime1" VARCHAR, "penalty1" VARCHAR, ' +
    '"result1" VARCHAR, "diffleader1" VARCHAR, "place1" INTEGER');
  AssertDetectionRejected('Incomplete stage columns must be rejected');

  RecreateMain(CompleteStageColumns(1) + ', ' + CompleteStageColumns(3));
  AssertDetectionRejected('A gap in stage numbering must be rejected');

  RecreateMain(CompleteStageColumns(1) + ', "starttime' +
    IntToStr(MAX_SUPPORTED_STAGE_COUNT + 1) + '" VARCHAR');
  AssertDetectionRejected('A stage above the supported limit must be rejected');
end;

procedure TDbSqlTests.EnsureStageCapacity_AddsCompleteStagesAndPreservesData;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 2,
    'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Race One');
  FQuery.SQL.Text :=
    'INSERT INTO main (number, name) VALUES (101, ''Existing rider'');';
  FQuery.ExecSQL;

  TSchemaSql.EnsureStageCapacity(FQuery, 4);

  AssertEquals(4, TSchemaSql.DetectStageCapacity(FQuery));
  AssertColumnType('main', 'starttime3', 'VARCHAR');
  AssertColumnType('main', 'correction3', 'INTEGER');
  AssertColumnType('main', 'finishtime3', 'VARCHAR');
  AssertColumnType('main', 'penalty3', 'VARCHAR');
  AssertColumnType('main', 'result3', 'VARCHAR');
  AssertColumnType('main', 'diffleader3', 'VARCHAR');
  AssertColumnType('main', 'place3', 'INTEGER');
  AssertColumnType('main', 'status3', 'VARCHAR');
  AssertColumnExists('main', 'status4', True);

  FQuery.SQL.Text := 'SELECT name FROM main WHERE number = 101;';
  FQuery.Open;
  AssertFalse('Existing participant must survive schema expansion', FQuery.EOF);
  AssertEquals('Existing rider', FQuery.FieldByName('name').AsString);
  FQuery.Close;
  AssertConfigValue('stagecount', '2');

  TSchemaSql.EnsureStageCapacity(FQuery, 4);
  TSchemaSql.EnsureStageCapacity(FQuery, 3);
  AssertEquals(4, TSchemaSql.DetectStageCapacity(FQuery));

  FQuery.SQL.Text :=
    'SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type = ''table'' ' +
    'AND name IN (''load'', ''loadresult'');';
  FQuery.Open;
  AssertEquals(0, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;
end;

procedure TDbSqlTests.EnsureStageCapacity_ExpandsEightToTwelveAndPreservesData;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8,
    'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Race One');
  FQuery.SQL.Text :=
    'INSERT INTO main (number, name, starttime1, result8) VALUES ' +
    '(812, ''Existing rider'', ''09:00:00.000'', ''00:08:12.000'');';
  FQuery.ExecSQL;

  TSchemaSql.EnsureStageCapacity(FQuery, 12);

  AssertEquals(12, TSchemaSql.DetectStageCapacity(FQuery));
  AssertColumnExists('main', 'starttime12', True);
  AssertColumnExists('main', 'status12', True);
  FQuery.SQL.Text :=
    'SELECT name, starttime1, result8 FROM main WHERE number = 812;';
  FQuery.Open;
  AssertFalse(FQuery.EOF);
  AssertEquals('Existing rider', FQuery.FieldByName('name').AsString);
  AssertEquals('09:00:00.000', FQuery.FieldByName('starttime1').AsString);
  AssertEquals('00:08:12.000', FQuery.FieldByName('result8').AsString);
  FQuery.Close;
end;

procedure TDbSqlTests.EnsureStageCapacity_SecondRunIsIdempotent;
var
  ColumnCountAfterFirstRun: integer;
  ColumnCountAfterSecondRun: integer;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8,
    'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Race One');

  TSchemaSql.EnsureStageCapacity(FQuery, 12);
  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM pragma_table_info(''main'');';
  FQuery.Open;
  ColumnCountAfterFirstRun := FQuery.FieldByName('cnt').AsInteger;
  FQuery.Close;

  TSchemaSql.EnsureStageCapacity(FQuery, 12);
  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM pragma_table_info(''main'');';
  FQuery.Open;
  ColumnCountAfterSecondRun := FQuery.FieldByName('cnt').AsInteger;
  FQuery.Close;

  AssertEquals(12, TSchemaSql.DetectStageCapacity(FQuery));
  AssertEquals(ColumnCountAfterFirstRun, ColumnCountAfterSecondRun);
end;

procedure TDbSqlTests.ConfiguredStageCount_SoftReductionPreservesHigherStageData;
var
  StageIndex: integer;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 12,
    'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Race One');
  FQuery.SQL.Text :=
    'INSERT INTO main (number, result6, result7, result8, result9, ' +
    'result10, result11, result12) VALUES ' +
    '(125, ''R6'', ''R7'', ''R8'', ''R9'', ''R10'', ''R11'', ''R12'');';
  FQuery.ExecSQL;

  TConfigSql.ExecUpsertByKey(FQuery, 'stagecount', '5');
  TSchemaSql.EnsureStageCapacity(FQuery, 5);
  AssertEquals(12, TSchemaSql.DetectStageCapacity(FQuery));
  AssertEquals(5, TSchemaSql.LoadConfiguredStageCount(FQuery));

  TConfigSql.ExecUpsertByKey(FQuery, 'stagecount', '12');
  TSchemaSql.EnsureStageCapacity(FQuery, 12);
  AssertEquals(12, TSchemaSql.LoadConfiguredStageCount(FQuery));
  FQuery.SQL.Text := 'SELECT * FROM main WHERE number = 125;';
  FQuery.Open;
  AssertFalse(FQuery.EOF);
  for StageIndex := 6 to 12 do
    AssertEquals('R' + IntToStr(StageIndex),
      FQuery.FieldByName('result' + IntToStr(StageIndex)).AsString);
  FQuery.Close;
end;

procedure TDbSqlTests.AddStageColumns_CompletesPartialStageAndIsIdempotent;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 2,
    'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Race One');
  FQuery.SQL.Text :=
    'ALTER TABLE "main" ADD COLUMN "starttime3" VARCHAR;';
  FQuery.ExecSQL;

  TSchemaSql.AddStageColumns(FQuery, 3);
  TSchemaSql.AddStageColumns(FQuery, 3);

  AssertEquals(3, TSchemaSql.DetectStageCapacity(FQuery));
  AssertColumnExists('main', 'starttime3', True);
  AssertColumnExists('main', 'correction3', True);
  AssertColumnExists('main', 'finishtime3', True);
  AssertColumnExists('main', 'penalty3', True);
  AssertColumnExists('main', 'result3', True);
  AssertColumnExists('main', 'diffleader3', True);
  AssertColumnExists('main', 'place3', True);
  AssertColumnExists('main', 'status3', True);
end;

procedure TDbSqlTests.EnsureStageCapacity_AllChangesCanBeRolledBackTogether;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 2,
    'Cat A', 'Cat B', 'Cat C', 'Cat D', 'Cat E', 'Race One');
  FTransaction.Commit;

  FTransaction.Active := True;
  TSchemaSql.EnsureStageCapacity(FQuery, 4);
  AssertEquals(4, TSchemaSql.DetectStageCapacity(FQuery));
  FTransaction.Rollback;

  FTransaction.Active := True;
  AssertEquals(2, TSchemaSql.DetectStageCapacity(FQuery));
  AssertColumnExists('main', 'starttime3', False);
  AssertColumnExists('main', 'status4', False);
end;

procedure TDbSqlTests.PublicFacade_DelegatesToSplitRepositories;
begin
  AssertEquals(TParticipantRepository.SelectNumbers, TMainSql.SelectNumbers);
  AssertEquals(TStageResultRepository.ResetStartTime(2),
    TMainSql.ResetStartTime(2));
  AssertEquals(TResultCalculationRepository.ResetSumPlaceAndDiff,
    TResultsSql.ResetSumPlaceAndDiff);
  AssertEquals(TCompetitionImportRepository.UpsertParticipantRowStatement(2),
    TImportSql.UpsertParticipantRowStatement(2));
end;

procedure TConfigSqlTests.UpsertConfig(const AKey, AValue: string);
begin
  TConfigSql.ExecUpsertByKey(FQuery, AKey, AValue);
end;

procedure TConfigSqlTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 2, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
end;

procedure TConfigSqlTests.SetUp;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FConnection.DatabaseName := ':memory:';
  FConnection.Transaction := FTransaction;
  FConnection.Open;

  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;

  CreateSchema;
end;

procedure TConfigSqlTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TConfigSqlTests.ExecUpsertByKey_InsertsNewKey;
begin
  UpsertConfig('test_key_insert', 'value_1');

  AssertEquals('value_1',
    TConfigSql.GetString(FQuery, 'test_key_insert', 'default'));
end;

procedure TConfigSqlTests.ExecUpsertByKey_UpdatesExistingKey;
begin
  UpsertConfig('test_key_update', 'value_1');
  UpsertConfig('test_key_update', 'value_2');

  AssertEquals('value_2',
    TConfigSql.GetString(FQuery, 'test_key_update', 'default'));
end;

procedure TConfigSqlTests.UpsertByKey_ReturnsExecutableSqlForInsertAndUpdate;
begin
  FQuery.Close;
  FQuery.SQL.Text := TConfigSql.UpsertByKey;
  FQuery.ParamByName('KEY').AsString := 'upsert_sql_key';
  FQuery.ParamByName('VALUE').AsString := 'value_1';
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;

  AssertEquals('value_1',
    TConfigSql.GetString(FQuery, 'upsert_sql_key', 'default'));

  FQuery.Close;
  FQuery.SQL.Text := TConfigSql.UpsertByKey;
  FQuery.ParamByName('KEY').AsString := 'upsert_sql_key';
  FQuery.ParamByName('VALUE').AsString := 'value_2';
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;

  AssertEquals('value_2',
    TConfigSql.GetString(FQuery, 'upsert_sql_key', 'default'));
end;

procedure TConfigSqlTests.GetString_ReturnsStoredValue;
begin
  UpsertConfig('race_name_test', 'My Race');

  AssertEquals('My Race',
    TConfigSql.GetString(FQuery, 'race_name_test', 'default'));
end;

procedure TConfigSqlTests.LoadAll_ReturnsTypedSnapshot;
var
  Values: TStringList;
begin
  UpsertConfig('snapshot_text', 'left=right');
  UpsertConfig('snapshot_true', 'True');
  UpsertConfig('snapshot_empty', '');

  Values := TStringList.Create;
  try
    TConfigSql.LoadAll(FQuery, Values);

    AssertFalse('The snapshot query must be closed after loading',
      FQuery.Active);
    AssertEquals('left=right', TConfigSql.StringValue(
      Values, 'snapshot_text', 'default'));
    AssertEquals('default', TConfigSql.StringValue(
      Values, 'snapshot_empty', 'default'));
    AssertEquals('default', TConfigSql.StringValue(
      Values, 'snapshot_missing', 'default'));
    AssertTrue(TConfigSql.BoolValue(Values, 'snapshot_true', False));
    AssertFalse(TConfigSql.BoolValue(Values, 'snapshot_missing', False));
  finally
    Values.Free;
  end;
end;

procedure TConfigSqlTests.GetString_ReturnsDefault_WhenKeyMissing;
begin
  AssertEquals('default',
    TConfigSql.GetString(FQuery, 'missing_key_test', 'default'));
end;

procedure TConfigSqlTests.GetString_ReturnsDefault_WhenValueEmpty;
begin
  UpsertConfig('empty_value_test', '');

  AssertEquals('default',
    TConfigSql.GetString(FQuery, 'empty_value_test', 'default'));
end;

procedure TConfigSqlTests.GetInteger_ReturnsStoredValue;
begin
  UpsertConfig('stagecount_test', '12');

  AssertEquals(12, TConfigSql.GetInteger(FQuery, 'stagecount_test', 8));
end;

procedure TConfigSqlTests.GetInteger_UsesDefault_ForMissingInvalidOrEmptyValue;
begin
  AssertEquals(8, TConfigSql.GetInteger(FQuery, 'missing_stagecount_test', 8));

  UpsertConfig('stagecount_test', 'not-a-number');
  AssertEquals(8, TConfigSql.GetInteger(FQuery, 'stagecount_test', 8));

  UpsertConfig('stagecount_test', '');
  AssertEquals(8, TConfigSql.GetInteger(FQuery, 'stagecount_test', 8));
end;

procedure TConfigSqlTests.GetBool_ParsesTrueValues;
const
  TrueValues: array[0..3] of string = ('1', 'true', 'TRUE', '  true  ');
var
  ValueText: string;
begin
  for ValueText in TrueValues do
  begin
    UpsertConfig('flag_true_test', ValueText);
    AssertTrue(
      'Expected True for value "' + ValueText + '"',
      TConfigSql.GetBool(FQuery, 'flag_true_test', False));
  end;
end;

procedure TConfigSqlTests.GetBool_ParsesFalseValues;
const
  FalseValues: array[0..3] of string = ('0', 'false', 'FALSE', ' 0 ');
var
  ValueText: string;
begin
  for ValueText in FalseValues do
  begin
    UpsertConfig('flag_false_test', ValueText);
    AssertFalse(
      'Expected False for value "' + ValueText + '"',
      TConfigSql.GetBool(FQuery, 'flag_false_test', True));
  end;
end;

procedure TConfigSqlTests.GetBool_UsesDefault_ForInvalidOrEmpty;
begin
  UpsertConfig('flag_invalid_test', 'abc');
  AssertTrue(TConfigSql.GetBool(FQuery, 'flag_invalid_test', True));
  AssertFalse(TConfigSql.GetBool(FQuery, 'flag_invalid_test', False));

  UpsertConfig('flag_invalid_test', '');
  AssertTrue(TConfigSql.GetBool(FQuery, 'flag_invalid_test', True));
  AssertFalse(TConfigSql.GetBool(FQuery, 'flag_invalid_test', False));
end;

procedure TConfigSqlTests.GetBool_UsesDefault_WhenKeyMissing;
begin
  AssertTrue(TConfigSql.GetBool(FQuery, 'missing_flag_test', True));
  AssertFalse(TConfigSql.GetBool(FQuery, 'missing_flag_test', False));
end;

procedure TParticipantAndStageResultRepositoryTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TParticipantAndStageResultRepositoryTests.ExecSqlFmt(const AFormat: string;
  const AArgs: array of const);
begin
  ExecSql(Format(AFormat, AArgs));
end;

procedure TParticipantAndStageResultRepositoryTests.InsertMainRow(const ANumber: integer;
  const ACategory: string; const AName: string);
begin
  ExecSqlFmt(
    'INSERT INTO main (category, number, name) VALUES (%s, %d, %s);',
    [QuotedStr(ACategory), ANumber, QuotedStr(AName)]);
end;

procedure TParticipantAndStageResultRepositoryTests.OpenMainByNumber(const ANumber: integer);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT * FROM main WHERE number = :NUMBER;';
  FQuery.ParamByName('NUMBER').AsInteger := ANumber;
  FQuery.Open;
  AssertFalse(Format('Row with number %d was not found.', [ANumber]), FQuery.EOF);
end;

procedure TParticipantAndStageResultRepositoryTests.AssertFieldEquals(const AFieldName, AExpected: string);
begin
  AssertEquals(AExpected, FQuery.FieldByName(AFieldName).AsString);
end;

procedure TParticipantAndStageResultRepositoryTests.AssertFieldEqualsInt(const AFieldName: string;
  const AExpected: integer);
begin
  AssertEquals(AExpected, FQuery.FieldByName(AFieldName).AsInteger);
end;

procedure TParticipantAndStageResultRepositoryTests.AssertFieldNull(const AFieldName: string);
begin
  AssertTrue(
    Format('Field "%s" must be NULL.', [AFieldName]),
    FQuery.FieldByName(AFieldName).IsNull);
end;

procedure TParticipantAndStageResultRepositoryTests.SetUp;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FConnection.DatabaseName := ':memory:';
  FConnection.Transaction := FTransaction;
  FConnection.Open;

  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;

  CreateSchema;
end;

procedure TParticipantAndStageResultRepositoryTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TParticipantAndStageResultRepositoryTests.OpenByNumber_ReturnsTrueForExistingAndFalseForMissing;
begin
  InsertMainRow(101);

  AssertTrue(TParticipantRepository.OpenByNumber(FQuery, 101));
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  AssertFalse(TParticipantRepository.OpenByNumber(FQuery, 999));
end;

procedure TParticipantAndStageResultRepositoryTests.OpenByCategoryLeader_ReturnsLeaderAndReturnsFalseWhenMissing;
begin
  InsertMainRow(101, 'elite', 'Leader');
  InsertMainRow(102, 'elite', 'Rider');
  ExecSql('UPDATE main SET place1 = 1 WHERE number = 101;');
  ExecSql('UPDATE main SET place1 = 2 WHERE number = 102;');

  AssertTrue(TStageResultRepository.OpenByCategoryLeader(FQuery, 1, 'elite'));
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  AssertFalse(TStageResultRepository.OpenByCategoryLeader(FQuery, 1, 'missing'));
end;

procedure TParticipantAndStageResultRepositoryTests.TryGetNumberByStartTimeBetween_ReturnsMatchAndNoMatch;
var
  Number: integer;
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET starttime1 = ''10:00:00.000'' WHERE number = 101;');

  AssertTrue(
    TStageResultRepository.TryGetNumberByStartTimeBetween(FQuery, 1,
    '09:59:59.000', '10:00:01.000', Number));
  AssertEquals(101, Number);

  AssertFalse(
    TStageResultRepository.TryGetNumberByStartTimeBetween(FQuery, 1,
    '10:05:00.000', '10:06:00.000', Number));
  AssertEquals(0, Number);
end;

procedure TParticipantAndStageResultRepositoryTests.GetFinishCount_CountsOnlyNonEmptyFinishTimes;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  ExecSql('UPDATE main SET finishtime1 = ''10:03:12.123'' WHERE number = 101;');
  ExecSql('UPDATE main SET finishtime1 = '''' WHERE number = 102;');
  ExecSql('UPDATE main SET finishtime1 = NULL WHERE number = 103;');

  AssertEquals(1, TStageResultRepository.GetFinishCount(FQuery, 1));
end;

procedure TParticipantAndStageResultRepositoryTests.GetPenaltyGroupsCount_CountsDistinctPenaltyCombinations;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  ExecSql('UPDATE main SET penalty1 = ''10'', penalty2 = ''0'' WHERE number IN (101, 102);');
  ExecSql('UPDATE main SET penalty1 = ''20'', penalty2 = ''0'' WHERE number = 103;');

  AssertEquals(2, TStageResultRepository.GetPenaltyGroupsCount(FQuery, 2));
end;

procedure TParticipantAndStageResultRepositoryTests.LoadCategories_ReturnsSortedDistinctNonEmptyValues;
var
  categories: TStringList;
begin
  InsertMainRow(101, 'Open');
  InsertMainRow(102, 'Masters');
  InsertMainRow(103, 'Open');
  InsertMainRow(104, '');
  ExecSql('INSERT INTO main (number, category) VALUES (105, NULL);');

  categories := TStringList.Create;
  try
    categories.Add('stale value');
    TParticipantRepository.LoadCategories(FQuery, categories);

    AssertEquals(2, categories.Count);
    AssertEquals('Masters', categories[0]);
    AssertEquals('Open', categories[1]);
    AssertFalse('Category query must be closed after loading', FQuery.Active);
  finally
    categories.Free;
  end;
end;

procedure TParticipantAndStageResultRepositoryTests.ExecUpdateStartTimeForNumber_SetsStartAndClearsStageStatus;
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET status1 = ''1'' WHERE number = 101;');

  TStageResultRepository.ExecUpdateStartTimeForNumber(FQuery, 1, '10:00:00.000', 101);

  OpenMainByNumber(101);
  AssertFieldEquals('starttime1', '10:00:00.000');
  AssertFieldNull('status1');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecUpdateCorrection_SetsCorrectionValue;
begin
  InsertMainRow(101);

  TStageResultRepository.ExecUpdateCorrection(FQuery, 1, -456, 101);

  OpenMainByNumber(101);
  AssertFieldEqualsInt('correction1', -456);
end;

procedure TParticipantAndStageResultRepositoryTests.ExecUpdateCorrection_DoesNotCommitTransaction;
begin
  InsertMainRow(101);

  TStageResultRepository.ExecUpdateCorrection(FQuery, 1, 42, 101);

  AssertTrue('SQL command helpers must leave the transaction to the caller',
    FTransaction.Active);
  FTransaction.Rollback;
  OpenMainByNumber(101);
  AssertFieldNull('correction1');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecUpdateFinishForCheckedStages_UpdatesSpecifiedStages;
const
  Stages: array[0..1] of integer = (1, 2);
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET status1 = ''1'', status2 = ''1'' WHERE number = 101;');

  TStageResultRepository.ExecUpdateFinishForCheckedStages(FQuery, Stages, '11:11:11.111', 101);

  OpenMainByNumber(101);
  AssertFieldEquals('finishtime1', '11:11:11.111');
  AssertFieldEquals('finishtime2', '11:11:11.111');
  AssertFieldNull('status1');
  AssertFieldNull('status2');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecUpdateFinishForCheckedStages_EmptyStages_NoChanges;
var
  EmptyStages: array of integer;
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET finishtime1 = ''x'' WHERE number = 101;');
  SetLength(EmptyStages, 0);

  TStageResultRepository.ExecUpdateFinishForCheckedStages(FQuery, EmptyStages, '11:11:11.111', 101);

  OpenMainByNumber(101);
  AssertFieldEquals('finishtime1', 'x');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecUpdateStageStatus_SetsStageResultAndClearsPlaceDiff;
begin
  InsertMainRow(101);
  ExecSql(
    'UPDATE main SET place1 = 5, diffleader1 = ''00:00:10.000'' WHERE number = 101;');

  TStageResultRepository.ExecUpdateStageStatus(FQuery, 1, psDNF, '101');

  OpenMainByNumber(101);
  AssertFieldEquals('result1', 'DNF');
  AssertFieldEquals('status1', '2');
  AssertFieldNull('place1');
  AssertFieldNull('diffleader1');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecUpdateOnlyGlobalStatusDsq_SetsStatusTo3;
begin
  InsertMainRow(101);

  TParticipantRepository.ExecUpdateOnlyGlobalStatusDsq(FQuery, '101');

  OpenMainByNumber(101);
  AssertFieldEquals('status', '3');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecUpdateGlobalStatus_SetsTypedValueAndClearsNone;
begin
  InsertMainRow(101);

  TParticipantRepository.ExecUpdateGlobalStatus(FQuery, psDNS, '101');
  OpenMainByNumber(101);
  AssertFieldEquals('status', '1');

  TParticipantRepository.ExecUpdateGlobalStatus(FQuery, psNone, '101');
  OpenMainByNumber(101);
  AssertFieldNull('status');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecClearOnlyGlobalStatus_ClearsGlobalStatus;
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET status = ''2'' WHERE number = 101;');

  TParticipantRepository.ExecClearOnlyGlobalStatus(FQuery, '101');

  OpenMainByNumber(101);
  AssertFieldNull('status');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecClearStageStatus_ClearsOnlyStageFields;
begin
  InsertMainRow(101);
  ExecSql(
    'UPDATE main SET result1 = ''DNF'', place1 = 5, diffleader1 = ''00:00:10.000'', ' +
    'status1 = ''2'', status = ''2'' WHERE number = 101;');

  TStageResultRepository.ExecClearStageStatus(FQuery, 1, '101');

  OpenMainByNumber(101);
  AssertFieldNull('result1');
  AssertFieldNull('place1');
  AssertFieldNull('diffleader1');
  AssertFieldNull('status1');
  AssertFieldEquals('status', '2');
end;

procedure TParticipantAndStageResultRepositoryTests.ExecClearStatusAllForStage_ClearsStageAndGlobalStatus;
begin
  InsertMainRow(101);
  ExecSql(
    'UPDATE main SET result1 = ''DNF'', place1 = 5, diffleader1 = ''00:00:10.000'', ' +
    'status1 = ''2'', status = ''2'' WHERE number = 101;');

  TStageResultRepository.ExecClearStatusAllForStage(FQuery, 1, '101');

  OpenMainByNumber(101);
  AssertFieldNull('result1');
  AssertFieldNull('place1');
  AssertFieldNull('diffleader1');
  AssertFieldNull('status1');
  AssertFieldNull('status');
end;

procedure TParticipantAndStageResultRepositoryTests.SelectAll_ReturnsInsertedRows;
var
  Seen101: boolean;
  Seen102: boolean;
begin
  InsertMainRow(101);
  InsertMainRow(102);

  Seen101 := False;
  Seen102 := False;
  FQuery.Close;
  FQuery.SQL.Text := TParticipantRepository.SelectAll;
  FQuery.Open;
  while not FQuery.EOF do
  begin
    if FQuery.FieldByName('number').AsInteger = 101 then
      Seen101 := True;
    if FQuery.FieldByName('number').AsInteger = 102 then
      Seen102 := True;
    FQuery.Next;
  end;
  FQuery.Close;

  AssertTrue(Seen101);
  AssertTrue(Seen102);
end;

procedure TParticipantAndStageResultRepositoryTests.SelectNumbers_ReturnsOnlyParticipantNumbers;
var
  rowCount: integer;
  seen101, seen102: boolean;
begin
  InsertMainRow(102);
  InsertMainRow(101);
  ExecSql('INSERT INTO main (name) VALUES (''Without number'');');

  rowCount := 0;
  seen101 := False;
  seen102 := False;
  FQuery.Close;
  FQuery.SQL.Text := TParticipantRepository.SelectNumbers;
  FQuery.Open;

  AssertEquals(1, FQuery.FieldCount);
  AssertEquals('number', LowerCase(FQuery.Fields[0].FieldName));
  while not FQuery.EOF do
  begin
    Inc(rowCount);
    if FQuery.Fields[0].AsInteger = 101 then
      seen101 := True;
    if FQuery.Fields[0].AsInteger = 102 then
      seen102 := True;
    FQuery.Next;
  end;
  FQuery.Close;

  AssertEquals(2, rowCount);
  AssertTrue(seen101);
  AssertTrue(seen102);
end;

procedure TParticipantAndStageResultRepositoryTests.ResetStartTime_ClearsStageStartTimeForAllRows;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  ExecSql('UPDATE main SET starttime1 = ''10:00:00.000'' WHERE number = 101;');
  ExecSql('UPDATE main SET starttime1 = ''10:05:00.000'' WHERE number = 102;');

  TStageResultRepository.ExecResetStartTime(FQuery, 1);
  FTransaction.Commit;

  OpenMainByNumber(101);
  AssertFieldNull('starttime1');
  OpenMainByNumber(102);
  AssertFieldNull('starttime1');
end;

procedure TParticipantAndStageResultRepositoryTests.UpdateStartTime_SetsStageStartTimeForSpecificNumber;
begin
  InsertMainRow(101);
  InsertMainRow(102);

  TStageResultRepository.ExecUpdateStartTime(FQuery, 1, '11:11:11.111', 102);
  FTransaction.Commit;

  OpenMainByNumber(101);
  AssertFieldNull('starttime1');
  OpenMainByNumber(102);
  AssertFieldEquals('starttime1', '11:11:11.111');
end;

procedure TParticipantAndStageResultRepositoryTests.SelectMinStartTime_ReturnsEarliestNonNullStartTime;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  ExecSql('UPDATE main SET starttime1 = ''10:10:10.100'' WHERE number = 101;');
  ExecSql('UPDATE main SET starttime1 = ''09:09:09.090'' WHERE number = 102;');
  ExecSql('UPDATE main SET starttime1 = NULL WHERE number = 103;');

  AssertEquals('09:09:09.090',
    TStageResultRepository.GetMinStartTime(FQuery, 1));
end;

procedure TParticipantAndStageResultRepositoryTests.SelectMaxNumber_ReturnsMaximumNumber;
begin
  InsertMainRow(17);
  InsertMainRow(99);
  InsertMainRow(42);

  AssertEquals(99, TParticipantRepository.GetMaxNumber(FQuery));
end;

procedure TParticipantAndStageResultRepositoryTests.IsParticipantOnTrack_ReturnsCurrentStageState;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  ExecSql('UPDATE main SET starttime1 = ''00:00:01.000'' WHERE number = 101;');
  ExecSql('UPDATE main SET starttime1 = ''00:00:01.000'', ' +
    'finishtime1 = ''00:10:00.000'' WHERE number = 102;');

  AssertTrue(TStageResultRepository.IsParticipantOnTrack(FQuery, 1, 101));
  AssertFalse(TStageResultRepository.IsParticipantOnTrack(FQuery, 1, 102));
  AssertFalse(TStageResultRepository.IsParticipantOnTrack(FQuery, 1, 999));
end;

procedure TParticipantAndStageResultRepositoryTests.SelectCategoryGrouped_ReturnsDistinctCategories;
var
  Count: integer;
begin
  InsertMainRow(101, 'elite');
  InsertMainRow(102, 'elite');
  InsertMainRow(103, 'sport');

  Count := 0;
  FQuery.Close;
  FQuery.SQL.Text := TParticipantRepository.SelectCategoryGrouped;
  FQuery.Open;
  while not FQuery.EOF do
  begin
    Inc(Count);
    FQuery.Next;
  end;
  FQuery.Close;

  AssertEquals(2, Count);
end;

procedure TParticipantAndStageResultRepositoryTests.SelectCategoryGroupedOrderedByStartTime_OrdersByStageStartTime;
begin
  InsertMainRow(101, 'elite');
  InsertMainRow(201, 'sport');
  ExecSql('UPDATE main SET starttime1 = ''10:00:00.000'' WHERE number = 101;');
  ExecSql('UPDATE main SET starttime1 = ''09:00:00.000'' WHERE number = 201;');

  FQuery.Close;
  FQuery.SQL.Text := TStageResultRepository.SelectCategoryGroupedOrderedByStartTime(1);
  FQuery.Open;
  AssertEquals('sport', FQuery.FieldByName('category').AsString);
  FQuery.Next;
  AssertEquals('elite', FQuery.FieldByName('category').AsString);
  FQuery.Close;
end;

procedure TParticipantAndStageResultRepositoryTests.SelectCategoryResults_FiltersByCategoryAndSorts;
begin
  InsertMainRow(101, 'elite');
  InsertMainRow(102, 'elite');
  InsertMainRow(103, 'elite');
  InsertMainRow(201, 'sport');
  ExecSql(
    'UPDATE main SET sumplace = 2, sumresult = ''00:20:00.000'' WHERE number = 101;');
  ExecSql(
    'UPDATE main SET sumplace = 1, sumresult = ''00:10:00.000'' WHERE number = 102;');
  ExecSql(
    'UPDATE main SET sumplace = NULL, sumresult = NULL WHERE number = 103;');
  ExecSql(
    'UPDATE main SET sumplace = 1, sumresult = ''00:05:00.000'' WHERE number = 201;');

  FQuery.Close;
  FQuery.SQL.Text := TParticipantRepository.SelectCategoryResults('number, sumplace, sumresult');
  FQuery.ParamByName('CATEGORY').AsString := 'elite';
  FQuery.Open;
  AssertEquals(102, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(103, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertTrue(FQuery.EOF);
  FQuery.Close;
end;

procedure TParticipantAndStageResultRepositoryTests.SelectCategoryResults_RejectsSqlFragments;
var
  Rejected: boolean;
begin
  Rejected := False;
  try
    TParticipantRepository.SelectCategoryResults(
      'number, (SELECT value FROM config)');
  except
    on E: ESqlIdentifierError do
      Rejected := True;
  end;
  AssertTrue('Raw SQL fragments must not be accepted as export columns.',
    Rejected);
end;

procedure TParticipantAndStageResultRepositoryTests.StageWriteError_IncludesOperationParticipantAndStageOnly;
var
  ErrorText: string;
begin
  ErrorText := '';
  ExecSql('DROP TABLE main;');
  try
    TStageResultRepository.ExecUpdateCorrection(FQuery, 2, 777, 123, 2);
  except
    on E: EDatabaseError do
      ErrorText := E.Message;
  end;
  AssertTrue(Pos('update correction', ErrorText) > 0);
  AssertTrue(Pos('participant number 123', ErrorText) > 0);
  AssertTrue(Pos('stage 2', ErrorText) > 0);
  AssertEquals('The correction value must not leak into the error.', 0,
    Pos('777', ErrorText));
end;

procedure TParticipantAndStageResultRepositoryTests.SelectStatusAll_ReturnsOnlyRowsWithGlobalStatus;
var
  Count: integer;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  ExecSql('UPDATE main SET status = ''1'' WHERE number = 101;');
  ExecSql('UPDATE main SET status = NULL WHERE number = 102;');
  ExecSql('UPDATE main SET status = ''3'' WHERE number = 103;');

  Count := 0;
  FQuery.Close;
  FQuery.SQL.Text := TParticipantRepository.SelectStatusAll;
  FQuery.Open;
  AssertEquals('Status-number lookup must not load the wide participant row',
    1, FQuery.Fields.Count);
  AssertEquals('number', FQuery.Fields[0].FieldName);
  while not FQuery.EOF do
  begin
    Inc(Count);
    FQuery.Next;
  end;
  FQuery.Close;

  AssertEquals(2, Count);
end;

procedure TParticipantAndStageResultRepositoryTests.SelectStatusByStage_ReturnsOnlyRowsWithStageStatus;
var
  Count: integer;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  ExecSql('UPDATE main SET status1 = ''1'' WHERE number = 101;');
  ExecSql('UPDATE main SET status1 = NULL WHERE number = 102;');
  ExecSql('UPDATE main SET status1 = ''2'' WHERE number = 103;');

  Count := 0;
  FQuery.Close;
  FQuery.SQL.Text := TStageResultRepository.SelectStatusByStage(1);
  FQuery.Open;
  AssertEquals('Stage-status lookup must not load the wide participant row',
    1, FQuery.Fields.Count);
  AssertEquals('number', FQuery.Fields[0].FieldName);
  while not FQuery.EOF do
  begin
    Inc(Count);
    FQuery.Next;
  end;
  FQuery.Close;

  AssertEquals(2, Count);
end;

procedure TParticipantAndStageResultRepositoryTests.ExportFinishTime_ReturnsRequestedStageColumns;
begin
  InsertMainRow(101);
  ExecSql(
    'UPDATE main SET starttime2 = ''10:00:00.000'', correction2 = -5, ' +
    'finishtime2 = ''10:05:00.000'', penalty2 = ''00:00:10.000'', status2 = ''1'' ' +
    'WHERE number = 101;');

  FQuery.Close;
  FQuery.SQL.Text := TStageResultRepository.ExportFinishTime(2);
  FQuery.Open;
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  AssertEquals('10:00:00.000', FQuery.FieldByName('starttime2').AsString);
  AssertEquals(-5, FQuery.FieldByName('correction2').AsInteger);
  AssertEquals('10:05:00.000', FQuery.FieldByName('finishtime2').AsString);
  AssertEquals('00:00:10.000', FQuery.FieldByName('penalty2').AsString);
  AssertEquals('1', FQuery.FieldByName('status2').AsString);
  FQuery.Close;
end;

procedure TParticipantAndStageResultRepositoryTests.TryLoadParticipantStageData_MapsFieldsToTypedModel;
var
  StageData: TParticipantStageData;
begin
  InsertMainRow(108);
  ExecSql(
    'UPDATE main SET starttime2 = ''10:00:00.000'', correction2 = -125, ' +
    'finishtime2 = ''10:09:00.000'', penalty2 = ''00:00:05.000'', ' +
    'result2 = ''00:09:05.000'', diffleader2 = ''00:00:03.000'', ' +
    'place2 = 4, status2 = ''2'' WHERE number = 108;');

  AssertTrue(TStageResultRepository.TryLoadParticipantStageData(
    FQuery, 108, 2, 8, StageData));
  AssertEquals(2, StageData.StageIndex);
  AssertEquals('10:00:00.000', StageData.StartTime);
  AssertTrue(StageData.HasCorrection);
  AssertEquals(-125, StageData.Correction);
  AssertEquals('10:09:00.000', StageData.FinishTime);
  AssertEquals('00:00:05.000', StageData.Penalty);
  AssertEquals('00:09:05.000', StageData.ResultValue);
  AssertEquals('00:00:03.000', StageData.DiffLeader);
  AssertTrue(StageData.HasPlace);
  AssertEquals(4, StageData.Place);
  AssertEquals(Ord(psDNF), Ord(StageData.Status));

  AssertTrue(TStageResultRepository.TryLoadParticipantStageData(
    FQuery, 108, 3, 8, StageData));
  AssertEquals(3, StageData.StageIndex);
  AssertFalse(StageData.HasCorrection);
  AssertFalse(StageData.HasPlace);
  AssertEquals(Ord(psNone), Ord(StageData.Status));
end;

procedure TDatasetSqlTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
end;

procedure TDatasetSqlTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TDatasetSqlTests.ExecSqlFmt(const AFormat: string;
  const AArgs: array of const);
begin
  ExecSql(Format(AFormat, AArgs));
end;

procedure TDatasetSqlTests.InsertMainRow(const ANumber: integer;
  const ACategory: string; const AName: string);
begin
  ExecSqlFmt(
    'INSERT INTO main (category, number, name) VALUES (%s, %d, %s);',
    [QuotedStr(ACategory), ANumber, QuotedStr(AName)]);
end;

procedure TDatasetSqlTests.OpenBySql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.Open;
end;

function TDatasetSqlTests.CountRows(const ASql: string): integer;
begin
  Result := 0;
  OpenBySql(ASql);
  while not FQuery.EOF do
  begin
    Inc(Result);
    FQuery.Next;
  end;
  FQuery.Close;
end;

procedure TDatasetSqlTests.SetUp;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FConnection.DatabaseName := ':memory:';
  FConnection.Transaction := FTransaction;
  FConnection.Open;

  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;

  CreateSchema;
end;

procedure TDatasetSqlTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TDatasetSqlTests.CorrectionPending_ReturnsOnlyRowsWithStartAndWithoutCorrectionOrStageStatus;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  InsertMainRow(104);
  InsertMainRow(105);
  ExecSql('UPDATE main SET starttime1 = ''10:00:00.000'' WHERE number = 101;');
  ExecSql('UPDATE main SET starttime1 = ''10:01:00.000'', correction1 = 100 WHERE number = 102;');
  ExecSql('UPDATE main SET starttime1 = ''10:02:00.000'', status1 = ''1'' WHERE number = 103;');
  ExecSql('UPDATE main SET starttime1 = NULL WHERE number = 104;');
  ExecSql('UPDATE main SET starttime1 = ''09:59:00.000'' WHERE number = 105;');

  OpenBySql(TDatasetSql.CorrectionPending(1));
  AssertEquals(3, FQuery.Fields.Count);
  AssertTrue(Assigned(FQuery.FindField('id')));
  AssertTrue(Assigned(FQuery.FindField('correction')));
  AssertFalse(Assigned(FQuery.FindField('name')));
  AssertEquals(2, CountRows(TDatasetSql.CorrectionPending(1)));

  OpenBySql(TDatasetSql.CorrectionPending(1));
  AssertEquals(105, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
end;

procedure TDatasetSqlTests.TrackStatus_ReturnsStartedRowsWithoutFinishAndWithoutStageStatus;
var
  TrackSql: string;
begin
  InsertMainRow(201);
  InsertMainRow(202);
  InsertMainRow(203);
  InsertMainRow(204);
  InsertMainRow(205);
  ExecSql('UPDATE main SET starttime1 = ''11:50:00.000'' WHERE number = 201;');
  ExecSql('UPDATE main SET starttime1 = ''12:10:00.000'' WHERE number = 202;');
  ExecSql('UPDATE main SET starttime1 = ''11:55:00.000'', finishtime1 = ''12:00:00.000'' WHERE number = 203;');
  ExecSql('UPDATE main SET starttime1 = ''11:54:00.000'', status1 = ''1'' WHERE number = 204;');
  ExecSql('UPDATE main SET starttime1 = ''11:40:00.000'' WHERE number = 205;');

  TrackSql := StringReplace(TDatasetSql.TrackStatus(1),
    'time(''now'', ''localtime'')', 'time(''12:00:00'')', [rfReplaceAll]);

  AssertEquals(2, CountRows(TrackSql));

  OpenBySql(TrackSql);
  AssertEquals(205, FQuery.FieldByName('number').AsInteger);
  AssertTrue(FQuery.FieldByName('timeontrack').AsString <> '');
  FQuery.Next;
  AssertEquals(201, FQuery.FieldByName('number').AsInteger);
  AssertTrue(FQuery.FieldByName('timeontrack').AsString <> '');
end;

procedure TDatasetSqlTests.ResultStage_ReturnsRowsWithResultAndResolvesGlobalDSQStatus;
var
  StatusFor301: string;
  StatusFor302: string;
begin
  InsertMainRow(301, 'elite', 'First');
  InsertMainRow(302, 'elite', 'Second');
  InsertMainRow(303, 'elite', 'Third');
  ExecSql(
    'UPDATE main SET result1 = ''00:03:10.000'', status = ''3'', place1 = 1, ' +
    'penalty1 = ''5'', diffleader1 = ''00:00:00.000'' WHERE number = 301;');
  ExecSql(
    'UPDATE main SET result1 = ''00:03:20.000'', status1 = ''1'', place1 = 2, ' +
    'penalty1 = ''0'', diffleader1 = ''00:00:10.000'' WHERE number = 302;');

  AssertEquals(2, CountRows(TDatasetSql.ResultStage(1)));

  StatusFor301 := '';
  StatusFor302 := '';
  OpenBySql(TDatasetSql.ResultStage(1));
  while not FQuery.EOF do
  begin
    if FQuery.FieldByName('number').AsInteger = 301 then
      StatusFor301 := FQuery.FieldByName('status1').AsString;
    if FQuery.FieldByName('number').AsInteger = 302 then
      StatusFor302 := FQuery.FieldByName('status1').AsString;
    FQuery.Next;
  end;
  AssertEquals('3', StatusFor301);
  AssertEquals('1', StatusFor302);
end;

procedure TDatasetSqlTests.ResultStageTotal_ReturnsOnlyRowsWithSumResultOrderedByStatusThenThruPlace;
begin
  InsertMainRow(401, 'elite', 'A');
  InsertMainRow(402, 'elite', 'B');
  InsertMainRow(403, 'elite', 'C');
  ExecSql(
    'UPDATE main SET sumresult = ''00:10:00.000'', sumstages = 2, thrudiff = ''00:00:10.000'', thruplace = 2, status = NULL WHERE number = 401;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:09:00.000'', sumstages = 2, thrudiff = ''00:00:00.000'', thruplace = 1, status = ''1'' WHERE number = 402;');
  ExecSql('UPDATE main SET sumresult = NULL, thruplace = 3 WHERE number = 403;');

  AssertEquals(2, CountRows(TDatasetSql.ResultStageTotal));

  OpenBySql(TDatasetSql.ResultStageTotal);
  AssertEquals(401, FQuery.FieldByName('number').AsInteger);
  AssertEquals(2, FQuery.FieldByName('sumplace').AsInteger);
  FQuery.Next;
  AssertEquals(402, FQuery.FieldByName('number').AsInteger);
  AssertEquals(1, FQuery.FieldByName('sumplace').AsInteger);
end;

procedure TDatasetSqlTests.ResultStageSum_ReturnsOnlyRowsWithSumResultOrderedByCategoryStatusStagesAndPlace;
begin
  InsertMainRow(501, 'elite', 'E1');
  InsertMainRow(502, 'elite', 'E2');
  InsertMainRow(503, 'elite', 'E3');
  InsertMainRow(504, 'sport', 'S1');
  InsertMainRow(505, 'sport', 'S2');
  ExecSql(
    'UPDATE main SET sumresult = ''00:10:00.000'', sumstages = 2, sumplace = 2, status = NULL WHERE number = 501;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:09:00.000'', sumstages = 3, sumplace = 1, status = NULL WHERE number = 502;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:11:00.000'', sumstages = 3, sumplace = NULL, status = ''1'' WHERE number = 503;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:12:00.000'', sumstages = 1, sumplace = 1, status = NULL WHERE number = 504;');
  ExecSql('UPDATE main SET sumresult = NULL WHERE number = 505;');

  AssertEquals(4, CountRows(TDatasetSql.ResultStageSum([1])));

  OpenBySql(TDatasetSql.ResultStageSum([1]));
  AssertEquals(6 + DEFAULT_STAGE_COUNT, FQuery.Fields.Count);
  AssertTrue(Assigned(FQuery.FindField(
    'result' + IntToStr(DEFAULT_STAGE_COUNT))));
  AssertFalse(Assigned(FQuery.FindField(
    'result' + IntToStr(DEFAULT_STAGE_COUNT + 1))));
  AssertFalse(Assigned(FQuery.FindField('status')));
  AssertEquals(502, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(501, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(503, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(504, FQuery.FieldByName('number').AsInteger);
end;

procedure TDatasetSqlTests.ResultStageSum_UsesActiveSparseStageIndexes;
var
  Sql: string;
begin
  Sql := TDatasetSql.ResultStageSum([1, 3, 5]);
  AssertTrue(Pos(', result1', Sql) > 0);
  AssertTrue(Pos(', result3', Sql) > 0);
  AssertTrue(Pos(', result5, sumresult', Sql) > 0);
  AssertEquals(0, Pos('result2', Sql));
  AssertEquals(0, Pos('result4', Sql));
end;

procedure TSchemaSqlStatementTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
end;

procedure TSchemaSqlStatementTests.SetUp;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FDbFilePath := GetTempDir(False) + 'db_sql_schema_test_' +
    IntToStr(GetTickCount64) + '.sqlite';
  FConnection.DatabaseName := FDbFilePath;
  FConnection.Transaction := FTransaction;
  FConnection.Open;

  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;
  CreateSchema;
end;

procedure TSchemaSqlStatementTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
  if (FDbFilePath <> '') and FileExists(FDbFilePath) then
    DeleteFile(FDbFilePath);
end;

procedure TSchemaSqlStatementTests.BeginAndEndTransaction_AreExecutableStatements;
begin
  AssertEquals('Begin Transaction', TSchemaSql.BeginTransaction);
  AssertEquals('End Transaction', TSchemaSql.EndTransaction);
end;

procedure TSchemaSqlStatementTests.
  CreateBackup_CreatesUsableCopyAndAppliesBusyTimeout;
var
  BackupPath: string;
  BackupConnection: TSQLite3Connection;
  BackupTransaction: TSQLTransaction;
  BackupQuery: TSQLQuery;
begin
  BackupPath := FDbFilePath + '.quoted'' timeout-backup';
  if FileExists(BackupPath) then
    DeleteFile(BackupPath);

  try
    FTransaction.Commit;
    TSchemaSql.ExecCreateBackup(FConnection, BackupPath, 1234);
    FQuery.Close;
    FQuery.SQL.Text := 'PRAGMA busy_timeout;';
    FQuery.Open;

    AssertEquals(1234, FQuery.Fields[0].AsInteger);
    AssertTrue(FileExists(BackupPath));
    FQuery.Close;

    BackupConnection := TSQLite3Connection.Create(nil);
    BackupTransaction := TSQLTransaction.Create(nil);
    BackupQuery := TSQLQuery.Create(nil);
    try
      BackupConnection.DatabaseName := BackupPath;
      BackupConnection.Transaction := BackupTransaction;
      BackupQuery.DataBase := BackupConnection;
      BackupQuery.Transaction := BackupTransaction;
      BackupConnection.Open;

      BackupQuery.SQL.Text :=
        'SELECT value FROM config WHERE key = ''racename'';';
      BackupQuery.Open;
      AssertEquals('Race One', BackupQuery.Fields[0].AsString);
      BackupQuery.Close;
      BackupTransaction.Rollback;
    finally
      BackupQuery.Free;
      BackupTransaction.Free;
      BackupConnection.Free;
    end;
  finally
    if FileExists(BackupPath) then
      DeleteFile(BackupPath);
  end;
end;

procedure TStartlistSqlTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
end;

procedure TStartlistSqlTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TStartlistSqlTests.ExecSqlFmt(const AFormat: string;
  const AArgs: array of const);
begin
  ExecSql(Format(AFormat, AArgs));
end;

procedure TStartlistSqlTests.InsertMainRow(const ANumber: integer;
  const ACategory: string; const AName: string);
begin
  ExecSqlFmt(
    'INSERT INTO main (category, number, name) VALUES (%s, %d, %s);',
    [QuotedStr(ACategory), ANumber, QuotedStr(AName)]);
end;

procedure TStartlistSqlTests.SetUp;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FConnection.DatabaseName := ':memory:';
  FConnection.Transaction := FTransaction;
  FConnection.Open;

  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;
  CreateSchema;
end;

procedure TStartlistSqlTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TStartlistSqlTests.SelectNumbersForCategory_SortsByNumberAndName;
begin
  InsertMainRow(30, 'elite', 'Charlie');
  InsertMainRow(10, 'elite', 'Alpha');
  InsertMainRow(20, 'elite', 'Bravo');

  TStartlistSql.ConfigureNumbersForCategory(FQuery,
    STARTLIST_SORT_BY_NUMBER_ASC, True, True, True, 'elite');
  FQuery.Open;
  AssertEquals(10, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(20, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(30, FQuery.FieldByName('number').AsInteger);
  FQuery.Close;

  FQuery.SQL.Text := TStartlistSql.SelectNumbersForCategory(
    STARTLIST_SORT_BY_NUMBER_DESC, True, True, True);
  FQuery.ParamByName('CATEGORY').AsString := 'elite';
  FQuery.Open;
  AssertEquals(30, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(20, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(10, FQuery.FieldByName('number').AsInteger);
  FQuery.Close;

  FQuery.SQL.Text := TStartlistSql.SelectNumbersForCategory(
    STARTLIST_SORT_BY_NAME_ASC, True, True, True);
  FQuery.ParamByName('CATEGORY').AsString := 'elite';
  FQuery.Open;
  AssertEquals(10, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(20, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(30, FQuery.FieldByName('number').AsInteger);
  FQuery.Close;
end;

procedure TDatasetSqlTests.ConfigureQueries_SetsEditableAndReadOnlyRoles;
begin
  TDatasetSql.ConfigureMainParticipants(FQuery, [1, 2]);
  AssertFalse(FQuery.ReadOnly);
  AssertEquals(Trim(TDatasetSql.MainParticipants([1, 2])),
    Trim(FQuery.SQL.Text));

  TDatasetSql.ConfigureCategoryStatistics(FQuery);
  AssertTrue(FQuery.ReadOnly);
  AssertEquals(Trim(TDatasetSql.CategoryStatistics), Trim(FQuery.SQL.Text));

  TDatasetSql.ConfigureCorrectionPending(FQuery, 2);
  AssertFalse(FQuery.ReadOnly);
  AssertEquals(Trim(TDatasetSql.CorrectionPending(2)), Trim(FQuery.SQL.Text));

  TDatasetSql.ConfigureStartMarkWorkQueue(FQuery);
  AssertFalse(FQuery.ReadOnly);
  AssertEquals(Trim(TStartMarkSql.SelectWorkQueue), Trim(FQuery.SQL.Text));

  TDatasetSql.ConfigureFinishMarkWorkQueue(FQuery);
  AssertFalse(FQuery.ReadOnly);
  AssertEquals(Trim(TFinishMarkSql.SelectWorkQueue), Trim(FQuery.SQL.Text));

  TDatasetSql.ConfigureResultStage(FQuery, 2);
  AssertTrue(FQuery.ReadOnly);
  AssertEquals(Trim(TDatasetSql.ResultStage(2)), Trim(FQuery.SQL.Text));
end;

procedure TDatasetSqlTests.MainParticipants_SelectsOnlyActiveSparseStageFields;
begin
  TDatasetSql.ConfigureMainParticipants(FQuery, [1, 3, 5]);
  FQuery.Open;
  AssertEquals(43, FQuery.Fields.Count);
  AssertNotNull(FQuery.FindField('starttime1'));
  AssertNotNull(FQuery.FindField('status3'));
  AssertNotNull(FQuery.FindField('starttime5'));
  AssertNull(FQuery.FindField('status2'));
  AssertNull(FQuery.FindField('starttime4'));
  AssertNull(FQuery.FindField('status8'));
  FQuery.Close;
end;

procedure TDatasetSqlTests.ConfigureCategoryStageResults_BindsCategoryParameter;
const
  CategoryWithQuote = 'women''s elite';
begin
  InsertMainRow(601, CategoryWithQuote, 'Rider');
  ExecSql('UPDATE main SET result2 = ''00:10:00.000'', place2 = 1 ' +
    'WHERE number = 601;');

  TDatasetSql.ConfigureCategoryStageResults(FQuery, 2, CategoryWithQuote);
  AssertTrue(FQuery.ReadOnly);
  AssertEquals(CategoryWithQuote, FQuery.ParamByName('CATEGORY').AsString);
  FQuery.Open;
  AssertEquals(601, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertTrue(FQuery.EOF);
end;

procedure TStartlistSqlTests.SelectNumbersForCategory_ResultMode_RespectsIncludeFlags;
begin
  InsertMainRow(101, 'elite', 'R1');
  InsertMainRow(102, 'elite', 'R2');
  InsertMainRow(103, 'elite', 'R3');
  InsertMainRow(104, 'elite', 'R4');
  InsertMainRow(105, 'elite', 'R5');
  ExecSql('UPDATE main SET sumresult = ''00:10:00.000'', sumstages = 2 WHERE number = 101;');
  ExecSql('UPDATE main SET sumresult = ''DNS'', sumstages = 2 WHERE number = 102;');
  ExecSql('UPDATE main SET sumresult = ''DNF'', sumstages = 2 WHERE number = 103;');
  ExecSql('UPDATE main SET sumresult = ''DSQ'', sumstages = 2 WHERE number = 104;');
  ExecSql('UPDATE main SET sumresult = NULL, sumstages = NULL WHERE number = 105;');

  FQuery.Close;
  FQuery.SQL.Text := TStartlistSql.SelectNumbersForCategory(
    STARTLIST_SORT_BY_RESULT, False, False, False);
  FQuery.ParamByName('CATEGORY').AsString := 'elite';
  FQuery.Open;
  AssertFalse(FQuery.EOF);
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertTrue(FQuery.EOF);
  FQuery.Close;

  FQuery.SQL.Text := TStartlistSql.SelectNumbersForCategory(
    STARTLIST_SORT_BY_RESULT, True, False, False);
  FQuery.ParamByName('CATEGORY').AsString := 'elite';
  FQuery.Open;
  AssertFalse(FQuery.EOF);
  AssertEquals(105, FQuery.FieldByName('number').AsInteger);
  FQuery.Close;
end;

procedure TStartlistSqlTests.SelectNumbersForCategory_ResultMode_ExcludesNullResultFromOtherCategory;
begin
  InsertMainRow(201, 'elite', 'Elite rider');
  InsertMainRow(202, 'sport', 'Sport rider');
  ExecSql(
    'UPDATE main SET sumresult = NULL, sumstages = NULL WHERE number IN (201, 202);');

  FQuery.Close;
  FQuery.SQL.Text := TStartlistSql.SelectNumbersForCategory(
    STARTLIST_SORT_BY_RESULT, True, False, False);
  FQuery.ParamByName('CATEGORY').AsString := 'elite';
  FQuery.Open;

  AssertFalse(FQuery.EOF);
  AssertEquals(201, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertTrue('A participant from another category must not be selected',
    FQuery.EOF);
  FQuery.Close;
end;

procedure TResultCalculationRepositoryTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
end;

procedure TResultCalculationRepositoryTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TResultCalculationRepositoryTests.ExecSqlFmt(const AFormat: string;
  const AArgs: array of const);
begin
  ExecSql(Format(AFormat, AArgs));
end;

procedure TResultCalculationRepositoryTests.InsertMainRow(const ANumber: integer;
  const ACategory: string; const AName: string);
begin
  ExecSqlFmt(
    'INSERT INTO main (category, number, name) VALUES (%s, %d, %s);',
    [QuotedStr(ACategory), ANumber, QuotedStr(AName)]);
end;

procedure TResultCalculationRepositoryTests.OpenMainByNumber(const ANumber: integer);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT * FROM main WHERE number = :NUMBER;';
  FQuery.ParamByName('NUMBER').AsInteger := ANumber;
  FQuery.Open;
  AssertFalse(FQuery.EOF);
end;

procedure TResultCalculationRepositoryTests.SetUp;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FConnection.DatabaseName := ':memory:';
  FConnection.Transaction := FTransaction;
  FConnection.Open;

  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;
  CreateSchema;
end;

procedure TResultCalculationRepositoryTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TResultCalculationRepositoryTests.UpdateStageResult_HandlesStatusesAndTimeCalculations;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  InsertMainRow(104);
  ExecSql(
    'UPDATE main SET starttime1 = ''10:00:00.000'', finishtime1 = ''10:02:00.000'', status = ''3'' WHERE number = 101;');
  ExecSql(
    'UPDATE main SET starttime1 = ''10:00:00.000'', finishtime1 = ''10:03:00.000'', status1 = ''2'' WHERE number = 102;');
  ExecSql(
    'UPDATE main SET starttime1 = ''10:00:00.000'', finishtime1 = ''10:04:00.000'', status1 = ''1'' WHERE number = 103;');
  ExecSql(
    'UPDATE main SET starttime1 = ''10:00:00.000'', finishtime1 = ''10:01:00.000'', status1 = NULL, correction1 = NULL, penalty1 = NULL WHERE number = 104;');

  ExecSql(TResultCalculationRepository.UpdateStageResult(1));

  OpenMainByNumber(101);
  AssertEquals('DSQ', FQuery.FieldByName('result1').AsString);

  OpenMainByNumber(102);
  AssertEquals('DNF', FQuery.FieldByName('result1').AsString);
  AssertTrue(FQuery.FieldByName('finishtime1').IsNull);

  OpenMainByNumber(103);
  AssertEquals('DNS', FQuery.FieldByName('result1').AsString);
  AssertTrue(FQuery.FieldByName('finishtime1').IsNull);

  OpenMainByNumber(104);
  AssertTrue(FQuery.FieldByName('result1').AsString <> '');
end;

procedure TResultCalculationRepositoryTests.SelectForSumCalculation_ReturnsOnlyRequestedStageResults;
begin
  InsertMainRow(110);
  ExecSql(
    'UPDATE main SET result1 = ''00:01:00.000'', ' +
    'result2 = ''00:02:00.000'', result3 = ''00:03:00.000'', ' +
    'status = ''1'' WHERE number = 110;');

  FQuery.Close;
  FQuery.SQL.Text := TResultCalculationRepository.SelectForSumCalculation([1, 3]);
  FQuery.Open;
  AssertEquals(4, FQuery.Fields.Count);
  AssertEquals(110, FQuery.FieldByName('number').AsInteger);
  AssertEquals('1', FQuery.FieldByName('status').AsString);
  AssertEquals('00:01:00.000', FQuery.FieldByName('result1').AsString);
  AssertEquals('00:03:00.000', FQuery.FieldByName('result3').AsString);
  AssertFalse(Assigned(FQuery.FindField('result2')));
end;

procedure TResultCalculationRepositoryTests.UpdateSumResult_UpdatesValuesAndPreservesStatusConditionally;
begin
  InsertMainRow(111);
  InsertMainRow(112);
  ExecSql('UPDATE main SET status = ''1'' WHERE number = 111;');
  ExecSql('UPDATE main SET status = ''3'' WHERE number = 112;');

  FQuery.Close;
  FQuery.SQL.Text := TResultCalculationRepository.UpdateSumResult;
  FQuery.Prepare;
  try
    FQuery.ParamByName('SUMRESULT').AsString := '01:02:03.000';
    FQuery.ParamByName('SUMSTAGES').AsInteger := 2;
    FQuery.ParamByName('CLEAR_STATUS').AsInteger := 1;
    FQuery.ParamByName('NUMBER').AsInteger := 111;
    FQuery.ExecSQL;

    FQuery.ParamByName('SUMRESULT').AsString := 'DSQ';
    FQuery.ParamByName('SUMSTAGES').Clear;
    FQuery.ParamByName('CLEAR_STATUS').AsInteger := 0;
    FQuery.ParamByName('NUMBER').AsInteger := 112;
    FQuery.ExecSQL;
  finally
    FQuery.UnPrepare;
  end;
  FTransaction.Commit;

  OpenMainByNumber(111);
  AssertEquals('01:02:03.000', FQuery.FieldByName('sumresult').AsString);
  AssertEquals(2, FQuery.FieldByName('sumstages').AsInteger);
  AssertTrue(FQuery.FieldByName('status').IsNull);

  OpenMainByNumber(112);
  AssertEquals('DSQ', FQuery.FieldByName('sumresult').AsString);
  AssertTrue(FQuery.FieldByName('sumstages').IsNull);
  AssertEquals('3', FQuery.FieldByName('status').AsString);
end;

procedure TResultCalculationRepositoryTests.ResetStagePlaceAndDiff_AndUpsertStagePlace_AssignsPlaces;
begin
  InsertMainRow(201, 'elite');
  InsertMainRow(202, 'elite');
  InsertMainRow(203, 'sport');
  ExecSql(
    'UPDATE main SET result1 = ''00:01:00.000'', finishtime1 = ''10:01:00.000'', status1 = NULL, place1 = 99, diffleader1 = ''xx'' WHERE number = 201;');
  ExecSql(
    'UPDATE main SET result1 = ''00:02:00.000'', finishtime1 = ''10:02:00.000'', status1 = NULL, place1 = 99, diffleader1 = ''yy'' WHERE number = 202;');
  ExecSql(
    'UPDATE main SET result1 = ''00:03:00.000'', finishtime1 = ''10:03:00.000'', status1 = NULL, place1 = 99, diffleader1 = ''zz'' WHERE number = 203;');

  ExecSql(TResultCalculationRepository.ResetStagePlaceAndDiff(1));
  ExecSql(TResultCalculationRepository.UpsertStagePlace(1));

  OpenMainByNumber(201);
  AssertEquals(1, FQuery.FieldByName('place1').AsInteger);
  OpenMainByNumber(202);
  AssertEquals(2, FQuery.FieldByName('place1').AsInteger);
  OpenMainByNumber(203);
  AssertEquals(1, FQuery.FieldByName('place1').AsInteger);
end;

procedure TResultCalculationRepositoryTests.ResetStageDiffLeader_AndUpsertStageDiffLeader_SetsLeaderDiff;
begin
  InsertMainRow(301, 'elite');
  InsertMainRow(302, 'elite');
  ExecSql(
    'UPDATE main SET result1 = ''00:01:00.000'', place1 = 1, diffleader1 = ''not_null'' WHERE number = 301;');
  ExecSql(
    'UPDATE main SET result1 = ''00:01:20.000'', place1 = 2, diffleader1 = NULL WHERE number = 302;');

  ExecSql(TResultCalculationRepository.ResetStageDiffLeader(1));
  ExecSql(TResultCalculationRepository.UpsertStageDiffLeader(1));

  OpenMainByNumber(301);
  AssertTrue(FQuery.FieldByName('diffleader1').IsNull);
  OpenMainByNumber(302);
  AssertTrue(FQuery.FieldByName('diffleader1').AsString <> '');
end;

procedure TResultCalculationRepositoryTests.ResetSumPlaceAndDiff_AndUpsertSumPlaceOnlyFullStages_AssignsSumPlace;
const
  ActiveStages: array[0..1] of integer = (1, 2);
begin
  InsertMainRow(401, 'elite');
  InsertMainRow(402, 'elite');
  InsertMainRow(403, 'elite');
  ExecSql(
    'UPDATE main SET sumresult = ''00:10:00.000'', status = NULL, sumplace = 9, ' +
    'sumdiffleader = ''x'', result1 = ''ok'', result2 = ''ok'', status1 = NULL, status2 = NULL WHERE number = 401;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:11:00.000'', status = NULL, sumplace = 9, ' +
    'sumdiffleader = ''x'', result1 = ''ok'', result2 = ''ok'', status1 = NULL, status2 = NULL WHERE number = 402;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:09:00.000'', status = NULL, sumplace = 9, ' +
    'sumdiffleader = ''x'', result1 = ''ok'', result2 = NULL, status1 = NULL, status2 = NULL WHERE number = 403;');

  ExecSql(TResultCalculationRepository.ResetSumPlaceAndDiff);
  ExecSql(TResultCalculationRepository.UpsertSumPlaceOnlyFullStages(ActiveStages));

  OpenMainByNumber(401);
  AssertEquals(1, FQuery.FieldByName('sumplace').AsInteger);
  OpenMainByNumber(402);
  AssertEquals(2, FQuery.FieldByName('sumplace').AsInteger);
  OpenMainByNumber(403);
  AssertTrue(FQuery.FieldByName('sumplace').IsNull);
end;

procedure TResultCalculationRepositoryTests.ResetSumDiffLeader_AndUpsertSumDiffLeader_SetsSumDiff;
begin
  InsertMainRow(501, 'elite');
  InsertMainRow(502, 'elite');
  ExecSql(
    'UPDATE main SET sumresult = ''00:10:00.000'', sumplace = 1, sumdiffleader = ''x'' WHERE number = 501;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:11:00.000'', sumplace = 2, sumdiffleader = NULL WHERE number = 502;');

  ExecSql(TResultCalculationRepository.ResetSumDiffLeader);
  ExecSql(TResultCalculationRepository.UpsertSumDiffLeader);

  OpenMainByNumber(501);
  AssertTrue(FQuery.FieldByName('sumdiffleader').IsNull);
  OpenMainByNumber(502);
  AssertTrue(FQuery.FieldByName('sumdiffleader').AsString <> '');
end;

procedure TResultCalculationRepositoryTests.ExecSqlWithStageCaption(
  const ASql, ACaption: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  TResultCalculationRepository.BindStageCaption(FQuery, ACaption);
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TResultCalculationRepositoryTests.UpsertSumDiffByStages_SetsStageGapText;
begin
  InsertMainRow(601, 'elite');
  InsertMainRow(602, 'elite');
  ExecSql(
    'UPDATE main SET sumstages = 5, sumplace = 1, status = NULL WHERE number = 601;');
  ExecSql(
    'UPDATE main SET sumstages = 3, sumplace = NULL, status = NULL WHERE number = 602;');

  ExecSqlWithStageCaption(TResultCalculationRepository.UpsertSumDiffByStages,
    'stages');

  OpenMainByNumber(602);
  AssertEquals(1, Pos('+', FQuery.FieldByName('sumdiffleader').AsString));
  AssertTrue(Pos('stages', FQuery.FieldByName('sumdiffleader').AsString) > 0);
end;

procedure TResultCalculationRepositoryTests.ResetThru_AndUpsertThruPlace_AssignsThruPlace;
begin
  InsertMainRow(701, 'elite');
  InsertMainRow(702, 'elite');
  InsertMainRow(703, 'sport');
  ExecSql(
    'UPDATE main SET sumresult = ''00:10:00.000'', sumstages = 3, status = NULL, ' +
    'thruplace = 9, thrudiff = ''x'' WHERE number = 701;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:11:00.000'', sumstages = 2, status = NULL, ' +
    'thruplace = 9, thrudiff = ''x'' WHERE number = 702;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:09:00.000'', sumstages = 3, status = NULL, ' +
    'thruplace = 9, thrudiff = ''x'' WHERE number = 703;');

  ExecSql(TResultCalculationRepository.ResetThru);
  ExecSql(TResultCalculationRepository.UpsertThruPlace);

  OpenMainByNumber(703);
  AssertEquals(1, FQuery.FieldByName('thruplace').AsInteger);
  OpenMainByNumber(701);
  AssertEquals(2, FQuery.FieldByName('thruplace').AsInteger);
  OpenMainByNumber(702);
  AssertEquals(3, FQuery.FieldByName('thruplace').AsInteger);
end;

procedure TResultCalculationRepositoryTests.UpsertThruDiff_AndUpsertThruDiffByStages_SetsThruDiff;
begin
  InsertMainRow(801, 'elite');
  InsertMainRow(802, 'elite');
  InsertMainRow(803, 'elite');
  ExecSql(
    'UPDATE main SET sumresult = ''00:10:00.000'', sumstages = 4, status = NULL, sumplace = 1 WHERE number = 801;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:12:00.000'', sumstages = 4, status = NULL, sumplace = 2 WHERE number = 802;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:20:00.000'', sumstages = 2, status = NULL, sumplace = NULL WHERE number = 803;');

  ExecSql(TResultCalculationRepository.UpsertThruPlace);
  ExecSql(TResultCalculationRepository.UpsertThruDiff);

  OpenMainByNumber(802);
  AssertTrue(FQuery.FieldByName('thrudiff').AsString <> '');

  ExecSqlWithStageCaption(TResultCalculationRepository.UpsertThruDiffByStages,
    'stages');

  OpenMainByNumber(803);
  AssertEquals(1, Pos('+', FQuery.FieldByName('thrudiff').AsString));
  AssertTrue(Pos('stages', FQuery.FieldByName('thrudiff').AsString) > 0);
end;

procedure TResultCalculationRepositoryTests.UpsertThruDiffByStages_UnfinishedRaceWithEqualStages_PreservesTimeDiff;
begin
  InsertMainRow(811, 'elite');
  InsertMainRow(812, 'elite');
  ExecSql(
    'UPDATE main SET sumresult = ''00:10:00.000'', sumstages = 2, ' +
    'sumplace = NULL, status = NULL WHERE number = 811;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:12:00.000'', sumstages = 2, ' +
    'sumplace = NULL, status = NULL WHERE number = 812;');

  ExecSql(TResultCalculationRepository.UpsertThruPlace);
  ExecSql(TResultCalculationRepository.UpsertThruDiff);
  ExecSqlWithStageCaption(TResultCalculationRepository.UpsertThruDiffByStages,
    'stages');

  OpenMainByNumber(812);
  AssertTrue('Participant with the same number of completed stages must keep ' +
    'the time gap instead of receiving a +0 stages gap.',
    Pos('+0 stages', FQuery.FieldByName('thrudiff').AsString) = 0);
end;

procedure TResultCalculationRepositoryTests.ClearResultsPrefixStageSuffix_ClearsResultsColumns;
begin
  InsertMainRow(901);
  ExecSql(
    'UPDATE main SET correction1 = 10, finishtime1 = ''10:10:10.100'', penalty1 = ''5'', ' +
    'result1 = ''00:01:00.000'', diffleader1 = ''00:00:05.000'', place1 = 1, status1 = ''1'', ' +
    'correction2 = 11, finishtime2 = ''10:11:10.100'', penalty2 = ''6'', result2 = ''00:02:00.000'', ' +
    'diffleader2 = ''00:00:06.000'', place2 = 2, status2 = ''2'', sumplace = 3, sumresult = ''00:20:00.000'', ' +
    'sumdiffleader = ''00:00:10.000'', thrudiff = ''00:00:15.000'', status = ''3'' WHERE number = 901;');

  FQuery.Close;
  FQuery.SQL.Clear;
  FQuery.SQL.Add(TResultCalculationRepository.ClearResultsPrefix);
  FQuery.SQL.Add(TResultCalculationRepository.ClearResultsStagePart(1));
  FQuery.SQL.Add(TResultCalculationRepository.ClearResultsStagePart(2));
  FQuery.SQL.Add(TResultCalculationRepository.ClearResultsSuffix);
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;

  OpenMainByNumber(901);
  AssertTrue(FQuery.FieldByName('correction1').IsNull);
  AssertTrue(FQuery.FieldByName('finishtime1').IsNull);
  AssertTrue(FQuery.FieldByName('penalty1').IsNull);
  AssertTrue(FQuery.FieldByName('result1').IsNull);
  AssertTrue(FQuery.FieldByName('diffleader1').IsNull);
  AssertTrue(FQuery.FieldByName('place1').IsNull);
  AssertTrue(FQuery.FieldByName('status1').IsNull);
  AssertTrue(FQuery.FieldByName('correction2').IsNull);
  AssertTrue(FQuery.FieldByName('finishtime2').IsNull);
  AssertTrue(FQuery.FieldByName('penalty2').IsNull);
  AssertTrue(FQuery.FieldByName('result2').IsNull);
  AssertTrue(FQuery.FieldByName('diffleader2').IsNull);
  AssertTrue(FQuery.FieldByName('place2').IsNull);
  AssertTrue(FQuery.FieldByName('status2').IsNull);
  AssertTrue(FQuery.FieldByName('sumplace').IsNull);
  AssertTrue(FQuery.FieldByName('sumresult').IsNull);
  AssertTrue(FQuery.FieldByName('sumdiffleader').IsNull);
  AssertTrue(FQuery.FieldByName('thrudiff').IsNull);
  AssertTrue(FQuery.FieldByName('status').IsNull);
end;

procedure TCompetitionImportRepositoryTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
end;

procedure TCompetitionImportRepositoryTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TCompetitionImportRepositoryTests.ExecSqlFmt(const AFormat: string;
  const AArgs: array of const);
begin
  ExecSql(Format(AFormat, AArgs));
end;

procedure TCompetitionImportRepositoryTests.InsertMainRow(const ANumber: integer;
  const ACategory: string; const AName: string);
begin
  ExecSqlFmt(
    'INSERT INTO main (category, number, name) VALUES (%s, %d, %s);',
    [QuotedStr(ACategory), ANumber, QuotedStr(AName)]);
end;

procedure TCompetitionImportRepositoryTests.OpenMainByNumber(const ANumber: integer);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT * FROM main WHERE number = :NUMBER;';
  FQuery.ParamByName('NUMBER').AsInteger := ANumber;
  FQuery.Open;
  AssertFalse(FQuery.EOF);
end;

procedure TCompetitionImportRepositoryTests.SetUp;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FConnection.DatabaseName := ':memory:';
  FConnection.Transaction := FTransaction;
  FConnection.Open;

  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;
  CreateSchema;
end;

procedure TCompetitionImportRepositoryTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TCompetitionImportRepositoryTests.PreparedParticipantRows_ImportAndUpsertRows;
var
  StartItem: TStartItemModel;
begin
  StartItem := TStartItemModel.Create;
  try
    StartItem.number := 101;
    StartItem.category := 'elite';
    StartItem.Name := 'Name A';
    StartItem.startTimes.Add('10:00:00.000');
    StartItem.startTimes.Add('10:10:00.000');
    TCompetitionImportRepository.PrepareParticipantRows(FQuery, 2);
    TCompetitionImportRepository.ExecPreparedParticipantRow(FQuery,
      StartItem, 2);

    StartItem.Name := 'Name A2';
    TCompetitionImportRepository.ExecPreparedParticipantRow(FQuery,
      StartItem, 2);
    TCompetitionImportRepository.FinishPreparedRows(FQuery);
  finally
    StartItem.Free;
  end;

  OpenMainByNumber(101);
  AssertEquals('Name A2', FQuery.FieldByName('name').AsString);
  AssertEquals('10:00:00.000', FQuery.FieldByName('starttime1').AsString);
  AssertEquals('10:10:00.000', FQuery.FieldByName('starttime2').AsString);
end;

procedure TCompetitionImportRepositoryTests.ParticipantUpsert_ParametersPreserveSqlSensitiveCharacters;
var
  StartItem: TStartItemModel;
begin
  StartItem := TStartItemModel.Create;
  try
    StartItem.category := 'Masters';
    StartItem.number := 99;
    StartItem.Name := 'O''Connor';
    StartItem.team := 'RiderShop&amp;Service';
    StartItem.city := 'Tashkent';
    StartItem.comment := 'Text; "quoted"';
    StartItem.startTimes.Add('11:30:00');
    StartItem.startTimes.Add('12:20:00');
    FQuery.SQL.Text :=
      TCompetitionImportRepository.UpsertParticipantRowStatement(2);
    TCompetitionImportRepository.BindParticipantRowParameters(FQuery,
      StartItem, 2);
    FQuery.ExecSQL;
    FQuery.SQLTransaction.Commit;
  finally
    StartItem.Free;
  end;

  FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT name, team, comment FROM main WHERE number = 99;';
  FQuery.Open;
  AssertFalse(FQuery.IsEmpty);
  AssertEquals('O''Connor', FQuery.FieldByName('name').AsString);
  AssertEquals('RiderShop&amp;Service',
    FQuery.FieldByName('team').AsString);
  AssertEquals('Text; "quoted"',
    FQuery.FieldByName('comment').AsString);
  FQuery.Close;
end;

procedure TCompetitionImportRepositoryTests.BindParticipantRowParameters_MapsModelToQueryParams;
var
  StartItem: TStartItemModel;
begin
  StartItem := TStartItemModel.Create;
  try
    StartItem.category := 'Elite';
    StartItem.number := 1201;
    StartItem.Name := 'Rider Name';
    StartItem.nickname := 'nickname';
    StartItem.birthday := '1999';
    StartItem.team := 'Team';
    StartItem.city := 'City';
    StartItem.phone := '+70000000000';
    StartItem.email := 'rider@example.test';
    StartItem.comment := 'Comment';
    StartItem.startTimes.Add('09:00:00.000');
    StartItem.startTimes.Add('09:10:00.000');

    FQuery.SQL.Text :=
      TCompetitionImportRepository.UpsertParticipantRowStatement(12);
    TCompetitionImportRepository.BindParticipantRowParameters(FQuery,
      StartItem, 12);

    AssertEquals('Elite', FQuery.ParamByName('CATEGORY').AsString);
    AssertEquals(1201, FQuery.ParamByName('NUMBER').AsInteger);
    AssertEquals('Rider Name', FQuery.ParamByName('NAME').AsString);
    AssertEquals('nickname', FQuery.ParamByName('NICKNAME').AsString);
    AssertEquals('1999', FQuery.ParamByName('AGE').AsString);
    AssertEquals('Team', FQuery.ParamByName('TEAM').AsString);
    AssertEquals('City', FQuery.ParamByName('CITY').AsString);
    AssertEquals('+70000000000', FQuery.ParamByName('PHONE').AsString);
    AssertEquals('rider@example.test', FQuery.ParamByName('EMAIL').AsString);
    AssertEquals('Comment', FQuery.ParamByName('COMMENT').AsString);
    AssertEquals('09:00:00.000',
      FQuery.ParamByName('STARTTIME1').AsString);
    AssertEquals('09:10:00.000',
      FQuery.ParamByName('STARTTIME2').AsString);
    AssertEquals('', FQuery.ParamByName('STARTTIME3').AsString);
    AssertEquals('', FQuery.ParamByName('STARTTIME12').AsString);
  finally
    StartItem.Free;
  end;
end;

procedure TCompetitionImportRepositoryTests.ApplyStageDefinitions_ReplacesActiveSetAndPreservesHiddenNames;
var
  StageNames: TStringList;
begin
  TConfigSql.ExecUpsertByKey(FQuery, 'stage3', 'True');
  TConfigSql.ExecUpsertByKey(FQuery, 'stagename3', 'Hidden stage');
  StageNames := TStringList.Create;
  try
    StageNames.Add('Start A');
    StageNames.Add('Start B');
    TCompetitionImportRepository.ExecApplyStageDefinitions(FQuery,
      StageNames, 8);
  finally
    StageNames.Free;
  end;

  AssertTrue(TConfigSql.GetBool(FQuery, 'stage1', False));
  AssertTrue(TConfigSql.GetBool(FQuery, 'stage2', False));
  AssertFalse(TConfigSql.GetBool(FQuery, 'stage3', True));
  AssertFalse(TConfigSql.GetBool(FQuery, 'stage8', True));
  AssertEquals('Start A', TConfigSql.GetString(FQuery, 'stagename1', ''));
  AssertEquals('Start B', TConfigSql.GetString(FQuery, 'stagename2', ''));
  AssertEquals('Hidden stage',
    TConfigSql.GetString(FQuery, 'stagename3', ''));
  AssertEquals(8, TConfigSql.GetInteger(FQuery, 'stagecount', 0));
end;

procedure TCompetitionImportRepositoryTests.ApplyStageDefinitions_EmptyListPreservesConfiguration;
var
  StageNames: TStringList;
begin
  TConfigSql.ExecUpsertByKey(FQuery, 'stage3', 'True');
  TConfigSql.ExecUpsertByKey(FQuery, 'stagename3', 'Existing stage');
  StageNames := TStringList.Create;
  try
    TCompetitionImportRepository.ExecApplyStageDefinitions(FQuery,
      StageNames, 8);
  finally
    StageNames.Free;
  end;

  AssertTrue(TConfigSql.GetBool(FQuery, 'stage3', False));
  AssertEquals('Existing stage',
    TConfigSql.GetString(FQuery, 'stagename3', ''));
end;

procedure TCompetitionImportRepositoryTests.PreparedFullStageResultRows_ImportAndUpsertValues;
var
  ImportRow: TStageResultImportRow;
begin
  InsertMainRow(301);
  ImportRow.ParticipantNumber := 301;
  ImportRow.StartTime := '10:00:00.000';
  ImportRow.HasCorrection := True;
  ImportRow.Correction := 5;
  ImportRow.FinishTime := '10:10:00.000';
  ImportRow.Penalty := 'Text; ''quoted''';
  ImportRow.HasStatus := True;
  ImportRow.Status := psDNF;

  TCompetitionImportRepository.PrepareStageResultRows(FQuery,
    srifFullStage, 2, 3);
  TCompetitionImportRepository.ExecPreparedStageResultRow(FQuery,
    ImportRow, srifFullStage);
  ImportRow.Correction := -7;
  ImportRow.Status := psDNS;
  TCompetitionImportRepository.ExecPreparedStageResultRow(FQuery,
    ImportRow, srifFullStage);
  TCompetitionImportRepository.FinishPreparedRows(FQuery);

  OpenMainByNumber(301);
  AssertTrue(FQuery.FieldByName('starttime1').IsNull);
  AssertEquals('10:00:00.000', FQuery.FieldByName('starttime2').AsString);
  AssertEquals(-7, FQuery.FieldByName('correction2').AsInteger);
  AssertEquals('10:10:00.000', FQuery.FieldByName('finishtime2').AsString);
  AssertEquals('Text; ''quoted''', FQuery.FieldByName('penalty2').AsString);
  AssertEquals(ParticipantStatusToDbValue(psDNS),
    FQuery.FieldByName('status2').AsString);
end;

procedure TCompetitionImportRepositoryTests.PreparedStartResultRows_PreserveNullsAndSelectedStage;
var
  ImportRow: TStageResultImportRow;
begin
  ImportRow.ParticipantNumber := 401;
  ImportRow.StartTime := '';
  ImportRow.HasCorrection := True;
  ImportRow.Correction := -250;
  ImportRow.FinishTime := '';
  ImportRow.Penalty := '';
  ImportRow.HasStatus := True;
  ImportRow.Status := psDNF;

  TCompetitionImportRepository.PrepareStageResultRows(FQuery,
    srifStart, 2, 3);
  TCompetitionImportRepository.ExecPreparedStageResultRow(FQuery,
    ImportRow, srifStart);
  TCompetitionImportRepository.FinishPreparedRows(FQuery);

  OpenMainByNumber(401);
  AssertTrue(FQuery.FieldByName('starttime1').IsNull);
  AssertTrue(FQuery.FieldByName('starttime2').IsNull);
  AssertEquals(-250, FQuery.FieldByName('correction2').AsInteger);
  AssertEquals(ParticipantStatusToDbValue(psDNF),
    FQuery.FieldByName('status2').AsString);
end;

procedure TCompetitionImportRepositoryTests.PreparedFinishResultRows_PreserveNullStatusAndSelectedStage;
var
  ImportRow: TStageResultImportRow;
begin
  ImportRow.ParticipantNumber := 501;
  ImportRow.StartTime := '';
  ImportRow.HasCorrection := False;
  ImportRow.Correction := 0;
  ImportRow.FinishTime := '12:12:12.120';
  ImportRow.Penalty := '';
  ImportRow.HasStatus := False;
  ImportRow.Status := psNone;

  TCompetitionImportRepository.PrepareStageResultRows(FQuery,
    srifFinish, 3, 3);
  TCompetitionImportRepository.ExecPreparedStageResultRow(FQuery,
    ImportRow, srifFinish);
  TCompetitionImportRepository.FinishPreparedRows(FQuery);

  OpenMainByNumber(501);
  AssertTrue(FQuery.FieldByName('finishtime2').IsNull);
  AssertEquals('12:12:12.120', FQuery.FieldByName('finishtime3').AsString);
  AssertTrue(FQuery.FieldByName('status3').IsNull);
end;

procedure TSqlSafetyTests.RequireStageIndex_RejectsOutsideConfiguredRange;
var
  RejectedBelow, RejectedAbove: boolean;
begin
  RejectedBelow := False;
  RejectedAbove := False;
  try
    RequireStageIndex(0, 2);
  except
    on E: EStageIndexError do
      RejectedBelow := True;
  end;
  try
    RequireStageIndex(3, 2);
  except
    on E: EStageIndexError do
      RejectedAbove := True;
  end;
  AssertTrue(RejectedBelow);
  AssertTrue(RejectedAbove);
end;

procedure TSqlSafetyTests.DynamicSqlBuilders_RejectStageAboveConfiguredCount;
var
  QueryRejected, CalculationRejected, ImportRejected: boolean;
begin
  QueryRejected := False;
  CalculationRejected := False;
  ImportRejected := False;
  try
    TDatasetSql.CorrectionPending(3, 2);
  except
    on E: EStageIndexError do
      QueryRejected := True;
  end;
  try
    TResultCalculationRepository.UpdateStageResult(3, 2);
  except
    on E: EStageIndexError do
      CalculationRejected := True;
  end;
  try
    TCompetitionImportRepository.UpsertStageResultRowStatement(
      srifFullStage, 3, 2);
  except
    on E: EStageIndexError do
      ImportRejected := True;
  end;
  AssertTrue(QueryRejected);
  AssertTrue(CalculationRejected);
  AssertTrue(ImportRejected);
end;

procedure TSqlSafetyTests.SqlIdentifierCsv_QuotesIdentifiersAndRejectsFragments;
var
  Rejected: boolean;
begin
  AssertEquals('"number", "sumplace"',
    SqlIdentifierCsv('number, sumplace'));
  Rejected := False;
  try
    SqlIdentifierCsv('number, sumplace DESC');
  except
    on E: ESqlIdentifierError do
      Rejected := True;
  end;
  AssertTrue(Rejected);
end;

initialization
  RegisterTest(TDbSqlTests);
  RegisterTest(TConfigSqlTests);
  RegisterTest(TParticipantAndStageResultRepositoryTests);
  RegisterTest(TDatasetSqlTests);
  RegisterTest(TSchemaSqlStatementTests);
  RegisterTest(TStartlistSqlTests);
  RegisterTest(TResultCalculationRepositoryTests);
  RegisterTest(TCompetitionImportRepositoryTests);
  RegisterTest(TSqlSafetyTests);

end.
