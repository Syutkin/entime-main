unit Main;

{$mode objfpc}{$H+}

{$IFOPT D+} {$DEFINE DEBUG} {$ENDIF}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Dialogs, StdCtrls, LazSerial,
  lazserialsetup, synaser, HistoryFiles, DataPortHTTP, ComCtrls, ExtCtrls,
  LCLType, LResources, Menus, ActnList, StdActns, Grids, rxdbgrid, rxlookup,
  rxdbcomb, rxtoolbar, RxTimeEdit, RxIniPropStorage, rxspin, RxAboutDialog,
  RxDBGridExportSpreadSheet, rxFileUtils, DB, Sqlite3DS, sqlite3conn, sqldb,
  fpcsvexport, dateutils, Controls, DBGrids, Graphics,
  i18n, gettext, LCLTranslator, translations,
  VersionSupport, LazUTF8, PropertyStorage, Buttons, DBCtrls,
  Types, Clipbrd, lclintf, DataPort, fpDBExport, Startlist, MyRxDBGrid,
  stagemodel;

type

  { TMainForm }

  TMainForm = class(TForm)
    AcCOMSetup: TAction;
    AcCOMOpen: TAction;
    AcCOMClose: TAction;
    AcSetFinish: TAction;
    AcClearResults: TAction;
    AcRunSettings: TAction;
    AcDeleteNumber: TAction;
    AcSetDNF: TAction;
    AcSetDNS: TAction;
    AcSetDSQ: TAction;
    AcSetDNSCor: TAction;
    AcSetDNFOnTrace: TAction;
    AcSetClear: TAction;
    AcSyncModule: TAction;
    AcGenerateStartTime: TAction;
    AcLoRaClear: TAction;
    AcSetStarttime: TAction;
    AcLEDPanel: TAction;
    AcTelegramBot: TAction;
    AcRunRaceSettings: TAction;
    AcCheckUpdate: TAction;
    ExportStageResults: TAction;
    CheckBoxAutomaticUpdateResutls: TCheckBox;
    CSVResultsExporter: TCSVExporter;
    CSVStartListExporter: TCSVExporter;
    CurrentSU: TRadioGroup;
    DataPortHTTP1: TDataPortHTTP;
    DataPortHTTPTelegramBot: TDataPortHTTP;
    FileExportCSVStartlist: TFileSaveAs;
    FileExportCSVResults: TFileSaveAs;
    FileExportStageResultsSaveAs: TFileSaveAs;
    GenerateSumDays: TAction;
    EditCopy1: TEditCopy;
    EditCopy2: TEditCopy;
    FileExportAllResults: TFileSaveAs;
    FileOpenCSVSum: TFileOpen;
    FileExportSumDays: TFileSaveAs;
    GridResult7: TRxDBGrid;
    GridResult8: TRxDBGrid;
    ImageList1: TImageList;
    LoRaPopupOpen: TAction;
    LoRaPopupHideSelected: TAction;
    LoRaPopupShow15min: TAction;
    LoRaPopupShowFromStart: TAction;
    LoRaPopupShowAll: TAction;
    LoRaPopupDefault: TAction;
    ButtonLoRaClear: TButton;
    DataSourceLoRa: TDataSource;
    FileGenerateFinal: TFileSaveAs;
    MainDataset1comment: TStringField;
    MainDataset1correction7: TStringField;
    MainDataset1correction8: TStringField;
    MainDataset1diffleader7: TStringField;
    MainDataset1diffleader8: TStringField;
    MainDataset1email: TStringField;
    MainDataset1finishtime7: TStringField;
    MainDataset1finishtime8: TStringField;
    MainDataset1penalty7: TStringField;
    MainDataset1penalty8: TStringField;
    MainDataset1phone: TStringField;
    MainDataset1place7: TLongintField;
    MainDataset1place8: TLongintField;
    MainDataset1result7: TStringField;
    MainDataset1result8: TStringField;
    MainDataset1starttime7: TStringField;
    MainDataset1starttime8: TStringField;
    MainDataset1status1: TStringField;
    MainDataset1status2: TStringField;
    MainDataset1status3: TStringField;
    MainDataset1status4: TStringField;
    MainDataset1status5: TStringField;
    MainDataset1status6: TStringField;
    MainDataset1status7: TStringField;
    MainDataset1status8: TStringField;
    MainDataset1sumstages: TLongintField;
    MainDataset1thrudiff: TStringField;
    MainDataset1thruplace: TStringField;
    MenuItem10: TMenuItem;
    ResultDataset7: TSqlite3Dataset;
    ResultDataset8: TSqlite3Dataset;
    Separator2: TMenuItem;
    MenuItemCheckUpdate: TMenuItem;
    MenuItemExportAllResults: TMenuItem;
    MenuItemExportCSVResults: TMenuItem;
    MenuItem2: TMenuItem;
    MainPanel: TPanel;
    RxDBGrid1: TMyRxDBGrid;
    Separator1: TMenuItem;
    MenuItemExportCSVStartList: TMenuItem;
    MenuItemTelegramBot: TMenuItem;
    Separator3: TMenuItem;
    MenuItemLED: TMenuItem;
    N13: TMenuItem;
    MenuItemGenerateSumDays: TMenuItem;
    pmSetStartTime: TMenuItem;
    N12: TMenuItem;
    N15: TMenuItem;
    MenuItemExportStageResults: TMenuItem;
    MenuItemLoRaCopy: TMenuItem;
    N11: TMenuItem;
    N9: TMenuItem;
    pmCopy: TMenuItem;
    N10: TMenuItem;
    N8: TMenuItem;
    MenuItemLoRaOpen: TMenuItem;
    MenuItemLoRaHideSelected: TMenuItem;
    MenuItemLoRaShow15min: TMenuItem;
    MenuItemLoRaShowFromStart: TMenuItem;
    MenuItemLoRaShowAll: TMenuItem;
    MenuItemLoRaDefault: TMenuItem;
    N7: TMenuItem;
    MenuItemMonitorMode: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItemGenerateStartTime: TMenuItem;
    MenuItemCompetition: TMenuItem;
    MenuItemDebug: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    N6: TMenuItem;
    MenuItemGenerateFinal: TMenuItem;
    ComboBox1Category: TComboBox;
    FileNewDB: TFileSaveAs;
    GridResult3: TRxDBGrid;
    GridResult4: TRxDBGrid;
    GridResult5: TRxDBGrid;
    GridResult6: TRxDBGrid;
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
    PanelLoRa: TGroupBox;
    PanelResult: TPanel;
    PopupMenuLoRa: TPopupMenu;
    RxAboutDialog1: TRxAboutDialog;
    RxDBComboBox1: TRxDBComboBox;
    RxDBGridLoRa: TRxDBGrid;
    RxDBLookupCombo1: TRxDBLookupCombo;
    RxIniPropStorage1: TRxIniPropStorage;
    pmSetClear: TMenuItem;
    ResultDataset2: TSqlite3Dataset;
    ResultDataset3: TSqlite3Dataset;
    ResultDataset4: TSqlite3Dataset;
    ResultDataset5: TSqlite3Dataset;
    ResultDataset6: TSqlite3Dataset;
    ResultDatasetStageTotal: TSqlite3Dataset;
    ResultDatasetStageSum: TSqlite3Dataset;
    ResultDataSource1: TDataSource;
    FileOpenCSVResult: TFileOpen;
    MainDataset1correction2: TStringField;
    MainDataset1correction3: TStringField;
    MainDataset1correction4: TStringField;
    MainDataset1correction5: TStringField;
    MainDataset1correction6: TStringField;
    MainDataset1diffleader2: TStringField;
    MainDataset1diffleader3: TStringField;
    MainDataset1diffleader4: TStringField;
    MainDataset1diffleader5: TStringField;
    MainDataset1diffleader6: TStringField;
    MainDataset1finishtime2: TStringField;
    MainDataset1finishtime3: TStringField;
    MainDataset1finishtime4: TStringField;
    MainDataset1finishtime5: TStringField;
    MainDataset1finishtime6: TStringField;
    MainDataset1penalty2: TStringField;
    MainDataset1penalty3: TStringField;
    MainDataset1penalty4: TStringField;
    MainDataset1penalty5: TStringField;
    MainDataset1penalty6: TStringField;
    MainDataset1place2: TLongintField;
    MainDataset1place3: TLongintField;
    MainDataset1place4: TLongintField;
    MainDataset1place5: TLongintField;
    MainDataset1place6: TLongintField;
    MainDataset1result2: TStringField;
    MainDataset1result3: TStringField;
    MainDataset1result4: TStringField;
    MainDataset1result5: TStringField;
    MainDataset1result6: TStringField;
    MainDataset1starttime2: TStringField;
    MainDataset1starttime3: TStringField;
    MainDataset1starttime4: TStringField;
    MainDataset1starttime5: TStringField;
    MainDataset1starttime6: TStringField;
    MainDataset1sumdiffleader: TStringField;
    MainDataset1sumplace: TLongintField;
    MainDataset1sumresult: TStringField;
    MenuItem1: TMenuItem;
    MenuItemImportResults: TMenuItem;
    OnTracePopupMenu: TPopupMenu;
    GridResult1: TRxDBGrid;
    GridResult2: TRxDBGrid;
    ResultDataSource2: TDataSource;
    ResultDataSource3: TDataSource;
    ResultDataSource4: TDataSource;
    ResultDataSource5: TDataSource;
    ResultDataSource6: TDataSource;
    ResultDataSource7: TDataSource;
    ResultDataSource8: TDataSource;
    ResultDataSourceStageTotal: TDataSource;
    ResultDataSourceStageSum: TDataSource;
    SheetStage: TPageControl;
    Splitter1: TSplitter;
    ResultDataset1: TSqlite3Dataset;
    Splitter2: TSplitter;
    DatasetLoRa: TSqlite3Dataset;
    SQLQuery2: TSQLQuery;
    StatDataset1id: TAutoIncField;
    StatDataset2name: TStringField;
    StatDataset2number: TLongintField;
    StatDataset2starttime: TStringField;
    StatDataset2timeontrack: TStringField;
    StatDataSource2: TDataSource;
    Empty: TAction;
    AcUpdateResults: TAction;
    ButtonSetFinish: TButton;
    ComboBoxLog: TComboBox;
    CorrectionDatasetcorrection: TStringField;
    CorrectionDatasetnumber: TStringField;
    CorrectionDataSource: TDataSource;
    pmDeleteNumber: TMenuItem;
    GroupBox2: TGroupBox;
    MainDataset1diffleader1: TStringField;
    MainDataset1status: TStringField;
    CorrectionPopupMenu: TPopupMenu;
    StatRxDBGrid2: TRxDBGrid;
    pmSetDNSCor: TMenuItem;
    pmSetStatus: TMenuItem;
    pmSetDNS: TMenuItem;
    pmSetDNF: TMenuItem;
    pmSetDSQ: TMenuItem;
    StatDataset2: TSqlite3Dataset;
    StatusBarRight: TStatusBar;
    StatusBarPanel: TPanel;
    StatDataset1catcount: TLongintField;
    StatDataset1category: TStringField;
    StatDataSource1: TDataSource;
    GroupBox1: TGroupBox;
    MainDataset1age: TStringField;
    MainDataset1category: TStringField;
    MainDataset1city: TStringField;
    MainDataset1correction1: TStringField;
    MainDataset1finishtime1: TStringField;
    MainDataset1id: TAutoIncField;
    MainDataset1name: TStringField;
    MainDataset1nickname: TStringField;
    MainDataset1number: TLongintField;
    MainDataset1penalty1: TStringField;
    MainDataset1place1: TLongintField;
    MainDataset1result1: TStringField;
    MainDataset1rfid: TLongintField;
    MainDataset1starttime1: TStringField;
    MainDataset1team: TStringField;
    SheetStage7: TTabSheet;
    SheetStage8: TTabSheet;
    TabSheetMainPanel: TPanel;
    EditPanel: TPanel;
    N1: TMenuItem;
    PageControl1: TPageControl;
    StatRxDBGrid1: TRxDBGrid;
    StatDataset1: TSqlite3Dataset;
    TabSheet1: TTabSheet;
    SheetStageTotal: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    SheetStage1: TTabSheet;
    SheetStage2: TTabSheet;
    SheetStage3: TTabSheet;
    SheetStage4: TTabSheet;
    SheetStage5: TTabSheet;
    SheetStage6: TTabSheet;
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
    sGridResult: TStringGrid;
    SQLite3Connection1: TSQLite3Connection;
    CorrectionDataset: TSqlite3Dataset;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    BackupTimer: TTimer;
    TimerMonitor: TTimer;
    ToolPanel1: TToolPanel;
    ViewMemo: TMenuItem;
    MenuItem3: TMenuItem;
    ViewResults: TMenuItem;
    DebugPanel: TPanel;
    DebugSplitter: TSplitter;
    MainDataset1: TSqlite3Dataset;
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
    StatusBarLeft: TStatusBar;
    Timer1: TTimer;
    procedure AcCheckDBOpenUpdate(Sender: TObject);
    procedure AcCheckUpdateExecute(Sender: TObject);
    procedure AcCheckUpdateUpdate(Sender: TObject);
    procedure AcCOMCloseExecute(Sender: TObject);
    procedure AcCOMOpenExecute(Sender: TObject);
    procedure AcGenerateStartTimeExecute(Sender: TObject);
    procedure AcLEDPanelExecute(Sender: TObject);
    procedure AcLoRaClearExecute(Sender: TObject);
    procedure AcRunRaceSettingsExecute(Sender: TObject);
    procedure AcTelegramBotExecute(Sender: TObject);
    procedure AcSetStarttimeExecute(Sender: TObject);
    procedure BackupTimerTimer(Sender: TObject);
    procedure CheckDBOpenAndRaceMode(Sender: TObject);
    procedure ExportStageResultsExecute(Sender: TObject);
    procedure DataPortHTTP1DataAppear(Sender: TObject);
    procedure DataPortHTTP1Error(Sender: TObject; const AMsg: string);
    procedure DataPortHTTPTelegramBotDataAppear(Sender: TObject);
    procedure DataPortHTTPTelegramBotError(Sender: TObject; const AMsg: ansistring);
    procedure FileExportCSVResultsAccept(Sender: TObject);
    procedure FileExportCSVResultsBeforeExecute(Sender: TObject);
    procedure FileExportCSVStartlistAccept(Sender: TObject);
    procedure FileExportCSVStartlistBeforeExecute(Sender: TObject);
    procedure FileExportFullBeforeExecute(Sender: TObject);
    procedure FileExportStageResultsSaveAsAccept(Sender: TObject);
    procedure FileExportStageResultsSaveAsBeforeExecute(Sender: TObject);
    procedure FileGenerateFinalBeforeExecute(Sender: TObject);
    procedure GenerateSumDaysExecute(Sender: TObject);
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
    procedure AcUpdateResultsExecute(Sender: TObject);
    procedure AcRunSettingsExecute(Sender: TObject);
    procedure AcSetFinishExecute(Sender: TObject);
    procedure AcClearResultsExecute(Sender: TObject);
    procedure AcViewResultsExecute(Sender: TObject);
    procedure AcViewMemoExecute(Sender: TObject);
    procedure BCloseClick(Sender: TObject);
    procedure ButtonFinishTestClick(Sender: TObject);
    procedure ButtonSaveMemoClick(Sender: TObject);
    procedure ButtonClearMemoClick(Sender: TObject);
    procedure CheckCorrectionSetText(Sender: TField; const aText: string);
    procedure EditCopy1Execute(Sender: TObject);
    procedure EditCopy2Execute(Sender: TObject);
    procedure EmptyExecute(Sender: TObject);
    procedure FileExportAllResultsAccept(Sender: TObject);
    procedure FileCloseExecute(Sender: TObject);
    procedure FileGenerateFinalAccept(Sender: TObject);
    procedure FileNewDBAccept(Sender: TObject);
    procedure FileOpenCSVAccept(Sender: TObject);
    procedure FileOpenCSVResultAccept(Sender: TObject);
    procedure FileOpenCSVSumAccept(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure HistoryFiles1ClickHistoryItem(Sender: TObject; Item: TMenuItem;
      const Filename: string);
    procedure LoRaPopupDefaultExecute(Sender: TObject);
    procedure LoRaPopupHideSelectedExecute(Sender: TObject);
    procedure LoRaPopupHideSelectedUpdate(Sender: TObject);
    procedure LoRaPopupOpenExecute(Sender: TObject);
    procedure LoRaPopupShow15minExecute(Sender: TObject);
    procedure LoRaPopupShowAllExecute(Sender: TObject);
    procedure LoRaPopupShowFromStartExecute(Sender: TObject);
    procedure MainDataset1AfterDelete(DataSet: TSqlite3DataSet);
    procedure MainDataset1AfterInsert(DataSet: TSqlite3DataSet);
    procedure MainDataset1BeforeDelete(DataSet: TSqlite3DataSet);
    procedure CheckPenaltySetText(Sender: TField; const aText: string);
    procedure HideZeroHour(Sender: TField; var aText: string; DisplayText: boolean);
    procedure MainDataSource1StateChange(Sender: TObject);
    procedure MenuItemMonitorModeClick(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
    procedure RecalcResults(Sender: TField);
    procedure MainDataset1statusGetText(Sender: TField; var aText: string;
      DisplayText: boolean);
    procedure MenuItemAboutClick(Sender: TObject);
    procedure RaceModeClick(Sender: TObject);
    procedure CurrentSUClick(Sender: TObject);
    procedure RxDBGrid1EditingDone(Sender: TObject);
    procedure RxDBGrid1KeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure RxDBGrid1KeyPress(Sender: TObject; var Key: char);
    procedure RxDBGrid1SelectEditor(Sender: TObject; Column: TColumn;
      var Editor: TWinControl);
    procedure RxDBGridLoRaDblClick(Sender: TObject);
    procedure RxDBGridCorrectionEditingDone(Sender: TObject);
    procedure RxDBSpinEdit1EditingDone(Sender: TObject);
    procedure RxIniPropStorage1RestoreProperties(Sender: TObject);
    procedure RxIniPropStorage1SavingProperties(Sender: TObject);
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
    procedure sGridResultDrawCell(Sender: TObject; aCol, aRow: integer;
      aRect: TRect; aState: TGridDrawState);
    procedure sGridResultValidateEntry(Sender: TObject; aCol, aRow: integer;
      const OldValue: string; var NewValue: string);
    procedure TabSheet2Show(Sender: TObject);
    procedure TimerMonitorTimer(Sender: TObject);
    procedure SyncButtonClick(Sender: TObject);
    procedure FileOpenDBAccept(Sender: TObject);
    procedure FileExportFullAccept(Sender: TObject);
    procedure ResultClearClick(Sender: TObject);
    procedure SerialRxData(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SerialStatus(Sender: TObject; Reason: THookSerialReason;
      const Value: string);
    procedure Timer1Timer(Sender: TObject);
    procedure CheckDBOpen(Sender: TObject);
    procedure SetLang(ALang: string);

    //functions
    function CheckUpdateOnline(ACurrentVersion: string; ForceCheck: bool;
      out LastVersion: string): boolean;
  private
    { private declarations }


  public
    { public declarations }

  end;



const
  //максимальное количество спецучаствок
  MAXSTAGES: integer = 8;
  //количество категорий в окне результатов
  VISIBLECAT: integer = 6;
  //первые девять колонок с информацией об участнике
  COMMON_COLS: integer = 12;
  //количество колонок в СУ
  STAGE_COLS: integer = 7;
  RELEASE_URL: string = 'https://codeberg.org/Syutkin/entime/releases/tag/';




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
  prevTime: TDateTime;
  //задержка в мс между приёмом нового значения финиша
  checkinterval: integer = 250;
  NAME_VERSION: string;
  raceName: string = '';
  //активные СУ
  //stages: TStageDictionary;
  stages: TStages;
  //stage: array[1..6] of boolean;
  //имена СУ
  //stageName: array[1..6] of string;
  //timemark: string;
  //режим работы со временем, str or mark
  //timemarkstr: string;
  //timemarkformat: string;

  //скрывать нулевое значение часа в результатах
  zerohour: boolean = True;

  //LED панель
  ledpaneladress: string;

  //Telegram Bot
  telegrambotadress: string;

  //Показывать название СУ если активен только один
  showStageNameForSingleStage: bool = False;

  //Индекс этапа при экспорте
  exportStageIndex: integer = 1;

  //Обновление
  updateExists: boolean = False;
  checkUpdateAtStartup: boolean = True;
  lastUpdateCheckoutTime: TDateTime;
  checkUpdateIntervalInDays: integer = 7;
  lastVersionOnline: string;

  //Backup
  doAutomaticBackup: boolean = True;
  backupPeriod: integer = 10 * 60 * 1000; //in milliseconds

  startlistConfig: TStartlistConfig;

  //CatList: TStringList;

implementation

uses
  Result, Settings, rxapputils, Implement, exsortsqlite, LoRa, updater, db_sql,
  Validators;

  {$R *.lfm}

  { TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  c: TComponent;
  i: integer;
begin
  NAME_VERSION := Application.Title + ' v' + GetFileVersion;

  Log(rsStartProgram + ' ' + NAME_VERSION);
  stages := TStages.Create(MAXSTAGES);

  //stages := TStageDictionary.Create;
  //for i := 1 to MAXSTAGES do
  //begin
  //  stages.Add(i, TStageModel.Create('', False));
  //end;
  //stages[1].isActive := True;
  //значение по умолчанию (режим работы с 1 СУ)
  HistoryFiles1.IniFile := UTF8ToSys(GetDefaultIniName);
  //для хранения там же, где и RxINIPropStorage
  HistoryFiles1.UpdateParentMenu;
  //  Log(rsShownCategories+' '+cat[1]+', '+cat[2]+', '+cat[3]+', '+cat[4]+', '+cat[5]+', '+cat[6]);
  Memo.Lines.Add('File version = ' + GetFileVersion);
  //  Memo.Lines.Add('Product version = ' + GetProductVersion);
  Memo.Lines.Add('');
  Memo.Lines.Add('Built for ' + GetTargetInfo);
  Memo.Lines.Add(' with ' + GetCompilerInfo + ' on ' + GetCompiledDate);
  Memo.Lines.Add(' and using ' + GetLCLVersion + ' and ' + GetWidgetset);

  StatusBarLeft.Panels[1].Text := Serial.Device;

  //устанавливаем специальные выборки для датасетов
  //тут, чтобы были на виду
  CorrectionDataset.SQL := TDatasetSql.CorrectionPending(1);
  StatDataset2.SQL := TDatasetSql.TrackStatus(1);
  ResultDatasetStageTotal.SQL := TDatasetSql.ResultStageTotal;
  ResultDatasetStageSum.SQL := TDatasetSql.ResultStageSum;

  for i := 1 to MAXSTAGES do
  begin
    c := FindComponent('ResultDataset' + IntToStr(i));
    TSqlite3Dataset(c).SQL := TDatasetSql.ResultStage(i);
  end;

  {$IFDEF DEBUG}
  NAME_VERSION := NAME_VERSION + ' debug';

  RxDBGrid1.Columns[0].Visible := True;
  RxDBGrid1.Columns[0].Width := 25;
  RxDBGrid1.ColumnByFieldName('status').Visible := True;
  RxDBGrid1.Columns[54].Width := 50;

  MenuItemDebug.Visible := True;
  AcViewMemo.Checked := True;
  {$ENDIF}

  (Sender as TForm).Caption := NAME_VERSION;

  //categoriesAtStartlist := TStringList.Create;

  startlistConfig := TStartlistConfig.Create;
end;


procedure TMainForm.SyncButtonClick(Sender: TObject);
//пробуем с текущим временем
var
  tpress: integer;
begin
  tpress := DateTimeToUnix(Now);
  //uses dateutils
  while tpress = DateTimeToUnix(Now) do
  begin
  end;
  Serial.WriteData('T' + IntToStr(DateTimeToUnix(Now)));
end;

procedure TMainForm.BCloseClick(Sender: TObject);
begin
  Serial.Close;
end;

procedure TMainForm.ButtonFinishTestClick(Sender: TObject);
begin
  RecalculateStatus(GetAllStageStatus(0));
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
    MessageDlg(rsIncorrectCorrection, mtInformation, [mbOK], 0);
  end;
end;

procedure TMainForm.EditCopy1Execute(Sender: TObject);
begin
  if dbopen and not MainDataset1.IsEmpty then
  begin
    Clipboard.AsText := MainDataset1.FieldByName(
      RxDBGrid1.SelectedColumn.FieldName).AsString;
  end;
end;

procedure TMainForm.EditCopy2Execute(Sender: TObject);
begin
  if dbopen and not DatasetLoRa.IsEmpty then
  begin
    Clipboard.AsText := DatasetLoRa.FieldByName(
      RxDBGridLoRa.SelectedColumn.FieldName).AsString;
  end;
end;

procedure TMainForm.EmptyExecute(Sender: TObject);
begin

end;

procedure TMainForm.FileExportAllResultsAccept(Sender: TObject);
begin
  ExportAllResults(FileExportAllResults.Dialog.FileName);
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
  n: integer;
  c: TComponent;
begin
  MainForm.Caption := NAME_VERSION;

  for n := 0 to MainForm.ComponentCount - 1 do
  begin
    c := MainForm.Components[n];
    if c is TSqlite3Dataset then
      TSqlite3Dataset(c).Close;
    //else if c is TSQLQuery then
    //  TSQLQuery(c).Close
    //else if c is TSQLTransaction then
    //  TSQLTransaction(c).Active := False
    //else if c is TSQLConnection then
    //  TSQLConnection(c).Close;
  end;

  for n := 0 to ResultsForm.ComponentCount - 1 do
  begin
    c := ResultsForm.Components[n];
    if c is TSqlite3Dataset then
      TSqlite3Dataset(c).Close;
  end;

  SetfName('');

  Log(rsDBFileClosed + ' ' + fName);
end;

procedure TMainForm.FileGenerateFinalAccept(Sender: TObject);
begin
  // Не используется формирование в отдельный файл
  //GenerateStartlistFromQualifier(FileGenerateFinal.Dialog.FileName);
end;

procedure TMainForm.FileNewDBAccept(Sender: TObject);
begin
  FileCloseExecute(nil);
  //fName := FileNewDB.Dialog.FileName;
  //SetfName(fName);
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

procedure TMainForm.FileOpenCSVSumAccept(Sender: TObject);
begin
  AddDayResult((Sender as TFileOpen).Dialog.FileName);
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  //DataPortHTTP1.Close();
  //DataPortHTTP1.Free;
  DataPortHTTP1.Close();
  DataPortHTTP1.OnOpen := nil;
  DataPortHTTP1.OnClose := nil;
  DataPortHTTP1.OnDataAppear := nil;
  DataPortHTTP1.OnError := nil;
  DataPortHTTP1 := nil;
  FreeAndNil(startlistConfig);
  FreeAndNil(stages);
end;

procedure TMainForm.AcViewMemoExecute(Sender: TObject);
begin
  DebugPanel.Visible := AcViewMemo.Checked;
  DebugSplitter.Visible := AcViewMemo.Checked;
  //DebugSplitter.Left := 0;
  // Make sure that the splitter is always at the left of the inspector tabcontrol
end;

procedure TMainForm.AcViewResultsExecute(Sender: TObject);
begin
  if AcViewResults.Checked then
    ResultsForm.Show
  else
    ResultsForm.Hide;
end;

procedure TMainForm.AcCOMSetupExecute(Sender: TObject);
begin
  Serial.ShowSetupDialog;
  StatusBarLeft.Panels[1].Text := Serial.Device;
end;

procedure TMainForm.AcDeleteNumberExecute(Sender: TObject);
begin
  if dbopen and dbnotempty then
  begin
    MainDataset1.Delete;
    MainDataset1.ApplyUpdates;
    RefreshAll;
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
  tpress: integer;
begin
  tpress := DateTimeToUnix(Now);
  //uses dateutils
  while tpress = DateTimeToUnix(Now) do
  begin
  end;
  Serial.WriteData('T' + IntToStr(DateTimeToUnix(Now)));
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

procedure TMainForm.AcSetFinishExecute(Sender: TObject);
begin
  SetFinish;
end;

procedure TMainForm.AcClearResultsExecute(Sender: TObject);
begin
  ClearResults;
end;

procedure TMainForm.AcCOMOpenExecute(Sender: TObject);
begin
  try
    Serial.Open;
  except
    On E: Exception do
    begin
      MessageDlg(rsCOMOpenError + ' ' + Serial.Device, mtError, [mbOK], 0);
      Log(rsCOMOpenError + ' ' + Serial.Device);
    end;
  end;
end;

procedure TMainForm.AcGenerateStartTimeExecute(Sender: TObject);
begin
  RunStartlist(startlistConfig);
end;

procedure TMainForm.AcLEDPanelExecute(Sender: TObject);
begin
  //ledpanelactive := AcLEDPanel.Checked;
  if AcLEDPanel.Checked then
    DataPortHTTP1.Open()
  else
    DataPortHTTP1.Close();
end;

procedure TMainForm.AcLoRaClearExecute(Sender: TObject);
begin
  with SQLQuery1 do
  begin
    SQL.Text := TLoRaSql.ResetIsSetNull;
    Close;
    ExecSQL;
    SQLTransaction.Commit;
    Close;
    //обновляем датасет
    DatasetLoRa.Close;
    try
      DatasetLoRa.Open;
    except
      On E: Exception do
      begin
        MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(rsDatabaseOpenError + E.Message);
      end;
    end;
  end;
end;

procedure TMainForm.AcRunRaceSettingsExecute(Sender: TObject);
begin
  // 2 - страница с настройками соревнования
  SettingsForm.RunSettings(2);
end;

procedure TMainForm.AcTelegramBotExecute(Sender: TObject);
begin
  //if AcTelegramBot.Checked then
  //DataPortHTTPTelegramBot.Open()
  //else
  //DataPortHTTPTelegramBot.Close();
end;

procedure TMainForm.AcSetStarttimeExecute(Sender: TObject);
begin
  SetStarttimeFromPopup;
end;

procedure TMainForm.BackupTimerTimer(Sender: TObject);
begin
  if dbopen then BackupBD;
end;

procedure TMainForm.CheckDBOpenAndRaceMode(Sender: TObject);
begin
   TAction(Sender).Enabled := (dbopen and not RaceMode.Checked);
end;

procedure TMainForm.ExportStageResultsExecute(Sender: TObject);
begin
  exportStageIndex := InputComboSelectStage(rsExportFinish, rsExportTimeToSU);
  if exportStageIndex > 0 then
  begin
    FileExportStageResultsSaveAs.Execute;
  end;
  //ExportFinishTime(FileExportStageResults.Dialog.FileName, exportStageIndex);

  //TFileSaveAs(Sender).Dialog.FileName :=
  //  raceName + '-' + UTF8LowerCase(rsResults) + '-' + stages[exportStageIndex].Name;

end;

procedure TMainForm.DataPortHTTP1DataAppear(Sender: TObject);
begin
  Print((Sender as TDataPortHTTP).Pull());
end;

procedure TMainForm.DataPortHTTP1Error(Sender: TObject; const AMsg: string);
begin
  Print('LED Panel error: ' + AMsg);
  //AcLEDPanel.Checked := False;
end;

procedure TMainForm.DataPortHTTPTelegramBotDataAppear(Sender: TObject);
begin
  Print((Sender as TDataPortHTTP).Pull());
end;

procedure TMainForm.DataPortHTTPTelegramBotError(Sender: TObject;
  const AMsg: ansistring);
begin
  Print('Telegram Bot error: ' + AMsg);
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

procedure TMainForm.GenerateSumDaysExecute(Sender: TObject);
var
  i: integer = 1;
begin
  if dbopen then
  begin
    with MainForm.SQLQuery1 do
    begin
      //если не существует - создание sumdays
      SQL.Text := TSumDaysSql.CreateTableIfNotExists;
      Close;
      ExecSQL;
      SQL.Text := TSumDaysSql.DeleteAll;
      ExecSQL;
      SQLTransaction.Commit;
      Close;
    end;

    while MessageDlg(rsAddDayResults + ' ' + IntToStr(i) + '?',
        mtConfirmation, [mbYes, mbNo], 0) = mrYes do
    begin
      if FileOpenCSVSum.Dialog.Execute then
      begin
        AddDayResult(FileOpenCSVSum.Dialog.FileName);
        i := i + 1;
      end;
    end;

    //Print('i = ' + IntToStr(i));

    if (i > 2) and (MessageDlg(rsSaveResults, mtConfirmation, [mbYes, mbNo], 0) =
      mrYes) then
    begin
      //ставим итоговые места
      with MainForm.SQLQuery1 do
      begin
        SQL.Text := TSumDaysSql.UpsertPlacesByCategory;
        Close;
        ExecSQL;
        SQLTransaction.Commit;
        Close;
        MainForm.SQLTransaction1.Active := False;
      end;
      if FileExportSumDays.Dialog.Execute then
      begin
        ExportSumDays(FileExportSumDays.Dialog.FileName);
        OpenDocument(FileExportSumDays.Dialog.FileName);
      end;
    end;
  end;
end;

procedure TMainForm.ComboBox1CategoryEditingDone(Sender: TObject);
begin
  MainDataset1.Edit;
  MainDataset1.FieldByName('category').AsString := TComboBox(Sender).Text;
  MainDataset1.ApplyUpdates;
  StatDataset1.RefetchData;
end;

procedure TMainForm.COMStatus(Sender: TObject);
begin
  TAction(Sender).Enabled := Serial.Active;
end;

procedure TMainForm.AcCOMCloseExecute(Sender: TObject);
begin
  Serial.Close;
end;

procedure TMainForm.AcCheckDBOpenUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := dbopen;
end;

procedure TMainForm.AcCheckUpdateExecute(Sender: TObject);
begin
  if updateExists and not lastVersionOnline.IsEmpty then
    OpenURL(RELEASE_URL + lastVersionOnline)
  else
    CheckUpdateOnline(GetFileVersion, True, lastVersionOnline);
end;

procedure TMainForm.AcCheckUpdateUpdate(Sender: TObject);
begin
  if updateExists then (Sender as TAction).Caption := rsUpdateAvailable;
end;

procedure TMainForm.RxDBGridCorrectionEditingDone(Sender: TObject);
begin
  if dbopen then
  begin
    if CorrectionDataset.Modified then
    begin
      CorrectionDataset.ApplyUpdates;
      UpdateResults;
    end;
  end;
end;

procedure TMainForm.RxDBSpinEdit1EditingDone(Sender: TObject);
begin
  MainDataset1.ApplyUpdates;
end;

procedure TMainForm.RxIniPropStorage1RestoreProperties(Sender: TObject);
begin
  StatusBarLeft.Panels[1].Text := Serial.Device;
  if AcLEDPanel.Checked then
    DataPortHTTP1.Open();
  AcViewMemoExecute(AcViewMemo);

  // Check update online
  CheckUpdateOnline(GetFileVersion, False, lastVersionOnline);

  // Do automatic backup
  BackupTimer.Enabled := doAutomaticBackup;
  BackupTimer.Interval := backupPeriod;
end;

procedure TMainForm.RxIniPropStorage1SavingProperties(Sender: TObject);
begin
  Width := MulDiv(Width, 96, Screen.PixelsPerInch);
  Height := MulDiv(Height, 96, Screen.PixelsPerInch);
end;

procedure TMainForm.RxIniPropStorage1StoredValues0Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if (Value = 'true') and (HistoryFiles1.Count > 0) then
  begin
    fName := HistoryFiles1.GetItemValue(0);
    //если fName файл существует, то он откроется при создании ResultUnit
  end;
end;

procedure TMainForm.RxIniPropStorage1StoredValues0Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if dbopen then
    Value := 'true'
  else
    Value := 'false';
end;

procedure TMainForm.RxIniPropStorage1StoredValues10Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    doAutomaticBackup := StrToBool(Value);
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
  begin
    backupPeriod := StrToInt(Value);
  end;
end;

procedure TMainForm.RxIniPropStorage1StoredValues11Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(backupPeriod);
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
  begin
    checkinterval := StrToInt(Value);
  end;
end;

procedure TMainForm.RxIniPropStorage1StoredValues2Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(checkinterval);
end;

procedure TMainForm.RxIniPropStorage1StoredValues3Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
    zerohour := StrToBool(Value);
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
  DataPortHTTP1.Url := 'http://' + ledpaneladress + '/post';
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
  //DataPortHTTPTelegramBot.Url := telegrambotadress;
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
    showStageNameForSingleStage := StrToBool(Value);
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
    checkUpdateAtStartup := StrToBool(Value);
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
    lastUpdateCheckoutTime := StrToDateTime(Value);
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
    checkUpdateIntervalInDays := StrToInt(Value);
end;

procedure TMainForm.RxIniPropStorage1StoredValues9Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := IntToStr(checkUpdateIntervalInDays);
end;

procedure TMainForm.sGridResultDrawCell(Sender: TObject; aCol, aRow: integer;
  aRect: TRect; aState: TGridDrawState);
begin
  if (aCol = 0) and ((Sender as TStringGrid).Cells[2, aRow] = 'manual') then
  begin
    (Sender as TStringGrid).Canvas.Brush.Color := clForm;
    (Sender as TStringGrid).Canvas.FillRect(aRect);
    (Sender as TStringGrid).Canvas.TextOut(aRect.Left + 3, aRect.Top + 3,
      (Sender as TStringGrid).Cells[aCol, aRow]);
  end;
end;

procedure TMainForm.sGridResultValidateEntry(Sender: TObject;
  aCol, aRow: integer; const OldValue: string; var NewValue: string);
var
  number: integer;
begin
  if aCol = 1 then
  begin
    if NewValue <> '' then
      if TryStrToInt(sGridResult.Cells[aCol, aRow], number) = False then
        NewValue := OldValue;
  end;
end;

procedure TMainForm.TabSheet2Show(Sender: TObject);
begin
  if dbopen then
  begin
    StatDataset1.Close;
    StatDataset1.Open;
  end;
end;

procedure TMainForm.TimerMonitorTimer(Sender: TObject);
begin
  if MenuItemMonitorMode.Checked and dbopen then
  begin
    RefreshResults;
  end;
end;


procedure TMainForm.FileOpenDBAccept(Sender: TObject);
begin
  if dbopen then
    FileCloseExecute(nil);
  //fName := FileOpenDB.Dialog.FileName;
  //OpenDB;
  //Log(rsDBFileOpen+' '+fName);
  InitDB(FileOpenDB.Dialog.FileName);
end;

procedure TMainForm.FileExportFullBeforeExecute(Sender: TObject);
begin
  TFileSaveAs(Sender).Dialog.FileName :=
    raceName + '-' + UTF8LowerCase(rsFinishProtocol);
end;

procedure TMainForm.FileExportStageResultsSaveAsAccept(Sender: TObject);
begin
  ExportFinishTime(FileExportStageResultsSaveAs.Dialog.FileName, exportStageIndex);
end;

procedure TMainForm.FileExportStageResultsSaveAsBeforeExecute(Sender: TObject);
begin
  TFileSaveAs(Sender).Dialog.FileName :=
    raceName + '-' + UTF8LowerCase(rsResults) + '-' + stages[exportStageIndex].Name;
end;

procedure TMainForm.FileGenerateFinalBeforeExecute(Sender: TObject);
begin
  TFileSaveAs(Sender).Dialog.FileName := raceName + '-' + UTF8LowerCase(rsFinal);
end;

procedure TMainForm.FileExportFullAccept(Sender: TObject);
begin
  ExportAllResultsToXLSX(TFileSaveAs(Sender).Dialog.FileName);
end;


procedure TMainForm.ResultClearClick(Sender: TObject);
begin
  sGridResult.RowCount := 1;
end;


procedure TMainForm.SerialRxData(Sender: TObject);
var
  Str: string;
begin
  Str := Serial.ReadData;
  if Str <> '' then
    ParseSerial(Str);
end;


//procedure TMainForm.SerialRxData(Sender: TObject);
//var
//  Str : string;
//  FinishTime: TDateTime;
//  contime: integer;
//  res: integer;
//begin
//  Str := Serial.ReadData;
//  FinishTime := Now;
//  sGridResult.InsertRowWithValues(sGridResult.RowCount,[FormatDateTime('hh:nn:ss.zzz', FinishTime)]);
//  if TryStrToInt(Str, contime) then begin
//    res := StrToInt(FormatDateTime('sszzz', FinishTime)) - contime;
//    //if res < 0 then res := res + 60000;
//    Memo.Lines.Add(FormatDateTime('sszzz', FinishTime)+' '+IntToStr(contime)+' '+IntToStr(res));
////  Memo.Lines.Add(Str+' '+FormatDateTime('sszzz', FinishTime));
//  end
//  else Memo.Lines.Add(Str);
//end;

procedure TMainForm.SerialStatus(Sender: TObject; Reason: THookSerialReason;
  const Value: string);
begin
  case Reason of
    HR_SerialClose: StatusBarLeft.Panels[2].Text :=
        Format(rsPortClosed, [Value]);
    HR_Connect: StatusBarLeft.Panels[2].Text :=
        Format(rsPortConnected, [Value]);
    HR_CanRead: StatusBarLeft.Panels[2].Text :=
        Format(rsSerialCanRead, [Value]);
    HR_CanWrite: StatusBarLeft.Panels[2].Text :=
        Format(rsSerialCanWrite, [Value]);
    HR_ReadCount: StatusBarLeft.Panels[2].Text :=
        Format(rsSerialReadCount, [Value]);
    HR_WriteCount: StatusBarLeft.Panels[2].Text :=
        Format(rsSerialWriteCount, [Value]);
    HR_Wait: StatusBarLeft.Panels[2].Text :=
        Format(rsSerialWait, [Value]);
  end;
end;


procedure TMainForm.Timer1Timer(Sender: TObject);
var
  pos: integer;
begin
  //это часы внизу
  StatusBarLeft.Panels[0].Text := FormatDateTime('hh:nn:ss', Now);

  //это тикающие секунды в окне "на трассе"
  if dbopen then
  begin
    //запоминает положение курсора
    pos := StatDataset2.RecNo;
    //и восстанавливает его
    StatDataset2.RefetchData;
    StatDataset2.MoveBy(pos - 1);
  end;
end;


procedure TMainForm.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
  FinishTime: TDateTime;
begin
  if (Key = VK_SPACE) and RaceMode.Checked then
  begin
    FinishTime := Now;
    sGridResult.InsertRowWithValues(sGridResult.RowCount,
      [FormatDateTime('hh:nn:ss.zzz', FinishTime), '', 'manual']);
    Memo.Lines.Add(FormatDateTime('hh:nn:ss.zzz', FinishTime) + ' manual');
    Key := VK_ESCAPE;
  end;
end;

procedure TMainForm.HistoryFiles1ClickHistoryItem(Sender: TObject;
  Item: TMenuItem; const Filename: string);
begin
  if dbopen then
    FileCloseExecute(nil);
  //fName := FileName;
  //OpenDB;
  InitDB(FileName);
  Log(rsDBFileOpen + ' ' + fName);
end;

procedure TMainForm.LoRaPopupDefaultExecute(Sender: TObject);
begin
  MainForm.DatasetLoRa.Close;
  MainForm.DatasetLoRa.SQL := TLoRaSql.SelectPending;
  try
    MainForm.DatasetLoRa.Open;
    MainForm.LoRaPopupDefault.Checked := False;
    MainForm.LoRaPopupShow15min.Checked := False;
    MainForm.LoRaPopupShowAll.Checked := False;
    MainForm.LoRaPopupShowFromStart.Checked := False;
    TAction(Sender).Checked := True;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure TMainForm.LoRaPopupHideSelectedExecute(Sender: TObject);
var
  id: string;
begin
  if dbopen and not MainForm.DatasetLoRa.IsEmpty then
  begin
    id := MainForm.DatasetLoRa.FieldByName('id').AsString;
    with MainForm.SQLQuery1 do
    begin
      Close;
      SQL.Text := TLoRaSql.SetIsSetById;
      ParamByName('ID').AsInteger := StrToIntDef(id, 0);
      ExecSQL;
      SQLTransaction.Commit;
      Close;
    end;
    MainForm.SQLite3Connection1.Close;
    MainForm.SQLTransaction1.Active := False;
    MainForm.DatasetLoRa.Close;
    try
      MainForm.DatasetLoRa.Open;
    except
      On E: Exception do
      begin
        MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(rsDatabaseOpenError + E.Message);
      end;
    end;
  end;
end;

procedure TMainForm.LoRaPopupHideSelectedUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := dbopen and MenuItemLoRaDefault.Checked;
end;

procedure TMainForm.LoRaPopupOpenExecute(Sender: TObject);
begin
  RunLoRa;
end;

procedure TMainForm.LoRaPopupShow15minExecute(Sender: TObject);
begin
  MainForm.DatasetLoRa.Close;
  MainForm.DatasetLoRa.SQL := StringReplace(
    TLoRaSql.SelectStartAfter,
    ':STARTTIME',
    '"' + FormatDateTime('hh:nn:ss', (Now - 15 / 24 / 60)) + '"',
    []);
  try
    MainForm.DatasetLoRa.Open;
    MainForm.LoRaPopupDefault.Checked := False;
    MainForm.LoRaPopupShow15min.Checked := False;
    MainForm.LoRaPopupShowAll.Checked := False;
    MainForm.LoRaPopupShowFromStart.Checked := False;
    TAction(Sender).Checked := True;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure TMainForm.LoRaPopupShowAllExecute(Sender: TObject);
begin
  MainForm.DatasetLoRa.Close;
  MainForm.DatasetLoRa.SQL := TLoRaSql.SelectAll;
  try
    MainForm.DatasetLoRa.Open;
    MainForm.LoRaPopupDefault.Checked := False;
    MainForm.LoRaPopupShow15min.Checked := False;
    MainForm.LoRaPopupShowAll.Checked := False;
    MainForm.LoRaPopupShowFromStart.Checked := False;
    TAction(Sender).Checked := True;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure TMainForm.LoRaPopupShowFromStartExecute(Sender: TObject);
var
  minstarttime: string;
begin
  SQLQuery1.Close;
  SQLQuery1.SQL.Text := TMainSql.SelectMinStartTime(ActiveStageIndex);
  SQLQuery1.Open();
  minstarttime := SQLQuery1.FieldByName('starttime').AsString;
  Print(minstarttime);
  SQLQuery1.Close;
  SQLTransaction1.Active := False;
  MainForm.DatasetLoRa.Close;
  MainForm.DatasetLoRa.SQL := StringReplace(
    TLoRaSql.SelectStartAfter,
    ':STARTTIME',
    '"' + minstarttime + '"',
    []);
  try
    MainForm.DatasetLoRa.Open;
    MainForm.LoRaPopupDefault.Checked := False;
    MainForm.LoRaPopupShow15min.Checked := False;
    MainForm.LoRaPopupShowAll.Checked := False;
    MainForm.LoRaPopupShowFromStart.Checked := False;
    TAction(Sender).Checked := True;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure TMainForm.MainDataset1AfterDelete(DataSet: TSqlite3DataSet);
begin
  Dataset.ApplyUpdates;
end;

procedure TMainForm.MainDataset1AfterInsert(DataSet: TSqlite3DataSet);
var
  i: integer;
begin
  SQLQuery1.Close;
  SQLQuery1.SQL.Text := TMainSql.SelectMaxNumber;
  SQLQuery1.Open();
  if TryStrToInt(MainForm.SQLQuery1.FieldByName('number').AsString, i) then
  begin
    i := i + 1;
  end
  else
    i := 1;
  //  i := MainForm.SQLQuery1.FieldByName('number').AsInteger + 1;
  SQLQuery1.Close;
  SQLTransaction1.Active := False;
  DataSet.FieldByName('number').AsInteger := i;
  DataSet.ApplyUpdates;
end;

procedure TMainForm.MainDataset1BeforeDelete(DataSet: TSqlite3DataSet);
var
  n: string;
begin
  n := DataSet.Fields.FieldByName('number').AsString;
  if MessageDlg(rsDeleteNumber + ' ' + n, mtWarning, [mbYes, mbNo], 0) <> mrYes then
    abort
  else
    Log(rsParticipantWithNumber + ' ' + n + ' ' + rsDeleted);
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
    MessageDlg(rsPenaltyTimeFormat, mtInformation, [mbOK], 0);
end;

procedure TMainForm.HideZeroHour(Sender: TField; var aText: string;
  DisplayText: boolean);
begin
  aText := HideLeadingZeroHour(Sender);
end;

procedure TMainForm.MainDataSource1StateChange(Sender: TObject);
begin
  //if TDataSource(Sender).DataSet.State = dsEdit   then Memo.Lines.Add('dsEdit');
  //if TDataSource(Sender).DataSet.State = dsInsert then Memo.Lines.Add('dsInsert');
  //if TDataSource(Sender).DataSet.State = dsBrowse then Memo.Lines.Add('dsBrowse');
  //if TDataSource(Sender).DataSet.State = dsInsert then Memo.Lines.Add('dsInsert');
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
  //DataPortHTTPTelegramBot.Close();
  //DataPortHTTPTelegramBot.Method:=THttpMethods.httpGet;
  //DataPortHTTPTelegramBot.Url := 'http://127.0.0.1/';
  //DataPortHTTPTelegramBot.Params.Clear;
  //DataPortHTTPTelegramBot.Params.Add('upperline=upperline123');
  //DataPortHTTPTelegramBot.Params.Add('bottomline=bottomline123');
  //DataPortHTTPTelegramBot.Open();

  //Print(DataPortHTTPTelegramBot.Url);
  //DataPortHTTPTelegramBot.Push('');
  //s := TFPCustomHTTPClient.SimpleGet('http://192.168.1.136/get?upperline=1%20%2010:10,123&bottomline=Фамилия');
  //Print(s);

end;

procedure TMainForm.RecalcResults(Sender: TField);
begin
  MainDataset1.ApplyUpdates;
  if CheckBoxAutomaticUpdateResutls.Checked then
    UpdateResults
  else
  begin
    CorrectionDataset.Close;
    CorrectionDataset.Open;
  end;
end;

procedure TMainForm.MainDataset1statusGetText(Sender: TField;
  var aText: string; DisplayText: boolean);
begin
  if Sender.AsString = '1' then
    aText := 'DNF';
  if Sender.AsString = '2' then
    aText := 'DNS';
  if Sender.AsString = '3' then
    aText := 'DSQ';
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

procedure TMainForm.CurrentSUClick(Sender: TObject);
var
  i: integer;
begin
  i := (Sender as TRadioGroup).ItemIndex + 1;
  CorrectionDatasetcorrection.FieldName := 'correction' + IntToStr(i);
  RxDBGridCorrection.Columns[1].FieldName := 'correction' + IntToStr(i);
  CorrectionDataset.SQL := TDatasetSql.CorrectionPending(i);
  StatDataset2.SQL := TDatasetSql.TrackStatus(i);
  if dbopen then
  begin
    ;
    CorrectionDataset.Close;
    CorrectionDataset.Open;
    StatDataset2.Close;
    StatDataset2.Open;
  end;
end;

procedure TMainForm.RxDBGrid1EditingDone(Sender: TObject);
begin
  if dbopen then
  begin
    MainDataset1.ApplyUpdates;
    RefreshResults;
    //CorrectionDataset.RefetchData;
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
  i: integer;
begin
  for i := 1 to maxstages do
  begin
    if TRxDBGrid(Sender).SelectedColumn.FieldName = 'penalty' + IntToStr(i) then
      Key := CheckPenaltyInput(Key);
  end;
end;

procedure TMainForm.RxDBGrid1SelectEditor(Sender: TObject; Column: TColumn;
  var Editor: TWinControl);
begin
  if Column.FieldName = 'category' then
  begin
    // ToDo: обновлять список категорий при их реальном изменении
    //а не делать каждый раз sql запросы
    ComboBox1Category.Items.Clear;
    ComboBox1Category.Text :=
      TRxDBGrid(Sender).DataSource.DataSet.FieldByName('category').AsString;
    if StatDataset1.Active then
      StatDataset1.First;
    while not StatDataset1.EOF do
    begin
      ComboBox1Category.Items.Add(StatDataset1.FieldByName('category').AsString);
      StatDataset1.Next;
    end;
    Editor := ComboBox1Category;
    Editor.BoundsRect := TRxDBGrid(Sender).SelectedFieldRect;
    // И заодно обнуляем список категорий
    // ToDo: делать это только при непосредственном изменении категорий
    startlistConfig.categories.Text := '';
  end;
end;

procedure TMainForm.RxDBGridLoRaDblClick(Sender: TObject);
begin
  SetCorrectionFromLoRa;
end;

procedure TMainForm.CheckDBOpen(Sender: TObject);
begin
  TCustomAction(Sender).Enabled := dbopen;
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

  TranslateUnitResourceStrings('rxconst', NormalizeDirectoryName(
    'languages/rxconst.%s.po'), lang, FallbackLang);
  TranslateUnitResourceStrings('rxdconst', NormalizeDirectoryName(
    'languages/rxdconst.%s.po'), lang, FallbackLang);

  //CurrentLang := lang;
end;

function TMainForm.CheckUpdateOnline(ACurrentVersion: string;
  ForceCheck: bool; out LastVersion: string): boolean;
var
  U: TUpdater;
begin
  Result := False;
  if ForceCheck or (checkUpdateAtStartup and
    ((checkUpdateIntervalInDays < 0) or
    (IncDay(lastUpdateCheckoutTime, checkUpdateIntervalInDays) < Now))) then
  begin
    U := TUpdater.Create;
    try
      updateExists := U.NewVersionAvailable(ACurrentVersion, LastVersion);
    finally
      U.Free;
    end;

    if updateExists then
    begin
      if MessageDlg(format(rsNewVersionAvailable, [LastVersion]),
        TMsgDlgType.mtInformation, mbYesNo, 0) = mrYes then
        OpenURL(RELEASE_URL + lastVersionOnline);

      //aMsgDlg := CreateMessageDialog(
      //  'Доступна новая версия программы: ' +
      //  LastVersion, TMsgDlgType.mtInformation, mbOKCancel);

      //for i := 0 to aMsgDlg.ComponentCount - 1 do
      //begin
      //  if (aMsgDlg.Components[i] is TBitBtn) then
      //  begin
      //    TBitBtn(aMsgDlg.Components[i]).Caption :=
      //      'Новый заголовок кнопки';
      //  end;
      //end;

      //aMsgDlg.ShowModal;
    end
    else
    begin
      if ForceCheck and not LastVersion.IsEmpty then
      begin
        MessageDlg(rsUpdatesNotFound, TMsgDlgType.mtInformation, [mbOK], 0);
      end;
    end;

    if not LastVersion.IsEmpty then
      lastUpdateCheckoutTime := Now;
  end;
end;

end.
