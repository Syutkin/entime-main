unit ResultsImportPreviewTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, Forms, Controls, Grids, DB, SQLDB, fpcunit,
  testregistry, DbSql, StageModel, CompetitionImportService,
  ResultsImportComparison, ResultsImportPreviewService, ResultsImportPreview,
  GuiTestSupport;

type
  TResultsImportPreviewTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FStages: TStages;
    FPlan: TResultsImportPlan;
    FForm: TResultsImportPreviewForm;
    FGui: TGuiTestSession;
    FMode, FBackupCount, FBackupAction: integer;
    FAllowBackup: boolean;
    FCallbackError: string;
    procedure Exec(const ASql: string);
    function StoredFinish: string;
    procedure Configure(const ACsv: string);
    procedure ClickCell(const AGrid: TStringGrid; const Col, Row: integer);
    procedure ClickButton(const AButton: TWinControl);
    procedure ActOnModal(Data: PtrInt);
    function Backup(out ACreated, AContinueWithoutBackup: boolean): boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure OpenCloseAndReopenShowsComparison;
    procedure ShowsImportFormatAndSourceRows;
    procedure CheckboxButtonsAndFiltersPreserveChoices;
    procedure UnknownNumbersNeedTheirOwnCreationDecision;
    procedure SpaceEnterAndEscapeCancelWithoutWriting;
    procedure ApplySelectedThroughModalCommits;
    procedure StaleValueRefreshesAndRequiresNewDecision;
    procedure BackupCancellationAllowsRetry;
    procedure ChangeDuringBackupRequiresReview;
    procedure ClosedSessionCannotApply;
    procedure DatabaseFailureCanRetryWithoutPartialWrites;
    procedure ReentrantApplyDoesNotRepeatBackup;
  end;

implementation

uses Types, LCLType, i18n;

procedure TResultsImportPreviewTests.SetUp;
var
  Work: TCompetitionUnitOfWork;
begin
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FStages := TStages.Create(2);
  FStages[2].isActive := True;
  Work := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, 2, 'A', 'B', 'C', 'D', 'E', 'Preview form');
    Work.Commit;
  finally
    Work.Free;
  end;
  Exec('INSERT INTO main (number, name, starttime2) VALUES (101, ''Rider'', ''10:00:00'');');
  FGui := TGuiTestSession.Create;
  FForm := TResultsImportPreviewForm.Create(nil);
  FForm.OnPrepareBackup := @Backup;
  FAllowBackup := True;
  Configure('101;11:00:00');
end;

procedure TResultsImportPreviewTests.TearDown;
begin
  Application.RemoveAsyncCalls(Self);
  FForm.Free;
  FGui.Free;
  FPlan.Free;
  FStages.Free;
  FContext.Free;
end;

procedure TResultsImportPreviewTests.Exec(const ASql: string);
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

function TResultsImportPreviewTests.StoredFinish: string;
var
  Q: TSQLQuery;
begin
  Q := FContext.CreateQuery(nil);
  try
    Q.SQL.Text := 'SELECT finishtime2 FROM main WHERE number = 101';
    Q.Open;
    Result := Q.Fields[0].AsString;
  finally
    Q.Free;
    if FContext.Transaction.Active then FContext.Transaction.Rollback;
  end;
end;

procedure TResultsImportPreviewTests.Configure(const ACsv: string);
var
  Path: string;
  Lines: TStringList;
begin
  FreeAndNil(FPlan);
  Path := GetTempFileName(GetTempDir(False), 'preview-form-');
  Lines := TStringList.Create;
  try
    Lines.Text := ACsv;
    Lines.SaveToFile(Path);
    FPlan := TCompetitionImportService.PrepareResultsFile(Path);
    FForm.Configure(FPlan, FContext, FStages, 2, Path);
  finally
    Lines.Free;
    DeleteFile(Path);
  end;
end;

procedure TResultsImportPreviewTests.ClickCell(const AGrid: TStringGrid;
  const Col, Row: integer);
var
  R: TRect;
begin
  R := AGrid.CellRect(Col, Row);
  FGui.ClickAndWaitForFocus(AGrid, (R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2);
end;

procedure TResultsImportPreviewTests.ClickButton(const AButton: TWinControl);
begin
  FGui.Click(AButton, AButton.ClientWidth div 2, AButton.ClientHeight div 2);
end;

function TResultsImportPreviewTests.Backup(
  out ACreated, AContinueWithoutBackup: boolean): boolean;
begin
  Inc(FBackupCount);
  if FBackupAction = 1 then
    Exec('UPDATE main SET finishtime2 = ''11:30:00'' WHERE number = 101;')
  else if FBackupAction = 2 then
    FForm.ApplyClick(FForm.ApplyButton);
  ACreated := FAllowBackup;
  AContinueWithoutBackup := False;
  Result := FAllowBackup;
end;

procedure TResultsImportPreviewTests.ShowsImportFormatAndSourceRows;
begin
  Configure('# result import' + LineEnding + '101;11:00:00');
  FForm.Show;
  FGui.Drain('Read import context');
  AssertTrue('The preview must identify the CSV format',
    Pos(rsImportPreviewFinishFormat, FForm.StageLabel.Caption) > 0);
  AssertEquals('2', FForm.ChangesGrid.Cells[7, 1]);
end;

procedure TResultsImportPreviewTests.OpenCloseAndReopenShowsComparison;
begin
  FForm.Show;
  FGui.Drain('Open preview');
  AssertEquals('101', FForm.ChangesGrid.Cells[1, 1]);
  AssertTrue(FForm.ApplyButton.Enabled);
  FForm.Close;
  AssertFalse(FForm.Visible);
  FForm.Show;
  FGui.Drain('Reopen preview');
  AssertEquals('101', FForm.ChangesGrid.Cells[1, 1]);
  AssertEquals('', StoredFinish);
end;

procedure TResultsImportPreviewTests.CheckboxButtonsAndFiltersPreserveChoices;
begin
  FForm.Show;
  FGui.Drain('Open preview');
  ClickCell(FForm.ChangesGrid, 0, 1);
  AssertFalse(FForm.Comparison.HasSelection);
  ClickButton(FForm.SelectAllButton);
  AssertEquals(1, FForm.Comparison.SelectedFieldCount);
  FForm.FilterComboBox.ItemIndex := 2;
  FForm.FilterChange(FForm.FilterComboBox);
  AssertEquals(1, FForm.Comparison.SelectedFieldCount);
  FForm.FilterComboBox.ItemIndex := 0;
  FForm.FilterChange(FForm.FilterComboBox);
  FForm.ChangesHeaderClick(FForm.ChangesGrid, True, 3);
  AssertEquals('1', FForm.ChangesGrid.Cells[0, 1]);
  ClickButton(FForm.ClearSelectionButton);
  AssertFalse(FForm.ApplyButton.Enabled);
end;

procedure TResultsImportPreviewTests.UnknownNumbersNeedTheirOwnCreationDecision;
begin
  Configure('101;11:00:00' + LineEnding + '102;11:01:00');
  FForm.Show;
  FGui.Drain('Open preview');
  ClickButton(FForm.SelectAllButton);
  AssertFalse(FForm.Comparison[1].CreateSelected);
  FGui.SelectTab(FForm.UnknownPage);
  ClickCell(FForm.UnknownGrid, 0, 1);
  AssertTrue(FForm.Comparison[1].CreateSelected);
  AssertEquals(2, FForm.Comparison.SelectedFieldCount);
  FGui.SelectTab(FForm.ChangesPage);
  ClickButton(FForm.ClearSelectionButton);
  AssertFalse(FForm.Comparison.HasSelection);
end;

procedure TResultsImportPreviewTests.ActOnModal(Data: PtrInt);
begin
  if Data < 0 then Exit;
  try
    case FMode of
      0: begin
        ClickCell(FForm.ChangesGrid, 1, 1);
        FGui.PressKey(FForm.ChangesGrid, VK_SPACE);
        AssertFalse(FForm.Comparison.HasSelection);
        FGui.PressKey(FForm.ChangesGrid, VK_RETURN);
        AssertEquals(0, FBackupCount);
        FGui.PressKey(FForm.ChangesGrid, VK_ESCAPE);
      end;
      1: ClickButton(FForm.ApplyButton);
      2: begin
        ClickButton(FForm.ApplyButton);
        AssertEquals(0, FBackupCount);
        AssertEquals(rsImportPreviewStale, FForm.StateLabel.Caption);
        AssertFalse(FForm.Comparison.HasSelection);
        AssertFalse(FForm.ApplyButton.Enabled);
      end;
      4: begin
        ClickButton(FForm.ApplyButton);
        AssertEquals(Ord(iasNeedsReview), Ord(FForm.Outcome.State));
        AssertEquals(rsImportPreviewStale, FForm.StateLabel.Caption);
        AssertFalse(FForm.Comparison.HasSelection);
      end;
      5: begin
        FContext.CloseFile;
        ClickButton(FForm.ApplyButton);
        AssertEquals(rsImportPreviewSessionChanged, FForm.StateLabel.Caption);
        AssertFalse(FForm.ApplyButton.Enabled);
        AssertEquals(0, FBackupCount);
      end;
      6: begin
        ClickButton(FForm.ApplyButton);
        AssertEquals(mrNone, FForm.ModalResult);
        AssertTrue(Pos('forced preview failure', FForm.LastError) > 0);
        AssertTrue(FForm.Comparison.HasSelection);
        AssertEquals('', StoredFinish);
        Exec('DROP TRIGGER reject_preview;');
        ClickButton(FForm.ApplyButton);
      end;
      3: begin
        FAllowBackup := False;
        ClickButton(FForm.ApplyButton);
        AssertEquals(mrNone, FForm.ModalResult);
        AssertTrue(FForm.Comparison.HasSelection);
        FAllowBackup := True;
        ClickButton(FForm.ApplyButton);
      end;
    end;
  except
    on E: Exception do FCallbackError := E.Message;
  end;
  if FForm.ModalResult = mrNone then FForm.ModalResult := mrCancel;
  // Input assertions drain events inside an async callback. Leave an event
  // for the outer modal loop so its idle wait observes the modal result.
  Application.QueueAsyncCall(@ActOnModal, -1);
end;

procedure TResultsImportPreviewTests.SpaceEnterAndEscapeCancelWithoutWriting;
begin
  FMode := 0;
  Application.QueueAsyncCall(@ActOnModal, 0);
  AssertEquals(mrCancel, FForm.ShowModal);
  AssertEquals('', FCallbackError);
  AssertEquals('', StoredFinish);
end;

procedure TResultsImportPreviewTests.ApplySelectedThroughModalCommits;
begin
  FMode := 1;
  Application.QueueAsyncCall(@ActOnModal, 0);
  AssertEquals(mrOk, FForm.ShowModal);
  AssertEquals('', FCallbackError);
  AssertEquals(1, FBackupCount);
  AssertEquals('11:00:00', StoredFinish);
  AssertEquals(1, FForm.Outcome.WrittenFields);
end;

procedure TResultsImportPreviewTests.StaleValueRefreshesAndRequiresNewDecision;
begin
  Exec('UPDATE main SET finishtime2 = ''11:20:00'' WHERE number = 101;');
  FMode := 2;
  Application.QueueAsyncCall(@ActOnModal, 0);
  AssertEquals(mrCancel, FForm.ShowModal);
  AssertEquals('', FCallbackError);
  AssertEquals('11:20:00', StoredFinish);
end;

procedure TResultsImportPreviewTests.BackupCancellationAllowsRetry;
begin
  FMode := 3;
  Application.QueueAsyncCall(@ActOnModal, 0);
  AssertEquals(mrOk, FForm.ShowModal);
  AssertEquals('', FCallbackError);
  AssertEquals(2, FBackupCount);
end;

procedure TResultsImportPreviewTests.ChangeDuringBackupRequiresReview;
begin
  FBackupAction := 1;
  FMode := 4;
  Application.QueueAsyncCall(@ActOnModal, 0);
  AssertEquals(mrCancel, FForm.ShowModal);
  AssertEquals('', FCallbackError);
  AssertEquals('11:30:00', StoredFinish);
  AssertEquals(1, FBackupCount);
end;

procedure TResultsImportPreviewTests.ClosedSessionCannotApply;
begin
  FMode := 5;
  Application.QueueAsyncCall(@ActOnModal, 0);
  AssertEquals(mrCancel, FForm.ShowModal);
  AssertEquals('', FCallbackError);
end;

procedure TResultsImportPreviewTests.DatabaseFailureCanRetryWithoutPartialWrites;
begin
  Exec('CREATE TRIGGER reject_preview BEFORE UPDATE ON main BEGIN ' +
    'SELECT RAISE(ABORT, ''forced preview failure''); END;');
  FMode := 6;
  Application.QueueAsyncCall(@ActOnModal, 0);
  AssertEquals(mrOk, FForm.ShowModal);
  AssertEquals('', FCallbackError);
  AssertEquals('11:00:00', StoredFinish);
  AssertEquals(2, FBackupCount);
  AssertEquals('', FForm.LastError);
end;

procedure TResultsImportPreviewTests.ReentrantApplyDoesNotRepeatBackup;
begin
  FBackupAction := 2;
  FMode := 1;
  Application.QueueAsyncCall(@ActOnModal, 0);
  AssertEquals(mrOk, FForm.ShowModal);
  AssertEquals('', FCallbackError);
  AssertEquals(1, FBackupCount);
  FForm.ApplyClick(FForm.ApplyButton);
  AssertEquals(1, FBackupCount);
  AssertEquals('11:00:00', StoredFinish);
end;

initialization
  RegisterTest(TResultsImportPreviewTests);
end.
