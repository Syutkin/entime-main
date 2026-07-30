unit db_sql;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, sqldb, sqlite3conn;

const
  STARTLIST_SORT_BY_NUMBER_ASC = 0;
  STARTLIST_SORT_BY_NUMBER_DESC = 1;
  STARTLIST_SORT_BY_NAME_ASC = 2;
  STARTLIST_SORT_BY_NAME_DESC = 3;
  STARTLIST_SORT_BY_RESULT = 4;

type
  TConfigSql = record
  private
    class function SelectByKey: string; static;
  public
    class function UpsertByKey: string; static;
    class procedure ExecUpsertByKey(Q: TSQLQuery; const Key, Value: string); static;
    class function GetString(Q: TSQLQuery; const Key, DefaultValue: string): string; static;
    class function GetBool(Q: TSQLQuery; const Key: string;
      const DefaultValue: boolean): boolean; static;
  end;

  TMainSql = record
  private
    class function SelectByNumber: string; static;
    class function UpdateGlobalStatus: string; static;
    class function UpdateStageStatus(const StageIndex: integer;
      const StatusText, StageStatus: string): string; static;
    class function UpdateOnlyGlobalStatusDsq: string; static;
    class function ClearStatusAllForStage(const StageIndex: integer): string; static;
    class function ClearOnlyGlobalStatus: string; static;
    class function ClearStageStatus(const StageIndex: integer): string; static;
    class function UpdateStartTimeForNumber(const StageIndex: integer): string; static;
    class function SelectNumberByStartTimeBetween(const StageIndex: integer): string; static;
    class function UpdateCorrection(const StageIndex: integer): string; static;
    class function SelectByCategoryLeader(const StageIndex: integer): string; static;
    class function UpdateFinishPrefix: string; static;
    class function UpdateFinishSetPart(const StageIndex: integer): string; static;
    class function UpdateFinishWhereNumber: string; static;
    class function SelectFinishExistsByStage(const StageIndex: integer): string; static;
    class function SelectPenaltyGroupsCount: string; static;
  public
    class function SelectAll: string; static;
    class function SelectNumbers: string; static;
    class function ResetStartTime(const StageIndex: integer): string; static;
    class function UpdateStartTime(const StageIndex: integer): string; static;
    class function SelectMinStartTime(const StageIndex: integer): string; static;
    class function SelectMaxNumber: string; static;
    class function SelectCategoryGrouped: string; static;
    class function SelectCategoryGroupedOrderedByStartTime(const StageIndex: integer): string; static;
    class function SelectCategoryResults(const ColumnsCsv: string): string; static;
    class function SelectStatusAll: string; static;
    class function SelectStatusByStage(const StageIndex: integer): string; static;
    class function ExportFinishTime(const StageIndex: integer): string; static;
    class function ExportAllResults: string; static;
    class function ExportSumDays: string; static;

    class function OpenByNumber(Q: TSQLQuery; const Number: integer): boolean; static;
    class function OpenByCategoryLeader(Q: TSQLQuery; const StageIndex: integer;
      const Category: string): boolean; static;
    class function TryGetNumberByStartTimeBetween(Q: TSQLQuery;
      const StageIndex: integer; const TimeBefore, TimeAfter: string;
      out Number: integer): boolean; static;
    class function GetPenaltyGroupsCount(Q: TSQLQuery): integer; static;
    class function GetFinishCount(Q: TSQLQuery; const StageIndex: integer): integer; static;

    class procedure ExecUpdateStageStatus(Q: TSQLQuery; const StageIndex: integer;
      const StatusText, StageStatus, Number: string); static;
    class procedure ExecUpdateOnlyGlobalStatusDsq(Q: TSQLQuery;
      const Number: string); static;
    class procedure ExecUpdateGlobalStatus(Q: TSQLQuery; const StatusOrNull,
      Number: string); static;
    class procedure ExecClearStatusAllForStage(Q: TSQLQuery;
      const StageIndex: integer; const Number: string); static;
    class procedure ExecClearOnlyGlobalStatus(Q: TSQLQuery;
      const Number: string); static;
    class procedure ExecClearStageStatus(Q: TSQLQuery; const StageIndex: integer;
      const Number: string); static;
    class procedure ExecUpdateStartTimeForNumber(Q: TSQLQuery;
      const StageIndex: integer; const StartTime: string; const Number: integer); static;
    class procedure ExecUpdateCorrection(Q: TSQLQuery; const StageIndex,
      Correction, Number: integer); static;
    class procedure ExecUpdateFinishForCheckedStages(Q: TSQLQuery;
      const CheckedStages: array of integer; const TimeValue: string;
      const Number: integer); static;
  end;

  TLoRaSql = record
  private
    class function SetIsSetByIdAndValue: string; static;
    class function InsertSample: string; static;
  public
    class function SelectPending: string; static;
    class function SelectAll: string; static;
    class function SelectStartAfter: string; static;
    class function ResetIsSetNull: string; static;
    class function SetIsSetById: string; static;
    class procedure ExecSetIsSetByIdAndValue(Q: TSQLQuery; const IsSet,
      Id: integer); static;
    class procedure ExecInsertSample(Q: TSQLQuery; const HasNumber: boolean;
      const Number: integer; const StartTime: string; const Correction: integer;
      const TimeMark: string); static;
  end;

  TSumDaysSql = record
  public
    class function CreateTableIfNotExists: string; static;
    class function DeleteAll: string; static;
    class function UpsertPlacesByCategory: string; static;
  end;

  TDatasetSql = record
  public
    class function CorrectionPending(const StageIndex: integer): string; static;
    class function TrackStatus(const StageIndex: integer): string; static;
    class function ResultStage(const StageIndex: integer): string; static;
    class function ResultStageTotal: string; static;
    class function ResultStageSum: string; static;
  end;

  TStartlistSql = record
  public
    class function SelectNumbersForCategory(const SortBy: integer;
      const IncludeDNS, IncludeDNF, IncludeDSQ: boolean): string; static;
  end;

  TResultsSql = record
  private
    class function UpsertSumPlace: string; static;
  public
    class function SelectForSumCalculation(
      const ActiveStages: array of integer): string; static;
    class function UpdateStageResult(const StageIndex: integer): string; static;
    class function ResetStagePlaceAndDiff(const StageIndex: integer): string; static;
    class function UpsertStagePlace(const StageIndex: integer): string; static;
    class function ResetStageDiffLeader(const StageIndex: integer): string; static;
    class function UpsertStageDiffLeader(const StageIndex: integer): string; static;

    class function UpdateSumResult: string; static;
    class function ResetSumPlaceAndDiff: string; static;
    class function UpsertSumPlaceOnlyFullStages(const ActiveStages: array of integer): string; static;
    class function ResetSumDiffLeader: string; static;
    class function UpsertSumDiffLeader: string; static;
    class function UpsertSumDiffByStages(const StageCaption: string): string; static;

    class function ResetThru: string; static;
    class function UpsertThruPlace: string; static;
    class function UpsertThruDiff: string; static;
    class function UpsertThruDiffByStages(const StageCaption: string): string; static;

    class function ClearResultsPrefix: string; static;
    class function ClearResultsStagePart(const StageIndex: integer): string; static;
    class function ClearResultsSuffix: string; static;
  end;

  TLoadSql = record
  private
    class function DeleteLoad: string; static;
    class function DeleteLoadResult: string; static;
    class function UpsertConfigByKey: string; static;
    class function InsertLoadMainHeader(const MaxStages: integer): string; static;
    class function InsertLoadMainSelect(const MaxStages: integer): string; static;
    class function InsertLoadMainUpsert(const MaxStages: integer): string; static;
    class function UpsertMainFromLoadResult6(const StageIndex: integer): string; static;
    class function UpsertMainFromLoadResult3(const StageIndex: integer): string; static;
    class function UpsertMainFromLoadResult2(const StageIndex: integer): string; static;
  public
    class procedure ExecDeleteLoad(Q: TSQLQuery); static;
    class procedure ExecDeleteLoadResult(Q: TSQLQuery); static;
    class procedure ExecInsertLoadMainFromLoad(Q: TSQLQuery;
      const MaxStages: integer); static;

    class function DeleteLoadStatement: string; static;
    class function DeleteLoadResultStatement: string; static;
    class function InsertLoadHeader(const MaxStages: integer): string; static;
    class function InsertLoadRow(const MaxStages: integer): string; static;
    class function InsertLoadMainFromLoad(const MaxStages: integer): string; static;
    class function InsertLoadResultHeader6: string; static;
    class function InsertLoadResultHeader3: string; static;
    class function InsertLoadResultHeader2: string; static;
    class function InsertLoadResultRow6: string; static;
    class function InsertLoadResultRow3: string; static;
    class function InsertLoadResultRow2: string; static;
    class function UpsertMainFromLoadResult6Statement(
      const StageIndex: integer): string; static;
    class function UpsertMainFromLoadResult3Statement(
      const StageIndex: integer): string; static;
    class function UpsertMainFromLoadResult2Statement(
      const StageIndex: integer): string; static;

    class function AddDayInsertLoadHeader: string; static;
    class function AddDayNormalizeResult: string; static;
    class function AddDayNormalizeStages: string; static;
    class function AddDayNormalizeStatus: string; static;
    class function AddDayUpsertSumdays: string; static;
    class function ValuesRowFromEscaped(const EscapedDelimited: string): string; static;
    class function SqlComma: string; static;
    class function SqlSemicolon: string; static;
    class function SqlOpenParen: string; static;
    class function SqlCloseParen: string; static;
    class function SqlValueNull: string; static;
    class function SqlValue1: string; static;
    class function SqlValue2: string; static;
  end;

  TSchemaSql = record
  private
    class function CreateTableMain(const MaxStages: integer): string; static;
    class function CreateTableLoad(const MaxStages: integer): string; static;
    class function CreateTableLoadResult: string; static;
    class function CreateTableStart: string; static;
    class function CreateTableFinish: string; static;
    class function CreateTableConfig: string; static;
    class function CreateTableLoRa: string; static;
    class function InsertDefaultConfig(const Cat1, Cat2, Cat3, Cat4, Cat5: string): string; static;
  public
    class procedure ExecCreateTables(Connection: TSQLite3Connection;
      const MaxStages: integer; const Cat1, Cat2, Cat3, Cat4, Cat5: string;
      const RaceName: string); static;
    class function EndTransaction: string; static;
    class function BeginTransaction: string; static;
    class function VacuumInto(const FileName: string): string; static;
  end;

implementation

uses
  Classes;

const
  MAIN_STAGE_COLUMNS_PLACEHOLDER = '{{STAGE_COLUMNS}}';
  LOAD_STARTTIME_COLUMNS_PLACEHOLDER = '{{LOAD_STARTTIME_COLUMNS}}';

var
  SchemaStatementsCache: TStringList = nil;

function ResolveSchemaFileName: string;
var
  exeDir: string;
  candidateExeDir: string;
  candidateExeParent: string;
  candidateCwd: string;
begin
  exeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  candidateExeDir := exeDir + 'sql' + DirectorySeparator + 'schema.sql';
  candidateExeParent := ExpandFileName(exeDir + '..' + DirectorySeparator + 'sql' +
    DirectorySeparator + 'schema.sql');
  candidateCwd := 'sql' + DirectorySeparator + 'schema.sql';

  if FileExists(candidateExeDir) then
    Exit(candidateExeDir);
  if FileExists(candidateExeParent) then
    Exit(candidateExeParent);
  if FileExists(candidateCwd) then
    Exit(candidateCwd);

  raise Exception.CreateFmt(
    'Schema file not found. Checked: "%s", "%s", "%s".',
    [candidateExeDir, candidateExeParent, candidateCwd]);
end;

function LoadSchemaSqlText: string;
var
  S: TStringList;
begin
  S := TStringList.Create;
  try
    S.LoadFromFile(ResolveSchemaFileName);
    Result := Trim(S.Text);
  finally
    S.Free;
  end;
  if Result = '' then
    raise Exception.Create('Schema file is empty.');
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

function BuildMainStageColumnsSql(const MaxStages: integer): string;
var
  I: integer;
begin
  Result := '';
  for I := 1 to MaxStages do
  begin
    Result := Result +
      ' "starttime' + IntToStr(I) + '" VARCHAR,' + LineEnding +
      ' "correction' + IntToStr(I) + '" INTEGER,' + LineEnding +
      ' "finishtime' + IntToStr(I) + '" VARCHAR,' + LineEnding +
      ' "penalty' + IntToStr(I) + '" VARCHAR,' + LineEnding +
      ' "result' + IntToStr(I) + '" VARCHAR,' + LineEnding +
      ' "diffleader' + IntToStr(I) + '" VARCHAR,' + LineEnding +
      ' "place' + IntToStr(I) + '" INTEGER,' + LineEnding +
      ' "status' + IntToStr(I) + '" VARCHAR,' + LineEnding;
  end;
end;

function BuildLoadStartTimeColumnsSql(const MaxStages: integer): string;
var
  I: integer;
begin
  Result := '';
  for I := 1 to MaxStages do
  begin
    Result := Result +
      ' "starttime' + IntToStr(I) + '" VARCHAR';
    if I < MaxStages then
      Result := Result + ',' + LineEnding
    else
      Result := Result + LineEnding;
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
    if (Pos(needle, statementUpper) > 0) or (Pos(needleIfNotExists, statementUpper) > 0) then
      Exit(statement);
  end;
  raise Exception.CreateFmt('CREATE TABLE statement for table "%s" not found in schema file.', [TableName]);
end;

function ParseBoolText(const Value: string; const DefaultValue: boolean): boolean;
var
  intValue: integer;
begin
  if SameText(Value, '1') or SameText(Value, 'true') then
    Exit(True);
  if SameText(Value, '0') or SameText(Value, 'false') then
    Exit(False);
  if TryStrToInt(Value, intValue) then
    Exit(intValue <> 0);
  Result := DefaultValue;
end;

{ TConfigSql }

class function TConfigSql.SelectByKey: string;
begin
  Result := 'SELECT * FROM config WHERE key = :KEY;';
end;

class function TConfigSql.UpsertByKey: string;
begin
  Result := 'INSERT INTO config (key, value) VALUES (:KEY, :VALUE) ' +
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value;';
end;

class procedure TConfigSql.ExecUpsertByKey(Q: TSQLQuery; const Key, Value: string);
begin
  Q.SQL.Text := UpsertByKey;
  Q.ParamByName('KEY').AsString := Key;
  Q.ParamByName('VALUE').AsString := Value;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class function TConfigSql.GetString(Q: TSQLQuery; const Key,
  DefaultValue: string): string;
begin
  Result := DefaultValue;
  Q.Close;
  Q.SQL.Text := SelectByKey;
  Q.ParamByName('KEY').AsString := Key;
  Q.Open;
  try
    if (not Q.EOF) and (not Q.FieldByName('value').IsNull) then
    begin
      Result := Q.FieldByName('value').AsString;
      if Result = '' then
        Result := DefaultValue;
    end;
  finally
    Q.Close;
  end;
end;

class function TConfigSql.GetBool(Q: TSQLQuery; const Key: string;
  const DefaultValue: boolean): boolean;
var
  valueText: string;
begin
  Result := DefaultValue;
  Q.Close;
  Q.SQL.Text := SelectByKey;
  Q.ParamByName('KEY').AsString := Key;
  Q.Open;
  try
    if (not Q.EOF) and (not Q.FieldByName('value').IsNull) then
    begin
      valueText := Trim(Q.FieldByName('value').AsString);
      if valueText <> '' then
        Result := ParseBoolText(valueText, DefaultValue);
    end;
  finally
    Q.Close;
  end;
end;

{ TMainSql }

class function TMainSql.SelectByNumber: string;
begin
  Result := 'SELECT * FROM main WHERE number = :NUMBER;';
end;

class function TMainSql.SelectAll: string;
begin
  Result := 'SELECT * FROM main;';
end;

class function TMainSql.SelectNumbers: string;
begin
  Result := 'SELECT number FROM main WHERE number IS NOT NULL;';
end;

class function TMainSql.UpdateGlobalStatus: string;
begin
  Result := 'UPDATE main SET status = :STATUS WHERE number = :NUMBER;';
end;

class function TMainSql.UpdateStageStatus(const StageIndex: integer;
  const StatusText, StageStatus: string): string;
begin
  Result := 'UPDATE main SET place' + IntToStr(StageIndex) + ' = NULL, result' +
    IntToStr(StageIndex) + ' = "' + StatusText + '", diffleader' + IntToStr(StageIndex) +
    ' = NULL, status' + IntToStr(StageIndex) + ' = ' + StageStatus +
    ' WHERE number = :NUMBER;';
end;

class function TMainSql.UpdateOnlyGlobalStatusDsq: string;
begin
  Result := 'UPDATE main SET status = 3 WHERE number = :NUMBER;';
end;

class function TMainSql.ClearStatusAllForStage(const StageIndex: integer): string;
begin
  Result := 'UPDATE main SET place' + IntToStr(StageIndex) + ' = NULL, result' +
    IntToStr(StageIndex) + ' = NULL, diffleader' + IntToStr(StageIndex) +
    ' = NULL, status' + IntToStr(StageIndex) +
    ' = NULL, status = NULL WHERE number = :NUMBER;';
end;

class function TMainSql.ClearOnlyGlobalStatus: string;
begin
  Result := 'UPDATE main SET status = NULL WHERE number = :NUMBER;';
end;

class function TMainSql.ClearStageStatus(const StageIndex: integer): string;
begin
  Result := 'UPDATE main SET place' + IntToStr(StageIndex) + ' = NULL, result' +
    IntToStr(StageIndex) + ' = NULL, diffleader' + IntToStr(StageIndex) +
    ' = NULL, status' + IntToStr(StageIndex) + ' = NULL WHERE number = :NUMBER;';
end;

class function TMainSql.ResetStartTime(const StageIndex: integer): string;
begin
  Result := 'UPDATE main SET starttime' + IntToStr(StageIndex) + ' = NULL;';
end;

class function TMainSql.UpdateStartTime(const StageIndex: integer): string;
begin
  Result := 'UPDATE main SET starttime' + IntToStr(StageIndex) +
    ' = :STARTTIME WHERE number = :NUMBER;';
end;

class function TMainSql.UpdateStartTimeForNumber(const StageIndex: integer): string;
begin
  Result := 'UPDATE main SET status' + IntToStr(StageIndex) + ' = NULL, starttime' +
    IntToStr(StageIndex) + ' = :STARTTIME WHERE number = :NUMBER;';
end;

class function TMainSql.SelectMinStartTime(const StageIndex: integer): string;
begin
  Result := 'SELECT min(starttime' + IntToStr(StageIndex) +
    ') as starttime FROM main WHERE starttime' + IntToStr(StageIndex) +
    ' NOTNULL;';
end;

class function TMainSql.SelectMaxNumber: string;
begin
  Result := 'SELECT MAX(number) as number FROM main;';
end;

class function TMainSql.SelectCategoryGrouped: string;
begin
  Result := 'SELECT category FROM main GROUP BY category;';
end;

class function TMainSql.SelectCategoryGroupedOrderedByStartTime(
  const StageIndex: integer): string;
begin
  Result := 'SELECT category FROM main GROUP BY category ORDER BY starttime' +
    IntToStr(StageIndex) + ';';
end;

class function TMainSql.SelectCategoryResults(const ColumnsCsv: string): string;
begin
  Result := 'SELECT ' + ColumnsCsv + ' FROM main ' +
    'WHERE category IS :CATEGORY ' +
    'ORDER BY IFNULL(sumplace,''toend''), IFNULL(sumresult,''toend'');';
end;

class function TMainSql.SelectNumberByStartTimeBetween(
  const StageIndex: integer): string;
begin
  Result := 'SELECT number FROM main WHERE starttime' + IntToStr(StageIndex) +
    ' BETWEEN :TIME_BEFORE AND :TIME_AFTER;';
end;

class function TMainSql.UpdateCorrection(const StageIndex: integer): string;
begin
  Result := 'UPDATE main SET correction' + IntToStr(StageIndex) +
    ' = :CORRECTION WHERE number = :NUMBER;';
end;

class function TMainSql.SelectByCategoryLeader(const StageIndex: integer): string;
begin
  Result := 'select * from main where category = :CATEGORY AND place' +
    IntToStr(StageIndex) + ' = 1;';
end;

class function TMainSql.UpdateFinishPrefix: string;
begin
  Result := 'UPDATE main';
end;

class function TMainSql.UpdateFinishSetPart(const StageIndex: integer): string;
begin
  Result := 'SET finishtime' + IntToStr(StageIndex) + ' = :TIME' +
    ', status' + IntToStr(StageIndex) + ' = NULL';
end;

class function TMainSql.UpdateFinishWhereNumber: string;
begin
  Result := 'WHERE number = :NUMBER;';
end;

class function TMainSql.SelectStatusAll: string;
begin
  Result := 'SELECT * FROM main WHERE status NOTNULL;';
end;

class function TMainSql.SelectStatusByStage(const StageIndex: integer): string;
begin
  Result := 'SELECT * FROM main WHERE status' + IntToStr(StageIndex) + ' NOTNULL;';
end;

class function TMainSql.SelectFinishExistsByStage(const StageIndex: integer): string;
begin
  Result := 'SELECT * FROM main WHERE finishtime' + IntToStr(StageIndex) +
    ' NOTNULL AND finishtime' + IntToStr(StageIndex) + ' <> '''';';
end;

class function TMainSql.ExportFinishTime(const StageIndex: integer): string;
begin
  Result := 'SELECT number, starttime' + IntToStr(StageIndex) + ', correction' +
    IntToStr(StageIndex) + ', finishtime' + IntToStr(StageIndex) + ', penalty' +
    IntToStr(StageIndex) + ', status' + IntToStr(StageIndex) + ' FROM main;';
end;

class function TMainSql.ExportAllResults: string;
begin
  Result := 'SELECT number, sumresult, sumstages, status FROM main;';
end;

class function TMainSql.ExportSumDays: string;
begin
  Result := 'SELECT main.category, sumdays.place, sumdays.number, main.name, ' +
    'main.nickname, main.age, main.team, main.city, sumdays.sumresult, ' +
    'sumdays.sumstages, sumdays.status FROM sumdays, main ' +
    'WHERE sumdays.number = main.number ORDER BY category, sumdays.sumstages DESC, sumdays.sumresult;';
end;

class function TMainSql.SelectPenaltyGroupsCount: string;
begin
  Result := 'SELECT COUNT(*) FROM main ' +
    'GROUP BY penalty1, penalty2, penalty3, penalty4, penalty5, penalty6, penalty7, penalty8;';
end;

class function TMainSql.OpenByNumber(Q: TSQLQuery; const Number: integer): boolean;
begin
  Q.Active := False;
  Q.SQL.Text := SelectByNumber;
  Q.ParamByName('NUMBER').AsInteger := Number;
  Q.Active := True;
  Result := not Q.EOF;
end;

class function TMainSql.OpenByCategoryLeader(Q: TSQLQuery;
  const StageIndex: integer; const Category: string): boolean;
begin
  Q.Active := False;
  Q.SQL.Text := SelectByCategoryLeader(StageIndex);
  Q.ParamByName('CATEGORY').AsString := Category;
  Q.Active := True;
  Result := not Q.EOF;
end;

class function TMainSql.TryGetNumberByStartTimeBetween(Q: TSQLQuery;
  const StageIndex: integer; const TimeBefore, TimeAfter: string;
  out Number: integer): boolean;
begin
  Result := False;
  Number := 0;
  Q.Close;
  Q.SQL.Text := SelectNumberByStartTimeBetween(StageIndex);
  Q.ParamByName('TIME_BEFORE').AsString := TimeBefore;
  Q.ParamByName('TIME_AFTER').AsString := TimeAfter;
  Q.Open;
  try
    if (not Q.EOF) and (not Q.Fields.Fields[0].IsNull) then
      Result := TryStrToInt(Q.Fields.Fields[0].AsString, Number);
  finally
    Q.Close;
  end;
end;

class function TMainSql.GetPenaltyGroupsCount(Q: TSQLQuery): integer;
begin
  Result := 0;
  Q.Close;
  Q.SQL.Text := SelectPenaltyGroupsCount;
  Q.Open;
  try
    while not Q.EOF do
    begin
      Inc(Result);
      Q.Next;
    end;
  finally
    Q.Close;
  end;
end;

class function TMainSql.GetFinishCount(Q: TSQLQuery;
  const StageIndex: integer): integer;
begin
  Result := 0;
  Q.Close;
  Q.SQL.Text := SelectFinishExistsByStage(StageIndex);
  Q.Open;
  try
    while not Q.EOF do
    begin
      Inc(Result);
      Q.Next;
    end;
  finally
    Q.Close;
  end;
end;

class procedure TMainSql.ExecUpdateStageStatus(Q: TSQLQuery;
  const StageIndex: integer; const StatusText, StageStatus, Number: string);
begin
  Q.SQL.Clear;
  Q.SQL.Add(UpdateStageStatus(StageIndex, StatusText, StageStatus));
  Q.ParamByName('NUMBER').AsString := Number;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TMainSql.ExecUpdateOnlyGlobalStatusDsq(Q: TSQLQuery;
  const Number: string);
begin
  Q.SQL.Clear;
  Q.SQL.Add(UpdateOnlyGlobalStatusDsq);
  Q.ParamByName('NUMBER').AsString := Number;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TMainSql.ExecUpdateGlobalStatus(Q: TSQLQuery;
  const StatusOrNull, Number: string);
begin
  Q.SQL.Text := UpdateGlobalStatus;
  if StatusOrNull = 'NULL' then
    Q.ParamByName('STATUS').Clear
  else
    Q.ParamByName('STATUS').AsInteger := StrToIntDef(StatusOrNull, 0);
  Q.ParamByName('NUMBER').AsString := Number;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TMainSql.ExecClearStatusAllForStage(Q: TSQLQuery;
  const StageIndex: integer; const Number: string);
begin
  Q.SQL.Clear;
  Q.SQL.Add(ClearStatusAllForStage(StageIndex));
  Q.ParamByName('NUMBER').AsString := Number;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TMainSql.ExecClearOnlyGlobalStatus(Q: TSQLQuery;
  const Number: string);
begin
  Q.SQL.Clear;
  Q.SQL.Add(ClearOnlyGlobalStatus);
  Q.ParamByName('NUMBER').AsString := Number;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TMainSql.ExecClearStageStatus(Q: TSQLQuery;
  const StageIndex: integer; const Number: string);
begin
  Q.SQL.Clear;
  Q.SQL.Add(ClearStageStatus(StageIndex));
  Q.ParamByName('NUMBER').AsString := Number;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TMainSql.ExecUpdateStartTimeForNumber(Q: TSQLQuery;
  const StageIndex: integer; const StartTime: string; const Number: integer);
begin
  Q.SQL.Text := UpdateStartTimeForNumber(StageIndex);
  Q.ParamByName('STARTTIME').AsString := StartTime;
  Q.ParamByName('NUMBER').AsInteger := Number;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TMainSql.ExecUpdateCorrection(Q: TSQLQuery;
  const StageIndex, Correction, Number: integer);
begin
  Q.SQL.Text := UpdateCorrection(StageIndex);
  Q.ParamByName('CORRECTION').AsInteger := Correction;
  Q.ParamByName('NUMBER').AsInteger := Number;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TMainSql.ExecUpdateFinishForCheckedStages(Q: TSQLQuery;
  const CheckedStages: array of integer; const TimeValue: string;
  const Number: integer);
var
  i: integer;
  setPart: string;
begin
  if Length(CheckedStages) = 0 then
    Exit;

  Q.SQL.Clear;
  Q.SQL.Add(UpdateFinishPrefix);
  for i := Low(CheckedStages) to High(CheckedStages) do
  begin
    setPart := UpdateFinishSetPart(CheckedStages[i]);
    if i > Low(CheckedStages) then
    begin
      if Pos('SET ', setPart) = 1 then
        Delete(setPart, 1, 4);
      setPart := ', ' + setPart;
    end;
    Q.SQL.Add(setPart);
  end;
  Q.SQL.Add(UpdateFinishWhereNumber);
  Q.ParamByName('TIME').AsString := TimeValue;
  Q.ParamByName('NUMBER').AsInteger := Number;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

{ TLoRaSql }

class function TLoRaSql.SelectPending: string;
begin
  Result := 'SELECT * FROM lora WHERE isset ISNULL;';
end;

class function TLoRaSql.SelectAll: string;
begin
  Result := 'SELECT * FROM lora;';
end;

class function TLoRaSql.SelectStartAfter: string;
begin
  Result := 'SELECT * FROM lora WHERE starttime > :STARTTIME;';
end;

class function TLoRaSql.ResetIsSetNull: string;
begin
  Result := 'UPDATE lora SET isset = 0 WHERE isset ISNULL;';
end;

class function TLoRaSql.SetIsSetById: string;
begin
  Result := 'UPDATE lora SET isset = 0 WHERE id = :ID;';
end;

class function TLoRaSql.SetIsSetByIdAndValue: string;
begin
  Result := 'UPDATE lora SET isset = :ISSET WHERE id = :ID;';
end;

class function TLoRaSql.InsertSample: string;
begin
  Result := 'INSERT INTO lora (number, starttime, correction, timemark) ' +
    'VALUES (:NUMBER, :STARTTIME, :CORRECTION, :TIMEMARK);';
end;

class procedure TLoRaSql.ExecSetIsSetByIdAndValue(Q: TSQLQuery;
  const IsSet, Id: integer);
begin
  Q.SQL.Text := SetIsSetByIdAndValue;
  Q.ParamByName('ISSET').AsInteger := IsSet;
  Q.ParamByName('ID').AsInteger := Id;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TLoRaSql.ExecInsertSample(Q: TSQLQuery; const HasNumber: boolean;
  const Number: integer; const StartTime: string; const Correction: integer;
  const TimeMark: string);
begin
  Q.SQL.Text := InsertSample;
  if HasNumber then
    Q.ParamByName('NUMBER').AsInteger := Number
  else
    Q.ParamByName('NUMBER').Clear;
  Q.ParamByName('STARTTIME').AsString := StartTime;
  Q.ParamByName('CORRECTION').AsInteger := Correction;
  Q.ParamByName('TIMEMARK').AsString := TimeMark;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

{ TSumDaysSql }

class function TSumDaysSql.CreateTableIfNotExists: string;
begin
  Result := FindCreateTableStatement('sumdays');
end;

class function TSumDaysSql.DeleteAll: string;
begin
  Result := 'DELETE from sumdays;';
end;

class function TSumDaysSql.UpsertPlacesByCategory: string;
begin
  Result := 'INSERT into sumdays (number, place) ' +
    'SELECT sumdays.number, row_number() over(partition BY category ORDER BY sumdays.sumresult) as place ' +
    'FROM main, sumdays ' +
    'WHERE sumdays.sumresult > 0 AND sumdays.sumstages = (SELECT MAX(sumstages) FROM sumdays) AND sumdays.number = main.number ' +
    'ORDER BY sumdays.sumresult DESC ' +
    'ON CONFLICT(number) DO UPDATE SET place = excluded.place;';
end;

{ TDatasetSql }

class function TDatasetSql.CorrectionPending(const StageIndex: integer): string;
begin
  Result := 'SELECT number, correction' + IntToStr(StageIndex) +
    ', id from main where correction' + IntToStr(StageIndex) +
    ' ISNULL AND status' + IntToStr(StageIndex) + ' ISNULL AND starttime' +
    IntToStr(StageIndex) + ' NOTNULL ORDER BY starttime' + IntToStr(StageIndex) + ';';
end;

class function TDatasetSql.TrackStatus(const StageIndex: integer): string;
begin
  Result := 'SELECT number, name, starttime' + IntToStr(StageIndex) +
    ' as starttime, strftime(''%H:%M:%S'',julianday(time(''now'', ''localtime'')) - julianday(time(starttime' +
    IntToStr(StageIndex) + ')) + 0.5) as timeontrack from main where julianday(time(''now'', ''localtime'')) > julianday(time(starttime' +
    IntToStr(StageIndex) + ')) AND finishtime' + IntToStr(StageIndex) +
    ' ISNULL AND status' + IntToStr(StageIndex) + ' ISNULL ORDER BY starttime;';
end;

class function TDatasetSql.ResultStage(const StageIndex: integer): string;
begin
  Result := 'SELECT category, place' + IntToStr(StageIndex) + ', number, name, penalty' +
    IntToStr(StageIndex) + ', result' + IntToStr(StageIndex) + ', diffleader' +
    IntToStr(StageIndex) + ', CASE status WHEN ''3'' THEN ''3'' ELSE status' +
    IntToStr(StageIndex) + ' END status' + IntToStr(StageIndex) +
    ' from main where result' + IntToStr(StageIndex) + ' NOTNULL ORDER BY category, status' +
    IntToStr(StageIndex) + ', place' + IntToStr(StageIndex) + ';';
end;

class function TDatasetSql.ResultStageTotal: string;
begin
  Result := 'SELECT category, thruplace as sumplace, number, name, sumresult, thrudiff, sumstages FROM main WHERE sumresult NOTNULL ORDER BY status, thruplace;';
end;

class function TDatasetSql.ResultStageSum: string;
var
  I: integer;
begin
  Result := 'SELECT category, sumplace, number, name';
  for I := 1 to 8 do
    Result := Result + ', result' + IntToStr(I);
  Result := Result +
    ', sumresult, sumdiffleader from main WHERE sumresult NOTNULL ' +
    'ORDER BY category, status, sumstages DESC, IFNULL(sumplace,''toend'');';
end;

{ TStartlistSql }

class function TStartlistSql.SelectNumbersForCategory(const SortBy: integer;
  const IncludeDNS, IncludeDNF, IncludeDSQ: boolean): string;
begin
  Result := 'SELECT number FROM main WHERE category IS :CATEGORY ';
  case SortBy of
    STARTLIST_SORT_BY_RESULT:
      begin
        if not IncludeDNS then
          Result := Result + 'AND sumresult <> ''DNS'' ';
        if not IncludeDNF then
          Result := Result + 'AND sumresult <> ''DNF'' ';
        if not IncludeDSQ then
          Result := Result + 'AND sumresult <> ''DSQ'' ';
        if IncludeDNS or IncludeDNF or IncludeDSQ then
          Result := Result + 'OR sumresult IS NULL '
        else
          Result := Result + 'AND sumresult NOTNULL ';
        Result := Result + 'ORDER BY sumstages DESC NULLS FIRST, sumresult DESC NULLS FIRST;';
      end;
    STARTLIST_SORT_BY_NUMBER_ASC:
      Result := Result + 'ORDER BY number ASC;';
    STARTLIST_SORT_BY_NUMBER_DESC:
      Result := Result + 'ORDER BY number DESC;';
    STARTLIST_SORT_BY_NAME_ASC:
      Result := Result + 'ORDER BY name ASC;';
    STARTLIST_SORT_BY_NAME_DESC:
      Result := Result + 'ORDER BY name DESC;';
  else
    Result := Result + ';';
  end;
end;

{ TResultsSql }

class function TResultsSql.SelectForSumCalculation(
  const ActiveStages: array of integer): string;
var
  I: integer;
begin
  Result := 'SELECT number, status';
  for I := Low(ActiveStages) to High(ActiveStages) do
    Result := Result + ', result' + IntToStr(ActiveStages[I]);
  Result := Result + ' FROM main;';
end;

class function TResultsSql.UpdateStageResult(const StageIndex: integer): string;
begin
  Result := 'UPDATE main SET result' + IntToStr(StageIndex) + ' = CASE ' +
    'WHEN status IS "3" THEN "DSQ" ' +
    'WHEN status' + IntToStr(StageIndex) + ' IS "1" THEN "DNF" ' +
    'WHEN status' + IntToStr(StageIndex) + ' IS "2" THEN "DNS" ' +
    'WHEN correction' + IntToStr(StageIndex) + ' IS NULL AND penalty' + IntToStr(StageIndex) +
    ' IS NULL AND status' + IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) + ') +1.5) ' +
    'WHEN correction' + IntToStr(StageIndex) + ' < 0 AND penalty' + IntToStr(StageIndex) +
    ' IS NULL AND status' + IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') +1.5 - julianday(-correction' + IntToStr(StageIndex) + '/86400000.0)) ' +
    'WHEN correction' + IntToStr(StageIndex) + ' >= 0 AND penalty' + IntToStr(StageIndex) +
    ' IS NULL AND status' + IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') +1.5 + julianday(correction' + IntToStr(StageIndex) + '/86400000.0)) ' +
    'WHEN correction' + IntToStr(StageIndex) + ' IS NULL AND penalty' + IntToStr(StageIndex) +
    ' > 0 AND status' + IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') + julianday(penalty' + IntToStr(StageIndex) + ') -0.5 +1.5) ' +
    'WHEN correction' + IntToStr(StageIndex) + ' < 0 AND penalty' + IntToStr(StageIndex) +
    ' > 0 AND status' + IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') +1.5 + julianday(penalty' + IntToStr(StageIndex) +
    ')-0.5 - julianday(-correction' + IntToStr(StageIndex) + '/86400000.0)) ' +
    'WHEN correction' + IntToStr(StageIndex) + ' >= 0 AND penalty' + IntToStr(StageIndex) +
    ' > 0 AND status' + IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') +1.5 + julianday(penalty' + IntToStr(StageIndex) +
    ')-0.5 + julianday(correction' + IntToStr(StageIndex) + '/86400000.0)) ' +
    'END, finishtime' + IntToStr(StageIndex) + ' = CASE WHEN status' +
    IntToStr(StageIndex) + ' NOTNULL THEN NULL ELSE finishtime' + IntToStr(StageIndex) + ' END;';
end;

class function TResultsSql.ResetStagePlaceAndDiff(const StageIndex: integer): string;
begin
  Result := 'UPDATE main SET place' + IntToStr(StageIndex) + ' = NULL, diffleader' +
    IntToStr(StageIndex) + ' = NULL;';
end;

class function TResultsSql.UpsertStagePlace(const StageIndex: integer): string;
begin
  Result := 'INSERT into main (number, place' + IntToStr(StageIndex) + ') ' +
    'SELECT number, row_number() over(partition BY category ORDER BY result' +
    IntToStr(StageIndex) + ') as place' + IntToStr(StageIndex) +
    ' FROM main WHERE result' + IntToStr(StageIndex) + ' > 0 AND status' +
    IntToStr(StageIndex) + ' ISNULL AND (status IS NULL OR status <> 3) ' +
    'ORDER BY finishtime' + IntToStr(StageIndex) + ' DESC ' +
    'ON CONFLICT(number) DO UPDATE SET place' + IntToStr(StageIndex) +
    ' = excluded.place' + IntToStr(StageIndex) + ';';
end;

class function TResultsSql.ResetStageDiffLeader(const StageIndex: integer): string;
begin
  Result := 'UPDATE main SET diffleader' + IntToStr(StageIndex) +
    ' = NULL WHERE place' + IntToStr(StageIndex) + ' = 1;';
end;

class function TResultsSql.UpsertStageDiffLeader(const StageIndex: integer): string;
begin
  Result := 'WITH ' +
    't1(leader1, cat1, num1) AS (SELECT julianday(result' + IntToStr(StageIndex) +
    '), category, number FROM main WHERE place' + IntToStr(StageIndex) + ' = 1), ' +
    't2(current,cat2, num2) AS (SELECT julianday(result' + IntToStr(StageIndex) +
    '), category, number FROM main WHERE place' + IntToStr(StageIndex) + ' > 1) ' +
    'INSERT into main (diffleader' + IntToStr(StageIndex) + ', number) ' +
    'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), t2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2 ' +
    'ON CONFLICT(number) DO UPDATE SET diffleader' + IntToStr(StageIndex) +
    '= excluded.diffleader' + IntToStr(StageIndex) + ';';
end;

class function TResultsSql.UpdateSumResult: string;
begin
  Result := 'UPDATE main SET sumresult = :SUMRESULT, ' +
    'sumstages = :SUMSTAGES, ' +
    'status = CASE WHEN :CLEAR_STATUS = 1 THEN NULL ELSE status END ' +
    'WHERE number = :NUMBER;';
end;

class function TResultsSql.ResetSumPlaceAndDiff: string;
begin
  Result := 'UPDATE main SET sumplace = NULL, sumdiffleader = NULL;';
end;

class function TResultsSql.UpsertSumPlace: string;
begin
  Result := 'INSERT into main (number, sumplace) ' +
    'SELECT number, row_number() over(partition BY category ORDER BY sumresult) as sumplace ' +
    'FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY sumresult DESC ' +
    'ON CONFLICT(number) DO UPDATE SET sumplace = excluded.sumplace;';
end;

class function TResultsSql.UpsertSumPlaceOnlyFullStages(
  const ActiveStages: array of integer): string;
var
  I: integer;
begin
  Result := 'INSERT into main (number, sumplace) ' +
    'SELECT number, row_number() over(partition BY category ORDER BY sumresult) as sumplace ' +
    'FROM main WHERE sumresult > 0 AND status ISNULL ';
  for I := Low(ActiveStages) to High(ActiveStages) do
    Result := Result + 'AND result' + IntToStr(ActiveStages[I]) + ' NOTNULL ' +
      'AND status' + IntToStr(ActiveStages[I]) + ' IS NULL ';
  Result := Result + 'ORDER BY sumresult DESC ' +
    'ON CONFLICT(number) DO UPDATE SET sumplace = excluded.sumplace;';
end;

class function TResultsSql.ResetSumDiffLeader: string;
begin
  Result := 'UPDATE main SET sumdiffleader = NULL WHERE sumplace = 1;';
end;

class function TResultsSql.UpsertSumDiffLeader: string;
begin
  Result := 'WITH ' +
    't1(leader1, cat1, num1) AS (SELECT julianday(sumresult), category, number FROM main WHERE sumplace = 1), ' +
    't2(current,cat2, num2) AS (SELECT julianday(sumresult), category, number FROM main WHERE sumplace > 1) ' +
    'INSERT into main (sumdiffleader, number) ' +
    'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), t2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2 ' +
    'ON CONFLICT(number) DO UPDATE SET sumdiffleader= excluded.sumdiffleader;';
end;

class function TResultsSql.UpsertSumDiffByStages(const StageCaption: string): string;
begin
  Result := 'WITH ' +
    't1(sumstages1, cat1, num1) AS (SELECT sumstages, category, number FROM main WHERE sumplace = 1), ' +
    't2(current,cat2, num2) AS (SELECT sumstages, category, number FROM main WHERE sumplace IS NULL AND sumstages NOT NULL AND (status < 3 OR status IS NULL)) ' +
    'INSERT into main (sumdiffleader, number) ' +
    'SELECT ''+'' || (t1.sumstages1 - t2.current) || '' ' + StageCaption + ''', t2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2 ' +
    'ON CONFLICT(number) DO UPDATE SET sumdiffleader= excluded.sumdiffleader;';
end;

class function TResultsSql.ResetThru: string;
begin
  Result := 'UPDATE main SET thrudiff = NULL, thruplace = NULL;';
end;

class function TResultsSql.UpsertThruPlace: string;
begin
  Result := 'INSERT into main (number, thruplace) ' +
    'SELECT number, row_number() over(ORDER BY sumstages DESC, sumresult) as thruplace ' +
    'FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY thruplace ' +
    'ON CONFLICT(number) DO UPDATE SET thruplace = excluded.thruplace;';
end;

class function TResultsSql.UpsertThruDiff: string;
begin
  Result := 'WITH ' +
    'tthru(sumresult, number, thruplace) AS (SELECT sumresult, number, thruplace FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY thruplace), ' +
    't1(leader1, num1) AS (SELECT julianday(sumresult), number FROM tthru WHERE thruplace = 1), ' +
    't2(current, num2) AS (SELECT julianday(sumresult), number FROM tthru WHERE thruplace > 1) ' +
    'INSERT into main (thrudiff, number) ' +
    'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), t2.num2 from t1, t2, tthru WHERE t2.num2 = tthru.number ORDER BY thruplace ' +
    'ON CONFLICT(number) DO UPDATE SET thrudiff= excluded.thrudiff;';
end;

class function TResultsSql.UpsertThruDiffByStages(const StageCaption: string): string;
begin
  Result := 'WITH ' +
    't1(sumstages1, num1) AS (SELECT sumstages, number FROM main WHERE thruplace = 1), ' +
    't2(current, num2) AS (SELECT sumstages, number FROM main WHERE sumplace IS NULL AND sumstages NOT NULL AND (status < 3 OR status IS NULL)) ' +
    'INSERT into main (thrudiff, number) ' +
    'SELECT ''+'' || (t1.sumstages1 - t2.current) || '' ' + StageCaption + ''', t2.num2 from t1, t2 WHERE TRUE ' +
    'ON CONFLICT(number) DO UPDATE SET thrudiff= excluded.thrudiff;';
end;

class function TResultsSql.ClearResultsPrefix: string;
begin
  Result := 'UPDATE main SET';
end;

class function TResultsSql.ClearResultsStagePart(const StageIndex: integer): string;
begin
  Result := 'correction' + IntToStr(StageIndex) + '=NULL, finishtime' +
    IntToStr(StageIndex) + '=NULL, penalty' + IntToStr(StageIndex) +
    '=NULL, result' + IntToStr(StageIndex) + '=NULL, diffleader' +
    IntToStr(StageIndex) + '=NULL, place' + IntToStr(StageIndex) + '=NULL, status' +
    IntToStr(StageIndex) + '=NULL,';
end;

class function TResultsSql.ClearResultsSuffix: string;
begin
  Result := 'sumplace=NULL, sumresult=NULL, sumdiffleader=NULL, thrudiff=NULL, status=NULL;';
end;

{ TLoadSql }

class function TLoadSql.DeleteLoad: string;
begin
  Result := 'DELETE from load';
end;

class function TLoadSql.DeleteLoadResult: string;
begin
  Result := 'DELETE from loadresult';
end;

class function TLoadSql.UpsertConfigByKey: string;
begin
  Result := TConfigSql.UpsertByKey;
end;

class procedure TLoadSql.ExecDeleteLoad(Q: TSQLQuery);
begin
  Q.SQL.Text := DeleteLoad;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TLoadSql.ExecDeleteLoadResult(Q: TSQLQuery);
begin
  Q.SQL.Text := DeleteLoadResult;
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class procedure TLoadSql.ExecInsertLoadMainFromLoad(Q: TSQLQuery;
  const MaxStages: integer);
begin
  Q.SQL.Text := InsertLoadMainFromLoad(MaxStages);
  Q.Close;
  Q.ExecSQL;
  Q.SQLTransaction.Commit;
  Q.Close;
end;

class function TLoadSql.DeleteLoadStatement: string;
begin
  Result := DeleteLoad;
end;

class function TLoadSql.DeleteLoadResultStatement: string;
begin
  Result := DeleteLoadResult;
end;

class function TLoadSql.InsertLoadHeader(const MaxStages: integer): string;
var
  I: integer;
begin
  Result := 'INSERT INTO load (category, number, name, nickname, age, team, city, phone, email, comment,';
  for I := 1 to MaxStages do
  begin
    Result := Result + 'starttime' + IntToStr(I);
    if I < MaxStages then
      Result := Result + ',';
  end;
  Result := Result + ') VALUES';
end;

class function TLoadSql.InsertLoadRow(const MaxStages: integer): string;
var
  I: integer;
begin
  Result := InsertLoadHeader(MaxStages) +
    ' (:CATEGORY, :NUMBER, :NAME, :NICKNAME, :AGE, :TEAM, :CITY, ' +
    ':PHONE, :EMAIL, :COMMENT,';
  for I := 1 to MaxStages do
  begin
    Result := Result + ':STARTTIME' + IntToStr(I);
    if I < MaxStages then
      Result := Result + ',';
  end;
  Result := Result + ');';
end;

class function TLoadSql.InsertLoadMainFromLoad(
  const MaxStages: integer): string;
begin
  Result := InsertLoadMainHeader(MaxStages) + LineEnding +
    InsertLoadMainSelect(MaxStages) + LineEnding +
    InsertLoadMainUpsert(MaxStages);
end;

class function TLoadSql.InsertLoadMainHeader(const MaxStages: integer): string;
var
  I: integer;
begin
  Result := 'INSERT into main (category, number, name, nickname, age, team, city, phone, email, comment,';
  for I := 1 to MaxStages do
  begin
    Result := Result + 'starttime' + IntToStr(I);
    if I < MaxStages then
      Result := Result + ',';
  end;
  Result := Result + ')';
end;

class function TLoadSql.InsertLoadMainSelect(const MaxStages: integer): string;
var
  I: integer;
begin
  Result := 'SELECT category, number, name, nickname, age, team, city, phone, email, comment,';
  for I := 1 to MaxStages do
  begin
    Result := Result + 'starttime' + IntToStr(I);
    if I < MaxStages then
      Result := Result + ',';
  end;
  Result := Result + ' FROM load WHERE number NOTNULL AND number != "" AND number != 0';
end;

class function TLoadSql.InsertLoadMainUpsert(const MaxStages: integer): string;
var
  I: integer;
begin
  Result := 'ON CONFLICT(number) DO UPDATE SET ' +
    'category = excluded.category, name = excluded.name, nickname = excluded.nickname, ' +
    'age = excluded.age, team = excluded.team, city = excluded.city, phone = excluded.phone, ' +
    'email = excluded.email, comment = excluded.comment,';
  for I := 1 to MaxStages do
  begin
    Result := Result + 'starttime' + IntToStr(I) + '= excluded.starttime' + IntToStr(I);
    if I < MaxStages then
      Result := Result + ',';
  end;
  Result := Result + ';';
end;

class function TLoadSql.InsertLoadResultHeader6: string;
begin
  Result := 'INSERT INTO loadresult (number, starttime, correction, finishtime, penalty, status) VALUES';
end;

class function TLoadSql.InsertLoadResultHeader3: string;
begin
  Result := 'INSERT INTO loadresult (number, starttime, correction, status) VALUES';
end;

class function TLoadSql.InsertLoadResultHeader2: string;
begin
  Result := 'INSERT INTO loadresult (number, finishtime, status) VALUES';
end;

class function TLoadSql.InsertLoadResultRow6: string;
begin
  Result := InsertLoadResultHeader6 +
    ' (:NUMBER, :STARTTIME, :CORRECTION, :FINISHTIME, :PENALTY, :STATUS);';
end;

class function TLoadSql.InsertLoadResultRow3: string;
begin
  Result := InsertLoadResultHeader3 +
    ' (:NUMBER, :STARTTIME, :CORRECTION, :STATUS);';
end;

class function TLoadSql.InsertLoadResultRow2: string;
begin
  Result := InsertLoadResultHeader2 +
    ' (:NUMBER, :FINISHTIME, :STATUS);';
end;

class function TLoadSql.UpsertMainFromLoadResult6(const StageIndex: integer): string;
begin
  Result := 'INSERT into main (number,starttime' + IntToStr(StageIndex) +
    ',correction' + IntToStr(StageIndex) + ',finishtime' + IntToStr(StageIndex) +
    ',penalty' + IntToStr(StageIndex) + ',status' + IntToStr(StageIndex) + ') ' +
    'SELECT number, starttime, correction, finishtime, penalty, status FROM loadresult WHERE number NOTNULL ' +
    'ON CONFLICT (number) DO UPDATE SET ' +
    'starttime' + IntToStr(StageIndex) + ' = excluded.starttime' + IntToStr(StageIndex) + ', ' +
    'correction' + IntToStr(StageIndex) + ' = excluded.correction' + IntToStr(StageIndex) + ', ' +
    'finishtime' + IntToStr(StageIndex) + ' = excluded.finishtime' + IntToStr(StageIndex) + ', ' +
    'penalty' + IntToStr(StageIndex) + ' = excluded.penalty' + IntToStr(StageIndex) + ', ' +
    'status' + IntToStr(StageIndex) + ' = excluded.status' + IntToStr(StageIndex) + ';';
end;

class function TLoadSql.UpsertMainFromLoadResult3(const StageIndex: integer): string;
begin
  Result := 'INSERT into main (number,starttime' + IntToStr(StageIndex) +
    ',correction' + IntToStr(StageIndex) + ',status' + IntToStr(StageIndex) + ') ' +
    'SELECT number, starttime, correction, status FROM loadresult WHERE number NOTNULL ' +
    'ON CONFLICT (number) DO UPDATE SET ' +
    'starttime' + IntToStr(StageIndex) + ' = excluded.starttime' + IntToStr(StageIndex) + ', ' +
    'correction' + IntToStr(StageIndex) + ' = excluded.correction' + IntToStr(StageIndex) + ', ' +
    'status' + IntToStr(StageIndex) + ' = excluded.status' + IntToStr(StageIndex) + ';';
end;

class function TLoadSql.UpsertMainFromLoadResult2(const StageIndex: integer): string;
begin
  Result := 'INSERT into main (number,finishtime' + IntToStr(StageIndex) +
    ',status' + IntToStr(StageIndex) + ') ' +
    'SELECT number, finishtime, status FROM loadresult WHERE number NOTNULL ' +
    'ON CONFLICT (number) DO UPDATE SET ' +
    'finishtime' + IntToStr(StageIndex) + ' = excluded.finishtime' + IntToStr(StageIndex) + ', ' +
    'status' + IntToStr(StageIndex) + ' = excluded.status' + IntToStr(StageIndex) + ';';
end;

class function TLoadSql.UpsertMainFromLoadResult6Statement(
  const StageIndex: integer): string;
begin
  Result := UpsertMainFromLoadResult6(StageIndex);
end;

class function TLoadSql.UpsertMainFromLoadResult3Statement(
  const StageIndex: integer): string;
begin
  Result := UpsertMainFromLoadResult3(StageIndex);
end;

class function TLoadSql.UpsertMainFromLoadResult2Statement(
  const StageIndex: integer): string;
begin
  Result := UpsertMainFromLoadResult2(StageIndex);
end;

class function TLoadSql.AddDayInsertLoadHeader: string;
begin
  Result := 'INSERT INTO load (number, starttime1, age, starttime2) VALUES';
end;

class function TLoadSql.AddDayNormalizeResult: string;
begin
  Result := 'UPDATE load SET starttime1 = "00:00:00.000" WHERE starttime1 = "DSQ" OR starttime1 = "DNF" OR starttime1 = "DNS" OR starttime1 ISNULL OR starttime1 = "";';
end;

class function TLoadSql.AddDayNormalizeStages: string;
begin
  Result := 'UPDATE load SET age = "0" WHERE age = "";';
end;

class function TLoadSql.AddDayNormalizeStatus: string;
begin
  Result := 'UPDATE load SET starttime2 = "0" WHERE starttime2 = "";';
end;

class function TLoadSql.AddDayUpsertSumdays: string;
begin
  Result := 'INSERT into sumdays (number, sumresult, sumstages, status) ' +
    'SELECT number, starttime1, age, starttime2 FROM load WHERE number NOTNULL AND number != "" ' +
    'ON CONFLICT(number) DO UPDATE SET ' +
    'sumresult = strftime(''%H:%M:%f'',julianday(excluded.sumresult) + julianday(sumresult) +0.5), ' +
    'sumstages = excluded.sumstages + sumstages, ' +
    'status = excluded.status + status;';
end;

class function TLoadSql.ValuesRowFromEscaped(const EscapedDelimited: string): string;
begin
  Result := '(''' + EscapedDelimited + ''')';
end;

class function TLoadSql.SqlComma: string;
begin
  Result := ',';
end;

class function TLoadSql.SqlSemicolon: string;
begin
  Result := ';';
end;

class function TLoadSql.SqlOpenParen: string;
begin
  Result := '(';
end;

class function TLoadSql.SqlCloseParen: string;
begin
  Result := ')';
end;

class function TLoadSql.SqlValueNull: string;
begin
  Result := 'NULL';
end;

class function TLoadSql.SqlValue1: string;
begin
  Result := '1';
end;

class function TLoadSql.SqlValue2: string;
begin
  Result := '2';
end;

{ TSchemaSql }

class function TSchemaSql.CreateTableMain(const MaxStages: integer): string;
var
  templateSql: string;
begin
  templateSql := FindCreateTableStatement('main');
  if Pos(MAIN_STAGE_COLUMNS_PLACEHOLDER, templateSql) = 0 then
    raise Exception.CreateFmt(
      'Placeholder "%s" not found in CREATE TABLE main statement.',
      [MAIN_STAGE_COLUMNS_PLACEHOLDER]);
  Result := StringReplace(templateSql, MAIN_STAGE_COLUMNS_PLACEHOLDER,
    BuildMainStageColumnsSql(MaxStages), [rfReplaceAll]);
end;

class function TSchemaSql.CreateTableLoad(const MaxStages: integer): string;
var
  templateSql: string;
begin
  templateSql := FindCreateTableStatement('load');
  if Pos(LOAD_STARTTIME_COLUMNS_PLACEHOLDER, templateSql) = 0 then
    raise Exception.CreateFmt(
      'Placeholder "%s" not found in CREATE TABLE load statement.',
      [LOAD_STARTTIME_COLUMNS_PLACEHOLDER]);
  Result := StringReplace(templateSql, LOAD_STARTTIME_COLUMNS_PLACEHOLDER,
    BuildLoadStartTimeColumnsSql(MaxStages), [rfReplaceAll]);
end;

class function TSchemaSql.CreateTableLoadResult: string;
begin
  Result := FindCreateTableStatement('loadresult');
end;

class function TSchemaSql.CreateTableStart: string;
begin
  Result := FindCreateTableStatement('start');
end;

class function TSchemaSql.CreateTableFinish: string;
begin
  Result := FindCreateTableStatement('finish');
end;

class function TSchemaSql.CreateTableConfig: string;
begin
  Result := FindCreateTableStatement('config');
end;

class function TSchemaSql.CreateTableLoRa: string;
begin
  Result := FindCreateTableStatement('lora');
end;

class function TSchemaSql.InsertDefaultConfig(const Cat1, Cat2, Cat3,
  Cat4, Cat5: string): string;
begin
  Result := 'INSERT INTO config (key, value) VALUES' + '("activestage", "1"),' +
    '("stage1", "True"),' + '("catname1", "' + Cat1 + '"),' +
    '("catname2", "' + Cat2 + '"),' + '("catname3", "' + Cat3 + '"),' +
    '("catname4", "' + Cat4 + '"),' + '("catname5", "' + Cat5 + '")' + ';';
end;

class procedure TSchemaSql.ExecCreateTables(Connection: TSQLite3Connection;
  const MaxStages: integer; const Cat1, Cat2, Cat3, Cat4, Cat5: string;
  const RaceName: string);
var
  Q: TSQLQuery;
begin
  if not Assigned(Connection) then
    raise Exception.Create('Connection must be assigned.');
  if not Assigned(Connection.Transaction) then
    raise Exception.Create('Connection.Transaction must be assigned.');

  Connection.ExecuteDirect(CreateTableMain(MaxStages));
  Connection.Transaction.Commit;

  Connection.ExecuteDirect(CreateTableLoad(MaxStages));
  Connection.Transaction.Commit;

  Connection.ExecuteDirect(CreateTableLoadResult);
  Connection.Transaction.Commit;

  Connection.ExecuteDirect(CreateTableStart);
  Connection.Transaction.Commit;

  Connection.ExecuteDirect(CreateTableFinish);
  Connection.Transaction.Commit;

  Connection.ExecuteDirect(CreateTableConfig);
  Connection.Transaction.Commit;

  Connection.ExecuteDirect(CreateTableLoRa);
  Connection.Transaction.Commit;

  Connection.ExecuteDirect(InsertDefaultConfig(Cat1, Cat2, Cat3, Cat4, Cat5));
  Connection.Transaction.Commit;

  Q := TSQLQuery.Create(nil);
  try
    Q.DataBase := Connection;
    Q.Transaction := Connection.Transaction;
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

class function TSchemaSql.VacuumInto(const FileName: string): string;
begin
  Result := 'VACUUM INTO "' + FileName + '";';
end;

finalization
  FreeAndNil(SchemaStatementsCache);

end.
