unit StageFinishReportServiceTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, DB, SQLDB, fpcunit, testregistry, CompetitionDbContext,
  CompetitionSchemaMigrator, StageModel, StageFinishReportModel, StageFinishReportService;

type
  TStageFinishReportServiceTests = class(TTestCase)
  private
    C: TCompetitionDbContext;
    Stages: TStages;
    Reads, Writes: integer;
    procedure Exec(const Sql: string);
    procedure Trace(Sender: TSQLConnection; Event: TDBEventType; const Msg: string);
    function Read(Index: integer): TStageReportReadOutcome;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ReadsOnlyChosenSavedStageAndConfiguration;
    procedure PendingRowsAndFiltersDoNotAffectSnapshot;
    procedure BusyEmptySessionAndReadErrors;
    procedure SelectedCategoriesAndOldSnapshotRemainIndependent;
  end;

implementation

procedure TStageFinishReportServiceTests.Exec(const Sql: string);
var
  W: TCompetitionUnitOfWork;
  Q: TSQLQuery;
begin
  W := C.BeginUnitOfWork;
  Q := C.CreateQuery(nil);
  try
    Q.SQL.Text := Sql;
    Q.ExecSQL;
    W.Commit;
  finally
    Q.Free;
    W.Free;
  end;
end;

procedure TStageFinishReportServiceTests.SetUp;
var
  W: TCompetitionUnitOfWork;
begin
  C := TCompetitionDbContext.Create;
  C.OpenFile(':memory:');
  Stages := TStages.Create(32);
  W := C.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(C.Connection, 32, 'A', 'B', 'C', 'D', 'E', 'Saved race');
    W.Commit;
  finally
    W.Free;
  end;
  Exec('INSERT INTO main(id,number,name,category,result1,place1,result9,place9,result32,place32,sumresult,sumplace) VALUES '
    + '(1,123,''Saved rider'',''A'',''00:01:00.123'',2,''01:02:03.456'',1,''00:00:00.000'',3,''09:09:09.999'',99),'
    +
    '(2,9,''Other'',''a'',''00:02:00.000'',1,NULL,NULL,NULL,NULL,NULL,NULL);');
  Exec('INSERT INTO config(key,value) VALUES(''stagename32'',''Saved stage'');');
  Reads := 0;
  Writes := 0;
  C.Connection.LogEvents := [detActualSQL];
  C.Connection.OnLog := @Trace;
end;

procedure TStageFinishReportServiceTests.TearDown;
begin
  C.Connection.OnLog := nil;
  Stages.Free;
  C.Free;
end;

procedure TStageFinishReportServiceTests.Trace(Sender: TSQLConnection;
  Event: TDBEventType; const Msg: string);
var
  S: string;
begin
  S := UpperCase(Trim(Msg));
  if Event <> detActualSQL then Exit;
  if Pos('SELECT ', S) = 1 then Inc(Reads);
  if (Pos('UPDATE ', S) = 1) or (Pos('INSERT ', S) = 1) or (Pos('DELETE ', S) = 1) then
    Inc(Writes);
end;

function TStageFinishReportServiceTests.Read(Index: integer): TStageReportReadOutcome;
var
  O: TStageReportOptions;
begin
  O := DefaultReportOptions;
  O.StageIndex := Index;
  Result := TStageFinishReportService.Read(C, Stages, O, EncodeDate(2026, 10, 31));
end;

procedure TStageFinishReportServiceTests.ReadsOnlyChosenSavedStageAndConfiguration;
var
  R: TStageReportReadOutcome;
  I, J: integer;
  Expected: array[0..2] of string = ('01:00.123', '01:02:03.456', '00:00.000');
begin
  Stages[32].Name := 'Pending stage name';
  for I := 0 to 2 do
  begin
    case I of
      0: R := Read(1);
      1: R := Read(9);
      2: R := Read(32);
    end;
    try
      AssertEquals(Ord(srrReady), Ord(R.State));
      J := 0;
      while (J < Length(R.Snapshot.Rows)) and (R.Snapshot.Rows[J].Number <> 123) do Inc(J);
      AssertTrue(J < Length(R.Snapshot.Rows));
      AssertEquals(Expected[I], R.Snapshot.Rows[J].Cells[rcResult]);
      AssertEquals('Saved race', R.Snapshot.RaceName);
      if I = 2 then AssertEquals('Saved stage', R.Snapshot.StageName);
      AssertEquals(EncodeDate(2026, 10, 31), R.Snapshot.FormedAt);
    finally
      R.Snapshot.Free;
    end;
  end;
  AssertEquals(6, Reads);
  AssertEquals(0, Writes);
  AssertFalse(C.Transaction.Active);
end;

procedure TStageFinishReportServiceTests.PendingRowsAndFiltersDoNotAffectSnapshot;
var
  Q: TSQLQuery;
  R: TStageReportReadOutcome;
begin
  Q := C.CreateQuery(nil);
  try
    C.RegisterUiQuery(Q);
    Q.SQL.Text := 'SELECT * FROM main ORDER BY number DESC';
    Q.Open;
    Q.Edit;
    Q.FieldByName('name').AsString := 'Pending first';
    Q.Post;
    Q.Next;
    Q.Edit;
    Q.FieldByName('name').AsString := 'Pending second';
    Q.Filter := 'number = 9'; // Do not activate a filter while editing: that itself posts.
    R := Read(32);
    try
      AssertEquals(Ord(srrReady), Ord(R.State));
      AssertEquals('Saved rider', R.Snapshot.Rows[0].Name);
      AssertEquals(Ord(dsEdit), Ord(Q.State));
      AssertEquals('Pending second', Q.FieldByName('name').AsString);
      AssertTrue(Q.ChangeCount > 0);
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

procedure TStageFinishReportServiceTests.BusyEmptySessionAndReadErrors;
var
  W: TCompetitionUnitOfWork;
  R: TStageReportReadOutcome;
  O: TStageReportOptions;
  Identity, Generation: QWord;
begin
  W := C.BeginUnitOfWork;
  try
    R := Read(1);
    AssertEquals(Ord(srrBusy), Ord(R.State));
    AssertTrue(R.Snapshot = nil);
  finally
    W.Free;
  end;
  Exec('ALTER TABLE main RENAME TO absent_main');
  R := Read(1);
  AssertEquals(Ord(srrError), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  AssertFalse(C.Transaction.Active);
  Exec('ALTER TABLE absent_main RENAME TO main');
  Exec('DELETE FROM main');
  R := Read(1);
  AssertEquals(Ord(srrEmpty), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
  Identity := C.Identity;
  Generation := C.SessionGeneration;
  C.CloseFile;
  C.OpenFile(':memory:');
  O := DefaultReportOptions;
  R := TStageFinishReportService.Read(C, Stages, O, Now, Identity, Generation);
  AssertEquals(Ord(srrSessionChanged), Ord(R.State));
  AssertTrue(R.Snapshot = nil);
end;

procedure TStageFinishReportServiceTests.
SelectedCategoriesAndOldSnapshotRemainIndependent;
var
  O: TStageReportOptions;
  Old, Fresh: TStageReportReadOutcome;
begin
  O := DefaultReportOptions;
  O.StageIndex := 32;
  O.AllCategories := False;
  SetLength(O.Categories, 1);
  O.Categories[0] := 'A';
  Old := TStageFinishReportService.Read(C, Stages, O, 10);
  try
    AssertEquals(1, Length(Old.Snapshot.Rows));
    O.Categories[0] := 'a';
    Exec('UPDATE main SET name=''New rider'' WHERE number=123');
    Fresh := Read(32);
    try
      AssertEquals('Saved rider', Old.Snapshot.Rows[0].Name);
      AssertEquals('A', Old.Snapshot.Options.Categories[0]);
      AssertEquals('New rider', Fresh.Snapshot.Rows[0].Name);
    finally
      Fresh.Snapshot.Free;
    end;
  finally
    Old.Snapshot.Free;
  end;
end;

initialization
  RegisterTest(TStageFinishReportServiceTests);
end.
