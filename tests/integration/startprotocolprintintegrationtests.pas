unit StartProtocolPrintIntegrationTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry, StartProtocolPrintForm,
  CompetitionDbContext, StageModel, GuiTestSupport, Controls, StdCtrls;

type
  TStartProtocolPrintIntegrationTests = class(TTestCase)
  private
    F: TStartProtocolPrintForm;
    C: TCompetitionDbContext;
    Stages: TStages;
    Gui: TGuiTestSession;
    Dir: string;
    procedure Exec(const SQL: string);
    procedure Click(Control: TWinControl);
    procedure SelectCombo(Combo: TComboBox; Index: integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure FitWidthAndAllSeparateStagesRebuildAndSave;
    procedure TeamToggleAndNumberOrderApplyToEveryMode;
    procedure NumberOrderIsContinuousAndTimeOrderRestoresCategories;
    procedure SortChoiceChangesParticipantOrder;
    procedure ModesAndSortingRebuildAutomatically;
    procedure MissingStartsAndSelectionKeepMidnight;
    procedure TemplateAndAllFormatsUseFrozenSnapshot;
    procedure NavigationZoomAndResizeRemainUsable;
    procedure ReadErrorNoStagesAndEscape;
    procedure IndependentHeadingsAndSessionClosure;
  end;

implementation

uses Forms, SQLDB, CompetitionSchemaMigrator, ProtocolDocumentModel, StartReportModel,
  FileUtil, LCLType, ReportTemplateModel;

procedure TStartProtocolPrintIntegrationTests.Exec(const SQL: string);
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

procedure TStartProtocolPrintIntegrationTests.Click(Control: TWinControl);
begin
  Gui.Click(Control, Control.ClientWidth div 2, Control.ClientHeight div 2);
end;

procedure TStartProtocolPrintIntegrationTests.SelectCombo(Combo: TComboBox;
  Index: integer);
var
  I, Steps: integer;
  Key: word;
begin
  Combo.SetFocus;
  Gui.Drain('Focus choice');
  Steps := Index - Combo.ItemIndex;
  Key := VK_DOWN;
  if Steps < 0 then Key := VK_UP;
  for I := 1 to Abs(Steps) do Gui.PressKey(Combo, Key);
  Gui.Drain('Change start protocol choice');
  AssertEquals(Index, Combo.ItemIndex);
end;

procedure TStartProtocolPrintIntegrationTests.FitWidthAndAllSeparateStagesRebuildAndSave;
var
  I: integer;
  Ext: string;
begin
  for I := 1 to 32 do Stages[I].isActive := True;
  F.ConfigureStart(C, Stages, srmAllStages, 8, rlRussian, Dir);
  AssertTrue(F.Document.PageCount > 1);
  Click(F.FitWidthCheck);
  AssertTrue(F.Protocol.Options.FitToWidth);
  AssertEquals(1, F.Document.PageCount);
  Click(F.TeamCheck);
  AssertEquals(34, Length(F.Protocol.Columns));
  AssertEquals(1, F.Document.PageCount);
  AssertTrue(F.SaveTo(Dir + '/fitted-without-team.pdf'));
  Click(F.TeamCheck);
  AssertEquals(35, Length(F.Protocol.Columns));
  SelectCombo(F.ModeCombo, 1);
  AssertFalse(F.FitWidthCheck.Enabled);
  SelectCombo(F.StartStageCombo, 0);
  AssertEquals(32, Length(F.Protocol.Sections));
  AssertEquals(32, F.Document.PageCount);
  for Ext in ['.pdf', '.docx', '.xlsx'] do
    AssertTrue(Ext + ': ' + F.LastError, F.SaveTo(Dir + '/all-stages' + Ext));
  SelectCombo(F.StartStageCombo, 8);
  AssertEquals(8, F.SelectedStage);
  AssertEquals(0, Length(F.Protocol.Sections));
  SelectCombo(F.ModeCombo, 0);
  AssertTrue(F.FitWidthCheck.Enabled);
  AssertTrue(F.FitWidthCheck.Checked);
  AssertEquals(1, F.Document.PageCount);
end;

procedure TStartProtocolPrintIntegrationTests.
NumberOrderIsContinuousAndTimeOrderRestoresCategories;
begin
  Exec('UPDATE main SET starttime1=CASE WHEN number=9 THEN ''08:00:00'' ELSE ''09:00:00'' END,starttime3=CASE WHEN number=9 THEN ''12:00:00'' ELSE ''07:00:00'' END');
  F.ConfigureStart(C, Stages, srmAllStages, 8, rlRussian, Dir);
  AssertEquals('B', F.Protocol.Rows[0].Category);
  SelectCombo(F.OrderCombo, 1);
  AssertTrue(F.Protocol.Options.HideCategories);
  AssertFalse(F.SortStageCombo.Enabled);
  AssertEquals(9, F.Protocol.Rows[0].Number);
  AssertEquals(17, F.Protocol.Rows[1].Number);
  AssertEquals(123, F.Protocol.Rows[2].Number);
  SelectCombo(F.OrderCombo, 0);
  AssertFalse(F.Protocol.Options.HideCategories);
  AssertTrue(F.SortStageCombo.Enabled);
  SelectCombo(F.SortStageCombo, 1);
  AssertEquals('A', F.Protocol.Rows[0].Category);
end;

procedure TStartProtocolPrintIntegrationTests.TeamToggleAndNumberOrderApplyToEveryMode;
var
  I: integer;
  Ext: string;
begin
  AssertTrue(F.TeamCheck.Checked);
  Click(F.TeamCheck);
  AssertEquals(5, Length(F.Protocol.Columns));
  SelectCombo(F.OrderCombo, 1);
  AssertTrue(F.Protocol.Options.HideCategories);
  AssertEquals(9, F.Protocol.Rows[0].Number);
  AssertEquals(17, F.Protocol.Rows[1].Number);
  AssertEquals(123, F.Protocol.Rows[2].Number);
  Gui.Click(F.CategoriesList, 8, F.CategoriesList.ItemHeight div 2);
  AssertEquals(2, Length(F.Protocol.Rows));
  AssertEquals(2, F.CategoriesList.Count);
  Click(F.AllButton);
  SelectCombo(F.ModeCombo, 1);
  AssertEquals(3, Length(F.Protocol.Columns));
  AssertFalse(F.TeamCheck.Checked);
  AssertEquals(9, F.Protocol.Rows[0].Number);
  SelectCombo(F.StartStageCombo, 0);
  AssertEquals(3, Length(F.Protocol.Sections));
  for I := 0 to High(F.Protocol.Sections) do
  begin
    AssertTrue(F.Protocol.Sections[I].Options.HideCategories);
    AssertEquals(3, Length(F.Protocol.Sections[I].Columns));
    AssertEquals(9, F.Protocol.Sections[I].Rows[0].Number);
  end;
  for Ext in ['.pdf', '.docx', '.xlsx'] do
    AssertTrue(Ext + ': ' + F.LastError, F.SaveTo(Dir + '/without-team' + Ext));
  Click(F.TeamCheck);
  AssertEquals(4, Length(F.Protocol.Sections[0].Columns));
  SelectCombo(F.OrderCombo, 0);
  AssertFalse(F.Protocol.Sections[0].Options.HideCategories);
end;

procedure TStartProtocolPrintIntegrationTests.SortChoiceChangesParticipantOrder;
begin
  Exec('UPDATE main SET category=''A'',starttime3=CASE WHEN number=9 THEN ''00:00:00.000'' ELSE ''12:00:00'' END');
  F.ConfigureStart(C, Stages, srmAllStages, 8, rlRussian, Dir);
  AssertEquals(123, F.Protocol.Rows[0].Number);
  SelectCombo(F.SortStageCombo, 1);
  AssertEquals(9, F.Protocol.Rows[0].Number);
  SelectCombo(F.OrderCombo, 1);
  AssertEquals(9, F.Protocol.Rows[0].Number);
  AssertFalse(F.SortStageCombo.Enabled);
  SelectCombo(F.ModeCombo, 1);
  AssertEquals(4, Length(F.Protocol.Columns));
  AssertEquals(8, F.SelectedStage);
end;

procedure TStartProtocolPrintIntegrationTests.SetUp;
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
  Exec('INSERT INTO main(number,name,category,starttime1,starttime3,starttime8) VALUES(123,''Rider'',''A'',''09:00:00.123'',''00:00:00.000'',''11:00:00''),(9,''Second'',''B'',NULL,''10:00:00'',NULL),(17,''Empty'',''B'',NULL,NULL,NULL)');
  T := TStringList.Create;
  try
    T.Text := '<p style="text-align:center">Frozen header</p><p>{{RESULTS}}</p><p>Footer</p>';
    T.SaveToFile(Dir + '/template.html');
  finally
    T.Free;
  end;
  F := TStartProtocolPrintForm.Create(nil);
  F.ConfigureStart(C, Stages, srmAllStages, 8, rlRussian, Dir);
  F.Show;
  Gui.Drain('Open overall protocol');
end;

procedure TStartProtocolPrintIntegrationTests.TearDown;
begin
  F.Free;
  Stages.Free;
  C.Free;
  Gui.Free;
  DeleteDirectory(Dir, False);
end;

procedure TStartProtocolPrintIntegrationTests.ModesAndSortingRebuildAutomatically;
begin
  AssertTrue('Ready: ' + F.LastError, F.SaveButton.Enabled);
  AssertEquals(6, Length(F.Protocol.Columns));
  AssertEquals(4, F.StartStageCombo.Items.Count);
  AssertEquals(3, F.SortStageCombo.Items.Count);
  AssertEquals(8, F.SelectedStage);
  F.ModeCombo.ItemIndex := 1;
  F.ParametersChange(F.ModeCombo);
  AssertEquals(4, Length(F.Protocol.Columns));
  AssertEquals('11:00:00', F.Protocol.Rows[0].Cells[3]);
  F.StartStageCombo.ItemIndex := 2;
  F.ParametersChange(F.StartStageCombo);
  AssertEquals(3, F.SelectedStage);
  AssertEquals('00:00:00.000', F.Protocol.Rows[0].Cells[3]);
  F.OrderCombo.ItemIndex := 1;
  F.ParametersChange(F.OrderCombo);
  AssertTrue(F.SaveButton.Enabled);
  F.ModeCombo.ItemIndex := 0;
  F.ParametersChange(F.ModeCombo);
  AssertEquals(6, Length(F.Protocol.Columns));
  AssertFalse(F.SortStageCombo.Enabled);
  F.OrderCombo.ItemIndex := 0;
  F.ParametersChange(F.OrderCombo);
  AssertTrue(F.SortStageCombo.Enabled);
  F.SortStageCombo.ItemIndex := 1;
  F.ParametersChange(F.SortStageCombo);
  AssertTrue(F.SaveButton.Enabled);
end;

procedure TStartProtocolPrintIntegrationTests.MissingStartsAndSelectionKeepMidnight;
begin
  Click(F.IncompleteCheck);
  AssertEquals(2, Length(F.Protocol.Rows));
  F.ModeCombo.ItemIndex := 1;
  F.ParametersChange(F.ModeCombo);
  AssertEquals(1, Length(F.Protocol.Rows));
  F.StartStageCombo.ItemIndex := 2;
  F.ParametersChange(F.StartStageCombo);
  AssertEquals(2, Length(F.Protocol.Rows));
  AssertEquals('00:00:00.000', F.Protocol.Rows[0].Cells[3]);
  Click(F.ClearButton);
  AssertFalse(F.SaveButton.Enabled);
  AssertTrue(F.Document = nil);
  Click(F.AllButton);
  AssertTrue(F.SaveButton.Enabled);
  Gui.Click(F.CategoriesList, 8, F.CategoriesList.ItemHeight div 2);
  AssertEquals(1, Length(F.Protocol.Rows));
  AssertEquals('B', F.Protocol.Rows[0].Category);
  F.ModeCombo.ItemIndex := 0;
  F.ParametersChange(F.ModeCombo);
  AssertEquals(1, Length(F.Protocol.Rows));
  AssertEquals(2, F.CategoriesList.Count);
end;

procedure TStartProtocolPrintIntegrationTests.TemplateAndAllFormatsUseFrozenSnapshot;
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
  AssertEquals('Rider', F.Protocol.Rows[0].Cells[1]);
  T := F.Protocol.Template;
  AssertEquals('Frozen header', T.Header[0].Text);
  AssertFalse(F.SaveTo(Dir + '/missing/result.pdf'));
  AssertTrue(F.SaveButton.Enabled);
  AssertTrue(F.SaveTo(Dir + '/retry.pdf'));
end;

procedure TStartProtocolPrintIntegrationTests.NavigationZoomAndResizeRemainUsable;
var
  I: integer;
begin
  for I := 1 to 32 do Stages[I].isActive := True;
  F.ConfigureStart(C, Stages, srmAllStages, 8, rlEnglish, Dir);
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

procedure TStartProtocolPrintIntegrationTests.ReadErrorNoStagesAndEscape;
var
  I: integer;
begin
  for I := 1 to 32 do Stages[I].isActive := False;
  F.ConfigureStart(C, Stages, srmAllStages, 8, rlRussian, Dir);
  AssertFalse(F.SaveButton.Enabled);
  AssertTrue(F.StateLabel.Caption <> '');
  Stages[1].isActive := True;
  Exec('ALTER TABLE main RENAME TO absent_main');
  F.ConfigureStart(C, Stages, srmAllStages, 8, rlRussian, Dir);
  AssertFalse(F.SaveButton.Enabled);
  Exec('ALTER TABLE absent_main RENAME TO main');
  F.ConfigureStart(C, Stages, srmAllStages, 8, rlRussian, Dir);
  AssertTrue(F.SaveButton.Enabled);
  F.CloseButton.SetFocus;
  Gui.Drain('Focus Close');
  Gui.PressKey(F.CloseButton, VK_ESCAPE);
  AssertFalse(F.Visible);
  F.Show;
  Gui.Drain('Reopen overall protocol');
  AssertTrue(F.SaveButton.Enabled);
end;

procedure TStartProtocolPrintIntegrationTests.IndependentHeadingsAndSessionClosure;
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
  RegisterTest(TStartProtocolPrintIntegrationTests);
end.
