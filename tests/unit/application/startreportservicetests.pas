unit StartReportServiceTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry, SQLDB, CompetitionDbContext, StageModel, StartReportService;

type
  TStartReportServiceTests = class(TTestCase)
  private
    C: TCompetitionDbContext;
    Stages: TStages;
    Reads, Writes: integer;
    ChangeStages: boolean;
    procedure Exec(const SQL: string);
    procedure Trace(Sender: TSQLConnection; Event: TDBEventType; const Msg: string);
    function Read: TStartReportReadOutcome;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure AllSingleStagesUseOneReadSnapshot;
    procedure SavedClocksAndOnlyActiveStagesAreRead;
    procedure SingleAndSortStagesMustBeActive;
    procedure BorrowedTransactionAndPendingInputRemain;
    procedure BusyNoActiveStagesEmptyAndReadError;
    procedure SessionAndConfigurationChangesInvalidate;
    procedure NullEmptyAndZeroAreNotMixed;
    procedure ThirtyTwoStagesStillUseTwoQueries;
  end;

implementation

uses SysUtils, DB, ProtocolDocumentModel, StartReportModel, CompetitionSchemaMigrator;

procedure TStartReportServiceTests.Exec(const SQL: string);
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

procedure TStartReportServiceTests.SetUp;
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
  Exec('INSERT INTO main(number,name,category,status,starttime1,starttime2,starttime3,starttime8) VALUES(123,''Saved'',''A'',''3'',''09:00:00'',''19:00:00'',''00:00:00.123'',''11:00:00'')');
  Exec('INSERT INTO config(key,value) VALUES(''stagename8'',''Saved eight'')');
  Reads := 0;
  Writes := 0;
  ChangeStages := False;
  C.Connection.LogEvents := [detActualSQL];
  C.Connection.OnLog := @Trace;
end;

procedure TStartReportServiceTests.TearDown;
begin
  C.Connection.OnLog := nil;
  Stages.Free;
  C.Free;
end;

procedure TStartReportServiceTests.Trace(Sender: TSQLConnection;
  Event: TDBEventType; const Msg: string);
var
  S: string;
begin
  if Event <> detActualSQL then Exit;
  S := UpperCase(Trim(Msg));
  if Pos('SELECT ', S) = 1 then
  begin
    Inc(Reads);
    if ChangeStages then
    begin
      Stages[1].Name := 'Changed';
      ChangeStages := False;
    end;
  end;
  if (Pos('UPDATE ', S) = 1) or (Pos('INSERT ', S) = 1) or (Pos('DELETE ', S) = 1) then
    Inc(Writes);
end;

function TStartReportServiceTests.Read: TStartReportReadOutcome;
begin
  Result := TStartReportService.Read(C, Stages, DefaultStartReportOptions, 42);
end;

procedure TStartReportServiceTests.AllSingleStagesUseOneReadSnapshot;
var
  O: TStartReportOptions;
  R: TStartReportReadOutcome;
begin
  O := DefaultStartReportOptions;
  O.Mode := srmSingleStage;
  O.AllSingleStages := True;
  O.View.StageIndex := 0;
  R := TStartReportService.Read(C, Stages, O, 42);
  try
    AssertEquals(Ord(prsReady), Ord(R.State));
    AssertEquals(3, Length(R.Stages));
    AssertEquals(3, Length(R.Snapshot.Sections));
    AssertEquals('00:00:00.123', R.Snapshot.Sections[1].Rows[0].Cells[3]);
    AssertEquals(2, Reads);
    AssertEquals(0, Writes);
  finally
    R.Snapshot.Free;
  end;
end;

procedure TStartReportServiceTests.SavedClocksAndOnlyActiveStagesAreRead;
var
  R: TStartReportReadOutcome;
begin
  R := Read;
  try
    AssertEquals(Ord(prsReady), Ord(R.State));
    AssertEquals(3, Length(R.Stages));
    AssertEquals(3, R.Stages[1].Index);
    AssertEquals(8, R.Stages[2].Index);
    AssertEquals('Saved eight', R.Stages[2].Name);
    AssertEquals('Saved race', R.Snapshot.RaceName);
    AssertEquals('09:00:00', R.Snapshot.Rows[0].Cells[3]);
    AssertEquals('00:00:00.123', R.Snapshot.Rows[0].Cells[4]);
    AssertEquals(2, Reads);
    AssertEquals(0, Writes);
    AssertFalse(C.Transaction.Active);
  finally
    R.Snapshot.Free;
  end;
end;

procedure TStartReportServiceTests.SingleAndSortStagesMustBeActive;
var
  O: TStartReportOptions;
  R: TStartReportReadOutcome;
begin
  O := DefaultStartReportOptions;
  O.Mode := srmSingleStage;
  O.View.StageIndex := 2;
  R := TStartReportService.Read(C, Stages, O, 42);
  AssertEquals(Ord(prsError), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  AssertEquals(0, Reads);
  O.View.StageIndex := 8;
  R := TStartReportService.Read(C, Stages, O, 42);
  try
    AssertEquals(Ord(prsReady), Ord(R.State));
    AssertEquals(1, Length(R.Stages));
    AssertEquals('11:00:00', R.Snapshot.Rows[0].Cells[3]);
  finally
    R.Snapshot.Free;
  end;
  O.Mode := srmAllStages;
  O.Order := sroNumber;
  O.SortStageIndex := 2;
  R := TStartReportService.Read(C, Stages, O, 42);
  try
    AssertEquals(Ord(prsReady), Ord(R.State));
  finally
    R.Snapshot.Free;
  end;
  O.Order := sroTime;
  R := TStartReportService.Read(C, Stages, O, 42);
  AssertEquals(Ord(prsError), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
end;

procedure TStartReportServiceTests.BorrowedTransactionAndPendingInputRemain;
var
  Q: TSQLQuery;
  R: TStartReportReadOutcome;
begin
  Q := C.CreateQuery(nil);
  try
    C.RegisterUiQuery(Q);
    Q.SQL.Text := 'SELECT * FROM main';
    Q.Open;
    Q.Edit;
    Q.FieldByName('starttime1').AsString := 'Pending';
    R := Read;
    try
      AssertEquals(Ord(prsReady), Ord(R.State));
      AssertEquals('09:00:00', R.Rows[0].Starts[0]);
      AssertTrue(Q.State = dsEdit);
      AssertEquals('Pending', Q.FieldByName('starttime1').AsString);
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

procedure TStartReportServiceTests.BusyNoActiveStagesEmptyAndReadError;
var
  W: TCompetitionUnitOfWork;
  R: TStartReportReadOutcome;
  O: TStartReportOptions;
  I: integer;
begin
  W := C.BeginUnitOfWork;
  try
    R := Read;
    AssertEquals(Ord(prsBusy), Ord(R.State));
    AssertTrue(R.Snapshot = nil);
  finally
    W.Free;
  end;
  for I := 1 to 32 do Stages[I].isActive := False;
  R := Read;
  AssertEquals(Ord(prsNoStages), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  O := DefaultStartReportOptions;
  O.Mode := srmSingleStage;
  R := TStartReportService.Read(C, Stages, O, 42);
  AssertEquals(Ord(prsNoStages), Ord(R.State));
  Stages[1].isActive := True;
  Exec('ALTER TABLE main RENAME TO absent_main');
  R := Read;
  AssertEquals(Ord(prsError), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  AssertFalse(C.Transaction.Active);
  Exec('ALTER TABLE absent_main RENAME TO main');
  Exec('DELETE FROM main');
  R := Read;
  AssertEquals(Ord(prsEmpty), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
end;

procedure TStartReportServiceTests.SessionAndConfigurationChangesInvalidate;
var
  R: TStartReportReadOutcome;
  Identity, Generation: QWord;
begin
  ChangeStages := True;
  R := Read;
  AssertEquals(Ord(prsSessionChanged), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  Identity := C.Identity;
  Generation := C.SessionGeneration;
  C.CloseFile;
  C.OpenFile(':memory:');
  R := TStartReportService.Read(C, Stages, DefaultStartReportOptions,
    42, Identity, Generation);
  AssertEquals(Ord(prsSessionChanged), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
end;

procedure TStartReportServiceTests.NullEmptyAndZeroAreNotMixed;
var
  Old, Fresh: TStartReportReadOutcome;
begin
  Old := Read;
  try
    Exec('UPDATE main SET starttime1=NULL,starttime3='''',starttime8=''0''');
    Fresh := Read;
    try
      AssertEquals('—', Fresh.Snapshot.Rows[0].Cells[3]);
      AssertEquals('—', Fresh.Snapshot.Rows[0].Cells[4]);
      AssertEquals('0', Fresh.Snapshot.Rows[0].Cells[5]);
      AssertEquals('09:00:00', Old.Snapshot.Rows[0].Cells[3]);
    finally
      Fresh.Snapshot.Free;
    end;
  finally
    Old.Snapshot.Free;
  end;
end;

procedure TStartReportServiceTests.ThirtyTwoStagesStillUseTwoQueries;
var
  I: integer;
  R: TStartReportReadOutcome;
begin
  for I := 1 to 32 do Stages[I].isActive := True;
  R := Read;
  try
    AssertEquals(32, Length(R.Stages));
    AssertEquals(2, Reads);
    AssertEquals(0, Writes);
  finally
    R.Snapshot.Free;
  end;
end;

initialization
  RegisterTest(TStartReportServiceTests);
end.
