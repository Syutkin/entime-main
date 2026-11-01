unit CompetitionLifecycleService;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, DbSql;

type
  TCompetitionBackupAction = function: boolean;
  TCompetitionStringArray = array of string;
  TCompetitionBooleanArray = array of boolean;

  TCompetitionPreparation = record
    Created: boolean;
    Migrated: boolean;
    PhysicalStageCount: integer;
    RequiredStageCount: integer;
    SchemaVersion: integer;
  end;

  TCompetitionConfiguration = record
    RaceName: string;
    ActiveStageIndex: integer;
    Categories: TCompetitionStringArray;
    StageNames: TCompetitionStringArray;
    StageActive: TCompetitionBooleanArray;
    StageConfigured: TCompetitionBooleanArray;
    class function Create(const AStageCount, ACategoryCount: integer):
      TCompetitionConfiguration; static;
    function StageCount: integer;
    function CategoryCount: integer;
  end;

  TCompetitionLifecycleService = record
  public
    class function OpenCompetition(const AContext: TCompetitionDbContext;
      const AExistingFile: boolean; const ADefaultStageCount: integer;
      const ADefaultCategories: array of string; const ARaceName: string;
      const ACreateBackup: TCompetitionBackupAction): TCompetitionPreparation;
      static;
    class function LoadConfiguration(const AContext: TCompetitionDbContext;
      const AStageCount, ACategoryCount: integer): TCompetitionConfiguration;
      static;
    class function SaveConfiguration(const AContext: TCompetitionDbContext;
      const AConfiguration: TCompetitionConfiguration;
      const APhysicalStageCapacity: integer): integer; static;
    class function PhysicalStageCapacity(const AContext: TCompetitionDbContext):
      integer; static;
    class procedure Close(const AContext: TCompetitionDbContext); static;
  end;

implementation

uses
  Classes, Math, SQLDB, StageConfig, i18n;

class function TCompetitionConfiguration.Create(
  const AStageCount, ACategoryCount: integer): TCompetitionConfiguration;
begin
  if not IsValidStageCount(AStageCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Invalid competition stage count: %d.', [AStageCount]);
  if ACategoryCount < 0 then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Invalid competition category count: %d.', [ACategoryCount]);
  Result.RaceName := '';
  Result.ActiveStageIndex := 1;
  SetLength(Result.Categories, ACategoryCount);
  SetLength(Result.StageNames, AStageCount);
  SetLength(Result.StageActive, AStageCount);
  SetLength(Result.StageConfigured, AStageCount);
end;

function TCompetitionConfiguration.StageCount: integer;
begin
  Result := Length(StageNames);
end;

function TCompetitionConfiguration.CategoryCount: integer;
begin
  Result := Length(Categories);
end;

class function TCompetitionLifecycleService.OpenCompetition(
  const AContext: TCompetitionDbContext; const AExistingFile: boolean;
  const ADefaultStageCount: integer; const ADefaultCategories: array of string;
  const ARaceName: string; const ACreateBackup: TCompetitionBackupAction):
TCompetitionPreparation;
var
  ConfiguredStageCount, TargetStageCapacity: integer;
  FinishMarksSchemaReady, MigrationRequired, StartMarksSchemaReady: boolean;
  Query: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if not IsValidStageCount(ADefaultStageCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Invalid default stage count: %d.', [ADefaultStageCount]);
  if Length(ADefaultCategories) < 5 then
    raise EArgumentException.Create(
      'At least five default categories are required.');

  Result := Default(TCompetitionPreparation);
  Result.Created := not AExistingFile;
  AContext.OpenConnection;
  Query := AContext.CreateQuery(nil);
  try
    if not AExistingFile then
    begin
      UnitOfWork := AContext.BeginUnitOfWork;
      try
        TSchemaSql.ExecCreateTables(AContext.Connection, ADefaultStageCount,
          ADefaultCategories[0], ADefaultCategories[1],
          ADefaultCategories[2], ADefaultCategories[3],
          ADefaultCategories[4], ARaceName);
        UnitOfWork.Commit;
      finally
        UnitOfWork.Free;
      end;
    end;

    Result.PhysicalStageCount := TSchemaSql.DetectStageCapacity(Query);
    ConfiguredStageCount := TSchemaSql.LoadConfiguredStageCount(Query);
    Result.SchemaVersion := TSchemaSql.LoadSchemaVersion(Query);
    if Result.SchemaVersion > CURRENT_COMPETITION_SCHEMA_VERSION then
      raise ECompetitionSchemaError.CreateFmt(rsSchemaVersionTooNew,
        [Result.SchemaVersion, CURRENT_COMPETITION_SCHEMA_VERSION]);

    if ConfiguredStageCount = 0 then
      Result.RequiredStageCount := Result.PhysicalStageCount
    else
      Result.RequiredStageCount := ConfiguredStageCount;
    TargetStageCapacity := Max(ADefaultStageCount, Result.RequiredStageCount);
    StartMarksSchemaReady := TSchemaSql.StartMarksSchemaReady(Query);
    FinishMarksSchemaReady := TSchemaSql.FinishMarksSchemaReady(Query);
    MigrationRequired := (ConfiguredStageCount = 0) or
      (Result.SchemaVersion < CURRENT_COMPETITION_SCHEMA_VERSION) or
      (Result.PhysicalStageCount < TargetStageCapacity) or
      (not StartMarksSchemaReady) or (not FinishMarksSchemaReady);
    Result.Migrated := MigrationRequired;
    if MigrationRequired then
    begin
      if not Assigned(ACreateBackup) or not ACreateBackup() then
        raise ECompetitionSchemaError.CreateFmt(rsSchemaMigrationBackupError,
          [AContext.Connection.DatabaseName]);
      UnitOfWork := AContext.BeginUnitOfWork;
      try
        TSchemaSql.EnsureStageCapacity(Query, TargetStageCapacity);
        TSchemaSql.EnsureStartMarksTable(Query);
        TSchemaSql.EnsureFinishMarksTable(Query);
        if ConfiguredStageCount = 0 then
          TConfigSql.ExecUpsertByKey(Query, 'stagecount',
            IntToStr(Result.RequiredStageCount));
        TConfigSql.ExecUpsertByKey(Query, 'schema_version',
          IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
        UnitOfWork.Commit;
      finally
        UnitOfWork.Free;
      end;
      Result.PhysicalStageCount := TSchemaSql.DetectStageCapacity(Query);
      Result.SchemaVersion := CURRENT_COMPETITION_SCHEMA_VERSION;
    end;
  finally
    Query.Free;
  end;
end;

class function TCompetitionLifecycleService.LoadConfiguration(
  const AContext: TCompetitionDbContext;
  const AStageCount, ACategoryCount: integer): TCompetitionConfiguration;
var
  ConfigValues: TStringList;
  Index: integer;
  Query: TSQLQuery;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  Result := TCompetitionConfiguration.Create(AStageCount, ACategoryCount);
  Query := AContext.CreateQuery(nil);
  ConfigValues := TStringList.Create;
  try
    TConfigSql.LoadAll(Query, ConfigValues);
    Result.RaceName := TConfigSql.StringValue(ConfigValues, 'racename', '');
    Result.ActiveStageIndex := TConfigSql.GetInteger(Query, 'activestage', 1);
    for Index := 0 to Result.CategoryCount - 1 do
      Result.Categories[Index] :=
        TConfigSql.StringValue(ConfigValues, 'catname' + IntToStr(Index + 1), '');
    for Index := 0 to Result.StageCount - 1 do
    begin
      Result.StageNames[Index] :=
        TConfigSql.StringValue(ConfigValues, 'stagename' + IntToStr(Index + 1), '');
      Result.StageConfigured[Index] :=
        ConfigValues.IndexOfName('stage' + IntToStr(Index + 1)) >= 0;
      Result.StageActive[Index] :=
        TConfigSql.BoolValue(ConfigValues, 'stage' + IntToStr(Index + 1), False);
    end;
  finally
    ConfigValues.Free;
    Query.Free;
  end;
end;

class function TCompetitionLifecycleService.SaveConfiguration(
  const AContext: TCompetitionDbContext;
  const AConfiguration: TCompetitionConfiguration;
  const APhysicalStageCapacity: integer): integer;
var
  Index: integer;
  Query: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if not IsValidStageCount(AConfiguration.StageCount) or
    (Length(AConfiguration.StageActive) <> AConfiguration.StageCount) or
    (Length(AConfiguration.StageConfigured) <> AConfiguration.StageCount) then
    raise EArgumentException.Create('Invalid competition stage configuration.');
  if (AConfiguration.ActiveStageIndex < 1) or
    (AConfiguration.ActiveStageIndex > AConfiguration.StageCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Invalid active stage index: %d.', [AConfiguration.ActiveStageIndex]);

  Query := AContext.CreateQuery(nil);
  UnitOfWork := AContext.BeginUnitOfWork;
  try
    if AConfiguration.StageCount > APhysicalStageCapacity then
      TSchemaSql.EnsureStageCapacity(Query, AConfiguration.StageCount);
    TConfigSql.PrepareUpsert(Query);
    try
      TConfigSql.ExecPreparedUpsert(Query, 'stagecount',
        IntToStr(AConfiguration.StageCount));
      TConfigSql.ExecPreparedUpsert(Query, 'racename',
        AConfiguration.RaceName);
      for Index := 0 to AConfiguration.CategoryCount - 1 do
        TConfigSql.ExecPreparedUpsert(Query, 'catname' + IntToStr(Index + 1),
          AConfiguration.Categories[Index]);
      for Index := 0 to AConfiguration.StageCount - 1 do
      begin
        TConfigSql.ExecPreparedUpsert(Query, 'stage' + IntToStr(Index + 1),
          BoolToStr(AConfiguration.StageActive[Index], True));
        TConfigSql.ExecPreparedUpsert(Query, 'stagename' + IntToStr(Index + 1),
          AConfiguration.StageNames[Index]);
      end;
      TConfigSql.ExecPreparedUpsert(Query, 'activestage',
        IntToStr(AConfiguration.ActiveStageIndex));
    finally
      TConfigSql.FinishPreparedUpsert(Query);
    end;
    UnitOfWork.Commit;
    Result := Max(APhysicalStageCapacity, AConfiguration.StageCount);
  finally
    UnitOfWork.Free;
    Query.Free;
  end;
end;

class function TCompetitionLifecycleService.PhysicalStageCapacity(
  const AContext: TCompetitionDbContext): integer;
var
  Query: TSQLQuery;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  Query := AContext.CreateQuery(nil);
  try
    Result := TSchemaSql.DetectStageCapacity(Query);
  finally
    Query.Free;
  end;
end;

class procedure TCompetitionLifecycleService.Close(
  const AContext: TCompetitionDbContext);
begin
  if AContext <> nil then
    AContext.CloseFile;
end;

end.
