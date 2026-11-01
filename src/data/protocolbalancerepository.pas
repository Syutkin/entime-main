unit ProtocolBalanceRepository;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  CompetitionDbContext, StageModel, ProtocolBalance;

type
  TProtocolBalanceRepository = record
    class function Load(const AContext: TCompetitionDbContext;
      const AStages: TStages): TProtocolBalanceSnapshot; static;
    class function TryLoadSaved(const AContext: TCompetitionDbContext;
      const AStages: TStages; var ASnapshot: TProtocolBalanceSnapshot): boolean; static;
  end;

implementation

uses
  SysUtils, DB, SQLDB, SqlValueHelpers;

type
  TStageFields = record
    StartTime, FinishTime, ResultValue, StatusValue: TField;
  end;

procedure ReadParticipants(const AQuery: TSQLQuery;
  var ASnapshot: TProtocolBalanceSnapshot);
var
  Sql, Suffix: string;
  StageFields: array of TStageFields;
  IdField, NumberField, NameField, CategoryField, GlobalStatusField: TField;
  I, RowIndex: integer;
  Row: TProtocolBalanceParticipantRow;
begin
  Sql := 'SELECT id, number, name, category, status';
  for I := 0 to High(ASnapshot.Stages) do
  begin
    Suffix := IntToStr(ASnapshot.Stages[I].StageIndex);
    Sql := Sql + ', ' + SqlIdentifier('starttime' + Suffix) + ', ' +
      SqlIdentifier('finishtime' + Suffix) + ', ' + SqlIdentifier('result' + Suffix) +
      ', ' + SqlIdentifier('status' + Suffix);
  end;
  AQuery.SQL.Text := Sql + ' FROM main ORDER BY number, id;';
  AQuery.Open;
  IdField := AQuery.FieldByName('id');
  NumberField := AQuery.FieldByName('number');
  NameField := AQuery.FieldByName('name');
  CategoryField := AQuery.FieldByName('category');
  GlobalStatusField := AQuery.FieldByName('status');
  SetLength(StageFields, Length(ASnapshot.Stages));
  for I := 0 to High(ASnapshot.Stages) do
  begin
    SetLength(ASnapshot.Stages[I].Participants, AQuery.RecordCount);
    Suffix := IntToStr(ASnapshot.Stages[I].StageIndex);
    StageFields[I].StartTime := AQuery.FieldByName('starttime' + Suffix);
    StageFields[I].FinishTime := AQuery.FieldByName('finishtime' + Suffix);
    StageFields[I].ResultValue := AQuery.FieldByName('result' + Suffix);
    StageFields[I].StatusValue := AQuery.FieldByName('status' + Suffix);
  end;
  RowIndex := 0;
  while not AQuery.EOF do
  begin
    Row.ParticipantId := IdField.AsInteger;
    Row.Number := NumberField.AsInteger;
    Row.Name := NameField.AsString;
    Row.Category := CategoryField.AsString;
    Row.Data.GlobalStatusValue := GlobalStatusField.AsString;
    for I := 0 to High(ASnapshot.Stages) do
    begin
      Row.Data.StartTime := StageFields[I].StartTime.AsString;
      Row.Data.FinishTime := StageFields[I].FinishTime.AsString;
      Row.Data.ResultValue := StageFields[I].ResultValue.AsString;
      Row.Data.StageStatusValue := StageFields[I].StatusValue.AsString;
      Row.Classification := ClassifyProtocolBalance(Row.Data);
      ASnapshot.Stages[I].Participants[RowIndex] := Row;
      AddProtocolBalanceClassification(ASnapshot.Stages[I].Summary,
        Row.Classification);
    end;
    Inc(RowIndex);
    AQuery.Next;
  end;
  AQuery.Close;
end;

procedure ReadMarkCounts(const AQuery: TSQLQuery; const AStartMarks: boolean;
  var ASnapshot: TProtocolBalanceSnapshot);
var
  TableName, PendingCondition, StageIndexes: string;
  I, StageIndex, PendingCount, ErrorCount: integer;
  StageField, PendingField, ErrorField: TField;
begin
  if AStartMarks then
  begin
    TableName := 'start_marks';
    PendingCondition := 'status IN (''pending'', ''conflict'')';
  end
  else
  begin
    TableName := 'finish_marks';
    PendingCondition := 'status = ''pending''';
  end;
  StageIndexes := '';
  for I := 0 to High(ASnapshot.Stages) do
  begin
    if StageIndexes <> '' then StageIndexes := StageIndexes + ', ';
    StageIndexes := StageIndexes + IntToStr(ASnapshot.Stages[I].StageIndex);
  end;
  AQuery.SQL.Text := 'SELECT stage_index, SUM(CASE WHEN ' + PendingCondition +
    ' THEN 1 ELSE 0 END) AS pending_count, ' +
    'SUM(CASE WHEN status = ''error'' THEN 1 ELSE 0 END) AS error_count FROM ' +
    TableName + ' WHERE stage_index IN (' + StageIndexes + ') AND (' +
    PendingCondition + ' OR status = ''error'') GROUP BY stage_index;';
  AQuery.Open;
  StageField := AQuery.FieldByName('stage_index');
  PendingField := AQuery.FieldByName('pending_count');
  ErrorField := AQuery.FieldByName('error_count');
  while not AQuery.EOF do
  begin
    StageIndex := StageField.AsInteger;
    PendingCount := PendingField.AsInteger;
    ErrorCount := ErrorField.AsInteger;
    for I := 0 to High(ASnapshot.Stages) do
      if ASnapshot.Stages[I].StageIndex = StageIndex then
      begin
        if AStartMarks then
        begin
          ASnapshot.Stages[I].Marks.PendingStarts := PendingCount;
          ASnapshot.Stages[I].Marks.StartErrors := ErrorCount;
        end
        else
        begin
          ASnapshot.Stages[I].Marks.PendingFinishes := PendingCount;
          ASnapshot.Stages[I].Marks.FinishErrors := ErrorCount;
        end;
        Break;
      end;
    AQuery.Next;
  end;
  AQuery.Close;
end;

class function TProtocolBalanceRepository.Load(const AContext: TCompetitionDbContext;
  const AStages: TStages): TProtocolBalanceSnapshot;
var
  Snapshot: TProtocolBalanceSnapshot;
  StageIndexes: TStageIndexArray;
  Query: TSQLQuery;
  OwnTransaction: boolean;
  I: integer;
begin
  if AContext = nil then raise EArgumentNilException.Create('AContext');
  if AStages = nil then raise EArgumentNilException.Create('AStages');
  if not AContext.Connection.Connected then
    raise EDatabaseError.Create('Competition database is not open.');

  Snapshot := Default(TProtocolBalanceSnapshot);
  StageIndexes := AStages.ActiveIndices;
  SetLength(Snapshot.Stages, Length(StageIndexes));
  for I := 0 to High(StageIndexes) do
  begin
    Snapshot.Stages[I].StageIndex := StageIndexes[I];
    Snapshot.Stages[I].StageName := AStages[StageIndexes[I]].Name;
  end;
  if Length(StageIndexes) = 0 then Exit(Snapshot);

  OwnTransaction := not AContext.Transaction.Active;
  if OwnTransaction then AContext.Transaction.StartTransaction;
  try
    Query := AContext.CreateQuery(nil);
    try
      Query.ReadOnly := True;
      // Fetch all rows once so the snapshot arrays can be allocated exactly.
      Query.PacketRecords := -1;
      ReadParticipants(Query, Snapshot);
      ReadMarkCounts(Query, True, Snapshot);
      ReadMarkCounts(Query, False, Snapshot);
    finally
      Query.Free;
    end;
  finally
    // Never commit or roll back a transaction that belongs to the caller.
    if OwnTransaction and AContext.Transaction.Active then
      AContext.Transaction.Rollback;
  end;
  // Publish only after every read and our transaction cleanup have succeeded.
  Result := Snapshot;
end;

class function TProtocolBalanceRepository.TryLoadSaved(
  const AContext: TCompetitionDbContext; const AStages: TStages;
  var ASnapshot: TProtocolBalanceSnapshot): boolean;
begin
  if AContext = nil then raise EArgumentNilException.Create('AContext');
  // A queued UI read may run inside a modal dialog opened by a writer.
  // Keep the previous snapshot until the whole operation has finished.
  if AContext.UnitOfWorkActive then Exit(False);
  ASnapshot := Load(AContext, AStages);
  Result := True;
end;

end.
