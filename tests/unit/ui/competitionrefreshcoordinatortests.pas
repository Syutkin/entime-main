unit CompetitionRefreshCoordinatorTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, SQLDB, fpcunit, testregistry, DbSql,
  CompetitionRefreshCoordinator;

type
  TCompetitionRefreshCoordinatorTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FMainQuery: TSQLQuery;
    FValidQuery: TSQLQuery;
    FBrokenQuery: TSQLQuery;
    procedure CreateFixture;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure RefreshAll_ContinuesAfterQueryErrorAndRestoresParticipant;
  end;

implementation

procedure TCompetitionRefreshCoordinatorTests.SetUp;
begin
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FMainQuery := FContext.CreateQuery(nil);
  FValidQuery := FContext.CreateQuery(nil);
  FBrokenQuery := FContext.CreateQuery(nil);
  CreateFixture;
end;

procedure TCompetitionRefreshCoordinatorTests.TearDown;
begin
  FBrokenQuery.Free;
  FValidQuery.Free;
  FMainQuery.Free;
  FContext.Free;
end;

procedure TCompetitionRefreshCoordinatorTests.CreateFixture;
var
  Query: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Query := FContext.CreateQuery(nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    Query.SQL.Text :=
      'CREATE TABLE sample (id INTEGER PRIMARY KEY, number INTEGER);';
    Query.ExecSQL;
    Query.SQL.Text :=
      'INSERT INTO sample (id, number) VALUES (1, 101), (2, 102);';
    Query.ExecSQL;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Query.Free;
  end;
  FMainQuery.SQL.Text :=
    'SELECT id, number FROM sample ORDER BY number DESC;';
  FMainQuery.Open;
  AssertTrue(FMainQuery.Locate('id', 1, []));
  FValidQuery.SQL.Text := 'SELECT COUNT(*) AS item_count FROM sample;';
  FValidQuery.Open;
  FBrokenQuery.SQL.Text := 'SELECT * FROM missing_refresh_table;';
end;

procedure TCompetitionRefreshCoordinatorTests.
  RefreshAll_ContinuesAfterQueryErrorAndRestoresParticipant;
var
  Outcome: TCompetitionRefreshOutcome;
begin
  Outcome := TCompetitionRefreshCoordinator.RefreshAll(FContext,
    FMainQuery, [FBrokenQuery, FValidQuery], [], nil);

  AssertEquals(1, Outcome.ErrorCount);
  AssertTrue(Pos('missing_refresh_table', Outcome.Errors) > 0);
  AssertTrue(FValidQuery.Active);
  AssertEquals(2, FValidQuery.FieldByName('item_count').AsInteger);
  AssertTrue(Outcome.HadCurrentParticipant);
  AssertTrue(Outcome.CurrentParticipantRestored);
  AssertEquals(1, FMainQuery.FieldByName('id').AsInteger);
  FMainQuery.First;
  AssertEquals(102, FMainQuery.FieldByName('number').AsInteger);
end;

initialization
  RegisterTest(TCompetitionRefreshCoordinatorTests);

end.
