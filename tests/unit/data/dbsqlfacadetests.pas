unit DbSqlFacadeTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, FpcUnit, TestRegistry, SQLite3Conn, SQLDB, DbSql,
  ParticipantStatus, StartItemModel;

type
  TDbSqlFacadeTests = class(TTestCase)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;
    procedure ExecSql(const SqlText: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ConfigAndSchemaApi_RemainsAvailableThroughFacade;
    procedure StartMarkApi_RemainsAvailableThroughFacade;
    procedure FinishMarkApi_RemainsAvailableThroughFacade;
    procedure ParticipantAndStageApi_RemainsAvailableThroughFacade;
    procedure ResultCalculationApi_RemainsAvailableThroughFacade;
    procedure ImportAndDatasetApi_RemainsAvailableThroughFacade;
  end;

implementation

procedure TDbSqlFacadeTests.SetUp;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);
  FConnection.DatabaseName := ':memory:';
  FConnection.Transaction := FTransaction;
  FConnection.Open;
  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;
  FTransaction.Active := True;
  TSchemaSql.ExecCreateTables(FConnection, 2, 'A', 'B', 'C', 'D', 'E',
    'Facade race');
end;

procedure TDbSqlFacadeTests.TearDown;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
end;

procedure TDbSqlFacadeTests.ExecSql(const SqlText: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := SqlText;
  FQuery.ExecSQL;
  FQuery.Close;
end;

procedure TDbSqlFacadeTests.ConfigAndSchemaApi_RemainsAvailableThroughFacade;
var
  Context: TCompetitionDbContext;
begin
  Context := TCompetitionDbContext.Create;
  Context.Free;
  AssertEquals(1, CURRENT_COMPETITION_SCHEMA_VERSION);
  AssertEquals('Facade race', TConfigSql.GetString(FQuery, 'racename', ''));
  TConfigSql.ExecUpsertByKey(FQuery, 'custom', 'value');
  AssertEquals('value', TConfigSql.GetString(FQuery, 'custom', ''));
  AssertEquals(2, TSchemaSql.DetectStageCapacity(FQuery));
  AssertEquals(2, TSchemaSql.LoadConfiguredStageCount(FQuery));
  AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION,
    TSchemaSql.LoadSchemaVersion(FQuery));
  TSchemaSql.EnsureStageCapacity(FQuery, 3);
  TSchemaSql.AddStageColumns(FQuery, 3);
  AssertEquals(3, TSchemaSql.DetectStageCapacity(FQuery));
  AssertEquals('Begin Transaction', TSchemaSql.BeginTransaction);
end;

procedure TDbSqlFacadeTests.StartMarkApi_RemainsAvailableThroughFacade;
begin
  AssertEquals(
    'SELECT * FROM start_marks ORDER BY received_at DESC, id DESC;',
    TStartMarkSql.SelectJournal);
  AssertEquals(
    'SELECT * FROM start_marks WHERE status = ''pending'' ' +
    'ORDER BY received_at DESC, id DESC;',
    TStartMarkSql.SelectJournal(smjfPending));
end;

procedure TDbSqlFacadeTests.FinishMarkApi_RemainsAvailableThroughFacade;
begin
  AssertEquals(
    'SELECT * FROM finish_marks ORDER BY received_at, id;',
    TFinishMarkSql.SelectAll);
  AssertEquals(
    'SELECT id, event_time, participant_number FROM finish_marks ' +
    'WHERE status = ''pending'' ORDER BY received_at, id;',
    TFinishMarkSql.SelectWorkQueue);
end;

procedure TDbSqlFacadeTests.ParticipantAndStageApi_RemainsAvailableThroughFacade;
var
  Numbers: TStringList;
  ParticipantName, Category: string;
  StageData: TParticipantStageData;
  GlobalStatus: TParticipantStatus;
  StageStatuses: TParticipantStatusArray;
  StatusRows: TParticipantStatusRows;
  ActiveStageIndexes: array[0..0] of integer;
begin
  ExecSql('INSERT INTO main (number, category, name) VALUES ' +
    '(101, ''A'', ''Rider'');');
  AssertFalse(TMainSql.HasAnyDataInStageRange(FQuery, 1, 2, 2));
  TMainSql.ExecUpdateCorrection(FQuery, 2, -1500, 101, 2);
  TMainSql.ExecUpdateStageStatus(FQuery, 2, psDNF, '101', 2);
  AssertFalse(TMainSql.HasAnyDataInStageRange(FQuery, 1, 1, 2));
  AssertTrue(TMainSql.HasAnyDataInStageRange(FQuery, 2, 2, 2));
  AssertTrue(TMainSql.TryLoadIdentity(FQuery, 101, ParticipantName, Category));
  AssertEquals('Rider', ParticipantName);
  AssertEquals('A', Category);
  AssertTrue(TMainSql.TryLoadParticipantStageData(FQuery, 101, 2, 2, StageData));
  AssertTrue(StageData.HasCorrection);
  AssertEquals(-1500, StageData.Correction);
  AssertEquals(Ord(psDNF), Ord(StageData.Status));
  AssertTrue(TMainSql.LoadStatuses(FQuery, 101, 2, GlobalStatus, StageStatuses));
  AssertEquals(2, Length(StageStatuses));
  AssertEquals(Ord(psDNF), Ord(StageStatuses[1]));
  ActiveStageIndexes[0] := 2;
  TMainSql.LoadAllStatuses(FQuery, 2, ActiveStageIndexes, StatusRows);
  AssertEquals(1, Length(StatusRows));
  AssertEquals(101, StatusRows[0].Number);
  AssertEquals(Ord(psDNF), Ord(StatusRows[0].StageStatuses[1]));
  TMainSql.PrepareGlobalStatusUpdates(FQuery);
  try
    TMainSql.ExecPreparedGlobalStatusUpdate(FQuery, psDNF, 101);
  finally
    TMainSql.FinishPreparedGlobalStatusUpdates(FQuery);
  end;
  AssertTrue(TMainSql.LoadStatuses(FQuery, 101, 2, GlobalStatus, StageStatuses));
  AssertEquals(Ord(psDNF), Ord(GlobalStatus));
  Numbers := TStringList.Create;
  try
    TMainSql.LoadNumbers(FQuery, Numbers);
    AssertEquals(1, Numbers.Count);
    AssertEquals('101', Numbers[0]);
  finally
    Numbers.Free;
  end;
end;

procedure TDbSqlFacadeTests.ResultCalculationApi_RemainsAvailableThroughFacade;
begin
  ExecSql('INSERT INTO main (number, category, starttime1, finishtime1) ' +
    'VALUES (201, ''A'', ''10:00:00.000'', ''10:10:00.000'');');
  TResultsSql.ExecCalculateStage(FQuery, 1, 2);
  FQuery.SQL.Text := 'SELECT result1 FROM main WHERE number = 201;';
  FQuery.Open;
  AssertEquals('00:10:00.000', FQuery.FieldByName('result1').AsString);
  FQuery.Close;
  TResultsSql.ExecClearResults(FQuery, 2);
end;

procedure TDbSqlFacadeTests.ImportAndDatasetApi_RemainsAvailableThroughFacade;
var
  StartItem: TStartItemModel;
  ImportRow: TStageResultImportRow;
  Snapshot: TQuerySnapshot;
  ColumnIndex, NumberColumnIndex, FinishColumnIndex: integer;
begin
  StartItem := TStartItemModel.Create;
  try
    StartItem.number := 301;
    StartItem.category := 'B';
    StartItem.Name := 'Imported';
    StartItem.startTimes.Add('11:00:00.000');
    TImportSql.PrepareParticipantRows(FQuery, 2);
    TImportSql.ExecPreparedParticipantRow(FQuery, StartItem, 2);
    TImportSql.FinishPreparedRows(FQuery);
  finally
    StartItem.Free;
  end;
  ImportRow.ParticipantNumber := 301;
  ImportRow.StartTime := '';
  ImportRow.HasCorrection := False;
  ImportRow.Correction := 0;
  ImportRow.FinishTime := '12:00:00.000';
  ImportRow.Penalty := '';
  ImportRow.HasStatus := False;
  ImportRow.Status := psNone;
  TImportSql.PrepareStageResultRows(FQuery, srifFinish, 2, 2);
  TImportSql.ExecPreparedStageResultRow(FQuery, ImportRow, srifFinish);
  TImportSql.FinishPreparedRows(FQuery);

  TDatasetSql.ConfigureMainParticipants(FQuery, [1, 2]);
  Snapshot := TDatasetSql.Capture(FQuery, True, True);
  AssertEquals(1, Length(Snapshot.Rows));
  NumberColumnIndex := -1;
  FinishColumnIndex := -1;
  for ColumnIndex := 0 to High(Snapshot.ColumnNames) do
  begin
    if Snapshot.ColumnNames[ColumnIndex] = 'number' then
      NumberColumnIndex := ColumnIndex;
    if Snapshot.ColumnNames[ColumnIndex] = 'finishtime2' then
      FinishColumnIndex := ColumnIndex;
  end;
  AssertTrue('number column must be present', NumberColumnIndex >= 0);
  AssertTrue('finishtime2 column must be present', FinishColumnIndex >= 0);
  AssertEquals('301', Snapshot.Rows[0][NumberColumnIndex]);
  AssertEquals('12:00:00.000', Snapshot.Rows[0][FinishColumnIndex]);
end;

initialization
  RegisterTest(TDbSqlFacadeTests);

end.
