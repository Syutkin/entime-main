unit CompetitionQueryProvider;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SQLDB, StageConfig, StartMarkRepository, FinishMarkRepository;

const
  STARTLIST_SORT_BY_NUMBER_ASC = 0;
  STARTLIST_SORT_BY_NUMBER_DESC = 1;
  STARTLIST_SORT_BY_NAME_ASC = 2;
  STARTLIST_SORT_BY_NAME_DESC = 3;
  STARTLIST_SORT_BY_RESULT = 4;

type
  TQueryStringArray = array of string;
  TQueryStringMatrix = array of TQueryStringArray;

  TQuerySnapshot = record
    ColumnNames: TQueryStringArray;
    Rows: TQueryStringMatrix;
  end;

  TDatasetSql = record
  private
    class procedure ConfigureQuery(Q: TSQLQuery; const SqlText: string;
      const IsReadOnly: boolean); static;
  public
    class function MainParticipants(
      const StageIndexes: array of integer): string; static;
    class function CategoryStatistics: string; static;
    class function CorrectionPending(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string;
      static;
    class function TrackStatus(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function ResultStage(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function ResultStageTotal: string; static;
    class function ResultStageSum(
      const StageIndexes: array of integer): string; static;
    class function CategoryStageResults(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string;
      static;
    class function LatestStageResults(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string;
      static;

    class procedure ConfigureMainParticipants(Q: TSQLQuery;
      const StageIndexes: array of integer); static;
    class procedure ConfigureCategoryStatistics(Q: TSQLQuery); static;
    class procedure ConfigureCorrectionPending(Q: TSQLQuery;
      const StageIndex: integer; const StageCount: integer =
      MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ConfigureTrackStatus(Q: TSQLQuery;
      const StageIndex: integer; const StageCount: integer =
      MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ConfigureResultStage(Q: TSQLQuery;
      const StageIndex: integer; const StageCount: integer =
      MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ConfigureResultStageTotal(Q: TSQLQuery); static;
    class procedure ConfigureResultStageSum(Q: TSQLQuery;
      const StageIndexes: array of integer); static;
    class procedure ConfigureCategoryStageResults(Q: TSQLQuery;
      const StageIndex: integer; const Category: string;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ConfigureLatestStageResults(Q: TSQLQuery;
      const StageIndex: integer; const StageCount: integer =
      MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ConfigureStartMarkWorkQueue(Q: TSQLQuery); static;
    class procedure ConfigureFinishMarkWorkQueue(Q: TSQLQuery); static;
    class procedure ConfigureStartMarkJournal(Q: TSQLQuery); static; overload;
    class procedure ConfigureStartMarkJournal(Q: TSQLQuery;
      const AFilter: TStartMarkJournalFilter;
      const AReceivedSince: TDateTime;
      const AStageIndex: integer); static; overload;
    class procedure ConfigureFinishMarkJournal(Q: TSQLQuery); static; overload;
    class procedure ConfigureFinishMarkJournal(Q: TSQLQuery;
      const AFilter: TFinishMarkJournalFilter;
      const AReceivedSince: TDateTime;
      const AStageIndex: integer); static; overload;
    class function Capture(Q: TSQLQuery; const Reopen: boolean;
      const CloseAfter: boolean = False): TQuerySnapshot; static;
  end;

  TStartlistSql = record
  public
    class function SelectNumbersForCategory(const SortBy: integer;
      const IncludeDNS, IncludeDNF, IncludeDSQ: boolean): string; static;
    class procedure ConfigureNumbersForCategory(Q: TSQLQuery;
      const SortBy: integer; const IncludeDNS, IncludeDNF, IncludeDSQ: boolean;
      const Category: string); static;
  end;

implementation

uses
  SysUtils, ParticipantStatus, SqlValueHelpers, StageFieldNames;

const
  MAIN_PARTICIPANT_FIXED_COLUMNS =
    '"id", "category", "sumplace", "number", "rfid", "name", ' +
    '"nickname", "age", "team", "city", "phone", "email", "comment", ' +
    '"sumresult", "sumdiffleader", "status", "sumstages", "thrudiff", ' +
    '"thruplace"';

class procedure TDatasetSql.ConfigureQuery(Q: TSQLQuery;
  const SqlText: string; const IsReadOnly: boolean);
begin
  if Q = nil then
    Exit;
  Q.Close;
  Q.ReadOnly := IsReadOnly;
  Q.SQL.Text := SqlText;
end;

class function TDatasetSql.Capture(Q: TSQLQuery; const Reopen: boolean;
  const CloseAfter: boolean): TQuerySnapshot;
var
  FieldIndex, RowIndex: integer;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Result := Default(TQuerySnapshot);
  if Reopen then
  begin
    Q.Close;
    Q.Open;
  end
  else if not Q.Active then
    Q.Open;
  try
    SetLength(Result.ColumnNames, Q.Fields.Count);
    for FieldIndex := 0 to Q.Fields.Count - 1 do
      Result.ColumnNames[FieldIndex] := Q.Fields[FieldIndex].FieldName;
    Q.First;
    RowIndex := 0;
    while not Q.EOF do
    begin
      SetLength(Result.Rows, RowIndex + 1);
      SetLength(Result.Rows[RowIndex], Q.Fields.Count);
      for FieldIndex := 0 to Q.Fields.Count - 1 do
        Result.Rows[RowIndex][FieldIndex] := Q.Fields[FieldIndex].AsString;
      Inc(RowIndex);
      Q.Next;
    end;
  finally
    if CloseAfter then
      Q.Close;
  end;
end;

class function TDatasetSql.MainParticipants(
  const StageIndexes: array of integer): string;
var
  Seen: array[MIN_STAGE_COUNT..MAX_SUPPORTED_STAGE_COUNT] of boolean;
  Columns: string;
  ArrayIndex, StageIndex: integer;
  FieldKind: TStageFieldKind;
begin
  if Length(StageIndexes) = 0 then
    raise EStageIndexError.Create('At least one active stage is required.');
  FillChar(Seen, SizeOf(Seen), 0);
  Columns := MAIN_PARTICIPANT_FIXED_COLUMNS;
  for ArrayIndex := 0 to High(StageIndexes) do
  begin
    StageIndex := StageIndexes[ArrayIndex];
    RequireSupportedStageIndex(StageIndex);
    if Seen[StageIndex] then
      raise EStageIndexError.CreateFmt(
        'Duplicate stage index: %d.', [StageIndex]);
    Seen[StageIndex] := True;
    for FieldKind := Succ(sfkUnknown) to High(TStageFieldKind) do
      Columns := Columns + ', ' + SqlIdentifier(
        StageFieldPrefix(FieldKind) + IntToStr(StageIndex));
  end;
  Result := 'SELECT ' + Columns + ' FROM main;';
end;

class function TDatasetSql.CategoryStatistics: string;
begin
  Result := 'SELECT id as id_stat, category, count(number) as catcount ' +
    'FROM main GROUP BY category;';
end;

class function TDatasetSql.CorrectionPending(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT number, correction' + IntToStr(StageIndex) +
    ' AS correction, id from main where correction' + IntToStr(StageIndex) +
    ' ISNULL AND status' + IntToStr(StageIndex) + ' ISNULL AND starttime' +
    IntToStr(StageIndex) + ' NOTNULL ORDER BY starttime' +
    IntToStr(StageIndex) + ';';
end;

class function TDatasetSql.TrackStatus(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT number, name, starttime' + IntToStr(StageIndex) +
    ' as starttime, strftime(''%H:%M:%S'',julianday(time(''now'', ''localtime'')) - julianday(time(starttime' +
    IntToStr(StageIndex) + ')) + 0.5) as timeontrack from main where julianday(time(''now'', ''localtime'')) > julianday(time(starttime' +
    IntToStr(StageIndex) + ')) AND finishtime' + IntToStr(StageIndex) +
    ' ISNULL AND status' + IntToStr(StageIndex) +
    ' ISNULL ORDER BY starttime;';
end;

class function TDatasetSql.ResultStage(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT category, place' + IntToStr(StageIndex) +
    ', number, name, penalty' + IntToStr(StageIndex) + ', result' +
    IntToStr(StageIndex) + ', diffleader' + IntToStr(StageIndex) +
    ', CASE status WHEN ' + SqlStatusDbValue(psDSQ) + ' THEN ' +
    SqlStatusDbValue(psDSQ) + ' ELSE status' + IntToStr(StageIndex) +
    ' END status' + IntToStr(StageIndex) + ' from main where result' +
    IntToStr(StageIndex) + ' NOTNULL ORDER BY category, status' +
    IntToStr(StageIndex) + ', place' + IntToStr(StageIndex) + ';';
end;

class function TDatasetSql.ResultStageTotal: string;
begin
  Result := 'SELECT category, thruplace as sumplace, number, name, sumresult, ' +
    'thrudiff, sumstages FROM main WHERE sumresult NOTNULL ' +
    'ORDER BY status, thruplace;';
end;

class function TDatasetSql.ResultStageSum(
  const StageIndexes: array of integer): string;
var
  Seen: array[MIN_STAGE_COUNT..MAX_SUPPORTED_STAGE_COUNT] of boolean;
  ArrayIndex, StageIndex: integer;
begin
  if Length(StageIndexes) = 0 then
    raise EStageIndexError.Create('At least one active stage is required.');
  FillChar(Seen, SizeOf(Seen), 0);
  Result := 'SELECT category, sumplace, number, name';
  for ArrayIndex := 0 to High(StageIndexes) do
  begin
    StageIndex := StageIndexes[ArrayIndex];
    RequireSupportedStageIndex(StageIndex);
    if Seen[StageIndex] then
      raise EStageIndexError.CreateFmt(
        'Duplicate stage index: %d.', [StageIndex]);
    Seen[StageIndex] := True;
    Result := Result + ', result' + IntToStr(StageIndex);
  end;
  Result := Result +
    ', sumresult, sumdiffleader from main WHERE sumresult NOTNULL ' +
    'ORDER BY category, status, sumstages DESC, IFNULL(sumplace,''toend'');';
end;

class function TDatasetSql.CategoryStageResults(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT number, name, result' + IntToStr(StageIndex) +
    ' AS result, diffleader' + IntToStr(StageIndex) +
    ' AS diffleader, place' + IntToStr(StageIndex) +
    ' AS place FROM main WHERE category = :CATEGORY AND result' +
    IntToStr(StageIndex) + ' > 0 ORDER BY status ASC, result' +
    IntToStr(StageIndex) + ' ASC;';
end;

class function TDatasetSql.LatestStageResults(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT number, name, category, result' + IntToStr(StageIndex) +
    ' AS result, place' + IntToStr(StageIndex) +
    ' AS place FROM main WHERE finishtime' + IntToStr(StageIndex) +
    ' > 0 AND status ISNULL ORDER BY finishtime' + IntToStr(StageIndex) +
    ' DESC;';
end;

class procedure TDatasetSql.ConfigureMainParticipants(Q: TSQLQuery;
  const StageIndexes: array of integer);
begin
  ConfigureQuery(Q, MainParticipants(StageIndexes), False);
end;

class procedure TDatasetSql.ConfigureCategoryStatistics(Q: TSQLQuery);
begin
  ConfigureQuery(Q, CategoryStatistics, True);
end;

class procedure TDatasetSql.ConfigureCorrectionPending(Q: TSQLQuery;
  const StageIndex, StageCount: integer);
begin
  ConfigureQuery(Q, CorrectionPending(StageIndex, StageCount), False);
end;

class procedure TDatasetSql.ConfigureTrackStatus(Q: TSQLQuery;
  const StageIndex, StageCount: integer);
begin
  ConfigureQuery(Q, TrackStatus(StageIndex, StageCount), True);
end;

class procedure TDatasetSql.ConfigureResultStage(Q: TSQLQuery;
  const StageIndex, StageCount: integer);
begin
  ConfigureQuery(Q, ResultStage(StageIndex, StageCount), True);
end;

class procedure TDatasetSql.ConfigureResultStageTotal(Q: TSQLQuery);
begin
  ConfigureQuery(Q, ResultStageTotal, True);
end;

class procedure TDatasetSql.ConfigureResultStageSum(Q: TSQLQuery;
  const StageIndexes: array of integer);
begin
  ConfigureQuery(Q, ResultStageSum(StageIndexes), True);
end;

class procedure TDatasetSql.ConfigureCategoryStageResults(Q: TSQLQuery;
  const StageIndex: integer; const Category: string;
  const StageCount: integer);
begin
  ConfigureQuery(Q, CategoryStageResults(StageIndex, StageCount), True);
  Q.ParamByName('CATEGORY').AsString := Category;
end;

class procedure TDatasetSql.ConfigureLatestStageResults(Q: TSQLQuery;
  const StageIndex, StageCount: integer);
begin
  ConfigureQuery(Q, LatestStageResults(StageIndex, StageCount), True);
end;

class procedure TDatasetSql.ConfigureStartMarkWorkQueue(Q: TSQLQuery);
begin
  ConfigureQuery(Q, TStartMarkSql.SelectWorkQueue, False);
end;

class procedure TDatasetSql.ConfigureFinishMarkWorkQueue(Q: TSQLQuery);
begin
  ConfigureQuery(Q, TFinishMarkSql.SelectWorkQueue, False);
end;

class procedure TDatasetSql.ConfigureStartMarkJournal(Q: TSQLQuery);
begin
  ConfigureStartMarkJournal(Q, smjfAll, 0, 0);
end;

class procedure TDatasetSql.ConfigureStartMarkJournal(Q: TSQLQuery;
  const AFilter: TStartMarkJournalFilter; const AReceivedSince: TDateTime;
  const AStageIndex: integer);
begin
  ConfigureQuery(Q, TStartMarkSql.SelectJournal(AFilter), True);
  TStartMarkSql.BindJournalParameters(Q, AFilter, AReceivedSince,
    AStageIndex);
end;

class procedure TDatasetSql.ConfigureFinishMarkJournal(Q: TSQLQuery);
begin
  ConfigureFinishMarkJournal(Q, fmjfAll, 0, 0);
end;

class procedure TDatasetSql.ConfigureFinishMarkJournal(Q: TSQLQuery;
  const AFilter: TFinishMarkJournalFilter; const AReceivedSince: TDateTime;
  const AStageIndex: integer);
begin
  ConfigureQuery(Q, TFinishMarkSql.SelectJournal(AFilter), True);
  TFinishMarkSql.BindJournalParameters(Q, AFilter, AReceivedSince,
    AStageIndex);
end;

class function TStartlistSql.SelectNumbersForCategory(const SortBy: integer;
  const IncludeDNS, IncludeDNF, IncludeDSQ: boolean): string;
var
  ExcludedStatuses: string;

  procedure ExcludeStatus(const AStatus: TParticipantStatus);
  begin
    if ExcludedStatuses <> '' then
      ExcludedStatuses := ExcludedStatuses + ', ';
    ExcludedStatuses := ExcludedStatuses + SqlStatusToken(AStatus);
  end;

begin
  Result := 'SELECT number FROM main WHERE category IS :CATEGORY ';
  case SortBy of
    STARTLIST_SORT_BY_RESULT:
      begin
        ExcludedStatuses := '';
        if not IncludeDNS then
          ExcludeStatus(psDNS);
        if not IncludeDNF then
          ExcludeStatus(psDNF);
        if not IncludeDSQ then
          ExcludeStatus(psDSQ);
        if ExcludedStatuses <> '' then
        begin
          Result := Result + 'AND (';
          if IncludeDNS or IncludeDNF or IncludeDSQ then
            Result := Result + 'sumresult IS NULL OR ';
          Result := Result + 'sumresult NOT IN (' + ExcludedStatuses + ')) ';
        end;
        Result := Result +
          'ORDER BY sumstages DESC NULLS FIRST, sumresult DESC NULLS FIRST;';
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

class procedure TStartlistSql.ConfigureNumbersForCategory(Q: TSQLQuery;
  const SortBy: integer; const IncludeDNS, IncludeDNF, IncludeDSQ: boolean;
  const Category: string);
begin
  if Q = nil then
    Exit;
  Q.Close;
  Q.ReadOnly := True;
  Q.SQL.Text := SelectNumbersForCategory(SortBy, IncludeDNS, IncludeDNF,
    IncludeDSQ);
  Q.ParamByName('CATEGORY').AsString := Category;
end;

end.
