unit CompetitionLifecycleServiceTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, fpcunit, testregistry, DbSql, StageConfig,
  CompetitionLifecycleService;

type
  TCompetitionLifecycleServiceTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FQuery: TSQLQuery;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure OpenNew_CreatesVersionedSchema;
    procedure OpenExisting_MigratesSchemaAfterBackup;
    procedure OpenExisting_CurrentVersionCreatesMissingStartMarks;
    procedure OpenExisting_CurrentVersionCreatesMissingFinishMarks;
    procedure SaveAndLoadConfiguration_ExpandsCapacityAndMapsValues;
  end;

implementation

var
  BackupRequested: boolean = False;

function AcceptBackup: boolean;
begin
  BackupRequested := True;
  Result := True;
end;

procedure TCompetitionLifecycleServiceTests.
OpenExisting_CurrentVersionCreatesMissingFinishMarks;
var
  Preparation: TCompetitionPreparation;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  TCompetitionLifecycleService.OpenCompetition(FContext, False,
    DEFAULT_STAGE_COUNT, ['A', 'B', 'C', 'D', 'E'], 'Test race', nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    FQuery.SQL.Text := 'DROP TABLE finish_marks;';
    FQuery.ExecSQL;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
  BackupRequested := False;

  Preparation := TCompetitionLifecycleService.OpenCompetition(FContext,
    True, DEFAULT_STAGE_COUNT, ['A', 'B', 'C', 'D', 'E'], 'Ignored', @AcceptBackup);

  AssertTrue(BackupRequested);
  AssertTrue(Preparation.Migrated);
  AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION, Preparation.SchemaVersion);
  FQuery.SQL.Text :=
    'SELECT name FROM sqlite_master WHERE type = ''table'' ' +
    'AND name = ''finish_marks'';';
  FQuery.Open;
  AssertFalse(FQuery.EOF);
  FQuery.Close;
end;

procedure TCompetitionLifecycleServiceTests.
OpenExisting_CurrentVersionCreatesMissingStartMarks;
var
  Preparation: TCompetitionPreparation;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  TCompetitionLifecycleService.OpenCompetition(FContext, False,
    DEFAULT_STAGE_COUNT, ['A', 'B', 'C', 'D', 'E'], 'Test race', nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    FQuery.SQL.Text := 'DROP TABLE start_marks;';
    FQuery.ExecSQL;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
  BackupRequested := False;

  Preparation := TCompetitionLifecycleService.OpenCompetition(FContext,
    True, DEFAULT_STAGE_COUNT, ['A', 'B', 'C', 'D', 'E'], 'Ignored', @AcceptBackup);

  AssertTrue(BackupRequested);
  AssertTrue(Preparation.Migrated);
  AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION,
    Preparation.SchemaVersion);
  FQuery.SQL.Text :=
    'SELECT name FROM sqlite_master ' +
    'WHERE type = ''table'' AND name = ''start_marks'';';
  FQuery.Open;
  AssertFalse(FQuery.EOF);
  FQuery.Close;
end;

procedure TCompetitionLifecycleServiceTests.SetUp;
begin
  FContext := TCompetitionDbContext.Create;
  FContext.SetDatabaseFile(':memory:');
  FQuery := FContext.CreateQuery(nil);
  BackupRequested := False;
end;

procedure TCompetitionLifecycleServiceTests.
OpenExisting_MigratesSchemaAfterBackup;
var
  Preparation: TCompetitionPreparation;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  TCompetitionLifecycleService.OpenCompetition(FContext, False,
    DEFAULT_STAGE_COUNT, ['A', 'B', 'C', 'D', 'E'], 'Test race', nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    FQuery.SQL.Text :=
      'DELETE FROM config WHERE key IN (''stagecount'', ''schema_version'');';
    FQuery.ExecSQL;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;

  Preparation := TCompetitionLifecycleService.OpenCompetition(FContext,
    True, DEFAULT_STAGE_COUNT, ['A', 'B', 'C', 'D', 'E'], 'Ignored', @AcceptBackup);

  AssertTrue(BackupRequested);
  AssertTrue(Preparation.Migrated);
  AssertFalse(Preparation.Created);
  AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION,
    Preparation.SchemaVersion);
  AssertEquals(DEFAULT_STAGE_COUNT, Preparation.RequiredStageCount);
end;

procedure TCompetitionLifecycleServiceTests.TearDown;
begin
  FQuery.Free;
  FContext.Free;
end;

procedure TCompetitionLifecycleServiceTests.OpenNew_CreatesVersionedSchema;
var
  Preparation: TCompetitionPreparation;
begin
  Preparation := TCompetitionLifecycleService.OpenCompetition(FContext,
    False, DEFAULT_STAGE_COUNT, ['A', 'B', 'C', 'D', 'E'], 'Test race', nil);

  AssertEquals(DEFAULT_STAGE_COUNT, Preparation.RequiredStageCount);
  AssertEquals(DEFAULT_STAGE_COUNT, Preparation.PhysicalStageCount);
  AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION,
    Preparation.SchemaVersion);
  AssertTrue(Preparation.Created);
  AssertFalse(Preparation.Migrated);
  AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION,
    TSchemaSql.LoadSchemaVersion(FQuery));
  TCompetitionLifecycleService.Close(FContext);
  AssertFalse(FContext.Connection.Connected);
end;

procedure TCompetitionLifecycleServiceTests.
SaveAndLoadConfiguration_ExpandsCapacityAndMapsValues;
var
  Configuration, Loaded: TCompetitionConfiguration;
  NewCapacity: integer;
begin
  TCompetitionLifecycleService.OpenCompetition(FContext, False,
    DEFAULT_STAGE_COUNT, ['A', 'B', 'C', 'D', 'E'], 'Test race', nil);
  Configuration := TCompetitionConfiguration.Create(2, 2);
  Configuration.RaceName := 'Changed race';
  Configuration.ActiveStageIndex := 2;
  Configuration.Categories[0] := 'Open';
  Configuration.Categories[1] := 'Women';
  Configuration.StageNames[0] := 'Prologue';
  Configuration.StageNames[1] := 'Final';
  Configuration.StageActive[0] := False;
  Configuration.StageActive[1] := True;

  NewCapacity := TCompetitionLifecycleService.SaveConfiguration(FContext,
    Configuration, DEFAULT_STAGE_COUNT);
  Loaded := TCompetitionLifecycleService.LoadConfiguration(FContext, 2, 2);

  AssertEquals(2, NewCapacity);
  AssertEquals('Changed race', Loaded.RaceName);
  AssertEquals(2, Loaded.ActiveStageIndex);
  AssertEquals('Open', Loaded.Categories[0]);
  AssertEquals('Women', Loaded.Categories[1]);
  AssertEquals('Prologue', Loaded.StageNames[0]);
  AssertEquals('Final', Loaded.StageNames[1]);
  AssertFalse(Loaded.StageActive[0]);
  AssertTrue(Loaded.StageActive[1]);
  AssertEquals(2, TSchemaSql.DetectStageCapacity(FQuery));
end;

initialization
  RegisterTest(TCompetitionLifecycleServiceTests);

end.
