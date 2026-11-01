unit StartLabelServiceTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry, SQLDB, CompetitionDbContext, StageModel;

type
  TStartLabelServiceTests = class(TTestCase)
  private
    C: TCompetitionDbContext;
    Stages: TStages;
    Reads, Writes: integer;
    ChangeStage: boolean;
    procedure Exec(const SQL: string);
    procedure Trace(Sender: TSQLConnection; Event: TDBEventType; const Msg: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure AllSavedRidersAndActiveStartsUseTwoQueries;
    procedure BorrowedTransactionAndPendingEditStayUntouched;
    procedure BusyEmptyNoStagesAndClosedSession;
    procedure ConfigurationChangeInvalidatesRead;
  end;

implementation

uses SysUtils, DB, StartLabelService, ProtocolDocumentModel, CompetitionSchemaMigrator;

procedure TStartLabelServiceTests.Exec(const SQL: string);
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

procedure TStartLabelServiceTests.SetUp;
var
  W: TCompetitionUnitOfWork;
begin
  C := TCompetitionDbContext.Create;
  C.OpenFile(':memory:');
  Stages := TStages.Create(32);
  Stages[3].isActive := True;
  Stages[32].isActive := True;
  W := C.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(C.Connection, 32, 'A', 'B', 'C', 'D', 'E', 'Race');
    W.Commit;
  finally
    W.Free;
  end;
  Exec('INSERT INTO main(number,name,status,starttime1,starttime3,starttime32) VALUES(123,''First'',''3'',''00:00:00.000'',NULL,''09:00:00.123''),(9,''Second'',''0'','''',''0'',NULL)');
  Reads := 0;
  Writes := 0;
  ChangeStage := False;
  C.Connection.LogEvents := [detActualSQL];
  C.Connection.OnLog := @Trace;
end;

procedure TStartLabelServiceTests.TearDown;
begin
  C.Connection.OnLog := nil;
  Stages.Free;
  C.Free;
end;

procedure TStartLabelServiceTests.Trace(Sender: TSQLConnection;
  Event: TDBEventType; const Msg: string);
var
  S: string;
begin
  S := UpperCase(Trim(Msg));
  if Pos('SELECT ', S) = 1 then
  begin
    Inc(Reads);
    if ChangeStage then
    begin
      ChangeStage := False;
      Stages[1].Name := 'Changed';
    end;
  end;
  if (Pos('UPDATE ', S) = 1) or (Pos('INSERT ', S) = 1) or (Pos('DELETE ', S) = 1) then
    Inc(Writes);
end;

procedure TStartLabelServiceTests.AllSavedRidersAndActiveStartsUseTwoQueries;
var
  R: TStartLabelReadOutcome;
begin
  R := TStartLabelService.Read(C, Stages, 42);
  AssertEquals(Ord(prsReady), Ord(R.State));
  AssertEquals(2, Length(R.Cards));
  AssertEquals(9, R.Cards[0].Number);
  AssertEquals(3, Length(R.Cards[0].Entries));
  AssertEquals(32, R.Cards[0].Entries[2].StageIndex);
  AssertEquals('—', R.Cards[0].Entries[0].Time);
  AssertEquals('0', R.Cards[0].Entries[1].Time);
  AssertEquals('00:00:00.000', R.Cards[1].Entries[0].Time);
  AssertEquals('09:00:00.123', R.Cards[1].Entries[2].Time);
  AssertEquals(2, Reads);
  AssertEquals(0, Writes);
  AssertFalse(C.Transaction.Active);
  AssertEquals(C.Identity, R.ContextIdentity);
  AssertEquals(42.0, R.FormedAt);
end;

procedure TStartLabelServiceTests.BorrowedTransactionAndPendingEditStayUntouched;
var
  Q: TSQLQuery;
  R: TStartLabelReadOutcome;
begin
  Q := C.CreateQuery(nil);
  try
    C.RegisterUiQuery(Q);
    Q.SQL.Text := 'SELECT * FROM main';
    Q.Open;
    Q.Edit;
    Q.FieldByName('name').AsString := 'Pending';
    R := TStartLabelService.Read(C, Stages, 42);
    AssertEquals(Ord(prsReady), Ord(R.State));
    AssertEquals(2, Length(R.Cards));
    AssertEquals('123 First', R.Cards[1].Title);
    AssertTrue(Q.State = dsEdit);
    AssertEquals('Pending', Q.FieldByName('name').AsString);
    AssertTrue(C.Transaction.Active);
    AssertEquals(0, Writes);
    Q.Cancel;
  finally
    Q.Free;
  end;
end;

procedure TStartLabelServiceTests.BusyEmptyNoStagesAndClosedSession;
var
  R: TStartLabelReadOutcome;
  W: TCompetitionUnitOfWork;
  I: integer;
  Identity, Generation: QWord;
begin
  W := C.BeginUnitOfWork;
  try
    R := TStartLabelService.Read(C, Stages, 42);
    AssertEquals(Ord(prsBusy), Ord(R.State));
  finally
    W.Free;
  end;
  for I := 1 to 32 do Stages[I].isActive := False;
  R := TStartLabelService.Read(C, Stages, 42);
  AssertEquals(Ord(prsNoStages), Ord(R.State));
  Stages[1].isActive := True;
  Exec('DELETE FROM main');
  R := TStartLabelService.Read(C, Stages, 42);
  AssertEquals(Ord(prsEmpty), Ord(R.State));
  Exec('ALTER TABLE main RENAME TO missing_main');
  R := TStartLabelService.Read(C, Stages, 42);
  AssertEquals(Ord(prsError), Ord(R.State));
  AssertEquals(0, Length(R.Cards));
  AssertFalse(C.Transaction.Active);
  Identity := C.Identity;
  Generation := C.SessionGeneration;
  C.CloseFile;
  C.OpenFile(':memory:');
  R := TStartLabelService.Read(C, Stages, 42, Identity, Generation);
  AssertEquals(Ord(prsSessionChanged), Ord(R.State));
  AssertEquals(0, Length(R.Cards));
end;

procedure TStartLabelServiceTests.ConfigurationChangeInvalidatesRead;
var
  R: TStartLabelReadOutcome;
  I: integer;
begin
  ChangeStage := True;
  R := TStartLabelService.Read(C, Stages, 42);
  AssertEquals(Ord(prsSessionChanged), Ord(R.State));
  AssertEquals(0, Length(R.Cards));
  for I := 1 to 32 do Stages[I].isActive := True;
  Reads := 0;
  R := TStartLabelService.Read(C, Stages, 42);
  AssertEquals(Ord(prsReady), Ord(R.State));
  AssertEquals(32, Length(R.Cards[0].Entries));
  AssertEquals(2, Reads);
end;

initialization
  RegisterTest(TStartLabelServiceTests);
end.
