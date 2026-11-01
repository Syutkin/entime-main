unit ParticipantCardServiceTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, DB, SQLDB, fpcunit, testregistry, CompetitionDbContext,
  CompetitionSchemaMigrator, StageModel, StageFieldNames, TimingMark,
  ParticipantCardModel, ParticipantCardService;

type
  TParticipantCardServiceTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FStages: TStages;
    FReads: integer;
    procedure Exec(const Sql: string);
    procedure Trace(Sender: TSQLConnection; EventType: TDBEventType; const Msg: string);
    function Read: TCardReadOutcome;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ReadsSavedFieldsIncludingInactiveStage32WithoutCalculation;
    procedure IgnoresPendingNumberAndNameAndPreservesEditor;
    procedure ReadsOnlyCurrentNumberAndKeepsBothMarkKinds;
    procedure RenumberingKeepsIdAndDoesNotClaimOldMarks;
    procedure MissingAndChangedSessionHaveDistinctOutcomes;
    procedure BusyWriteDoesNotPublishUncommittedValues;
    procedure ReadFailureReleasesOwnTransactionAndCanRetry;
    procedure MaximumStagesAndLargeOtherJournalUseThreeReads;
    procedure LargeParticipantJournalKeepsNewestIdsAndBoundedReads;
  end;

implementation

procedure TParticipantCardServiceTests.SetUp;
var
  W: TCompetitionUnitOfWork;
begin
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FStages := TStages.Create(32);
  FStages[9].isActive := True;
  W := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, 32, 'A', 'B', 'C', 'D', 'E', 'Card');
    W.Commit;
  finally
    W.Free;
  end;
  Exec('INSERT INTO main(id,number,name,category,comment,sumresult,sumplace,' +
    'starttime32,correction32,penalty32) VALUES(1,123,''Saved rider'',''A'',''Note'',''00:07:00.125'',5,'
    +
    '''10:00:00.123'',-125,''00:00:00'');');
end;

procedure TParticipantCardServiceTests.TearDown;
begin
  FContext.Connection.OnLog := nil;
  FStages.Free;
  FContext.Free;
end;

procedure TParticipantCardServiceTests.Exec(const Sql: string);
var
  Q: TSQLQuery;
  W: TCompetitionUnitOfWork;
begin
  Q := FContext.CreateQuery(nil);
  W := FContext.BeginUnitOfWork;
  try
    Q.SQL.Text := Sql;
    Q.ExecSQL;
    W.Commit;
  finally
    W.Free;
    Q.Free;
  end;
end;

function TParticipantCardServiceTests.Read: TCardReadOutcome;
begin
  Result := TParticipantCardService.Read(FContext, FStages, 1);
end;

procedure TParticipantCardServiceTests.Trace(Sender: TSQLConnection;
  EventType: TDBEventType; const Msg: string);
begin
  if (EventType = detActualSQL) and (Pos('SELECT ', UpperCase(Trim(Msg))) = 1) then
    Inc(FReads);
end;

procedure TParticipantCardServiceTests.
ReadsSavedFieldsIncludingInactiveStage32WithoutCalculation;
var
  R: TCardReadOutcome;
begin
  R := Read;
  try
    AssertEquals(Ord(crsReady), Ord(R.State));
    AssertEquals(123, R.Snapshot.Number);
    AssertEquals('Note', R.Snapshot.Fields[cpfComment].Text);
    AssertEquals('00:07:00.125', R.Snapshot.Fields[cpfSumResult].Text);
    AssertEquals(32, Length(R.Snapshot.Stages));
    AssertFalse(R.Snapshot.Stages[31].Active);
    AssertEquals('-125', R.Snapshot.Stages[31].Values[sfkCorrection].Text);
    AssertFalse(R.Snapshot.Stages[31].Values[sfkPenalty].Empty);
    AssertTrue(R.Snapshot.Stages[31].Values[sfkFinishTime].IsNull);
    AssertFalse(FContext.Transaction.Active);
  finally
    R.Snapshot.Free;
  end;
end;

procedure TParticipantCardServiceTests.IgnoresPendingNumberAndNameAndPreservesEditor;
var
  Q: TSQLQuery;
  R: TCardReadOutcome;
begin
  Q := FContext.CreateQuery(nil);
  try
    FContext.RegisterUiQuery(Q);
    Q.SQL.Text := 'SELECT * FROM main;';
    Q.Open;
    Q.Filter := 'number = 123';
    Q.Filtered := True;
    Q.Edit;
    Q.FieldByName('number').AsInteger := 999;
    Q.FieldByName('name').AsString := 'Pending rider';
    R := Read;
    try
      AssertEquals(Ord(crsReady), Ord(R.State));
      AssertEquals(123, R.Snapshot.Number);
      AssertEquals('Saved rider', R.Snapshot.Fields[cpfName].Text);
      AssertEquals(Ord(dsEdit), Ord(Q.State));
      AssertEquals('Pending rider', Q.FieldByName('name').AsString);
      AssertTrue(FContext.Transaction.Active);
    finally
      R.Snapshot.Free;
    end;
  finally
    Q.Cancel;
    Q.Free;
  end;
end;

procedure TParticipantCardServiceTests.ReadsOnlyCurrentNumberAndKeepsBothMarkKinds;
var
  R: TCardReadOutcome;
begin
  Exec('INSERT INTO start_marks(id,stage_index,applied_stage_index,event_time,' +
    'participant_number,source_kind,source_device_id,received_at,status) VALUES ' +
    '(7,1,9,''10:00:00.000'',123,''ble'',''start-device'',''2026-10-30T10:00:01.000'',''applied'');');
  Exec('INSERT INTO finish_marks(id,stage_index,event_time,participant_number,' +
    'source_kind,received_at,status) VALUES ' +
    '(7,9,''10:07:00.000'',123,''serial'',''2026-10-30T10:07:01.000'',''hidden''),' +
    '(8,9,''10:07:00.000'',NULL,''manual'',''2026-10-30T10:07:02.000'',''pending''),' +
    '(9,9,''10:07:00.000'',999,''manual'',''2026-10-30T10:07:03.000'',''pending'');');
  R := Read;
  try
    AssertEquals(2, Length(R.Snapshot.Marks));
    AssertEquals(Ord(tmkFinish), Ord(R.Snapshot.Marks[0].Key.Kind));
    AssertEquals(7, R.Snapshot.Marks[0].Key.Id);
    AssertEquals('hidden', R.Snapshot.Marks[0].Status);
    AssertEquals(9, R.Snapshot.Marks[1].EffectiveStage);
    AssertEquals(1, R.Snapshot.Marks[1].ReceivedStage);
    AssertEquals('start-device', R.Snapshot.Marks[1].DeviceId);
  finally
    R.Snapshot.Free;
  end;
end;

procedure TParticipantCardServiceTests.RenumberingKeepsIdAndDoesNotClaimOldMarks;
var
  Old, Fresh: TCardReadOutcome;
begin
  Exec('INSERT INTO finish_marks(stage_index,event_time,participant_number,source_kind,'
    +
    'received_at,status) VALUES(1,''10:07:00.000'',123,''manual'',''2026-10-30T10:07:00.000'',''applied'');');
  Old := Read;
  try
    Exec('UPDATE main SET number=321 WHERE id=1;');
    Fresh := Read;
    try
      AssertEquals(1, Fresh.Snapshot.ParticipantId);
      AssertEquals(321, Fresh.Snapshot.Number);
      AssertEquals(0, Length(Fresh.Snapshot.Marks));
      AssertEquals(123, Old.Snapshot.Number);
      AssertEquals(1, Length(Old.Snapshot.Marks));
    finally
      Fresh.Snapshot.Free;
    end;
  finally
    Old.Snapshot.Free;
  end;
end;

procedure TParticipantCardServiceTests.MissingAndChangedSessionHaveDistinctOutcomes;
var
  R: TCardReadOutcome;
  Identity, Generation: QWord;
begin
  R := TParticipantCardService.Read(FContext, FStages, 999);
  AssertEquals(Ord(crsMissing), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  Identity := FContext.Identity;
  Generation := FContext.SessionGeneration;
  FContext.CloseFile;
  FContext.OpenFile(':memory:');
  R := TParticipantCardService.Read(FContext, FStages, 1, Identity, Generation);
  AssertEquals(Ord(crsSessionChanged), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
end;

procedure TParticipantCardServiceTests.BusyWriteDoesNotPublishUncommittedValues;
var
  W: TCompetitionUnitOfWork;
  Q: TSQLQuery;
  R: TCardReadOutcome;
begin
  W := FContext.BeginUnitOfWork;
  Q := FContext.CreateQuery(nil);
  try
    Q.SQL.Text := 'UPDATE main SET name=''Uncommitted''';
    Q.ExecSQL;
    R := Read;
    AssertEquals(Ord(crsBusy), Ord(R.State));
    AssertTrue(R.Snapshot = nil);
    AssertTrue(FContext.UnitOfWorkActive);
  finally
    Q.Free;
    W.Free;
  end;
  R := Read;
  try
    AssertEquals('Saved rider', R.Snapshot.Fields[cpfName].Text);
  finally
    R.Snapshot.Free;
  end;
end;

procedure TParticipantCardServiceTests.ReadFailureReleasesOwnTransactionAndCanRetry;
var
  R: TCardReadOutcome;
begin
  Exec('ALTER TABLE finish_marks RENAME TO missing_finish_marks;');
  R := Read;
  AssertEquals(Ord(crsError), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  AssertTrue(R.ErrorText <> '');
  AssertFalse(FContext.Transaction.Active);
  Exec('ALTER TABLE missing_finish_marks RENAME TO finish_marks;');
  R := Read;
  try
    AssertEquals(Ord(crsReady), Ord(R.State));
  finally
    R.Snapshot.Free;
  end;
end;

procedure TParticipantCardServiceTests.
LargeParticipantJournalKeepsNewestIdsAndBoundedReads;
var
  R: TCardReadOutcome;
begin
  Exec('WITH RECURSIVE n(v) AS (SELECT 1 UNION ALL SELECT v+1 FROM n WHERE v<1000) ' +
    'INSERT INTO finish_marks(stage_index,event_time,participant_number,source_kind,received_at,status) '
    +
    'SELECT 32,''10:00:00.000'',123,''manual'',''2026-10-30T10:00:00.000'',''pending'' FROM n;');
  FContext.Connection.LogEvents := [detActualSQL];
  FContext.Connection.OnLog := @Trace;
  R := Read;
  try
    AssertEquals(Ord(crsReady), Ord(R.State));
    AssertEquals(3, FReads);
    AssertEquals(1000, Length(R.Snapshot.Marks));
    AssertEquals(1000, R.Snapshot.Marks[0].Key.Id);
    AssertEquals(1, R.Snapshot.Marks[999].Key.Id);
    AssertTrue(R.Snapshot.Marks[0].MatchesStage(32, False));
  finally
    R.Snapshot.Free;
  end;
end;

procedure TParticipantCardServiceTests.MaximumStagesAndLargeOtherJournalUseThreeReads;
var
  R: TCardReadOutcome;
begin
  Exec('WITH RECURSIVE n(v) AS (SELECT 1 UNION ALL SELECT v+1 FROM n WHERE v<1000) ' +
    'INSERT INTO finish_marks(stage_index,event_time,participant_number,source_kind,received_at,status) '
    +
    'SELECT 1,''10:00:00.000'',999,''manual'',''2026-10-30T10:00:00.000'',''pending'' FROM n;');
  FContext.Connection.LogEvents := [detActualSQL];
  FContext.Connection.OnLog := @Trace;
  R := Read;
  try
    AssertEquals(Ord(crsReady), Ord(R.State));
    AssertEquals(3, FReads);
    AssertEquals(0, Length(R.Snapshot.Marks));
    R.Snapshot.PreferredStage(9);
    AssertEquals(3, FReads);
  finally
    R.Snapshot.Free;
  end;
end;

initialization
  RegisterTest(TParticipantCardServiceTests);
end.
