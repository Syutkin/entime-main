unit StartMarkRepositoryTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, DB, FPCUnit, TestRegistry, SQLDB, CompetitionDbContext,
  CompetitionSchemaMigrator, TimingMark, StartMark, StartMarkRepository,
  CompetitionQueryProvider;

type
  { TStartMarkRepositoryTests }

  TStartMarkRepositoryTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FQuery: TSQLQuery;
    FRepository: TStartMarkRepository;
    function PendingMark(const AEventTime, AReceivedAt: TDateTime;
      const AHasCorrection: boolean = True): TStartMark;
    procedure CreateSchema;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure InsertAndLoadAll_PreserveCompleteAppliedMark;
    procedure InsertAndLoadAll_PreserveNullablePendingFields;
    procedure LoadAll_OrdersByReceiptThenId;
    procedure Update_PersistsMutableStateWithoutChangingReceivedStage;
    procedure HideWorkQueue_HidesPendingAndConflictOnly;
    procedure SelectWorkQueue_ReturnsOnlyUnappliedMarksInReceiptOrder;
    procedure SelectJournal_ReturnsEveryStatusNewestFirst;
    procedure SelectJournal_FiltersByStatusTimeAndReceivedStage;
    procedure SelectJournal_CombinesReceivedStageWithEveryStateFilter;
    procedure SelectJournal_RejectsNegativeStageScope;
  end;

implementation

procedure TStartMarkRepositoryTests.SetUp;
begin
  inherited SetUp;
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FQuery := FContext.CreateQuery(nil);
  CreateSchema;
  FRepository := TStartMarkRepository.Create(FContext);
end;

procedure TStartMarkRepositoryTests.TearDown;
begin
  FRepository.Free;
  FQuery.Free;
  FContext.Free;
  inherited TearDown;
end;

procedure TStartMarkRepositoryTests.CreateSchema;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, 2,
      'A', 'B', 'C', 'D', 'E', 'Repository test');
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
end;

function TStartMarkRepositoryTests.PendingMark(const AEventTime, AReceivedAt: TDateTime;
  const AHasCorrection: boolean): TStartMark;
begin
  Result := TStartMark.FromTimingMark(TTimingMark.Start(AEventTime,
    AHasCorrection, 0, TTimingMarkSource.Serial('COM7'), AReceivedAt), 2);
end;

procedure TStartMarkRepositoryTests.
InsertAndLoadAll_PreserveCompleteAppliedMark;
var
  AppliedAt: TDateTime;
  Inserted: TStartMark;
  Marks: TStartMarkArray;
  Mark: TStartMark;
begin
  AppliedAt := EncodeDateTime(2026, 8, 13, 10, 0, 3, 456);
  Mark := TStartMark.FromTimingMark(TTimingMark.Start(
    EncodeTime(9, 59, 58, 123), True, -27, TTimingMarkSource.Ble('ENTime-3'),
    EncodeDateTime(2026, 8, 13, 10, 0, 0, 321)), 2);
  Mark.HasMatchDeltaMs := True;
  Mark.MatchDeltaMs := 1877;
  AssertTrue(Mark.TryApply(17, 4, smamManual, AppliedAt));

  Inserted := FRepository.Insert(Mark);
  Marks := FRepository.LoadAll;

  AssertTrue(Inserted.Id > 0);
  AssertEquals(1, Length(Marks));
  AssertEquals(Inserted.Id, Marks[0].Id);
  AssertEquals(2, Marks[0].StageIndex);
  AssertTrue(Marks[0].HasAppliedStageIndex);
  AssertEquals(4, Marks[0].AppliedStageIndex);
  AssertEquals(Mark.EventTime, Marks[0].EventTime);
  AssertTrue(Marks[0].HasCorrection);
  AssertEquals(-27, Marks[0].CorrectionMs);
  AssertTrue(Marks[0].HasParticipantNumber);
  AssertEquals(17, Marks[0].ParticipantNumber);
  AssertTrue(Marks[0].HasMatchDeltaMs);
  AssertEquals(1877, Marks[0].MatchDeltaMs);
  AssertEquals(Ord(tmskBle), Ord(Marks[0].Source.Kind));
  AssertEquals('ENTime-3', Marks[0].Source.DeviceId);
  AssertEquals(Mark.ReceivedAt, Marks[0].ReceivedAt);
  AssertTrue(Marks[0].HasAssignmentMode);
  AssertEquals(Ord(smamManual), Ord(Marks[0].AssignmentMode));
  AssertEquals(Ord(smsApplied), Ord(Marks[0].Status));
  AssertTrue(Marks[0].HasAppliedAt);
  AssertEquals(AppliedAt, Marks[0].AppliedAt);
  AssertEquals('', Marks[0].Diagnostic);
end;

procedure TStartMarkRepositoryTests.
InsertAndLoadAll_PreserveNullablePendingFields;
var
  Inserted: TStartMark;
  Marks: TStartMarkArray;
begin
  Inserted := FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 1, 0), False));

  FQuery.SQL.Text := 'SELECT * FROM start_marks WHERE id = :ID;';
  FQuery.ParamByName('ID').AsLargeInt := Inserted.Id;
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('applied_stage_index').IsNull);
  AssertTrue(FQuery.FieldByName('correction_ms').IsNull);
  AssertTrue(FQuery.FieldByName('participant_number').IsNull);
  AssertTrue(FQuery.FieldByName('match_delta_ms').IsNull);
  AssertTrue(FQuery.FieldByName('assignment_mode').IsNull);
  AssertTrue(FQuery.FieldByName('applied_at').IsNull);
  AssertTrue(FQuery.FieldByName('diagnostic').IsNull);
  FQuery.Close;

  Marks := FRepository.LoadAll;
  AssertEquals(1, Length(Marks));
  AssertFalse(Marks[0].HasAppliedStageIndex);
  AssertFalse(Marks[0].HasCorrection);
  AssertFalse(Marks[0].HasParticipantNumber);
  AssertFalse(Marks[0].HasMatchDeltaMs);
  AssertFalse(Marks[0].HasAssignmentMode);
  AssertFalse(Marks[0].HasAppliedAt);
  AssertEquals('', Marks[0].Diagnostic);
  AssertEquals(Ord(smsPending), Ord(Marks[0].Status));
end;

procedure TStartMarkRepositoryTests.LoadAll_OrdersByReceiptThenId;
var
  FirstTime, SecondTime: TDateTime;
  Marks: TStartMarkArray;
begin
  FirstTime := EncodeDateTime(2026, 8, 13, 10, 0, 1, 0);
  SecondTime := IncSecond(FirstTime);
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0), SecondTime));
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0), FirstTime));
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0), FirstTime));

  Marks := FRepository.LoadAll;

  AssertEquals(3, Length(Marks));
  AssertEquals(EncodeTime(10, 0, 0, 0), Marks[0].EventTime);
  AssertEquals(EncodeTime(10, 0, 1, 0), Marks[1].EventTime);
  AssertEquals(EncodeTime(10, 0, 2, 0), Marks[2].EventTime);
end;

procedure TStartMarkRepositoryTests.
Update_PersistsMutableStateWithoutChangingReceivedStage;
var
  Inserted, Changed: TStartMark;
  Marks: TStartMarkArray;
begin
  Inserted := FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 1, 0)));
  Changed := Inserted;
  Changed.StageIndex := 9;
  Changed.SuggestParticipant(23);
  Changed.MarkConflict('ambiguous');

  FRepository.Update(Changed);
  Marks := FRepository.LoadAll;

  AssertEquals(1, Length(Marks));
  AssertEquals(2, Marks[0].StageIndex);
  AssertTrue(Marks[0].HasParticipantNumber);
  AssertEquals(23, Marks[0].ParticipantNumber);
  AssertEquals(Ord(smsConflict), Ord(Marks[0].Status));
  AssertEquals('ambiguous', Marks[0].Diagnostic);
end;

procedure TStartMarkRepositoryTests.
HideWorkQueue_HidesPendingAndConflictOnly;
var
  Applied, Conflict, Hidden, Pending: TStartMark;
begin
  Pending := FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 1, 0)));
  Conflict := FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 2, 0)));
  Conflict.MarkConflict('ambiguous');
  FRepository.Update(Conflict);
  Hidden := FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 3, 0)));
  Hidden.Hide;
  FRepository.Update(Hidden);
  Applied := FRepository.Insert(PendingMark(EncodeTime(10, 0, 3, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 4, 0)));
  AssertTrue(Applied.TryApply(17, 2, smamManual,
    EncodeDateTime(2026, 8, 13, 10, 0, 5, 0)));
  FRepository.Update(Applied);

  AssertEquals(2, FRepository.HideWorkQueue);
  AssertEquals(0, FRepository.HideWorkQueue);

  FQuery.SQL.Text :=
    'SELECT id, status FROM start_marks ORDER BY id;';
  FQuery.Open;
  AssertEquals(Pending.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('hidden', FQuery.FieldByName('status').AsString);
  FQuery.Next;
  AssertEquals(Conflict.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('hidden', FQuery.FieldByName('status').AsString);
  FQuery.Next;
  AssertEquals(Hidden.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('hidden', FQuery.FieldByName('status').AsString);
  FQuery.Next;
  AssertEquals(Applied.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('applied', FQuery.FieldByName('status').AsString);
end;

procedure TStartMarkRepositoryTests.
SelectWorkQueue_ReturnsOnlyUnappliedMarksInReceiptOrder;
var
  Applied, Hidden, Pending: TStartMark;
begin
  Pending := FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 2, 0)));
  Hidden := FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 3, 0)));
  Hidden.Hide;
  FRepository.Update(Hidden);
  Applied := FRepository.Insert(PendingMark(EncodeTime(10, 0, 3, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 4, 0)));
  AssertTrue(Applied.TryApply(17, 2, smamManual,
    EncodeDateTime(2026, 8, 13, 10, 0, 5, 0)));
  FRepository.Update(Applied);
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 13, 10, 0, 1, 0)));

  FQuery.SQL.Text := TStartMarkSql.SelectWorkQueue;
  FQuery.Open;

  AssertEquals(2, FQuery.RecordCount);
  AssertTrue(FQuery.FieldByName('event_time') is TStringField);
  AssertEquals('10:00:00.000', FQuery.FieldByName('event_time').AsString);
  FQuery.Next;
  AssertEquals(Pending.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('10:00:01.000', FQuery.FieldByName('event_time').AsString);
end;

procedure TStartMarkRepositoryTests.
SelectJournal_ReturnsEveryStatusNewestFirst;
var
  Applied, Conflict, Hidden: TStartMark;
begin
  Hidden := FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 14, 10, 0, 1, 0)));
  Hidden.Hide;
  FRepository.Update(Hidden);
  Applied := FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0),
    EncodeDateTime(2026, 8, 14, 10, 0, 2, 0)));
  AssertTrue(Applied.TryApply(17, 2, smamManual,
    EncodeDateTime(2026, 8, 14, 10, 0, 3, 0)));
  FRepository.Update(Applied);
  Conflict := FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0),
    EncodeDateTime(2026, 8, 14, 10, 0, 4, 0)));
  Conflict.MarkConflict('ambiguous');
  FRepository.Update(Conflict);

  FQuery.SQL.Text := TStartMarkSql.SelectJournal;
  FQuery.Open;

  AssertEquals(Conflict.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('conflict', FQuery.FieldByName('status').AsString);
  FQuery.Next;
  AssertEquals(Applied.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('applied', FQuery.FieldByName('status').AsString);
  FQuery.Next;
  AssertEquals(Hidden.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('hidden', FQuery.FieldByName('status').AsString);
  FQuery.Next;
  AssertTrue(FQuery.EOF);
end;

procedure TStartMarkRepositoryTests.
SelectJournal_FiltersByStatusTimeAndReceivedStage;
var
  Applied, Conflict, ErrorMark, Hidden, Recent: TStartMark;

  procedure AssertFilter(const AFilter: TStartMarkJournalFilter;
  const AExpectedCount: integer; const AReceivedSince: TDateTime;
  const AStageIndex: integer);
  begin
    FQuery.Close;
    FQuery.SQL.Text := TStartMarkSql.SelectJournal(AFilter);
    TStartMarkSql.BindJournalParameters(FQuery, AFilter,
      AReceivedSince, AStageIndex);
    FQuery.Open;
    AssertEquals(AExpectedCount, FQuery.RecordCount);
  end;

begin
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 14, 9, 40, 0, 0)));
  Conflict := FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0),
    EncodeDateTime(2026, 8, 14, 9, 50, 0, 0)));
  Conflict.MarkConflict('ambiguous');
  FRepository.Update(Conflict);
  ErrorMark := FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0),
    EncodeDateTime(2026, 8, 14, 9, 55, 0, 0)));
  ErrorMark.MarkError('failed');
  FRepository.Update(ErrorMark);
  Hidden := FRepository.Insert(PendingMark(EncodeTime(10, 0, 3, 0),
    EncodeDateTime(2026, 8, 14, 9, 56, 0, 0)));
  Hidden.Hide;
  FRepository.Update(Hidden);
  Applied := FRepository.Insert(PendingMark(EncodeTime(10, 0, 4, 0),
    EncodeDateTime(2026, 8, 14, 9, 57, 0, 0)));
  AssertTrue(Applied.TryApply(17, 2, smamManual,
    EncodeDateTime(2026, 8, 14, 9, 58, 0, 0)));
  FRepository.Update(Applied);
  Recent := PendingMark(EncodeTime(10, 0, 5, 0),
    EncodeDateTime(2026, 8, 14, 10, 0, 0, 0));
  Recent.StageIndex := 1;
  FRepository.Insert(Recent);

  AssertFilter(smjfAll, 6, 0, 0);
  AssertFilter(smjfPending, 2, 0, 0);
  AssertFilter(smjfApplied, 1, 0, 0);
  AssertFilter(smjfHidden, 1, 0, 0);
  AssertFilter(smjfConflictOrError, 2, 0, 0);
  AssertFilter(smjfLast15Minutes, 5,
    EncodeDateTime(2026, 8, 14, 9, 45, 0, 0), 0);
  AssertFilter(smjfCurrentStage, 1, 0, 1);
end;

procedure TStartMarkRepositoryTests.
SelectJournal_CombinesReceivedStageWithEveryStateFilter;
const
  EXPECTED: array[TStartMarkJournalFilter] of integer = (5, 1, 1, 1, 2, 5, 5, 2, 1);
var
  Mark: TStartMark;
  Status: TStartMarkStatus;
  StageIndex: integer;
  Filter: TStartMarkJournalFilter;
begin
  for StageIndex := 1 to 2 do
    for Status := Low(TStartMarkStatus) to High(TStartMarkStatus) do
    begin
      Mark := PendingMark(EncodeTime(10, 0, 0, 0),
        EncodeDateTime(2026, 10, 29, 8 + StageIndex, Ord(Status), 0, 0));
      Mark.StageIndex := StageIndex;
      Mark.Status := Status;
      Mark.HasParticipantNumber := True;
      Mark.ParticipantNumber := 17;
      Mark.HasAppliedStageIndex := Status = smsApplied;
      Mark.AppliedStageIndex := 3 - StageIndex;
      FRepository.Insert(Mark);
    end;
  for Filter := Low(TStartMarkJournalFilter) to High(TStartMarkJournalFilter) do
  begin
    TDatasetSql.ConfigureStartMarkJournal(FQuery, Filter,
      EncodeDateTime(2026, 10, 29, 9, 45, 0, 0), 2);
    FQuery.Open;
    AssertEquals('Filter ' + IntToStr(Ord(Filter)), EXPECTED[Filter],
      FQuery.RecordCount);
    while not FQuery.EOF do
    begin
      AssertEquals('Received stage, not applied stage', 2,
        FQuery.FieldByName('stage_index').AsInteger);
      if Filter = smjfError then
        AssertEquals('error', FQuery.FieldByName('status').AsString);
      if Filter = smjfPendingOrConflict then
        AssertTrue(FQuery.FieldByName('status').AsString <> 'error');
      FQuery.Next;
    end;
    FQuery.Close;
  end;
  TDatasetSql.ConfigureStartMarkJournal(FQuery);
  FQuery.Open;
  AssertEquals('Unscoped journal still includes all stages', 10, FQuery.RecordCount);
end;

procedure TStartMarkRepositoryTests.SelectJournal_RejectsNegativeStageScope;
begin
  try
    TDatasetSql.ConfigureStartMarkJournal(FQuery, smjfPending, 0, -1);
    Fail('Expected invalid stage scope');
  except
    on E: EArgumentOutOfRangeException do ;
  end;
end;

initialization
  RegisterTest(TStartMarkRepositoryTests);

end.
