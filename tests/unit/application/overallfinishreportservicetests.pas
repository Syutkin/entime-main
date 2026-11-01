unit OverallFinishReportServiceTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry, SQLDB, CompetitionDbContext, StageModel,
  OverallFinishReportService;

type
  TOverallFinishReportServiceTests = class(TTestCase)
  private
    C: TCompetitionDbContext;
    Stages: TStages;
    Reads, Writes: integer;
    MutateStages: boolean;
    procedure Exec(const SQL: string);
    procedure Trace(Sender: TSQLConnection; Event: TDBEventType; const Msg: string);
    function Read: TOverallReportReadOutcome;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SavedCompletedStagesControlPartialOrder;
    procedure ReadsSavedTotalsAndNonconsecutiveStagesWithoutWrites;
    procedure BorrowedTransactionAndPendingEditsRemain;
    procedure BusyNoStagesEmptyAndReadError;
    procedure SessionAndConfigurationChangesInvalidateRead;
    procedure NullEmptyZeroAndSnapshotRemainIndependent;
    procedure ThirtyTwoStagesUseTwoReads;
  end;

implementation

uses SysUtils, DB, CompetitionSchemaMigrator, OverallFinishReportModel;

procedure TOverallFinishReportServiceTests.Exec(const SQL: string);
var
  W: TCompetitionUnitOfWork;
  Q: TSQLQuery;
begin
  W := C.BeginUnitOfWork;
  Q := C.CreateQuery(nil);
  try
    Q.SQL.Text := SQL;
    Q.ExecSQL;
    W.Commit;
  finally
    Q.Free;
    W.Free;
  end;
end;

procedure TOverallFinishReportServiceTests.SetUp;
var
  W: TCompetitionUnitOfWork;
begin
  C := TCompetitionDbContext.Create;
  C.OpenFile(':memory:');
  Stages := TStages.Create(32);
  Stages[3].isActive := True;
  Stages[8].isActive := True;
  W := C.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(C.Connection, 32, 'A', 'B', 'C', 'D', 'E', 'Saved race');
    W.Commit;
  finally
    W.Free;
  end;
  Exec('INSERT INTO main(number,name,category,sumplace,sumresult,sumdiffleader,result1,result3,result8,status3,penalty8) VALUES(123,''Saved'',''A'',5,''00:12:34.567'',''+1 СУ'',''00:01:00.000'',NULL,''00:00:00.000'',''2'',''00:00:00.000'')');
  Exec('INSERT INTO config(key,value) VALUES(''stagename8'',''Saved eight'')');
  Reads := 0;
  Writes := 0;
  MutateStages := False;
  C.Connection.LogEvents := [detActualSQL];
  C.Connection.OnLog := @Trace;
end;

procedure TOverallFinishReportServiceTests.TearDown;
begin
  C.Connection.OnLog := nil;
  Stages.Free;
  C.Free;
end;

procedure TOverallFinishReportServiceTests.Trace(Sender: TSQLConnection;
  Event: TDBEventType; const Msg: string);
var
  S: string;
begin
  if Event <> detActualSQL then Exit;
  S := UpperCase(Trim(Msg));
  if Pos('SELECT ', S) = 1 then
  begin
    Inc(Reads);
    if MutateStages then
    begin
      Stages[1].Name := 'Changed';
      MutateStages := False;
    end;
  end;
  if (Pos('UPDATE ', S) = 1) or (Pos('INSERT ', S) = 1) or (Pos('DELETE ', S) = 1) then
    Inc(Writes);
end;

function TOverallFinishReportServiceTests.Read: TOverallReportReadOutcome;
begin
  Result := TOverallFinishReportService.Read(C, Stages, DefaultOverallReportOptions, 42);
end;

procedure TOverallFinishReportServiceTests.
ReadsSavedTotalsAndNonconsecutiveStagesWithoutWrites;
var
  R: TOverallReportReadOutcome;
begin
  R := Read;
  try
    AssertEquals(Ord(orrReady), Ord(R.State));
    AssertEquals(3, Length(R.Stages));
    AssertEquals(3, R.Stages[1].Index);
    AssertEquals(8, R.Stages[2].Index);
    AssertEquals('Saved eight', R.Stages[2].Name);
    AssertEquals('Saved race', R.Snapshot.RaceName);
    AssertEquals('00:12:34.567', R.Rows[0].ResultValue);
    AssertEquals('5', R.Snapshot.Rows[0].Cells[0]);
    AssertEquals('Saved', R.Snapshot.Rows[0].Cells[2]);
    AssertEquals('DNF', R.Snapshot.Rows[0].Cells[5]);
    AssertEquals('00:00.000', R.Snapshot.Rows[0].Cells[6]);
    AssertEquals(2, Reads);
    AssertEquals(0, Writes);
    AssertFalse(C.Transaction.Active);
  finally
    R.Snapshot.Free;
  end;
end;

procedure TOverallFinishReportServiceTests.BorrowedTransactionAndPendingEditsRemain;
var
  Q: TSQLQuery;
  R: TOverallReportReadOutcome;
begin
  Q := C.CreateQuery(nil);
  try
    C.RegisterUiQuery(Q);
    Q.SQL.Text := 'SELECT * FROM main';
    Q.Open;
    Q.Edit;
    Q.FieldByName('name').AsString := 'Pending';
    R := Read;
    try
      AssertEquals(Ord(orrReady), Ord(R.State));
      AssertEquals('Saved', R.Rows[0].Name);
      AssertTrue(Q.State = dsEdit);
      AssertEquals('Pending', Q.FieldByName('name').AsString);
      AssertTrue(C.Transaction.Active);
      AssertEquals(0, Writes);
    finally
      R.Snapshot.Free;
    end;
  finally
    Q.Cancel;
    Q.Free;
  end;
end;

procedure TOverallFinishReportServiceTests.BusyNoStagesEmptyAndReadError;
var
  W: TCompetitionUnitOfWork;
  R: TOverallReportReadOutcome;
  I: integer;
begin
  W := C.BeginUnitOfWork;
  try
    R := Read;
    AssertEquals(Ord(orrBusy), Ord(R.State));
    AssertTrue(R.Snapshot = nil);
  finally
    W.Free;
  end;
  for I := 1 to Stages.Count do Stages[I].isActive := False;
  R := Read;
  AssertEquals(Ord(orrNoStages), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  Stages[1].isActive := True;
  Exec('ALTER TABLE main RENAME TO absent_main');
  R := Read;
  AssertEquals(Ord(orrError), Ord(R.State));
  AssertFalse(C.Transaction.Active);
  AssertTrue(R.Snapshot = nil);
  Exec('ALTER TABLE absent_main RENAME TO main');
  Exec('DELETE FROM main');
  R := Read;
  AssertEquals(Ord(orrEmpty), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
end;

procedure TOverallFinishReportServiceTests.SessionAndConfigurationChangesInvalidateRead;
var
  R: TOverallReportReadOutcome;
  Identity, Generation: QWord;
begin
  MutateStages := True;
  R := Read;
  AssertEquals(Ord(orrSessionChanged), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  Identity := C.Identity;
  Generation := C.SessionGeneration;
  C.CloseFile;
  C.OpenFile(':memory:');
  R := TOverallFinishReportService.Read(C, Stages, DefaultOverallReportOptions,
    42, Identity, Generation);
  AssertEquals(Ord(orrSessionChanged), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
end;

procedure TOverallFinishReportServiceTests.NullEmptyZeroAndSnapshotRemainIndependent;
var
  R, Fresh: TOverallReportReadOutcome;
begin
  R := Read;
  try
    Exec('UPDATE main SET result1=NULL,result3='''',result8=''0'',sumresult=''00:00:00.000'',sumplace=0');
    Fresh := Read;
    try
      AssertEquals('', Fresh.Rows[0].Stages[0].ResultValue);
      AssertEquals('', Fresh.Rows[0].Stages[1].ResultValue);
      AssertEquals('0', Fresh.Rows[0].Stages[2].ResultValue);
      AssertEquals('0', Fresh.Snapshot.Rows[0].Cells[0]);
      AssertEquals('5', R.Snapshot.Rows[0].Cells[0]);
    finally
      Fresh.Snapshot.Free;
    end;
  finally
    R.Snapshot.Free;
  end;
end;

procedure TOverallFinishReportServiceTests.ThirtyTwoStagesUseTwoReads;
var
  I: integer;
  R: TOverallReportReadOutcome;
begin
  for I := 1 to 32 do Stages[I].isActive := True;
  R := Read;
  try
    AssertEquals(32, Length(R.Stages));
    AssertEquals(2, Reads);
  finally
    R.Snapshot.Free;
  end;
end;

procedure TOverallFinishReportServiceTests.SavedCompletedStagesControlPartialOrder;
var
  R: TOverallReportReadOutcome;
begin
  Exec('UPDATE main SET sumplace=NULL,sumstages=2,sumdiffleader=''+1 СУ'' WHERE number=123');
  Exec('INSERT INTO main(number,name,category,sumresult,sumstages,sumdiffleader) VALUES(9,''Partial'',''A'',''00:01:00.000'',1,''+2 СУ'')');
  Writes := 0;
  R := Read;
  try
    AssertEquals(Ord(orrReady), Ord(R.State));
    AssertEquals('2', R.Rows[0].CompletedStages);
    AssertEquals(123, R.Snapshot.Rows[0].Number);
    AssertEquals('+1 СУ', R.Snapshot.Rows[0].Cells[High(R.Snapshot.Columns)]);
    AssertEquals(0, Writes);
    AssertEquals(2, Reads);
  finally
    R.Snapshot.Free;
  end;
end;

initialization
  RegisterTest(TOverallFinishReportServiceTests);
end.
