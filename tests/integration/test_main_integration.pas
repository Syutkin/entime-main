unit test_main_integration;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, Forms, Controls, fpcunit, testregistry,
  Main, Result, Settings, Startlist, Implement, i18n, db_sql, app_logger,
  synaser;

type
  TMainFlowIntegrationTests = class(TTestCase)
  private
    FDbFilePath: string;
    FCsvFilePath: string;
    FImportFilePath: string;
    FExpectedImportedRows: integer;

    class function ResolveRepoRoot: string; static;
    procedure EnsureFormsCreated;
    procedure CreateNewCompetitionFile;
    procedure WriteCsv(const ALines: array of string);
    procedure AssertTableExists(const ATableName: string);
    procedure AssertMainRowCount(const AExpectedCount: integer);
    procedure ConfigureSingleActiveStage(const AStageIndex: integer);
    procedure InsertParticipant(const AParticipantNumber: integer);
    procedure DeleteBackupFiles;
    procedure CloseSettingsForm(Data: PtrInt);
    function CountLogItemsContaining(const AText: string): integer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MainForm_SecondaryQuerySharesPrimaryConnectionAndTransaction;
    procedure RefreshAll_ActiveDatasetsRefetchWithoutReopening;
    procedure CreateNewCompetitionFile_ViaMainFormHandler_CreatesDbAndOpensDatasets;
    procedure CompetitionFileLifecycle_LogsActualPathOncePerStateChange;
    procedure CompetitionFileHistoryOpen_DoesNotDuplicateInfo;
    procedure CompetitionFileCreateError_LogsPathBeforeDialog;
    procedure AutomaticBackup_LogsOnlyToFile;
    procedure ImportStartListCp1251_ViaMainFormHandler_LoadsUtf8DataToMainTable;
    procedure ImportStartListCp1251_DoesNotRequireInteractiveDialogsInCI;
    procedure LoadParticipantsList_MinimalUtf8Csv_MapsParticipantAndStage;
    procedure LoadParticipantsList_TooManyStages_LogsPartialImportWarning;
    procedure LoadParticipantsList_ReimportExistingNumber_UpdatesWithoutDuplicate;
    procedure LoadParticipantsList_HtmlEntities_AreDecoded;
    procedure LoadParticipantsList_DatabaseError_RollsBackEntireImport;
    procedure LoadParticipantsList_WithoutNumberColumn_ReportsErrorAndImportsNothing;
    procedure LoadParticipantsList_InvalidStartTime_ReportsErrorAndImportsNothing;
    procedure LoadParticipantsList_DuplicateNumber_ReportsBothRows;
    procedure LoadStageResults_TwoColumns_ImportsFinishIntoSelectedStage;
    procedure LoadStageResults_ThreeColumns_ImportsStartIntoSelectedStage;
    procedure LoadStageResults_SixColumns_ImportsFullResultIntoSelectedStage;
    procedure LoadStageResults_DatabaseError_RollsBackEntireImport;
    procedure LoadStageResults_InvalidCsv_DoesNotChangeExistingResults;
    procedure LoadStageResults_InvalidCsv_DoesNotRequestStageSelection;
    procedure LoadStageResults_Reimport_UpdatesWithoutDuplicate;
    procedure LoadStageResults_StageSelectionCancellation_ChangesNothing;
    procedure LoadStageResults_DuplicateNumber_ReportsLocalizedCsvError;
    procedure LoadStageResults_UnknownParticipant_ConfirmationCreatesParticipant;
    procedure LoadStageResults_UnknownParticipant_RejectionSkipsOnlyUnknownResult;
    procedure AddDayResult_ValidCsv_ImportsRowsAndLogsSummary;
    procedure AddDayResult_DatabaseError_RollsBackAndLogsOnce;
    procedure ExportSqlCsvFiles_LogSuccessWithPathAndStage;
    procedure ExportDatasetCsvFiles_LogSuccessOnlyAfterWrite;
    procedure ExportAllResultsToXLSX_LogsSuccessAfterWrite;
    procedure ExportSqlCsvFailure_LogsErrorBeforeDialog;
    procedure ExportDatasetCsvFailure_DoesNotLogPrematureSuccess;
    procedure UpdateSumResults_PreparedSecondaryQueryPreservesStatusSemantics;
    procedure UpdateSumResults_ActiveStageTimesAreSummed;
    procedure ParticipantEdit_LogsSuccessfulSaveOnce;
    procedure ParticipantStageValueEdit_LogsSuccessfulSaveOnce;
    procedure CorrectionEdit_LogsParticipantStageAndValueOnce;
    procedure ParticipantDelete_LogsOnlyAfterConfirmedSave;
    procedure ParticipantStatus_LogsSuccessfulStageChangeOnce;
    procedure SerialStatus_LogsTransitionsWithoutRepeatedWarnings;
    procedure ModuleSync_ClosedPortLogsErrorWithoutSuccess;
    procedure ParseSerial_InvalidPacketsStayInDebugMemo;
    procedure LoRaActions_LogCompletedChanges;
    procedure LoRaChange_RefreshFailureKeepsSuccessAndWarns;
    procedure IntegrationActions_LogStateChanges;
    procedure LEDPanelCallbacks_LogManualTestOutcome;
    procedure TelegramTestFailure_DoesNotLogRequestSecrets;
    procedure SettingsCompetitionPage_UsesScrollableContent;
    procedure SettingsAccept_LogsSuccessfulSave;
    procedure SettingsCancel_DoesNotLogSave;
    procedure StartlistForm_UsesScrollableContent;
    procedure AppLog_RoutesOnlyToRequestedMainFormView;
    procedure AppLog_DefaultViewTimestampFormatting;
    procedure AppLog_ComboBoxHistoryKeepsOnlyNewestConfiguredItems;
    procedure AppLog_MemoHistoryTrimsOldestConfiguredBatch;
    procedure OpenLogActions_AreEnabledOnlyForCurrentFile;
    procedure LoggingIniSettings_AreAppliedToFileAndUi;
  end;

implementation

uses
  IniFiles;

var
  DialogCallCount: integer = 0;
  LastDialogMessage: string = '';
  LastDialogHadPriorLog: boolean = False;
  ConfirmationDialogResult: integer = mrYes;
  StageSelectionCallCount: integer = 0;
  StageSelectionResult: integer = 2;

function IntegrationMessageDlgHandler(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: LongInt): Integer;
begin
  Inc(DialogCallCount);
  LastDialogMessage := Msg;
  LastDialogHadPriorLog := Assigned(MainForm) and
    (((MainForm.ComboBoxLog.Items.Count > 0) and
    (Pos(Msg, MainForm.ComboBoxLog.Items[
      MainForm.ComboBoxLog.Items.Count - 1]) > 0)) or
    ((MainForm.Memo.Lines.Count > 0) and
    (Pos(Msg, MainForm.Memo.Lines[MainForm.Memo.Lines.Count - 1]) > 0)));
  if Pos(rsSetCategoryName, Msg) > 0 then
    Exit(mrNo);
  if mbYes in Buttons then
    Exit(ConfirmationDialogResult);
  Result := mrOK;
end;

function IntegrationStageSelectionHandler(const ACaption,
  APrompt: string): integer;
begin
  Inc(StageSelectionCallCount);
  Result := StageSelectionResult;
end;

class function TMainFlowIntegrationTests.ResolveRepoRoot: string;
begin
  Result := Trim(GetEnvironmentVariable('ENTIME_ROOT'));
  if Result <> '' then
    Exit(ExpandFileName(Result));

  Result := ExpandFileName(ExtractFileDir(ParamStr(0)) + DirectorySeparator +
    '..' + DirectorySeparator + '..');
end;

procedure TMainFlowIntegrationTests.EnsureFormsCreated;
begin
  if not Assigned(MainForm) then
    Application.CreateForm(TMainForm, MainForm);
  if not Assigned(ResultsForm) then
    Application.CreateForm(TResultsForm, ResultsForm);
end;

procedure TMainFlowIntegrationTests.CreateNewCompetitionFile;
begin
  MainForm.FileNewDB.Dialog.FileName := FDbFilePath;
  MainForm.FileNewDBAccept(MainForm.FileNewDB);
  AssertTrue('Expected DB file to be created: ' + FDbFilePath, FileExists(FDbFilePath));
  AssertTrue('Expected database datasets to be opened after DB creation', dbopen);
end;

procedure TMainFlowIntegrationTests.WriteCsv(const ALines: array of string);
var
  csvLines: TStringList;
  line: string;
begin
  csvLines := TStringList.Create;
  try
    for line in ALines do
      csvLines.Add(line);
    csvLines.SaveToFile(FCsvFilePath);
  finally
    csvLines.Free;
  end;
end;

procedure TMainFlowIntegrationTests.AssertTableExists(const ATableName: string);
begin
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = :table_name;';
  MainForm.SQLQuery1.ParamByName('table_name').AsString := ATableName;
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected table "' + ATableName + '" to exist', MainForm.SQLQuery1.IsEmpty);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.AssertMainRowCount(const AExpectedCount: integer);
begin
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text := 'SELECT COUNT(*) AS row_count FROM main;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Unexpected row count in main table', AExpectedCount,
    MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.ConfigureSingleActiveStage(
  const AStageIndex: integer);
var
  i: integer;
begin
  for i := 1 to MAXSTAGES do
  begin
    stages[i].isActive := i = AStageIndex;
    MainForm.CurrentSU.Buttons[i - 1].Enabled := i = AStageIndex;
  end;
  MainForm.CurrentSU.ItemIndex := AStageIndex - 1;
end;

procedure TMainFlowIntegrationTests.InsertParticipant(
  const AParticipantNumber: integer);
begin
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name) VALUES (:NUMBER, :NAME);';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := AParticipantNumber;
  MainForm.SQLQuery1.ParamByName('NAME').AsString := 'Test participant';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;
  RefreshAll;
end;

procedure TMainFlowIntegrationTests.DeleteBackupFiles;
var
  backupDirectory, fileMask: string;
  searchRec: TSearchRec;
begin
  if FDbFilePath = '' then
    Exit;

  backupDirectory := IncludeTrailingPathDelimiter(
    ExtractFilePath(FDbFilePath) + 'backup');
  fileMask := backupDirectory + '*' + ExtractFileName(FDbFilePath);

  if FindFirst(fileMask, faAnyFile, searchRec) = 0 then
  begin
    repeat
      if (searchRec.Attr and faDirectory) = 0 then
        DeleteFile(backupDirectory + searchRec.Name);
    until FindNext(searchRec) <> 0;
    FindClose(searchRec);
  end;
end;

procedure TMainFlowIntegrationTests.CloseSettingsForm(Data: PtrInt);
var
  i: integer;
begin
  for i := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[i] is TSettingsForm then
    begin
      Screen.Forms[i].ModalResult := TModalResult(Data);
      Exit;
    end;
end;

function TMainFlowIntegrationTests.CountLogItemsContaining(
  const AText: string): integer;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to MainForm.ComboBoxLog.Items.Count - 1 do
    if Pos(AText, MainForm.ComboBoxLog.Items[i]) > 0 then
      Inc(Result);
end;

procedure TMainFlowIntegrationTests.SetUp;
var
  repoRoot: string;
  fixtureLines: TStringList;
begin
  EnsureFormsCreated;
  MainForm.FileCloseExecute(nil);

  DialogCallCount := 0;
  LastDialogMessage := '';
  LastDialogHadPriorLog := False;
  ConfirmationDialogResult := mrYes;
  StageSelectionCallCount := 0;
  StageSelectionResult := 2;
  SetMessageDlgHandler(@IntegrationMessageDlgHandler);
  ResetStageSelectionHandler;

  FDbFilePath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    Format('entime-main-integration-%d.db', [GetTickCount64]);
  FCsvFilePath := ChangeFileExt(FDbFilePath, '.csv');
  if FileExists(FDbFilePath) then
    DeleteFile(FDbFilePath);
  if FileExists(FCsvFilePath) then
    DeleteFile(FCsvFilePath);

  repoRoot := ResolveRepoRoot;
  FImportFilePath := IncludeTrailingPathDelimiter(repoRoot) + 'startlist ansi.csv';
  AssertTrue('Missing fixture file: ' + FImportFilePath, FileExists(FImportFilePath));

  fixtureLines := TStringList.Create;
  try
    fixtureLines.LoadFromFile(FImportFilePath);
    FExpectedImportedRows := fixtureLines.Count - 1;
  finally
    fixtureLines.Free;
  end;
end;

procedure TMainFlowIntegrationTests.TearDown;
begin
  ResetStageSelectionHandler;
  ResetMessageDlgHandler;
  MainForm.FileCloseExecute(nil);
  DeleteBackupFiles;
  if FileExists(FDbFilePath) then
    DeleteFile(FDbFilePath);
  if FileExists(FCsvFilePath) then
    DeleteFile(FCsvFilePath);
end;

procedure TMainFlowIntegrationTests.MainForm_SecondaryQuerySharesPrimaryConnectionAndTransaction;
begin
  AssertSame(MainForm.SQLite3Connection1, MainForm.SQLQuery2.Database);
  AssertSame(MainForm.SQLTransaction1, MainForm.SQLQuery2.Transaction);
end;

procedure TMainFlowIntegrationTests.CompetitionFileLifecycle_LogsActualPathOncePerStateChange;
var
  competitionFile: string;
begin
  competitionFile := ExpandFileName(FDbFilePath);
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  CreateNewCompetitionFile;
  Application.ProcessMessages;

  AssertEquals(1, CountLogItemsContaining(
    Format(rsNewFileCreated, [competitionFile])));
  AssertEquals(1, CountLogItemsContaining(
    Format(rsDBFileOpen, [competitionFile])));

  MainForm.FileCloseExecute(nil);
  Application.ProcessMessages;

  AssertEquals(1, CountLogItemsContaining(
    Format(rsDBFileClosed, [competitionFile])));

  MainForm.FileCloseExecute(nil);
  Application.ProcessMessages;
  AssertEquals('Closing without an open file must not create another entry',
    1, CountLogItemsContaining(Format(rsDBFileClosed, [competitionFile])));
end;

procedure TMainFlowIntegrationTests.CompetitionFileHistoryOpen_DoesNotDuplicateInfo;
begin
  CreateNewCompetitionFile;
  MainForm.FileCloseExecute(nil);
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  MainForm.HistoryFiles1ClickHistoryItem(nil, nil, FDbFilePath);
  Application.ProcessMessages;

  AssertEquals(1, CountLogItemsContaining(
    Format(rsDBFileOpen, [ExpandFileName(FDbFilePath)])));
end;

procedure TMainFlowIntegrationTests.CompetitionFileCreateError_LogsPathBeforeDialog;
var
  blockingFile, competitionFile: string;
  content: TStringList;
begin
  blockingFile := ChangeFileExt(FDbFilePath, '.blocker');
  competitionFile := blockingFile + DirectorySeparator + 'race.db';
  content := TStringList.Create;
  try
    content.Add('not a directory');
    content.SaveToFile(blockingFile);
  finally
    content.Free;
  end;

  try
    MainForm.ComboBoxLog.Clear;
    DialogCallCount := 0;
    LastDialogHadPriorLog := False;

    InitDB(competitionFile);

    AssertEquals(1, DialogCallCount);
    AssertTrue('The file path must be present in the error',
      Pos(ExpandFileName(competitionFile), LastDialogMessage) > 0);
    AssertTrue('The error must be logged before the dialog',
      LastDialogHadPriorLog);
    AssertEquals(1, MainForm.ComboBoxLog.Items.Count);
  finally
    SetfName('');
    if FileExists(blockingFile) then
      DeleteFile(blockingFile);
  end;
end;

procedure TMainFlowIntegrationTests.AutomaticBackup_LogsOnlyToFile;
begin
  CreateNewCompetitionFile;
  MainForm.ComboBoxLog.Clear;

  AssertTrue(BackupBD(alvNone));

  AssertEquals(0, CountLogItemsContaining(Copy(rsBackupCreated, 1,
    Pos('%s', rsBackupCreated) - 1)));
end;

procedure TMainFlowIntegrationTests.AppLog_RoutesOnlyToRequestedMainFormView;
begin
  MainForm.ComboBoxLog.Clear;
  MainForm.Memo.Clear;

  AppLog('status message', allInfo, alvStatus, alsDatabase);
  AppLog('details message', allDebug, alvDetails, alsHTTP);
  AppLog('file only warning', allWarning, alvNone);

  AssertEquals(1, MainForm.ComboBoxLog.Items.Count);
  AssertTrue(Pos('status message', MainForm.ComboBoxLog.Items[0]) > 0);
  AssertTrue(Pos('[Database]', MainForm.ComboBoxLog.Items[0]) = 0);
  AssertEquals(MainForm.ComboBoxLog.Items[0], MainForm.ComboBoxLog.Text);
  AssertEquals(1, MainForm.Memo.Lines.Count);
  AssertEquals('details message', MainForm.Memo.Lines[0]);
end;

procedure TMainFlowIntegrationTests.AppLog_DefaultViewTimestampFormatting;
const
  STATUS_MESSAGE = 'timestamped status';
  DETAILS_MESSAGE = 'original details';
var
  statusText, timeText: string;
  parsedTime: TDateTime;
begin
  MainForm.ComboBoxLog.Clear;
  MainForm.Memo.Clear;

  AppLog(STATUS_MESSAGE, allInfo, alvStatus);
  AppLog(DETAILS_MESSAGE, allDebug, alvDetails);

  AssertEquals(1, MainForm.ComboBoxLog.Items.Count);
  statusText := MainForm.ComboBoxLog.Items[0];
  AssertEquals(Length(STATUS_MESSAGE) + 9, Length(statusText));
  AssertEquals(' ', statusText[9]);
  AssertEquals(STATUS_MESSAGE, Copy(statusText, 10, MaxInt));
  timeText := Copy(statusText, 1, 8);
  AssertTrue('ComboBoxLog timestamp must use hh:nn:ss',
    TryStrToTime(timeText, parsedTime));

  AssertEquals(1, MainForm.Memo.Lines.Count);
  AssertEquals(DETAILS_MESSAGE, MainForm.Memo.Lines[0]);
end;

procedure TMainFlowIntegrationTests.AppLog_ComboBoxHistoryKeepsOnlyNewestConfiguredItems;
var
  i, maxItems: integer;
begin
  MainForm.ComboBoxLog.Clear;
  maxItems := CurrentLoggingSettings.ComboBoxMaxItems;

  for i := 1 to maxItems + 5 do
    AppLog(Format('status-%d', [i]), allInfo, alvStatus);

  AssertEquals(maxItems, MainForm.ComboBoxLog.Items.Count);
  AssertTrue(Pos('status-6', MainForm.ComboBoxLog.Items[0]) > 0);
  AssertTrue(Pos(Format('status-%d', [maxItems + 5]),
    MainForm.ComboBoxLog.Items[maxItems - 1]) > 0);
  AssertEquals(MainForm.ComboBoxLog.Items[maxItems - 1],
    MainForm.ComboBoxLog.Text);
end;

procedure TMainFlowIntegrationTests.AppLog_MemoHistoryTrimsOldestConfiguredBatch;
var
  i, maxLines, trimLines: integer;
begin
  MainForm.Memo.Clear;
  maxLines := CurrentLoggingSettings.MemoMaxLines;
  trimLines := CurrentLoggingSettings.MemoTrimLines;

  for i := 1 to maxLines + 1 do
    AppLog(Format('detail-%d', [i]), allDebug, alvDetails);

  AssertEquals(maxLines + 1 - trimLines, MainForm.Memo.Lines.Count);
  AssertEquals(Format('detail-%d', [trimLines + 1]),
    MainForm.Memo.Lines[0]);
  AssertEquals(Format('detail-%d', [maxLines + 1]),
    MainForm.Memo.Lines[MainForm.Memo.Lines.Count - 1]);
end;

procedure TMainFlowIntegrationTests.OpenLogActions_AreEnabledOnlyForCurrentFile;
var
  logDirectory, logFileName: string;
begin
  logDirectory := ChangeFileExt(FDbFilePath, '') + '-logs';
  logFileName := '';
  FinalizeAppLogger;
  try
    MainForm.AcOpenLogFileUpdate(MainForm.AcOpenLogFile);
    MainForm.AcOpenLogDirectoryUpdate(MainForm.AcOpenLogDirectory);
    AssertFalse(MainForm.AcOpenLogFile.Enabled);
    AssertFalse(MainForm.AcOpenLogDirectory.Enabled);

    InitializeAppLogger(DefaultLoggingSettings, logDirectory, '');
    logFileName := CurrentAppLogFileName;
    MainForm.AcOpenLogFileUpdate(MainForm.AcOpenLogFile);
    MainForm.AcOpenLogDirectoryUpdate(MainForm.AcOpenLogDirectory);
    AssertTrue(MainForm.AcOpenLogFile.Enabled);
    AssertTrue(MainForm.AcOpenLogDirectory.Enabled);
  finally
    FinalizeAppLogger;
    if FileExists(logFileName) then
      DeleteFile(logFileName);
    if DirectoryExists(logDirectory) then
      RemoveDir(logDirectory);
  end;

  MainForm.AcOpenLogFileUpdate(MainForm.AcOpenLogFile);
  MainForm.AcOpenLogDirectoryUpdate(MainForm.AcOpenLogDirectory);
  AssertFalse(MainForm.AcOpenLogFile.Enabled);
  AssertFalse(MainForm.AcOpenLogDirectory.Enabled);
end;

procedure TMainFlowIntegrationTests.LoggingIniSettings_AreAppliedToFileAndUi;
var
  content, iniFileName, logDirectory, logFileName, restoreLogFileName,
    warning: string;
  ini: TIniFile;
  lines: TStringList;
  settings: TLoggingSettings;
begin
  iniFileName := ChangeFileExt(FDbFilePath, '.logging.ini');
  logDirectory := ChangeFileExt(FDbFilePath, '') + '-logging';
  logFileName := '';
  restoreLogFileName := '';

  ini := TIniFile.Create(iniFileName);
  try
    ini.WriteString('Logging', 'FileNamePrefix', 'ini-integration');
    ini.WriteString('Logging', 'FileMinimumLevel', 'info');
    ini.WriteInteger('Logging', 'RetentionDays', 7);
    ini.WriteInteger('Logging', 'ComboBoxMaxItems', 2);
    ini.WriteInteger('Logging', 'MemoMaxLines', 3);
    ini.WriteInteger('Logging', 'MemoTrimLines', 2);
    ini.WriteString('Logging', 'FileTimestampFormat', 'yyyy');
    ini.WriteString('Logging', 'ComboBoxTimestampFormat', 'hh:nn:ss.zzz');
    ini.WriteBool('Logging', 'MemoAddTimestamp', True);
    ini.UpdateFile;
  finally
    ini.Free;
  end;

  settings := LoadLoggingSettings(iniFileName, warning);
  AssertEquals('', warning);
  AssertEquals('ini-integration', settings.FileNamePrefix);
  AssertEquals(Ord(allInfo), Ord(settings.FileMinimumLevel));
  AssertEquals(7, settings.RetentionDays);
  AssertEquals(2, settings.ComboBoxMaxItems);
  AssertEquals(3, settings.MemoMaxLines);
  AssertEquals(2, settings.MemoTrimLines);
  AssertEquals('yyyy', settings.FileTimestampFormat);
  AssertEquals('hh:nn:ss.zzz', settings.ComboBoxTimestampFormat);
  AssertTrue(settings.MemoAddTimestamp);

  FinalizeAppLogger;
  try
    InitializeAppLogger(settings, logDirectory, '');
    logFileName := CurrentAppLogFileName;
    MainForm.ComboBoxLog.Clear;
    MainForm.Memo.Clear;

    AppLog('ini-status-1', allInfo, alvStatus);
    AppLog('ini-status-2', allInfo, alvStatus);
    AppLog('ini-status-3', allInfo, alvStatus);
    AppLog('ini-detail-1', allDebug, alvDetails);
    AppLog('ini-detail-2', allDebug, alvDetails);
    AppLog('ini-detail-3', allDebug, alvDetails);
    AppLog('ini-detail-4', allDebug, alvDetails);
    FinalizeAppLogger;

    AssertTrue(Pos('ini-integration-', ExtractFileName(logFileName)) = 1);
    lines := TStringList.Create;
    try
      lines.LoadFromFile(logFileName);
      content := lines.Text;
    finally
      lines.Free;
    end;
    AssertEquals('20', Copy(content, 1, 2));
    AssertTrue(Pos(' [INFO] [Application] File logger initialized',
      content) > 0);
    AssertTrue(Pos('ini-status-3', content) > 0);
    AssertTrue(Pos('ini-detail-1', content) = 0);

    AssertEquals(2, MainForm.ComboBoxLog.Items.Count);
    AssertTrue(Pos('ini-status-2', MainForm.ComboBoxLog.Items[0]) > 0);
    AssertTrue(Pos('ini-status-3', MainForm.ComboBoxLog.Items[1]) > 0);
    AssertEquals(12, Pos(' ', MainForm.ComboBoxLog.Items[1]) - 1);

    AssertEquals(2, MainForm.Memo.Lines.Count);
    AssertTrue(Pos('ini-detail-3', MainForm.Memo.Lines[0]) > 0);
    AssertTrue(Pos('ini-detail-4', MainForm.Memo.Lines[1]) > 0);
    AssertEquals(12, Pos(' ', MainForm.Memo.Lines[1]) - 1);
  finally
    FinalizeAppLogger;
    InitializeAppLogger(DefaultLoggingSettings, logDirectory, '');
    restoreLogFileName := CurrentAppLogFileName;
    FinalizeAppLogger;
    if FileExists(logFileName) then
      DeleteFile(logFileName);
    if FileExists(restoreLogFileName) then
      DeleteFile(restoreLogFileName);
    if DirectoryExists(logDirectory) then
      RemoveDir(logDirectory);
    if FileExists(iniFileName) then
      DeleteFile(iniFileName);
  end;
end;

procedure TMainFlowIntegrationTests.RefreshAll_ActiveDatasetsRefetchWithoutReopening;
var
  mainHandle, correctionHandle, stageSumHandle: Pointer;
begin
  CreateNewCompetitionFile;
  InsertParticipant(401);

  mainHandle := MainForm.MainDataset1.SqliteHandle;
  correctionHandle := MainForm.CorrectionDataset.SqliteHandle;
  stageSumHandle := MainForm.ResultDatasetStageSum.SqliteHandle;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET name = ''Updated participant'' WHERE number = 401;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  RefreshAll;

  AssertTrue('MainDataset1 SQLite handle must be reused',
    mainHandle = MainForm.MainDataset1.SqliteHandle);
  AssertTrue('CorrectionDataset SQLite handle must be reused',
    correctionHandle = MainForm.CorrectionDataset.SqliteHandle);
  AssertTrue('ResultDatasetStageSum SQLite handle must be reused',
    stageSumHandle = MainForm.ResultDatasetStageSum.SqliteHandle);
  AssertTrue(MainForm.MainDataset1.Locate('number', 401, []));
  AssertEquals('Updated participant',
    MainForm.MainDataset1.FieldByName('name').AsString);
end;

procedure TMainFlowIntegrationTests.CreateNewCompetitionFile_ViaMainFormHandler_CreatesDbAndOpensDatasets;
var
  expectedRaceName: string;
begin
  CreateNewCompetitionFile;

  AssertTableExists('main');
  AssertTableExists('config');
  AssertTableExists('load');

  expectedRaceName := ChangeFileExt(ExtractFileName(FDbFilePath), '');
  AssertEquals('Unexpected default race name in config', expectedRaceName,
    TConfigSql.GetString(MainForm.SQLQuery1, 'racename', ''));
end;

procedure TMainFlowIntegrationTests.ImportStartListCp1251_ViaMainFormHandler_LoadsUtf8DataToMainTable;
begin
  CreateNewCompetitionFile;

  MainForm.FileOpenCSV.Dialog.FileName := FImportFilePath;
  MainForm.FileOpenCSVAccept(MainForm.FileOpenCSV);

  AssertMainRowCount(FExpectedImportedRows);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name, city, starttime1, starttime2 FROM main WHERE number = 2;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected row for participant number 2', MainForm.SQLQuery1.IsEmpty);
  AssertEquals('Unexpected participant name after CP1251 import',
    'Алексахина Варвара', MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('Unexpected participant city after CP1251 import',
    'Занаду', MainForm.SQLQuery1.FieldByName('city').AsString);
  AssertEquals('Unexpected starttime1 value', '10:00:00',
    MainForm.SQLQuery1.FieldByName('starttime1').AsString);
  AssertEquals('Unexpected starttime2 value', '11:00:00',
    MainForm.SQLQuery1.FieldByName('starttime2').AsString);
  MainForm.SQLQuery1.Close;

  AssertEquals('Unexpected stage 1 name in config', 'Старт 1',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename1', ''));
  AssertEquals('Unexpected stage 2 name in config', 'Старт 2',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename2', ''));
  AssertTrue('Expected stage1 to be active in config',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage1', False));
  AssertTrue('Expected stage2 to be active in config',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage2', False));
end;

procedure TMainFlowIntegrationTests.ImportStartListCp1251_DoesNotRequireInteractiveDialogsInCI;
begin
  CreateNewCompetitionFile;

  DialogCallCount := 0;
  MainForm.FileOpenCSV.Dialog.FileName := FImportFilePath;
  MainForm.FileOpenCSVAccept(MainForm.FileOpenCSV);

  AssertTrue('Expected at least one dialog call to be handled by the test hook',
    DialogCallCount > 0);
  AssertMainRowCount(FExpectedImportedRows);
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_MinimalUtf8Csv_MapsParticipantAndStage;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'number;name;category;nickname;birthday;team;city;phone;email;comment;Prologue',
    '42;Alice Rider;Elite;ali;1995;Fast Team;Perm;+79990000000;alice@example.test;Guest;09:15:00,123'
  ]);
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;
  MainForm.Memo.Clear;

  LoadParticipantsList(FCsvFilePath);
  Application.ProcessMessages;

  AssertEquals('Expected one participant import summary', 1,
    CountLogItemsContaining(Format(rsParticipantsImported,
      [1, ExpandFileName(FCsvFilePath)])));
  AssertTrue('Detected stages must be logged as one contextual message',
    Pos(Format(rsDetectedParticipantStages, ['Prologue']),
      MainForm.Memo.Text) > 0);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT category, name, nickname, age, team, city, phone, email, ' +
    'comment, starttime1 FROM main WHERE number = 42;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 42', MainForm.SQLQuery1.IsEmpty);
  AssertEquals('Elite', MainForm.SQLQuery1.FieldByName('category').AsString);
  AssertEquals('Alice Rider', MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('ali', MainForm.SQLQuery1.FieldByName('nickname').AsString);
  AssertEquals('1995', MainForm.SQLQuery1.FieldByName('age').AsString);
  AssertEquals('Fast Team', MainForm.SQLQuery1.FieldByName('team').AsString);
  AssertEquals('Perm', MainForm.SQLQuery1.FieldByName('city').AsString);
  AssertEquals('+79990000000', MainForm.SQLQuery1.FieldByName('phone').AsString);
  AssertEquals('alice@example.test',
    MainForm.SQLQuery1.FieldByName('email').AsString);
  AssertEquals('Guest', MainForm.SQLQuery1.FieldByName('comment').AsString);
  AssertEquals('09:15:00.123',
    MainForm.SQLQuery1.FieldByName('starttime1').AsString);
  MainForm.SQLQuery1.Close;

  AssertEquals('Prologue',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename1', ''));
  AssertTrue('Expected imported stage to be active',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage1', False));
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_TooManyStages_LogsPartialImportWarning;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'number;name;S1;S2;S3;S4;S5;S6;S7;S8;S9',
    '42;Alice;10:00;10:01;10:02;10:03;10:04;10:05;10:06;10:07;10:08'
  ]);
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  LoadParticipantsList(FCsvFilePath);
  Application.ProcessMessages;

  AssertMainRowCount(1);
  AssertEquals('Expected one partial participant import warning', 1,
    CountLogItemsContaining(Format(rsParticipantsImportPartial,
      [1, MAXSTAGES, MAXSTAGES + 1, ExpandFileName(FCsvFilePath)])));
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_ReimportExistingNumber_UpdatesWithoutDuplicate;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'number;name;category;Stage 1',
    '77;First Name;Open;10:00:00'
  ]);
  LoadParticipantsList(FCsvFilePath);

  WriteCsv([
    'number;name;category;Stage 1',
    '77;Updated Name;Masters;10:30:00'
  ]);
  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name, category, starttime1 FROM main WHERE number = 77;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 77', MainForm.SQLQuery1.IsEmpty);
  AssertEquals('Updated Name', MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('Masters', MainForm.SQLQuery1.FieldByName('category').AsString);
  AssertEquals('10:30:00',
    MainForm.SQLQuery1.FieldByName('starttime1').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_HtmlEntities_AreDecoded;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'category;number;name;team;comment;Stage 1',
    'Masters;99;"O&#39;Connor";"RiderShop&amp;Service";"Text; quoted";11:30:00'
  ]);

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name, team, comment FROM main WHERE number = 99;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 99', MainForm.SQLQuery1.IsEmpty);
  AssertEquals('O''Connor', MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('RiderShop&Service',
    MainForm.SQLQuery1.FieldByName('team').AsString);
  AssertEquals('Text; quoted',
    MainForm.SQLQuery1.FieldByName('comment').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_DatabaseError_RollsBackEntireImport;
begin
  CreateNewCompetitionFile;
  TConfigSql.ExecUpsertByKey(
    MainForm.SQLQuery1, 'stagename1', 'Existing Stage');

  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO load (number, name) VALUES (500, ''Existing participant'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.SQL.Text :=
    'CREATE TRIGGER reject_participant BEFORE INSERT ON load ' +
    'WHEN NEW.number = 2 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced import failure''); END;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    'number;name;New Stage',
    '1;First participant;10:00:00',
    '2;Second participant;10:01:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  LoadParticipantsList(FCsvFilePath);
  Application.ProcessMessages;

  AssertMainRowCount(0);
  AssertTrue('Expected database error dialog', DialogCallCount > 0);
  AssertTrue('Expected participant database error context, got: ' +
    LastDialogMessage,
    Pos(rsWriteParticipantsDatabaseError, LastDialogMessage) > 0);
  AssertTrue('Expected forced database error, got: ' + LastDialogMessage,
    Pos('forced import failure', LastDialogMessage) > 0);
  AssertTrue('Expected import file path in error, got: ' + LastDialogMessage,
    Pos(ExpandFileName(FCsvFilePath), LastDialogMessage) > 0);
  AssertEquals('Expected exactly one participant import error', 1,
    CountLogItemsContaining(LastDialogMessage));
  AssertEquals('Existing Stage',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename1', ''));

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count FROM load WHERE number = 500;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Previous load rows must be restored after rollback',
    1, MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_WithoutNumberColumn_ReportsErrorAndImportsNothing;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'name;category;Stage 1',
    'No Number;Open;10:00:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(0);
  AssertEquals('Expected exactly one import error dialog', 1, DialogCallCount);
  AssertEquals(Format(rsParticipantsImportError,
    [ExpandFileName(FCsvFilePath),
    rsLoadParticipantsListError + rsNumberColumnNotFound]), LastDialogMessage);
  AssertTrue('Import error must be logged before its dialog',
    LastDialogHadPriorLog);
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_InvalidStartTime_ReportsErrorAndImportsNothing;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'number;name;Stage 1',
    '42;Alice Rider;25:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(0);
  AssertEquals('Expected exactly one import error dialog', 1, DialogCallCount);
  AssertEquals(Format(rsParticipantsImportError,
    [ExpandFileName(FCsvFilePath), rsLoadParticipantsListError +
    Format(rsInvalidParticipantStartTime,
      ['25:00', 2, 'Stage 1'])]), LastDialogMessage);
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_DuplicateNumber_ReportsBothRows;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    '# participant import',
    'number;name;Stage 1',
    '42;Alice Rider;10:00:00',
    '# duplicate follows',
    '42;Bob Rider;10:01:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(0);
  AssertEquals('Expected exactly one import error dialog', 1, DialogCallCount);
  AssertEquals(Format(rsParticipantsImportError,
    [ExpandFileName(FCsvFilePath), rsLoadParticipantsListError +
    Format(rsDuplicateParticipantNumber, [42, 3, 5])]), LastDialogMessage);
end;

procedure TMainFlowIntegrationTests.LoadStageResults_TwoColumns_ImportsFinishIntoSelectedStage;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(101);
  WriteCsv([
    '######;',
    '#номер;время финиша',
    '101;11:00:00.123'
  ]);
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  LoadStageResults(FCsvFilePath);
  Application.ProcessMessages;

  AssertEquals('Expected one result import summary', 1,
    CountLogItemsContaining(Format(rsResultsImported,
      [2, stages[2].Name, 1, ExpandFileName(FCsvFilePath)])));

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime1, finishtime2, status2 FROM main WHERE number = 101;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 101', MainForm.SQLQuery1.IsEmpty);
  AssertTrue('Stage 1 finish time must remain empty',
    MainForm.SQLQuery1.FieldByName('finishtime1').IsNull);
  AssertEquals('11:00:00.123',
    MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  AssertTrue('Finish import without DNF must not set a status',
    MainForm.SQLQuery1.FieldByName('status2').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_ThreeColumns_ImportsStartIntoSelectedStage;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(102);
  WriteCsv([
    '######',
    '#номер;время старта;стартовая поправка',
    '102;10:00:00;-250'
  ]);

  LoadStageResults(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT starttime1, starttime2, correction2, status2 ' +
    'FROM main WHERE number = 102;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 102', MainForm.SQLQuery1.IsEmpty);
  AssertTrue('Stage 1 start time must remain empty',
    MainForm.SQLQuery1.FieldByName('starttime1').IsNull);
  AssertEquals('10:00:00',
    MainForm.SQLQuery1.FieldByName('starttime2').AsString);
  AssertEquals(-250, MainForm.SQLQuery1.FieldByName('correction2').AsInteger);
  AssertTrue('Start import without DNS must not set a status',
    MainForm.SQLQuery1.FieldByName('status2').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_SixColumns_ImportsFullResultIntoSelectedStage;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(103);
  WriteCsv([
    '######',
    '#номер;время старта;стартовая поправка;время финиша;штраф;статус',
    '103;10:00:00;-250;11:00:00.123;00:00:05;'
  ]);

  LoadStageResults(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT starttime1, finishtime1, starttime2, correction2, ' +
    'finishtime2, penalty2, status2 FROM main WHERE number = 103;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 103', MainForm.SQLQuery1.IsEmpty);
  AssertTrue('Stage 1 start time must remain empty',
    MainForm.SQLQuery1.FieldByName('starttime1').IsNull);
  AssertTrue('Stage 1 finish time must remain empty',
    MainForm.SQLQuery1.FieldByName('finishtime1').IsNull);
  AssertEquals('10:00:00',
    MainForm.SQLQuery1.FieldByName('starttime2').AsString);
  AssertEquals(-250, MainForm.SQLQuery1.FieldByName('correction2').AsInteger);
  AssertEquals('11:00:00.123',
    MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  AssertEquals('00:00:05',
    MainForm.SQLQuery1.FieldByName('penalty2').AsString);
  AssertTrue('Full import without a status must leave it empty',
    MainForm.SQLQuery1.FieldByName('status2').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_DatabaseError_RollsBackEntireImport;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(104);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = ''10:30:00'' WHERE number = 104;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO loadresult (number, finishtime) VALUES (999, ''09:00:00'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.SQL.Text :=
    'CREATE TRIGGER reject_result BEFORE UPDATE ON main ' +
    'WHEN NEW.number = 104 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced result import failure''); END;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;finish time',
    '104;11:00:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  LoadStageResults(FCsvFilePath);
  Application.ProcessMessages;

  AssertTrue('Expected database error dialog', DialogCallCount > 0);
  AssertTrue('Expected database error context, got: ' + LastDialogMessage,
    Pos(rsWriteResultsDatabaseError, LastDialogMessage) > 0);
  AssertTrue('Expected forced result error, got: ' + LastDialogMessage,
    Pos('forced result import failure', LastDialogMessage) > 0);
  AssertTrue('Expected import file path in error, got: ' + LastDialogMessage,
    Pos(ExpandFileName(FCsvFilePath), LastDialogMessage) > 0);
  AssertEquals('Expected exactly one result import error', 1,
    CountLogItemsContaining(LastDialogMessage));

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 104;';
  MainForm.SQLQuery1.Open;
  AssertEquals('10:30:00',
    MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;

  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, finishtime FROM loadresult;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Previous staging row must be restored after rollback',
    1, MainForm.SQLQuery1.RecordCount);
  AssertEquals(999, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('09:00:00',
    MainForm.SQLQuery1.FieldByName('finishtime').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_InvalidCsv_DoesNotChangeExistingResults;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(105);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = ''10:30:00'' WHERE number = 105;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;finish time',
    '105;25:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadStageResults(FCsvFilePath);

  AssertTrue('Expected CSV validation error dialog', DialogCallCount > 0);
  AssertEquals(Format(rsResultsImportError,
    [ExpandFileName(FCsvFilePath), rsLoadResultsError +
    Format(rsInvalidResultTime, ['25:00', 2, rsFinishtime])]),
    LastDialogMessage);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 105;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Existing finish time must survive CSV validation failure',
    '10:30:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_InvalidCsv_DoesNotRequestStageSelection;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(108);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = ''10:30:00'' WHERE number = 108;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;finish time',
    '108;25:00'
  ]);
  SetStageSelectionHandler(@IntegrationStageSelectionHandler);

  LoadStageResults(FCsvFilePath);

  AssertEquals('Invalid CSV must not request stage selection',
    0, StageSelectionCallCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 108;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Invalid CSV must not change the existing finish time',
    '10:30:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_Reimport_UpdatesWithoutDuplicate;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(109);

  WriteCsv([
    '# number;finish time',
    '109;10:00:00'
  ]);
  LoadStageResults(FCsvFilePath);

  DeleteBackupFiles;
  WriteCsv([
    '# number;finish time',
    '109;11:00:00'
  ]);
  LoadStageResults(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count, MAX(finishtime2) AS finishtime2 ' +
    'FROM main WHERE number = 109;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Reimport must not create a duplicate participant',
    1, MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  AssertEquals('Reimport must replace the existing result',
    '11:00:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_StageSelectionCancellation_ChangesNothing;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(110);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = ''10:30:00'' WHERE number = 110;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO loadresult (number, finishtime) VALUES (999, ''09:00:00'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;finish time',
    '110;11:00:00'
  ]);
  StageSelectionResult := -1;
  SetStageSelectionHandler(@IntegrationStageSelectionHandler);
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  LoadStageResults(FCsvFilePath);
  Application.ProcessMessages;

  AssertEquals('Expected one stage selection request',
    1, StageSelectionCallCount);
  AssertEquals('Cancellation must not create an import summary', 0,
    CountLogItemsContaining(Copy(rsResultsImported, 1,
      Pos('%', rsResultsImported) - 1)));
  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 110;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Cancellation must preserve the existing result',
    '10:30:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;

  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, finishtime FROM loadresult;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Cancellation must preserve the staging row',
    1, MainForm.SQLQuery1.RecordCount);
  AssertEquals(999, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('09:00:00',
    MainForm.SQLQuery1.FieldByName('finishtime').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_DuplicateNumber_ReportsLocalizedCsvError;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(107);

  WriteCsv([
    '# number;finish time',
    '107;10:00:00',
    '# duplicate follows',
    '107;11:00:00'
  ]);

  LoadStageResults(FCsvFilePath);

  AssertEquals('Expected exactly one CSV validation error dialog',
    1, DialogCallCount);
  AssertEquals(Format(rsResultsImportError,
    [ExpandFileName(FCsvFilePath), rsLoadResultsError +
    Format(rsDuplicateResultParticipantNumber, [107, 2, 4])]),
    LastDialogMessage);
  AssertEquals('CSV error must not use the database prefix',
    0, Pos(rsDatabaseOpenError, LastDialogMessage));

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 107;';
  MainForm.SQLQuery1.Open;
  AssertTrue('Duplicate CSV must not change the participant result',
    MainForm.SQLQuery1.FieldByName('finishtime2').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_UnknownParticipant_ConfirmationCreatesParticipant;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(106);

  WriteCsv([
    '# number;finish time',
    '999;11:00:00'
  ]);

  LoadStageResults(FCsvFilePath);

  AssertTrue('Expected confirmation for unknown participant',
    DialogCallCount > 0);
  AssertTrue('Unexpected confirmation text: ' + LastDialogMessage,
    Pos(Format(rsAddUnknownResultParticipant, [999]),
    LastDialogMessage) > 0);
  AssertMainRowCount(2);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 999;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Confirmed participant must be created',
    MainForm.SQLQuery1.IsEmpty);
  AssertEquals('11:00:00',
    MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_UnknownParticipant_RejectionSkipsOnlyUnknownResult;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(106);

  WriteCsv([
    '# number;finish time',
    '106;10:00:00',
    '999;11:00:00'
  ]);
  ConfirmationDialogResult := mrNo;
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  LoadStageResults(FCsvFilePath);
  Application.ProcessMessages;

  AssertTrue('Expected confirmation for unknown participant',
    DialogCallCount > 0);
  AssertEquals('Expected one partial import warning', 1,
    CountLogItemsContaining(Format(rsResultsImportPartial,
      [2, stages[2].Name, 1, 2, ExpandFileName(FCsvFilePath)])));
  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 106;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Known participant result must still be imported',
    '10:00:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;

  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count FROM main WHERE number = 999;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Rejected participant must not be created',
    0, MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.AddDayResult_ValidCsv_ImportsRowsAndLogsSummary;
begin
  CreateNewCompetitionFile;
  MainForm.SQLQuery1.SQL.Text := TSumDaysSql.CreateTableIfNotExists;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  WriteCsv([
    '801;00:10:00.000;1;0',
    '802;00:11:00.000;1;0'
  ]);
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  AddDayResult(FCsvFilePath);
  Application.ProcessMessages;

  AssertEquals('Expected one day import summary', 1,
    CountLogItemsContaining(Format(rsDayResultsImported,
      [2, ExpandFileName(FCsvFilePath)])));
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count FROM sumdays WHERE number IN (801, 802);';
  MainForm.SQLQuery1.Open;
  AssertEquals(2, MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.AddDayResult_DatabaseError_RollsBackAndLogsOnce;
begin
  CreateNewCompetitionFile;
  MainForm.SQLQuery1.SQL.Text := TSumDaysSql.CreateTableIfNotExists;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO load (number, name) VALUES (500, ''existing'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'CREATE TRIGGER reject_day_result BEFORE INSERT ON load ' +
    'WHEN NEW.number = 802 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced day import failure''); END;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  WriteCsv([
    '801;00:10:00.000;1;0',
    '802;00:11:00.000;1;0'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';
  Application.ProcessMessages;
  MainForm.ComboBoxLog.Clear;

  AddDayResult(FCsvFilePath);
  Application.ProcessMessages;

  AssertEquals('Expected exactly one day import error dialog', 1,
    DialogCallCount);
  AssertTrue('Expected day import path in error, got: ' + LastDialogMessage,
    Pos(ExpandFileName(FCsvFilePath), LastDialogMessage) > 0);
  AssertTrue('Expected database failure details, got: ' + LastDialogMessage,
    Pos('forced day import failure', LastDialogMessage) > 0);
  AssertTrue('The error must be logged before the dialog',
    LastDialogHadPriorLog);
  AssertEquals('Expected exactly one day import error', 1,
    CountLogItemsContaining(LastDialogMessage));
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count FROM load WHERE number = 500;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Previous staging row must survive rollback', 1,
    MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count FROM sumdays;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Failed import must not update sumdays', 0,
    MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.ExportSqlCsvFiles_LogSuccessWithPathAndStage;
var
  stageFileName, allFileName, sumFileName: string;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(301);
  MainForm.SQLQuery1.SQL.Text := TSumDaysSql.CreateTableIfNotExists;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO sumdays (number, sumresult, sumstages, status) ' +
    'VALUES (301, ''00:10:00'', 1, ''0'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  stageFileName := ChangeFileExt(FCsvFilePath, '.stage.csv');
  allFileName := ChangeFileExt(FCsvFilePath, '.all.csv');
  sumFileName := ChangeFileExt(FCsvFilePath, '.sum.csv');
  try
    Application.ProcessMessages;
    MainForm.ComboBoxLog.Clear;

    ExportFinishTime(stageFileName, 2);
    ExportAllResults(allFileName);
    ExportSumDays(sumFileName);
    Application.ProcessMessages;

    AssertTrue(FileExists(stageFileName));
    AssertTrue(FileExists(allFileName));
    AssertTrue(FileExists(sumFileName));
    AssertEquals(1, CountLogItemsContaining(Format(rsStageResultsExported,
      [2, stages[2].Name, ExpandFileName(stageFileName)])));
    AssertEquals(1, CountLogItemsContaining(Format(rsAllResultsExported,
      [ExpandFileName(allFileName)])));
    AssertEquals(1, CountLogItemsContaining(Format(rsSumDaysExported,
      [ExpandFileName(sumFileName)])));
  finally
    if FileExists(stageFileName) then DeleteFile(stageFileName);
    if FileExists(allFileName) then DeleteFile(allFileName);
    if FileExists(sumFileName) then DeleteFile(sumFileName);
  end;
end;

procedure TMainFlowIntegrationTests.ExportDatasetCsvFiles_LogSuccessOnlyAfterWrite;
var
  startListFileName, resultsFileName: string;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(302);
  startListFileName := ChangeFileExt(FCsvFilePath, '.start.csv');
  resultsFileName := ChangeFileExt(FCsvFilePath, '.results.csv');
  try
    Application.ProcessMessages;
    MainForm.ComboBoxLog.Clear;

    ExportCSVStartList(startListFileName);
    ExportCSVResults(resultsFileName);
    Application.ProcessMessages;

    AssertTrue(FileExists(startListFileName));
    AssertTrue(FileExists(resultsFileName));
    AssertEquals(1, CountLogItemsContaining(Format(rsStartListExported,
      [ExpandFileName(startListFileName)])));
    AssertEquals(1, CountLogItemsContaining(Format(rsCSVResultsExported,
      [ExpandFileName(resultsFileName)])));
  finally
    if FileExists(startListFileName) then DeleteFile(startListFileName);
    if FileExists(resultsFileName) then DeleteFile(resultsFileName);
  end;
end;

procedure TMainFlowIntegrationTests.ExportAllResultsToXLSX_LogsSuccessAfterWrite;
var
  exportFileName: string;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(303);
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET category = ''Open'', sumresult = ''00:10:00'', ' +
    'sumplace = 1 WHERE number = 303;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  RefreshAll;
  exportFileName := ChangeFileExt(FCsvFilePath, '.xlsx');
  try
    Application.ProcessMessages;
    MainForm.ComboBoxLog.Clear;

    AssertTrue(ExportAllResultsToXLSX(exportFileName));
    Application.ProcessMessages;

    AssertTrue(FileExists(exportFileName));
    AssertEquals(1, CountLogItemsContaining(Format(rsFullResultsExported,
      [ExpandFileName(exportFileName)])));
  finally
    if FileExists(exportFileName) then DeleteFile(exportFileName);
  end;
end;

procedure TMainFlowIntegrationTests.ExportSqlCsvFailure_LogsErrorBeforeDialog;
var
  blockingFileName, exportFileName: string;
  content: TStringList;
begin
  CreateNewCompetitionFile;
  InsertParticipant(304);
  blockingFileName := ChangeFileExt(FCsvFilePath, '.blocker');
  exportFileName := blockingFileName + DirectorySeparator + 'all.csv';
  content := TStringList.Create;
  try
    content.Add('not a directory');
    content.SaveToFile(blockingFileName);
  finally
    content.Free;
  end;
  try
    DialogCallCount := 0;
    Application.ProcessMessages;
    MainForm.ComboBoxLog.Clear;

    ExportAllResults(exportFileName);
    Application.ProcessMessages;

    AssertEquals(1, DialogCallCount);
    AssertTrue(Pos(ExpandFileName(exportFileName), LastDialogMessage) > 0);
    AssertTrue(LastDialogHadPriorLog);
    AssertEquals(1, CountLogItemsContaining(LastDialogMessage));
    AssertEquals(0, CountLogItemsContaining(Copy(rsAllResultsExported, 1,
      Pos('%', rsAllResultsExported) - 1)));
  finally
    if FileExists(blockingFileName) then DeleteFile(blockingFileName);
  end;
end;

procedure TMainFlowIntegrationTests.ExportDatasetCsvFailure_DoesNotLogPrematureSuccess;
var
  blockingFileName, exportFileName: string;
  content: TStringList;
begin
  CreateNewCompetitionFile;
  InsertParticipant(305);
  blockingFileName := ChangeFileExt(FCsvFilePath, '.blocker');
  exportFileName := blockingFileName + DirectorySeparator + 'results.csv';
  content := TStringList.Create;
  try
    content.Add('not a directory');
    content.SaveToFile(blockingFileName);
  finally
    content.Free;
  end;
  try
    DialogCallCount := 0;
    Application.ProcessMessages;
    MainForm.ComboBoxLog.Clear;

    ExportCSVResults(exportFileName);
    Application.ProcessMessages;

    AssertEquals(1, DialogCallCount);
    AssertTrue(Pos(ExpandFileName(exportFileName), LastDialogMessage) > 0);
    AssertTrue(LastDialogHadPriorLog);
    AssertEquals(1, CountLogItemsContaining(LastDialogMessage));
    AssertEquals(0, CountLogItemsContaining(Copy(rsCSVResultsExported, 1,
      Pos('%', rsCSVResultsExported) - 1)));
  finally
    if FileExists(blockingFileName) then DeleteFile(blockingFileName);
  end;
end;

procedure TMainFlowIntegrationTests.UpdateSumResults_PreparedSecondaryQueryPreservesStatusSemantics;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name, result1, status) VALUES ' +
    '(201, ''Calculated'', ''00:10:00.000'', ''1''), ' +
    '(202, ''Did not finish'', NULL, ''1''), ' +
    '(203, ''Did not start'', NULL, ''2''), ' +
    '(204, ''Disqualified'', ''00:05:00.000'', ''3'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  UpdateSumResults;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, sumresult, sumstages, status FROM main ORDER BY number;';
  MainForm.SQLQuery1.Open;

  AssertEquals(201, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('00:10:00.000',
    MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('sumstages').AsInteger);
  AssertTrue(MainForm.SQLQuery1.FieldByName('status').IsNull);

  MainForm.SQLQuery1.Next;
  AssertEquals(202, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('DNF', MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('sumstages').IsNull);
  AssertEquals('1', MainForm.SQLQuery1.FieldByName('status').AsString);

  MainForm.SQLQuery1.Next;
  AssertEquals(203, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('DNS', MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('sumstages').IsNull);
  AssertEquals('2', MainForm.SQLQuery1.FieldByName('status').AsString);

  MainForm.SQLQuery1.Next;
  AssertEquals(204, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('DSQ', MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('sumstages').IsNull);
  AssertEquals('3', MainForm.SQLQuery1.FieldByName('status').AsString);
  MainForm.SQLQuery1.Close;

  AssertEquals('UpdateSumResults must not report database errors',
    0, DialogCallCount);
end;

procedure TMainFlowIntegrationTests.UpdateSumResults_ActiveStageTimesAreSummed;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  stages[2].isActive := True;
  MainForm.CurrentSU.Buttons[1].Enabled := True;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name, result1, result2, result3) VALUES ' +
    '(301, ''Summed result'', ''00:45:30.250'', ''01:20:40.750'', ' +
    '''05:00:00.000'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  UpdateSumResults;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT sumresult, sumstages FROM main WHERE number = 301;';
  MainForm.SQLQuery1.Open;
  AssertFalse(MainForm.SQLQuery1.EOF);
  AssertEquals('02:06:11.000',
    MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertEquals(2, MainForm.SQLQuery1.FieldByName('sumstages').AsInteger);
  MainForm.SQLQuery1.Close;

  AssertEquals('UpdateSumResults must not report database errors',
    0, DialogCallCount);
end;

procedure TMainFlowIntegrationTests.ParticipantEdit_LogsSuccessfulSaveOnce;
begin
  CreateNewCompetitionFile;
  InsertParticipant(401);
  MainForm.ComboBoxLog.Clear;

  MainForm.MainDataset1.Locate('number', 401, []);
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('name').AsString := 'Changed participant';
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;

  AssertEquals(1, CountLogItemsContaining(
    Format(rsParticipantUpdated, ['401'])));
end;

procedure TMainFlowIntegrationTests.ParticipantStageValueEdit_LogsSuccessfulSaveOnce;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(405);
  MainForm.MainDataset1.Locate('number', 405, []);
  MainForm.ComboBoxLog.Clear;

  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('starttime1').AsString := '10:15:00.000';
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;

  AssertEquals(1, CountLogItemsContaining(Format(
    rsParticipantStageValueUpdated,
    ['405', rsStarttime, 1, '10:15:00.000'])));
end;

procedure TMainFlowIntegrationTests.CorrectionEdit_LogsParticipantStageAndValueOnce;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(402);
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''10:00:00.000'' WHERE number = 402;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.CorrectionDataset.Close;
  MainForm.CorrectionDataset.SQL := TDatasetSql.CorrectionPending(1);
  MainForm.CorrectionDataset.Open;
  AssertTrue(MainForm.CorrectionDataset.Locate('number', 402, []));
  MainForm.ComboBoxLog.Clear;

  MainForm.CorrectionDataset.Edit;
  MainForm.CorrectionDataset.FieldByName('correction1').AsInteger := 7;
  MainForm.RxDBGridCorrectionEditingDone(MainForm.RxDBGridCorrection);
  Application.ProcessMessages;

  AssertEquals(1, CountLogItemsContaining(
    Format(rsParticipantCorrectionSet, ['402', 1, '7'])));
end;

procedure TMainFlowIntegrationTests.ParticipantDelete_LogsOnlyAfterConfirmedSave;
begin
  CreateNewCompetitionFile;
  InsertParticipant(403);
  MainForm.MainDataset1.Locate('number', 403, []);
  MainForm.ComboBoxLog.Clear;

  ConfirmationDialogResult := mrNo;
  MainForm.AcDeleteNumberExecute(MainForm.AcDeleteNumber);
  Application.ProcessMessages;
  AssertEquals('Cancelled deletion must not be logged', 0, CountLogItemsContaining(
    Format(rsParticipantDeleted, ['403'])));
  AssertTrue('Cancelled deletion must keep the participant',
    MainForm.MainDataset1.Locate('number', 403, []));

  ConfirmationDialogResult := mrYes;
  DialogCallCount := 0;
  LastDialogMessage := '';
  MainForm.AcDeleteNumberExecute(MainForm.AcDeleteNumber);
  Application.ProcessMessages;
  AssertEquals('Unexpected dialog after confirmed deletion: ' +
    LastDialogMessage, 1, DialogCallCount);
  AssertEquals('Confirmed deletion must be logged', 1, CountLogItemsContaining(
    Format(rsParticipantDeleted, ['403'])));
  AssertMainRowCount(0);
end;

procedure TMainFlowIntegrationTests.ParticipantStatus_LogsSuccessfulStageChangeOnce;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(404);
  MainForm.ComboBoxLog.Clear;

  SetSQLStatus(1, 'DNF', '404');
  Application.ProcessMessages;

  AssertEquals(1, CountLogItemsContaining(
    Format(rsParticipantStatusSet, ['404', rsDidNotFinish])));
end;

procedure TMainFlowIntegrationTests.SerialStatus_LogsTransitionsWithoutRepeatedWarnings;
begin
  MainForm.SerialStatus(MainForm.Serial, HR_Connect, 'TEST1');
  MainForm.ComboBoxLog.Clear;

  MainForm.SerialStatus(MainForm.Serial, HR_Connect, 'TEST1');
  AssertEquals(1, CountLogItemsContaining(Format(rsPortConnected, ['TEST1'])));

  MainForm.SerialStatus(MainForm.Serial, HR_SerialClose, 'TEST1');
  MainForm.SerialStatus(MainForm.Serial, HR_SerialClose, 'TEST1');
  AssertEquals(1, CountLogItemsContaining(
    Format(rsPortConnectionLost, ['TEST1'])));

  MainForm.SerialStatus(MainForm.Serial, HR_Connect, 'TEST1');
  AssertEquals(1, CountLogItemsContaining(
    Format(rsPortConnectionRestored, ['TEST1'])));
end;

procedure TMainFlowIntegrationTests.ModuleSync_ClosedPortLogsErrorWithoutSuccess;
begin
  MainForm.Serial.Close;
  MainForm.ComboBoxLog.Clear;
  DialogCallCount := 0;
  LastDialogMessage := '';
  LastDialogHadPriorLog := False;

  MainForm.AcSyncModuleExecute(MainForm.AcSyncModule);
  Application.ProcessMessages;

  AssertEquals(1, DialogCallCount);
  AssertTrue(Pos(MainForm.Serial.Device, LastDialogMessage) > 0);
  AssertTrue(LastDialogHadPriorLog);
  AssertEquals(1, CountLogItemsContaining(LastDialogMessage));
  AssertEquals(0, CountLogItemsContaining(Copy(rsModuleSynchronized, 1,
    Pos('%', rsModuleSynchronized) - 1)));
end;

procedure TMainFlowIntegrationTests.ParseSerial_InvalidPacketsStayInDebugMemo;
begin
  MainForm.ComboBoxLog.Clear;
  MainForm.Memo.Clear;

  ParseSerial('$invalid#');
  ParseSerial('raw packet');
  Application.ProcessMessages;

  AssertEquals(0, MainForm.ComboBoxLog.Items.Count);
  AssertTrue(Pos(Format(rsSerialRaw, ['$invalid#']), MainForm.Memo.Text) > 0);
  AssertTrue(Pos(Format(rsSerialRaw, ['raw packet']), MainForm.Memo.Text) > 0);
end;

procedure TMainFlowIntegrationTests.LoRaActions_LogCompletedChanges;
var
  recordId: string;
begin
  CreateNewCompetitionFile;
  TLoRaSql.ExecInsertSample(MainForm.SQLQuery1, False, 0,
    '10:00:00.000', 5, 'test');
  TLoRaSql.ExecInsertSample(MainForm.SQLQuery1, False, 0,
    '10:01:00.000', 6, 'test');
  MainForm.DatasetLoRa.Close;
  MainForm.DatasetLoRa.SQL := TLoRaSql.SelectPending;
  MainForm.DatasetLoRa.Open;
  MainForm.ComboBoxLog.Clear;

  MainForm.DatasetLoRa.First;
  recordId := MainForm.DatasetLoRa.FieldByName('id').AsString;
  MainForm.LoRaPopupHideSelectedExecute(MainForm.LoRaPopupHideSelected);
  AssertEquals('Hiding one LoRa record must be logged',
    1, CountLogItemsContaining(Format(rsLoRaRecordHidden, [recordId])));

  MainForm.AcLoRaClearExecute(MainForm.AcLoRaClear);
  AssertEquals('Resetting LoRa records must be logged',
    1, CountLogItemsContaining(rsLoRaRecordsReset));
end;

procedure TMainFlowIntegrationTests.LoRaChange_RefreshFailureKeepsSuccessAndWarns;
var
  oldSql: string;
begin
  CreateNewCompetitionFile;
  oldSql := MainForm.DatasetLoRa.SQL;
  MainForm.DatasetLoRa.Close;
  MainForm.DatasetLoRa.SQL := 'SELECT * FROM missing_lora_table';
  MainForm.ComboBoxLog.Clear;
  DialogCallCount := 0;
  LastDialogHadPriorLog := False;
  try
    MainForm.AcLoRaClearExecute(MainForm.AcLoRaClear);

    AssertEquals('The committed change must retain its success entry',
      1, CountLogItemsContaining(rsLoRaRecordsReset));
    AssertEquals('A failed view refresh must produce one warning',
      1, CountLogItemsContaining(Copy(rsLoRaRecordsRefreshWarning, 1,
        Pos('%', rsLoRaRecordsRefreshWarning) - 1)));
    AssertEquals(1, DialogCallCount);
    AssertTrue('The refresh warning must be logged before the dialog',
      LastDialogHadPriorLog);
    AssertEquals(0, CountLogItemsContaining(rsDatabaseOpenError));
  finally
    MainForm.DatasetLoRa.Close;
    MainForm.DatasetLoRa.SQL := oldSql;
    MainForm.DatasetLoRa.Open;
  end;
end;

procedure TMainFlowIntegrationTests.IntegrationActions_LogStateChanges;
var
  oldSafeMode: boolean;
  oldUrl: string;
begin
  oldSafeMode := MainForm.DataPortHTTP1.SafeMode;
  oldUrl := MainForm.DataPortHTTP1.Url;
  try
    MainForm.DataPortHTTP1.Close;
    MainForm.DataPortHTTP1.SafeMode := True;
    MainForm.DataPortHTTP1.Url := 'http://127.0.0.1/post';
    MainForm.ComboBoxLog.Clear;

    MainForm.AcLEDPanel.Checked := True;
    MainForm.AcLEDPanelExecute(MainForm.AcLEDPanel);
    MainForm.AcLEDPanel.Checked := False;
    MainForm.AcLEDPanelExecute(MainForm.AcLEDPanel);
    MainForm.AcTelegramBot.Checked := True;
    MainForm.AcTelegramBotExecute(MainForm.AcTelegramBot);
    MainForm.AcTelegramBot.Checked := False;
    MainForm.AcTelegramBotExecute(MainForm.AcTelegramBot);

    AssertEquals(1, CountLogItemsContaining(rsLEDPanelEnabled));
    AssertEquals(1, CountLogItemsContaining(rsLEDPanelDisabled));
    AssertEquals(1, CountLogItemsContaining(rsTelegramBotEnabled));
    AssertEquals(1, CountLogItemsContaining(rsTelegramBotDisabled));
  finally
    MainForm.DataPortHTTP1.Close;
    MainForm.DataPortHTTP1.SafeMode := oldSafeMode;
    MainForm.DataPortHTTP1.Url := oldUrl;
  end;
end;

procedure TMainFlowIntegrationTests.LEDPanelCallbacks_LogManualTestOutcome;
begin
  MainForm.ComboBoxLog.Clear;
  MainForm.Memo.Clear;
  MainForm.LEDPanelTestPending := True;

  MainForm.DataPortHTTP1DataAppear(MainForm.DataPortHTTP1);

  AssertFalse(MainForm.LEDPanelTestPending);
  AssertEquals(1, CountLogItemsContaining(rsLEDPanelTestSucceeded));
  AssertTrue(Pos(Format(rsHTTPResponseReceived, [0]), MainForm.Memo.Text) > 0);

  MainForm.LEDPanelTestPending := True;
  MainForm.DataPortHTTP1Error(MainForm.DataPortHTTP1, 'test failure');

  AssertFalse(MainForm.LEDPanelTestPending);
  AssertEquals(1, CountLogItemsContaining(
    Format(rsLEDPanelError, ['test failure'])));
end;

procedure TMainFlowIntegrationTests.TelegramTestFailure_DoesNotLogRequestSecrets;
const
  TOKEN_SECRET = 'botTOKEN_SECRET';
  PAYLOAD_SECRET = 'PARTICIPANT_SECRET';
var
  form: TSettingsForm;
  oldTelegramAddress: string;
begin
  oldTelegramAddress := telegrambotadress;
  form := TSettingsForm.Create(nil);
  try
    form.TelegramBotAdressEdit.Text :=
      'http://127.0.0.1:1/' + TOKEN_SECRET;
    form.TelegramNumber.Clear;
    form.TelegramName.Text := PAYLOAD_SECRET;
    form.TelegramCategory.Clear;
    form.TelegramResult.Clear;
    form.TelegramDiff.Clear;
    form.TelegramPlace.Clear;
    MainForm.ComboBoxLog.Clear;
    MainForm.Memo.Clear;

    form.ButtonTelegramTestClick(form.ButtonTelegramTest);

    AssertEquals(1, CountLogItemsContaining(Copy(
      rsTelegramBotSendingError, 1,
      Pos('%', rsTelegramBotSendingError) - 1)));
    AssertTrue(Pos(Format(rsHTTPRequestMetadata, ['GET', 1]),
      MainForm.Memo.Text) > 0);
    AssertEquals(0, Pos(TOKEN_SECRET, MainForm.ComboBoxLog.Text +
      MainForm.Memo.Text));
    AssertEquals(0, Pos(PAYLOAD_SECRET, MainForm.ComboBoxLog.Text +
      MainForm.Memo.Text));
  finally
    telegrambotadress := oldTelegramAddress;
    form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.SettingsCompetitionPage_UsesScrollableContent;
var
  form: TSettingsForm;
begin
  form := TSettingsForm.Create(nil);
  try
    AssertSame(form.Page3Competition, form.CompetitionScrollBox.Parent);
    AssertEquals(Ord(alClient), Ord(form.CompetitionScrollBox.Align));
    AssertTrue(form.CompetitionScrollBox.AutoScroll);
    AssertSame(form.CompetitionScrollBox, form.CompetitionContentPanel.Parent);
    AssertSame(form.CompetitionContentPanel, form.LeftPanel.Parent);
    AssertSame(form.CompetitionContentPanel, form.GroupBoxStages.Parent);

    form.Notebook1.PageIndex := 2;
    form.Show;
    Application.ProcessMessages;
    AssertTrue(form.CompetitionScrollBox.VertScrollBar.Range <=
      form.CompetitionScrollBox.ClientHeight);

    form.Height := form.Constraints.MinHeight;
    Application.ProcessMessages;
    AssertTrue(form.CompetitionContentPanel.Height >
      form.CompetitionScrollBox.ClientHeight);
    AssertTrue(form.CompetitionScrollBox.VertScrollBar.Range >
      form.CompetitionScrollBox.ClientHeight);
  finally
    form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.SettingsAccept_LogsSuccessfulSave;
begin
  MainForm.ComboBoxLog.Clear;
  Application.QueueAsyncCall(@CloseSettingsForm, mrOk);

  SettingsForm.RunSettings;

  AssertEquals(1, MainForm.ComboBoxLog.Items.Count);
  AssertTrue(Pos(rsSettingsSaved, MainForm.ComboBoxLog.Items[0]) > 0);
end;

procedure TMainFlowIntegrationTests.SettingsCancel_DoesNotLogSave;
begin
  MainForm.ComboBoxLog.Clear;
  Application.QueueAsyncCall(@CloseSettingsForm, mrCancel);

  SettingsForm.RunSettings;

  AssertEquals(0, MainForm.ComboBoxLog.Items.Count);
end;

procedure TMainFlowIntegrationTests.StartlistForm_UsesScrollableContent;
var
  form: TStartlistForm;
begin
  form := TStartlistForm.Create(nil);
  try
    AssertSame(form, form.ButtonPanel1.Parent);
    AssertSame(form, form.StartlistScrollBox.Parent);
    AssertTrue(form.StartlistScrollBox.AutoScroll);
    AssertSame(form.StartlistScrollBox, form.StageSelected.Parent);
    AssertSame(form.StartlistScrollBox, form.Panel1.Parent);
    AssertSame(form.StartlistScrollBox, form.Panel2.Parent);

    form.Show;
    Application.ProcessMessages;
    AssertTrue(form.StartlistScrollBox.VertScrollBar.Range <=
      form.StartlistScrollBox.ClientHeight);

    form.Height := form.Constraints.MinHeight;
    Application.ProcessMessages;
    AssertTrue(form.Panel2.Top + form.Panel2.Height >
      form.StartlistScrollBox.ClientHeight);
    AssertTrue(form.StartlistScrollBox.VertScrollBar.Range >
      form.StartlistScrollBox.ClientHeight);
  finally
    form.Free;
  end;
end;

initialization
  RegisterTest(TMainFlowIntegrationTests);

end.
