unit FinishMarkRepositoryTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, DB, FPCUnit, TestRegistry, SQLDB, CompetitionDbContext,
  CompetitionSchemaMigrator, TimingMark, FinishMark, FinishMarkRepository,
  CompetitionQueryProvider;

type
  TFinishMarkRepositoryTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FQuery: TSQLQuery;
    FRepository: TFinishMarkRepository;
    function PendingMark(const AEventTime, AReceivedAt: TDateTime;
      const ASource: TTimingMarkSource): TFinishMark;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure InsertAndLoadAll_PreserveAppliedMark;
    procedure InsertAndLoadAll_PreserveNullableManualMark;
    procedure LoadAll_OrdersByReceiptThenId;
    procedure Update_PersistsMutableStateWithoutChangingReceivedStage;
    procedure HideWorkQueue_HidesPendingOnly;
    procedure SelectWorkQueue_ReturnsPendingMarksInReceiptOrder;
    procedure SelectJournal_ReturnsEveryStatusNewestFirst;
    procedure SelectJournal_FiltersByStatusTimeAndReceivedStage;
    procedure SelectJournal_CombinesReceivedStageWithEveryStateFilter;
    procedure SelectJournal_RejectsNegativeStageScope;
  end;

implementation

procedure TFinishMarkRepositoryTests.SetUp;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  inherited SetUp;
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FQuery := FContext.CreateQuery(nil);
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, 2,
      'A', 'B', 'C', 'D', 'E', 'Finish repository test');
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
  FRepository := TFinishMarkRepository.Create(FContext);
end;

procedure TFinishMarkRepositoryTests.TearDown;
begin
  FRepository.Free;
  FQuery.Free;
  FContext.Free;
  inherited TearDown;
end;

function TFinishMarkRepositoryTests.PendingMark(
  const AEventTime, AReceivedAt: TDateTime;
  const ASource: TTimingMarkSource): TFinishMark;
begin
  Result := TFinishMark.FromTimingMark(
    TTimingMark.Finish(AEventTime, ASource, AReceivedAt), 2);
end;

procedure TFinishMarkRepositoryTests.InsertAndLoadAll_PreserveAppliedMark;
var
  AppliedAt: TDateTime;
  Inserted, Mark: TFinishMark;
  Marks: TFinishMarkArray;
begin
  AppliedAt := EncodeDateTime(2026, 8, 15, 10, 0, 3, 456);
  Mark := PendingMark(EncodeTime(9, 59, 58, 123),
    EncodeDateTime(2026, 8, 15, 10, 0, 0, 321), TTimingMarkSource.Ble('ENTime-3'));
  AssertTrue(Mark.TryApply(17, AppliedAt));

  Inserted := FRepository.Insert(Mark);
  Marks := FRepository.LoadAll;

  AssertTrue(Inserted.Id > 0);
  AssertEquals(1, Length(Marks));
  AssertEquals(Inserted.Id, Marks[0].Id);
  AssertEquals(2, Marks[0].StageIndex);
  AssertEquals(Mark.EventTime, Marks[0].EventTime);
  AssertTrue(Marks[0].HasParticipantNumber);
  AssertEquals(17, Marks[0].ParticipantNumber);
  AssertEquals(Ord(tmskBle), Ord(Marks[0].Source.Kind));
  AssertEquals('ENTime-3', Marks[0].Source.DeviceId);
  AssertEquals(Mark.ReceivedAt, Marks[0].ReceivedAt);
  AssertTrue(Marks[0].HasAssignmentMode);
  AssertEquals(Ord(fmamManual), Ord(Marks[0].AssignmentMode));
  AssertEquals(Ord(fmsApplied), Ord(Marks[0].Status));
  AssertTrue(Marks[0].HasAppliedAt);
  AssertEquals(AppliedAt, Marks[0].AppliedAt);
end;

procedure TFinishMarkRepositoryTests.
InsertAndLoadAll_PreserveNullableManualMark;
var
  Inserted: TFinishMark;
  Marks: TFinishMarkArray;
begin
  Inserted := FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 15, 10, 0, 1, 0), TTimingMarkSource.Manual));

  FQuery.SQL.Text := 'SELECT * FROM finish_marks WHERE id = :ID;';
  FQuery.ParamByName('ID').AsLargeInt := Inserted.Id;
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('participant_number').IsNull);
  AssertTrue(FQuery.FieldByName('source_device_id').IsNull);
  AssertTrue(FQuery.FieldByName('assignment_mode').IsNull);
  AssertTrue(FQuery.FieldByName('applied_at').IsNull);
  AssertTrue(FQuery.FieldByName('diagnostic').IsNull);
  FQuery.Close;

  Marks := FRepository.LoadAll;
  AssertEquals(1, Length(Marks));
  AssertEquals(Ord(tmskManual), Ord(Marks[0].Source.Kind));
  AssertFalse(Marks[0].HasParticipantNumber);
  AssertFalse(Marks[0].HasAssignmentMode);
  AssertFalse(Marks[0].HasAppliedAt);
  AssertEquals(Ord(fmsPending), Ord(Marks[0].Status));
end;

procedure TFinishMarkRepositoryTests.LoadAll_OrdersByReceiptThenId;
var
  FirstTime: TDateTime;
  Marks: TFinishMarkArray;
begin
  FirstTime := EncodeDateTime(2026, 8, 15, 10, 0, 1, 0);
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0), IncSecond(FirstTime),
    TTimingMarkSource.Serial('COM7')));
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0), FirstTime,
    TTimingMarkSource.Serial('COM7')));
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0), FirstTime,
    TTimingMarkSource.Serial('COM7')));

  Marks := FRepository.LoadAll;

  AssertEquals(3, Length(Marks));
  AssertEquals(EncodeTime(10, 0, 0, 0), Marks[0].EventTime);
  AssertEquals(EncodeTime(10, 0, 1, 0), Marks[1].EventTime);
  AssertEquals(EncodeTime(10, 0, 2, 0), Marks[2].EventTime);
end;

procedure TFinishMarkRepositoryTests.
Update_PersistsMutableStateWithoutChangingReceivedStage;
var
  Changed, Inserted, Loaded: TFinishMark;
begin
  Inserted := FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 15, 10, 0, 1, 0), TTimingMarkSource.Serial('COM7')));
  Changed := Inserted;
  Changed.StageIndex := 9;
  AssertTrue(Changed.TryApply(23, EncodeDateTime(2026, 8, 15, 10, 0, 2, 0)));

  FRepository.Update(Changed);
  AssertTrue(FRepository.TryLoadById(Inserted.Id, Loaded));

  AssertEquals(2, Loaded.StageIndex);
  AssertEquals(23, Loaded.ParticipantNumber);
  AssertEquals(Ord(fmsApplied), Ord(Loaded.Status));
end;

procedure TFinishMarkRepositoryTests.HideWorkQueue_HidesPendingOnly;
var
  Applied, Ignored: TFinishMark;
begin
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 15, 10, 0, 1, 0), TTimingMarkSource.Serial('COM7')));
  Ignored := FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0),
    EncodeDateTime(2026, 8, 15, 10, 0, 2, 0), TTimingMarkSource.Serial('COM7')));
  Ignored.MarkIgnoredDebounce('debounce');
  FRepository.Update(Ignored);
  Applied := FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0),
    EncodeDateTime(2026, 8, 15, 10, 0, 3, 0), TTimingMarkSource.Serial('COM7')));
  AssertTrue(Applied.TryApply(5, EncodeDateTime(2026, 8, 15, 10, 0, 4, 0)));
  FRepository.Update(Applied);

  AssertEquals(1, FRepository.HideWorkQueue);
  AssertEquals(0, FRepository.HideWorkQueue);
end;

procedure TFinishMarkRepositoryTests.
SelectWorkQueue_ReturnsPendingMarksInReceiptOrder;
var
  Ignored: TFinishMark;
begin
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0),
    EncodeDateTime(2026, 8, 15, 10, 0, 2, 0), TTimingMarkSource.Ble('A')));
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0),
    EncodeDateTime(2026, 8, 15, 10, 0, 1, 0), TTimingMarkSource.Ble('A')));
  Ignored := FRepository.Insert(PendingMark(EncodeTime(10, 0, 3, 0),
    EncodeDateTime(2026, 8, 15, 10, 0, 3, 0), TTimingMarkSource.Ble('A')));
  Ignored.MarkIgnoredDebounce('debounce');
  FRepository.Update(Ignored);

  FQuery.SQL.Text := TFinishMarkSql.SelectWorkQueue;
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('event_time') is TStringField);
  AssertEquals(EncodeTime(10, 0, 1, 0),
    StrToTime(FQuery.FieldByName('event_time').AsString));
  FQuery.Next;
  AssertEquals(EncodeTime(10, 0, 2, 0),
    StrToTime(FQuery.FieldByName('event_time').AsString));
  FQuery.Next;
  AssertTrue(FQuery.EOF);
  FQuery.Close;
end;

procedure TFinishMarkRepositoryTests.
SelectJournal_ReturnsEveryStatusNewestFirst;
var
  Applied, Hidden, Ignored: TFinishMark;
begin
  Hidden := FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 23, 10, 0, 1, 0), TTimingMarkSource.Serial('COM7')));
  Hidden.Hide;
  FRepository.Update(Hidden);
  Applied := FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0),
    EncodeDateTime(2026, 8, 23, 10, 0, 2, 0), TTimingMarkSource.Ble('ENTime-1')));
  AssertTrue(Applied.TryApply(17, EncodeDateTime(2026, 8, 23, 10, 0, 3, 0)));
  FRepository.Update(Applied);
  Ignored := FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0),
    EncodeDateTime(2026, 8, 23, 10, 0, 4, 0), TTimingMarkSource.Ble('ENTime-1')));
  Ignored.MarkIgnoredDebounce('debounce');
  FRepository.Update(Ignored);

  FQuery.SQL.Text := TFinishMarkSql.SelectJournal;
  FQuery.Open;

  AssertEquals(Ignored.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('ignored_debounce',
    FQuery.FieldByName('status').AsString);
  FQuery.Next;
  AssertEquals(Applied.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('applied', FQuery.FieldByName('status').AsString);
  FQuery.Next;
  AssertEquals(Hidden.Id, FQuery.FieldByName('id').AsLargeInt);
  AssertEquals('hidden', FQuery.FieldByName('status').AsString);
  FQuery.Next;
  AssertTrue(FQuery.EOF);
end;

procedure TFinishMarkRepositoryTests.
SelectJournal_FiltersByStatusTimeAndReceivedStage;
var
  Applied, ErrorMark, Hidden, Ignored, Recent: TFinishMark;

  procedure AssertFilter(const AFilter: TFinishMarkJournalFilter;
  const AExpectedCount: integer; const AReceivedSince: TDateTime;
  const AStageIndex: integer);
  begin
    FQuery.Close;
    FQuery.SQL.Text := TFinishMarkSql.SelectJournal(AFilter);
    TFinishMarkSql.BindJournalParameters(FQuery, AFilter,
      AReceivedSince, AStageIndex);
    FQuery.Open;
    AssertEquals(AExpectedCount, FQuery.RecordCount);
  end;

begin
  FRepository.Insert(PendingMark(EncodeTime(10, 0, 0, 0),
    EncodeDateTime(2026, 8, 23, 9, 40, 0, 0), TTimingMarkSource.Serial('COM7')));
  Ignored := FRepository.Insert(PendingMark(EncodeTime(10, 0, 1, 0),
    EncodeDateTime(2026, 8, 23, 9, 50, 0, 0), TTimingMarkSource.Serial('COM7')));
  Ignored.MarkIgnoredDebounce('debounce');
  FRepository.Update(Ignored);
  ErrorMark := FRepository.Insert(PendingMark(EncodeTime(10, 0, 2, 0),
    EncodeDateTime(2026, 8, 23, 9, 55, 0, 0), TTimingMarkSource.Serial('COM7')));
  ErrorMark.MarkError('failed');
  FRepository.Update(ErrorMark);
  Hidden := FRepository.Insert(PendingMark(EncodeTime(10, 0, 3, 0),
    EncodeDateTime(2026, 8, 23, 9, 56, 0, 0), TTimingMarkSource.Serial('COM7')));
  Hidden.Hide;
  FRepository.Update(Hidden);
  Applied := FRepository.Insert(PendingMark(EncodeTime(10, 0, 4, 0),
    EncodeDateTime(2026, 8, 23, 9, 57, 0, 0), TTimingMarkSource.Serial('COM7')));
  AssertTrue(Applied.TryApply(17, EncodeDateTime(2026, 8, 23, 9, 58, 0, 0)));
  FRepository.Update(Applied);
  Recent := PendingMark(EncodeTime(10, 0, 5, 0),
    EncodeDateTime(2026, 8, 23, 10, 0, 0, 0), TTimingMarkSource.Ble('ENTime-1'));
  Recent.StageIndex := 1;
  FRepository.Insert(Recent);

  AssertFilter(fmjfAll, 6, 0, 0);
  AssertFilter(fmjfPending, 2, 0, 0);
  AssertFilter(fmjfApplied, 1, 0, 0);
  AssertFilter(fmjfIgnoredDebounce, 1, 0, 0);
  AssertFilter(fmjfHidden, 1, 0, 0);
  AssertFilter(fmjfError, 1, 0, 0);
  AssertFilter(fmjfLast15Minutes, 5,
    EncodeDateTime(2026, 8, 23, 9, 45, 0, 0), 0);
  AssertFilter(fmjfCurrentStage, 1, 0, 1);
end;

procedure TFinishMarkRepositoryTests.
SelectJournal_CombinesReceivedStageWithEveryStateFilter;
const
  EXPECTED: array[TFinishMarkJournalFilter] of integer = (5, 1, 1, 1, 1, 1, 5, 5);
var
  Mark: TFinishMark;
  Status: TFinishMarkStatus;
  StageIndex: integer;
  Filter: TFinishMarkJournalFilter;
begin
  for StageIndex := 1 to 2 do
    for Status := Low(TFinishMarkStatus) to High(TFinishMarkStatus) do
    begin
      Mark := PendingMark(EncodeTime(10, 0, 0, 0),
        EncodeDateTime(2026, 10, 29, 8 + StageIndex, Ord(Status), 0, 0),
        TTimingMarkSource.Manual);
      Mark.StageIndex := StageIndex;
      Mark.Status := Status;
      Mark.HasParticipantNumber := True;
      Mark.ParticipantNumber := 17;
      FRepository.Insert(Mark);
    end;
  for Filter := Low(TFinishMarkJournalFilter) to High(TFinishMarkJournalFilter) do
  begin
    TDatasetSql.ConfigureFinishMarkJournal(FQuery, Filter,
      EncodeDateTime(2026, 10, 29, 9, 45, 0, 0), 2);
    FQuery.Open;
    AssertEquals('Filter ' + IntToStr(Ord(Filter)), EXPECTED[Filter],
      FQuery.RecordCount);
    while not FQuery.EOF do
    begin
      AssertEquals(2, FQuery.FieldByName('stage_index').AsInteger);
      FQuery.Next;
    end;
    FQuery.Close;
  end;
  TDatasetSql.ConfigureFinishMarkJournal(FQuery);
  FQuery.Open;
  AssertEquals(10, FQuery.RecordCount);
end;

procedure TFinishMarkRepositoryTests.SelectJournal_RejectsNegativeStageScope;
begin
  try
    TDatasetSql.ConfigureFinishMarkJournal(FQuery, fmjfError, 0, -1);
    Fail('Expected invalid stage scope');
  except
    on E: EArgumentOutOfRangeException do ;
  end;
end;

initialization
  RegisterTest(TFinishMarkRepositoryTests);

end.
