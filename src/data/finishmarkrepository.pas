unit FinishMarkRepository;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, SQLDB, CompetitionDbContext, FinishMark;

type
  TFinishMarkArray = array of TFinishMark;
  TFinishMarkJournalFilter = (fmjfAll, fmjfPending, fmjfApplied,
    fmjfIgnoredDebounce, fmjfHidden, fmjfError, fmjfLast15Minutes,
    fmjfCurrentStage);

  TFinishMarkSql = record
  private
    class function InsertStatement: string; static;
    class function UpdateStatement: string; static;
  public
    class function SelectAll: string; static;
    class function SelectJournal: string; static; overload;
    class function SelectJournal(const AFilter: TFinishMarkJournalFilter;
      const AStageIndex: integer = 0): string; static; overload;
    class procedure BindJournalParameters(Q: TSQLQuery;
      const AFilter: TFinishMarkJournalFilter; const AReceivedSince: TDateTime;
      const AStageIndex: integer); static;
    class function SelectWorkQueue: string; static;
    class function ExecInsert(Q: TSQLQuery;
      const AMark: TFinishMark): TFinishMark; static;
    class procedure ExecUpdate(Q: TSQLQuery; const AMark: TFinishMark); static;
    class function TryReadCurrent(Q: TSQLQuery; out AMark: TFinishMark): boolean;
      static;
  end;

  TFinishMarkRepository = class
  private
    FContext: TCompetitionDbContext;
  public
    constructor Create(const AContext: TCompetitionDbContext);
    function Insert(const AMark: TFinishMark): TFinishMark;
    function TryLoadById(const AMarkId: int64; out AMark: TFinishMark): boolean;
    function HideWorkQueue: integer;
    procedure Update(const AMark: TFinishMark);
    function LoadAll: TFinishMarkArray;
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
        'Invalid %s value "%s" in finish_marks.', [AFieldName, AText]);
    Value := Value * 10 + Ord(AText[I]) - Ord('0');
  end;
  Result := Value;
end;

procedure RequireSeparator(const AText, AFieldName: string;
  const APosition: integer; const ASeparator: char);
begin
  if (APosition > Length(AText)) or (AText[APosition] <> ASeparator) then
    raise EDatabaseError.CreateFmt('Invalid %s value "%s" in finish_marks.',
      [AFieldName, AText]);
end;

function ParseEventTime(const AText: string): TDateTime;
var
  Hour, Minute, Second, Millisecond: word;
begin
  if Length(AText) <> 12 then
    raise EDatabaseError.CreateFmt(
      'Invalid event_time value "%s" in finish_marks.', [AText]);
  RequireSeparator(AText, 'event_time', 3, ':');
  RequireSeparator(AText, 'event_time', 6, ':');
  RequireSeparator(AText, 'event_time', 9, '.');
  Hour := ParseDigits(AText, 'event_time', 1, 2);
  Minute := ParseDigits(AText, 'event_time', 4, 2);
  Second := ParseDigits(AText, 'event_time', 7, 2);
  Millisecond := ParseDigits(AText, 'event_time', 10, 3);
  if not TryEncodeTime(Hour, Minute, Second, Millisecond, Result) then
    raise EDatabaseError.CreateFmt(
      'Invalid event_time value "%s" in finish_marks.', [AText]);
end;

function ParseTimestamp(const AText, AFieldName: string): TDateTime;
var
  DatePart, TimePart: TDateTime;
  Year, Month, Day, Hour, Minute, Second, Millisecond: word;
begin
  if Length(AText) <> 23 then
    raise EDatabaseError.CreateFmt('Invalid %s value "%s" in finish_marks.',
      [AFieldName, AText]);
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
  if not TryEncodeDate(Year, Month, Day, DatePart) or not
    TryEncodeTime(Hour, Minute, Second, Millisecond, TimePart) then
    raise EDatabaseError.CreateFmt('Invalid %s value "%s" in finish_marks.',
      [AFieldName, AText]);
  Result := DatePart + TimePart;
end;

function SourceKindText(const AKind: TTimingMarkSourceKind): string;
begin
  case AKind of
    tmskSerial: Result := 'serial';
    tmskBle: Result := 'ble';
    tmskManual: Result := 'manual';
  end;
end;

function SourceFromFields(Q: TSQLQuery): TTimingMarkSource;
var
  KindText: string;
begin
  KindText := Q.FieldByName('source_kind').AsString;
  if KindText = 'serial' then
    Exit(TTimingMarkSource.Serial(Q.FieldByName('source_device_id').AsString));
  if KindText = 'ble' then
    Exit(TTimingMarkSource.Ble(Q.FieldByName('source_device_id').AsString));
  if KindText = 'manual' then
    Exit(TTimingMarkSource.Manual);
  raise EDatabaseError.CreateFmt('Invalid source_kind value "%s" in finish_marks.',
    [KindText]);
end;

function ParseStatus(const AText: string): TFinishMarkStatus;
begin
  if AText = 'pending' then Exit(fmsPending);
  if AText = 'applied' then Exit(fmsApplied);
  if AText = 'ignored_debounce' then Exit(fmsIgnoredDebounce);
  if AText = 'hidden' then Exit(fmsHidden);
  if AText = 'error' then Exit(fmsError);
  raise EDatabaseError.CreateFmt(
    'Invalid status value "%s" in finish_marks.', [AText]);
end;

procedure BindMutableFields(Q: TSQLQuery; const AMark: TFinishMark);
begin
  if AMark.HasParticipantNumber then
    Q.ParamByName('PARTICIPANT_NUMBER').AsInteger :=
      AMark.ParticipantNumber
  else
    Q.ParamByName('PARTICIPANT_NUMBER').Clear;
  if AMark.HasAssignmentMode then
    Q.ParamByName('ASSIGNMENT_MODE').AsString := 'manual'
  else
    Q.ParamByName('ASSIGNMENT_MODE').Clear;
  Q.ParamByName('STATUS').AsString := FinishMarkStatusCode(AMark.Status);
  if AMark.HasAppliedAt then
    Q.ParamByName('APPLIED_AT').AsString := TimestampText(AMark.AppliedAt)
  else
    Q.ParamByName('APPLIED_AT').Clear;
  if AMark.Diagnostic <> '' then
    Q.ParamByName('DIAGNOSTIC').AsString := AMark.Diagnostic
  else
    Q.ParamByName('DIAGNOSTIC').Clear;
end;

class function TFinishMarkSql.InsertStatement: string;
begin
  Result :=
    'INSERT INTO finish_marks (' +
    'stage_index, event_time, participant_number, source_kind, ' +
    'source_device_id, received_at, assignment_mode, status, applied_at, ' +
    'diagnostic) VALUES (' +
    ':STAGE_INDEX, :EVENT_TIME, :PARTICIPANT_NUMBER, :SOURCE_KIND, ' +
    ':SOURCE_DEVICE_ID, :RECEIVED_AT, :ASSIGNMENT_MODE, :STATUS, ' +
    ':APPLIED_AT, :DIAGNOSTIC);';
end;

class function TFinishMarkSql.UpdateStatement: string;
begin
  Result :=
    'UPDATE finish_marks SET participant_number = :PARTICIPANT_NUMBER, ' +
    'assignment_mode = :ASSIGNMENT_MODE, status = :STATUS, ' +
    'applied_at = :APPLIED_AT, diagnostic = :DIAGNOSTIC WHERE id = :ID;';
end;

class function TFinishMarkSql.SelectAll: string;
begin
  Result := 'SELECT * FROM finish_marks ORDER BY received_at, id;';
end;

class function TFinishMarkSql.SelectJournal: string;
begin
  Result := SelectJournal(fmjfAll);
end;

class function TFinishMarkSql.SelectJournal(const AFilter: TFinishMarkJournalFilter;
  const AStageIndex: integer): string;
begin
  if AStageIndex < 0 then
    raise EArgumentOutOfRangeException.Create('Stage index must not be negative.');
  Result := 'SELECT * FROM finish_marks';
  case AFilter of
    fmjfAll: ;
    fmjfPending: Result := Result + ' WHERE status = ''pending''';
    fmjfApplied: Result := Result + ' WHERE status = ''applied''';
    fmjfIgnoredDebounce:
      Result := Result + ' WHERE status = ''ignored_debounce''';
    fmjfHidden: Result := Result + ' WHERE status = ''hidden''';
    fmjfError: Result := Result + ' WHERE status = ''error''';
    fmjfLast15Minutes:
      Result := Result + ' WHERE received_at >= :RECEIVED_SINCE';
    fmjfCurrentStage:
      Result := Result + ' WHERE stage_index = :STAGE_INDEX';
  end;
  if (AStageIndex > 0) and (AFilter <> fmjfCurrentStage) then
  begin
    if AFilter = fmjfAll then Result := Result + ' WHERE '
    else
      Result := Result + ' AND ';
    Result := Result + 'stage_index = :STAGE_INDEX';
  end;
  Result := Result + ' ORDER BY received_at DESC, id DESC;';
end;

class procedure TFinishMarkSql.BindJournalParameters(Q: TSQLQuery;
  const AFilter: TFinishMarkJournalFilter; const AReceivedSince: TDateTime;
  const AStageIndex: integer);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if (AStageIndex < 0) or ((AFilter = fmjfCurrentStage) and (AStageIndex = 0)) then
    raise EArgumentOutOfRangeException.Create('Invalid stage scope.');
  if AFilter = fmjfLast15Minutes then
    Q.ParamByName('RECEIVED_SINCE').AsString := TimestampText(AReceivedSince);
  if AStageIndex > 0 then
    Q.ParamByName('STAGE_INDEX').AsInteger := AStageIndex;
end;

class function TFinishMarkSql.SelectWorkQueue: string;
begin
  Result :=
    'SELECT id, event_time, participant_number FROM finish_marks ' +
    'WHERE status = ''pending'' ORDER BY received_at, id;';
end;

class function TFinishMarkSql.ExecInsert(Q: TSQLQuery;
  const AMark: TFinishMark): TFinishMark;
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if AMark.Id <> 0 then
    raise EArgumentException.Create(
      'A new finish mark must not already have an ID.');
  Q.Close;
  Q.SQL.Text := InsertStatement;
  Q.ParamByName('STAGE_INDEX').AsInteger := AMark.StageIndex;
  Q.ParamByName('EVENT_TIME').AsString := EventTimeText(AMark.EventTime);
  Q.ParamByName('SOURCE_KIND').AsString := SourceKindText(AMark.Source.Kind);
  if AMark.Source.Kind = tmskManual then
    Q.ParamByName('SOURCE_DEVICE_ID').Clear
  else
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

class procedure TFinishMarkSql.ExecUpdate(Q: TSQLQuery; const AMark: TFinishMark);
begin
  if Q = nil then
    raise EArgumentNilException.Create('Q');
  if AMark.Id < 1 then
    raise EArgumentException.Create(
      'A persisted finish mark must have a positive ID.');
  Q.Close;
  Q.SQL.Text := UpdateStatement;
  BindMutableFields(Q, AMark);
  Q.ParamByName('ID').AsLargeInt := AMark.Id;
  Q.ExecSQL;
  if Q.RowsAffected <> 1 then
    raise EDatabaseError.CreateFmt('Finish mark %d was not found for update.',
      [AMark.Id]);
  Q.Close;
end;

class function TFinishMarkSql.TryReadCurrent(Q: TSQLQuery;
  out AMark: TFinishMark): boolean;
begin
  AMark := Default(TFinishMark);
  Result := Assigned(Q) and Q.Active and not Q.EOF;
  if not Result then
    Exit;
  AMark.Id := Q.FieldByName('id').AsLargeInt;
  AMark.StageIndex := Q.FieldByName('stage_index').AsInteger;
  AMark.EventTime := ParseEventTime(Q.FieldByName('event_time').AsString);
  AMark.HasParticipantNumber := not Q.FieldByName('participant_number').IsNull;
  if AMark.HasParticipantNumber then
    AMark.ParticipantNumber :=
      Q.FieldByName('participant_number').AsInteger;
  AMark.Source := SourceFromFields(Q);
  AMark.ReceivedAt := ParseTimestamp(Q.FieldByName('received_at').AsString,
    'received_at');
  AMark.HasAssignmentMode := not Q.FieldByName('assignment_mode').IsNull;
  if AMark.HasAssignmentMode then
  begin
    if Q.FieldByName('assignment_mode').AsString <> 'manual' then
      raise EDatabaseError.CreateFmt(
        'Invalid assignment_mode value "%s" in finish_marks.',
        [Q.FieldByName('assignment_mode').AsString]);
    AMark.AssignmentMode := fmamManual;
  end;
  AMark.Status := ParseStatus(Q.FieldByName('status').AsString);
  AMark.HasAppliedAt := not Q.FieldByName('applied_at').IsNull;
  if AMark.HasAppliedAt then
    AMark.AppliedAt := ParseTimestamp(Q.FieldByName('applied_at').AsString,
      'applied_at');
  if not Q.FieldByName('diagnostic').IsNull then
    AMark.Diagnostic := Q.FieldByName('diagnostic').AsString;
end;

constructor TFinishMarkRepository.Create(const AContext: TCompetitionDbContext);
begin
  inherited Create;
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  FContext := AContext;
end;

function TFinishMarkRepository.Insert(const AMark: TFinishMark): TFinishMark;
var
  Q: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Q := FContext.CreateQuery(nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    Result := TFinishMarkSql.ExecInsert(Q, AMark);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Q.Free;
  end;
end;

function TFinishMarkRepository.TryLoadById(const AMarkId: int64;
  out AMark: TFinishMark): boolean;
var
  Q: TSQLQuery;
begin
  AMark := Default(TFinishMark);
  if AMarkId < 1 then
    Exit(False);
  Q := FContext.CreateQuery(nil);
  try
    Q.SQL.Text := 'SELECT * FROM finish_marks WHERE id = :ID;';
    Q.ParamByName('ID').AsLargeInt := AMarkId;
    Q.Open;
    Result := TFinishMarkSql.TryReadCurrent(Q, AMark);
  finally
    Q.Free;
  end;
end;

function TFinishMarkRepository.HideWorkQueue: integer;
var
  Q: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Q := FContext.CreateQuery(nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    Q.SQL.Text :=
      'UPDATE finish_marks SET status = ''hidden'' ' +
      'WHERE status = ''pending'';';
    Q.ExecSQL;
    Result := Q.RowsAffected;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Q.Free;
  end;
end;

procedure TFinishMarkRepository.Update(const AMark: TFinishMark);
var
  Q: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Q := FContext.CreateQuery(nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    TFinishMarkSql.ExecUpdate(Q, AMark);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
    Q.Free;
  end;
end;

function TFinishMarkRepository.LoadAll: TFinishMarkArray;
var
  Mark: TFinishMark;
  Q: TSQLQuery;
begin
  Result := nil;
  Q := FContext.CreateQuery(nil);
  try
    Q.SQL.Text := TFinishMarkSql.SelectAll;
    Q.Open;
    while TFinishMarkSql.TryReadCurrent(Q, Mark) do
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
