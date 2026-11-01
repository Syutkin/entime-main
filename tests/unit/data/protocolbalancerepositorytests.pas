unit ProtocolBalanceRepositoryTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DB, SQLDB, fpcunit, testregistry, CompetitionDbContext,
  CompetitionSchemaMigrator, StageConfig, StageModel, ProtocolBalance,
  ProtocolBalanceRepository;

type
  TProtocolBalanceRepositoryTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FQuery: TSQLQuery;
    FStages: TStages;
    FSelectCount, FCommitCount, FRollbackCount: integer;
    procedure Exec(const ASql: string);
    function ScalarInt(const ASql: string): int64;
    procedure AddParticipant(const ANumber: integer; const AName: string = 'Rider';
      const ACategory: string = 'A');
    procedure AddStart(const AStageIndex: integer; const AStatus: string;
      const ANumber: integer = 0; const AAppliedStageIndex: integer = 0);
    procedure AddFinish(const AStageIndex: integer; const AStatus: string;
      const ANumber: integer = 0);
    procedure TraceSql(Sender: TSQLConnection; EventType: TDBEventType;
      const Msg: string);
    procedure StartTrace;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Load_RejectsMissingArgumentsAndClosedDatabase;
    procedure Load_EmptyDatabaseKeepsActiveStagesInIndexOrder;
    procedure Load_NoActiveStagesReturnsEmptyWithoutQueries;
    procedure Load_SparseStagesPreserveIdentityDataAndClassification;
    procedure Load_NullsWhitespaceZeroAndUnknownStatusArePreserved;
    procedure Load_CountsAllStartStatesByReceivedStage;
    procedure Load_CountsAllFinishStatesByReceivedStage;
    procedure Load_MarksWithoutParticipantsStillCount;
    procedure Load_MultipleMarksDoNotMultiplyParticipants;
    procedure Load_DoesNotUseFilteredDatasetOrPostPendingEdit;
    procedure Load_DoesNotWriteOrFinishCallerTransaction;
    procedure Load_RestoresInactiveTransactionAfterRead;
    procedure Load_FailurePreservesPreviousSnapshotAndAllowsRetry;
    procedure Load_FailureDoesNotFinishCallerTransaction;
    procedure Load_RereadsSavedChangesWithoutMutatingPreviousSnapshot;
    procedure TryLoadSaved_DefersUntilCommitWithoutPublishingPartialChanges;
    procedure TryLoadSaved_RereadsAfterRollbackAndKeepsPendingEditor;
    procedure TryLoadSaved_RereadsParticipantsStagesAndMarkStateTransitions;
    procedure Load_MaximumStagesUseBoundedQueries;
  end;

implementation

procedure TProtocolBalanceRepositoryTests.SetUp;
var
  Work: TCompetitionUnitOfWork;
begin
  inherited SetUp;
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FQuery := FContext.CreateQuery(nil);
  FStages := TStages.Create(MAX_SUPPORTED_STAGE_COUNT);
  Work := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, MAX_SUPPORTED_STAGE_COUNT,
      'A', 'B', 'C', 'D', 'E', 'Protocol balance test');
    Work.Commit;
  finally
    Work.Free;
  end;
end;

procedure TProtocolBalanceRepositoryTests.TearDown;
begin
  FContext.Connection.OnLog := nil;
  FStages.Free;
  FQuery.Free;
  FContext.Free;
  inherited TearDown;
end;

procedure TProtocolBalanceRepositoryTests.Exec(const ASql: string);
var
  Work: TCompetitionUnitOfWork;
begin
  Work := FContext.BeginUnitOfWork;
  try
    FQuery.Close;
    FQuery.SQL.Text := ASql;
    FQuery.ExecSQL;
    FQuery.Close;
    Work.Commit;
  finally
    Work.Free;
  end;
end;

function TProtocolBalanceRepositoryTests.ScalarInt(const ASql: string): int64;
var
  Query: TSQLQuery;
  OwnTransaction: boolean;
begin
  OwnTransaction := not FContext.Transaction.Active;
  Query := FContext.CreateQuery(nil);
  try
    Query.SQL.Text := ASql;
    Query.Open;
    Result := Query.Fields[0].AsLargeInt;
  finally
    Query.Free;
    if OwnTransaction and FContext.Transaction.Active then
      FContext.Transaction.Rollback;
  end;
end;

procedure TProtocolBalanceRepositoryTests.AddParticipant(const ANumber: integer;
  const AName, ACategory: string);
begin
  Exec(Format('INSERT INTO main (number, name, category) VALUES (%d, %s, %s);',
    [ANumber, QuotedStr(AName), QuotedStr(ACategory)]));
end;

procedure TProtocolBalanceRepositoryTests.AddStart(const AStageIndex: integer;
  const AStatus: string; const ANumber, AAppliedStageIndex: integer);
var
  NumberSql, AppliedStageSql: string;
begin
  NumberSql := 'NULL';
  if ANumber <> 0 then NumberSql := IntToStr(ANumber);
  AppliedStageSql := 'NULL';
  if AAppliedStageIndex <> 0 then AppliedStageSql := IntToStr(AAppliedStageIndex);
  Exec(Format('INSERT INTO start_marks (stage_index, applied_stage_index, ' +
    'event_time, participant_number, source_kind, source_device_id, received_at, status) '
    + 'VALUES (%d, %s, ''12:00:00.000'', %s, ''serial'', ''TEST'', ' +
    '''2026-10-29T12:00:00.000'', %s);', [AStageIndex, AppliedStageSql,
    NumberSql, QuotedStr(AStatus)]));
end;

procedure TProtocolBalanceRepositoryTests.AddFinish(const AStageIndex: integer;
  const AStatus: string; const ANumber: integer);
var
  NumberSql: string;
begin
  NumberSql := 'NULL';
  if ANumber <> 0 then NumberSql := IntToStr(ANumber);
  Exec(Format('INSERT INTO finish_marks (stage_index, event_time, ' +
    'participant_number, source_kind, received_at, status) ' +
    'VALUES (%d, ''12:00:00.000'', %s, ''manual'', ' +
    '''2026-10-29T12:00:00.000'', %s);', [AStageIndex, NumberSql,
    QuotedStr(AStatus)]));
end;

procedure TProtocolBalanceRepositoryTests.TraceSql(Sender: TSQLConnection;
  EventType: TDBEventType; const Msg: string);
begin
  case EventType of
    detActualSQL:
      if Pos('SELECT ', UpperCase(TrimLeft(Msg))) = 1 then Inc(FSelectCount);
    detCommit: Inc(FCommitCount);
    detRollback: Inc(FRollbackCount);
  end;
end;

procedure TProtocolBalanceRepositoryTests.StartTrace;
begin
  FSelectCount := 0;
  FCommitCount := 0;
  FRollbackCount := 0;
  FContext.Connection.LogEvents := [detActualSQL, detCommit, detRollback];
  FContext.Connection.OnLog := @TraceSql;
end;

procedure TProtocolBalanceRepositoryTests.Load_RejectsMissingArgumentsAndClosedDatabase;
begin
  try
    TProtocolBalanceRepository.Load(nil, FStages);
    Fail('Expected missing context error');
  except
    on E: EArgumentNilException do ;
  end;
  try
    TProtocolBalanceRepository.Load(FContext, nil);
    Fail('Expected missing stages error');
  except
    on E: EArgumentNilException do ;
  end;
  FContext.CloseFile;
  try
    TProtocolBalanceRepository.Load(FContext, FStages);
    Fail('Expected closed database error');
  except
    on E: EDatabaseError do ;
  end;
  AssertFalse(FContext.Connection.Connected);
end;

procedure TProtocolBalanceRepositoryTests.
Load_EmptyDatabaseKeepsActiveStagesInIndexOrder;
var
  Snapshot: TProtocolBalanceSnapshot;
  I: integer;
  Group: TProtocolBalanceGroup;
begin
  FStages[3].isActive := True;
  FStages[32].isActive := True;
  FStages[3].Name := 'Лес';
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(3, Length(Snapshot.Stages));
  AssertEquals(1, Snapshot.Stages[0].StageIndex);
  AssertEquals(3, Snapshot.Stages[1].StageIndex);
  AssertEquals(32, Snapshot.Stages[2].StageIndex);
  AssertEquals('Лес', Snapshot.Stages[1].StageName);
  for I := 0 to High(Snapshot.Stages) do
  begin
    AssertEquals(0, Length(Snapshot.Stages[I].Participants));
    AssertEquals(0, Snapshot.Stages[I].Summary.ParticipantCount);
    AssertEquals(0, Snapshot.Stages[I].Summary.FinishWithoutStartCount);
    for Group := Low(TProtocolBalanceGroup) to High(TProtocolBalanceGroup) do
      AssertEquals(0, Snapshot.Stages[I].Summary.GroupCounts[Group]);
    AssertEquals(0, Snapshot.Stages[I].Marks.PendingStarts);
    AssertEquals(0, Snapshot.Stages[I].Marks.PendingFinishes);
    AssertEquals(0, Snapshot.Stages[I].Marks.StartErrors);
    AssertEquals(0, Snapshot.Stages[I].Marks.FinishErrors);
  end;
end;

procedure TProtocolBalanceRepositoryTests.Load_NoActiveStagesReturnsEmptyWithoutQueries;
var
  Snapshot: TProtocolBalanceSnapshot;
begin
  FStages[1].isActive := False;
  StartTrace;
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(0, Length(Snapshot.Stages));
  AssertEquals(0, FSelectCount);
  AssertFalse(FContext.Transaction.Active);
end;

procedure TProtocolBalanceRepositoryTests.
Load_SparseStagesPreserveIdentityDataAndClassification;
var
  Snapshot: TProtocolBalanceSnapshot;
  I, J: integer;
  Expected: TProtocolBalanceClassification;
begin
  FStages[3].isActive := True;
  FStages[32].isActive := True;
  AddParticipant(90, 'Иван', 'Элита');
  AddParticipant(9, 'Олег', 'Юниоры');
  Exec('UPDATE main SET status = ''1'', result1 = ''00:01:00.000'', ' +
    'starttime3 = ''23:59:00.000'', finishtime3 = ''00:01:00.000'', ' +
    'result3 = ''00:02:00.000'', status32 = ''2'' WHERE number = 9;');
  Exec('UPDATE main SET status = ''3'', status1 = ''1'', ' +
    'result3 = ''00:01:00.000'' WHERE number = 90;');
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(3, Length(Snapshot.Stages));
  AssertEquals(9, Snapshot.Stages[0].Participants[0].Number);
  AssertEquals(90, Snapshot.Stages[0].Participants[1].Number);
  AssertEquals(ScalarInt('SELECT id FROM main WHERE number = 9'),
    int64(Snapshot.Stages[0].Participants[0].ParticipantId));
  AssertEquals('Олег', Snapshot.Stages[0].Participants[0].Name);
  AssertEquals('Юниоры', Snapshot.Stages[0].Participants[0].Category);
  AssertEquals('23:59:00.000', Snapshot.Stages[1].Participants[0].Data.StartTime);
  AssertEquals('00:01:00.000', Snapshot.Stages[1].Participants[0].Data.FinishTime);
  AssertEquals('00:02:00.000', Snapshot.Stages[1].Participants[0].Data.ResultValue);
  AssertEquals(Ord(pbgDNF), Ord(
    Snapshot.Stages[2].Participants[0].Classification.Group));
  for I := 0 to High(Snapshot.Stages) do
  begin
    AssertEquals(2, Snapshot.Stages[I].Summary.ParticipantCount);
    AssertEquals(1, Snapshot.Stages[I].Summary.GroupCounts[pbgDSQ]);
    for J := 0 to High(Snapshot.Stages[I].Participants) do
    begin
      Expected := ClassifyProtocolBalance(Snapshot.Stages[I].Participants[J].Data);
      AssertEquals(Ord(Expected.Group),
        Ord(Snapshot.Stages[I].Participants[J].Classification.Group));
      AssertEquals(Ord(Expected.Reason),
        Ord(Snapshot.Stages[I].Participants[J].Classification.Reason));
    end;
  end;
end;

procedure TProtocolBalanceRepositoryTests.
Load_NullsWhitespaceZeroAndUnknownStatusArePreserved;
var
  Snapshot: TProtocolBalanceSnapshot;
begin
  AddParticipant(1);
  AddParticipant(2);
  AddParticipant(3);
  AddParticipant(4);
  Exec('UPDATE main SET starttime1 = '' '', finishtime1 = '' '', ' +
    'result1 = '' '', status1 = '' '' WHERE number = 2;');
  Exec('UPDATE main SET starttime1 = ''00:00:00.000'', ' +
    'finishtime1 = ''00:00:00.000'', result1 = ''00:00:00.000'' WHERE number = 3;');
  Exec('UPDATE main SET status1 = '' unknown '', result1 = '' DNF '' WHERE number = 4;');
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(1, Length(Snapshot.Stages));
  AssertEquals(4, Length(Snapshot.Stages[0].Participants));
  AssertEquals('', Snapshot.Stages[0].Participants[0].Data.StartTime);
  AssertEquals('', Snapshot.Stages[0].Participants[0].Data.StageStatusValue);
  AssertEquals(Ord(pbrNoStageData),
    Ord(Snapshot.Stages[0].Participants[0].Classification.Reason));
  AssertEquals(' ', Snapshot.Stages[0].Participants[1].Data.StartTime);
  AssertEquals(Ord(pbrNoStageData),
    Ord(Snapshot.Stages[0].Participants[1].Classification.Reason));
  AssertEquals(Ord(pbgWithResult),
    Ord(Snapshot.Stages[0].Participants[2].Classification.Group));
  AssertEquals(' unknown ', Snapshot.Stages[0].Participants[3].Data.StageStatusValue);
  AssertEquals(' DNF ', Snapshot.Stages[0].Participants[3].Data.ResultValue);
  AssertEquals(Ord(pbrUnknownStageStatus),
    Ord(Snapshot.Stages[0].Participants[3].Classification.Reason));
  AssertEquals(1, Snapshot.Stages[0].Summary.GroupCounts[pbgWithResult]);
  AssertEquals(3, Snapshot.Stages[0].Summary.GroupCounts[pbgUnresolved]);
end;

procedure TProtocolBalanceRepositoryTests.Load_CountsAllStartStatesByReceivedStage;
var
  Snapshot: TProtocolBalanceSnapshot;
begin
  FStages[3].isActive := True;
  AddStart(1, 'pending');
  AddStart(1, 'pending', 999);
  AddStart(1, 'conflict', 999);
  AddStart(1, 'error');
  AddStart(1, 'applied', 999, 3);
  AddStart(1, 'hidden');
  AddStart(3, 'pending');
  AddStart(3, 'applied', 999, 1);
  AddStart(2, 'pending');
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(2, Length(Snapshot.Stages));
  AssertEquals(3, Snapshot.Stages[0].Marks.PendingStarts);
  AssertEquals(1, Snapshot.Stages[0].Marks.StartErrors);
  AssertEquals(1, Snapshot.Stages[1].Marks.PendingStarts);
  AssertEquals(0, Snapshot.Stages[1].Marks.StartErrors);
  AssertEquals(0, Snapshot.Stages[0].Marks.PendingFinishes);
end;

procedure TProtocolBalanceRepositoryTests.Load_CountsAllFinishStatesByReceivedStage;
var
  Snapshot: TProtocolBalanceSnapshot;
begin
  FStages[3].isActive := True;
  AddFinish(1, 'pending');
  AddFinish(1, 'pending', 999);
  AddFinish(1, 'error');
  AddFinish(1, 'applied', 999);
  AddFinish(1, 'hidden');
  AddFinish(1, 'ignored_debounce');
  AddFinish(3, 'pending');
  AddFinish(2, 'error');
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(2, Length(Snapshot.Stages));
  AssertEquals(2, Snapshot.Stages[0].Marks.PendingFinishes);
  AssertEquals(1, Snapshot.Stages[0].Marks.FinishErrors);
  AssertEquals(1, Snapshot.Stages[1].Marks.PendingFinishes);
  AssertEquals(0, Snapshot.Stages[1].Marks.FinishErrors);
  AssertEquals(0, Snapshot.Stages[0].Marks.PendingStarts);
end;

procedure TProtocolBalanceRepositoryTests.Load_MarksWithoutParticipantsStillCount;
var
  Snapshot: TProtocolBalanceSnapshot;
begin
  AddStart(1, 'conflict', 999);
  AddFinish(1, 'pending', 999);
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(1, Length(Snapshot.Stages));
  AssertEquals(0, Snapshot.Stages[0].Summary.ParticipantCount);
  AssertEquals(0, Length(Snapshot.Stages[0].Participants));
  AssertEquals(1, Snapshot.Stages[0].Marks.PendingStarts);
  AssertEquals(1, Snapshot.Stages[0].Marks.PendingFinishes);
end;

procedure TProtocolBalanceRepositoryTests.Load_MultipleMarksDoNotMultiplyParticipants;
var
  Snapshot: TProtocolBalanceSnapshot;
  I: integer;
begin
  AddParticipant(1);
  AddParticipant(2);
  for I := 1 to 4 do AddStart(1, 'pending', 1);
  for I := 1 to 6 do AddFinish(1, 'pending', 1);
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(1, Length(Snapshot.Stages));
  AssertEquals(2, Length(Snapshot.Stages[0].Participants));
  AssertEquals(2, Snapshot.Stages[0].Summary.ParticipantCount);
  AssertEquals(2, Snapshot.Stages[0].Summary.GroupCounts[pbgUnresolved]);
  AssertEquals(4, Snapshot.Stages[0].Marks.PendingStarts);
  AssertEquals(6, Snapshot.Stages[0].Marks.PendingFinishes);
end;

procedure TProtocolBalanceRepositoryTests.
Load_DoesNotUseFilteredDatasetOrPostPendingEdit;
var
  View: TSQLQuery;
  Snapshot: TProtocolBalanceSnapshot;
begin
  AddParticipant(1, 'Alice', 'A');
  AddParticipant(2, 'Bob', 'B');
  AddParticipant(3, 'Carol', 'A');
  View := FContext.CreateQuery(nil);
  try
    View.SQL.Text := 'SELECT * FROM main WHERE category = ''A'' ORDER BY number DESC;';
    View.Open;
    View.Edit;
    View.FieldByName('name').AsString := 'Unsaved edit';
    Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
    AssertEquals(1, Length(Snapshot.Stages));
    AssertEquals(3, Snapshot.Stages[0].Summary.ParticipantCount);
    AssertEquals('Carol', Snapshot.Stages[0].Participants[2].Name);
    AssertTrue(View.Active);
    AssertEquals(Ord(dsEdit), Ord(View.State));
    AssertEquals(3, View.FieldByName('number').AsInteger);
    AssertEquals('Unsaved edit', View.FieldByName('name').AsString);
    AssertEquals(0, View.ChangeCount);
  finally
    View.Free;
  end;
end;

procedure TProtocolBalanceRepositoryTests.Load_DoesNotWriteOrFinishCallerTransaction;
var
  Snapshot: TProtocolBalanceSnapshot;
  Work: TCompetitionUnitOfWork;
  ChangesBefore: int64;
begin
  AddParticipant(1, 'Original');
  Work := FContext.BeginUnitOfWork;
  try
    FQuery.SQL.Text :=
      'UPDATE main SET name = ''Uncommitted'', result1 = ''00:01:00.000'';';
    FQuery.ExecSQL;
    ChangesBefore := ScalarInt('SELECT total_changes();');
    StartTrace;
    Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
    AssertEquals(1, Length(Snapshot.Stages));
    AssertEquals('Uncommitted', Snapshot.Stages[0].Participants[0].Name);
    AssertEquals(1, Snapshot.Stages[0].Summary.GroupCounts[pbgWithResult]);
    AssertTrue(FContext.Transaction.Active);
    AssertFalse(Work.Completed);
    AssertEquals(0, FCommitCount);
    AssertEquals(0, FRollbackCount);
    AssertEquals(ChangesBefore, ScalarInt('SELECT total_changes();'));
    Work.Rollback;
  finally
    Work.Free;
  end;
  AssertEquals(1, ScalarInt(
    'SELECT COUNT(*) FROM main WHERE name = ''Original'' AND result1 IS NULL;'));
end;

procedure TProtocolBalanceRepositoryTests.Load_RestoresInactiveTransactionAfterRead;
var
  Snapshot: TProtocolBalanceSnapshot;
  ChangesBefore: int64;
begin
  AddParticipant(1);
  AddStart(1, 'pending');
  ChangesBefore := ScalarInt('SELECT total_changes();');
  AssertFalse(FContext.Transaction.Active);
  StartTrace;
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(1, Length(Snapshot.Stages));
  AssertEquals(1, Snapshot.Stages[0].Marks.PendingStarts);
  AssertFalse(FContext.Transaction.Active);
  AssertEquals(0, FCommitCount);
  AssertEquals(ChangesBefore, ScalarInt('SELECT total_changes();'));
  AssertEquals(1, ScalarInt(
    'SELECT COUNT(*) FROM start_marks WHERE status = ''pending'';'));
end;

procedure TProtocolBalanceRepositoryTests.
Load_FailurePreservesPreviousSnapshotAndAllowsRetry;
var
  Snapshot: TProtocolBalanceSnapshot;
begin
  AddParticipant(1);
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(1, Length(Snapshot.Stages));
  AddParticipant(2);
  Exec('ALTER TABLE finish_marks RENAME TO saved_finish_marks;');
  try
    Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
    Fail('Expected read failure');
  except
    on E: EDatabaseError do ;
  end;
  AssertFalse(FContext.Transaction.Active);
  AssertEquals(1, Length(Snapshot.Stages));
  AssertEquals(1, Snapshot.Stages[0].Summary.ParticipantCount);
  AssertEquals(1, Length(Snapshot.Stages[0].Participants));
  Exec('ALTER TABLE saved_finish_marks RENAME TO finish_marks;');
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(2, Snapshot.Stages[0].Summary.ParticipantCount);
end;

procedure TProtocolBalanceRepositoryTests.Load_FailureDoesNotFinishCallerTransaction;
var
  Work: TCompetitionUnitOfWork;
begin
  AddParticipant(1, 'Original');
  Exec('ALTER TABLE finish_marks RENAME TO saved_finish_marks;');
  Work := FContext.BeginUnitOfWork;
  try
    FQuery.SQL.Text := 'UPDATE main SET name = ''Uncommitted'';';
    FQuery.ExecSQL;
    StartTrace;
    try
      TProtocolBalanceRepository.Load(FContext, FStages);
      Fail('Expected read failure');
    except
      on E: EDatabaseError do ;
    end;
    AssertTrue(FContext.Transaction.Active);
    AssertFalse(Work.Completed);
    AssertEquals(0, FCommitCount);
    AssertEquals(0, FRollbackCount);
    Work.Rollback;
  finally
    Work.Free;
  end;
  AssertEquals(1, ScalarInt('SELECT COUNT(*) FROM main WHERE name = ''Original'';'));
end;

procedure TProtocolBalanceRepositoryTests.
Load_RereadsSavedChangesWithoutMutatingPreviousSnapshot;
var
  BeforeSnapshot, AfterSnapshot: TProtocolBalanceSnapshot;
begin
  AddParticipant(1);
  AddFinish(1, 'pending', 1);
  BeforeSnapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(1, Length(BeforeSnapshot.Stages));
  Exec('UPDATE main SET result1 = ''00:01:00.000'', status1 = NULL;');
  Exec('UPDATE finish_marks SET status = ''applied'';');
  AfterSnapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AssertEquals(1, BeforeSnapshot.Stages[0].Summary.GroupCounts[pbgUnresolved]);
  AssertEquals(1, BeforeSnapshot.Stages[0].Marks.PendingFinishes);
  AssertEquals('', BeforeSnapshot.Stages[0].Participants[0].Data.ResultValue);
  AssertEquals(1, AfterSnapshot.Stages[0].Summary.GroupCounts[pbgWithResult]);
  AssertEquals(0, AfterSnapshot.Stages[0].Marks.PendingFinishes);
end;

procedure TProtocolBalanceRepositoryTests.
TryLoadSaved_DefersUntilCommitWithoutPublishingPartialChanges;
var
  Snapshot: TProtocolBalanceSnapshot;
  Work: TCompetitionUnitOfWork;
begin
  AddParticipant(1, 'Before');
  AddStart(1, 'pending', 1);
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  Work := FContext.BeginUnitOfWork;
  try
    FQuery.SQL.Text := 'UPDATE main SET name = ''After'', result1 = ''00:01:00.000'';';
    FQuery.ExecSQL;
    StartTrace;
    AssertFalse('Do not publish an unfinished operation',
      TProtocolBalanceRepository.TryLoadSaved(FContext, FStages, Snapshot));
    AssertEquals(0, FSelectCount);
    AssertEquals(0, FCommitCount);
    AssertEquals(0, FRollbackCount);
    AssertFalse(Work.Completed);
    AssertEquals('Before', Snapshot.Stages[0].Participants[0].Name);
    AssertEquals(1, Snapshot.Stages[0].Summary.GroupCounts[pbgUnresolved]);
    FQuery.SQL.Text := 'UPDATE start_marks SET status = ''applied'';';
    FQuery.ExecSQL;
    Work.Commit;
  finally
    Work.Free;
  end;
  AssertTrue(TProtocolBalanceRepository.TryLoadSaved(FContext, FStages, Snapshot));
  AssertEquals('After', Snapshot.Stages[0].Participants[0].Name);
  AssertEquals(1, Snapshot.Stages[0].Summary.GroupCounts[pbgWithResult]);
  AssertEquals(0, Snapshot.Stages[0].Marks.PendingStarts);
end;

procedure TProtocolBalanceRepositoryTests.
TryLoadSaved_RereadsAfterRollbackAndKeepsPendingEditor;
var
  Snapshot: TProtocolBalanceSnapshot;
  Work: TCompetitionUnitOfWork;
  View: TSQLQuery;
begin
  AddParticipant(1, 'Saved');
  Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  Work := FContext.BeginUnitOfWork;
  try
    FQuery.SQL.Text := 'DELETE FROM main;';
    FQuery.ExecSQL;
    AssertFalse(TProtocolBalanceRepository.TryLoadSaved(FContext, FStages, Snapshot));
    AssertEquals(1, Snapshot.Stages[0].Summary.ParticipantCount);
    Work.Rollback;
  finally
    Work.Free;
  end;
  View := FContext.CreateQuery(nil);
  try
    View.SQL.Text := 'SELECT * FROM main;';
    View.Open;
    View.Edit;
    View.FieldByName('name').AsString := 'Unsaved';
    AssertTrue(TProtocolBalanceRepository.TryLoadSaved(FContext, FStages, Snapshot));
    AssertEquals('Saved', Snapshot.Stages[0].Participants[0].Name);
    AssertEquals(Ord(dsEdit), Ord(View.State));
    AssertEquals('Unsaved', View.FieldByName('name').AsString);
    AssertEquals(0, View.ChangeCount);
  finally
    View.Free;
  end;
end;

procedure TProtocolBalanceRepositoryTests.
TryLoadSaved_RereadsParticipantsStagesAndMarkStateTransitions;
var
  BeforeSnapshot, Snapshot: TProtocolBalanceSnapshot;
begin
  AddParticipant(1, 'Original');
  AddStart(1, 'pending');
  AddFinish(1, 'pending');
  BeforeSnapshot := TProtocolBalanceRepository.Load(FContext, FStages);
  AddParticipant(2);
  Exec('UPDATE main SET name = ''Renamed'', category = ''B'', status1 = ''1'' WHERE number = 1;');
  Exec('UPDATE start_marks SET status = ''conflict'';');
  Exec('UPDATE finish_marks SET status = ''error'';');
  AssertTrue(TProtocolBalanceRepository.TryLoadSaved(FContext, FStages, Snapshot));
  AssertEquals(2, Snapshot.Stages[0].Summary.ParticipantCount);
  AssertEquals(1, Snapshot.Stages[0].Summary.GroupCounts[pbgDNS]);
  AssertEquals('Renamed', Snapshot.Stages[0].Participants[0].Name);
  AssertEquals('B', Snapshot.Stages[0].Participants[0].Category);
  AssertEquals(1, Snapshot.Stages[0].Marks.PendingStarts);
  AssertEquals(0, Snapshot.Stages[0].Marks.PendingFinishes);
  AssertEquals(1, Snapshot.Stages[0].Marks.FinishErrors);
  Exec('DELETE FROM main WHERE number = 1;');
  Exec('UPDATE start_marks SET status = ''error'';');
  Exec('UPDATE finish_marks SET status = ''hidden'';');
  AssertTrue(TProtocolBalanceRepository.TryLoadSaved(FContext, FStages, Snapshot));
  AssertEquals(1, Snapshot.Stages[0].Summary.ParticipantCount);
  AssertEquals(2, Snapshot.Stages[0].Participants[0].Number);
  AssertEquals(0, Snapshot.Stages[0].Marks.PendingStarts);
  AssertEquals(1, Snapshot.Stages[0].Marks.StartErrors);
  AssertEquals(0, Snapshot.Stages[0].Marks.FinishErrors);
  FStages[1].isActive := False;
  FStages[3].isActive := True;
  FStages[3].Name := 'New stage';
  AssertTrue(TProtocolBalanceRepository.TryLoadSaved(FContext, FStages, Snapshot));
  AssertEquals(1, Length(Snapshot.Stages));
  AssertEquals(3, Snapshot.Stages[0].StageIndex);
  AssertEquals('New stage', Snapshot.Stages[0].StageName);
  AssertEquals(1, BeforeSnapshot.Stages[0].Summary.ParticipantCount);
  AssertEquals('Original', BeforeSnapshot.Stages[0].Participants[0].Name);
  AssertEquals(1, BeforeSnapshot.Stages[0].Marks.PendingStarts);
  AssertEquals(1, BeforeSnapshot.Stages[0].Marks.PendingFinishes);
end;

procedure TProtocolBalanceRepositoryTests.Load_MaximumStagesUseBoundedQueries;
const
  PARTICIPANT_COUNTS: array[0..1] of integer = (1, 1000);
var
  Snapshot: TProtocolBalanceSnapshot;
  I, ParticipantCount: integer;
  HeapBefore, HeapAfter: PtrUInt;
begin
  for I := 1 to FStages.Count do FStages[I].isActive := True;
  for ParticipantCount in PARTICIPANT_COUNTS do
  begin
    Exec('DELETE FROM main;');
    Exec(Format('WITH RECURSIVE numbers(n) AS (SELECT 1 UNION ALL ' +
      'SELECT n + 1 FROM numbers WHERE n < %d) ' +
      'INSERT INTO main (number, name) SELECT n, ''Rider '' || n FROM numbers;',
      [ParticipantCount]));
    Snapshot := Default(TProtocolBalanceSnapshot);
    StartTrace;
    HeapBefore := GetFPCHeapStatus.CurrHeapUsed;
    Snapshot := TProtocolBalanceRepository.Load(FContext, FStages);
    HeapAfter := GetFPCHeapStatus.CurrHeapUsed;
    AssertEquals(32, Length(Snapshot.Stages));
    AssertEquals('Read query count is independent of participants/stages', 3,
      FSelectCount);
    for I := 0 to High(Snapshot.Stages) do
    begin
      AssertEquals(ParticipantCount, Length(Snapshot.Stages[I].Participants));
      AssertEquals(ParticipantCount, Snapshot.Stages[I].Summary.ParticipantCount);
      AssertEquals(ParticipantCount,
        Snapshot.Stages[I].Summary.GroupCounts[pbgUnresolved]);
    end;
    WriteLn('Protocol balance snapshot: ', ParticipantCount,
      ' participants x 32 stages; heap delta: ',
      int64(HeapAfter) - int64(HeapBefore), ' bytes');
  end;
end;

initialization
  RegisterTest(TProtocolBalanceRepositoryTests);

end.
