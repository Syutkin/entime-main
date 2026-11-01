unit ResultsImportPreviewServiceTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, DB, SQLDB, fpcunit, testregistry, DbSql, StageModel,
  CompetitionImportService, ResultsImportComparison, ResultsImportPreviewService,
  CompetitionResultsService;

type
  TResultsImportPreviewServiceTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FStages: TStages;
    FPlan: TResultsImportPlan;
    FSnapshotReads: integer;
    procedure TraceSnapshotSql(Sender: TSQLConnection; EventType: TDBEventType;
      const Msg: string);
    procedure Exec(const ASql: string);
    procedure Plan(const ACsv: string);
    function ReadValue(const AColumn: string;
      const ANumber: integer = 101): TImportValue;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Build_ReadsSavedFieldsAndSelectsOnlyFills;
    procedure SaveEditor_CalculationFailureKeepsPendingRowsForRetry;
    procedure Build_ThousandParticipantsUsesOneSnapshotRead;
    procedure Build_FormatsIncludeTheirImplicitStatus;
    procedure Build_IgnoresUiFilterAndPreservesPendingEdit;
    procedure Build_RejectsUnfinishedWrite;
    procedure Build_ErrorReleasesReadTransactionAndAllowsRetry;
    procedure Build_ReopeningEvenTheSameFileInvalidatesSession;
    procedure Apply_ChangesOnlySelectedFieldsAndKeepsOtherStages;
    procedure Apply_StaleSelectedValueRejectsAllChanges;
    procedure Apply_AllowsChangesToUnselectedFields;
    procedure Apply_CreatesOnlyConfirmedNumbersIncludingNumberOnly;
    procedure Apply_CalculationFailureRollsBackCreationAndAllowsRetry;
    procedure Apply_RequiresBackupButEmptySelectionDoesNothing;
    procedure Apply_RejectsChangedIdentityConfigurationAndSession;
  end;

implementation

procedure TResultsImportPreviewServiceTests.SetUp;
var
  Work: TCompetitionUnitOfWork;
begin
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FStages := TStages.Create(9);
  FStages[2].isActive := True;
  FStages[9].isActive := True;
  Work := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, 9, 'A', 'B', 'C', 'D', 'E', 'Preview');
    Work.Commit;
  finally
    Work.Free;
  end;
  Exec('INSERT INTO main (number, name, starttime2, penalty2, status2) ' +
    'VALUES (101, ''Saved name'', ''10:00:00'', ''00:00:05'', ''2'');');
end;

procedure TResultsImportPreviewServiceTests.TearDown;
begin
  FPlan.Free;
  FStages.Free;
  FContext.Free;
end;

procedure TResultsImportPreviewServiceTests.Exec(const ASql: string);
var
  Q: TSQLQuery;
  Work: TCompetitionUnitOfWork;
begin
  Q := FContext.CreateQuery(nil);
  Work := FContext.BeginUnitOfWork;
  try
    Q.SQL.Text := ASql;
    Q.ExecSQL;
    Work.Commit;
  finally
    Work.Free;
    Q.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.Plan(const ACsv: string);
var
  FileName: string;
  Lines: TStringList;
begin
  FreeAndNil(FPlan);
  FileName := GetTempFileName(GetTempDir(False), 'preview-');
  Lines := TStringList.Create;
  try
    Lines.Text := ACsv;
    Lines.SaveToFile(FileName);
    FPlan := TCompetitionImportService.PrepareResultsFile(FileName);
  finally
    Lines.Free;
    DeleteFile(FileName);
  end;
end;

procedure TResultsImportPreviewServiceTests.
SaveEditor_CalculationFailureKeepsPendingRowsForRetry;
var
  Q: TSQLQuery;
begin
  Exec('INSERT INTO main(number, name) VALUES(102, ''Other'');');
  Exec('CREATE TRIGGER reject_editor_calc BEFORE UPDATE OF result2 ON main ' +
    'BEGIN SELECT RAISE(ABORT, ''forced editor calculation failure''); END;');
  Q := FContext.CreateQuery(nil);
  try
    FContext.RegisterUiQuery(Q);
    Q.SQL.Text := 'SELECT id, number, name FROM main ORDER BY number;';
    Q.UpdateSQL.Text := 'UPDATE main SET name = :name WHERE id = :OLD_id';
    Q.Open;
    Q.Edit;
    Q.FieldByName('name').AsString := 'Pending first';
    Q.Post;
    Q.Next;
    Q.Edit;
    Q.FieldByName('name').AsString := 'Pending second';
    try
      TParticipantEditService.ApplyChangesKeepingInput(FContext, Q, FStages);
      Fail('Expected calculation failure');
    except
      on E: EDatabaseError do
        AssertTrue(Pos('forced editor calculation failure', E.Message) > 0);
    end;
    AssertEquals(2, Q.ChangeCount);
    AssertEquals('Pending second', Q.FieldByName('name').AsString);
    Q.First;
    AssertEquals('Pending first', Q.FieldByName('name').AsString);
    AssertEquals('Saved name', ReadValue('name').Text);
    Exec('DROP TRIGGER reject_editor_calc;');
    TParticipantEditService.ApplyChangesKeepingInput(FContext, Q, FStages);
    AssertEquals(0, Q.ChangeCount);
    AssertEquals('Pending first', ReadValue('name').Text);
    AssertEquals('Pending second', ReadValue('name', 102).Text);
  finally
    Q.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.TraceSnapshotSql(Sender: TSQLConnection;
  EventType: TDBEventType; const Msg: string);
begin
  if (EventType = detActualSQL) and
    (Pos(' FROM MAIN ORDER BY NUMBER', UpperCase(Msg)) > 0) then Inc(FSnapshotReads);
end;

procedure TResultsImportPreviewServiceTests.
Build_ThousandParticipantsUsesOneSnapshotRead;
var
  C: TResultsImportComparison;
  Csv: TStringList;
  I: integer;
begin
  Exec('WITH RECURSIVE numbers(n) AS (SELECT 1001 UNION ALL SELECT n + 1 ' +
    'FROM numbers WHERE n < 2000) INSERT INTO main(number, starttime2) ' +
    'SELECT n, ''10:00:00'' FROM numbers;');
  Csv := TStringList.Create;
  try
    for I := 1001 to 2000 do Csv.Add(IntToStr(I) + ';11:00:00');
    Plan(Csv.Text);
  finally
    Csv.Free;
  end;
  FContext.Connection.LogEvents := [detActualSQL];
  FContext.Connection.OnLog := @TraceSnapshotSql;
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    AssertEquals(1000, C.Count);
    AssertEquals(1000, C.SelectedFieldCount);
    AssertEquals(1, FSnapshotReads);
    C.ClearSelection;
    C.SelectAll;
    AssertEquals('Selection does not reread SQLite', 1, FSnapshotReads);
    AssertFalse(FContext.Transaction.Active);
  finally
    C.Free;
    FContext.Connection.OnLog := nil;
    FContext.Connection.LogEvents := [];
  end;
end;

procedure TResultsImportPreviewServiceTests.Build_ReadsSavedFieldsAndSelectsOnlyFills;
var
  C: TResultsImportComparison;
begin
  Plan('101;10:00:00.000;0;11:00:00;;' + LineEnding + '102;;;;;');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    AssertEquals(2, C.Count);
    AssertEquals('Saved name', C[0].Name);
    AssertTrue(C[0].Id > 0);
    AssertTrue(C[0].Selected = [ifCorrection, ifFinish]);
    AssertEquals(Ord(ickClear), Ord(C[0].Kind(ifStatus)));
    AssertEquals(Ord(ickSame), Ord(C[0].Kind(ifStart)));
    AssertEquals(0, C[1].Id);
    AssertFalse(C[1].CreateSelected);
    AssertFalse(FContext.Transaction.Active);
  finally
    C.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.Build_FormatsIncludeTheirImplicitStatus;
var
  C: TResultsImportComparison;
begin
  Plan('101;DNF');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 9);
  try
    AssertEquals(9, C.StageIndex);
    AssertTrue(C[0].Fields = [ifFinish, ifStatus]);
    AssertEquals('2', C[0].Proposed[ifStatus].Text);
    AssertEquals(1, C[0].SourceRow);
  finally
    C.Free;
  end;
  Plan('101;10:00:00;DNS');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    AssertTrue(C[0].Fields = [ifStart, ifCorrection, ifStatus]);
    AssertTrue(C[0].Proposed[ifCorrection].IsNull);
    AssertEquals('1', C[0].Proposed[ifStatus].Text);
  finally
    C.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.Build_IgnoresUiFilterAndPreservesPendingEdit;
var
  C: TResultsImportComparison;
  Q: TSQLQuery;
begin
  Q := FContext.CreateQuery(nil);
  try
    FContext.RegisterUiQuery(Q);
    Q.SQL.Text := 'SELECT * FROM main;';
    FContext.ConfigureEditableQuery(Q, 'main', 'id');
    Q.Open;
    Q.Filter := 'number = 101';
    Q.Filtered := True;
    Q.Edit;
    Q.FieldByName('name').AsString := 'Unsaved name';
    Plan('101;11:00:00');
    C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
    try
      AssertEquals('Saved name', C[0].Name);
      AssertEquals(Ord(dsEdit), Ord(Q.State));
      AssertEquals('Unsaved name', Q.FieldByName('name').AsString);
      AssertTrue(Q.Filtered);
    finally
      C.Free;
    end;
    Q.Cancel;
  finally
    Q.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.Build_RejectsUnfinishedWrite;
var
  C: TResultsImportComparison;
  Work: TCompetitionUnitOfWork;
begin
  Plan('101;11:00:00');
  Work := FContext.BeginUnitOfWork;
  try
    try
      C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
      C.Free;
      Fail('An unfinished operation cannot be published');
    except
      on E: EImportPreviewBusy do ;
    end;
    AssertFalse(Work.Completed);
  finally
    Work.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.
Build_ErrorReleasesReadTransactionAndAllowsRetry;
var
  C: TResultsImportComparison;
begin
  Plan('101;11:00:00');
  Exec('ALTER TABLE main RENAME TO unavailable_main;');
  try
    C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
    C.Free;
    Fail('Missing table must fail the read');
  except
    on E: EDatabaseError do ;
  end;
  AssertFalse(FContext.Transaction.Active);
  Exec('ALTER TABLE unavailable_main RENAME TO main;');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    AssertEquals(1, C.Count);
  finally
    C.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.
Build_ReopeningEvenTheSameFileInvalidatesSession;
var
  C: TResultsImportComparison;
  OldSession: QWord;
begin
  Plan('101;11:00:00');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    OldSession := C.SessionGeneration;
    AssertEquals(FContext.Identity, C.ContextIdentity);
    FContext.CloseFile;
    FContext.OpenFile(':memory:');
    AssertTrue(FContext.SessionGeneration <> OldSession);
  finally
    C.Free;
  end;
end;

function TResultsImportPreviewServiceTests.ReadValue(const AColumn: string;
  const ANumber: integer): TImportValue;
var
  Q: TSQLQuery;
  Own: boolean;
begin
  Own := not FContext.Transaction.Active;
  Q := FContext.CreateQuery(nil);
  try
    Q.SQL.Text := 'SELECT ' + AColumn + ' FROM main WHERE number = :NUMBER';
    Q.ParamByName('NUMBER').AsInteger := ANumber;
    Q.Open;
    if Q.IsEmpty or Q.Fields[0].IsNull then Result := TImportValue.Null
    else
      Result := TImportValue.Value(Q.Fields[0].AsString);
  finally
    Q.Free;
    if Own and FContext.Transaction.Active then FContext.Transaction.Rollback;
  end;
end;

procedure TResultsImportPreviewServiceTests.
Apply_ChangesOnlySelectedFieldsAndKeepsOtherStages;
var
  C: TResultsImportComparison;
  Outcome: TImportApplyOutcome;
begin
  Plan('101;10:05:00;10;11:00:00;;');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    C.ClearSelection;
    C[0].Select(ifFinish, True);
    Outcome := TResultsImportPreviewService.Apply(C, FPlan, FContext,
      FStages, True, False);
    AssertEquals(Ord(iasApplied), Ord(Outcome.State));
    AssertEquals(1, Outcome.WrittenFields);
    AssertEquals('11:00:00', ReadValue('finishtime2').Text);
    AssertEquals('10:00:00', ReadValue('starttime2').Text);
    AssertTrue(ReadValue('correction2').IsNull);
    AssertEquals('00:00:05', ReadValue('penalty2').Text);
    AssertEquals('2', ReadValue('status2').Text);
    AssertTrue(ReadValue('finishtime1').IsNull);
    Outcome := TResultsImportPreviewService.Apply(C, FPlan, FContext,
      FStages, True, False);
    AssertEquals(Ord(iasNoChanges), Ord(Outcome.State));
  finally
    C.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.Apply_StaleSelectedValueRejectsAllChanges;
var
  C: TResultsImportComparison;
  Outcome: TImportApplyOutcome;
begin
  Plan('101;10:00:00;0;11:00:00;;');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    Exec('UPDATE main SET finishtime2 = ''11:20:00'' WHERE number = 101;');
    Outcome := TResultsImportPreviewService.Apply(C, FPlan, FContext,
      FStages, True, False);
    AssertEquals(Ord(iasNeedsReview), Ord(Outcome.State));
    AssertEquals('11:20:00', ReadValue('finishtime2').Text);
    AssertTrue(ReadValue('correction2').IsNull);
    AssertTrue(C.HasSelection);
  finally
    C.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.Apply_AllowsChangesToUnselectedFields;
var
  C: TResultsImportComparison;
  Outcome: TImportApplyOutcome;
begin
  Plan('101;10:00:00;0;11:00:00;;');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    C.ClearSelection;
    C[0].Select(ifCorrection, True);
    Exec('UPDATE main SET finishtime2 = ''11:30:00'' WHERE number = 101;');
    Outcome := TResultsImportPreviewService.Apply(C, FPlan, FContext,
      FStages, True, False);
    AssertEquals(Ord(iasApplied), Ord(Outcome.State));
    AssertEquals('11:30:00', ReadValue('finishtime2').Text);
    AssertFalse(ReadValue('correction2').IsNull);
    AssertEquals('0', ReadValue('correction2').Text);
  finally
    C.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.
Apply_CreatesOnlyConfirmedNumbersIncludingNumberOnly;
var
  C: TResultsImportComparison;
  Outcome: TImportApplyOutcome;
begin
  Plan('102;;;;;' + LineEnding + '103;10:00:00;0;11:00:00;;');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    C[0].ConfirmCreation(True);
    Outcome := TResultsImportPreviewService.Apply(C, FPlan, FContext,
      FStages, True, False);
    AssertEquals(1, Outcome.CreatedParticipants);
    AssertFalse(ReadValue('number', 102).IsNull);
    AssertTrue(ReadValue('number', 103).IsNull);
    AssertTrue(ReadValue('finishtime2', 102).IsNull);
  finally
    C.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.
Apply_CalculationFailureRollsBackCreationAndAllowsRetry;
var
  C: TResultsImportComparison;
begin
  Plan('101;10:00:00;0;11:00:00;;' + LineEnding + '102;10:00:00;0;11:00:00;;');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    C[1].ConfirmCreation(True);
    C.SelectAll;
    Exec('CREATE TRIGGER fail_preview BEFORE UPDATE OF result2 ON main ' +
      'BEGIN SELECT RAISE(ABORT, ''preview calculation failure''); END;');
    try
      TResultsImportPreviewService.Apply(C, FPlan, FContext, FStages, True, False);
      Fail('Calculation must fail');
    except
      on E: EDatabaseError do AssertTrue(Pos('preview calculation failure', E.Message) > 0);
    end;
    AssertTrue(ReadValue('number', 102).IsNull);
    AssertTrue(ReadValue('finishtime2').IsNull);
    AssertEquals('2', ReadValue('status2').Text);
    AssertTrue(C.HasSelection);
    Exec('DROP TRIGGER fail_preview;');
    AssertEquals(Ord(iasApplied), Ord(TResultsImportPreviewService.Apply(
      C, FPlan, FContext, FStages, True, False).State));
    AssertEquals('01:00:00.000', ReadValue('result2').Text);
  finally
    C.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.
Apply_RequiresBackupButEmptySelectionDoesNothing;
var
  C: TResultsImportComparison;
begin
  Plan('101;11:00:00');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    C.ClearSelection;
    AssertEquals(Ord(iasNoChanges), Ord(TResultsImportPreviewService.Apply(
      C, FPlan, FContext, FStages, False, False).State));
    C[0].Select(ifFinish, True);
    try
      TResultsImportPreviewService.Apply(C, FPlan, FContext, FStages, False, False);
      Fail('Backup decision required');
    except
      on E: EArgumentException do ;
    end;
    AssertTrue(ReadValue('finishtime2').IsNull);
  finally
    C.Free;
  end;
end;

procedure TResultsImportPreviewServiceTests.
Apply_RejectsChangedIdentityConfigurationAndSession;
var
  C: TResultsImportComparison;
begin
  Plan('101;11:00:00');
  C := TResultsImportPreviewService.Build(FPlan, FContext, FStages, 2);
  try
    FStages[9].isActive := False;
    AssertFalse(TResultsImportPreviewService.IsCurrent(C, FPlan, FContext, FStages));
    FStages[9].isActive := True;
    Inc(C.SessionGeneration);
    AssertFalse(TResultsImportPreviewService.IsCurrent(C, FPlan, FContext, FStages));
    Dec(C.SessionGeneration);
    Exec('DELETE FROM main WHERE number = 101;');
    Exec('INSERT INTO main (number) VALUES (101);');
    AssertEquals(Ord(iasNeedsReview), Ord(TResultsImportPreviewService.Apply(
      C, FPlan, FContext, FStages, True, False).State));
  finally
    C.Free;
  end;
end;

initialization
  RegisterTest(TResultsImportPreviewServiceTests);
end.
