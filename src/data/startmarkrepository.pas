unit StartMarkRepository;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, SQLDB, CompetitionDbContext, StartMark;

type
  TStartMarkArray = array of TStartMark;
  TStartMarkJournalFilter = (smjfAll, smjfPending, smjfApplied,
    smjfHidden, smjfConflictOrError, smjfLast15Minutes,
    smjfCurrentStage);

  { TStartMarkSql }

  TStartMarkSql = record
  private
    class function InsertStatement: string; static;
    class function UpdateStatement: string; static;
  public
    class function SelectAll: string; static;
    class function SelectJournal: string; static; overload;
    class function SelectJournal(
      const AFilter: TStartMarkJournalFilter): string; static; overload;
    class procedure BindJournalParameters(Q: TSQLQuery;
      const AFilter: TStartMarkJournalFilter;
      const AReceivedSince: TDateTime;
      const AStageIndex: integer); static;
    class function SelectWorkQueue: string; static;
    class function ExecInsert(Q: TSQLQuery;
      const AMark: TStartMark): TStartMark; static;
    class procedure ExecUpdate(Q: TSQLQuery;
      const AMark: TStartMark); static;
    class function TryReadCurrent(Q: TSQLQuery;
      out AMark: TStartMark): boolean; static;
  end;

  { TStartMarkRepository }

  TStartMarkRepository = class
  private
    FContext: TCompetitionDbContext;
  public
    constructor Create(const AContext: TCompetitionDbContext);
    function Insert(const AMark: TStartMark): TStartMark;
    function TryLoadById(const AMarkId: int64;
      out AMark: TStartMark): boolean;
    function HideWorkQueue: integer;
    procedure Update(const AMark: TStartMark);
    function LoadAll: TStartMarkArray;
  end;

implementation

uses
  DB, DateUtils, TimingMark;

function TwoDigits(const AValue: word): string;
begin
  Result := Format('%.2d', [AValue]);
end;

function ThreeDigits(const AValue: word): string;
begin
  Result := Format('%.3d', [AValue]);
end;

function FourDigits(const AValue: word): string;
begin
  Result := Format('%.4d', [AValue]);
end;

function EventTimeText(const AValue: TDateTime): string;
var
  Hour, Minute, Second, Millisecond: word;
begin
  DecodeTime(AValue, Hour, Minute, Second, Millisecond);
  Result := TwoDigits(Hour) + ':' + TwoDigits(Minute) + ':' +
    TwoDigits(Second) + '.' + ThreeDigits(Millisecond);
end;

function TimestampText(const AValue: TDateTime): string;
var
  Year, Month, Day, Hour, Minute, Second, Millisecond: word;
begin
  DecodeDateTime(AValue, Year, Month, Day, Hour, Minute, Second,
    Millisecond);
  Result := FourDigits(Year) + '-' + TwoDigits(Month) + '-' +
    TwoDigits(Day) + 'T' + TwoDigits(Hour) + ':' + TwoDigits(Minute) +
    ':' + TwoDigits(Second) + '.' + ThreeDigits(Millisecond);
end;

function ParseDigits(const AText, AFieldName: string;
  const AStart, ACount: integer): word;
var
  I, Value: integer;
begin
  Value := 0;
  for I := AStart to AStart + ACount - 1 do
  begin
    if (I > Length(AText)) or not (AText[I] in ['0'..'9']) then
      raise EDatabaseError.CreateFmt(
        'Invalid %s value "%s" in start_marks.', [AFieldName, AText]);
    Value := Value * 10 + Ord(AText[I]) - Ord('0');
  end;
  Result := Value;
end;

procedure RequireSeparator(const AText, AFieldName: string;
  const APosition: integer; const ASeparator: char);
begin
  if (APosition > Length(AText)) or (AText[APosition] <> ASeparator) then
    raise EDatabaseError.CreateFmt(
      'Invalid %s value "%s" in start_marks.', [AFieldName, AText]);
end;

function ParseEventTime(const AText: string): TDateTime;
var
  Hour, Minute, Second, Millisecond: word;
begin
  if Length(AText) <> 12 then
    raise EDatabaseError.CreateFmt(
      'Invalid event_time value "%s" in start_marks.', [AText]);
  RequireSeparator(AText, 'event_time', 3, ':');
  RequireSeparator(AText, 'event_time', 6, ':');
  RequireSeparator(AText, 'event_time', 9, '.');
  Hour := ParseDigits(AText, 'event_time', 1, 2);
  Minute := ParseDigits(AText, 'event_time', 4, 2);
  Second := ParseDigits(AText, 'event_time', 7, 2);
  Millisecond := ParseDigits(AText, 'event_time', 10, 3);
  if not TryEncodeTime(Hour, Minute, Second, Millisecond, Result) then
    raise EDatabaseError.CreateFmt(
      'Invalid event_time value "%s" in start_marks.', [AText]);
end;

function ParseTimestamp(const AText, AFieldName: string): TDateTime;
var
  DatePart, TimePart: TDateTime;
  Year, Month, Day, Hour, Minute, Second, Millisecond: word;
begin
  if Length(AText) <> 23 then
    raise EDatabaseError.CreateFmt(
      'Invalid %s value "%s" in start_marks.', [AFieldName, AText]);
  RequireSeparator(AText, AFieldName, 5, '-');
  RequireSeparator(AText, AFieldName, 8, '-');
  RequireSeparator(AText, AFieldName, 11, 'T');
  RequireSeparator(AText, AFieldName, 14, ':');
  RequireSeparator(AText, AFieldName, 17, ':');
  RequireSeparator(AText, AFieldName, 20, '.');
  Year := ParseDigits(AText, AFieldName, 1, 4);
  Month := ParseDigits(AText, AFieldName, 6, 2);
  Day := ParseDigits(AText, AFieldName, 9, 2);
  Hour := ParseDigits(AText, AFieldName, 12, 2);
  Minute := ParseDigits(AText, AFieldName, 15, 2);
  Second := ParseDigits(AText, AFieldName, 18, 2);
  Millisecond := ParseDigits(AText, AFieldName, 21, 3);
  if not TryEncodeDate(Year, Month, Day, DatePart) or
    not TryEncodeTime(Hour, Minute, Second, Millisecond, TimePart) then
    raise EDatabaseError.CreateFmt(
      'Invalid %s value "%s" in start_marks.', [AFieldName, AText]);
  Result := DatePart + TimePart;
end;

function SourceKindText(const AKind: TTimingMarkSourceKind): string;
begin
  case AKind of
    tmskSerial: Result := 'serial';
    tmskBle: Result := 'ble';
    tmskManual:
      raise EArgumentException.Create(
        'A start mark source must be serial or BLE.');
  end;
end;

function SourceFromFields(Q: TSQLQuery): TTimingMarkSource;
var
  DeviceId, KindText: string;
begin
  KindText := Q.FieldByName('source_kind').AsString;
  DeviceId := Q.FieldByName('source_device_id').AsString;
  if KindText = 'serial' then
    Exit(TTimingMarkSource.Serial(DeviceId));
  if KindText = 'ble' then
    Exit(TTimingMarkSource.Ble(DeviceId));
  raise EDatabaseError.CreateFmt(
    'Invalid source_kind value "%s" in start_marks.', [KindText]);
end;

function AssignmentModeText(const AMode: TStartMarkAssignmentMode): string;
begin
  case AMode of
    smamManual: Result := 'manual';
    smamAutomatic: Result := 'automatic';
  end;
end;

function ParseAssignmentMode(const AText: string): TStartMarkAssignmentMode;
begin
  if AText = 'manual' then
    Exit(smamManual);
  if AText = 'automatic' then
    Exit(smamAutomatic);
  raise EDatabaseError.CreateFmt(
    'Invalid assignment_mode value "%s" in start_marks.', [AText]);
end;

function ParseStatus(const AText: string): TStartMarkStatus;
begin
  if AText = 'pending' then
    Exit(smsPending);
  if AText = 'applied' then
    Exit(smsApplied);
  if AText = 'hidden' then
    Exit(smsHidden);
  if AText = 'conflict' then
    Exit(smsConflict);
  if AText = 'error' then
    Exit(smsError);
  raise EDatabaseError.CreateFmt(
    'Invalid status value "%s" in start_marks.', [AText]);
end;

procedure BindOptionalInteger(Q: TSQLQuery; const AParameterName: string;
  const AHasValue: boolean; const AValue: integer);
begin
  if AHasValue then
    Q.ParamByName(AParameterName).AsInteger := AValue
  else
    Q.ParamByName(AParameterName).Clear;
end;

procedure BindMutableFields(Q: TSQLQuery; const AMark: TStartMark);
begin
  BindOptionalInteger(Q, 'APPLIED_STAGE_INDEX', AMark.HasAppliedStageIndex,
    AMark.AppliedStageIndex);
  BindOptionalInteger(Q, 'PARTICIPANT_NUMBER', AMark.HasParticipantNumber,
    AMark.ParticipantNumber);
  BindOptionalInteger(Q, 'MATCH_DELTA_MS', AMark.HasMatchDeltaMs,
    AMark.MatchDeltaMs);
  if AMark.HasAssignmentMode then
    Q.ParamByName('ASSIGNMENT_MODE').AsString :=
      AssignmentModeText(AMark.AssignmentMode)
  else
    Q.ParamByName('ASSIGNMENT_MODE').Clear;
  Q.ParamByName('STATUS').AsString := StartMarkStatusCode(AMark.Status);
  if AMark.HasAppliedAt then
    Q.ParamByName('APPLIED_AT').AsString := TimestampText(AMark.AppliedAt)
  else
    Q.ParamByName('APPLIED_AT').Clear;
  if AMark.Diagnostic <> '' then
    Q.ParamByName('DIAGNOSTIC').AsString := AMark.Diagnostic
  else
    Q.ParamByName('DIAGNOSTIC').Clear;
end;

class function TStartMarkSql.InsertStatement: string;
begin
  Result :=
    'INSERT INTO start_marks (' +
    'stage_index, applied_stage_index, event_time, correction_ms, ' +
    'participant_number, match_delta_ms, source_kind, source_device_id, received_at, ' +
    'assignment_mode, status, applied_at, diagnostic) VALUES (' +
    ':STAGE_INDEX, :APPLIED_STAGE_INDEX, :EVENT_TIME, :CORRECTION_MS, ' +
    ':PARTICIPANT_NUMBER, :MATCH_DELTA_MS, :SOURCE_KIND, :SOURCE_DEVICE_ID, :RECEIVED_AT, ' +
    ':ASSIGNMENT_MODE, :STATUS, :APPLIED_AT, :DIAGNOSTIC);';
end;

class function TStartMarkSql.UpdateStatement: string;
begin
  Result :=
    'UPDATE start_marks SET ' +
    'applied_stage_index = :APPLIED_STAGE_INDEX, ' +
    'participant_number = :PARTICIPANT_NUMBER, ' +
    'match_delta_ms = :MATCH_DELTA_MS, ' +
    'assignment_mode = :ASSIGNMENT_MODE, status = :STATUS, ' +
    'applied_at = :APPLIED_AT, diagnostic = :DIAGNOSTIC ' +
    'WHERE id = :ID;';
end;

class function TStartMarkSql.SelectAll: string;
begin
  Result := 'SELECT * FROM start_marks ORDER BY received_at, id;';
end;

class function TStartMarkSql.SelectJournal: string;
begin
  Result := SelectJournal(smjfAll);
end;

class function TStartMarkSql.SelectJournal(
  const AFilter: TStartMarkJournalFilter): string;
begin
  Result := 'SELECT * FROM start_marks';
  case AFilter of
    smjfAll: ;
    smjfPending: Result := Result + ' WHERE status = ''pending''';
    smjfApplied: Result := Result + ' WHERE status = ''applied''';
    smjfHidden: Result := Result + ' WHERE status = ''hidden''';
    smjfConflictOrError:
      Result := Result + ' WHERE status IN (''conflict'', ''error'')';
    smjfLast15Minutes:
      Result := Result + ' WHERE received_at >= :RECEIVED_SINCE';
    smjfCurrentStage:
      Result := Result + ' WHERE stage_index = :STAGE_INDEX';
  end;
  Result := Result + ' ORDER BY received_at DESC, id DESC;';
end;

class procedure TStartMarkSql.BindJournalParameters(Q: TSQLQuery;
  const AFilter: TStartMarkJournalFilter; const AReceivedSince: TDateTime;
  const AStageIndex: integer);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  case AFilter of
    smjfLast15Minutes:
      Q.ParamByName('RECEIVED_SINCE').AsString :=
        TimestampText(AReceivedSince);
    smjfCurrentStage:
      begin
        if AStageIndex < 1 then
          raise EArgumentOutOfRangeException.Create(
            'Stage index must be positive.');
        Q.ParamByName('STAGE_INDEX').AsInteger := AStageIndex;
      end;
  end;
end;

class function TStartMarkSql.SelectWorkQueue: string;
begin
  Result :=
    'SELECT id, event_time, correction_ms, participant_number ' +
    'FROM start_marks WHERE status IN (''pending'', ''conflict'') ' +
    'ORDER BY received_at, id;';
end;

class function TStartMarkSql.ExecInsert(Q: TSQLQuery;
  const AMark: TStartMark): TStartMark;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if AMark.Id <> 0 then
    raise EArgumentException.Create(
      'A new start mark must not already have an ID.');
  Q.Close;
  Q.SQL.Text := InsertStatement;
  Q.ParamByName('STAGE_INDEX').AsInteger := AMark.StageIndex;
  Q.ParamByName('EVENT_TIME').AsString := EventTimeText(AMark.EventTime);
  BindOptionalInteger(Q, 'CORRECTION_MS', AMark.HasCorrection,
    AMark.CorrectionMs);
  Q.ParamByName('SOURCE_KIND').AsString := SourceKindText(AMark.Source.Kind);
  Q.ParamByName('SOURCE_DEVICE_ID').AsString := AMark.Source.DeviceId;
  Q.ParamByName('RECEIVED_AT').AsString := TimestampText(AMark.ReceivedAt);
  BindMutableFields(Q, AMark);
  Q.ExecSQL;
  Q.Close;

  Q.SQL.Text := 'SELECT last_insert_rowid() AS id;';
  Q.Open;
  try
    Result := AMark;
    Result.Id := Q.FieldByName('id').AsLargeInt;
  finally
    Q.Close;
  end;
end;

class procedure TStartMarkSql.ExecUpdate(Q: TSQLQuery;
  const AMark: TStartMark);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if AMark.Id < 1 then
    raise EArgumentException.Create(
      'A persisted start mark must have a positive ID.');
  Q.Close;
  Q.SQL.Text := UpdateStatement;
  BindMutableFields(Q, AMark);
  Q.ParamByName('ID').AsLargeInt := AMark.Id;
  Q.ExecSQL;
  if Q.RowsAffected <> 1 then
    raise EDatabaseError.CreateFmt(
      'Start mark %d was not found for update.', [AMark.Id]);
  Q.Close;
end;

class function TStartMarkSql.TryReadCurrent(Q: TSQLQuery;
  out AMark: TStartMark): boolean;
begin
  AMark := Default(TStartMark);
  Result := Assigned(Q) and Q.Active and not Q.EOF;
  if not Result then
    Exit;

  AMark.Id := Q.FieldByName('id').AsLargeInt;
  AMark.StageIndex := Q.FieldByName('stage_index').AsInteger;
  AMark.HasAppliedStageIndex :=
    not Q.FieldByName('applied_stage_index').IsNull;
  if AMark.HasAppliedStageIndex then
    AMark.AppliedStageIndex :=
      Q.FieldByName('applied_stage_index').AsInteger;
  AMark.EventTime := ParseEventTime(Q.FieldByName('event_time').AsString);
  AMark.HasCorrection := not Q.FieldByName('correction_ms').IsNull;
  if AMark.HasCorrection then
    AMark.CorrectionMs := Q.FieldByName('correction_ms').AsInteger;
  AMark.HasParticipantNumber :=
    not Q.FieldByName('participant_number').IsNull;
  if AMark.HasParticipantNumber then
    AMark.ParticipantNumber :=
      Q.FieldByName('participant_number').AsInteger;
  AMark.HasMatchDeltaMs := not Q.FieldByName('match_delta_ms').IsNull;
  if AMark.HasMatchDeltaMs then
    AMark.MatchDeltaMs := Q.FieldByName('match_delta_ms').AsInteger;
  AMark.Source := SourceFromFields(Q);
  AMark.ReceivedAt := ParseTimestamp(
    Q.FieldByName('received_at').AsString, 'received_at');
  AMark.HasAssignmentMode := not Q.FieldByName('assignment_mode').IsNull;
  if AMark.HasAssignmentMode then
    AMark.AssignmentMode := ParseAssignmentMode(
      Q.FieldByName('assignment_mode').AsString);
  AMark.Status := ParseStatus(Q.FieldByName('status').AsString);
  AMark.HasAppliedAt := not Q.FieldByName('applied_at').IsNull;
  if AMark.HasAppliedAt then
    AMark.AppliedAt := ParseTimestamp(
      Q.FieldByName('applied_at').AsString, 'applied_at');
  if not Q.FieldByName('diagnostic').IsNull then
    AMark.Diagnostic := Q.FieldByName('diagnostic').AsString;
end;

constructor TStartMarkRepository.Create(
  const AContext: TCompetitionDbContext);
begin
  inherited Create;
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  FContext := AContext;
end;

function TStartMarkRepository.Insert(
  const AMark: TStartMark): TStartMark;
var
  Q: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Q := FContext.CreateQuery(nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    Result := TStartMarkSql.ExecInsert(Q, AMark);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Q.Free;
  end;
end;

function TStartMarkRepository.TryLoadById(const AMarkId: int64;
  out AMark: TStartMark): boolean;
var
  Q: TSQLQuery;
begin
  AMark := Default(TStartMark);
  if AMarkId < 1 then
    Exit(False);
  Q := FContext.CreateQuery(nil);
  try
    Q.SQL.Text := 'SELECT * FROM start_marks WHERE id = :ID;';
    Q.ParamByName('ID').AsLargeInt := AMarkId;
    Q.Open;
    Result := TStartMarkSql.TryReadCurrent(Q, AMark);
  finally
    Q.Free;
  end;
end;

function TStartMarkRepository.HideWorkQueue: integer;
var
  Q: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Q := FContext.CreateQuery(nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    Q.SQL.Text :=
      'UPDATE start_marks SET status = ''hidden'' ' +
      'WHERE status IN (''pending'', ''conflict'');';
    Q.ExecSQL;
    Result := Q.RowsAffected;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Q.Free;
  end;
end;

procedure TStartMarkRepository.Update(const AMark: TStartMark);
var
  Q: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Q := FContext.CreateQuery(nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    TStartMarkSql.ExecUpdate(Q, AMark);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Q.Free;
  end;
end;

function TStartMarkRepository.LoadAll: TStartMarkArray;
var
  Mark: TStartMark;
  Q: TSQLQuery;
begin
  Result := nil;
  Q := FContext.CreateQuery(nil);
  try
    Q.SQL.Text := TStartMarkSql.SelectAll;
    Q.Open;
    while TStartMarkSql.TryReadCurrent(Q, Mark) do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Mark;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

end.
