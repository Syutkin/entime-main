unit CompetitionImportRepository;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SQLDB, StartItemModel, StageConfig, ParticipantStatus;

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
      const StageCount: integer): string; static;
    class function UpsertStageResultRowStatement(
      const ImportFormat: TStageResultImportFormat;
      const StageIndex: integer; const StageCount: integer =
      MAX_SUPPORTED_STAGE_COUNT): string; static;
  end;

implementation

uses
  SysUtils, ConfigRepository, SqlValueHelpers;

class procedure TCompetitionImportRepository.BindParticipantRowParameters(
  Q: TSQLQuery; const StartItem: TStartItemModel; const StageCount: integer);
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

class procedure TCompetitionImportRepository.ExecUpsertStageDefinitions(
  Q: TSQLQuery; const StageNames: TStrings);
var
  I: integer;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if StageNames = nil then
    raise EArgumentNilException.Create('StageNames');
  for I := 0 to StageNames.Count - 1 do
  begin
    TConfigSql.ExecUpsertByKey(Q, 'stagename' + IntToStr(I + 1),
      StageNames[I]);
    TConfigSql.ExecUpsertByKey(Q, 'stage' + IntToStr(I + 1),
      BoolToStr(True, True));
  end;
end;

class procedure TCompetitionImportRepository.ExecApplyStageDefinitions(
  Q: TSQLQuery; const StageNames: TStrings; const StageCount: integer);
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

  for StageIndex := 1 to StageCount do
  begin
    StageIsActive := StageIndex <= StageNames.Count;
    if StageIsActive then
      TConfigSql.ExecUpsertByKey(Q, 'stagename' + IntToStr(StageIndex),
        StageNames[StageIndex - 1]);
    TConfigSql.ExecUpsertByKey(Q, 'stage' + IntToStr(StageIndex),
      BoolToStr(StageIsActive, True));
  end;
  TConfigSql.ExecUpsertByKey(Q, 'stagecount', IntToStr(StageCount));
end;

class procedure TCompetitionImportRepository.PrepareParticipantRows(
  Q: TSQLQuery; const StageCount: integer);
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

class procedure TCompetitionImportRepository.ExecPreparedParticipantRow(
  Q: TSQLQuery; const StartItem: TStartItemModel; const StageCount: integer);
begin
  BindParticipantRowParameters(Q, StartItem, StageCount);
  Q.ExecSQL;
end;

class procedure TCompetitionImportRepository.PrepareStageResultRows(
  Q: TSQLQuery; const ImportFormat: TStageResultImportFormat;
  const StageIndex, StageCount: integer);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  Q.Close;
  if Q.Prepared then
    Q.UnPrepare;
  Q.SQL.Text := UpsertStageResultRowStatement(ImportFormat, StageIndex,
    StageCount);
  Q.Prepare;
end;

class procedure TCompetitionImportRepository.ExecPreparedStageResultRow(
  Q: TSQLQuery; const ImportRow: TStageResultImportRow;
  const ImportFormat: TStageResultImportFormat);

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
    Result := Result + 'starttime' + IntToStr(I) +
      '= excluded.starttime' + IntToStr(I);
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
        ', penalty' + StageSuffix + ', status' + StageSuffix + ') VALUES ' +
        '(:NUMBER, :STARTTIME, :CORRECTION, :FINISHTIME, :PENALTY, :STATUS) ' +
        'ON CONFLICT(number) DO UPDATE SET ' +
        'starttime' + StageSuffix + ' = excluded.starttime' + StageSuffix +
        ', correction' + StageSuffix + ' = excluded.correction' + StageSuffix +
        ', finishtime' + StageSuffix + ' = excluded.finishtime' + StageSuffix +
        ', penalty' + StageSuffix + ' = excluded.penalty' + StageSuffix +
        ', status' + StageSuffix + ' = excluded.status' + StageSuffix + ';';
    srifStart:
      Result := 'INSERT INTO main (number, starttime' + StageSuffix +
        ', correction' + StageSuffix + ', status' + StageSuffix + ') VALUES ' +
        '(:NUMBER, :STARTTIME, :CORRECTION, :STATUS) ' +
        'ON CONFLICT(number) DO UPDATE SET ' +
        'starttime' + StageSuffix + ' = excluded.starttime' + StageSuffix +
        ', correction' + StageSuffix + ' = excluded.correction' + StageSuffix +
        ', status' + StageSuffix + ' = excluded.status' + StageSuffix + ';';
    srifFinish:
      Result := 'INSERT INTO main (number, finishtime' + StageSuffix +
        ', status' + StageSuffix + ') VALUES (:NUMBER, :FINISHTIME, :STATUS) ' +
        'ON CONFLICT(number) DO UPDATE SET ' +
        'finishtime' + StageSuffix + ' = excluded.finishtime' + StageSuffix +
        ', status' + StageSuffix + ' = excluded.status' + StageSuffix + ';';
  end;
end;

end.
