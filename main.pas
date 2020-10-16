unit Main;

{$mode objfpc}{$H+}
{$IFOPT D+} {$DEFINE DEBUG} {$ENDIF}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Dialogs, StdCtrls, LazSerial,
  lazserialsetup, synaser, HistoryFiles, ComCtrls, ExtCtrls, LCLType,
  LResources, Menus, ActnList, StdActns, Grids, rxdbgrid, rxlookup, rxdbcomb,
  rxtoolbar, RxTimeEdit, RxIniPropStorage, rxspin, RxAboutDialog,
  RxDBGridExportSpreadSheet, DB, Sqlite3DS, sqlite3conn, sqldb, dateutils,
  Controls, DBGrids, Graphics, i18n, LCLTranslator, VersionSupport, LazUTF8,
  PropertyStorage, Buttons, DBCtrls, translations, Types, Clipbrd, lclintf;

type

  TMyDBGrid = class(TRxDBGrid);



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
    GenerateSumDays: TAction;
    EditCopy1: TEditCopy;
    EditCopy2: TEditCopy;
    FileExportStageResults: TFileSaveAs;
    FileExportAllResults: TFileSaveAs;
    FileOpenCSVSum: TFileOpen;
    FileExportSumDays: TFileSaveAs;
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
    FileExportBDStartlist: TFileSaveAs;
    MenuItem10: TMenuItem;
    N13: TMenuItem;
    MenuItemGenerateSumDays: TMenuItem;
    pmSetStartTime: TMenuItem;
    N12: TMenuItem;
    MenuItem11: TMenuItem;
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
    MenuItemExportBDStartList: TMenuItem;
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
    CurrentSU: TGroupBox;
    ExportSpreadSheet2: TRxDBGridExportSpreadSheet;
    FileExportThru: TFileSaveAs;
    FileNewDB: TFileSaveAs;
    GridResult3: TRxDBGrid;
    GridResult4: TRxDBGrid;
    GridResult5: TRxDBGrid;
    GridResult6: TRxDBGrid;
    GridResult7: TRxDBGrid;
    GridResult8: TRxDBGrid;
    HistoryFiles1: THistoryFiles;
    MenuItem2: TMenuItem;
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
    ResultDataset7: TSqlite3Dataset;
    ResultDataset8: TSqlite3Dataset;
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
    SheetStage: TPageControl;
    RadioCur1: TRadioButton;
    RadioCur2: TRadioButton;
    RadioCur3: TRadioButton;
    RadioCur4: TRadioButton;
    RadioCur5: TRadioButton;
    RadioCur6: TRadioButton;
    ExportSpreadSheet1: TRxDBGridExportSpreadSheet;
    Splitter1: TSplitter;
    ResultDataset1: TSqlite3Dataset;
    Splitter2: TSplitter;
    SQLite3Connection2: TSQLite3Connection;
    DatasetLoRa: TSqlite3Dataset;
    SQLQuery2: TSQLQuery;
    SQLTransaction2: TSQLTransaction;
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
    MainPanel: TPanel;
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
    RxDBGrid1: TRxDBGrid;
    RxDBGridCorrection: TRxDBGrid;
    sGridResult: TStringGrid;
    SQLite3Connection1: TSQLite3Connection;
    CorrectionDataset: TSqlite3Dataset;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
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
    procedure AcCOMCloseExecute(Sender: TObject);
    procedure AcCOMOpenExecute(Sender: TObject);
    procedure AcGenerateStartTimeExecute(Sender: TObject);
    procedure AcLoRaClearExecute(Sender: TObject);
    procedure AcSetStarttimeExecute(Sender: TObject);
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
    procedure FileExportBDStartlistAccept(Sender: TObject);
    procedure FileCloseExecute(Sender: TObject);
    procedure FileExportStageResultsAccept(Sender: TObject);
    procedure FileExportThruAccept(Sender: TObject);
    procedure FileGenerateFinalAccept(Sender: TObject);
    procedure FileNewDBAccept(Sender: TObject);
    procedure FileOpenCSVAccept(Sender: TObject);
    procedure FileOpenCSVResultAccept(Sender: TObject);
    procedure FileOpenCSVResultBeforeExecute(Sender: TObject);
    procedure FileOpenCSVSumAccept(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
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
    procedure RecalcResultsAfterPenaltyChange(Sender: TField);
    procedure MainDataset1statusGetText(Sender: TField; var aText: string;
      DisplayText: boolean);
    procedure MenuItemAboutClick(Sender: TObject);
    procedure RaceModeClick(Sender: TObject);
    procedure RadioCurClick(Sender: TObject);
    procedure RxDBGrid1EditingDone(Sender: TObject);
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
    //functions

  private
    { private declarations }


  public
    { public declarations }

  end;



const
  maxstages: integer = 6;
  //максимальное количество спецучаствок
  visiblecat: integer = 6;
  //количество категорий в окне результатов
  commoncols: integer = 9;
  //первые девять колонок с информацией об участнике
  stagecols: integer = 7;
//количество колонок в СУ



var
  //значения по умолчанию
  MainForm: TMainForm;
  fName: string = '';
  //имя файла БД
  lang: string = 'ru';
  //язык программы
  astage: string = '1';
  //номер СУ, результаты которого будут выводиться в отдельно окно
  cat: array[1..6] of string;
  //список категорий, которые будут выводиться в отдельно окно
  prevTime: TDateTime;
  checkinterval: integer = 250;
  //задержка в мс между приёмом нового значения финиша
  NAME_VERSION: string;
  stage: array[1..6] of boolean;
  //активные СУ
  sname: array[1..6] of string;
  //имена СУ
  //timemark: string;
  //режим работы со временем, str or mark
  //timemarkstr: string;
  //timemarkformat: string;

  //для генерации стартового протокола
  //время начала заездов
  startTime: TDateTime = 0.5;
  //время между стартами  (в секундах)
  delayBetweenRacers: integer = 60;
  //время между категориями (в минутах)
  delayBetweenCategories: integer = 3;

  //скрывать нулевое значение часа в результатах
  zerohour: boolean = True;



//CatList: TStringList;

implementation

uses Result, Settings, Startlist, rxapputils, Implement, exsortsqlite, LoRa;

{$R *.lfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  c: TComponent;
  i: integer;
begin
  NAME_VERSION := Application.Title + ' v' + GetFileVersion;

  Log(sStartProgram + ' ' + NAME_VERSION);
  stage[1] := True;
  //значение по умолчанию (режим работы с 1 СУ)
  HistoryFiles1.IniFile := UTF8ToSys(GetDefaultIniName);
  //для хранения там же, где и RxINIPropStorage
  HistoryFiles1.UpdateParentMenu;
  //  Log(sShownCategories+' '+cat[1]+', '+cat[2]+', '+cat[3]+', '+cat[4]+', '+cat[5]+', '+cat[6]);
  Memo.Lines.Add('File version = ' + GetFileVersion);
  //  Memo.Lines.Add('Product version = ' + GetProductVersion);
  Memo.Lines.Add('');
  Memo.Lines.Add('Built for ' + GetTargetInfo);
  Memo.Lines.Add(' with ' + GetCompilerInfo + ' on ' + GetCompiledDate);
  Memo.Lines.Add(' and using ' + GetLCLVersion + ' and ' + GetWidgetset);

  StatusBarLeft.Panels[1].Text := Serial.Device;

  //устанавливаем специальные выборки для датасетов
  //тут, чтобы были на виду
  CorrectionDataset.SQL :=
    'SELECT * from main where correction1 ISNULL AND status1 ISNULL AND starttime1 NOTNULL ORDER BY starttime1';
  StatDataset2.SQL :=
    'SELECT number, name, starttime1 as starttime, strftime(''%H:%M:%S'',julianday(time(''now'', ''localtime'')) - julianday(time(starttime1)) + 0.5) as timeontrack FROM main WHERE julianday(time(''now'', ''localtime'')) > julianday(time(starttime1)) AND finishtime1 ISNULL AND status1 ISNULL ORDER BY starttime';
  ResultDataset7.SQL :=
    'SELECT category, thruplace as sumplace, number, name, sumresult, thrudiff FROM main WHERE sumresult NOTNULL ORDER BY status, sumresult';
  ResultDataset8.SQL :=
    'SELECT * from main WHERE sumresult NOTNULL ORDER BY category, status, sumstages DESC, IFNULL(sumplace,''toend'')';

  for i := 1 to visiblecat do
  begin
    //шесть категорий для вывода на окно результатов
    c := FindComponent('ResultDataset' + IntToStr(i));
    TSqlite3Dataset(c).SQL :=
      'SELECT category, place' + IntToStr(i) + ', number, name, penalty' +
      IntToStr(i) + ', result' + IntToStr(i) + ', diffleader' +
      IntToStr(i) + ', CASE status WHEN ''3'' THEN ''3'' ELSE status' +
      IntToStr(i) + ' END status' + IntToStr(i) + ' from main where result' +
      IntToStr(i) + ' NOTNULL ORDER BY category, status' + IntToStr(i) +
      ', place' + IntToStr(i);
  end;

  {$IFDEF DEBUG}
  NAME_VERSION := NAME_VERSION + ' debug';

  RxDBGrid1.Columns[0].Visible := True;
  RxDBGrid1.Columns[0].Width := 25;
  RxDBGrid1.ColumnByFieldName('status').Visible := True;
  RxDBGrid1.Columns[54].Width := 50;

  MenuItemDebug.Visible := True;

  //AcViewMemo.Checked := True;
  //ViewMemo.Checked := True;
  //DebugPanel.Visible := True;
  //DebugSplitter.Visible := True;
  {$ENDIF}

  (Sender as TForm).Caption := NAME_VERSION;

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
  Memo.Lines.SaveToFile(FormatDateTime('YYYY-MM-DD hh-mm', now) + ' memo log.txt');
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
    MessageDlg(sIncorrectCorrection, mtInformation, [mbOK], 0);
    Abort;
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

procedure TMainForm.FileExportBDStartlistAccept(Sender: TObject);
begin
  ExportBDStartList(FileExportBDStartlist.Dialog.FileName);
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

  Log(sDBFileClosed + ' ' + fName);
end;

procedure TMainForm.FileExportStageResultsAccept(Sender: TObject);
begin
  ExportFinishTime(FileExportStageResults.Dialog.FileName);
end;

procedure TMainForm.FileExportThruAccept(Sender: TObject);
begin
  ExportSpreadSheet2.FileName := FileExportThru.Dialog.FileName;
  ExportSpreadSheet2.Execute;
  Log(sResultsThruExportedToFile + ' ' + FileExportThru.Dialog.FileName);
end;

procedure TMainForm.FileGenerateFinalAccept(Sender: TObject);
begin
  GenerateStartlistFromQualifier(FileGenerateFinal.Dialog.FileName);
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
  LoadFinishTime((Sender as TFileOpen).Dialog.FileName);
end;

procedure TMainForm.FileOpenCSVResultBeforeExecute(Sender: TObject);
begin

end;

procedure TMainForm.FileOpenCSVSumAccept(Sender: TObject);
begin
  AddDayResult((Sender as TFileOpen).Dialog.FileName);
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  //CatList.Free;
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
  //Memo.Lines.Add('sync');
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
      MessageDlg(sCOMOpenError + ' ' + Serial.Device, mtError, [mbOK], 0);
      Log(sCOMOpenError + ' ' + Serial.Device);
    end;
  end;
end;

procedure TMainForm.AcGenerateStartTimeExecute(Sender: TObject);
begin
  RunStartlist;
end;

procedure TMainForm.AcLoRaClearExecute(Sender: TObject);
begin
  with SQLQuery1 do
  begin
    SQL.Text := 'UPDATE lora SET isset = 0 WHERE isset ISNULL;';
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
        MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(sDatabaseOpenError + E.Message);
      end;
    end;
  end;
end;

procedure TMainForm.AcSetStarttimeExecute(Sender: TObject);
begin
  SetStarttimeFromPopup;
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
      SQL.Text :=
        'CREATE TABLE IF NOT EXISTS sumdays ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE, "number" INTEGER UNIQUE, "place" INTEGER, "sumresult" VARCHAR, "sumstages" INTEGER, "diffleader" VARCHAR, "status" VARCHAR);';
      ExecSQL;
      SQL.Text := 'DELETE from sumdays';
      ExecSQL;
      SQLTransaction.Commit;
      Close;
    end;

    while MessageDlg(sAddDayResults + ' ' + IntToStr(i) + '?',
        mtConfirmation, [mbYes, mbNo], 0) = mrYes do
    begin
      if FileOpenCSVSum.Dialog.Execute then
      begin
        AddDayResult(FileOpenCSVSum.Dialog.FileName);
        i := i + 1;
      end;
    end;

    //Print('i = ' + IntToStr(i));

    if (i > 2) and (MessageDlg(sSaveResults, mtConfirmation, [mbYes, mbNo], 0) =
      mrYes) then
    begin
      //ставим итоговые места
      with MainForm.SQLQuery1 do
      begin
        SQL.Clear;
        SQL.Add('INSERT into sumdays (number, place)');
        SQL.Add(
          'SELECT sumdays.number, row_number() over(partition BY category ORDER BY sumdays.sumresult) as place');
        SQL.Add('FROM main, sumdays');
        SQL.Add(
          'WHERE sumdays.sumresult > 0 AND sumdays.sumstages = (SELECT MAX(sumstages) FROM sumdays) AND sumdays.number = main.number');
        SQL.Add('ORDER BY sumdays.sumresult DESC');
        SQL.Add('ON CONFLICT(number) DO UPDATE SET place = excluded.place;');
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

procedure TMainForm.RxIniPropStorage1StoredValues1Restore(Sender: TStoredValue;
  var Value: TStoredType);
begin
  if Value <> '' then
  begin
    lang := Value;
  end;
  SetDefaultLang(lang);
  TranslateUnitResourceStrings('rxconst', 'languages/rxconst.' + lang + '.po');
  //var
  //  Lang, FallbackLang: String;
  //begin
  //  GetLanguageIDs(Lang{%H-},FallbackLang{%H-}); // in unit gettext
  //  TranslateUnitResourceStrings('rxconst',NormalizeDirectoryName('../../../languages/rxconst.%s.po'), Lang, FallbackLang);
  //  TranslateUnitResourceStrings('rxdconst',NormalizeDirectoryName('../../../languages/rxdconst.%s.po'), Lang, FallbackLang);
end;

procedure TMainForm.RxIniPropStorage1StoredValues1Save(Sender: TStoredValue;
  var Value: TStoredType);
begin
  Value := lang;
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
  //Log(sDBFileOpen+' '+fName);
  InitDB(FileOpenDB.Dialog.FileName);
end;


procedure TMainForm.FileExportFullAccept(Sender: TObject);
var
  sql: string;
begin
  MainDataset1.Close;
  //sql запрос для выдачи итоговой таблицы
  sql := MainDataset1.SQL;
  //сортирует по категории, а внутри неё по результату
  MainDataset1.SQL :=
    'SELECT * from main ORDER BY category, IFNULL(sumplace,''toend''), IFNULL(sumresult,''toend'');';
  //манёвр с 'toend' чтобы результат NULL был в конце
  MainDataset1.Open;
  ExportSpreadSheet1.FileName := FileExportFull.Dialog.FileName;
  ExportSpreadSheet1.Execute;
  MainDataset1.Close;
  MainDataset1.SQL := sql;
  MainDataset1.Open;
  Log(sResultsExportedToFile + ' ' + FileExportFull.Dialog.FileName);
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
        'Port ' + Value + ' closed';
    HR_Connect: StatusBarLeft.Panels[2].Text := 'Port ' + Value + ' connected';
    HR_CanRead: StatusBarLeft.Panels[2].Text := 'CanRead : ' + Value;
    HR_CanWrite: StatusBarLeft.Panels[2].Text := 'CanWrite : ' + Value;
    HR_ReadCount: StatusBarLeft.Panels[2].Text := 'ReadCount : ' + Value;
    HR_WriteCount: StatusBarLeft.Panels[2].Text := 'WriteCount : ' + Value;
    HR_Wait: StatusBarLeft.Panels[2].Text := 'Wait : ' + Value;
  end;
end;


procedure TMainForm.Timer1Timer(Sender: TObject);
var
  pos: integer;
begin
  StatusBarLeft.Panels[0].Text := FormatDateTime('hh:nn:ss', Now);
  //это часы внизу
  if dbopen then
  begin
    //это тикающие секунды в окне "на трассе"
    pos := StatDataset2.RecNo;
    //запоминает положение курсора
    StatDataset2.RefetchData;
    StatDataset2.MoveBy(pos - 1);
    //и восстанавливает его
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

procedure TMainForm.FormResize(Sender: TObject);
var
  h, k: integer;
begin
  h := Splitter1.Top;
  k := PageControl1.Height - Splitter1.Height - sGridResult.Height -
    sGridResult.BorderSpacing.Bottom - ResultClear.Height -
    ResultClear.BorderSpacing.Bottom;
  if h > k then
  begin
    h := k;
    if CurrentSU.Visible then
      Splitter1.Top := h - CurrentSU.Height
    else
      Splitter1.Top := h;
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
  Log(sDBFileOpen + ' ' + fName);
end;

procedure TMainForm.LoRaPopupDefaultExecute(Sender: TObject);
begin
  MainForm.DatasetLoRa.Close;
  MainForm.DatasetLoRa.SQL := 'SELECT * FROM lora WHERE isset ISNULL';
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
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
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
      SQL.Text := 'UPDATE lora SET isset = 0 WHERE id = ' + id + ';';
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
        MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(sDatabaseOpenError + E.Message);
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
  MainForm.DatasetLoRa.SQL :=
    'SELECT * FROM lora WHERE starttime > "' +
    FormatDateTime('hh:nn:ss', (Now - 15 / 24 / 60)) + '";';
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
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure TMainForm.LoRaPopupShowAllExecute(Sender: TObject);
begin
  MainForm.DatasetLoRa.Close;
  MainForm.DatasetLoRa.SQL := 'SELECT * FROM lora;';
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
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure TMainForm.LoRaPopupShowFromStartExecute(Sender: TObject);
var
  minstarttime: string;
begin
  SQLQuery1.Close;
  SQLQuery1.SQL.Text := 'SELECT min(starttime' + IntToStr(CurrentStage) +
    ') as starttime FROM main WHERE starttime' + IntToStr(CurrentStage) + ' NOTNULL;';
  SQLQuery1.Open();
  minstarttime := SQLQuery1.FieldByName('starttime').AsString;
  Print(minstarttime);
  SQLQuery1.Close;
  SQLTransaction1.Active := False;
  MainForm.DatasetLoRa.Close;
  MainForm.DatasetLoRa.SQL :=
    'SELECT * FROM lora WHERE starttime > "' + minstarttime + '";';
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
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
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
  SQLQuery1.SQL.Text := 'SELECT MAX(number) as number FROM main';
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
  if MessageDlg(sDeleteNumber + ' ' + n, mtWarning, [mbYes, mbNo], 0) <> mrYes then
    abort
  else
    Log(sParticipantWithNumber + ' ' + n + ' ' + sDeleted);
end;

procedure TMainForm.CheckPenaltySetText(Sender: TField; const aText: string);
var
  t: TDateTime;
  a: string;
begin
  //Memo.Lines.Add('CheckPenaltySetText');
  a := '00:' + aText;
  if TryStrToTime(a, t) then
  begin
    Sender.AsString := FormatDateTime('hh:nn:ss', t);
  end
  else
  begin
    if TryStrToTime(aText, t) then
    begin
      Sender.AsString := FormatDateTime('hh:nn:ss', t);
    end
    else
    begin
      if aText = '' then
        Sender.AsString := ''
      else
        MessageDlg(sPenaltyTimeFormat, mtInformation, [mbOK], 0);
    end;
  end;
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
  Memo.Lines.Add(IntToStr(CurrentStage));
end;

procedure TMainForm.RecalcResultsAfterPenaltyChange(Sender: TField);
begin
  MainDataset1.ApplyUpdates;
  UpdateResults;
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
  end
  else
  begin
    RxDBGrid1.Options := RxDBGrid1.Options + [dgEditing];
    RaceModeLabel.Font.Style := RaceModeLabel.Font.Style - [fsBold];
    RaceModeLabel.Font.Color := clDefault;
  end;
end;

procedure TMainForm.RadioCurClick(Sender: TObject);
var
  c: TComponent;
  i: integer;
begin
  for i := 1 to maxstages do
  begin
    c := FindComponent('RadioCur' + IntToStr(i));
    if TRadioButton(c).Checked then
    begin
      CorrectionDatasetcorrection.FieldName := 'correction' + IntToStr(i);
      RxDBGridCorrection.Columns[1].FieldName := 'correction' + IntToStr(i);
      CorrectionDataset.SQL :=
        'SELECT * from main where correction' + IntToStr(i) +
        ' ISNULL AND status' + IntToStr(i) + ' ISNULL AND starttime' +
        IntToStr(i) + ' NOTNULL ORDER BY starttime' + IntToStr(i);
      StatDataset2.SQL := 'SELECT number, name, starttime' + IntToStr(i) +
        ' as starttime, strftime(''%H:%M:%S'',julianday(time(''now'', ''localtime'')) - julianday(time(starttime'
        + IntToStr(i) +
        ')) + 0.5) as timeontrack from main where julianday(time(''now'', ''localtime'')) > julianday(time(starttime'
        + IntToStr(i) + ')) AND finishtime' + IntToStr(i) +
        ' ISNULL AND status' + IntToStr(i) + ' ISNULL ORDER BY starttime';

      if dbopen then
      begin
        ;
        CorrectionDataset.Close;
        CorrectionDataset.Open;
        StatDataset2.Close;
        StatDataset2.Open;
      end;
    end;
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
    ComboBox1Category.Items.Clear;
    //а не делать каждый раз sql запросы
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
  end;
end;

procedure TMainForm.RxDBGridLoRaDblClick(Sender: TObject);
begin
  SetCorrectionFromLoRa;
end;

procedure TMainForm.CheckDBOpen(Sender: TObject);
begin
  TAction(Sender).Enabled := dbopen;
end;

end.
