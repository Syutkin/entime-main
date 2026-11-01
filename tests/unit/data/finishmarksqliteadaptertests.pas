unit FinishMarkSqliteAdapterTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, FPCUnit, TestRegistry, SQLDB,
  CompetitionDbContext, CompetitionSchemaMigrator, TimingMark, FinishMark,
  FinishMarkService, FinishMarkSqliteAdapters;

type
  TFinishMarkSqliteAdapterTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FPersistence: IFinishMarkPersistence;
    FQuery: TSQLQuery;
    FService: TFinishMarkService;
    function MarkAt(const ATime: TDateTime): TFinishMark;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Handle_PersistsPendingAndDebouncedMarks;
  end;

implementation

procedure TFinishMarkSqliteAdapterTests.SetUp;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  inherited SetUp;
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FQuery := FContext.CreateQuery(nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, 2,
      'A', 'B', 'C', 'D', 'E', 'Finish adapter test');
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
  FPersistence := TSqliteFinishMarkPersistence.Create(FContext);
  FService := TFinishMarkService.Create(FPersistence, 250);
end;

procedure TFinishMarkSqliteAdapterTests.TearDown;
begin
  FService.Free;
  FPersistence := nil;
  FQuery.Free;
  FContext.Free;
  inherited TearDown;
end;

function TFinishMarkSqliteAdapterTests.MarkAt(const ATime: TDateTime): TFinishMark;
begin
  Result := TFinishMark.FromTimingMark(TTimingMark.Finish(ATime,
    TTimingMarkSource.Serial('COM7'), EncodeDateTime(2026, 8, 15, 10, 0, 0, 0)), 2);
end;

procedure TFinishMarkSqliteAdapterTests.
Handle_PersistsPendingAndDebouncedMarks;
var
  BaseTime: TDateTime;
begin
  BaseTime := EncodeTime(10, 0, 0, 0);
  FService.Handle(MarkAt(BaseTime), True);
  FService.Handle(MarkAt(IncMilliSecond(BaseTime, 100)), False);

  FQuery.SQL.Text :=
    'SELECT status, diagnostic FROM finish_marks ORDER BY id;';
  FQuery.Open;
  AssertFalse(FQuery.EOF);
  AssertEquals('pending', FQuery.FieldByName('status').AsString);
  AssertTrue(FQuery.FieldByName('diagnostic').IsNull);
  FQuery.Next;
  AssertFalse(FQuery.EOF);
  AssertEquals('ignored_debounce',
    FQuery.FieldByName('status').AsString);
  AssertEquals('debounce_interval_ms=250; elapsed_ms=100',
    FQuery.FieldByName('diagnostic').AsString);
  FQuery.Next;
  AssertTrue(FQuery.EOF);
  FQuery.Close;
end;

initialization
  RegisterTest(TFinishMarkSqliteAdapterTests);

end.
