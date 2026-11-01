unit ParticipantCardRepository;
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
interface

uses SQLDB, StageModel, ParticipantCardModel;

type
  TParticipantCardRepository = record
    class function Load(const Q: TSQLQuery; const Stages: TStages;
      const ParticipantId: integer; const Snapshot: TParticipantCardSnapshot): boolean;
      static;
  end;

implementation

uses SysUtils, DB, StageFieldNames, TimingMark;

function ReadValue(const Field: TField): TCardValue;
begin
  if Field.IsNull then Result := TCardValue.Null
  else
    Result := TCardValue.Value(Field.AsString);
end;

procedure ReadMarks(const Q: TSQLQuery; const Snapshot: TParticipantCardSnapshot;
  const Kind: TTimingMarkKind);
var
  I, Offset: integer;
  M: TCardMark;
  TableName: string;
begin
  if Kind = tmkStart then TableName := 'start_marks'
  else
    TableName := 'finish_marks';
  Q.SQL.Text := 'SELECT * FROM ' + TableName + ' WHERE participant_number = :NUMBER ' +
    'ORDER BY received_at DESC, id DESC;';
  Q.ParamByName('NUMBER').AsInteger := Snapshot.Number;
  Q.Open;
  Offset := Length(Snapshot.Marks);
  SetLength(Snapshot.Marks, Offset + Q.RecordCount);
  I := Offset;
  while not Q.EOF do
  begin
    M := Default(TCardMark);
    M.Key.Kind := Kind;
    M.Key.Id := Q.FieldByName('id').AsLargeInt;
    M.Number := Snapshot.Number;
    M.ReceivedStage := Q.FieldByName('stage_index').AsInteger;
    if Kind = tmkStart then
    begin
      M.HasAppliedStage := not Q.FieldByName('applied_stage_index').IsNull;
      M.AppliedStage := Q.FieldByName('applied_stage_index').AsInteger;
      M.Correction := ReadValue(Q.FieldByName('correction_ms'));
    end
    else
      M.Correction := TCardValue.Null;
    M.EventTime := Q.FieldByName('event_time').AsString;
    M.ReceivedAt := Q.FieldByName('received_at').AsString;
    M.AppliedAt := Q.FieldByName('applied_at').AsString;
    M.Status := Q.FieldByName('status').AsString;
    M.SourceKind := Q.FieldByName('source_kind').AsString;
    M.DeviceId := Q.FieldByName('source_device_id').AsString;
    M.AssignmentMode := Q.FieldByName('assignment_mode').AsString;
    M.Diagnostic := Q.FieldByName('diagnostic').AsString;
    Snapshot.Marks[I] := M;
    Inc(I);
    Q.Next;
  end;
  Q.Close;
end;

class function TParticipantCardRepository.Load(const Q: TSQLQuery;
  const Stages: TStages; const ParticipantId: integer;
  const Snapshot: TParticipantCardSnapshot): boolean;
var
  Sql: string;
  P: TCardParticipantField;
  K: TStageFieldKind;
  I: integer;
begin
  Sql := 'SELECT id, number';
  for P := Low(P) to High(P) do Sql := Sql + ', ' + CardParticipantColumns[P];
  for I := 1 to Stages.Count do
    for K := sfkStartTime to sfkStatus do
      Sql := Sql + ', ' + StageFieldPrefix(K) + IntToStr(I);
  Q.ReadOnly := True;
  Q.PacketRecords := -1;
  Q.SQL.Text := Sql + ' FROM main WHERE id = :ID;';
  Q.ParamByName('ID').AsInteger := ParticipantId;
  Q.Open;
  Result := not Q.IsEmpty;
  if not Result then
  begin
    Q.Close;
    Exit;
  end;
  Snapshot.ParticipantId := Q.FieldByName('id').AsInteger;
  Snapshot.Number := Q.FieldByName('number').AsInteger;
  for P := Low(P) to High(P) do
    Snapshot.Fields[P] := ReadValue(Q.FieldByName(CardParticipantColumns[P]));
  SetLength(Snapshot.Stages, Stages.Count);
  for I := 1 to Stages.Count do
  begin
    Snapshot.Stages[I - 1].Index := I;
    Snapshot.Stages[I - 1].Name := Stages[I].Name;
    Snapshot.Stages[I - 1].Active := Stages[I].isActive;
    for K := sfkStartTime to sfkStatus do
      Snapshot.Stages[I - 1].Values[K] :=
        ReadValue(Q.FieldByName(StageFieldPrefix(K) + IntToStr(I)));
    Snapshot.Stages[I - 1].Classification :=
      ClassifyCardStage(Snapshot.Stages[I - 1], Snapshot.Fields[cpfStatus]);
  end;
  Q.Close;
  ReadMarks(Q, Snapshot, tmkStart);
  ReadMarks(Q, Snapshot, tmkFinish);
  SortCardMarks(Snapshot.Marks);
end;

end.
