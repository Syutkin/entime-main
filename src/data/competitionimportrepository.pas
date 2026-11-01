unit CompetitionImportRepository;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SQLDB, StartItemModel, StageConfig, ParticipantStatus,
  ResultsImportComparison;

type
  TStageResultImportFormat = (srifFullStage, srifStart, srifFinish);

  TStageResultImportRow = record
    ParticipantNumber: integer;
    StartTime: string;
    HasCorrection: boolean;
    Correction: integer;
    FinishTime: string;
    Penalty: string;
    HasStatus: boolean;
    Status: TParticipantStatus;
  end;

  TCompetitionImportRepository = record
    class function PreviewColumn(const AField: TImportField;
      const AStageIndex: integer): string; static;
    class procedure ReadPreviewRows(const Q: TSQLQuery;
      const AComparison: TResultsImportComparison; const AStageCount: integer); static;
    class procedure WritePreviewRows(const Q: TSQLQuery;
      const AComparison: TResultsImportComparison); static;
  public
    class procedure BindParticipantRowParameters(Q: TSQLQuery;
      const StartItem: TStartItemModel; const StageCount: integer); static;
    class procedure ExecUpsertStageDefinitions(Q: TSQLQuery;
      const StageNames: TStrings); static;
    class procedure ExecApplyStageDefinitions(Q: TSQLQuery;
      const StageNames: TStrings; const StageCount: integer); static;
    class procedure PrepareParticipantRows(Q: TSQLQuery;
      const StageCount: integer); static;
    class procedure FinishPreparedRows(Q: TSQLQuery); static;
    class procedure ExecPreparedParticipantRow(Q: TSQLQuery;
      const StartItem: TStartItemModel; const StageCount: integer); static;
    class procedure PrepareStageResultRows(Q: TSQLQuery;
      const ImportFormat: TStageResultImportFormat;
      const StageIndex, StageCount: integer); static;
    class procedure ExecPreparedStageResultRow(Q: TSQLQuery;
      const ImportRow: TStageResultImportRow;
      const ImportFormat: TStageResultImportFormat); static;

    class function UpsertParticipantRowStatement(
      const StageCount: integer): string;
      static;
    class function UpsertStageResultRowStatement(
      const ImportFormat: TStageResultImportFormat; const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
  end;

implementation

uses
  SysUtils, DB, ConfigRepository, SqlValueHelpers;

class function TCompetitionImportRepository.PreviewColumn(const AField: TImportField;
  const AStageIndex: integer): string;
const
  Names: array[TImportField] of string =
    ('starttime', 'correction', 'finishtime', 'penalty', 'status');
begin
  RequireStageIndex(AStageIndex, MAX_SUPPORTED_STAGE_COUNT);
  Result := Names[AField] + IntToStr(AStageIndex);
end;

class procedure TCompetitionImportRepository.ReadPreviewRows(const Q: TSQLQuery;
  const AComparison: TResultsImportComparison; const AStageCount: integer);
var
  Map: TStringList;
  I, Index: integer;
  P: TImportParticipant;
  Field: TImportField;
  Stored: TField;
  Value: TImportValue;
  Sql: string;
begin
  RequireStageIndex(AComparison.StageIndex, AStageCount);
  Map := TStringList.Create;
  try
    Map.Sorted := True;
    for I := 0 to AComparison.Count - 1 do
      Map.AddObject(IntToStr(AComparison[I].Number), AComparison[I]);
    Sql := 'SELECT id, number, name';
    for Field := Low(TImportField) to High(TImportField) do
      Sql := Sql + ', ' + PreviewColumn(Field, AComparison.StageIndex);
    Q.SQL.Text := Sql + ' FROM main ORDER BY number;';
    Q.ReadOnly := True;
    Q.PacketRecords := -1;
    Q.Open;
    while not Q.EOF do
    begin
      if Map.Find(Q.FieldByName('number').AsString, Index) then
      begin
        P := TImportParticipant(Map.Objects[Index]);
        P.Id := Q.FieldByName('id').AsInteger;
        P.Name := Q.FieldByName('name').AsString;
        for Field in P.Fields do
        begin
          Stored := Q.FieldByName(PreviewColumn(Field, AComparison.StageIndex));
          if Stored.IsNull then Value := TImportValue.Null
          else
            Value := TImportValue.Value(Stored.AsString);
          P.AddField(Field, Value, P.Proposed[Field]);
        end;
      end;
      Q.Next;
    end;
    Q.Close;
  finally
    Map.Free;
  end;
end;

class procedure TCompetitionImportRepository.WritePreviewRows(
  const Q: TSQLQuery; const AComparison: TResultsImportComparison);
var
  I, Mask, RowMask: integer;
  P: TImportParticipant;
  Field: TImportField;
  Sql, ParameterName: string;
begin
  Q.ReadOnly := False;
  Q.SQL.Text := 'INSERT INTO main (number) VALUES (:NUMBER);';
  Q.Prepare;
  try
    for I := 0 to AComparison.Count - 1 do
      if AComparison[I].CreateSelected then
      begin
        Q.ParamByName('NUMBER').AsInteger := AComparison[I].Number;
        Q.ExecSQL;
      end;
  finally
    Q.UnPrepare;
  end;
  // Five allowed fields give at most 31 statement shapes. Reuse each shape
  // for all matching rows, never use the old full-row UPSERT for a selection.
  for Mask := 1 to (1 shl (Ord(High(TImportField)) + 1)) - 1 do
  begin
    Sql := '';
    for Field := Low(TImportField) to High(TImportField) do
      if (Mask and (1 shl Ord(Field))) <> 0 then
      begin
        if Sql <> '' then Sql := Sql + ', ';
        Sql := Sql + PreviewColumn(Field, AComparison.StageIndex) +
          ' = :V' + IntToStr(Ord(Field));
      end;
    Q.SQL.Text := 'UPDATE main SET ' + Sql + ' WHERE number = :NUMBER ' +
      'AND (:ID = 0 OR id = :ID);';
    for I := 0 to AComparison.Count - 1 do
    begin
      P := AComparison[I];
      RowMask := 0;
      for Field in P.Selected do RowMask := RowMask or (1 shl Ord(Field));
      if RowMask <> Mask then Continue;
      if not Q.Prepared then Q.Prepare;
      Q.ParamByName('NUMBER').AsInteger := P.Number;
      Q.ParamByName('ID').AsInteger := P.Id;
      for Field in P.Selected do
      begin
        ParameterName := 'V' + IntToStr(Ord(Field));
        if P.Proposed[Field].Empty(Field) then Q.ParamByName(ParameterName).Clear
        else if Field = ifCorrection then
          Q.ParamByName(ParameterName).AsInteger := StrToInt(P.Proposed[Field].Text)
        else
          Q.ParamByName(ParameterName).AsString := P.Proposed[Field].Text;
      end;
      Q.ExecSQL;
      if Q.RowsAffected <> 1 then
        raise EDatabaseError.Create('Selected import participant no longer exists');
    end;
    if Q.Prepared then Q.UnPrepare;
  end;
end;

class procedure TCompetitionImportRepository.BindParticipantRowParameters(Q: TSQLQuery;
  const StartItem: TStartItemModel; const StageCount: integer);
var
  StageIndex: integer;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if StartItem = nil then
    raise EArgumentNilException.Create('StartItem');
  RequireStageCount(StageCount);
  Q.ParamByName('CATEGORY').AsString := StartItem.category;
  Q.ParamByName('NUMBER').AsInteger := StartItem.number;
  Q.ParamByName('NAME').AsString := StartItem.Name;
  Q.ParamByName('NICKNAME').AsString := StartItem.nickname;
  Q.ParamByName('AGE').AsString := StartItem.birthday;
  Q.ParamByName('TEAM').AsString := StartItem.team;
  Q.ParamByName('CITY').AsString := StartItem.city;
  Q.ParamByName('PHONE').AsString := StartItem.phone;
  Q.ParamByName('EMAIL').AsString := StartItem.email;
  Q.ParamByName('COMMENT').AsString := StartItem.comment;
  for StageIndex := 1 to StageCount do
    if StageIndex <= StartItem.startTimes.Count then
      Q.ParamByName('STARTTIME' + IntToStr(StageIndex)).AsString :=
        StartItem.startTimes[StageIndex - 1]
    else
      Q.ParamByName('STARTTIME' + IntToStr(StageIndex)).AsString := '';
end;

class procedure TCompetitionImportRepository.ExecUpsertStageDefinitions(Q: TSQLQuery;
  const StageNames: TStrings);
var
  I: integer;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if StageNames = nil then
    raise EArgumentNilException.Create('StageNames');
  TConfigSql.PrepareUpsert(Q);
  try
    for I := 0 to StageNames.Count - 1 do
    begin
      TConfigSql.ExecPreparedUpsert(Q, 'stagename' + IntToStr(I + 1),
        StageNames[I]);
      TConfigSql.ExecPreparedUpsert(Q, 'stage' + IntToStr(I + 1),
        BoolToStr(True, True));
    end;
  finally
    TConfigSql.FinishPreparedUpsert(Q);
  end;
end;

class procedure TCompetitionImportRepository.ExecApplyStageDefinitions(Q: TSQLQuery;
  const StageNames: TStrings; const StageCount: integer);
var
  StageIndex: integer;
  StageIsActive: boolean;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if StageNames = nil then
    raise EArgumentNilException.Create('StageNames');
  RequireStageCount(StageCount);
  if StageNames.Count > StageCount then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Detected stage count %d exceeds configured stage count %d.',
      [StageNames.Count, StageCount]);

  // CSV without stage columns is a participant-only import and must not
  // change the competition stage configuration.
  if StageNames.Count = 0 then
    Exit;

  TConfigSql.PrepareUpsert(Q);
  try
    for StageIndex := 1 to StageCount do
    begin
      StageIsActive := StageIndex <= StageNames.Count;
      if StageIsActive then
        TConfigSql.ExecPreparedUpsert(Q, 'stagename' + IntToStr(StageIndex),
          StageNames[StageIndex - 1]);
      TConfigSql.ExecPreparedUpsert(Q, 'stage' + IntToStr(StageIndex),
        BoolToStr(StageIsActive, True));
    end;
    TConfigSql.ExecPreparedUpsert(Q, 'stagecount', IntToStr(StageCount));
  finally
    TConfigSql.FinishPreparedUpsert(Q);
  end;
end;

class procedure TCompetitionImportRepository.PrepareParticipantRows(Q: TSQLQuery;
  const StageCount: integer);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  if Q.Prepared then
    Q.UnPrepare;
  Q.SQL.Text := UpsertParticipantRowStatement(StageCount);
  Q.Prepare;
end;

class procedure TCompetitionImportRepository.FinishPreparedRows(Q: TSQLQuery);
begin
  if Q = nil then
    Exit;
  Q.Close;
  if Q.Prepared then
    Q.UnPrepare;
end;

class procedure TCompetitionImportRepository.ExecPreparedParticipantRow(Q: TSQLQuery;
  const StartItem: TStartItemModel; const StageCount: integer);
begin
  BindParticipantRowParameters(Q, StartItem, StageCount);
  Q.ExecSQL;
end;

class procedure TCompetitionImportRepository.PrepareStageResultRows(Q: TSQLQuery;
  const ImportFormat: TStageResultImportFormat; const StageIndex, StageCount: integer);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  if Q.Prepared then
    Q.UnPrepare;
  Q.SQL.Text := UpsertStageResultRowStatement(ImportFormat, StageIndex, StageCount);
  Q.Prepare;
end;

class procedure TCompetitionImportRepository.ExecPreparedStageResultRow(Q: TSQLQuery;
  const ImportRow: TStageResultImportRow; const ImportFormat: TStageResultImportFormat);

  procedure BindNullableString(const ParameterName, Value: string);
  begin
    if Value = '' then
      Q.ParamByName(ParameterName).Clear
    else
      Q.ParamByName(ParameterName).AsString := Value;
  end;

begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.ParamByName('NUMBER').AsInteger := ImportRow.ParticipantNumber;
  case ImportFormat of
    srifFullStage:
    begin
      BindNullableString('STARTTIME', ImportRow.StartTime);
      if ImportRow.HasCorrection then
        Q.ParamByName('CORRECTION').AsInteger := ImportRow.Correction
      else
        Q.ParamByName('CORRECTION').Clear;
      BindNullableString('FINISHTIME', ImportRow.FinishTime);
      BindNullableString('PENALTY', ImportRow.Penalty);
    end;
    srifStart:
    begin
      BindNullableString('STARTTIME', ImportRow.StartTime);
      if ImportRow.HasCorrection then
        Q.ParamByName('CORRECTION').AsInteger := ImportRow.Correction
      else
        Q.ParamByName('CORRECTION').Clear;
    end;
    srifFinish:
      BindNullableString('FINISHTIME', ImportRow.FinishTime);
  end;
  if ImportRow.HasStatus then
    Q.ParamByName('STATUS').AsString :=
      ParticipantStatusToDbValue(ImportRow.Status)
  else
    Q.ParamByName('STATUS').Clear;
  Q.ExecSQL;
end;

class function TCompetitionImportRepository.UpsertParticipantRowStatement(
  const StageCount: integer): string;
var
  I: integer;
begin
  RequireStageCount(StageCount);
  Result := 'INSERT INTO main (category, number, name, nickname, age, team, ' +
    'city, phone, email, comment,';
  for I := 1 to StageCount do
  begin
    Result := Result + 'starttime' + IntToStr(I);
    if I < StageCount then
      Result := Result + ',';
  end;
  Result := Result + ') VALUES ' +
    '(:CATEGORY, :NUMBER, :NAME, :NICKNAME, :AGE, :TEAM, :CITY, ' +
    ':PHONE, :EMAIL, :COMMENT,';
  for I := 1 to StageCount do
  begin
    Result := Result + ':STARTTIME' + IntToStr(I);
    if I < StageCount then
      Result := Result + ',';
  end;
  Result := Result + ') ON CONFLICT(number) DO UPDATE SET ' +
    'category = excluded.category, name = excluded.name, ' +
    'nickname = excluded.nickname, age = excluded.age, team = excluded.team, ' +
    'city = excluded.city, phone = excluded.phone, email = excluded.email, ' +
    'comment = excluded.comment,';
  for I := 1 to StageCount do
  begin
    Result := Result + 'starttime' + IntToStr(I) + '= excluded.starttime' +
      IntToStr(I);
    if I < StageCount then
      Result := Result + ',';
  end;
  Result := Result + ';';
end;

class function TCompetitionImportRepository.UpsertStageResultRowStatement(
  const ImportFormat: TStageResultImportFormat;
  const StageIndex, StageCount: integer): string;
var
  StageSuffix: string;
begin
  RequireStageIndex(StageIndex, StageCount);
  StageSuffix := IntToStr(StageIndex);
  case ImportFormat of
    srifFullStage:
      Result := 'INSERT INTO main (number, starttime' + StageSuffix +
        ', correction' + StageSuffix + ', finishtime' + StageSuffix +
        ', penalty' + StageSuffix + ', status' + StageSuffix +
        ') VALUES ' + '(:NUMBER, :STARTTIME, :CORRECTION, :FINISHTIME, :PENALTY, :STATUS) '
        + 'ON CONFLICT(number) DO UPDATE SET ' + 'starttime' +
        StageSuffix + ' = excluded.starttime' + StageSuffix + ', correction' +
        StageSuffix + ' = excluded.correction' + StageSuffix + ', finishtime' +
        StageSuffix + ' = excluded.finishtime' + StageSuffix + ', penalty' +
        StageSuffix + ' = excluded.penalty' + StageSuffix + ', status' +
        StageSuffix + ' = excluded.status' + StageSuffix + ';';
    srifStart:
      Result := 'INSERT INTO main (number, starttime' + StageSuffix +
        ', correction' + StageSuffix + ', status' + StageSuffix +
        ') VALUES ' + '(:NUMBER, :STARTTIME, :CORRECTION, :STATUS) ' +
        'ON CONFLICT(number) DO UPDATE SET ' + 'starttime' +
        StageSuffix + ' = excluded.starttime' + StageSuffix + ', correction' +
        StageSuffix + ' = excluded.correction' + StageSuffix + ', status' +
        StageSuffix + ' = excluded.status' + StageSuffix + ';';
    srifFinish:
      Result := 'INSERT INTO main (number, finishtime' + StageSuffix +
        ', status' + StageSuffix + ') VALUES (:NUMBER, :FINISHTIME, :STATUS) ' +
        'ON CONFLICT(number) DO UPDATE SET ' + 'finishtime' +
        StageSuffix + ' = excluded.finishtime' + StageSuffix + ', status' +
        StageSuffix + ' = excluded.status' + StageSuffix + ';';
  end;
end;

end.
