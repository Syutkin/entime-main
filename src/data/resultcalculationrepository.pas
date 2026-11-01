unit ResultCalculationRepository;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SQLDB, ParticipantStatus, StageConfig;

type
  TStringArray = array of string;

  TSumCalculationRow = record
    ParticipantNumber: string;
    Status: TParticipantStatus;
    StageResults: TStringArray;
  end;

  TResultCalculationRepository = record
  private
    class function UpsertSumPlace: string; static;
    class function StandingsUpsert(
      const ResultColumn, PlaceColumn, DiffColumn, FilterSql, WindowSql: string;
      const ByCategory: boolean): string; static;
    class function UpsertStageStandings(const StageIndex, StageCount: integer): string;
      static;
    class function UpsertSumStandings(const ActiveStages: array of integer;
      const StageCount: integer): string; static;
    class function UpsertThruStandings: string; static;
    class procedure ExecSql(Q: TSQLQuery; const SqlText: string); static;
  public
    class function SelectForSumCalculation(const ActiveStages: array of integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function UpdateStageResult(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT;
      const APreserveFinish: boolean = False): string; static;
    class function ResetStagePlaceAndDiff(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function UpsertStagePlace(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function ResetStageDiffLeader(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function UpsertStageDiffLeader(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;

    class function UpdateSumResult: string; static;
    class function ResetSumPlaceAndDiff: string; static;
    class function UpsertSumPlaceOnlyFullStages(
      const ActiveStages: array of integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function ResetSumDiffLeader: string; static;
    class function UpsertSumDiffLeader: string; static;
    class function UpsertSumDiffByStages: string; static;

    class function ResetThru: string; static;
    class function UpsertThruPlace: string; static;
    class function UpsertThruDiff: string; static;
    class function UpsertThruDiffByStages: string; static;

    class function ReadSumCalculationRow(Q: TSQLQuery;
      const ActiveStages: array of integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): TSumCalculationRow; static;
    class procedure BindSumResult(Q: TSQLQuery;
      const ParticipantNumber, SumResult: string; const SumStages: integer;
      const ClearStatus: boolean); static;
    class procedure BindStageCaption(Q: TSQLQuery;
      const StageCaption: string); static;

    class procedure ExecCalculateStage(Q: TSQLQuery;
      const StageIndex, StageCount: integer;
      const APreserveFinish: boolean = False); static;
    class procedure OpenSumCalculation(Q: TSQLQuery;
      const ActiveStages: array of integer; const StageCount: integer); static;
    class function HasCurrentSumCalculationRow(Q: TSQLQuery): boolean; static;
    class procedure NextSumCalculationRow(Q: TSQLQuery); static;
    class procedure CloseSumCalculation(Q: TSQLQuery); static;
    class procedure PrepareSumResultUpdate(Q: TSQLQuery); static;
    class procedure FinishPreparedSumResultUpdate(Q: TSQLQuery); static;
    class procedure ExecPreparedSumResult(Q: TSQLQuery;
      const ParticipantNumber, SumResult: string; const SumStages: integer;
      const ClearStatus: boolean); static;
    class procedure FinishSumCalculation(Q: TSQLQuery;
      const ActiveStages: array of integer; const StageCount: integer;
      const StageCaption: string); static;
    class procedure ExecCalculateThru(Q: TSQLQuery;
      const StageCaption: string); static;
    class procedure ExecClearResults(Q: TSQLQuery;
      const StageCount: integer); static;

    class function ClearResultsPrefix: string; static;
    class function ClearResultsStagePart(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function ClearResultsSuffix: string; static;
  end;

implementation

uses
  SysUtils, SqlValueHelpers;

class procedure TResultCalculationRepository.ExecSql(Q: TSQLQuery;
  const SqlText: string);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  Q.SQL.Text := SqlText;
  Q.ExecSQL;
  Q.Close;
end;

class function TResultCalculationRepository.SelectForSumCalculation(
  const ActiveStages: array of integer; const StageCount: integer): string;
var
  I: integer;
begin
  for I := Low(ActiveStages) to High(ActiveStages) do
    RequireStageIndex(ActiveStages[I], StageCount);
  Result := 'SELECT number, status';
  for I := Low(ActiveStages) to High(ActiveStages) do
    Result := Result + ', result' + IntToStr(ActiveStages[I]);
  Result := Result + ' FROM main;';
end;

class function TResultCalculationRepository.UpdateStageResult(
  const StageIndex, StageCount: integer; const APreserveFinish: boolean): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET result' + IntToStr(StageIndex) +
    ' = CASE ' + 'WHEN status = ' + SqlStatusDbValue(psDSQ) + ' THEN ' +
    SqlStatusToken(psDSQ) + ' ' + 'WHEN status' + IntToStr(StageIndex) +
    ' = ' + SqlStatusDbValue(psDNF) + ' THEN ' + SqlStatusToken(psDNF) +
    ' ' + 'WHEN status' + IntToStr(StageIndex) + ' = ' +
    SqlStatusDbValue(psDNS) + ' THEN ' + SqlStatusToken(psDNS) + ' ' +
    'WHEN correction' + IntToStr(StageIndex) + ' IS NULL AND penalty' +
    IntToStr(StageIndex) + ' IS NULL AND status' + IntToStr(StageIndex) +
    ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') +1.5) ' + 'WHEN correction' + IntToStr(StageIndex) +
    ' < 0 AND penalty' + IntToStr(StageIndex) + ' IS NULL AND status' +
    IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') +1.5 - julianday(-correction' + IntToStr(StageIndex) +
    '/86400000.0)) ' + 'WHEN correction' + IntToStr(StageIndex) +
    ' >= 0 AND penalty' + IntToStr(StageIndex) + ' IS NULL AND status' +
    IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') +1.5 + julianday(correction' + IntToStr(StageIndex) +
    '/86400000.0)) ' + 'WHEN correction' + IntToStr(StageIndex) +
    ' IS NULL AND penalty' + IntToStr(StageIndex) + ' > 0 AND status' +
    IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') + julianday(penalty' + IntToStr(StageIndex) + ') -0.5 +1.5) ' +
    'WHEN correction' + IntToStr(StageIndex) + ' < 0 AND penalty' +
    IntToStr(StageIndex) + ' > 0 AND status' + IntToStr(StageIndex) +
    ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') +1.5 + julianday(penalty' + IntToStr(StageIndex) +
    ')-0.5 - julianday(-correction' + IntToStr(StageIndex) +
    '/86400000.0)) ' + 'WHEN correction' + IntToStr(StageIndex) +
    ' >= 0 AND penalty' + IntToStr(StageIndex) + ' > 0 AND status' +
    IntToStr(StageIndex) + ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
    IntToStr(StageIndex) + ') - julianday(starttime' + IntToStr(StageIndex) +
    ') +1.5 + julianday(penalty' + IntToStr(StageIndex) +
    ')-0.5 + julianday(correction' + IntToStr(StageIndex) + '/86400000.0)) ' + 'END';
  if not APreserveFinish then
    Result := Result + ', finishtime' + IntToStr(StageIndex) +
      ' = CASE WHEN status' + IntToStr(StageIndex) +
      ' NOTNULL THEN NULL ELSE finishtime' + IntToStr(StageIndex) + ' END';
  Result := Result + ';';
end;

class function TResultCalculationRepository.ResetStagePlaceAndDiff(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET place' + IntToStr(StageIndex) +
    ' = NULL, diffleader' + IntToStr(StageIndex) + ' = NULL;';
end;

class function TResultCalculationRepository.UpsertStagePlace(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'INSERT into main (number, place' + IntToStr(StageIndex) +
    ') ' + 'SELECT number, row_number() over(partition BY category ORDER BY result' +
    IntToStr(StageIndex) + ') as place' + IntToStr(StageIndex) +
    ' FROM main WHERE result' + IntToStr(StageIndex) + ' > 0 AND status' +
    IntToStr(StageIndex) + ' ISNULL AND (status IS NULL OR status <> ' +
    SqlStatusDbValue(psDSQ) + ') ' + 'ORDER BY finishtime' +
    IntToStr(StageIndex) + ' DESC ' + 'ON CONFLICT(number) DO UPDATE SET place' +
    IntToStr(StageIndex) + ' = excluded.place' + IntToStr(StageIndex) + ';';
end;

class function TResultCalculationRepository.ResetStageDiffLeader(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET diffleader' + IntToStr(StageIndex) +
    ' = NULL WHERE place' + IntToStr(StageIndex) + ' = 1;';
end;

class function TResultCalculationRepository.UpsertStageDiffLeader(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'WITH ' + 't1(leader1, cat1, num1) AS (SELECT julianday(result' +
    IntToStr(StageIndex) + '), category, number FROM main WHERE place' +
    IntToStr(StageIndex) + ' = 1), ' +
    't2(current,cat2, num2) AS (SELECT julianday(result' +
    IntToStr(StageIndex) + '), category, number FROM main WHERE place' +
    IntToStr(StageIndex) + ' > 1) ' + 'INSERT into main (diffleader' +
    IntToStr(StageIndex) + ', number) ' +
    'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), ' +
    't2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2 ' +
    'ON CONFLICT(number) DO UPDATE SET diffleader' + IntToStr(StageIndex) +
    '= excluded.diffleader' + IntToStr(StageIndex) + ';';
end;

class function TResultCalculationRepository.StandingsUpsert(
  const ResultColumn, PlaceColumn, DiffColumn, FilterSql, WindowSql: string;
  const ByCategory: boolean): string;
var
  CategoryGuard: string;
begin
  CategoryGuard := '';
  // The previous category join does not match NULL to NULL.
  if ByCategory then
    CategoryGuard := ' AND category IS NOT NULL';
  Result := 'WITH ranked AS (SELECT number, category, ' +
    'row_number() OVER standings AS position, ' + 'julianday(' +
    ResultColumn + ') AS elapsed, ' + 'first_value(julianday(' +
    ResultColumn + ')) OVER standings AS leader ' + 'FROM main WHERE ' +
    FilterSql + ' WINDOW standings AS (' + WindowSql + ')) ' +
    'INSERT INTO main (number, ' + PlaceColumn + ', ' + DiffColumn +
    ') ' + 'SELECT number, position, CASE WHEN position > 1' +
    CategoryGuard + ' THEN strftime(''%H:%M:%f'', elapsed - leader + 0.5) END ' +
    'FROM ranked WHERE 1 ' + 'ON CONFLICT(number) DO UPDATE SET ' +
    PlaceColumn + ' = excluded.' + PlaceColumn + ', ' + DiffColumn +
    ' = excluded.' + DiffColumn + ';';
end;

class function TResultCalculationRepository.UpsertStageStandings(
  const StageIndex, StageCount: integer): string;
var
  S: string;
begin
  RequireStageIndex(StageIndex, StageCount);
  S := IntToStr(StageIndex);
  Result := StandingsUpsert('result' + S, 'place' + S, 'diffleader' +
    S, 'result' + S + ' > 0 AND status' + S +
    ' IS NULL AND (status IS NULL OR status <> ' + SqlStatusDbValue(psDSQ) +
    ')', 'PARTITION BY category ORDER BY result' + S, True);
end;

class function TResultCalculationRepository.UpsertSumStandings(
  const ActiveStages: array of integer; const StageCount: integer): string;
var
  I: integer;
  FilterSql, S: string;
begin
  FilterSql := 'sumresult > 0 AND status IS NULL';
  for I := Low(ActiveStages) to High(ActiveStages) do
  begin
    RequireStageIndex(ActiveStages[I], StageCount);
    S := IntToStr(ActiveStages[I]);
    FilterSql := FilterSql + ' AND result' + S + ' IS NOT NULL AND status' +
      S + ' IS NULL';
  end;
  Result := StandingsUpsert('sumresult', 'sumplace', 'sumdiffleader',
    FilterSql, 'PARTITION BY category ORDER BY sumresult', True);
end;

class function TResultCalculationRepository.UpsertThruStandings: string;
begin
  Result := StandingsUpsert('sumresult', 'thruplace', 'thrudiff',
    'sumresult > 0 AND status IS NULL', 'ORDER BY sumstages DESC, sumresult', False);
end;

class function TResultCalculationRepository.UpdateSumResult: string;
begin
  Result := 'UPDATE main SET sumresult = :SUMRESULT, ' +
    'sumstages = :SUMSTAGES, ' +
    'status = CASE WHEN :CLEAR_STATUS = 1 THEN NULL ELSE status END ' +
    'WHERE number = :NUMBER AND (' +
    'sumresult IS NOT :SUMRESULT OR sumstages IS NOT :SUMSTAGES OR ' +
    '(:CLEAR_STATUS = 1 AND status IS NOT NULL));';
end;

class function TResultCalculationRepository.ResetSumPlaceAndDiff: string;
begin
  Result := 'UPDATE main SET sumplace = NULL, sumdiffleader = NULL;';
end;

class function TResultCalculationRepository.UpsertSumPlace: string;
begin
  Result := 'INSERT into main (number, sumplace) ' +
    'SELECT number, row_number() over(partition BY category ORDER BY sumresult) as sumplace '
    + 'FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY sumresult DESC ' +
    'ON CONFLICT(number) DO UPDATE SET sumplace = excluded.sumplace;';
end;

class function TResultCalculationRepository.UpsertSumPlaceOnlyFullStages(
  const ActiveStages: array of integer; const StageCount: integer): string;
var
  I: integer;
begin
  for I := Low(ActiveStages) to High(ActiveStages) do
    RequireStageIndex(ActiveStages[I], StageCount);
  Result := 'INSERT into main (number, sumplace) ' +
    'SELECT number, row_number() over(partition BY category ORDER BY sumresult) as sumplace '
    + 'FROM main WHERE sumresult > 0 AND status ISNULL ';
  for I := Low(ActiveStages) to High(ActiveStages) do
    Result := Result + 'AND result' + IntToStr(ActiveStages[I]) +
      ' NOTNULL ' + 'AND status' + IntToStr(ActiveStages[I]) + ' IS NULL ';
  Result := Result + 'ORDER BY sumresult DESC ' +
    'ON CONFLICT(number) DO UPDATE SET sumplace = excluded.sumplace;';
end;

class function TResultCalculationRepository.ResetSumDiffLeader: string;
begin
  Result := 'UPDATE main SET sumdiffleader = NULL WHERE sumplace = 1;';
end;

class function TResultCalculationRepository.UpsertSumDiffLeader: string;
begin
  Result := 'WITH ' +
    't1(leader1, cat1, num1) AS (SELECT julianday(sumresult), category, number FROM main WHERE sumplace = 1), '
    +
    't2(current,cat2, num2) AS (SELECT julianday(sumresult), category, number FROM main WHERE sumplace > 1) '
    +
    'INSERT into main (sumdiffleader, number) ' +
    'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), t2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2 '
    +
    'ON CONFLICT(number) DO UPDATE SET sumdiffleader= excluded.sumdiffleader;';
end;

class function TResultCalculationRepository.UpsertSumDiffByStages: string;
begin
  Result := 'WITH ' +
    't1(sumstages1, cat1, num1) AS (SELECT sumstages, category, number FROM main WHERE sumplace = 1), '
    +
    't2(current,cat2, num2) AS (SELECT sumstages, category, number FROM main WHERE sumplace IS NULL AND sumstages NOT NULL AND (status < '
    +
    SqlStatusDbValue(psDSQ) + ' OR status IS NULL)) ' +
    'INSERT into main (sumdiffleader, number) ' +
    'SELECT ''+'' || (t1.sumstages1 - t2.current) || '' '' || :STAGE_CAPTION, ' +
    't2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2 ' +
    'ON CONFLICT(number) DO UPDATE SET sumdiffleader= excluded.sumdiffleader;';
end;

class function TResultCalculationRepository.ResetThru: string;
begin
  Result := 'UPDATE main SET thrudiff = NULL, thruplace = NULL;';
end;

class function TResultCalculationRepository.UpsertThruPlace: string;
begin
  Result := 'INSERT into main (number, thruplace) ' +
    'SELECT number, row_number() over(ORDER BY sumstages DESC, sumresult) as thruplace '
    +
    'FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY thruplace ' +
    'ON CONFLICT(number) DO UPDATE SET thruplace = excluded.thruplace;';
end;

class function TResultCalculationRepository.UpsertThruDiff: string;
begin
  Result := 'WITH ' +
    'tthru(sumresult, number, thruplace) AS (SELECT sumresult, number, thruplace FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY thruplace), ' + 't1(leader1, num1) AS (SELECT julianday(sumresult), number FROM tthru WHERE thruplace = 1), ' + 't2(current, num2) AS (SELECT julianday(sumresult), number FROM tthru WHERE thruplace > 1) ' + 'INSERT into main (thrudiff, number) ' + 'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), t2.num2 from t1, t2, tthru WHERE t2.num2 = tthru.number ORDER BY thruplace ' + 'ON CONFLICT(number) DO UPDATE SET thrudiff= excluded.thrudiff;';
end;

class function TResultCalculationRepository.UpsertThruDiffByStages: string;
begin
  Result := 'WITH ' +
    't1(sumstages1, num1) AS (SELECT sumstages, number FROM main WHERE thruplace = 1), '
    +
    't2(current, num2) AS (SELECT sumstages, number FROM main WHERE sumplace IS NULL AND sumstages NOT NULL AND (status < '
    +
    SqlStatusDbValue(psDSQ) + ' OR status IS NULL)) ' +
    'INSERT into main (thrudiff, number) ' +
    'SELECT ''+'' || (t1.sumstages1 - t2.current) || '' '' || :STAGE_CAPTION, ' +
    't2.num2 from t1, t2 WHERE t1.sumstages1 > t2.current ' +
    'ON CONFLICT(number) DO UPDATE SET thrudiff= excluded.thrudiff;';
end;

class function TResultCalculationRepository.ClearResultsPrefix: string;
begin
  Result := 'UPDATE main SET';
end;

class function TResultCalculationRepository.ClearResultsStagePart(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'correction' + IntToStr(StageIndex) + '=NULL, finishtime' +
    IntToStr(StageIndex) + '=NULL, penalty' + IntToStr(StageIndex) +
    '=NULL, result' + IntToStr(StageIndex) + '=NULL, diffleader' +
    IntToStr(StageIndex) + '=NULL, place' + IntToStr(StageIndex) +
    '=NULL, status' + IntToStr(StageIndex) + '=NULL,';
end;

class function TResultCalculationRepository.ReadSumCalculationRow(Q: TSQLQuery;
  const ActiveStages: array of integer; const StageCount: integer): TSumCalculationRow;
var
  I: integer;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Result.ParticipantNumber := '';
  Result.Status := psNone;
  SetLength(Result.StageResults, Length(ActiveStages));
  Result.ParticipantNumber := Q.FieldByName('number').AsString;
  if not TryParticipantStatusFromDbValue(Q.FieldByName('status').AsString,
    Result.Status) then
    Result.Status := psNone;
  for I := Low(ActiveStages) to High(ActiveStages) do
  begin
    RequireStageIndex(ActiveStages[I], StageCount);
    Result.StageResults[I - Low(ActiveStages)] :=
      Q.FieldByName('result' + IntToStr(ActiveStages[I])).AsString;
  end;
end;

class procedure TResultCalculationRepository.BindSumResult(Q: TSQLQuery;
  const ParticipantNumber, SumResult: string; const SumStages: integer;
  const ClearStatus: boolean);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.ParamByName('NUMBER').AsString := ParticipantNumber;
  if SumResult = '' then
    Q.ParamByName('SUMRESULT').Clear
  else
    Q.ParamByName('SUMRESULT').AsString := SumResult;
  if ClearStatus then
    Q.ParamByName('SUMSTAGES').AsInteger := SumStages
  else
    Q.ParamByName('SUMSTAGES').Clear;
  Q.ParamByName('CLEAR_STATUS').AsInteger := Ord(ClearStatus);
end;

class procedure TResultCalculationRepository.BindStageCaption(Q: TSQLQuery;
  const StageCaption: string);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.ParamByName('STAGE_CAPTION').AsString := StageCaption;
end;

class procedure TResultCalculationRepository.ExecCalculateStage(Q: TSQLQuery;
  const StageIndex, StageCount: integer; const APreserveFinish: boolean);
begin
  ExecSql(Q, UpdateStageResult(StageIndex, StageCount, APreserveFinish));
  ExecSql(Q, ResetStagePlaceAndDiff(StageIndex, StageCount));
  ExecSql(Q, UpsertStageStandings(StageIndex, StageCount));
end;

class procedure TResultCalculationRepository.OpenSumCalculation(Q: TSQLQuery;
  const ActiveStages: array of integer; const StageCount: integer);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  Q.SQL.Text := SelectForSumCalculation(ActiveStages, StageCount);
  Q.Open;
end;

class function TResultCalculationRepository.HasCurrentSumCalculationRow(
  Q: TSQLQuery): boolean;
begin
  Result := Assigned(Q) and Q.Active and (not Q.EOF);
end;

class procedure TResultCalculationRepository.NextSumCalculationRow(Q: TSQLQuery);
begin
  if not HasCurrentSumCalculationRow(Q) then
    Exit;
  Q.Next;
end;

class procedure TResultCalculationRepository.CloseSumCalculation(Q: TSQLQuery);
begin
  if Assigned(Q) then
    Q.Close;
end;

class procedure TResultCalculationRepository.PrepareSumResultUpdate(Q: TSQLQuery);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  if Q.Prepared then
    Q.UnPrepare;
  Q.SQL.Text := UpdateSumResult;
  Q.Prepare;
end;

class procedure TResultCalculationRepository.FinishPreparedSumResultUpdate(
  Q: TSQLQuery);
begin
  if Q = nil then
    Exit;
  Q.Close;
  if Q.Prepared then
    Q.UnPrepare;
end;

class procedure TResultCalculationRepository.ExecPreparedSumResult(Q: TSQLQuery;
  const ParticipantNumber, SumResult: string; const SumStages: integer;
  const ClearStatus: boolean);
begin
  BindSumResult(Q, ParticipantNumber, SumResult, SumStages, ClearStatus);
  Q.ExecSQL;
end;

class procedure TResultCalculationRepository.FinishSumCalculation(Q: TSQLQuery;
  const ActiveStages: array of integer; const StageCount: integer;
  const StageCaption: string);
begin
  ExecSql(Q, ResetSumPlaceAndDiff);
  ExecSql(Q, UpsertSumStandings(ActiveStages, StageCount));
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  Q.SQL.Text := UpsertSumDiffByStages;
  BindStageCaption(Q, StageCaption);
  Q.ExecSQL;
  Q.Close;
end;

class procedure TResultCalculationRepository.ExecCalculateThru(Q: TSQLQuery;
  const StageCaption: string);
begin
  ExecSql(Q, ResetThru);
  ExecSql(Q, UpsertThruStandings);
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  Q.SQL.Text := UpsertThruDiffByStages;
  BindStageCaption(Q, StageCaption);
  Q.ExecSQL;
  Q.Close;
end;

class procedure TResultCalculationRepository.ExecClearResults(Q: TSQLQuery;
  const StageCount: integer);
var
  I: integer;
begin
  RequireStageCount(StageCount);
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  Q.SQL.Clear;
  Q.SQL.Add(ClearResultsPrefix);
  for I := 1 to StageCount do
    Q.SQL.Add(ClearResultsStagePart(I, StageCount));
  Q.SQL.Add(ClearResultsSuffix);
  Q.ExecSQL;
  Q.Close;
end;

class function TResultCalculationRepository.ClearResultsSuffix: string;
begin
  Result := 'sumplace=NULL, sumresult=NULL, sumdiffleader=NULL, ' +
    'thrudiff=NULL, status=NULL;';
end;

end.
