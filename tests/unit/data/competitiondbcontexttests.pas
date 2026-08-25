unit CompetitionDbContextTests;

{$mode ObjFPC}{$H+}

interface

uses
  fpcunit, testregistry, DB, sqldb, CompetitionDbContext;

type
  TCompetitionDbContextTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FWriter: TSQLQuery;
    FReader: TSQLQuery;
    procedure CreateTable;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure CreateQuery_UsesOwnedConnectionAndTransaction;
    procedure OpenConnection_OpensConfiguredDatabase;
    procedure OpenConnection_AppliesBusyTimeout;
    procedure OpenConnection_RejectsMissingDatabaseFile;
    procedure UnitOfWorkCommit_DoesNotRefreshQueries;
    procedure RefreshQueries_ContinuesAfterQueryError;
    procedure RegisteredUiQuery_RemainsActiveAfterCommit;
    procedure RegisteredQuery_CanBeFreedBeforeContext;
    procedure UnitOfWorkDestructor_RollsBackUncommittedChanges;
    procedure NestedUnitOfWork_IsRejected;
  end;

implementation

procedure TCompetitionDbContextTests.SetUp;
begin
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FWriter := FContext.CreateQuery(nil);
  FReader := FContext.CreateQuery(nil);
end;

procedure TCompetitionDbContextTests.TearDown;
begin
  FContext.Free;
  FWriter.Free;
  FReader.Free;
end;

procedure TCompetitionDbContextTests.CreateTable;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    FWriter.SQL.Text := 'CREATE TABLE sample (id INTEGER PRIMARY KEY, value TEXT);';
    FWriter.ExecSQL;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
end;

procedure TCompetitionDbContextTests.CreateQuery_UsesOwnedConnectionAndTransaction;
begin
  AssertTrue(FContext.Connection.Connected);
  AssertSame(FContext.Connection, FWriter.Database);
  AssertSame(FContext.Transaction, FWriter.Transaction);
end;

procedure TCompetitionDbContextTests.OpenConnection_OpensConfiguredDatabase;
begin
  FContext.CloseFile;
  FContext.SetDatabaseFile(':memory:');
  AssertFalse(FContext.Connection.Connected);

  FContext.OpenConnection;

  AssertTrue(FContext.Connection.Connected);
end;

procedure TCompetitionDbContextTests.OpenConnection_AppliesBusyTimeout;
begin
  FReader.SQL.Text := 'PRAGMA busy_timeout;';
  FReader.Open;

  AssertEquals(DEFAULT_SQLITE_BUSY_TIMEOUT_MS,
    FReader.Fields[0].AsInteger);
end;

procedure TCompetitionDbContextTests.OpenConnection_RejectsMissingDatabaseFile;
begin
  FContext.CloseFile;
  try
    FContext.OpenConnection;
    Fail('A database file must be assigned before opening');
  except
    on E: EDatabaseError do
      AssertTrue(Pos('must be assigned', E.Message) > 0);
  end;
end;

procedure TCompetitionDbContextTests.UnitOfWorkCommit_DoesNotRefreshQueries;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  CreateTable;
  FContext.RegisterUiQuery(FReader);
  FReader.SQL.Text := 'SELECT COUNT(*) AS item_count FROM sample;';
  FReader.Open;
  AssertTrue('The reader must be active before the write', FReader.Active);
  AssertEquals(0, FReader.FieldByName('item_count').AsInteger);

  UnitOfWork := FContext.BeginUnitOfWork;
  try
    FWriter.SQL.Text := 'INSERT INTO sample (value) VALUES (''saved'');';
    FWriter.ExecSQL;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;

  AssertTrue('The reader must remain active after commit', FReader.Active);
  AssertEquals('Commit must not implicitly refresh datasets', 0,
    FReader.FieldByName('item_count').AsInteger);

  FContext.RefreshQuery(FReader);
  AssertEquals('An explicit refresh must see the committed row', 1,
    FReader.FieldByName('item_count').AsInteger);
end;

procedure TCompetitionDbContextTests.RefreshQueries_ContinuesAfterQueryError;
var
  BrokenReader: TSQLQuery;
  Errors: string;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  CreateTable;
  BrokenReader := FContext.CreateQuery(nil);
  try
    BrokenReader.SQL.Text := 'SELECT * FROM missing_table;';
    FReader.SQL.Text := 'SELECT COUNT(*) AS item_count FROM sample;';
    FReader.Open;

    UnitOfWork := FContext.BeginUnitOfWork;
    try
      FWriter.SQL.Text := 'INSERT INTO sample (value) VALUES (''saved'');';
      FWriter.ExecSQL;
      UnitOfWork.Commit;
    finally
      UnitOfWork.Free;
    end;

    AssertEquals('Exactly one refresh must fail', 1,
      FContext.RefreshQueries([BrokenReader, FReader], Errors));
    AssertTrue('The refresh error must identify the missing table',
      Pos('missing_table', Errors) > 0);
    AssertTrue('A query after the failed one must still be refreshed',
      FReader.Active);
    AssertEquals('The successful refresh must see committed data', 1,
      FReader.FieldByName('item_count').AsInteger);
  finally
    BrokenReader.Free;
  end;
end;

procedure TCompetitionDbContextTests.RegisteredUiQuery_RemainsActiveAfterCommit;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  CreateTable;
  FContext.RegisterUiQuery(FReader);
  FReader.SQL.Text := 'SELECT * FROM sample ORDER BY id;';
  FReader.Open;

  UnitOfWork := FContext.BeginUnitOfWork;
  try
    FWriter.SQL.Text := 'INSERT INTO sample (value) VALUES (''saved'');';
    FWriter.ExecSQL;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;

  AssertTrue('A UI query must stay active across a shared transaction commit',
    FReader.Active);
end;

procedure TCompetitionDbContextTests.RegisteredQuery_CanBeFreedBeforeContext;
begin
  FReader.Free;
  FReader := nil;

  FContext.CloseFile;
  AssertFalse(FContext.Connection.Connected);
end;

procedure TCompetitionDbContextTests.UnitOfWorkDestructor_RollsBackUncommittedChanges;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  CreateTable;
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    FWriter.SQL.Text := 'INSERT INTO sample (value) VALUES (''discarded'');';
    FWriter.ExecSQL;
  finally
    UnitOfWork.Free;
  end;

  FReader.SQL.Text := 'SELECT COUNT(*) AS item_count FROM sample;';
  FReader.Open;
  AssertEquals(0, FReader.FieldByName('item_count').AsInteger);
end;

procedure TCompetitionDbContextTests.NestedUnitOfWork_IsRejected;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    try
      FContext.BeginUnitOfWork.Free;
      Fail('A nested unit of work must be rejected');
    except
      on E: EDatabaseError do
        AssertTrue(Pos('already active', E.Message) > 0);
    end;
  finally
    UnitOfWork.Free;
  end;
end;

initialization
  RegisterTest(TCompetitionDbContextTests);

end.
