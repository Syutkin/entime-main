unit StageResultRepository;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, DB, SQLDB, ParticipantStatus, SqlValueHelpers,
  StageConfig, ParticipantStageData;

type
  TStageResultRepository = record
  private
    class function UpdateStageStatus(const StageIndex, StageCount: integer): string;
      static;
    class function ClearStatusAllForStage(const StageIndex, StageCount: integer):
      string; static;
    class function ClearStageStatus(const StageIndex, StageCount: integer): string;
      static;
    class function UpdateStartTimeForNumber(
      const StageIndex, StageCount: integer): string; static;
    class function SelectNumberByStartTimeBetween(
      const StageIndex, StageCount: integer): string; static;
    class function UpdateCorrection(const StageIndex, StageCount: integer): string;
      static;
    class function SelectByCategoryLeader(const StageIndex, StageCount: integer):
      string; static;
    class function UpdateFinishPrefix: string; static;
    class function UpdateFinishSetPart(const StageIndex, StageCount: integer): string;
      static;
    class function UpdateFinishWhereNumber: string; static;
    class function SelectFinishExistsByStage(
      const StageIndex, StageCount: integer): string; static;
    class function SelectPenaltyGroupsCount(const StageCount: integer): string;
      static;
    class function SelectParticipantOnTrack(
      const StageIndex, StageCount: integer): string; static;
    class procedure ExecuteParticipantStageWrite(Q: TSQLQuery;
      const OperationName, StageContext, ParticipantNumber: string); static;
    class procedure ReadStageData(Q: TSQLQuery; const StageIndex: integer;
      out Data: TParticipantStageData); static;
  public
    class function ResetStartTime(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function UpdateStartTime(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function SelectMinStartTime(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function SelectCategoryGroupedOrderedByStartTime(
      const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function SelectStatusByStage(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function ExportFinishTime(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class procedure LoadCategoriesOrderedByStartTime(Q: TSQLQuery;
      const StageIndex, StageCount: integer; Categories: TStrings); static;
    class procedure LoadStageStatusNumbers(Q: TSQLQuery;
      const StageIndex, StageCount: integer; Numbers: TStrings); static;
    class procedure ConfigureFinishExport(Q: TSQLQuery;
      const StageIndex, StageCount: integer); static;

    class function OpenByCategoryLeader(Q: TSQLQuery; const StageIndex: integer;
      const Category: string; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT):
      boolean; static;
    class function TryGetNumberByStartTimeBetween(Q: TSQLQuery;
      const StageIndex: integer; const TimeBefore, TimeAfter: string;
      out Number: integer; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT):
      boolean; static;
    class function GetPenaltyGroupsCount(Q: TSQLQuery;
      const StageCount: integer): integer; static;
    class function GetFinishCount(Q: TSQLQuery; const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): integer; static;
    class function GetMinStartTime(Q: TSQLQuery; const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function HasAnyDataInStageRange(Q: TSQLQuery;
      const FirstStageIndex, LastStageIndex, StageCount: integer): boolean; static;
    class function IsParticipantOnTrack(Q: TSQLQuery;
      const StageIndex, Number: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): boolean; static;
    class function TryLoadParticipantStageData(Q: TSQLQuery;
      const Number, StageIndex, StageCount: integer;
      out Data: TParticipantStageData): boolean; static;
    class function TryLoadCategoryLeaderStageData(Q: TSQLQuery;
      const StageIndex: integer; const Category: string;
      out LeaderNumber: integer; out Data: TParticipantStageData;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): boolean; static;

    class procedure ExecResetStartTime(Q: TSQLQuery; const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecUpdateStartTime(Q: TSQLQuery; const StageIndex: integer;
      const StartTime: string; const Number: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecUpdateStageStatus(Q: TSQLQuery;
      const StageIndex: integer; const Status: TParticipantStatus;
      const Number: string; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT);
      static;
    class procedure ExecClearStatusAllForStage(Q: TSQLQuery;
      const StageIndex: integer; const Number: string;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecClearStageStatus(Q: TSQLQuery;
      const StageIndex: integer; const Number: string;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecUpdateStartTimeForNumber(Q: TSQLQuery;
      const StageIndex: integer; const StartTime: string;
      const Number: integer; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT);
      static;
    class procedure ExecUpdateCorrection(Q: TSQLQuery;
      const StageIndex, Correction, Number: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecUpdateFinishForCheckedStages(Q: TSQLQuery;
      const CheckedStages: array of integer; const TimeValue: string;
      const Number: integer; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT);
      static;
  end;

implementation

const
  STAGE_DATA_COLUMN_PREFIXES: array[0..7] of string = (
    'starttime', 'correction', 'finishtime', 'penalty',
    'result', 'diffleader', 'place', 'status'
    );

class procedure TStageResultRepository.ReadStageData(Q: TSQLQuery;
  const StageIndex: integer; out Data: TParticipantStageData);
var
  StatusText: string;
begin
  Data := TParticipantStageData.Create(StageIndex);
  Data.StartTime := Q.FieldByName('starttime' + IntToStr(StageIndex)).AsString;
  Data.HasCorrection := not Q.FieldByName('correction' +
    IntToStr(StageIndex)).IsNull;
  if Data.HasCorrection then
    Data.Correction := Q.FieldByName('correction' +
      IntToStr(StageIndex)).AsInteger;
  Data.FinishTime := Q.FieldByName('finishtime' + IntToStr(StageIndex)).AsString;
  Data.Penalty := Q.FieldByName('penalty' + IntToStr(StageIndex)).AsString;
  Data.ResultValue := Q.FieldByName('result' + IntToStr(StageIndex)).AsString;
  Data.DiffLeader := Q.FieldByName('diffleader' + IntToStr(StageIndex)).AsString;
  Data.HasPlace := not Q.FieldByName('place' + IntToStr(StageIndex)).IsNull;
  if Data.HasPlace then
    Data.Place := Q.FieldByName('place' + IntToStr(StageIndex)).AsInteger;
  StatusText := Q.FieldByName('status' + IntToStr(StageIndex)).AsString;
  if not TryParticipantStatusFromDbValue(StatusText, Data.Status) then
    Data.Status := psNone;
end;

class function TStageResultRepository.HasAnyDataInStageRange(Q: TSQLQuery;
  const FirstStageIndex, LastStageIndex, StageCount: integer): boolean;
var
  ColumnPrefix: string;
  StageIndex: integer;
  Predicate: string;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  RequireStageIndex(FirstStageIndex, StageCount);
  RequireStageIndex(LastStageIndex, StageCount);
  if FirstStageIndex > LastStageIndex then
    raise EArgumentOutOfRangeException.Create(
      'First stage index must not exceed the last stage index.');

  Predicate := '';
  for StageIndex := FirstStageIndex to LastStageIndex do
    for ColumnPrefix in STAGE_DATA_COLUMN_PREFIXES do
    begin
      if Predicate <> '' then
        Predicate := Predicate + ' OR ';
      Predicate := Predicate + 'NULLIF(CAST(' +
        SqlIdentifier(ColumnPrefix + IntToStr(StageIndex)) +
        ' AS TEXT), '''') IS NOT NULL';
    end;

  Q.Close;
  Q.SQL.Text := 'SELECT EXISTS(SELECT 1 FROM main WHERE ' + Predicate +
    ') AS has_data;';
  Q.Open;
  try
    Result := Q.FieldByName('has_data').AsInteger <> 0;
  finally
    Q.Close;
  end;
end;

class procedure TStageResultRepository.ExecuteParticipantStageWrite(Q: TSQLQuery;
  const OperationName, StageContext, ParticipantNumber: string);
begin
  try
    Q.Close;
    Q.ExecSQL;
    Q.Close;
  except
    on E: Exception do
    begin
      Q.Close;
      raise EDatabaseError.CreateFmt(
        'Database operation "%s" failed for participant number %s on stage %s: %s',
        [OperationName, ParticipantNumber, StageContext, E.Message]);
    end;
  end;
end;

class function TStageResultRepository.UpdateStageStatus(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET place' + IntToStr(StageIndex) +
    ' = NULL, result' + IntToStr(StageIndex) + ' = :STATUS_TEXT, diffleader' +
    IntToStr(StageIndex) + ' = NULL, status' + IntToStr(StageIndex) +
    ' = :STATUS' + ' WHERE number = :NUMBER;';
end;

class function TStageResultRepository.ClearStatusAllForStage(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET place' + IntToStr(StageIndex) +
    ' = NULL, result' + IntToStr(StageIndex) + ' = NULL, diffleader' +
    IntToStr(StageIndex) + ' = NULL, status' + IntToStr(StageIndex) +
    ' = NULL, status = NULL WHERE number = :NUMBER;';
end;

class function TStageResultRepository.ClearStageStatus(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET place' + IntToStr(StageIndex) +
    ' = NULL, result' + IntToStr(StageIndex) + ' = NULL, diffleader' +
    IntToStr(StageIndex) + ' = NULL, status' + IntToStr(StageIndex) +
    ' = NULL WHERE number = :NUMBER;';
end;

class function TStageResultRepository.UpdateStartTimeForNumber(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET status' + IntToStr(StageIndex) +
    ' = NULL, starttime' + IntToStr(StageIndex) +
    ' = :STARTTIME WHERE number = :NUMBER;';
end;

class function TStageResultRepository.SelectNumberByStartTimeBetween(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT number FROM main WHERE starttime' + IntToStr(StageIndex) +
    ' BETWEEN :TIME_BEFORE AND :TIME_AFTER;';
end;

class function TStageResultRepository.UpdateCorrection(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET correction' + IntToStr(StageIndex) +
    ' = :CORRECTION WHERE number = :NUMBER;';
end;

class function TStageResultRepository.SelectByCategoryLeader(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'select * from main where category = :CATEGORY AND place' +
    IntToStr(StageIndex) + ' = 1;';
end;

class function TStageResultRepository.UpdateFinishPrefix: string;
begin
  Result := 'UPDATE main';
end;

class function TStageResultRepository.UpdateFinishSetPart(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SET finishtime' + IntToStr(StageIndex) + ' = :TIME' +
    ', status' + IntToStr(StageIndex) + ' = NULL';
end;

class function TStageResultRepository.UpdateFinishWhereNumber: string;
begin
  Result := 'WHERE number = :NUMBER;';
end;

class function TStageResultRepository.SelectFinishExistsByStage(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT COUNT(*) FROM main WHERE finishtime' + IntToStr(StageIndex) +
    ' NOTNULL AND finishtime' + IntToStr(StageIndex) + ' <> '''';';
end;

class function TStageResultRepository.SelectPenaltyGroupsCount(
  const StageCount: integer): string;
var
  StageIndex: integer;
begin
  RequireStageCount(StageCount);
  Result := 'SELECT COUNT(*) FROM (SELECT 1 FROM main GROUP BY ';
  for StageIndex := 1 to StageCount do
  begin
    if StageIndex > 1 then
      Result := Result + ', ';
    Result := Result + 'penalty' + IntToStr(StageIndex);
  end;
  Result := Result + ');';
end;

class function TStageResultRepository.SelectParticipantOnTrack(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT number FROM main WHERE ' +
    'julianday(time(''now'', ''localtime'')) > julianday(time(starttime' +
    IntToStr(StageIndex) + ')) AND finishtime' + IntToStr(StageIndex) +
    ' ISNULL AND status' + IntToStr(StageIndex) + ' ISNULL AND number = :NUMBER;';
end;

class function TStageResultRepository.ResetStartTime(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET starttime' + IntToStr(StageIndex) + ' = NULL;';
end;

class function TStageResultRepository.UpdateStartTime(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'UPDATE main SET starttime' + IntToStr(StageIndex) +
    ' = :STARTTIME WHERE number = :NUMBER;';
end;

class function TStageResultRepository.SelectMinStartTime(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT min(starttime' + IntToStr(StageIndex) +
    ') as starttime FROM main WHERE starttime' + IntToStr(StageIndex) + ' NOTNULL;';
end;

class function TStageResultRepository.SelectCategoryGroupedOrderedByStartTime(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT category FROM main GROUP BY category ORDER BY starttime' +
    IntToStr(StageIndex) + ';';
end;

class function TStageResultRepository.SelectStatusByStage(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT number FROM main WHERE status' + IntToStr(StageIndex) +
    ' NOTNULL;';
end;

class function TStageResultRepository.ExportFinishTime(
  const StageIndex, StageCount: integer): string;
begin
  RequireStageIndex(StageIndex, StageCount);
  Result := 'SELECT number, starttime' + IntToStr(StageIndex) +
    ', correction' + IntToStr(StageIndex) + ', finishtime' +
    IntToStr(StageIndex) + ', penalty' + IntToStr(StageIndex) +
    ', status' + IntToStr(StageIndex) + ' FROM main;';
end;

class procedure TStageResultRepository.LoadCategoriesOrderedByStartTime(Q: TSQLQuery;
  const StageIndex, StageCount: integer; Categories: TStrings);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if Categories = nil then
    raise EArgumentNilException.Create('Categories');
  Categories.Clear;
  Q.Close;
  Q.SQL.Text := SelectCategoryGroupedOrderedByStartTime(StageIndex, StageCount);
  Q.Open;
  try
    while not Q.EOF do
    begin
      Categories.Add(Q.FieldByName('category').AsString);
      Q.Next;
    end;
  finally
    Q.Close;
  end;
end;

class procedure TStageResultRepository.LoadStageStatusNumbers(Q: TSQLQuery;
  const StageIndex, StageCount: integer; Numbers: TStrings);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if Numbers = nil then
    raise EArgumentNilException.Create('Numbers');
  Numbers.Clear;
  Q.Close;
  Q.SQL.Text := SelectStatusByStage(StageIndex, StageCount);
  Q.Open;
  try
    while not Q.EOF do
    begin
      Numbers.Add(Q.FieldByName('number').AsString);
      Q.Next;
    end;
  finally
    Q.Close;
  end;
end;

class procedure TStageResultRepository.ConfigureFinishExport(Q: TSQLQuery;
  const StageIndex, StageCount: integer);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  Q.SQL.Text := ExportFinishTime(StageIndex, StageCount);
end;

class function TStageResultRepository.OpenByCategoryLeader(Q: TSQLQuery;
  const StageIndex: integer; const Category: string;
  const StageCount: integer): boolean;
begin
  Q.Close;
  Q.SQL.Text := SelectByCategoryLeader(StageIndex, StageCount);
  Q.ParamByName('CATEGORY').AsString := Category;
  Q.Open;
  Result := not Q.EOF;
end;

class function TStageResultRepository.TryGetNumberByStartTimeBetween(Q: TSQLQuery;
  const StageIndex: integer; const TimeBefore, TimeAfter: string;
  out Number: integer; const StageCount: integer): boolean;
begin
  Result := False;
  Number := 0;
  Q.Close;
  Q.SQL.Text := SelectNumberByStartTimeBetween(StageIndex, StageCount);
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

class function TStageResultRepository.GetPenaltyGroupsCount(Q: TSQLQuery;
  const StageCount: integer): integer;
begin
  Result := 0;
  Q.Close;
  Q.SQL.Text := SelectPenaltyGroupsCount(StageCount);
  Q.Open;
  try
    Result := Q.Fields[0].AsInteger;
  finally
    Q.Close;
  end;
end;

class function TStageResultRepository.GetFinishCount(Q: TSQLQuery;
  const StageIndex, StageCount: integer): integer;
begin
  Result := 0;
  Q.Close;
  Q.SQL.Text := SelectFinishExistsByStage(StageIndex, StageCount);
  Q.Open;
  try
    Result := Q.Fields[0].AsInteger;
  finally
    Q.Close;
  end;
end;

class function TStageResultRepository.GetMinStartTime(Q: TSQLQuery;
  const StageIndex, StageCount: integer): string;
begin
  Result := '';
  Q.Close;
  Q.SQL.Text := SelectMinStartTime(StageIndex, StageCount);
  Q.Open;
  try
    if not Q.FieldByName('starttime').IsNull then
      Result := Q.FieldByName('starttime').AsString;
  finally
    Q.Close;
  end;
end;

class function TStageResultRepository.IsParticipantOnTrack(Q: TSQLQuery;
  const StageIndex, Number, StageCount: integer): boolean;
begin
  Q.Close;
  Q.SQL.Text := SelectParticipantOnTrack(StageIndex, StageCount);
  Q.ParamByName('NUMBER').AsInteger := Number;
  Q.Open;
  try
    Result := not Q.EOF;
  finally
    Q.Close;
  end;
end;

class function TStageResultRepository.TryLoadParticipantStageData(Q: TSQLQuery;
  const Number, StageIndex, StageCount: integer;
  out Data: TParticipantStageData): boolean;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  RequireStageIndex(StageIndex, StageCount);
  Data := TParticipantStageData.Create(StageIndex);
  Q.Close;
  Q.SQL.Text := 'SELECT * FROM main WHERE number = :NUMBER;';
  Q.ParamByName('NUMBER').AsInteger := Number;
  Q.Open;
  try
    Result := not Q.EOF;
    if Result then
      ReadStageData(Q, StageIndex, Data);
  finally
    Q.Close;
  end;
end;

class function TStageResultRepository.TryLoadCategoryLeaderStageData(Q: TSQLQuery;
  const StageIndex: integer; const Category: string; out LeaderNumber: integer;
  out Data: TParticipantStageData; const StageCount: integer): boolean;
begin
  LeaderNumber := 0;
  Data := TParticipantStageData.Create(StageIndex);
  Result := OpenByCategoryLeader(Q, StageIndex, Category, StageCount);
  try
    if Result then
    begin
      LeaderNumber := Q.FieldByName('number').AsInteger;
      ReadStageData(Q, StageIndex, Data);
    end;
  finally
    Q.Close;
  end;
end;

class procedure TStageResultRepository.ExecResetStartTime(Q: TSQLQuery;
  const StageIndex, StageCount: integer);
begin
  Q.Close;
  Q.SQL.Text := ResetStartTime(StageIndex, StageCount);
  Q.ExecSQL;
  Q.Close;
end;

class procedure TStageResultRepository.ExecUpdateStartTime(Q: TSQLQuery;
  const StageIndex: integer; const StartTime: string;
  const Number, StageCount: integer);
begin
  Q.Close;
  Q.SQL.Text := UpdateStartTime(StageIndex, StageCount);
  Q.ParamByName('STARTTIME').AsString := StartTime;
  Q.ParamByName('NUMBER').AsInteger := Number;
  ExecuteParticipantStageWrite(Q, 'update start time', IntToStr(StageIndex),
    IntToStr(Number));
end;

class procedure TStageResultRepository.ExecUpdateStageStatus(Q: TSQLQuery;
  const StageIndex: integer; const Status: TParticipantStatus;
  const Number: string; const StageCount: integer);
begin
  if Status = psNone then
    raise EArgumentException.Create('A stage status is required.');
  Q.SQL.Text := UpdateStageStatus(StageIndex, StageCount);
  Q.ParamByName('STATUS_TEXT').AsString := ParticipantStatusToToken(Status);
  Q.ParamByName('STATUS').AsString := ParticipantStatusToDbValue(Status);
  Q.ParamByName('NUMBER').AsString := Number;
  ExecuteParticipantStageWrite(Q, 'update status', IntToStr(StageIndex),
    Number);
end;

class procedure TStageResultRepository.ExecClearStatusAllForStage(Q: TSQLQuery;
  const StageIndex: integer; const Number: string; const StageCount: integer);
begin
  Q.SQL.Text := ClearStatusAllForStage(StageIndex, StageCount);
  Q.ParamByName('NUMBER').AsString := Number;
  ExecuteParticipantStageWrite(Q, 'clear stage and global status',
    IntToStr(StageIndex), Number);
end;

class procedure TStageResultRepository.ExecClearStageStatus(Q: TSQLQuery;
  const StageIndex: integer; const Number: string; const StageCount: integer);
begin
  Q.SQL.Text := ClearStageStatus(StageIndex, StageCount);
  Q.ParamByName('NUMBER').AsString := Number;
  ExecuteParticipantStageWrite(Q, 'clear stage status', IntToStr(StageIndex),
    Number);
end;

class procedure TStageResultRepository.ExecUpdateStartTimeForNumber(Q: TSQLQuery;
  const StageIndex: integer; const StartTime: string; const Number, StageCount: integer);
begin
  Q.SQL.Text := UpdateStartTimeForNumber(StageIndex, StageCount);
  Q.ParamByName('STARTTIME').AsString := StartTime;
  Q.ParamByName('NUMBER').AsInteger := Number;
  ExecuteParticipantStageWrite(Q, 'update start time', IntToStr(StageIndex),
    IntToStr(Number));
end;

class procedure TStageResultRepository.ExecUpdateCorrection(Q: TSQLQuery;
  const StageIndex, Correction, Number, StageCount: integer);
begin
  Q.SQL.Text := UpdateCorrection(StageIndex, StageCount);
  Q.ParamByName('CORRECTION').AsInteger := Correction;
  Q.ParamByName('NUMBER').AsInteger := Number;
  ExecuteParticipantStageWrite(Q, 'update correction', IntToStr(StageIndex),
    IntToStr(Number));
end;

class procedure TStageResultRepository.ExecUpdateFinishForCheckedStages(Q: TSQLQuery;
  const CheckedStages: array of integer; const TimeValue: string;
  const Number, StageCount: integer);
var
  I: integer;
  setPart, stageContext: string;
begin
  if Length(CheckedStages) = 0 then
    Exit;

  Q.SQL.Clear;
  Q.SQL.Add(UpdateFinishPrefix);
  stageContext := '';
  for I := Low(CheckedStages) to High(CheckedStages) do
  begin
    setPart := UpdateFinishSetPart(CheckedStages[I], StageCount);
    if stageContext <> '' then
      stageContext := stageContext + ',';
    stageContext := stageContext + IntToStr(CheckedStages[I]);
    if I > Low(CheckedStages) then
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
  ExecuteParticipantStageWrite(Q, 'update finish time', stageContext,
    IntToStr(Number));
end;

end.
