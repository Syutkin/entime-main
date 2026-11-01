unit OverallFinishPrintIntegrationTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry, FinishProtocolPrintForm,
  CompetitionDbContext, StageModel, GuiTestSupport, Controls;

type
  TOverallFinishPrintIntegrationTests = class(TTestCase)
  private
    F: TFinishProtocolPrintForm;
    C: TCompetitionDbContext;
    Stages: TStages;
    Gui: TGuiTestSession;
    Dir: string;
    procedure Exec(const SQL: string);
    procedure Click(Control: TWinControl);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ModesPreserveOptionsAndExportBothKinds;
    procedure DetailedColumnsRebuildAutomatically;
    procedure SelectionAndZeroResultRemainVisible;
    procedure TemplateAndAllFormatsUseFrozenSnapshot;
    procedure NavigationZoomAndResizeRemainUsable;
    procedure ReadErrorNoStagesAndEscape;
    procedure IndependentHeadingsAndSessionClosure;
    procedure FitWidthRebuildsAndSurvivesModeChanges;
  end;

implementation

uses Forms, StdCtrls, SQLDB, CompetitionSchemaMigrator, StageFinishReportModel,
  FileUtil, LCLType, ReportTemplateModel;

procedure TOverallFinishPrintIntegrationTests.Exec(const SQL: string);
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

procedure TOverallFinishPrintIntegrationTests.Click(Control: TWinControl);
begin
  Gui.Click(Control, Control.ClientWidth div 2, Control.ClientHeight div 2);
end;

procedure TOverallFinishPrintIntegrationTests.SetUp;
var
  W: TCompetitionUnitOfWork;
  T: TStringList;
begin
  Gui := TGuiTestSession.Create;
  Dir := GetTempFileName;
  DeleteFile(Dir);
  ForceDirectories(Dir);
  C := TCompetitionDbContext.Create;
  C.OpenFile(':memory:');
  Stages := TStages.Create(32);
  Stages[3].isActive := True;
  Stages[8].isActive := True;
  W := C.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(C.Connection, 32, 'A', 'B', 'C', 'D', 'E', 'Race');
    W.Commit;
  finally
    W.Free;
  end;
  Exec('INSERT INTO main(number,name,category,sumresult,sumplace,result1,result3,result8) VALUES(123,''Rider'',''A'',''00:00:00.000'',5,''00:00:00.000'',NULL,NULL),(9,''Second'',''B'',''DNF'',NULL,''00:01:00.123'',NULL,NULL),(17,''Empty'',''B'',NULL,NULL,NULL,NULL,NULL)');
  T := TStringList.Create;
  try
    T.Text := '<p style="text-align:center">Frozen header</p><p>{{RESULTS}}</p><p>Footer</p>';
    T.SaveToFile(Dir + '/template.html');
  finally
    T.Free;
  end;
  F := TFinishProtocolPrintForm.Create(nil);
  F.ConfigureFinish(C, Stages, frmOverall, 8, rlRussian, Dir);
  F.Show;
  Gui.Drain('Open overall protocol');
end;

procedure TOverallFinishPrintIntegrationTests.TearDown;
begin
  F.Free;
  Stages.Free;
  C.Free;
  Gui.Free;
  DeleteDirectory(Dir, False);
end;

procedure TOverallFinishPrintIntegrationTests.ModesPreserveOptionsAndExportBothKinds;
var
  Ext: string;
  T: TReportTemplate;
begin
  AssertEquals(0, F.ModeCombo.ItemIndex);
  AssertTrue(F.DetailsPanel.Visible);
  AssertFalse(F.SingleStagePanel.Visible);
  F.TemplateCombo.ItemIndex := 1;
  F.ParametersChange(F.TemplateCombo);
  Gui.Click(F.CategoriesList, 8, F.CategoriesList.ItemHeight * 3 div 2);
  AssertEquals(1, Length(F.Protocol.Rows));
  Click(F.StagePlacesCheck);
  Click(F.StagePenaltyCheck);
  Click(F.HeadingsCheck);
  F.ModeCombo.SetFocus;
  Gui.Drain('Focus finish mode');
  Gui.PressKey(F.ModeCombo, VK_DOWN);
  AssertEquals(1, F.ModeCombo.ItemIndex);
  AssertTrue(F.SingleStagePanel.Visible);
  AssertFalse(F.DetailsPanel.Visible);
  AssertTrue(F.PenaltyCheck.Visible);
  AssertEquals(8, F.SelectedStage);
  AssertTrue(F.Snapshot <> nil);
  AssertEquals(1, Length(F.Protocol.Rows));
  T := F.Protocol.Template;
  AssertEquals('Frozen header', T.Header[0].Text);
  AssertFalse(F.Protocol.Options.ShowHeadings);
  F.SelectStageCombo.SetFocus;
  Gui.Drain('Focus finish stage');
  Gui.PressKey(F.SelectStageCombo, VK_UP);
  AssertEquals(7, F.SelectedStage);
  Click(F.PenaltyCheck);
  AssertTrue(F.Snapshot.Options.ShowPenalty);
  for Ext in ['.pdf', '.docx', '.xlsx'] do
    AssertTrue(Ext + ': ' + F.LastError, F.SaveTo(Dir + '/single' + Ext));
  F.ModeCombo.SetFocus;
  Gui.Drain('Back to overall');
  Gui.PressKey(F.ModeCombo, VK_UP);
  AssertEquals(0, F.ModeCombo.ItemIndex);
  AssertTrue(F.Snapshot = nil);
  AssertEquals(1, Length(F.Protocol.Rows));
  T := F.Protocol.Template;
  AssertEquals('Frozen header', T.Header[0].Text);
  AssertTrue(F.StagePlacesCheck.Checked);
  AssertTrue(F.StagePenaltyCheck.Checked);
  AssertFalse(F.Protocol.Options.ShowHeadings);
  for Ext in ['.pdf', '.docx', '.xlsx'] do
    AssertTrue(Ext + ': ' + F.LastError, F.SaveTo(Dir + '/overall' + Ext));
  F.ModeCombo.ItemIndex := 1;
  F.SourceChange(F.ModeCombo);
  AssertTrue(F.PenaltyCheck.Checked);
  AssertEquals(7, F.SelectedStage);
end;

procedure TOverallFinishPrintIntegrationTests.DetailedColumnsRebuildAutomatically;
begin
  AssertTrue('Ready: ' + F.LastError, F.SaveButton.Enabled);
  AssertEquals(9, Length(F.Protocol.Columns));
  Click(F.StagePlacesCheck);
  AssertEquals(12, Length(F.Protocol.Columns));
  Click(F.StageGapsCheck);
  AssertEquals(15, Length(F.Protocol.Columns));
  Click(F.StagePenaltyCheck);
  AssertEquals(18, Length(F.Protocol.Columns));
  Click(F.DetailedCheck);
  AssertEquals(6, Length(F.Protocol.Columns));
  AssertFalse(F.StagePlacesCheck.Enabled);
  AssertTrue(F.SaveButton.Enabled);
  Click(F.DetailedCheck);
  AssertEquals(18, Length(F.Protocol.Columns));
end;

procedure TOverallFinishPrintIntegrationTests.FitWidthRebuildsAndSurvivesModeChanges;
var
  Fit: TCheckBox;
  I: integer;
  Ext: string;
begin
  Fit := F.FindComponent('FitWidthCheck') as TCheckBox;
  AssertNotNull('Overall finish protocol needs a fit-width checkbox', Fit);
  AssertFalse(Fit.Checked);
  for I := 1 to 32 do Stages[I].isActive := True;
  F.ConfigureFinish(C, Stages, frmOverall, 8, rlRussian, Dir);
  AssertTrue(F.Document.PageCount > 1);
  Click(Fit);
  AssertTrue(F.Protocol.Options.FitToWidth);
  AssertEquals(1, F.Document.PageCount);
  Click(F.StagePlacesCheck);
  Click(F.StageGapsCheck);
  Click(F.StagePenaltyCheck);
  AssertEquals(134, Length(F.Protocol.Columns));
  AssertEquals(1, F.Document.PageCount);
  for Ext in ['.pdf', '.docx', '.xlsx'] do
    AssertTrue(Ext + ': ' + F.LastError, F.SaveTo(Dir + '/fitted' + Ext));
  Click(F.DetailedCheck);
  AssertEquals(6, Length(F.Protocol.Columns));
  AssertTrue(F.Protocol.Options.FitToWidth);
  AssertEquals(1, F.Document.PageCount);
  Click(F.DetailedCheck);
  F.ModeCombo.SetFocus;
  Gui.Drain('Switch fitted finish protocol to single stage');
  Gui.PressKey(F.ModeCombo, VK_DOWN);
  AssertFalse(Fit.Visible);
  AssertFalse(Fit.Enabled);
  AssertFalse(F.Protocol.Options.FitToWidth);
  AssertTrue(F.SaveTo(Dir + '/single-after-fit.pdf'));
  Gui.PressKey(F.ModeCombo, VK_UP);
  AssertTrue(Fit.Visible);
  AssertTrue(Fit.Enabled);
  AssertTrue(Fit.Checked);
  AssertTrue(F.Protocol.Options.FitToWidth);
  AssertEquals(1, F.Document.PageCount);
  Click(Fit);
  AssertFalse(F.Protocol.Options.FitToWidth);
  AssertTrue(F.Document.PageCount > 1);
  AssertTrue(F.SaveTo(Dir + '/unfitted.pdf'));
end;

procedure TOverallFinishPrintIntegrationTests.SelectionAndZeroResultRemainVisible;
begin
  Click(F.DetailedCheck);
  AssertEquals('00:00.000', F.Protocol.Rows[0].Cells[4]);
  Click(F.IncompleteCheck);
  AssertEquals(2, Length(F.Protocol.Rows));
  Click(F.ClearButton);
  AssertFalse(F.SaveButton.Enabled);
  AssertTrue(F.Document = nil);
  Click(F.AllButton);
  AssertTrue(F.SaveButton.Enabled);
  F.CategoriesList.ItemIndex := 0;
  F.CategoriesList.SetFocus;
  Gui.Drain('Focus category');
  Gui.Click(F.CategoriesList, 8, F.CategoriesList.ItemHeight div 2);
  AssertEquals(1, Length(F.Protocol.Rows));
  AssertEquals('B', F.Protocol.Rows[0].Category);
end;

procedure TOverallFinishPrintIntegrationTests.TemplateAndAllFormatsUseFrozenSnapshot;
var
  T: TReportTemplate;
  Ext: string;
  Count: integer;
begin
  F.TemplateCombo.ItemIndex := 1;
  F.ParametersChange(F.TemplateCombo);
  T := F.Protocol.Template;
  AssertEquals('Frozen header', T.Header[0].Text);
  DeleteFile(Dir + '/template.html');
  Exec('UPDATE main SET name=''Changed''');
  Count := F.Document.PageCount;
  for Ext in ['.pdf', '.docx', '.xlsx'] do
    AssertTrue(Ext + ': ' + F.LastError, F.SaveTo(Dir + '/result' + Ext));
  AssertEquals(Count, F.Document.PageCount);
  AssertEquals('Rider', F.Protocol.Rows[0].Cells[2]);
  T := F.Protocol.Template;
  AssertEquals('Frozen header', T.Header[0].Text);
  AssertFalse(F.SaveTo(Dir + '/missing/result.pdf'));
  AssertTrue(F.SaveButton.Enabled);
  AssertTrue(F.SaveTo(Dir + '/retry.pdf'));
end;

procedure TOverallFinishPrintIntegrationTests.NavigationZoomAndResizeRemainUsable;
var
  I: integer;
begin
  for I := 1 to 32 do Stages[I].isActive := True;
  F.ConfigureFinish(C, Stages, frmOverall, 8, rlEnglish, Dir);
  AssertTrue(F.Document.PageCount > 1);
  Click(F.LastButton);
  AssertEquals(F.Document.PageCount, F.PageSpin.Value);
  Click(F.FirstButton);
  AssertEquals(1, F.PageSpin.Value);
  F.ZoomCombo.ItemIndex := 3;
  F.ZoomChange(F.ZoomCombo);
  for I := 0 to 5 do
  begin
    F.Width := 900 + I * 20;
    Gui.Drain('Resize overall preview');
  end;
  AssertTrue(F.SaveButton.Enabled);
  AssertTrue(F.SaveTo(Dir + '/resized.pdf'));
end;

procedure TOverallFinishPrintIntegrationTests.ReadErrorNoStagesAndEscape;
var
  I: integer;
begin
  for I := 1 to 32 do Stages[I].isActive := False;
  F.ConfigureFinish(C, Stages, frmOverall, 8, rlRussian, Dir);
  AssertFalse(F.SaveButton.Enabled);
  AssertTrue(F.StateLabel.Caption <> '');
  Stages[1].isActive := True;
  Exec('ALTER TABLE main RENAME TO absent_main');
  F.ConfigureFinish(C, Stages, frmOverall, 8, rlRussian, Dir);
  AssertFalse(F.SaveButton.Enabled);
  Exec('ALTER TABLE absent_main RENAME TO main');
  F.ConfigureFinish(C, Stages, frmOverall, 8, rlRussian, Dir);
  AssertTrue(F.SaveButton.Enabled);
  F.CloseButton.SetFocus;
  Gui.Drain('Focus Close');
  Gui.PressKey(F.CloseButton, VK_ESCAPE);
  AssertFalse(F.Visible);
  F.Show;
  Gui.Drain('Reopen overall protocol');
  AssertTrue(F.SaveButton.Enabled);
end;

procedure TOverallFinishPrintIntegrationTests.IndependentHeadingsAndSessionClosure;
begin
  Click(F.HeadingsCheck);
  AssertFalse(F.Protocol.Options.ShowHeadings);
  AssertTrue(F.Protocol.Options.ShowHeader);
  Click(F.HeaderCheck);
  AssertFalse(F.Protocol.Options.ShowHeader);
  Click(F.FooterCheck);
  AssertFalse(F.Protocol.Options.ShowFooter);
  F.EndSession;
  AssertFalse(F.SaveButton.Enabled);
  AssertFalse(F.SaveTo(Dir + '/closed.pdf'));
end;

initialization
  RegisterTest(TOverallFinishPrintIntegrationTests);
end.
