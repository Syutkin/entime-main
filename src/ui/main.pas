unit Main;

{$mode objfpc}{$H+}

{$IFOPT D+} {$DEFINE DEBUG} {$ENDIF}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Dialogs, StdCtrls, LazSerial,
  LazSerialDevices,
  lazserialsetup, synaser, HistoryFiles, ComCtrls, ExtCtrls,
  LCLType, LResources, Menus, ActnList, StdActns, Grids, rxdbgrid, rxlookup,
  rxdbcomb, rxtoolbar, RxTimeEdit, RxIniPropStorage, rxspin, RxAboutDialog,
  RxDBGridExportSpreadSheet, rxFileUtils, DB, sqlite3conn, sqldb, fpcsvexport,
  dateutils, Controls, DBGrids, Graphics, i18n, gettext, LCLTranslator,
  translations, VersionSupport, LazUTF8, PropertyStorage, Buttons, DBCtrls,
  Types, Clipbrd, lclintf, fpDBExport, StartList, MyRxDBGrid,
  LazBleClient, LazBleComponent, LazBleDeviceControl, LazBleLclScan,
  LazBleLclTranslations, LazBleTypes, StageModel, StageConfig,
  StageFieldNames, StageFieldFactory, StageGridColumnFactory, StageResultTabs,
  Updater, AppLogger, DbSql, TimingProtocol, TimingMark, StartMark, FinishMark,
  FirmwareResponseProtocol, TransportStreamProcessor,
  TimingPacketMarkMapper, TimingMarkRouter,
  StartMarkService, FinishMarkService,
  FinishMarkSqliteAdapters,
  TimingTransport, SerialTimingTransport,
  LazSerialTimingConnection, TimingTransportController,
  SerialDeviceProvider, BleTimingTransport, CompetitionBackupService,
  ParticipantStatus,
  CompetitionFinishService, CompetitionRefreshCoordinator, HttpTransport,
  FpHttpTransport, TelegramNotificationCoordinator, LedPanelCoordinator;

type
  { TMainForm }

  TMainForm = class(TForm)
    AcCOMSetup: TAction;
    AcCOMOpen: TAction;
    AcCOMClose: TAction;
    AcApplyFinishMarks: TAction;
    AcClearResults: TAction;
    AcRunSettings: TAction;
    AcOpenLogFile: TAction;
    AcOpenLogDirectory: TAction;
    AcDeleteNumber: TAction;
    AcSetDNF: TAction;
    AcSetDNS: TAction;
    AcSetDSQ: TAction;
    AcSetDNSCor: TAction;
    AcSetDNFOnTrace: TAction;
    AcSetClear: TAction;
    AcSyncModule: TAction;
    AcApplyStartMarks: TAction;
    AcClearStartMarks: TAction;
    AcOpenStartMarkJournal: TAction;
    AcOpenFinishMarkJournal: TAction;
    AcGenerateStartTime: TAction;
    AcSetStarttime: TAction;
    AcLEDPanel: TAction;
    AcTelegramBot: TAction;
    AcRunRaceSettings: TAction;
    AcCheckUpdate: TAction;
    ExportStageResults: TAction;
    CheckBoxAutomaticUpdateResutls: TCheckBox;
    CSVResultsExporter: TCSVExporter;
    CSVStartListExporter: TCSVExporter;
    CurrentStageComboBox: TComboBox;
    CurrentStageGroup: TGroupBox;
    FileExportCSVStartlist: TFileSaveAs;
    FileExportCSVResults: TFileSaveAs;
    FileExportStageResultsSaveAs: TFileSaveAs;
    EditCopy1: TEditCopy;
    ImageList1: TImageList;
    LazBleComponent1: TLazBleComponent;
    LazBleLclClient1: TLazBleLclClient;
    ButtonApplyStartMarks: TButton;
    ButtonStartMarksClear: TButton;
    DataSourceFinishMarks: TDataSource;
    DataSourceStartMarks: TDataSource;
    FileGenerateFinal: TFileSaveAs;
    MainDataset1comment: TStringField;
    MainDataset1email: TStringField;
    MainDataset1phone: TStringField;
    MainDataset1sumstages: TLongintField;
    MainDataset1thrudiff: TStringField;
    MainDataset1thruplace: TLongintField;
    MenuItemOpenStartMarkJournal: TMenuItem;
    MenuItemOpenFinishMarkJournal: TMenuItem;
    Separator4: TMenuItem;
    Separator2: TMenuItem;
    MenuItemCheckUpdate: TMenuItem;
    MenuItemExportCSVResults: TMenuItem;
    MenuItem2: TMenuItem;
    MainPanel: TPanel;
    RxDBGrid1: TMyRxDBGrid;
    Separator1: TMenuItem;
    MenuItemExportCSVStartList: TMenuItem;
    MenuItemTelegramBot: TMenuItem;
    Separator3: TMenuItem;
    MenuItemLED: TMenuItem;
    pmSetStartTime: TMenuItem;
    N12: TMenuItem;
    N15: TMenuItem;
    MenuItemExportStageResults: TMenuItem;
    N9: TMenuItem;
    pmCopy: TMenuItem;
    N10: TMenuItem;
    MenuItemMonitorMode: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItemGenerateStartTime: TMenuItem;
    MenuItemCompetition: TMenuItem;
    MenuItemDebug: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    N6: TMenuItem;
    MenuItemGenerateFinal: TMenuItem;
    ComboBox1Category: TComboBox;
    FileNewDB: TFileSaveAs;
    GridResultStageTotal: TRxDBGrid;
    GridResultStageSum: TRxDBGrid;
    HistoryFiles1: THistoryFiles;
    MenuItemAbout: TMenuItem;
    MenuItemCOMClose: TMenuItem;
    MenuItemHelp: TMenuItem;
    N5: TMenuItem;
    MenuItemCOMSync: TMenuItem;
    N4: TMenuItem;
    MenuItemCOMOpen: TMenuItem;
    MenuItemSettings: TMenuItem;
    MenuItemLog: TMenuItem;
    MenuItemOpenLogFile: TMenuItem;
    MenuItemOpenLogDirectory: TMenuItem;
    PanelStartMarks: TGroupBox;
    PanelResult: TGroupBox;
    PopupMenuStartMarks: TPopupMenu;
    PopupMenuFinishMarks: TPopupMenu;
    RxAboutDialog1: TRxAboutDialog;
    RxDBComboBox1: TRxDBComboBox;
    RxDBGridStartMarks: TRxDBGrid;
    RxDBLookupCombo1: TRxDBLookupCombo;
    RxIniPropStorage1: TRxIniPropStorage;
    pmSetClear: TMenuItem;
    ResultDatasetStageTotal: TSQLQuery;
    ResultDatasetStageSum: TSQLQuery;
    FileOpenCSVResult: TFileOpen;
    MainDataset1sumdiffleader: TStringField;
    MainDataset1sumplace: TLongintField;
    MainDataset1sumresult: TStringField;
    MenuItem1: TMenuItem;
    MenuItemImportResults: TMenuItem;
    OnTracePopupMenu: TPopupMenu;
    ResultDataSourceStageTotal: TDataSource;
    ResultDataSourceStageSum: TDataSource;
    SheetStage: TPageControl;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    DatasetFinishMarks: TSQLQuery;
    DatasetStartMarks: TSQLQuery;
    SQLQuery2: TSQLQuery;
    StatDataset1id: TLongintField;
    StatDataset2name: TStringField;
    StatDataset2number: TLongintField;
    StatDataset2starttime: TStringField;
    StatDataset2timeontrack: TStringField;
    StatDataSource2: TDataSource;
    Empty: TAction;
    AcUpdateResults: TAction;
    ButtonSetFinish: TButton;
    Clock: TStaticText;
    ComboBoxLog: TComboBox;
    CorrectionDataSource: TDataSource;
    pmDeleteNumber: TMenuItem;
    GroupBox2: TGroupBox;
    MainDataset1status: TStringField;
    CorrectionPopupMenu: TPopupMenu;
    StatRxDBGrid2: TRxDBGrid;
    pmSetDNSCor: TMenuItem;
    pmSetStatus: TMenuItem;
    pmSetDNS: TMenuItem;
    pmSetDNF: TMenuItem;
    pmSetDSQ: TMenuItem;
    StatDataset2: TSQLQuery;
    TimingInputControl: TPanel;
    TimingInputDeviceLabel: TLabel;
    TimingInputStateButton: TSpeedButton;
    TimingInputStatusText: TStaticText;
    StatusBarPanel: TPanel;
    StatDataset1catcount: TLargeintField;
    StatDataset1category: TStringField;
    StatDataSource1: TDataSource;
    GroupBox1: TGroupBox;
    MainDataset1age: TStringField;
    MainDataset1category: TStringField;
    MainDataset1city: TStringField;
    MainDataset1id: TAutoIncField;
    MainDataset1name: TStringField;
    MainDataset1nickname: TStringField;
    MainDataset1number: TLongintField;
    MainDataset1rfid: TStringField;
    MainDataset1team: TStringField;
    TabSheetMainPanel: TPanel;
    EditPanel: TPanel;
    N1: TMenuItem;
    PageControl1: TPageControl;
    StatRxDBGrid1: TRxDBGrid;
    StatDataset1: TSQLQuery;
    TabSheet1: TTabSheet;
    SheetStageTotal: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    SheetStageSum: TTabSheet;
    pmUpdateResults: TMenuItem;
    MenuItemTools: TMenuItem;
    RaceModeLabel: TLabel;
    RaceMode: TCheckBox;
    FileClose: TAction;
    AcViewResults: TAction;
    AcViewMemo: TAction;
    ActionList1: TActionList;
    FileExit: TFileExit;
    FileOpenCSV: TFileOpen;
    MainDataSource1: TDataSource;
    pmClearResults: TMenuItem;
    MenuItemOpenCSV: TMenuItem;
    PopupMenu1: TPopupMenu;
    ResultClear: TButton;
    CorrectionPanel: TPanel;
    RxDBGridCorrection: TRxDBGrid;
    RxDBGridFinishMarks: TRxDBGrid;
    CorrectionDataset: TSQLQuery;
    CorrectionDatasetnumber: TLongintField;
    CorrectionDatasetcorrection: TLongintField;
    CorrectionDatasetid: TAutoIncField;
    SQLQuery1: TSQLQuery;
    BackupTimer: TTimer;
    TimerMonitor: TTimer;
    ToolPanel1: TToolPanel;
    ViewMemo: TMenuItem;
    MenuItem3: TMenuItem;
    ViewResults: TMenuItem;
    DebugPanel: TPanel;
    DebugSplitter: TSplitter;
    MainDataset1: TSQLQuery;
    ButtonSaveMemo: TButton;
    ButtonClearMemo: TButton;
    FileOpenDB: TFileOpen;
    FileExportFull: TFileSaveAs;
    MainMenu: TMainMenu;
    Memo: TMemo;
    MenuItemNewDB: TMenuItem;
    N3: TMenuItem;
    MenuItemOpen: TMenuItem;
    MenuItemOpenRecent: TMenuItem;
    MenuItemExport: TMenuItem;
    MenuItemClose: TMenuItem;
    N2: TMenuItem;
    MenuItemExit: TMenuItem;
    MenuItemFile: TMenuItem;
    Serial: TLazSerial;
    SerialPortPopupMenu: TPopupMenu;
    Timer1: TTimer;
    procedure AcCheckDBOpenUpdate(Sender: TObject);
    procedure AcCheckUpdateExecute(Sender: TObject);
    procedure AcCheckUpdateUpdate(Sender: TObject);
    procedure AcCOMCloseExecute(Sender: TObject);
    procedure AcCOMOpenExecute(Sender: TObject);
    procedure AcGenerateStartTimeExecute(Sender: TObject);
    procedure AcLEDPanelExecute(Sender: TObject);
    procedure AcRunRaceSettingsExecute(Sender: TObject);
    procedure AcTelegramBotExecute(Sender: TObject);
    procedure AcSetStarttimeExecute(Sender: TObject);
    procedure BackupTimerTimer(Sender: TObject);
    procedure CheckDBOpenAndRaceMode(Sender: TObject);
    procedure ExportStageResultsExecute(Sender: TObject);
    procedure FileExportCSVResultsAccept(Sender: TObject);
    procedure FileExportCSVResultsBeforeExecute(Sender: TObject);
    procedure FileExportCSVStartlistAccept(Sender: TObject);
    procedure FileExportCSVStartlistBeforeExecute(Sender: TObject);
    procedure FileExportFullBeforeExecute(Sender: TObject);
    procedure FileExportStageResultsSaveAsAccept(Sender: TObject);
    procedure FileExportStageResultsSaveAsBeforeExecute(Sender: TObject);
    procedure FileGenerateFinalBeforeExecute(Sender: TObject);
    procedure ComboBox1CategoryEditingDone(Sender: TObject);
    procedure COMStatus(Sender: TObject);
    procedure AcCOMSetupExecute(Sender: TObject);
    procedure AcDeleteNumberExecute(Sender: TObject);
    procedure AcSetDNFExecute(Sender: TObject);
    procedure AcSetDNSExecute(Sender: TObject);
    procedure AcSetDSQExecute(Sender: TObject);
    procedure AcSetDNSCorExecute(Sender: TObject);
    procedure AcSetDNFOnTraceExecute(Sender: TObject);
    procedure AcSetClearExecute(Sender: TObject);
    procedure AcSyncModuleExecute(Sender: TObject);
    procedure AcApplyStartMarksExecute(Sender: TObject);
    procedure AcApplyStartMarksUpdate(Sender: TObject);
    procedure AcClearStartMarksExecute(Sender: TObject);
    procedure AcClearStartMarksUpdate(Sender: TObject);
    procedure AcOpenStartMarkJournalExecute(Sender: TObject);
    procedure AcOpenFinishMarkJournalExecute(Sender: TObject);
    procedure AcUpdateResultsExecute(Sender: TObject);
    procedure AcRunSettingsExecute(Sender: TObject);
    procedure AcOpenLogFileExecute(Sender: TObject);
    procedure AcOpenLogFileUpdate(Sender: TObject);
    procedure AcOpenLogDirectoryExecute(Sender: TObject);
    procedure AcOpenLogDirectoryUpdate(Sender: TObject);
    procedure AcApplyFinishMarksExecute(Sender: TObject);
    procedure AcClearResultsExecute(Sender: TObject);
    procedure AcViewResultsExecute(Sender: TObject);
    procedure AcViewMemoExecute(Sender: TObject);
    procedure BCloseClick(Sender: TObject);
    procedure ButtonFinishTestClick(Sender: TObject);
    procedure ButtonSaveMemoClick(Sender: TObject);
    procedure ButtonClearMemoClick(Sender: TObject);
    procedure CheckCorrectionSetText(Sender: TField; const aText: string);
    procedure EditCopy1Execute(Sender: TObject);
    procedure EmptyExecute(Sender: TObject);
    procedure FileCloseExecute(Sender: TObject);
    procedure FileGenerateFinalAccept(Sender: TObject);
    procedure FileNewDBAccept(Sender: TObject);
    procedure FileOpenCSVAccept(Sender: TObject);
    procedure FileOpenCSVResultAccept(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure HistoryFiles1ClickHistoryItem(Sender: TObject; Item: TMenuItem;
      const Filename: string);
    procedure LazBleLclClient1ConfigureClient(Sender: TObject);
    procedure LazBleComponent1AvailabilityChanged(Sender: TObject;
      const AAvailability: TBleAvailability);
    procedure LazBleComponent1Error(Sender: TObject;
      const AErrorCode: Integer; const AErrorMessage: string);
    procedure LazBleComponent1ScanStateChanged(Sender: TObject;
      const AState: TLazBleLclScanState);
    procedure LazBleLclClient1DeviceChanged(Sender: TObject);
    procedure LazBleLclClient1Error(Sender: TObject;
      const AErrorCode: Integer; const AErrorMessage: string);
    procedure LazBleLclClient1StateChanged(Sender: TObject;
      const AState: TLazBleClientState);
    procedure MainDataset1AfterInsert(DataSet: TDataSet);
    procedure CheckPenaltySetText(Sender: TField; const aText: string);
    procedure CheckStatusSetText(Sender: TField; const aText: string);
    procedure HideZeroHour(Sender: TField; var aText: string; DisplayText: boolean);
    procedure MenuItemMonitorModeClick(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
    procedure StageFieldChanged(Sender: TField);
    procedure MainDataset1statusGetText(Sender: TField; var aText: string;
      DisplayText: boolean);
    procedure MenuItemAboutClick(Sender: TObject);
    procedure RaceModeClick(Sender: TObject);
    procedure CurrentStageComboBoxChange(Sender: TObject);
    procedure RxDBGrid1EditingDone(Sender: TObject);
    procedure RxDBGrid1KeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure RxDBGrid1KeyPress(Sender: TObject; var Key: char);
    procedure RxDBGrid1SelectEditor(Sender: TObject; Column: TColumn;
      var Editor: TWinControl);
    procedure RxDBGridStartMarksDblClick(Sender: TObject);
    procedure RxDBGridStartMarksEditingDone(Sender: TObject);
    procedure TimingMarkWorkQueueBeforeInsert(DataSet: TDataSet);
    procedure RxDBGridFinishMarksDblClick(Sender: TObject);
    procedure RxDBGridFinishMarksEditingDone(Sender: TObject);
    procedure RxDBGridCorrectionEditingDone(Sender: TObject);
    procedure RxDBSpinEdit1EditingDone(Sender: TObject);
    procedure RxIniPropStorage1RestoreProperties(Sender: TObject);
    procedure RxIniPropStorage1StoredValues0Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues0Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues10Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues10Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues11Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues11Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues12Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues12Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues13Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues13Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues14Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues14Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues15Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues15Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues16Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues16Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues17Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues17Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues18Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues18Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues19Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues19Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues20Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues20Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues21Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues21Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues1Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues1Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues2Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues2Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues3Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues3Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues4Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues4Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues5Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues5Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues6Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues6Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues7Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues7Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues8Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues8Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues9Restore(Sender: TStoredValue;
      var Value: TStoredType);
    procedure RxIniPropStorage1StoredValues9Save(Sender: TStoredValue;
      var Value: TStoredType);
    procedure TabSheet2Show(Sender: TObject);
    procedure TimerMonitorTimer(Sender: TObject);
    procedure SyncButtonClick(Sender: TObject);
    procedure FileOpenDBAccept(Sender: TObject);
    procedure FileExportFullAccept(Sender: TObject);
    procedure ResultClearClick(Sender: TObject);
    procedure SerialPortMenuItemClick(Sender: TObject);
    procedure TimingInputDeviceLabelClick(Sender: TObject);
    procedure SerialPortPopupMenuPopup(Sender: TObject);
    procedure TimingInputStateButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SerialStatus(Sender: TObject; Reason: THookSerialReason;
      const Value: string);
    procedure Timer1Timer(Sender: TObject);
    procedure CheckDBOpen(Sender: TObject);
    procedure SetLang(ALang: string);
  private
    { private declarations }
    FClosing: boolean;
    FAvailableSerialDevices: TSerialDeviceInfoArray;
    FBleTimingTransport: TBleTimingTransport;
    FPendingParticipantLogMessage: string;
    FPendingParticipantStageIndex: integer;
    FSerialCloseRequested: boolean;
    FSerialConnectionEnabled: boolean;
    FSerialConnectionHint: string;
    FSerialConnectionImageIndex: integer;
    FSerialConnectionLost: boolean;
    FTimingStreamProcessor: TTransportStreamProcessor;
    FSerialTransport: ITimingTransport;
    FBleTransport: ITimingTransport;
    FTimingTransportController: TTimingTransportController;
    FModuleSyncOperation: ITimingSendOperation;
    FModuleSyncTime: integer;
    FSerialStatusText: string;
    FStoredBleDeviceId: string;
    FStoredBleDeviceName: string;
    FBackupController: TCompetitionBackupController;
    FUpdateCheckController: TUpdateCheckController;
    FCompetitionDb: TCompetitionDbContext;
    FStartupCompetitionFileName: string;
    FCurrentStageIndexes: array of integer;
    FUpdatingCurrentStageSelector: boolean;
    FStageFieldFactory: TStageFieldFactory;
    FStageGridColumnFactory: TStageGridColumnFactory;
    FStageResultTabs: TStageResultTabs;
    FStageResultSumColumns: TStageResultSumColumns;
    FTimingMarkRouter: TTimingMarkRouter;
    FStartMarkCandidateProvider: IStartMarkCandidateProvider;
    FStartMarkApplyPort: IStartMarkApplyPort;
    FStartMarkPersistence: IStartMarkPersistence;
    FStartMarkService: TStartMarkService;
    FFinishDebounceIntervalMs: integer;
    FFinishMarkEditDialogQueued: boolean;
    FPendingFinishMarkEditDialogType: TMsgDlgType;
    FPendingFinishMarkEditMessage: string;
    FFinishMarkPersistence: IFinishMarkPersistence;
    FFinishMarkService: TFinishMarkService;
    FLedPanelCoordinator: TLedPanelCoordinator;
    FTelegramCoordinator: TTelegramNotificationCoordinator;
    function GetSQLite3Connection1: TSQLite3Connection;
    function GetSQLTransaction1: TSQLTransaction;
    procedure AppLogEntryReceived(const AEntry: TAppLogEntry);
    procedure ConfigureMainGridOptionalColumnWidths;
    procedure ConfigureMainStageFields(
      const AStageIndexes: array of integer);
    procedure ConfigureMainStageColumns(const AStageCount: integer);
    procedure ConfigureMainStage(const AStageIndex: integer;
      const ADisplayName: string; const AActive: boolean);
    procedure ConfigureMainSingleStage(const AStageIndex: integer;
      const AShowStageName: boolean);
    procedure BeginMainStageColumnsUpdate;
    procedure EndMainStageColumnsUpdate;
    procedure ConfigureStageResultUi(const AStageCount: integer;
      const AActiveStageIndexes: array of integer);
    procedure ConfigureStageResultSum(
      const AActiveStageIndexes: array of integer);
    procedure ConfigureStageResult(const AStageIndex: integer;
      const ADisplayName: string; const AActive: boolean);
    procedure ApplyStoredTimingInputSettings;
    procedure AutomaticBackupCompleted(Sender: TObject;
      const AResult: TCompetitionBackupResult);
    procedure RebuildSerialPortMenu;
    procedure RefreshAvailableSerialDevices;
    procedure FirmwareResponseReceived(Sender: TObject;
      const AResponse: TFirmwareResponse);
    procedure TimingMessageRejected(Sender: TObject;
      const ARejected: TTransportStreamRejected);
    procedure TimingTransportDataReceived(Sender: TObject;
      const AData: RawByteString; const ASource: TTimingMarkSource);
    procedure TimingSendCompleted(Sender: TObject);
    procedure SelectBleTimingTransportDevice;
    function SelectedSerialPortAvailable: boolean;
    procedure UpdateSerialStatusText(const AText: string);
    procedure UpdateBleTimingTransportControls;
    procedure SetTimingInputStatusText(const AText: string);
    procedure UpdateSerialPortControls;
    procedure EnsureUpdateCheckController;
    procedure StartAutomaticUpdateCheck(Data: PtrInt);
    procedure UpdateCheckCompleted(Sender: TObject; AMode: TUpdateCheckMode;
      const AResult: TUpdateCheckResult);
    procedure StartMarkReceived(Sender: TObject; const AMark: TStartMark);
    procedure FinishMarkReceived(Sender: TObject; const AMark: TFinishMark);
    procedure QueueFinishMarkEditDialog(const AMessage: string;
      const ADialogType: TMsgDlgType);
    procedure ShowFinishMarkEditDialog(Data: PtrInt);
    procedure ReportRefreshOutcome(
      const AOutcome: TCompetitionRefreshOutcome);
    procedure RefreshAll;
    procedure RefreshResults;
    procedure LoadCompetitionConfigModel;
    procedure ApplyCompetitionConfigToUi(
      const APreferredStageIndex: integer = 0);
    procedure RebuildCompetitionStageConfiguration(const AStageCount,
      APreferredCurrentStageIndex: integer;
      const ARefreshQueries: boolean = True);
    procedure ReconfigureCompetitionStageActivity(
      const APreferredCurrentStageIndex: integer;
      const ARefreshQueries: boolean = True);
    procedure LoadIniCategory(const AConfigureQueries: boolean = True);
    procedure SetfName(const AFileName: string);
    procedure CreateStartMarkService;
    procedure FreeStartMarkService;
    procedure CreateFinishMarkService;
    procedure FreeFinishMarkService;
    procedure UpdateStartMarkPanelTranslations;
    procedure UpdateFinishMarkPanelTranslations;
    function HasNumberedStartMarks: boolean;
    function ApplyStartMark(const AMarkId: int64;
      const AParticipantNumber: integer;
      const ARefreshAfterApply: boolean = True): boolean;
    procedure RefreshAfterStartMarkApply;
    function PrepareCompetitionSchema(const AExistingFile: boolean): integer;
    function SelectedMainGridFieldName: string;
    procedure SetSelectedParticipantStatus(
      const AStatus: TParticipantStatus);
    procedure SetParticipantStatus(const AStageIndex: integer;
      const AStatus: TParticipantStatus; const AParticipantNumber: string);
    procedure SetDNS;
    procedure SetDNF;
    procedure SetDSQ;
    procedure RecalculateAllStatuses;
    procedure ClearStatus;
    procedure InitDB(fileName: string);
    procedure SetFinish;
    function ApplyFinishMark(const AMarkId: int64;
      const AParticipantNumber: integer): boolean;
    procedure NotifyFinish(const AResult: TFinishResult);
    procedure LedPanelCompleted(Sender: TObject;
      const ADelivery: TLedPanelDeliveryResult);
    procedure TelegramCompleted(Sender: TObject;
      const ADelivery: TTelegramDeliveryResult);
    procedure TelegramDropped(Sender: TObject;
      const AItem: TTelegramQueueItemInfo);
    procedure SaveStageCorrection(const StageIndex, Correction,
      ParticipantNumber: integer);
    procedure UpdateResults;
    procedure UpdateSumResults;
    procedure ClearResults(silent: boolean = False);
    procedure SetDNSFromCorrection;
    procedure SetStarttimeFromPopup;
    procedure SetDNFFromOnTrace;
    procedure LoadParticipantsList(FileName: string);
    procedure LoadStageResults(FileName: string);
    procedure ExportFinishTime(FileName: string; stageIndex: integer);
    function ExportAllResultsToXLSX(FileName: string): boolean;
    procedure ApplyTimingPacket(const APacket: TTimingPacket;
      const ASource: TTimingMarkSource);
    procedure RefreshFinishMarkWorkQueue(const AMarkId: int64 = 0);
    procedure SetTimingFinishInterval(const AValue: integer);
    function TimingFinishInterval: integer;
    procedure ExportCSVStartList(FileName: string);
    procedure ExportCSVResults(FileName: string);
    function InputComboSelectStage(const ACaption, APrompt: string): integer;
    function GetSelectedStage: integer;
    function BackupBD(ASuccessView: TAppLogView = alvStatus;
      AReason: TCompetitionBackupReason = cbrNone): boolean;

  protected
    procedure CompleteBleTimingDeviceSelection(const AAccepted: boolean;
      const ADevice: TBleDeviceInfo);
  public
    { public declarations }
    destructor Destroy; override;
    procedure TimingPacketReceived(Sender: TObject;
      const APacket: TTimingPacket; const ASource: TTimingMarkSource);
    procedure RefreshSerialPortUi;
    procedure RefreshTimingInputUi;
    procedure ActivateStageResult(const AStageIndex: integer);
    procedure ConfigureCurrentStageDatasets;
    procedure RebuildCurrentStageSelector(
      const APreferredStageIndex: integer = 0);
    procedure SelectCurrentStage(const AStageIndex: integer);
    function CurrentStageIndex: integer;
    function StageResultView(const AStageIndex: integer): TStageResultView;
    function StageResultViewCount: integer;
    function RefreshStageResultQueries(out AErrors: string;
      out AQueryCount: integer): integer;
    procedure ResultsFormReady;
    procedure ApplyResultParameterChanges(const AStageCount,
      APreviousCurrentStageIndex, APreviousParticipantId: integer;
      const AHadOpenDatabase, ARestoreCurrentParticipant,
      AStageCountChanged: boolean);
    procedure ApplyPresentationChanges(
      const APreviousCurrentStageIndex: integer;
      const AHadOpenDatabase, AStageUiChanged,
      AResultViewQueriesChanged, AStageNamesChanged,
      AZeroHourChanged: boolean);
    procedure RecoverCompetitionAfterSettingsFailure;
    procedure QueueTelegramTest(const AEndpoint: string;
      const AFields: THttpFormFields;
      const ARetryPolicy: TTelegramRetryPolicy);
    procedure QueueLedPanelTest(const AAddress, ASingleLine,
      AUpperLine, ABottomLine: string);
    property CompetitionDb: TCompetitionDbContext read FCompetitionDb;
    property StartMarkService: TStartMarkService read FStartMarkService;
    property FinishMarkService: TFinishMarkService read FFinishMarkService;
    property BleTimingTransport: TBleTimingTransport read FBleTimingTransport;
    property SQLite3Connection1: TSQLite3Connection read GetSQLite3Connection1;
    property SQLTransaction1: TSQLTransaction read GetSQLTransaction1;
    property SerialConnectionEnabled: boolean
      read FSerialConnectionEnabled;
    property SerialConnectionHint: string read FSerialConnectionHint;
    property SerialConnectionImageIndex: integer
      read FSerialConnectionImageIndex;
    property FinishDebounceInterval: integer read TimingFinishInterval
      write SetTimingFinishInterval;

  end;



const
  //количество категорий в окне результатов
  VISIBLECAT: integer = 6;
  DEFAULT_FINISH_DEBOUNCE_INTERVAL_MS = 250;
  DEFAULT_ZERO_HOUR = True;
  DEFAULT_SHOW_STAGE_NAME_FOR_SINGLE_STAGE = False;
  DEFAULT_CHECK_UPDATE_AT_STARTUP = True;
  DEFAULT_CHECK_UPDATE_INTERVAL_IN_DAYS = 7;
  DEFAULT_AUTOMATIC_BACKUP = True;
  DEFAULT_BACKUP_PERIOD_MS = 10 * 60 * 1000;




var

  MainForm: TMainForm;
  //значения по умолчанию
  //имя файла БД
  fName: string = '';
  //язык программы
  CurrentLang: string = '';
  FallbackLang: string = 'ru';
  //номер СУ, результаты которого будут выводиться в отдельное окно
  astage: string = '1';
  //список категорий, которые будут выводиться в отдельно окно
  cat: array[1..6] of string;
  //активный транспорт отсечек
  timingInputTransport: TTimingTransportKind = ttkSerial;
  // Настройки обработки стартовых отметок рабочего места.
  startMarkMatchDeltaSeconds: integer = 15;
  startMarkAutomaticApply: boolean = False;
  NAME_VERSION: string;
  raceName: string = '';
  //активные СУ
  stages: TStages;
  // Итоговое значение config.stagecount из подготовленной схемы.
  StoredStageCount: integer = MIN_STAGE_COUNT;
  //скрывать нулевое значение часа в результатах
  zerohour: boolean = DEFAULT_ZERO_HOUR;

  //LED панель
  ledpaneladress: string;

  //Telegram Bot
  telegrambotadress: string;
  telegramRetryEnabled: boolean = TELEGRAM_RETRY_DEFAULT_ENABLED;
  telegramRetryCount: integer = TELEGRAM_RETRY_DEFAULT_COUNT;
  telegramRetryDelaySeconds: integer =
    TELEGRAM_RETRY_DEFAULT_DELAY_SECONDS;

  //Показывать название СУ если активен только один
  showStageNameForSingleStage: bool = DEFAULT_SHOW_STAGE_NAME_FOR_SINGLE_STAGE;

  //Индекс этапа при экспорте
  exportStageIndex: integer = 1;

  //Обновление
  updateExists: boolean = False;
  checkUpdateAtStartup: boolean = DEFAULT_CHECK_UPDATE_AT_STARTUP;
  lastUpdateCheckoutTime: TDateTime;
  checkUpdateIntervalInDays: integer = DEFAULT_CHECK_UPDATE_INTERVAL_IN_DAYS;
  lastVersionOnline: string;
  lastReleaseUrlOnline: string;

  //Backup
  doAutomaticBackup: boolean = DEFAULT_AUTOMATIC_BACKUP;
  backupPeriod: integer = DEFAULT_BACKUP_PERIOD_MS; //in milliseconds
  automaticBackupRetentionDays: integer =
    DEFAULT_AUTOMATIC_BACKUP_RETENTION_DAYS;
  automaticBackupMaxSizeMb: integer = DEFAULT_AUTOMATIC_BACKUP_MAX_SIZE_MB;

  startlistConfig: TStartlistConfig;

function IsCompetitionDatabaseOpen: boolean;
function CompetitionHasParticipants: boolean;
function CurrentBackupRetentionPolicy: TBackupRetentionPolicy;

implementation

uses
  Result, Settings, rxapputils, StartMarks, FinishMarks,
  Validators, Variants, LazBleDeviceSelectForm,
  InputDialogs, ResultFormatting, CompetitionExportService,
  CompetitionImportService,
  CompetitionResultsService, CompetitionLifecycleService, LazFileUtils,
  StartMarkSqliteAdapters;

type
  TStartMarkWorkItem = record
    MarkId: int64;
    ParticipantNumber: integer;
  end;

  TStartMarkWorkItems = array of TStartMarkWorkItem;

  TFinishMarkWorkItem = record
    MarkId: int64;
    ParticipantNumber: integer;
  end;

  TFinishMarkWorkItems = array of TFinishMarkWorkItem;

  {$R *.lfm}

function IsCompetitionDatabaseOpen: boolean;
begin
  Result := Assigned(MainForm) and Assigned(MainForm.MainDataset1) and
    MainForm.MainDataset1.Active;
end;

function CompetitionHasParticipants: boolean;
begin
  Result := IsCompetitionDatabaseOpen and not MainForm.MainDataset1.IsEmpty;
end;

function CurrentBackupRetentionPolicy: TBackupRetentionPolicy;
begin
  Result := DefaultBackupRetentionPolicy;
  Result.AutomaticRetentionDays := automaticBackupRetentionDays;
  Result.AutomaticMaxTotalBytes := Int64(automaticBackupMaxSizeMb) *
    1024 * 1024;
end;

const
  TIMING_INPUT_TRANSPORT_SERIAL = 'serial';
  TIMING_INPUT_TRANSPORT_BLE = 'ble';

procedure LogInvalidStoredSetting(const ASettingName, AValue,
  ADefaultValue: string);
begin
  AppLog(Format(
    'Invalid stored setting "%s": "%s"; using default "%s"',
    [ASettingName, AValue, ADefaultValue]), allWarning, alvDetails,
    alsApplication);
end;

function StoredBooleanOrDefault(const ASettingName: string;
  const AValue: TStoredType; const ADefault: boolean): boolean;
var
  ValueText: string;
begin
  ValueText := Trim(VarToStr(AValue));
  if TryStrToBool(ValueText, Result) then
    Exit;
  Result := ADefault;
  LogInvalidStoredSetting(ASettingName, ValueText,
    BoolToStr(ADefault, True));
end;

function StoredIntegerOrDefault(const ASettingName: string;
  const AValue: TStoredType; const ADefault: integer): integer;
var
  ValueText: string;
begin
  ValueText := Trim(VarToStr(AValue));
  if TryStrToInt(ValueText, Result) then
    Exit;
  Result := ADefault;
  LogInvalidStoredSetting(ASettingName, ValueText, IntToStr(ADefault));
end;

function StoredIntegerInRangeOrDefault(const ASettingName: string;
  const AValue: TStoredType; const ADefault, AMinimum,
  AMaximum: integer): integer;
begin
  Result := StoredIntegerOrDefault(ASettingName, AValue, ADefault);
  if (Result >= AMinimum) and (Result <= AMaximum) then
    Exit;
  LogInvalidStoredSetting(ASettingName, VarToStr(AValue),
    IntToStr(ADefault));
  Result := ADefault;
end;

function StoredDateTimeOrDefault(const ASettingName: string;
  const AValue: TStoredType; const ADefault: TDateTime): TDateTime;
var
  ValueText: string;
begin
  ValueText := Trim(VarToStr(AValue));
  if TryStrToDateTime(ValueText, Result) then
    Exit;
  Result := ADefault;
  LogInvalidStoredSetting(ASettingName, ValueText, FloatToStr(ADefault));
end;

function BleDiagnosticValue(const AValue, ADefault: string): string;
begin
  if AValue <> '' then
    Result := TimingPacketLogValue(AValue)
  else
    Result := ADefault;
end;

function BleBackendLogContext(const AComponent: TLazBleComponent): string;
var
  AdapterId: string;
  BackendInfo: TLazBleBackendInfo;
begin
  BackendInfo := AComponent.BackendInfo;
  AdapterId := BackendInfo.AdapterId;
  if AdapterId = '' then
    AdapterId := AComponent.AdapterId;
  Result := ' backend=' + BleDiagnosticValue(BackendInfo.Name, 'unknown') +
    ' version=' + BleDiagnosticValue(BackendInfo.Version, 'unknown') +
    ' adapter=' + BleDiagnosticValue(AdapterId, 'default');
end;

function BleScanStateName(const AState: TLazBleLclScanState): string;
begin
  case AState of
    lblssIdle: Result := 'idle';
    lblssScanning: Result := 'scanning';
    lblssSucceeded: Result := 'succeeded';
    lblssCancelled: Result := 'cancelled';
    lblssTimedOut: Result := 'timed_out';
    lblssFailed: Result := 'failed';
  end;
end;

function BleClientStateName(const AState: TLazBleClientState): string;
begin
  case AState of
    lbcstDisconnected: Result := 'disconnected';
    lbcstConnecting: Result := 'connect_discovery';
    lbcstAttachingProfiles: Result := 'profile_attach_subscription';
    lbcstReady: Result := 'ready';
    lbcstWaitingToReconnect: Result := 'waiting_to_reconnect';
    lbcstDisconnecting: Result := 'disconnecting';
    lbcstError: Result := 'error';
  end;
end;

function FieldValuesAreEqual(const OldValue, NewValue: Variant): boolean;
begin
  // SQLDB exposes an empty VARCHAR editor value as an empty string even when
  // the value loaded from SQLite was NULL.  For an unchanged empty cell these
  // representations are equivalent; cancelling the edit also preserves NULL.
  if VarIsNull(OldValue) and
    (VarIsNull(NewValue) or VarIsEmpty(NewValue) or (VarToStr(NewValue) = '')) then
    Exit(True);
  if VarIsNull(NewValue) and
    (VarIsNull(OldValue) or VarIsEmpty(OldValue) or (VarToStr(OldValue) = '')) then
    Exit(True);
  Result := VarSameValue(OldValue, NewValue);
end;

function QueryHasActualChanges(const AQuery: TSQLQuery): boolean;
var
  field: TField;
begin
  Result := False;
  if AQuery = nil then
    Exit;

  if AQuery.UpdateStatus in [usInserted, usDeleted] then
    Exit(True);

  if not (AQuery.State in [dsEdit, dsInsert]) and
    (AQuery.ChangeCount = 0) then
    Exit;

  try
    for field in AQuery.Fields do
      if (field.FieldKind = fkData) and not field.ReadOnly and
        not FieldValuesAreEqual(field.OldValue, field.Value) then
        Exit(True);
  except
    Result := AQuery.Modified or (AQuery.ChangeCount > 0);
  end;
end;

function ParticipantFieldCaption(const AGrid: TRxDBGrid;
  const AField: TField): string;
var
  column: TRxColumn;
begin
  Result := AField.FieldName;
  column := AGrid.ColumnByFieldName(AField.FieldName);
  if Assigned(column) and (Trim(column.Title.Caption) <> '') then
    Result := StringReplace(column.Title.Caption, '|', ' / ', [rfReplaceAll]);
end;

function ParticipantFieldValueCanBeLogged(const AFieldName: string): boolean;
var
  stageFieldKind: TStageFieldKind;
  stageIndex: integer;
begin
  Result := SameText(AFieldName, 'category') or
    SameText(AFieldName, 'rfid') or
    SameText(AFieldName, 'sumresult') or
    SameText(AFieldName, 'sumdiffleader') or
    SameText(AFieldName, 'sumplace') or
    SameText(AFieldName, 'status') or
    SameText(AFieldName, 'sumstages') or
    SameText(AFieldName, 'thrudiff') or
    SameText(AFieldName, 'thruplace') or
    TryParseStageFieldName(AFieldName, stageFieldKind, stageIndex);
end;

function ParticipantLogValue(const AField: TField;
  const AValue: Variant): string;
var
  status: TParticipantStatus;
  stageFieldKind: TStageFieldKind;
  stageIndex: integer;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) or (VarToStr(AValue) = '') then
    Exit(rsEmptyLogValue);

  Result := VarToStr(AValue);
  if (SameText(AField.FieldName, 'status') or
    (TryParseStageFieldName(AField.FieldName, stageFieldKind, stageIndex) and
    (stageFieldKind = sfkStatus))) and
    TryParticipantStatusFromDbValue(Result, status) and
    (status <> psNone) then
    Result := ParticipantStatusToToken(status);
end;

procedure BuildParticipantChangeLogMessages(const AQuery: TSQLQuery;
  const AGrid: TRxDBGrid; Messages: TStrings);
var
  field: TField;
  participantNumber: string;
begin
  Messages.Clear;
  participantNumber := AQuery.FieldByName('number').AsString;

  if AQuery.UpdateStatus = usInserted then
  begin
    Messages.Add(Format(rsParticipantUpdated, [participantNumber]));
    Exit;
  end;

  try
    for field in AQuery.Fields do
      if (field.FieldKind = fkData) and not field.ReadOnly and
        not FieldValuesAreEqual(field.OldValue, field.Value) then
      begin
        if SameText(field.FieldName, 'id') then
          Continue
        else if SameText(field.FieldName, 'number') then
          Messages.Add(Format(rsParticipantNumberChanged,
            [VarToStr(field.OldValue), field.AsString]))
        else if ParticipantFieldValueCanBeLogged(field.FieldName) then
          Messages.Add(Format(rsParticipantFieldValueChanged,
            [participantNumber, ParticipantFieldCaption(AGrid, field),
            ParticipantLogValue(field, field.OldValue),
            ParticipantLogValue(field, field.Value)]))
        else
          Messages.Add(Format(rsParticipantFieldUpdated,
            [participantNumber, ParticipantFieldCaption(AGrid, field)]));
      end;
  except
    Messages.Clear;
    Messages.Add(Format(rsParticipantUpdated, [participantNumber]));
  end;
end;

function RuntimeResourceDirectory(const DirectoryName: string): string;
var
  exeDir: string;
  candidateExeDir: string;
  candidateSourceTree: string;
  candidateCwd: string;
begin
  exeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  candidateExeDir := IncludeTrailingPathDelimiter(exeDir + DirectoryName);
  candidateSourceTree := IncludeTrailingPathDelimiter(ExpandFileName(exeDir + '..' +
    DirectorySeparator + '..' + DirectorySeparator + '..' + DirectorySeparator +
    DirectoryName));
  candidateCwd := IncludeTrailingPathDelimiter(ExpandFileName(DirectoryName));

  if DirectoryExists(candidateExeDir) then
    Exit(candidateExeDir);
  if DirectoryExists(candidateSourceTree) then
    Exit(candidateSourceTree);
  if DirectoryExists(candidateCwd) then
    Exit(candidateCwd);

  Result := candidateExeDir;
end;

function TMainForm.GetSQLite3Connection1: TSQLite3Connection;
begin
  Result := FCompetitionDb.Connection;
end;

function TMainForm.GetSQLTransaction1: TSQLTransaction;
begin
  Result := FCompetitionDb.Transaction;
end;

destructor TMainForm.Destroy;
var
  SendOperation: ITimingSendOperation;
begin
  FreeAndNil(FLedPanelCoordinator);
  FreeAndNil(FTelegramCoordinator);
  FreeStartMarkService;
  FreeFinishMarkService;
  SendOperation := FModuleSyncOperation;
  if Assigned(SendOperation) then
    SendOperation.OnCompleted := nil;
  FModuleSyncOperation := nil;
  if Assigned(Serial) then
    Serial.OnStatus := nil;
  if Assigned(FTimingTransportController) then
    FTimingTransportController.OnData := nil;
  FreeAndNil(FTimingTransportController);
  FSerialTransport := nil;
  FBleTimingTransport := nil;
  FBleTransport := nil;
  FAvailableSerialDevices := nil;
  FreeAndNil(FTimingStreamProcessor);
  if Assigned(FTimingMarkRouter) then
  begin
    FTimingMarkRouter.OnStartMark := nil;
    FTimingMarkRouter.OnFinishMark := nil;
  end;
  FreeAndNil(FTimingMarkRouter);
  FreeAndNil(FStageResultSumColumns);
  FreeAndNil(FStageResultTabs);
  FreeAndNil(FStageGridColumnFactory);
  FreeAndNil(FStageFieldFactory);
  FreeAndNil(FBackupController);
  FreeAndNil(FCompetitionDb);
  inherited Destroy;
end;

procedure TMainForm.CreateStartMarkService;
begin
  FreeStartMarkService;
  if not CompetitionDb.Connection.Connected then
    Exit;
  FStartMarkPersistence := TSqliteStartMarkPersistence.Create(CompetitionDb);
  FStartMarkCandidateProvider := TSqliteStartMarkCandidateProvider.Create(
    CompetitionDb, stages);
  FStartMarkApplyPort := TSqliteStartMarkApplyPort.Create(
    CompetitionDb, stages);
  FStartMarkService := TStartMarkService.Create(FStartMarkCandidateProvider,
    FStartMarkApplyPort, FStartMarkPersistence);
end;

procedure TMainForm.FreeStartMarkService;
begin
  FreeAndNil(FStartMarkService);
  FStartMarkApplyPort := nil;
  FStartMarkCandidateProvider := nil;
  FStartMarkPersistence := nil;
end;

procedure TMainForm.CreateFinishMarkService;
begin
  FreeFinishMarkService;
  if not CompetitionDb.Connection.Connected then
    Exit;
  FFinishMarkPersistence :=
    TSqliteFinishMarkPersistence.Create(CompetitionDb);
  FFinishMarkService := TFinishMarkService.Create(FFinishMarkPersistence,
    FFinishDebounceIntervalMs);
end;

procedure TMainForm.FreeFinishMarkService;
begin
  FreeAndNil(FFinishMarkService);
  FFinishMarkPersistence := nil;
end;

procedure TMainForm.RefreshAvailableSerialDevices;
begin
  FAvailableSerialDevices := ReadSerialDevices;
end;

procedure TMainForm.RefreshSerialPortUi;
begin
  RefreshAvailableSerialDevices;
  UpdateSerialPortControls;
end;

procedure TMainForm.RefreshTimingInputUi;
begin
  if Assigned(FTimingTransportController) and
    (FTimingTransportController.ActiveKind <> timingInputTransport) then
  begin
    FTimingStreamProcessor.Reset;
    FTimingTransportController.ActiveKind := timingInputTransport;
  end;
  if timingInputTransport = ttkBle then
    UpdateBleTimingTransportControls
  else
  begin
    UpdateSerialPortControls;
    SetTimingInputStatusText(FSerialStatusText);
  end;
end;

function TMainForm.SelectedSerialPortAvailable: boolean;
begin
  Result := SerialDeviceIsAvailable(Serial.Device,
    FAvailableSerialDevices);
end;

procedure TMainForm.UpdateSerialPortControls;
begin
  if Serial.Active then
  begin
    FSerialConnectionImageIndex := AcCOMOpen.ImageIndex;
    FSerialConnectionEnabled := True;
    FSerialConnectionHint := Format(rsDisconnectFromPort, [Serial.Device]);
  end
  else
  begin
    FSerialConnectionImageIndex := AcCOMClose.ImageIndex;
    FSerialConnectionEnabled := SelectedSerialPortAvailable;
    if FSerialConnectionEnabled then
      FSerialConnectionHint := Format(rsConnectToPort, [Serial.Device])
    else
      FSerialConnectionHint := Format(rsPortUnavailable, [Serial.Device]);
  end;
  if timingInputTransport <> ttkSerial then
    Exit;
  TimingInputDeviceLabel.Cursor := crHandPoint;
  TimingInputDeviceLabel.Caption := Serial.Device;
  TimingInputDeviceLabel.Hint := Serial.Device;
  TimingInputDeviceLabel.Enabled := not Serial.Active;
  TimingInputStateButton.ImageIndex := FSerialConnectionImageIndex;
  TimingInputStateButton.Enabled := FSerialConnectionEnabled;
  TimingInputStateButton.Hint := FSerialConnectionHint;
end;

procedure TMainForm.UpdateSerialStatusText(const AText: string);
begin
  FSerialStatusText := AText;
  if timingInputTransport = ttkSerial then
    SetTimingInputStatusText(AText);
end;

procedure TMainForm.SetTimingInputStatusText(const AText: string);
begin
  TimingInputStatusText.Caption := AText;
  TimingInputStatusText.Hint := AText;
end;

procedure TMainForm.UpdateBleTimingTransportControls;
var
  ConnectionAction: TLazBleConnectionAction;
  CanSelectDevice: boolean;
  statusText: string;
begin
  ConnectionAction := LazBleConnectionAction(LazBleLclClient1);
  CanSelectDevice := LazBleCanSelectDevice(LazBleLclClient1);
  statusText := LazBleStatusText(LazBleLclClient1);
  if CanSelectDevice then
    TimingInputDeviceLabel.Cursor := crHandPoint
  else
    TimingInputDeviceLabel.Cursor := crDefault;
  TimingInputDeviceLabel.Caption := LazBleDeviceText(LazBleLclClient1);
  TimingInputDeviceLabel.Hint := LazBleLclClient1.DeviceId;
  TimingInputDeviceLabel.Enabled := CanSelectDevice;
  if LazBleLclClient1.State = lbcstReady then
    TimingInputStateButton.ImageIndex := AcCOMOpen.ImageIndex
  else
    TimingInputStateButton.ImageIndex := AcCOMClose.ImageIndex;
  TimingInputStateButton.Enabled := ConnectionAction <> lbcaNone;
  if ConnectionAction <> lbcaNone then
    TimingInputStateButton.Hint :=
      LazBleConnectionActionText(LazBleLclClient1)
  else
    TimingInputStateButton.Hint := statusText;
  SetTimingInputStatusText(statusText);
end;

procedure TMainForm.SelectBleTimingTransportDevice;
var
  Accepted: boolean;
  Device: TBleDeviceInfo;
  Dialog: TBleDeviceSelectForm;
begin
  if not LazBleCanSelectDevice(LazBleLclClient1) then
    Exit;
  Device := Default(TBleDeviceInfo);
  Dialog := TBleDeviceSelectForm.Create(Self,
    LazBleComponent1.ScanController);
  Accepted := False;
  try
    Dialog.AdapterId := LazBleComponent1.AdapterId;
    Dialog.ScanTimeoutMs := LazBleComponent1.ScanTimeoutMs;
    Accepted := Dialog.Execute(Device);
  finally
    Dialog.Free;
  end;
  CompleteBleTimingDeviceSelection(Accepted, Device);
end;

procedure TMainForm.CompleteBleTimingDeviceSelection(
  const AAccepted: boolean; const ADevice: TBleDeviceInfo);
begin
  if not AAccepted or (ADevice.DeviceId = '') then
    Exit;
  LazBleLclClient1.SelectDevice(ADevice);
  if LazBleConnectionAction(LazBleLclClient1) = lbcaConnect then
    LazBleLclClient1.Connect;
end;

procedure TMainForm.RebuildSerialPortMenu;
var
  i: integer;
  menuItem: TMenuItem;
begin
  RefreshAvailableSerialDevices;
  SerialPortPopupMenu.Items.Clear;
  if Length(FAvailableSerialDevices) = 0 then
  begin
    menuItem := TMenuItem.Create(SerialPortPopupMenu);
    menuItem.Caption := rsNoAvailableSerialPorts;
    menuItem.Enabled := False;
    SerialPortPopupMenu.Items.Add(menuItem);
  end
  else
    for i := Low(FAvailableSerialDevices) to High(FAvailableSerialDevices) do
    begin
      menuItem := TMenuItem.Create(SerialPortPopupMenu);
      menuItem.Caption := FormatSerialDeviceDisplayName(
        FAvailableSerialDevices[i],
        [sddoVendor, sddoModel, sddoErrorCode]);
      menuItem.Hint := FAvailableSerialDevices[i].Device;
      menuItem.RadioItem := True;
      menuItem.GroupIndex := 1;
      menuItem.Checked := IndexOfSerialDevice(
        FAvailableSerialDevices,
        Serial.Device
      ) = i;
      menuItem.Enabled := not Serial.Active;
      menuItem.OnClick := @SerialPortMenuItemClick;
      SerialPortPopupMenu.Items.Add(menuItem);
    end;
  UpdateSerialPortControls;
end;

procedure TMainForm.ConfigureMainStageFields(
  const AStageIndexes: array of integer);
begin
  FStageFieldFactory.EnsureStageIndexes(AStageIndexes);
  TDatasetSql.ConfigureMainParticipants(MainDataset1, AStageIndexes);
  FCompetitionDb.ConfigureEditableQuery(MainDataset1, 'main', 'id');
end;

procedure TMainForm.ConfigureMainStageColumns(const AStageCount: integer);
begin
  FStageGridColumnFactory.Rebuild(AStageCount);
end;

procedure TMainForm.ConfigureMainStage(const AStageIndex: integer;
  const ADisplayName: string; const AActive: boolean);
begin
  FStageGridColumnFactory.ConfigureStage(AStageIndex, ADisplayName, AActive);
end;

procedure TMainForm.ConfigureMainSingleStage(const AStageIndex: integer;
  const AShowStageName: boolean);
begin
  FStageGridColumnFactory.ConfigureSingleStage(AStageIndex, AShowStageName);
end;

procedure TMainForm.BeginMainStageColumnsUpdate;
begin
  FStageGridColumnFactory.BeginColumnUpdate;
end;

procedure TMainForm.EndMainStageColumnsUpdate;
begin
  FStageGridColumnFactory.EndColumnUpdate;
end;

procedure TMainForm.ConfigureMainGridOptionalColumnWidths;
begin
  RxDBGrid1.ColumnByFieldName('id').Width := 60;
  RxDBGrid1.ColumnByFieldName('rfid').Width := 120;
  RxDBGrid1.ColumnByFieldName('nickname').Width := 100;
  RxDBGrid1.ColumnByFieldName('age').Width := 60;
  RxDBGrid1.ColumnByFieldName('team').Width := 120;
  RxDBGrid1.ColumnByFieldName('city').Width := 100;
  RxDBGrid1.ColumnByFieldName('phone').Width := 130;
  RxDBGrid1.ColumnByFieldName('email').Width := 180;
  RxDBGrid1.ColumnByFieldName('comment').Width := 200;
  RxDBGrid1.ColumnByFieldName('status').Width := 70;
end;

procedure TMainForm.ConfigureStageResultUi(const AStageCount: integer;
  const AActiveStageIndexes: array of integer);
begin
  FStageResultTabs.Rebuild(AStageCount);
  FStageResultSumColumns.Rebuild(AStageCount);
  ConfigureStageResultSum(AActiveStageIndexes);
  SheetStage.ActivePage := FStageResultTabs[1].Sheet;
end;

procedure TMainForm.ConfigureStageResultSum(
  const AActiveStageIndexes: array of integer);
begin
  TDatasetSql.ConfigureResultStageSum(ResultDatasetStageSum,
    AActiveStageIndexes);
end;

procedure TMainForm.ConfigureStageResult(const AStageIndex: integer;
  const ADisplayName: string; const AActive: boolean);
begin
  FStageResultTabs.ConfigureStage(AStageIndex, ADisplayName, AActive);
  FStageResultSumColumns.ConfigureStage(AStageIndex, ADisplayName, AActive);
end;

procedure TMainForm.ActivateStageResult(const AStageIndex: integer);
begin
  FStageResultTabs.ActivateStage(AStageIndex);
end;

function TMainForm.CurrentStageIndex: integer;
begin
  Result := 0;
  if (CurrentStageComboBox.ItemIndex >= 0) and
    (CurrentStageComboBox.ItemIndex < Length(FCurrentStageIndexes)) then
    Result := FCurrentStageIndexes[CurrentStageComboBox.ItemIndex];
end;

procedure TMainForm.SelectCurrentStage(const AStageIndex: integer);
var
  SelectorIndex: integer;
begin
  for SelectorIndex := 0 to High(FCurrentStageIndexes) do
    if FCurrentStageIndexes[SelectorIndex] = AStageIndex then
    begin
      FUpdatingCurrentStageSelector := True;
      try
        CurrentStageComboBox.ItemIndex := SelectorIndex;
      finally
        FUpdatingCurrentStageSelector := False;
      end;
      ConfigureCurrentStageDatasets;
      Exit;
    end;
  raise EArgumentOutOfRangeException.CreateFmt(
    'Stage %d is not available in the current stage selector.',
    [AStageIndex]);
end;

procedure TMainForm.RebuildCurrentStageSelector(
  const APreferredStageIndex: integer);
var
  PreferredStageIndex, SelectedIndex, StageIndex: integer;
begin
  PreferredStageIndex := APreferredStageIndex;
  if PreferredStageIndex = 0 then
    PreferredStageIndex := CurrentStageIndex;
  SelectedIndex := -1;

  FUpdatingCurrentStageSelector := True;
  CurrentStageComboBox.Items.BeginUpdate;
  try
    CurrentStageComboBox.Clear;
    SetLength(FCurrentStageIndexes, stages.ActiveStagesCount);
    for StageIndex := 1 to stages.Count do
      if stages[StageIndex].isActive then
      begin
        FCurrentStageIndexes[CurrentStageComboBox.Items.Count] := StageIndex;
        CurrentStageComboBox.Items.Add(Format('%d — %s',
          [StageIndex, stages[StageIndex].Name]));
        if StageIndex = PreferredStageIndex then
          SelectedIndex := CurrentStageComboBox.Items.Count - 1;
      end;

    if (SelectedIndex < 0) and (CurrentStageComboBox.Items.Count > 0) then
      SelectedIndex := 0;
    CurrentStageComboBox.ItemIndex := SelectedIndex;
    CurrentStageGroup.Visible := CurrentStageComboBox.Items.Count > 1;
  finally
    CurrentStageComboBox.Items.EndUpdate;
    FUpdatingCurrentStageSelector := False;
  end;
  ConfigureCurrentStageDatasets;
end;

procedure TMainForm.ConfigureCurrentStageDatasets;
var
  StageIndex: integer;
begin
  StageIndex := CurrentStageIndex;
  if not stages.IsActiveIndex(StageIndex) then
    Exit;

  TDatasetSql.ConfigureCorrectionPending(CorrectionDataset, StageIndex,
    stages.Count);
  TDatasetSql.ConfigureTrackStatus(StatDataset2, StageIndex, stages.Count);
  if IsCompetitionDatabaseOpen then
  begin
    CorrectionDataset.Open;
    StatDataset2.Open;
  end;
end;

function TMainForm.StageResultView(
  const AStageIndex: integer): TStageResultView;
begin
  Result := FStageResultTabs[AStageIndex];
end;

function TMainForm.StageResultViewCount: integer;
begin
  Result := FStageResultTabs.Count;
end;

function TMainForm.RefreshStageResultQueries(out AErrors: string;
  out AQueryCount: integer): integer;
begin
  Result := FStageResultTabs.RefreshQueries(AErrors, AQueryCount);
end;

procedure TMainForm.ResultsFormReady;
var
  startupCompetitionFileName: string;
begin
  startupCompetitionFileName := FStartupCompetitionFileName;
  FStartupCompetitionFileName := '';
  if FileExists(startupCompetitionFileName) then
    InitDB(startupCompetitionFileName)
  else
  begin
    LoadCompetitionConfigModel;
    ApplyCompetitionConfigToUi;
    LoadIniCategory;
  end;
end;

procedure TMainForm.ApplyResultParameterChanges(const AStageCount,
  APreviousCurrentStageIndex, APreviousParticipantId: integer;
  const AHadOpenDatabase, ARestoreCurrentParticipant,
  AStageCountChanged: boolean);
begin
  if AHadOpenDatabase and AStageCountChanged then
    RebuildCompetitionStageConfiguration(AStageCount,
      APreviousCurrentStageIndex, False)
  else if AHadOpenDatabase then
    ReconfigureCompetitionStageActivity(APreviousCurrentStageIndex, False)
  else
  begin
    MainDataset1.Close;
    ConfigureMainStageFields(stages.ActiveIndices);
    ConfigureStageResultSum(stages.ActiveIndices);
    if AStageCountChanged then
    begin
      ConfigureMainStageColumns(AStageCount);
      ConfigureStageResultUi(AStageCount, stages.ActiveIndices);
    end;
    ApplyCompetitionConfigToUi(APreviousCurrentStageIndex);
  end;

  if not (AHadOpenDatabase and AStageCountChanged) then
    LoadIniCategory;
  if AHadOpenDatabase then
  begin
    RecalculateAllStatuses;
    UpdateResults;
    if ARestoreCurrentParticipant then
      MainDataset1.Locate('id', APreviousParticipantId, []);
  end;
end;

procedure TMainForm.ApplyPresentationChanges(
  const APreviousCurrentStageIndex: integer;
  const AHadOpenDatabase, AStageUiChanged,
  AResultViewQueriesChanged, AStageNamesChanged,
  AZeroHourChanged: boolean);
begin
  if AStageUiChanged then
    ApplyCompetitionConfigToUi(APreviousCurrentStageIndex);
  if AResultViewQueriesChanged then
  begin
    LoadIniCategory;
    if AHadOpenDatabase then
      RefreshResults;
  end
  else if AStageNamesChanged then
    LoadIniCategory(False);
  if AZeroHourChanged then
    RxDBGrid1.Invalidate;
end;

procedure TMainForm.RecoverCompetitionAfterSettingsFailure;
begin
  InitDB(fName);
end;

procedure TMainForm.QueueTelegramTest(const AEndpoint: string;
  const AFields: THttpFormFields;
  const ARetryPolicy: TTelegramRetryPolicy);
begin
  if not Assigned(FTelegramCoordinator) or
    not FTelegramCoordinator.EnqueueFields(AFields, AEndpoint,
      ARetryPolicy) then
    AppLog(Format(rsTelegramBotSendingError, [rsHTTPRequestNotStarted]),
      allError, alvStatus, alsTelegram);
end;

procedure TMainForm.QueueLedPanelTest(const AAddress, ASingleLine,
  AUpperLine, ABottomLine: string);
begin
  if not Assigned(FLedPanelCoordinator) or
    not FLedPanelCoordinator.EnqueueTest(AAddress, ASingleLine,
      AUpperLine, ABottomLine) then
    AppLog(Format(rsLEDPanelError, [rsLEDPanelInvalidAddress]), allError,
      alvStatus, alsHTTP);
end;

  { TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  BleTransport: ITimingTransport;
  SerialConnection: ISerialTimingConnection;
  SerialTransport: ITimingTransport;
  StageFieldHandlers: TStageFieldHandlers;
begin
  SetAppLogEvent(@AppLogEntryReceived);
  FLedPanelCoordinator := TLedPanelCoordinator.Create(
    TFpHttpTransportFactory.Create);
  FLedPanelCoordinator.OnCompleted := @LedPanelCompleted;
  FTelegramCoordinator := TTelegramNotificationCoordinator.Create(
    TFpHttpTransportFactory.Create);
  FTelegramCoordinator.OnCompleted := @TelegramCompleted;
  FTelegramCoordinator.OnDropped := @TelegramDropped;
  FTimingMarkRouter := TTimingMarkRouter.Create;
  FTimingMarkRouter.OnStartMark := @StartMarkReceived;
  FTimingMarkRouter.OnFinishMark := @FinishMarkReceived;
  FFinishDebounceIntervalMs := DEFAULT_FINISH_DEBOUNCE_INTERVAL_MS;
  FAvailableSerialDevices := nil;
  FTimingStreamProcessor := TTransportStreamProcessor.Create;
  FTimingStreamProcessor.OnTimingPacket := @TimingPacketReceived;
  FTimingStreamProcessor.OnFirmwareResponse := @FirmwareResponseReceived;
  FTimingStreamProcessor.OnRejected := @TimingMessageRejected;
  SerialConnection := TLazSerialTimingConnection.Create(Serial);
  SerialTransport := TSerialTimingTransport.Create(SerialConnection);
  FSerialTransport := SerialTransport;
  FBleTimingTransport := TBleTimingTransport.Create;
  BleTransport := FBleTimingTransport;
  FBleTransport := BleTransport;
  FBleTimingTransport.HandleDeviceChanged(LazBleLclClient1.DeviceId);
  FTimingTransportController := TTimingTransportController.Create(
    FSerialTransport, FBleTransport);
  FTimingTransportController.ActiveKind := timingInputTransport;
  FTimingTransportController.OnData := @TimingTransportDataReceived;
  stages := TStages.Create(MIN_STAGE_COUNT);
  FCompetitionDb := TCompetitionDbContext.Create(Self);
  FBackupController := TCompetitionBackupController.Create(nil,
    @AutomaticBackupCompleted);
  StageFieldHandlers.OnEditableFieldChange := @StageFieldChanged;
  StageFieldHandlers.OnCorrectionSetText := @CheckCorrectionSetText;
  StageFieldHandlers.OnPenaltySetText := @CheckPenaltySetText;
  StageFieldHandlers.OnResultGetText := @HideZeroHour;
  FStageFieldFactory := TStageFieldFactory.Create(MainDataset1,
    StageFieldHandlers);
  FStageFieldFactory.EnsureStageIndexes(stages.ActiveIndices);
  FStageGridColumnFactory := TStageGridColumnFactory.Create(RxDBGrid1);
  FStageGridColumnFactory.Rebuild(stages.Count);
  ConfigureMainGridOptionalColumnWidths;
  FStageResultTabs := TStageResultTabs.Create(SheetStage, FCompetitionDb);
  FStageResultSumColumns := TStageResultSumColumns.Create(GridResultStageSum);
  TDatasetSql.ConfigureMainParticipants(MainDataset1, stages.ActiveIndices);
  TDatasetSql.ConfigureCategoryStatistics(StatDataset1);
  TDatasetSql.ConfigureCorrectionPending(CorrectionDataset, 1, stages.Count);
  TDatasetSql.ConfigureStartMarkWorkQueue(DatasetStartMarks);
  TDatasetSql.ConfigureFinishMarkWorkQueue(DatasetFinishMarks);
  TDatasetSql.ConfigureTrackStatus(StatDataset2, 1, stages.Count);
  TDatasetSql.ConfigureResultStageTotal(ResultDatasetStageTotal);
  ConfigureStageResultUi(stages.Count, stages.ActiveIndices);
  FCompetitionDb.AttachQuery(SQLQuery1);
  FCompetitionDb.AttachQuery(SQLQuery2);
  FCompetitionDb.AttachQuery(MainDataset1);
  FCompetitionDb.ConfigureEditableQuery(MainDataset1, 'main', 'id');
  FCompetitionDb.RegisterUiQuery(CorrectionDataset);
  FCompetitionDb.RegisterUiQuery(DatasetStartMarks);
  FCompetitionDb.RegisterUiQuery(DatasetFinishMarks);
  FCompetitionDb.RegisterUiQuery(ResultDatasetStageTotal);
  FCompetitionDb.RegisterUiQuery(ResultDatasetStageSum);
  FCompetitionDb.RegisterUiQuery(StatDataset1);
  FCompetitionDb.RegisterUiQuery(StatDataset2);
  RebuildCurrentStageSelector(stages.FirstActiveIndex);
  UpdateStartMarkPanelTranslations;
  UpdateFinishMarkPanelTranslations;
  NAME_VERSION := Application.Title + ' v' + GetFileVersion;
  //значение по умолчанию (режим работы с 1 СУ)
  HistoryFiles1.IniFile := UTF8ToSys(GetDefaultIniName);
  //для хранения там же, где и RxINIPropStorage
  HistoryFiles1.UpdateParentMenu;
  Memo.Lines.Add('File version = ' + GetFileVersion);
  Memo.Lines.Add('');
  Memo.Lines.Add('Built for ' + GetTargetInfo);
  Memo.Lines.Add(' with ' + GetCompilerInfo + ' on ' + GetCompiledDate);
  Memo.Lines.Add(' and using ' + GetLCLVersion + ' and ' + GetWidgetset);

  {$IFDEF DEBUG}
  NAME_VERSION := NAME_VERSION + ' debug';

  RxDBGrid1.Columns[0].Visible := True;
  RxDBGrid1.Columns[0].Width := 25;
  RxDBGrid1.ColumnByFieldName('status').Visible := True;
  RxDBGrid1.ColumnByFieldName('status').Width := 50;

  MenuItemDebug.Visible := True;
  AcViewMemo.Checked := True;
  {$ENDIF}

  (Sender as TForm).Caption := NAME_VERSION;

  startlistConfig := TStartlistConfig.Create;
  FClosing := False;
  FSerialCloseRequested := False;
  FSerialConnectionLost := False;
  RefreshAvailableSerialDevices;
  RefreshTimingInputUi;
  EnsureUpdateCheckController;
end;

procedure TMainForm.AppLogEntryReceived(const AEntry: TAppLogEntry);
var
  viewText: string;
  i, trimCount: integer;
  loggingSettings: TLoggingSettings;
begin
  loggingSettings := CurrentLoggingSettings;
  case AEntry.View of
    alvStatus:
    begin
      viewText := FormatDateTime(loggingSettings.ComboBoxTimestampFormat,
        AEntry.CreatedAt) + ' ' + AEntry.MessageText;
      ComboBoxLog.Items.Add(viewText);
      while ComboBoxLog.Items.Count > loggingSettings.ComboBoxMaxItems do
        ComboBoxLog.Items.Delete(0);
      ComboBoxLog.Text := viewText;
    end;
    alvDetails:
    begin
      viewText := AEntry.MessageText;
      if loggingSettings.MemoAddTimestamp then
        viewText := FormatDateTime(loggingSettings.ComboBoxTimestampFormat,
          AEntry.CreatedAt) + ' ' + viewText;
      Memo.Lines.Add(viewText);
      if Memo.Lines.Count > loggingSettings.MemoMaxLines then
      begin
        trimCount := loggingSettings.MemoTrimLines;
        if trimCount > Memo.Lines.Count then
          trimCount := Memo.Lines.Count;
        Memo.Lines.BeginUpdate;
        try
          for i := 1 to trimCount do
            Memo.Lines.Delete(0);
        finally
          Memo.Lines.EndUpdate;
        end;
      end;
    end;
  end;
end;


procedure TMainForm.SyncButtonClick(Sender: TObject);
begin
  AcSyncModuleExecute(Sender);
end;

procedure TMainForm.BCloseClick(Sender: TObject);
begin
  if Serial.Active then
  begin
    FSerialCloseRequested := True;
    Serial.Close;
  end;
end;

procedure TMainForm.ButtonFinishTestClick(Sender: TObject);
begin
  RecalculateAllStatuses;
end;

procedure TMainForm.ButtonSaveMemoClick(Sender: TObject);
begin
  Memo.Lines.SaveToFile(
    FormatDateTime('YYYY-MM-DD hh-mm-ss', Now) + ' memo log.txt');
end;

procedure TMainForm.ButtonClearMemoClick(Sender: TObject);
begin
  Memo.Clear;
end;

procedure TMainForm.CheckCorrectionSetText(Sender: TField; const aText: string);
var
  i: integer;
begin
  if TryStrToInt(aText, i) or (aText = '') then
  begin
    Sender.AsString := aText;
  end
  else
  begin
    AskMessageDlg(rsIncorrectCorrection, mtInformation, [mbOK], 0);
  end;
end;

procedure TMainForm.EditCopy1Execute(Sender: TObject);
begin
  if IsCompetitionDatabaseOpen and not MainDataset1.IsEmpty then
  begin
    Clipboard.AsText := MainDataset1.FieldByName(
      RxDBGrid1.SelectedColumn.FieldName).AsString;
  end;
end;

procedure TMainForm.EmptyExecute(Sender: TObject);
begin

end;

procedure TMainForm.FileExportCSVStartlistAccept(Sender: TObject);
begin
  ExportCSVStartList(FileExportCSVStartlist.Dialog.FileName);
end;

procedure TMainForm.FileExportCSVStartlistBeforeExecute(Sender: TObject);
begin
  TFileSaveAs(Sender).Dialog.FileName := raceName + '-' + UTF8LowerCase(rsStartProtocol);
end;

procedure TMainForm.FileCloseExecute(Sender: TObject);
var
  closedFileName: string;
begin
  closedFileName := fName;
  FreeStartMarkService;
  FreeFinishMarkService;
  FPendingParticipantLogMessage := '';
  FPendingParticipantStageIndex := 0;
  TCompetitionLifecycleService.Close(MainForm.CompetitionDb);
  SetfName('');

  if closedFileName <> '' then
    AppLog(Format(rsDBFileClosed, [closedFileName]), allInfo, alvStatus,
      alsDatabase);
end;

procedure TMainForm.FileGenerateFinalAccept(Sender: TObject);
begin
end;

procedure TMainForm.FileNewDBAccept(Sender: TObject);
begin
  FileCloseExecute(nil);
  InitDB(FileNewDB.Dialog.FileName);
end;

procedure TMainForm.FileOpenCSVAccept(Sender: TObject);
begin
  LoadParticipantsList((Sender as TFileOpen).Dialog.FileName);
end;

procedure TMainForm.FileOpenCSVResultAccept(Sender: TObject);
begin
  LoadStageResults((Sender as TFileOpen).Dialog.FileName);
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  ClearedTelegramCount: Integer;
begin
  FClosing := True;
  FreeAndNil(FLedPanelCoordinator);
  ClearedTelegramCount := 0;
  if Assigned(FTelegramCoordinator) then
    ClearedTelegramCount := FTelegramCoordinator.Shutdown;
  if ClearedTelegramCount > 0 then
    AppLog(Format(rsTelegramQueueCleared, [ClearedTelegramCount]),
      allWarning, alvDetails, alsTelegram);
  FreeAndNil(FTelegramCoordinator);
  FreeStartMarkService;
  FreeFinishMarkService;
  BackupTimer.Enabled := False;
  FreeAndNil(FBackupController);
  DefaultCompetitionBackupCoordinator.WaitForIdle;
  SetAppLogEvent(nil);
  Application.RemoveAsyncCalls(Self);
  if Assigned(FModuleSyncOperation) then
    FModuleSyncOperation.OnCompleted := nil;
  FModuleSyncOperation := nil;
  if Assigned(FTimingTransportController) then
    FTimingTransportController.OnData := nil;
  FreeAndNil(FTimingTransportController);
  FSerialTransport := nil;
  FBleTimingTransport := nil;
  FBleTransport := nil;
  FreeAndNil(FUpdateCheckController);

  FreeAndNil(startlistConfig);
  FreeAndNil(stages);
end;

procedure TMainForm.AcViewMemoExecute(Sender: TObject);
begin
  DebugPanel.Visible := AcViewMemo.Checked;
  DebugSplitter.Visible := AcViewMemo.Checked;
end;

procedure TMainForm.AcViewResultsExecute(Sender: TObject);
begin
  if AcViewResults.Checked then
    ResultsForm.Show
  else
    ResultsForm.Hide;
end;

procedure TMainForm.AcCOMSetupExecute(Sender: TObject);
var
  oldDevice: string;
begin
  oldDevice := Serial.Device;
  Serial.ShowSetupDialog;
  if (Serial.Device <> oldDevice) and Assigned(FTimingStreamProcessor) then
    FTimingStreamProcessor.Reset;
  RefreshAvailableSerialDevices;
  UpdateSerialPortControls;
end;

procedure TMainForm.AcDeleteNumberExecute(Sender: TObject);
var
  n, messageText: string;
begin
  if CompetitionHasParticipants then
  begin
    n := MainDataset1.FieldByName('number').AsString;
    if AskMessageDlg(Format(rsDeleteNumber, [n]), mtWarning,
      [mbYes, mbNo], 0) <> mrYes then
      Exit;
    try
      MainDataset1.Delete;
      CompetitionDb.ApplyUpdatesAndRefreshUi(MainDataset1);
      RefreshAll;
      AppLog(Format(rsParticipantDeleted, [n]),
        allInfo, alvStatus, alsResults);
    except
      on E: Exception do
      begin
        messageText := Format(rsParticipantSaveError, [n, E.Message]);
        AppLog(messageText, allError, alvStatus, alsResults);
        AskMessageDlg(messageText, mtError, [mbOK], 0);
      end;
    end;
  end;
end;

procedure TMainForm.AcSetDNSExecute(Sender: TObject);
begin
  SetDNS;
end;

procedure TMainForm.AcSetDNFExecute(Sender: TObject);
begin
  SetDNF;
end;

procedure TMainForm.AcSetDSQExecute(Sender: TObject);
begin
  SetDSQ;
end;

procedure TMainForm.AcSetClearExecute(Sender: TObject);
begin
  ClearStatus;
end;

procedure TMainForm.AcSyncModuleExecute(Sender: TObject);
var
  tpress, syncTime: integer;
begin
  if Assigned(FModuleSyncOperation) and
    (FModuleSyncOperation.State = tssPending) then
    Exit;
  tpress := DateTimeToUnix(Now);
  //uses dateutils
  while tpress = DateTimeToUnix(Now) do
  begin
  end;
  syncTime := DateTimeToUnix(Now);
  FModuleSyncTime := syncTime;
  try
    FModuleSyncOperation := FTimingTransportController.SendAsync(
      RawByteString('T' + IntToStr(syncTime)));
    FModuleSyncOperation.OnCompleted := @TimingSendCompleted;
  except
    on E: Exception do
    begin
      FModuleSyncOperation := TTimingSendOperation.Failed(
        TTimingMarkSource.Manual, E.Message);
      FModuleSyncOperation.OnCompleted := @TimingSendCompleted;
    end;
  end;
end;

procedure TMainForm.TimingSendCompleted(Sender: TObject);
var
  ErrorText, messageText: string;
  LogSource: TAppLogSource;
  Operation: ITimingSendOperation;
begin
  Operation := FModuleSyncOperation;
  if not Assigned(Operation) then
    Exit;
  Operation.OnCompleted := nil;
  case Operation.Source.Kind of
    tmskSerial: LogSource := alsSerial;
    tmskBle: LogSource := alsBle;
  else
    LogSource := alsApplication;
  end;

  if Operation.State = tssSucceeded then
    AppLog(Format(rsModuleSynchronized,
      [Operation.Source.DeviceId, FModuleSyncTime]), allInfo, alvStatus,
      LogSource)
  else
  begin
    ErrorText := Operation.ErrorMessage;
    if ErrorText = '' then
      ErrorText := IntToStr(Operation.ErrorCode);
    messageText := Format(rsModuleSynchronizationError,
      [Operation.Source.DeviceId, ErrorText]);
    AppLog(messageText, allError, alvStatus, LogSource);
    AskMessageDlg(messageText, mtError, [mbOK], 0);
  end;
  FModuleSyncOperation := nil;
end;

procedure TMainForm.AcSetDNSCorExecute(Sender: TObject);
begin
  SetDNSFromCorrection;
end;

procedure TMainForm.AcSetDNFOnTraceExecute(Sender: TObject);
begin
  SetDNFFromOnTrace;
end;

procedure TMainForm.AcUpdateResultsExecute(Sender: TObject);
begin
  UpdateResults;
end;

procedure TMainForm.AcRunSettingsExecute(Sender: TObject);
begin
  SettingsForm.RunSettings;
end;

procedure TMainForm.AcOpenLogFileExecute(Sender: TObject);
var
  logFileName, messageText: string;
begin
  logFileName := CurrentAppLogFileName;
  if (logFileName = '') or not FileExists(logFileName) then
    Exit;

  if not OpenDocument(logFileName) then
  begin
    messageText := Format(rsLogFileOpenError, [logFileName]);
    AppLog(messageText, allError, alvDetails, alsApplication);
    AskMessageDlg(messageText, mtError, [mbOK], 0);
  end;
end;

procedure TMainForm.AcOpenLogFileUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := FileExists(CurrentAppLogFileName);
end;

procedure TMainForm.AcOpenLogDirectoryExecute(Sender: TObject);
var
  logDirectory, logFileName, messageText: string;
begin
  logFileName := CurrentAppLogFileName;
  if logFileName = '' then
    Exit;

  logDirectory := ExtractFileDir(logFileName);
  if not DirectoryExists(logDirectory) then
    Exit;

  if not OpenDocument(logDirectory) then
  begin
    messageText := Format(rsLogDirectoryOpenError, [logDirectory]);
    AppLog(messageText, allError, alvDetails, alsApplication);
    AskMessageDlg(messageText, mtError, [mbOK], 0);
  end;
end;

procedure TMainForm.AcOpenLogDirectoryUpdate(Sender: TObject);
var
  logFileName: string;
begin
  logFileName := CurrentAppLogFileName;
  TAction(Sender).Enabled := (logFileName <> '') and
    DirectoryExists(ExtractFileDir(logFileName));
end;

procedure TMainForm.AcApplyFinishMarksExecute(Sender: TObject);
begin
  SetFinish;
end;

procedure TMainForm.AcClearResultsExecute(Sender: TObject);
begin
  ClearResults;
end;

procedure TMainForm.AcCOMOpenExecute(Sender: TObject);
var
  messageText: string;
begin
  RefreshAvailableSerialDevices;
  UpdateSerialPortControls;
  if not SelectedSerialPortAvailable then
  begin
    AppLog(Format(rsPortUnavailable, [Serial.Device]), allWarning,
      alvStatus, alsSerial);
    Exit;
  end;
  try
    FTimingStreamProcessor.Reset;
    Serial.Open;
    UpdateSerialPortControls;
  except
    On E: Exception do
    begin
      messageText := Format(rsCOMOpenErrorDetails, [Serial.Device, E.Message]);
      AppLog(messageText, allError, alvStatus, alsSerial);
      AskMessageDlg(messageText, mtError, [mbOK], 0);
      UpdateSerialPortControls;
    end;
  end;
end;

procedure TMainForm.AcGenerateStartTimeExecute(Sender: TObject);
begin
  if not RunStartlist(startlistConfig) then
    Exit;
  if startlistConfig.activatedStageIndex > 0 then
  begin
    LoadCompetitionConfigModel;
    ApplyCompetitionConfigToUi(startlistConfig.activatedStageIndex);
    if IsCompetitionDatabaseOpen then
      RecalculateAllStatuses;
  end;
  UpdateResults;
end;

procedure TMainForm.AcLEDPanelExecute(Sender: TObject);
begin
  if AcLEDPanel.Checked then
    AppLog(rsLEDPanelEnabled, allInfo, alvStatus, alsHTTP)
  else
    AppLog(rsLEDPanelDisabled, allInfo, alvStatus, alsHTTP);
end;

procedure TMainForm.AcRunRaceSettingsExecute(Sender: TObject);
begin
  // 2 - страница с настройками соревнования
  SettingsForm.RunSettings(2);
end;

procedure TMainForm.AcApplyStartMarksExecute(Sender: TObject);
var
  AppliedAny: boolean;
  I: integer;
  Items: TStartMarkWorkItems;
begin
  if not IsCompetitionDatabaseOpen or not Assigned(FStartMarkService) or
    not DatasetStartMarks.Active then
    Exit;
  if (DatasetStartMarks.State in [dsEdit, dsInsert]) or
    (DatasetStartMarks.ChangeCount > 0) then
    RxDBGridStartMarksEditingDone(RxDBGridStartMarks);

  SetLength(Items, 0);
  DatasetStartMarks.DisableControls;
  try
    DatasetStartMarks.First;
    while not DatasetStartMarks.EOF do
    begin
      if not DatasetStartMarks.FieldByName(
        'participant_number').IsNull and
        (DatasetStartMarks.FieldByName(
        'participant_number').AsInteger > 0) then
      begin
        SetLength(Items, Length(Items) + 1);
        Items[High(Items)].MarkId :=
          DatasetStartMarks.FieldByName('id').AsLargeInt;
        Items[High(Items)].ParticipantNumber :=
          DatasetStartMarks.FieldByName('participant_number').AsInteger;
      end;
      DatasetStartMarks.Next;
    end;
  finally
    DatasetStartMarks.EnableControls;
  end;

  AppliedAny := False;
  for I := 0 to High(Items) do
    if ApplyStartMark(Items[I].MarkId, Items[I].ParticipantNumber,
      False) then
      AppliedAny := True;
  if AppliedAny then
    RefreshAfterStartMarkApply;
end;

procedure TMainForm.AcApplyStartMarksUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := IsCompetitionDatabaseOpen and
    Assigned(FStartMarkService) and HasNumberedStartMarks;
end;

procedure TMainForm.AcClearStartMarksExecute(Sender: TObject);
var
  HiddenCount: integer;
  MessageText: string;
begin
  if not IsCompetitionDatabaseOpen or not Assigned(FStartMarkService) or
    not DatasetStartMarks.Active then
    Exit;

  if DatasetStartMarks.State in [dsEdit, dsInsert] then
    DatasetStartMarks.Cancel;
  if DatasetStartMarks.ChangeCount > 0 then
    DatasetStartMarks.CancelUpdates;

  try
    HiddenCount := FStartMarkService.HideWorkQueue;
    if HiddenCount = 0 then
      Exit;
    AppLog(Format(rsStartMarksHidden, [HiddenCount]), allInfo,
      alvStatus, alsDatabase);
    try
      CompetitionDb.RefreshQuery(DatasetStartMarks);
    except
      on E: Exception do
      begin
        MessageText := Format(rsStartMarksHideRefreshWarning, [E.Message]);
        AppLog(MessageText, allWarning, alvStatus, alsDatabase);
        AskMessageDlg(MessageText, mtWarning, [mbOK], 0);
      end;
    end;
  except
    on E: Exception do
    begin
      MessageText := Format(rsStartMarksHideError, [E.Message]);
      AppLog(MessageText, allError, alvStatus, alsDatabase);
      AskMessageDlg(MessageText, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.AcClearStartMarksUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := IsCompetitionDatabaseOpen and
    Assigned(FStartMarkService) and DatasetStartMarks.Active and
    not DatasetStartMarks.IsEmpty;
end;

procedure TMainForm.AcOpenStartMarkJournalExecute(Sender: TObject);
begin
  RunStartMarks;
end;

procedure TMainForm.AcOpenFinishMarkJournalExecute(Sender: TObject);
begin
  RunFinishMarks;
end;

procedure TMainForm.AcTelegramBotExecute(Sender: TObject);
begin
  if AcTelegramBot.Checked then
    AppLog(rsTelegramBotEnabled, allInfo, alvStatus, alsTelegram)
  else
    AppLog(rsTelegramBotDisabled, allInfo, alvStatus, alsTelegram);
end;

procedure TMainForm.AcSetStarttimeExecute(Sender: TObject);
begin
  SetStarttimeFromPopup;
end;

procedure TMainForm.BackupTimerTimer(Sender: TObject);
begin
  if IsCompetitionDatabaseOpen and not FClosing and
    Assigned(FBackupController) then
    FBackupController.Start(fName, Now, CurrentBackupRetentionPolicy);
end;

procedure TMainForm.AutomaticBackupCompleted(Sender: TObject;
  const AResult: TCompetitionBackupResult);
begin
  if FClosing or (AResult.Status in [cbsCancelled, cbsSkipped]) then
    Exit;
  if AResult.Status = cbsCreated then
  begin
    AppLog(Format(rsBackupCreated, [AResult.BackupFileName]), allInfo,
      alvNone, alsDatabase);
    if AResult.Cleanup.DeletedCount > 0 then
      AppLog(Format(rsBackupCleanupCompleted,
        [AResult.Cleanup.DeletedCount, AResult.Cleanup.FreedBytes]), allInfo,
        alvDetails, alsDatabase);
    if AResult.Cleanup.WarningMessage <> '' then
      AppLog(Format(rsBackupCleanupWarning,
        [AResult.Cleanup.WarningMessage]), allWarning, alvDetails,
        alsDatabase);
  end
  else
    case AResult.Failure of
      cbfDirectoryCreate:
        AppLog(Format(rsBackupDirectoryCreateError,
          [ExtractFilePath(AResult.BackupFileName)]), allWarning,
          alvDetails, alsDatabase);
      cbfInvalidFile:
        AppLog(Format(rsBackupFileInvalid, [AResult.BackupFileName]),
          allWarning, alvDetails, alsDatabase);
      else
        AppLog(Format(rsBackupCreateError,
          [AResult.BackupFileName, AResult.ErrorMessage]), allWarning,
          alvDetails, alsDatabase);
    end;
end;

procedure TMainForm.CheckDBOpenAndRaceMode(Sender: TObject);
begin
   TAction(Sender).Enabled := IsCompetitionDatabaseOpen and
     not RaceMode.Checked;
end;

procedure TMainForm.ExportStageResultsExecute(Sender: TObject);
begin
  exportStageIndex := InputComboSelectStage(rsExportFinish, rsExportTimeToSU);
  if stages.IsActiveIndex(exportStageIndex) then
  begin
    FileExportStageResultsSaveAs.Execute;
  end;
end;

procedure TMainForm.FileExportCSVResultsAccept(Sender: TObject);
begin
  ExportCSVResults(FileExportCSVResults.Dialog.FileName);
end;

procedure TMainForm.FileExportCSVResultsBeforeExecute(Sender: TObject);
begin
  TFileSaveAs(Sender).Dialog.FileName :=
    raceName + '-' + UTF8LowerCase(rsResults);
end;

procedure TMainForm.ComboBox1CategoryEditingDone(Sender: TObject);
var
  n, oldCategory, newCategory, messageText: string;
begin
  if not IsCompetitionDatabaseOpen or TComboBox(Sender).DroppedDown then
    Exit;

  newCategory := TComboBox(Sender).Text;
  if MainDataset1category.AsString = newCategory then
    Exit;

  n := MainDataset1.FieldByName('number').AsString;
  oldCategory := MainDataset1category.AsString;
  try
    MainDataset1.Edit;
    MainDataset1category.AsString := newCategory;
    CompetitionDb.ApplyUpdatesAndRefreshUi(MainDataset1);
    CompetitionDb.RefreshQuery(StatDataset1);
    AppLog(Format(rsParticipantFieldValueChanged,
      [n, ParticipantFieldCaption(RxDBGrid1, MainDataset1category),
      ParticipantLogValue(MainDataset1category, oldCategory),
      ParticipantLogValue(MainDataset1category, newCategory)]), allInfo,
      alvStatus, alsResults);
  except
    on E: Exception do
    begin
      messageText := Format(rsParticipantSaveError, [n, E.Message]);
      AppLog(messageText, allError, alvStatus, alsResults);
      AskMessageDlg(messageText, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.COMStatus(Sender: TObject);
begin
  if Sender = AcCOMOpen then
    TAction(Sender).Enabled := (not Serial.Active) and
      SelectedSerialPortAvailable
  else
    TAction(Sender).Enabled := Serial.Active;
end;

procedure TMainForm.AcCOMCloseExecute(Sender: TObject);
begin
  if Serial.Active then
  begin
    FSerialCloseRequested := True;
    Serial.Close;
    UpdateSerialPortControls;
  end;
end;

procedure TMainForm.AcCheckDBOpenUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := IsCompetitionDatabaseOpen;
end;

procedure TMainForm.AcCheckUpdateExecute(Sender: TObject);
var
  checkStarted: boolean;
  messageText: string;
begin
  if FClosing then
    Exit;

  if updateExists and not lastReleaseUrlOnline.IsEmpty then
    OpenURL(lastReleaseUrlOnline)
  else
  begin
    EnsureUpdateCheckController;
    try
      checkStarted := Assigned(FUpdateCheckController) and
        FUpdateCheckController.StartManual(GetFileVersion);
    except
      on E: Exception do
      begin
        messageText := Format(rsUpdateCheckFailed, [E.Message]);
        AppLog(messageText, allError, alvStatus, alsUpdater);
        AskMessageDlg(messageText, TMsgDlgType.mtError, [mbOK], 0);
        Exit;
      end;
    end;
    if checkStarted then
      AppLog(rsManualUpdateCheckStarted, allDebug, alvNone, alsUpdater)
    else
    begin
      AppLog(rsUpdateCheckStartFailed, allError, alvStatus, alsUpdater);
      AskMessageDlg(rsUpdateCheckStartFailed, TMsgDlgType.mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.AcCheckUpdateUpdate(Sender: TObject);
begin
  EnsureUpdateCheckController;
  if Assigned(FUpdateCheckController) and FUpdateCheckController.Busy then
  begin
    TAction(Sender).Caption := rsCheckingForUpdates;
    TAction(Sender).Enabled := False;
  end
  else
  begin
    TAction(Sender).Enabled := True;
    if updateExists then
      TAction(Sender).Caption := rsUpdateAvailable
    else
      TAction(Sender).Caption := rsCheckForUpdates;
  end;
end;

procedure TMainForm.RxDBGridCorrectionEditingDone(Sender: TObject);
var
  n, oldCorrection, newCorrection, messageText: string;
  stageIndex, numberValue, correctionValue: integer;
begin
  if IsCompetitionDatabaseOpen then
  begin
    if (CorrectionDataset.State in [dsEdit, dsInsert]) or
      (CorrectionDataset.ChangeCount > 0) then
    begin
      if CorrectionDatasetcorrection.IsNull then
      begin
        if CorrectionDataset.State in [dsEdit, dsInsert] then
          CorrectionDataset.Cancel
        else
          CorrectionDataset.CancelUpdates;
        Exit;
      end;

      n := CorrectionDatasetnumber.AsString;
      stageIndex := CurrentStageIndex;
      try
        if not stages.IsActiveIndex(stageIndex) then
          raise EArgumentOutOfRangeException.CreateFmt(
            'Stage %d is not an active competition stage.', [stageIndex]);
        if FieldValuesAreEqual(CorrectionDatasetcorrection.OldValue,
          CorrectionDatasetcorrection.Value) then
        begin
          if CorrectionDataset.State in [dsEdit, dsInsert] then
            CorrectionDataset.Cancel
          else
            CorrectionDataset.CancelUpdates;
          Exit;
        end;
        oldCorrection := ParticipantLogValue(CorrectionDatasetcorrection,
          CorrectionDatasetcorrection.OldValue);
        newCorrection := ParticipantLogValue(CorrectionDatasetcorrection,
          CorrectionDatasetcorrection.Value);
        numberValue := CorrectionDatasetnumber.AsInteger;
        correctionValue := CorrectionDatasetcorrection.AsInteger;
        if CorrectionDataset.State in [dsEdit, dsInsert] then
          CorrectionDataset.Cancel
        else
          CorrectionDataset.CancelUpdates;
        SaveStageCorrection(stageIndex, correctionValue, numberValue);
        AppLog(Format(rsParticipantStageValueChanged,
          [n, rsCorrection, stageIndex, oldCorrection, newCorrection]),
          allInfo, alvNone, alsResults);
      except
        on E: Exception do
        begin
          messageText := Format(rsParticipantStageSaveError,
            [n, stageIndex, E.Message]);
          AppLog(messageText, allError, alvStatus, alsResults);
          AskMessageDlg(messageText, mtError, [mbOK], 0);
        end;
      end;
    end;
  end;
end;

procedure TMainForm.RxDBSpinEdit1EditingDone(Sender: TObject);
var
  n, messageText, logMessage: string;
  changeMessages: TStringList;
begin
  if MainDataset1.Modified or (MainDataset1.ChangeCount > 0) then
  begin
    n := MainDataset1.FieldByName('number').AsString;
    changeMessages := TStringList.Create;
    try
      BuildParticipantChangeLogMessages(MainDataset1, RxDBGrid1, changeMessages);
      try
        CompetitionDb.ApplyUpdatesAndRefreshUi(MainDataset1);
        for logMessage in changeMessages do
          AppLog(logMessage, allInfo, alvNone, alsResults);
      except
        on E: Exception do
        begin
          messageText := Format(rsParticipantSaveError, [n, E.Message]);
          AppLog(messageText, allError, alvStatus, alsResults);
          AskMessageDlg(messageText, mtError, [mbOK], 0);
        end;
      end;
    finally
      changeMessages.Free;
    end;
  end;
end;

procedure TMainForm.ApplyStoredTimingInputSettings;
var
  device: TBleDeviceInfo;
begin
  device := Default(TBleDeviceInfo);
  device.DeviceId := FStoredBleDeviceId;
  device.DeviceName := FStoredBleDeviceName;
  LazBleLclClient1.SelectDevice(device);
  FStoredBleDeviceId := '';
  FStoredBleDeviceName := '';
end;

procedure TMainForm.RxIniPropStorage1RestoreProperties(Sender: TObject);
begin
  ApplyStoredTimingInputSettings;
  RefreshTimingInputUi;
  AppLog(Format(rsSettingsLoaded, [GetDefaultIniName]), allDebug, alvNone,
    alsApplication);
  AppLog(Format(rsStartProgram, [NAME_VERSION]), allInfo, alvStatus,
    alsApplication);
  RefreshAvailableSerialDevices;
  UpdateSerialPortControls;
  AcViewMemoExecute(AcViewMemo);

  // Start the online check only after the application event loop is running.
  if IsAutomaticUpdateCheckDue(checkUpdateAtStartup,
    checkUpdateIntervalInDays, lastUpdateCheckoutTime, Now) then
    Application.QueueAsyncCall(@StartAutomaticUpdateCheck, 0);

  // Do automatic backup
  BackupTimer.Enabled := doAutomaticBackup;
  BackupTimer.Interval := backupPeriod;
end;

procedure TMainForm.RxIniPropStorage1StoredValues0Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if (Value = 'true') and (HistoryFiles1.Count > 0) then
  begin
    FStartupCompetitionFileName := HistoryFiles1.GetItemValue(0);
    // Файл будет опубликован как текущий только после успешного открытия.
  end;
end;

procedure TMainForm.RxIniPropStorage1StoredValues0Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if IsCompetitionDatabaseOpen then
    Value := 'true'
  else
    Value := 'false';
end;

procedure TMainForm.RxIniPropStorage1StoredValues10Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    doAutomaticBackup := StoredBooleanOrDefault('automatic_backup', Value,
      DEFAULT_AUTOMATIC_BACKUP);
end;

procedure TMainForm.RxIniPropStorage1StoredValues10Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := BoolToStr(doAutomaticBackup);
end;

procedure TMainForm.RxIniPropStorage1StoredValues11Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    backupPeriod := StoredIntegerOrDefault('backup_period_ms', Value,
      DEFAULT_BACKUP_PERIOD_MS);
end;

procedure TMainForm.RxIniPropStorage1StoredValues11Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(backupPeriod);
end;

procedure TMainForm.RxIniPropStorage1StoredValues12Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if SameText(Trim(VarToStr(Value)), TIMING_INPUT_TRANSPORT_BLE) then
    timingInputTransport := ttkBle
  else
    timingInputTransport := ttkSerial;
end;

procedure TMainForm.RxIniPropStorage1StoredValues12Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if timingInputTransport = ttkBle then
    Value := TIMING_INPUT_TRANSPORT_BLE
  else
    Value := TIMING_INPUT_TRANSPORT_SERIAL;
end;

procedure TMainForm.RxIniPropStorage1StoredValues13Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  FStoredBleDeviceId := VarToStr(Value);
end;

procedure TMainForm.RxIniPropStorage1StoredValues13Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := LazBleLclClient1.DeviceId;
end;

procedure TMainForm.RxIniPropStorage1StoredValues14Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  FStoredBleDeviceName := VarToStr(Value);
end;

procedure TMainForm.RxIniPropStorage1StoredValues14Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := LazBleLclClient1.DeviceName;
end;

procedure TMainForm.RxIniPropStorage1StoredValues15Restore(Sender: TStoredValue;
  var Value: TStoredType);
var
  ParsedValue: integer;
begin
  ParsedValue := StrToIntDef(Trim(VarToStr(Value)), 15);
  if (ParsedValue < 0) or (ParsedValue > 60) then
    ParsedValue := 15;
  startMarkMatchDeltaSeconds := ParsedValue;
end;

procedure TMainForm.RxIniPropStorage1StoredValues15Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(startMarkMatchDeltaSeconds);
end;

procedure TMainForm.RxIniPropStorage1StoredValues16Restore(Sender: TStoredValue;
  var Value: TStoredType);
var
  ParsedValue: boolean;
begin
  if not TryStrToBool(Trim(VarToStr(Value)), ParsedValue) then
    ParsedValue := False;
  startMarkAutomaticApply := ParsedValue;
end;

procedure TMainForm.RxIniPropStorage1StoredValues16Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := BoolToStr(startMarkAutomaticApply, True);
end;

procedure TMainForm.RxIniPropStorage1StoredValues17Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    automaticBackupRetentionDays := StoredIntegerInRangeOrDefault(
      'automatic_backup_retention_days', Value,
      DEFAULT_AUTOMATIC_BACKUP_RETENTION_DAYS, 1, 3650);
end;

procedure TMainForm.RxIniPropStorage1StoredValues17Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(automaticBackupRetentionDays);
end;

procedure TMainForm.RxIniPropStorage1StoredValues18Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    automaticBackupMaxSizeMb := StoredIntegerInRangeOrDefault(
      'automatic_backup_max_size_mb', Value,
      DEFAULT_AUTOMATIC_BACKUP_MAX_SIZE_MB, 1, 1048576);
end;

procedure TMainForm.RxIniPropStorage1StoredValues18Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(automaticBackupMaxSizeMb);
end;

procedure TMainForm.RxIniPropStorage1StoredValues19Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    telegramRetryEnabled := StoredBooleanOrDefault(
      'telegram_retry_enabled', Value, TELEGRAM_RETRY_DEFAULT_ENABLED);
end;

procedure TMainForm.RxIniPropStorage1StoredValues19Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := BoolToStr(telegramRetryEnabled, True);
end;

procedure TMainForm.RxIniPropStorage1StoredValues20Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    telegramRetryCount := StoredIntegerInRangeOrDefault(
      'telegram_retry_count', Value, TELEGRAM_RETRY_DEFAULT_COUNT,
      TELEGRAM_RETRY_MIN_COUNT, TELEGRAM_RETRY_MAX_COUNT);
end;

procedure TMainForm.RxIniPropStorage1StoredValues20Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(telegramRetryCount);
end;

procedure TMainForm.RxIniPropStorage1StoredValues21Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    telegramRetryDelaySeconds := StoredIntegerInRangeOrDefault(
      'telegram_retry_delay_seconds', Value,
      TELEGRAM_RETRY_DEFAULT_DELAY_SECONDS,
      TELEGRAM_RETRY_MIN_DELAY_SECONDS,
      TELEGRAM_RETRY_MAX_DELAY_SECONDS);
end;

procedure TMainForm.RxIniPropStorage1StoredValues21Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(telegramRetryDelaySeconds);
end;

procedure TMainForm.RxIniPropStorage1StoredValues1Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  SetLang(Value);
end;

procedure TMainForm.RxIniPropStorage1StoredValues1Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := CurrentLang;
end;

procedure TMainForm.RxIniPropStorage1StoredValues2Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    SetTimingFinishInterval(StoredIntegerOrDefault(
      'finish_debounce_interval_ms', Value,
      DEFAULT_FINISH_DEBOUNCE_INTERVAL_MS));
end;

procedure TMainForm.RxIniPropStorage1StoredValues2Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(TimingFinishInterval);
end;

procedure TMainForm.RxIniPropStorage1StoredValues3Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    zerohour := StoredBooleanOrDefault('hide_zero_hour', Value,
      DEFAULT_ZERO_HOUR);
end;

procedure TMainForm.RxIniPropStorage1StoredValues3Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := BoolToStr(zerohour);
end;

procedure TMainForm.RxIniPropStorage1StoredValues4Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  ledpaneladress := Value;
end;

procedure TMainForm.RxIniPropStorage1StoredValues4Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := ledpaneladress;
end;

procedure TMainForm.RxIniPropStorage1StoredValues5Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  telegrambotadress := Value;
end;

procedure TMainForm.RxIniPropStorage1StoredValues5Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := telegrambotadress;
end;

procedure TMainForm.RxIniPropStorage1StoredValues6Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    showStageNameForSingleStage := StoredBooleanOrDefault(
      'show_stage_name_for_single_stage', Value,
      DEFAULT_SHOW_STAGE_NAME_FOR_SINGLE_STAGE);
end;

procedure TMainForm.RxIniPropStorage1StoredValues6Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := BoolToStr(showStageNameForSingleStage);
end;

procedure TMainForm.RxIniPropStorage1StoredValues7Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    checkUpdateAtStartup := StoredBooleanOrDefault('check_update_at_startup',
      Value, DEFAULT_CHECK_UPDATE_AT_STARTUP);
end;

procedure TMainForm.RxIniPropStorage1StoredValues7Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := BoolToStr(checkUpdateAtStartup);
end;

procedure TMainForm.RxIniPropStorage1StoredValues8Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    lastUpdateCheckoutTime := StoredDateTimeOrDefault(
      'last_update_checkout_time', Value, 0);
end;

procedure TMainForm.RxIniPropStorage1StoredValues8Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := DateTimeToStr(lastUpdateCheckoutTime);
end;

procedure TMainForm.RxIniPropStorage1StoredValues9Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    checkUpdateIntervalInDays := StoredIntegerOrDefault(
      'check_update_interval_days', Value,
      DEFAULT_CHECK_UPDATE_INTERVAL_IN_DAYS);
end;

procedure TMainForm.RxIniPropStorage1StoredValues9Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(checkUpdateIntervalInDays);
end;

procedure TMainForm.TabSheet2Show(Sender: TObject);
begin
  if IsCompetitionDatabaseOpen then
  begin
    StatDataset1.Close;
    StatDataset1.Open;
  end;
end;

procedure TMainForm.TimerMonitorTimer(Sender: TObject);
begin
  if MenuItemMonitorMode.Checked and IsCompetitionDatabaseOpen then
  begin
    RefreshResults;
  end;
end;


procedure TMainForm.FileOpenDBAccept(Sender: TObject);
begin
  if IsCompetitionDatabaseOpen then
    FileCloseExecute(nil);
  InitDB(FileOpenDB.Dialog.FileName);
end;

procedure TMainForm.FileExportFullBeforeExecute(Sender: TObject);
begin
  TFileSaveAs(Sender).Dialog.FileName :=
    raceName + '-' + UTF8LowerCase(rsFinishProtocol);
end;

procedure TMainForm.FileExportStageResultsSaveAsAccept(Sender: TObject);
begin
  exportStageIndex := stages.NormalizeActiveIndex(exportStageIndex);
  if exportStageIndex = 0 then
    Exit;
  ExportFinishTime(FileExportStageResultsSaveAs.Dialog.FileName, exportStageIndex);
end;

procedure TMainForm.FileExportStageResultsSaveAsBeforeExecute(Sender: TObject);
begin
  exportStageIndex := stages.NormalizeActiveIndex(exportStageIndex);
  if exportStageIndex = 0 then
    Exit;
  TFileSaveAs(Sender).Dialog.FileName :=
    raceName + '-' + UTF8LowerCase(rsResults) + '-' + stages[exportStageIndex].Name;
end;

procedure TMainForm.FileGenerateFinalBeforeExecute(Sender: TObject);
begin
  TFileSaveAs(Sender).Dialog.FileName := raceName + '-' + UTF8LowerCase(rsFinal);
end;

procedure TMainForm.FileExportFullAccept(Sender: TObject);
var
  exportFileName: string;
begin
  exportFileName := TFileSaveAs(Sender).Dialog.FileName;
  if ExportAllResultsToXLSX(exportFileName) then
    OpenDocument(ExpandFileName(exportFileName));
end;


procedure TMainForm.ResultClearClick(Sender: TObject);
var
  HiddenCount: integer;
  MessageText: string;
begin
  if not IsCompetitionDatabaseOpen or not Assigned(FFinishMarkService) or
    not DatasetFinishMarks.Active then
    Exit;
  if DatasetFinishMarks.State in [dsEdit, dsInsert] then
    DatasetFinishMarks.Cancel;
  if DatasetFinishMarks.ChangeCount > 0 then
    DatasetFinishMarks.CancelUpdates;
  try
    HiddenCount := FFinishMarkService.HideWorkQueue;
    if HiddenCount = 0 then
      Exit;
    AppLog(Format(rsFinishMarksHidden, [HiddenCount]), allInfo,
      alvStatus, alsDatabase);
    try
      CompetitionDb.RefreshQuery(DatasetFinishMarks);
    except
      on E: Exception do
      begin
        MessageText := Format(rsFinishMarksHideRefreshWarning, [E.Message]);
        AppLog(MessageText, allWarning, alvStatus, alsDatabase);
        AskMessageDlg(MessageText, mtWarning, [mbOK], 0);
      end;
    end;
  except
    on E: Exception do
    begin
      MessageText := Format(rsFinishMarksHideError, [E.Message]);
      AppLog(MessageText, allError, alvStatus, alsDatabase);
      AskMessageDlg(MessageText, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.SerialPortMenuItemClick(Sender: TObject);
var
  menuItem: TMenuItem;
begin
  if Serial.Active or not (Sender is TMenuItem) then
    Exit;
  menuItem := TMenuItem(Sender);
  if not menuItem.Enabled or (menuItem.Hint = '') then
    Exit;
  if Serial.Device <> menuItem.Hint then
  begin
    Serial.Device := menuItem.Hint;
    if Assigned(FTimingStreamProcessor) then
      FTimingStreamProcessor.Reset;
  end;
  RefreshAvailableSerialDevices;
  UpdateSerialPortControls;
end;

procedure TMainForm.SerialPortPopupMenuPopup(Sender: TObject);
begin
  RebuildSerialPortMenu;
end;

procedure TMainForm.TimingInputDeviceLabelClick(Sender: TObject);
var
  popupPosition: TPoint;
begin
  if timingInputTransport = ttkBle then
  begin
    SelectBleTimingTransportDevice;
    Exit;
  end;
  if Serial.Active then
    Exit;
  popupPosition := TimingInputDeviceLabel.ClientToScreen(
    Point(0, TimingInputDeviceLabel.Height));
  SerialPortPopupMenu.PopUp(popupPosition.X, popupPosition.Y);
end;

procedure TMainForm.TimingInputStateButtonClick(Sender: TObject);
begin
  if timingInputTransport = ttkBle then
  begin
    case LazBleConnectionAction(LazBleLclClient1) of
      lbcaConnect: LazBleLclClient1.Connect;
      lbcaDisconnect: LazBleLclClient1.Disconnect;
    end;
    Exit;
  end;
  if FSerialConnectionEnabled then
    if Serial.Active then
      AcCOMCloseExecute(AcCOMClose)
    else
      AcCOMOpenExecute(AcCOMOpen);
end;


procedure TMainForm.TimingPacketReceived(Sender: TObject;
  const APacket: TTimingPacket; const ASource: TTimingMarkSource);
begin
  ApplyTimingPacket(APacket, ASource);
end;

procedure TMainForm.TimingTransportDataReceived(Sender: TObject;
  const AData: RawByteString; const ASource: TTimingMarkSource);
begin
  FTimingStreamProcessor.Feed(AData, ASource, Now);
end;

procedure TMainForm.FirmwareResponseReceived(Sender: TObject;
  const AResponse: TFirmwareResponse);
var
  LogSource: TAppLogSource;
begin
  case AResponse.Source.Kind of
    tmskSerial: LogSource := alsSerial;
    tmskBle: LogSource := alsBle;
  else
    LogSource := alsApplication;
  end;
  AppLog(Format(
    'Firmware JSON response received validation=valid bytes=%d payload=%s device=%s',
    [Length(AResponse.RawJson),
    TimingPacketLogValue(AResponse.RawJson),
    TimingPacketLogValue(AResponse.Source.DeviceId)]), allDebug,
    alvDetails, LogSource);
end;

procedure TMainForm.LazBleLclClient1ConfigureClient(Sender: TObject);
begin
  if Assigned(FBleTimingTransport) then
    FBleTimingTransport.ConfigureClient(LazBleLclClient1.CoreClient);
end;

procedure TMainForm.LazBleComponent1AvailabilityChanged(Sender: TObject;
  const AAvailability: TBleAvailability);
begin
  case AAvailability of
    lbaChecking:
      AppLog('BLE availability check started', allDebug, alvNone, alsBle);
    lbaAvailable:
      AppLog('BLE available' +
        BleBackendLogContext(LazBleComponent1), allInfo, alvDetails, alsBle);
    lbaUnavailable:
      if LazBleComponent1.LastErrorMessage = '' then
        AppLog('BLE unavailable' +
          BleBackendLogContext(LazBleComponent1), allWarning, alvNone,
          alsBle);
  end;
  if timingInputTransport = ttkBle then
    RefreshTimingInputUi;
end;

procedure TMainForm.LazBleComponent1Error(Sender: TObject;
  const AErrorCode: Integer; const AErrorMessage: string);
var
  ErrorText: string;
begin
  ErrorText := AErrorMessage;
  if ErrorText = '' then
    ErrorText := IntToStr(AErrorCode);
  AppLog(Format('BLE operation failed code=%d error=%s',
    [AErrorCode, TimingPacketLogValue(ErrorText)]), allError, alvNone,
    alsBle);
  if timingInputTransport = ttkBle then
    RefreshTimingInputUi;
end;

procedure TMainForm.LazBleComponent1ScanStateChanged(Sender: TObject;
  const AState: TLazBleLclScanState);
begin
  if AState = lblssScanning then
    AppLog(Format('BLE scan started timeout_ms=%d',
      [LazBleComponent1.ScanTimeoutMs]), allDebug, alvNone, alsBle)
  else if AState <> lblssIdle then
    AppLog(Format('BLE scan completed state=%s result_count=%d',
      [BleScanStateName(AState), Length(LazBleComponent1.ScanResults)]),
      allDebug, alvNone, alsBle);
  if timingInputTransport = ttkBle then
    RefreshTimingInputUi;
end;

procedure TMainForm.LazBleLclClient1DeviceChanged(Sender: TObject);
begin
  if Assigned(FBleTimingTransport) then
    FBleTimingTransport.HandleDeviceChanged(LazBleLclClient1.DeviceId);
  if timingInputTransport = ttkBle then
    RefreshTimingInputUi;
end;

procedure TMainForm.LazBleLclClient1Error(Sender: TObject;
  const AErrorCode: Integer; const AErrorMessage: string);
var
  ErrorText: string;
begin
  ErrorText := AErrorMessage;
  if ErrorText = '' then
    ErrorText := IntToStr(AErrorCode);
  AppLog(Format('BLE client operation failed code=%d error=%s device=%s',
    [AErrorCode, TimingPacketLogValue(ErrorText),
    BleDiagnosticValue(LazBleLclClient1.DeviceId, 'unknown')]),
    allError, alvNone, alsBle);
  if timingInputTransport = ttkBle then
    RefreshTimingInputUi;
end;

procedure TMainForm.LazBleLclClient1StateChanged(Sender: TObject;
  const AState: TLazBleClientState);
begin
  AppLog(Format('BLE connection state=%s device=%s',
    [BleClientStateName(AState),
    BleDiagnosticValue(LazBleLclClient1.DeviceId, 'unknown')]),
    allDebug, alvNone, alsBle);
  if Assigned(FBleTimingTransport) then
    FBleTimingTransport.HandleStateChanged(AState);
  if (timingInputTransport = ttkBle) and
    (AState in [lbcstDisconnected, lbcstError]) and
    Assigned(FTimingStreamProcessor) then
    FTimingStreamProcessor.Reset;
  if timingInputTransport = ttkBle then
    RefreshTimingInputUi;
end;

procedure TMainForm.TimingMessageRejected(Sender: TObject;
  const ARejected: TTransportStreamRejected);
var
  LogSource: TAppLogSource;
begin
  case ARejected.Source.Kind of
    tmskBle: LogSource := alsBle;
  else
    LogSource := alsSerial;
  end;
  AppLog(Format(rsSerialPacketRejected,
    [TransportStreamRejectedCode(ARejected),
    TimingPacketLogValue(ARejected.RawText)]),
    allDebug, alvDetails, LogSource);
end;


procedure TMainForm.SerialStatus(Sender: TObject; Reason: THookSerialReason;
  const Value: string);
begin
  case Reason of
    HR_SerialClose:
      begin
        if Assigned(FTimingStreamProcessor) then
          FTimingStreamProcessor.Reset;
        UpdateSerialStatusText(Format(rsPortClosed, [Value]));
        if FSerialCloseRequested then
        begin
          if not FClosing then
            AppLog(Format(rsPortClosed, [Value]), allInfo, alvNone,
              alsSerial);
          FSerialConnectionLost := False;
        end
        else
        begin
          if not FClosing and not FSerialConnectionLost then
            AppLog(Format(rsPortConnectionLost, [Value]), allWarning,
              alvStatus, alsSerial);
          FSerialConnectionLost := True;
        end;
        FSerialCloseRequested := False;
      end;
    HR_Connect:
      begin
        if Assigned(FTimingStreamProcessor) then
          FTimingStreamProcessor.Reset;
        if FSerialConnectionLost then
        begin
          UpdateSerialStatusText(
            Format(rsPortConnectionRestored, [Value]));
          AppLog(Format(rsPortConnectionRestored, [Value]), allInfo,
            alvStatus, alsSerial);
        end
        else
        begin
          UpdateSerialStatusText(Format(rsPortConnected, [Value]));
          AppLog(Format(rsPortConnected, [Value]), allInfo, alvNone,
            alsSerial);
        end;
        FSerialCloseRequested := False;
        FSerialConnectionLost := False;
      end;
    HR_CanRead: UpdateSerialStatusText(Format(rsSerialCanRead, [Value]));
    HR_CanWrite: UpdateSerialStatusText(Format(rsSerialCanWrite, [Value]));
    HR_ReadCount: UpdateSerialStatusText(Format(rsSerialReadCount, [Value]));
    HR_WriteCount: UpdateSerialStatusText(Format(rsSerialWriteCount, [Value]));
    HR_Wait: UpdateSerialStatusText(Format(rsSerialWait, [Value]));
  end;
  UpdateSerialPortControls;
end;


procedure TMainForm.Timer1Timer(Sender: TObject);
var
  pos: integer;
begin
  //это часы внизу
  Clock.Caption := FormatDateTime('hh:nn:ss', Now);

  //это тикающие секунды в окне "на трассе"
  if IsCompetitionDatabaseOpen then
  begin
    //запоминает положение курсора
    pos := StatDataset2.RecNo;
    //и восстанавливает его
    CompetitionDb.RefreshQuery(StatDataset2);
    StatDataset2.MoveBy(pos - 1);
  end;
end;


procedure TMainForm.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
  FinishTime: TDateTime;
  StageIndex: integer;
begin
  if (Key = VK_RETURN) and (Shift = [ssCtrl]) then
  begin
    if RxDBGridFinishMarks.ContainsControl(ActiveControl) then
    begin
      if RxDBGridFinishMarks.EditorMode then
        RxDBGridFinishMarks.EditorMode := False;
      if AcApplyFinishMarks.Enabled then
        AcApplyFinishMarks.Execute;
      Key := 0;
      Exit;
    end;

    if RxDBGridStartMarks.ContainsControl(ActiveControl) then
    begin
      if RxDBGridStartMarks.EditorMode then
        RxDBGridStartMarks.EditorMode := False;
      AcApplyStartMarksUpdate(AcApplyStartMarks);
      if AcApplyStartMarks.Enabled then
        AcApplyStartMarks.Execute;
      Key := 0;
      Exit;
    end;
  end;

  if (Key = VK_SPACE) and RaceMode.Checked then
  begin
    if DatasetFinishMarks.Active and
      ((DatasetFinishMarks.State in [dsEdit, dsInsert]) or
      (DatasetFinishMarks.ChangeCount > 0)) then
      RxDBGridFinishMarksEditingDone(RxDBGridFinishMarks);
    FinishTime := Now;
    StageIndex := stages.NormalizeActiveIndex(CurrentStageIndex);
    if StageIndex > 0 then
      FTimingMarkRouter.Route(TTimingMark.Finish(FinishTime,
        TTimingMarkSource.Manual, FinishTime), StageIndex);
    Memo.Lines.Add(FormatDateTime('hh:nn:ss.zzz', FinishTime) + ' manual');
    Key := 0;
  end;
end;

procedure TMainForm.HistoryFiles1ClickHistoryItem(Sender: TObject;
  Item: TMenuItem; const Filename: string);
begin
  if IsCompetitionDatabaseOpen then
    FileCloseExecute(nil);
  InitDB(FileName);
end;

procedure TMainForm.MainDataset1AfterInsert(DataSet: TDataSet);
var
  i: integer;
begin
  i := TMainSql.GetMaxNumber(SQLQuery1);
  if i > 0 then
    i := i + 1
  else
    i := 1;
  DataSet.FieldByName('number').AsInteger := i;
end;

procedure TMainForm.CheckPenaltySetText(Sender: TField; const aText: string);
var
  normalizedValue: string;
begin
  if Trim(aText) = '' then
    Sender.AsString := ''
  else if TryNormalizeDuration(aText, normalizedValue) then
    Sender.AsString := normalizedValue
  else
    AskMessageDlg(rsPenaltyTimeFormat, mtInformation, [mbOK], 0);
end;

procedure TMainForm.CheckStatusSetText(Sender: TField; const aText: string);
var
  status: TParticipantStatus;
begin
  if TryParseParticipantStatus(aText, status) then
  begin
    if status = psNone then
      Sender.Clear
    else
      Sender.AsString := ParticipantStatusToDbValue(status);
  end
  else
    AskMessageDlg(rsParticipantStatusValueFormat, mtInformation, [mbOK], 0);
end;

procedure TMainForm.HideZeroHour(Sender: TField; var aText: string;
  DisplayText: boolean);
begin
  aText := ResultFormatting.HideLeadingZeroHour(Sender, zerohour);
end;

procedure TMainForm.MenuItemMonitorModeClick(Sender: TObject);
var
  n: integer;
  c: TComponent;
begin
  if MenuItemMonitorMode.Checked then
  begin
    TimerMonitor.Enabled := True;
    for n := 0 to ComponentCount - 1 do
    begin
      c := MainForm.Components[n];
      if c is TRxDBGrid then
        TRxDBGrid(c).Enabled := False;
    end;
  end
  else
  begin
    TimerMonitor.Enabled := False;
    for n := 0 to ComponentCount - 1 do
    begin
      c := MainForm.Components[n];
      if c is TRxDBGrid then
        TRxDBGrid(c).Enabled := True;
    end;
  end;
end;

procedure TMainForm.MenuItem5Click(Sender: TObject);
begin
end;

procedure TMainForm.StageFieldChanged(Sender: TField);
var
  n, fieldCaption, oldValue, newValue: string;
  stageIndex: integer;
  stageFieldKind: TStageFieldKind;
begin
  if not QueryHasActualChanges(MainDataset1) then
  begin
    FPendingParticipantLogMessage := '';
    FPendingParticipantStageIndex := 0;
    Exit;
  end;

  try
    if FieldValuesAreEqual(Sender.OldValue, Sender.Value) then
      Exit;
    oldValue := ParticipantLogValue(Sender, Sender.OldValue);
    newValue := ParticipantLogValue(Sender, Sender.Value);
  except
    Exit;
  end;

  n := MainDataset1.FieldByName('number').AsString;
  if not TryParseStageFieldName(Sender.FieldName, stageFieldKind,
    stageIndex) then
  begin
    FPendingParticipantLogMessage := '';
    FPendingParticipantStageIndex := 0;
    Exit;
  end;
  case stageFieldKind of
    sfkStartTime: fieldCaption := rsStarttime;
    sfkFinishTime: fieldCaption := rsFinishtime;
    sfkCorrection: fieldCaption := rsCorrection;
    sfkPenalty: fieldCaption := rsPenalty;
    else fieldCaption := Sender.FieldName;
  end;
  FPendingParticipantStageIndex := stageIndex;
  FPendingParticipantLogMessage := Format(rsParticipantStageValueChanged,
    [n, fieldCaption, stageIndex, oldValue, newValue]);
end;

procedure TMainForm.MainDataset1statusGetText(Sender: TField;
  var aText: string; DisplayText: boolean);
var
  status: TParticipantStatus;
begin
  if TryParticipantStatusFromDbValue(Sender.AsString, status) then
    aText := ParticipantStatusToToken(status)
  else
    aText := Sender.AsString;
end;

procedure TMainForm.MenuItemAboutClick(Sender: TObject);
begin
  RxAboutDialog1.Execute;
end;

procedure TMainForm.RaceModeClick(Sender: TObject);
begin
  if RaceMode.Checked then
  begin
    RaceModeLabel.Font.Color := clRed;
    RaceModeLabel.Font.Style := RaceModeLabel.Font.Style + [fsBold];
    RxDBGrid1.Options := RxDBGrid1.Options - [dgEditing];
    RxDBGrid1.Color := clMenu;
  end
  else
  begin
    RxDBGrid1.Options := RxDBGrid1.Options + [dgEditing];
    RaceModeLabel.Font.Style := RaceModeLabel.Font.Style - [fsBold];
    RaceModeLabel.Font.Color := clDefault;
    RxDBGrid1.Color := clWindow;
  end;
end;

procedure TMainForm.CurrentStageComboBoxChange(Sender: TObject);
begin
  if not FUpdatingCurrentStageSelector then
    ConfigureCurrentStageDatasets;
end;

procedure TMainForm.RxDBGrid1EditingDone(Sender: TObject);
var
  n, messageText, pendingLogMessage, logMessage: string;
  pendingStageIndex: integer;
  changeMessages: TStringList;
begin
  if IsCompetitionDatabaseOpen then
  begin
    if FPendingParticipantLogMessage <> '' then
    begin
      if not QueryHasActualChanges(MainDataset1) then
      begin
        FPendingParticipantLogMessage := '';
        FPendingParticipantStageIndex := 0;
        if MainDataset1.State in [dsEdit, dsInsert] then
          MainDataset1.Cancel;
        Exit;
      end;
      n := MainDataset1.FieldByName('number').AsString;
      pendingLogMessage := FPendingParticipantLogMessage;
      pendingStageIndex := FPendingParticipantStageIndex;
      FPendingParticipantLogMessage := '';
      try
        CompetitionDb.ApplyUpdatesAndRefreshUi(MainDataset1);
        if CheckBoxAutomaticUpdateResutls.Checked then
          UpdateResults
        else
        begin
          CorrectionDataset.Close;
          CorrectionDataset.Open;
        end;
        AppLog(pendingLogMessage, allInfo, alvNone, alsResults);
      except
        on E: Exception do
        begin
          messageText := Format(rsParticipantStageSaveError,
            [n, pendingStageIndex, E.Message]);
          AppLog(messageText, allError, alvStatus, alsResults);
          AskMessageDlg(messageText, mtError, [mbOK], 0);
        end;
      end;
      FPendingParticipantLogMessage := '';
      Exit;
    end;
    if not QueryHasActualChanges(MainDataset1) then
    begin
      if MainDataset1.State in [dsEdit, dsInsert] then
        MainDataset1.Cancel;
      Exit;
    end;
    n := MainDataset1.FieldByName('number').AsString;
    changeMessages := TStringList.Create;
    try
      BuildParticipantChangeLogMessages(MainDataset1, RxDBGrid1, changeMessages);
      try
        CompetitionDb.ApplyUpdatesAndRefreshUi(MainDataset1);
        RefreshResults;
        for logMessage in changeMessages do
          AppLog(logMessage, allInfo, alvNone, alsResults);
        FPendingParticipantLogMessage := '';
        FPendingParticipantStageIndex := 0;
      except
        on E: Exception do
        begin
          messageText := Format(rsParticipantSaveError, [n, E.Message]);
          AppLog(messageText, allError, alvStatus, alsResults);
          AskMessageDlg(messageText, mtError, [mbOK], 0);
        end;
      end;
    finally
      changeMessages.Free;
    end;
  end;
end;


//Отключить добавление новой строки при нажатии стрелки вниз на последней строке
procedure TMainForm.RxDBGrid1KeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
  if (Key = VK_DOWN) then
  begin
    MainDataset1.DisableControls;
    MainDataset1.Next;
    if MainDataset1.EOF then
      Key := 0
    else
      MainDataset1.Prior;
    MainDataset1.EnableControls;
  end;
end;

procedure TMainForm.RxDBGrid1KeyPress(Sender: TObject; var Key: char);
var
  stageFieldKind: TStageFieldKind;
  stageIndex: integer;
begin
  if Assigned(TRxDBGrid(Sender).SelectedColumn) and
    TryParseStageFieldName(TRxDBGrid(Sender).SelectedColumn.FieldName,
    stageFieldKind, stageIndex) and (stageFieldKind = sfkPenalty) then
    Key := ResultFormatting.CheckPenaltyInput(Key);
end;

procedure TMainForm.RxDBGrid1SelectEditor(Sender: TObject; Column: TColumn;
  var Editor: TWinControl);
var
  categoryQuery: TSQLQuery;
begin
  if Column.FieldName = 'category' then
  begin
    categoryQuery := CompetitionDb.CreateQuery(nil);
    try
      TMainSql.LoadCategories(categoryQuery, ComboBox1Category.Items);
    finally
      categoryQuery.Free;
    end;
    ComboBox1Category.Text :=
      TRxDBGrid(Sender).DataSource.DataSet.FieldByName('category').AsString;
    Editor := ComboBox1Category;
    Editor.BoundsRect := TRxDBGrid(Sender).SelectedFieldRect;
    // И заодно обнуляем список категорий
    // ToDo: делать это только при непосредственном изменении категорий
    startlistConfig.categories.Text := '';
  end;
end;

procedure TMainForm.RxDBGridStartMarksEditingDone(Sender: TObject);
var
  HasParticipantNumber: boolean;
  MarkId: int64;
  ParticipantNumber: integer;
begin
  if not IsCompetitionDatabaseOpen or not Assigned(FStartMarkService) or
    not DatasetStartMarks.Active or DatasetStartMarks.IsEmpty then
    Exit;
  if not ((DatasetStartMarks.State in [dsEdit, dsInsert]) or
    (DatasetStartMarks.ChangeCount > 0)) then
    Exit;

  MarkId := DatasetStartMarks.FieldByName('id').AsLargeInt;
  HasParticipantNumber :=
    not DatasetStartMarks.FieldByName('participant_number').IsNull;
  if HasParticipantNumber then
    ParticipantNumber :=
      DatasetStartMarks.FieldByName('participant_number').AsInteger
  else
    ParticipantNumber := 0;
  if DatasetStartMarks.State in [dsEdit, dsInsert] then
    DatasetStartMarks.Cancel
  else
    DatasetStartMarks.CancelUpdates;

  try
    FStartMarkService.SetParticipantNumber(MarkId, HasParticipantNumber,
      ParticipantNumber);
    CompetitionDb.RefreshQuery(DatasetStartMarks);
    DatasetStartMarks.Locate('id', MarkId, []);
  except
    on E: Exception do
    begin
      AppLog(Format(rsStartMarkNumberSaveError, [E.Message]), allError,
        alvStatus, alsDatabase);
      AskMessageDlg(Format(rsStartMarkNumberSaveError, [E.Message]),
        mtError, [mbOK], 0);
      CompetitionDb.RefreshQuery(DatasetStartMarks);
    end;
  end;
end;

procedure TMainForm.TimingMarkWorkQueueBeforeInsert(DataSet: TDataSet);
begin
  Abort;
end;

procedure TMainForm.RxDBGridStartMarksDblClick(Sender: TObject);
var
  MarkId: int64;
  ParticipantNumber: integer;
begin
  if not IsCompetitionDatabaseOpen or not Assigned(FStartMarkService) or
    not DatasetStartMarks.Active or DatasetStartMarks.IsEmpty or
    DatasetStartMarks.FieldByName('participant_number').IsNull then
    Exit;
  ParticipantNumber :=
    DatasetStartMarks.FieldByName('participant_number').AsInteger;
  if ParticipantNumber < 1 then
    Exit;
  MarkId := DatasetStartMarks.FieldByName('id').AsLargeInt;
  ApplyStartMark(MarkId, ParticipantNumber);
end;

procedure TMainForm.RxDBGridFinishMarksEditingDone(Sender: TObject);
var
  HasParticipantNumber: boolean;
  MarkId: int64;
  MessageText: string;
  ParticipantNumber: integer;
begin
  if not IsCompetitionDatabaseOpen or not Assigned(FFinishMarkService) or
    not DatasetFinishMarks.Active or DatasetFinishMarks.IsEmpty then
    Exit;
  if not ((DatasetFinishMarks.State in [dsEdit, dsInsert]) or
    (DatasetFinishMarks.ChangeCount > 0)) then
    Exit;

  MarkId := DatasetFinishMarks.FieldByName('id').AsLargeInt;
  HasParticipantNumber :=
    not DatasetFinishMarks.FieldByName('participant_number').IsNull;
  if HasParticipantNumber then
    ParticipantNumber :=
      DatasetFinishMarks.FieldByName('participant_number').AsInteger
  else
    ParticipantNumber := 0;
  if DatasetFinishMarks.State in [dsEdit, dsInsert] then
    DatasetFinishMarks.Cancel
  else
    DatasetFinishMarks.CancelUpdates;

  if HasParticipantNumber and (ParticipantNumber < 1) then
  begin
    AppLog(rsParticipantNumberMustBePositive, allWarning,
      alvDetails, alsFinishMarks);
    QueueFinishMarkEditDialog(rsParticipantNumberMustBePositive,
      mtWarning);
    RefreshFinishMarkWorkQueue(MarkId);
    Exit;
  end;

  try
    FFinishMarkService.SetParticipantNumber(MarkId,
      HasParticipantNumber, ParticipantNumber);
    RefreshFinishMarkWorkQueue(MarkId);
  except
    on E: Exception do
    begin
      MessageText := Format(rsFinishMarkNumberSaveError, [E.Message]);
      AppLog(MessageText, allError, alvStatus, alsDatabase);
      QueueFinishMarkEditDialog(MessageText, mtError);
      RefreshFinishMarkWorkQueue(MarkId);
    end;
  end;
end;

procedure TMainForm.QueueFinishMarkEditDialog(const AMessage: string;
  const ADialogType: TMsgDlgType);
begin
  if FClosing or FFinishMarkEditDialogQueued then
    Exit;
  FPendingFinishMarkEditMessage := AMessage;
  FPendingFinishMarkEditDialogType := ADialogType;
  FFinishMarkEditDialogQueued := True;
  Application.QueueAsyncCall(@ShowFinishMarkEditDialog, 0);
end;

procedure TMainForm.ShowFinishMarkEditDialog(Data: PtrInt);
var
  MessageText: string;
begin
  FFinishMarkEditDialogQueued := False;
  MessageText := FPendingFinishMarkEditMessage;
  FPendingFinishMarkEditMessage := '';
  if FClosing or (MessageText = '') then
    Exit;
  AskMessageDlg(MessageText, FPendingFinishMarkEditDialogType, [mbOK], 0);
end;

procedure TMainForm.RxDBGridFinishMarksDblClick(Sender: TObject);
var
  MarkId: int64;
  ParticipantNumber: integer;
begin
  if not IsCompetitionDatabaseOpen or not Assigned(FFinishMarkService) or
    not DatasetFinishMarks.Active or DatasetFinishMarks.IsEmpty then
    Exit;
  if (DatasetFinishMarks.State in [dsEdit, dsInsert]) or
    (DatasetFinishMarks.ChangeCount > 0) then
    RxDBGridFinishMarksEditingDone(RxDBGridFinishMarks);
  if DatasetFinishMarks.IsEmpty or DatasetFinishMarks.FieldByName(
    'participant_number').IsNull then
    Exit;
  ParticipantNumber := DatasetFinishMarks.FieldByName(
    'participant_number').AsInteger;
  if ParticipantNumber < 1 then
    Exit;
  MarkId := DatasetFinishMarks.FieldByName('id').AsLargeInt;
  if ApplyFinishMark(MarkId, ParticipantNumber) then
    RefreshAll;
end;

function TMainForm.HasNumberedStartMarks: boolean;
var
  CurrentMarkId: int64;
begin
  Result := False;
  if not DatasetStartMarks.Active or DatasetStartMarks.IsEmpty then
    Exit;
  if DatasetStartMarks.State <> dsBrowse then
  begin
    Result := not DatasetStartMarks.FieldByName(
      'participant_number').IsNull and
      (DatasetStartMarks.FieldByName(
      'participant_number').AsInteger > 0);
    Exit;
  end;

  CurrentMarkId := DatasetStartMarks.FieldByName('id').AsLargeInt;
  DatasetStartMarks.DisableControls;
  try
    DatasetStartMarks.First;
    while not DatasetStartMarks.EOF do
    begin
      if not DatasetStartMarks.FieldByName(
        'participant_number').IsNull and
        (DatasetStartMarks.FieldByName(
        'participant_number').AsInteger > 0) then
      begin
        Result := True;
        Break;
      end;
      DatasetStartMarks.Next;
    end;
  finally
    DatasetStartMarks.Locate('id', CurrentMarkId, []);
    DatasetStartMarks.EnableControls;
  end;
end;

procedure TMainForm.RefreshAfterStartMarkApply;
var
  MessageText: string;
begin
  try
    RefreshAll;
  except
    on E: Exception do
    begin
      MessageText := Format(rsStartMarkRefreshWarning, [E.Message]);
      AppLog(MessageText, allWarning, alvStatus, alsResults);
      AskMessageDlg(MessageText, mtWarning, [mbOK], 0);
    end;
  end;
end;

function TMainForm.ApplyStartMark(const AMarkId: int64;
  const AParticipantNumber: integer;
  const ARefreshAfterApply: boolean): boolean;
var
  ApplyResult: TStartMarkApplyResult;
  AppliedStageIndex: integer;
  CurrentStage: integer;
  Mark: TStartMark;
  MessageText: string;
  StageChoice: TStartMarkStageChoice;
begin
  Result := False;
  if not FStartMarkService.TryLoad(AMarkId, Mark) then
    Exit;

  CurrentStage := CurrentStageIndex;
  AppliedStageIndex := Mark.StageIndex;
  if CurrentStage <> Mark.StageIndex then
  begin
    if not stages.IsValidIndex(CurrentStage) then
      Exit;
    StageChoice := AskStartMarkStageChoice(rsStartMarkStageChoiceTitle,
      Format(rsStartMarkStageChoiceMessage,
        [AParticipantNumber, Mark.StageIndex, stages[Mark.StageIndex].Name,
        CurrentStage, stages[CurrentStage].Name]),
      Format(rsApplyToReceivedStage, [Mark.StageIndex]),
      Format(rsApplyToCurrentStage, [CurrentStage]));
    case StageChoice of
      smscReceivedStage: AppliedStageIndex := Mark.StageIndex;
      smscCurrentStage: AppliedStageIndex := CurrentStage;
      smscCancel: Exit;
    end;
  end;

  try
    ApplyResult := FStartMarkService.ApplyManualById(AMarkId,
      AParticipantNumber, AppliedStageIndex, False, Now);
    if ApplyResult.ApplyFailure = smafExistingCorrection then
    begin
      if AskMessageDlg(Format(rsCorrectionAlreadySet,
        [IntToStr(AParticipantNumber)]), mtWarning,
        [mbYes, mbNo], 0) <> mrYes then
        Exit;
      ApplyResult := FStartMarkService.ApplyManualById(AMarkId,
        AParticipantNumber, AppliedStageIndex, True, Now);
    end;

    if ApplyResult.Applied then
    begin
      AppLog(Format(rsStartMarkApplied,
        [AParticipantNumber, Mark.StageIndex, AppliedStageIndex,
        Mark.CorrectionMs]), allInfo, alvStatus, alsResults);
      Result := True;
      if ARefreshAfterApply then
        RefreshAfterStartMarkApply;
      Exit;
    end;

    case ApplyResult.ApplyFailure of
      smafCorrectionMissing:
        MessageText := Format(rsStartMarkCorrectionMissing,
          [AParticipantNumber]);
      smafParticipantNotFound:
        MessageText := Format(rsParticipantDoesNotExist,
          [IntToStr(AParticipantNumber)]);
      else
        MessageText := Format(rsStartMarkApplyError,
          [AParticipantNumber, ApplyResult.Mark.Diagnostic]);
    end;
    AppLog(MessageText, allWarning, alvStatus, alsResults);
    AskMessageDlg(MessageText, mtWarning, [mbOK], 0);
    CompetitionDb.RefreshQuery(DatasetStartMarks);
    DatasetStartMarks.Locate('id', AMarkId, []);
  except
    on E: Exception do
    begin
      MessageText := Format(rsStartMarkApplyError,
        [AParticipantNumber, E.Message]);
      AppLog(MessageText, allError, alvStatus, alsResults);
      AskMessageDlg(MessageText, mtError, [mbOK], 0);
      CompetitionDb.RefreshQuery(DatasetStartMarks);
    end;
  end;
end;

procedure TMainForm.UpdateStartMarkPanelTranslations;
begin
  PanelStartMarks.Caption := rsStartMarks;
  AcApplyStartMarks.Caption := rsWrite;
  AcClearStartMarks.Caption := rsClear;
  AcOpenStartMarkJournal.Caption := rsOpenStartMarksWindow;
  AcOpenStartMarkJournal.Hint := rsOpenStartMarksWindowHint;
  RxDBGridStartMarks.Columns[0].Title.Caption := rsTime;
  RxDBGridStartMarks.Columns[1].Title.Caption := rsCorrection;
  RxDBGridStartMarks.Columns[2].Title.Caption := rsNumber;
end;

procedure TMainForm.UpdateFinishMarkPanelTranslations;
begin
  PanelResult.Caption := rsFinishMarks;
  AcApplyFinishMarks.Caption := rsWrite;
  ResultClear.Caption := rsClear;
  AcOpenFinishMarkJournal.Caption := rsOpenFinishMarksWindow;
  AcOpenFinishMarkJournal.Hint := rsOpenFinishMarksWindowHint;
  RxDBGridFinishMarks.Columns[0].Title.Caption := rsTime;
  RxDBGridFinishMarks.Columns[1].Title.Caption := rsNumber;
end;

procedure TMainForm.CheckDBOpen(Sender: TObject);
begin
  TCustomAction(Sender).Enabled := IsCompetitionDatabaseOpen;
end;

procedure TMainForm.SetLang(ALang: string);
var
  lang, SystemCurrentLang, SystemFallbackLang: string;
begin
  if ALang <> '' then
  begin
    lang := ALang;
    CurrentLang := ALang;
  end
  else
  begin
    GetLanguageIDs(SystemCurrentLang{%H-}, SystemFallbackLang{%H-}); // in unit gettext
    lang := SystemFallbackLang;
    CurrentLang := '';
  end;

  SetDefaultLang(lang);

  TranslateUnitResourceStrings('i18n', NormalizeDirectoryName(
    RuntimeResourceDirectory('languages') + 'entime.%s.po'), lang, FallbackLang);
  TranslateUnitResourceStrings('rxconst', NormalizeDirectoryName(
    RuntimeResourceDirectory('languages') + 'rxconst.%s.po'), lang, FallbackLang);
  TranslateUnitResourceStrings('rxdconst', NormalizeDirectoryName(
    RuntimeResourceDirectory('languages') + 'rxdconst.%s.po'), lang, FallbackLang);
  TranslateLazBleLclResourceStrings(RuntimeResourceDirectory('languages'), lang,
    FallbackLang);
  UpdateStartMarkPanelTranslations;
  UpdateFinishMarkPanelTranslations;
end;

procedure TMainForm.EnsureUpdateCheckController;
begin
  if not FClosing and not Assigned(FUpdateCheckController) then
    FUpdateCheckController := TUpdateCheckController.Create(
      @CreateDefaultUpdateChecker, @UpdateCheckCompleted);
end;

procedure TMainForm.StartAutomaticUpdateCheck(Data: PtrInt);
begin
  if FClosing then
    Exit;

  EnsureUpdateCheckController;
  try
    if Assigned(FUpdateCheckController) and
      FUpdateCheckController.StartAutomatic(GetFileVersion,
        checkUpdateAtStartup, checkUpdateIntervalInDays,
        lastUpdateCheckoutTime, Now) then
      AppLog(rsAutomaticUpdateCheckStarted, allDebug, alvNone, alsUpdater);
  except
    on E: Exception do
      AppLog(Format(rsAutomaticUpdateCheckFailed, [E.Message]), allWarning,
        alvNone, alsUpdater);
  end;
end;

procedure TMainForm.UpdateCheckCompleted(Sender: TObject;
  AMode: TUpdateCheckMode; const AResult: TUpdateCheckResult);
var
  logLevel: TAppLogLevel;
  logMessage: string;
  logView: TAppLogView;
begin
  if FClosing then
    Exit;

  if UpdateCheckSucceeded(AResult.Status) then
    lastUpdateCheckoutTime := Now;

  case AResult.Status of
    ucsUpdateAvailable:
      begin
        updateExists := True;
        lastVersionOnline := AResult.LastVersion;
        lastReleaseUrlOnline := AResult.ReleaseUrl;
      end;
    ucsUpToDate:
      begin
        updateExists := False;
        lastVersionOnline := AResult.LastVersion;
        lastReleaseUrlOnline := AResult.ReleaseUrl;
      end;
  end;

  case AResult.Status of
    ucsUpdateAvailable:
      logLevel := allInfo;
    ucsUpToDate:
      if AMode = ucmManual then
        logLevel := allInfo
      else
        logLevel := allDebug;
    ucsFailed:
      if AMode = ucmManual then
        logLevel := allError
      else
        logLevel := allWarning;
    else
      logLevel := allDebug;
  end;

  if logLevel in [allInfo, allError] then
    logView := alvStatus
  else
    logView := alvNone;

  case AResult.Status of
    ucsUpdateAvailable:
      logMessage := Format(rsNewVersionFound, [AResult.LastVersion]);
    ucsUpToDate:
      logMessage := rsUpdatesNotFound;
    ucsFailed:
      if AMode = ucmManual then
        logMessage := Format(rsUpdateCheckFailed, [AResult.ErrorMessage])
      else
        logMessage := Format(rsAutomaticUpdateCheckFailed,
          [AResult.ErrorMessage]);
    else
      logMessage := rsUpdateCheckCancelled;
  end;
  AppLog(logMessage, logLevel, logView, alsUpdater);

  case UpdateCheckNotification(AMode, AResult.Status) of
    ucnUpdateAvailable:
      begin
        if AskMessageDlg(Format(rsNewVersionAvailable, [AResult.LastVersion]),
          TMsgDlgType.mtInformation, mbYesNo, 0) = mrYes then
          OpenURL(AResult.ReleaseUrl);
      end;
    ucnUpToDate:
      begin
        AskMessageDlg(rsUpdatesNotFound, TMsgDlgType.mtInformation, [mbOK], 0);
      end;
    ucnFailure:
      begin
        AskMessageDlg(Format(rsUpdateCheckFailed, [AResult.ErrorMessage]),
          TMsgDlgType.mtError, [mbOK], 0);
      end;
    ucnNone:
    begin
    end;
  end;
end;

procedure TMainForm.SetTimingFinishInterval(const AValue: integer);
begin
  FFinishDebounceIntervalMs := AValue;
  if Assigned(FFinishMarkService) then
    FFinishMarkService.DebounceIntervalMs := AValue;
end;

function TMainForm.TimingFinishInterval: integer;
begin
  Result := FFinishDebounceIntervalMs;
end;

procedure TMainForm.ReportRefreshOutcome(
  const AOutcome: TCompetitionRefreshOutcome);
var
  MessageText: string;
begin
  if AOutcome.ErrorCount = 0 then
    Exit;
  MessageText := Format(rsDatabaseRefreshError,
    [AOutcome.ErrorCount, AOutcome.Errors]);
  AppLog(MessageText, allError, alvStatus, alsDatabase);
  AskMessageDlg(MessageText, mtError, [mbOK], 0);
end;

procedure TMainForm.RefreshAll;
var
  GridRow: integer;
  HadGridPosition: boolean;
  Outcome: TCompetitionRefreshOutcome;
begin
  HadGridPosition := MainDataset1.Active and not MainDataset1.IsEmpty;
  if HadGridPosition then
    GridRow := RxDBGrid1.GetRow;

  Outcome := TCompetitionRefreshCoordinator.RefreshAll(
    CompetitionDb, MainDataset1,
    [CorrectionDataset, DatasetStartMarks, DatasetFinishMarks,
    ResultDatasetStageTotal,
    ResultDatasetStageSum, StatDataset1, StatDataset2],
    [ResultsForm.CatDataset1, ResultsForm.CatDataset2,
    ResultsForm.CatDataset3, ResultsForm.CatDataset4,
    ResultsForm.CatDataset5, ResultsForm.CatDataset6,
    ResultsForm.ResultDataset], @RefreshStageResultQueries);

  if HadGridPosition and Outcome.CurrentParticipantRestored and
    Assigned(RxDBGrid1.DataSource) and
    Assigned(RxDBGrid1.DataSource.DataSet) then
    try
      RxDBGrid1.RestoreCurrentRow(GridRow);
    except
      on E: Exception do
      begin
        Inc(Outcome.ErrorCount);
        if Outcome.Errors <> '' then
          Outcome.Errors := Outcome.Errors + LineEnding;
        Outcome.Errors := Outcome.Errors + 'RxDBGrid1: ' + E.Message;
      end;
    end;
  ReportRefreshOutcome(Outcome);
end;

procedure TMainForm.RefreshResults;
var
  Outcome: TCompetitionRefreshOutcome;
begin
  Outcome := TCompetitionRefreshCoordinator.RefreshResults(
    CompetitionDb,
    [ResultsForm.CatDataset1, ResultsForm.CatDataset2,
    ResultsForm.CatDataset3, ResultsForm.CatDataset4,
    ResultsForm.CatDataset5, ResultsForm.CatDataset6,
    ResultsForm.ResultDataset]);
  ReportRefreshOutcome(Outcome);
end;

procedure TMainForm.LoadCompetitionConfigModel;
var
  i: integer;
  messageText: string;
  Configuration: TCompetitionConfiguration;
begin
  if MainForm.CompetitionDb.Connection.Connected then
    try
      Configuration := TCompetitionLifecycleService.LoadConfiguration(
        MainForm.CompetitionDb, stages.Count, VISIBLECAT);
      raceName := Configuration.RaceName;
      for i := 1 to VISIBLECAT do
        cat[i] := Configuration.Categories[i - 1];
      for i := 1 to stages.Count do
      begin
        stages[i].isActive := Configuration.StageActive[i - 1];
        stages[i].Name := Configuration.StageNames[i - 1];
      end;
      astage := IntToStr(Configuration.ActiveStageIndex);
    except
      On E: Exception do
      begin
        messageText := Format(rsCompetitionSettingsLoadError, [E.Message]);
        AppLog(messageText, allError, alvStatus, alsDatabase);
        AskMessageDlg(messageText, mtError, [mbOK], 0);
      end;
    end;

  for i := 1 to stages.Count do
    if stages[i].Name = '' then
    begin
      stages[i].Name := Format(rsSUFormat, [i]);
    end;
  stages.EnsureActiveStage;
end;

procedure TMainForm.ApplyCompetitionConfigToUi(
  const APreferredStageIndex: integer);
var
  activeStageCount, firstActiveStageIndex, i, preferredStageIndex: integer;
  iStr: string;
  performanceTrace: TPerformanceTrace;
begin
  activeStageCount := stages.ActiveStagesCount;
  performanceTrace := TPerformanceTrace.Create(
    'ui.competition_config.apply', alsApplication,
    'stage_count=' + IntToStr(stages.Count) +
    ' active_stage_count=' + IntToStr(activeStageCount) +
    ' preferred_stage_index=' + IntToStr(APreferredStageIndex));
  Screen.Cursor := crHourGlass;
  try
    try
      // Модель этапов, основная таблица и представления результатов всегда
      // перестраиваются до одинакового количества СУ перед применением настроек.
      for i := 1 to stages.Count do
        MainForm.ConfigureStageResult(i, stages[i].Name, stages[i].isActive);
      performanceTrace.Step('stage_result_views.configure',
        'stage_count=' + IntToStr(stages.Count));

      MainForm.BeginMainStageColumnsUpdate;
      try
        for i := 1 to stages.Count do
          MainForm.ConfigureMainStage(i, stages[i].Name, stages[i].isActive);
        performanceTrace.Step('main_grid_columns.configure',
          'column_count=' + IntToStr(stages.Count * 7));

        // Настройка для работы с одним этапом.
        if activeStageCount = 1 then
        begin
          firstActiveStageIndex := stages.FirstActiveIndex;
          iStr := IntToStr(firstActiveStageIndex);
          MainForm.SheetStageSum.TabVisible := False;
          MainForm.StageResultView(firstActiveStageIndex).Sheet.Caption :=
            rsTotal;
          MainForm.GridResultStageSum.ColumnByFieldName(
            'result' + iStr).Visible := False;
          MainForm.ConfigureMainSingleStage(firstActiveStageIndex,
            showStageNameForSingleStage);
        end
        else
          MainForm.SheetStageSum.TabVisible := True;

        MainForm.RxDBGrid1.ColumnByFieldName('sumresult').Visible := True;
        MainForm.RxDBGrid1.ColumnByFieldName('sumdiffleader').Visible := True;
      finally
        MainForm.EndMainStageColumnsUpdate;
      end;
      performanceTrace.Step('single_stage_layout.configure',
        'single_stage=' + LowerCase(BoolToStr(activeStageCount = 1, True)));

      preferredStageIndex := APreferredStageIndex;
      if preferredStageIndex = 0 then
        preferredStageIndex := MainForm.CurrentStageIndex;
      MainForm.RebuildCurrentStageSelector(preferredStageIndex);
      performanceTrace.Step('current_stage_selector.rebuild',
        'selected_stage_index=' + IntToStr(MainForm.CurrentStageIndex));

      // Перестраиваем таблицу после показа или скрытия выбора текущего СУ.
      MainForm.RxDBGridCorrection.Parent.ReAlign;
      performanceTrace.Step('correction_panel.realign');

      // Если активных СУ больше одного, показываем число пройденных СУ.
      MainForm.GridResultStageTotal.ColumnByFieldName('sumstages').Visible :=
        activeStageCount > 1;
      performanceTrace.Step('through_result_columns.configure');
      performanceTrace.Finish('ok',
        'selected_stage_index=' + IntToStr(MainForm.CurrentStageIndex));
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        raise;
      end;
    end;

  finally
    Screen.Cursor := crDefault;
    performanceTrace.Free;
  end;
end;

procedure TMainForm.RebuildCompetitionStageConfiguration(const AStageCount,
  APreferredCurrentStageIndex: integer; const ARefreshQueries: boolean);
var
  currentParticipantId, resultsStageIndex: integer;
  restoreCurrentParticipant: boolean;
  performanceTrace: TPerformanceTrace;
begin
  if not IsValidStageCount(AStageCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      rsStageCountRangeError,
      [IntToStr(AStageCount), MIN_STAGE_COUNT, MAX_SUPPORTED_STAGE_COUNT]);

  performanceTrace := TPerformanceTrace.Create('stages.rebuild',
    alsApplication, 'from_stage_count=' + IntToStr(stages.Count) +
    ' to_stage_count=' + IntToStr(AStageCount));
  try
    try
      restoreCurrentParticipant := MainForm.MainDataset1.Active and
        TMainSql.TryGetCurrentId(MainForm.MainDataset1, currentParticipantId);

      // Persistent fields can only be rebuilt while the main dataset is closed.
      // Other affected queries are closed by their typed Configure methods.
      MainForm.MainDataset1.Close;
      performanceTrace.Step('main_query.close');
      stages.Resize(AStageCount);
      StoredStageCount := AStageCount;
      LoadCompetitionConfigModel;
      performanceTrace.Step('config.load');
      MainForm.ConfigureMainStageFields(stages.ActiveIndices);
      performanceTrace.Step('stage_fields.configure',
        'active_stage_count=' + IntToStr(stages.ActiveStagesCount));
      MainForm.ConfigureMainStageColumns(AStageCount);
      performanceTrace.Step('stage_columns.configure');
      MainForm.ConfigureStageResultUi(AStageCount, stages.ActiveIndices);
      performanceTrace.Step('stage_result_ui.configure');
      ApplyCompetitionConfigToUi(APreferredCurrentStageIndex);
      performanceTrace.Step('config.apply');

      resultsStageIndex := stages.NormalizeActiveIndex(StrToIntDef(astage, 0));
      astage := IntToStr(resultsStageIndex);

      LoadIniCategory;
      performanceTrace.Step('categories.load');
      if ARefreshQueries then
      begin
        RefreshAll;
        performanceTrace.Step('queries.refresh');
        if restoreCurrentParticipant then
          MainForm.MainDataset1.Locate('id', currentParticipantId, []);
      end;
      performanceTrace.Finish('ok',
        'stage_count=' + IntToStr(AStageCount));
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E,
          'stage_count=' + IntToStr(AStageCount));
        raise;
      end;
    end;
  finally
    performanceTrace.Free;
  end;
end;

procedure TMainForm.ReconfigureCompetitionStageActivity(
  const APreferredCurrentStageIndex: integer; const ARefreshQueries: boolean);
var
  currentParticipantId, resultsStageIndex: integer;
  restoreCurrentParticipant: boolean;
  performanceTrace: TPerformanceTrace;
begin
  performanceTrace := TPerformanceTrace.Create('stages.activity_reconfigure',
    alsApplication, 'stage_count=' + IntToStr(stages.Count) +
    ' active_stage_count=' + IntToStr(stages.ActiveStagesCount));
  try
    try
      restoreCurrentParticipant := MainForm.MainDataset1.Active and
        TMainSql.TryGetCurrentId(MainForm.MainDataset1, currentParticipantId);
      MainForm.MainDataset1.Close;
      performanceTrace.Step('main_query.close');
      MainForm.ConfigureMainStageFields(stages.ActiveIndices);
      performanceTrace.Step('stage_fields.configure',
        'active_stage_count=' + IntToStr(stages.ActiveStagesCount));
      MainForm.ConfigureStageResultSum(stages.ActiveIndices);
      performanceTrace.Step('stage_sum_query.configure');
      ApplyCompetitionConfigToUi(APreferredCurrentStageIndex);
      performanceTrace.Step('config.apply');

      resultsStageIndex := stages.NormalizeActiveIndex(StrToIntDef(astage, 0));
      astage := IntToStr(resultsStageIndex);
      if ARefreshQueries then
      begin
        RefreshAll;
        performanceTrace.Step('queries.refresh');
        if restoreCurrentParticipant then
          MainForm.MainDataset1.Locate('id', currentParticipantId, []);
      end;
      performanceTrace.Finish('ok');
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        raise;
      end;
    end;
  finally
    performanceTrace.Free;
  end;
end;

procedure TMainForm.LoadIniCategory(const AConfigureQueries: boolean);
var
  c: TComponent;
  i, stageIndex: integer;
begin
  stageIndex := stages.NormalizeActiveIndex(StrToIntDef(astage, 0));
  if stageIndex = 0 then
    Exit;
  astage := IntToStr(stageIndex);
  for i := 1 to VISIBLECAT do
  begin
    c := ResultsForm.FindComponent('GroupBox' + IntToStr(i));
    TGroupBox(c).Caption := cat[i];
    if AConfigureQueries then
    begin
      c := ResultsForm.FindComponent('CatDataset' + IntToStr(i));
      TDatasetSql.ConfigureCategoryStageResults(TSQLQuery(c), stageIndex,
        cat[i], stages.Count);
    end;
  end;
  if AConfigureQueries then
    TDatasetSql.ConfigureLatestStageResults(ResultsForm.ResultDataset,
      stageIndex, stages.Count);
  ResultsForm.GroupBoxResults.Caption :=
    rsCurrentResults + ': ' + stages[stageIndex].Name;
end;

procedure TMainForm.SetfName(const AFileName: string);
begin
  if AFileName <> '' then
    HistoryFiles1.UpdateList(AFileName);
  fName := AFileName;
  if AFileName = '' then
    Caption := NAME_VERSION
  else
    Caption := NAME_VERSION + ' ' + AFileName;
end;

function CreateCompetitionMigrationBackup: boolean;
begin
  Result := MainForm.BackupBD(alvNone, cbrBeforeMigration);
end;

function TMainForm.PrepareCompetitionSchema(
  const AExistingFile: boolean): integer;
var
  databaseFileName: string;
  MessageText: string;
  Preparation: TCompetitionPreparation;
begin
  databaseFileName := CompetitionDb.Connection.DatabaseName;
  try
    Preparation := TCompetitionLifecycleService.OpenCompetition(
      CompetitionDb, AExistingFile, DEFAULT_STAGE_COUNT,
      [rsCat1, rsCat2, rsCat3, rsCat4, rsCat5],
      ExtractFileNameOnly(databaseFileName), @CreateCompetitionMigrationBackup);
    if Preparation.Migrated then
      AppLog(Format(rsSchemaMigrationCompleted,
        [databaseFileName, Preparation.SchemaVersion,
        Preparation.RequiredStageCount,
        Preparation.PhysicalStageCount]), allInfo, alvStatus, alsDatabase);
    if Preparation.Created then
      AppLog(Format(rsNewFileCreated, [databaseFileName]), allInfo, alvStatus,
        alsDatabase);
    Result := Preparation.RequiredStageCount;
  except
    on E: Exception do
    begin
      if not AExistingFile then
        raise;
      MessageText := Format(rsSchemaMigrationError,
        [databaseFileName, E.Message]);
      AppLog(MessageText, allError, alvStatus, alsDatabase);
      raise ECompetitionSchemaError.Create(MessageText);
    end;
  end;
end;

function TMainForm.SelectedMainGridFieldName: string;
begin
  Result := '';
  if Assigned(RxDBGrid1.SelectedColumn) then
    Result := RxDBGrid1.SelectedColumn.FieldName;
end;

function IsOverallResultFieldName(const AFieldName: string): boolean;
begin
  Result := SameText(AFieldName, 'sumresult') or
    SameText(AFieldName, 'sumdiffleader') or
    SameText(AFieldName, 'status');
end;

procedure TMainForm.SetSelectedParticipantStatus(
  const AStatus: TParticipantStatus);
var
  n: string;
begin
  if CompetitionHasParticipants and
    TMainSql.TryGetCurrentNumber(MainDataset1, n) then
    SetParticipantStatus(GetSelectedStage, AStatus, n);
end;

procedure TMainForm.SetDNS;
begin
  SetSelectedParticipantStatus(psDNS);
end;

procedure TMainForm.SetDNF;
begin
  SetSelectedParticipantStatus(psDNF);
end;

procedure TMainForm.SetDSQ;
begin
  SetSelectedParticipantStatus(psDSQ);
end;

function LogValueOrEmpty(const AValue: string): string;
begin
  if AValue = '' then
    Result := rsEmptyLogValue
  else
    Result := AValue;
end;

function StatusLogValue(const AValue: string): string;
var
  status: TParticipantStatus;
begin
  Result := LogValueOrEmpty(AValue);
  if TryParticipantStatusFromDbValue(AValue, status) and
    (status <> psNone) then
    Result := ParticipantStatusToToken(status);
end;

procedure TMainForm.SetParticipantStatus(const AStageIndex: integer;
  const AStatus: TParticipantStatus; const AParticipantNumber: string);
//устанавливает статус в БД для номера "n" на СУ "i"
var
  d, logstatus, oldStatus: string;
  Outcome: TParticipantStatusOutcome;
begin
  try
    if AStatus = psNone then
      raise EArgumentException.Create('A participant status is required.');

    if AStatus <> psDSQ then
    begin
      if not stages.IsActiveIndex(AStageIndex) then
        raise EArgumentOutOfRangeException.CreateFmt(
          'Stage %d is not an active competition stage.', [AStageIndex]);
      if AStatus = psDNS then
      begin
        logstatus := rsDidNotStart;
      end
      else
      begin
        logstatus := rsDidNotFinish;
      end;
      if stages.ActiveStagesCount = 1 then
      begin
        d := Format(rsConfirmParticipantStatus,
          [AParticipantNumber, logstatus]);
      end
      else
      begin
        if Format(rsSUFormat, [AStageIndex]) = stages[AStageIndex].Name then
        begin
          d := Format(rsConfirmParticipantStageStatus,
            [AParticipantNumber, logstatus, AStageIndex]);
        end
        else
        begin
          d := Format(rsConfirmParticipantNamedStageStatus,
            [AParticipantNumber, logstatus, AStageIndex,
            stages[AStageIndex].Name]);
        end;
      end;
      if AskMessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
      begin
        Outcome := TParticipantStatusService.SetStatus(
          CompetitionDb, stages, StrToIntDef(AParticipantNumber, 0),
          AStageIndex, AStatus);
        RefreshAll;
        if Outcome.Changed then
        begin
          oldStatus := ParticipantStatusToDbValue(Outcome.PreviousStatus);
          AppLog(Format(rsParticipantStageValueChanged,
            [AParticipantNumber, rsStatus, AStageIndex,
            StatusLogValue(oldStatus),
            ParticipantStatusToToken(AStatus)]), allInfo, alvNone,
            alsResults);
        end;
      end;
    end
    else
    begin
      if AskMessageDlg(Format(rsReallyDisqualifyNumber,
        [AParticipantNumber]), mtWarning,
        [mbYes, mbNo], 0) = mrYes then
      begin
        Outcome := TParticipantStatusService.SetStatus(
          CompetitionDb, stages, StrToIntDef(AParticipantNumber, 0),
          AStageIndex, AStatus);
        RefreshAll;
        if Outcome.Changed then
        begin
          oldStatus := ParticipantStatusToDbValue(Outcome.PreviousStatus);
          AppLog(Format(rsParticipantFieldValueChanged,
            [AParticipantNumber, rsStatus, StatusLogValue(oldStatus),
            ParticipantStatusToToken(psDSQ)]), allInfo, alvNone,
            alsResults);
        end;
      end;
    end;
  except
    On E: Exception do
    begin
      d := Format(rsParticipantStageSaveError,
        [AParticipantNumber, AStageIndex, E.Message]);
      AppLog(d, allError, alvStatus, alsResults);
      AskMessageDlg(d, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.RecalculateAllStatuses;
var
  Outcome: TStatusRecalculationOutcome;
  messageText: string;
begin
  if not MainForm.SQLite3Connection1.Connected then
    Exit;
  try
    Outcome := TParticipantStatusService.RecalculateAll(
      CompetitionDb, stages);
    AppLog(Format(rsParticipantStatusesRecalculated,
      [Outcome.ProcessedCount]),
      allDebug, alvDetails, alsResults);
  except
    on E: Exception do
    begin
      messageText := E.Message;
      AppLog(messageText, allError, alvStatus, alsResults);
      AskMessageDlg(messageText, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.ClearStatus;
var
  n, d, l, selectedFieldName: string;
  i: integer = 1;
begin
  try
    if CompetitionHasParticipants then
    begin
      selectedFieldName := SelectedMainGridFieldName;
      if not TMainSql.TryGetCurrentNumber(MainForm.MainDataset1, n) then
        Exit;
      if stages.ActiveStagesCount = 1 then
      begin
        i := stages.FirstActiveIndex;
        d := Format(rsClearAllStatus, [n]);
        l := Format(rsClearAllStatusLog, [n]);
        if AskMessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          TParticipantStatusService.ClearStatus(MainForm.CompetitionDb,
            stages, StrToIntDef(n, 0), i, pcscStageAndGlobal);
          RefreshAll;
          AppLog(l, allInfo, alvNone, alsResults);
        end;
      end
      else
      // выделение в общих результатах
      if IsOverallResultFieldName(selectedFieldName) then
      begin
        d := Format(rsClearDSQ, [n]);
        l := Format(rsClearDSQLog, [n]);
        if AskMessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          TParticipantStatusService.ClearStatus(MainForm.CompetitionDb,
            stages, StrToIntDef(n, 0), i, pcscGlobalOnly);
          RefreshAll;
          AppLog(l, allInfo, alvNone, alsResults);
        end;
      end
      else
      begin
        i := GetSelectedStage;
        if Format(rsSUFormat, [i]) = stages[i].Name then
        begin
          d := Format(rsClearStatus, [n, i]);
          l := Format(rsClearStatusLog, [n, i]);
        end
        else
        begin
          d := Format(rsClearNamedStageStatus, [n, i, stages[i].Name]);
          l := Format(rsClearNamedStageStatusLog, [n, i, stages[i].Name]);
        end;
        if AskMessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          TParticipantStatusService.ClearStatus(MainForm.CompetitionDb,
            stages, StrToIntDef(n, 0), i, pcscStageOnly);
          RefreshAll;
          AppLog(l, allInfo, alvNone, alsResults);
        end;
      end;
    end;
  except
    On E: Exception do
    begin
      TMainSql.TryGetCurrentNumber(MainForm.MainDataset1, n);
      i := GetSelectedStage;
      l := Format(rsParticipantStageSaveError, [n, i, E.Message]);
      AppLog(l, allError, alvStatus, alsResults);
      AskMessageDlg(l, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.InitDB(fileName: string);
var
  candidateFileName: string;
  messageText: string;
  ExistingFile: boolean;
  performanceTrace: TPerformanceTrace;
begin
  candidateFileName := ExpandFileName(fileName);
  ExistingFile := FileExists(candidateFileName);
  performanceTrace := TPerformanceTrace.Create('competition.open',
    alsDatabase, 'existing=' + LowerCase(BoolToStr(ExistingFile, True)));
  SetfName('');
  FreeStartMarkService;
  FreeFinishMarkService;
  CompetitionDb.SetDatabaseFile(candidateFileName);
  try
    try
      Screen.Cursor := crSQLWait;
      try
        try
          StoredStageCount := PrepareCompetitionSchema(ExistingFile);
          performanceTrace.Step('schema.prepare',
            'stage_count=' + IntToStr(StoredStageCount));
        except
          on E: Exception do
          begin
            if ExistingFile then
              raise;
            performanceTrace.FinishError(E, 'step=schema.prepare');
            messageText := Format(rsCompetitionFileCreateError,
              [candidateFileName, E.Message]);
            AppLog(messageText, allError, alvStatus, alsDatabase);
            AskMessageDlg(messageText, mtError, [mbOK], 0);
            TCompetitionLifecycleService.Close(MainForm.CompetitionDb);
            // Если файл не создан, не пытаемся его открыть
            Exit;
          end;
        end;
      finally
        Screen.Cursor := crDefault;
      end;

      stages.Resize(StoredStageCount);
      LoadCompetitionConfigModel;
      CreateStartMarkService;
      CreateFinishMarkService;
      performanceTrace.Step('config.load');
      MainForm.ConfigureMainStageFields(stages.ActiveIndices);
      performanceTrace.Step('stage_fields.configure',
        'active_stage_count=' + IntToStr(stages.ActiveStagesCount));

      MainForm.ConfigureMainStageColumns(StoredStageCount);
      performanceTrace.Step('stage_columns.configure');
      MainForm.ConfigureStageResultUi(StoredStageCount, stages.ActiveIndices);
      performanceTrace.Step('stage_result_ui.configure');
      ApplyCompetitionConfigToUi;
      performanceTrace.Step('config.apply');
      LoadIniCategory;
      performanceTrace.Step('categories.load');
      RefreshAll;
      performanceTrace.Step('queries.refresh');
      performanceTrace.Finish('ok',
        'stage_count=' + IntToStr(StoredStageCount));
      AppLog(Format(rsDBFileOpen, [candidateFileName]), allInfo, alvStatus,
        alsDatabase);
      SetfName(candidateFileName);
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        FreeStartMarkService;
        FreeFinishMarkService;
        TCompetitionLifecycleService.Close(MainForm.CompetitionDb);
        messageText := Format(rsCompetitionFileOpenError,
          [candidateFileName, E.Message]);
        AppLog(messageText, allError, alvStatus, alsDatabase);
        AskMessageDlg(messageText, mtError, [mbOK], 0);
      end;
    end;
  finally
    performanceTrace.Free;
  end;
end;

procedure TMainForm.NotifyFinish(const AResult: TFinishResult);
begin
  if AcLEDPanel.Checked then
    if not Assigned(FLedPanelCoordinator) or
      not FLedPanelCoordinator.EnqueueFinish(AResult, ledpaneladress) then
      AppLog(Format(rsLEDPanelError, [rsLEDPanelInvalidAddress]), allError,
        alvStatus, alsHTTP);
  if AcTelegramBot.Checked then
    if not Assigned(FTelegramCoordinator) or
      not FTelegramCoordinator.EnqueueResult(AResult, telegrambotadress,
        TTelegramRetryPolicy.Create(telegramRetryEnabled,
          telegramRetryCount, telegramRetryDelaySeconds)) then
      AppLog(Format(rsTelegramBotSendingError, [rsHTTPRequestNotStarted]),
        allError, alvStatus, alsTelegram);
end;

procedure TMainForm.LedPanelCompleted(Sender: TObject;
  const ADelivery: TLedPanelDeliveryResult);
begin
  if FClosing then
    Exit;
  AppLog(Format(rsHTTPRequestMetadata,
    ['POST', ADelivery.Outcome.RequestParameterCount]), allDebug,
    alvDetails, alsHTTP);
  if ADelivery.Outcome.ResponseStatusCode <> 0 then
    AppLog(Format(rsHTTPResponseMetadata,
      [ADelivery.Outcome.ResponseStatusCode,
      ADelivery.Outcome.ResponseStatusText,
      ADelivery.Outcome.ResponseHeaderCount,
      ADelivery.Outcome.ResponseSize]), allDebug, alvDetails, alsHTTP);
  if ADelivery.Outcome.Success then
  begin
    if ADelivery.IsTest then
      AppLog(rsLEDPanelTestSucceeded, allInfo, alvStatus, alsHTTP);
  end
  else
    AppLog(Format(rsLEDPanelError,
      [ADelivery.Outcome.SafeErrorMessage]), allError, alvStatus, alsHTTP);
end;

procedure TMainForm.TelegramCompleted(Sender: TObject;
  const ADelivery: TTelegramDeliveryResult);
begin
  if FClosing then
    Exit;
  AppLog(Format(rsHTTPRequestMetadata,
    ['GET', ADelivery.Outcome.RequestParameterCount]), allDebug,
    alvDetails, alsTelegram);
  if ADelivery.Outcome.ResponseStatusCode <> 0 then
    AppLog(Format(rsHTTPResponseMetadata,
      [ADelivery.Outcome.ResponseStatusCode,
      ADelivery.Outcome.ResponseStatusText,
      ADelivery.Outcome.ResponseHeaderCount,
      ADelivery.Outcome.ResponseSize]), allDebug, alvDetails,
      alsTelegram);
  if ADelivery.Outcome.Success then
  begin
    if ADelivery.Item.IsTest then
      AppLog(rsTelegramBotTestSucceeded, allInfo, alvStatus, alsTelegram);
  end
  else
    AppLog(Format(rsTelegramBotSendingError,
      [ADelivery.Outcome.SafeErrorMessage]), allError, alvStatus,
      alsTelegram);
end;

procedure TMainForm.TelegramDropped(Sender: TObject;
  const AItem: TTelegramQueueItemInfo);
begin
  if FClosing then
    Exit;
  AppLog(Format(rsTelegramQueueItemDropped,
    [AItem.ParticipantNumber,
    FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AItem.EnqueuedAt)]),
    allWarning, alvDetails, alsTelegram);
end;

procedure TMainForm.SetFinish;
var
  AppliedAny: boolean;
  CurrentMarkId: int64;
  I: integer;
  Items: TFinishMarkWorkItems;
begin
  if not IsCompetitionDatabaseOpen or not Assigned(FFinishMarkService) or
    not DatasetFinishMarks.Active then
    Exit;
  if (DatasetFinishMarks.State in [dsEdit, dsInsert]) or
    (DatasetFinishMarks.ChangeCount > 0) then
    RxDBGridFinishMarksEditingDone(RxDBGridFinishMarks);

  SetLength(Items, 0);
  CurrentMarkId := 0;
  if not DatasetFinishMarks.IsEmpty then
    CurrentMarkId := DatasetFinishMarks.FieldByName('id').AsLargeInt;
  DatasetFinishMarks.DisableControls;
  try
    DatasetFinishMarks.First;
    while not DatasetFinishMarks.EOF do
    begin
      if not DatasetFinishMarks.FieldByName(
        'participant_number').IsNull and
        (DatasetFinishMarks.FieldByName(
        'participant_number').AsInteger > 0) then
      begin
        SetLength(Items, Length(Items) + 1);
        Items[High(Items)].MarkId :=
          DatasetFinishMarks.FieldByName('id').AsLargeInt;
        Items[High(Items)].ParticipantNumber :=
          DatasetFinishMarks.FieldByName('participant_number').AsInteger;
      end;
      DatasetFinishMarks.Next;
    end;
  finally
    if CurrentMarkId > 0 then
      DatasetFinishMarks.Locate('id', CurrentMarkId, []);
    DatasetFinishMarks.EnableControls;
  end;

  Screen.Cursor := crSQLWait;
  AppliedAny := False;
  try
    for I := 0 to High(Items) do
      if ApplyFinishMark(Items[I].MarkId,
        Items[I].ParticipantNumber) then
        AppliedAny := True;
    if AppliedAny then
      RefreshAll;
  finally
    Screen.Cursor := crDefault;
  end;
end;

function TMainForm.ApplyFinishMark(const AMarkId: int64;
  const AParticipantNumber: integer): boolean;
var
  AppliedAt: TDateTime;
  Failure: TFinishFailure;
  FinishMark: TFinishMark;
  FinishResult: TFinishResult;
  Inspection: TFinishInspection;
  MessageText, StageText: string;
  OverwritePolicy: TFinishOverwritePolicy;
  Request: TFinishRequest;
  StageIndex: integer;
  TrackPolicy: TFinishTrackPolicy;
begin
  Result := False;
  StageText := '';
  try
    if not FFinishMarkService.TryLoad(AMarkId, FinishMark) then
      Exit;
    StageIndex := FinishMark.StageIndex;
    StageText := IntToStr(StageIndex);
    if not stages.IsActiveIndex(StageIndex) then
      Exit;

    Inspection := TFinishService.Inspect(CompetitionDb,
      stages, AParticipantNumber, StageIndex);
    if not Inspection.ParticipantExists then
    begin
      AppLog(Format(rsFinishSkippedParticipantMissing,
        [IntToStr(AParticipantNumber)]), allWarning, alvDetails, alsResults);
      Exit;
    end;

    TrackPolicy := ftpRequireOnTrack;
    if not Inspection.IsOnTrack then
    begin
      if AskMessageDlg(Format(rsDidNotStartSetFinish,
        [AParticipantNumber]), mtWarning, [mbYes, mbNo], 0) <> mrYes then
        Exit;
      TrackPolicy := ftpAllowNotOnTrack;
    end;

    OverwritePolicy := fopRejectExisting;
    if Inspection.HasExistingResult then
    begin
      if AskMessageDlg(Format(rsUpdateFinishTime,
        [AParticipantNumber]), mtWarning, [mbYes, mbNo], 0) <> mrYes then
        Exit;
      OverwritePolicy := fopOverwriteExisting;
    end;

    AppliedAt := Now;
    Request := TFinishRequest.CreateForMark(AMarkId,
      AParticipantNumber, TrackPolicy, OverwritePolicy, AppliedAt);
    if TFinishService.TrySave(CompetitionDb, stages, Request,
      FinishResult, Failure) then
    begin
      AppLog(Format(rsFinishTimeSetForStages,
        [AParticipantNumber, StageText]), allInfo, alvNone, alsResults);
      NotifyFinish(FinishResult);
      Exit(True);
    end;

    if Failure.Kind = ffkParticipantMissing then
      AppLog(Format(rsFinishSkippedParticipantMissing,
        [IntToStr(AParticipantNumber)]), allWarning, alvDetails, alsResults)
    else
    begin
      MessageText := Format(rsParticipantStagesSaveError,
        [IntToStr(AParticipantNumber), StageText, Failure.SafeMessage]);
      AppLog(MessageText, allError, alvStatus, alsResults);
      AskMessageDlg(MessageText, mtError, [mbOK], 0);
    end;
  except
    on E: Exception do
    begin
      MessageText := Format(rsParticipantStagesSaveError,
        [IntToStr(AParticipantNumber), StageText, E.Message]);
      AppLog(MessageText, allError, alvStatus, alsResults);
      AskMessageDlg(MessageText, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.SaveStageCorrection(const StageIndex, Correction,
  ParticipantNumber: integer);
begin
  TParticipantStageService.SaveCorrection(MainForm.CompetitionDb, stages,
    ParticipantNumber, StageIndex, Correction);
  RefreshAll;
end;

procedure TMainForm.UpdateResults;
var
  calculationSucceeded: boolean;
  performanceTrace: TPerformanceTrace;
begin
  Screen.Cursor := crSQLWait;
  calculationSucceeded := False;
  performanceTrace := TPerformanceTrace.Create('results.recalculate',
    alsResults, 'operation=all stage_count=' + IntToStr(stages.Count));
  try
    try
      TResultCalculationService.RecalculateAll(CompetitionDb, stages);
      calculationSucceeded := True;
      performanceTrace.Finish('ok');
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        AppLog(E.Message, allError, alvStatus, alsResults);
        AskMessageDlg(E.Message, mtError, [mbOK], 0);
      end;
    end;
    if calculationSucceeded then
      RefreshAll;
  finally
    performanceTrace.Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure TMainForm.UpdateSumResults;
var
  performanceTrace: TPerformanceTrace;
begin
  performanceTrace := TPerformanceTrace.Create('results.recalculate',
    alsResults, 'operation=sum_results stage_count=' +
    IntToStr(stages.Count));
  try
    try
      TResultCalculationService.RecalculateSumResults(CompetitionDb,
        stages);
      performanceTrace.Finish('ok');
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        AppLog(E.Message, allError, alvStatus, alsResults);
        AskMessageDlg(E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    performanceTrace.Free;
  end;
end;

procedure TMainForm.ClearResults(silent: boolean);
begin
  if silent or (AskMessageDlg(rsClearResults, mtWarning, [mbYes, mbNo], 0) = mrYes) then
    if not BackupBD(alvStatus, cbrBeforeClear) then
    begin
      if AskMessageDlg(Format(rsClearResultsWithoutBackup, [sLineBreak]),
        mtWarning, [mbYes, mbNo], 0) = mrNo then
        Exit;
    end;
  begin
    try
      TResultCalculationService.ClearResults(MainForm.CompetitionDb,
        stages.Count);
      RefreshAll;
      AppLog(rsResultsCleared, allInfo, alvStatus, alsResults);
    except
      On E: Exception do
      begin
        AppLog(Format(rsResultsClearError, [E.Message]), allError, alvStatus,
          alsResults);
        AskMessageDlg(Format(rsResultsClearError, [E.Message]), mtError,
          [mbOK], 0);
      end;
    end;
  end;
end;

procedure TMainForm.SetDNSFromCorrection;
var
  n: string;
  stageIndex: integer;
begin
  if IsCompetitionDatabaseOpen then
  begin
    stageIndex := MainForm.CurrentStageIndex;
    if not stages.IsActiveIndex(stageIndex) then
      Exit;
    if not MainForm.CorrectionDataset.IsEmpty then
      if TMainSql.TryGetCurrentNumber(MainForm.CorrectionDataset, n) then
        SetParticipantStatus(stageIndex, psDNS, n);
  end;
end;

procedure TMainForm.SetStarttimeFromPopup;
var
  t: TDateTime;
  n, startTimeText, messageText: string;
  st: integer;
  Outcome: TParticipantStageValueOutcome;
begin
  if CompetitionHasParticipants and
    TMainSql.TryGetCurrentNumber(MainForm.MainDataset1, n) then
  begin
    st := GetSelectedStage;
    t := InputDateTime(rsTimeToStart,
      Format(rsEnterStartTime, [n, stages[st].Name]));
    if t > 0 then
    begin
      startTimeText := TimeToStr(t);
      try
        Outcome := TParticipantStageService.SaveStartTime(
          MainForm.CompetitionDb, stages, StrToIntDef(n, 0), st,
          startTimeText);
        RefreshAll;
        if Outcome.Changed then
          AppLog(Format(rsParticipantStageValueChanged,
            [n, rsStarttime, st, LogValueOrEmpty(Outcome.PreviousValue),
            Outcome.CurrentValue]), allInfo, alvNone, alsResults);
      except
        on E: Exception do
        begin
          messageText := Format(rsParticipantStageSaveError,
            [n, st, E.Message]);
          AppLog(messageText, allError, alvStatus, alsResults);
          AskMessageDlg(messageText, mtError, [mbOK], 0);
        end;
      end;
    end;
  end;
end;

procedure TMainForm.SetDNFFromOnTrace;
var
  n: string;
  stageIndex: integer;
begin
  if not MainForm.StatDataset2.IsEmpty then
  begin
    stageIndex := MainForm.CurrentStageIndex;
    if not stages.IsActiveIndex(stageIndex) then
      Exit;
    if TMainSql.TryGetCurrentNumber(MainForm.StatDataset2, n) then
      SetParticipantStatus(stageIndex, psDNF, n);
  end;
end;

function ConfirmUnknownImportEncoding: boolean;
begin
  Result := AskMessageDlg(rsUnknownFileEncoding, mtWarning,
    [mbYes, mbNo], 0) = mrYes;
end;

function ConfirmParticipantCategoryImport: boolean;
begin
  Result := AskMessageDlg(rsSetCategoryName, mtConfirmation,
    [mbYes, mbNo], 0) = mrYes;
end;

function ConfirmUnknownResultParticipant(
  const AParticipantNumber: integer): boolean;
begin
  Result := AskMessageDlg(Format(rsAddUnknownResultParticipant,
    [AParticipantNumber]), mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

function ConfirmResultsImportWithoutBackup: boolean;
begin
  Result := AskMessageDlg(Format(rsContinueLoadingResultsWithoutBackup,
    [sLineBreak]), mtWarning, [mbYes, mbNo], 0) <> mrNo;
end;

procedure TMainForm.LoadParticipantsList(FileName: string);
var
  previousCurrentStageIndex: integer;
  canonicalFileName, messageText: string;
  importPlan: TParticipantsImportPlan;
  importOutcome: TParticipantsImportOutcome;
  importRequest: TParticipantsImportRequest;
  requiresExpansion: boolean;
  performanceTrace: TPerformanceTrace;

  procedure ReportLoadError(const APrefix, ADetails: string);
  begin
    messageText := Format(rsParticipantsImportError,
      [canonicalFileName, APrefix + ADetails]);
    AppLog(messageText, allError, alvStatus, alsImport);
    AskMessageDlg(messageText, mtError, [mbOK], 0);
  end;

begin
  if not IsCompetitionDatabaseOpen then
    Exit;

  Screen.Cursor := crSQLWait;
  importPlan := nil;
  canonicalFileName := ExpandFileName(FileName);
  previousCurrentStageIndex := MainForm.CurrentStageIndex;
  performanceTrace := TPerformanceTrace.Create('csv.participants.import',
    alsImport, 'stage_count=' + IntToStr(stages.Count));
  try
    try
      AppLog(Format(rsOpenStartListFile, [canonicalFileName]), allDebug,
        alvDetails, alsImport);
      importPlan := TCompetitionImportService.PrepareParticipantsFile(
        canonicalFileName, MAX_SUPPORTED_STAGE_COUNT);
      if SameText(importPlan.EncodingName, 'Unknown') and
        (not ConfirmUnknownImportEncoding) then
      begin
        performanceTrace.Finish('cancelled', 'step=encoding.confirm');
        Exit;
      end;

      AppLog(Format(rsCodepage, [importPlan.EncodingName]), allDebug,
        alvDetails, alsImport);
      if SameText(importPlan.EncodingName, 'Unknown') then
        AppLog(rsUnknownFileEncodingContinued, allWarning, alvDetails,
          alsImport);
      performanceTrace.Step('parse',
        'row_count=' + IntToStr(importPlan.RowCount) +
        ' detected_stage_count=' +
        IntToStr(importPlan.DetectedStageCount));
      AppLog(Format(rsDetectedParticipantStages,
        [importPlan.DetectedStageNamesText]), allDebug, alvDetails, alsImport);

      importRequest := Default(TParticipantsImportRequest);
      importRequest.StoredActiveStageIndex := StrToIntDef(astage, 1);
      importRequest.CategoryLimit := VISIBLECAT;
      importRequest.ImportCategories := ConfirmParticipantCategoryImport;
      requiresExpansion :=
        TCompetitionImportService.RequiresStageCapacityExpansion(importPlan,
          MainForm.CompetitionDb, stages);
      importRequest.ExpansionBackupCreated := not requiresExpansion;
      if requiresExpansion then
        importRequest.ExpansionBackupCreated := BackupBD(alvStatus,
          cbrBeforeStageExpansion);
      if requiresExpansion and
        (not importRequest.ExpansionBackupCreated) then
        raise ECompetitionImportBackupError.Create(Format(
          rsStageCapacityExpansionBackupError, [fName]));

      importOutcome := TCompetitionImportService.ApplyParticipants(importPlan,
        MainForm.CompetitionDb, stages, importRequest);
      performanceTrace.Step('database_write',
        'row_count=' + IntToStr(importOutcome.RowCount) +
        ' target_stage_count=' + IntToStr(importOutcome.TargetStageCount));
      performanceTrace.Step('category_prompt.wait',
        'accepted=' + LowerCase(BoolToStr(
        importOutcome.CategoryNamesAccepted, True)));
      if importOutcome.CategoryNamesAccepted then
        performanceTrace.Step('categories.save',
          'category_count=' +
          IntToStr(importOutcome.ImportedCategoryCount));

      if importOutcome.TargetStageCount <>
        importOutcome.PreviousStageCount then
      begin
        RebuildCompetitionStageConfiguration(importOutcome.TargetStageCount,
          previousCurrentStageIndex);
        performanceTrace.Step('stages.rebuild',
          'stage_count=' + IntToStr(importOutcome.TargetStageCount));
      end
      else
      begin
        LoadCompetitionConfigModel;
        performanceTrace.Step('config.load');
        if importOutcome.StageDefinitionsApplied then
        begin
          ReconfigureCompetitionStageActivity(previousCurrentStageIndex);
          performanceTrace.Step('stages.activity_reconfigure',
            'active_stage_count=' + IntToStr(stages.ActiveStagesCount));
        end
        else
        begin
          ApplyCompetitionConfigToUi;
          performanceTrace.Step('config.apply',
            'active_stage_count=' + IntToStr(stages.ActiveStagesCount));
        end;
        LoadIniCategory;
        performanceTrace.Step('categories.load');
        if not importOutcome.StageDefinitionsApplied then
        begin
          RefreshAll;
          performanceTrace.Step('queries.refresh');
        end;
      end;

      if importOutcome.TargetStageCount <>
        importOutcome.PreviousStageCount then
        AppLog(Format(rsParticipantStageCountExpanded,
          [importOutcome.PreviousStageCount,
          importOutcome.TargetStageCount]), allInfo, alvStatus, alsImport);
      if importOutcome.StageDefinitionsApplied then
        AppLog(Format(rsParticipantStagesApplied,
          [importPlan.DetectedStageNamesText,
          importOutcome.DeactivatedStageCount]), allInfo, alvStatus,
          alsImport);
      AppLog(Format(rsParticipantsImported,
        [importOutcome.RowCount, canonicalFileName]), allInfo, alvStatus,
        alsImport);
      performanceTrace.Finish('ok',
        'row_count=' + IntToStr(importOutcome.RowCount) +
        ' stage_count=' + IntToStr(importOutcome.TargetStageCount));
    except
      on E: ECompetitionImportValidationError do
      begin
        performanceTrace.FinishError(E);
        ReportLoadError(rsLoadParticipantsListError, E.Message);
      end;
      on E: ECompetitionImportBackupError do
      begin
        performanceTrace.FinishError(E, 'step=backup');
        ReportLoadError(rsWriteParticipantsDatabaseError, E.Message);
      end;
      on E: EDatabaseError do
      begin
        performanceTrace.FinishError(E);
        ReportLoadError(rsWriteParticipantsDatabaseError, E.Message);
      end;
      on E: EStreamError do
      begin
        performanceTrace.FinishError(E);
        ReportLoadError(rsLoadParticipantsListError, E.Message);
      end;
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        ReportLoadError(rsLoadParticipantsListError, E.Message);
      end;
    end;
  finally
    importPlan.Free;
    performanceTrace.Free;
    Screen.Cursor := crDefault;
  end;
end;
function TMainForm.InputComboSelectStage(const ACaption, APrompt: string): integer;
var
  strlst: TStringList;
  activeStageIndexes: array of integer;
  selectedStageIndex, i, selectedIndex: integer;
  selectedText: string;
  k: integer = -1;
begin
  if TryHandleStageSelection(ACaption, APrompt, Result) then
  begin
    if (Result > 0) and (not stages.IsActiveIndex(Result)) then
      Result := -1;
    Exit;
  end;

  Result := -1;
  strlst := TStringList.Create;
  try
    activeStageIndexes := nil;
    selectedStageIndex := stages.NormalizeActiveIndex(
      MainForm.CurrentStageIndex);

    // Если активных СУ больше одного, то
    // получаем список активных СУ и выводим инпуткомбо
    // В противном случае сразу выбираем активный СУ
    if stages.ActiveStagesCount > 1 then
    begin
      for i := 1 to stages.Count do
      begin
        if stages[i].isActive then
        begin
          strlst.add(stages[i].Name);
          SetLength(activeStageIndexes, Length(activeStageIndexes) + 1);
          activeStageIndexes[High(activeStageIndexes)] := i;
          if selectedStageIndex = i then
            k := strlst.Count - 1;
        end;
      end;
      if MyDoInputCombo(ACaption, APrompt, strlst, k, False,
        selectedIndex, selectedText) = mrOk then
        if (selectedIndex >= 0) and
          (selectedIndex < Length(activeStageIndexes)) then
          Result := activeStageIndexes[selectedIndex];
    end
    else if stages.ActiveStagesCount = 1 then
      Result := selectedStageIndex;
  finally
    strlst.Free;
  end;
end;

procedure TMainForm.LoadStageResults(FileName: string);
var
  acceptedCount, unknownIndex: integer;
  canonicalFileName, messageText: string;
  importPlan: TResultsImportPlan;
  importInspection: TResultsImportInspection;
  importOutcome: TResultsImportOutcome;
  importRequest: TResultsImportRequest;
  performanceTrace: TPerformanceTrace;

  procedure ReportLoadError(const APrefix, ADetails: string);
  begin
    messageText := Format(rsResultsImportError,
      [canonicalFileName, APrefix + ADetails]);
    AppLog(messageText, allError, alvStatus, alsImport);
    AskMessageDlg(messageText, mtError, [mbOK], 0);
  end;

begin
  if not IsCompetitionDatabaseOpen then
    Exit;

  Screen.Cursor := crSQLWait;
  importPlan := nil;
  canonicalFileName := ExpandFileName(FileName);
  performanceTrace := TPerformanceTrace.Create('csv.results.import',
    alsImport, 'stage_count=' + IntToStr(stages.Count));
  try
    try
      AppLog(Format(rsOpenResultsFile, [canonicalFileName]), allDebug,
        alvDetails, alsImport);
      importPlan := TCompetitionImportService.PrepareResultsFile(
        canonicalFileName);
      if SameText(importPlan.EncodingName, 'Unknown') and
        (not ConfirmUnknownImportEncoding) then
      begin
        performanceTrace.Finish('cancelled', 'step=encoding.confirm');
        Exit;
      end;

      AppLog(Format(rsCodepage, [importPlan.EncodingName]), allDebug,
        alvDetails, alsImport);
      if SameText(importPlan.EncodingName, 'Unknown') then
        AppLog(rsUnknownFileEncodingContinued, allWarning, alvDetails,
          alsImport);
      AppLog(Format(rsResultsImportFormat,
        [importPlan.FormatColumnCount]), allDebug, alvDetails, alsImport);
      performanceTrace.Step('parse',
        'row_count=' + IntToStr(importPlan.RowCount) +
        ' column_count=' + IntToStr(importPlan.FormatColumnCount));

      importRequest := Default(TResultsImportRequest);
      importRequest.StageIndex := InputComboSelectStage(
        rsImportFinish, rsSetTimeToSU);
      if not stages.IsActiveIndex(importRequest.StageIndex) then
      begin
        performanceTrace.Finish('cancelled', 'step=stage.select');
        Exit;
      end;
      importInspection :=
        TCompetitionImportService.InspectResultsParticipants(importPlan,
          MainForm.CompetitionDb);
      for unknownIndex := Low(importInspection.UnknownParticipantNumbers) to
        High(importInspection.UnknownParticipantNumbers) do
        if ConfirmUnknownResultParticipant(
          importInspection.UnknownParticipantNumbers[unknownIndex]) then
        begin
          acceptedCount := Length(
            importRequest.AcceptedUnknownParticipantNumbers);
          SetLength(importRequest.AcceptedUnknownParticipantNumbers,
            acceptedCount + 1);
          importRequest.AcceptedUnknownParticipantNumbers[acceptedCount] :=
            importInspection.UnknownParticipantNumbers[unknownIndex];
        end;
      acceptedCount := importInspection.KnownParticipantCount +
        Length(importRequest.AcceptedUnknownParticipantNumbers);
      if acceptedCount = 0 then
      begin
        performanceTrace.Finish('cancelled',
          'step=participants.confirm skipped_count=' +
          IntToStr(importPlan.RowCount));
        Exit;
      end;
      importRequest.BackupCreated := BackupBD(alvStatus, cbrBeforeImport);
      if not importRequest.BackupCreated then
        importRequest.ContinueWithoutBackup :=
          ConfirmResultsImportWithoutBackup;
      if (not importRequest.BackupCreated) and
        (not importRequest.ContinueWithoutBackup) then
      begin
        performanceTrace.Finish('cancelled', 'step=backup');
        Exit;
      end;

      importOutcome := TCompetitionImportService.ApplyResults(importPlan,
        MainForm.CompetitionDb, stages, importRequest);

      performanceTrace.Step('participants.prepare',
        'row_count=' + IntToStr(importOutcome.ImportedRowCount) +
        ' skipped_count=' + IntToStr(importOutcome.SkippedRowCount) +
        ' stage_index=' + IntToStr(importOutcome.StageIndex));
      performanceTrace.Step('backup',
        'created=' + LowerCase(BoolToStr(
        importRequest.BackupCreated, True)));
      performanceTrace.Step('rows_write',
        'row_count=' + IntToStr(importOutcome.ImportedRowCount) +
        ' stage_index=' + IntToStr(importOutcome.StageIndex));
      performanceTrace.Step('statuses',
        'applied=' + LowerCase(BoolToStr(
        importPlan.ImportFormat = crifFullStage, True)) +
        ' processed_count=' +
        IntToStr(importOutcome.StatusProcessedCount) +
        ' changed_count=' + IntToStr(importOutcome.StatusChangedCount));
      performanceTrace.Step('recalculate',
        'stage_count=' + IntToStr(stages.Count) +
        ' active_stage_count=' + IntToStr(stages.ActiveStagesCount));
      performanceTrace.Step('commit',
        'stage_index=' + IntToStr(importOutcome.StageIndex));

      RefreshAll;
      AppLog(Format(rsResultsImported,
        [importOutcome.StageIndex, stages[importOutcome.StageIndex].Name,
        importOutcome.ImportedRowCount, canonicalFileName]), allInfo,
        alvStatus, alsImport);
      if importOutcome.SkippedRowCount > 0 then
        AppLog(Format(rsResultsImportPartial,
          [importOutcome.StageIndex, stages[importOutcome.StageIndex].Name,
          importOutcome.ImportedRowCount, importOutcome.TotalRowCount,
          canonicalFileName]), allWarning, alvStatus, alsImport);
      performanceTrace.Finish('ok',
        'row_count=' + IntToStr(importOutcome.ImportedRowCount) +
        ' skipped_count=' + IntToStr(importOutcome.SkippedRowCount) +
        ' stage_index=' + IntToStr(importOutcome.StageIndex));
    except
      on E: ECompetitionImportValidationError do
      begin
        performanceTrace.FinishError(E);
        ReportLoadError(rsLoadResultsError, E.Message);
      end;
      on E: EDatabaseError do
      begin
        performanceTrace.FinishError(E);
        ReportLoadError(rsWriteResultsDatabaseError, E.Message);
      end;
      on E: EStreamError do
      begin
        performanceTrace.FinishError(E);
        ReportLoadError(rsLoadResultsError, E.Message);
      end;
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        ReportLoadError(rsLoadResultsError, E.Message);
      end;
    end;
  finally
    importPlan.Free;
    performanceTrace.Free;
    Screen.Cursor := crDefault;
  end;
end;
function CreateCompetitionExportLabels: TCompetitionExportLabels;
begin
  Result := Default(TCompetitionExportLabels);
  Result.FinishProtocol := rsFinishProtocol;
  Result.FinishThruProtocol := rsFinishThruProtocol;
  Result.Place := rsPlace;
  Result.Number := rsNumber;
  Result.ParticipantName := rsName;
  Result.Nickname := rsNickname;
  Result.Age := rsAge;
  Result.Team := rsTeam;
  Result.City := rsCity;
  Result.Result := rsResult;
  Result.DiffLeader := rsDiffleader;
  Result.Penalty := rsPenalty;
  Result.SumResult := rsSumresult;
  Result.SumStages := rsSumstages;
  Result.Category := rsCategory;
end;

procedure TMainForm.ExportFinishTime(FileName: string; stageIndex: integer);
var
  canonicalFileName, messageText: string;
  performanceTrace: TPerformanceTrace;
begin
  canonicalFileName := ExpandFileName(FileName);
  performanceTrace := TPerformanceTrace.Create('csv.stage_results.export',
    alsExport, 'stage_index=' + IntToStr(stageIndex) +
    ' stage_count=' + IntToStr(stages.Count));
  try
    try
      if IsCompetitionDatabaseOpen then
        TCompetitionExportService.ExportStageResultsToCsv(canonicalFileName,
          MainForm.SQLQuery1, stages, stageIndex);
      performanceTrace.Finish('ok',
        'stage_index=' + IntToStr(stageIndex));
      AppLog(Format(rsStageResultsExported,
        [stageIndex, stages[stageIndex].Name, canonicalFileName]), allInfo,
        alvStatus, alsExport);
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        messageText := Format(rsExportFileError,
          [canonicalFileName, E.Message]);
        AppLog(messageText, allError, alvStatus, alsExport);
        AskMessageDlg(messageText, mtError, [mbOK], 0);
      end;
    end;
  finally
    performanceTrace.Free;
  end;
end;
function TMainForm.ExportAllResultsToXLSX(FileName: string): boolean;
var
  canonicalFileName, messageText: string;
  exportOutcome: TXlsxExportOutcome;
  performanceTrace: TPerformanceTrace;
begin
  Result := False;
  canonicalFileName := ExpandFileName(FileName);
  performanceTrace := TPerformanceTrace.Create('xlsx.results.export',
    alsExport, 'stage_count=' + IntToStr(stages.Count) +
    ' active_stage_count=' + IntToStr(stages.ActiveStagesCount));
  try
    try
      if FileExists(canonicalFileName) and
        (AskMessageDlg(rsFileExists, mtWarning,
        [mbOK, mbCancel], 0) <> mrOk) then
      begin
        performanceTrace.Finish('cancelled', 'step=overwrite.confirm');
        Exit;
      end;

      try
        exportOutcome := TCompetitionExportService.ExportAllResultsToXlsx(
          canonicalFileName, MainForm.SQLQuery1,
          MainForm.ResultDatasetStageTotal, stages,
          CreateCompetitionExportLabels);
      except
        on E: ECompetitionExportFileError do
        begin
          performanceTrace.FinishError(E, 'step=file.write');
          messageText := Format(rsExportFileError,
            [canonicalFileName, E.Message]);
          AppLog(messageText, allError, alvStatus, alsExport);
          AskMessageDlg(messageText, mtError, [mbOK], 0);
          Exit;
        end;
      end;

      AppLog(Format(rsExportReportParameters,
        [exportOutcome.PenaltyGroupCount]), allDebug, alvDetails, alsExport);
      performanceTrace.Finish('ok',
        'category_count=' + IntToStr(exportOutcome.CategoryCount) +
        ' finish_row_count=' + IntToStr(exportOutcome.FinishRowCount) +
        ' thru_row_count=' + IntToStr(exportOutcome.ThroughRowCount));
      AppLog(Format(rsFullResultsExported, [canonicalFileName]), allInfo,
        alvStatus, alsExport);
      Result := True;
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        raise;
      end;
    end;
  finally
    performanceTrace.Free;
  end;
end;

procedure TMainForm.RefreshFinishMarkWorkQueue(const AMarkId: int64);
var
  SelectedMarkId: int64;
begin
  if not DatasetFinishMarks.Active then
    Exit;
  SelectedMarkId := 0;
  if not DatasetFinishMarks.IsEmpty then
    SelectedMarkId := DatasetFinishMarks.FieldByName('id').AsLargeInt;
  CompetitionDb.RefreshQuery(DatasetFinishMarks);
  if (AMarkId > 0) and DatasetFinishMarks.Locate('id', AMarkId, []) then
    Exit;
  if SelectedMarkId > 0 then
    DatasetFinishMarks.Locate('id', SelectedMarkId, []);
end;

procedure TMainForm.ExportCSVStartList(FileName: string);
const
  BASE_EXPORT_FIELD_COUNT = 10;
var
  canonicalFileName, messageText: string;
  fieldSpecs: TExportFieldSpecs;
  performanceTrace: TPerformanceTrace;
begin
  canonicalFileName := ExpandFileName(FileName);
  performanceTrace := TPerformanceTrace.Create('csv.start_list.export',
    alsExport, 'stage_count=' + IntToStr(stages.Count) +
    ' active_stage_count=' + IntToStr(stages.ActiveStagesCount));
  try
    if FileExists(canonicalFileName) and
      (AskMessageDlg(rsStartListFileExists, mtWarning,
      [mbYes, mbNo], 0) <> mrYes) then
    begin
      performanceTrace.Finish('cancelled', 'step=overwrite.confirm');
      Exit;
    end;

    try
      fieldSpecs := TCompetitionExportService.BuildStartListFieldSpecs(stages);
      TCompetitionExportService.ExportDataSetToCsv(CSVStartListExporter,
        MainForm.MainDataSource1.DataSet, canonicalFileName,
        BASE_EXPORT_FIELD_COUNT, fieldSpecs);
      performanceTrace.Finish('ok',
        'active_stage_count=' + IntToStr(stages.ActiveStagesCount));
      AppLog(Format(rsStartListExported, [canonicalFileName]), allInfo,
        alvStatus, alsExport);
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        messageText := Format(rsExportFileError,
          [canonicalFileName, E.Message]);
        AppLog(messageText, allError, alvStatus, alsExport);
        AskMessageDlg(messageText, mtError, [mbOK], 0);
      end;
    end;
  finally
    performanceTrace.Free;
  end;
end;
procedure TMainForm.ExportCSVResults(FileName: string);
const
  BASE_EXPORT_FIELD_COUNT = 8;
var
  canonicalFileName, messageText: string;
  fieldSpecs: TExportFieldSpecs;
  performanceTrace: TPerformanceTrace;
begin
  canonicalFileName := ExpandFileName(FileName);
  performanceTrace := TPerformanceTrace.Create('csv.results.export',
    alsExport, 'stage_count=' + IntToStr(stages.Count) +
    ' active_stage_count=' + IntToStr(stages.ActiveStagesCount));
  try
    if FileExists(canonicalFileName) and
      (AskMessageDlg(rsCSVResultsFileExists, mtWarning,
      [mbYes, mbNo], 0) <> mrYes) then
    begin
      performanceTrace.Finish('cancelled', 'step=overwrite.confirm');
      Exit;
    end;

    try
      fieldSpecs := TCompetitionExportService.BuildResultsFieldSpecs(stages,
        rsResult, rsDiffleader, rsPlace, rsSumresult);
      TCompetitionExportService.ExportDataSetToCsv(CSVResultsExporter,
        MainForm.MainDataSource1.DataSet, canonicalFileName,
        BASE_EXPORT_FIELD_COUNT, fieldSpecs);
      performanceTrace.Finish('ok',
        'active_stage_count=' + IntToStr(stages.ActiveStagesCount));
      AppLog(Format(rsCSVResultsExported, [canonicalFileName]), allInfo,
        alvStatus, alsExport);
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E);
        messageText := Format(rsExportFileError,
          [canonicalFileName, E.Message]);
        AppLog(messageText, allError, alvStatus, alsExport);
        AskMessageDlg(messageText, mtError, [mbOK], 0);
      end;
    end;
  finally
    performanceTrace.Free;
  end;
end;
procedure TMainForm.StartMarkReceived(Sender: TObject;
  const AMark: TStartMark);
var
  correctionText, timeText: string;
  logSource: TAppLogSource;
  ReceiveResult: TStartMarkReceiveResult;
begin
  case AMark.Source.Kind of
    tmskSerial: logSource := alsSerial;
    tmskBle: logSource := alsBle;
    tmskManual: logSource := alsApplication;
  end;
  if not Assigned(FStartMarkService) or
    not CompetitionDb.Connection.Connected then
    Exit;
  try
    ReceiveResult := FStartMarkService.Receive(AMark,
      startMarkMatchDeltaSeconds, startMarkAutomaticApply, Now);
    if ReceiveResult.Mark.Status = smsApplied then
      RefreshAll;
    if DatasetStartMarks.Active then
    begin
      CompetitionDb.RefreshQuery(DatasetStartMarks);
      DatasetStartMarks.Locate('id', ReceiveResult.Mark.Id, []);
    end;
  except
    on E: Exception do
    begin
      AppLog(E.Message, allError, alvStatus, alsDatabase);
      Exit;
    end;
  end;
  timeText := FormatDateTime('hh:nn:ss.zzz', AMark.EventTime);
  if AMark.HasCorrection then
    correctionText := IntToStr(AMark.CorrectionMs)
  else
    correctionText := '';
  AppLog(Format(rsTimingStart, [timeText, correctionText]), allDebug,
    alvDetails, logSource);
end;

procedure TMainForm.FinishMarkReceived(Sender: TObject;
  const AMark: TFinishMark);
var
  Mark: TFinishMark;
  logSource: TAppLogSource;
begin
  case AMark.Source.Kind of
    tmskSerial: logSource := alsSerial;
    tmskBle: logSource := alsBle;
    tmskManual: logSource := alsApplication;
  end;
  if not Assigned(FFinishMarkService) or
    not CompetitionDb.Connection.Connected then
    Exit;
  try
    Mark := FFinishMarkService.Handle(AMark,
      not DatasetFinishMarks.Active or DatasetFinishMarks.IsEmpty);
    RefreshFinishMarkWorkQueue(Mark.Id);
  except
    on E: Exception do
    begin
      AppLog(E.Message, allError, alvStatus, alsDatabase);
      Exit;
    end;
  end;
  AppLog(Format(rsTimingFinish,
    [FormatDateTime('hh:nn:ss.zzz', Mark.EventTime)]), allDebug,
    alvDetails, logSource);
end;

procedure TMainForm.ApplyTimingPacket(const APacket: TTimingPacket;
  const ASource: TTimingMarkSource);
var
  Mark: TTimingMark;
  StageIndex: integer;
begin
  Mark := TimingMarkFromTimingPacket(APacket, ASource, Now);
  StageIndex := stages.NormalizeActiveIndex(CurrentStageIndex);
  FTimingMarkRouter.Route(Mark, StageIndex);
end;


function TMainForm.GetSelectedStage: integer;
var
  stageIndex: integer;
begin
  Result := 0;
  if not Assigned(stages) then
    Exit;

  // Поле конкретного СУ имеет приоритет. Для общих полей используется
  // текущий СУ из типизированного селектора главной формы.
  if TryGetStageIndexFromFieldName(SelectedMainGridFieldName, stageIndex) and
    stages.IsActiveIndex(stageIndex) then
    Exit(stageIndex);
  Result := stages.NormalizeActiveIndex(MainForm.CurrentStageIndex);
end;


function TMainForm.BackupBD(ASuccessView: TAppLogView;
  AReason: TCompetitionBackupReason): boolean;
var
  BackupRequest: TCompetitionBackupRequest;
  BackupResult: TCompetitionBackupResult;
begin
  BackupRequest := NewCompetitionBackupRequest(
    CompetitionDb.Connection.DatabaseName, Now, cbkSafety, AReason,
    CurrentBackupRetentionPolicy);
  BackupResult := TCompetitionBackupService.CreateBackup(BackupRequest);
  Result := BackupResult.Status = cbsCreated;
  if Result then
  begin
    AppLog(Format(rsBackupCreated, [BackupResult.BackupFileName]),
      allInfo, ASuccessView, alsDatabase);
    if BackupResult.Cleanup.DeletedCount > 0 then
      AppLog(Format(rsBackupCleanupCompleted,
        [BackupResult.Cleanup.DeletedCount,
        BackupResult.Cleanup.FreedBytes]), allInfo, alvDetails, alsDatabase);
    if BackupResult.Cleanup.WarningMessage <> '' then
      AppLog(Format(rsBackupCleanupWarning,
        [BackupResult.Cleanup.WarningMessage]), allWarning, alvDetails,
        alsDatabase);
  end
  else
    case BackupResult.Failure of
      cbfDirectoryCreate:
        AppLog(Format(rsBackupDirectoryCreateError,
          [ExtractFilePath(BackupResult.BackupFileName)]), allWarning,
          alvDetails, alsDatabase);
      cbfInvalidFile:
        AppLog(Format(rsBackupFileInvalid,
          [BackupResult.BackupFileName]), allWarning, alvDetails,
          alsDatabase);
      else
        AppLog(Format(rsBackupCreateError,
          [BackupResult.BackupFileName, BackupResult.ErrorMessage]),
          allWarning, alvDetails, alsDatabase);
    end;
end;

end.
