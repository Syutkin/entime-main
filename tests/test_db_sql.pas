unit test_db_sql;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, sqlite3conn, sqldb, db_sql;

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
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ExecCreateTables_InMemoryDatabase_CreatesSchemaAndDefaults;
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
    procedure GetString_ReturnsStoredValue;
    procedure GetString_ReturnsDefault_WhenKeyMissing;
    procedure GetString_ReturnsDefault_WhenValueEmpty;
    procedure GetBool_ParsesTrueValues;
    procedure GetBool_ParsesFalseValues;
    procedure GetBool_UsesDefault_ForInvalidOrEmpty;
    procedure GetBool_UsesDefault_WhenKeyMissing;
  end;

  TMainSqlTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    // Test-only helper: creates fresh in-memory schema for TMainSql tests.
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
    procedure ExecUpdateStartTimeForNumber_SetsStartAndClearsStageStatus;
    procedure ExecUpdateCorrection_SetsCorrectionValue;
    procedure ExecUpdateFinishForCheckedStages_UpdatesSpecifiedStages;
    procedure ExecUpdateFinishForCheckedStages_EmptyStages_NoChanges;
    procedure ExecUpdateStageStatus_SetsStageResultAndClearsPlaceDiff;
    procedure ExecUpdateOnlyGlobalStatusDsq_SetsStatusTo3;
    procedure ExecUpdateGlobalStatus_SetsNumericAndClearsOnNULLKeyword;
    procedure ExecClearOnlyGlobalStatus_ClearsGlobalStatus;
    procedure ExecClearStageStatus_ClearsOnlyStageFields;
    procedure ExecClearStatusAllForStage_ClearsStageAndGlobalStatus;
    procedure SelectAll_ReturnsInsertedRows;
    procedure SelectNumbers_ReturnsOnlyParticipantNumbers;
    procedure ResetStartTime_ClearsStageStartTimeForAllRows;
    procedure UpdateStartTime_SetsStageStartTimeForSpecificNumber;
    procedure SelectMinStartTime_ReturnsEarliestNonNullStartTime;
    procedure SelectMaxNumber_ReturnsMaximumNumber;
    procedure SelectCategoryGrouped_ReturnsDistinctCategories;
    procedure SelectCategoryGroupedOrderedByStartTime_OrdersByStageStartTime;
    procedure SelectCategoryResults_FiltersByCategoryAndSorts;
    procedure SelectStatusAll_ReturnsOnlyRowsWithGlobalStatus;
    procedure SelectStatusByStage_ReturnsOnlyRowsWithStageStatus;
    procedure ExportFinishTime_ReturnsRequestedStageColumns;
    procedure ExportAllResults_ReturnsSummaryColumns;
    procedure ExportSumDays_JoinsMainAndSumDays;
  end;

  TSumDaysSqlTests = class(TTestCase)
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
    // Test-only helper: inserts minimal row into main table for joins in sumdays SQL.
    procedure InsertMainRow(const ANumber: integer; const ACategory: string);
    // Test-only helper: inserts row into sumdays with explicit place SQL literal.
    procedure InsertSumDaysRow(const ANumber: integer; const ASumResult: string;
      const ASumStages: integer; const APlaceSql: string = 'NULL');
    // Test-only helper: opens sumdays row by number for assertions.
    procedure OpenSumDaysByNumber(const ANumber: integer);
    // Test-only helper: asserts sumdays place equals expected integer.
    procedure AssertSumDaysPlaceEquals(const ANumber, AExpected: integer);
    // Test-only helper: asserts sumdays place is SQL NULL.
    procedure AssertSumDaysPlaceNull(const ANumber: integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure CreateTableIfNotExists_CreatesSumDaysTable;
    procedure DeleteAll_RemovesAllRows;
    procedure UpsertPlacesByCategory_AssignsPlacesByCategoryAndMaxStages;
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
    procedure VacuumInto_CreatesBackupFile;
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
  end;

  TLoRaSqlTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    procedure CreateSchema;
    procedure ExecSql(const ASql: string);
    procedure OpenBySql(const ASql: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SelectPendingAndSelectAll_ReturnExpectedRows;
    procedure SelectStartAfter_FiltersByStartTime;
    procedure ResetIsSetNull_UpdatesOnlyNullRows;
    procedure SetIsSetById_UpdatesOnlyTargetRow;
    procedure ExecSetIsSetByIdAndValue_UpdatesTargetRow;
    procedure ExecInsertSample_InsertsWithAndWithoutNumber;
  end;

  TResultsSqlTests = class(TTestCase)
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
    procedure ClearResultsPrefixStageSuffix_ClearsResultsColumns;
  end;

  TLoadSqlTests = class(TTestCase)
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
    procedure ExecDeleteLoadAndLoadResult_RemoveRows;
    procedure InsertLoadRow_ParametersPreserveSqlSensitiveCharacters;
    procedure InsertLoadHeaderAndExecInsertLoadMainFromLoad_ImportsAndUpsertsRows;
    procedure InsertLoadResultHeaders_AreExecutableFor6And3And2Columns;
    procedure InsertLoadResultRows_ParametersPreserveValuesAndNulls;
    procedure UpsertMainFromLoadResult6Statement_UpdatesStageFields;
    procedure UpsertMainFromLoadResult3Statement_UpdatesStageFields;
    procedure UpsertMainFromLoadResult2Statement_UpdatesStageFields;
    procedure AddDayNormalizeStatements_NormalizeLoadValues;
    procedure AddDayInsertLoadHeaderAndValuesRowFromEscaped_InsertRows;
    procedure AddDayUpsertSumdays_UpsertsAndAccumulates;
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

procedure TDbSqlTests.ExecCreateTables_InMemoryDatabase_CreatesSchemaAndDefaults;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 2, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');

  AssertTableExists('main');
  AssertTableExists('load');
  AssertTableExists('loadresult');
  AssertTableExists('start');
  AssertTableExists('finish');
  AssertTableExists('config');
  AssertTableExists('lora');

  AssertConfigValue('activestage', '1');
  AssertConfigValue('stage1', 'True');
  AssertConfigValue('catname1', 'Cat A');
  AssertConfigValue('catname5', 'Cat E');
  AssertConfigValue('racename', 'Race One');

  AssertColumnExists('load', 'starttime1', True);
  AssertColumnExists('load', 'starttime2', True);
  AssertColumnExists('load', 'starttime3', False);
  AssertColumnExists('main', 'sumplace', True);
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

procedure TMainSqlTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
  ExecSql(TSumDaysSql.CreateTableIfNotExists);
end;

procedure TMainSqlTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TMainSqlTests.ExecSqlFmt(const AFormat: string;
  const AArgs: array of const);
begin
  ExecSql(Format(AFormat, AArgs));
end;

procedure TMainSqlTests.InsertMainRow(const ANumber: integer;
  const ACategory: string; const AName: string);
begin
  ExecSqlFmt(
    'INSERT INTO main (category, number, name) VALUES (%s, %d, %s);',
    [QuotedStr(ACategory), ANumber, QuotedStr(AName)]);
end;

procedure TMainSqlTests.OpenMainByNumber(const ANumber: integer);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT * FROM main WHERE number = :NUMBER;';
  FQuery.ParamByName('NUMBER').AsInteger := ANumber;
  FQuery.Open;
  AssertFalse(Format('Row with number %d was not found.', [ANumber]), FQuery.EOF);
end;

procedure TMainSqlTests.AssertFieldEquals(const AFieldName, AExpected: string);
begin
  AssertEquals(AExpected, FQuery.FieldByName(AFieldName).AsString);
end;

procedure TMainSqlTests.AssertFieldEqualsInt(const AFieldName: string;
  const AExpected: integer);
begin
  AssertEquals(AExpected, FQuery.FieldByName(AFieldName).AsInteger);
end;

procedure TMainSqlTests.AssertFieldNull(const AFieldName: string);
begin
  AssertTrue(
    Format('Field "%s" must be NULL.', [AFieldName]),
    FQuery.FieldByName(AFieldName).IsNull);
end;

procedure TMainSqlTests.SetUp;
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

procedure TMainSqlTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TMainSqlTests.OpenByNumber_ReturnsTrueForExistingAndFalseForMissing;
begin
  InsertMainRow(101);

  AssertTrue(TMainSql.OpenByNumber(FQuery, 101));
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  AssertFalse(TMainSql.OpenByNumber(FQuery, 999));
end;

procedure TMainSqlTests.OpenByCategoryLeader_ReturnsLeaderAndReturnsFalseWhenMissing;
begin
  InsertMainRow(101, 'elite', 'Leader');
  InsertMainRow(102, 'elite', 'Rider');
  ExecSql('UPDATE main SET place1 = 1 WHERE number = 101;');
  ExecSql('UPDATE main SET place1 = 2 WHERE number = 102;');

  AssertTrue(TMainSql.OpenByCategoryLeader(FQuery, 1, 'elite'));
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  AssertFalse(TMainSql.OpenByCategoryLeader(FQuery, 1, 'missing'));
end;

procedure TMainSqlTests.TryGetNumberByStartTimeBetween_ReturnsMatchAndNoMatch;
var
  Number: integer;
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET starttime1 = ''10:00:00.000'' WHERE number = 101;');

  AssertTrue(
    TMainSql.TryGetNumberByStartTimeBetween(FQuery, 1,
    '09:59:59.000', '10:00:01.000', Number));
  AssertEquals(101, Number);

  AssertFalse(
    TMainSql.TryGetNumberByStartTimeBetween(FQuery, 1,
    '10:05:00.000', '10:06:00.000', Number));
  AssertEquals(0, Number);
end;

procedure TMainSqlTests.GetFinishCount_CountsOnlyNonEmptyFinishTimes;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  ExecSql('UPDATE main SET finishtime1 = ''10:03:12.123'' WHERE number = 101;');
  ExecSql('UPDATE main SET finishtime1 = '''' WHERE number = 102;');
  ExecSql('UPDATE main SET finishtime1 = NULL WHERE number = 103;');

  AssertEquals(1, TMainSql.GetFinishCount(FQuery, 1));
end;

procedure TMainSqlTests.GetPenaltyGroupsCount_CountsDistinctPenaltyCombinations;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  ExecSql('UPDATE main SET penalty1 = ''10'', penalty2 = ''0'' WHERE number IN (101, 102);');
  ExecSql('UPDATE main SET penalty1 = ''20'', penalty2 = ''0'' WHERE number = 103;');

  AssertEquals(2, TMainSql.GetPenaltyGroupsCount(FQuery));
end;

procedure TMainSqlTests.ExecUpdateStartTimeForNumber_SetsStartAndClearsStageStatus;
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET status1 = ''1'' WHERE number = 101;');

  TMainSql.ExecUpdateStartTimeForNumber(FQuery, 1, '10:00:00.000', 101);

  OpenMainByNumber(101);
  AssertFieldEquals('starttime1', '10:00:00.000');
  AssertFieldNull('status1');
end;

procedure TMainSqlTests.ExecUpdateCorrection_SetsCorrectionValue;
begin
  InsertMainRow(101);

  TMainSql.ExecUpdateCorrection(FQuery, 1, -456, 101);

  OpenMainByNumber(101);
  AssertFieldEqualsInt('correction1', -456);
end;

procedure TMainSqlTests.ExecUpdateFinishForCheckedStages_UpdatesSpecifiedStages;
const
  Stages: array[0..1] of integer = (1, 2);
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET status1 = ''1'', status2 = ''1'' WHERE number = 101;');

  TMainSql.ExecUpdateFinishForCheckedStages(FQuery, Stages, '11:11:11.111', 101);

  OpenMainByNumber(101);
  AssertFieldEquals('finishtime1', '11:11:11.111');
  AssertFieldEquals('finishtime2', '11:11:11.111');
  AssertFieldNull('status1');
  AssertFieldNull('status2');
end;

procedure TMainSqlTests.ExecUpdateFinishForCheckedStages_EmptyStages_NoChanges;
var
  EmptyStages: array of integer;
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET finishtime1 = ''x'' WHERE number = 101;');
  SetLength(EmptyStages, 0);

  TMainSql.ExecUpdateFinishForCheckedStages(FQuery, EmptyStages, '11:11:11.111', 101);

  OpenMainByNumber(101);
  AssertFieldEquals('finishtime1', 'x');
end;

procedure TMainSqlTests.ExecUpdateStageStatus_SetsStageResultAndClearsPlaceDiff;
begin
  InsertMainRow(101);
  ExecSql(
    'UPDATE main SET place1 = 5, diffleader1 = ''00:00:10.000'' WHERE number = 101;');

  TMainSql.ExecUpdateStageStatus(FQuery, 1, 'DNF', '1', '101');

  OpenMainByNumber(101);
  AssertFieldEquals('result1', 'DNF');
  AssertFieldEquals('status1', '1');
  AssertFieldNull('place1');
  AssertFieldNull('diffleader1');
end;

procedure TMainSqlTests.ExecUpdateOnlyGlobalStatusDsq_SetsStatusTo3;
begin
  InsertMainRow(101);

  TMainSql.ExecUpdateOnlyGlobalStatusDsq(FQuery, '101');

  OpenMainByNumber(101);
  AssertFieldEquals('status', '3');
end;

procedure TMainSqlTests.ExecUpdateGlobalStatus_SetsNumericAndClearsOnNULLKeyword;
begin
  InsertMainRow(101);

  TMainSql.ExecUpdateGlobalStatus(FQuery, '2', '101');
  OpenMainByNumber(101);
  AssertFieldEquals('status', '2');

  TMainSql.ExecUpdateGlobalStatus(FQuery, 'NULL', '101');
  OpenMainByNumber(101);
  AssertFieldNull('status');
end;

procedure TMainSqlTests.ExecClearOnlyGlobalStatus_ClearsGlobalStatus;
begin
  InsertMainRow(101);
  ExecSql('UPDATE main SET status = ''2'' WHERE number = 101;');

  TMainSql.ExecClearOnlyGlobalStatus(FQuery, '101');

  OpenMainByNumber(101);
  AssertFieldNull('status');
end;

procedure TMainSqlTests.ExecClearStageStatus_ClearsOnlyStageFields;
begin
  InsertMainRow(101);
  ExecSql(
    'UPDATE main SET result1 = ''DNF'', place1 = 5, diffleader1 = ''00:00:10.000'', ' +
    'status1 = ''1'', status = ''2'' WHERE number = 101;');

  TMainSql.ExecClearStageStatus(FQuery, 1, '101');

  OpenMainByNumber(101);
  AssertFieldNull('result1');
  AssertFieldNull('place1');
  AssertFieldNull('diffleader1');
  AssertFieldNull('status1');
  AssertFieldEquals('status', '2');
end;

procedure TMainSqlTests.ExecClearStatusAllForStage_ClearsStageAndGlobalStatus;
begin
  InsertMainRow(101);
  ExecSql(
    'UPDATE main SET result1 = ''DNF'', place1 = 5, diffleader1 = ''00:00:10.000'', ' +
    'status1 = ''1'', status = ''2'' WHERE number = 101;');

  TMainSql.ExecClearStatusAllForStage(FQuery, 1, '101');

  OpenMainByNumber(101);
  AssertFieldNull('result1');
  AssertFieldNull('place1');
  AssertFieldNull('diffleader1');
  AssertFieldNull('status1');
  AssertFieldNull('status');
end;

procedure TMainSqlTests.SelectAll_ReturnsInsertedRows;
var
  Seen101: boolean;
  Seen102: boolean;
begin
  InsertMainRow(101);
  InsertMainRow(102);

  Seen101 := False;
  Seen102 := False;
  FQuery.Close;
  FQuery.SQL.Text := TMainSql.SelectAll;
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

procedure TMainSqlTests.SelectNumbers_ReturnsOnlyParticipantNumbers;
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
  FQuery.SQL.Text := TMainSql.SelectNumbers;
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

procedure TMainSqlTests.ResetStartTime_ClearsStageStartTimeForAllRows;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  ExecSql('UPDATE main SET starttime1 = ''10:00:00.000'' WHERE number = 101;');
  ExecSql('UPDATE main SET starttime1 = ''10:05:00.000'' WHERE number = 102;');

  ExecSql(TMainSql.ResetStartTime(1));

  OpenMainByNumber(101);
  AssertFieldNull('starttime1');
  OpenMainByNumber(102);
  AssertFieldNull('starttime1');
end;

procedure TMainSqlTests.UpdateStartTime_SetsStageStartTimeForSpecificNumber;
begin
  InsertMainRow(101);
  InsertMainRow(102);

  FQuery.Close;
  FQuery.SQL.Text := TMainSql.UpdateStartTime(1);
  FQuery.ParamByName('STARTTIME').AsString := '11:11:11.111';
  FQuery.ParamByName('NUMBER').AsInteger := 102;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;

  OpenMainByNumber(101);
  AssertFieldNull('starttime1');
  OpenMainByNumber(102);
  AssertFieldEquals('starttime1', '11:11:11.111');
end;

procedure TMainSqlTests.SelectMinStartTime_ReturnsEarliestNonNullStartTime;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  ExecSql('UPDATE main SET starttime1 = ''10:10:10.100'' WHERE number = 101;');
  ExecSql('UPDATE main SET starttime1 = ''09:09:09.090'' WHERE number = 102;');
  ExecSql('UPDATE main SET starttime1 = NULL WHERE number = 103;');

  FQuery.Close;
  FQuery.SQL.Text := TMainSql.SelectMinStartTime(1);
  FQuery.Open;
  AssertEquals('09:09:09.090', FQuery.FieldByName('starttime').AsString);
  FQuery.Close;
end;

procedure TMainSqlTests.SelectMaxNumber_ReturnsMaximumNumber;
begin
  InsertMainRow(17);
  InsertMainRow(99);
  InsertMainRow(42);

  FQuery.Close;
  FQuery.SQL.Text := TMainSql.SelectMaxNumber;
  FQuery.Open;
  AssertEquals(99, FQuery.FieldByName('number').AsInteger);
  FQuery.Close;
end;

procedure TMainSqlTests.SelectCategoryGrouped_ReturnsDistinctCategories;
var
  Count: integer;
begin
  InsertMainRow(101, 'elite');
  InsertMainRow(102, 'elite');
  InsertMainRow(103, 'sport');

  Count := 0;
  FQuery.Close;
  FQuery.SQL.Text := TMainSql.SelectCategoryGrouped;
  FQuery.Open;
  while not FQuery.EOF do
  begin
    Inc(Count);
    FQuery.Next;
  end;
  FQuery.Close;

  AssertEquals(2, Count);
end;

procedure TMainSqlTests.SelectCategoryGroupedOrderedByStartTime_OrdersByStageStartTime;
begin
  InsertMainRow(101, 'elite');
  InsertMainRow(201, 'sport');
  ExecSql('UPDATE main SET starttime1 = ''10:00:00.000'' WHERE number = 101;');
  ExecSql('UPDATE main SET starttime1 = ''09:00:00.000'' WHERE number = 201;');

  FQuery.Close;
  FQuery.SQL.Text := TMainSql.SelectCategoryGroupedOrderedByStartTime(1);
  FQuery.Open;
  AssertEquals('sport', FQuery.FieldByName('category').AsString);
  FQuery.Next;
  AssertEquals('elite', FQuery.FieldByName('category').AsString);
  FQuery.Close;
end;

procedure TMainSqlTests.SelectCategoryResults_FiltersByCategoryAndSorts;
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
  FQuery.SQL.Text := TMainSql.SelectCategoryResults('number, sumplace, sumresult');
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

procedure TMainSqlTests.SelectStatusAll_ReturnsOnlyRowsWithGlobalStatus;
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
  FQuery.SQL.Text := TMainSql.SelectStatusAll;
  FQuery.Open;
  while not FQuery.EOF do
  begin
    Inc(Count);
    FQuery.Next;
  end;
  FQuery.Close;

  AssertEquals(2, Count);
end;

procedure TMainSqlTests.SelectStatusByStage_ReturnsOnlyRowsWithStageStatus;
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
  FQuery.SQL.Text := TMainSql.SelectStatusByStage(1);
  FQuery.Open;
  while not FQuery.EOF do
  begin
    Inc(Count);
    FQuery.Next;
  end;
  FQuery.Close;

  AssertEquals(2, Count);
end;

procedure TMainSqlTests.ExportFinishTime_ReturnsRequestedStageColumns;
begin
  InsertMainRow(101);
  ExecSql(
    'UPDATE main SET starttime2 = ''10:00:00.000'', correction2 = -5, ' +
    'finishtime2 = ''10:05:00.000'', penalty2 = ''00:00:10.000'', status2 = ''1'' ' +
    'WHERE number = 101;');

  FQuery.Close;
  FQuery.SQL.Text := TMainSql.ExportFinishTime(2);
  FQuery.Open;
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  AssertEquals('10:00:00.000', FQuery.FieldByName('starttime2').AsString);
  AssertEquals(-5, FQuery.FieldByName('correction2').AsInteger);
  AssertEquals('10:05:00.000', FQuery.FieldByName('finishtime2').AsString);
  AssertEquals('00:00:10.000', FQuery.FieldByName('penalty2').AsString);
  AssertEquals('1', FQuery.FieldByName('status2').AsString);
  FQuery.Close;
end;

procedure TMainSqlTests.ExportAllResults_ReturnsSummaryColumns;
begin
  InsertMainRow(101);
  ExecSql(
    'UPDATE main SET sumresult = ''00:30:00.000'', sumstages = 2, status = ''2'' ' +
    'WHERE number = 101;');

  FQuery.Close;
  FQuery.SQL.Text := TMainSql.ExportAllResults;
  FQuery.Open;
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  AssertEquals('00:30:00.000', FQuery.FieldByName('sumresult').AsString);
  AssertEquals(2, FQuery.FieldByName('sumstages').AsInteger);
  AssertEquals('2', FQuery.FieldByName('status').AsString);
  FQuery.Close;
end;

procedure TMainSqlTests.ExportSumDays_JoinsMainAndSumDays;
begin
  InsertMainRow(101, 'elite', 'A');
  InsertMainRow(102, 'sport', 'B');
  ExecSql(
    'INSERT INTO sumdays (number, place, sumresult, sumstages, status) VALUES ' +
    '(101, 1, ''00:10:00.000'', 3, ''0''), (102, 2, ''00:20:00.000'', 2, ''1'');');

  FQuery.Close;
  FQuery.SQL.Text := TMainSql.ExportSumDays;
  FQuery.Open;
  AssertEquals('elite', FQuery.FieldByName('category').AsString);
  AssertEquals(1, FQuery.FieldByName('place').AsInteger);
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals('sport', FQuery.FieldByName('category').AsString);
  AssertEquals(2, FQuery.FieldByName('place').AsInteger);
  AssertEquals(102, FQuery.FieldByName('number').AsInteger);
  FQuery.Close;
end;

procedure TSumDaysSqlTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
end;

procedure TSumDaysSqlTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TSumDaysSqlTests.ExecSqlFmt(const AFormat: string;
  const AArgs: array of const);
begin
  ExecSql(Format(AFormat, AArgs));
end;

procedure TSumDaysSqlTests.InsertMainRow(const ANumber: integer;
  const ACategory: string);
begin
  ExecSqlFmt(
    'INSERT INTO main (category, number, name) VALUES (%s, %d, ''Rider'');',
    [QuotedStr(ACategory), ANumber]);
end;

procedure TSumDaysSqlTests.InsertSumDaysRow(const ANumber: integer;
  const ASumResult: string; const ASumStages: integer; const APlaceSql: string);
begin
  ExecSqlFmt(
    'INSERT INTO sumdays (number, sumresult, sumstages, place) VALUES (%d, %s, %d, %s);',
    [ANumber, QuotedStr(ASumResult), ASumStages, APlaceSql]);
end;

procedure TSumDaysSqlTests.OpenSumDaysByNumber(const ANumber: integer);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT * FROM sumdays WHERE number = :NUMBER;';
  FQuery.ParamByName('NUMBER').AsInteger := ANumber;
  FQuery.Open;
  AssertFalse(
    Format('sumdays row for number %d not found.', [ANumber]),
    FQuery.EOF);
end;

procedure TSumDaysSqlTests.AssertSumDaysPlaceEquals(
  const ANumber, AExpected: integer);
begin
  OpenSumDaysByNumber(ANumber);
  AssertEquals(AExpected, FQuery.FieldByName('place').AsInteger);
end;

procedure TSumDaysSqlTests.AssertSumDaysPlaceNull(const ANumber: integer);
begin
  OpenSumDaysByNumber(ANumber);
  AssertTrue(
    Format('Expected NULL place for number %d.', [ANumber]),
    FQuery.FieldByName('place').IsNull);
end;

procedure TSumDaysSqlTests.SetUp;
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

procedure TSumDaysSqlTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TSumDaysSqlTests.CreateTableIfNotExists_CreatesSumDaysTable;
begin
  ExecSql(TSumDaysSql.CreateTableIfNotExists);

  FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = ''sumdays'';';
  FQuery.Open;
  AssertFalse('sumdays table was not created.', FQuery.EOF);
  AssertEquals('sumdays', FQuery.FieldByName('name').AsString);
end;

procedure TSumDaysSqlTests.DeleteAll_RemovesAllRows;
begin
  ExecSql(TSumDaysSql.CreateTableIfNotExists);
  InsertSumDaysRow(101, '00:10:00.000', 2, '1');
  InsertSumDaysRow(102, '00:11:00.000', 2, '2');

  ExecSql(TSumDaysSql.DeleteAll);

  FQuery.Close;
  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM sumdays;';
  FQuery.Open;
  AssertEquals(0, FQuery.FieldByName('cnt').AsInteger);
end;

procedure TSumDaysSqlTests.UpsertPlacesByCategory_AssignsPlacesByCategoryAndMaxStages;
begin
  ExecSql(TSumDaysSql.CreateTableIfNotExists);

  InsertMainRow(101, 'elite');
  InsertMainRow(102, 'elite');
  InsertMainRow(103, 'elite');
  InsertMainRow(104, 'sport');
  InsertMainRow(105, 'sport');

  InsertSumDaysRow(101, '00:10:00.000', 2, '99');
  InsertSumDaysRow(102, '00:12:00.000', 2, '99');
  InsertSumDaysRow(103, '00:09:30.000', 1, 'NULL');
  InsertSumDaysRow(104, '00:11:00.000', 2, '99');
  InsertSumDaysRow(105, '00:10:30.000', 2, '99');

  ExecSql(TSumDaysSql.UpsertPlacesByCategory);

  AssertSumDaysPlaceEquals(101, 1);
  AssertSumDaysPlaceEquals(102, 2);
  AssertSumDaysPlaceNull(103);
  AssertSumDaysPlaceEquals(105, 1);
  AssertSumDaysPlaceEquals(104, 2);
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
  AssertTrue(Assigned(FQuery.FindField('correction1')));
  AssertFalse(Assigned(FQuery.FindField('name')));
  AssertEquals(2, CountRows(TDatasetSql.CorrectionPending(1)));

  OpenBySql(TDatasetSql.CorrectionPending(1));
  AssertEquals(105, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(101, FQuery.FieldByName('number').AsInteger);
end;

procedure TDatasetSqlTests.TrackStatus_ReturnsStartedRowsWithoutFinishAndWithoutStageStatus;
begin
  InsertMainRow(201);
  InsertMainRow(202);
  InsertMainRow(203);
  InsertMainRow(204);
  InsertMainRow(205);
  ExecSql('UPDATE main SET starttime1 = time(''now'', ''localtime'', ''-00:10:00'') WHERE number = 201;');
  ExecSql('UPDATE main SET starttime1 = time(''now'', ''localtime'', ''+00:10:00'') WHERE number = 202;');
  ExecSql('UPDATE main SET starttime1 = time(''now'', ''localtime'', ''-00:05:00''), finishtime1 = ''10:10:10.100'' WHERE number = 203;');
  ExecSql('UPDATE main SET starttime1 = time(''now'', ''localtime'', ''-00:06:00''), status1 = ''1'' WHERE number = 204;');
  ExecSql('UPDATE main SET starttime1 = time(''now'', ''localtime'', ''-00:20:00'') WHERE number = 205;');

  AssertEquals(2, CountRows(TDatasetSql.TrackStatus(1)));

  OpenBySql(TDatasetSql.TrackStatus(1));
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

  AssertEquals(4, CountRows(TDatasetSql.ResultStageSum));

  OpenBySql(TDatasetSql.ResultStageSum);
  AssertEquals(14, FQuery.Fields.Count);
  AssertTrue(Assigned(FQuery.FindField('result8')));
  AssertFalse(Assigned(FQuery.FindField('status')));
  AssertEquals(502, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(501, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(503, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertEquals(504, FQuery.FieldByName('number').AsInteger);
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

procedure TSchemaSqlStatementTests.VacuumInto_CreatesBackupFile;
var
  BackupPath: string;
begin
  BackupPath := FDbFilePath + '.backup';
  if FileExists(BackupPath) then
    DeleteFile(BackupPath);

  FConnection.ExecuteDirect(TSchemaSql.EndTransaction);
  FConnection.ExecuteDirect(TSchemaSql.VacuumInto(BackupPath));
  FConnection.ExecuteDirect(TSchemaSql.BeginTransaction);

  AssertTrue(FileExists(BackupPath));
  DeleteFile(BackupPath);
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

  FQuery.Close;
  FQuery.SQL.Text := TStartlistSql.SelectNumbersForCategory(
    STARTLIST_SORT_BY_NUMBER_ASC, True, True, True);
  FQuery.ParamByName('CATEGORY').AsString := 'elite';
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

procedure TLoRaSqlTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
end;

procedure TLoRaSqlTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TLoRaSqlTests.OpenBySql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.Open;
end;

procedure TLoRaSqlTests.SetUp;
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

procedure TLoRaSqlTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TLoRaSqlTests.SelectPendingAndSelectAll_ReturnExpectedRows;
var
  Count: integer;
begin
  ExecSql(
    'INSERT INTO lora (number, starttime, isset, timemark) VALUES ' +
    '(101, ''10:00:00.000'', NULL, ''a''), ' +
    '(102, ''10:01:00.000'', 0, ''b''), ' +
    '(103, ''10:02:00.000'', 1, ''c'');');

  Count := 0;
  OpenBySql(TLoRaSql.SelectPending);
  while not FQuery.EOF do
  begin
    Inc(Count);
    FQuery.Next;
  end;
  AssertEquals(1, Count);

  Count := 0;
  OpenBySql(TLoRaSql.SelectAll);
  while not FQuery.EOF do
  begin
    Inc(Count);
    FQuery.Next;
  end;
  AssertEquals(3, Count);
end;

procedure TLoRaSqlTests.SelectStartAfter_FiltersByStartTime;
begin
  ExecSql(
    'INSERT INTO lora (number, starttime, isset, timemark) VALUES ' +
    '(101, ''10:00:00.000'', 0, ''a''), ' +
    '(102, ''10:05:00.000'', 0, ''b''), ' +
    '(103, ''10:10:00.000'', 0, ''c'');');

  FQuery.Close;
  FQuery.SQL.Text := TLoRaSql.SelectStartAfter;
  FQuery.ParamByName('STARTTIME').AsString := '10:05:00.000';
  FQuery.Open;
  AssertEquals(103, FQuery.FieldByName('number').AsInteger);
  FQuery.Next;
  AssertTrue(FQuery.EOF);
  FQuery.Close;
end;

procedure TLoRaSqlTests.ResetIsSetNull_UpdatesOnlyNullRows;
begin
  ExecSql(
    'INSERT INTO lora (number, starttime, isset, timemark) VALUES ' +
    '(101, ''10:00:00.000'', NULL, ''a''), ' +
    '(102, ''10:01:00.000'', 1, ''b'');');

  ExecSql(TLoRaSql.ResetIsSetNull);

  OpenBySql('SELECT isset FROM lora WHERE number = 101;');
  AssertEquals(0, FQuery.FieldByName('isset').AsInteger);
  OpenBySql('SELECT isset FROM lora WHERE number = 102;');
  AssertEquals(1, FQuery.FieldByName('isset').AsInteger);
end;

procedure TLoRaSqlTests.SetIsSetById_UpdatesOnlyTargetRow;
var
  TargetId: integer;
begin
  ExecSql(
    'INSERT INTO lora (number, starttime, isset, timemark) VALUES ' +
    '(201, ''11:00:00.000'', 1, ''x''), ' +
    '(202, ''11:01:00.000'', 2, ''y'');');

  OpenBySql('SELECT id FROM lora WHERE number = 202;');
  TargetId := FQuery.FieldByName('id').AsInteger;

  FQuery.Close;
  FQuery.SQL.Text := TLoRaSql.SetIsSetById;
  FQuery.ParamByName('ID').AsInteger := TargetId;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;

  OpenBySql('SELECT isset FROM lora WHERE number = 201;');
  AssertEquals(1, FQuery.FieldByName('isset').AsInteger);
  OpenBySql('SELECT isset FROM lora WHERE number = 202;');
  AssertEquals(0, FQuery.FieldByName('isset').AsInteger);
end;

procedure TLoRaSqlTests.ExecSetIsSetByIdAndValue_UpdatesTargetRow;
var
  TargetId: integer;
begin
  ExecSql(
    'INSERT INTO lora (number, starttime, isset, timemark) VALUES ' +
    '(301, ''12:00:00.000'', 0, ''m'');');
  OpenBySql('SELECT id FROM lora WHERE number = 301;');
  TargetId := FQuery.FieldByName('id').AsInteger;

  TLoRaSql.ExecSetIsSetByIdAndValue(FQuery, 7, TargetId);

  OpenBySql('SELECT isset FROM lora WHERE number = 301;');
  AssertEquals(7, FQuery.FieldByName('isset').AsInteger);
end;

procedure TLoRaSqlTests.ExecInsertSample_InsertsWithAndWithoutNumber;
begin
  TLoRaSql.ExecInsertSample(FQuery, True, 55, '10:00:00.000', -3, 'tm1');
  TLoRaSql.ExecInsertSample(FQuery, False, 0, '10:01:00.000', 4, 'tm2');

  OpenBySql('SELECT number, correction FROM lora WHERE timemark = ''tm1'';');
  AssertEquals(55, FQuery.FieldByName('number').AsInteger);
  AssertEquals('-3', FQuery.FieldByName('correction').AsString);

  OpenBySql('SELECT number, correction FROM lora WHERE timemark = ''tm2'';');
  AssertTrue(FQuery.FieldByName('number').IsNull);
  AssertEquals('4', FQuery.FieldByName('correction').AsString);
end;

procedure TResultsSqlTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
  ExecSql(TSumDaysSql.CreateTableIfNotExists);
end;

procedure TResultsSqlTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TResultsSqlTests.ExecSqlFmt(const AFormat: string;
  const AArgs: array of const);
begin
  ExecSql(Format(AFormat, AArgs));
end;

procedure TResultsSqlTests.InsertMainRow(const ANumber: integer;
  const ACategory: string; const AName: string);
begin
  ExecSqlFmt(
    'INSERT INTO main (category, number, name) VALUES (%s, %d, %s);',
    [QuotedStr(ACategory), ANumber, QuotedStr(AName)]);
end;

procedure TResultsSqlTests.OpenMainByNumber(const ANumber: integer);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT * FROM main WHERE number = :NUMBER;';
  FQuery.ParamByName('NUMBER').AsInteger := ANumber;
  FQuery.Open;
  AssertFalse(FQuery.EOF);
end;

procedure TResultsSqlTests.SetUp;
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

procedure TResultsSqlTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TResultsSqlTests.UpdateStageResult_HandlesStatusesAndTimeCalculations;
begin
  InsertMainRow(101);
  InsertMainRow(102);
  InsertMainRow(103);
  InsertMainRow(104);
  ExecSql(
    'UPDATE main SET starttime1 = ''10:00:00.000'', finishtime1 = ''10:02:00.000'', status = ''3'' WHERE number = 101;');
  ExecSql(
    'UPDATE main SET starttime1 = ''10:00:00.000'', finishtime1 = ''10:03:00.000'', status1 = ''1'' WHERE number = 102;');
  ExecSql(
    'UPDATE main SET starttime1 = ''10:00:00.000'', finishtime1 = ''10:04:00.000'', status1 = ''2'' WHERE number = 103;');
  ExecSql(
    'UPDATE main SET starttime1 = ''10:00:00.000'', finishtime1 = ''10:01:00.000'', status1 = NULL, correction1 = NULL, penalty1 = NULL WHERE number = 104;');

  ExecSql(TResultsSql.UpdateStageResult(1));

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

procedure TResultsSqlTests.SelectForSumCalculation_ReturnsOnlyRequestedStageResults;
begin
  InsertMainRow(110);
  ExecSql(
    'UPDATE main SET result1 = ''00:01:00.000'', ' +
    'result2 = ''00:02:00.000'', result3 = ''00:03:00.000'', ' +
    'status = ''1'' WHERE number = 110;');

  FQuery.Close;
  FQuery.SQL.Text := TResultsSql.SelectForSumCalculation([1, 3]);
  FQuery.Open;
  AssertEquals(4, FQuery.Fields.Count);
  AssertEquals(110, FQuery.FieldByName('number').AsInteger);
  AssertEquals('1', FQuery.FieldByName('status').AsString);
  AssertEquals('00:01:00.000', FQuery.FieldByName('result1').AsString);
  AssertEquals('00:03:00.000', FQuery.FieldByName('result3').AsString);
  AssertFalse(Assigned(FQuery.FindField('result2')));
end;

procedure TResultsSqlTests.UpdateSumResult_UpdatesValuesAndPreservesStatusConditionally;
begin
  InsertMainRow(111);
  InsertMainRow(112);
  ExecSql('UPDATE main SET status = ''1'' WHERE number = 111;');
  ExecSql('UPDATE main SET status = ''3'' WHERE number = 112;');

  FQuery.Close;
  FQuery.SQL.Text := TResultsSql.UpdateSumResult;
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

procedure TResultsSqlTests.ResetStagePlaceAndDiff_AndUpsertStagePlace_AssignsPlaces;
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

  ExecSql(TResultsSql.ResetStagePlaceAndDiff(1));
  ExecSql(TResultsSql.UpsertStagePlace(1));

  OpenMainByNumber(201);
  AssertEquals(1, FQuery.FieldByName('place1').AsInteger);
  OpenMainByNumber(202);
  AssertEquals(2, FQuery.FieldByName('place1').AsInteger);
  OpenMainByNumber(203);
  AssertEquals(1, FQuery.FieldByName('place1').AsInteger);
end;

procedure TResultsSqlTests.ResetStageDiffLeader_AndUpsertStageDiffLeader_SetsLeaderDiff;
begin
  InsertMainRow(301, 'elite');
  InsertMainRow(302, 'elite');
  ExecSql(
    'UPDATE main SET result1 = ''00:01:00.000'', place1 = 1, diffleader1 = ''not_null'' WHERE number = 301;');
  ExecSql(
    'UPDATE main SET result1 = ''00:01:20.000'', place1 = 2, diffleader1 = NULL WHERE number = 302;');

  ExecSql(TResultsSql.ResetStageDiffLeader(1));
  ExecSql(TResultsSql.UpsertStageDiffLeader(1));

  OpenMainByNumber(301);
  AssertTrue(FQuery.FieldByName('diffleader1').IsNull);
  OpenMainByNumber(302);
  AssertTrue(FQuery.FieldByName('diffleader1').AsString <> '');
end;

procedure TResultsSqlTests.ResetSumPlaceAndDiff_AndUpsertSumPlaceOnlyFullStages_AssignsSumPlace;
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

  ExecSql(TResultsSql.ResetSumPlaceAndDiff);
  ExecSql(TResultsSql.UpsertSumPlaceOnlyFullStages(ActiveStages));

  OpenMainByNumber(401);
  AssertEquals(1, FQuery.FieldByName('sumplace').AsInteger);
  OpenMainByNumber(402);
  AssertEquals(2, FQuery.FieldByName('sumplace').AsInteger);
  OpenMainByNumber(403);
  AssertTrue(FQuery.FieldByName('sumplace').IsNull);
end;

procedure TResultsSqlTests.ResetSumDiffLeader_AndUpsertSumDiffLeader_SetsSumDiff;
begin
  InsertMainRow(501, 'elite');
  InsertMainRow(502, 'elite');
  ExecSql(
    'UPDATE main SET sumresult = ''00:10:00.000'', sumplace = 1, sumdiffleader = ''x'' WHERE number = 501;');
  ExecSql(
    'UPDATE main SET sumresult = ''00:11:00.000'', sumplace = 2, sumdiffleader = NULL WHERE number = 502;');

  ExecSql(TResultsSql.ResetSumDiffLeader);
  ExecSql(TResultsSql.UpsertSumDiffLeader);

  OpenMainByNumber(501);
  AssertTrue(FQuery.FieldByName('sumdiffleader').IsNull);
  OpenMainByNumber(502);
  AssertTrue(FQuery.FieldByName('sumdiffleader').AsString <> '');
end;

procedure TResultsSqlTests.UpsertSumDiffByStages_SetsStageGapText;
begin
  InsertMainRow(601, 'elite');
  InsertMainRow(602, 'elite');
  ExecSql(
    'UPDATE main SET sumstages = 5, sumplace = 1, status = NULL WHERE number = 601;');
  ExecSql(
    'UPDATE main SET sumstages = 3, sumplace = NULL, status = NULL WHERE number = 602;');

  ExecSql(TResultsSql.UpsertSumDiffByStages('stages'));

  OpenMainByNumber(602);
  AssertEquals(1, Pos('+', FQuery.FieldByName('sumdiffleader').AsString));
  AssertTrue(Pos('stages', FQuery.FieldByName('sumdiffleader').AsString) > 0);
end;

procedure TResultsSqlTests.ResetThru_AndUpsertThruPlace_AssignsThruPlace;
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

  ExecSql(TResultsSql.ResetThru);
  ExecSql(TResultsSql.UpsertThruPlace);

  OpenMainByNumber(703);
  AssertEquals(1, FQuery.FieldByName('thruplace').AsInteger);
  OpenMainByNumber(701);
  AssertEquals(2, FQuery.FieldByName('thruplace').AsInteger);
  OpenMainByNumber(702);
  AssertEquals(3, FQuery.FieldByName('thruplace').AsInteger);
end;

procedure TResultsSqlTests.UpsertThruDiff_AndUpsertThruDiffByStages_SetsThruDiff;
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

  ExecSql(TResultsSql.UpsertThruPlace);
  ExecSql(TResultsSql.UpsertThruDiff);

  OpenMainByNumber(802);
  AssertTrue(FQuery.FieldByName('thrudiff').AsString <> '');

  ExecSql(TResultsSql.UpsertThruDiffByStages('stages'));

  OpenMainByNumber(803);
  AssertEquals(1, Pos('+', FQuery.FieldByName('thrudiff').AsString));
  AssertTrue(Pos('stages', FQuery.FieldByName('thrudiff').AsString) > 0);
end;

procedure TResultsSqlTests.ClearResultsPrefixStageSuffix_ClearsResultsColumns;
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
  FQuery.SQL.Add(TResultsSql.ClearResultsPrefix);
  FQuery.SQL.Add(TResultsSql.ClearResultsStagePart(1));
  FQuery.SQL.Add(TResultsSql.ClearResultsStagePart(2));
  FQuery.SQL.Add(TResultsSql.ClearResultsSuffix);
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

procedure TLoadSqlTests.CreateSchema;
begin
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 8, 'Cat A', 'Cat B',
    'Cat C', 'Cat D', 'Cat E', 'Race One');
  ExecSql(TSumDaysSql.CreateTableIfNotExists);
end;

procedure TLoadSqlTests.ExecSql(const ASql: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASql;
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;
  FQuery.Close;
end;

procedure TLoadSqlTests.ExecSqlFmt(const AFormat: string;
  const AArgs: array of const);
begin
  ExecSql(Format(AFormat, AArgs));
end;

procedure TLoadSqlTests.InsertMainRow(const ANumber: integer;
  const ACategory: string; const AName: string);
begin
  ExecSqlFmt(
    'INSERT INTO main (category, number, name) VALUES (%s, %d, %s);',
    [QuotedStr(ACategory), ANumber, QuotedStr(AName)]);
end;

procedure TLoadSqlTests.OpenMainByNumber(const ANumber: integer);
begin
  FQuery.Close;
  FQuery.SQL.Text := 'SELECT * FROM main WHERE number = :NUMBER;';
  FQuery.ParamByName('NUMBER').AsInteger := ANumber;
  FQuery.Open;
  AssertFalse(FQuery.EOF);
end;

procedure TLoadSqlTests.SetUp;
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

procedure TLoadSqlTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TLoadSqlTests.ExecDeleteLoadAndLoadResult_RemoveRows;
begin
  ExecSql('INSERT INTO load (category, number, name) VALUES (''elite'', 1, ''A'');');
  ExecSql(
    'INSERT INTO loadresult (number, starttime, correction, finishtime, penalty, status) ' +
    'VALUES (1, ''10:00:00.000'', 0, ''10:10:00.000'', ''0'', ''0'');');

  TLoadSql.ExecDeleteLoad(FQuery);
  TLoadSql.ExecDeleteLoadResult(FQuery);

  FQuery.Close;
  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM load;';
  FQuery.Open;
  AssertEquals(0, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;

  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM loadresult;';
  FQuery.Open;
  AssertEquals(0, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;
end;

procedure TLoadSqlTests.InsertLoadHeaderAndExecInsertLoadMainFromLoad_ImportsAndUpsertsRows;
begin
  ExecSql(
    TLoadSql.InsertLoadHeader(2) +
    ' (''elite'', 101, ''Name A'', ''N'', ''20'', ''T'', ''C'', ''P'', ''E'', ''Comm'', ''10:00:00.000'', ''10:10:00.000''), ' +
    ' (''elite'', 102, ''Name B'', ''N'', ''21'', ''T'', ''C'', ''P'', ''E'', ''Comm'', ''11:00:00.000'', ''11:10:00.000'');');

  TLoadSql.ExecInsertLoadMainFromLoad(FQuery, 2);

  OpenMainByNumber(101);
  AssertEquals('Name A', FQuery.FieldByName('name').AsString);
  AssertEquals('10:00:00.000', FQuery.FieldByName('starttime1').AsString);
  AssertEquals('10:10:00.000', FQuery.FieldByName('starttime2').AsString);

  ExecSql('UPDATE load SET name = ''Name A2'' WHERE number = 101;');
  TLoadSql.ExecInsertLoadMainFromLoad(FQuery, 2);
  OpenMainByNumber(101);
  AssertEquals('Name A2', FQuery.FieldByName('name').AsString);
end;

procedure TLoadSqlTests.InsertLoadRow_ParametersPreserveSqlSensitiveCharacters;
begin
  FQuery.SQL.Text := TLoadSql.InsertLoadRow(2);
  FQuery.ParamByName('CATEGORY').AsString := 'Masters';
  FQuery.ParamByName('NUMBER').AsInteger := 99;
  FQuery.ParamByName('NAME').AsString := 'O''Connor';
  FQuery.ParamByName('NICKNAME').AsString := '';
  FQuery.ParamByName('AGE').AsString := '';
  FQuery.ParamByName('TEAM').AsString := 'RiderShop&amp;Service';
  FQuery.ParamByName('CITY').AsString := 'Tashkent';
  FQuery.ParamByName('PHONE').AsString := '';
  FQuery.ParamByName('EMAIL').AsString := '';
  FQuery.ParamByName('COMMENT').AsString := 'Text; "quoted"';
  FQuery.ParamByName('STARTTIME1').AsString := '11:30:00';
  FQuery.ParamByName('STARTTIME2').AsString := '12:20:00';
  FQuery.ExecSQL;
  FQuery.SQLTransaction.Commit;

  FQuery.Close;
  FQuery.SQL.Text :=
    'SELECT name, team, comment FROM load WHERE number = 99;';
  FQuery.Open;
  AssertFalse(FQuery.IsEmpty);
  AssertEquals('O''Connor', FQuery.FieldByName('name').AsString);
  AssertEquals('RiderShop&amp;Service',
    FQuery.FieldByName('team').AsString);
  AssertEquals('Text; "quoted"',
    FQuery.FieldByName('comment').AsString);
  FQuery.Close;
end;

procedure TLoadSqlTests.InsertLoadResultHeaders_AreExecutableFor6And3And2Columns;
begin
  ExecSql(
    TLoadSql.InsertLoadResultHeader6 +
    ' (201, ''10:00:00.000'', 0, ''10:10:00.000'', ''0'', ''0'');');
  ExecSql('DELETE FROM loadresult;');

  ExecSql(
    TLoadSql.InsertLoadResultHeader3 +
    ' (202, ''10:01:00.000'', -1, ''2'');');
  ExecSql('DELETE FROM loadresult;');

  ExecSql(
    TLoadSql.InsertLoadResultHeader2 +
    ' (203, ''10:02:00.000'', ''1'');');

  FQuery.Close;
  FQuery.SQL.Text := 'SELECT number, finishtime, status FROM loadresult;';
  FQuery.Open;
  AssertEquals(203, FQuery.FieldByName('number').AsInteger);
  AssertEquals('10:02:00.000', FQuery.FieldByName('finishtime').AsString);
  AssertEquals('1', FQuery.FieldByName('status').AsString);
  FQuery.Close;
end;

procedure TLoadSqlTests.InsertLoadResultRows_ParametersPreserveValuesAndNulls;
begin
  FQuery.Close;
  FQuery.SQL.Text := TLoadSql.InsertLoadResultRow6;
  FQuery.Prepare;
  FQuery.ParamByName('NUMBER').AsInteger := 211;
  FQuery.ParamByName('STARTTIME').AsString := '10:00:00';
  FQuery.ParamByName('CORRECTION').Clear;
  FQuery.ParamByName('FINISHTIME').AsString := '11:00:00.123';
  FQuery.ParamByName('PENALTY').AsString := 'Text; ''quoted''';
  FQuery.ParamByName('STATUS').Clear;
  FQuery.ExecSQL;
  FQuery.UnPrepare;

  FQuery.SQL.Text := TLoadSql.InsertLoadResultRow3;
  FQuery.Prepare;
  FQuery.ParamByName('NUMBER').AsInteger := 212;
  FQuery.ParamByName('STARTTIME').Clear;
  FQuery.ParamByName('CORRECTION').AsInteger := -250;
  FQuery.ParamByName('STATUS').AsInteger := 2;
  FQuery.ExecSQL;
  FQuery.UnPrepare;

  FQuery.SQL.Text := TLoadSql.InsertLoadResultRow2;
  FQuery.Prepare;
  FQuery.ParamByName('NUMBER').AsInteger := 213;
  FQuery.ParamByName('FINISHTIME').AsString := '12:00:00.456';
  FQuery.ParamByName('STATUS').Clear;
  FQuery.ExecSQL;
  FQuery.UnPrepare;
  FQuery.SQLTransaction.Commit;

  FQuery.SQL.Text :=
    'SELECT starttime, correction, finishtime, penalty, status ' +
    'FROM loadresult WHERE number = 211;';
  FQuery.Open;
  AssertEquals('10:00:00', FQuery.FieldByName('starttime').AsString);
  AssertTrue(FQuery.FieldByName('correction').IsNull);
  AssertEquals('11:00:00.123', FQuery.FieldByName('finishtime').AsString);
  AssertEquals('Text; ''quoted''', FQuery.FieldByName('penalty').AsString);
  AssertTrue(FQuery.FieldByName('status').IsNull);
  FQuery.Close;

  FQuery.SQL.Text :=
    'SELECT starttime, correction, status FROM loadresult WHERE number = 212;';
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('starttime').IsNull);
  AssertEquals(-250, FQuery.FieldByName('correction').AsInteger);
  AssertEquals(2, FQuery.FieldByName('status').AsInteger);
  FQuery.Close;

  FQuery.SQL.Text :=
    'SELECT finishtime, status FROM loadresult WHERE number = 213;';
  FQuery.Open;
  AssertEquals('12:00:00.456', FQuery.FieldByName('finishtime').AsString);
  AssertTrue(FQuery.FieldByName('status').IsNull);
  FQuery.Close;
end;

procedure TLoadSqlTests.UpsertMainFromLoadResult6Statement_UpdatesStageFields;
begin
  ExecSql(
    'INSERT INTO loadresult (number, starttime, correction, finishtime, penalty, status) VALUES ' +
    '(301, ''10:00:00.000'', 5, ''10:10:00.000'', ''0'', ''1'');');
  ExecSql(TLoadSql.UpsertMainFromLoadResult6Statement(1));

  OpenMainByNumber(301);
  AssertEquals('10:00:00.000', FQuery.FieldByName('starttime1').AsString);
  AssertEquals(5, FQuery.FieldByName('correction1').AsInteger);
  AssertEquals('10:10:00.000', FQuery.FieldByName('finishtime1').AsString);
  AssertEquals('0', FQuery.FieldByName('penalty1').AsString);
  AssertEquals('1', FQuery.FieldByName('status1').AsString);

  ExecSql(
    'UPDATE loadresult SET correction = -7, status = ''2'' WHERE number = 301;');
  ExecSql(TLoadSql.UpsertMainFromLoadResult6Statement(1));
  OpenMainByNumber(301);
  AssertEquals(-7, FQuery.FieldByName('correction1').AsInteger);
  AssertEquals('2', FQuery.FieldByName('status1').AsString);
end;

procedure TLoadSqlTests.UpsertMainFromLoadResult3Statement_UpdatesStageFields;
begin
  ExecSql(
    'INSERT INTO loadresult (number, starttime, correction, status) VALUES ' +
    '(401, ''10:11:00.000'', -3, ''1'');');
  ExecSql(TLoadSql.UpsertMainFromLoadResult3Statement(2));

  OpenMainByNumber(401);
  AssertEquals('10:11:00.000', FQuery.FieldByName('starttime2').AsString);
  AssertEquals(-3, FQuery.FieldByName('correction2').AsInteger);
  AssertEquals('1', FQuery.FieldByName('status2').AsString);
end;

procedure TLoadSqlTests.UpsertMainFromLoadResult2Statement_UpdatesStageFields;
begin
  ExecSql(
    'INSERT INTO loadresult (number, finishtime, status) VALUES ' +
    '(501, ''12:12:12.120'', ''3'');');
  ExecSql(TLoadSql.UpsertMainFromLoadResult2Statement(3));

  OpenMainByNumber(501);
  AssertEquals('12:12:12.120', FQuery.FieldByName('finishtime3').AsString);
  AssertEquals('3', FQuery.FieldByName('status3').AsString);
end;

procedure TLoadSqlTests.AddDayNormalizeStatements_NormalizeLoadValues;
begin
  ExecSql(
    'INSERT INTO load (number, starttime1, age, starttime2) VALUES ' +
    '(601, ''DNF'', '''', '''');');

  ExecSql(TLoadSql.AddDayNormalizeResult);
  ExecSql(TLoadSql.AddDayNormalizeStages);
  ExecSql(TLoadSql.AddDayNormalizeStatus);

  FQuery.Close;
  FQuery.SQL.Text := 'SELECT starttime1, age, starttime2 FROM load WHERE number = 601;';
  FQuery.Open;
  AssertEquals('00:00:00.000', FQuery.FieldByName('starttime1').AsString);
  AssertEquals('0', FQuery.FieldByName('age').AsString);
  AssertEquals('0', FQuery.FieldByName('starttime2').AsString);
  FQuery.Close;
end;

procedure TLoadSqlTests.AddDayInsertLoadHeaderAndValuesRowFromEscaped_InsertRows;
begin
  ExecSql(
    TLoadSql.AddDayInsertLoadHeader +
    TLoadSql.ValuesRowFromEscaped('701'',''00:10:00.000'',''1'',''0') + ', ' +
    TLoadSql.ValuesRowFromEscaped('702'',''00:11:00.000'',''2'',''1') + ';');

  FQuery.Close;
  FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM load WHERE number IN (701, 702);';
  FQuery.Open;
  AssertEquals(2, FQuery.FieldByName('cnt').AsInteger);
  FQuery.Close;
end;

procedure TLoadSqlTests.AddDayUpsertSumdays_UpsertsAndAccumulates;
begin
  ExecSql(
    'INSERT INTO load (number, starttime1, age, starttime2) VALUES ' +
    '(801, ''00:10:00.000'', ''1'', ''0'');');

  ExecSql(TLoadSql.AddDayUpsertSumdays);

  FQuery.Close;
  FQuery.SQL.Text := 'SELECT sumresult, sumstages, status FROM sumdays WHERE number = 801;';
  FQuery.Open;
  AssertEquals('00:10:00.000', FQuery.FieldByName('sumresult').AsString);
  AssertEquals(1, FQuery.FieldByName('sumstages').AsInteger);
  AssertEquals('0', FQuery.FieldByName('status').AsString);
  FQuery.Close;

  ExecSql(
    'UPDATE load SET starttime1 = ''00:05:00.000'', age = ''2'', starttime2 = ''1'' ' +
    'WHERE number = 801;');
  ExecSql(TLoadSql.AddDayUpsertSumdays);

  FQuery.Close;
  FQuery.SQL.Text := 'SELECT sumresult, sumstages, status FROM sumdays WHERE number = 801;';
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('sumresult').AsString <> '');
  AssertEquals(3, FQuery.FieldByName('sumstages').AsInteger);
  AssertEquals('1', FQuery.FieldByName('status').AsString);
  FQuery.Close;
end;

initialization
  RegisterTest(TDbSqlTests);
  RegisterTest(TConfigSqlTests);
  RegisterTest(TMainSqlTests);
  RegisterTest(TSumDaysSqlTests);
  RegisterTest(TDatasetSqlTests);
  RegisterTest(TSchemaSqlStatementTests);
  RegisterTest(TStartlistSqlTests);
  RegisterTest(TLoRaSqlTests);
  RegisterTest(TResultsSqlTests);
  RegisterTest(TLoadSqlTests);

end.
