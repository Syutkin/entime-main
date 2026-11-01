unit CompetitionSchemaMigrator;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, SQLDB, SQLite3Conn;

const
  CURRENT_COMPETITION_SCHEMA_VERSION = 1;

function CreateTableStatementFromSchema(const TableName: string): string;

type
  ECompetitionSchemaError = class(Exception);

  TSchemaSql = record
  private
    class function CreateTableMain(const StageCount: integer): string; static;
    class function CreateTableStart: string; static;
    class function CreateTableConfig: string; static;
    class function CreateTableStartMarks: string; static;
    class function CreateStartMarksStatusReceivedAtIndex: string; static;
    class function CreateStartMarksStageEventTimeIndex: string; static;
    class function CreateTableFinishMarks: string; static;
    class function CreateFinishMarksStatusReceivedAtIndex: string; static;
    class function CreateFinishMarksStageEventTimeIndex: string; static;
  public
    class function DetectStageCapacity(Q: TSQLQuery): integer; static;
    class function LoadConfiguredStageCount(Q: TSQLQuery): integer; static;
    class function LoadSchemaVersion(Q: TSQLQuery): integer; static;
    class procedure AddStageColumns(Q: TSQLQuery;
      const StageIndex: integer); static;
    class procedure EnsureStageCapacity(Q: TSQLQuery;
      const RequiredCount: integer); static;
    class function StartMarksSchemaReady(Q: TSQLQuery): boolean; static;
    class procedure EnsureStartMarksTable(Q: TSQLQuery); static;
    class function FinishMarksSchemaReady(Q: TSQLQuery): boolean; static;
    class procedure EnsureFinishMarksTable(Q: TSQLQuery); static;
    class procedure ExecCreateTables(Connection: TSQLite3Connection;
      const StageCount: integer; const Cat1, Cat2, Cat3, Cat4, Cat5: string;
      const RaceName: string); static;
    class function EndTransaction: string; static;
    class function BeginTransaction: string; static;
    class procedure ExecVacuumInto(Connection: TSQLite3Connection;
      const FileName: string); static;
    class procedure ExecCreateBackup(Connection: TSQLite3Connection;
      const FileName: string; const BusyTimeoutMs: integer = 0); static;
  end;

implementation

uses
  {$IFDEF Windows}
  Windows,
  {$ENDIF}
  DB, ConfigRepository, CompetitionDbContext, SqlValueHelpers, StageConfig,
  i18n;

const
  SCHEMA_RESOURCE_NAME = 'ENTIME_SCHEMA';
  MAIN_STAGE_COLUMNS_PLACEHOLDER = '{{STAGE_COLUMNS}}';
  STAGE_COLUMN_PREFIXES: array[0..7] of string = (
    'starttime',
    'correction',
    'finishtime',
    'penalty',
    'result',
    'diffleader',
    'place',
    'status'
    );
  STAGE_COLUMN_TYPES: array[0..7] of string = (
    'VARCHAR',
    'INTEGER',
    'VARCHAR',
    'VARCHAR',
    'VARCHAR',
    'VARCHAR',
    'INTEGER',
    'VARCHAR'
    );
  START_MARK_REQUIRED_COLUMNS: array[0..13] of string = (
    'id',
    'stage_index',
    'applied_stage_index',
    'event_time',
    'correction_ms',
    'participant_number',
    'match_delta_ms',
    'source_kind',
    'source_device_id',
    'received_at',
    'assignment_mode',
    'status',
    'applied_at',
    'diagnostic'
    );
  START_MARK_STATUS_INDEX = 'idx_start_marks_status_received_at';
  START_MARK_STAGE_INDEX = 'idx_start_marks_stage_event_time';
  FINISH_MARK_REQUIRED_COLUMNS: array[0..10] of string = (
    'id',
    'stage_index',
    'event_time',
    'participant_number',
    'source_kind',
    'source_device_id',
    'received_at',
    'assignment_mode',
    'status',
    'applied_at',
    'diagnostic'
    );
  FINISH_MARK_STATUS_INDEX = 'idx_finish_marks_status_received_at';
  FINISH_MARK_STAGE_INDEX = 'idx_finish_marks_stage_event_time';

var
  SchemaStatementsCache: TStringList = nil;

function LoadSchemaSqlText: string;
var
  ResourceStream: TResourceStream;
  TextStream: TStringStream;
begin
  ResourceStream := TResourceStream.Create(HInstance, SCHEMA_RESOURCE_NAME,
    RT_RCDATA);
  try
    TextStream := TStringStream.Create('');
    try
      TextStream.CopyFrom(ResourceStream, ResourceStream.Size);
      Result := Trim(TextStream.DataString);
    finally
      TextStream.Free;
    end;
  finally
    ResourceStream.Free;
  end;
  if Result = '' then
    raise ECompetitionSchemaError.Create('Embedded schema resource is empty.');
end;

procedure SplitSqlStatements(const SqlText: string; Statements: TStrings);
var
  i: integer;
  ch: char;
  current: string;
  inString: boolean;
begin
  Statements.Clear;
  current := '';
  inString := False;
  i := 1;
  while i <= Length(SqlText) do
  begin
    ch := SqlText[i];
    current := current + ch;
    if ch = '''' then
    begin
      if inString and (i < Length(SqlText)) and (SqlText[i + 1] = '''') then
      begin
        Inc(i);
        current := current + SqlText[i];
      end
      else
        inString := not inString;
    end
    else if (ch = ';') and (not inString) then
    begin
      current := Trim(current);
      if current <> ';' then
        Statements.Add(current);
      current := '';
    end;
    Inc(i);
  end;
  current := Trim(current);
  if current <> '' then
    Statements.Add(current);
end;

function BuildMainStageColumnsSql(const StageCount: integer): string;
var
  I: integer;
begin
  RequireStageCount(StageCount);
  Result := '';
  for I := 1 to StageCount do
  begin
    Result := Result + ' "starttime' + IntToStr(I) + '" VARCHAR,' +
      LineEnding + ' "correction' + IntToStr(I) + '" INTEGER,' +
      LineEnding + ' "finishtime' + IntToStr(I) + '" VARCHAR,' +
      LineEnding + ' "penalty' + IntToStr(I) + '" VARCHAR,' +
      LineEnding + ' "result' + IntToStr(I) + '" VARCHAR,' + LineEnding +
      ' "diffleader' + IntToStr(I) + '" VARCHAR,' + LineEnding +
      ' "place' + IntToStr(I) + '" INTEGER,' + LineEnding + ' "status' +
      IntToStr(I) + '" VARCHAR,' + LineEnding;
  end;
end;

function GetSchemaStatements: TStringList;
begin
  if not Assigned(SchemaStatementsCache) then
  begin
    SchemaStatementsCache := TStringList.Create;
    SplitSqlStatements(LoadSchemaSqlText, SchemaStatementsCache);
  end;
  Result := SchemaStatementsCache;
end;

function FindCreateTableStatement(const TableName: string): string;
var
  statements: TStringList;
  statementUpper: string;
  statement: string;
  i: integer;
  needle: string;
  needleIfNotExists: string;
begin
  statements := GetSchemaStatements;
  needle := 'CREATE TABLE "' + UpperCase(TableName) + '"';
  needleIfNotExists := 'CREATE TABLE IF NOT EXISTS "' + UpperCase(TableName) + '"';
  for i := 0 to statements.Count - 1 do
  begin
    statement := statements[i];
    statementUpper := UpperCase(statement);
    if (Pos(needle, statementUpper) > 0) or
      (Pos(needleIfNotExists, statementUpper) > 0) then
      Exit(statement);
  end;
  raise Exception.CreateFmt(
    'CREATE TABLE statement for table "%s" not found in schema file.', [TableName]);
end;

function FindCreateIndexStatement(const IndexName: string): string;
var
  Statements: TStringList;
  Statement, StatementUpper: string;
  I: integer;
  Needle: string;
begin
  Statements := GetSchemaStatements;
  Needle := '"' + UpperCase(IndexName) + '"';
  for I := 0 to Statements.Count - 1 do
  begin
    Statement := Statements[I];
    StatementUpper := UpperCase(Statement);
    if (Pos('CREATE INDEX', StatementUpper) > 0) and
      (Pos(Needle, StatementUpper) > 0) then
      Exit(Statement);
  end;
  raise Exception.CreateFmt(
    'CREATE INDEX statement for index "%s" not found in schema file.', [IndexName]);
end;

function CreateTableStatementFromSchema(const TableName: string): string;
begin
  Result := FindCreateTableStatement(TableName);
end;

function TryGetStageColumnIndex(const ColumnName: string;
  out StageIndex: integer): boolean;
var
  PrefixIndex: integer;
  Prefix: string;
  Suffix: string;
begin
  StageIndex := 0;
  for PrefixIndex := Low(STAGE_COLUMN_PREFIXES) to High(STAGE_COLUMN_PREFIXES) do
  begin
    Prefix := STAGE_COLUMN_PREFIXES[PrefixIndex];
    if Copy(ColumnName, 1, Length(Prefix)) <> Prefix then
      Continue;
    Suffix := Copy(ColumnName, Length(Prefix) + 1, MaxInt);
    if (Suffix <> '') and TryStrToInt(Suffix, StageIndex) and (StageIndex > 0) then
      Exit(True);
  end;
  StageIndex := 0;
  Result := False;
end;

procedure RequireActiveSchemaTransaction(Q: TSQLQuery);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if Q.DataBase = nil then
    raise EDatabaseError.Create('Schema query database must be assigned.');
  if Q.Transaction = nil then
    raise EDatabaseError.Create('Schema query transaction must be assigned.');
  if not Q.Transaction.Active then
    raise EDatabaseError.Create('Schema changes require an active unit of work.');
end;

function MainColumnExists(Q: TSQLQuery; const ColumnName: string): boolean;
begin
  Q.Close;
  Q.SQL.Text :=
    'SELECT 1 FROM pragma_table_info(''main'') ' +
    'WHERE lower(name) = lower(:COLUMN_NAME);';
  Q.ParamByName('COLUMN_NAME').AsString := ColumnName;
  Q.Open;
  try
    Result := not Q.EOF;
  finally
    Q.Close;
  end;
end;

function SqliteObjectExists(Q: TSQLQuery; const AType, AName: string): boolean;
begin
  Q.Close;
  Q.SQL.Text :=
    'SELECT 1 FROM sqlite_master ' +
    'WHERE type = :OBJECT_TYPE AND name = :OBJECT_NAME;';
  Q.ParamByName('OBJECT_TYPE').AsString := AType;
  Q.ParamByName('OBJECT_NAME').AsString := AName;
  Q.Open;
  try
    Result := not Q.EOF;
  finally
    Q.Close;
  end;
end;

function TableColumnExists(Q: TSQLQuery;
  const ATableName, AColumnName: string): boolean;
begin
  Q.Close;
  Q.SQL.Text :=
    'SELECT 1 FROM pragma_table_info(:TABLE_NAME) ' +
    'WHERE lower(name) = lower(:COLUMN_NAME);';
  Q.ParamByName('TABLE_NAME').AsString := ATableName;
  Q.ParamByName('COLUMN_NAME').AsString := AColumnName;
  Q.Open;
  try
    Result := not Q.EOF;
  finally
    Q.Close;
  end;
end;

class function TSchemaSql.DetectStageCapacity(Q: TSQLQuery): integer;
var
  ColumnNames: TStringList;
  ColumnName: string;
  ExpectedColumnName: string;
  StageIndex: integer;
  ColumnIndex: integer;
  MaxStageIndex: integer;
  PresentColumnCount: integer;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');

  ColumnNames := TStringList.Create;
  try
    ColumnNames.CaseSensitive := False;
    ColumnNames.Sorted := True;
    ColumnNames.Duplicates := dupIgnore;
    Q.Close;
    Q.SQL.Text := 'PRAGMA table_info(main);';
    Q.Open;
    try
      while not Q.EOF do
      begin
        ColumnName := LowerCase(Q.FieldByName('name').AsString);
        ColumnNames.Add(ColumnName);
        Q.Next;
      end;
    finally
      Q.Close;
    end;

    if ColumnNames.Count = 0 then
      raise ECompetitionSchemaError.Create(
        'Table "main" is missing or has no columns.');

    MaxStageIndex := 0;
    for ColumnIndex := 0 to ColumnNames.Count - 1 do
      if TryGetStageColumnIndex(ColumnNames[ColumnIndex], StageIndex) then
      begin
        if StageIndex > MAX_SUPPORTED_STAGE_COUNT then
          raise ECompetitionSchemaError.CreateFmt(
            'Stage column "%s" exceeds the supported stage count %d.',
            [ColumnNames[ColumnIndex], MAX_SUPPORTED_STAGE_COUNT]);
        if StageIndex > MaxStageIndex then
          MaxStageIndex := StageIndex;
      end;

    if MaxStageIndex = 0 then
      raise ECompetitionSchemaError.Create(
        'Table "main" does not contain stage columns.');

    Result := 0;
    for StageIndex := 1 to MaxStageIndex do
    begin
      PresentColumnCount := 0;
      for ColumnIndex := Low(STAGE_COLUMN_PREFIXES)
        to High(STAGE_COLUMN_PREFIXES) do
      begin
        ExpectedColumnName := STAGE_COLUMN_PREFIXES[ColumnIndex] +
          IntToStr(StageIndex);
        if ColumnNames.IndexOf(ExpectedColumnName) >= 0 then
          Inc(PresentColumnCount);
      end;

      if PresentColumnCount = 0 then
        raise ECompetitionSchemaError.CreateFmt(
          'Stage %d is missing before stage %d.', [StageIndex, MaxStageIndex]);
      if PresentColumnCount <> Length(STAGE_COLUMN_PREFIXES) then
        raise ECompetitionSchemaError.CreateFmt(
          'Stage %d has %d of %d required columns.',
          [StageIndex, PresentColumnCount, Length(STAGE_COLUMN_PREFIXES)]);
      Result := StageIndex;
    end;
  finally
    ColumnNames.Free;
  end;
end;

class function TSchemaSql.LoadConfiguredStageCount(Q: TSQLQuery): integer;
var
  ValueText: string;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  ValueText := Trim(TConfigSql.GetString(Q, 'stagecount', ''));
  if ValueText = '' then
    Exit(0);
  if (not TryStrToInt(ValueText, Result)) or (not IsValidStageCount(Result)) then
    raise ECompetitionSchemaError.CreateFmt(rsStageCountRangeError,
      [ValueText, MIN_STAGE_COUNT, MAX_SUPPORTED_STAGE_COUNT]);
end;

class function TSchemaSql.LoadSchemaVersion(Q: TSQLQuery): integer;
var
  ValueText: string;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  ValueText := Trim(TConfigSql.GetString(Q, 'schema_version', ''));
  if ValueText = '' then
    Exit(0);
  if (not TryStrToInt(ValueText, Result)) or (Result < 0) then
    raise ECompetitionSchemaError.CreateFmt(
      'Invalid schema version "%s".', [ValueText]);
end;

class procedure TSchemaSql.AddStageColumns(Q: TSQLQuery; const StageIndex: integer);
var
  PrefixIndex: integer;
  ColumnName: string;
begin
  RequireSupportedStageIndex(StageIndex);
  RequireActiveSchemaTransaction(Q);
  for PrefixIndex := Low(STAGE_COLUMN_PREFIXES) to High(STAGE_COLUMN_PREFIXES) do
  begin
    ColumnName := STAGE_COLUMN_PREFIXES[PrefixIndex] + IntToStr(StageIndex);
    if MainColumnExists(Q, ColumnName) then
      Continue;
    Q.SQL.Text := 'ALTER TABLE "main" ADD COLUMN ' + SqlIdentifier(ColumnName) +
      ' ' + STAGE_COLUMN_TYPES[PrefixIndex] + ';';
    Q.ExecSQL;
    Q.Close;
  end;
end;

class procedure TSchemaSql.EnsureStageCapacity(Q: TSQLQuery;
  const RequiredCount: integer);
var
  CurrentCount: integer;
  StageIndex: integer;
begin
  RequireStageCount(RequiredCount);
  RequireActiveSchemaTransaction(Q);
  CurrentCount := DetectStageCapacity(Q);
  for StageIndex := CurrentCount + 1 to RequiredCount do
    AddStageColumns(Q, StageIndex);
end;

class function TSchemaSql.StartMarksSchemaReady(Q: TSQLQuery): boolean;
var
  ColumnName: string;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if not SqliteObjectExists(Q, 'table', 'start_marks') then
    Exit(False);
  for ColumnName in START_MARK_REQUIRED_COLUMNS do
    if not TableColumnExists(Q, 'start_marks', ColumnName) then
      Exit(False);
  Result :=
    SqliteObjectExists(Q, 'index', START_MARK_STATUS_INDEX) and
    SqliteObjectExists(Q, 'index', START_MARK_STAGE_INDEX);
end;

class procedure TSchemaSql.EnsureStartMarksTable(Q: TSQLQuery);
var
  ColumnName: string;
begin
  RequireActiveSchemaTransaction(Q);
  Q.Close;
  Q.SQL.Text := CreateTableStartMarks;
  Q.ExecSQL;
  Q.Close;

  for ColumnName in START_MARK_REQUIRED_COLUMNS do
    if not TableColumnExists(Q, 'start_marks', ColumnName) then
      raise ECompetitionSchemaError.CreateFmt(
        'Table "start_marks" is missing required column "%s".', [ColumnName]);

  Q.SQL.Text := CreateStartMarksStatusReceivedAtIndex;
  Q.ExecSQL;
  Q.Close;
  Q.SQL.Text := CreateStartMarksStageEventTimeIndex;
  Q.ExecSQL;
  Q.Close;
end;

class function TSchemaSql.FinishMarksSchemaReady(Q: TSQLQuery): boolean;
var
  ColumnName: string;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if not SqliteObjectExists(Q, 'table', 'finish_marks') then
    Exit(False);
  for ColumnName in FINISH_MARK_REQUIRED_COLUMNS do
    if not TableColumnExists(Q, 'finish_marks', ColumnName) then
      Exit(False);
  Result :=
    SqliteObjectExists(Q, 'index', FINISH_MARK_STATUS_INDEX) and
    SqliteObjectExists(Q, 'index', FINISH_MARK_STAGE_INDEX);
end;

class procedure TSchemaSql.EnsureFinishMarksTable(Q: TSQLQuery);
var
  ColumnName: string;
begin
  RequireActiveSchemaTransaction(Q);
  Q.Close;
  Q.SQL.Text := CreateTableFinishMarks;
  Q.ExecSQL;
  Q.Close;

  for ColumnName in FINISH_MARK_REQUIRED_COLUMNS do
    if not TableColumnExists(Q, 'finish_marks', ColumnName) then
      raise ECompetitionSchemaError.CreateFmt(
        'Table "finish_marks" is missing required column "%s".', [ColumnName]);

  Q.SQL.Text := CreateFinishMarksStatusReceivedAtIndex;
  Q.ExecSQL;
  Q.Close;
  Q.SQL.Text := CreateFinishMarksStageEventTimeIndex;
  Q.ExecSQL;
  Q.Close;
end;

class function TSchemaSql.CreateTableMain(const StageCount: integer): string;
var
  templateSql: string;
begin
  RequireStageCount(StageCount);
  templateSql := FindCreateTableStatement('main');
  if Pos(MAIN_STAGE_COLUMNS_PLACEHOLDER, templateSql) = 0 then
    raise Exception.CreateFmt(
      'Placeholder "%s" not found in CREATE TABLE main statement.',
      [MAIN_STAGE_COLUMNS_PLACEHOLDER]);
  Result := StringReplace(templateSql, MAIN_STAGE_COLUMNS_PLACEHOLDER,
    BuildMainStageColumnsSql(StageCount), [rfReplaceAll]);
end;

class function TSchemaSql.CreateTableStart: string;
begin
  Result := FindCreateTableStatement('start');
end;

class function TSchemaSql.CreateTableConfig: string;
begin
  Result := FindCreateTableStatement('config');
end;

class function TSchemaSql.CreateTableFinishMarks: string;
begin
  Result := FindCreateTableStatement('finish_marks');
end;

class function TSchemaSql.CreateTableStartMarks: string;
begin
  Result := FindCreateTableStatement('start_marks');
end;

class function TSchemaSql.CreateStartMarksStatusReceivedAtIndex: string;
begin
  Result := FindCreateIndexStatement(START_MARK_STATUS_INDEX);
end;

class function TSchemaSql.CreateStartMarksStageEventTimeIndex: string;
begin
  Result := FindCreateIndexStatement(START_MARK_STAGE_INDEX);
end;

class function TSchemaSql.CreateFinishMarksStatusReceivedAtIndex: string;
begin
  Result := FindCreateIndexStatement(FINISH_MARK_STATUS_INDEX);
end;

class function TSchemaSql.CreateFinishMarksStageEventTimeIndex: string;
begin
  Result := FindCreateIndexStatement(FINISH_MARK_STAGE_INDEX);
end;

class procedure TSchemaSql.ExecCreateTables(Connection: TSQLite3Connection;
  const StageCount: integer; const Cat1, Cat2, Cat3, Cat4, Cat5: string;
  const RaceName: string);
var
  Q: TSQLQuery;
begin
  if not Assigned(Connection) then
    raise Exception.Create('Connection must be assigned.');
  if not Assigned(Connection.Transaction) then
    raise Exception.Create('Connection.Transaction must be assigned.');
  RequireStageCount(StageCount);

  Connection.ExecuteDirect(CreateTableMain(StageCount));
  Connection.ExecuteDirect(CreateTableStart);
  Connection.ExecuteDirect(CreateTableConfig);
  Connection.ExecuteDirect(CreateTableStartMarks);
  Connection.ExecuteDirect(CreateStartMarksStatusReceivedAtIndex);
  Connection.ExecuteDirect(CreateStartMarksStageEventTimeIndex);
  Connection.ExecuteDirect(CreateTableFinishMarks);
  Connection.ExecuteDirect(CreateFinishMarksStatusReceivedAtIndex);
  Connection.ExecuteDirect(CreateFinishMarksStageEventTimeIndex);

  Q := TSQLQuery.Create(nil);
  try
    Q.DataBase := Connection;
    Q.Transaction := Connection.Transaction;
    TConfigSql.ExecUpsertByKey(Q, 'activestage', '1');
    TConfigSql.ExecUpsertByKey(Q, 'stagecount', IntToStr(StageCount));
    TConfigSql.ExecUpsertByKey(Q, 'schema_version',
      IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
    TConfigSql.ExecUpsertByKey(Q, 'stage1', BoolToStr(True, True));
    TConfigSql.ExecUpsertByKey(Q, 'catname1', Cat1);
    TConfigSql.ExecUpsertByKey(Q, 'catname2', Cat2);
    TConfigSql.ExecUpsertByKey(Q, 'catname3', Cat3);
    TConfigSql.ExecUpsertByKey(Q, 'catname4', Cat4);
    TConfigSql.ExecUpsertByKey(Q, 'catname5', Cat5);
    TConfigSql.ExecUpsertByKey(Q, 'racename', RaceName);
  finally
    Q.Free;
  end;
end;

class function TSchemaSql.EndTransaction: string;
begin
  Result := 'End Transaction';
end;

class function TSchemaSql.BeginTransaction: string;
begin
  Result := 'Begin Transaction';
end;

class procedure TSchemaSql.ExecVacuumInto(Connection: TSQLite3Connection;
  const FileName: string);
var
  Q: TSQLQuery;
begin
  if not Assigned(Connection) then
    raise EArgumentNilException.Create('Connection');
  if not Assigned(Connection.Transaction) then
    raise EDatabaseError.Create('Connection.Transaction must be assigned.');
  Q := TSQLQuery.Create(nil);
  try
    Q.DataBase := Connection;
    Q.Transaction := Connection.Transaction;
    Q.SQL.Text := 'VACUUM INTO :FILE_NAME;';
    Q.ParamByName('FILE_NAME').AsString := FileName;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

class procedure TSchemaSql.ExecCreateBackup(Connection: TSQLite3Connection;
  const FileName: string; const BusyTimeoutMs: integer);
begin
  if not Assigned(Connection) then
    raise EArgumentNilException.Create('Connection');
  Connection.Close;
  Connection.ExecuteDirect(EndTransaction);
  if BusyTimeoutMs > 0 then
    ConfigureSQLiteBusyTimeout(Connection, BusyTimeoutMs);
  ExecVacuumInto(Connection, FileName);
  Connection.ExecuteDirect(BeginTransaction);
end;

finalization
  FreeAndNil(SchemaStatementsCache);

end.
