unit ParticipantRepository;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, SQLDB, ParticipantStatus;

type
  TParticipantStatusArray = array of TParticipantStatus;

  TParticipantStatusRow = record
    Number: integer;
    GlobalStatus: TParticipantStatus;
    StageStatuses: TParticipantStatusArray;
  end;

  TParticipantStatusRows = array of TParticipantStatusRow;

  TParticipantRepository = record
  private
    class function SelectByNumber: string; static;
    class function SelectStatuses(const StageCount: integer;
      const ActiveStageIndexes: array of integer;
      const FilterByNumber: boolean): string; static;
    class function UpdateGlobalStatus: string; static;
    class function ClearOnlyGlobalStatus: string; static;
  public
    class function SelectAll: string; static;
    class function SelectNumbers: string; static;
    class function SelectMaxNumber: string; static;
    class function SelectCategoryGrouped: string; static;
    class function SelectCategoryResults(const ColumnsCsv: string): string; static;
    class function SelectStatusAll: string; static;

    class function OpenByNumber(Q: TSQLQuery; const Number: integer): boolean;
      static;
    class function OpenById(Q: TSQLQuery; const ParticipantId: integer): boolean;
      static;
    class function TryGetCurrentId(Q: TSQLQuery; out Id: integer): boolean; static;
    class function TryGetCurrentNumber(Q: TSQLQuery; out Number: string): boolean;
      static;
    class function TryLoadIdentity(Q: TSQLQuery; const Number: integer;
      out ParticipantName, Category: string): boolean; static;
    class function LoadStatuses(Q: TSQLQuery; const Number, StageCount: integer;
      out GlobalStatus: TParticipantStatus;
      out StageStatuses: TParticipantStatusArray): boolean; static;
    class procedure LoadAllStatuses(Q: TSQLQuery; const StageCount: integer;
      const ActiveStageIndexes: array of integer;
      out Rows: TParticipantStatusRows); static;
    class function GetMaxNumber(Q: TSQLQuery): integer; static;
    class procedure LoadCategories(Q: TSQLQuery; Categories: TStrings); static;
    class procedure LoadNumbers(Q: TSQLQuery; Numbers: TStrings); static;
    class procedure LoadGroupedCategories(Q: TSQLQuery; Categories: TStrings;
      const MaxCount: integer = 0); static;
    class procedure LoadGlobalStatusNumbers(Q: TSQLQuery;
      Numbers: TStrings); static;
    class procedure ConfigureCategoryResults(Q: TSQLQuery;
      const ColumnsCsv, Category: string); static;

    class procedure ExecUpdateOnlyGlobalStatusDsq(Q: TSQLQuery;
      const Number: string); static;
    class procedure ExecUpdateGlobalStatus(Q: TSQLQuery;
      const Status: TParticipantStatus; const Number: string); static;
    class procedure PrepareGlobalStatusUpdates(Q: TSQLQuery); static;
    class procedure ExecPreparedGlobalStatusUpdate(Q: TSQLQuery;
      const Status: TParticipantStatus; const Number: integer); static;
    class procedure FinishPreparedGlobalStatusUpdates(Q: TSQLQuery); static;
    class procedure ExecClearOnlyGlobalStatus(Q: TSQLQuery;
      const Number: string); static;
  end;

implementation

uses
  SqlValueHelpers;

class function TParticipantRepository.SelectByNumber: string;
begin
  Result := 'SELECT * FROM main WHERE number = :NUMBER;';
end;

class function TParticipantRepository.SelectStatuses(const StageCount: integer;
  const ActiveStageIndexes: array of integer; const FilterByNumber: boolean): string;
var
  ActiveIndex, StageIndex: integer;
begin
  RequireStageCount(StageCount);
  Result := 'SELECT number, status';
  for ActiveIndex := 0 to High(ActiveStageIndexes) do
  begin
    StageIndex := ActiveStageIndexes[ActiveIndex];
    RequireStageIndex(StageIndex, StageCount);
    Result := Result + ', status' + IntToStr(StageIndex);
  end;
  Result := Result + ' FROM main';
  if FilterByNumber then
    Result := Result + ' WHERE number = :NUMBER'
  else
    Result := Result + ' WHERE number IS NOT NULL';
  Result := Result + ';';
end;

class function TParticipantRepository.UpdateGlobalStatus: string;
begin
  Result := 'UPDATE main SET status = :STATUS WHERE number = :NUMBER;';
end;

class function TParticipantRepository.ClearOnlyGlobalStatus: string;
begin
  Result := 'UPDATE main SET status = NULL WHERE number = :NUMBER;';
end;

class function TParticipantRepository.SelectAll: string;
begin
  Result := 'SELECT * FROM main;';
end;

class function TParticipantRepository.SelectNumbers: string;
begin
  Result := 'SELECT number FROM main WHERE number IS NOT NULL;';
end;

class function TParticipantRepository.SelectMaxNumber: string;
begin
  Result := 'SELECT MAX(number) as number FROM main;';
end;

class function TParticipantRepository.SelectCategoryGrouped: string;
begin
  Result := 'SELECT category FROM main GROUP BY category;';
end;

class function TParticipantRepository.SelectCategoryResults(
  const ColumnsCsv: string): string;
begin
  Result := 'SELECT ' + SqlIdentifierCsv(ColumnsCsv) + ' FROM main ' +
    'WHERE category IS :CATEGORY ' +
    'ORDER BY IFNULL(sumplace,''toend''), IFNULL(sumresult,''toend'');';
end;

class function TParticipantRepository.SelectStatusAll: string;
begin
  Result := 'SELECT number FROM main WHERE status NOTNULL;';
end;

class function TParticipantRepository.OpenByNumber(Q: TSQLQuery;
  const Number: integer): boolean;
begin
  Q.Close;
  Q.SQL.Text := SelectByNumber;
  Q.ParamByName('NUMBER').AsInteger := Number;
  Q.Open;
  Result := not Q.EOF;
end;

class function TParticipantRepository.OpenById(Q: TSQLQuery;
  const ParticipantId: integer): boolean;
begin
  Q.Close;
  Q.SQL.Text := 'SELECT * FROM main WHERE id = :ID;';
  Q.ParamByName('ID').AsInteger := ParticipantId;
  Q.Open;
  Result := not Q.EOF;
end;

class function TParticipantRepository.TryGetCurrentId(Q: TSQLQuery;
  out Id: integer): boolean;
begin
  Id := 0;
  Result := Assigned(Q) and Q.Active and (not Q.EOF) and
    (not Q.FieldByName('id').IsNull);
  if Result then
    Id := Q.FieldByName('id').AsInteger;
end;

class function TParticipantRepository.TryGetCurrentNumber(Q: TSQLQuery;
  out Number: string): boolean;
begin
  Number := '';
  Result := Assigned(Q) and Q.Active and (not Q.EOF) and
    (not Q.FieldByName('number').IsNull);
  if Result then
    Number := Q.FieldByName('number').AsString;
end;

class function TParticipantRepository.TryLoadIdentity(Q: TSQLQuery;
  const Number: integer; out ParticipantName, Category: string): boolean;
begin
  ParticipantName := '';
  Category := '';
  Result := OpenByNumber(Q, Number);
  try
    if Result then
    begin
      ParticipantName := Q.FieldByName('name').AsString;
      Category := Q.FieldByName('category').AsString;
    end;
  finally
    Q.Close;
  end;
end;

class function TParticipantRepository.LoadStatuses(Q: TSQLQuery;
  const Number, StageCount: integer; out GlobalStatus: TParticipantStatus;
  out StageStatuses: TParticipantStatusArray): boolean;
var
  StageIndex: integer;
  StageIndexes: array of integer;
  StatusText: string;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  RequireStageCount(StageCount);
  GlobalStatus := psNone;
  StageStatuses := nil;
  StageIndexes := nil;
  SetLength(StageStatuses, StageCount);
  SetLength(StageIndexes, StageCount);
  for StageIndex := 0 to High(StageStatuses) do
  begin
    StageStatuses[StageIndex] := psNone;
    StageIndexes[StageIndex] := StageIndex + 1;
  end;

  Q.Close;
  Q.SQL.Text := SelectStatuses(StageCount, StageIndexes, True);
  Q.ParamByName('NUMBER').AsInteger := Number;
  Q.Open;
  Result := not Q.EOF;
  try
    if not Result then
      Exit;
    StatusText := Q.FieldByName('status').AsString;
    if not TryParticipantStatusFromDbValue(StatusText, GlobalStatus) then
      GlobalStatus := psNone;
    for StageIndex := 1 to StageCount do
    begin
      StatusText := Q.FieldByName('status' + IntToStr(StageIndex)).AsString;
      if not TryParticipantStatusFromDbValue(StatusText,
        StageStatuses[StageIndex - 1]) then
        StageStatuses[StageIndex - 1] := psNone;
    end;
  finally
    Q.Close;
  end;
end;

class procedure TParticipantRepository.LoadAllStatuses(Q: TSQLQuery;
  const StageCount: integer; const ActiveStageIndexes: array of integer;
  out Rows: TParticipantStatusRows);
var
  ActiveIndex, Capacity, RowCount, RowIndex, StageIndex: integer;
  StatusText: string;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Rows := nil;
  Capacity := 0;
  RowCount := 0;
  Q.Close;
  Q.SQL.Text := SelectStatuses(StageCount, ActiveStageIndexes, False);
  Q.Open;
  try
    while not Q.EOF do
    begin
      if RowCount = Capacity then
      begin
        if Capacity = 0 then
          Capacity := 16
        else
          Capacity := Capacity * 2;
        SetLength(Rows, Capacity);
      end;
      RowIndex := RowCount;
      Inc(RowCount);
      Rows[RowIndex].Number := Q.FieldByName('number').AsInteger;
      StatusText := Q.FieldByName('status').AsString;
      if not TryParticipantStatusFromDbValue(StatusText,
        Rows[RowIndex].GlobalStatus) then
        Rows[RowIndex].GlobalStatus := psNone;

      SetLength(Rows[RowIndex].StageStatuses, StageCount);
      for StageIndex := 0 to StageCount - 1 do
        Rows[RowIndex].StageStatuses[StageIndex] := psNone;
      for ActiveIndex := 0 to High(ActiveStageIndexes) do
      begin
        StageIndex := ActiveStageIndexes[ActiveIndex];
        StatusText := Q.FieldByName('status' + IntToStr(StageIndex)).AsString;
        if not TryParticipantStatusFromDbValue(StatusText,
          Rows[RowIndex].StageStatuses[StageIndex - 1]) then
          Rows[RowIndex].StageStatuses[StageIndex - 1] := psNone;
      end;
      Q.Next;
    end;
    SetLength(Rows, RowCount);
  finally
    Q.Close;
  end;
end;

class function TParticipantRepository.GetMaxNumber(Q: TSQLQuery): integer;
begin
  Result := 0;
  Q.Close;
  Q.SQL.Text := SelectMaxNumber;
  Q.Open;
  try
    if not Q.FieldByName('number').IsNull then
      Result := Q.FieldByName('number').AsInteger;
  finally
    Q.Close;
  end;
end;

class procedure TParticipantRepository.LoadCategories(Q: TSQLQuery;
  Categories: TStrings);
begin
  Categories.BeginUpdate;
  try
    Categories.Clear;
    Q.Close;
    Q.SQL.Text :=
      'SELECT DISTINCT category FROM main ' +
      'WHERE category IS NOT NULL AND TRIM(category) <> '''' ' +
      'ORDER BY category COLLATE NOCASE;';
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
  finally
    Categories.EndUpdate;
  end;
end;

class procedure TParticipantRepository.LoadNumbers(Q: TSQLQuery; Numbers: TStrings);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if Numbers = nil then
    raise EArgumentNilException.Create('Numbers');
  Numbers.Clear;
  Q.Close;
  Q.SQL.Text := SelectNumbers;
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

class procedure TParticipantRepository.LoadGroupedCategories(Q: TSQLQuery;
  Categories: TStrings; const MaxCount: integer);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if Categories = nil then
    raise EArgumentNilException.Create('Categories');
  Categories.Clear;
  Q.Close;
  Q.SQL.Text := SelectCategoryGrouped;
  Q.Open;
  try
    while not Q.EOF do
    begin
      Categories.Add(Q.FieldByName('category').AsString);
      if (MaxCount > 0) and (Categories.Count >= MaxCount) then
        Break;
      Q.Next;
    end;
  finally
    Q.Close;
  end;
end;

class procedure TParticipantRepository.LoadGlobalStatusNumbers(Q: TSQLQuery;
  Numbers: TStrings);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if Numbers = nil then
    raise EArgumentNilException.Create('Numbers');
  Numbers.Clear;
  Q.Close;
  Q.SQL.Text := SelectStatusAll;
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

class procedure TParticipantRepository.ConfigureCategoryResults(Q: TSQLQuery;
  const ColumnsCsv, Category: string);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  Q.SQL.Text := SelectCategoryResults(ColumnsCsv);
  Q.ParamByName('CATEGORY').AsString := Category;
end;

class procedure TParticipantRepository.ExecUpdateOnlyGlobalStatusDsq(Q: TSQLQuery;
  const Number: string);
begin
  ExecUpdateGlobalStatus(Q, psDSQ, Number);
end;

class procedure TParticipantRepository.ExecUpdateGlobalStatus(Q: TSQLQuery;
  const Status: TParticipantStatus; const Number: string);
begin
  PrepareGlobalStatusUpdates(Q);
  try
    ExecPreparedGlobalStatusUpdate(Q, Status, StrToIntDef(Number, 0));
  finally
    FinishPreparedGlobalStatusUpdates(Q);
  end;
end;

class procedure TParticipantRepository.PrepareGlobalStatusUpdates(Q: TSQLQuery);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  if Q.Prepared then
    Q.UnPrepare;
  Q.SQL.Text := UpdateGlobalStatus;
  Q.Prepare;
end;

class procedure TParticipantRepository.ExecPreparedGlobalStatusUpdate(Q: TSQLQuery;
  const Status: TParticipantStatus; const Number: integer);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if Status = psNone then
    Q.ParamByName('STATUS').Clear
  else
    Q.ParamByName('STATUS').AsString := ParticipantStatusToDbValue(Status);
  Q.ParamByName('NUMBER').AsInteger := Number;
  Q.ExecSQL;
end;

class procedure TParticipantRepository.FinishPreparedGlobalStatusUpdates(Q: TSQLQuery);
begin
  if Q = nil then
    Exit;
  Q.Close;
  if Q.Prepared then
    Q.UnPrepare;
end;

class procedure TParticipantRepository.ExecClearOnlyGlobalStatus(Q: TSQLQuery;
  const Number: string);
begin
  Q.SQL.Text := ClearOnlyGlobalStatus;
  Q.ParamByName('NUMBER').AsString := Number;
  Q.Close;
  Q.ExecSQL;
  Q.Close;
end;

end.
