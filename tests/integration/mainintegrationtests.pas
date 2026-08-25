unit MainIntegrationTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, Dialogs, Forms, Controls, ComCtrls, Menus, StdCtrls,
  Graphics, DB, DBGrids, Clipbrd, fpcunit,
  testregistry,
  Main, Result, Settings, StartList, StartMarks, FinishMarks, InputDialogs,
  i18n, DbSql, AppLogger,
  synaser, LazSerial, ParticipantStatus, rxdbgrid, MyRxDBGrid,
  StageSettingsFrame,
  SerialDeviceProvider, SerialSelector, LazSerialDevices,
  TimingProtocol, TimingMark, TimingTransport,
  TransportStreamProcessor, CompetitionBackupService,
  CompetitionFinishService,
  TelegramNotificationCoordinator,
  BleTimingTransport, LazBleBackend,
  LazBleOperation, LazBleClient, LazBleComponent, LazBleTypes,
  LazBleNus, DateTimePicker,
  FakeLazBleBackend;

type
  TMainFlowIntegrationTests = class(TTestCase)
  private
    FDbFilePath: string;
    FCsvFilePath: string;
    FImportFilePath: string;
    FExpectedImportedRows: integer;
    FMainDatasetOpenCount: integer;
    FStatDatasetOpenCount: integer;
    FCorrectionDatasetOpenCount: integer;
    FResultDatasetOpenCount: integer;
    FBleTestProcessor: TTransportStreamProcessor;

    class function ResolveRepoRoot: string; static;
    procedure EnsureFormsCreated;
    procedure CreateNewCompetitionFile;
    procedure OpenCompetitionFile(const AFileName: string);
    procedure RefreshCompetitionViews;
    procedure ImportParticipantsFile(const AFileName: string);
    procedure ImportStageResultsFile(const AFileName: string);
    procedure ExportStageResultsFile(const AFileName: string;
      const AStageIndex: integer);
    procedure ExportStartListFile(const AFileName: string);
    procedure ExportResultsFile(const AFileName: string);
    procedure ExportAllResultsFile(const AFileName: string);
    procedure ApplyStartPacketAt(const ATime: TDateTime;
      const AHasCorrection: boolean = False;
      const ACorrectionMs: integer = 0);
    procedure ApplyFinishPacketAt(const ATime: TDateTime);
    procedure SelectFinishMarkAt(const AIndex: integer);
    procedure SetFinishMarkNumberAt(const AIndex,
      AParticipantNumber: integer; const APersist: boolean = True);
    procedure ApplyStageActivityToUi(const APreferredStageIndex: integer);
    procedure ApplyStagePresentationToUi(
      const APreferredStageIndex: integer = 0);
    procedure RefreshResultViewConfiguration;
    procedure CreateEmptyCompetitionFixture(const AStageCount: integer);
    procedure WriteCsv(const ALines: array of string);
    procedure AssertTableExists(const ATableName: string);
    procedure AssertMainRowCount(const AExpectedCount: integer);
    procedure AssertDynamicStageFields(const AStageCount: integer);
    procedure AssertDynamicStageColumns(const AStageCount: integer);
    procedure AssertDynamicStageResultUi(const AStageCount: integer);
    procedure AssertCurrentStageSelector(const AStageCount: integer);
    procedure AssertDynamicStageSettings(const AStageCount: integer);
    procedure ConfigureSingleActiveStage(const AStageIndex: integer);
    procedure InsertParticipant(const AParticipantNumber: integer);
    procedure CreateSchemaFixture(const APhysicalStageCount: integer;
      const AStageCountValue, ASchemaVersionValue: string);
    function FindBackupFile: string;
    function LoadConfigValueFromFile(const AFileName, AKey,
      ADefaultValue: string): string;
    procedure DeleteBackupFiles;
    procedure CloseSettingsForm(Data: PtrInt);
    procedure SelectFriendlySerialDeviceAndClose(Data: PtrInt);
    procedure EnterCustomSerialDeviceAndClose(Data: PtrInt);
    procedure EditStageDraftAndClose(Data: PtrInt);
    procedure ResizeStageDraftAndClose(Data: PtrInt);
    procedure ActivateOnlyStageAndClose(Data: PtrInt);
    procedure ActivateAllStagesAndClose(Data: PtrInt);
    procedure RenameFirstStageAndClose(Data: PtrInt);
    procedure ChangeResultCategoryAndClose(Data: PtrInt);
    procedure CountMainDatasetOpen(DataSet: TDataSet);
    procedure CountStatDatasetOpen(DataSet: TDataSet);
    procedure CountCorrectionDatasetOpen(DataSet: TDataSet);
    procedure CountResultDatasetOpen(DataSet: TDataSet);
    procedure ConfigureSerialUi(const ADevice: string;
      const ADeviceNames: array of string);
    function FindSerialPortMenuItem(const ACaption: string): TMenuItem;
    {$IFDEF UNIX}
    function VirtualSerialDevice: string;
    procedure OpenVirtualSerialPort;
    {$ENDIF}
    procedure AcceptInputComboDialog(Data: PtrInt);
    procedure AcceptInputDateTimeDialog(Data: PtrInt);
    procedure BleTimingPacketReceived(Sender: TObject;
      const APacket: TTimingPacket; const ASource: TTimingMarkSource);
    procedure BleTimingDataReceived(Sender: TObject;
      const AData: RawByteString; const ASource: TTimingMarkSource);
    procedure CompleteBleTimingConnection(
      const ABackend: TFakeLazBleBackend;
      const ASubscriptionId: TBleSubscriptionId);
    procedure EmitBleTimingNotification(const ABackend: TFakeLazBleBackend;
      const AInput: TBleTimingTransport;
      const ASubscriptionId: TBleSubscriptionId;
      const AValue: RawByteString);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MainForm_InitialStageContextUsesMinimumStageCount;
    procedure MainForm_SerialDefaultsMatchFirmwareAndPersist;
    procedure InputDialogs_ReturnValuesAndReleaseOwnedForms;
    procedure MainForm_BleTimingTransportStartsDisconnected;
    procedure MyRxDBGrid_ColumnBatchDefersSortListRefreshUntilOuterEnd;
    procedure MainForm_SecondaryQuerySharesPrimaryConnectionAndTransaction;
    procedure ReadOnlyDatasets_UseSqlQueryAndSharedContext;
    procedure PersistentFieldTypes_MatchSqliteAndQueryResults;
    procedure MainGrid_OptionalParticipantColumnsHaveExplicitWidths;
    procedure RaceModeSpace_AddsTimeWithoutClearingSelectedCell;
    procedure FinishMarkPanel_NumberEditPersistsWithoutApplying;
    procedure FinishMarkPanel_ZeroNumberShowsDeferredDialog;
    procedure SqlQuerySortEngine_SortsMainGridDataset;
    procedure RefreshAll_RefreshesLegacyDatasetsAndSqlQueries;
    procedure CategoryEdit_RefreshesOnlyAffectedQueriesAfterCommit;
    procedure CreateNewCompetitionFile_ViaMainFormHandler_CreatesDbAndOpensDatasets;
    procedure NewCompetitionSchema_IsVersionedAndReopensWithoutMigration;
    procedure CompetitionConfigModel_LoadDoesNotApplyUiUntilExplicitPhase;
    procedure ActiveStageChange_ReconfiguresCurrentTrackQuery;
    procedure CurrentStageSelector_MapsSparseStagesAndPreservesSelection;
    procedure CurrentStageOperations_UseSparseStageAboveEight;
    procedure CompetitionFileCreateError_ReportsPathAndLeavesDatabaseClosed;
    procedure CompetitionFileOpenError_DoesNotPublishFailedFile;
    procedure LegacySchemaMigration_CreatesBackupAndPreservesData;
    procedure ConfiguredSchemaMigration_ExpandsCapacity;
    procedure MinimumStageCount_ResizesModelBeforeConfigLoad;
    procedure MaximumStageCount_ResizesModelBeforeConfigLoad;
    procedure DynamicStageUi_RebuildForSupportedStageCounts;
    procedure StageSelection_UsesFullFieldSuffix;
    procedure StageIndexes_RejectInvalidSelectionsAndNormalizeStoredValues;
    procedure DynamicStageFields_EditRecalculateAndReopen;
    procedure NewerSchema_IsRejectedWithoutOpeningDatasets;
    procedure ImportStartListCp1251_ViaMainFormHandler_LoadsUtf8DataToMainTable;
    procedure ImportStartListCp1251_DoesNotRequireInteractiveDialogsInCI;
    procedure LoadParticipantsList_MinimalUtf8Csv_MapsParticipantAndStage;
    procedure LoadParticipantsList_CategoryDeclinedStillAppliesDetectedStages;
    procedure LoadParticipantsList_WithoutStageColumnsPreservesActiveStages;
    procedure LoadParticipantsList_EqualStageCountUpdatesNamesAndActivity;
    procedure LoadParticipantsList_ReimportReplacesStagesAndRestoresHiddenResult;
    procedure LoadParticipantsList_MoreStages_ExpandsCompetition;
    procedure LoadParticipantsList_AboveSupportedStages_RejectsWithoutChanges;
    procedure LoadParticipantsList_ReimportExistingNumber_UpdatesWithoutDuplicate;
    procedure LoadParticipantsList_HtmlEntities_AreDecoded;
    procedure LoadParticipantsList_DatabaseError_RollsBackEntireImport;
    procedure LoadParticipantsList_WithoutNumberColumn_ReportsErrorAndImportsNothing;
    procedure LoadParticipantsList_InvalidStartTime_ReportsErrorAndImportsNothing;
    procedure LoadParticipantsList_DuplicateNumber_ReportsBothRows;
    procedure LoadStageResults_ActiveStageAboveEightImportsValues;
    procedure LoadStageResults_InactiveAndReducedStagesAreRejected;
    procedure LoadStageResults_TwoColumns_ImportsFinishIntoSelectedStage;
    procedure LoadStageResults_ThreeColumns_ImportsStartIntoSelectedStage;
    procedure LoadStageResults_SixColumns_ImportsFullResultIntoSelectedStage;
    procedure LoadStageResults_FullImportClearsStaleGlobalStatus;
    procedure LoadStageResults_DatabaseError_RollsBackEntireImport;
    procedure LoadStageResults_InvalidCsv_DoesNotChangeExistingResults;
    procedure LoadStageResults_InvalidCsv_DoesNotRequestStageSelection;
    procedure LoadStageResults_Reimport_UpdatesWithoutDuplicate;
    procedure LoadStageResults_StageSelectionCancellation_ChangesNothing;
    procedure LoadStageResults_DuplicateNumber_ReportsLocalizedCsvError;
    procedure LoadStageResults_UnknownParticipant_ConfirmationCreatesParticipant;
    procedure LoadStageResults_UnknownParticipant_RejectionSkipsOnlyUnknownResult;
    procedure ExportStageResultsCsv_StageAboveEightUsesDynamicFields;
    procedure DynamicCsvExports_UseActiveStagesAndComplexNames;
    procedure ExportAllResultsToXLSX_UsesDynamicStagesAndComplexNames;
    procedure ExportStageResultsCsvFailure_ReportsErrorAndWritesNoFile;
    procedure ExportDatasetCsvFailure_ReportsErrorAndWritesNoFile;
    procedure UpdateSumResults_PreparedSecondaryQueryPreservesStatusSemantics;
    procedure UpdateSumResults_ActiveStageTimesAreSummed;
    procedure UpdateResults_StageAboveEightCalculatesStageSumAndThruPlaces;
    procedure UpdateResults_FromPopupPreservesMainGridRow;
    procedure SetFinish_MultipleRowsAreProcessedSequentially;
    procedure SetFinish_UsesStageCapturedWhenMarkWasReceived;
    procedure SetFinish_UsesCapturedTimeInsteadOfGridText;
    procedure SetFinish_CalculationErrorRollsBackFinishAndResults;
    procedure SetFinish_RefreshFailureKeepsCommittedFinish;
    procedure SetFinish_TelegramFailureKeepsCommittedFinish;
    procedure ParticipantAppend_SavesAndKeepsInsertedRowCurrent;
    procedure ParticipantEdit_SavesAndKeepsEditedRowCurrent;
    procedure ParticipantNumberEdit_SavesNewNumber;
    procedure ParticipantPrivateFields_LogNamesWithoutValues;
    procedure ParticipantStageValueEdit_SavesAndKeepsEditedRowCurrent;
    procedure ParticipantUnchangedStageField_CancelsEdit;
    procedure CategoryEditor_LoadsCategoriesWithoutStatisticsDataset;
    procedure CorrectionEdit_UpdatesSelectedStageOnly;
    procedure CorrectionEdit_InvalidValueIsRejectedWithoutRollback;
    procedure ParticipantDelete_RequiresConfirmationAndDeletesRow;
    procedure ParticipantStatusTableEdit_NormalizesAndClearsSupportedValues;
    procedure ParticipantStatusTableEdit_RejectsInvalidValue;
    procedure TimingStart_PersistsSourceAndStage;
    procedure TimingStart_AutomaticSettingsApplyCorrection;
    procedure TimingStart_ClosedCompetitionIsIgnored;
    procedure FinishMarkPanel_UsesEditableSqlQueryAndRxDbGrid;
    procedure TimingMarkWorkQueues_RejectDatasetInsert;
    procedure FinishMarkPanel_RestoresPendingMarksFromSqlite;
    procedure FinishMarkPanel_DebouncedMarkPreservesSelection;
    procedure FinishMarkPanel_RapidMarksRemainStable;
    procedure FinishMarkPanel_CtrlEnterWritesAndEnterRemainsForEditing;
    procedure FinishMarkPanel_DoubleClickWithoutNumberDoesNothing;
    procedure FinishMarkPanel_DoubleClickAppliesNumberedMark;
    procedure FinishMarkPanel_ClearSoftHidesEntireWorkQueue;
    procedure StartMarkPanel_ShowsEditableWorkQueueWithRestoredLayout;
    procedure StartMarkPanel_NumberEditPersistsWithoutApplying;
    procedure StartMarkPanel_DoubleClickWithoutNumberDoesNothing;
    procedure StartMarkPanel_DoubleClickAppliesToReceivedStage;
    procedure StartMarkPanel_DifferentStageCanBeCancelled;
    procedure StartMarkPanel_DifferentStageCanApplyToReceivedStage;
    procedure StartMarkPanel_DifferentStageCanApplyToCurrentStage;
    procedure StartMarkPanel_ExistingCorrectionRequiresConfirmation;
    procedure StartMarkPanel_CtrlEnterWritesOnlyWhenFocused;
    procedure StartMarkPanel_WriteCommitsCurrentNumberEdit;
    procedure StartMarkPanel_WriteAppliesEveryNumberedRow;
    procedure StartMarkPanel_WriteContinuesAfterStageChoiceCancellation;
    procedure StartMarkPanel_ClearSoftHidesEntireWorkQueue;
    procedure StartMarkJournal_ShowsAllStatusesNewestFirstAndReadOnly;
    procedure StartMarkJournal_FiltersAndRefreshesPreservingSelection;
    procedure StartMarkJournal_DiagnosticPreviewCopyAndViewerUseFullText;
    procedure FinishMarkJournal_ShowsAllStatusesNewestFirstAndReadOnly;
    procedure FinishMarkJournal_FiltersAndRefreshesPreservingSelection;
    procedure FinishMarkJournal_DiagnosticPreviewCopyAndViewerUseFullText;
    procedure SerialUi_ControlsUseMenuImagesAndPlaceIconBeforePort;
    procedure SerialUi_DisconnectedAvailablePortEnablesOpenState;
    procedure SerialUi_DisconnectedUnavailablePortDisablesOpenState;
    procedure SerialUi_OpenActionRechecksAndRejectsUnavailablePort;
    {$IFDEF UNIX}
    procedure SerialUi_ConnectedPortUsesCloseStateAndButtonDisconnects;
    {$ENDIF}
    procedure SerialUi_PortMenuRefreshesAndChecksCurrentDevice;
    procedure SerialUi_EmptyPortMenuShowsDisabledLocalizedItem;
    procedure SerialUi_SelectingAvailablePortUpdatesDeviceWithoutConnecting;
    {$IFDEF UNIX}
    procedure SerialUi_ConnectedPortPreventsDeviceSelection;
    {$ENDIF}
    procedure SerialUi_PortDisappearingBeforeClickIsNotOpened;
    {$IFDEF UNIX}
    procedure SerialUi_StatusCallbacksSynchronizeControlsActionsAndText;
    {$ENDIF}
    procedure SerialUi_RestoredUnavailablePortRemainsSelectedButDisabled;
    procedure SerialUi_ClockTimerDoesNotEnumeratePorts;
    procedure SerialUi_PortLabelDoesNotRepeatSelectedPort;
    procedure TimingInputUi_SwitchesBetweenSerialAndBleStatus;
    procedure BleDeviceSelection_AcceptConnectsSelectedDevice;
    procedure BleDeviceSelection_CancelDoesNotChangeOrConnect;
    {$IFDEF UNIX}
    procedure SerialVirtualPort_ProcessesMixedTransportStream;
    {$ENDIF}
    procedure BleStartPersistsStartMarkOnce;
    procedure BleFinishInvokesGetFinishTimeOnce;
    procedure LEDPanelTest_UsesDraftAddressWithoutChangingGlobal;
    procedure TelegramTestFailure_DoesNotLogRequestSecrets;
    procedure SettingsSerialSelector_ShowsFriendlyNameButAppliesDevice;
    procedure SettingsSerialSelector_AppliesCustomDevice;
    procedure SettingsTimingInputPage_SwitchesTransportPanels;
    procedure SettingsTimingInputPage_DisablesUnavailableBleButKeepsSerial;
    procedure SettingsTimingInputPage_AppliesSelectedBleDeviceOnlyAfterAccept;
    procedure SettingsStartMarkSettings_AreDraftedAndApplied;
    procedure TimingInputIni_RoundTripsModeAndBleIdentityWithoutConnection;
    procedure TimingInputIni_InvalidTransportFallsBackToSerial;
    procedure StartMarkIni_RoundTripsSettings;
    procedure TelegramRetryIni_RoundTripsAndValidates;
    procedure SettingsTelegramRetry_UsesStoredDraftValues;
    procedure BackupRetentionIni_RoundTripsAndValidates;
    procedure SettingsBackupRetention_UsesStoredValues;
    procedure MainIni_InvalidScalarValuesUseDefaults;
    procedure SettingsCompetitionPage_UsesScrollableContent;
    procedure SettingsStageLabels_RefreshWhenLanguageChanges;
    procedure SettingsStageDraft_AppliesOnlyAfterAccept;
    procedure SettingsStageDraft_RequiresAtLeastOneActiveStage;
    procedure SettingsStageCount_ExpandsSchemaAndCreatesBackup;
    procedure SettingsStageCount_SoftReductionPreservesHiddenStage;
    procedure SettingsStageCount_KeepsMainGridSortingUsable;
    procedure SettingsStageCount_RebuildsUiAndPreservesCurrentContext;
    procedure SettingsStageActivity_KeepsMainDatasetOpenForSparseStage;
    procedure SettingsStageActivity_ReactivatesAllStagesAndPreservesEditing;
    procedure SettingsNoChanges_DoesNotRefreshDatasets;
    procedure SettingsStageName_UpdatesUiWithoutRefreshingMainDataset;
    procedure SettingsResultCategory_RefreshesOnlyResultQueries;
    procedure StartlistForm_UsesScrollableContent;
    procedure OpenLogActions_AreEnabledOnlyForCurrentFile;
    procedure LoggingIniSettings_AreAppliedToFile;
  end;

implementation

uses
  IniFiles, LCLType, LazBleDeviceControl, Math, PropertyStorage, SQLite3Conn,
  SQLDB, StageConfig, StageFieldNames, CompetitionRefreshCoordinator,
  CompetitionResultsService, CompetitionLifecycleService,
  CompetitionExportService,
  StartMarkRepository, FinishMarkRepository, SqlQuerySortEngine,
  CsvDocument, fpstypes,
  fpspreadsheet, fpsallformats;

type
  TMainFormAccess = class(TMainForm);

  TMyRxDBGridAccess = class(TMyRxDBGrid)
  public
    function IntegerFieldAtRow(const ARow: integer;
      const AFieldName: string): integer;
    procedure SelectDataRow(const ARow: integer);
  end;

  TTestSettingsForm = class(TSettingsForm)
  private
    FDeviceSelectionResult: Boolean;
    FDeviceToSelect: TBleDeviceInfo;
  protected
    function ExecuteBleDeviceSelection(
      out ADevice: TBleDeviceInfo): Boolean; override;
  public
    procedure ApplyTimingInputSettingsForTest;
    property DeviceSelectionResult: Boolean read FDeviceSelectionResult
      write FDeviceSelectionResult;
    property DeviceToSelect: TBleDeviceInfo read FDeviceToSelect
      write FDeviceToSelect;
  end;

  TTestStartMarksForm = class(TStartMarksForm)
  private
    FShownDiagnostic: string;
  protected
    procedure ShowDiagnostic(const AText: string); override;
  public
    property ShownDiagnostic: string read FShownDiagnostic;
  end;

  TTestFinishMarksForm = class(TFinishMarksForm)
  private
    FShownDiagnostic: string;
  protected
    procedure ShowDiagnostic(const AText: string); override;
  public
    property ShownDiagnostic: string read FShownDiagnostic;
  end;

  TSerialSelectorTestAccess = class(TSerialSelector)
  public
    procedure ApplyTestDevices(const ADevices: TSerialDeviceInfoArray);
  end;

var
  DialogCallCount: integer = 0;
  LastDialogMessage: string = '';
  ConfirmationDialogResult: integer = mrYes;
  StartMarkStageChoiceCallCount: integer = 0;
  StartMarkStageChoiceResult: TStartMarkStageChoice = smscCancel;
  LastStartMarkStageChoiceMessage: string = '';
  StageSelectionCallCount: integer = 0;
  StageSelectionResult: integer = 2;
  SettingsDraftStageCount: integer = 0;
  SettingsDraftStageName: string = '';
  SettingsDraftStageActive: boolean = False;
  SettingsDraftActiveStageIndex: integer = 0;
  SettingsDraftCategoryName: string = '';
  FakeSerialDevices: TSerialDeviceInfoArray = nil;
  FakeSerialDevicesProviderCallCount: integer = 0;
  InputDialogCallbackError: string = '';

const
  TEST_SERIAL_DEVICE = 'COM77';
  TEST_SERIAL_FRIENDLY_NAME = 'COM77 <ENTime USB UART>';

procedure TSerialSelectorTestAccess.ApplyTestDevices(
  const ADevices: TSerialDeviceInfoArray);
var
  deadline: QWord;
begin
  deadline := GetTickCount64 + 2000;
  while not BackgroundRefreshFinished and (GetTickCount64 < deadline) do
    CheckSynchronize(10);
  CheckSynchronize;
  ApplyDevices(ADevices);
end;

procedure SetFakeSerialDevices(const ADeviceNames: array of string);
var
  i: integer;
begin
  SetLength(FakeSerialDevices, Length(ADeviceNames));
  for i := Low(ADeviceNames) to High(ADeviceNames) do
  begin
    FakeSerialDevices[i] := Default(TSerialDeviceInfo);
    FakeSerialDevices[i].Device := ADeviceNames[i];
  end;
end;

procedure TTestStartMarksForm.ShowDiagnostic(const AText: string);
begin
  FShownDiagnostic := AText;
end;

procedure TTestFinishMarksForm.ShowDiagnostic(const AText: string);
begin
  FShownDiagnostic := AText;
end;

function IntegrationSerialDevicesProvider: TSerialDeviceInfoArray;
begin
  Inc(FakeSerialDevicesProviderCallCount);
  Result := FakeSerialDevices;
end;

procedure TMyRxDBGridAccess.SelectDataRow(const ARow: integer);
begin
  DataLink.ActiveRecord := ARow - FixedRows;
  UpdateActive;
end;

function TMyRxDBGridAccess.IntegerFieldAtRow(const ARow: integer;
  const AFieldName: string): integer;
var
  savedActiveRecord: integer;
begin
  savedActiveRecord := DataLink.ActiveRecord;
  try
    DataLink.ActiveRecord := ARow - FixedRows;
    Result := DataLink.DataSet.FieldByName(AFieldName).AsInteger;
  finally
    DataLink.ActiveRecord := savedActiveRecord;
  end;
end;

function TTestSettingsForm.ExecuteBleDeviceSelection(
  out ADevice: TBleDeviceInfo): Boolean;
begin
  ADevice := FDeviceToSelect;
  Result := FDeviceSelectionResult;
end;

procedure TTestSettingsForm.ApplyTimingInputSettingsForTest;
begin
  ApplyTimingInputSettings;
end;

function IntegrationMessageDlgHandler(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: LongInt): Integer;
begin
  Inc(DialogCallCount);
  LastDialogMessage := Msg;
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

function IntegrationStartMarkStageChoiceHandler(const ACaption, AMessage,
  AReceivedStageButton, ACurrentStageButton: string): TStartMarkStageChoice;
begin
  Inc(StartMarkStageChoiceCallCount);
  LastStartMarkStageChoiceMessage := AMessage;
  Result := StartMarkStageChoiceResult;
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
  AssertTrue('Expected database datasets to be opened after DB creation',
    IsCompetitionDatabaseOpen);
end;

procedure TMainFlowIntegrationTests.OpenCompetitionFile(
  const AFileName: string);
begin
  MainForm.FileOpenDB.Dialog.FileName := AFileName;
  MainForm.FileOpenDBAccept(MainForm.FileOpenDB);
end;

procedure TMainFlowIntegrationTests.RefreshCompetitionViews;
var
  Outcome: TCompetitionRefreshOutcome;
begin
  Outcome := TCompetitionRefreshCoordinator.RefreshAll(
    MainForm.CompetitionDb, MainForm.MainDataset1,
    [MainForm.CorrectionDataset, MainForm.DatasetStartMarks,
    MainForm.DatasetFinishMarks,
    MainForm.ResultDatasetStageTotal, MainForm.ResultDatasetStageSum,
    MainForm.StatDataset1, MainForm.StatDataset2],
    [ResultsForm.CatDataset1, ResultsForm.CatDataset2,
    ResultsForm.CatDataset3, ResultsForm.CatDataset4,
    ResultsForm.CatDataset5, ResultsForm.CatDataset6,
    ResultsForm.ResultDataset], @MainForm.RefreshStageResultQueries);
  AssertEquals('Unexpected dataset refresh error: ' + Outcome.Errors,
    0, Outcome.ErrorCount);
end;

procedure TMainFlowIntegrationTests.ImportParticipantsFile(
  const AFileName: string);
begin
  MainForm.FileOpenCSV.Dialog.FileName := AFileName;
  MainForm.FileOpenCSVAccept(MainForm.FileOpenCSV);
end;

procedure TMainFlowIntegrationTests.ImportStageResultsFile(
  const AFileName: string);
begin
  MainForm.FileOpenCSVResult.Dialog.FileName := AFileName;
  MainForm.FileOpenCSVResultAccept(MainForm.FileOpenCSVResult);
end;

procedure TMainFlowIntegrationTests.ExportStageResultsFile(
  const AFileName: string; const AStageIndex: integer);
begin
  exportStageIndex := AStageIndex;
  MainForm.FileExportStageResultsSaveAs.Dialog.FileName := AFileName;
  MainForm.FileExportStageResultsSaveAsAccept(
    MainForm.FileExportStageResultsSaveAs);
end;

procedure TMainFlowIntegrationTests.ExportStartListFile(
  const AFileName: string);
begin
  MainForm.FileExportCSVStartlist.Dialog.FileName := AFileName;
  MainForm.FileExportCSVStartlistAccept(MainForm.FileExportCSVStartlist);
end;

procedure TMainFlowIntegrationTests.ExportResultsFile(
  const AFileName: string);
begin
  MainForm.FileExportCSVResults.Dialog.FileName := AFileName;
  MainForm.FileExportCSVResultsAccept(MainForm.FileExportCSVResults);
end;

procedure TMainFlowIntegrationTests.ExportAllResultsFile(
  const AFileName: string);
var
  Labels: TCompetitionExportLabels;
begin
  Labels := Default(TCompetitionExportLabels);
  Labels.FinishProtocol := rsFinishProtocol;
  Labels.FinishThruProtocol := rsFinishThruProtocol;
  Labels.Place := rsPlace;
  Labels.Number := rsNumber;
  Labels.ParticipantName := rsName;
  Labels.Nickname := rsNickname;
  Labels.Age := rsAge;
  Labels.Team := rsTeam;
  Labels.City := rsCity;
  Labels.Result := rsResult;
  Labels.DiffLeader := rsDiffleader;
  Labels.Penalty := rsPenalty;
  Labels.SumResult := rsSumresult;
  Labels.SumStages := rsSumstages;
  Labels.Category := rsCategory;
  TCompetitionExportService.ExportAllResultsToXlsx(AFileName,
    MainForm.SQLQuery1, MainForm.ResultDatasetStageTotal, stages, Labels);
end;

procedure TMainFlowIntegrationTests.ApplyStartPacketAt(
  const ATime: TDateTime; const AHasCorrection: boolean;
  const ACorrectionMs: integer);
var
  Packet: TTimingPacket;
begin
  Packet := Default(TTimingPacket);
  Packet.Kind := tpkStart;
  Packet.EventTime := ATime;
  Packet.HasCorrection := AHasCorrection;
  Packet.CorrectionMs := ACorrectionMs;
  MainForm.TimingPacketReceived(MainForm, Packet,
    TTimingMarkSource.Ble('integration-test'));
end;

procedure TMainFlowIntegrationTests.ApplyFinishPacketAt(
  const ATime: TDateTime);
var
  Packet: TTimingPacket;
begin
  Packet := Default(TTimingPacket);
  Packet.Kind := tpkFinish;
  Packet.EventTime := ATime;
  MainForm.TimingPacketReceived(MainForm, Packet,
    TTimingMarkSource.Serial('integration-test'));
end;

procedure TMainFlowIntegrationTests.SelectFinishMarkAt(
  const AIndex: integer);
var
  I: integer;
begin
  AssertTrue('Finish marks dataset must be active',
    MainForm.DatasetFinishMarks.Active);
  AssertTrue('Finish mark index must be non-negative', AIndex >= 0);
  MainForm.DatasetFinishMarks.First;
  for I := 1 to AIndex do
  begin
    AssertFalse('Finish mark index is outside the work queue',
      MainForm.DatasetFinishMarks.EOF);
    MainForm.DatasetFinishMarks.Next;
  end;
  AssertFalse('Finish mark index is outside the work queue',
    MainForm.DatasetFinishMarks.EOF);
end;

procedure TMainFlowIntegrationTests.SetFinishMarkNumberAt(
  const AIndex, AParticipantNumber: integer; const APersist: boolean);
begin
  SelectFinishMarkAt(AIndex);
  MainForm.DatasetFinishMarks.Edit;
  MainForm.DatasetFinishMarks.FieldByName(
    'participant_number').AsInteger := AParticipantNumber;
  MainForm.DatasetFinishMarks.Post;
  if APersist then
    MainForm.RxDBGridFinishMarksEditingDone(
      MainForm.RxDBGridFinishMarks);
end;

procedure TMainFlowIntegrationTests.ApplyStageActivityToUi(
  const APreferredStageIndex: integer);
begin
  MainForm.ApplyResultParameterChanges(stages.Count,
    APreferredStageIndex, 0, IsCompetitionDatabaseOpen, False, False);
end;

procedure TMainFlowIntegrationTests.ApplyStagePresentationToUi(
  const APreferredStageIndex: integer);
begin
  MainForm.ApplyPresentationChanges(APreferredStageIndex,
    IsCompetitionDatabaseOpen, True, False, True, False);
end;

procedure TMainFlowIntegrationTests.RefreshResultViewConfiguration;
begin
  MainForm.ApplyPresentationChanges(MainForm.CurrentStageIndex,
    IsCompetitionDatabaseOpen, False, True, False, False);
end;

procedure TMainFlowIntegrationTests.CreateEmptyCompetitionFixture(
  const AStageCount: integer);
begin
  CreateSchemaFixture(AStageCount, IntToStr(AStageCount),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text := 'DELETE FROM main;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;
  RefreshCompetitionViews;
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

procedure TMainFlowIntegrationTests.AssertDynamicStageFields(
  const AStageCount: integer);
const
  FieldPrefixes: array[0..7] of string = (
    'starttime', 'correction', 'finishtime', 'penalty',
    'result', 'diffleader', 'place', 'status'
  );
var
  FieldPrefix: string;
  StageIndex: integer;
begin
  for StageIndex := 1 to AStageCount do
    for FieldPrefix in FieldPrefixes do
      if stages[StageIndex].isActive then
        AssertTrue(Format('Active-stage field %s%d must exist',
          [FieldPrefix, StageIndex]),
          MainForm.MainDataset1.FindField(
          FieldPrefix + IntToStr(StageIndex)) <> nil)
      else
        AssertTrue(Format('Inactive-stage field %s%d must stay detached',
          [FieldPrefix, StageIndex]),
          MainForm.MainDataset1.FindField(
          FieldPrefix + IntToStr(StageIndex)) = nil);

  if AStageCount < MAX_SUPPORTED_STAGE_COUNT then
    AssertTrue('A field above StageCount must not remain attached',
      MainForm.MainDataset1.FindField(
      'status' + IntToStr(AStageCount + 1)) = nil);
  AssertTrue('Stage fields must no longer be persistent form components',
    MainForm.FindComponent('MainDataset1starttime1') = nil);
  AssertTrue('Stage fields must not have streamed component names',
    MainForm.MainDataset1.FindComponent('MainDataset1starttime1') = nil);
end;

procedure TMainFlowIntegrationTests.AssertDynamicStageColumns(
  const AStageCount: integer);
const
  ColumnPrefixes: array[0..6] of string = (
    'correction', 'starttime', 'finishtime', 'penalty',
    'result', 'diffleader', 'place'
  );
  ColumnWidths: array[0..6] of integer = (67, 67, 80, 67, 80, 80, 45);
  ColumnAlignments: array[0..6] of TAlignment = (
    taRightJustify, taCenter, taCenter, taRightJustify,
    taCenter, taCenter, taCenter
  );
var
  BaseIndex, ColumnIndex, PrefixIndex, StageIndex: integer;
  Column: TRxColumn;
  ExpectedVisible: boolean;
begin
  BaseIndex := MainForm.RxDBGrid1.ColumnByFieldName('comment').Index + 1;
  for StageIndex := 1 to AStageCount do
    for PrefixIndex := Low(ColumnPrefixes) to High(ColumnPrefixes) do
    begin
      Column := MainForm.RxDBGrid1.ColumnByFieldName(
        ColumnPrefixes[PrefixIndex] + IntToStr(StageIndex));
      AssertTrue(Format('Dynamic column %s%d must exist',
        [ColumnPrefixes[PrefixIndex], StageIndex]), Column <> nil);
      ColumnIndex := BaseIndex + (StageIndex - 1) * Length(ColumnPrefixes) +
        PrefixIndex;
      AssertEquals(Format('Unexpected position of column %s%d',
        [ColumnPrefixes[PrefixIndex], StageIndex]), ColumnIndex, Column.Index);
      AssertEquals(Format('Unexpected alignment of column %s%d',
        [ColumnPrefixes[PrefixIndex], StageIndex]),
        Ord(ColumnAlignments[PrefixIndex]), Ord(Column.Alignment));
      AssertEquals(Ord(taCenter), Ord(Column.Title.Alignment));

      ExpectedVisible := stages[StageIndex].isActive;
      if (stages.ActiveStagesCount = 1) and
        (StageIndex = stages.FirstActiveIndex) and (PrefixIndex >= 4) then
        ExpectedVisible := False;
      AssertEquals(Format('Unexpected visibility of column %s%d',
        [ColumnPrefixes[PrefixIndex], StageIndex]),
        ExpectedVisible, Column.Visible);

      // In LCL a hidden TGridColumn reports an effective width of zero while
      // retaining its configured width. Show it briefly to verify the width
      // that Ctrl+W will restore for the user.
      if not Column.Visible then
        Column.Visible := True;
      AssertEquals(Format('Unexpected width of column %s%d',
        [ColumnPrefixes[PrefixIndex], StageIndex]),
        ColumnWidths[PrefixIndex], Column.Width);
      Column.Visible := ExpectedVisible;
    end;

  AssertEquals('The summary columns must follow all stage columns',
    BaseIndex + AStageCount * Length(ColumnPrefixes),
    MainForm.RxDBGrid1.ColumnByFieldName('sumresult').Index);
  AssertEquals('The summary-gap column must retain its tail position',
    MainForm.RxDBGrid1.ColumnByFieldName('sumresult').Index + 1,
    MainForm.RxDBGrid1.ColumnByFieldName('sumdiffleader').Index);
  AssertEquals('The global-status column must remain after summary columns',
    MainForm.RxDBGrid1.ColumnByFieldName('sumresult').Index + 2,
    MainForm.RxDBGrid1.ColumnByFieldName('status').Index);
  AssertEquals('Stage result columns must preserve the highlighted color',
    9568145, MainForm.RxDBGrid1.ColumnByFieldName(
      'result' + IntToStr(AStageCount)).Color);

  if AStageCount > 1 then
  begin
    AssertEquals(stages[AStageCount].Name + '|' + rsCorrection,
      MainForm.RxDBGrid1.ColumnByFieldName(
      'correction' + IntToStr(AStageCount)).Title.Caption);
    AssertEquals(stages[AStageCount].Name + '|' + rsPlace,
      MainForm.RxDBGrid1.ColumnByFieldName(
      'place' + IntToStr(AStageCount)).Title.Caption);
  end;

  if AStageCount < MAX_SUPPORTED_STAGE_COUNT then
    for PrefixIndex := Low(ColumnPrefixes) to High(ColumnPrefixes) do
      AssertTrue('A column above StageCount must not remain attached',
        MainForm.RxDBGrid1.ColumnByFieldName(
        ColumnPrefixes[PrefixIndex] + IntToStr(AStageCount + 1)) = nil);
end;

procedure TMainFlowIntegrationTests.AssertDynamicStageResultUi(
  const AStageCount: integer);
const
  ResultFieldPrefixes: array[0..6] of string = (
    'category', 'place', 'number', 'name', 'penalty', 'result', 'diffleader'
  );
  ResultColumnWidths: array[0..6] of integer = (100, 45, 45, 151, 64, 100, 75);
var
  Column: TRxColumn;
  ExpectedCaption, ExpectedFieldName: string;
  ExpectedVisible: boolean;
  PrefixIndex, StageIndex, SummaryBaseIndex: integer;
begin
  AssertEquals('Unexpected number of dynamic stage result views',
    AStageCount, MainForm.StageResultViewCount);
  AssertEquals('Only dynamic stages plus summary and through tabs are expected',
    AStageCount + 2, MainForm.SheetStage.PageCount);
  AssertEquals('The summary tab must follow all dynamic stage tabs',
    AStageCount, MainForm.SheetStageSum.PageIndex);
  AssertEquals('The through tab must remain last', AStageCount + 1,
    MainForm.SheetStageTotal.PageIndex);
  AssertSame('The first stage tab must remain the default result page',
    MainForm.StageResultView(1).Sheet, MainForm.SheetStage.ActivePage);

  SummaryBaseIndex :=
    MainForm.GridResultStageSum.ColumnByFieldName('name').Index + 1;
  for StageIndex := 1 to AStageCount do
  begin
    AssertEquals(StageIndex,
      MainForm.StageResultView(StageIndex).StageIndex);
    AssertSame(MainForm.SheetStage,
      MainForm.StageResultView(StageIndex).Sheet.PageControl);
    AssertEquals(StageIndex - 1,
      MainForm.StageResultView(StageIndex).Sheet.PageIndex);

    ExpectedCaption := stages[StageIndex].Name;
    if (stages.ActiveStagesCount = 1) and
      (stages.FirstActiveIndex = StageIndex) then
      ExpectedCaption := rsTotal;
    AssertEquals(ExpectedCaption,
      MainForm.StageResultView(StageIndex).Sheet.Caption);
    AssertEquals(stages[StageIndex].isActive,
      MainForm.StageResultView(StageIndex).Sheet.TabVisible);

    if stages[StageIndex].isActive then
    begin
      MainForm.ActivateStageResult(StageIndex);
      Application.ProcessMessages;
      AssertTrue(Format('Opened active stage %d must create its content lazily',
        [StageIndex]),
        MainForm.StageResultView(StageIndex).ContentCreated);
      AssertSame(MainForm.StageResultView(StageIndex).Sheet,
        MainForm.StageResultView(StageIndex).Grid.Parent);
      AssertSame(MainForm.StageResultView(StageIndex).DataSource,
        MainForm.StageResultView(StageIndex).Grid.DataSource);
      AssertSame(MainForm.StageResultView(StageIndex).Query,
        MainForm.StageResultView(StageIndex).DataSource.DataSet);
      AssertSame(MainForm.SQLite3Connection1,
        MainForm.StageResultView(StageIndex).Query.Database);
      AssertSame(MainForm.SQLTransaction1,
        MainForm.StageResultView(StageIndex).Query.Transaction);
      AssertTrue(MainForm.StageResultView(StageIndex).Query.ReadOnly);
      AssertTrue(sqoKeepOpenOnCommit in
        MainForm.StageResultView(StageIndex).Query.Options);
      AssertTrue('The selected active stage query must be open',
        MainForm.StageResultView(StageIndex).Query.Active);
      AssertEquals(Trim(TDatasetSql.ResultStage(StageIndex, AStageCount)),
        Trim(MainForm.StageResultView(StageIndex).Query.SQL.Text));

      AssertEquals(Length(ResultFieldPrefixes),
        MainForm.StageResultView(StageIndex).Grid.Columns.Count);
      for PrefixIndex := Low(ResultFieldPrefixes) to High(ResultFieldPrefixes) do
      begin
        ExpectedFieldName := ResultFieldPrefixes[PrefixIndex];
        if PrefixIndex in [1, 4, 5, 6] then
          ExpectedFieldName := ExpectedFieldName + IntToStr(StageIndex);
        Column := MainForm.StageResultView(StageIndex).Grid.Columns[PrefixIndex];
        AssertEquals(ExpectedFieldName, Column.FieldName);
        AssertEquals(ResultColumnWidths[PrefixIndex], Column.Width);
        AssertEquals(Ord(taCenter), Ord(Column.Title.Alignment));
      end;
    end;
    if not stages[StageIndex].isActive then
      AssertFalse('Inactive stage content must not be created during open',
        MainForm.StageResultView(StageIndex).ContentCreated);

    Column := MainForm.GridResultStageSum.ColumnByFieldName(
      'result' + IntToStr(StageIndex));
    AssertTrue('A dynamic summary result column must exist', Column <> nil);
    AssertEquals(SummaryBaseIndex + StageIndex - 1, Column.Index);
    AssertEquals(stages[StageIndex].Name, Column.Title.Caption);
    ExpectedVisible := stages[StageIndex].isActive and
      (stages.ActiveStagesCount <> 1);
    AssertEquals(ExpectedVisible, Column.Visible);
    if not Column.Visible then
      Column.Visible := True;
    AssertEquals(100, Column.Width);
    Column.Visible := ExpectedVisible;
  end;

  MainForm.ActivateStageResult(stages.FirstActiveIndex);
  Application.ProcessMessages;

  AssertEquals(SummaryBaseIndex + AStageCount,
    MainForm.GridResultStageSum.ColumnByFieldName('sumresult').Index);
  AssertEquals(Trim(TDatasetSql.ResultStageSum(stages.ActiveIndices)),
    Trim(MainForm.ResultDatasetStageSum.SQL.Text));
  if AStageCount < MAX_SUPPORTED_STAGE_COUNT then
    AssertTrue('A summary column above StageCount must not remain attached',
      MainForm.GridResultStageSum.ColumnByFieldName(
      'result' + IntToStr(AStageCount + 1)) = nil);

  AssertTrue('Static result datasets must no longer belong to the form',
    MainForm.FindComponent('ResultDataset1') = nil);
  AssertTrue('Static result tabs must no longer belong to the form',
    MainForm.FindComponent('SheetStage1') = nil);
end;

procedure TMainFlowIntegrationTests.AssertCurrentStageSelector(
  const AStageCount: integer);
var
  FirstActiveStageIndex: integer;
begin
  FirstActiveStageIndex := stages.FirstActiveIndex;
  AssertEquals('The selector must list every active stage',
    stages.ActiveStagesCount, MainForm.CurrentStageComboBox.Items.Count);
  AssertEquals('The selector must initially use the first active stage',
    FirstActiveStageIndex, MainForm.CurrentStageIndex);
  AssertEquals('Selector visibility must depend only on active stage count',
    stages.ActiveStagesCount > 1, MainForm.CurrentStageGroup.Visible);
  AssertTrue('The highest configured stage must be active in the fixture',
    stages[AStageCount].isActive);

  MainForm.SelectCurrentStage(AStageCount);
  AssertEquals('The selector must support the highest configured stage',
    AStageCount, MainForm.CurrentStageIndex);
  AssertEquals(Format('%d — %s',
    [AStageCount, stages[AStageCount].Name]),
    MainForm.CurrentStageComboBox.Items[
    MainForm.CurrentStageComboBox.ItemIndex]);

  MainForm.SelectCurrentStage(FirstActiveStageIndex);
end;

procedure TMainFlowIntegrationTests.AssertDynamicStageSettings(
  const AStageCount: integer);
const
  ROW_HEIGHT = 34;
var
  form: TSettingsForm;
  row: TStageSettingsFrame;
  originalFirstName: string;
  originalFirstActive: boolean;
  originalStage2Active: boolean;
  originalStage12Active: boolean;
  StageIndex: integer;
begin
  originalFirstName := stages[1].Name;
  originalFirstActive := stages[1].isActive;
  if AStageCount >= 12 then
  begin
    originalStage2Active := stages[2].isActive;
    originalStage12Active := stages[12].isActive;
  end;
  form := TSettingsForm.Create(nil);
  try
    AssertEquals(AStageCount, form.StageCountSpinEdit.Value);
    AssertTrue('Stage count editing must be enabled',
      form.StageCountSpinEdit.Enabled);
    AssertEquals(MIN_STAGE_COUNT, form.StageCountSpinEdit.MinValue);
    AssertEquals(MAX_SUPPORTED_STAGE_COUNT, form.StageCountSpinEdit.MaxValue);
    AssertSame(form.GroupBoxStages, form.StagesContentPanel.Parent);
    AssertEquals(Max(form.StagesContentPanel.Constraints.MinHeight,
      AStageCount * ROW_HEIGHT), form.StagesContentPanel.Height);
    form.Notebook1.PageIndex := 2;
    form.Show;
    Application.ProcessMessages;
    for StageIndex := 1 to 8 do
      AssertTrue(Format('Legacy stage name edit SUEdit%d must be removed',
        [StageIndex]), form.FindComponent(
        'SUEdit' + IntToStr(StageIndex)) = nil);
    AssertTrue('Legacy active-stage check group must be removed',
      form.FindComponent('CheckGroup1') = nil);

    for StageIndex := 1 to AStageCount do
    begin
      row := TStageSettingsFrame(form.FindComponent(
        'StageSettingsFrame' + IntToStr(StageIndex)));
      AssertTrue(Format('Missing settings row for stage %d', [StageIndex]),
        row <> nil);
      AssertSame(form.StagesContentPanel, row.Parent);
      AssertEquals(StageIndex, row.StageIndex);
      AssertEquals((StageIndex - 1) * ROW_HEIGHT, row.Top);
      AssertEquals(stages[StageIndex].Name, row.StageName);
      AssertEquals(stages[StageIndex].isActive, row.Active);
    end;

    row := TStageSettingsFrame(form.FindComponent('StageSettingsFrame1'));
    row.StageName := 'Draft stage name';
    row.Active := not originalFirstActive;
    AssertEquals('Editing the draft must not change the model name',
      originalFirstName, stages[1].Name);
    AssertEquals('Editing the draft must not change model activity',
      originalFirstActive, stages[1].isActive);

    if AStageCount >= 12 then
    begin
      for StageIndex := 1 to AStageCount do
        TStageSettingsFrame(form.FindComponent(
          'StageSettingsFrame' + IntToStr(StageIndex))).Active := False;
      TStageSettingsFrame(form.FindComponent('StageSettingsFrame2')).Active :=
        True;
      TStageSettingsFrame(form.FindComponent('StageSettingsFrame12')).Active :=
        True;
      AssertEquals(2, form.ComboBoxAStage.Items.Count);
      AssertEquals('2', form.ComboBoxAStage.Items[0]);
      AssertEquals('12', form.ComboBoxAStage.Items[1]);
      AssertEquals('Sparse draft activity must stay local',
        originalStage2Active, stages[2].isActive);
      AssertEquals('Sparse draft activity must stay local',
        originalStage12Active, stages[12].isActive);
    end;
  finally
    form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.ConfigureSingleActiveStage(
  const AStageIndex: integer);
var
  i: integer;
begin
  for i := 1 to stages.Count do
    stages[i].isActive := i = AStageIndex;
  ApplyStageActivityToUi(AStageIndex);
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
  RefreshCompetitionViews;
end;

procedure TMainFlowIntegrationTests.CreateSchemaFixture(
  const APhysicalStageCount: integer; const AStageCountValue,
  ASchemaVersionValue: string);
var
  Connection: TSQLite3Connection;
  Transaction: TSQLTransaction;
  Query: TSQLQuery;
begin
  Connection := TSQLite3Connection.Create(nil);
  Transaction := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Connection.DatabaseName := FDbFilePath;
    Connection.Transaction := Transaction;
    Transaction.Database := Connection;
    Query.DataBase := Connection;
    Query.Transaction := Transaction;
    Connection.Open;
    Transaction.Active := True;
    TSchemaSql.ExecCreateTables(Connection, APhysicalStageCount,
      'A', 'B', 'C', 'D', 'E', 'Legacy race');

    if AStageCountValue = '' then
    begin
      Query.SQL.Text := 'DELETE FROM config WHERE key = ''stagecount'';';
      Query.ExecSQL;
    end
    else
      TConfigSql.ExecUpsertByKey(Query, 'stagecount', AStageCountValue);
    if ASchemaVersionValue = '' then
    begin
      Query.SQL.Text := 'DELETE FROM config WHERE key = ''schema_version'';';
      Query.ExecSQL;
    end
    else
      TConfigSql.ExecUpsertByKey(Query, 'schema_version',
        ASchemaVersionValue);

    TConfigSql.ExecUpsertByKey(Query, 'stage1', 'True');
    TConfigSql.ExecUpsertByKey(Query, 'stagename1', 'Legacy stage one');
    if APhysicalStageCount >= 8 then
    begin
      TConfigSql.ExecUpsertByKey(Query, 'stage8', 'True');
      TConfigSql.ExecUpsertByKey(Query, 'stagename8', 'Legacy stage eight');
    end;
    if APhysicalStageCount > 8 then
    begin
      TConfigSql.ExecUpsertByKey(Query,
        'stage' + IntToStr(APhysicalStageCount), 'True');
      TConfigSql.ExecUpsertByKey(Query,
        'stagename' + IntToStr(APhysicalStageCount),
        'Legacy stage ' + IntToStr(APhysicalStageCount));
    end;
    Query.SQL.Text :=
      'INSERT INTO main (number, name, starttime1, result1) VALUES ' +
      '(808, ''Legacy participant'', ''10:00:00.000'', ''00:05:00.000'');';
    Query.ExecSQL;
    Transaction.Commit;
  finally
    Query.Free;
    Transaction.Free;
    Connection.Free;
  end;
end;

function TMainFlowIntegrationTests.FindBackupFile: string;
var
  BackupDirectory, FileMask: string;
  SearchRec: TSearchRec;
begin
  Result := '';
  BackupDirectory := IncludeTrailingPathDelimiter(
    ExtractFilePath(FDbFilePath) + 'backup');
  FileMask := BackupDirectory + '*' + ExtractFileName(FDbFilePath);
  if FindFirst(FileMask, faAnyFile, SearchRec) <> 0 then
    Exit;
  try
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        Result := BackupDirectory + SearchRec.Name;
        Exit;
      end;
    until FindNext(SearchRec) <> 0;
  finally
    FindClose(SearchRec);
  end;
end;

function TMainFlowIntegrationTests.LoadConfigValueFromFile(
  const AFileName, AKey, ADefaultValue: string): string;
var
  Connection: TSQLite3Connection;
  Transaction: TSQLTransaction;
  Query: TSQLQuery;
begin
  Connection := TSQLite3Connection.Create(nil);
  Transaction := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Connection.DatabaseName := AFileName;
    Connection.Transaction := Transaction;
    Transaction.Database := Connection;
    Query.DataBase := Connection;
    Query.Transaction := Transaction;
    Connection.Open;
    Result := TConfigSql.GetString(Query, AKey, ADefaultValue);
  finally
    Query.Free;
    Transaction.Free;
    Connection.Free;
  end;
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

procedure TMainFlowIntegrationTests.SelectFriendlySerialDeviceAndClose(
  Data: PtrInt);
var
  devices: TSerialDeviceInfoArray;
  form: TSettingsForm;
  i: integer;
begin
  form := nil;
  for i := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[i] is TSettingsForm then
    begin
      form := TSettingsForm(Screen.Forms[i]);
      Break;
    end;
  if form = nil then
  begin
    InputDialogCallbackError := 'The settings form was not found';
    Exit;
  end;

  SetLength(devices, 1);
  devices[0] := Default(TSerialDeviceInfo);
  devices[0].Device := TEST_SERIAL_DEVICE;
  devices[0].Vendor := 'ENTime';
  devices[0].Model := 'USB UART';
  devices[0].SerialShort := 'ABC123';
  TSerialSelectorTestAccess(form.ComComboBox1).ApplyTestDevices(devices);
  form.ComComboBox1.Device := TEST_SERIAL_DEVICE;
  if form.ComComboBox1.Text <> TEST_SERIAL_FRIENDLY_NAME then
    InputDialogCallbackError := 'The serial selector does not show the friendly name'
  else if form.ComComboBox1.Device <> TEST_SERIAL_DEVICE then
    InputDialogCallbackError := 'The serial selector does not expose the raw device';
  form.ModalResult := TModalResult(Data);
end;

procedure TMainFlowIntegrationTests.EnterCustomSerialDeviceAndClose(
  Data: PtrInt);
var
  form: TSettingsForm;
  i: integer;
begin
  form := nil;
  for i := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[i] is TSettingsForm then
    begin
      form := TSettingsForm(Screen.Forms[i]);
      Break;
    end;
  if form = nil then
  begin
    InputDialogCallbackError := 'The settings form was not found';
    Exit;
  end;

  if not form.ComComboBox1.AllowCustomDevice then
    InputDialogCallbackError := 'The serial selector does not allow custom devices'
  else
  begin
    form.ComComboBox1.ItemIndex := -1;
    form.ComComboBox1.Text := '/tmp/entime-manual-port';
  end;
  form.ModalResult := TModalResult(Data);
end;

procedure TMainFlowIntegrationTests.EditStageDraftAndClose(Data: PtrInt);
var
  form: TSettingsForm;
  i: integer;
begin
  for i := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[i] is TSettingsForm then
    begin
      form := TSettingsForm(Screen.Forms[i]);
      TStageSettingsFrame(form.FindComponent('StageSettingsFrame1')).StageName :=
        'Accepted draft stage';
      form.StageCountSpinEdit.Value := 2;
      AssertTrue('A newly added stage must be checked before accepting',
        TStageSettingsFrame(form.FindComponent(
          'StageSettingsFrame2')).Active);
      AssertTrue('A newly added stage must enter the active-stage selector',
        form.ComboBoxAStage.Items.IndexOf('2') >= 0);
      form.ModalResult := TModalResult(Data);
      Exit;
    end;
end;

procedure TMainFlowIntegrationTests.ResizeStageDraftAndClose(Data: PtrInt);
var
  form: TSettingsForm;
  row: TStageSettingsFrame;
  i, itemIndex: integer;
begin
  for i := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[i] is TSettingsForm then
    begin
      form := TSettingsForm(Screen.Forms[i]);
      form.StageCountSpinEdit.Value := SettingsDraftStageCount;
      if SettingsDraftStageName <> '' then
      begin
        row := TStageSettingsFrame(form.FindComponent('StageSettingsFrame' +
          IntToStr(SettingsDraftStageCount)));
        row.StageName := SettingsDraftStageName;
        row.Active := SettingsDraftStageActive;
      end;
      if SettingsDraftActiveStageIndex > 0 then
      begin
        itemIndex := form.ComboBoxAStage.Items.IndexOf(
          IntToStr(SettingsDraftActiveStageIndex));
        if itemIndex >= 0 then
          form.ComboBoxAStage.ItemIndex := itemIndex;
      end;
      form.ModalResult := TModalResult(Data);
      Exit;
    end;
end;

procedure TMainFlowIntegrationTests.ActivateOnlyStageAndClose(Data: PtrInt);
var
  form: TSettingsForm;
  formIndex, stageIndex, itemIndex: integer;
begin
  for formIndex := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[formIndex] is TSettingsForm then
    begin
      form := TSettingsForm(Screen.Forms[formIndex]);
      for stageIndex := 1 to form.StageCountSpinEdit.Value do
        TStageSettingsFrame(form.FindComponent('StageSettingsFrame' +
          IntToStr(stageIndex))).Active :=
          stageIndex = SettingsDraftActiveStageIndex;
      itemIndex := form.ComboBoxAStage.Items.IndexOf(
        IntToStr(SettingsDraftActiveStageIndex));
      if itemIndex >= 0 then
        form.ComboBoxAStage.ItemIndex := itemIndex;
      form.ModalResult := TModalResult(Data);
      Exit;
    end;
end;

procedure TMainFlowIntegrationTests.ActivateAllStagesAndClose(Data: PtrInt);
var
  form: TSettingsForm;
  formIndex, stageIndex, itemIndex: integer;
begin
  for formIndex := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[formIndex] is TSettingsForm then
    begin
      form := TSettingsForm(Screen.Forms[formIndex]);
      for stageIndex := 1 to form.StageCountSpinEdit.Value do
        TStageSettingsFrame(form.FindComponent('StageSettingsFrame' +
          IntToStr(stageIndex))).Active := True;
      itemIndex := form.ComboBoxAStage.Items.IndexOf(
        IntToStr(SettingsDraftActiveStageIndex));
      if itemIndex >= 0 then
        form.ComboBoxAStage.ItemIndex := itemIndex;
      form.ModalResult := TModalResult(Data);
      Exit;
    end;
end;

procedure TMainFlowIntegrationTests.RenameFirstStageAndClose(Data: PtrInt);
var
  form: TSettingsForm;
  formIndex: integer;
begin
  for formIndex := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[formIndex] is TSettingsForm then
    begin
      form := TSettingsForm(Screen.Forms[formIndex]);
      TStageSettingsFrame(form.FindComponent(
        'StageSettingsFrame1')).StageName := SettingsDraftStageName;
      form.ModalResult := TModalResult(Data);
      Exit;
    end;
end;

procedure TMainFlowIntegrationTests.ChangeResultCategoryAndClose(Data: PtrInt);
var
  form: TSettingsForm;
  formIndex: integer;
begin
  for formIndex := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[formIndex] is TSettingsForm then
    begin
      form := TSettingsForm(Screen.Forms[formIndex]);
      form.Edit1.Text := SettingsDraftCategoryName;
      form.ModalResult := TModalResult(Data);
      Exit;
    end;
end;

procedure TMainFlowIntegrationTests.CountMainDatasetOpen(DataSet: TDataSet);
begin
  Inc(FMainDatasetOpenCount);
end;

procedure TMainFlowIntegrationTests.CountStatDatasetOpen(DataSet: TDataSet);
begin
  Inc(FStatDatasetOpenCount);
end;

procedure TMainFlowIntegrationTests.CountCorrectionDatasetOpen(
  DataSet: TDataSet);
begin
  Inc(FCorrectionDatasetOpenCount);
end;

procedure TMainFlowIntegrationTests.CountResultDatasetOpen(DataSet: TDataSet);
begin
  Inc(FResultDatasetOpenCount);
end;

procedure TMainFlowIntegrationTests.ConfigureSerialUi(const ADevice: string;
  const ADeviceNames: array of string);
begin
  if MainForm.Serial.Active then
    MainForm.AcCOMCloseExecute(MainForm.AcCOMClose);
  SetFakeSerialDevices(ADeviceNames);
  MainForm.Serial.Device := ADevice;
  MainForm.SerialPortPopupMenuPopup(MainForm.SerialPortPopupMenu);
end;

function TMainFlowIntegrationTests.FindSerialPortMenuItem(
  const ACaption: string): TMenuItem;
var
  i: integer;
begin
  Result := nil;
  for i := 0 to MainForm.SerialPortPopupMenu.Items.Count - 1 do
    if MainForm.SerialPortPopupMenu.Items[i].Caption = ACaption then
      Exit(MainForm.SerialPortPopupMenu.Items[i]);
  Fail('Serial-port menu item not found: ' + ACaption);
end;

{$IFDEF UNIX}
function TMainFlowIntegrationTests.VirtualSerialDevice: string;
begin
  Result := Trim(GetEnvironmentVariable('ENTIME_SERIAL_DEVICE'));
  AssertTrue('Virtual serial port is not configured by the integration runner',
    Result <> '');
end;

procedure TMainFlowIntegrationTests.OpenVirtualSerialPort;
var
  deviceName: string;
begin
  deviceName := VirtualSerialDevice;
  ConfigureSerialUi(deviceName, [deviceName]);
  MainForm.AcCOMOpenExecute(MainForm.AcCOMOpen);
  Application.ProcessMessages;
  AssertTrue('Expected the virtual serial port to be connected',
    MainForm.Serial.Active);
end;
{$ENDIF}

procedure TMainFlowIntegrationTests.AcceptInputComboDialog(Data: PtrInt);
var
  componentIndex, formIndex: integer;
  dialogForm: TForm;
begin
  dialogForm := nil;
  for formIndex := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[formIndex].Caption = 'Input combo test' then
    begin
      dialogForm := Screen.Forms[formIndex];
      Break;
    end;
  if dialogForm = nil then
  begin
    InputDialogCallbackError := 'The input combo dialog was not found';
    Exit;
  end;
  for componentIndex := 0 to dialogForm.ComponentCount - 1 do
    if dialogForm.Components[componentIndex] is TComboBox then
    begin
      TComboBox(dialogForm.Components[componentIndex]).ItemIndex := 1;
      dialogForm.ModalResult := mrOk;
      Exit;
    end;
  InputDialogCallbackError :=
    'The input combo dialog does not own a combo box';
  dialogForm.ModalResult := mrCancel;
end;

procedure TMainFlowIntegrationTests.AcceptInputDateTimeDialog(Data: PtrInt);
var
  componentIndex, formIndex: integer;
  dialogForm: TForm;
begin
  dialogForm := nil;
  for formIndex := Screen.FormCount - 1 downto 0 do
    if Screen.Forms[formIndex].Caption = 'Input date-time test' then
    begin
      dialogForm := Screen.Forms[formIndex];
      Break;
    end;
  if dialogForm = nil then
  begin
    InputDialogCallbackError := 'The date-time dialog was not found';
    Exit;
  end;
  for componentIndex := 0 to dialogForm.ComponentCount - 1 do
    if dialogForm.Components[componentIndex] is TDateTimePicker then
    begin
      TDateTimePicker(dialogForm.Components[componentIndex]).Time :=
        EncodeTime(12, 34, 56, 0);
      dialogForm.ModalResult := mrOk;
      Exit;
    end;
  InputDialogCallbackError :=
    'The date-time dialog does not own a date-time picker';
  dialogForm.ModalResult := mrCancel;
end;

procedure TMainFlowIntegrationTests.SetUp;
var
  repoRoot: string;
  fixtureLines: TStringList;
begin
  FBleTestProcessor := TTransportStreamProcessor.Create;
  FBleTestProcessor.OnTimingPacket := @BleTimingPacketReceived;
  DialogCallCount := 0;
  LastDialogMessage := '';
  ConfirmationDialogResult := mrYes;
  SetMessageDlgHandler(@IntegrationMessageDlgHandler);
  // Integration tests must never start the real Codeberg update request while
  // the main form restores its persisted properties.
  checkUpdateAtStartup := False;
  EnsureFormsCreated;
  MainForm.ResultClearClick(MainForm);
  AssertEquals('Unexpected dialog while creating the main form: ' +
    LastDialogMessage, 0, DialogCallCount);
  timingInputTransport := ttkSerial;
  startMarkMatchDeltaSeconds := 15;
  startMarkAutomaticApply := False;
  MainForm.LazBleLclClient1.DeviceId := '';
  MainForm.RefreshTimingInputUi;
  if MainForm.Serial.Active then
    MainForm.AcCOMCloseExecute(MainForm.AcCOMClose);
  FakeSerialDevices := nil;
  FakeSerialDevicesProviderCallCount := 0;
  InputDialogCallbackError := '';
  SetSerialDevicesProvider(@IntegrationSerialDevicesProvider);
  MainForm.FileCloseExecute(nil);

  StageSelectionCallCount := 0;
  StageSelectionResult := 2;
  SettingsDraftStageCount := 0;
  SettingsDraftStageName := '';
  SettingsDraftStageActive := False;
  SettingsDraftActiveStageIndex := 0;
  SettingsDraftCategoryName := '';
  ResetStageSelectionHandler;
  StartMarkStageChoiceCallCount := 0;
  StartMarkStageChoiceResult := smscCancel;
  LastStartMarkStageChoiceMessage := '';
  SetStartMarkStageChoiceHandler(@IntegrationStartMarkStageChoiceHandler);

  FDbFilePath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    Format('entime-main-integration-%d.db', [GetTickCount64]);
  FCsvFilePath := ChangeFileExt(FDbFilePath, '.csv');
  if FileExists(FDbFilePath) then
    DeleteFile(FDbFilePath);
  if FileExists(FCsvFilePath) then
    DeleteFile(FCsvFilePath);

  repoRoot := ResolveRepoRoot;
  FImportFilePath := IncludeTrailingPathDelimiter(repoRoot) +
    'tests' + DirectorySeparator + 'fixtures' + DirectorySeparator +
    'startlist ansi.csv';
  AssertTrue('Missing fixture file: ' + FImportFilePath, FileExists(FImportFilePath));

  fixtureLines := TStringList.Create;
  try
    fixtureLines.LoadFromFile(FImportFilePath);
    FExpectedImportedRows := fixtureLines.Count - 1;
  finally
    fixtureLines.Free;
  end;
end;

procedure TMainFlowIntegrationTests.MainForm_InitialStageContextUsesMinimumStageCount;
begin
  AssertEquals('The initial stage model must contain only one stage',
    MIN_STAGE_COUNT, stages.Count);
  AssertEquals('The initial stored stage count must match the model',
    MIN_STAGE_COUNT, StoredStageCount);
  AssertTrue('The initial first-stage field must be created',
    MainForm.MainDataset1.FindField('starttime1') <> nil);
  AssertTrue('Higher-stage fields must wait until a competition is opened',
    MainForm.MainDataset1.FindField('starttime2') = nil);
  AssertTrue('The initial first-stage column must be created',
    MainForm.RxDBGrid1.ColumnByFieldName('correction1') <> nil);
  AssertTrue('Higher-stage columns must wait until a competition is opened',
    MainForm.RxDBGrid1.ColumnByFieldName('correction2') = nil);
  AssertEquals('Only one result-stage view must be created initially',
    MIN_STAGE_COUNT, MainForm.StageResultViewCount);
end;

procedure TMainFlowIntegrationTests.MainForm_SerialDefaultsMatchFirmwareAndPersist;
begin
  AssertEquals(
    'The default serial baud rate must match entime-firmware',
    Ord(br115200),
    Ord(MainForm.Serial.BaudRate)
  );
  AssertTrue(
    'The selected baud rate must be stored between application runs',
    Pos('Serial.BaudRate', MainForm.SessionProperties) > 0
  );
end;

procedure TMainFlowIntegrationTests.InputDialogs_ReturnValuesAndReleaseOwnedForms;
var
  initialFormCount, selectedIndex: integer;
  selectedText: string;
  items: TStringList;
  selectedTime: TDateTime;
begin
  initialFormCount := Screen.FormCount;
  InputDialogCallbackError := '';
  selectedIndex := -1;
  selectedText := '';
  items := TStringList.Create;
  try
    items.Add('First');
    items.Add('Second');
    Application.QueueAsyncCall(@AcceptInputComboDialog, 0);
    AssertEquals(mrOk, MyDoInputCombo('Input combo test', 'Prompt', items, 0,
      False, selectedIndex, selectedText));
    AssertEquals('', InputDialogCallbackError);
    AssertEquals(1, selectedIndex);
    AssertEquals('Second', selectedText);
    AssertEquals('The combo dialog and its controls must be released',
      initialFormCount, Screen.FormCount);

    Application.QueueAsyncCall(@AcceptInputDateTimeDialog, 0);
    selectedTime := InputDateTime('Input date-time test', 'Prompt');
    AssertEquals('', InputDialogCallbackError);
    AssertEquals('12:34:56', FormatDateTime('hh:nn:ss', selectedTime));
    AssertEquals('The date-time dialog and its controls must be released',
      initialFormCount, Screen.FormCount);
  finally
    items.Free;
  end;
end;

procedure TMainFlowIntegrationTests.MainForm_BleTimingTransportStartsDisconnected;
begin
  AssertNotNull(MainForm.BleTimingTransport);
  AssertSame(MainForm.LazBleComponent1, MainForm.LazBleLclClient1.LazBle);
  AssertEquals(1, MainForm.LazBleComponent1.ClientCount);
  AssertTrue(Assigned(MainForm.LazBleLclClient1.OnConfigureClient));
  AssertTrue(Assigned(MainForm.LazBleLclClient1.OnDeviceChanged));
  AssertTrue(Assigned(MainForm.LazBleLclClient1.OnStateChanged));
  AssertTrue(Assigned(MainForm.LazBleLclClient1.OnError));
  AssertEquals('', MainForm.BleTimingTransport.DeviceId);
  AssertEquals(Ord(lbcstDisconnected),
    Ord(MainForm.BleTimingTransport.State));

  MainForm.LazBleLclClient1.DeviceId := 'integration-device';
  AssertEquals('integration-device', MainForm.BleTimingTransport.DeviceId);
  MainForm.LazBleLclClient1.DeviceId := '';
  AssertEquals('', MainForm.BleTimingTransport.DeviceId);
end;

procedure TMainFlowIntegrationTests.
  MyRxDBGrid_ColumnBatchDefersSortListRefreshUntilOuterEnd;
var
  grid: TMyRxDBGrid;
  oldFixedRows, oldRowCount: integer;
  sortedColumn: TRxColumn;
begin
  grid := TMyRxDBGrid.Create(nil);
  try
    grid.Parent := MainForm;
    grid.Visible := False;
    AssertTrue('The batch test requires an allocated grid handle',
      grid.Handle <> 0);
    oldFixedRows := TMyRxDBGridAccess(grid).FixedRows;
    oldRowCount := TMyRxDBGridAccess(grid).RowCount;
    sortedColumn := grid.Columns.Add;
    sortedColumn.FieldName := 'sortable';
    grid.SetSort(['sortable'], [smUp], False);
    AssertEquals(1, grid.SortColumns.Count);

    grid.BeginColumnsUpdate;
    try
      grid.BeginColumnsUpdate;
      try
        AssertEquals('Rx title recalculation must be deferred in a batch',
          0, TMyRxDBGridAccess(grid).RowCount);
        sortedColumn.Title.Caption := 'Stage|Result';
        sortedColumn.Free;
        AssertEquals('Sort-list refresh must be deferred inside the batch',
          1, grid.SortColumns.Count);
      finally
        grid.EndColumnsUpdate;
      end;
      AssertEquals('The inner End must not finish the outer batch',
        1, grid.SortColumns.Count);
    finally
      grid.EndColumnsUpdate;
    end;
    AssertEquals('The outer End must rebuild the sort list exactly once',
      0, grid.SortColumns.Count);
    AssertEquals('The batch must restore the grid row count', oldRowCount,
      TMyRxDBGridAccess(grid).RowCount);
    AssertEquals('The batch must restore the fixed title rows', oldFixedRows,
      TMyRxDBGridAccess(grid).FixedRows);

    sortedColumn := grid.Columns.Add;
    sortedColumn.FieldName := 'sortable_after_batch';
    grid.SetSort(['sortable_after_batch'], [smDown], False);
    AssertEquals('Header sorting must remain usable after a batch',
      1, grid.SortColumns.Count);
  finally
    grid.Free;
  end;
end;

procedure TMainFlowIntegrationTests.TearDown;
begin
  MainForm.ResultClearClick(MainForm);
  FreeAndNil(FBleTestProcessor);
  if MainForm.Serial.Active then
    MainForm.AcCOMCloseExecute(MainForm.AcCOMClose);
  ResetSerialDevicesProvider;
  ResetStageSelectionHandler;
  ResetStartMarkStageChoiceHandler;
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

procedure TMainFlowIntegrationTests.ReadOnlyDatasets_UseSqlQueryAndSharedContext;
begin
  AssertFalse('MainDataset1 is the editable SQLDB query',
    MainForm.MainDataset1.ReadOnly);
  AssertEquals(Trim(TDatasetSql.MainParticipants(stages.ActiveIndices)),
    Trim(MainForm.MainDataset1.SQL.Text));
  AssertSame(MainForm.SQLite3Connection1, MainForm.MainDataset1.Database);
  AssertSame(MainForm.SQLTransaction1, MainForm.MainDataset1.Transaction);
  AssertTrue(MainForm.StageResultView(1).Query.ReadOnly);
  AssertTrue(MainForm.ResultDatasetStageSum.ReadOnly);
  AssertTrue(MainForm.StatDataset1.ReadOnly);
  AssertTrue(MainForm.StatDataset2.ReadOnly);
  AssertFalse(MainForm.CorrectionDataset.ReadOnly);
  AssertFalse(MainForm.DatasetStartMarks.ReadOnly);
  AssertFalse(MainForm.DatasetFinishMarks.ReadOnly);
  AssertEquals(Trim(TDatasetSql.CategoryStatistics),
    Trim(MainForm.StatDataset1.SQL.Text));
  AssertEquals(Trim(TDatasetSql.CorrectionPending(1)),
    Trim(MainForm.CorrectionDataset.SQL.Text));
  AssertEquals(Trim(TDatasetSql.ResultStage(1)),
    Trim(MainForm.StageResultView(1).Query.SQL.Text));
  AssertEquals(Trim(TStartMarkSql.SelectWorkQueue),
    Trim(MainForm.DatasetStartMarks.SQL.Text));
  AssertEquals(Trim(TFinishMarkSql.SelectWorkQueue),
    Trim(MainForm.DatasetFinishMarks.SQL.Text));
  AssertTrue(ResultsForm.CatDataset1.ReadOnly);
  AssertTrue(ResultsForm.ResultDataset.ReadOnly);
  AssertSame(MainForm.SQLite3Connection1,
    MainForm.StageResultView(1).Query.Database);
  AssertSame(MainForm.SQLTransaction1,
    MainForm.StageResultView(1).Query.Transaction);
  AssertSame(MainForm.SQLite3Connection1, ResultsForm.ResultDataset.Database);
  AssertSame(MainForm.SQLTransaction1, ResultsForm.ResultDataset.Transaction);
end;

procedure TMainFlowIntegrationTests.PersistentFieldTypes_MatchSqliteAndQueryResults;
begin
  CreateNewCompetitionFile;
  InsertParticipant(409);
  MainForm.CompetitionDb.RefreshQuery(MainForm.StatDataset1);

  AssertTrue('rfid is declared VARCHAR in SQLite',
    MainForm.MainDataset1.FieldByName('rfid') is TStringField);
  AssertTrue('thruplace is declared INTEGER in SQLite',
    MainForm.MainDataset1.FieldByName('thruplace') is TLongintField);
  AssertTrue('An aliased id is no longer an autoincrement result field',
    MainForm.StatDataset1.FieldByName('id_stat') is TLongintField);
  AssertTrue('SQLite count() returns a 64-bit result',
    MainForm.StatDataset1.FieldByName('catcount') is TLargeintField);
end;

procedure TMainFlowIntegrationTests.MainGrid_OptionalParticipantColumnsHaveExplicitWidths;
begin
  AssertEquals(60, MainForm.RxDBGrid1.ColumnByFieldName('id').StoredWidth);
  AssertEquals(120, MainForm.RxDBGrid1.ColumnByFieldName('rfid').StoredWidth);
  AssertEquals(100, MainForm.RxDBGrid1.ColumnByFieldName('nickname').StoredWidth);
  AssertEquals(60, MainForm.RxDBGrid1.ColumnByFieldName('age').StoredWidth);
  AssertEquals(120, MainForm.RxDBGrid1.ColumnByFieldName('team').StoredWidth);
  AssertEquals(100, MainForm.RxDBGrid1.ColumnByFieldName('city').StoredWidth);
  AssertEquals(130, MainForm.RxDBGrid1.ColumnByFieldName('phone').StoredWidth);
  AssertEquals(180, MainForm.RxDBGrid1.ColumnByFieldName('email').StoredWidth);
  AssertEquals(200, MainForm.RxDBGrid1.ColumnByFieldName('comment').StoredWidth);
  AssertEquals(70, MainForm.RxDBGrid1.ColumnByFieldName('status').StoredWidth);
end;

procedure TMainFlowIntegrationTests.RaceModeSpace_AddsTimeWithoutClearingSelectedCell;
var
  key: word;
begin
  CreateNewCompetitionFile;
  ApplyFinishPacketAt(EncodeTime(10, 0, 0, 0));
  SetFinishMarkNumberAt(0, 123, False);
  MainForm.RaceMode.Checked := True;
  try
    key := VK_SPACE;
    MainForm.FormKeyDown(MainForm, key, []);

    AssertEquals('The handled Space key must not reach the cell editor', 0, key);
    AssertEquals(2, MainForm.DatasetFinishMarks.RecordCount);
    SelectFinishMarkAt(0);
    AssertEquals(123, MainForm.DatasetFinishMarks.FieldByName(
      'participant_number').AsInteger);
    SelectFinishMarkAt(1);
    AssertTrue(MainForm.DatasetFinishMarks.FieldByName(
      'participant_number').IsNull);
    MainForm.SQLQuery1.Close;
    MainForm.SQLQuery1.SQL.Text :=
      'SELECT source_kind, source_device_id, status FROM finish_marks ' +
      'WHERE source_kind = ''manual'';';
    MainForm.SQLQuery1.Open;
    AssertEquals(1, MainForm.SQLQuery1.RecordCount);
    AssertEquals('manual',
      MainForm.SQLQuery1.FieldByName('source_kind').AsString);
    AssertTrue(MainForm.SQLQuery1.FieldByName('source_device_id').IsNull);
    AssertEquals('pending',
      MainForm.SQLQuery1.FieldByName('status').AsString);
    MainForm.SQLQuery1.Close;
  finally
    MainForm.RaceMode.Checked := False;
    MainForm.ResultClearClick(MainForm);
  end;
end;

procedure TMainFlowIntegrationTests.
  FinishMarkPanel_NumberEditPersistsWithoutApplying;
begin
  CreateNewCompetitionFile;
  ApplyFinishPacketAt(EncodeTime(10, 20, 30, 123));

  SetFinishMarkNumberAt(0, 123);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT participant_number, assignment_mode, status ' +
    'FROM finish_marks;';
  MainForm.SQLQuery1.Open;
  AssertEquals(123,
    MainForm.SQLQuery1.FieldByName('participant_number').AsInteger);
  AssertTrue(MainForm.SQLQuery1.FieldByName('assignment_mode').IsNull);
  AssertEquals('pending', MainForm.SQLQuery1.FieldByName('status').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  FinishMarkPanel_ZeroNumberShowsDeferredDialog;
begin
  CreateNewCompetitionFile;
  ApplyFinishPacketAt(EncodeTime(10, 20, 30, 123));
  DialogCallCount := 0;

  SetFinishMarkNumberAt(0, 0, False);
  MainForm.AcApplyFinishMarksExecute(MainForm.AcApplyFinishMarks);

  AssertEquals('The dialog must not open inside the grid editing event',
    0, DialogCallCount);
  Application.ProcessMessages;
  AssertEquals('Invalid grid input must show one deferred dialog',
    1, DialogCallCount);
  AssertEquals(rsParticipantNumberMustBePositive,
    LastDialogMessage);
  AssertEquals(1, MainForm.DatasetFinishMarks.RecordCount);
  AssertTrue('The rejected participant number must be cleared from the grid',
    MainForm.DatasetFinishMarks.FieldByName('participant_number').IsNull);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT participant_number, status FROM finish_marks;';
  MainForm.SQLQuery1.Open;
  AssertTrue(MainForm.SQLQuery1.FieldByName('participant_number').IsNull);
  AssertEquals('pending', MainForm.SQLQuery1.FieldByName('status').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  FinishMarkPanel_CtrlEnterWritesAndEnterRemainsForEditing;
var
  Key: word;
  WasMainFormVisible: boolean;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(431);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''00:00:00.000'' WHERE number = 431;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  MainForm.SelectCurrentStage(1);
  MainForm.ResultClearClick(MainForm);
  ApplyFinishPacketAt(EncodeTime(0, 20, 0, 0));
  SetFinishMarkNumberAt(0, 431, False);
  MainForm.CheckDBOpen(MainForm.AcApplyFinishMarks);
  AssertEquals('The action must not expose a form-wide shortcut',
    0, MainForm.AcApplyFinishMarks.ShortCut);

  WasMainFormVisible := MainForm.Visible;
  if not WasMainFormVisible then
  begin
    MainForm.Show;
    Application.ProcessMessages;
  end;
  try
    MainForm.ButtonSetFinish.SetFocus;
    Key := VK_RETURN;
    MainForm.FormKeyDown(MainForm, Key, [ssCtrl]);
    AssertEquals('Ctrl+Enter outside the finish marks grid must remain ' +
      'unhandled', VK_RETURN, Key);
    AssertEquals(1, MainForm.DatasetFinishMarks.RecordCount);

    MainForm.RxDBGridFinishMarks.SetFocus;
    Application.ProcessMessages;
    AssertTrue('The finish marks grid must own the active control',
      MainForm.RxDBGridFinishMarks.ContainsControl(MainForm.ActiveControl));

    Key := VK_RETURN;
    MainForm.FormKeyDown(MainForm, Key, []);
    AssertEquals('Enter must remain available to the grid editor',
      VK_RETURN, Key);
    AssertEquals(1, MainForm.DatasetFinishMarks.RecordCount);

    Key := VK_RETURN;
    MainForm.FormKeyDown(MainForm, Key, [ssCtrl]);
    AssertEquals('Ctrl+Enter must not reach the grid editor', 0, Key);
    AssertEquals('Ctrl+Enter must apply the numbered finish mark',
      0, MainForm.DatasetFinishMarks.RecordCount);
    AssertTrue('The applied participant must remain available in the main grid',
      MainForm.MainDataset1.Locate('number', 431, []));
    AssertEquals('00:20:00.000',
      MainForm.MainDataset1.FieldByName('finishtime1').AsString);
  finally
    if not WasMainFormVisible then
      MainForm.Hide;
  end;
end;

procedure TMainFlowIntegrationTests.SqlQuerySortEngine_SortsMainGridDataset;
var
  sortEngine: TEntimeSQLQuerySortEngine;
begin
  CreateNewCompetitionFile;
  InsertParticipant(410);
  InsertParticipant(420);
  sortEngine := TEntimeSQLQuerySortEngine.Create;
  try
    sortEngine.Sort('number', MainForm.MainDataset1, False, []);
    MainForm.MainDataset1.First;
    AssertEquals(420,
      MainForm.MainDataset1.FieldByName('number').AsInteger);

    sortEngine.Sort('number', MainForm.MainDataset1, True, []);
    MainForm.MainDataset1.First;
    AssertEquals(410,
      MainForm.MainDataset1.FieldByName('number').AsInteger);
  finally
    sortEngine.Free;
  end;
end;

procedure TMainFlowIntegrationTests.
  CompetitionFileCreateError_ReportsPathAndLeavesDatabaseClosed;
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
    DialogCallCount := 0;

    OpenCompetitionFile(competitionFile);

    AssertEquals(1, DialogCallCount);
    AssertTrue('The file path must be present in the error',
      Pos(ExpandFileName(competitionFile), LastDialogMessage) > 0);
    AssertFalse('A failed create must leave the database closed',
      IsCompetitionDatabaseOpen);
  finally
    MainForm.FileCloseExecute(nil);
    if FileExists(blockingFile) then
      DeleteFile(blockingFile);
  end;
end;

procedure TMainFlowIntegrationTests.
  CompetitionFileOpenError_DoesNotPublishFailedFile;
var
  historyBefore, invalidContent: TStringList;
  invalidFileName, previousCaption: string;
  historyIndex: integer;
begin
  CreateNewCompetitionFile;
  MainForm.FileCloseExecute(nil);
  invalidFileName := ChangeFileExt(FDbFilePath, '.invalid.db');
  previousCaption := MainForm.Caption;

  historyBefore := TStringList.Create;
  invalidContent := TStringList.Create;
  try
    for historyIndex := 0 to MainForm.HistoryFiles1.Count - 1 do
      historyBefore.Add(MainForm.HistoryFiles1.GetItemValue(historyIndex));
    AssertTrue('The invalid file must not already be present in recent files',
      historyBefore.IndexOf(invalidFileName) < 0);

    invalidContent.Add('not a SQLite database');
    invalidContent.SaveToFile(invalidFileName);
    DialogCallCount := 0;

    OpenCompetitionFile(invalidFileName);

    AssertEquals(1, DialogCallCount);
    AssertFalse('A failed open must leave the database closed',
      IsCompetitionDatabaseOpen);
    AssertEquals('A failed file must not become the current competition',
      '', fName);
    AssertEquals('A failed file must not change the form caption',
      previousCaption, MainForm.Caption);
    AssertEquals('A failed file must not change recent-file count',
      historyBefore.Count, MainForm.HistoryFiles1.Count);
    for historyIndex := 0 to historyBefore.Count - 1 do
      AssertEquals('A failed file must not reorder recent files',
        historyBefore[historyIndex],
        MainForm.HistoryFiles1.GetItemValue(historyIndex));
  finally
    invalidContent.Free;
    historyBefore.Free;
    if FileExists(invalidFileName) then
      DeleteFile(invalidFileName);
  end;
end;

procedure TMainFlowIntegrationTests.LegacySchemaMigration_CreatesBackupAndPreservesData;
var
  BackupFile: string;
begin
  CreateSchemaFixture(8, '', '');
  DialogCallCount := 0;

  OpenCompetitionFile(FDbFilePath);

  AssertTrue('Migrated database datasets must be opened',
    IsCompetitionDatabaseOpen);
  AssertEquals(0, DialogCallCount);
  AssertEquals(8, TSchemaSql.LoadConfiguredStageCount(MainForm.SQLQuery1));
  AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION,
    TSchemaSql.LoadSchemaVersion(MainForm.SQLQuery1));
  AssertEquals('Legacy stage one',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename1', ''));
  AssertTrue(TConfigSql.GetBool(MainForm.SQLQuery1, 'stage1', False));
  AssertEquals('Legacy stage eight',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename8', ''));
  AssertTrue(TConfigSql.GetBool(MainForm.SQLQuery1, 'stage8', False));

  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name, starttime1, result1 FROM main WHERE number = 808;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Legacy participant must be preserved', MainForm.SQLQuery1.EOF);
  AssertEquals('Legacy participant',
    MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('10:00:00.000',
    MainForm.SQLQuery1.FieldByName('starttime1').AsString);
  AssertEquals('00:05:00.000',
    MainForm.SQLQuery1.FieldByName('result1').AsString);
  MainForm.SQLQuery1.Close;

  BackupFile := FindBackupFile;
  AssertTrue('Migration backup must be created in the backup directory',
    (BackupFile <> '') and FileExists(BackupFile));
  AssertEquals('Backup must contain the pre-migration schema', 'missing',
    LoadConfigValueFromFile(BackupFile, 'stagecount', 'missing'));
  AssertEquals('Backup must precede the schema version write', 'missing',
    LoadConfigValueFromFile(BackupFile, 'schema_version', 'missing'));

end;

procedure TMainFlowIntegrationTests.ConfiguredSchemaMigration_ExpandsCapacity;
begin
  CreateSchemaFixture(2, '4', '');

  OpenCompetitionFile(FDbFilePath);

  AssertTrue('Expanded database datasets must be opened',
    IsCompetitionDatabaseOpen);
  AssertEquals(4, TSchemaSql.DetectStageCapacity(MainForm.SQLQuery1));
  AssertEquals(4, TSchemaSql.LoadConfiguredStageCount(MainForm.SQLQuery1));
  AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION,
    TSchemaSql.LoadSchemaVersion(MainForm.SQLQuery1));
  AssertTrue('Expansion must create a backup first', FindBackupFile <> '');

  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name, result1 FROM main WHERE number = 808;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Existing data must survive schema expansion',
    MainForm.SQLQuery1.EOF);
  AssertEquals('Legacy participant',
    MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('00:05:00.000',
    MainForm.SQLQuery1.FieldByName('result1').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.MinimumStageCount_ResizesModelBeforeConfigLoad;
begin
  CreateSchemaFixture(MIN_STAGE_COUNT, IntToStr(MIN_STAGE_COUNT),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));

  OpenCompetitionFile(FDbFilePath);

  AssertTrue('Minimum-stage database datasets must be opened',
    IsCompetitionDatabaseOpen);
  AssertEquals(0, DialogCallCount);
  AssertEquals(MIN_STAGE_COUNT, StoredStageCount);
  AssertEquals(MIN_STAGE_COUNT, stages.Count);
  AssertEquals('Legacy stage one', stages[1].Name);
  AssertTrue(stages[1].isActive);
end;

procedure TMainFlowIntegrationTests.MaximumStageCount_ResizesModelBeforeConfigLoad;
var
  ExistingFirstStageColumn: TRxColumn;
begin
  ExistingFirstStageColumn :=
    MainForm.RxDBGrid1.ColumnByFieldName('correction1');
  AssertTrue('The existing first-stage column must be available before resize',
    ExistingFirstStageColumn <> nil);
  CreateSchemaFixture(MAX_SUPPORTED_STAGE_COUNT,
    IntToStr(MAX_SUPPORTED_STAGE_COUNT),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));

  OpenCompetitionFile(FDbFilePath);

  AssertTrue('Maximum-stage database datasets must be opened',
    IsCompetitionDatabaseOpen);
  AssertSame('Growing the stage grid must reuse its existing columns',
    ExistingFirstStageColumn,
    MainForm.RxDBGrid1.ColumnByFieldName('correction1'));
  AssertEquals(0, DialogCallCount);
  AssertEquals(MAX_SUPPORTED_STAGE_COUNT, StoredStageCount);
  AssertEquals(MAX_SUPPORTED_STAGE_COUNT, stages.Count);
  AssertEquals('Legacy stage ' + IntToStr(MAX_SUPPORTED_STAGE_COUNT),
    stages[MAX_SUPPORTED_STAGE_COUNT].Name);
  AssertTrue(stages[MAX_SUPPORTED_STAGE_COUNT].isActive);
  AssertTrue('Maximum-stage start field must be created before opening',
    MainForm.MainDataset1.FieldByName('starttime32') is TStringField);
  AssertTrue('Maximum-stage correction field must preserve its integer type',
    MainForm.MainDataset1.FieldByName('correction32') is TLongintField);
  AssertTrue('Maximum-stage status field must be created',
    MainForm.MainDataset1.FieldByName('status32') is TStringField);
  AssertTrue('Dynamic editable fields must preserve the change handler',
    Assigned(MainForm.MainDataset1.FieldByName('starttime32').OnChange));
  AssertTrue('Editable SQL must include dynamically created stage fields',
    Pos('"starttime32"', MainForm.MainDataset1.InsertSQL.Text) > 0);
  AssertTrue('The initially selected stage must create its result view',
    MainForm.StageResultView(1).ContentCreated);
  AssertFalse('An unvisited active stage must remain lightweight',
    MainForm.StageResultView(8).ContentCreated);
  AssertFalse('The maximum unvisited stage must remain lightweight',
    MainForm.StageResultView(MAX_SUPPORTED_STAGE_COUNT).ContentCreated);
  RefreshCompetitionViews;
  AssertFalse('Refresh must not create an unvisited active stage view',
    MainForm.StageResultView(8).ContentCreated);
  AssertFalse('Refresh must not open every configured stage query',
    MainForm.StageResultView(MAX_SUPPORTED_STAGE_COUNT).ContentCreated);

  MainForm.ActivateStageResult(MAX_SUPPORTED_STAGE_COUNT);
  AssertTrue('Selecting a stage must create its result view on demand',
    MainForm.StageResultView(MAX_SUPPORTED_STAGE_COUNT).ContentCreated);
  AssertTrue('The lazily created result query must be opened',
    MainForm.StageResultView(MAX_SUPPORTED_STAGE_COUNT).Query.Active);
  AssertFalse('Selecting another stage must not create unrelated views',
    MainForm.StageResultView(8).ContentCreated);
end;

procedure TMainFlowIntegrationTests.DynamicStageUi_RebuildForSupportedStageCounts;
const
  StageCounts: array[0..3] of integer = (
    MIN_STAGE_COUNT, 8, 12, MAX_SUPPORTED_STAGE_COUNT
  );
var
  StageCount: integer;
begin
  for StageCount in StageCounts do
  begin
    MainForm.FileCloseExecute(nil);
    if FileExists(FDbFilePath) then
      DeleteFile(FDbFilePath);
    DeleteBackupFiles;
    CreateSchemaFixture(StageCount, IntToStr(StageCount),
      IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));

    OpenCompetitionFile(FDbFilePath);
    AssertTrue(Format('Database with %d stages must open', [StageCount]),
      IsCompetitionDatabaseOpen);
    AssertEquals(StageCount, stages.Count);
    AssertDynamicStageFields(StageCount);
    AssertDynamicStageColumns(StageCount);
    AssertDynamicStageResultUi(StageCount);
    AssertCurrentStageSelector(StageCount);
    AssertDynamicStageSettings(StageCount);

    MainForm.FileCloseExecute(nil);
    OpenCompetitionFile(FDbFilePath);
    AssertTrue(Format('Database with %d stages must reopen', [StageCount]),
      IsCompetitionDatabaseOpen);
    AssertEquals(StageCount, stages.Count);
    AssertDynamicStageFields(StageCount);
    AssertDynamicStageColumns(StageCount);
    AssertDynamicStageResultUi(StageCount);
    AssertCurrentStageSelector(StageCount);
  end;
end;

procedure TMainFlowIntegrationTests.StageSelection_UsesFullFieldSuffix;
var
  PenaltyColumn: TRxColumn;
begin
  CreateSchemaFixture(12, '12',
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  AssertTrue('Twelve-stage database must open', IsCompetitionDatabaseOpen);

  PenaltyColumn := MainForm.RxDBGrid1.ColumnByFieldName('penalty12');
  AssertTrue('Stage 12 penalty column must exist', PenaltyColumn <> nil);
  PenaltyColumn.Index :=
    MainForm.RxDBGrid1.ColumnByFieldName('correction1').Index;
  MainForm.RxDBGrid1.SelectedIndex := PenaltyColumn.Index;
  AssertTrue('Selected stage must come from FieldName, not column position',
    TryGetStageIndexFromFieldName(
      MainForm.RxDBGrid1.SelectedColumn.FieldName, StageSelectionResult));
  AssertEquals(12, StageSelectionResult);

  AssertTrue(MainForm.MainDataset1.Locate('number', 808, []));
  MainForm.RxDBGrid1.SelectedIndex :=
    MainForm.RxDBGrid1.ColumnByFieldName('starttime1').Index;
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('penalty12').AsString :=
    '00:00:10.000';
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  AssertEquals('The complete stage suffix must address stage 12',
    '00:00:10.000',
    MainForm.MainDataset1.FieldByName('penalty12').AsString);
end;

procedure TMainFlowIntegrationTests.StageIndexes_RejectInvalidSelectionsAndNormalizeStoredValues;
begin
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  SetStageSelectionHandler(@IntegrationStageSelectionHandler);

  WriteCsv(['# number;finish time', '1;10:00:00']);
  StageSelectionResult := 2;
  ImportStageResultsFile(FCsvFilePath);
  StageSelectionResult := 1;
  ImportStageResultsFile(FCsvFilePath);
  StageSelectionResult := stages.Count + 1;
  ImportStageResultsFile(FCsvFilePath);
  AssertEquals('All stage choices must pass through the dialog seam',
    3, StageSelectionCallCount);

  astage := IntToStr(stages.Count + 1);
  RefreshResultViewConfiguration;
  AssertEquals('Stored results stage must fall back to the active stage',
    '2', astage);
  AssertTrue(Pos('result2', ResultsForm.ResultDataset.SQL.Text) > 0);

  exportStageIndex := stages.Count + 1;
  MainForm.FileExportStageResultsSaveAsBeforeExecute(
    MainForm.FileExportStageResultsSaveAs);
  AssertEquals('Stored export stage must fall back to the active stage',
    2, exportStageIndex);
end;

procedure TMainFlowIntegrationTests.DynamicStageFields_EditRecalculateAndReopen;
const
  PARTICIPANT_NUMBER = 808;
  STAGE_INDEX = 12;

  procedure EditStageField(const AFieldName, AValue: string);
  begin
    DialogCallCount := 0;
    MainForm.MainDataset1.Edit;
    MainForm.MainDataset1.FieldByName(AFieldName).AsString := AValue;
    MainForm.MainDataset1.Post;
    MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
    Application.ProcessMessages;

    AssertTrue('The editable dataset must remain active',
      MainForm.MainDataset1.Active);
    AssertEquals('The edited participant must remain current',
      PARTICIPANT_NUMBER,
      MainForm.MainDataset1.FieldByName('number').AsInteger);
    AssertEquals('A valid stage edit must not show an error dialog',
      0, DialogCallCount);
  end;

begin
  CreateSchemaFixture(STAGE_INDEX, IntToStr(STAGE_INDEX),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  AssertTrue('Twelve-stage database must open', IsCompetitionDatabaseOpen);
  AssertTrue(MainForm.MainDataset1.Locate('number', PARTICIPANT_NUMBER, []));
  MainForm.CheckBoxAutomaticUpdateResutls.Checked := True;

  EditStageField('starttime12', '10:00:00.000');
  EditStageField('correction12', '250');
  EditStageField('finishtime12', '10:05:00.000');
  AssertEquals('Stage 12 result must include the correction',
    '00:05:00.250',
    MainForm.MainDataset1.FieldByName('result12').AsString);

  EditStageField('penalty12', '00:00:10.000');
  AssertEquals('Stage 12 result must include correction and penalty',
    '00:05:10.250',
    MainForm.MainDataset1.FieldByName('result12').AsString);
  AssertEquals('The only stage 12 finisher must receive first place', 1,
    MainForm.MainDataset1.FieldByName('place12').AsInteger);

  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('penalty12').AsString :=
    MainForm.MainDataset1.FieldByName('penalty12').AsString;
  MainForm.StageFieldChanged(
    MainForm.MainDataset1.FieldByName('penalty12'));
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;
  AssertEquals('An unchanged edit must be cancelled',
    Ord(dsBrowse), Ord(MainForm.MainDataset1.State));

  AssertFalse('Inactive stage 11 columns must remain hidden',
    MainForm.RxDBGrid1.ColumnByFieldName('penalty11').Visible);
  AssertTrue('Inactive stage 11 fields must stay detached from the sparse query',
    MainForm.MainDataset1.FindField('penalty11') = nil);

  MainForm.FileCloseExecute(nil);
  OpenCompetitionFile(FDbFilePath);
  AssertTrue('Twelve-stage database must reopen', IsCompetitionDatabaseOpen);
  AssertTrue(MainForm.MainDataset1.Locate('number', PARTICIPANT_NUMBER, []));
  AssertEquals('10:00:00.000',
    MainForm.MainDataset1.FieldByName('starttime12').AsString);
  AssertEquals(250,
    MainForm.MainDataset1.FieldByName('correction12').AsInteger);
  AssertEquals('10:05:00.000',
    MainForm.MainDataset1.FieldByName('finishtime12').AsString);
  AssertEquals('00:00:10.000',
    MainForm.MainDataset1.FieldByName('penalty12').AsString);
  AssertEquals('00:05:10.250',
    MainForm.MainDataset1.FieldByName('result12').AsString);
end;

procedure TMainFlowIntegrationTests.NewerSchema_IsRejectedWithoutOpeningDatasets;
var
  UnsupportedVersion: integer;
begin
  UnsupportedVersion := CURRENT_COMPETITION_SCHEMA_VERSION + 1;
  CreateSchemaFixture(8, '8', IntToStr(UnsupportedVersion));
  DialogCallCount := 0;

  OpenCompetitionFile(FDbFilePath);

  AssertFalse('Main dataset must remain closed for an incompatible schema',
    MainForm.MainDataset1.Active);
  AssertFalse('Result datasets must remain closed for an incompatible schema',
    MainForm.StageResultView(1).Query.Active);
  AssertEquals(1, DialogCallCount);
  AssertTrue('The unsupported version must be reported',
    Pos(Format(rsSchemaVersionTooNew,
      [UnsupportedVersion, CURRENT_COMPETITION_SCHEMA_VERSION]),
      LastDialogMessage) > 0);
  AssertEquals('An incompatible schema must not be backed up or changed', '',
    FindBackupFile);
  AssertEquals(IntToStr(UnsupportedVersion),
    LoadConfigValueFromFile(FDbFilePath, 'schema_version', 'missing'));
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

procedure TMainFlowIntegrationTests.LoggingIniSettings_AreAppliedToFile;
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
    AppLog('ini-info', allInfo, alvNone);
    AppLog('ini-debug', allDebug, alvNone);
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
    AssertTrue(Pos('ini-info', content) > 0);
    AssertTrue(Pos('ini-debug', content) = 0);
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

procedure TMainFlowIntegrationTests.RefreshAll_RefreshesLegacyDatasetsAndSqlQueries;
begin
  CreateNewCompetitionFile;
  InsertParticipant(401);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET name = ''Updated participant'' WHERE number = 401;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  RefreshCompetitionViews;

  AssertTrue('MainDataset1 must use the shared SQLDB connection',
    MainForm.MainDataset1.Database = MainForm.SQLite3Connection1);
  AssertTrue('CorrectionDataset must use the shared SQLDB connection',
    MainForm.CorrectionDataset.Database = MainForm.SQLite3Connection1);
  AssertTrue('ResultDatasetStageSum query must be reopened after refresh',
    MainForm.ResultDatasetStageSum.Active);
  AssertTrue(MainForm.MainDataset1.Locate('number', 401, []));
  AssertEquals('Updated participant',
    MainForm.MainDataset1.FieldByName('name').AsString);
end;

procedure TMainFlowIntegrationTests.CategoryEdit_RefreshesOnlyAffectedQueriesAfterCommit;
begin
  CreateNewCompetitionFile;
  InsertParticipant(402);
  AssertTrue(MainForm.MainDataset1.Locate('number', 402, []));
  AssertTrue(MainForm.StatDataset1.Active);
  AssertTrue(MainForm.CorrectionDataset.Active);

  FMainDatasetOpenCount := 0;
  FStatDatasetOpenCount := 0;
  FCorrectionDatasetOpenCount := 0;
  MainForm.MainDataset1.AfterOpen := @CountMainDatasetOpen;
  MainForm.StatDataset1.AfterOpen := @CountStatDatasetOpen;
  MainForm.CorrectionDataset.AfterOpen := @CountCorrectionDatasetOpen;
  try
    MainForm.ComboBox1Category.Text := 'Changed category';
    MainForm.ComboBox1CategoryEditingDone(MainForm.ComboBox1Category);

    AssertEquals('The editable query must stay open across commit',
      0, FMainDatasetOpenCount);
    AssertEquals('Category statistics must be refreshed once',
      1, FStatDatasetOpenCount);
    AssertEquals('An unrelated correction query must not be refreshed',
      0, FCorrectionDatasetOpenCount);
    AssertTrue(MainForm.MainDataset1.Active);
    AssertTrue(MainForm.StatDataset1.Active);
    AssertTrue(MainForm.CorrectionDataset.Active);
    AssertEquals('Changed category',
      MainForm.MainDataset1.FieldByName('category').AsString);
  finally
    MainForm.MainDataset1.AfterOpen := nil;
    MainForm.StatDataset1.AfterOpen := nil;
    MainForm.CorrectionDataset.AfterOpen := nil;
  end;
end;

procedure TMainFlowIntegrationTests.CreateNewCompetitionFile_ViaMainFormHandler_CreatesDbAndOpensDatasets;
var
  expectedRaceName: string;
begin
  CreateNewCompetitionFile;

  AssertTableExists('main');
  AssertTableExists('config');
  AssertTableExists('start_marks');
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS cnt FROM start_marks;';
  MainForm.SQLQuery1.Open;
  AssertEquals('A new start mark journal must be empty', 0,
    MainForm.SQLQuery1.FieldByName('cnt').AsInteger);
  MainForm.SQLQuery1.Close;

  expectedRaceName := ChangeFileExt(ExtractFileName(FDbFilePath), '');
  AssertEquals('Unexpected default race name in config', expectedRaceName,
    TConfigSql.GetString(MainForm.SQLQuery1, 'racename', ''));
  AssertEquals(DEFAULT_STAGE_COUNT, StoredStageCount);
  AssertEquals(DEFAULT_STAGE_COUNT, stages.Count);
end;

procedure TMainFlowIntegrationTests.NewCompetitionSchema_IsVersionedAndReopensWithoutMigration;
begin
  CreateNewCompetitionFile;

  AssertEquals(DEFAULT_STAGE_COUNT,
    TSchemaSql.DetectStageCapacity(MainForm.SQLQuery1));
  AssertEquals(DEFAULT_STAGE_COUNT,
    TSchemaSql.LoadConfiguredStageCount(MainForm.SQLQuery1));
  AssertEquals(CURRENT_COMPETITION_SCHEMA_VERSION,
    TSchemaSql.LoadSchemaVersion(MainForm.SQLQuery1));
  AssertEquals('1',
    TConfigSql.GetString(MainForm.SQLQuery1, 'activestage', ''));
  AssertTrue(TConfigSql.GetBool(MainForm.SQLQuery1, 'stage1', False));
  AssertTrue('A new database must contain the first stage columns',
    MainForm.MainDataset1.FindField('starttime1') <> nil);
  AssertTrue('A new database must not preallocate the second stage columns',
    MainForm.MainDataset1.FindField('starttime2') = nil);

  MainForm.FileCloseExecute(nil);
  DialogCallCount := 0;

  OpenCompetitionFile(FDbFilePath);

  AssertTrue('A current schema must reopen normally',
    IsCompetitionDatabaseOpen);
  AssertEquals(0, DialogCallCount);
  AssertEquals('A current schema must not create a migration backup', '',
    FindBackupFile);
end;

procedure TMainFlowIntegrationTests.CompetitionConfigModel_LoadDoesNotApplyUiUntilExplicitPhase;
const
  UPDATED_STAGE_NAME = 'Loaded stage model';
  UI_SENTINEL = 'UI must stay unchanged';
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  CreateEmptyCompetitionFixture(2);
  MainForm.StageResultView(2).Sheet.Caption := UI_SENTINEL;
  MainForm.RxDBGrid1.ColumnByFieldName(
    'starttime2').Title.Caption := UI_SENTINEL;
  MainForm.StageResultView(2).Sheet.TabVisible := False;

  UnitOfWork := MainForm.CompetitionDb.BeginUnitOfWork;
  try
    TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage2', 'True');
    TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stagename2',
      UPDATED_STAGE_NAME);
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;

  with TCompetitionLifecycleService.LoadConfiguration(
    MainForm.CompetitionDb, stages.Count, VISIBLECAT) do
  begin
    stages[2].Name := StageNames[1];
    stages[2].isActive := StageActive[1];
  end;

  AssertEquals(UPDATED_STAGE_NAME, stages[2].Name);
  AssertTrue(stages[2].isActive);
  AssertEquals(UI_SENTINEL, MainForm.StageResultView(2).Sheet.Caption);
  AssertEquals(UI_SENTINEL,
    MainForm.RxDBGrid1.ColumnByFieldName(
      'starttime2').Title.Caption);
  AssertFalse(MainForm.StageResultView(2).Sheet.TabVisible);

  ApplyStagePresentationToUi;

  AssertEquals(UPDATED_STAGE_NAME,
    MainForm.StageResultView(2).Sheet.Caption);
  AssertEquals(UPDATED_STAGE_NAME + '|' + rsStarttime,
    MainForm.RxDBGrid1.ColumnByFieldName(
      'starttime2').Title.Caption);
  AssertTrue(MainForm.StageResultView(2).Sheet.TabVisible);
end;

procedure TMainFlowIntegrationTests.ActiveStageChange_ReconfiguresCurrentTrackQuery;
begin
  CreateEmptyCompetitionFixture(2);
  InsertParticipant(801);
  InsertParticipant(802);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''00:00:01.000'' WHERE number = 801;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime2 = ''00:00:01.000'' WHERE number = 802;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;

  MainForm.SelectCurrentStage(1);
  AssertTrue('Stage 1 participant must initially be shown on track',
    MainForm.StatDataset2.Locate('number', 801, []));
  AssertFalse('Stage 2 participant must not be shown by the stage 1 query',
    MainForm.StatDataset2.Locate('number', 802, []));

  stages[2].isActive := True;
  ApplyStagePresentationToUi;
  MainForm.SelectCurrentStage(2);
  AssertEquals('Clicking the stage selector must change the current stage',
    2, MainForm.CurrentStageIndex);
  AssertTrue('A manual stage switch must refresh the current-track query',
    MainForm.StatDataset2.Locate('number', 802, []));

  MainForm.SelectCurrentStage(1);
  stages[1].isActive := False;
  ApplyStagePresentationToUi;

  AssertEquals('The only active stage must become current',
    2, MainForm.CurrentStageIndex);
  AssertEquals(Trim(TDatasetSql.TrackStatus(2, stages.Count)),
    Trim(MainForm.StatDataset2.SQL.Text));
  AssertTrue('The current-track query must remain active after switching',
    MainForm.StatDataset2.Active);
  AssertTrue('Stage 2 participant must be shown after switching stages',
    MainForm.StatDataset2.Locate('number', 802, []));
  AssertFalse('Stage 1 participant must disappear after switching stages',
    MainForm.StatDataset2.Locate('number', 801, []));
end;

procedure TMainFlowIntegrationTests.CurrentStageSelector_MapsSparseStagesAndPreservesSelection;
var
  i: integer;
begin
  CreateSchemaFixture(12, '12',
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  AssertTrue('Twelve-stage database must open', IsCompetitionDatabaseOpen);

  for i := 1 to stages.Count do
    stages[i].isActive := (i = 2) or (i = 12);
  stages[2].Name := 'Second stage';
  stages[12].Name := 'Twelfth stage';

  MainForm.RebuildCurrentStageSelector(12);

  AssertEquals('Only active stages must be listed', 2,
    MainForm.CurrentStageComboBox.Items.Count);
  AssertEquals('2 — Second stage', MainForm.CurrentStageComboBox.Items[0]);
  AssertEquals('12 — Twelfth stage', MainForm.CurrentStageComboBox.Items[1]);
  AssertEquals('Combo position must map to the real stage index', 12,
    MainForm.CurrentStageIndex);
  AssertTrue('The combo box height must be calculated by the widget set',
    MainForm.CurrentStageComboBox.AutoSize);
  AssertTrue('The group height must follow its native preferred size',
    MainForm.CurrentStageGroup.AutoSize);
  AssertEquals('The selector group must not have a fixed minimum height', 0,
    MainForm.CurrentStageGroup.Constraints.MinHeight);
  AssertEquals('The selector group must not have a fixed maximum height', 0,
    MainForm.CurrentStageGroup.Constraints.MaxHeight);
  AssertTrue('The selector must be visible for multiple active stages',
    MainForm.CurrentStageGroup.Visible);

  stages[12].Name := 'Renamed stage';
  MainForm.RebuildCurrentStageSelector;
  AssertEquals('Rebuild must preserve the selected stage', 12,
    MainForm.CurrentStageIndex);
  AssertEquals('12 — Renamed stage', MainForm.CurrentStageComboBox.Items[1]);

  stages[12].isActive := False;
  MainForm.RebuildCurrentStageSelector;
  AssertEquals('The first active stage must be selected as fallback', 2,
    MainForm.CurrentStageIndex);
  AssertEquals('A single active stage must be the only item', 1,
    MainForm.CurrentStageComboBox.Items.Count);
  AssertFalse('The selector must be hidden for a single active stage',
    MainForm.CurrentStageGroup.Visible);
  AssertTrue('The legacy current-stage radio group must not exist',
    MainForm.FindComponent('CurrentSU') = nil);
end;

procedure TMainFlowIntegrationTests.CurrentStageOperations_UseSparseStageAboveEight;
const
  OTHER_STAGE_INDEX = 2;
  CURRENT_STAGE_INDEX = 12;
  FINISH_PARTICIPANT = 812;
  DNS_PARTICIPANT = 813;
  DNF_PARTICIPANT = 814;
  OTHER_STAGE_PARTICIPANT = 802;
var
  StageIndex: integer;
begin
  CreateSchemaFixture(CURRENT_STAGE_INDEX, IntToStr(CURRENT_STAGE_INDEX),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  AssertTrue('Twelve-stage database must open', IsCompetitionDatabaseOpen);

  for StageIndex := 1 to stages.Count do
    stages[StageIndex].isActive :=
      StageIndex in [OTHER_STAGE_INDEX, CURRENT_STAGE_INDEX];
  ApplyStageActivityToUi(CURRENT_STAGE_INDEX);

  InsertParticipant(OTHER_STAGE_PARTICIPANT);
  InsertParticipant(FINISH_PARTICIPANT);
  InsertParticipant(DNS_PARTICIPANT);
  InsertParticipant(DNF_PARTICIPANT);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime2 = ''00:00:00.000'' WHERE number = 802;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime12 = ''00:00:00.000'' WHERE number = 812;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime12 = ''00:00:00.000'' WHERE number = 813;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime12 = ''00:00:00.000'' WHERE number = 814;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;
  RefreshCompetitionViews;
  MainForm.SelectCurrentStage(CURRENT_STAGE_INDEX);

  AssertTrue('Stage 12 participant must be shown on track',
    MainForm.StatDataset2.Locate('number', FINISH_PARTICIPANT, []));
  AssertFalse('Stage 2 participant must not leak into the stage 12 query',
    MainForm.StatDataset2.Locate('number', OTHER_STAGE_PARTICIPANT, []));

  AssertTrue(MainForm.CorrectionDataset.Locate(
    'number', FINISH_PARTICIPANT, []));
  MainForm.CorrectionDataset.Edit;
  MainForm.CorrectionDataset.FieldByName('correction').AsInteger := 250;
  MainForm.CorrectionDataset.Post;
  MainForm.RxDBGridCorrectionEditingDone(MainForm.RxDBGridCorrection);

  AssertTrue(MainForm.MainDataset1.Locate('number', FINISH_PARTICIPANT, []));
  AssertEquals(250, MainForm.MainDataset1.FieldByName(
    'correction12').AsInteger);
  AssertTrue('Editing stage 12 must not change stage 2 correction',
    MainForm.MainDataset1.FieldByName('correction2').IsNull);

  MainForm.ResultClearClick(MainForm);
  ApplyFinishPacketAt(EncodeTime(0, 5, 0, 0));
  SetFinishMarkNumberAt(0, FINISH_PARTICIPANT);
  DialogCallCount := 0;
  MainForm.AcApplyFinishMarksExecute(MainForm.AcApplyFinishMarks);

  AssertEquals('An on-track stage 12 finish must not need confirmation',
    0, DialogCallCount);
  AssertTrue(MainForm.MainDataset1.Locate('number', FINISH_PARTICIPANT, []));
  AssertEquals('00:05:00.000', MainForm.MainDataset1.FieldByName(
    'finishtime12').AsString);
  AssertEquals('00:05:00.250', MainForm.MainDataset1.FieldByName(
    'result12').AsString);
  AssertTrue('Setting stage 12 finish must not change stage 2',
    MainForm.MainDataset1.FieldByName('finishtime2').IsNull);

  AssertTrue(MainForm.CorrectionDataset.Locate(
    'number', DNS_PARTICIPANT, []));
  MainForm.AcSetDNSCorExecute(MainForm.AcSetDNSCor);
  AssertTrue(MainForm.MainDataset1.Locate('number', DNS_PARTICIPANT, []));
  AssertEquals(ParticipantStatusToDbValue(psDNS),
    MainForm.MainDataset1.FieldByName('status12').AsString);
  AssertTrue('Stage 12 DNS must not change stage 2 status',
    MainForm.MainDataset1.FieldByName('status2').IsNull);

  AssertTrue(MainForm.StatDataset2.Locate('number', DNF_PARTICIPANT, []));
  MainForm.AcSetDNFOnTraceExecute(MainForm.AcSetDNFOnTrace);
  AssertTrue(MainForm.MainDataset1.Locate('number', DNF_PARTICIPANT, []));
  AssertEquals(ParticipantStatusToDbValue(psDNF),
    MainForm.MainDataset1.FieldByName('status12').AsString);
  AssertTrue('Stage 12 DNF must not change stage 2 status',
    MainForm.MainDataset1.FieldByName('status2').IsNull);

  MainForm.ResultClearClick(MainForm);
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
  ImportParticipantsFile(FCsvFilePath);

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

procedure TMainFlowIntegrationTests.LoadParticipantsList_CategoryDeclinedStillAppliesDetectedStages;
begin
  CreateEmptyCompetitionFixture(3);
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage1', 'False');
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage2', 'False');
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage3', 'True');
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stagename3',
    'Previous stage');
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'activestage', '3');
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name, result3) VALUES ' +
    '(900, ''Existing participant'', ''00:10:00.000'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  OpenCompetitionFile(FDbFilePath);
  RefreshCompetitionViews;
  AssertEquals(3, MainForm.CurrentStageIndex);
  AssertEquals('3', astage);

  WriteCsv([
    'number;name;category;Start A;Start B',
    '42;Alice Rider;Elite;09:15:00;10:15:00'
  ]);
  DialogCallCount := 0;
  ConfirmationDialogResult := mrNo;

  ImportParticipantsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertEquals(1, DialogCallCount);
  AssertEquals(2, stages.ActiveStagesCount);
  AssertEquals('Start A', stages[1].Name);
  AssertEquals('Start B', stages[2].Name);
  AssertTrue(stages[1].isActive);
  AssertTrue(stages[2].isActive);
  AssertFalse('A stage absent from CSV must become inactive',
    stages[3].isActive);
  AssertEquals('The current stage must fall back after deactivation',
    1, MainForm.CurrentStageIndex);
  AssertEquals('The results stage must fall back after deactivation',
    '1', astage);
  AssertEquals('The normalized results stage must be persisted', 1,
    TConfigSql.GetInteger(MainForm.SQLQuery1, 'activestage', 0));
  AssertTrue('The first detected stage column must remain visible',
    MainForm.RxDBGrid1.ColumnByFieldName('starttime1').Visible);
  AssertTrue('The second detected stage column must become visible',
    MainForm.RxDBGrid1.ColumnByFieldName('starttime2').Visible);
  AssertEquals('Start B|' + rsStarttime,
    MainForm.RxDBGrid1.ColumnByFieldName('starttime2').Title.Caption);
  AssertTrue('The second detected stage must be persisted as active',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage2', False));
  AssertEquals('Start B',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename2', ''));
  AssertFalse('The absent stage must be persisted as inactive',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage3', True));
  AssertEquals('Disabling a stage must preserve its stored name',
    'Previous stage',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename3', ''));
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT result3 FROM main WHERE number = 900;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Disabling a stage must preserve its results',
    '00:10:00.000', MainForm.SQLQuery1.FieldByName('result3').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_WithoutStageColumnsPreservesActiveStages;
begin
  CreateEmptyCompetitionFixture(2);
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage1', 'False');
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage2', 'True');
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stagename2',
    'Existing stage');
  MainForm.SQLQuery1.SQLTransaction.Commit;
  OpenCompetitionFile(FDbFilePath);
  WriteCsv([
    'number;name;category',
    '42;Alice Rider;Elite'
  ]);
  ConfirmationDialogResult := mrNo;
  ImportParticipantsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertMainRowCount(1);
  AssertEquals(1, stages.ActiveStagesCount);
  AssertFalse(stages[1].isActive);
  AssertTrue(stages[2].isActive);
  AssertEquals('Existing stage', stages[2].Name);
  AssertFalse(TConfigSql.GetBool(MainForm.SQLQuery1, 'stage1', True));
  AssertTrue(TConfigSql.GetBool(MainForm.SQLQuery1, 'stage2', False));
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_EqualStageCountUpdatesNamesAndActivity;
var
  i: integer;
begin
  CreateEmptyCompetitionFixture(8);
  DeleteBackupFiles;
  WriteCsv([
    'number;name;Equal 1;Equal 2;Equal 3;Equal 4;Equal 5;Equal 6;Equal 7;Equal 8',
    '42;Alice;10:01:00;10:02:00;10:03:00;10:04:00;10:05:00;10:06:00;10:07:00;10:08:00'
  ]);
  ConfirmationDialogResult := mrNo;

  ImportParticipantsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertMainRowCount(1);
  AssertEquals(8, stages.Count);
  AssertEquals(8, StoredStageCount);
  AssertEquals(8, stages.ActiveStagesCount);
  AssertEquals(8,
    TSchemaSql.DetectStageCapacity(MainForm.SQLQuery1));
  AssertEquals('Equal-size import must not create a backup', '',
    FindBackupFile);
  for i := 1 to 8 do
  begin
    AssertTrue('Imported stage must be active: ' + IntToStr(i),
      stages[i].isActive);
    AssertEquals('Equal ' + IntToStr(i), stages[i].Name);
    AssertTrue(TConfigSql.GetBool(MainForm.SQLQuery1,
      'stage' + IntToStr(i), False));
    AssertEquals('Equal ' + IntToStr(i),
      TConfigSql.GetString(MainForm.SQLQuery1,
      'stagename' + IntToStr(i), ''));
  end;
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_ReimportReplacesStagesAndRestoresHiddenResult;
begin
  CreateEmptyCompetitionFixture(5);
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name, result3) VALUES ' +
    '(900, ''Existing participant'', ''00:10:00.000'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  ConfirmationDialogResult := mrNo;

  WriteCsv([
    'number;name;Initial 1;Initial 2;Initial 3;Initial 4;Initial 5',
    '42;Alice;10:01:00;10:02:00;10:03:00;10:04:00;10:05:00'
  ]);
  ImportParticipantsFile(FCsvFilePath);
  Application.ProcessMessages;
  AssertEquals(5, stages.ActiveStagesCount);
  AssertTrue(stages[5].isActive);

  WriteCsv([
    'number;name;Reduced 1;Reduced 2',
    '42;Alice;11:01:00;11:02:00'
  ]);
  ImportParticipantsFile(FCsvFilePath);
  Application.ProcessMessages;
  AssertEquals('A repeated import must replace, not merge, the active set',
    2, stages.ActiveStagesCount);
  AssertTrue(stages[1].isActive);
  AssertTrue(stages[2].isActive);
  AssertFalse(stages[3].isActive);
  AssertFalse(stages[4].isActive);
  AssertFalse(stages[5].isActive);
  AssertEquals('A disabled stage must retain its previous name',
    'Initial 3', stages[3].Name);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT result3 FROM main WHERE number = 900;';
  MainForm.SQLQuery1.Open;
  AssertEquals('A disabled stage must retain its result',
    '00:10:00.000', MainForm.SQLQuery1.FieldByName('result3').AsString);
  MainForm.SQLQuery1.Close;

  WriteCsv([
    'number;name;Restored 1;Restored 2;Restored 3',
    '42;Alice;12:01:00;12:02:00;12:03:00'
  ]);
  ImportParticipantsFile(FCsvFilePath);
  Application.ProcessMessages;
  AssertEquals(3, stages.ActiveStagesCount);
  AssertTrue('The third stage must become active again', stages[3].isActive);
  AssertEquals('Restored 3', stages[3].Name);
  AssertTrue('The restored stage result column must be visible',
    MainForm.RxDBGrid1.ColumnByFieldName('result3').Visible);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT result3 FROM main WHERE number = 900;';
  MainForm.SQLQuery1.Open;
  AssertEquals('The result must be available after re-enabling the stage',
    '00:10:00.000', MainForm.SQLQuery1.FieldByName('result3').AsString);
  MainForm.SQLQuery1.Close;

  OpenCompetitionFile(FDbFilePath);
  Application.ProcessMessages;
  AssertEquals(5, stages.Count);
  AssertEquals(3, stages.ActiveStagesCount);
  AssertTrue(stages[3].isActive);
  AssertFalse(stages[4].isActive);
  AssertEquals('Restored 3', stages[3].Name);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT result3 FROM main WHERE number = 900;';
  MainForm.SQLQuery1.Open;
  AssertEquals('The restored result must survive reopening the competition',
    '00:10:00.000', MainForm.SQLQuery1.FieldByName('result3').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_MoreStages_ExpandsCompetition;
begin
  CreateNewCompetitionFile;
  DeleteBackupFiles;
  WriteCsv([
    'number;name;S1;S2;S3;S4;S5;S6;S7;S8;S9',
    '42;Alice;10:00:00;10:01:00;10:02:00;10:03:00;10:04:00;10:05:00;10:06:00;10:07:00;10:08:00'
  ]);
  ImportParticipantsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertMainRowCount(1);
  AssertEquals('The competition must expand to all detected stages', 9,
    stages.Count);
  AssertEquals(9, StoredStageCount);
  AssertEquals(9, stages.ActiveStagesCount);
  AssertEquals(9, TSchemaSql.DetectStageCapacity(MainForm.SQLQuery1));
  AssertTrue(stages[9].isActive);
  AssertEquals('S9', stages[9].Name);
  AssertEquals(9,
    TConfigSql.GetInteger(MainForm.SQLQuery1, 'stagecount', 0));
  AssertTrue(TConfigSql.GetBool(MainForm.SQLQuery1, 'stage9', False));
  AssertEquals('S9',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename9', ''));
  AssertTrue('Physical schema expansion must create a backup first',
    FindBackupFile <> '');
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT starttime9 FROM main WHERE number = 42;';
  MainForm.SQLQuery1.Open;
  AssertEquals('10:08:00',
    MainForm.SQLQuery1.FieldByName('starttime9').AsString);
  MainForm.SQLQuery1.Close;

  OpenCompetitionFile(FDbFilePath);
  Application.ProcessMessages;
  AssertEquals('Expanded stage count must survive reopening', 9,
    stages.Count);
  AssertTrue(stages[9].isActive);
  AssertEquals('S9', stages[9].Name);
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_AboveSupportedStages_RejectsWithoutChanges;
var
  csvLines: TStringList;
  headerText, rowText: string;
  i: integer;
begin
  CreateNewCompetitionFile;
  DeleteBackupFiles;
  csvLines := TStringList.Create;
  try
    headerText := 'number;name';
    rowText := '42;Alice';
    for i := 1 to MAX_SUPPORTED_STAGE_COUNT + 1 do
    begin
      headerText := headerText + ';S' + IntToStr(i);
      rowText := rowText + ';10:00';
    end;
    csvLines.Add(headerText);
    csvLines.Add(rowText);
    csvLines.SaveToFile(FCsvFilePath);
  finally
    csvLines.Free;
  end;
  DialogCallCount := 0;
  LastDialogMessage := '';
  ImportParticipantsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertMainRowCount(0);
  AssertEquals(DEFAULT_STAGE_COUNT, stages.Count);
  AssertEquals(DEFAULT_STAGE_COUNT,
    TSchemaSql.DetectStageCapacity(MainForm.SQLQuery1));
  AssertEquals(DEFAULT_STAGE_COUNT,
    TConfigSql.GetInteger(MainForm.SQLQuery1, 'stagecount', 0));
  AssertEquals('Import above the supported maximum must show one error',
    1, DialogCallCount);
  AssertTrue('Expected the supported-stage limit in the error, got: ' +
    LastDialogMessage,
    Pos(Format(rsTooManyParticipantStages,
      [MAX_SUPPORTED_STAGE_COUNT + 1, MAX_SUPPORTED_STAGE_COUNT]),
      LastDialogMessage) > 0);
  AssertEquals('Rejected import must not create a backup', '',
    FindBackupFile);
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_ReimportExistingNumber_UpdatesWithoutDuplicate;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'number;name;category;Stage 1',
    '77;First Name;Open;10:00:00'
  ]);
  ImportParticipantsFile(FCsvFilePath);

  WriteCsv([
    'number;name;category;Stage 1',
    '77;Updated Name;Masters;10:30:00'
  ]);
  ImportParticipantsFile(FCsvFilePath);

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

  ImportParticipantsFile(FCsvFilePath);

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
  DeleteBackupFiles;
  TConfigSql.ExecUpsertByKey(
    MainForm.SQLQuery1, 'stagename1', 'Existing Stage');
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage2', 'True');
  TConfigSql.ExecUpsertByKey(
    MainForm.SQLQuery1, 'stagename2', 'Second existing stage');

  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name) VALUES (500, ''Existing participant'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.SQL.Text :=
    'CREATE TRIGGER reject_participant BEFORE INSERT ON main ' +
    'WHEN NEW.number = 2 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced import failure''); END;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    'number;name;New 1;New 2;New 3;New 4;New 5;New 6;New 7;New 8;New 9',
    '1;First participant;10:00:00;10:01:00;10:02:00;10:03:00;10:04:00;10:05:00;10:06:00;10:07:00;10:08:00',
    '2;Second participant;11:00:00;11:01:00;11:02:00;11:03:00;11:04:00;11:05:00;11:06:00;11:07:00;11:08:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';
  ImportParticipantsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertMainRowCount(1);
  AssertTrue('Expected database error dialog', DialogCallCount > 0);
  AssertTrue('Expected participant database error context, got: ' +
    LastDialogMessage,
    Pos(rsWriteParticipantsDatabaseError, LastDialogMessage) > 0);
  AssertTrue('Expected forced database error, got: ' + LastDialogMessage,
    Pos('forced import failure', LastDialogMessage) > 0);
  AssertTrue('Expected import file path in error, got: ' + LastDialogMessage,
    Pos(ExpandFileName(FCsvFilePath), LastDialogMessage) > 0);
  AssertEquals('Existing Stage',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename1', ''));
  AssertTrue('Stage activity changes must be rolled back with participants',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage2', False));
  AssertEquals('Stage names must survive import rollback',
    'Second existing stage',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename2', ''));
  AssertEquals('Stage-count changes must be rolled back with participants',
    DEFAULT_STAGE_COUNT,
    TConfigSql.GetInteger(MainForm.SQLQuery1, 'stagecount', 0));
  AssertEquals('Physical schema expansion must be rolled back',
    DEFAULT_STAGE_COUNT,
    TSchemaSql.DetectStageCapacity(MainForm.SQLQuery1));
  AssertEquals('The in-memory stage model must remain unchanged after rollback',
    DEFAULT_STAGE_COUNT, stages.Count);
  AssertTrue('Attempted physical expansion must still create a safety backup',
    FindBackupFile <> '');

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count FROM main WHERE number = 500;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Previous participant rows must survive import rollback',
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

  ImportParticipantsFile(FCsvFilePath);

  AssertMainRowCount(0);
  AssertEquals('Expected exactly one import error dialog', 1, DialogCallCount);
  AssertEquals(Format(rsParticipantsImportError,
    [ExpandFileName(FCsvFilePath),
    rsLoadParticipantsListError + rsNumberColumnNotFound]), LastDialogMessage);
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_InvalidStartTime_ReportsErrorAndImportsNothing;
begin
  CreateNewCompetitionFile;
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage1', 'False');
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage2', 'True');
  TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stagename2',
    'Existing second stage');
  MainForm.SQLQuery1.SQLTransaction.Commit;
  WriteCsv([
    'number;name;Stage 1',
    '42;Alice Rider;25:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  ImportParticipantsFile(FCsvFilePath);

  AssertMainRowCount(0);
  AssertEquals('Expected exactly one import error dialog', 1, DialogCallCount);
  AssertEquals(Format(rsParticipantsImportError,
    [ExpandFileName(FCsvFilePath), rsLoadParticipantsListError +
    Format(rsInvalidParticipantStartTime,
      ['25:00', 2, 'Stage 1'])]), LastDialogMessage);
  AssertFalse('Invalid rows must not change stage activity',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage1', True));
  AssertTrue('Invalid rows must preserve existing active stages',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage2', False));
  AssertEquals('Invalid rows must preserve existing stage names',
    'Existing second stage',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename2', ''));
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

  ImportParticipantsFile(FCsvFilePath);

  AssertMainRowCount(0);
  AssertEquals('Expected exactly one import error dialog', 1, DialogCallCount);
  AssertEquals(Format(rsParticipantsImportError,
    [ExpandFileName(FCsvFilePath), rsLoadParticipantsListError +
    Format(rsDuplicateParticipantNumber, [42, 3, 5])]), LastDialogMessage);
end;

procedure TMainFlowIntegrationTests.LoadStageResults_ActiveStageAboveEightImportsValues;
const
  STAGE_INDEX = 12;
  PARTICIPANT_NUMBER = 112;
begin
  CreateSchemaFixture(STAGE_INDEX, IntToStr(STAGE_INDEX),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  ConfigureSingleActiveStage(STAGE_INDEX);
  stages[STAGE_INDEX].Name := 'СУ "Лесной этап"';
  InsertParticipant(PARTICIPANT_NUMBER);
  WriteCsv([
    '#номер;время старта;стартовая поправка;время финиша;штраф;статус',
    '112;10:00:00;-125;11:00:00.123;00:00:05;'
  ]);
  StageSelectionResult := STAGE_INDEX;
  SetStageSelectionHandler(@IntegrationStageSelectionHandler);
  ImportStageResultsFile(FCsvFilePath);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT starttime8, finishtime8, starttime12, correction12, ' +
    'finishtime12, penalty12, status12 FROM main WHERE number = 112;';
  MainForm.SQLQuery1.Open;
  AssertTrue('Stage 8 start must remain empty',
    MainForm.SQLQuery1.FieldByName('starttime8').IsNull);
  AssertTrue('Stage 8 finish must remain empty',
    MainForm.SQLQuery1.FieldByName('finishtime8').IsNull);
  AssertEquals('10:00:00',
    MainForm.SQLQuery1.FieldByName('starttime12').AsString);
  AssertEquals(-125,
    MainForm.SQLQuery1.FieldByName('correction12').AsInteger);
  AssertEquals('11:00:00.123',
    MainForm.SQLQuery1.FieldByName('finishtime12').AsString);
  AssertEquals('00:00:05',
    MainForm.SQLQuery1.FieldByName('penalty12').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('status12').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_InactiveAndReducedStagesAreRejected;
const
  PARTICIPANT_NUMBER = 113;
var
  i: integer;
begin
  CreateSchemaFixture(12, IntToStr(DEFAULT_STAGE_COUNT),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  for i := 1 to stages.Count do
    stages[i].isActive := i in [1, 2];
  MainForm.RebuildCurrentStageSelector(2);
  InsertParticipant(PARTICIPANT_NUMBER);
  WriteCsv([
    '# number;finish time',
    '113;11:00:00'
  ]);
  DeleteBackupFiles;
  SetStageSelectionHandler(@IntegrationStageSelectionHandler);
  StageSelectionResult := 3;
  ImportStageResultsFile(FCsvFilePath);
  StageSelectionResult := 12;
  ImportStageResultsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertEquals('Both invalid selections must be checked',
    2, StageSelectionCallCount);
  AssertEquals('Rejected stages must not create a backup', '',
    FindBackupFile);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2, finishtime3, finishtime12 FROM main ' +
    'WHERE number = 113;';
  MainForm.SQLQuery1.Open;
  AssertTrue(MainForm.SQLQuery1.FieldByName('finishtime2').IsNull);
  AssertTrue('An inactive configured stage must not be imported',
    MainForm.SQLQuery1.FieldByName('finishtime3').IsNull);
  AssertTrue('A stage outside the reduced stagecount must not be imported',
    MainForm.SQLQuery1.FieldByName('finishtime12').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_TwoColumns_ImportsFinishIntoSelectedStage;
begin
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(101);
  WriteCsv([
    '######;',
    '#номер;время финиша',
    '101;11:00:00.123'
  ]);
  ImportStageResultsFile(FCsvFilePath);

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
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(102);
  WriteCsv([
    '######',
    '#номер;время старта;стартовая поправка',
    '102;10:00:00;-250'
  ]);

  ImportStageResultsFile(FCsvFilePath);

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

  AssertTrue(MainForm.MainDataset1.Locate('number', 102, []));
  AssertTrue('Correction fields must match the SQLite INTEGER type',
    MainForm.MainDataset1.FieldByName('correction2') is TLongintField);
  AssertEquals('Imported correction must contain printable decimal text',
    '-250', MainForm.MainDataset1.FieldByName('correction2').DisplayText);
end;

procedure TMainFlowIntegrationTests.LoadStageResults_SixColumns_ImportsFullResultIntoSelectedStage;
begin
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(103);
  WriteCsv([
    '######',
    '#номер;время старта;стартовая поправка;время финиша;штраф;статус',
    '103;10:00:00;-250;11:00:00.123;00:00:05;'
  ]);
  ImportStageResultsFile(FCsvFilePath);
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

procedure TMainFlowIntegrationTests.LoadStageResults_FullImportClearsStaleGlobalStatus;
begin
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(115);
  InsertParticipant(116);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET status = ''2'', status2 = ''2'' WHERE number = 115;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET status = ''2'' WHERE number = 116;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;start time;correction;finish time;penalty;status',
    '115;10:00:00;;11:00:00;;'
  ]);

  ImportStageResultsFile(FCsvFilePath);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT status, status2 FROM main WHERE number = 115;';
  MainForm.SQLQuery1.Open;
  AssertTrue('Full import must clear the stage status',
    MainForm.SQLQuery1.FieldByName('status2').IsNull);
  AssertTrue('Cleared stage status must clear the derived global status',
    MainForm.SQLQuery1.FieldByName('status').IsNull);
  MainForm.SQLQuery1.Close;

  MainForm.SQLQuery1.SQL.Text :=
    'SELECT status FROM main WHERE number = 116;';
  MainForm.SQLQuery1.Open;
  AssertTrue('Status recalculation must include participants outside the CSV',
    MainForm.SQLQuery1.FieldByName('status').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_DatabaseError_RollsBackEntireImport;
begin
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(104);
  InsertParticipant(114);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = CASE number ' +
    'WHEN 104 THEN ''10:30:00'' WHEN 114 THEN ''10:20:00'' END ' +
    'WHERE number IN (104, 114);';
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
    '114;11:10:00',
    '104;11:00:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';
  ImportStageResultsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertTrue('Expected database error dialog', DialogCallCount > 0);
  AssertTrue('Expected database error context, got: ' + LastDialogMessage,
    Pos(rsWriteResultsDatabaseError, LastDialogMessage) > 0);
  AssertTrue('Expected forced result error, got: ' + LastDialogMessage,
    Pos('forced result import failure', LastDialogMessage) > 0);
  AssertTrue('Expected import file path in error, got: ' + LastDialogMessage,
    Pos(ExpandFileName(FCsvFilePath), LastDialogMessage) > 0);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, finishtime2 FROM main WHERE number IN (104, 114) ' +
    'ORDER BY number;';
  MainForm.SQLQuery1.Open;
  AssertEquals(104, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('10:30:00',
    MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Next;
  AssertEquals(114, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('First imported row must be rolled back after a later error',
    '10:20:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;

end;

procedure TMainFlowIntegrationTests.LoadStageResults_InvalidCsv_DoesNotChangeExistingResults;
begin
  CreateEmptyCompetitionFixture(2);
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

  ImportStageResultsFile(FCsvFilePath);

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
  CreateEmptyCompetitionFixture(2);
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

  ImportStageResultsFile(FCsvFilePath);

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
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(109);

  WriteCsv([
    '# number;finish time',
    '109;10:00:00'
  ]);
  ImportStageResultsFile(FCsvFilePath);

  DeleteBackupFiles;
  WriteCsv([
    '# number;finish time',
    '109;11:00:00'
  ]);
  ImportStageResultsFile(FCsvFilePath);

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
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(110);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = ''10:30:00'' WHERE number = 110;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;finish time',
    '110;11:00:00'
  ]);
  StageSelectionResult := -1;
  SetStageSelectionHandler(@IntegrationStageSelectionHandler);
  ImportStageResultsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertEquals('Expected one stage selection request',
    1, StageSelectionCallCount);
  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 110;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Cancellation must preserve the existing result',
    '10:30:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;

end;

procedure TMainFlowIntegrationTests.LoadStageResults_DuplicateNumber_ReportsLocalizedCsvError;
begin
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(107);

  WriteCsv([
    '# number;finish time',
    '107;10:00:00',
    '# duplicate follows',
    '107;11:00:00'
  ]);

  ImportStageResultsFile(FCsvFilePath);

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
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(106);

  WriteCsv([
    '# number;finish time',
    '999;11:00:00'
  ]);

  ImportStageResultsFile(FCsvFilePath);

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
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  InsertParticipant(106);

  WriteCsv([
    '# number;finish time',
    '106;10:00:00',
    '999;11:00:00'
  ]);
  ConfirmationDialogResult := mrNo;
  ImportStageResultsFile(FCsvFilePath);
  Application.ProcessMessages;

  AssertTrue('Expected confirmation for unknown participant',
    DialogCallCount > 0);
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

procedure TMainFlowIntegrationTests.ExportStageResultsCsv_StageAboveEightUsesDynamicFields;
const
  STAGE_INDEX = 12;
  PARTICIPANT_NUMBER = 412;
var
  stageFileName: string;
  content: TStringList;
begin
  CreateSchemaFixture(STAGE_INDEX, IntToStr(STAGE_INDEX),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  ConfigureSingleActiveStage(STAGE_INDEX);
  stages[STAGE_INDEX].Name := 'СУ "Лесной этап"';
  MainForm.SQLQuery1.SQL.Text := 'DELETE FROM main;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  InsertParticipant(PARTICIPANT_NUMBER);
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime12 = ''10:00:00'', correction12 = -125, ' +
    'finishtime12 = ''11:00:00.123'', penalty12 = ''00:00:05'', ' +
    'status12 = ''2'' WHERE number = 412;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  stageFileName := ChangeFileExt(FCsvFilePath, '.stage12.csv');
  content := TStringList.Create;
  try
    ExportStageResultsFile(stageFileName, STAGE_INDEX);
    Application.ProcessMessages;

    AssertTrue(FileExists(stageFileName));
    content.LoadFromFile(stageFileName);
    AssertEquals(1, content.Count);
    AssertEquals('412;10:00:00;-125;11:00:00.123;00:00:05;2',
      content[0]);
  finally
    content.Free;
    if FileExists(stageFileName) then
      DeleteFile(stageFileName);
  end;
end;

procedure TMainFlowIntegrationTests.DynamicCsvExports_UseActiveStagesAndComplexNames;
const
  STAGE_COUNT = 12;
  COMPLEX_STAGE_NAME = 'СУ "Лесной этап"';
var
  i: integer;
  startListFileName, resultsFileName: string;
  content: TStringList;
  csvDocument: TCSVDocument;
begin
  CreateSchemaFixture(STAGE_COUNT, IntToStr(STAGE_COUNT),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  for i := 1 to stages.Count do
    stages[i].isActive := i in [1, STAGE_COUNT];
  stages[1].Name := 'Короткий этап';
  stages[STAGE_COUNT].Name := COMPLEX_STAGE_NAME;
  ApplyStagePresentationToUi(STAGE_COUNT);
  MainForm.SQLQuery1.SQL.Text := 'DELETE FROM main;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  InsertParticipant(413);
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET category = ''Open'', starttime1 = ''09:00:00'', ' +
    'starttime12 = ''10:00:00'', result1 = ''00:05:00.000'', ' +
    'diffleader1 = ''00:00:00.000'', place1 = 1, ' +
    'result12 = ''00:06:00.000'', diffleader12 = ''00:01:00.000'', ' +
    'place12 = 2, sumresult = ''00:11:00.000'', ' +
    'sumdiffleader = ''00:01:00.000'' WHERE number = 413;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  RefreshCompetitionViews;
  startListFileName := ChangeFileExt(FCsvFilePath, '.dynamic-start.csv');
  resultsFileName := ChangeFileExt(FCsvFilePath, '.dynamic-results.csv');
  content := TStringList.Create;
  csvDocument := TCSVDocument.Create;
  try
    ExportStartListFile(startListFileName);
    ExportResultsFile(resultsFileName);

    content.LoadFromFile(startListFileName);
    csvDocument.Delimiter := ';';
    csvDocument.CSVText := content.Text;
    AssertEquals(2, csvDocument.RowCount);
    AssertEquals('Only base and active-stage start columns are expected',
      12, csvDocument.ColCount[0]);
    AssertEquals('Короткий этап', csvDocument.Cells[10, 0]);
    AssertEquals(COMPLEX_STAGE_NAME, csvDocument.Cells[11, 0]);
    AssertEquals('09:00:00', csvDocument.Cells[10, 1]);
    AssertEquals('10:00:00', csvDocument.Cells[11, 1]);

    content.LoadFromFile(resultsFileName);
    csvDocument.CSVText := content.Text;
    AssertEquals(2, csvDocument.RowCount);
    AssertEquals('Only base, active-stage and summary columns are expected',
      16, csvDocument.ColCount[0]);
    AssertEquals('Короткий этап — ' + rsResult,
      csvDocument.Cells[8, 0]);
    AssertEquals('Короткий этап — ' + rsDiffleader,
      csvDocument.Cells[9, 0]);
    AssertEquals('Короткий этап — ' + rsPlace,
      csvDocument.Cells[10, 0]);
    AssertEquals(COMPLEX_STAGE_NAME + ' — ' + rsResult,
      csvDocument.Cells[11, 0]);
    AssertEquals(COMPLEX_STAGE_NAME + ' — ' + rsDiffleader,
      csvDocument.Cells[12, 0]);
    AssertEquals(COMPLEX_STAGE_NAME + ' — ' + rsPlace,
      csvDocument.Cells[13, 0]);
    AssertEquals(rsSumresult, csvDocument.Cells[14, 0]);
    AssertEquals(rsDiffleader, csvDocument.Cells[15, 0]);
    AssertEquals('00:06:00.000', csvDocument.Cells[11, 1]);
    AssertEquals('2', csvDocument.Cells[13, 1]);
    AssertEquals('Dynamic start fields must be cleaned after export',
      10, MainForm.CSVStartListExporter.ExportFields.Count);
    AssertEquals('Dynamic result fields must be cleaned after export',
      8, MainForm.CSVResultsExporter.ExportFields.Count);
  finally
    csvDocument.Free;
    content.Free;
    if FileExists(startListFileName) then
      DeleteFile(startListFileName);
    if FileExists(resultsFileName) then
      DeleteFile(resultsFileName);
  end;
end;

procedure TMainFlowIntegrationTests.ExportAllResultsToXLSX_UsesDynamicStagesAndComplexNames;
const
  STAGE_COUNT = 12;
  COMPLEX_STAGE_NAME = 'СУ "Лесной этап"';
var
  i: integer;
  exportFileName: string;
  workbook: TsWorkbook;
  finishWorksheet, thruWorksheet: TsWorksheet;
begin
  CreateSchemaFixture(STAGE_COUNT, IntToStr(STAGE_COUNT),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  for i := 1 to stages.Count do
    stages[i].isActive := i in [1, STAGE_COUNT];
  stages[1].Name := 'Короткий этап';
  stages[STAGE_COUNT].Name := COMPLEX_STAGE_NAME;
  ApplyStagePresentationToUi(STAGE_COUNT);
  MainForm.SQLQuery1.SQL.Text := 'DELETE FROM main;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  InsertParticipant(414);
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET category = ''Open'', starttime1 = ''09:00:00'', ' +
    'result1 = ''00:05:00.000'', diffleader1 = ''00:00:00.000'', ' +
    'place1 = 1, result12 = ''00:06:00.000'', ' +
    'diffleader12 = ''00:01:00.000'', place12 = 2, ' +
    'sumresult = ''00:11:00.000'', sumdiffleader = ''00:01:00.000'', ' +
    'sumplace = 1, sumstages = 2, thruplace = 1, ' +
    'thrudiff = ''00:01:00.000'' WHERE number = 414;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  RefreshCompetitionViews;
  exportFileName := ChangeFileExt(FCsvFilePath, '.dynamic.xlsx');
  workbook := TsWorkbook.Create;
  try
    ExportAllResultsFile(exportFileName);
    AssertTrue(FileExists(exportFileName));

    workbook.ReadFromFile(exportFileName, sfOOXML);
    finishWorksheet := workbook.GetWorksheetByName(rsFinishProtocol);
    AssertTrue('Finish worksheet must exist', finishWorksheet <> nil);
    AssertEquals('Open', finishWorksheet.ReadAsText(0, 0));
    AssertEquals('Короткий этап', finishWorksheet.ReadAsText(1, 7));
    AssertEquals(COMPLEX_STAGE_NAME, finishWorksheet.ReadAsText(1, 10));
    AssertEquals(rsPlace, finishWorksheet.ReadAsText(2, 0));
    AssertEquals(rsNumber, finishWorksheet.ReadAsText(2, 1));
    AssertEquals(rsName, finishWorksheet.ReadAsText(2, 2));
    AssertEquals(rsResult, finishWorksheet.ReadAsText(2, 7));
    AssertEquals(rsDiffleader, finishWorksheet.ReadAsText(2, 8));
    AssertEquals(rsPlace, finishWorksheet.ReadAsText(2, 9));
    AssertEquals(rsResult, finishWorksheet.ReadAsText(2, 10));
    AssertEquals(rsDiffleader, finishWorksheet.ReadAsText(2, 11));
    AssertEquals(rsPlace, finishWorksheet.ReadAsText(2, 12));
    AssertEquals(rsSumresult, finishWorksheet.ReadAsText(2, 13));
    AssertEquals(rsDiffleader, finishWorksheet.ReadAsText(2, 14));
    AssertEquals(rsSumstages, finishWorksheet.ReadAsText(2, 15));
    AssertEquals('1', finishWorksheet.ReadAsText(3, 0));
    AssertEquals('414', finishWorksheet.ReadAsText(3, 1));
    AssertEquals('Test participant', finishWorksheet.ReadAsText(3, 2));
    AssertEquals('05:00.000', finishWorksheet.ReadAsText(3, 7));
    AssertEquals('00:00.000', finishWorksheet.ReadAsText(3, 8));
    AssertEquals('1', finishWorksheet.ReadAsText(3, 9));
    AssertEquals('06:00.000', finishWorksheet.ReadAsText(3, 10));
    AssertEquals('01:00.000', finishWorksheet.ReadAsText(3, 11));
    AssertEquals('2', finishWorksheet.ReadAsText(3, 12));
    AssertEquals('11:00.000', finishWorksheet.ReadAsText(3, 13));
    AssertEquals('01:00.000', finishWorksheet.ReadAsText(3, 14));
    AssertEquals('2', finishWorksheet.ReadAsText(3, 15));
    AssertEquals('Dynamic XLSX must contain exactly two stage groups',
      15, finishWorksheet.GetLastColIndex(True));
    AssertEquals('Finish place must remain a numeric cell',
      Ord(cctNumber), Ord(finishWorksheet.FindCell(3, 0)^.ContentType));
    AssertEquals('Finish duration must remain a text cell',
      Ord(cctUTF8String), Ord(finishWorksheet.FindCell(3, 7)^.ContentType));
    AssertEquals('Finish place must remain centered', Ord(haCenter),
      Ord(finishWorksheet.ReadHorAlignment(finishWorksheet.FindCell(3, 0))));
    AssertEquals('Finish duration must remain right-aligned', Ord(haRight),
      Ord(finishWorksheet.ReadHorAlignment(finishWorksheet.FindCell(3, 7))));
    AssertTrue('Finish header must remain bold',
      fssBold in finishWorksheet.ReadCellFont(
      finishWorksheet.FindCell(2, 0)).Style);
    AssertTrue('Stage heading must remain merged',
      finishWorksheet.IsMerged(finishWorksheet.FindCell(1, 7)));
    AssertEquals('Number column width must remain 50 points', 50.0,
      finishWorksheet.GetColWidth(1, suPoints), 0.1);
    AssertEquals('Name column width must remain 125 points', 125.0,
      finishWorksheet.GetColWidth(2, suPoints), 0.1);

    thruWorksheet := workbook.GetWorksheetByName(rsFinishThruProtocol);
    AssertTrue('Through worksheet must exist', thruWorksheet <> nil);
    AssertEquals(rsCategory, thruWorksheet.ReadAsText(0, 0));
    AssertEquals(rsPlace, thruWorksheet.ReadAsText(0, 1));
    AssertEquals(rsNumber, thruWorksheet.ReadAsText(0, 2));
    AssertEquals(rsName, thruWorksheet.ReadAsText(0, 3));
    AssertEquals(rsResult, thruWorksheet.ReadAsText(0, 4));
    AssertEquals(rsDiffleader, thruWorksheet.ReadAsText(0, 5));
    AssertEquals(rsSumstages, thruWorksheet.ReadAsText(0, 6));
    AssertEquals('Open', thruWorksheet.ReadAsText(1, 0));
    AssertEquals('1', thruWorksheet.ReadAsText(1, 1));
    AssertEquals('414', thruWorksheet.ReadAsText(1, 2));
    AssertEquals('Test participant', thruWorksheet.ReadAsText(1, 3));
    AssertEquals('11:00.000', thruWorksheet.ReadAsText(1, 4));
    AssertEquals('01:00.000', thruWorksheet.ReadAsText(1, 5));
    AssertEquals('2', thruWorksheet.ReadAsText(1, 6));
    AssertEquals('Through place must remain a numeric cell',
      Ord(cctNumber), Ord(thruWorksheet.FindCell(1, 1)^.ContentType));
    AssertEquals('Through duration must remain a text cell',
      Ord(cctUTF8String), Ord(thruWorksheet.FindCell(1, 4)^.ContentType));
    AssertEquals('Through duration must remain right-aligned', Ord(haRight),
      Ord(thruWorksheet.ReadHorAlignment(thruWorksheet.FindCell(1, 4))));
    AssertTrue('Through result must remain bold',
      fssBold in thruWorksheet.ReadCellFont(
      thruWorksheet.FindCell(1, 4)).Style);
  finally
    workbook.Free;
    if FileExists(exportFileName) then
      DeleteFile(exportFileName);
  end;
end;

procedure TMainFlowIntegrationTests.
  ExportStageResultsCsvFailure_ReportsErrorAndWritesNoFile;
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
    ExportStageResultsFile(exportFileName, 1);

    AssertEquals(1, DialogCallCount);
    AssertTrue(Pos(ExpandFileName(exportFileName), LastDialogMessage) > 0);
    AssertFalse('Failed export must not leave an output file',
      FileExists(exportFileName));
  finally
    if FileExists(blockingFileName) then DeleteFile(blockingFileName);
  end;
end;

procedure TMainFlowIntegrationTests.
  ExportDatasetCsvFailure_ReportsErrorAndWritesNoFile;
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
    ExportResultsFile(exportFileName);

    AssertEquals(1, DialogCallCount);
    AssertTrue(Pos(ExpandFileName(exportFileName), LastDialogMessage) > 0);
    AssertFalse('Failed export must not leave an output file',
      FileExists(exportFileName));
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
    '(201, ''Calculated'', ''00:10:00.000'', ''2''), ' +
    '(202, ''Did not finish'', NULL, ''2''), ' +
    '(203, ''Did not start'', NULL, ''1''), ' +
    '(204, ''Disqualified'', ''00:05:00.000'', ''3'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  TResultCalculationService.RecalculateSumResults(MainForm.CompetitionDb, stages);

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
  AssertEquals('2', MainForm.SQLQuery1.FieldByName('status').AsString);

  MainForm.SQLQuery1.Next;
  AssertEquals(203, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('DNS', MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('sumstages').IsNull);
  AssertEquals('1', MainForm.SQLQuery1.FieldByName('status').AsString);

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
  CreateEmptyCompetitionFixture(3);
  ConfigureSingleActiveStage(1);
  stages[2].isActive := True;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name, result1, result2, result3) VALUES ' +
    '(301, ''Summed result'', ''00:45:30.250'', ''01:20:40.750'', ' +
    '''05:00:00.000'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  TResultCalculationService.RecalculateSumResults(MainForm.CompetitionDb, stages);

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

procedure TMainFlowIntegrationTests.UpdateResults_StageAboveEightCalculatesStageSumAndThruPlaces;
begin
  CreateSchemaFixture(12, '12',
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  ConfigureSingleActiveStage(12);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text := 'DELETE FROM main;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (category, number, name, starttime12, finishtime12) ' +
    'VALUES ' +
    '(''Open'', 1201, ''Leader'', ''10:00:00.000'', ''10:10:00.000''), ' +
    '(''Open'', 1202, ''Second'', ''10:00:00.000'', ''10:12:00.000'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  MainForm.AcUpdateResultsExecute(MainForm.AcUpdateResults);

  AssertEquals('A stage-12 calculation must not show an error dialog',
    0, DialogCallCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, result12, diffleader12, place12, sumresult, ' +
    'sumdiffleader, sumplace, sumstages, thrudiff, thruplace ' +
    'FROM main ORDER BY number;';
  MainForm.SQLQuery1.Open;

  AssertEquals(1201, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('00:10:00.000',
    MainForm.SQLQuery1.FieldByName('result12').AsString);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('place12').AsInteger);
  AssertTrue(MainForm.SQLQuery1.FieldByName('diffleader12').IsNull);
  AssertEquals('00:10:00.000',
    MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('sumstages').AsInteger);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('sumplace').AsInteger);
  AssertTrue(MainForm.SQLQuery1.FieldByName('sumdiffleader').IsNull);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('thruplace').AsInteger);
  AssertTrue(MainForm.SQLQuery1.FieldByName('thrudiff').IsNull);

  MainForm.SQLQuery1.Next;
  AssertEquals(1202, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('00:12:00.000',
    MainForm.SQLQuery1.FieldByName('result12').AsString);
  AssertEquals(2, MainForm.SQLQuery1.FieldByName('place12').AsInteger);
  AssertEquals('00:02:00.000',
    MainForm.SQLQuery1.FieldByName('diffleader12').AsString);
  AssertEquals('00:12:00.000',
    MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('sumstages').AsInteger);
  AssertEquals(2, MainForm.SQLQuery1.FieldByName('sumplace').AsInteger);
  AssertEquals('00:02:00.000',
    MainForm.SQLQuery1.FieldByName('sumdiffleader').AsString);
  AssertEquals(2, MainForm.SQLQuery1.FieldByName('thruplace').AsInteger);
  AssertEquals('00:02:00.000',
    MainForm.SQLQuery1.FieldByName('thrudiff').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.UpdateResults_FromPopupPreservesMainGridRow;
var
  participantIndex: integer;
  selectedNumber, selectedRow, targetRow, topNumber: integer;
  wasMainFormVisible: boolean;
begin
  wasMainFormVisible := MainForm.Visible;
  if not wasMainFormVisible then
  begin
    MainForm.Show;
    Application.ProcessMessages;
  end;
  try
    CreateNewCompetitionFile;
    MainForm.SQLQuery1.Close;
    MainForm.SQLQuery1.SQL.Text :=
      'INSERT INTO main (number, name) VALUES (:NUMBER, :NAME);';
    for participantIndex := 1 to 60 do
    begin
      MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger :=
        1000 + participantIndex;
      MainForm.SQLQuery1.ParamByName('NAME').AsString :=
        'Participant ' + IntToStr(participantIndex);
      MainForm.SQLQuery1.ExecSQL;
    end;
    MainForm.SQLTransaction1.Commit;
    MainForm.SQLQuery1.Close;
    RefreshCompetitionViews;

    MainForm.MainDataset1.First;
    MainForm.MainDataset1.MoveBy(30);
    targetRow := TMyRxDBGridAccess(MainForm.RxDBGrid1).FixedRows + 5;
    TMyRxDBGridAccess(MainForm.RxDBGrid1).SelectDataRow(targetRow);
    selectedNumber := MainForm.MainDataset1.FieldByName('number').AsInteger;
    selectedRow := MainForm.RxDBGrid1.GetRow;
    topNumber := TMyRxDBGridAccess(MainForm.RxDBGrid1).IntegerFieldAtRow(
      TMyRxDBGridAccess(MainForm.RxDBGrid1).FixedRows, 'number');
    AssertTrue(Format(
      'The test selection must leave visible rows below it ' +
      '(row=%d, row_count=%d, visible_rows=%d, height=%d, client_height=%d)',
      [selectedRow, TMyRxDBGridAccess(MainForm.RxDBGrid1).RowCount,
      TMyRxDBGridAccess(MainForm.RxDBGrid1).VisibleRowCount,
      MainForm.RxDBGrid1.Height, MainForm.RxDBGrid1.ClientHeight]),
      selectedRow < TMyRxDBGridAccess(MainForm.RxDBGrid1).RowCount - 1);

    MainForm.AcUpdateResults.Update;
    AssertTrue('The popup update item must be enabled for an open database',
      MainForm.pmUpdateResults.Enabled);
    FMainDatasetOpenCount := 0;
    MainForm.MainDataset1.AfterOpen := @CountMainDatasetOpen;
    try
      MainForm.pmUpdateResults.Click;
    finally
      MainForm.MainDataset1.AfterOpen := nil;
    end;

    AssertEquals('The popup action must refresh the main dataset',
      1, FMainDatasetOpenCount);
    AssertEquals('Popup recalculation must keep the selected participant',
      selectedNumber,
      MainForm.MainDataset1.FieldByName('number').AsInteger);
    AssertEquals('Popup recalculation must not scroll the selected row downward',
      selectedRow, MainForm.RxDBGrid1.GetRow);
    AssertEquals('Popup recalculation must preserve the first visible participant',
      topNumber, TMyRxDBGridAccess(MainForm.RxDBGrid1).IntegerFieldAtRow(
      TMyRxDBGridAccess(MainForm.RxDBGrid1).FixedRows, 'number'));
  finally
    if not wasMainFormVisible then
      MainForm.Hide;
  end;
end;

procedure TMainFlowIntegrationTests.SetFinish_MultipleRowsAreProcessedSequentially;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(421);
  InsertParticipant(422);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''00:00:00.000'' ' +
    'WHERE number IN (421, 422);';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  MainForm.SelectCurrentStage(1);
  MainForm.ResultClearClick(MainForm);
  ApplyFinishPacketAt(EncodeTime(0, 15, 0, 0));
  SetFinishMarkNumberAt(0, 421);
  ApplyFinishPacketAt(EncodeTime(0, 10, 0, 0));
  SetFinishMarkNumberAt(1, 422);
  DialogCallCount := 0;

  MainForm.AcApplyFinishMarksExecute(MainForm.AcApplyFinishMarks);

  AssertEquals('On-track finishes must not require confirmation',
    0, DialogCallCount);
  AssertEquals('Every saved finish must be removed from the pending list',
    0, MainForm.DatasetFinishMarks.RecordCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, finishtime1, result1, place1 FROM main ' +
    'WHERE number IN (421, 422) ORDER BY number;';
  MainForm.SQLQuery1.Open;
  AssertEquals(421, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('00:15:00.000',
    MainForm.SQLQuery1.FieldByName('finishtime1').AsString);
  AssertEquals('00:15:00.000',
    MainForm.SQLQuery1.FieldByName('result1').AsString);
  AssertEquals(2, MainForm.SQLQuery1.FieldByName('place1').AsInteger);
  MainForm.SQLQuery1.Next;
  AssertEquals(422, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('00:10:00.000',
    MainForm.SQLQuery1.FieldByName('finishtime1').AsString);
  AssertEquals('00:10:00.000',
    MainForm.SQLQuery1.FieldByName('result1').AsString);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('place1').AsInteger);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT participant_number, status, assignment_mode, applied_at ' +
    'FROM finish_marks ORDER BY event_time;';
  MainForm.SQLQuery1.Open;
  AssertEquals(422,
    MainForm.SQLQuery1.FieldByName('participant_number').AsInteger);
  AssertEquals('applied', MainForm.SQLQuery1.FieldByName('status').AsString);
  AssertEquals('manual',
    MainForm.SQLQuery1.FieldByName('assignment_mode').AsString);
  AssertFalse(MainForm.SQLQuery1.FieldByName('applied_at').IsNull);
  MainForm.SQLQuery1.Next;
  AssertEquals(421,
    MainForm.SQLQuery1.FieldByName('participant_number').AsInteger);
  AssertEquals('applied', MainForm.SQLQuery1.FieldByName('status').AsString);
  AssertFalse(MainForm.SQLQuery1.FieldByName('applied_at').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.SetFinish_UsesStageCapturedWhenMarkWasReceived;
begin
  CreateEmptyCompetitionFixture(2);
  stages[2].isActive := True;
  ApplyStageActivityToUi(1);
  InsertParticipant(425);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''00:00:00.000'' WHERE number = 425;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  MainForm.ResultClearClick(MainForm);
  MainForm.SelectCurrentStage(1);
  ApplyFinishPacketAt(EncodeTime(0, 18, 0, 0));
  AssertEquals(1, MainForm.DatasetFinishMarks.RecordCount);
  SetFinishMarkNumberAt(0, 425);

  MainForm.SelectCurrentStage(2);
  DialogCallCount := 0;
  MainForm.AcApplyFinishMarksExecute(MainForm.AcApplyFinishMarks);

  AssertEquals(0, DialogCallCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime1, finishtime2 FROM main WHERE number = 425;';
  MainForm.SQLQuery1.Open;
  AssertEquals('00:18:00.000',
    MainForm.SQLQuery1.FieldByName('finishtime1').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('finishtime2').IsNull);
  MainForm.SQLQuery1.Close;
  AssertEquals(0, MainForm.DatasetFinishMarks.RecordCount);
end;

procedure TMainFlowIntegrationTests.SetFinish_UsesCapturedTimeInsteadOfGridText;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(426);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''00:00:00.000'' WHERE number = 426;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  MainForm.ResultClearClick(MainForm);
  MainForm.SelectCurrentStage(1);
  ApplyFinishPacketAt(EncodeTime(0, 19, 0, 0));
  SetFinishMarkNumberAt(0, 426);

  MainForm.AcApplyFinishMarksExecute(MainForm.AcApplyFinishMarks);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime1 FROM main WHERE number = 426;';
  MainForm.SQLQuery1.Open;
  AssertEquals('00:19:00.000',
    MainForm.SQLQuery1.FieldByName('finishtime1').AsString);
  MainForm.SQLQuery1.Close;
  AssertEquals(0, MainForm.DatasetFinishMarks.RecordCount);
end;

procedure TMainFlowIntegrationTests.SetFinish_CalculationErrorRollsBackFinishAndResults;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(420);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''00:00:00.000'' WHERE number = 420;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'CREATE TRIGGER fail_result_update BEFORE UPDATE OF result1 ON main ' +
    'WHEN NEW.number = 420 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced result calculation failure''); END;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  MainForm.SelectCurrentStage(1);
  MainForm.ResultClearClick(MainForm);
  ApplyFinishPacketAt(EncodeTime(0, 15, 0, 0));
  SetFinishMarkNumberAt(0, 420);

  MainForm.AcApplyFinishMarksExecute(MainForm.AcApplyFinishMarks);

  AssertEquals('Calculation failure must be reported once', 1,
    DialogCallCount);
  AssertTrue(Pos('forced result calculation failure', LastDialogMessage) > 0);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime1, result1, place1, diffleader1 ' +
    'FROM main WHERE number = 420;';
  MainForm.SQLQuery1.Open;
  AssertTrue('Finish time must roll back with failed calculations',
    MainForm.SQLQuery1.FieldByName('finishtime1').IsNull);
  AssertTrue(MainForm.SQLQuery1.FieldByName('result1').IsNull);
  AssertTrue(MainForm.SQLQuery1.FieldByName('place1').IsNull);
  AssertTrue(MainForm.SQLQuery1.FieldByName('diffleader1').IsNull);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT participant_number, status, applied_at FROM finish_marks;';
  MainForm.SQLQuery1.Open;
  AssertEquals(420,
    MainForm.SQLQuery1.FieldByName('participant_number').AsInteger);
  AssertEquals('pending', MainForm.SQLQuery1.FieldByName('status').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('applied_at').IsNull);
  MainForm.SQLQuery1.Close;
  AssertEquals('A failed save must leave the typed mark available for retry',
    1, MainForm.DatasetFinishMarks.RecordCount);

  MainForm.ResultClearClick(MainForm);
end;

procedure TMainFlowIntegrationTests.SetFinish_RefreshFailureKeepsCommittedFinish;
var
  oldSql: string;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(423);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''00:00:00.000'' WHERE number = 423;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  MainForm.SelectCurrentStage(1);
  MainForm.ResultClearClick(MainForm);
  ApplyFinishPacketAt(EncodeTime(0, 16, 0, 0));
  SetFinishMarkNumberAt(0, 423);
  oldSql := MainForm.StatDataset1.SQL.Text;
  MainForm.StatDataset1.Close;
  MainForm.StatDataset1.SQL.Text := 'SELECT * FROM missing_statistics_table';
  DialogCallCount := 0;
  try
    MainForm.AcApplyFinishMarksExecute(MainForm.AcApplyFinishMarks);

    AssertEquals('Only the refresh failure must be reported', 1,
      DialogCallCount);
    AssertTrue('The refresh error must not be reported as a save failure',
      Pos('missing_statistics_table', LastDialogMessage) > 0);
    AssertEquals('A committed finish must leave the pending list even when ' +
      'a later refresh fails', 0, MainForm.DatasetFinishMarks.RecordCount);

    MainForm.SQLQuery1.Close;
    MainForm.SQLQuery1.SQL.Text :=
      'SELECT finishtime1, result1, place1 FROM main WHERE number = 423;';
    MainForm.SQLQuery1.Open;
    AssertEquals('00:16:00.000',
      MainForm.SQLQuery1.FieldByName('finishtime1').AsString);
    AssertEquals('00:16:00.000',
      MainForm.SQLQuery1.FieldByName('result1').AsString);
    AssertEquals(1, MainForm.SQLQuery1.FieldByName('place1').AsInteger);
    MainForm.SQLQuery1.Close;
  finally
    MainForm.StatDataset1.Close;
    MainForm.StatDataset1.SQL.Text := oldSql;
    MainForm.StatDataset1.Open;
    MainForm.ResultClearClick(MainForm);
  end;
end;

procedure TMainFlowIntegrationTests.SetFinish_TelegramFailureKeepsCommittedFinish;
var
  oldTelegramAddress: string;
  oldTelegramEnabled, oldLedEnabled: boolean;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(424);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET category = ''Open'', ' +
    'starttime1 = ''00:00:00.000'' WHERE number = 424;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  MainForm.SelectCurrentStage(1);
  MainForm.ResultClearClick(MainForm);
  ApplyFinishPacketAt(EncodeTime(0, 17, 0, 0));
  SetFinishMarkNumberAt(0, 424);
  oldTelegramAddress := telegrambotadress;
  oldTelegramEnabled := MainForm.AcTelegramBot.Checked;
  oldLedEnabled := MainForm.AcLEDPanel.Checked;
  telegrambotadress := 'http://127.0.0.1:1/unreachable-test-endpoint';
  MainForm.AcTelegramBot.Checked := True;
  MainForm.AcLEDPanel.Checked := False;
  DialogCallCount := 0;
  try
    MainForm.AcApplyFinishMarksExecute(MainForm.AcApplyFinishMarks);

    AssertEquals('A notifier failure must not be shown as a save failure',
      0, DialogCallCount);
    AssertEquals('A committed finish must leave the pending list even when ' +
      'Telegram is unavailable', 0, MainForm.DatasetFinishMarks.RecordCount);
    MainForm.SQLQuery1.Close;
    MainForm.SQLQuery1.SQL.Text :=
      'SELECT finishtime1, result1, place1 FROM main WHERE number = 424;';
    MainForm.SQLQuery1.Open;
    AssertEquals('00:17:00.000',
      MainForm.SQLQuery1.FieldByName('finishtime1').AsString);
    AssertEquals('00:17:00.000',
      MainForm.SQLQuery1.FieldByName('result1').AsString);
    AssertEquals(1, MainForm.SQLQuery1.FieldByName('place1').AsInteger);
    MainForm.SQLQuery1.Close;
  finally
    MainForm.AcTelegramBot.Checked := oldTelegramEnabled;
    MainForm.AcLEDPanel.Checked := oldLedEnabled;
    telegrambotadress := oldTelegramAddress;
    MainForm.ResultClearClick(MainForm);
  end;
end;

procedure TMainFlowIntegrationTests.ParticipantEdit_SavesAndKeepsEditedRowCurrent;
begin
  CreateNewCompetitionFile;
  InsertParticipant(401);

  MainForm.MainDataset1.Locate('number', 401, []);
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('name').AsString := 'Changed participant';
  MainForm.MainDataset1.Post;
  AssertTrue('Posting must leave cached updates for ApplyUpdates',
    MainForm.MainDataset1.ChangeCount > 0);
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;

  AssertEquals('EditingDone must apply all cached updates', 0,
    MainForm.MainDataset1.ChangeCount);
  AssertTrue('The main dataset must remain open after saving an edit',
    MainForm.MainDataset1.Active);
  AssertEquals('The edited row must remain current', 401,
    MainForm.MainDataset1.FieldByName('number').AsInteger);
  AssertEquals('Changed participant',
    MainForm.MainDataset1.FieldByName('name').AsString);
  MainForm.FileCloseExecute(nil);
  MainForm.FileOpenDB.Dialog.FileName := FDbFilePath;
  MainForm.FileOpenDBAccept(MainForm.FileOpenDB);
  AssertTrue('The participant must exist after reopening the database',
    MainForm.MainDataset1.Locate('number', 401, []));
  AssertEquals('The edited name must persist after reopening the database',
    'Changed participant', MainForm.MainDataset1.FieldByName('name').AsString);
end;

procedure TMainFlowIntegrationTests.ParticipantNumberEdit_SavesNewNumber;
begin
  CreateNewCompetitionFile;
  InsertParticipant(414);
  AssertTrue(MainForm.MainDataset1.Locate('number', 414, []));
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1number.AsInteger := 415;
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;

  AssertTrue('The participant must remain current under the new number',
    MainForm.MainDataset1.Locate('number', 415, []));
end;

procedure TMainFlowIntegrationTests.ParticipantPrivateFields_LogNamesWithoutValues;
const
  PrivatePhone = 'PRIVATE-PHONE-VALUE';
  PrivateEmail = 'PRIVATE-EMAIL-VALUE';
var
  logDirectory, logFileName, logText: string;
  logLines: TStringList;
begin
  CreateNewCompetitionFile;
  InsertParticipant(416);
  AssertTrue(MainForm.MainDataset1.Locate('number', 416, []));
  logDirectory := ChangeFileExt(FDbFilePath, '') + '-privacy-logs';
  ForceDirectories(logDirectory);
  InitializeAppLogger(DefaultLoggingSettings, logDirectory, '');
  logFileName := CurrentAppLogFileName;
  try
    MainForm.MainDataset1.Edit;
    MainForm.MainDataset1phone.AsString := PrivatePhone;
    MainForm.MainDataset1email.AsString := PrivateEmail;
    MainForm.MainDataset1.Post;
    MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  finally
    FinalizeAppLogger;
  end;

  logLines := TStringList.Create;
  try
    logLines.LoadFromFile(logFileName);
    logText := logLines.Text;
  finally
    logLines.Free;
  end;
  AssertTrue(Pos(Format(rsParticipantFieldUpdated,
    ['416', MainForm.RxDBGrid1.ColumnByFieldName('phone').Title.Caption]),
    logText) > 0);
  AssertTrue(Pos(Format(rsParticipantFieldUpdated,
    ['416', MainForm.RxDBGrid1.ColumnByFieldName('email').Title.Caption]),
    logText) > 0);
  AssertEquals('A private phone value must not be written to the log',
    0, Pos(PrivatePhone, logText));
  AssertEquals('A private email value must not be written to the log',
    0, Pos(PrivateEmail, logText));
  if FileExists(logFileName) then
    DeleteFile(logFileName);
  if DirectoryExists(logDirectory) then
    RemoveDir(logDirectory);
end;

procedure TMainFlowIntegrationTests.ParticipantAppend_SavesAndKeepsInsertedRowCurrent;
var
  participantNumber: integer;
begin
  CreateNewCompetitionFile;
  MainForm.MainDataset1.Append;
  participantNumber := MainForm.MainDataset1.FieldByName('number').AsInteger;
  MainForm.MainDataset1.FieldByName('name').AsString := 'New participant';
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;

  AssertTrue('The main dataset must remain open after append',
    MainForm.MainDataset1.Active);
  AssertEquals('The inserted row must remain current', participantNumber,
    MainForm.MainDataset1.FieldByName('number').AsInteger);
  AssertEquals('New participant',
    MainForm.MainDataset1.FieldByName('name').AsString);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS item_count FROM main WHERE number = :NUMBER ' +
    'AND name = :NAME;';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := participantNumber;
  MainForm.SQLQuery1.ParamByName('NAME').AsString := 'New participant';
  MainForm.SQLQuery1.Open;
  AssertEquals('The appended participant must be stored in SQLite', 1,
    MainForm.SQLQuery1.FieldByName('item_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  ParticipantStageValueEdit_SavesAndKeepsEditedRowCurrent;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(405);
  MainForm.MainDataset1.Locate('number', 405, []);

  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('starttime1').AsString := '10:00:00.000';
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('starttime1').AsString := '10:15:00.000';
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;

  AssertTrue('The main dataset must remain open after saving a stage value',
    MainForm.MainDataset1.Active);
  AssertEquals('The edited participant must remain current', 405,
    MainForm.MainDataset1.FieldByName('number').AsInteger);
  AssertEquals('10:15:00.000',
    MainForm.MainDataset1.FieldByName('starttime1').AsString);
end;

procedure TMainFlowIntegrationTests.ParticipantUnchangedStageField_CancelsEdit;
begin
  CreateEmptyCompetitionFixture(8);
  ConfigureSingleActiveStage(1);
  InsertParticipant(413);
  AssertTrue(MainForm.MainDataset1.Locate('number', 413, []));
  AssertTrue('Inactive stage fields must stay detached from the sparse query',
    MainForm.MainDataset1.FindField('penalty8') = nil);
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('penalty1').AsString :=
    MainForm.MainDataset1.FieldByName('penalty1').AsString;
  MainForm.StageFieldChanged(MainForm.MainDataset1.FieldByName('penalty1'));
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;

  AssertEquals('An unchanged edit must be cancelled',
    Ord(dsBrowse), Ord(MainForm.MainDataset1.State));

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT penalty8 FROM main WHERE number = 413;';
  MainForm.SQLQuery1.Open;
  AssertTrue('An unchanged inactive-stage value must remain NULL',
    MainForm.SQLQuery1.FieldByName('penalty8').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.CategoryEditor_LoadsCategoriesWithoutStatisticsDataset;
var
  editor: TWinControl;
begin
  CreateNewCompetitionFile;
  InsertParticipant(411);
  InsertParticipant(412);
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET category = ''Open'' WHERE number = 411;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET category = ''Masters'' WHERE number = 412;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  RefreshCompetitionViews;
  AssertTrue(MainForm.MainDataset1.Locate('number', 411, []));

  MainForm.StatDataset1.Close;
  editor := nil;
  MainForm.RxDBGrid1SelectEditor(MainForm.RxDBGrid1,
    MainForm.RxDBGrid1.ColumnByFieldName('category'), editor);

  AssertSame('Category column must use the category combo box',
    MainForm.ComboBox1Category, editor);
  AssertTrue('Open category must be available in the editor',
    MainForm.ComboBox1Category.Items.IndexOf('Open') >= 0);
  AssertTrue('Masters category must be available in the editor',
    MainForm.ComboBox1Category.Items.IndexOf('Masters') >= 0);
  AssertEquals('The current category must remain selected', 'Open',
    MainForm.ComboBox1Category.Text);
  AssertFalse('Category editor must not open the statistics dataset',
    MainForm.StatDataset1.Active);

  MainForm.ComboBox1Category.Text := 'Masters';
  MainForm.ComboBox1CategoryEditingDone(MainForm.ComboBox1Category);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT category FROM main WHERE number = 411;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Masters', MainForm.SQLQuery1.FieldByName('category').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.CorrectionEdit_UpdatesSelectedStageOnly;
begin
  CreateEmptyCompetitionFixture(2);
  ConfigureSingleActiveStage(2);
  MainForm.ConfigureCurrentStageDatasets;
  InsertParticipant(406);
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime2 = ''10:00:00.000'' WHERE number = 406;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.ConfigureCurrentStageDatasets;
  AssertTrue(MainForm.CorrectionDataset.Locate('number', 406, []));

  MainForm.CorrectionDataset.Edit;
  MainForm.CorrectionDataset.FieldByName('correction').AsInteger := 9;
  MainForm.CorrectionDataset.Post;
  MainForm.RxDBGridCorrectionEditingDone(MainForm.RxDBGridCorrection);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT correction1, correction2 FROM main WHERE number = 406;';
  MainForm.SQLQuery1.Open;
  AssertTrue('Editing stage 2 must not change stage 1 correction',
    MainForm.SQLQuery1.FieldByName('correction1').IsNull);
  AssertEquals(9,
    MainForm.SQLQuery1.FieldByName('correction2').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.CorrectionEdit_InvalidValueIsRejectedWithoutRollback;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(407);
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''10:00:00.000'' WHERE number = 407;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.CorrectionDataset.Close;
  MainForm.CorrectionDataset.SQL.Text := TDatasetSql.CorrectionPending(1);
  MainForm.CorrectionDataset.Open;
  AssertTrue(MainForm.CorrectionDataset.Locate('number', 407, []));

  AssertTrue('Correction must be a persistent integer field',
    MainForm.CorrectionDatasetcorrection is TLongintField);
  MainForm.CorrectionDataset.Edit;
  MainForm.CorrectionDatasetcorrection.Text := 'invalid';
  MainForm.RxDBGridCorrectionEditingDone(MainForm.RxDBGridCorrection);

  AssertEquals('Invalid correction must show one validation message',
    1, DialogCallCount);
  AssertEquals(rsIncorrectCorrection, LastDialogMessage);
  AssertEquals('Invalid correction must leave the dataset in browse state',
    Ord(dsBrowse), Ord(MainForm.CorrectionDataset.State));
  AssertTrue('Correction dataset must remain active after validation failure',
    MainForm.CorrectionDataset.Active);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT correction1 FROM main WHERE number = 407;';
  MainForm.SQLQuery1.Open;
  AssertTrue('Invalid correction must not be saved',
    MainForm.SQLQuery1.FieldByName('correction1').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  ParticipantDelete_RequiresConfirmationAndDeletesRow;
begin
  CreateNewCompetitionFile;
  InsertParticipant(403);
  MainForm.MainDataset1.Locate('number', 403, []);
  ConfirmationDialogResult := mrNo;
  MainForm.AcDeleteNumberExecute(MainForm.AcDeleteNumber);
  Application.ProcessMessages;
  AssertTrue('Cancelled deletion must keep the participant',
    MainForm.MainDataset1.Locate('number', 403, []));

  ConfirmationDialogResult := mrYes;
  DialogCallCount := 0;
  LastDialogMessage := '';
  MainForm.AcDeleteNumberExecute(MainForm.AcDeleteNumber);
  Application.ProcessMessages;
  AssertEquals('Unexpected dialog after confirmed deletion: ' +
    LastDialogMessage, 1, DialogCallCount);
  AssertMainRowCount(0);
end;

procedure TMainFlowIntegrationTests.ParticipantStatusTableEdit_NormalizesAndClearsSupportedValues;
begin
  CreateNewCompetitionFile;
  InsertParticipant(419);
  AssertTrue(MainForm.MainDataset1.Locate('number', 419, []));

  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1status.Text := 'dnf';
  AssertEquals('Text status must be normalized before saving', '2',
    MainForm.MainDataset1status.AsString);
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);

  AssertTrue(MainForm.MainDataset1.Locate('number', 419, []));
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1status.Text := ' 2 ';
  AssertEquals('Numeric status with surrounding whitespace must be accepted',
    '2', MainForm.MainDataset1status.AsString);
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);

  AssertTrue(MainForm.MainDataset1.Locate('number', 419, []));
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1status.Text := '';
  AssertTrue('Cleared status must be represented as NULL',
    MainForm.MainDataset1status.IsNull);
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT status FROM main WHERE number = 419;';
  MainForm.SQLQuery1.Open;
  AssertTrue('Cleared status must be stored as NULL in SQLite',
    MainForm.SQLQuery1.FieldByName('status').IsNull);
  MainForm.SQLQuery1.Close;
  AssertEquals('Supported status values must not show validation dialogs',
    0, DialogCallCount);
end;

procedure TMainFlowIntegrationTests.ParticipantStatusTableEdit_RejectsInvalidValue;
begin
  CreateNewCompetitionFile;
  InsertParticipant(420);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET status = ''2'' WHERE number = 420;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  RefreshCompetitionViews;
  AssertTrue(MainForm.MainDataset1.Locate('number', 420, []));
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1status.Text := 'retired';
  AssertEquals('Invalid status must leave the old field value intact', '2',
    MainForm.MainDataset1status.AsString);
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);

  AssertEquals('Invalid status must show one validation message',
    1, DialogCallCount);
  AssertEquals(rsParticipantStatusValueFormat, LastDialogMessage);
  AssertEquals('Invalid status must leave the dataset in browse state',
    Ord(dsBrowse), Ord(MainForm.MainDataset1.State));
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT status FROM main WHERE number = 420;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Invalid status must not be stored in SQLite', '2',
    MainForm.SQLQuery1.FieldByName('status').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  TimingStart_PersistsSourceAndStage;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 27);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT stage_index, source_kind, source_device_id, correction_ms, status ' +
    'FROM start_marks;';
  MainForm.SQLQuery1.Open;
  AssertEquals(1, MainForm.SQLQuery1.RecordCount);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('stage_index').AsInteger);
  AssertEquals('ble', MainForm.SQLQuery1.FieldByName('source_kind').AsString);
  AssertEquals('integration-test',
    MainForm.SQLQuery1.FieldByName('source_device_id').AsString);
  AssertEquals(27, MainForm.SQLQuery1.FieldByName('correction_ms').AsInteger);
  AssertEquals('pending', MainForm.SQLQuery1.FieldByName('status').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_ShowsEditableWorkQueueWithRestoredLayout;
begin
  AssertTrue(MainForm.Splitter2.Visible);
  AssertTrue(MainForm.PanelStartMarks.Visible);
  AssertEquals(5, MainForm.Splitter2.Height);
  AssertTrue('The restored panel must keep at least its former 217 px height',
    MainForm.PanelStartMarks.Height >= 217);
  AssertTrue('The restored grid must keep at least its former 133 px height',
    MainForm.RxDBGridStartMarks.Height >= 133);
  AssertEquals(MainForm.Splitter2.Top + MainForm.Splitter2.Height,
    MainForm.PanelStartMarks.Top);
  AssertEquals(MainForm.EditPanel.ClientHeight,
    MainForm.PanelStartMarks.Top + MainForm.PanelStartMarks.Height);
  AssertEquals(3, MainForm.RxDBGridStartMarks.Columns.Count);
  AssertEquals('event_time',
    MainForm.RxDBGridStartMarks.Columns[0].FieldName);
  AssertEquals('correction_ms',
    MainForm.RxDBGridStartMarks.Columns[1].FieldName);
  AssertEquals('participant_number',
    MainForm.RxDBGridStartMarks.Columns[2].FieldName);
  AssertTrue(MainForm.RxDBGridStartMarks.Columns[0].ReadOnly);
  AssertTrue(MainForm.RxDBGridStartMarks.Columns[1].ReadOnly);
  AssertFalse(MainForm.RxDBGridStartMarks.Columns[2].ReadOnly);
  AssertTrue('The start work queue must not append empty records',
    dgDisableInsert in MainForm.RxDBGridStartMarks.Options);
  AssertEquals(rsTime,
    MainForm.RxDBGridStartMarks.Columns[0].Title.Caption);
  AssertEquals(rsCorrection,
    MainForm.RxDBGridStartMarks.Columns[1].Title.Caption);
  AssertEquals(rsNumber,
    MainForm.RxDBGridStartMarks.Columns[2].Title.Caption);
  AssertEquals(rsClear, MainForm.ButtonStartMarksClear.Caption);
  AssertFalse(MainForm.ButtonStartMarksClear.Enabled);
  AssertSame(MainForm.AcClearStartMarks,
    MainForm.ButtonStartMarksClear.Action);
  AssertSame(MainForm.AcApplyStartMarks,
    MainForm.ButtonApplyStartMarks.Action);
  AssertTrue(MainForm.ButtonApplyStartMarks.Left >=
    MainForm.ButtonStartMarksClear.Left +
    MainForm.ButtonStartMarksClear.Width);
  AssertEquals(MainForm.ButtonStartMarksClear.Top,
    MainForm.ButtonApplyStartMarks.Top);
  AssertFalse(MainForm.ButtonApplyStartMarks.Enabled);
  AssertSame(MainForm.PopupMenuStartMarks,
    MainForm.RxDBGridStartMarks.PopupMenu);
  AssertEquals(1, MainForm.PopupMenuStartMarks.Items.Count);
  AssertSame(MainForm.AcOpenStartMarkJournal,
    MainForm.PopupMenuStartMarks.Items[0].Action);
  AssertEquals(rsOpenStartMarksWindow,
    MainForm.AcOpenStartMarkJournal.Caption);
  AssertEquals(rsOpenStartMarksWindowHint,
    MainForm.AcOpenStartMarkJournal.Hint);
  AssertEquals(Trim(TStartMarkSql.SelectWorkQueue),
    Trim(MainForm.DatasetStartMarks.SQL.Text));
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_NumberEditPersistsWithoutApplying;
const
  PARTICIPANT_NUMBER = 731;
var
  MarkId: int64;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 27);

  AssertEquals(1, MainForm.DatasetStartMarks.RecordCount);
  MarkId := MainForm.DatasetStartMarks.FieldByName('id').AsLargeInt;
  MainForm.DatasetStartMarks.Edit;
  MainForm.DatasetStartMarks.FieldByName('participant_number').AsInteger :=
    PARTICIPANT_NUMBER;
  MainForm.DatasetStartMarks.Post;
  MainForm.RxDBGridStartMarksEditingDone(MainForm.RxDBGridStartMarks);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT participant_number, status, applied_stage_index, assignment_mode ' +
    'FROM start_marks WHERE id = :ID;';
  MainForm.SQLQuery1.ParamByName('ID').AsLargeInt := MarkId;
  MainForm.SQLQuery1.Open;
  AssertEquals(PARTICIPANT_NUMBER,
    MainForm.SQLQuery1.FieldByName('participant_number').AsInteger);
  AssertEquals('pending', MainForm.SQLQuery1.FieldByName('status').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('applied_stage_index').IsNull);
  AssertTrue(MainForm.SQLQuery1.FieldByName('assignment_mode').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_DoubleClickWithoutNumberDoesNothing;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 27);

  DialogCallCount := 0;
  MainForm.RxDBGridStartMarksDblClick(MainForm.RxDBGridStartMarks);

  AssertEquals(0, DialogCallCount);
  AssertEquals(0, StartMarkStageChoiceCallCount);
  MainForm.AcApplyStartMarksUpdate(MainForm.AcApplyStartMarks);
  AssertFalse(MainForm.AcApplyStartMarks.Enabled);
  AssertEquals(1, MainForm.DatasetStartMarks.RecordCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text := 'SELECT status FROM start_marks;';
  MainForm.SQLQuery1.Open;
  AssertEquals('pending', MainForm.SQLQuery1.FieldByName('status').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_DoubleClickAppliesToReceivedStage;
const
  PARTICIPANT_NUMBER = 732;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(PARTICIPANT_NUMBER);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 27);
  MainForm.DatasetStartMarks.Edit;
  MainForm.DatasetStartMarks.FieldByName('participant_number').AsInteger :=
    PARTICIPANT_NUMBER;
  MainForm.DatasetStartMarks.Post;
  MainForm.RxDBGridStartMarksEditingDone(MainForm.RxDBGridStartMarks);

  MainForm.RxDBGridStartMarksDblClick(MainForm.RxDBGridStartMarks);

  AssertTrue(MainForm.DatasetStartMarks.IsEmpty);
  AssertEquals(0, StartMarkStageChoiceCallCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT m.correction1, s.stage_index, s.applied_stage_index, ' +
    's.assignment_mode, s.status FROM main m JOIN start_marks s ' +
    'ON s.participant_number = m.number WHERE m.number = :NUMBER;';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := PARTICIPANT_NUMBER;
  MainForm.SQLQuery1.Open;
  AssertEquals(27, MainForm.SQLQuery1.FieldByName('correction1').AsInteger);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('stage_index').AsInteger);
  AssertEquals(1,
    MainForm.SQLQuery1.FieldByName('applied_stage_index').AsInteger);
  AssertEquals('manual',
    MainForm.SQLQuery1.FieldByName('assignment_mode').AsString);
  AssertEquals('applied', MainForm.SQLQuery1.FieldByName('status').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_DifferentStageCanBeCancelled;
const
  PARTICIPANT_NUMBER = 733;
begin
  CreateEmptyCompetitionFixture(2);
  stages[1].isActive := True;
  stages[2].isActive := True;
  ApplyStageActivityToUi(1);
  MainForm.SelectCurrentStage(1);
  InsertParticipant(PARTICIPANT_NUMBER);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 27);
  MainForm.DatasetStartMarks.Edit;
  MainForm.DatasetStartMarks.FieldByName('participant_number').AsInteger :=
    PARTICIPANT_NUMBER;
  MainForm.DatasetStartMarks.Post;
  MainForm.RxDBGridStartMarksEditingDone(MainForm.RxDBGridStartMarks);
  MainForm.SelectCurrentStage(2);
  StartMarkStageChoiceResult := smscCancel;

  MainForm.RxDBGridStartMarksDblClick(MainForm.RxDBGridStartMarks);

  AssertEquals(1, StartMarkStageChoiceCallCount);
  AssertTrue(Pos(IntToStr(PARTICIPANT_NUMBER),
    LastStartMarkStageChoiceMessage) > 0);
  AssertTrue(Pos('1', LastStartMarkStageChoiceMessage) > 0);
  AssertTrue(Pos('2', LastStartMarkStageChoiceMessage) > 0);
  AssertEquals(1, MainForm.DatasetStartMarks.RecordCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT correction1, correction2 FROM main WHERE number = :NUMBER;';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := PARTICIPANT_NUMBER;
  MainForm.SQLQuery1.Open;
  AssertTrue(MainForm.SQLQuery1.FieldByName('correction1').IsNull);
  AssertTrue(MainForm.SQLQuery1.FieldByName('correction2').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_DifferentStageCanApplyToCurrentStage;
const
  PARTICIPANT_NUMBER = 734;
begin
  CreateEmptyCompetitionFixture(2);
  stages[1].isActive := True;
  stages[2].isActive := True;
  ApplyStageActivityToUi(1);
  MainForm.SelectCurrentStage(1);
  InsertParticipant(PARTICIPANT_NUMBER);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 31);
  MainForm.DatasetStartMarks.Edit;
  MainForm.DatasetStartMarks.FieldByName('participant_number').AsInteger :=
    PARTICIPANT_NUMBER;
  MainForm.DatasetStartMarks.Post;
  MainForm.RxDBGridStartMarksEditingDone(MainForm.RxDBGridStartMarks);
  MainForm.SelectCurrentStage(2);
  StartMarkStageChoiceResult := smscCurrentStage;

  MainForm.RxDBGridStartMarksDblClick(MainForm.RxDBGridStartMarks);

  AssertEquals(1, StartMarkStageChoiceCallCount);
  AssertTrue(MainForm.DatasetStartMarks.IsEmpty);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT m.correction1, m.correction2, s.stage_index, ' +
    's.applied_stage_index FROM main m JOIN start_marks s ' +
    'ON s.participant_number = m.number WHERE m.number = :NUMBER;';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := PARTICIPANT_NUMBER;
  MainForm.SQLQuery1.Open;
  AssertTrue(MainForm.SQLQuery1.FieldByName('correction1').IsNull);
  AssertEquals(31, MainForm.SQLQuery1.FieldByName('correction2').AsInteger);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('stage_index').AsInteger);
  AssertEquals(2,
    MainForm.SQLQuery1.FieldByName('applied_stage_index').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_DifferentStageCanApplyToReceivedStage;
const
  PARTICIPANT_NUMBER = 736;
begin
  CreateEmptyCompetitionFixture(2);
  stages[1].isActive := True;
  stages[2].isActive := True;
  ApplyStageActivityToUi(1);
  MainForm.SelectCurrentStage(1);
  InsertParticipant(PARTICIPANT_NUMBER);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 33);
  MainForm.DatasetStartMarks.Edit;
  MainForm.DatasetStartMarks.FieldByName('participant_number').AsInteger :=
    PARTICIPANT_NUMBER;
  MainForm.DatasetStartMarks.Post;
  MainForm.RxDBGridStartMarksEditingDone(MainForm.RxDBGridStartMarks);
  MainForm.SelectCurrentStage(2);
  StartMarkStageChoiceResult := smscReceivedStage;

  MainForm.RxDBGridStartMarksDblClick(MainForm.RxDBGridStartMarks);

  AssertEquals(1, StartMarkStageChoiceCallCount);
  AssertTrue(MainForm.DatasetStartMarks.IsEmpty);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT m.correction1, m.correction2, s.stage_index, ' +
    's.applied_stage_index FROM main m JOIN start_marks s ' +
    'ON s.participant_number = m.number WHERE m.number = :NUMBER;';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := PARTICIPANT_NUMBER;
  MainForm.SQLQuery1.Open;
  AssertEquals(33, MainForm.SQLQuery1.FieldByName('correction1').AsInteger);
  AssertTrue(MainForm.SQLQuery1.FieldByName('correction2').IsNull);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('stage_index').AsInteger);
  AssertEquals(1,
    MainForm.SQLQuery1.FieldByName('applied_stage_index').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_ExistingCorrectionRequiresConfirmation;
const
  PARTICIPANT_NUMBER = 735;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(PARTICIPANT_NUMBER);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET correction1 = 19 WHERE number = :NUMBER;';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := PARTICIPANT_NUMBER;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 37);
  MainForm.DatasetStartMarks.Edit;
  MainForm.DatasetStartMarks.FieldByName('participant_number').AsInteger :=
    PARTICIPANT_NUMBER;
  MainForm.DatasetStartMarks.Post;
  MainForm.RxDBGridStartMarksEditingDone(MainForm.RxDBGridStartMarks);
  ConfirmationDialogResult := mrNo;
  DialogCallCount := 0;

  MainForm.RxDBGridStartMarksDblClick(MainForm.RxDBGridStartMarks);

  AssertEquals(1, DialogCallCount);
  AssertTrue(Pos(IntToStr(PARTICIPANT_NUMBER), LastDialogMessage) > 0);
  AssertEquals(1, MainForm.DatasetStartMarks.RecordCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT correction1 FROM main WHERE number = :NUMBER;';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := PARTICIPANT_NUMBER;
  MainForm.SQLQuery1.Open;
  AssertEquals(19, MainForm.SQLQuery1.FieldByName('correction1').AsInteger);
  MainForm.SQLQuery1.Close;

  ConfirmationDialogResult := mrYes;
  MainForm.RxDBGridStartMarksDblClick(MainForm.RxDBGridStartMarks);

  AssertEquals(2, DialogCallCount);
  AssertTrue(MainForm.DatasetStartMarks.IsEmpty);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT correction1 FROM main WHERE number = :NUMBER;';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := PARTICIPANT_NUMBER;
  MainForm.SQLQuery1.Open;
  AssertEquals(37, MainForm.SQLQuery1.FieldByName('correction1').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_CtrlEnterWritesOnlyWhenFocused;
var
  Key: word;
  WasMainFormVisible: boolean;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(739);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 39);
  MainForm.DatasetStartMarks.Edit;
  MainForm.DatasetStartMarks.FieldByName('participant_number').AsInteger :=
    739;
  MainForm.AcApplyStartMarksUpdate(MainForm.AcApplyStartMarks);
  AssertTrue(MainForm.AcApplyStartMarks.Enabled);
  AssertEquals('The start action must not expose a form-wide shortcut',
    0, MainForm.AcApplyStartMarks.ShortCut);

  WasMainFormVisible := MainForm.Visible;
  if not WasMainFormVisible then
  begin
    MainForm.Show;
    Application.ProcessMessages;
  end;
  try
    MainForm.ButtonApplyStartMarks.SetFocus;
    Key := VK_RETURN;
    MainForm.FormKeyDown(MainForm, Key, [ssCtrl]);
    AssertEquals('Ctrl+Enter outside the start marks grid must remain ' +
      'unhandled', VK_RETURN, Key);
    AssertEquals(1, MainForm.DatasetStartMarks.RecordCount);

    MainForm.RxDBGridStartMarks.SetFocus;
    Application.ProcessMessages;
    AssertTrue('The start marks grid must own the active control',
      MainForm.RxDBGridStartMarks.ContainsControl(MainForm.ActiveControl));

    Key := VK_RETURN;
    MainForm.FormKeyDown(MainForm, Key, []);
    AssertEquals('Enter must remain available to the start grid editor',
      VK_RETURN, Key);
    AssertEquals(1, MainForm.DatasetStartMarks.RecordCount);

    Key := VK_RETURN;
    MainForm.FormKeyDown(MainForm, Key, [ssCtrl]);
    AssertEquals('Ctrl+Enter must not reach the start grid editor', 0, Key);
    AssertTrue('Ctrl+Enter must apply the numbered start mark',
      MainForm.DatasetStartMarks.IsEmpty);
    MainForm.SQLQuery1.Close;
    MainForm.SQLQuery1.SQL.Text :=
      'SELECT correction1 FROM main WHERE number = 739;';
    MainForm.SQLQuery1.Open;
    AssertEquals(39, MainForm.SQLQuery1.FieldByName('correction1').AsInteger);
    MainForm.SQLQuery1.Close;
  finally
    if not WasMainFormVisible then
      MainForm.Hide;
  end;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_WriteCommitsCurrentNumberEdit;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(740);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 40);
  MainForm.DatasetStartMarks.Edit;
  MainForm.DatasetStartMarks.FieldByName('participant_number').AsInteger :=
    740;

  MainForm.AcApplyStartMarksExecute(MainForm.AcApplyStartMarks);

  AssertTrue(MainForm.DatasetStartMarks.IsEmpty);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT correction1 FROM main WHERE number = 740;';
  MainForm.SQLQuery1.Open;
  AssertEquals(40, MainForm.SQLQuery1.FieldByName('correction1').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_WriteAppliesEveryNumberedRow;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(741);
  InsertParticipant(742);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 41);
  ApplyStartPacketAt(EncodeTime(10, 0, 1, 0), True, 42);
  ApplyStartPacketAt(EncodeTime(10, 0, 2, 0), True, 43);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE start_marks SET participant_number = CASE correction_ms ' +
    'WHEN 41 THEN 741 WHEN 43 THEN 742 ELSE NULL END;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;
  MainForm.CompetitionDb.RefreshQuery(MainForm.DatasetStartMarks);

  MainForm.AcApplyStartMarksUpdate(MainForm.AcApplyStartMarks);

  AssertTrue(MainForm.AcApplyStartMarks.Enabled);
  AssertEquals(rsWrite, MainForm.AcApplyStartMarks.Caption);
  MainForm.ButtonApplyStartMarks.Click;

  AssertEquals(1, MainForm.DatasetStartMarks.RecordCount);
  AssertTrue(MainForm.DatasetStartMarks.FieldByName(
    'participant_number').IsNull);
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, correction1 FROM main WHERE number IN (741, 742) ' +
    'ORDER BY number;';
  MainForm.SQLQuery1.Open;
  AssertEquals(41, MainForm.SQLQuery1.FieldByName('correction1').AsInteger);
  MainForm.SQLQuery1.Next;
  AssertEquals(43, MainForm.SQLQuery1.FieldByName('correction1').AsInteger);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS applied_count FROM start_marks ' +
    'WHERE status = ''applied'';';
  MainForm.SQLQuery1.Open;
  AssertEquals(2,
    MainForm.SQLQuery1.FieldByName('applied_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_WriteContinuesAfterStageChoiceCancellation;
begin
  CreateEmptyCompetitionFixture(2);
  stages[1].isActive := True;
  stages[2].isActive := True;
  ApplyStageActivityToUi(1);
  InsertParticipant(751);
  InsertParticipant(752);
  MainForm.SelectCurrentStage(1);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 51);
  MainForm.SelectCurrentStage(2);
  ApplyStartPacketAt(EncodeTime(10, 0, 1, 0), True, 52);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE start_marks SET participant_number = CASE correction_ms ' +
    'WHEN 51 THEN 751 WHEN 52 THEN 752 END;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;
  MainForm.CompetitionDb.RefreshQuery(MainForm.DatasetStartMarks);
  StartMarkStageChoiceResult := smscCancel;

  MainForm.AcApplyStartMarksUpdate(MainForm.AcApplyStartMarks);
  MainForm.ButtonApplyStartMarks.Click;

  AssertEquals(1, StartMarkStageChoiceCallCount);
  AssertEquals(1, MainForm.DatasetStartMarks.RecordCount);
  AssertEquals(751, MainForm.DatasetStartMarks.FieldByName(
    'participant_number').AsInteger);
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, correction1, correction2 FROM main ' +
    'WHERE number IN (751, 752) ORDER BY number;';
  MainForm.SQLQuery1.Open;
  AssertTrue(MainForm.SQLQuery1.FieldByName('correction1').IsNull);
  AssertTrue(MainForm.SQLQuery1.FieldByName('correction2').IsNull);
  MainForm.SQLQuery1.Next;
  AssertTrue(MainForm.SQLQuery1.FieldByName('correction1').IsNull);
  AssertEquals(52, MainForm.SQLQuery1.FieldByName('correction2').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkPanel_ClearSoftHidesEntireWorkQueue;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 61);
  ApplyStartPacketAt(EncodeTime(10, 0, 1, 0), True, 62);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE start_marks SET status = ''conflict'', ' +
    'diagnostic = ''test conflict'' WHERE correction_ms = 62;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;
  MainForm.CompetitionDb.RefreshQuery(MainForm.DatasetStartMarks);

  MainForm.AcClearStartMarksUpdate(MainForm.AcClearStartMarks);

  AssertTrue(MainForm.ButtonStartMarksClear.Enabled);
  MainForm.ButtonStartMarksClear.Click;

  AssertTrue(MainForm.DatasetStartMarks.IsEmpty);
  MainForm.AcClearStartMarksUpdate(MainForm.AcClearStartMarks);
  AssertFalse(MainForm.ButtonStartMarksClear.Enabled);
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS total_count, ' +
    'SUM(CASE WHEN status = ''hidden'' THEN 1 ELSE 0 END) AS hidden_count ' +
    'FROM start_marks;';
  MainForm.SQLQuery1.Open;
  AssertEquals(2, MainForm.SQLQuery1.FieldByName('total_count').AsInteger);
  AssertEquals(2, MainForm.SQLQuery1.FieldByName('hidden_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  StartMarkJournal_ShowsAllStatusesNewestFirstAndReadOnly;
var
  Form: TStartMarksForm;
  FirstId, SecondId: int64;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(701);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''10:00:03.000'' WHERE number = 701;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 71);
  ApplyStartPacketAt(EncodeTime(10, 0, 1, 0), True, 72);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT id FROM start_marks ORDER BY id;';
  MainForm.SQLQuery1.Open;
  FirstId := MainForm.SQLQuery1.FieldByName('id').AsLargeInt;
  MainForm.SQLQuery1.Next;
  SecondId := MainForm.SQLQuery1.FieldByName('id').AsLargeInt;
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE start_marks SET status = ''hidden'' WHERE id = :ID;';
  MainForm.SQLQuery1.ParamByName('ID').AsLargeInt := FirstId;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;

  Form := TStartMarksForm.Create(Application);
  try
    AssertEquals(rsStartMarks, Form.Caption);
    AssertEquals(rsStartMarkJournalFilter, Form.LabelJournalFilter.Caption);
    AssertEquals(7, Form.ComboBoxJournalFilter.Items.Count);
    AssertEquals(rsStartMarkJournalFilterAll,
      Form.ComboBoxJournalFilter.Items[0]);
    AssertEquals(rsStartMarkJournalFilterCurrentStage,
      Form.ComboBoxJournalFilter.Items[6]);
    AssertTrue(Form.StartMarksDataset.ReadOnly);
    AssertTrue(Form.RxDBGridStartMarks.ReadOnly);
    AssertFalse(dgEditing in Form.RxDBGridStartMarks.Options);
    AssertEquals(14, Form.RxDBGridStartMarks.Columns.Count);
    AssertEquals('id', Form.RxDBGridStartMarks.Columns[0].FieldName);
    AssertEquals('stage_index',
      Form.RxDBGridStartMarks.Columns[1].FieldName);
    AssertEquals('applied_stage_index',
      Form.RxDBGridStartMarks.Columns[2].FieldName);
    AssertEquals('event_time',
      Form.RxDBGridStartMarks.Columns[3].FieldName);
    AssertEquals('correction_ms',
      Form.RxDBGridStartMarks.Columns[4].FieldName);
    AssertEquals('participant_number',
      Form.RxDBGridStartMarks.Columns[5].FieldName);
    AssertEquals('match_delta_ms',
      Form.RxDBGridStartMarks.Columns[6].FieldName);
    AssertEquals('source_kind',
      Form.RxDBGridStartMarks.Columns[7].FieldName);
    AssertEquals('source_device_id',
      Form.RxDBGridStartMarks.Columns[8].FieldName);
    AssertEquals('assignment_mode',
      Form.RxDBGridStartMarks.Columns[9].FieldName);
    AssertEquals('status',
      Form.RxDBGridStartMarks.Columns[10].FieldName);
    AssertEquals('received_at',
      Form.RxDBGridStartMarks.Columns[11].FieldName);
    AssertEquals('applied_at',
      Form.RxDBGridStartMarks.Columns[12].FieldName);
    AssertEquals('diagnostic',
      Form.RxDBGridStartMarks.Columns[13].FieldName);
    AssertEquals(2, Form.StartMarksDataset.RecordCount);
    AssertEquals(SecondId,
      Form.StartMarksDataset.FieldByName('id').AsLargeInt);
    AssertEquals('pending',
      Form.StartMarksDataset.FieldByName('status').AsString);
    AssertEquals(701,
      Form.StartMarksDataset.FieldByName('participant_number').AsInteger);
    AssertEquals(2000,
      Form.StartMarksDataset.FieldByName('match_delta_ms').AsInteger);
    AssertEquals('ble',
      Form.StartMarksDataset.FieldByName('source_kind').AsString);
    AssertEquals('integration-test',
      Form.StartMarksDataset.FieldByName('source_device_id').AsString);
    Form.StartMarksDataset.Next;
    AssertEquals(FirstId,
      Form.StartMarksDataset.FieldByName('id').AsLargeInt);
    AssertEquals('hidden',
      Form.StartMarksDataset.FieldByName('status').AsString);
  finally
    Form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.
  StartMarkJournal_FiltersAndRefreshesPreservingSelection;
var
  FirstId: int64;
  Form: TStartMarksForm;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 81);
  ApplyStartPacketAt(EncodeTime(10, 0, 1, 0), True, 82);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT id FROM start_marks ORDER BY id;';
  MainForm.SQLQuery1.Open;
  FirstId := MainForm.SQLQuery1.FieldByName('id').AsLargeInt;
  MainForm.SQLQuery1.Close;

  Form := TStartMarksForm.Create(Application);
  try
    AssertTrue(Form.StartMarksDataset.Locate('id', FirstId, []));

    ApplyStartPacketAt(EncodeTime(10, 0, 2, 0), True, 83);

    AssertEquals(3, Form.StartMarksDataset.RecordCount);
    AssertEquals(FirstId,
      Form.StartMarksDataset.FieldByName('id').AsLargeInt);

    MainForm.SQLQuery1.SQL.Text :=
      'UPDATE start_marks SET status = ''hidden'' WHERE id = :ID;';
    MainForm.SQLQuery1.ParamByName('ID').AsLargeInt := FirstId;
    MainForm.SQLQuery1.ExecSQL;
    MainForm.SQLQuery1.SQLTransaction.Commit;
    MainForm.SQLQuery1.Close;
    Form.ComboBoxJournalFilter.ItemIndex := Ord(smjfHidden);
    Form.ComboBoxJournalFilterChange(Form.ComboBoxJournalFilter);

    AssertEquals(1, Form.StartMarksDataset.RecordCount);
    AssertEquals('hidden',
      Form.StartMarksDataset.FieldByName('status').AsString);

    Form.ComboBoxJournalFilter.ItemIndex := Ord(smjfCurrentStage);
    Form.ComboBoxJournalFilterChange(Form.ComboBoxJournalFilter);
    AssertEquals(3, Form.StartMarksDataset.RecordCount);
  finally
    Form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.
  StartMarkJournal_DiagnosticPreviewCopyAndViewerUseFullText;
var
  DiagnosticField: TField;
  DiagnosticText, ExpectedPreview: string;
  Form: TTestStartMarksForm;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 84);
  DiagnosticText := StringOfChar('A', 60) + LineEnding +
    StringOfChar('B', 70) + ' complete diagnostic';
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE start_marks SET diagnostic = :DIAGNOSTIC;';
  MainForm.SQLQuery1.ParamByName('DIAGNOSTIC').AsString := DiagnosticText;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;

  Form := TTestStartMarksForm.Create(Application);
  try
    DiagnosticField := Form.StartMarksDataset.FieldByName('diagnostic');
    AssertTrue(DiagnosticField is TMemoField);
    ExpectedPreview := StringOfChar('A', 60) + ' ' +
      StringOfChar('B', 59) + '...';
    AssertEquals(ExpectedPreview, DiagnosticField.DisplayText);
    AssertEquals(DiagnosticText, DiagnosticField.AsString);

    Form.RxDBGridStartMarks.SelectedIndex := 13;
    Clipboard.AsText := '';
    Form.AcCopyExecute(Form.AcCopy);
    AssertEquals(DiagnosticText, Clipboard.AsText);

    Form.RxDBGridStartMarksDblClick(Form.RxDBGridStartMarks);
    AssertEquals(DiagnosticText, Form.ShownDiagnostic);
  finally
    Form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.
  FinishMarkJournal_ShowsAllStatusesNewestFirstAndReadOnly;
var
  FirstId, SecondId, ThirdId, FourthId, FifthId: int64;
  Form: TFinishMarksForm;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyFinishPacketAt(EncodeTime(10, 0, 0, 0));
  ApplyFinishPacketAt(EncodeTime(10, 0, 0, 100));
  ApplyFinishPacketAt(EncodeTime(10, 0, 1, 0));
  ApplyFinishPacketAt(EncodeTime(10, 0, 2, 0));
  ApplyFinishPacketAt(EncodeTime(10, 0, 3, 0));
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT id FROM finish_marks ORDER BY id;';
  MainForm.SQLQuery1.Open;
  FirstId := MainForm.SQLQuery1.FieldByName('id').AsLargeInt;
  MainForm.SQLQuery1.Next;
  SecondId := MainForm.SQLQuery1.FieldByName('id').AsLargeInt;
  MainForm.SQLQuery1.Next;
  ThirdId := MainForm.SQLQuery1.FieldByName('id').AsLargeInt;
  MainForm.SQLQuery1.Next;
  FourthId := MainForm.SQLQuery1.FieldByName('id').AsLargeInt;
  MainForm.SQLQuery1.Next;
  FifthId := MainForm.SQLQuery1.FieldByName('id').AsLargeInt;
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE finish_marks SET status = ''applied'', ' +
    'participant_number = 701, assignment_mode = ''manual'', ' +
    'applied_at = received_at WHERE id = :FIRST_ID;';
  MainForm.SQLQuery1.ParamByName('FIRST_ID').AsLargeInt := FirstId;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE finish_marks SET status = ''hidden'' WHERE id = :THIRD_ID;';
  MainForm.SQLQuery1.ParamByName('THIRD_ID').AsLargeInt := ThirdId;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE finish_marks SET status = ''error'', ' +
    'diagnostic = ''test error'' WHERE id = :FOURTH_ID;';
  MainForm.SQLQuery1.ParamByName('FOURTH_ID').AsLargeInt := FourthId;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;

  Form := TFinishMarksForm.Create(Application);
  try
    AssertEquals(rsFinishMarks, Form.Caption);
    AssertEquals(rsFinishMarkJournalFilter,
      Form.LabelJournalFilter.Caption);
    AssertEquals(8, Form.ComboBoxJournalFilter.Items.Count);
    AssertEquals(rsFinishMarkJournalFilterAll,
      Form.ComboBoxJournalFilter.Items[0]);
    AssertEquals(rsFinishMarkJournalFilterCurrentStage,
      Form.ComboBoxJournalFilter.Items[7]);
    AssertTrue(Form.FinishMarksDataset.ReadOnly);
    AssertTrue(Form.RxDBGridFinishMarks.ReadOnly);
    AssertFalse(dgEditing in Form.RxDBGridFinishMarks.Options);
    AssertEquals(11, Form.RxDBGridFinishMarks.Columns.Count);
    AssertEquals('id', Form.RxDBGridFinishMarks.Columns[0].FieldName);
    AssertEquals('stage_index',
      Form.RxDBGridFinishMarks.Columns[1].FieldName);
    AssertEquals('event_time',
      Form.RxDBGridFinishMarks.Columns[2].FieldName);
    AssertEquals('participant_number',
      Form.RxDBGridFinishMarks.Columns[3].FieldName);
    AssertEquals('source_kind',
      Form.RxDBGridFinishMarks.Columns[4].FieldName);
    AssertEquals('source_device_id',
      Form.RxDBGridFinishMarks.Columns[5].FieldName);
    AssertEquals('assignment_mode',
      Form.RxDBGridFinishMarks.Columns[6].FieldName);
    AssertEquals('status',
      Form.RxDBGridFinishMarks.Columns[7].FieldName);
    AssertEquals('received_at',
      Form.RxDBGridFinishMarks.Columns[8].FieldName);
    AssertEquals('applied_at',
      Form.RxDBGridFinishMarks.Columns[9].FieldName);
    AssertEquals('diagnostic',
      Form.RxDBGridFinishMarks.Columns[10].FieldName);
    AssertEquals(5, Form.FinishMarksDataset.RecordCount);
    AssertEquals(FifthId,
      Form.FinishMarksDataset.FieldByName('id').AsLargeInt);
    AssertEquals('pending',
      Form.FinishMarksDataset.FieldByName('status').AsString);
    Form.FinishMarksDataset.Next;
    AssertEquals(FourthId,
      Form.FinishMarksDataset.FieldByName('id').AsLargeInt);
    AssertEquals('error',
      Form.FinishMarksDataset.FieldByName('status').AsString);
    Form.FinishMarksDataset.Next;
    AssertEquals(ThirdId,
      Form.FinishMarksDataset.FieldByName('id').AsLargeInt);
    AssertEquals('hidden',
      Form.FinishMarksDataset.FieldByName('status').AsString);
    Form.FinishMarksDataset.Next;
    AssertEquals(SecondId,
      Form.FinishMarksDataset.FieldByName('id').AsLargeInt);
    AssertEquals('ignored_debounce',
      Form.FinishMarksDataset.FieldByName('status').AsString);
    Form.FinishMarksDataset.Next;
    AssertEquals(FirstId,
      Form.FinishMarksDataset.FieldByName('id').AsLargeInt);
    AssertEquals('applied',
      Form.FinishMarksDataset.FieldByName('status').AsString);
    AssertEquals('serial',
      Form.FinishMarksDataset.FieldByName('source_kind').AsString);
    AssertEquals('integration-test',
      Form.FinishMarksDataset.FieldByName('source_device_id').AsString);

    AssertSame(MainForm.PopupMenuFinishMarks,
      MainForm.RxDBGridFinishMarks.PopupMenu);
    AssertEquals(1, MainForm.PopupMenuFinishMarks.Items.Count);
    AssertSame(MainForm.AcOpenFinishMarkJournal,
      MainForm.PopupMenuFinishMarks.Items[0].Action);
    AssertEquals(rsOpenFinishMarksWindow,
      MainForm.AcOpenFinishMarkJournal.Caption);
    AssertEquals(rsOpenFinishMarksWindowHint,
      MainForm.AcOpenFinishMarkJournal.Hint);
  finally
    Form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.
  FinishMarkJournal_FiltersAndRefreshesPreservingSelection;
var
  FirstId: int64;
  Form: TFinishMarksForm;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyFinishPacketAt(EncodeTime(10, 0, 0, 0));
  ApplyFinishPacketAt(EncodeTime(10, 0, 1, 0));
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT id FROM finish_marks ORDER BY id;';
  MainForm.SQLQuery1.Open;
  FirstId := MainForm.SQLQuery1.FieldByName('id').AsLargeInt;
  MainForm.SQLQuery1.Close;

  Form := TFinishMarksForm.Create(Application);
  try
    AssertTrue(Form.FinishMarksDataset.Locate('id', FirstId, []));

    ApplyFinishPacketAt(EncodeTime(10, 0, 2, 0));

    AssertEquals(3, Form.FinishMarksDataset.RecordCount);
    AssertEquals(FirstId,
      Form.FinishMarksDataset.FieldByName('id').AsLargeInt);

    MainForm.SQLQuery1.SQL.Text :=
      'UPDATE finish_marks SET status = ''hidden'' WHERE id = :ID;';
    MainForm.SQLQuery1.ParamByName('ID').AsLargeInt := FirstId;
    MainForm.SQLQuery1.ExecSQL;
    MainForm.SQLQuery1.SQLTransaction.Commit;
    MainForm.SQLQuery1.Close;
    Form.ComboBoxJournalFilter.ItemIndex := Ord(fmjfHidden);
    Form.ComboBoxJournalFilterChange(Form.ComboBoxJournalFilter);

    AssertEquals(1, Form.FinishMarksDataset.RecordCount);
    AssertEquals('hidden',
      Form.FinishMarksDataset.FieldByName('status').AsString);

    Form.ComboBoxJournalFilter.ItemIndex := Ord(fmjfCurrentStage);
    Form.ComboBoxJournalFilterChange(Form.ComboBoxJournalFilter);
    AssertEquals(3, Form.FinishMarksDataset.RecordCount);

    Form.Free;
    Form := nil;
    AssertFalse(Assigned(MainForm.FinishMarkService.OnChanged));
    ApplyFinishPacketAt(EncodeTime(10, 0, 3, 0));
  finally
    Form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.
  FinishMarkJournal_DiagnosticPreviewCopyAndViewerUseFullText;
var
  DiagnosticField: TField;
  DiagnosticText, ExpectedPreview: string;
  Form: TTestFinishMarksForm;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyFinishPacketAt(EncodeTime(10, 0, 0, 0));
  DiagnosticText := StringOfChar('A', 60) + LineEnding +
    StringOfChar('B', 70) + ' complete diagnostic';
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE finish_marks SET diagnostic = :DIAGNOSTIC;';
  MainForm.SQLQuery1.ParamByName('DIAGNOSTIC').AsString := DiagnosticText;
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;

  Form := TTestFinishMarksForm.Create(Application);
  try
    DiagnosticField := Form.FinishMarksDataset.FieldByName('diagnostic');
    AssertTrue(DiagnosticField is TMemoField);
    ExpectedPreview := StringOfChar('A', 60) + ' ' +
      StringOfChar('B', 59) + '...';
    AssertEquals(ExpectedPreview, DiagnosticField.DisplayText);
    AssertEquals(DiagnosticText, DiagnosticField.AsString);

    Form.RxDBGridFinishMarks.SelectedIndex := 10;
    Clipboard.AsText := '';
    Form.AcCopyExecute(Form.AcCopy);
    AssertEquals(DiagnosticText, Clipboard.AsText);

    Form.RxDBGridFinishMarksDblClick(Form.RxDBGridFinishMarks);
    AssertEquals(DiagnosticText, Form.ShownDiagnostic);
  finally
    Form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.
  TimingStart_AutomaticSettingsApplyCorrection;
var
  OldAutomaticApply: boolean;
  OldMatchDeltaSeconds: integer;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(501);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''10:00:02.000'' WHERE number = 501;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;
  OldAutomaticApply := startMarkAutomaticApply;
  OldMatchDeltaSeconds := startMarkMatchDeltaSeconds;
  try
    startMarkAutomaticApply := True;
    startMarkMatchDeltaSeconds := 3;
    ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 31);
  finally
    startMarkAutomaticApply := OldAutomaticApply;
    startMarkMatchDeltaSeconds := OldMatchDeltaSeconds;
  end;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT m.correction1, s.participant_number, s.status, ' +
    's.assignment_mode FROM main m JOIN start_marks s ' +
    'ON s.participant_number = m.number WHERE m.number = 501;';
  MainForm.SQLQuery1.Open;
  AssertEquals(31, MainForm.SQLQuery1.FieldByName('correction1').AsInteger);
  AssertEquals(501,
    MainForm.SQLQuery1.FieldByName('participant_number').AsInteger);
  AssertEquals('applied', MainForm.SQLQuery1.FieldByName('status').AsString);
  AssertEquals('automatic',
    MainForm.SQLQuery1.FieldByName('assignment_mode').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  TimingStart_ClosedCompetitionIsIgnored;
begin
  MainForm.FileCloseExecute(nil);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0), True, 10);
  AssertFalse(IsCompetitionDatabaseOpen);
end;

procedure TMainFlowIntegrationTests.
  FinishMarkPanel_UsesEditableSqlQueryAndRxDbGrid;
begin
  CreateNewCompetitionFile;

  AssertFalse(MainForm.DatasetFinishMarks.ReadOnly);
  AssertEquals(Trim(TFinishMarkSql.SelectWorkQueue),
    Trim(MainForm.DatasetFinishMarks.SQL.Text));
  AssertSame(MainForm.SQLite3Connection1,
    MainForm.DatasetFinishMarks.Database);
  AssertSame(MainForm.SQLTransaction1,
    MainForm.DatasetFinishMarks.Transaction);
  AssertSame(MainForm.DataSourceFinishMarks,
    MainForm.RxDBGridFinishMarks.DataSource);
  AssertSame(MainForm.DatasetFinishMarks,
    MainForm.DataSourceFinishMarks.DataSet);
  AssertEquals('event_time',
    MainForm.RxDBGridFinishMarks.Columns[0].FieldName);
  AssertTrue(MainForm.RxDBGridFinishMarks.Columns[0].ReadOnly);
  AssertEquals('participant_number',
    MainForm.RxDBGridFinishMarks.Columns[1].FieldName);
  AssertFalse(MainForm.RxDBGridFinishMarks.Columns[1].ReadOnly);
  AssertTrue('The finish work queue must not append empty records',
    dgDisableInsert in MainForm.RxDBGridFinishMarks.Options);
end;

procedure TMainFlowIntegrationTests.TimingMarkWorkQueues_RejectDatasetInsert;

  procedure AssertAppendRejected(const AName: string; ADataSet: TDataSet);
  var
    AppendRejected: boolean;
    RecordCountBefore: integer;
  begin
    RecordCountBefore := ADataSet.RecordCount;
    AppendRejected := False;
    try
      try
        ADataSet.Append;
      except
        on E: EAbort do
          AppendRejected := True;
      end;
    finally
      if ADataSet.State in [dsEdit, dsInsert] then
        ADataSet.Cancel;
    end;
    AssertTrue(AName + ' must reject Append', AppendRejected);
    AssertEquals(AName + ' must remain in browse state',
      Ord(dsBrowse), Ord(ADataSet.State));
    AssertEquals(AName + ' must not gain an empty record',
      RecordCountBefore, ADataSet.RecordCount);
  end;

begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  ApplyStartPacketAt(EncodeTime(10, 0, 0, 0));
  ApplyFinishPacketAt(EncodeTime(10, 1, 0, 0));

  AssertAppendRejected('Start mark work queue', MainForm.DatasetStartMarks);
  AssertAppendRejected('Finish mark work queue', MainForm.DatasetFinishMarks);
end;

procedure TMainFlowIntegrationTests.
  FinishMarkPanel_RestoresPendingMarksFromSqlite;
var
  CompetitionFileName: string;
begin
  CreateNewCompetitionFile;
  ApplyFinishPacketAt(EncodeTime(10, 11, 12, 345));
  AssertEquals(1, MainForm.DatasetFinishMarks.RecordCount);
  CompetitionFileName := FDbFilePath;

  MainForm.FileCloseExecute(nil);
  OpenCompetitionFile(CompetitionFileName);

  AssertTrue(MainForm.DatasetFinishMarks.Active);
  AssertEquals(1, MainForm.DatasetFinishMarks.RecordCount);
  AssertEquals('10:11:12.345',
    MainForm.DatasetFinishMarks.FieldByName('event_time').AsString);
  AssertTrue(MainForm.DatasetFinishMarks.FieldByName(
    'participant_number').IsNull);
end;

procedure TMainFlowIntegrationTests.
  FinishMarkPanel_DebouncedMarkPreservesSelection;
var
  OldDebounceInterval: integer;
  SelectedMarkId: int64;
begin
  CreateNewCompetitionFile;
  OldDebounceInterval := MainForm.FinishDebounceInterval;
  try
    MainForm.FinishDebounceInterval := 250;
    ApplyFinishPacketAt(EncodeTime(10, 0, 0, 0));
    ApplyFinishPacketAt(EncodeTime(10, 0, 0, 300));
    AssertEquals(2, MainForm.DatasetFinishMarks.RecordCount);
    AssertEquals('A new pending mark must become selected',
      '10:00:00.300', MainForm.DatasetFinishMarks.FieldByName(
      'event_time').AsString);
    SelectedMarkId := MainForm.DatasetFinishMarks.FieldByName('id').AsLargeInt;

    ApplyFinishPacketAt(EncodeTime(10, 0, 0, 400));

    AssertEquals('A debounced mark must not enter the work queue',
      2, MainForm.DatasetFinishMarks.RecordCount);
    AssertEquals('A debounced mark must preserve the selected row',
      SelectedMarkId,
      MainForm.DatasetFinishMarks.FieldByName('id').AsLargeInt);
    MainForm.SQLQuery1.Close;
    MainForm.SQLQuery1.SQL.Text :=
      'SELECT status FROM finish_marks ORDER BY id DESC LIMIT 1;';
    MainForm.SQLQuery1.Open;
    AssertEquals('ignored_debounce',
      MainForm.SQLQuery1.FieldByName('status').AsString);
    MainForm.SQLQuery1.Close;
  finally
    MainForm.FinishDebounceInterval := OldDebounceInterval;
  end;
end;

procedure TMainFlowIntegrationTests.FinishMarkPanel_RapidMarksRemainStable;
const
  MarkOffsetsMs: array[0..10] of integer =
    (0, 233, 752, 903, 1514, 1629, 2361, 2526, 2765, 3152, 3269);
var
  BaseTime: TDateTime;
  I: integer;
begin
  CreateNewCompetitionFile;
  BaseTime := EncodeTime(3, 23, 2, 898);
  MainForm.Show;
  try
    for I := Low(MarkOffsetsMs) to High(MarkOffsetsMs) do
    begin
      ApplyFinishPacketAt(IncMilliSecond(BaseTime, MarkOffsetsMs[I]));
      Application.ProcessMessages;
    end;

    AssertEquals('Only marks outside the debounce interval enter the queue',
      6, MainForm.DatasetFinishMarks.RecordCount);
    AssertEquals('The last accepted mark remains selected',
      '03:23:06.050', MainForm.DatasetFinishMarks.FieldByName(
      'event_time').AsString);
  finally
    MainForm.Hide;
  end;
end;

procedure TMainFlowIntegrationTests.
  FinishMarkPanel_DoubleClickWithoutNumberDoesNothing;
begin
  CreateNewCompetitionFile;
  ApplyFinishPacketAt(EncodeTime(10, 11, 12, 345));
  DialogCallCount := 0;

  MainForm.RxDBGridFinishMarksDblClick(MainForm.RxDBGridFinishMarks);

  AssertEquals(0, DialogCallCount);
  AssertEquals(1, MainForm.DatasetFinishMarks.RecordCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT status FROM finish_marks;';
  MainForm.SQLQuery1.Open;
  AssertEquals('pending', MainForm.SQLQuery1.FieldByName('status').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  FinishMarkPanel_DoubleClickAppliesNumberedMark;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  InsertParticipant(510);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET starttime1 = ''00:00:00.000'' WHERE number = 510;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;
  ApplyFinishPacketAt(EncodeTime(0, 10, 0, 0));
  SetFinishMarkNumberAt(0, 510);
  DialogCallCount := 0;

  MainForm.RxDBGridFinishMarksDblClick(MainForm.RxDBGridFinishMarks);

  AssertEquals(0, DialogCallCount);
  AssertEquals(0, MainForm.DatasetFinishMarks.RecordCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime1 FROM main WHERE number = 510;';
  MainForm.SQLQuery1.Open;
  AssertEquals('00:10:00.000',
    MainForm.SQLQuery1.FieldByName('finishtime1').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  FinishMarkPanel_ClearSoftHidesEntireWorkQueue;
begin
  CreateNewCompetitionFile;
  ApplyFinishPacketAt(EncodeTime(10, 0, 0, 0));
  ApplyFinishPacketAt(EncodeTime(10, 0, 1, 0));
  AssertEquals(2, MainForm.DatasetFinishMarks.RecordCount);

  MainForm.ResultClearClick(MainForm);

  AssertTrue(MainForm.DatasetFinishMarks.IsEmpty);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT status FROM finish_marks ORDER BY id;';
  MainForm.SQLQuery1.Open;
  AssertEquals(2, MainForm.SQLQuery1.RecordCount);
  while not MainForm.SQLQuery1.EOF do
  begin
    AssertEquals('hidden',
      MainForm.SQLQuery1.FieldByName('status').AsString);
    MainForm.SQLQuery1.Next;
  end;
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.
  SerialUi_ControlsUseMenuImagesAndPlaceIconBeforePort;
begin
  ConfigureSerialUi('COM1', ['COM1']);

  AssertTrue('The old left status bar must be removed',
    MainForm.FindComponent('StatusBarLeft') = nil);
  AssertTrue('The old right status bar must be removed',
    MainForm.FindComponent('StatusBarRight') = nil);
  AssertSame(MainForm.StatusBarPanel, MainForm.TimingInputControl.Parent);
  AssertSame(MainForm.TimingInputControl,
    MainForm.TimingInputStateButton.Parent);
  AssertSame(MainForm.TimingInputControl,
    MainForm.TimingInputDeviceLabel.Parent);
  AssertSame(MainForm.StatusBarPanel, MainForm.TimingInputStatusText.Parent);
  AssertSame(MainForm.StatusBarPanel, MainForm.ComboBoxLog.Parent);
  AssertSame(MainForm.StatusBarPanel, MainForm.Clock.Parent);
  AssertSame(MainForm.ImageList1, MainForm.TimingInputStateButton.Images);
  AssertTrue('Clicking the port name must have a menu handler',
    Assigned(MainForm.TimingInputDeviceLabel.OnClick));
  AssertTrue(MainForm.TimingInputDeviceLabel is TLabel);
  AssertFalse(MainForm.TimingInputDeviceLabel.AutoSize);
  AssertEquals(Ord(taLeftJustify),
    Ord(MainForm.TimingInputDeviceLabel.Alignment));
  AssertEquals(Ord(tlCenter), Ord(MainForm.TimingInputDeviceLabel.Layout));
  AssertEquals('COM1', MainForm.TimingInputDeviceLabel.Caption);
  AssertEquals('Disconnected icon must show the closed-port state',
    MainForm.AcCOMClose.ImageIndex,
    MainForm.TimingInputStateButton.ImageIndex);
  AssertEquals(Ord(alLeft), Ord(MainForm.TimingInputControl.Align));
  AssertEquals(Ord(alLeft), Ord(MainForm.TimingInputStatusText.Align));
  AssertEquals(Ord(alClient), Ord(MainForm.ComboBoxLog.Align));
  AssertEquals(Ord(alRight), Ord(MainForm.Clock.Align));
  AssertTrue('Clock must be to the right of the log combo box',
    MainForm.Clock.Left > MainForm.ComboBoxLog.Left);
end;

procedure TMainFlowIntegrationTests.
  SerialUi_DisconnectedAvailablePortEnablesOpenState;
begin
  ConfigureSerialUi('/dev/ttyUSB0', ['/dev/ttyUSB0', '/dev/ttyUSB1']);
  MainForm.COMStatus(MainForm.AcCOMOpen);
  MainForm.COMStatus(MainForm.AcCOMClose);

  AssertFalse(MainForm.Serial.Active);
  AssertTrue(MainForm.SerialConnectionEnabled);
  AssertEquals(MainForm.AcCOMClose.ImageIndex,
    MainForm.SerialConnectionImageIndex);
  AssertEquals('/dev/ttyUSB0', MainForm.TimingInputDeviceLabel.Caption);
  AssertTrue(MainForm.TimingInputStateButton.Enabled);
  AssertEquals(Format(rsConnectToPort, ['/dev/ttyUSB0']),
    MainForm.SerialConnectionHint);
  AssertTrue('Open action must be enabled for an available device',
    MainForm.AcCOMOpen.Enabled);
  AssertFalse('Close action must be disabled while disconnected',
    MainForm.AcCOMClose.Enabled);
end;

procedure TMainFlowIntegrationTests.
  SerialUi_DisconnectedUnavailablePortDisablesOpenState;
begin
  ConfigureSerialUi('/dev/ttyUSB9', ['/dev/ttyUSB0', '/dev/ttyUSB1']);
  MainForm.COMStatus(MainForm.AcCOMOpen);
  MainForm.COMStatus(MainForm.AcCOMClose);

  AssertFalse(MainForm.SerialConnectionEnabled);
  AssertEquals(MainForm.AcCOMClose.ImageIndex,
    MainForm.SerialConnectionImageIndex);
  AssertEquals('/dev/ttyUSB9', MainForm.TimingInputDeviceLabel.Caption);
  AssertFalse(MainForm.TimingInputStateButton.Enabled);
  AssertEquals(Format(rsPortUnavailable, ['/dev/ttyUSB9']),
    MainForm.SerialConnectionHint);
  AssertFalse('Open action must reject the unavailable selected device',
    MainForm.AcCOMOpen.Enabled);
  AssertFalse(MainForm.AcCOMClose.Enabled);
end;

procedure TMainFlowIntegrationTests.
  SerialUi_OpenActionRechecksAndRejectsUnavailablePort;
const
  MissingDeviceName = '/dev/entime-missing-serial-device';
begin
  ConfigureSerialUi(MissingDeviceName, ['COM1']);
  FakeSerialDevicesProviderCallCount := 0;

  MainForm.AcCOMOpenExecute(MainForm.AcCOMOpen);

  AssertFalse('Unavailable device must not be passed to Serial.Open',
    MainForm.Serial.Active);
  AssertTrue('The old menu action must refresh availability before opening',
    FakeSerialDevicesProviderCallCount > 0);
  AssertEquals('Unavailable selection must not show an open-error dialog',
    0, DialogCallCount);
end;

{$IFDEF UNIX}
procedure TMainFlowIntegrationTests.
  SerialUi_ConnectedPortUsesCloseStateAndButtonDisconnects;
var
  deviceName: string;
begin
  deviceName := VirtualSerialDevice;
  OpenVirtualSerialPort;

  AssertTrue(MainForm.SerialConnectionEnabled);
  AssertEquals(MainForm.AcCOMOpen.ImageIndex,
    MainForm.SerialConnectionImageIndex);
  AssertEquals(Format(rsDisconnectFromPort, [deviceName]),
    MainForm.SerialConnectionHint);

  MainForm.TimingInputStateButton.Click;
  Application.ProcessMessages;

  AssertFalse('Clicking the connected-state icon must close the port',
    MainForm.Serial.Active);
  AssertEquals(MainForm.AcCOMClose.ImageIndex,
    MainForm.SerialConnectionImageIndex);
end;
{$ENDIF}

procedure TMainFlowIntegrationTests.
  SerialUi_PortMenuRefreshesAndChecksCurrentDevice;
var
  currentItem: TMenuItem;
begin
  ConfigureSerialUi('COM2', ['COM1', 'COM2']);
  AssertEquals(2, MainForm.SerialPortPopupMenu.Items.Count);
  AssertEquals('COM1', MainForm.SerialPortPopupMenu.Items[0].Caption);
  AssertEquals('COM2', MainForm.SerialPortPopupMenu.Items[1].Caption);
  currentItem := FindSerialPortMenuItem('COM2');
  AssertTrue('Current serial device must be checked in the menu',
    currentItem.Checked);

  SetFakeSerialDevices(['COM3']);
  MainForm.SerialPortPopupMenuPopup(MainForm.SerialPortPopupMenu);
  AssertEquals('Menu must be rebuilt from the fresh provider value',
    1, MainForm.SerialPortPopupMenu.Items.Count);
  AssertEquals('COM3', MainForm.SerialPortPopupMenu.Items[0].Caption);
  AssertEquals('The provider must be called for every menu opening',
    2, FakeSerialDevicesProviderCallCount);

  SetLength(FakeSerialDevices, 1);
  FakeSerialDevices[0] := Default(TSerialDeviceInfo);
  FakeSerialDevices[0].Device := 'COM4';
  FakeSerialDevices[0].Vendor := 'ENTime';
  FakeSerialDevices[0].Model := 'USB UART';
  FakeSerialDevices[0].SerialShort := 'ABC123';
  MainForm.SerialPortPopupMenuPopup(MainForm.SerialPortPopupMenu);
  AssertEquals('COM4 <ENTime USB UART>',
    MainForm.SerialPortPopupMenu.Items[0].Caption);
end;

procedure TMainFlowIntegrationTests.
  SerialUi_EmptyPortMenuShowsDisabledLocalizedItem;
var
  emptyItem: TMenuItem;
begin
  ConfigureSerialUi('COM1', []);

  AssertEquals(1, MainForm.SerialPortPopupMenu.Items.Count);
  emptyItem := MainForm.SerialPortPopupMenu.Items[0];
  AssertEquals(rsNoAvailableSerialPorts, emptyItem.Caption);
  AssertFalse(emptyItem.Enabled);
  AssertFalse(emptyItem.Checked);
end;

procedure TMainFlowIntegrationTests.
  SerialUi_SelectingAvailablePortUpdatesDeviceWithoutConnecting;
var
  item: TMenuItem;
begin
  ConfigureSerialUi('COM1', ['COM1', 'COM2']);
  item := FindSerialPortMenuItem('COM2');

  item.Click;

  AssertFalse('Selecting a device must not connect automatically',
    MainForm.Serial.Active);
  AssertEquals('COM2', MainForm.Serial.Device);
  AssertEquals('COM2', MainForm.TimingInputDeviceLabel.Caption);
  AssertTrue(MainForm.SerialConnectionEnabled);
  AssertEquals(Format(rsConnectToPort, ['COM2']),
    MainForm.SerialConnectionHint);
end;

{$IFDEF UNIX}
procedure TMainFlowIntegrationTests.
  SerialUi_ConnectedPortPreventsDeviceSelection;
var
  otherItem: TMenuItem;
begin
  OpenVirtualSerialPort;
  SetFakeSerialDevices([VirtualSerialDevice, 'COM2']);
  MainForm.SerialPortPopupMenuPopup(MainForm.SerialPortPopupMenu);
  otherItem := FindSerialPortMenuItem('COM2');

  AssertFalse('Ports must not be selectable during an active connection',
    otherItem.Enabled);
  otherItem.Click;
  AssertEquals(VirtualSerialDevice, MainForm.Serial.Device);
  AssertTrue(MainForm.Serial.Active);
end;
{$ENDIF}

procedure TMainFlowIntegrationTests.
  SerialUi_PortDisappearingBeforeClickIsNotOpened;
const
  MissingDeviceName = '/dev/entime-missing-serial-device';
begin
  ConfigureSerialUi(MissingDeviceName, [MissingDeviceName]);
  AssertTrue(MainForm.SerialConnectionEnabled);

  FakeSerialDevices := nil;
  FakeSerialDevicesProviderCallCount := 0;
  MainForm.TimingInputStateButton.Click;

  AssertFalse('A device removed after menu refresh must not be opened',
    MainForm.Serial.Active);
  AssertTrue('Connect click must re-enumerate devices',
    FakeSerialDevicesProviderCallCount > 0);
  AssertFalse(MainForm.SerialConnectionEnabled);
  AssertEquals(Format(rsPortUnavailable, [MissingDeviceName]),
    MainForm.SerialConnectionHint);
end;

{$IFDEF UNIX}
procedure TMainFlowIntegrationTests.
  SerialUi_StatusCallbacksSynchronizeControlsActionsAndText;
var
  deviceName: string;
begin
  deviceName := VirtualSerialDevice;
  OpenVirtualSerialPort;
  MainForm.COMStatus(MainForm.AcCOMOpen);
  MainForm.COMStatus(MainForm.AcCOMClose);

  AssertEquals(Format(rsPortConnected, [deviceName]),
    MainForm.TimingInputStatusText.Caption);
  AssertEquals(MainForm.AcCOMOpen.ImageIndex,
    MainForm.SerialConnectionImageIndex);
  AssertFalse(MainForm.AcCOMOpen.Enabled);
  AssertTrue(MainForm.AcCOMClose.Enabled);

  MainForm.SerialStatus(MainForm.Serial, HR_CanRead, 'read');
  AssertEquals(Format(rsSerialCanRead, ['read']),
    MainForm.TimingInputStatusText.Caption);
  MainForm.SerialStatus(MainForm.Serial, HR_CanWrite, 'write');
  AssertEquals(Format(rsSerialCanWrite, ['write']),
    MainForm.TimingInputStatusText.Caption);
  MainForm.SerialStatus(MainForm.Serial, HR_ReadCount, '12');
  AssertEquals(Format(rsSerialReadCount, ['12']),
    MainForm.TimingInputStatusText.Caption);
  MainForm.SerialStatus(MainForm.Serial, HR_WriteCount, '7');
  AssertEquals(Format(rsSerialWriteCount, ['7']),
    MainForm.TimingInputStatusText.Caption);
  MainForm.SerialStatus(MainForm.Serial, HR_Wait, 'idle');
  AssertEquals(Format(rsSerialWait, ['idle']),
    MainForm.TimingInputStatusText.Caption);
  AssertEquals(MainForm.TimingInputStatusText.Caption,
    MainForm.TimingInputStatusText.Hint);

  MainForm.AcCOMCloseExecute(MainForm.AcCOMClose);
  Application.ProcessMessages;
  MainForm.COMStatus(MainForm.AcCOMOpen);
  MainForm.COMStatus(MainForm.AcCOMClose);

  AssertEquals(Format(rsPortClosed, [deviceName]),
    MainForm.TimingInputStatusText.Caption);
  AssertEquals(MainForm.AcCOMClose.ImageIndex,
    MainForm.SerialConnectionImageIndex);
  AssertTrue(MainForm.AcCOMOpen.Enabled);
  AssertFalse(MainForm.AcCOMClose.Enabled);
end;
{$ENDIF}

procedure TMainFlowIntegrationTests.
  SerialUi_RestoredUnavailablePortRemainsSelectedButDisabled;
var
  oldCheckUpdateAtStartup: boolean;
begin
  oldCheckUpdateAtStartup := checkUpdateAtStartup;
  try
    checkUpdateAtStartup := False;
    SetFakeSerialDevices(['COM1']);
    MainForm.Serial.Device := 'COM9';

    MainForm.RxIniPropStorage1RestoreProperties(MainForm.RxIniPropStorage1);

    AssertEquals('COM9', MainForm.Serial.Device);
    AssertEquals('COM9', MainForm.TimingInputDeviceLabel.Caption);
    AssertFalse(MainForm.SerialConnectionEnabled);
    AssertEquals(Format(rsPortUnavailable, ['COM9']),
      MainForm.SerialConnectionHint);
  finally
    checkUpdateAtStartup := oldCheckUpdateAtStartup;
  end;
end;

procedure TMainFlowIntegrationTests.SerialUi_ClockTimerDoesNotEnumeratePorts;
begin
  ConfigureSerialUi('COM1', ['COM1']);
  FakeSerialDevicesProviderCallCount := 0;

  MainForm.Timer1Timer(MainForm.Timer1);

  AssertEquals('Clock updates must not poll physical serial devices',
    0, FakeSerialDevicesProviderCallCount);
  AssertEquals('Clock must display hh:nn:ss', 8, Length(MainForm.Clock.Caption));
end;

procedure TMainFlowIntegrationTests.SerialUi_PortLabelDoesNotRepeatSelectedPort;
var
  item: TMenuItem;
begin
  ConfigureSerialUi('COM1', ['COM1', 'COM2']);
  item := FindSerialPortMenuItem('COM2');
  item.Click;

  AssertEquals('The serial-port button displays the selected port once',
    'COM2', MainForm.TimingInputDeviceLabel.Caption);
end;

procedure TMainFlowIntegrationTests.
  TimingInputUi_SwitchesBetweenSerialAndBleStatus;
var
  device: TBleDeviceInfo;
  bleStatusText: string;
begin
  ConfigureSerialUi('COM1', ['COM1']);
  timingInputTransport := ttkSerial;
  MainForm.RefreshTimingInputUi;
  AssertEquals('COM1', MainForm.TimingInputDeviceLabel.Caption);

  MainForm.LazBleLclClient1.DeviceId := '';
  timingInputTransport := ttkBle;
  MainForm.RefreshTimingInputUi;
  AssertFalse(MainForm.TimingInputStateButton.Enabled);
  AssertTrue('BLE device label starts a scan even without a saved device',
    MainForm.TimingInputDeviceLabel.Enabled);

  device := Default(TBleDeviceInfo);
  device.DeviceId := 'ble-device-id';
  device.DeviceName := 'ENTime BLE';
  MainForm.LazBleLclClient1.SelectDevice(device);
  MainForm.RefreshTimingInputUi;
  bleStatusText := LazBleStatusText(MainForm.LazBleLclClient1);

  AssertEquals('ENTime BLE', MainForm.TimingInputDeviceLabel.Caption);
  AssertEquals('ble-device-id', MainForm.TimingInputDeviceLabel.Hint);
  AssertEquals(bleStatusText, MainForm.TimingInputStatusText.Caption);
  AssertTrue(MainForm.TimingInputStateButton.Enabled);
  AssertTrue(MainForm.TimingInputDeviceLabel.Enabled);
  AssertEquals(Ord(crHandPoint), Ord(MainForm.TimingInputDeviceLabel.Cursor));

  MainForm.SerialStatus(MainForm.Serial, HR_CanRead, 'serial-only');
  AssertEquals('Serial callbacks must not overwrite visible BLE status',
    bleStatusText, MainForm.TimingInputStatusText.Caption);

  timingInputTransport := ttkSerial;
  MainForm.RefreshTimingInputUi;
  AssertEquals('COM1', MainForm.TimingInputDeviceLabel.Caption);
  AssertEquals(Format(rsSerialCanRead, ['serial-only']),
    MainForm.TimingInputStatusText.Caption);
end;

{$IFDEF UNIX}
procedure TMainFlowIntegrationTests.
  SerialVirtualPort_ProcessesMixedTransportStream;
var
  deadline: QWord;
  deviceName, oldDeviceName, payload, peerName: string;
  peerStream: TFileStream;
begin
  deviceName := GetEnvironmentVariable('ENTIME_SERIAL_DEVICE');
  peerName := GetEnvironmentVariable('ENTIME_SERIAL_PEER');
  if (deviceName = '') or (peerName = '') then
    Fail('Virtual serial ports are not configured; run integration tests ' +
      'via scripts/run-integration-tests.sh');

  CreateNewCompetitionFile;
  MainForm.ResultClearClick(MainForm);
  oldDeviceName := MainForm.Serial.Device;
  MainForm.Serial.Device := deviceName;
  MainForm.Serial.RcvLineCRLF := False;
  peerStream := nil;
  try
    MainForm.AcCOMOpenExecute(MainForm.AcCOMOpen);
    AssertTrue('The UI action must accept an existing PTY device',
      MainForm.Serial.Active);
    peerStream := TFileStream.Create(peerName, fmOpenWrite or fmShareDenyNone);

    payload := 'I (1) Firmware ready' + #10 +
      '{"status":"ok"}' + #10 + '$10:10';
    peerStream.WriteBuffer(payload[1], Length(payload));
    Application.ProcessMessages;
    Sleep(20);
    payload := ':10#' + #10 + '{invalid}' + #10 +
      'F10:10:11#' + #13#10;
    peerStream.WriteBuffer(payload[1], Length(payload));

    deadline := GetTickCount64 + 3000;
    repeat
      Application.ProcessMessages;
      Sleep(10);
    until (GetTickCount64 >= deadline) or
      (MainForm.DatasetFinishMarks.RecordCount > 0);

    MainForm.SQLQuery1.Close;
    MainForm.SQLQuery1.SQL.Text :=
      'SELECT source_kind, source_device_id, correction_ms ' +
      'FROM start_marks;';
    MainForm.SQLQuery1.Open;
    AssertEquals(1, MainForm.SQLQuery1.RecordCount);
    AssertEquals('serial',
      MainForm.SQLQuery1.FieldByName('source_kind').AsString);
    AssertEquals(deviceName,
      MainForm.SQLQuery1.FieldByName('source_device_id').AsString);
    AssertTrue(MainForm.SQLQuery1.FieldByName('correction_ms').IsNull);
    MainForm.SQLQuery1.Close;
    AssertEquals(1, MainForm.DatasetFinishMarks.RecordCount);
  finally
    peerStream.Free;
    if MainForm.Serial.Active then
      MainForm.AcCOMCloseExecute(MainForm.AcCOMClose);
    MainForm.Serial.Device := oldDeviceName;
  end;
end;
{$ENDIF}

procedure TMainFlowIntegrationTests.BleTimingPacketReceived(Sender: TObject;
  const APacket: TTimingPacket; const ASource: TTimingMarkSource);
begin
  AssertSame(FBleTestProcessor, Sender);
  AssertEquals(Ord(tmskBle), Ord(ASource.Kind));
  MainForm.TimingPacketReceived(Sender, APacket, ASource);
end;

procedure TMainFlowIntegrationTests.BleTimingDataReceived(Sender: TObject;
  const AData: RawByteString; const ASource: TTimingMarkSource);
begin
  AssertTrue(Sender is TBleTimingTransport);
  FBleTestProcessor.Feed(AData, ASource, Now);
end;

procedure TMainFlowIntegrationTests.CompleteBleTimingConnection(
  const ABackend: TFakeLazBleBackend;
  const ASubscriptionId: TBleSubscriptionId);
var
  BackendEvent: TLazBleBackendEvent;
  Command: TLazBleBackendCommand;
  OperationId: TBleOperationId;
begin
  Command := ABackend.Commands[ABackend.CommandCount - 1];
  OperationId := ABackend.OperationIds[ABackend.CommandCount - 1];
  AssertEquals(Ord(lbckConnect), Ord(Command.Kind));

  BackendEvent := Default(TLazBleBackendEvent);
  BackendEvent.Kind := lbekConnected;
  BackendEvent.OperationId := OperationId;
  BackendEvent.DeviceId := Command.DeviceId;
  BackendEvent.Generation := Command.Generation;
  AssertTrue(ABackend.EmitProgress(BackendEvent));

  Command := ABackend.Commands[ABackend.CommandCount - 1];
  OperationId := ABackend.OperationIds[ABackend.CommandCount - 1];
  AssertEquals(Ord(lbckDiscoverServices), Ord(Command.Kind));
  BackendEvent := Default(TLazBleBackendEvent);
  BackendEvent.Kind := lbekServicesDiscovered;
  BackendEvent.OperationId := OperationId;
  BackendEvent.DeviceId := Command.DeviceId;
  BackendEvent.Generation := Command.Generation;
  SetLength(BackendEvent.Services, 1);
  BackendEvent.Services[0].Uuid := NusServiceUuid;
  SetLength(BackendEvent.Services[0].Characteristics, 2);
  BackendEvent.Services[0].Characteristics[0].Uuid :=
    NusRxCharacteristicUuid;
  BackendEvent.Services[0].Characteristics[0].Properties :=
    [lbgcpWriteCommand];
  BackendEvent.Services[0].Characteristics[1].Uuid :=
    NusTxCharacteristicUuid;
  BackendEvent.Services[0].Characteristics[1].Properties := [lbgcpNotify];
  AssertTrue(ABackend.EmitProgress(BackendEvent));

  Command := ABackend.Commands[ABackend.CommandCount - 1];
  OperationId := ABackend.OperationIds[ABackend.CommandCount - 1];
  AssertEquals(Ord(lbckSubscribe), Ord(Command.Kind));
  BackendEvent := Default(TLazBleBackendEvent);
  BackendEvent.Kind := lbekSubscribed;
  BackendEvent.OperationId := OperationId;
  BackendEvent.SubscriptionId := ASubscriptionId;
  BackendEvent.DeviceId := Command.DeviceId;
  BackendEvent.Generation := Command.Generation;
  AssertTrue(ABackend.EmitProgress(BackendEvent));
  AssertTrue(ABackend.CompleteOperation(OperationId,
    lbekOperationSucceeded));
end;

procedure TMainFlowIntegrationTests.EmitBleTimingNotification(
  const ABackend: TFakeLazBleBackend; const AInput: TBleTimingTransport;
  const ASubscriptionId: TBleSubscriptionId;
  const AValue: RawByteString);
var
  BackendEvent: TLazBleBackendEvent;
  Index: Integer;
begin
  BackendEvent := Default(TLazBleBackendEvent);
  BackendEvent.Kind := lbekNotification;
  BackendEvent.OperationId := InvalidBleOperationId;
  BackendEvent.SubscriptionId := ASubscriptionId;
  BackendEvent.DeviceId := AInput.DeviceId;
  BackendEvent.Generation := ABackend.Commands[
    ABackend.CommandCount - 1].Generation;
  SetLength(BackendEvent.Value, Length(AValue));
  for Index := 1 to Length(AValue) do
    BackendEvent.Value[Index - 1] := Byte(AValue[Index]);
  AssertTrue(ABackend.EmitProgress(BackendEvent));
end;

procedure TMainFlowIntegrationTests.BleStartPersistsStartMarkOnce;
const
  SubscriptionId = TBleSubscriptionId(61);
var
  Backend: ILazBleBackend;
  BackendObject: TFakeLazBleBackend;
  Input: TBleTimingTransport;
begin
  CreateNewCompetitionFile;
  BackendObject := TFakeLazBleBackend.Create;
  Backend := BackendObject;
  Input := TBleTimingTransport.Create(Backend);
  try
    Input.OnData := @BleTimingDataReceived;
    Input.ConnectAsync('ENTime-1');
    CompleteBleTimingConnection(BackendObject, SubscriptionId);

    EmitBleTimingNotification(BackendObject, Input, SubscriptionId,
      '$10:10:10#');

    MainForm.SQLQuery1.Close;
    MainForm.SQLQuery1.SQL.Text :=
      'SELECT source_kind, source_device_id FROM start_marks;';
    MainForm.SQLQuery1.Open;
    AssertEquals(1, MainForm.SQLQuery1.RecordCount);
    AssertEquals('ble',
      MainForm.SQLQuery1.FieldByName('source_kind').AsString);
    AssertEquals('ENTime-1',
      MainForm.SQLQuery1.FieldByName('source_device_id').AsString);
    MainForm.SQLQuery1.Close;
  finally
    Input.Free;
    Backend := nil;
    BackendObject := nil;
  end;
end;

procedure TMainFlowIntegrationTests.BleFinishInvokesGetFinishTimeOnce;
const
  SubscriptionId = TBleSubscriptionId(62);
var
  Backend: ILazBleBackend;
  BackendObject: TFakeLazBleBackend;
  Input: TBleTimingTransport;
  OldCheckInterval: Integer;
begin
  CreateNewCompetitionFile;
  MainForm.ResultClearClick(MainForm);
  BackendObject := TFakeLazBleBackend.Create;
  Backend := BackendObject;
  Input := TBleTimingTransport.Create(Backend);
  OldCheckInterval := MainForm.FinishDebounceInterval;
  try
    Input.OnData := @BleTimingDataReceived;
    Input.ConnectAsync('ENTime-1');
    CompleteBleTimingConnection(BackendObject, SubscriptionId);

    MainForm.FinishDebounceInterval := -1;
    EmitBleTimingNotification(BackendObject, Input, SubscriptionId,
      'F10:10:11#');

    AssertEquals(1, MainForm.DatasetFinishMarks.RecordCount);
    MainForm.SQLQuery1.Close;
    MainForm.SQLQuery1.SQL.Text :=
      'SELECT source_kind, source_device_id, status FROM finish_marks;';
    MainForm.SQLQuery1.Open;
    AssertEquals(1, MainForm.SQLQuery1.RecordCount);
    AssertEquals('ble',
      MainForm.SQLQuery1.FieldByName('source_kind').AsString);
    AssertEquals('ENTime-1',
      MainForm.SQLQuery1.FieldByName('source_device_id').AsString);
    AssertEquals('pending',
      MainForm.SQLQuery1.FieldByName('status').AsString);
    MainForm.SQLQuery1.Close;
  finally
    MainForm.FinishDebounceInterval := OldCheckInterval;
    Input.Free;
    Backend := nil;
    BackendObject := nil;
  end;
end;

procedure TMainFlowIntegrationTests.
  LEDPanelTest_UsesDraftAddressWithoutChangingGlobal;
var
  Form: TSettingsForm;
  OldLedPanelAddress: string;
begin
  OldLedPanelAddress := ledpaneladress;
  Form := TSettingsForm.Create(nil);
  try
    Form.LEDAdress.Text := 'http://draft-panel.invalid/post';
    Form.ButtonLEDTestClick(Form.ButtonLEDTest);

    AssertEquals('LED test must not apply the draft address',
      OldLedPanelAddress, ledpaneladress);
  finally
    Form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.TelegramTestFailure_DoesNotLogRequestSecrets;
const
  TOKEN_SECRET = 'botTOKEN_SECRET';
  PAYLOAD_SECRET = 'PARTICIPANT_SECRET';
var
  errorPrefix: string;
  form: TSettingsForm;
  logDirectory, logFileName, logText, oldTelegramAddress: string;
  logLines: TStringList;
  waitStartedAt: QWord;

  function TryLoadLogText(out AText: string): boolean;
  begin
    Result := False;
    AText := '';
    if not FileExists(logFileName) then
      Exit;
    try
      logLines.LoadFromFile(logFileName);
      AText := logLines.Text;
      Result := True;
    except
      // The logger may still be writing; retry until the deadline.
    end;
  end;

begin
  oldTelegramAddress := telegrambotadress;
  logDirectory := ChangeFileExt(FDbFilePath, '') + '-telegram-logs';
  ForceDirectories(logDirectory);
  form := TSettingsForm.Create(nil);
  logLines := TStringList.Create;
  try
    form.TelegramBotAdressEdit.Text :=
      'http://127.0.0.1:1/' + TOKEN_SECRET;
    form.CheckBoxTelegramRetry.Checked := False;
    form.TelegramNumber.Clear;
    form.TelegramName.Text := PAYLOAD_SECRET;
    form.TelegramCategory.Clear;
    form.TelegramResult.Clear;
    form.TelegramDiff.Clear;
    form.TelegramPlace.Clear;
    InitializeAppLogger(DefaultLoggingSettings, logDirectory, '');
    logFileName := CurrentAppLogFileName;
    form.ButtonTelegramTestClick(form.ButtonTelegramTest);
    AssertEquals('Telegram test must not apply the draft endpoint',
      oldTelegramAddress, telegrambotadress);
    errorPrefix := Copy(rsTelegramBotSendingError, 1,
      Pos('%', rsTelegramBotSendingError) - 1);
    waitStartedAt := GetTickCount64;
    repeat
      CheckSynchronize(10);
      if TryLoadLogText(logText) and (Pos(errorPrefix, logText) > 0) then
        Break;
      Sleep(10);
    until GetTickCount64 - waitStartedAt >=
      QWord(TELEGRAM_CONNECT_TIMEOUT_MS + 2000);
    FinalizeAppLogger;
    if not TryLoadLogText(logText) then
      logText := '';

    AssertTrue('Telegram failure was not logged before the timeout',
      Pos(errorPrefix, logText) > 0);
    AssertTrue('Telegram request metadata was not logged',
      Pos(Format(rsHTTPRequestMetadata, ['GET', 1]), logText) > 0);
    AssertEquals('Telegram endpoint secret leaked to the log',
      0, Pos(TOKEN_SECRET, logText));
    AssertEquals('Telegram payload secret leaked to the log',
      0, Pos(PAYLOAD_SECRET, logText));
  finally
    FinalizeAppLogger;
    telegrambotadress := oldTelegramAddress;
    logLines.Free;
    form.Free;
    if FileExists(logFileName) then
      DeleteFile(logFileName);
    if DirectoryExists(logDirectory) then
      RemoveDir(logDirectory);
  end;
end;

procedure TMainFlowIntegrationTests.
  SettingsSerialSelector_ShowsFriendlyNameButAppliesDevice;
var
  oldDevice: string;
begin
  oldDevice := MainForm.Serial.Device;
  try
    MainForm.Serial.Device := 'COM1';
    InputDialogCallbackError := '';
    Application.QueueAsyncCall(@SelectFriendlySerialDeviceAndClose, mrOk);
    SettingsForm.RunSettings(3);

    AssertEquals('', InputDialogCallbackError);
    AssertEquals('Settings must apply the raw serial device name',
      TEST_SERIAL_DEVICE, MainForm.Serial.Device);
  finally
    MainForm.Serial.Close;
    MainForm.Serial.Device := oldDevice;
    MainForm.RefreshSerialPortUi;
  end;
end;

procedure TMainFlowIntegrationTests.
  SettingsSerialSelector_AppliesCustomDevice;
var
  oldDevice: string;
begin
  oldDevice := MainForm.Serial.Device;
  try
    MainForm.Serial.Device := 'COM1';
    InputDialogCallbackError := '';
    Application.QueueAsyncCall(@EnterCustomSerialDeviceAndClose, mrOk);
    SettingsForm.RunSettings(3);

    AssertEquals('', InputDialogCallbackError);
    AssertEquals('/tmp/entime-manual-port', MainForm.Serial.Device);
  finally
    MainForm.Serial.Close;
    MainForm.Serial.Device := oldDevice;
    MainForm.RefreshSerialPortUi;
  end;
end;

procedure TMainFlowIntegrationTests.
  SettingsTimingInputPage_SwitchesTransportPanels;
var
  form: TSettingsForm;
begin
  form := TSettingsForm.Create(nil);
  try
    AssertEquals(rsSettingsTimingInput, form.TreeView1.Items[3].Text);
    AssertTrue(form.RadioButtonTimingInputSerial.Checked);
    AssertFalse(form.RadioButtonTimingInputBle.Checked);
    AssertSame(form.PageTimingInputSerial,
      form.TimingInputSettingsNotebook.ActivePageComponent);

    form.RadioButtonTimingInputBle.Checked := True;
    form.TimingInputModeChanged(form.RadioButtonTimingInputBle);

    AssertFalse(form.RadioButtonTimingInputSerial.Checked);
    AssertSame(form.PageTimingInputBle,
      form.TimingInputSettingsNotebook.ActivePageComponent);
    AssertTrue(form.BleDeviceNameEdit.ReadOnly);
    AssertTrue(form.BleDeviceIdEdit.ReadOnly);
  finally
    form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.
  SettingsTimingInputPage_DisablesUnavailableBleButKeepsSerial;
var
  form: TSettingsForm;
  availabilityChanged, previousAvailabilityChanged: TBleAvailabilityEvent;
begin
  previousAvailabilityChanged :=
    MainForm.LazBleComponent1.OnAvailabilityChanged;
  form := TSettingsForm.Create(nil);
  try
    availabilityChanged := MainForm.LazBleComponent1.OnAvailabilityChanged;
    AssertTrue(Assigned(availabilityChanged));

    availabilityChanged(MainForm.LazBleComponent1, lbaUnavailable);

    AssertTrue(form.RadioButtonTimingInputSerial.Enabled);
    AssertFalse(form.RadioButtonTimingInputBle.Enabled);
    AssertFalse(form.ButtonSelectBleDevice.Enabled);
  finally
    form.Free;
  end;
  availabilityChanged := MainForm.LazBleComponent1.OnAvailabilityChanged;
  AssertTrue(TMethod(previousAvailabilityChanged).Code =
    TMethod(availabilityChanged).Code);
  AssertTrue(TMethod(previousAvailabilityChanged).Data =
    TMethod(availabilityChanged).Data);
end;

procedure TMainFlowIntegrationTests.
  SettingsTimingInputPage_AppliesSelectedBleDeviceOnlyAfterAccept;
var
  form: TTestSettingsForm;
  device: TBleDeviceInfo;
begin
  device := Default(TBleDeviceInfo);
  device.DeviceId := 'ble-device-id';
  device.DeviceName := 'ENTime BLE';
  device.Rssi := -42;

  form := TTestSettingsForm.Create(nil);
  try
    form.DeviceToSelect := device;
    form.DeviceSelectionResult := True;
    form.RadioButtonTimingInputBle.Checked := True;
    form.TimingInputModeChanged(form.RadioButtonTimingInputBle);
    form.ButtonSelectBleDeviceClick(form.ButtonSelectBleDevice);

    AssertEquals('ENTime BLE', form.BleDeviceNameEdit.Text);
    AssertEquals('ble-device-id', form.BleDeviceIdEdit.Text);
    AssertEquals('Selection must remain a form draft until settings are accepted',
      '', MainForm.LazBleLclClient1.DeviceId);
    AssertEquals(Ord(ttkSerial), Ord(timingInputTransport));

    form.ApplyTimingInputSettingsForTest;

    AssertEquals(Ord(ttkBle), Ord(timingInputTransport));
    AssertEquals('ble-device-id', MainForm.LazBleLclClient1.DeviceId);
    AssertEquals('ENTime BLE', MainForm.LazBleLclClient1.DeviceName);
    AssertEquals('Applying settings must not connect implicitly',
      Ord(lbcstDisconnected), Ord(MainForm.LazBleLclClient1.State));
  finally
    form.Free;
    MainForm.LazBleLclClient1.DeviceId := '';
    timingInputTransport := ttkSerial;
  end;
end;

procedure TMainFlowIntegrationTests.
  BleDeviceSelection_AcceptConnectsSelectedDevice;
var
  Backend: ILazBleBackend;
  BackendObject: TFakeLazBleBackend;
  Device: TBleDeviceInfo;
  FakeBle: TLazBleComponent;
  OriginalBle: TLazBleComponent;
  OperationId: TBleOperationId;
begin
  BackendObject := TFakeLazBleBackend.Create;
  Backend := BackendObject;
  FakeBle := TLazBleComponent.Create(nil, Backend);
  OriginalBle := MainForm.LazBleLclClient1.LazBle;
  MainForm.LazBleLclClient1.LazBle := FakeBle;
  try
    Device := Default(TBleDeviceInfo);
    Device.DeviceId := 'selected-device';
    Device.DeviceName := 'ENTime selected';

    TMainFormAccess(MainForm).CompleteBleTimingDeviceSelection(True, Device);

    AssertEquals('selected-device', MainForm.LazBleLclClient1.DeviceId);
    AssertEquals('ENTime selected', MainForm.LazBleLclClient1.DeviceName);
    AssertEquals(1, BackendObject.CommandCount);
    AssertEquals(Ord(lbckConnect), Ord(BackendObject.Commands[0].Kind));
    AssertEquals('selected-device', BackendObject.Commands[0].DeviceId);

    OperationId := BackendObject.OperationIds[0];
    AssertTrue(BackendObject.CompleteOperation(OperationId,
      lbekOperationFailed, 1, 'expected test failure'));
    Application.ProcessMessages;
  finally
    MainForm.LazBleLclClient1.LazBle := OriginalBle;
    MainForm.LazBleLclClient1.DeviceId := '';
    FakeBle.Free;
    Backend := nil;
  end;
end;

procedure TMainFlowIntegrationTests.
  BleDeviceSelection_CancelDoesNotChangeOrConnect;
var
  Device: TBleDeviceInfo;
begin
  Device := Default(TBleDeviceInfo);
  Device.DeviceId := 'cancelled-device';
  Device.DeviceName := 'Cancelled';

  TMainFormAccess(MainForm).CompleteBleTimingDeviceSelection(False, Device);

  AssertEquals('', MainForm.LazBleLclClient1.DeviceId);
  AssertEquals(Ord(lbcstDisconnected), Ord(MainForm.LazBleLclClient1.State));
end;

procedure TMainFlowIntegrationTests.
  SettingsStartMarkSettings_AreDraftedAndApplied;
var
  Form: TTestSettingsForm;
  OldAutomaticApply: boolean;
  OldMatchDeltaSeconds: integer;
begin
  OldAutomaticApply := startMarkAutomaticApply;
  OldMatchDeltaSeconds := startMarkMatchDeltaSeconds;
  startMarkAutomaticApply := True;
  startMarkMatchDeltaSeconds := 22;
  Form := TTestSettingsForm.Create(nil);
  try
    AssertEquals(22, Form.StartMarkMatchDeltaSpin.Value);
    AssertTrue(Form.CheckBoxStartMarkAutomaticApply.Checked);
    AssertEquals(rsStartMarkMatchDeltaHint,
      Form.StartMarkMatchDeltaLabel.Hint);
    AssertTrue(Form.StartMarkMatchDeltaLabel.ShowHint);
    AssertEquals(rsStartMarkAutomaticApplyHint,
      Form.CheckBoxStartMarkAutomaticApply.Hint);
    AssertTrue(Form.CheckBoxStartMarkAutomaticApply.ShowHint);

    Form.StartMarkMatchDeltaSpin.Value := 7;
    Form.CheckBoxStartMarkAutomaticApply.Checked := False;
    AssertEquals('Settings must stay a draft until accepted',
      22, startMarkMatchDeltaSeconds);
    AssertTrue(startMarkAutomaticApply);

    Form.ApplyTimingInputSettingsForTest;
    AssertEquals(7, startMarkMatchDeltaSeconds);
    AssertFalse(startMarkAutomaticApply);
  finally
    Form.Free;
    startMarkAutomaticApply := OldAutomaticApply;
    startMarkMatchDeltaSeconds := OldMatchDeltaSeconds;
  end;
end;

procedure TMainFlowIntegrationTests.
  TimingInputIni_RoundTripsModeAndBleIdentityWithoutConnection;
var
  device: TBleDeviceInfo;
  transportValue, deviceIdValue, deviceNameValue: TStoredType;
  oldCheckUpdateAtStartup: boolean;
begin
  device := Default(TBleDeviceInfo);
  device.DeviceId := 'ble-device-id';
  device.DeviceName := 'ENTime BLE';
  MainForm.LazBleLclClient1.SelectDevice(device);
  timingInputTransport := ttkBle;
  transportValue := '';
  deviceIdValue := '';
  deviceNameValue := '';

  MainForm.RxIniPropStorage1StoredValues12Save(nil, transportValue);
  MainForm.RxIniPropStorage1StoredValues13Save(nil, deviceIdValue);
  MainForm.RxIniPropStorage1StoredValues14Save(nil, deviceNameValue);

  AssertEquals('ble', string(transportValue));
  AssertEquals('ble-device-id', string(deviceIdValue));
  AssertEquals('ENTime BLE', string(deviceNameValue));

  MainForm.LazBleLclClient1.DeviceId := '';
  timingInputTransport := ttkSerial;
  MainForm.RxIniPropStorage1StoredValues14Restore(nil, deviceNameValue);
  MainForm.RxIniPropStorage1StoredValues13Restore(nil, deviceIdValue);
  MainForm.RxIniPropStorage1StoredValues12Restore(nil, transportValue);

  AssertEquals('BLE identity must be applied only after all INI values load',
    '', MainForm.LazBleLclClient1.DeviceId);
  AssertNull('Restoring settings must not create a BLE client',
    MainForm.LazBleLclClient1.CoreClient);

  oldCheckUpdateAtStartup := checkUpdateAtStartup;
  try
    checkUpdateAtStartup := False;
    MainForm.RxIniPropStorage1RestoreProperties(MainForm.RxIniPropStorage1);
  finally
    checkUpdateAtStartup := oldCheckUpdateAtStartup;
  end;

  AssertEquals(Ord(ttkBle), Ord(timingInputTransport));
  AssertEquals('ble-device-id', MainForm.LazBleLclClient1.DeviceId);
  AssertEquals('ENTime BLE', MainForm.LazBleLclClient1.DeviceName);
  AssertNull('Restoring settings must not start scan or connection',
    MainForm.LazBleLclClient1.CoreClient);
end;

procedure TMainFlowIntegrationTests.
  TimingInputIni_InvalidTransportFallsBackToSerial;
var
  transportValue: TStoredType;
begin
  timingInputTransport := ttkBle;
  transportValue := 'unsupported';

  MainForm.RxIniPropStorage1StoredValues12Restore(nil, transportValue);

  AssertEquals(Ord(ttkSerial), Ord(timingInputTransport));
end;

procedure TMainFlowIntegrationTests.StartMarkIni_RoundTripsSettings;
var
  AutomaticValue, DeltaValue: TStoredType;
  OldAutomaticApply: boolean;
  OldMatchDeltaSeconds: integer;
begin
  OldAutomaticApply := startMarkAutomaticApply;
  OldMatchDeltaSeconds := startMarkMatchDeltaSeconds;
  try
    startMarkMatchDeltaSeconds := 42;
    startMarkAutomaticApply := True;
    DeltaValue := '';
    AutomaticValue := '';

    MainForm.RxIniPropStorage1StoredValues15Save(nil, DeltaValue);
    MainForm.RxIniPropStorage1StoredValues16Save(nil, AutomaticValue);
    AssertEquals('42', string(DeltaValue));
    AssertEquals('True', string(AutomaticValue));

    startMarkMatchDeltaSeconds := 15;
    startMarkAutomaticApply := False;
    MainForm.RxIniPropStorage1StoredValues15Restore(nil, DeltaValue);
    MainForm.RxIniPropStorage1StoredValues16Restore(nil, AutomaticValue);
    AssertEquals(42, startMarkMatchDeltaSeconds);
    AssertTrue(startMarkAutomaticApply);

    DeltaValue := '61';
    MainForm.RxIniPropStorage1StoredValues15Restore(nil, DeltaValue);
    AssertEquals('Invalid values must restore the safe default',
      15, startMarkMatchDeltaSeconds);
  finally
    startMarkAutomaticApply := OldAutomaticApply;
    startMarkMatchDeltaSeconds := OldMatchDeltaSeconds;
  end;
end;

procedure TMainFlowIntegrationTests.MainIni_InvalidScalarValuesUseDefaults;
var
  InvalidValue: TStoredType;
  OldAutomaticBackup, OldZeroHour, OldShowStageName,
    OldCheckUpdateAtStartup: boolean;
  OldBackupPeriod, OldFinishDebounceInterval,
    OldCheckUpdateIntervalInDays: integer;
  OldLastUpdateCheckoutTime: TDateTime;
begin
  OldAutomaticBackup := doAutomaticBackup;
  OldBackupPeriod := backupPeriod;
  OldFinishDebounceInterval := MainForm.FinishDebounceInterval;
  OldZeroHour := zerohour;
  OldShowStageName := showStageNameForSingleStage;
  OldCheckUpdateAtStartup := checkUpdateAtStartup;
  OldLastUpdateCheckoutTime := lastUpdateCheckoutTime;
  OldCheckUpdateIntervalInDays := checkUpdateIntervalInDays;
  try
    doAutomaticBackup := False;
    backupPeriod := 1;
    MainForm.FinishDebounceInterval := 1;
    zerohour := False;
    showStageNameForSingleStage := True;
    checkUpdateAtStartup := False;
    lastUpdateCheckoutTime := EncodeDate(2025, 1, 2);
    checkUpdateIntervalInDays := 1;
    InvalidValue := 'damaged-value';

    MainForm.RxIniPropStorage1StoredValues10Restore(nil, InvalidValue);
    MainForm.RxIniPropStorage1StoredValues11Restore(nil, InvalidValue);
    MainForm.RxIniPropStorage1StoredValues2Restore(nil, InvalidValue);
    MainForm.RxIniPropStorage1StoredValues3Restore(nil, InvalidValue);
    MainForm.RxIniPropStorage1StoredValues6Restore(nil, InvalidValue);
    MainForm.RxIniPropStorage1StoredValues7Restore(nil, InvalidValue);
    MainForm.RxIniPropStorage1StoredValues8Restore(nil, InvalidValue);
    MainForm.RxIniPropStorage1StoredValues9Restore(nil, InvalidValue);

    AssertTrue(doAutomaticBackup);
    AssertEquals(10 * 60 * 1000, backupPeriod);
    AssertEquals(250, MainForm.FinishDebounceInterval);
    AssertTrue(zerohour);
    AssertFalse(showStageNameForSingleStage);
    AssertTrue(checkUpdateAtStartup);
    AssertTrue(lastUpdateCheckoutTime = 0);
    AssertEquals(7, checkUpdateIntervalInDays);
  finally
    doAutomaticBackup := OldAutomaticBackup;
    backupPeriod := OldBackupPeriod;
    MainForm.FinishDebounceInterval := OldFinishDebounceInterval;
    zerohour := OldZeroHour;
    showStageNameForSingleStage := OldShowStageName;
    checkUpdateAtStartup := OldCheckUpdateAtStartup;
    lastUpdateCheckoutTime := OldLastUpdateCheckoutTime;
    checkUpdateIntervalInDays := OldCheckUpdateIntervalInDays;
  end;
end;

procedure TMainFlowIntegrationTests.TelegramRetryIni_RoundTripsAndValidates;
var
  EnabledValue, CountValue, DelayValue: TStoredType;
  OldEnabled: Boolean;
  OldCount, OldDelay: Integer;
begin
  OldEnabled := telegramRetryEnabled;
  OldCount := telegramRetryCount;
  OldDelay := telegramRetryDelaySeconds;
  try
    telegramRetryEnabled := True;
    telegramRetryCount := 4;
    telegramRetryDelaySeconds := 12;
    EnabledValue := '';
    CountValue := '';
    DelayValue := '';

    MainForm.RxIniPropStorage1StoredValues19Save(nil, EnabledValue);
    MainForm.RxIniPropStorage1StoredValues20Save(nil, CountValue);
    MainForm.RxIniPropStorage1StoredValues21Save(nil, DelayValue);
    AssertEquals('True', string(EnabledValue));
    AssertEquals('4', string(CountValue));
    AssertEquals('12', string(DelayValue));

    telegramRetryEnabled := False;
    telegramRetryCount := 1;
    telegramRetryDelaySeconds := 1;
    MainForm.RxIniPropStorage1StoredValues19Restore(nil, EnabledValue);
    MainForm.RxIniPropStorage1StoredValues20Restore(nil, CountValue);
    MainForm.RxIniPropStorage1StoredValues21Restore(nil, DelayValue);
    AssertTrue(telegramRetryEnabled);
    AssertEquals(4, telegramRetryCount);
    AssertEquals(12, telegramRetryDelaySeconds);

    EnabledValue := 'invalid';
    CountValue := '0';
    DelayValue := '301';
    MainForm.RxIniPropStorage1StoredValues19Restore(nil, EnabledValue);
    MainForm.RxIniPropStorage1StoredValues20Restore(nil, CountValue);
    MainForm.RxIniPropStorage1StoredValues21Restore(nil, DelayValue);
    AssertFalse(telegramRetryEnabled);
    AssertEquals(TELEGRAM_RETRY_DEFAULT_COUNT, telegramRetryCount);
    AssertEquals(TELEGRAM_RETRY_DEFAULT_DELAY_SECONDS,
      telegramRetryDelaySeconds);
  finally
    telegramRetryEnabled := OldEnabled;
    telegramRetryCount := OldCount;
    telegramRetryDelaySeconds := OldDelay;
  end;
end;

procedure TMainFlowIntegrationTests.SettingsTelegramRetry_UsesStoredDraftValues;
var
  Form: TSettingsForm;
  OldEnabled: Boolean;
  OldCount, OldDelay: Integer;
begin
  OldEnabled := telegramRetryEnabled;
  OldCount := telegramRetryCount;
  OldDelay := telegramRetryDelaySeconds;
  try
    telegramRetryEnabled := True;
    telegramRetryCount := 7;
    telegramRetryDelaySeconds := 20;
    Form := TSettingsForm.Create(nil);
    try
      AssertTrue(Form.CheckBoxTelegramRetry.Checked);
      AssertEquals(7, Form.SpinTelegramRetryCount.Value);
      AssertEquals(20, Form.SpinTelegramRetryDelay.Value);
      AssertTrue(Form.SpinTelegramRetryCount.Enabled);
      AssertTrue(Form.SpinTelegramRetryDelay.Enabled);

      Form.CheckBoxTelegramRetry.Checked := False;
      Form.CheckBoxTelegramRetryChange(Form.CheckBoxTelegramRetry);
      AssertFalse(Form.SpinTelegramRetryCount.Enabled);
      AssertFalse(Form.SpinTelegramRetryDelay.Enabled);
      AssertTrue('Draft edits must not change globals before OK',
        telegramRetryEnabled);
    finally
      Form.Free;
    end;
  finally
    telegramRetryEnabled := OldEnabled;
    telegramRetryCount := OldCount;
    telegramRetryDelaySeconds := OldDelay;
  end;
end;

procedure TMainFlowIntegrationTests.BackupRetentionIni_RoundTripsAndValidates;
var
  DaysValue, SizeValue: TStoredType;
  OldRetentionDays, OldMaxSizeMb: integer;
  Policy: TBackupRetentionPolicy;
begin
  OldRetentionDays := automaticBackupRetentionDays;
  OldMaxSizeMb := automaticBackupMaxSizeMb;
  try
    automaticBackupRetentionDays := 45;
    automaticBackupMaxSizeMb := 3072;
    DaysValue := '';
    SizeValue := '';

    MainForm.RxIniPropStorage1StoredValues17Save(nil, DaysValue);
    MainForm.RxIniPropStorage1StoredValues18Save(nil, SizeValue);
    AssertEquals('45', string(DaysValue));
    AssertEquals('3072', string(SizeValue));

    automaticBackupRetentionDays := 1;
    automaticBackupMaxSizeMb := 1;
    MainForm.RxIniPropStorage1StoredValues17Restore(nil, DaysValue);
    MainForm.RxIniPropStorage1StoredValues18Restore(nil, SizeValue);
    AssertEquals(45, automaticBackupRetentionDays);
    AssertEquals(3072, automaticBackupMaxSizeMb);

    Policy := CurrentBackupRetentionPolicy;
    AssertEquals(45, Policy.AutomaticRetentionDays);
    AssertEquals(Int64(3072) * 1024 * 1024,
      Policy.AutomaticMaxTotalBytes);

    DaysValue := '0';
    SizeValue := 'invalid';
    MainForm.RxIniPropStorage1StoredValues17Restore(nil, DaysValue);
    MainForm.RxIniPropStorage1StoredValues18Restore(nil, SizeValue);
    AssertEquals(DEFAULT_AUTOMATIC_BACKUP_RETENTION_DAYS,
      automaticBackupRetentionDays);
    AssertEquals(DEFAULT_AUTOMATIC_BACKUP_MAX_SIZE_MB,
      automaticBackupMaxSizeMb);
  finally
    automaticBackupRetentionDays := OldRetentionDays;
    automaticBackupMaxSizeMb := OldMaxSizeMb;
  end;
end;

procedure TMainFlowIntegrationTests.SettingsBackupRetention_UsesStoredValues;
var
  Form: TSettingsForm;
  OldRetentionDays, OldMaxSizeMb: integer;
begin
  OldRetentionDays := automaticBackupRetentionDays;
  OldMaxSizeMb := automaticBackupMaxSizeMb;
  try
    automaticBackupRetentionDays := 75;
    automaticBackupMaxSizeMb := 4096;
    Form := TSettingsForm.Create(nil);
    try
      AssertEquals(75, Form.SpinBackupRetentionDays.Value);
      AssertEquals(4096, Form.SpinBackupMaxSizeMb.Value);
      AssertTrue(Form.LabelBackupRetentionDays.Left +
        Form.LabelBackupRetentionDays.Width <=
        Form.SpinBackupRetentionDays.Left);
      AssertTrue(Form.SpinBackupRetentionDays.Left +
        Form.SpinBackupRetentionDays.Width <=
        Form.LabelBackupRetentionDaysUnit.Left);
      AssertTrue(Form.PanelBackup.Height >=
        Form.SpinBackupMaxSizeMb.Top + Form.SpinBackupMaxSizeMb.Height);
    finally
      Form.Free;
    end;
  finally
    automaticBackupRetentionDays := OldRetentionDays;
    automaticBackupMaxSizeMb := OldMaxSizeMb;
  end;
end;

procedure TMainFlowIntegrationTests.SettingsCompetitionPage_UsesScrollableContent;
var
  form: TSettingsForm;
  firstRow, ninthRow: TStageSettingsFrame;
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

    form.Height := form.Height + 200;
    Application.ProcessMessages;
    AssertTrue('Extra window height must not create page scrolling',
      form.CompetitionScrollBox.VertScrollBar.Range <=
      form.CompetitionScrollBox.ClientHeight);

    form.StageCountSpinEdit.Value := 8;
    Application.ProcessMessages;
    firstRow := TStageSettingsFrame(form.FindComponent(
      'StageSettingsFrame1'));
    form.StageCountSpinEdit.Value := 9;
    Application.ProcessMessages;
    AssertSame('Existing stage rows must be reused when the count grows',
      firstRow, form.FindComponent('StageSettingsFrame1'));
    ninthRow := TStageSettingsFrame(form.FindComponent(
      'StageSettingsFrame9'));
    AssertTrue(ninthRow.Visible);
    form.StageCountSpinEdit.Value := 8;
    Application.ProcessMessages;
    AssertSame('A reduced stage row must stay allocated for reuse',
      ninthRow, form.FindComponent('StageSettingsFrame9'));
    AssertFalse(ninthRow.Visible);
    form.StageCountSpinEdit.Value := 9;
    Application.ProcessMessages;
    AssertSame('A hidden stage row must be reused after re-expansion',
      ninthRow, form.FindComponent('StageSettingsFrame9'));
    AssertTrue(ninthRow.Visible);

    form.StageCountSpinEdit.Value := MAX_SUPPORTED_STAGE_COUNT;
    Application.ProcessMessages;
    AssertEquals('The stage list must expose every row',
      MAX_SUPPORTED_STAGE_COUNT * 34, form.StagesContentPanel.Height);
    AssertTrue('The stages section must grow with its content',
      form.GroupBoxStages.ClientHeight >=
      form.ActiveStagePanel.Top + form.ActiveStagePanel.Height);
    AssertTrue('The expanded stage list must use the page scroll range',
      form.CompetitionScrollBox.VertScrollBar.Range >
      form.CompetitionScrollBox.ClientHeight);
    form.CompetitionScrollBox.VertScrollBar.Position := 100;
    Application.ProcessMessages;
    AssertTrue('The competition page must be vertically scrollable',
      form.CompetitionScrollBox.VertScrollBar.Position > 0);

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

procedure TMainFlowIntegrationTests.SettingsStageLabels_RefreshWhenLanguageChanges;
var
  form: TSettingsForm;
  firstRow: TStageSettingsFrame;
  originalLanguage: string;
begin
  originalLanguage := CurrentLang;
  MainForm.SetLang('ru');
  form := TSettingsForm.Create(nil);
  try
    firstRow := TStageSettingsFrame(form.FindComponent(
      'StageSettingsFrame1'));
    AssertTrue(firstRow <> nil);
    AssertEquals('Количество спецучастков', form.StageCountLabel.Caption);
    AssertEquals('СУ 1', firstRow.StageLabel.Caption);

    form.ComboBoxLanguage.Text := rsEnglish;
    form.ComboBoxLanguageChange(form.ComboBoxLanguage);

    AssertEquals('Number of stages', form.StageCountLabel.Caption);
    AssertEquals('Stage 1', firstRow.StageLabel.Caption);
  finally
    form.Free;
    MainForm.SetLang(originalLanguage);
  end;
end;

procedure TMainFlowIntegrationTests.SettingsStageDraft_AppliesOnlyAfterAccept;
var
  originalStageName: string;
begin
  CreateNewCompetitionFile;
  originalStageName := stages[1].Name;
  AssertEquals(1, stages.Count);

  Application.QueueAsyncCall(@EditStageDraftAndClose, mrCancel);
  SettingsForm.RunSettings;

  AssertEquals('Cancel must preserve the stage name', originalStageName,
    stages[1].Name);
  AssertEquals('Cancel must preserve the stage count', 1, stages.Count);
  AssertEquals('Cancel must not store the draft name', '',
    LoadConfigValueFromFile(FDbFilePath, 'stagename1', ''));
  AssertEquals('Cancel must not store draft activity', '',
    LoadConfigValueFromFile(FDbFilePath, 'stage2', ''));

  Application.QueueAsyncCall(@EditStageDraftAndClose, mrOk);
  SettingsForm.RunSettings;

  AssertEquals('Accepted draft stage', stages[1].Name);
  AssertEquals(2, stages.Count);
  AssertTrue(stages[2].isActive);
  AssertEquals('Accepted draft stage', LoadConfigValueFromFile(
    FDbFilePath, 'stagename1', ''));
  AssertEquals('True', LoadConfigValueFromFile(FDbFilePath, 'stage2', ''));
end;

procedure TMainFlowIntegrationTests.SettingsStageDraft_RequiresAtLeastOneActiveStage;
var
  canClose: boolean;
  form: TSettingsForm;
  stageIndex: integer;
  storedStageOneActive: string;
begin
  CreateNewCompetitionFile;
  storedStageOneActive := LoadConfigValueFromFile(
    FDbFilePath, 'stage1', '');
  AssertTrue(stages[1].isActive);

  form := TSettingsForm.Create(nil);
  try
    for stageIndex := 1 to form.StageCountSpinEdit.Value do
      TStageSettingsFrame(form.FindComponent('StageSettingsFrame' +
        IntToStr(stageIndex))).Active := False;
    AssertFalse(form.ComboBoxAStage.Enabled);

    form.ModalResult := mrOk;
    canClose := True;
    form.FormCloseQuery(form, canClose);

    AssertFalse('Settings must reject a draft without active stages',
      canClose);
    AssertEquals(1, DialogCallCount);
    AssertEquals(rsAtLeastOneActiveStageRequired, LastDialogMessage);
  finally
    form.Free;
  end;

  AssertTrue('Rejected draft must not change the stage model',
    stages[1].isActive);
  AssertEquals('Rejected draft must not change the database',
    storedStageOneActive, LoadConfigValueFromFile(
    FDbFilePath, 'stage1', ''));
end;

procedure TMainFlowIntegrationTests.SettingsStageCount_ExpandsSchemaAndCreatesBackup;
var
  stageIndex: integer;
begin
  CreateNewCompetitionFile;
  DeleteBackupFiles;
  AssertEquals(DEFAULT_STAGE_COUNT,
    TSchemaSql.DetectStageCapacity(MainForm.SQLQuery1));

  SettingsDraftStageCount := MAX_SUPPORTED_STAGE_COUNT;
  SettingsDraftStageName := 'Expanded stage 32';
  SettingsDraftStageActive := True;
  SettingsDraftActiveStageIndex := MAX_SUPPORTED_STAGE_COUNT;
  Application.QueueAsyncCall(@ResizeStageDraftAndClose, mrOk);
  SettingsForm.RunSettings(2);

  AssertTrue(IsCompetitionDatabaseOpen);
  AssertEquals(MAX_SUPPORTED_STAGE_COUNT, stages.Count);
  AssertEquals(MAX_SUPPORTED_STAGE_COUNT, StoredStageCount);
  AssertEquals(MAX_SUPPORTED_STAGE_COUNT,
    TSchemaSql.DetectStageCapacity(MainForm.SQLQuery1));
  AssertEquals(IntToStr(MAX_SUPPORTED_STAGE_COUNT),
    LoadConfigValueFromFile(FDbFilePath, 'stagecount', ''));
  AssertEquals('Expanded stage 32', LoadConfigValueFromFile(
    FDbFilePath, 'stagename32', ''));
  AssertEquals('True', LoadConfigValueFromFile(FDbFilePath, 'stage32', ''));
  AssertEquals(IntToStr(MAX_SUPPORTED_STAGE_COUNT),
    LoadConfigValueFromFile(FDbFilePath, 'activestage', ''));
  AssertEquals(Format(rsSUFormat, [9]), LoadConfigValueFromFile(
    FDbFilePath, 'stagename9', ''));
  AssertEquals('True', LoadConfigValueFromFile(FDbFilePath, 'stage9', ''));
  for stageIndex := 1 to MAX_SUPPORTED_STAGE_COUNT do
    AssertTrue('Every newly added stage must be active: ' +
      IntToStr(stageIndex), stages[stageIndex].isActive);
  AssertEquals('Expanded stage 32',
    stages[MAX_SUPPORTED_STAGE_COUNT].Name);
  AssertTrue(stages[MAX_SUPPORTED_STAGE_COUNT].isActive);
  AssertTrue('Schema expansion must create a backup beside the database',
    FindBackupFile <> '');
  AssertTrue(MainForm.MainDataset1.FindField('starttime32') <> nil);

  MainForm.FileCloseExecute(nil);
  OpenCompetitionFile(FDbFilePath);
  AssertTrue(IsCompetitionDatabaseOpen);
  AssertEquals(MAX_SUPPORTED_STAGE_COUNT, stages.Count);
  AssertEquals('Expanded stage 32',
    stages[MAX_SUPPORTED_STAGE_COUNT].Name);
  AssertTrue(stages[MAX_SUPPORTED_STAGE_COUNT].isActive);
end;

procedure TMainFlowIntegrationTests.SettingsStageCount_SoftReductionPreservesHiddenStage;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  CreateSchemaFixture(12, '12',
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  UnitOfWork := MainForm.CompetitionDb.BeginUnitOfWork;
  try
    TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stage11', 'False');
    TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'stagename11',
      'Saved inactive stage 11');
    MainForm.SQLQuery1.SQL.Text :=
      'UPDATE main SET starttime12 = ''10:00:00.000'', ' +
      'finishtime12 = ''10:42:00.000'', result12 = ''00:42:00.000'' ' +
      'WHERE number = 808;';
    MainForm.SQLQuery1.ExecSQL;
    MainForm.SQLQuery1.Close;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;

  SettingsDraftStageCount := 5;
  Application.QueueAsyncCall(@ResizeStageDraftAndClose, mrOk);
  SettingsForm.RunSettings(2);

  AssertEquals(1, DialogCallCount);
  AssertTrue(Pos(Format(rsStageCountReductionWarning, [12, 5]),
    LastDialogMessage) > 0);
  AssertEquals(5, stages.Count);
  AssertEquals('5', LoadConfigValueFromFile(FDbFilePath, 'stagecount', ''));
  AssertEquals(12, TSchemaSql.DetectStageCapacity(MainForm.SQLQuery1));
  AssertEquals('Legacy stage 12', LoadConfigValueFromFile(
    FDbFilePath, 'stagename12', ''));
  AssertEquals('True', LoadConfigValueFromFile(FDbFilePath, 'stage12', ''));
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT result12 FROM main WHERE number = 808;';
  MainForm.SQLQuery1.Open;
  AssertEquals('00:42:00.000',
    MainForm.SQLQuery1.FieldByName('result12').AsString);
  MainForm.SQLQuery1.Close;

  DialogCallCount := 0;
  LastDialogMessage := '';
  SettingsDraftStageCount := 12;
  SettingsDraftActiveStageIndex := 12;
  Application.QueueAsyncCall(@ResizeStageDraftAndClose, mrOk);
  SettingsForm.RunSettings(2);

  AssertEquals(0, DialogCallCount);
  AssertEquals(12, stages.Count);
  AssertEquals('Legacy stage 12', stages[12].Name);
  AssertTrue(stages[12].isActive);
  AssertEquals('Saved inactive stage 11', stages[11].Name);
  AssertFalse('A restored hidden stage must keep its saved activity',
    stages[11].isActive);
  AssertEquals('False', LoadConfigValueFromFile(
    FDbFilePath, 'stage11', ''));
  AssertEquals('12', LoadConfigValueFromFile(FDbFilePath, 'stagecount', ''));
  AssertEquals('12', LoadConfigValueFromFile(FDbFilePath, 'activestage', ''));
  AssertEquals('', FindBackupFile);
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT result12 FROM main WHERE number = 808;';
  MainForm.SQLQuery1.Open;
  AssertEquals('00:42:00.000',
    MainForm.SQLQuery1.FieldByName('result12').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.SettingsStageCount_KeepsMainGridSortingUsable;
var
  sortEngine: TEntimeSQLQuerySortEngine;
begin
  CreateNewCompetitionFile;
  InsertParticipant(410);
  InsertParticipant(420);
  sortEngine := TEntimeSQLQuerySortEngine.Create;
  try
    MainForm.RxDBGrid1.SetSort(['number'], [smDown], False);
    AssertEquals('The initial sort column must be registered',
      1, MainForm.RxDBGrid1.SortColumns.Count);
    sortEngine.Sort('number', MainForm.MainDataset1, False, []);
    MainForm.MainDataset1.First;
    AssertEquals(420,
      MainForm.MainDataset1.FieldByName('number').AsInteger);

    SettingsDraftStageCount := 12;
    SettingsDraftActiveStageIndex := 1;
    Application.QueueAsyncCall(@ResizeStageDraftAndClose, mrOk);
    SettingsForm.RunSettings(2);

    MainForm.RxDBGrid1.SetSort(['number'], [smUp], False);
    AssertEquals('Sorting must remain available after expansion',
      1, MainForm.RxDBGrid1.SortColumns.Count);
    sortEngine.Sort('number', MainForm.MainDataset1, True, []);
    MainForm.MainDataset1.First;
    AssertEquals('Ascending sorting must work after expansion', 410,
      MainForm.MainDataset1.FieldByName('number').AsInteger);

    SettingsDraftStageCount := 5;
    SettingsDraftActiveStageIndex := 1;
    Application.QueueAsyncCall(@ResizeStageDraftAndClose, mrOk);
    SettingsForm.RunSettings(2);

    MainForm.RxDBGrid1.SetSort(['number'], [smDown], False);
    AssertEquals('Sorting must remain available after soft reduction',
      1, MainForm.RxDBGrid1.SortColumns.Count);
    sortEngine.Sort('number', MainForm.MainDataset1, False, []);
    MainForm.MainDataset1.First;
    AssertEquals('Descending sorting must work after soft reduction', 420,
      MainForm.MainDataset1.FieldByName('number').AsInteger);
  finally
    sortEngine.Free;
  end;
end;

procedure TMainFlowIntegrationTests.SettingsStageCount_RebuildsUiAndPreservesCurrentContext;
begin
  CreateSchemaFixture(12, '12',
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  InsertParticipant(809);
  AssertTrue(MainForm.MainDataset1.Locate('number', 808, []));
  MainForm.SelectCurrentStage(8);
  SettingsDraftStageCount := 10;
  SettingsDraftActiveStageIndex := 8;
  Application.QueueAsyncCall(@ResizeStageDraftAndClose, mrOk);
  SettingsForm.RunSettings(2);

  AssertTrue(IsCompetitionDatabaseOpen);
  AssertEquals('A still-valid current stage must be preserved', 8,
    MainForm.CurrentStageIndex);
  AssertEquals('The current participant must be restored after rebuilding',
    808, MainForm.MainDataset1.FieldByName('number').AsInteger);
  AssertEquals('8', astage);
  AssertDynamicStageFields(10);
  AssertDynamicStageColumns(10);
  AssertDynamicStageResultUi(10);
  AssertTrue(Pos('finishtime8', ResultsForm.ResultDataset.SQL.Text) > 0);

  SettingsDraftStageCount := 5;
  SettingsDraftActiveStageIndex := 1;
  Application.QueueAsyncCall(@ResizeStageDraftAndClose, mrOk);
  SettingsForm.RunSettings(2);

  AssertEquals('An unavailable current stage must fall back to the first active stage',
    1, MainForm.CurrentStageIndex);
  AssertEquals('The participant must stay current after the fallback rebuild',
    808, MainForm.MainDataset1.FieldByName('number').AsInteger);
  AssertEquals('1', astage);
  AssertDynamicStageFields(5);
  AssertDynamicStageColumns(5);
  AssertDynamicStageResultUi(5);
  AssertTrue(Pos('finishtime1', ResultsForm.ResultDataset.SQL.Text) > 0);
end;

procedure TMainFlowIntegrationTests.SettingsStageActivity_KeepsMainDatasetOpenForSparseStage;
const
  ACTIVE_STAGE_INDEX = 31;
begin
  CreateSchemaFixture(MAX_SUPPORTED_STAGE_COUNT,
    IntToStr(MAX_SUPPORTED_STAGE_COUNT),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET status = ''1'' WHERE number = 808;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  RefreshCompetitionViews;
  AssertTrue(MainForm.MainDataset1.Locate('number', 808, []));

  SettingsDraftActiveStageIndex := ACTIVE_STAGE_INDEX;
  FMainDatasetOpenCount := 0;
  MainForm.MainDataset1.AfterOpen := @CountMainDatasetOpen;
  Application.QueueAsyncCall(@ActivateOnlyStageAndClose, mrOk);
  try
    SettingsForm.RunSettings(2);
  finally
    MainForm.MainDataset1.AfterOpen := nil;
  end;

  AssertEquals('Activity changes must reopen the main dataset exactly once',
    1, FMainDatasetOpenCount);
  AssertTrue('Changing only stage activity must reopen the main dataset',
    MainForm.MainDataset1.Active);
  AssertFalse('The main table must still contain its participant row',
    MainForm.MainDataset1.IsEmpty);
  AssertEquals(1, stages.ActiveStagesCount);
  AssertTrue(stages[ACTIVE_STAGE_INDEX].isActive);
  AssertEquals(ACTIVE_STAGE_INDEX, MainForm.CurrentStageIndex);
  AssertTrue('The active sparse stage field must be attached',
    MainForm.MainDataset1.FindField(
      'starttime' + IntToStr(ACTIVE_STAGE_INDEX)) <> nil);
  AssertTrue('An inactive stage field must not be attached',
    MainForm.MainDataset1.FindField('starttime1') = nil);
  AssertTrue('The sparse query must select stage 31',
    Pos('"starttime31"', MainForm.MainDataset1.SQL.Text) > 0);
  AssertEquals(808, MainForm.MainDataset1.FieldByName('number').AsInteger);
  AssertTrue('Activity changes must recalculate global statuses while the ' +
    'main dataset is temporarily closed',
    MainForm.MainDataset1.FieldByName('status').IsNull);
end;

procedure TMainFlowIntegrationTests.
  SettingsStageActivity_ReactivatesAllStagesAndPreservesEditing;
const
  PARTICIPANT_NUMBER = 808;
  SPARSE_STAGE_INDEX = 31;
begin
  CreateSchemaFixture(MAX_SUPPORTED_STAGE_COUNT,
    IntToStr(MAX_SUPPORTED_STAGE_COUNT),
    IntToStr(CURRENT_COMPETITION_SCHEMA_VERSION));
  OpenCompetitionFile(FDbFilePath);

  SettingsDraftActiveStageIndex := SPARSE_STAGE_INDEX;
  Application.QueueAsyncCall(@ActivateOnlyStageAndClose, mrOk);
  SettingsForm.RunSettings(2);

  AssertTrue(MainForm.MainDataset1.Locate('number', PARTICIPANT_NUMBER, []));
  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('starttime31').AsString :=
    '11:00:00.000';
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;
  AssertEquals('11:00:00.000',
    MainForm.MainDataset1.FieldByName('starttime31').AsString);

  SettingsDraftActiveStageIndex := SPARSE_STAGE_INDEX;
  Application.QueueAsyncCall(@ActivateAllStagesAndClose, mrOk);
  SettingsForm.RunSettings(2);

  AssertTrue('The main dataset must remain open after reactivating all stages',
    MainForm.MainDataset1.Active);
  AssertEquals(MAX_SUPPORTED_STAGE_COUNT, stages.ActiveStagesCount);
  AssertEquals('The selected sparse stage must remain current',
    SPARSE_STAGE_INDEX, MainForm.CurrentStageIndex);
  AssertEquals('The edited participant must remain current',
    PARTICIPANT_NUMBER,
    MainForm.MainDataset1.FieldByName('number').AsInteger);
  AssertTrue(MainForm.MainDataset1.FindField('starttime1') <> nil);
  AssertTrue(MainForm.MainDataset1.FindField('starttime31') <> nil);
  AssertTrue(MainForm.MainDataset1.FindField('starttime32') <> nil);
  AssertEquals('Data edited in sparse mode must survive reactivation',
    '11:00:00.000',
    MainForm.MainDataset1.FieldByName('starttime31').AsString);

  MainForm.MainDataset1.Edit;
  MainForm.MainDataset1.FieldByName('penalty32').AsString :=
    '00:00:10.000';
  MainForm.MainDataset1.Post;
  MainForm.RxDBGrid1EditingDone(MainForm.RxDBGrid1);
  Application.ProcessMessages;
  AssertTrue('Editing must keep the expanded main dataset open',
    MainForm.MainDataset1.Active);
  AssertEquals('Editing stage 32 must keep the participant current',
    PARTICIPANT_NUMBER,
    MainForm.MainDataset1.FieldByName('number').AsInteger);
  AssertEquals('00:00:10.000',
    MainForm.MainDataset1.FieldByName('penalty32').AsString);

  MainForm.FileCloseExecute(nil);
  OpenCompetitionFile(FDbFilePath);
  AssertTrue(MainForm.MainDataset1.Locate('number', PARTICIPANT_NUMBER, []));
  AssertEquals('11:00:00.000',
    MainForm.MainDataset1.FieldByName('starttime31').AsString);
  AssertEquals('00:00:10.000',
    MainForm.MainDataset1.FieldByName('penalty32').AsString);
end;

procedure TMainFlowIntegrationTests.SettingsNoChanges_DoesNotRefreshDatasets;
begin
  CreateNewCompetitionFile;
  InsertParticipant(810);
  AssertTrue(MainForm.MainDataset1.Locate('number', 810, []));
  FMainDatasetOpenCount := 0;
  FResultDatasetOpenCount := 0;
  MainForm.MainDataset1.AfterOpen := @CountMainDatasetOpen;
  ResultsForm.ResultDataset.AfterOpen := @CountResultDatasetOpen;
  try
    Application.QueueAsyncCall(@CloseSettingsForm, mrOk);
    SettingsForm.RunSettings(2);
  finally
    MainForm.MainDataset1.AfterOpen := nil;
    ResultsForm.ResultDataset.AfterOpen := nil;
  end;

  AssertEquals('Saving unchanged settings must not reopen MainDataset1',
    0, FMainDatasetOpenCount);
  AssertEquals('Saving unchanged settings must not refresh result queries',
    0, FResultDatasetOpenCount);
  AssertTrue(MainForm.MainDataset1.Active);
  AssertEquals(810, MainForm.MainDataset1.FieldByName('number').AsInteger);
end;

procedure TMainFlowIntegrationTests.SettingsStageName_UpdatesUiWithoutRefreshingMainDataset;
var
  stageColumn: TRxColumn;
  stageSheet: TTabSheet;
begin
  CreateNewCompetitionFile;
  stageColumn := MainForm.RxDBGrid1.ColumnByFieldName('correction1');
  stageSheet := MainForm.StageResultView(1).Sheet;
  SettingsDraftStageName := 'Renamed without refresh';
  FMainDatasetOpenCount := 0;
  MainForm.MainDataset1.AfterOpen := @CountMainDatasetOpen;
  try
    Application.QueueAsyncCall(@RenameFirstStageAndClose, mrOk);
    SettingsForm.RunSettings(2);
  finally
    MainForm.MainDataset1.AfterOpen := nil;
  end;

  AssertEquals(0, FMainDatasetOpenCount);
  AssertTrue(MainForm.MainDataset1.Active);
  AssertEquals(SettingsDraftStageName, stages[1].Name);
  AssertSame('Renaming must reuse the existing main-grid column', stageColumn,
    MainForm.RxDBGrid1.ColumnByFieldName('correction1'));
  AssertSame('Renaming must reuse the existing result tab', stageSheet,
    MainForm.StageResultView(1).Sheet);
  AssertEquals(rsCurrentResults + ': ' + SettingsDraftStageName,
    ResultsForm.GroupBoxResults.Caption);
end;

procedure TMainFlowIntegrationTests.SettingsResultCategory_RefreshesOnlyResultQueries;
begin
  CreateNewCompetitionFile;
  SettingsDraftCategoryName := 'Updated result category';
  FMainDatasetOpenCount := 0;
  FResultDatasetOpenCount := 0;
  MainForm.MainDataset1.AfterOpen := @CountMainDatasetOpen;
  ResultsForm.ResultDataset.AfterOpen := @CountResultDatasetOpen;
  try
    Application.QueueAsyncCall(@ChangeResultCategoryAndClose, mrOk);
    SettingsForm.RunSettings(2);
  finally
    MainForm.MainDataset1.AfterOpen := nil;
    ResultsForm.ResultDataset.AfterOpen := nil;
  end;

  AssertEquals('Presentation changes must not reopen MainDataset1',
    0, FMainDatasetOpenCount);
  AssertEquals('Result queries must be refreshed exactly once',
    1, FResultDatasetOpenCount);
  AssertEquals(SettingsDraftCategoryName, cat[1]);
  AssertEquals(SettingsDraftCategoryName,
    ResultsForm.GroupBox1.Caption);
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
