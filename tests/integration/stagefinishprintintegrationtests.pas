unit StageFinishPrintIntegrationTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry, FinishProtocolPrintForm, GuiTestSupport,
  CompetitionDbContext, StageModel, Controls;

type
  TStageFinishPrintIntegrationTests = class(TTestCase)
  private
    FEndSessionWhileSaving, FChoosingTemplate: boolean;
    FSaveFilter: integer;
    FSavePath, FDialogError: string;
    FReturnedFileName, FSaveDirectory, FOverwriteTarget: string;
    FOverwriteAnswer, FOverwriteCount: integer;
    FEndSessionOnOverwrite: boolean;
    FForm: TFinishProtocolPrintForm;
    FGui: TGuiTestSession;
    C: TCompetitionDbContext;
    Stages: TStages;
    procedure Click(Control: TWinControl);
    procedure QueueCancelSave(Sender: TObject);
    procedure CancelSave(Data: PtrInt);
    procedure QueueAcceptSave(Sender: TObject);
    procedure AcceptSave(Data: PtrInt);
    procedure RecordReturnedFileName(Sender: TObject);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure HeadingsCheckboxRebuildsAndKeepsOtherOptions;
    procedure TemplateSelectionRebuildsAndKeepsOptions;
    procedure TemplateBrowseCancelAndSamePathReload;
    procedure InvalidTemplateClearsAndRecovers;
    procedure SavingUsesFrozenTemplate;
    procedure SessionClosedWhileChoosingTemplate;
    procedure PreparedReportRendersInNativePreview;
    procedure ParametersSelectionAndSaveReadiness;
    procedure NavigationZoomAndFrozenPages;
    procedure ReadFailureCanRetryAndEscapeCloses;
    procedure CancelSaveAndRetryAfterFileFailure;
    procedure FooterAndPenaltyChoicesRebuildPreview;
    procedure ResizingFitWidthPreviewKeepsReportUsable;
    procedure SaveDialogChoosesPdfDocxOrXlsxWithoutRebuilding;
    procedure ExistingFinalFileRequiresConfirmation;
    procedure OutputFormatFollowsResolvedFileName;
    procedure SessionClosedDuringOverwriteKeepsOldFile;
    procedure SessionClosedWhileChoosingFileDoesNotSave;

  end;

implementation

uses Forms, Dialogs, InputDialogs, i18n, LCLType, FileUtil, SQLDB,
  CompetitionSchemaMigrator, StageFinishReportModel, Graphics, fpreport,
  fpreportlclexport, StageFinishReportBackend, fpspreadsheet, fpstypes
  {$IFDEF LCLQT6},Qt6,QtObjects{$ENDIF}
  {$IFDEF LCLWIN32},Windows,ShlObj,ComObj,JwaWinBase{$ENDIF};
  {$IFDEF LCLQT6}
function QtSendSpontaneousEvent(Receiver:QObjectH;Event:QEventH):boolean;cdecl;
 external 'Qt6Core' name '_ZN16QCoreApplication20sendSpontaneousEventEP7QObjectP6QEvent';
  {$ENDIF}

var
  CurrentOverwriteTest: TStageFinishPrintIntegrationTests;

function ReplyToOverwrite(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: longint): integer;
begin
  Inc(CurrentOverwriteTest.FOverwriteCount);
  CurrentOverwriteTest.FOverwriteTarget :=
    CurrentOverwriteTest.FForm.SaveDialog.FileName;
  if (Msg <> rsFileExists) or (DlgType <> mtWarning) or
    (Buttons <> [mbOK, mbCancel]) or (HelpCtx <> 0) then
    CurrentOverwriteTest.FDialogError :=
      'Use the same overwrite dialog as the existing XLSX export';
  if CurrentOverwriteTest.FEndSessionOnOverwrite then
    CurrentOverwriteTest.FForm.EndSession;
  Result := CurrentOverwriteTest.FOverwriteAnswer;
end;

procedure TStageFinishPrintIntegrationTests.SetUp;
var
  W: TCompetitionUnitOfWork;
  Q: TSQLQuery;
  {$IFDEF LCLWIN32}
  LongDirectory: UnicodeString;
  DirectoryLength: DWORD;
  {$ENDIF}
begin
  FSaveDirectory := SysUtils.GetTempFileName;
  SysUtils.DeleteFile(FSaveDirectory);
  ForceDirectories(FSaveDirectory);
  {$IFDEF LCLWIN32}
  // The shell returns long names, while GetTempFileName may return a short path.
  DirectoryLength := JwaWinBase.GetLongPathNameW(PWideChar(UTF8Decode(FSaveDirectory)), nil, 0);
  AssertTrue('Resolve the test directory long name', DirectoryLength > 0);
  SetLength(LongDirectory, DirectoryLength);
  DirectoryLength := JwaWinBase.GetLongPathNameW(PWideChar(UTF8Decode(FSaveDirectory)),
    PWideChar(LongDirectory), DirectoryLength);
  AssertTrue('Read the test directory long name', DirectoryLength > 0);
  SetLength(LongDirectory, DirectoryLength);
  FSaveDirectory := UTF8Encode(LongDirectory);
  {$ENDIF}
  FGui := TGuiTestSession.Create;
  C := TCompetitionDbContext.Create;
  C.OpenFile(':memory:');
  Stages := TStages.Create(32);
  W := C.BeginUnitOfWork;
  Q := C.CreateQuery(nil);
  try
    TSchemaSql.ExecCreateTables(C.Connection, 32, 'A', 'B', 'C', 'D', 'E', 'Race');
    Q.SQL.Text := 'WITH RECURSIVE n(v) AS (SELECT 1 UNION ALL SELECT v+1 FROM n WHERE v<120) '
      + 'INSERT INTO main(number,name,category,result32,place32) SELECT v,''Rider ''||v,CASE WHEN v<60 THEN ''A'' ELSE ''B'' END,''00:01:00.123'',v FROM n';
    Q.ExecSQL;
    W.Commit;
  finally
    Q.Free;
    W.Free;
  end;
  FForm := TFinishProtocolPrintForm.Create(nil);
  FForm.ConfigureFinish(C, Stages, frmSingleStage, 32, rlRussian);
  CurrentOverwriteTest := Self;
  SetMessageDlgHandler(@ReplyToOverwrite);
end;

procedure TStageFinishPrintIntegrationTests.TearDown;
begin
  ResetMessageDlgHandler;
  CurrentOverwriteTest := nil;
  Application.RemoveAsyncCalls(Self);
  FForm.Free;
  Stages.Free;
  C.Free;
  FGui.Free;
  if FSaveDirectory <> '' then FileUtil.DeleteDirectory(FSaveDirectory, False);
end;

procedure TStageFinishPrintIntegrationTests.Click(Control: TWinControl);
begin
  FGui.Click(Control, Control.ClientWidth div 2, Control.ClientHeight div 2);
end;

procedure TStageFinishPrintIntegrationTests.ParametersSelectionAndSaveReadiness;
begin
  FForm.Show;
  FGui.Drain('Open report parameters');
  AssertEquals(32, FForm.SelectedStage);
  AssertTrue('Opening prepares the report', FForm.SaveButton.Enabled);
  AssertEquals(2, FForm.CategoriesList.Count);
  Click(FForm.ClearButton);
  AssertFalse(FForm.SaveButton.Enabled);
  AssertTrue(FForm.Document = nil);
  Click(FForm.AllButton);
  AssertTrue(FForm.SaveButton.Enabled);
  AssertEquals(120, Length(FForm.Snapshot.Rows));
  Click(FForm.IncompleteCheck);
  AssertTrue('No manual update after changing a checkbox', FForm.SaveButton.Enabled);
  AssertFalse(FForm.Snapshot.Options.IncludeIncomplete);
  FForm.OrientationCombo.SetFocus;
  FGui.Drain('Focus orientation');
  FGui.PressKey(FForm.OrientationCombo, VK_DOWN);
  AssertTrue(FForm.SaveButton.Enabled);
  AssertEquals(Ord(roLandscape), Ord(FForm.Snapshot.Options.Orientation));
  FForm.SelectStageCombo.SetFocus;
  FGui.Drain('Focus stage');
  FGui.PressKey(FForm.SelectStageCombo, VK_UP);
  AssertEquals(31, FForm.SelectedStage);
  AssertTrue('An empty selection clears the previous pages', FForm.Document = nil);
  AssertFalse(FForm.SaveButton.Enabled);
  AssertEquals('Keep the category list when no rows match', 2,
    FForm.CategoriesList.Count);
  Click(FForm.IncompleteCheck);
  AssertTrue(FForm.SaveButton.Enabled);
  AssertEquals(31, FForm.Snapshot.Options.StageIndex);
  FForm.CategoriesList.ItemIndex := 0;
  FForm.CategoriesList.SetFocus;
  FGui.Drain('Focus category');
  FGui.Click(FForm.CategoriesList, 8, FForm.CategoriesList.ItemHeight div 2);
  AssertFalse('Click unchecks the selected category', FForm.CategoriesList.Checked[0]);
  AssertTrue(FForm.SaveButton.Enabled);
  AssertEquals(61, Length(FForm.Snapshot.Rows));
  AssertEquals('B', FForm.Snapshot.Rows[0].Category);
end;

procedure TStageFinishPrintIntegrationTests.NavigationZoomAndFrozenPages;
var
  Old: TPreparedStageReport;
  Count: integer;
  Notice: string;
  W: TCompetitionUnitOfWork;
  Q: TSQLQuery;
begin
  FForm.Show;
  FGui.Drain('Open report');
  Old := FForm.Document;
  Count := Old.PageCount;
  Notice := FForm.StateLabel.Caption;
  AssertEquals('A ready preview needs no snapshot notice', '', Notice);
  AssertTrue(Count > 1);
  Click(FForm.LastButton);
  AssertEquals(Count, FForm.PageSpin.Value);
  Click(FForm.FirstButton);
  AssertEquals(1, FForm.PageSpin.Value);
  Click(FForm.NextButton);
  AssertEquals(2, FForm.PageSpin.Value);
  Click(FForm.PreviousButton);
  AssertEquals(1, FForm.PageSpin.Value);
  FForm.ZoomCombo.SetFocus;
  FGui.Drain('Focus zoom');
  FGui.PressKey(FForm.ZoomCombo, VK_DOWN);
  AssertSame(Old, FForm.Document);
  W := C.BeginUnitOfWork;
  Q := C.CreateQuery(nil);
  try
    Q.SQL.Text := 'UPDATE main SET name=''Changed rider'' WHERE number=1';
    Q.ExecSQL;
    W.Commit;
  finally
    Q.Free;
    W.Free;
  end;
  FGui.Drain('Saved data changes do not trigger background tracking');
  AssertTrue(FForm.SaveButton.Enabled);
  AssertSame(Old, FForm.Document);
  AssertEquals(Notice, FForm.StateLabel.Caption);
  AssertEquals('Rider 1', FForm.Snapshot.Rows[0].Name);
  Click(FForm.PenaltyCheck);
  AssertTrue(FForm.SaveButton.Enabled);
  AssertEquals('Changed rider', FForm.Snapshot.Rows[0].Name);
end;

procedure TStageFinishPrintIntegrationTests.ReadFailureCanRetryAndEscapeCloses;
var
  W: TCompetitionUnitOfWork;
  Q: TSQLQuery;
begin
  FForm.Show;
  FGui.Drain('Open report');
  W := C.BeginUnitOfWork;
  try
    Click(FForm.PenaltyCheck);
    AssertFalse(FForm.SaveButton.Enabled);
    AssertTrue(FForm.LastError <> '');
  finally
    W.Free;
  end;
  Click(FForm.PenaltyCheck);
  AssertTrue(FForm.SaveButton.Enabled);
  AssertEquals('', FForm.StateLabel.Caption);
  FForm.PageSpin.SetFocus;
  FGui.Drain('Focus page');
  FGui.PressKey(FForm.PageSpin, VK_ESCAPE);
  AssertFalse(FForm.Visible);
end;

procedure TStageFinishPrintIntegrationTests.FooterAndPenaltyChoicesRebuildPreview;
var
  Footer, Penalty: boolean;
begin
  FForm.Show;
  FGui.Drain('Report options');
  Footer := FForm.FooterCheck.Checked;
  Penalty := FForm.PenaltyCheck.Checked;
  AssertEquals(Footer, FForm.Snapshot.Options.ShowFooter);
  AssertEquals(Penalty, FForm.Snapshot.Options.ShowPenalty);
  Click(FForm.FooterCheck);
  AssertEquals(not Footer, FForm.Snapshot.Options.ShowFooter);
  AssertEquals(Penalty, FForm.Snapshot.Options.ShowPenalty);
  AssertTrue(FForm.SaveButton.Enabled);
  Click(FForm.PenaltyCheck);
  AssertEquals(not Footer, FForm.Snapshot.Options.ShowFooter);
  AssertEquals(not Penalty, FForm.Snapshot.Options.ShowPenalty);
  AssertTrue(FForm.SaveButton.Enabled);
  Click(FForm.FooterCheck);
  AssertEquals(Footer, FForm.Snapshot.Options.ShowFooter);
  AssertEquals(not Penalty, FForm.Snapshot.Options.ShowPenalty);
  Click(FForm.PenaltyCheck);
  AssertEquals(Penalty, FForm.Snapshot.Options.ShowPenalty);
  AssertTrue(FForm.SaveButton.Enabled);
end;

procedure TStageFinishPrintIntegrationTests.ResizingFitWidthPreviewKeepsReportUsable;
var
  D: TPreparedStageReport;
  I: integer;
begin
  FForm.Show;
  FGui.Drain('Open report before resizing');
  FForm.OrientationCombo.SetFocus;
  FGui.Drain('Focus orientation');
  FGui.PressKey(FForm.OrientationCombo, VK_DOWN);
  AssertEquals(Ord(roLandscape), Ord(FForm.Snapshot.Options.Orientation));
  AssertEquals('Use fit width', 0, FForm.ZoomCombo.ItemIndex);
  D := FForm.Document;
  // Cross the point where the page needs a vertical scrollbar in both
  // directions. Sizes are user actions, not assertions about the layout.
  for I := 0 to 150 do
  begin
    FForm.SetBounds(FForm.Left, FForm.Top, 1240, 900 - I * 2);
    FGui.Drain('Shrink preview window');
  end;
  for I := 0 to 150 do
  begin
    FForm.SetBounds(FForm.Left, FForm.Top, 1240, 600 + I * 2);
    FGui.Drain('Enlarge preview window');
  end;
  for I := 0 to 80 do
  begin
    FForm.SetBounds(FForm.Left, FForm.Top, 900 + I * 5, 720);
    FGui.Drain('Widen preview window');
  end;
  for I := 0 to 80 do
  begin
    FForm.SetBounds(FForm.Left, FForm.Top, 1300 - I * 5, 720);
    FGui.Drain('Narrow preview window');
  end;
  FForm.ZoomCombo.SetFocus;
  FGui.Drain('Focus zoom after resizing');
  FGui.PressKey(FForm.ZoomCombo, VK_DOWN);
  FGui.PressKey(FForm.ZoomCombo, VK_UP);
  AssertSame('Resizing keeps the prepared report', D, FForm.Document);
  AssertEquals('', FForm.LastError);
  AssertTrue(FForm.SaveButton.Enabled);
  Click(FForm.NextButton);
  AssertEquals('Navigation still responds', 2, FForm.PageSpin.Value);
  Click(FForm.CloseButton);
  AssertFalse('Closing still responds', FForm.Visible);
end;

procedure TStageFinishPrintIntegrationTests.QueueCancelSave(Sender: TObject);
begin
  FGui.WhenFileDialogReady(TFileDialog(Sender), @CancelSave);
end;

procedure TStageFinishPrintIntegrationTests.QueueAcceptSave(Sender: TObject);
begin
  {$IFDEF LCLWIN32}
  // SetFileTypeIndex is supported only before the native dialog is shown.
  OleCheck(IFileDialog(TFileDialog(Sender).Handle).SetFileTypeIndex(FSaveFilter));
  {$ENDIF}
  FGui.WhenFileDialogReady(TFileDialog(Sender), @AcceptSave);
end;

procedure TStageFinishPrintIntegrationTests.AcceptSave(Data: PtrInt);
{$IFDEF LCLQT6}var Path:WideString;Dialog:QFileDialogH;Tree:TQtObjectDump;
 Combo,Edit:QWidgetH;Event:QKeyEventH;Key,I:integer;{$ENDIF}
{$IFDEF LCLWIN32}var Dialog:IFileDialog;Path:UnicodeString;Window:HWND;Normalized:string;{$ENDIF}
begin
  try
    {$IFDEF LCLQT6}
  Dialog:=QFileDialogH(Pointer(QApplication_activeModalWidget()));
  if Dialog=nil then raise Exception.Create('No active file dialog');
  Tree:=TQtObjectDump.Create(Dialog);
  try
   Tree.DumpObject;Combo:=Tree.FindWidgetByName('fileTypeCombo');Edit:=Tree.FindWidgetByName('fileNameEdit');
   if (Combo=nil) or (Edit=nil) then raise Exception.Create('Native file dialog controls unavailable');
   QWidget_setFocus(Combo,QtOtherFocusReason);
   for I:=0 to FSaveFilter-1 do begin
    if I=0 then Key:=QtKey_Home else Key:=QtKey_Down;
    Event:=QKeyEvent_create(QEventKeyPress,Key,QtNoModifier);
    try QtSendSpontaneousEvent(Combo,Event);finally QKeyEvent_destroy(Event);end;
    Event:=QKeyEvent_create(QEventKeyRelease,Key,QtNoModifier);
    try QtSendSpontaneousEvent(Combo,Event);finally QKeyEvent_destroy(Event);end;
   end;
   Path:=UTF8Decode(FSavePath);QLineEdit_setText(QLineEditH(Pointer(Edit)),@Path);
   if FEndSessionWhileSaving then FForm.EndSession;
   QDialog_accept(Dialog);
  finally Tree.Free;end;
    {$ENDIF}
    {$IFDEF LCLWIN32}
  if FChoosingTemplate then Dialog:=IFileDialog(FForm.TemplateDialog.Handle)
  else Dialog:=IFileDialog(FForm.SaveDialog.Handle);Path:=UTF8Decode(FSavePath);
  if FChoosingTemplate then begin
   Normalized:=StringReplace(FSavePath,'/',DirectorySeparator,[rfReplaceAll]);
   Path:=UTF8Decode(Normalized);
   if GetFileAttributesW(PWideChar(Path))=INVALID_FILE_ATTRIBUTES then
    raise Exception.Create('Native file not found: '+Normalized);
   Path:=UTF8Decode(ExtractFileName(Normalized));
  end;
  OleCheck(Dialog.SetFileName(PWideChar(Path)));
  Window:=HWND(Data);
  if FEndSessionWhileSaving then FForm.EndSession;
  Windows.PostMessage(Window,WM_COMMAND,IDOK,0);
    {$ENDIF}
  except
    on E: Exception do
    begin
      FDialogError := E.Message;
      CancelSave(Data);
    end;
  end;
end;

procedure TStageFinishPrintIntegrationTests.
SaveDialogChoosesPdfDocxOrXlsxWithoutRebuilding;
const
  Exts: array[1..3] of string = ('.pdf', '.docx', '.xlsx');
var
  D: TPreparedStageReport;
  S: TStageReportSnapshot;
  Base, Path: string;
  FileData: TFileStream;
  Header: array[0..4] of char;
  I: integer;
  Book: TsWorkbook;
begin
  FForm.Show;
  FGui.Drain('Open report before choosing output format');
  D := FForm.Document;
  S := FForm.Snapshot;
  AssertTrue('The save dialog offers DOCX', Pos('*.docx', FForm.SaveDialog.Filter) > 0);
  AssertTrue('The save dialog offers XLSX', Pos('*.xlsx', FForm.SaveDialog.Filter) > 0);
  Base := FSaveDirectory + DirectorySeparator + 'report';
  FForm.SaveDialog.OnShow := @QueueAcceptSave;
  try
    for I := 3 downto 1 do
    begin
      FSaveFilter := I;
      FSavePath := Base + '-format' + IntToStr(I);
      if I = 1 then FForm.SaveDialog.FilterIndex := 3
      else
        FForm.SaveDialog.FilterIndex := 1;
      Path := FSavePath + Exts[I];
      Click(FForm.SaveButton);
      AssertEquals('', FDialogError);
      AssertEquals('', FForm.LastError);
      AssertEquals('Report filename includes the chosen extension', Path,
        FForm.SaveDialog.FileName);
      AssertTrue('Native dialog appends the chosen extension: ' +
        Path + '; returned ' + FForm.SaveDialog.FileName + '; filter ' +
        IntToStr(FForm.SaveDialog.FilterIndex), FileExists(Path));
      FileData := TFileStream.Create(Path, fmOpenRead);
      try
        FileData.ReadBuffer(Header, SizeOf(Header));
      finally
        FileData.Free;
      end;
      if I > 1 then AssertEquals('PK', Copy(string(Header), 1, 2))
      else
        AssertEquals('%PDF-', string(Header));
      if I = 3 then
      begin
        Book := TsWorkbook.Create;
        try
          Book.ReadFromFile(Path, sfOOXML);
          AssertEquals('The saved file is a spreadsheet', 1, Book.GetWorksheetCount);
        finally
          Book.Free;
        end;
      end;
      AssertSame('Saving keeps the preview', D, FForm.Document);
      AssertSame('Saving uses the displayed snapshot', S, FForm.Snapshot);
      AssertTrue(FForm.SaveButton.Enabled);
      SysUtils.DeleteFile(Path);
    end;
  finally
    SysUtils.DeleteFile(Base + '-format1.pdf');
    SysUtils.DeleteFile(Base + '-format2.docx');
    SysUtils.DeleteFile(Base + '-format3.xlsx');
  end;
end;

procedure TStageFinishPrintIntegrationTests.ExistingFinalFileRequiresConfirmation;
const
  Exts: array[1..3] of string = ('.pdf', '.docx', '.xlsx');
var
  Base, Path: string;
  I: integer;
  Old: TStringList;
  FileData: TFileStream;
  Header: array[0..4] of char;
begin
  FForm.Show;
  FGui.Drain('Open report before overwrite');
  Base := FSaveDirectory + DirectorySeparator + 'report';
  FForm.SaveDialog.OnShow := @QueueAcceptSave;
  try
    for I := 1 to 3 do
    begin
      FSaveFilter := I;
      FSavePath := Base + '-overwrite' + IntToStr(I);
      Path := FSavePath + Exts[I];
      Old := TStringList.Create;
      try
        Old.Text := 'old report';
        Old.SaveToFile(Path);
      finally
        Old.Free;
      end;
      FOverwriteAnswer := mrCancel;
      FOverwriteCount := 0;
      Click(FForm.SaveButton);
      AssertEquals('', FDialogError);
      AssertEquals('One confirmation for the final filename', 1, FOverwriteCount);
      AssertEquals(Path, FOverwriteTarget);
      Old := TStringList.Create;
      try
        Old.LoadFromFile(Path);
        AssertEquals('Declining keeps the old file', 'old report' +
          LineEnding, Old.Text);
      finally
        Old.Free;
      end;
      FOverwriteAnswer := mrOk;
      FOverwriteCount := 0;
      Click(FForm.SaveButton);
      AssertEquals('', FDialogError);
      AssertEquals(1, FOverwriteCount);
      AssertEquals('', FForm.LastError);
      AssertEquals(Path, FOverwriteTarget);
      FileData := TFileStream.Create(Path, fmOpenRead);
      try
        FileData.ReadBuffer(Header, SizeOf(Header));
      finally
        FileData.Free;
      end;
      if I = 1 then AssertEquals('%PDF-', string(Header))
      else
        AssertEquals('PK', Copy(string(Header), 1, 2));
      AssertTrue(FForm.SaveButton.Enabled);
      SysUtils.DeleteFile(Path);
    end;
  finally
    for I := 1 to 3 do SysUtils.DeleteFile(Base + '-overwrite' + IntToStr(I) + Exts[I]);
  end;
end;

procedure TStageFinishPrintIntegrationTests.RecordReturnedFileName(Sender: TObject);
begin
  FReturnedFileName := FForm.SaveDialog.FileName;
end;

procedure TStageFinishPrintIntegrationTests.OutputFormatFollowsResolvedFileName;
const
  Exts: array[1..3] of string = ('.PDF', '.DoCx', '.XlSx');
var
  Base, Path, Ext: string;
  I: integer;
  DataFile: TFileStream;
  Header: array[0..4] of char;
begin
  FForm.Show;
  FGui.Drain('Open report before entering an extension');
  Base := FSaveDirectory + DirectorySeparator + 'report';
  FForm.SaveDialog.OnShow := @QueueAcceptSave;
  FForm.SaveDialog.OnClose := @RecordReturnedFileName;
  try
    for I := 1 to 3 do
    begin
      FSaveFilter := (I mod 3) + 1;
      Path := Base + '-explicit' + Exts[I];
      FSavePath := Path;
      Click(FForm.SaveButton);
      AssertEquals('', FDialogError);
      AssertEquals('', FForm.LastError);
      Path := FForm.SaveDialog.FileName;
      Ext := ExtractFileExt(Path);
      AssertEquals('Keep the filename resolved by TSaveDialog', FReturnedFileName, Path);
      AssertTrue('Save the filename resolved by the dialog', FileExists(Path));
      DataFile := TFileStream.Create(Path, fmOpenRead);
      try
        DataFile.ReadBuffer(Header, SizeOf(Header));
      finally
        DataFile.Free;
      end;
      if SameText(Ext, '.pdf') then AssertEquals('%PDF-', string(Header))
      else
        AssertEquals('PK', Copy(string(Header), 1, 2));
      if SameText(Ext, '.xlsx') then
      begin
        with TsWorkbook.Create do
        try
          ReadFromFile(Path, sfOOXML);
          AssertEquals(1, GetWorksheetCount);
        finally
          Free;
        end;
      end;
      SysUtils.DeleteFile(Path);
    end;
  finally
    for I := 1 to 3 do
    begin
      SysUtils.DeleteFile(Base + '-explicit' + Exts[I]);
      SysUtils.DeleteFile(Base + '-explicit' + Exts[I] + '.docx');
      SysUtils.DeleteFile(Base + '-explicit' + Exts[I] + '.xlsx');
      SysUtils.DeleteFile(Base + '-explicit' + Exts[I] + '.pdf');
    end;
  end;
end;

procedure TStageFinishPrintIntegrationTests.SessionClosedDuringOverwriteKeepsOldFile;
var
  Base, Path: string;
  Old: TStringList;
begin
  FForm.Show;
  FGui.Drain('Open report before closing its session');
  Base := FSaveDirectory + DirectorySeparator + 'report';
  Path := Base + '.xlsx';
  Old := TStringList.Create;
  try
    Old.Text := 'old report';
    Old.SaveToFile(Path);
    FSaveFilter := 3;
    FSavePath := Base;
    FForm.SaveDialog.OnShow := @QueueAcceptSave;
    FEndSessionOnOverwrite := True;
    FOverwriteAnswer := mrOk;
    Click(FForm.SaveButton);
    AssertEquals('', FDialogError);
    AssertEquals(1, FOverwriteCount);
    AssertFalse(FForm.Visible);
    Old.LoadFromFile(Path);
    AssertEquals('old report' + LineEnding, Old.Text);
  finally
    Old.Free;
    SysUtils.DeleteFile(Path);
  end;
end;

procedure TStageFinishPrintIntegrationTests.SessionClosedWhileChoosingFileDoesNotSave;
begin
  FForm.Show;
  FGui.Drain('Open report before invalidating the session');
  FSaveFilter := 3;
  FSavePath := FSaveDirectory + DirectorySeparator + 'stale';
  FEndSessionWhileSaving := True;
  FForm.SaveDialog.OnShow := @QueueAcceptSave;
  Click(FForm.SaveButton);
  AssertEquals('', FDialogError);
  AssertFalse(FForm.Visible);
  AssertFalse(FForm.SaveButton.Enabled);
  AssertFalse('An accepted dialog cannot save a closed competition',
    FileExists(FSavePath + '.xlsx'));
end;

procedure TStageFinishPrintIntegrationTests.CancelSave(Data: PtrInt);
{$IFDEF LCLQT6}var Dialog:QWidgetH;{$ENDIF}
{$IFDEF LCLWIN32}var Window:HWND;{$ENDIF}
begin
  {$IFDEF LCLQT6}
Dialog:=QApplication_activeModalWidget();
  {$ENDIF}
  {$IFDEF LCLWIN32}
Window:=HWND(Data);
  {$ENDIF}
  if FEndSessionWhileSaving then FForm.EndSession;
  // Simulate cancellation by the user; application code only consumes Execute.
  {$IFDEF LCLQT6}
if Dialog<>nil then QDialog_reject(QDialogH(Pointer(Dialog)));
  {$ENDIF}
  {$IFDEF LCLWIN32}
Windows.PostMessage(Window,WM_CLOSE,0,0);
  {$ENDIF}
end;

procedure TStageFinishPrintIntegrationTests.CancelSaveAndRetryAfterFileFailure;
var
  D: TPreparedStageReport;
  Path: string;
begin
  FForm.Show;
  FGui.Drain('Report before saving');
  D := FForm.Document;
  FForm.SaveDialog.FilterIndex := 2;
  FForm.SaveDialog.OnShow := @QueueCancelSave;
  Click(FForm.SaveButton);
  AssertSame(D, FForm.Document);
  AssertTrue(FForm.SaveButton.Enabled);
  Path := SysUtils.GetTempFileName;
  SysUtils.DeleteFile(Path);
  AssertFalse(FForm.SaveTo(Path + '/missing/report.pdf'));
  AssertTrue(FForm.LastError <> '');
  AssertTrue(FForm.SaveButton.Enabled);
  try
    AssertTrue(FForm.SaveTo(Path));
    AssertTrue(FileExists(Path));
    AssertSame(D, FForm.Document);
    AssertEquals('Saving reports only the output path', Format(
      rsPrintExported, [Path]), FForm.StateLabel.Caption);
  finally
    SysUtils.DeleteFile(Path);
  end;
  FEndSessionWhileSaving := True;
  Click(FForm.SaveButton);
  AssertFalse(FForm.Visible);
  AssertFalse(FForm.SaveButton.Enabled);
  AssertFalse(FForm.SaveTo(Path));
end;

procedure TStageFinishPrintIntegrationTests.PreparedReportRendersInNativePreview;
var
  D: TPreparedStageReport;
  P: TFPReportPage;
  B: TFPReportTitleBand;
  M: TFPReportMemo;
  R: TFPReportExportCanvas;
  Bitmap: Graphics.TBitmap;
begin
  LoadReportFonts;
  D := TPreparedStageReport.Create;
  try
    P := TFPReportPage.Create(D.Report);
    P.PageSize.PaperName := 'A4';
    P.Font.Name := ReportRegularFont;
    B := TFPReportTitleBand.Create(P);
    B.Layout.Height := 20;
    M := TFPReportMemo.Create(B);
    M.Layout.Width := 180;
    M.Layout.Height := 15;
    M.Text := 'Протокол — Иван Иванов';
    D.Prepare;
    R := TFPReportExportCanvas.Create(nil);
    Bitmap := Graphics.TBitmap.Create;
    try
      Bitmap.SetSize(800, 1200);
      R.Canvas := Bitmap.Canvas;
      R.Zoom := 1;
      R.Report := D.Report;
      R.Execute;
      AssertEquals(D.PageCount, R.PageCount);
      R.PageIndex := 0;
      R.RenderCurrentPage;
    finally
      R.Free;
      Bitmap.Free;
    end;
  finally
    D.Free;
  end;
end;

function DialogDirectory(const Path: string): string;
begin
  Result := ExtractFileDir(StringReplace(Path, '/', DirectorySeparator, [rfReplaceAll]));
end;

procedure PutTemplate(const Path, Text: string);
var
  F: TStringStream;
begin
  F := TStringStream.Create(Text);
  try
    F.SaveToFile(Path);
  finally
    F.Free;
  end;
end;

procedure TStageFinishPrintIntegrationTests.TemplateSelectionRebuildsAndKeepsOptions;
var
  Path: string;
begin
  Path := FSaveDirectory + '/one.html';
  PutTemplate(Path, '<p>Custom title</p>{{RESULTS}}<p>Signature</p>');
  FForm.ConfigureFinish(C, Stages, frmSingleStage, 32, rlRussian, FSaveDirectory);
  FForm.Show;
  FGui.Drain('Show templates');
  AssertEquals(2, FForm.TemplateCombo.Items.Count);
  FForm.TemplateCombo.SetFocus;
  FGui.PressKey(FForm.TemplateCombo, VK_DOWN);
  AssertEquals('Custom title', FForm.Snapshot.Template.Header[0].Text);
  AssertTrue(Pos('Custom title', FForm.Document.PageText(0)) > 0);
  Click(FForm.HeadingsCheck);
  AssertFalse(FForm.Snapshot.Options.ShowHeadings);
  AssertEquals(0, Pos('Race', FForm.Document.PageText(0)));
  Click(FForm.PenaltyCheck);
  AssertEquals('Custom title', FForm.Snapshot.Template.Header[0].Text);
  FForm.OrientationCombo.SetFocus;
  FGui.PressKey(FForm.OrientationCombo, VK_DOWN);
  AssertEquals('Custom title', FForm.Snapshot.Template.Header[0].Text);
  FForm.TemplateCombo.SetFocus;
  FGui.PressKey(FForm.TemplateCombo, VK_UP);
  AssertEquals(0, Length(FForm.Snapshot.Template.Header));
  AssertTrue(FForm.SaveButton.Enabled);
end;

procedure TStageFinishPrintIntegrationTests.TemplateBrowseCancelAndSamePathReload;
var
  Path, Other: string;
  Old: TStageReportSnapshot;
begin
  Path := FSaveDirectory + '/one.html';
  Other := FSaveDirectory + '/другая папка/one.html';
  ForceDirectories(ExtractFilePath(Other));
  PutTemplate(Path, '<p>One</p>{{RESULTS}}');
  PutTemplate(Other, '<p>External</p>{{RESULTS}}');
  FForm.ConfigureFinish(C, Stages, frmSingleStage, 32, rlRussian, FSaveDirectory);
  FForm.Show;
  FGui.Drain('Show report');
  Old := FForm.Snapshot;
  FForm.TemplateDialog.OnShow := @QueueCancelSave;
  Click(FForm.BrowseTemplateButton);
  AssertSame('Cancel keeps prepared snapshot', Old, FForm.Snapshot);
  AssertEquals(0, FForm.TemplateCombo.ItemIndex);
  FChoosingTemplate := True;
  FSaveFilter := 1;
  FSavePath := Other;
  FForm.TemplateDialog.InitialDir := DialogDirectory(Other);
  FForm.TemplateDialog.OnShow := @QueueAcceptSave;
  Click(FForm.BrowseTemplateButton);
  AssertEquals('', FDialogError);
  AssertEquals('', FForm.LastError);
  AssertEquals(3, FForm.TemplateCombo.Items.Count);
  AssertEquals('External', FForm.Snapshot.Template.Header[0].Text);
  PutTemplate(Other, '<p>Reloaded</p>{{RESULTS}}');
  Click(FForm.BrowseTemplateButton);
  AssertEquals('', FDialogError);
  AssertEquals(3, FForm.TemplateCombo.Items.Count);
  AssertEquals('Reloaded', FForm.Snapshot.Template.Header[0].Text);
end;

procedure TStageFinishPrintIntegrationTests.InvalidTemplateClearsAndRecovers;
var
  Path: string;
begin
  Path := FSaveDirectory + '/bad.html';
  PutTemplate(Path, '<p>{{RESULTS}}</p>');
  FForm.ConfigureFinish(C, Stages, frmSingleStage, 32, rlRussian, FSaveDirectory);
  FForm.Show;
  FGui.Drain('Show report');
  FForm.CategoriesList.ItemIndex := 0;
  FForm.CategoriesList.SetFocus;
  FGui.Click(FForm.CategoriesList, 8, FForm.CategoriesList.ItemHeight div 2);
  AssertFalse(FForm.CategoriesList.Checked[0]);
  PutTemplate(Path, '<p>Broken</p>');
  FChoosingTemplate := True;
  FSaveFilter := 1;
  FSavePath := Path;
  FForm.TemplateDialog.InitialDir := DialogDirectory(Path);
  FForm.TemplateDialog.OnShow := @QueueAcceptSave;
  Click(FForm.BrowseTemplateButton);
  AssertEquals('', FDialogError);
  AssertTrue(FForm.Document = nil);
  AssertTrue(FForm.Snapshot = nil);
  AssertFalse(FForm.SaveButton.Enabled);
  AssertFalse(FForm.NavigationPanel.Enabled);
  AssertTrue(Pos('bad.html', FForm.LastError) > 0);
  AssertFalse(FForm.CategoriesList.Checked[0]);
  PutTemplate(Path, '<p>Fixed</p>{{RESULTS}}');
  Click(FForm.BrowseTemplateButton);
  AssertTrue(FForm.SaveButton.Enabled);
  AssertFalse(FForm.CategoriesList.Checked[0]);
  AssertEquals(61, Length(FForm.Snapshot.Rows));
  AssertEquals('Fixed', FForm.Snapshot.Template.Header[0].Text);
end;

procedure TStageFinishPrintIntegrationTests.SavingUsesFrozenTemplate;
const
  Exts: array[0..2] of string = ('.pdf', '.docx', '.xlsx');
var
  Path, Target: string;
  Old: TStageReportSnapshot;
  I: integer;
  Book: TsWorkbook;
begin
  Path := FSaveDirectory + '/snapshot.html';
  PutTemplate(Path, '<p>Frozen header</p>{{RESULTS}}<p>Frozen footer</p>');
  FForm.ConfigureFinish(C, Stages, frmSingleStage, 32, rlRussian, FSaveDirectory);
  FForm.Show;
  FGui.Drain('Show report');
  FForm.TemplateCombo.SetFocus;
  FGui.PressKey(FForm.TemplateCombo, VK_DOWN);
  Old := FForm.Snapshot;
  SysUtils.DeleteFile(Path);
  for I := 0 to 2 do
  begin
    Target := FSaveDirectory + '/frozen' + Exts[I];
    AssertTrue(FForm.SaveTo(Target));
    AssertSame(Old, FForm.Snapshot);
  end;
  Book := TsWorkbook.Create;
  try
    Book.ReadFromFile(Target, sfOOXML);
    AssertEquals('Frozen header', Book.GetWorksheetByIndex(0).ReadAsText(0, 0));
  finally
    Book.Free;
  end;
  Click(FForm.PenaltyCheck);
  AssertFalse(FForm.SaveButton.Enabled);
  AssertTrue(FForm.Document = nil);
  FForm.TemplateCombo.SetFocus;
  FGui.PressKey(FForm.TemplateCombo, VK_UP);
  AssertTrue(FForm.SaveButton.Enabled);
end;

procedure TStageFinishPrintIntegrationTests.SessionClosedWhileChoosingTemplate;
begin
  FForm.Show;
  FGui.Drain('Show report');
  FSavePath := FSaveDirectory + '/stale.html';
  PutTemplate(FSavePath, '{{RESULTS}}');
  FChoosingTemplate := True;
  FSaveFilter := 1;
  FEndSessionWhileSaving := True;
  FForm.TemplateDialog.InitialDir := DialogDirectory(FSavePath);
  FForm.TemplateDialog.OnShow := @QueueAcceptSave;
  Click(FForm.BrowseTemplateButton);
  AssertEquals('', FDialogError);
  AssertFalse(FForm.Visible);
  AssertFalse(FForm.SaveButton.Enabled);
end;

procedure TStageFinishPrintIntegrationTests.HeadingsCheckboxRebuildsAndKeepsOtherOptions;
var
  Footer: boolean;
  I: integer;
begin
  FForm.Show;
  FGui.Drain('Open headings option');
  AssertTrue(FForm.HeadingsCheck.Checked);
  Footer := FForm.FooterCheck.Checked;
  Click(FForm.HeaderCheck);
  Click(FForm.HeadingsCheck);
  AssertFalse(FForm.Snapshot.Options.ShowHeadings);
  AssertEquals(Footer, FForm.Snapshot.Options.ShowFooter);
  AssertTrue(FForm.SaveButton.Enabled);
  for I := 0 to FForm.Document.PageCount - 1 do
  begin
    AssertEquals(0, Pos(FForm.Snapshot.Labels.Title, FForm.Document.PageText(I)));
    AssertEquals(0, Pos(FForm.Snapshot.RaceName, FForm.Document.PageText(I)));
  end;
  Click(FForm.HeaderCheck);
  AssertTrue(FForm.Snapshot.Options.ShowHeader);
  AssertFalse(FForm.Snapshot.Options.ShowHeadings);
  AssertEquals(0, Pos(FForm.Snapshot.RaceName, FForm.Document.PageText(0)));
  Click(FForm.HeadingsCheck);
  AssertTrue(FForm.Snapshot.Options.ShowHeadings);
  AssertTrue(Pos(FForm.Snapshot.RaceName, FForm.Document.PageText(0)) > 0);
  for I := 0 to FForm.Document.PageCount - 1 do
    AssertTrue(Pos(FForm.Snapshot.Labels.Title, FForm.Document.PageText(I)) > 0);
end;

initialization
  RegisterTest(TStageFinishPrintIntegrationTests);
end.
