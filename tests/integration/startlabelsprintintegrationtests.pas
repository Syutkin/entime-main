unit StartLabelsPrintIntegrationTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry, StartLabelsPrintForm,
  CompetitionDbContext, StageModel, GuiTestSupport, Controls;

type
  TStartLabelsPrintIntegrationTests = class(TTestCase)
  private
    F: TStartLabelsPrintForm;
    C: TCompetitionDbContext;
    Stages: TStages;
    Gui: TGuiTestSession;
    Dir: string;
    NameText, NameDialogError: string;
    NameCancel, NameResponded, EndDuringName: boolean;
    procedure AnswerTemplateName(Data: PtrInt);
    procedure NameCommand(const Text: string; Cancel: boolean = False);
    procedure Exec(const SQL: string);
    procedure Click(Control: TWinControl);
    procedure FinishEditing(Control: TWinControl);
    procedure QueueCancelSave(Sender: TObject);
    procedure CancelSave(Data: PtrInt);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ParametersRebuildFrozenSnapshotAndResetFirstSlot;
    procedure InvalidAndIncompleteInputClearsDocumentAndRecovers;
    procedure FontOverflowAndRecovery;
    procedure NavigationResizeSaveRetryAndSession;
    procedure ReopenRestoresIniAndEscapeCloses;
    procedure EmptyNoStagesAndBusyCannotSave;
    procedure TypingAndCancellingSaveKeepDocumentUsable;
    procedure StartColumnsRebuildAndPersistWithoutReloadingStarts;
    procedure ManualDimensionsWaitForEnterAndFocusExit;
    procedure ThousandthsDimensionsAndMarginsRoundTrip;
    procedure OverflowKeepsPreviewNavigationAndShowsOnlyCount;
    procedure ArrowKeysAndButtonsRebuildImmediately;
    procedure FontRangeUsesSelectedMinimumAndStopsAt36;
    procedure TemplatesApplyFrozenSnapshotAndDirtyState;
    procedure TemplateErrorsKeepCurrentDocument;
    procedure TemplateReopenKeepsWorkingChanges;
    procedure TemplateCommandsUseNameDialogAndPreserveDocument;
    procedure TemplateNameCancelAndWriteErrorCanRetry;
    procedure TemplateSaveMissingFileAndOverflow;
    procedure TemplateNameDoesNotWriteAfterSessionEnds;
  end;

implementation

uses Forms, StdCtrls, SQLDB, CompetitionSchemaMigrator, FileUtil, LCLType,
  StartLabelReportBuilder, StartLabelModel, StartLabelSettings,
  StartLabelTemplates, StartLabelTemplateStore, InputDialogs, Dialogs, IniFiles, i18n
  {$IFDEF LCLQT6},Qt6{$ENDIF}
  {$IFDEF LCLWIN32},Windows{$ENDIF};

var
  TemplateTestError: string;

function CaptureTemplateError(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: longint): integer;
begin
  TemplateTestError := Msg;
  Result := mrOk;
end;

function FindNameEdit(Control: TWinControl): TCustomEdit;
var
  I: integer;
begin
  Result := nil;
  for I := 0 to Control.ControlCount - 1 do
  begin
    if Control.Controls[I] is TCustomEdit then Exit(TCustomEdit(Control.Controls[I]));
    if Control.Controls[I] is TWinControl then
      Result := FindNameEdit(TWinControl(Control.Controls[I]));
    if Result <> nil then Exit;
  end;
end;

procedure TStartLabelsPrintIntegrationTests.AnswerTemplateName(Data: PtrInt);
var
  Dialog: TCustomForm;
  Edit: TCustomEdit;
begin
  Dialog := Screen.ActiveCustomForm;
  try
    AssertTrue('InputQuery is open', Dialog <> F);
    AssertNotNull(Dialog);
    Edit := FindNameEdit(Dialog);
    AssertNotNull(Edit);
    Edit.SetFocus;
    Gui.Drain('Focus template name');
    Edit.SelectAll;
    Edit.SelText := '';
    Gui.TypeText(Edit, NameText);
    if EndDuringName then F.EndSession;
    if NameCancel then Gui.PressKey(Edit, VK_ESCAPE)
    else
      Gui.PressKey(Edit, VK_RETURN);
    NameResponded := True;
  except
    on E: Exception do
    begin
      NameDialogError := E.Message;
      if Dialog <> nil then Dialog.ModalResult := mrCancel;
    end;
  end;
end;

procedure TStartLabelsPrintIntegrationTests.NameCommand(const Text: string;
  Cancel: boolean);
begin
  NameText := Text;
  NameCancel := Cancel;
  NameResponded := False;
  NameDialogError := '';
  Application.QueueAsyncCall(@AnswerTemplateName, 0);
  F.SaveTemplateAsItem.Click;
  AssertEquals('', NameDialogError);
  AssertTrue('Standard name dialog was answered', NameResponded);
end;

procedure TStartLabelsPrintIntegrationTests.
TemplateCommandsUseNameDialogAndPreserveDocument;
var
  Store: TStartLabelTemplateStore;
  D: TStartLabelReport;
  L: TStartLabelTemplateFiles;
begin
  Store := TStartLabelTemplateStore.Create(Dir + '/templates');
  try
    F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
    D := F.Document;
    NameCommand('Моя бумага');
    AssertSame(D, F.Document);
    AssertEquals(1, F.TemplateCombo.ItemIndex);
    AssertEquals('Моя бумага', F.TemplateCombo.Text);
    AssertFalse(F.SaveTemplateChangesItem.Enabled);
    F.WidthEdit.Value := 80;
    FinishEditing(F.WidthEdit);
    F.FirstSlotEdit.Value := 2;
    FinishEditing(F.FirstSlotEdit);
    AssertTrue(F.SaveTemplateChangesItem.Enabled);
    L := Store.List;
    AssertEquals(70000, Store.Load(L[0].FileName).Paper.Width);
    D := F.Document;
    F.SaveTemplateChangesItem.Click;
    AssertSame(D, F.Document);
    AssertEquals(2, F.Paper.FirstSlot);
    AssertEquals(80000, Store.Load(L[0].FileName).Paper.Width);
    AssertFalse(F.SaveTemplateChangesItem.Enabled);
    AssertEquals('Моя бумага', F.TemplateCombo.Text);
  finally
    Store.Free;
  end;
end;

procedure TStartLabelsPrintIntegrationTests.TemplateNameCancelAndWriteErrorCanRetry;
var
  S: TStringList;
  D: TStartLabelReport;
begin
  F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
  D := F.Document;
  NameCommand('Cancelled', True);
  AssertEquals(0, F.TemplateCombo.ItemIndex);
  AssertFalse(DirectoryExists(Dir + '/templates'));
  AssertSame(D, F.Document);
  SetMessageDlgHandler(@CaptureTemplateError);
  try
    TemplateTestError := '';
    NameCommand('');
    AssertTrue(TemplateTestError <> '');
    AssertSame(D, F.Document);
    AssertEquals(0, F.TemplateCombo.ItemIndex);
    if DirectoryExists(Dir + '/templates') then
      DeleteDirectory(Dir + '/templates', False);
    S := TStringList.Create;
    try
      S.Text := 'not a directory';
      S.SaveToFile(Dir + '/templates');
    finally
      S.Free;
    end;
    TemplateTestError := '';
    NameCommand('Retry');
    AssertTrue(TemplateTestError <> '');
    AssertSame(D, F.Document);
    AssertEquals(0, F.TemplateCombo.ItemIndex);
    SysUtils.DeleteFile(Dir + '/templates');
    NameCommand('Retry');
    AssertEquals(1, F.TemplateCombo.ItemIndex);
    AssertSame(D, F.Document);
  finally
    ResetMessageDlgHandler;
  end;
end;

procedure TStartLabelsPrintIntegrationTests.TemplateSaveMissingFileAndOverflow;
var
  Store: TStartLabelTemplateStore;
  L: TStartLabelTemplateFiles;
  D: TStartLabelReport;
  I: integer;
begin
  Store := TStartLabelTemplateStore.Create(Dir + '/templates');
  try
    for I := 1 to 32 do Stages[I].isActive := True;
    F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
    AssertFalse(F.SaveButton.Enabled);
    AssertTrue(F.SaveTemplateAsItem.Enabled);
    NameCommand('Overflow is a valid format');
    F.FontEdit.Value := 10;
    FinishEditing(F.FontEdit);
    AssertTrue(F.SaveTemplateChangesItem.Enabled);
    L := Store.List;
    SysUtils.DeleteFile(Dir + '/templates/' + L[0].FileName);
    D := F.Document;
    SetMessageDlgHandler(@CaptureTemplateError);
    try
      TemplateTestError := '';
      F.SaveTemplateChangesItem.Click;
      AssertTrue(TemplateTestError <> '');
      AssertSame(D, F.Document);
      AssertTrue(F.SaveTemplateChangesItem.Enabled);
    finally
      ResetMessageDlgHandler;
    end;
    WriteStartLabelTemplate(Dir + '/templates/' + L[0].FileName,
      'Overflow is a valid format', DefaultStartLabelPaper);
    F.SaveTemplateChangesItem.Click;
    AssertEquals(10, Store.Load(L[0].FileName).Paper.FontSize);
    AssertFalse(F.SaveTemplateChangesItem.Enabled);
  finally
    Store.Free;
  end;
end;

procedure TStartLabelsPrintIntegrationTests.TemplateNameDoesNotWriteAfterSessionEnds;
begin
  F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
  EndDuringName := True;
  try
    NameCommand('Closed');
    AssertFalse(DirectoryExists(Dir + '/templates'));
    AssertFalse(F.SaveTemplateAsItem.Enabled);
  finally
    EndDuringName := False;
  end;
end;

procedure TStartLabelsPrintIntegrationTests.TemplatesApplyFrozenSnapshotAndDirtyState;
var
  Store: TStartLabelTemplateStore;
  P: TStartLabelPaper;
  A: TStartLabelTemplate;
  I: TMemIniFile;
begin
  Store := TStartLabelTemplateStore.Create(Dir + '/templates');
  try
    P := DefaultStartLabelPaper;
    P.Width := 105000;
    P.Height := 37125;
    P.StartColumns := 2;
    P.Left := 250;
    P.Right := 250;
    P.GapY := 500;
    P.Padding := 1500;
    P.FontSize := 12;
    P.DrawBorders := True;
    A := Store.CreateTemplate('My labels', P);
    F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
    AssertEquals(2, F.TemplateCombo.Items.Count);
    F.FirstSlotEdit.Value := 20;
    FinishEditing(F.FirstSlotEdit);
    Exec('UPDATE main SET name=''Changed''');
    F.TemplateCombo.SetFocus;
    Gui.Drain('Focus template selector');
    Gui.PressKey(F.TemplateCombo, VK_DOWN);
    AssertTrue(SameStartLabelTemplatePaper(P, F.Paper));
    AssertEquals(1, F.Paper.FirstSlot);
    AssertEquals('123 Rider', F.Cards[1].Title);
    AssertEquals('My labels', F.TemplateCombo.Text);
    F.FontEdit.Value := 13;
    FinishEditing(F.FontEdit);
    AssertTrue(Pos('*', F.TemplateCombo.Text) > 0);
    AssertEquals(12, Store.Load(A.FileName).Paper.FontSize);
    F.FontEdit.Value := 12;
    FinishEditing(F.FontEdit);
    AssertEquals('My labels', F.TemplateCombo.Text);
    F.FirstSlotEdit.Value := 2;
    FinishEditing(F.FirstSlotEdit);
    AssertEquals('My labels', F.TemplateCombo.Text);
    I := TMemIniFile.Create(Dir + '/settings.ini');
    try
      AssertEquals(A.FileName, I.ReadString('StartLabels', 'TemplateFile', ''));
    finally
      I.Free;
    end;
  finally
    Store.Free;
  end;
end;

procedure TStartLabelsPrintIntegrationTests.TemplateErrorsKeepCurrentDocument;
var
  Store: TStartLabelTemplateStore;
  A: TStartLabelTemplate;
  D: TStartLabelReport;
  S: TStringList;
  Ini: TMemIniFile;
begin
  Store := TStartLabelTemplateStore.Create(Dir + '/templates');
  try
    A := Store.CreateTemplate('Broken', DefaultStartLabelPaper);
    F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
    F.WidthEdit.Value := 80;
    FinishEditing(F.WidthEdit);
    D := F.Document;
    SysUtils.DeleteFile(Dir + '/templates/' + A.FileName);
    TemplateTestError := '';
    SetMessageDlgHandler(@CaptureTemplateError);
    F.TemplateCombo.SetFocus;
    Gui.Drain('Focus missing template');
    Gui.PressKey(F.TemplateCombo, VK_DOWN);
    AssertEquals('Missing template is silent', '', TemplateTestError);
    AssertSame(D, F.Document);
    AssertEquals(0, F.TemplateCombo.ItemIndex);
    AssertEquals(1, F.TemplateCombo.Items.Count);
    AssertEquals(80000, F.Paper.Width);
    AssertEquals(80000, LoadStartLabelPaper(Dir + '/settings.ini').Width);
    AssertFalse(F.SaveTemplateChangesItem.Enabled);
    Ini := TMemIniFile.Create(Dir + '/settings.ini');
    try
      AssertEquals('', Ini.ReadString('StartLabels', 'TemplateFile', 'missing'));
    finally
      Ini.Free;
    end;
    S := TStringList.Create;
    try
      S.Text := '[StartLabels]' + LineEnding + 'Width=broken';
      S.SaveToFile(Dir + '/templates/' + A.FileName);
    finally
      S.Free;
    end;
    F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
    D := F.Document;
    F.TemplateCombo.SetFocus;
    Gui.Drain('Focus damaged template');
    TemplateTestError := '';
    Gui.PressKey(F.TemplateCombo, VK_DOWN);
    AssertTrue(TemplateTestError <> '');
    AssertSame(D, F.Document);
    WriteStartLabelTemplate(Dir + '/templates/' + A.FileName, 'Recovered',
      DefaultStartLabelPaper);
    Gui.PressKey(F.TemplateCombo, VK_DOWN);
    AssertEquals(1, F.TemplateCombo.ItemIndex);
    AssertTrue(F.SaveButton.Enabled);
  finally
    ResetMessageDlgHandler;
    Store.Free;
  end;
end;

procedure TStartLabelsPrintIntegrationTests.TemplateReopenKeepsWorkingChanges;
var
  Store: TStartLabelTemplateStore;
  A: TStartLabelTemplate;
  Ini: TMemIniFile;
begin
  Store := TStartLabelTemplateStore.Create(Dir + '/templates');
  try
    A := Store.CreateTemplate('Saved', DefaultStartLabelPaper);
    F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
    F.TemplateCombo.SetFocus;
    Gui.Drain('Choose saved template');
    Gui.PressKey(F.TemplateCombo, VK_DOWN);
    F.WidthEdit.Value := 80;
    FinishEditing(F.WidthEdit);
    F.Free;
    F := nil;
    F := TStartLabelsPrintForm.Create(nil);
    F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
    F.Show;
    Gui.Drain('Restore edited template');
    AssertEquals(80000, F.Paper.Width);
    AssertEquals(1, F.TemplateCombo.ItemIndex);
    AssertTrue(Pos('*', F.TemplateCombo.Text) > 0);
    TemplateTestError := '';
    SetMessageDlgHandler(@CaptureTemplateError);
    SysUtils.DeleteFile(Dir + '/templates/' + A.FileName);
    F.Free;
    F := nil;
    F := TStartLabelsPrintForm.Create(nil);
    F.Configure(C, Stages, Dir + '/settings.ini', Dir + '/templates');
    F.Show;
    Gui.Drain('Restore after template removed externally');
    AssertEquals(80000, F.Paper.Width);
    AssertEquals(0, F.TemplateCombo.ItemIndex);
    AssertEquals('Missing saved template is silent', '', TemplateTestError);
    AssertEquals('', F.LastError);
    AssertTrue(F.SaveButton.Enabled);
    Ini := TMemIniFile.Create(Dir + '/settings.ini');
    try
      AssertEquals('', Ini.ReadString('StartLabels', 'TemplateFile', 'missing'));
    finally
      Ini.Free;
    end;
  finally
    ResetMessageDlgHandler;
    Store.Free;
  end;
end;

procedure TStartLabelsPrintIntegrationTests.FontRangeUsesSelectedMinimumAndStopsAt36;
var
  D: TStartLabelReport;
begin
  D := F.Document;
  F.FontEdit.SetFocus;
  Gui.Drain('Focus font for a value below the minimum');
  F.FontEdit.SelectAll;
  Gui.TypeText(F.FontEdit, '2');
  AssertSame('Typing still waits for completion', D, F.Document);
  Gui.PressKey(F.FontEdit, VK_RETURN);
  AssertEquals(6, F.FontEdit.Value);
  AssertEquals(6, F.Paper.FontSize);
  AssertEquals(6, LoadStartLabelPaper(Dir + '/settings.ini').FontSize);
  Gui.PressKey(F.FontEdit, VK_DOWN);
  AssertEquals('Arrow cannot go below the minimum', 6, F.FontEdit.Value);
  F.MinFontEdit.Value := 12;
  FinishEditing(F.MinFontEdit);
  AssertEquals('Raising the minimum also raises the font', 12, F.FontEdit.Value);
  AssertEquals(12, F.Paper.FontSize);
  AssertEquals(12, F.Paper.MinFontSize);
  F.FontEdit.SetFocus;
  Gui.Drain('Type a two-digit font without applying the first digit');
  F.FontEdit.SelectAll;
  Gui.TypeText(F.FontEdit, '3');
  AssertEquals(12, F.Paper.FontSize);
  Gui.TypeText(F.FontEdit, '6');
  Gui.PressKey(F.FontEdit, VK_RETURN);
  AssertEquals(36, F.Paper.FontSize);
  Gui.PressKey(F.FontEdit, VK_UP);
  AssertEquals('Arrow cannot go above 36', 36, F.FontEdit.Value);
  F.MinFontEdit.Value := 4;
  FinishEditing(F.MinFontEdit);
  F.FontEdit.SetFocus;
  Gui.Drain('Finish a smaller font by leaving the field');
  F.FontEdit.SelectAll;
  Gui.TypeText(F.FontEdit, '2');
  F.CloseButton.SetFocus;
  Gui.Drain('Commit font on focus exit');
  AssertEquals(4, F.FontEdit.Value);
  AssertEquals(4, F.Paper.FontSize);
  AssertEquals(4, LoadStartLabelPaper(Dir + '/settings.ini').FontSize);
end;

procedure TStartLabelsPrintIntegrationTests.ArrowKeysAndButtonsRebuildImmediately;
begin
  F.WidthEdit.SetFocus;
  Gui.Drain('Focus width for keyboard step');
  Gui.PressKey(F.WidthEdit, VK_UP);
  AssertEquals('Keyboard up immediately applies width', 71000, F.Paper.Width);
  Gui.PressKey(F.WidthEdit, VK_DOWN);
  AssertEquals(70000, F.Paper.Width);
  F.LeftEdit.Value := 1.25;
  FinishEditing(F.LeftEdit);
  Gui.PressKey(F.LeftEdit, VK_UP);
  AssertEquals('Keyboard step retains hundredths', 1350, F.Paper.Left);
  Gui.ClickSpinArrow(F.WidthEdit);
  AssertEquals('Mouse up immediately applies width', 71000, F.Paper.Width);
  Gui.ClickSpinArrow(F.LeftEdit);
  AssertEquals('Mouse step retains hundredths', 1450, F.Paper.Left);
  AssertEquals(1450, LoadStartLabelPaper(Dir + '/settings.ini').Left);
  AssertTrue(F.SaveButton.Enabled);
end;

procedure TStartLabelsPrintIntegrationTests.
OverflowKeepsPreviewNavigationAndShowsOnlyCount;
var
  I: integer;
begin
  for I := 1 to 32 do Stages[I].isActive := True;
  F.Configure(C, Stages, Dir + '/settings.ini');
  AssertNotNull('Overflow still has a preview', F.Document);
  AssertEquals(2, F.Document.OverflowCount);
  AssertTrue(F.NavigationPanel.Enabled);
  AssertFalse(F.SaveButton.Enabled);
  AssertTrue('Warning is concise', Length(F.LastError) < 160);
  AssertEquals(0, Pos('Rider', F.LastError));
  AssertEquals(0, Pos('Second', F.LastError));
  AssertFalse(F.SaveTo(Dir + '/clipped.pdf'));
  AssertFalse(FileExists(Dir + '/clipped.pdf'));
  F.FirstSlotEdit.Value := 24;
  FinishEditing(F.FirstSlotEdit);
  Click(F.LastButton);
  AssertEquals(2, F.PageSpin.Value);
  F.HeightEdit.Value := 148;
  FinishEditing(F.HeightEdit);
  F.WidthEdit.Value := 105;
  FinishEditing(F.WidthEdit);
  AssertEquals(0, F.Document.OverflowCount);
  AssertTrue(F.SaveButton.Enabled);
  AssertEquals('', F.LastError);
  AssertTrue(F.SaveTo(Dir + '/fits.pdf'));
end;

procedure TStartLabelsPrintIntegrationTests.ManualDimensionsWaitForEnterAndFocusExit;
var
  D: TStartLabelReport;
begin
  D := F.Document;
  F.WidthEdit.SetFocus;
  Gui.Drain('Focus width before typing');
  F.WidthEdit.SelectAll;
  Gui.TypeText(F.WidthEdit, '6');
  AssertSame('Intermediate width must not rebuild', D, F.Document);
  AssertEquals(70000, F.Paper.Width);
  AssertEquals(70000, LoadStartLabelPaper(Dir + '/settings.ini').Width);
  Gui.TypeText(F.WidthEdit, '0');
  AssertSame('Completed text waits for Enter', D, F.Document);
  Gui.Click(F.WidthEdit, F.WidthEdit.ClientWidth div 3, F.WidthEdit.ClientHeight div 2);
  AssertSame('Clicking the text does not commit a pending number', D, F.Document);
  Gui.PressKey(F.WidthEdit, VK_RETURN);
  AssertEquals(60000, F.Paper.Width);
  AssertTrue(F.SaveButton.Enabled);
  D := F.Document;
  F.HeightEdit.SetFocus;
  Gui.Drain('Focus height before typing');
  F.HeightEdit.SelectAll;
  Gui.TypeText(F.HeightEdit, '4');
  AssertSame(D, F.Document);
  Gui.TypeText(F.HeightEdit, '0');
  AssertSame(D, F.Document);
  F.CloseButton.SetFocus;
  Gui.Drain('Finish height on focus exit');
  AssertEquals(40000, F.Paper.Height);
  AssertTrue(F.SaveButton.Enabled);
end;

procedure TStartLabelsPrintIntegrationTests.
ThousandthsDimensionsAndMarginsRoundTrip;
var
  P: TStartLabelPaper;
begin
  P := DefaultStartLabelPaper;
  P.Width := 63400;
  P.Height := 37125;
  P.Left := 1245;
  P.Right := 2370;
  P.Top := 1260;
  P.Bottom := 3490;
  SaveStartLabelPaper(Dir + '/settings.ini', P);
  F.Configure(C, Stages, Dir + '/settings.ini');
  AssertEquals(63400, F.Paper.Width);
  AssertEquals(37125, F.Paper.Height);
  AssertEquals(1245, F.Paper.Left);
  AssertEquals(2370, F.Paper.Right);
  AssertEquals(1260, F.Paper.Top);
  AssertEquals(3490, F.Paper.Bottom);
  P := LoadStartLabelPaper(Dir + '/settings.ini');
  AssertEquals(63400, P.Width);
  AssertEquals(1245, P.Left);
  AssertEquals(1260, P.Top);
  F.HeightEdit.SetFocus;
  Gui.Drain('Focus height for exact typing');
  F.HeightEdit.SelectAll;
  Gui.TypeText(F.HeightEdit, FloatToStr(37.125));
  Gui.PressKey(F.HeightEdit, VK_RETURN);
  AssertEquals(37125, F.Paper.Height);
  Gui.PressKey(F.HeightEdit, VK_UP);
  AssertEquals('Size arrow moves by 1 mm without rounding', 38125, F.Paper.Height);
  AssertEquals(38125, LoadStartLabelPaper(Dir + '/settings.ini').Height);
  F.LeftEdit.SetFocus;
  Gui.Drain('Focus margin for precise typing');
  F.LeftEdit.SelectAll;
  Gui.TypeText(F.LeftEdit, FloatToStr(1.255));
  Gui.PressKey(F.LeftEdit, VK_RETURN);
  AssertEquals(1255, F.Paper.Left);
  Gui.PressKey(F.LeftEdit, VK_UP);
  Gui.PressKey(F.LeftEdit, VK_RETURN);
  AssertEquals('Arrow moves by 0.1 mm', 1355, F.Paper.Left);
  P := LoadStartLabelPaper(Dir + '/settings.ini');
  AssertEquals(1355, P.Left);
  AssertTrue(F.SaveButton.Enabled);
end;

procedure TStartLabelsPrintIntegrationTests.
StartColumnsRebuildAndPersistWithoutReloadingStarts;
var
  Combo: TComboBox;
begin
  Combo := F.FindComponent('StartColumnsCombo') as TComboBox;
  AssertNotNull('Start columns selector', Combo);
  AssertEquals(0, Combo.ItemIndex);
  Exec('UPDATE main SET name=''Changed''');
  Combo.SetFocus;
  Gui.Drain('Focus start columns');
  Gui.PressKey(Combo, VK_DOWN);
  AssertEquals(2, F.Paper.StartColumns);
  AssertTrue('Two blocks: ' + F.LastError, F.SaveButton.Enabled);
  AssertEquals('123 Rider', F.Cards[1].Title);
  AssertTrue(F.SaveTo(Dir + '/two-columns.pdf'));
  F.Free;
  F := nil;
  F := TStartLabelsPrintForm.Create(nil);
  F.Configure(C, Stages, Dir + '/settings.ini');
  F.Show;
  Gui.Drain('Restore start columns from INI');
  Combo := F.FindComponent('StartColumnsCombo') as TComboBox;
  AssertEquals(1, Combo.ItemIndex);
  AssertEquals(2, F.Paper.StartColumns);
  Combo.SetFocus;
  Gui.Drain('Focus restored start columns');
  Gui.PressKey(Combo, VK_UP);
  AssertEquals(1, F.Paper.StartColumns);
  AssertTrue(F.SaveButton.Enabled);
end;

procedure TStartLabelsPrintIntegrationTests.Exec(const SQL: string);
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

procedure TStartLabelsPrintIntegrationTests.Click(Control: TWinControl);
begin
  Gui.Click(Control, Control.ClientWidth div 2, Control.ClientHeight div 2);
end;

procedure TStartLabelsPrintIntegrationTests.FinishEditing(Control: TWinControl);
begin
  Control.SetFocus;
  Gui.Drain('Focus edited parameter');
  Gui.PressKey(Control, VK_RETURN);
end;

procedure TStartLabelsPrintIntegrationTests.QueueCancelSave(Sender: TObject);
begin
  Gui.WhenFileDialogReady(TFileDialog(Sender), @CancelSave);
end;

procedure TStartLabelsPrintIntegrationTests.CancelSave(Data: PtrInt);
{$IFDEF LCLQT6}var Dialog:QWidgetH;{$ENDIF}
{$IFDEF LCLWIN32}var Window:HWND;{$ENDIF}
begin
  {$IFDEF LCLQT6}
  Dialog:=QApplication_activeModalWidget();
  if Dialog<>nil then QDialog_reject(QDialogH(Pointer(Dialog)));
  {$ENDIF}
  {$IFDEF LCLWIN32}
  Window:=HWND(Data);
  Windows.PostMessage(Window,WM_CLOSE,0,0);
  {$ENDIF}
end;

procedure TStartLabelsPrintIntegrationTests.TypingAndCancellingSaveKeepDocumentUsable;
var
  D: TStartLabelReport;
begin
  F.WidthEdit.SetFocus;
  Gui.Drain('Focus label width');
  F.WidthEdit.SelectAll;
  Gui.TypeText(F.WidthEdit, '63');
  Gui.PressKey(F.WidthEdit, VK_RETURN);
  Gui.Drain('Type fractional label width');
  AssertEquals(63000, F.Paper.Width);
  AssertTrue(F.SaveButton.Enabled);
  D := F.Document;
  F.SaveDialog.OnShow := @QueueCancelSave;
  Click(F.SaveButton);
  AssertSame(D, F.Document);
  AssertTrue(F.SaveButton.Enabled);
  AssertTrue(F.SaveTo(Dir + '/after-cancel.pdf'));
end;

procedure TStartLabelsPrintIntegrationTests.SetUp;
var
  W: TCompetitionUnitOfWork;
begin
  Gui := TGuiTestSession.Create;
  Dir := SysUtils.GetTempFileName;
  SysUtils.DeleteFile(Dir);
  ForceDirectories(Dir);
  C := TCompetitionDbContext.Create;
  C.OpenFile(':memory:');
  Stages := TStages.Create(32);
  Stages[3].isActive := True;
  W := C.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(C.Connection, 32, 'A', 'B', 'C', 'D', 'E', 'Race');
    W.Commit;
  finally
    W.Free;
  end;
  Exec('INSERT INTO main(number,name,starttime1,starttime3) VALUES(123,''Rider'',''00:00:00.000'',''09:12:34.567''),(9,''Second'',NULL,NULL)');
  F := TStartLabelsPrintForm.Create(nil);
  F.Configure(C, Stages, Dir + '/settings.ini');
  F.Show;
  Gui.Drain('Open start labels');
end;

procedure TStartLabelsPrintIntegrationTests.TearDown;
begin
  Application.RemoveAsyncCalls(Self);
  F.Free;
  Stages.Free;
  C.Free;
  Gui.Free;
  DeleteDirectory(Dir, False);
end;

procedure TStartLabelsPrintIntegrationTests.
ParametersRebuildFrozenSnapshotAndResetFirstSlot;
begin
  AssertTrue('Ready: ' + F.LastError, F.SaveButton.Enabled);
  AssertEquals(2, Length(F.Cards));
  AssertEquals(9, F.Cards[0].Number);
  F.FirstSlotEdit.Value := 24;
  FinishEditing(F.FirstSlotEdit);
  Gui.Drain('Start at last label');
  AssertEquals(2, F.Document.PageCount);
  Exec('UPDATE main SET name=''Changed''');
  Click(F.BordersCheck);
  AssertTrue(F.Paper.DrawBorders);
  AssertEquals('123 Rider', F.Cards[1].Title);
  F.WidthEdit.Value := 105;
  FinishEditing(F.WidthEdit);
  Gui.Drain('Reduce sheet capacity');
  AssertEquals(1, F.FirstSlotEdit.Value);
  AssertTrue(F.SaveButton.Enabled);
  AssertEquals(105000, F.Paper.Width);
  F.GapXEdit.Value := 1.25;
  FinishEditing(F.GapXEdit);
  F.PaddingEdit.Value := 1.1;
  FinishEditing(F.PaddingEdit);
  Gui.Drain('Fractional spacing');
  AssertEquals(1250, F.Paper.GapX);
  AssertEquals(1100, F.Paper.Padding);
end;

procedure TStartLabelsPrintIntegrationTests.
InvalidAndIncompleteInputClearsDocumentAndRecovers;
begin
  AssertTrue(F.Document <> nil);
  F.WidthEdit.Value := 0;
  FinishEditing(F.WidthEdit);
  Gui.Drain('Invalid label width');
  AssertTrue(F.Document = nil);
  AssertFalse(F.SaveButton.Enabled);
  AssertTrue(F.LastError <> '');
  F.WidthEdit.Value := 70;
  FinishEditing(F.WidthEdit);
  Gui.Drain('Restore valid width');
  AssertTrue(F.SaveButton.Enabled);
  F.WidthEdit.Text := '';
  F.ParametersChange(F.WidthEdit);
  AssertTrue(F.Document = nil);
  AssertFalse(F.SaveButton.Enabled);
  F.WidthEdit.Text := '70';
  F.ParametersChange(F.WidthEdit);
  AssertTrue(F.SaveButton.Enabled);
  F.LeftEdit.Value := 200;
  FinishEditing(F.LeftEdit);
  Gui.Drain('Margins consume the sheet');
  AssertFalse(F.SaveButton.Enabled);
  F.LeftEdit.Value := 0;
  FinishEditing(F.LeftEdit);
  Gui.Drain('Recover after invalid margins');
  AssertTrue(F.SaveButton.Enabled);
end;

procedure TStartLabelsPrintIntegrationTests.FontOverflowAndRecovery;
var
  I: integer;
begin
  for I := 1 to 32 do Stages[I].isActive := True;
  F.Configure(C, Stages, Dir + '/settings.ini');
  AssertFalse(F.SaveButton.Enabled);
  AssertTrue(F.LastError <> '');
  AssertTrue('Font reduction remains visible alongside overflow',
    Pos(Format(rsLabelFontReduced, [F.Paper.FontSize, F.Document.TableFontSize]),
    F.StateLabel.Caption) > 0);
  F.HeightEdit.Value := 148;
  FinishEditing(F.HeightEdit);
  F.WidthEdit.Value := 105;
  FinishEditing(F.WidthEdit);
  Gui.Drain('Larger labels fit 32 stages');
  AssertTrue('Larger labels: ' + F.LastError, F.SaveButton.Enabled);
  F.FontEdit.Value := 10;
  FinishEditing(F.FontEdit);
  F.MinFontEdit.Value := 7;
  FinishEditing(F.MinFontEdit);
  Gui.Drain('Change font range');
  AssertTrue(F.SaveButton.Enabled);
  AssertTrue(F.Document.TableFontSize >= 7);
  F.FontEdit.Value := 36;
  FinishEditing(F.FontEdit);
  AssertEquals('The requested font is retained', 36, F.Paper.FontSize);
  AssertTrue(F.Document.TableFontSize < F.Paper.FontSize);
  AssertTrue('The status explains the requested and actual sizes',
    Pos(Format(rsLabelFontReduced, [36, F.Document.TableFontSize]),
    F.StateLabel.Caption) > 0);
  AssertTrue(F.SaveButton.Enabled);
  F.FontEdit.Value := 7;
  FinishEditing(F.FontEdit);
  AssertEquals(7, F.Document.TableFontSize);
  AssertEquals('The reduction notice clears when the requested font fits',
    Format(rsLabelReady, [Length(F.Cards), F.Document.PageCount, 7]),
    F.StateLabel.Caption);
end;

procedure TStartLabelsPrintIntegrationTests.NavigationResizeSaveRetryAndSession;
var
  I: integer;
begin
  AssertTrue(F.Document <> nil);
  F.FirstSlotEdit.Value := 24;
  FinishEditing(F.FirstSlotEdit);
  Gui.Drain('Multiple pages');
  Click(F.LastButton);
  AssertEquals(2, F.PageSpin.Value);
  Click(F.FirstButton);
  AssertEquals(1, F.PageSpin.Value);
  F.ZoomCombo.ItemIndex := 3;
  F.ZoomChange(F.ZoomCombo);
  for I := 0 to 5 do
  begin
    F.Width := 850 + I * 25;
    Gui.Drain('Resize labels preview');
  end;
  AssertFalse(F.SaveTo(Dir + '/missing/labels.pdf'));
  AssertTrue(F.SaveButton.Enabled);
  AssertTrue(F.SaveTo(Dir + '/labels.pdf'));
  AssertTrue(FileExists(Dir + '/labels.pdf'));
  F.EndSession;
  AssertFalse(F.SaveButton.Enabled);
  AssertFalse(F.SaveTo(Dir + '/closed.pdf'));
end;

procedure TStartLabelsPrintIntegrationTests.ReopenRestoresIniAndEscapeCloses;
begin
  F.WidthEdit.Value := 64;
  FinishEditing(F.WidthEdit);
  Click(F.BordersCheck);
  F.FirstSlotEdit.Value := 2;
  FinishEditing(F.FirstSlotEdit);
  Gui.Drain('Remember paper');
  F.Free;
  F := nil;
  F := TStartLabelsPrintForm.Create(nil);
  F.Configure(C, Stages, Dir + '/settings.ini');
  F.Show;
  Gui.Drain('Reopen labels');
  AssertEquals(64, F.WidthEdit.Value);
  AssertTrue(F.BordersCheck.Checked);
  AssertEquals(1, F.FirstSlotEdit.Value);
  F.CloseButton.SetFocus;
  Gui.Drain('Focus labels close button');
  Gui.PressKey(F.CloseButton, VK_ESCAPE);
  AssertFalse(F.Visible);
end;

procedure TStartLabelsPrintIntegrationTests.EmptyNoStagesAndBusyCannotSave;
var
  W: TCompetitionUnitOfWork;
begin
  W := C.BeginUnitOfWork;
  try
    F.Configure(C, Stages, Dir + '/settings.ini');
    AssertFalse(F.SaveButton.Enabled);
  finally
    W.Free;
  end;
  Stages[1].isActive := False;
  Stages[3].isActive := False;
  F.Configure(C, Stages, Dir + '/settings.ini');
  AssertFalse(F.SaveButton.Enabled);
  Stages[1].isActive := True;
  Exec('DELETE FROM main');
  F.Configure(C, Stages, Dir + '/settings.ini');
  AssertFalse(F.SaveButton.Enabled);
  AssertTrue(F.Document = nil);
end;

initialization
  RegisterTest(TStartLabelsPrintIntegrationTests);
end.
