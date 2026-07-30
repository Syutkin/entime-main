unit Implement;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, rxdbgrid, Sqlite3DS, i18n, Dialogs,
  ComCtrls, StdCtrls, strutils, sqldb, sqlite3conn, LazUTF8, Forms,
  ButtonPanel, Math, fileutil, LazFileUtils, DB, dateutils, DateTimePicker,
  opensslsockets, fphttpclient, nsCore, chsdIntf, fpcsvexport,
  fpstypes, fpspreadsheet, LCLIntf, LConvEncoding;

type
  TMessageDlgHandler = function(const Msg: string; DlgType: TMsgDlgType;
    Buttons: TMsgDlgButtons; HelpCtx: longint): integer;
  TStageSelectionHandler = function(const ACaption, APrompt: string): integer;

  { BackupThread }

  BackupThread = class(TThread)
  public
    procedure Execute; override;
  end;

procedure RefreshAll;
procedure RefreshResults;
procedure LoadConfig;
procedure LoadIniCategory;
procedure SetfName(fName: string);
procedure SetMessageDlgHandler(AHandler: TMessageDlgHandler);
procedure ResetMessageDlgHandler;
procedure SetStageSelectionHandler(AHandler: TStageSelectionHandler);
procedure ResetStageSelectionHandler;
procedure Log(msglog: string);
//procedure OpenDB;
procedure SetStatus(const status: string);
procedure SetDNS;
procedure SetDNF;
procedure SetDSQ;
procedure SetSQLStatus(const i: integer; status, n: string);
procedure SetGlobalStatus(n: string);
procedure RecalculateStatus(n: TStringList);
procedure ClearStatus;
procedure InitDB(fileName: string);
procedure SetFinish;
procedure SetCorrectionFromLoRa;
procedure UpdateResults;
procedure UpdateStageResults;
procedure UpdateSumResults;
procedure UpdateThruResults;
procedure ClearResults(silent: boolean = False);
procedure SetDNSFromCorrection;
procedure SetStarttimeFromPopup;
procedure SetDNFFromOnTrace;
procedure LoadParticipantsList(FileName: string);
procedure LoadStageResults(FileName: string);
procedure ExportFinishTime(FileName: string; stageIndex: integer);
procedure ExportAllResults(FileName: string);
procedure ExportSumDays(FileName: string);
procedure ExportAllResultsToXLSX(FileName: string);
procedure GetFinishTime(FinishTime: TDateTime);
procedure SetLoRaTime(StartTime: TDateTime; correction: string);
//procedure GenerateStartlistFromQualifier(FileName: string);
procedure ExportCSVStartList(FileName: string);
procedure ExportCSVResults(FileName: string);
procedure ParseSerial(Str: string);
procedure SQLQueryToCSV(FileName: string; Query: TSQLQuery; headers: boolean = False);
procedure AddDayResult(FileName: string);
procedure Print(Str: string);
procedure Print(Int: integer);
procedure Print(Bool: boolean);

function InputComboSelectStage(const ACaption, APrompt: string): integer;
function CatStartList: TStringList;
function GetAllStageStatus(stage: integer): TStringList;
function CountOccurrences(ASubString: string; AString: string): integer;
function CheckPenaltyInput(key: char): char;
//function ActiveStagesCount: integer;
function GetSelectedStage: integer;
function ActiveStageIndex: integer;
function IsFinishesExists(stageIndex: integer): boolean;
function BackupBD: boolean;
function HideLeadingZeroHour(Sender: TField): string;
function HideLeadingZeroHour(time: string): string;
function FormatNumber(number: integer): string;
function FormatTime(time: string): string;
function FormatDiff(diff: string; diffsign: string = ' '): string;
function FormatPlace(place: integer): string;
function FormatLEDLine(number: integer; time: string; diff: string;
  place: integer; diffsign: string = ' '): string;
function dbopen: boolean;
function dbnotempty: boolean;


implementation

uses Main, Result, Startlist, StartItemModel, CsvParser, db_sql,
  ParticipantsCsvParser, ResultsCsvParser;

  {$I include/my.inc}

var
  MessageDlgHandler: TMessageDlgHandler = nil;
  StageSelectionHandler: TStageSelectionHandler = nil;

function AskMessageDlg(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: longint): integer;
begin
  if Assigned(MessageDlgHandler) then
    Result := MessageDlgHandler(Msg, DlgType, Buttons, HelpCtx)
  else
    Result := MessageDlg(Msg, DlgType, Buttons, HelpCtx);
end;

function FormatResultsCsvError(const E: ECsvParserError): string;
var
  fieldName: string;
begin
  if E is EUnsupportedFileEncoding then
    Result := Format(rsUnsupportedFileEncoding,
      [EUnsupportedFileEncoding(E).EncodingName])
  else if E is EEmptyCsv then
    Result := rsResultsCsvEmpty
  else if E is EUnsupportedResultsColumnCount then
    Result := Format(rsUnsupportedResultsColumnCount,
      [EUnsupportedResultsColumnCount(E).ColumnCount])
  else if E is EResultsRowFieldCountMismatch then
    Result := Format(rsResultsRowFieldCountMismatch, [
      EResultsRowFieldCountMismatch(E).RowNumber,
      EResultsRowFieldCountMismatch(E).ActualFieldCount,
      EResultsRowFieldCountMismatch(E).ExpectedFieldCount
    ])
  else if E is EResultsRowsNotFound then
    Result := rsResultsRowsNotFound
  else if E is EInvalidResultParticipantNumber then
    Result := Format(rsInvalidResultParticipantNumber, [
      EInvalidResultParticipantNumber(E).NumberText,
      EInvalidResultParticipantNumber(E).RowNumber
    ])
  else if E is EDuplicateResultParticipantNumber then
    Result := Format(rsDuplicateResultParticipantNumber, [
      EDuplicateResultParticipantNumber(E).ParticipantNumber,
      EDuplicateResultParticipantNumber(E).FirstRowNumber,
      EDuplicateResultParticipantNumber(E).DuplicateRowNumber
    ])
  else if E is EInvalidResultTime then
  begin
    fieldName := EInvalidResultTime(E).FieldName;
    if SameText(fieldName, 'starttime') then
      fieldName := rsStarttime
    else if SameText(fieldName, 'finishtime') then
      fieldName := rsFinishtime;
    Result := Format(rsInvalidResultTime, [
      EInvalidResultTime(E).TimeText,
      EInvalidResultTime(E).RowNumber,
      fieldName
    ]);
  end
  else if E is EInvalidResultCorrection then
    Result := Format(rsInvalidResultCorrection, [
      EInvalidResultCorrection(E).CorrectionText,
      EInvalidResultCorrection(E).RowNumber
    ])
  else if E is EInvalidResultPenalty then
    Result := Format(rsInvalidResultPenalty, [
      EInvalidResultPenalty(E).PenaltyText,
      EInvalidResultPenalty(E).RowNumber
    ])
  else if E is EInvalidResultStatus then
    Result := Format(rsInvalidResultStatus, [
      EInvalidResultStatus(E).StatusText,
      EInvalidResultStatus(E).RowNumber
    ])
  else
    Result := E.Message;
end;

function FormatParticipantsCsvError(const E: ECsvParserError): string;
begin
  if E is EUnsupportedFileEncoding then
    Result := Format(rsUnsupportedFileEncoding,
      [EUnsupportedFileEncoding(E).EncodingName])
  else if E is EEmptyCsv then
    Result := rsParticipantsCsvEmpty
  else if E is ENumberColumnNotFound then
    Result := rsNumberColumnNotFound
  else if E is EMultipleNumberColumns then
    Result := Format(rsMultipleNumberColumns,
      [EMultipleNumberColumns(E).ColumnCount])
  else if E is EEmptyColumnName then
    Result := Format(rsEmptyParticipantColumnName,
      [EEmptyColumnName(E).ColumnIndex])
  else if E is EDuplicateColumnName then
    Result := Format(rsDuplicateParticipantColumnName,
      [EDuplicateColumnName(E).ColumnName])
  else if E is EParticipantRowsNotFound then
    Result := rsParticipantRowsNotFound
  else if E is ERowFieldCountMismatch then
    Result := Format(rsParticipantRowFieldCountMismatch, [
      ERowFieldCountMismatch(E).RowNumber,
      ERowFieldCountMismatch(E).ActualFieldCount,
      ERowFieldCountMismatch(E).ExpectedFieldCount
    ])
  else if E is EInvalidParticipantNumber then
    Result := Format(rsInvalidParticipantNumber, [
      EInvalidParticipantNumber(E).NumberText,
      EInvalidParticipantNumber(E).RowNumber
    ])
  else if E is EInvalidParticipantStartTime then
    Result := Format(rsInvalidParticipantStartTime, [
      EInvalidParticipantStartTime(E).TimeText,
      EInvalidParticipantStartTime(E).RowNumber,
      EInvalidParticipantStartTime(E).ColumnName
    ])
  else if E is EDuplicateParticipantNumber then
    Result := Format(rsDuplicateParticipantNumber, [
      EDuplicateParticipantNumber(E).ParticipantNumber,
      EDuplicateParticipantNumber(E).FirstRowNumber,
      EDuplicateParticipantNumber(E).DuplicateRowNumber
    ])
  else
    Result := E.Message;
end;

// https://www.freepascal.org/docs-html/current/fcl/db/tdataset.refresh.html
// https://forum.lazarus.freepascal.org/index.php?topic=38564.0
procedure RefreshAll;
var
  n, row, id: integer;
  c: TComponent;
  db: boolean;
begin
  db := dbnotempty;
  if db then
  begin
    //запоминаем положение курсора в датасете
    id := MainForm.RxDBGrid1.DataSource.DataSet.Fields.FieldByName('id').Value;
    //и основном гриде (GetRow из MyDBGrid)
    row := MainForm.RxDBGrid1.GetRow;
  end;
  for n := 0 to MainForm.ComponentCount - 1 do
  begin
    c := MainForm.Components[n];
    if c is TSqlite3Dataset then
    begin
      try
        if TSqlite3Dataset(c).Active then
        begin
          TSqlite3Dataset(c).RefetchData;
        end
        else
        begin
          TSqlite3Dataset(c).Open;
        end;
      except
        On E: Exception do
        begin
          MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
          Log(rsDatabaseOpenError + E.Message);
        end;
      end;
    end;
  end;
  RefreshResults;
  if db then
  begin
    //восстанавливаем положение курсора
    MainForm.MainDataset1.Locate('id', id, []);
    //и основного грида после открытия
    //(на остальные забили)
    MainForm.RxDBGrid1.DataSource.DataSet.MoveBy(-row + 1);
    MainForm.RxDBGrid1.DataSource.DataSet.MoveBy(row - 1);
  end;
end;

procedure RefreshResults;
var
  n: integer;
  c: TComponent;
begin
  for n := 0 to ResultsForm.ComponentCount - 1 do
  begin
    c := ResultsForm.Components[n];
    if c is TSqlite3Dataset then
    begin
      try
        if TSqlite3Dataset(c).Active then
        begin
          TSqlite3Dataset(c).RefetchData;
        end
        else
        begin
          TSqlite3Dataset(c).Open;
        end;
      except
        On E: Exception do
        begin
          MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
          Log(rsDatabaseOpenError + E.Message);
        end;
      end;
    end;
  end;
end;

procedure LoadConfig;
var
  c: TComponent;
  i: integer;
  iStr: string;
begin
  Screen.Cursor := crHourGlass;
  try
    //пока датасеты закрыты, проверяем наличие файла соревнований
    if FileExists(fName) then
    begin
      raceName := TConfigSql.GetString(MainForm.SQLQuery1, 'racename', '');

      for i := 1 to VISIBLECAT do
      begin
        cat[i] := TConfigSql.GetString(MainForm.SQLQuery1, 'catname' + IntToStr(i), '');
      end;
      for i := 1 to maxstages do
      begin
        stages[i].isActive := TConfigSql.GetBool(MainForm.SQLQuery1,
          'stage' + IntToStr(i), False);
        stages[i].Name := TConfigSql.GetString(MainForm.SQLQuery1,
          'stagename' + IntToStr(i), '');
      end;
      astage := TConfigSql.GetString(MainForm.SQLQuery1, 'activestage', '1');

      //MainForm.SQLQuery1.Close;
      //MainForm.SQLQuery1.SQL.Text :=
      //  'SELECT * FROM config WHERE key = "timemark";';
      //MainForm.SQLQuery1.Open();
      //timemark := MainForm.SQLQuery1.FieldByName('value').AsString;
      //MainForm.SQLQuery1.Close;
      //MainForm.SQLQuery1.SQL.Text :=
      //  'SELECT * FROM config WHERE key = "timemarkstr";';
      //MainForm.SQLQuery1.Open();
      //timemarkstr := MainForm.SQLQuery1.FieldByName('value').AsString;
      //MainForm.SQLQuery1.Close;
      //MainForm.SQLQuery1.SQL.Text :=
      //  'SELECT * FROM config WHERE key = "timemarkformat";';
      //MainForm.SQLQuery1.Open();
      //timemarkformat := MainForm.SQLQuery1.FieldByName('value').AsString;

      MainForm.SQLQuery1.Close;
      MainForm.SQLTransaction1.Active := False;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;

  //  RxIniPropStorage1.Restore;

  if stages[1].Name = '' then
    stages[1].Name := rsSU1;
  if stages[2].Name = '' then
    stages[2].Name := rsSU2;
  if stages[3].Name = '' then
    stages[3].Name := rsSU3;
  if stages[4].Name = '' then
    stages[4].Name := rsSU4;
  if stages[5].Name = '' then
    stages[5].Name := rsSU5;
  if stages[6].Name = '' then
    stages[6].Name := rsSU6;
  if stages[7].Name = '' then
    stages[7].Name := rsSU7;
  if stages[8].Name = '' then
    stages[8].Name := rsSU8;

  for i := 1 to maxstages do
  begin
    c := MainForm.FindComponent('SheetStage' + IntToStr(i));
    TTabSheet(c).Caption := stages[i].Name;

    with MainForm.GridResultStageSum do
    begin
      ColumnByFieldName('result' + IntToStr(i)).Title.Caption := stages[i].Name;
      if stages[i].isActive then
      begin
        ColumnByFieldName('result' + IntToStr(i)).Visible := True;
      end
      else
      begin
        ColumnByFieldName('result' + IntToStr(i)).Visible := False;
      end;
    end;

    with MainForm.RxDBGrid1 do
    begin
      //ставим названия
      ColumnByFieldName('correction' + IntToStr(i)).Title.Caption :=
        stages[i].Name + '|' + rsCorrection;
      ColumnByFieldName('starttime' + IntToStr(i)).Title.Caption :=
        stages[i].Name + '|' + rsStarttime;
      ColumnByFieldName('finishtime' + IntToStr(i)).Title.Caption :=
        stages[i].Name + '|' + rsFinishtime;
      ColumnByFieldName('penalty' + IntToStr(i)).Title.Caption :=
        stages[i].Name + '|' + rsPenalty;
      ColumnByFieldName('result' + IntToStr(i)).Title.Caption :=
        stages[i].Name + '|' + rsResult;
      ColumnByFieldName('diffleader' + IntToStr(i)).Title.Caption :=
        stages[i].Name + '|' + rsDiffleader;
      ColumnByFieldName('place' + IntToStr(i)).Title.Caption :=
        stages[i].Name + '|' + rsPlace;
    end;
    //скрываем неиспользуемые СУ
    if stages[i].isActive then
    begin
      with MainForm.RxDBGrid1 do
      begin
        ColumnByFieldName('correction' + IntToStr(i)).Visible := True;
        ColumnByFieldName('starttime' + IntToStr(i)).Visible := True;
        ColumnByFieldName('finishtime' + IntToStr(i)).Visible := True;
        ColumnByFieldName('penalty' + IntToStr(i)).Visible := True;
        ColumnByFieldName('result' + IntToStr(i)).Visible := True;
        ColumnByFieldName('diffleader' + IntToStr(i)).Visible := True;
        ColumnByFieldName('place' + IntToStr(i)).Visible := True;
      end;
      MainForm.CurrentSU.Buttons[i - 1].Enabled := True;
      c := MainForm.FindComponent('SheetStage' + IntToStr(i));
      TTabSheet(c).TabVisible := True;
    end
    else
    begin
      with MainForm.RxDBGrid1 do
      begin
        ColumnByFieldName('correction' + IntToStr(i)).Visible := False;
        ColumnByFieldName('starttime' + IntToStr(i)).Visible := False;
        ColumnByFieldName('finishtime' + IntToStr(i)).Visible := False;
        ColumnByFieldName('penalty' + IntToStr(i)).Visible := False;
        ColumnByFieldName('result' + IntToStr(i)).Visible := False;
        ColumnByFieldName('diffleader' + IntToStr(i)).Visible := False;
        ColumnByFieldName('place' + IntToStr(i)).Visible := False;
      end;
      MainForm.CurrentSU.Buttons[i - 1].Enabled := False;
      c := MainForm.FindComponent('SheetStage' + IntToStr(i));
      TTabSheet(c).TabVisible := False;
    end;
  end;

  //настройка для работы с одним этапом
  if stages.ActiveStagesCount = 1 then
  begin
    iStr := IntToStr(stages.FirstActiveStage.Key);
    MainForm.CurrentSU.Visible := False;
    MainForm.CurrentSU.ItemIndex := stages.FirstActiveStage.Key - 1;
    MainForm.SheetStageSum.TabVisible := False;
    MainForm.SheetStage1.Caption := rsTotal;
    MainForm.GridResultStageSum.ColumnByFieldName('result' + iStr).Visible := False;
    with MainForm.RxDBGrid1 do
    begin
      if not showStageNameForSingleStage then
      begin
        ColumnByFieldName('correction' + iStr).Title.Caption := rsCorrection;
        ColumnByFieldName('starttime' + iStr).Title.Caption := rsStarttime;
        ColumnByFieldName('finishtime' + iStr).Title.Caption := rsFinishtime;
        ColumnByFieldName('penalty' + iStr).Title.Caption := rsPenalty;
        ColumnByFieldName('result' + iStr).Title.Caption := rsResult;
        ColumnByFieldName('diffleader' + iStr).Title.Caption := rsDiffleader;
        ColumnByFieldName('place' + iStr).Title.Caption := rsPlace;
      end;
      ColumnByFieldName('place' + iStr).Visible := False;
      //RxDBGrid1.ColumnByFieldName('sumresult').Visible:=false;
      //RxDBGrid1.ColumnByFieldName('sumdiffleader').Visible:=false;
      ColumnByFieldName('sumresult').Visible := True;
      ColumnByFieldName('sumdiffleader').Visible := True;
      ColumnByFieldName('result' + iStr).Visible := False;
      ColumnByFieldName('diffleader' + iStr).Visible := False;
    end;
  end
  else
  begin
    MainForm.CurrentSU.Visible := True;
    MainForm.RxDBGrid1.ColumnByFieldName('sumresult').Visible := True;
    MainForm.RxDBGrid1.ColumnByFieldName('sumdiffleader').Visible := True;
    MainForm.SheetStageSum.TabVisible := True;
  end;

  // Перестраиваем таблицу после показа или скрытия выбора текущего СУ.
  MainForm.RxDBGridCorrection.Parent.ReAlign;

  // Если активных СУ больше одного, включаем показ кол-ва пройденных СУ
  // в сквозном протоколе
  if stages.ActiveStagesCount > 1 then
    (MainForm.FindComponent('GridResultStageTotal') as
      TRxDBGrid).ColumnByFieldName('sumstages').Visible := True
  else
    (MainForm.FindComponent('GridResultStageTotal') as
      TRxDBGrid).ColumnByFieldName('sumstages').Visible := False;

  // Если текущий выбранный СУ неактивен, то выбираем первый активный СУ
  with MainForm.CurrentSU do
  begin
    if not Buttons[ItemIndex].Enabled and (stages.FirstActiveStage.Key > 0) then
      Buttons[stages.FirstActiveStage.Key - 1].Checked := True;
  end;

  Screen.Cursor := crDefault;
end;

procedure LoadIniCategory;
var
  c: TComponent;
  i: integer;
begin
  for i := 1 to VISIBLECAT do
  begin
    c := ResultsForm.FindComponent('GroupBox' + IntToStr(i));
    TGroupBox(c).Caption := cat[i];
    c := ResultsForm.FindComponent('CatDataset' + IntToStr(i));
    TSqlite3Dataset(c).Close;
    TSqlite3Dataset(c).SQL :=
      'Select number, name, result' + astage + ' as result, diffleader' +
      astage + ' as diffleader, place' + astage +
      ' as place from main WHERE category = ' + '''' + cat[i] + '''' +
      ' AND result' + astage + ' > 0 ORDER BY status ASC, result' + astage + ' ASC';
  end;
  ResultsForm.ResultDataset.Close;
  ResultsForm.ResultDataset.SQL :=
    'Select number, name, category, result' + astage + ' as result, place' +
    astage + ' as place from main WHERE finishtime' + astage +
    ' > 0 AND status ISNULL ORDER BY finishtime' + astage + ' DESC';
  ResultsForm.GroupBoxResults.Caption :=
    rsCurrentResults + ': ' + stages[StrToInt(astage)].Name;
end;

procedure SetfName(fName: string);
var
  n: integer;
  c: TComponent;
begin
  for n := 0 to MainForm.ComponentCount - 1 do
  begin
    c := MainForm.Components[n];
    if c is TSqlite3Dataset then
    begin
      TSqlite3Dataset(c).FileName := fName;
    end;
    if c is TSQLite3Connection then
    begin
      TSQLite3Connection(c).Close;
      TSQLite3Connection(c).DatabaseName := fName;
    end;
    if c is TSQLTransaction then
    begin
      TSQLTransaction(c).Active := False;
    end;
    if c is TSQLQuery then
    begin
      TSQLQuery(c).Close;
    end;
  end;
  for n := 0 to ResultsForm.ComponentCount - 1 do
  begin
    c := ResultsForm.Components[n];
    if c is TSqlite3Dataset then
    begin
      TSqlite3Dataset(c).FileName := fName;
    end;
  end;
  MainForm.Caption := NAME_VERSION + ' ' + fName;
  MainForm.HistoryFiles1.UpdateList(fName);
end;

procedure SetMessageDlgHandler(AHandler: TMessageDlgHandler);
begin
  MessageDlgHandler := AHandler;
end;

procedure ResetMessageDlgHandler;
begin
  MessageDlgHandler := nil;
end;

procedure SetStageSelectionHandler(AHandler: TStageSelectionHandler);
begin
  StageSelectionHandler := AHandler;
end;

procedure ResetStageSelectionHandler;
begin
  StageSelectionHandler := nil;
end;

procedure Log(msglog: string);
begin
  msglog := FormatDateTime('hh:nn:ss', now) + ' ' + msglog;
  MainForm.ComboBoxLog.Items.Add(msglog);
  MainForm.ComboBoxLog.Text := msglog;
end;

//procedure OpenDB;
//begin
//  //присваиваем имя файла дб датасетам
//  //SetfName(fName);
//  LoadConfig;
//  LoadIniCategory;
//  // --> close-open dataset в Main и затем в settings (RefreshResults)
//  RefreshAll;
//  Log(rsDBFileOpen + ' ' + fName);
//end;

procedure SetStatus(const status: string);
var
  n: string;
begin
  if dbnotempty then
  begin
    n := MainForm.MainDataset1.FieldByName('number').AsString;
    SetSQLStatus(GetSelectedStage, status, n);
  end;
end;

procedure SetDNS;
begin
  SetStatus('DNS');
end;

procedure SetDNF;
begin
  SetStatus('DNF');
end;

procedure SetDSQ;
begin
  SetStatus('DSQ');
end;

procedure SetSQLStatus(const i: integer; status, n: string);
//устанавливает статус в БД для номера "n" на СУ "i"
var
  d, l, s, logstatus: string;
begin
  try
    if status <> 'DSQ' then
    begin
      if status = 'DNS' then
      begin
        s := '2';
        logstatus := rsDidNotStart;
      end
      else
      begin
        s := '1';
        logstatus := rsDidNotFinish;
      end;
      if (not stages[2].isActive) and (not stages[3].isActive) and
        (not stages[4].isActive) and (not stages[5].isActive) and
        (not stages[6].isActive) and (not stages[7].isActive) and
        (not stages[8].isActive) then
      begin
        d := rsSureWithNumber + ' ' + n + ' ' + logstatus + '?';
        l := rsParticipantWithNumber + ' ' + n + ' ' + logstatus;
      end
      else
      begin
        if rsSU + ' ' + IntToStr(i) = stages[i].Name then
        begin
          d := rsSureWithNumber + ' ' + n + ' ' + logstatus + ' ' +
            rsOnStage + ' ' + IntToStr(i) + '?';
          l := rsParticipantWithNumber + ' ' + n + ' ' + logstatus +
            ' ' + rsOnStage + ' ' + IntToStr(i);
        end
        else
        begin
          d := rsSureWithNumber + ' ' + n + ' ' + logstatus + ' ' +
            rsOnStage + ' ' + IntToStr(i) + ': ' + stages[i].Name + '?';
          l := rsParticipantWithNumber + ' ' + n + ' ' + logstatus +
            ' ' + rsOnStage + ' ' + IntToStr(i) + ': ' + stages[i].Name;
        end;
      end;
      if MessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
      begin
        TMainSql.ExecUpdateStageStatus(MainForm.SQLQuery1, i, status, s, n);
        SetGlobalStatus(n);
        UpdateResults;
        Log(l);
      end;
    end
    else
    begin
      if MessageDlg(rsReallyDisqualifyNumber + ' ' + n + '?', mtWarning,
        [mbYes, mbNo], 0) = mrYes then
      begin
        TMainSql.ExecUpdateOnlyGlobalStatusDsq(MainForm.SQLQuery1, n);
        UpdateResults;
        Log(rsParticipantWithNumber + ' ' + n + ' ' + rsDisqualified);
      end;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure SetGlobalStatus(n: string);
//высчитывает глобальный статус (status) на основе статусов СУ
var
  stat: string = 'NULL';
  // 8 = MAXSTAGES
  st: array[0..8] of integer;
  k: integer;
begin
  try
    with MainForm.SQLQuery1 do
    begin
      TMainSql.OpenByNumber(MainForm.SQLQuery1, StrToIntDef(n, 0));
      if FieldByName('status').AsString <> '3' then
      begin
        //если не общий дисквал, то считаем
        for k := 1 to maxstages do
        begin
          if stages[k].isActive then
          begin
            if FieldByName('status' + IntToStr(k)).AsString <> '' then
            begin
              st[k] := FieldByName('status' + IntToStr(k)).AsInteger;
            end
            else
              st[k] := 0;
            if (k = 1) and (st[k] = 2) then
              stat := '2';
            if (k = 1) and (st[k] = 1) then
              stat := '1';
            if (k >= 2) and (st[k] > 0) and (stat = 'NULL') then
              stat := '1';
          end;
        end;
        TMainSql.ExecUpdateGlobalStatus(MainForm.SQLQuery1, stat, n);
      end;
      Close;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure RecalculateStatus(n: TStringList);
var
  i: integer;
begin
  if dbnotempty then
  begin
    try
      for i := 0 to n.Count - 1 do
      begin
        SetGlobalStatus(n[i]);
      end;
    finally
      n.Free;
    end;
  end;
end;

procedure ClearStatus;
var
  n, d, l: string;
  i: integer = 1;
  co: integer;
begin
  try
    if dbnotempty then
    begin
      co := MainForm.RxDBGrid1.SelectedIndex;
      n := MainForm.MainDataset1.FieldByName('number').AsString;
      if (not stages[2].isActive) and (not stages[3].isActive) and
        (not stages[4].isActive) and (not stages[5].isActive) and
        (not stages[6].isActive) and (not stages[7].isActive) and
        (not stages[8].isActive) then
      begin
        d := rsClearAllStatus + ' ' + n + '?';
        l := rsClearAllStatusLog + ' ' + n;
        if MessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          TMainSql.ExecClearStatusAllForStage(MainForm.SQLQuery1, i, n);
          SetGlobalStatus(n);
          UpdateResults;
          Log(l);
          Print('1');
        end;
      end
      else
      // выделение в общих результатах
      if (co > COMMON_COLS + STAGE_COLS * maxstages) then
      begin
        d := rsClearDSQ + ' ' + n + '?';
        l := rsClearDSQLog + ' ' + n;
        if MessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          TMainSql.ExecClearOnlyGlobalStatus(MainForm.SQLQuery1, n);
          SetGlobalStatus(n);
          UpdateResults;
          Log(l);
          Print('2');
        end;
      end
      else
      begin
        i := GetSelectedStage;
        if rsSU + ' ' + IntToStr(i) = stages[i].Name then
        begin
          d := rsClearStatus + ' ' + n + ' ' + rsOnStage + ' ' + IntToStr(i) + '?';
          l := rsClearStatusLog + ' ' + n + ' ' + rsOnStage + ' ' + IntToStr(i);
        end
        else
        begin
          d := rsClearStatus + ' ' + n + ' ' + rsOnStage + ' ' +
            IntToStr(i) + ': ' + stages[i].Name + '?';
          l := rsClearStatusLog + ' ' + n + ' ' + rsOnStage + ' ' +
            IntToStr(i) + ': ' + stages[i].Name;
        end;
        if MessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          TMainSql.ExecClearStageStatus(MainForm.SQLQuery1, i, n);
          SetGlobalStatus(n);
          UpdateResults;
          Log(l);
          Print('3');
        end;
      end;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure InitDB(fileName: string);
begin
  fName := fileName;
  //присваиваем имя файла дб датасетам
  SetfName(fName);
  try
    if not FileExists(fName) then
    begin
      //если файл не существует - создаём
      Screen.Cursor := crSQLWait;
      //если существует, то открываем (ниже где DatabaseOpen;)
      try
        MainForm.SQLite3Connection1.Open;
        MainForm.SQLTransaction1.Active := True;
        TSchemaSql.ExecCreateTables(MainForm.SQLite3Connection1, MAXSTAGES,
          rsCat1, rsCat2, rsCat3, rsCat4, rsCat5, ExtractFileNameOnly(fName));
        MainForm.SQLTransaction1.Active := False;
        Log(rsNewFileCreated + ': ' + fName);
      except
        MainForm.SQLTransaction1.Active := False;
        MessageDlg(rsNewFileNotCreated, mtError, [mbOK], 0);
        Log(rsNewFileNotCreated);
        Screen.Cursor := crDefault;
        // Если файл не создан, не пытаемся его открыть
        Exit;
      end;
      Screen.Cursor := crDefault;
    end;

    //OpenDB;
    LoadConfig;
    LoadIniCategory;
    // --> close-open dataset в Main и затем в settings (RefreshResults)
    RefreshAll;
    Log(rsDBFileOpen + ' ' + fName);
  except
    MessageDlg(rsNewFileExistUnknow, mtError, [mbOK], 0);
    Log(rsNewFileExistUnknow);
  end;
end;

procedure SetFinish;
var
  row, number, leadernumber, currentplace, i: integer;
  setfinish: boolean = False;
  checkedStages: array of integer;
  currentresult, bottomline, currentcategory, st, leaderresult, upperline, pName: string;
  currentdiff: string = '';

  //Отправка в телегу
  QueryParams: TStrings = nil;
  AURL: string;
  s: string = '';
  item: string;
  l: TStringstream;
  http: tfphttpclient;
begin
  Screen.Cursor := crSQLWait;
  checkedStages := nil;
  try
    try
      for row := MainForm.sGridResult.RowCount - 1 downto 1 do
      begin
        if (TryStrToInt(MainForm.sGridResult.Cells[1, row], number)) and
          (number > 0) then
        begin
          if TMainSql.OpenByNumber(MainForm.SQLQuery1, number) then
          begin
            //проверяем что номер есть в таблице результатов
            MainForm.SQLQuery2.Active := False;
            MainForm.SQLQuery2.SQL.Text :=
              StringReplace(MainForm.StatDataset2.SQL, 'ORDER BY starttime',
              'AND number = :NUMBER;', []);
            //  MainForm.StatDataset2.SQL + ' AND number = :NUMBER;';
            MainForm.SQLQuery2.ParamByName('NUMBER').AsInteger := number;
            MainForm.SQLQuery2.Active := True;
            if MainForm.SQLQuery2.FieldByName('number').AsInteger <> number then
            begin
              //проверяем что номер в данный момент находится на трассе
              if MessageDlg(rsNumber + ' ' + IntToStr(number) + ' ' +
                rsDidNotStartSetFinish, mtWarning, [mbYes, mbNo], 0) = mrYes then
                setfinish := True
              else
                setfinish := False;
            end
            else
              setfinish := True;
            MainForm.SQLQuery2.Active := False;
            for i := 1 to maxstages do
            begin
              if MainForm.CurrentSU.Buttons[i - 1].Checked and setfinish then
              begin
                //проверяем в какой этап заносить результат
                if MainForm.SQLQuery1.FieldByName('result' +
                  IntToStr(i)).AsString <> '' then
                begin
                  if MessageDlg(rsUpdateFinishTime + ' ' + IntToStr(number) +
                    '?', mtWarning, [mbYes, mbNo], 0) = mrYes then
                    setfinish := True
                  else
                    setfinish := False;
                end
                else
                  setfinish := True;
              end;
            end;
            if setfinish then
            begin
              //сначала определяем номер и результат текущего лидера категории для LED панели или телеграм бота
              if Mainform.AcLEDPanel.Checked or Mainform.AcTelegramBot.Checked then
              begin
                st := IntToStr(ActiveStageIndex);
                currentcategory := MainForm.SQLQuery1.FieldByName('category').AsString;
                pName := MainForm.SQLQuery1.FieldByName('name').AsString;
                TMainSql.OpenByCategoryLeader(MainForm.SQLQuery1,
                  ActiveStageIndex, currentcategory);
                leaderresult := MainForm.SQLQuery1.FieldByName('result' + st).AsString;
                leadernumber := MainForm.SQLQuery1.FieldByName('number').AsInteger;
              end;

              SetLength(checkedStages, 0);
              for i := 1 to maxstages do
              begin
                if MainForm.CurrentSU.Buttons[i - 1].Checked then
                begin
                  SetLength(checkedStages, Length(checkedStages) + 1);
                  checkedStages[High(checkedStages)] := i;
                end;
              end;
              TMainSql.ExecUpdateFinishForCheckedStages(
                MainForm.SQLQuery1,
                checkedStages,
                MainForm.sGridResult.Cells[0, row],
                number
                );
              //ставим время финиша для номера
              UpdateResults;
              //ставим результат
              MainForm.sGridResult.DeleteRow(row);
              Log(rsFinishTimeSet + ' ' + IntToStr(number));

              //если используется LED панель или телеграм бот, добываем для них данные
              if Mainform.AcLEDPanel.Checked or Mainform.AcTelegramBot.Checked then
              begin
                //результаты текущего участника
                TMainSql.OpenByNumber(MainForm.SQLQuery1, number);

                currentresult := MainForm.SQLQuery1.FieldByName('result' + st).AsString;
                currentplace := MainForm.SQLQuery1.FieldByName('place' + st).AsInteger;

                //если текущий участник занял первое место
                if currentplace = 1 then
                begin

                  // ToDo: фоматирование

                  //результаты лидера категории для определения, насколько обогнал предыдущего лидера текущий участник
                  if leadernumber > 0 then
                  begin
                    TMainSql.OpenByNumber(MainForm.SQLQuery1, leadernumber);
                    currentdiff :=
                      MainForm.SQLQuery1.FieldByName('diffleader' + st).AsString;

                    //формируем верхнюю строку (текущий участник-лидер)
                    //upperline := FormatLEDLine(number, currentresult, currentdiff, currentplace, '-');
                    //bottomline := FormatLEDLine(leadernumber, leaderresult, '', 2);
                  end
                  else
                  begin
                    //upperline := FormatLEDLine(number, currentresult, '', currentplace);
                    //bottomline := '';
                  end;
                end
                //если текущий участник НЕ занял первое место
                else
                begin
                  //  upperline := FormatLEDLine(leadernumber, leaderresult, '', 1);
                  currentdiff :=
                    MainForm.SQLQuery1.FieldByName('diffleader' + st).AsString;
                  //  bottomline := FormatLEDLine(number, currentresult, currentdiff, currentplace);
                end;
              end;

              //если используется LED панель, отправляем в неё данные
              if Mainform.AcLEDPanel.Checked then
              begin
                if MainForm.DataPortHTTP1.Active then
                  MainForm.DataPortHTTP1.Close();
                //результаты текущего участника
                //MainForm.SQLQuery1.Active := False;
                //MainForm.SQLQuery1.SQL.Text :=
                //  'select * from main where number = :NUMBER;';
                //MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := number;
                //MainForm.SQLQuery1.Active := True;

                //currentresult := MainForm.SQLQuery1.FieldByName('result' + st).AsString;
                //currentplace := MainForm.SQLQuery1.FieldByName('place' + st).AsInteger;

                //если текущий участник занял первое место
                if currentplace = 1 then
                begin

                  // ToDo: фоматирование

                  //результаты лидера категории для определения, насколько обогнал предыдущего лидера текущий участник
                  if leadernumber > 0 then
                  begin
                    //MainForm.SQLQuery1.Active := False;
                    //MainForm.SQLQuery1.SQL.Text :=
                    //  'select * from main where number = ' + IntToStr(leadernumber) + ';';
                    //MainForm.SQLQuery1.Active := True;
                    //currentdiff := MainForm.SQLQuery1.FieldByName('diffleader' + st).AsString;

                    //формируем верхнюю строку (текущий участник-лидер)
                    upperline :=
                      FormatLEDLine(number, currentresult, currentdiff,
                      currentplace, '-');
                    bottomline := FormatLEDLine(leadernumber, leaderresult, '', 2);
                  end
                  else
                  begin
                    upperline := FormatLEDLine(number, currentresult, '', currentplace);
                    bottomline := '';
                  end;
                end
                //если текущий участник НЕ занял первое место
                else
                begin
                  upperline := FormatLEDLine(leadernumber, leaderresult, '', 1);
                  //currentdiff := MainForm.SQLQuery1.FieldByName('diffleader' + st).AsString;
                  bottomline :=
                    FormatLEDLine(number, currentresult, currentdiff, currentplace);
                end;

                MainForm.DataPortHTTP1.Params.Clear;
                MainForm.DataPortHTTP1.Params.Add('upperline=' + upperline);
                MainForm.DataPortHTTP1.Params.Add('bottomline=' + bottomline);
                Print(MainForm.DataPortHTTP1.Params.Text);
                Print(MainForm.DataPortHTTP1.Url);
                MainForm.DataPortHTTP1.Open();
                MainForm.DataPortHTTP1.Push('');
              end;

              //если хотим отправлять данные в бота телеги
              if Mainform.AcTelegramBot.Checked then
              begin
                //if MainForm.DataPortHTTPTelegramBot.Active then
                //  MainForm.DataPortHTTPTelegramBot.Close();
                //если текущий участник занял первое место
                if currentplace = 1 then
                begin
                  //результаты лидера категории для определения, насколько обогнал предыдущего лидера текущий участник
                  if leadernumber > 0 then
                  begin
                    // Участник кого-то обогнал
                    //upperline := FormatLEDLine(number, currentresult, currentdiff, currentplace, '-');
                    //bottomline := FormatLEDLine(leadernumber, leaderresult, '', 2);
                    currentdiff := FormatDiff(currentdiff, '-');
                  end
                  else
                  begin
                    // Участник первый финишировавший
                    //upperline := FormatLEDLine(number, currentresult, '', currentplace);
                    //bottomline := '';
                  end;
                end
                //если текущий участник НЕ занял первое место
                else
                begin
                  //upperline := FormatLEDLine(leadernumber, leaderresult, '', 1);
                  currentdiff :=
                    MainForm.SQLQuery1.FieldByName('diffleader' + st).AsString;
                  currentdiff := FormatDiff(currentdiff, '');
                  //bottomline := FormatLEDLine(number, currentresult, currentdiff, currentplace);
                end;

                // отправка данных в телегу
                l := TStringStream.Create('');
                http := tfphttpclient.Create(nil);
                with http do
                try
                  QueryParams := TStringList.Create;
                  //AddHeader('Authorization', 'AccessToken MjtAFOrgYUrsfCC7KPLpAi03N4Od17Bh');
                  //AddHeader('X-User-Authorization', 'Basic aW5mb0BzcG1hc2gucnU6NTE0NzU4');
                  //AddHeader('Content-Type', 'application/json;charset=UTF-8');
                  with QueryParams do
                  begin
                    if not IntToStr(number).IsEmpty then
                      Values['number'] := EncodeURLElement(IntToStr(number));
                    if not pName.IsEmpty then
                      Values['name'] := EncodeURLElement(pName);
                    if not currentcategory.IsEmpty then
                      Values['category'] := EncodeURLElement(currentcategory);
                    if not currentresult.IsEmpty then
                      Values['result'] := EncodeURLElement(FormatTime(currentresult));
                    if not currentdiff.IsEmpty then
                      Values['diff'] := EncodeURLElement(currentdiff);
                    if not IntToStr(currentplace).IsEmpty then
                      Values['place'] := EncodeURLElement(IntToStr(currentplace));
                  end;
                  AURL := telegrambotadress;
                  for item in QueryParams do
                    s := s + '&' + item;
                  AURL := AURL + '?' + s.Substring(1);
                  try
                    httpmethod('GET', AURL, l, []);
                  except
                    On E: Exception do
                    begin
                      //MessageDlg(rsTelegramBotSendingError + E.Message, mtError, [mbOK], 0);
                      Log(rsTelegramBotSendingError + E.Message);
                    end;
                  end;
                  Print(IntToStr(ResponseStatusCode) + ' ' +
                    ResponseStatusText);
                  Print(ResponseHeaders.Text);
                  Print(l.DataString);

                finally
                  Free;
                  QueryParams.Free;
                  l.Free;
                end;

                //end;

                //MainForm.DataPortHTTPTelegramBot.Params.Clear;
                //MainForm.DataPortHTTPTelegramBot.Params.Add('number=' + IntToStr(number));
                //MainForm.DataPortHTTPTelegramBot.Params.Add('name=' + name);
                //MainForm.DataPortHTTPTelegramBot.Params.Add('category=' + currentcategory);
                //MainForm.DataPortHTTPTelegramBot.Params.Add('result=' + FormatTime(currentresult));
                //MainForm.DataPortHTTPTelegramBot.Params.Add('diff=' + currentdiff);
                //MainForm.DataPortHTTPTelegramBot.Params.Add('place=' + IntToStr(currentplace));

                //Print(MainForm.DataPortHTTPTelegramBot.Params.Text);
                //Print(MainForm.DataPortHTTPTelegramBot.Url);
                //MainForm.DataPortHTTPTelegramBot.Open();
                //MainForm.DataPortHTTPTelegramBot.Push('');
              end;
            end;
          end
          else
            Log(rsNumber + ' ' + IntToStr(number) + ' ' + rsDoNotExist);
        end;
      end;
    except
      On E: Exception do
      begin
        MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(rsDatabaseOpenError + E.Message);
      end;
    end;
  finally
    MainForm.SQLQuery1.Active := False;
    MainForm.SQLQuery2.Active := False;
    MainForm.SQLTransaction1.Active := False;
    Screen.Cursor := crDefault;
  end;
end;

procedure SetCorrectionFromLoRa;
var
  n, correction, id: string;
  setcorrection: boolean;
  numberValue, correctionValue, idValue: integer;
begin
  if dbopen and not MainForm.DatasetLoRa.IsEmpty then
  begin
    n := MainForm.DatasetLoRa.FieldByName('number').AsString;
    correction := MainForm.DatasetLoRa.FieldByName('correction').AsString;
    id := MainForm.DatasetLoRa.FieldByName('id').AsString;
    if n <> '' then
    begin
      numberValue := StrToIntDef(n, 0);
      correctionValue := StrToIntDef(correction, 0);
      idValue := StrToIntDef(id, 0);
      if TMainSql.OpenByNumber(MainForm.SQLQuery1, numberValue) then
      begin
        if MainForm.SQLQuery1.FieldByName('correction' + IntToStr(
          ActiveStageIndex)).AsString = '' then
          //если поправки нет
        begin
          setcorrection := True;
        end
        else
          //если поправка есть спрашиваем переписать или нет
        begin
          if MessageDlg(rsNumberu + ' ' + n + ' ' + rsCorrectionAlreadySet,
            mtWarning, [mbYes, mbNo], 0) = mrYes then
            setcorrection := True
          else
            setcorrection := False;
        end;
        if setcorrection then
        begin
          TMainSql.ExecUpdateCorrection(MainForm.SQLQuery1, ActiveStageIndex,
            correctionValue, numberValue);
          TLoRaSql.ExecSetIsSetByIdAndValue(MainForm.SQLQuery1, 1, idValue);
          UpdateResults;
        end;
      end
      else
      begin
        Log(rsNumber + ' ' + n + ' ' + rsDoNotExist);
      end;
      MainForm.SQLQuery1.Close;
      MainForm.SQLite3Connection1.Close;
      MainForm.SQLTransaction1.Active := False;
    end;
  end;
end;

procedure UpdateResults;
begin
  Screen.Cursor := crSQLWait;

  UpdateStageResults;
  UpdateSumResults;
  UpdateThruResults;
  RefreshAll;

  Screen.Cursor := crDefault;
end;

procedure UpdateStageResults;
var
  i: integer;
begin
  try
    for i := 1 to maxstages do
    begin
      if stages[i].isActive then
        with MainForm.SQLQuery1 do
        begin
          SQL.Text := TResultsSql.UpdateStageResult(i);
          Close;
          ExecSQL;

          SQL.Text := TResultsSql.ResetStagePlaceAndDiff(i);
          Close;
          ExecSQL;

          SQL.Text := TResultsSql.UpsertStagePlace(i);
          Close;
          ExecSQL;

          SQL.Text := TResultsSql.ResetStageDiffLeader(i);
          Close;
          ExecSQL;

          SQL.Text := TResultsSql.UpsertStageDiffLeader(i);
          Close;
          ExecSQL;
          SQLTransaction.Commit;
          Close;
        end;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure UpdateSumResults;
var
  sumtime, outtime: TDateTime;
  participantNumber, participantStatus, stringtime, sumResult: string;
  i, sumstages: integer;
  clearStatus: boolean;
  activeStages: array of integer = nil;
begin
  try
    SetLength(activeStages, 0);
    for i := 1 to maxstages do
    begin
      if stages[i].isActive then
      begin
        SetLength(activeStages, Length(activeStages) + 1);
        activeStages[High(activeStages)] := i;
      end;
    end;

    with MainForm.SQLQuery1 do
    begin
      Close;
      SQL.Text := TResultsSql.SelectForSumCalculation(activeStages);
      Open;
      MainForm.SQLQuery2.Close;
      if MainForm.SQLQuery2.Prepared then
        MainForm.SQLQuery2.UnPrepare;
      MainForm.SQLQuery2.SQL.Text := TResultsSql.UpdateSumResult;
      MainForm.SQLQuery2.Prepare;
      try
        while not EOF do
        begin
          participantNumber := FieldByName('number').AsString;
          participantStatus := FieldByName('status').AsString;
          sumtime := 0;
          sumstages := 0;
          for i := Low(activeStages) to High(activeStages) do
          begin
            stringtime := FieldByName('result' +
              IntToStr(activeStages[i])).AsString;
            if stringtime <> '' then
            begin
              stringtime :=
                StringReplace(stringtime, '.',
                DefaultFormatSettings.DecimalSeparator, [rfReplaceAll]);
              if TryStrToTime(stringtime, outtime) then
              begin
                sumtime := sumtime + outtime;
                sumstages := sumstages + 1;
              end;
            end;
          end;

          sumResult := '';
          clearStatus := False;
          if participantStatus = '3' then
            sumResult := 'DSQ'
          else if sumtime <> 0 then
          begin
            sumResult := FormatDateTime('hh:nn:ss.zzz', sumtime);
            clearStatus := True;
          end
          else if participantStatus = '1' then
            sumResult := 'DNF'
          else if participantStatus = '2' then
            sumResult := 'DNS';

          with MainForm.SQLQuery2 do
          begin
            ParamByName('NUMBER').AsString := participantNumber;
            if sumResult = '' then
              ParamByName('SUMRESULT').Clear
            else
              ParamByName('SUMRESULT').AsString := sumResult;
            if clearStatus then
              ParamByName('SUMSTAGES').AsInteger := sumstages
            else
              ParamByName('SUMSTAGES').Clear;
            ParamByName('CLEAR_STATUS').AsInteger := Ord(clearStatus);
            ExecSQL;
          end;
          Next;
        end;
      finally
        if MainForm.SQLQuery2.Prepared then
          MainForm.SQLQuery2.UnPrepare;
        MainForm.SQLQuery2.Close;
      end;
      Close;
      SQLTransaction.Commit;

      SQL.Text := TResultsSql.ResetSumPlaceAndDiff;
      Close;
      ExecSQL;

      //ставим место только тем, у кого есть результаты на всех активных СУ
      //и не было DNS/DNF
      SQL.Text := TResultsSql.UpsertSumPlaceOnlyFullStages(activeStages);
      Close;
      ExecSQL;

      //обнуляем отставание для первых номеров
      SQL.Text := TResultsSql.ResetSumDiffLeader;
      Close;
      ExecSQL;

      //ставим отставание от лидера категории
      SQL.Text := TResultsSql.UpsertSumDiffLeader;
      Close;
      ExecSQL;

      //ставим отставание в количестве СУ
      SQL.Text := TResultsSql.UpsertSumDiffByStages(rsSU);
      Close;
      ExecSQL;
      SQLTransaction.Commit;
      SQLTransaction.Active := False;
    end;
  except
    On E: Exception do
    begin
      if MainForm.SQLQuery2.Prepared then
        MainForm.SQLQuery2.UnPrepare;
      MainForm.SQLQuery2.Close;
      MainForm.SQLQuery1.Close;
      if MainForm.SQLQuery1.SQLTransaction.Active then
        MainForm.SQLQuery1.SQLTransaction.Rollback;
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure UpdateThruResults;                     //для сквозного
begin
  try
    with MainForm.SQLQuery1 do
    begin
      //обнуляем отставание и место для всех
      SQL.Text := TResultsSql.ResetThru;
      Close;
      ExecSQL;

      //обновляем места
      SQL.Text := TResultsSql.UpsertThruPlace;
      Close;
      ExecSQL;

      //ставим отставание от лидера общего протокола
      SQL.Text := TResultsSql.UpsertThruDiff;
      Close;
      ExecSQL;

      //ставим отставание в количестве СУ
      SQL.Text := TResultsSql.UpsertThruDiffByStages(rsSU);
      Close;
      ExecSQL;
      SQLTransaction.Commit;
      SQLTransaction.Active := False;
    end;
  except
    On E: Exception do
    begin
      MainForm.SQLQuery1.Close;
      MainForm.SQLQuery1.SQLTransaction.Active := False;
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure ClearResults(silent: boolean);
var
  i: integer;
begin
  if silent or (MessageDlg(rsClearResults, mtWarning, [mbYes, mbNo], 0) = mrYes) then
    if not BackupBD then
    begin
      if MessageDlg(rsCanNotBackup + sLineBreak + rsClearResultsWOBackup,
        mtWarning, [mbYes, mbNo], 0) = mrNo then
        Exit;
    end;
  begin
    try
      with MainForm.SQLQuery1 do
      begin
        SQL.Clear;
        SQL.Add(TResultsSql.ClearResultsPrefix);
        for i := 1 to maxstages do
        begin
          SQL.Add(TResultsSql.ClearResultsStagePart(i));
        end;
        SQL.Add(TResultsSql.ClearResultsSuffix);
        Close;
        ExecSQL;
        SQLTransaction.Commit;
        Close;
        RefreshAll;
      end;
      Log(rsResultsCleared);
    except
      On E: Exception do
      begin
        MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(rsDatabaseOpenError + E.Message);
      end;
    end;
  end;
end;

procedure SetDNSFromCorrection;
var
  n: string;
  i: integer;
begin
  if dbopen then
  begin
    if not MainForm.CorrectionDataset.IsEmpty then
    begin
      for i := 1 to maxstages do
      begin
        if MainForm.CurrentSU.Buttons[i - 1].Checked then
        begin
          n := MainForm.CorrectionDataset.FieldByName('number').AsString;
          SetSQLStatus(i, 'DNS', n);
        end;
      end;
    end;
  end;
end;

procedure SetStarttimeFromPopup;
var
  t: TDateTime;
  n: string;
  st: integer;
begin
  if dbnotempty then
  begin
    n := MainForm.MainDataset1.FieldByName('number').AsString;
    st := GetSelectedStage;
    t := InputDateTime(rsTimeToStart, rsEnterStartTime + ' ' + n +
      ' ' + rsOnStage + ': ' + stages[st].Name);
    if t > 0 then
    begin
      TMainSql.ExecUpdateStartTimeForNumber(MainForm.SQLQuery1, st,
        TimeToStr(t), StrToIntDef(n, 0));
      UpdateResults;
    end;
  end;
end;

procedure SetDNFFromOnTrace;
var
  n: string;
  i: integer;
begin
  if not MainForm.StatDataset2.IsEmpty then
  begin
    for i := 1 to maxstages do
    begin
      if MainForm.CurrentSU.Buttons[i - 1].Checked then
      begin
        n := MainForm.StatDataset2.FieldByName('number').AsString;
        SetSQLStatus(i, 'DNF', n);
      end;
    end;
  end;
end;

procedure LoadParticipantsList(FileName: string);
var
  i, k: integer;
  startItem: TStartItemModel;
  encodingName, csvText: string;
  about: rAboutHolder;
  parser: TParticipantsCsvParser;
  parseResult: TParticipantsCsvParseResult;
  importTransactionStarted: boolean;

  procedure ReportLoadError(const APrefix, ADetails: string);
  var
    messageText: string;
  begin
    messageText := APrefix + ADetails;
    AskMessageDlg(messageText, mtError, [mbOK], 0);
    Log(messageText);
  end;

  procedure BindLoadRowParameters(const AStartItem: TStartItemModel);
  var
    stageIndex: integer;
  begin
    with MainForm.SQLQuery1 do
    begin
      ParamByName('CATEGORY').AsString := AStartItem.category;
      ParamByName('NUMBER').AsInteger := AStartItem.number;
      ParamByName('NAME').AsString := AStartItem.Name;
      ParamByName('NICKNAME').AsString := AStartItem.nickname;
      ParamByName('AGE').AsString := AStartItem.birthday;
      ParamByName('TEAM').AsString := AStartItem.team;
      ParamByName('CITY').AsString := AStartItem.city;
      ParamByName('PHONE').AsString := AStartItem.phone;
      ParamByName('EMAIL').AsString := AStartItem.email;
      ParamByName('COMMENT').AsString := AStartItem.comment;

      for stageIndex := 1 to MAXSTAGES do
        if stageIndex <= AStartItem.startTimes.Count then
          ParamByName('STARTTIME' + IntToStr(stageIndex)).AsString :=
            AStartItem.startTimes[stageIndex - 1]
        else
          ParamByName('STARTTIME' + IntToStr(stageIndex)).AsString := '';
    end;
  end;

begin
  if dbopen then
  begin
    Screen.Cursor := crSQLWait;
    parser := nil;
    parseResult := nil;
    importTransactionStarted := False;
    try
      try
        csd_GetAbout(about);
        Print(about.About);

        Print('Open startlist file: ' + FileName);
        parser := TParticipantsCsvParser.Create;
        csvText := parser.ReadFile(FileName, encodingName);

        Print('Codepage: ' + encodingName);

        // Для неизвестной кодировки решение принимает пользователь.
        if SameText(encodingName, 'Unknown') and
          (AskMessageDlg(rsUnknownFileEncoding, mtWarning, [mbYes, mbNo], 0) <>
          mrYes) then
        begin
          Exit;
        end;

        parseResult := parser.Parse(csvText, MAXSTAGES);
        FreeAndNil(parser);

        Print(rsDetectedParticipantStages);
        for i := 0 to parseResult.StageNames.Count - 1 do
          Print(parseResult.StageNames[i]);

        // Предупреждаем о пропуске СУ до изменения данных в базе.
        if (parseResult.DetectedStageCount > MAXSTAGES) and
          (AskMessageDlg(Format(rsTooManyParticipantStages,
          [parseResult.DetectedStageCount, MAXSTAGES]), mtWarning,
          [mbYes, mbNo], 0) <> mrYes) then
          Exit;

        // Все изменения импорта выполняются атомарно.
        try
          MainForm.SQLQuery1.Close;
          if MainForm.SQLQuery1.Prepared then
            MainForm.SQLQuery1.UnPrepare;
          if MainForm.SQLQuery1.SQLTransaction.Active then
            MainForm.SQLQuery1.SQLTransaction.Commit;
          MainForm.SQLQuery1.SQLTransaction.StartTransaction;
          importTransactionStarted := True;

          MainForm.SQLQuery1.SQL.Text := TLoadSql.DeleteLoadStatement;
          MainForm.SQLQuery1.ExecSQL;

          if parseResult.StageNames.Count > 0 then
          begin
            MainForm.SQLQuery1.SQL.Text := TConfigSql.UpsertByKey;
            MainForm.SQLQuery1.Prepare;
            for i := 0 to parseResult.StageNames.Count - 1 do
            begin
              MainForm.SQLQuery1.ParamByName('KEY').AsString :=
                'stagename' + IntToStr(i + 1);
              MainForm.SQLQuery1.ParamByName('VALUE').AsString :=
                parseResult.StageNames[i];
              MainForm.SQLQuery1.ExecSQL;

              MainForm.SQLQuery1.ParamByName('KEY').AsString :=
                'stage' + IntToStr(i + 1);
              MainForm.SQLQuery1.ParamByName('VALUE').AsString :=
                BoolToStr(True, True);
              MainForm.SQLQuery1.ExecSQL;
            end;
            MainForm.SQLQuery1.UnPrepare;
          end;

          MainForm.SQLQuery1.SQL.Text := TLoadSql.InsertLoadRow(MAXSTAGES);
          MainForm.SQLQuery1.Prepare;
          for i := 0 to parseResult.StartItems.Count - 1 do
          begin
            startItem := TStartItemModel(parseResult.StartItems[i]);
            BindLoadRowParameters(startItem);
            MainForm.SQLQuery1.ExecSQL;
          end;
          MainForm.SQLQuery1.UnPrepare;

          // Запись в основную таблицу
          MainForm.SQLQuery1.SQL.Text :=
            TLoadSql.InsertLoadMainFromLoad(MAXSTAGES);
          MainForm.SQLQuery1.ExecSQL;

          MainForm.SQLQuery1.SQLTransaction.Commit;
          importTransactionStarted := False;
        except
          if MainForm.SQLQuery1.Prepared then
            MainForm.SQLQuery1.UnPrepare;
          if importTransactionStarted and
            MainForm.SQLQuery1.SQLTransaction.Active then
            MainForm.SQLQuery1.SQLTransaction.Rollback;
          importTransactionStarted := False;
          raise;
        end;

        if AskMessageDlg(rsSetCategoryName, mtConfirmation, [mbYes, mbNo], 0) =
          mrYes then
        begin
          //записывать ли первые несколько* категорий из списка участников
          with MainForm.SQLQuery1 do
          begin
            //в окно результатов и в конфиг БД
            Close;
            //*несколько равно количеству категорий, показываемых в окне результатов
            SQL.Text := TMainSql.SelectCategoryGrouped;
            Open;
            k := RecordCount;
            if k > VISIBLECAT then
              k := VISIBLECAT;
            for i := 1 to k do
            begin
              cat[i] := Fields.Fields[0].AsString;
              Next;
            end;
            Close;
          end;
          for i := 1 to VISIBLECAT do
            TConfigSql.ExecUpsertByKey(MainForm.SQLQuery1, 'catname' +
              IntToStr(i), cat[i]);
          LoadConfig;
          LoadIniCategory;
        end;
        RefreshAll;
        Log(rsLoadCSVParticipants);
        MainForm.SQLQuery1.Close;
      except
        On E: ECsvParserError do
          ReportLoadError(rsLoadParticipantsListError,
            FormatParticipantsCsvError(E));
        On E: EDatabaseError do
          ReportLoadError(rsWriteParticipantsDatabaseError, E.Message);
        On E: EStreamError do
          ReportLoadError(rsLoadParticipantsListError, E.Message);
        On E: Exception do
          ReportLoadError(rsLoadParticipantsListError, E.Message);
      end;
    finally
      parseResult.Free;
      parser.Free;
      Screen.Cursor := crDefault;
    end;
  end;
end;

function InputComboSelectStage(const ACaption, APrompt: string): integer;
var
  strlst: TStringList;
  i, index: integer;
  k: integer = -1;
begin
  if Assigned(StageSelectionHandler) then
  begin
    Result := StageSelectionHandler(ACaption, APrompt);
    Exit;
  end;

  Result := -1;
  strlst := TStringList.Create;

  // Если активных СУ больше одного, то
  // получаем список активных СУ и выводим инпуткомбо
  // В противном случае сразу выбираем активный СУ
  if stages.ActiveStagesCount > 1 then
  begin
    for i := 1 to maxstages do
    begin
      if stages[i].isActive then
      begin
        strlst.add(stages[i].Name);
        if MainForm.CurrentSU.Buttons[i - 1].Checked then
        begin
          k := strlst.Count - 1;
        end;
      end;
    end;
    if MyInputCombo(ACaption, APrompt, strlst, k, index) = mrOk then
      Result := index;
  end
  else
  begin
    Result := ActiveStageIndex();
  end;
  strlst.Free;
end;

procedure LoadStageResults(FileName: string);
var
  importfinish, i: integer;
  parser: TResultsCsvParser;
  parseResult: TResultsCsvParseResult;
  item: TResultImportItem;
  itemsToImport: TList;
  csvText, encodingName: string;
  backupCreated, importTransactionStarted: boolean;

  procedure ReportLoadError(const APrefix, ADetails: string);
  var
    messageText: string;
  begin
    messageText := APrefix + ADetails;
    AskMessageDlg(messageText, mtError, [mbOK], 0);
    Log(messageText);
  end;

  function InsertStatement(const AFormat: TResultsCsvFormat): string;
  begin
    case AFormat of
      rcfFullStage:
        Result := TLoadSql.InsertLoadResultRow6;
      rcfStart:
        Result := TLoadSql.InsertLoadResultRow3;
      rcfFinish:
        Result := TLoadSql.InsertLoadResultRow2;
    end;
  end;

  function UpsertStatement(const AFormat: TResultsCsvFormat): string;
  begin
    case AFormat of
      rcfFullStage:
        Result := TLoadSql.UpsertMainFromLoadResult6Statement(importfinish);
      rcfStart:
        Result := TLoadSql.UpsertMainFromLoadResult3Statement(importfinish);
      rcfFinish:
        Result := TLoadSql.UpsertMainFromLoadResult2Statement(importfinish);
    end;
  end;

  procedure BindNullableString(const AParameterName, AValue: string);
  begin
    with MainForm.SQLQuery1.ParamByName(AParameterName) do
      if AValue = '' then
        Clear
      else
        AsString := AValue;
  end;

  procedure BindResultItem(const AItem: TResultImportItem;
    const AFormat: TResultsCsvFormat);
  begin
    MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger :=
      AItem.ParticipantNumber;

    case AFormat of
      rcfFullStage:
        begin
          BindNullableString('STARTTIME', AItem.StartTime);
          if AItem.HasCorrection then
            MainForm.SQLQuery1.ParamByName('CORRECTION').AsInteger :=
              AItem.Correction
          else
            MainForm.SQLQuery1.ParamByName('CORRECTION').Clear;
          BindNullableString('FINISHTIME', AItem.FinishTime);
          BindNullableString('PENALTY', AItem.Penalty);
        end;
      rcfStart:
        begin
          BindNullableString('STARTTIME', AItem.StartTime);
          if AItem.HasCorrection then
            MainForm.SQLQuery1.ParamByName('CORRECTION').AsInteger :=
              AItem.Correction
          else
            MainForm.SQLQuery1.ParamByName('CORRECTION').Clear;
        end;
      rcfFinish:
        BindNullableString('FINISHTIME', AItem.FinishTime);
    end;

    if AItem.HasStatus then
      MainForm.SQLQuery1.ParamByName('STATUS').AsInteger := AItem.StatusCode
    else
      MainForm.SQLQuery1.ParamByName('STATUS').Clear;
  end;

  procedure CollectItemsToImport;
  var
    itemIndex: integer;
    parsedItem: TResultImportItem;
    existingNumbers: TStringList;
    numberKey: string;
    participantExists, addUnknown: boolean;
  begin
    itemsToImport.Clear;
    existingNumbers := TStringList.Create;
    try
      MainForm.SQLQuery1.Close;
      MainForm.SQLQuery1.SQL.Text := TMainSql.SelectNumbers;
      MainForm.SQLQuery1.Open;

      while not MainForm.SQLQuery1.EOF do
      begin
        existingNumbers.Add(IntToStr(
          MainForm.SQLQuery1.FieldByName('number').AsInteger));
        MainForm.SQLQuery1.Next;
      end;
      existingNumbers.Sort;
      existingNumbers.Sorted := True;

      MainForm.SQLQuery1.Close;
      if MainForm.SQLQuery1.SQLTransaction.Active then
      begin
        MainForm.SQLQuery1.SQLTransaction.Active := False;
      end;

      for itemIndex := 0 to parseResult.Items.Count - 1 do
      begin
        parsedItem := TResultImportItem(parseResult.Items[itemIndex]);
        numberKey := IntToStr(parsedItem.ParticipantNumber);
        participantExists := existingNumbers.IndexOf(numberKey) >= 0;

        addUnknown := False;
        if not participantExists then
        begin
          addUnknown := AskMessageDlg(Format(rsAddUnknownResultParticipant,
            [parsedItem.ParticipantNumber]), mtConfirmation,
            [mbYes, mbNo], 0) = mrYes;
        end;

        if participantExists or addUnknown then
        begin
          itemsToImport.Add(parsedItem);
        end;
      end;
    finally
      MainForm.SQLQuery1.Close;
      if MainForm.SQLQuery1.SQLTransaction.Active then
        MainForm.SQLQuery1.SQLTransaction.Active := False;
      existingNumbers.Free;
    end;
  end;
begin
  if not dbopen then
  begin
    Exit;
  end;

  Screen.Cursor := crSQLWait;
  parser := nil;
  parseResult := nil;
  itemsToImport := TList.Create;
  importTransactionStarted := False;
  try
    try
      parser := TResultsCsvParser.Create;
      csvText := parser.ReadFile(FileName, encodingName);

      if SameText(encodingName, 'Unknown') then
      begin
        if AskMessageDlg(rsUnknownFileEncoding, mtWarning,
          [mbYes, mbNo], 0) <> mrYes then
        begin
          Exit;
        end;
      end;

      parseResult := parser.Parse(csvText);

      // Выбираем СУ только после успешной проверки файла.
      importfinish := InputComboSelectStage(rsImportFinish, rsSetTimeToSU);
      if importfinish <= 0 then
      begin
        Exit;
      end;

      // Неизвестного участника добавляем только с согласия пользователя.
      CollectItemsToImport;
      if itemsToImport.Count = 0 then
      begin
        Exit;
      end;

      // Делаем резервную копию до начала изменений в базе.
      backupCreated := BackupBD;
      if not backupCreated and
        (AskMessageDlg(rsCanNotBackup + sLineBreak +
        rsContinueWithLoadingResults, mtWarning,
        [mbYes, mbNo], 0) = mrNo) then
      begin
        Exit;
      end;

      MainForm.SQLQuery1.Close;
      if MainForm.SQLQuery1.Prepared then
      begin
        MainForm.SQLQuery1.UnPrepare;
      end;
      if MainForm.SQLQuery1.SQLTransaction.Active then
      begin
        MainForm.SQLQuery1.SQLTransaction.Commit;
      end;
      MainForm.SQLQuery1.SQLTransaction.StartTransaction;
      importTransactionStarted := True;

      try
        MainForm.SQLQuery1.SQL.Text :=
          TLoadSql.DeleteLoadResultStatement;
        MainForm.SQLQuery1.ExecSQL;

        MainForm.SQLQuery1.SQL.Text :=
          InsertStatement(parseResult.Format);
        MainForm.SQLQuery1.Prepare;
        for i := 0 to itemsToImport.Count - 1 do
        begin
          item := TResultImportItem(itemsToImport[i]);
          BindResultItem(item, parseResult.Format);
          MainForm.SQLQuery1.ExecSQL;
        end;
        MainForm.SQLQuery1.UnPrepare;

        MainForm.SQLQuery1.SQL.Text :=
          UpsertStatement(parseResult.Format);
        MainForm.SQLQuery1.ExecSQL;
        MainForm.SQLQuery1.SQLTransaction.Commit;
        importTransactionStarted := False;
      except
        if MainForm.SQLQuery1.Prepared then
        begin
          MainForm.SQLQuery1.UnPrepare;
        end;
        if importTransactionStarted and
          MainForm.SQLQuery1.SQLTransaction.Active then
        begin
          MainForm.SQLQuery1.SQLTransaction.Rollback;
        end;
        importTransactionStarted := False;
        raise;
      end;

      case parseResult.Format of
        rcfFullStage:
          begin
            RecalculateStatus(GetAllStageStatus(importfinish));
            UpdateResults;
            Log(rsImportFinishtime + ' ' + IntToStr(importfinish) +
              ': ' + stages[importfinish].Name + ' ' + rsLoaded_o);
          end;
        rcfStart:
          begin
            UpdateResults;
            Log(rsImportStarttime + ' ' + IntToStr(importfinish) +
              ': ' + stages[importfinish].Name + ' ' + rsLoaded);
          end;
        rcfFinish:
          begin
            UpdateResults;
            Log(rsImportFinishtime + ' ' + IntToStr(importfinish) +
              ': ' + stages[importfinish].Name + ' ' + rsLoaded_o);
          end;
      end;
    except
      On E: ECsvParserError do
        ReportLoadError(rsLoadResultsError, FormatResultsCsvError(E));
      On E: EDatabaseError do
        ReportLoadError(rsWriteResultsDatabaseError, E.Message);
      On E: EStreamError do
        ReportLoadError(rsLoadResultsError, E.Message);
      On E: Exception do
        ReportLoadError(rsLoadResultsError, E.Message);
    end;
  finally
    itemsToImport.Free;
    parseResult.Free;
    parser.Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure ExportFinishTime(FileName: string; stageIndex: integer);
var
  index: string;
begin
  index := IntToStr(stageIndex);
  MainForm.SQLQuery1.SQL.Text := TMainSql.ExportFinishTime(StrToIntDef(index, 1));
  SQLQueryToCSV(FileName, MainForm.SQLQuery1);
end;

procedure ExportAllResults(FileName: string);
begin
  MainForm.SQLQuery1.SQL.Text := TMainSql.ExportAllResults;
  SQLQueryToCSV(FileName, MainForm.SQLQuery1, True);
end;

procedure ExportSumDays(FileName: string);
begin
  MainForm.SQLQuery1.SQL.Text := TMainSql.ExportSumDays;
  SQLQueryToCSV(FileName, MainForm.SQLQuery1, True);
end;

procedure ExportAllResultsToXLSX(FileName: string);
var
  //sql: string;
  //fileName: string;
  MyWorkbook: TsWorkbook;
  FinishWorksheet, ThruWorksheet: TsWorksheet;
  c, i, j: integer;
  stageColumnCount: integer = 3;
  categories, exportColumns, ColumnstageName, stageNames: TStringList;
  normalFont, categoryFont, legendFont: TsFont;
  inormalFont, icategoryFont, ilegendFont: integer;
  showPenalty: boolean = False;
begin
  if not FileExists(FileName) or
    (MessageDlg(rsFileExists, mtWarning, [mbOK, mbCancel], 0) = mrOk) then
  begin
    // Create the spreadsheet
    MyWorkbook := TsWorkbook.Create;
    FinishWorksheet := MyWorkbook.AddWorksheet(rsFinishProtocol);
    ThruWorksheet := MyWorkbook.AddWorksheet(rsFinishThruProtocol);

    // Шрифты
    normalFont := TsFont.Create;
    normalFont.FontName := 'Arial';
    normalFont.Size := 10.0;
    legendFont := TsFont.Create;
    legendFont.CopyOf(normalFont);
    legendFont.Style := [TsFontStyle.fssBold];
    categoryFont := TsFont.Create;
    categoryFont.CopyOf(legendFont);
    categoryFont.Size := 14.0;
    inormalFont := MyWorkbook.AddFont(normalFont);
    ilegendFont := MyWorkbook.AddFont(legendFont);
    icategoryFont := MyWorkbook.AddFont(categoryFont);


    categories := TStringList.Create;
    exportColumns := TStringList.Create;
    ColumnstageName := TStringList.Create;
    stageNames := TStringList.Create;

    // Формируем список колонок для экспорта
    exportColumns.add('sumplace');
    exportColumns.add('number');
    exportColumns.add('name');
    exportColumns.add('nickname');
    exportColumns.add('age');
    exportColumns.add('team');
    exportColumns.add('city');

    ColumnstageName.add(rsPlace);
    ColumnstageName.add(rsNumber);
    ColumnstageName.add(rsName);
    ColumnstageName.add(rsNickname);
    ColumnstageName.add(rsAge);
    ColumnstageName.add(rsTeam);
    ColumnstageName.add(rsCity);

    // Если есть штрафы в таблице, заносим их в результаты,
    // в противном случае не показываем эти столбцы
    i := TMainSql.GetPenaltyGroupsCount(MainForm.SQLQuery1);
    print(IntToStr(i));
    if (i > 1) then
    begin
      showPenalty := True;
      stageColumnCount := 4;
    end;

    if (stages.ActiveStagesCount > 1) then
    begin
      // Колонки для активных СУ
      for i := 1 to MAXSTAGES do
      begin
        if stages[i].isActive then
        begin
          exportColumns.add('result' + IntToStr(i));
          ColumnstageName.add(rsResult);
          exportColumns.add('diffleader' + IntToStr(i));
          ColumnstageName.add(rsDiffleader);
          if (showPenalty) then
          begin
            exportColumns.add('penalty' + IntToStr(i));
            ColumnstageName.add(rsPenalty);
          end;
          exportColumns.add('place' + IntToStr(i));
          ColumnstageName.add(rsPlace);
          stageNames.add(stages[i].Name);
        end;
      end;
    end;

    exportColumns.add('sumresult');
    exportColumns.add('sumdiffleader');

    ColumnstageName.add(rsSumresult);
    ColumnstageName.add(rsDiffleader);

    if (stages.ActiveStagesCount > 1) then
    begin
      exportColumns.add('sumstages');
      ColumnstageName.add(rsSumstages);
    end;

    // Создаём список категорий
    with MainForm.SQLQuery1 do
    begin
      Close;
      SQL.Text := TMainSql.SelectCategoryGroupedOrderedByStartTime(1);
      Open();
      while not MainForm.SQLQuery1.EOF do
      begin
        Categories.Add(Fields[0].AsString);
        Next;
      end;
      Close;
    end;

    j := 0;
    for c := 0 to Categories.Count - 1 do
    begin
      with MainForm.SQLQuery1 do
      begin
        Close;
        SQL.Text := TMainSql.SelectCategoryResults(exportColumns.CommaText);
        ParamByName('CATEGORY').AsString := Categories[c];
        Open();

        // Запись категории
        FinishWorksheet.WriteText(j, 0, Categories[c]);
        FinishWorksheet.WriteFont(j, 0, icategoryFont);
        Inc(j);

        // Отдельной строкой название СУ если их больше одного
        if (stages.ActiveStagesCount > 1) then
        begin
          for i := 0 to stages.ActiveStagesCount - 1 do
          begin
            // 7 - количество столбцов до отдельных результатов СУ
            // 4 - кол-во столбцов на СУ
            FinishWorksheet.WriteText(j, 7 + stageColumnCount * i, stageNames[i]);
            FinishWorksheet.WriteFont(j, 7 + stageColumnCount * i, ilegendFont);
            FinishWorksheet.WriteHorAlignment(j, 7 + stageColumnCount * i, haCenter);
            FinishWorksheet.MergeCells(j, 7 + stageColumnCount * i, j,
              7 + stageColumnCount * i + stageColumnCount - 1);
          end;
          Inc(j);
        end;

        // Запись имён столбцов
        for i := 0 to Fields.Count - 1 do
        begin
          FinishWorksheet.WriteText(j, i, ColumnstageName[i]);
          FinishWorksheet.WriteFont(j, i, ilegendFont);
          FinishWorksheet.WriteHorAlignment(j, i, haCenter);

          // Изменяем ширину столбцов (да, в каждой категории :( )
          if pos('number', exportColumns[i]) > 0 then
            FinishWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints);
          if pos('place', exportColumns[i]) > 0 then
            FinishWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints);
          if exportColumns[i] = 'name' then
            FinishWorksheet.WriteColWidth(i, 125, TsSizeUnits.suPoints);
          if exportColumns[i] = 'age' then
            FinishWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints);
          if pos('penalty', exportColumns[i]) > 0 then
            FinishWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints);
          if exportColumns[i] = 'sumstages' then
            FinishWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints);
        end;
        Inc(j);

        // Запись результатов категории в worksheet
        First;
        while not EOF do
        begin
          for i := 0 to Fields.Count - 1 do
          begin
            // Если содержит 'place'
            if ((pos('place', exportColumns[i]) > 0) and
              (Fields[i].AsString <> '')) or (exportColumns[i] = 'number') or
              (exportColumns[i] = 'sumstages') then
            begin
              FinishWorksheet.WriteNumber(j, i, Fields[i].AsInteger);
              FinishWorksheet.WriteHorAlignment(j, i, haCenter);
            end
            else if (pos('result', exportColumns[i]) > 0) or
              (pos('diff', exportColumns[i]) > 0) or
              (pos('penalty', exportColumns[i]) > 0) then
            begin
              FinishWorksheet.WriteText(j, i, HideLeadingZeroHour(Fields[i].AsString));
              FinishWorksheet.WriteHorAlignment(j, i, haRight);
              if (exportColumns[i] = 'sumresult') then
                FinishWorksheet.WriteFont(j, i, ilegendFont);
            end
            else
            begin
              FinishWorksheet.WriteText(j, i, Fields[i].AsString);
              FinishWorksheet.WriteFont(j, i, inormalFont);
            end;
          end;
          Next;
          Inc(j);
        end;

        // Пустая строка между категориями
        Inc(j);
      end;
    end;


    // Сквозной протокол
    // Формируем список колонок для экспорта
    exportColumns.Clear;
    exportColumns.add('category');
    exportColumns.add('sumplace');
    exportColumns.add('number');
    exportColumns.add('name');
    exportColumns.add('sumresult');
    exportColumns.add('thrudiff');

    ColumnstageName.Clear;
    ColumnstageName.add(rsCategory);
    ColumnstageName.add(rsPlace);
    ColumnstageName.add(rsNumber);
    ColumnstageName.add(rsName);
    ColumnstageName.add(rsResult);
    ColumnstageName.add(rsDiffleader);

    if stages.ActiveStagesCount > 1 then
    begin
      exportColumns.add('sumstages');
      ColumnstageName.add(rsSumstages);
    end;

    j := 0;
    with MainForm.ResultDatasetStageTotal do
    begin
      First;

      // Запись имён столбцов
      for i := 0 to exportColumns.Count - 1 do
      begin
        ThruWorksheet.WriteText(j, i, ColumnstageName[i]);
        ThruWorksheet.WriteFont(j, i, ilegendFont);
        ThruWorksheet.WriteHorAlignment(j, i, haCenter);

        //// Изменяем ширину столбцов
        //if exportColumns[i] = 'category' then
        //ThruWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints)
        if exportColumns[i] = 'sumplace' then
          ThruWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints)
        else if exportColumns[i] = 'number' then
          ThruWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints)
        else if exportColumns[i] = 'name' then
          ThruWorksheet.WriteColWidth(i, 125, TsSizeUnits.suPoints)
        //else if exportColumns[i] = 'sumresult' then
        //ThruWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints)
        //else if exportColumns[i] = 'thrudiff' then
        //ThruWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints)
        else if exportColumns[i] = 'sumstages' then
          ThruWorksheet.WriteColWidth(i, 50, TsSizeUnits.suPoints);
      end;
      Inc(j);

      // Запись результатов категории в worksheet
      while not EOF do
      begin
        for i := 0 to exportColumns.Count - 1 do
        begin
          ThruWorksheet.WriteText(j, i, Fields[i].AsString);
          //Если содержит 'place'
          if (exportColumns[i] = 'sumplace') or (exportColumns[i] =
            'number') or (exportColumns[i] = 'sumstages') then
          begin
            ThruWorksheet.WriteNumber(j, i, Fields[i].AsInteger);
            ThruWorksheet.WriteHorAlignment(j, i, haCenter);
          end
          else if (exportColumns[i] = 'sumresult') or
            (exportColumns[i] = 'place') then
          begin
            ThruWorksheet.WriteText(j, i, HideLeadingZeroHour(Fields[i].AsString));
            ThruWorksheet.WriteHorAlignment(j, i, haRight);
            ThruWorksheet.WriteFont(j, i, ilegendFont);
          end
          else if exportColumns[i] = 'thrudiff' then
          begin
            ThruWorksheet.WriteText(j, i, HideLeadingZeroHour(Fields[i].AsString));
            ThruWorksheet.WriteHorAlignment(j, i, haRight);
          end
          else
          begin
            ThruWorksheet.WriteText(j, i, Fields[i].AsString);
            ThruWorksheet.WriteFont(j, i, inormalFont);
          end;
        end;
        Next;
        Inc(j);
      end;
    end;

    // Save the spreadsheet to a file
    try
      begin
        //MyWorkbook.WriteToFile(MyDir + 'test' + STR_EXCEL_EXTENSION, OUTPUT_FORMAT);
        MyWorkbook.WriteToFile(FileName, True);
        Log(rsResultsExportedToFile + ' ' + FileName);
        OpenDocument(FileName);
      end;
    finally
      begin
        MainForm.SQLQuery1.Close;
        MainForm.SQLTransaction1.Active := False;
        MyWorkbook.Free;
        Categories.Free;
        exportColumns.Free;
        ColumnstageName.Free;
        stageNames.Free;
      end;
    end;
  end;
end;

procedure GetFinishTime(FinishTime: TDateTime);
begin
  if MainForm.sGridResult.RowCount = 1 then
  begin
    prevTime := FinishTime;
    MainForm.sGridResult.InsertRowWithValues(MainForm.sGridResult.RowCount,
      [FormatDateTime('hh:nn:ss.zzz', FinishTime)]);
  end
  else
  begin
    if StrToInt(FormatDateTime('hhnnsszzz', (FinishTime - prevTime))) >
      checkinterval then
    begin
      MainForm.sGridResult.InsertRowWithValues(
        MainForm.sGridResult.RowCount,
        [FormatDateTime('hh:nn:ss.zzz', FinishTime)]);
      prevTime := FinishTime;
    end;
  end;
end;

procedure SetLoRaTime(StartTime: TDateTime; correction: string);
var
  seconds, timeAfter, timeBefore: TDateTime;
  number: integer;
  hasNumber: boolean;
begin
  if dbopen then
  begin
    seconds := 15 / 24 / 60 / 60; //15 секунд
    timeAfter := StartTime + seconds;
    timeBefore := StartTime - seconds;
    hasNumber := TMainSql.TryGetNumberByStartTimeBetween(
      MainForm.SQLQuery1, ActiveStageIndex, FormatDateTime(
      'hh:nn:ss.zzz', timeBefore), FormatDateTime('hh:nn:ss.zzz', timeAfter), number);

    TLoRaSql.ExecInsertSample(MainForm.SQLQuery1, hasNumber, number,
      FormatDateTime('hh:nn:ss.zzz', StartTime), StrToIntDef(correction, 0),
      FormatDateTime('hh:nn:ss', Now));
    //обновляем датасет
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

//procedure GenerateStartlistFromQualifier(FileName: string);
//var
//  prevfName: string;
//  fileExistsBefore: boolean;
//begin
//  if fName <> FileName then
//  begin
//    fileExistsBefore := FileExists(FileName);
//    if fileExistsBefore and (MessageDlg(rsFinalFileExists, mtWarning,
//      [mbOK, mbCancel], 0) = mrCancel) then
//      Exit;
//    prevfName := fName;
//    //1. закрываем текущее соревнование
//    MainForm.FileCloseExecute(nil);
//    SetfName('');
//    //2. копируем файл
//    try
//      CopyFile(fName, FileName, False, True);
//      //3. открываем новый файл
//      //fName := FileName;
//      //SetfName(fName);
//      //OpenDB;
//      InitDB(FileName);
//      //4 формируем порядок старта категорий
//      if RunStartlist(startlistConfig) then
//      begin
//        //5. удаляем результаты
//        ClearResults(True);
//        //уведомление что стартовый протокол создан
//        MessageDlg(rsGenerateStartList + ': ' + FileName,
//          mtInformation, [mbOK], 0);
//      end
//      else
//      begin
//        MainForm.FileCloseExecute(nil);
//        if not fileExistsBefore then
//          DeleteFile(FileName);
//        //fName := prevfName;
//        //SetfName(fName);
//        //OpenDB;
//        InitDB(prevfName);
//      end;
//    except
//      on E: Exception do
//      begin
//        MessageDlg(rsFileCopyError + ':' + #13#10 + E.Message,
//          mtError, [mbOK], 0);
//      end;
//    end;
//  end
//  else
//    MessageDlg(rsFilesAreEqual, mtError, [mbOK], 0);
//end;

procedure ExportCSVStartList(FileName: string);
var
  i, k, fieldIndex: integer;
  fieldName: string = 'starttime';
  csvfilename: string;
begin
  csvfilename := FileName;

  if FileExists(FileName) then
  begin
    if MessageDlg(rsStartListFileExists, mtWarning, [mbYes, mbNo], 0) <> mrYes then
      exit;
  end;

  with MainForm.CSVStartListExporter do
  begin
    Dataset := MainForm.MainDataSource1.DataSet;
    FileName := csvfilename;
    for i := 1 to MAXSTAGES do
    begin
      if (stages[i].isActive) then
        // Эта хрень с добавлением/удалением из-за того,
        // что почему-то экспортируются задизейбленные поля
      begin
        ExportFields.AddField(fieldName + IntToStr(i));
        fieldIndex := ExportFields.IndexOfField(fieldName + IntToStr(i));
        ExportFields.Fields[fieldIndex].ExportedName := stages[i].Name;
      end;
    end;

    try
      Execute;
    finally
      begin
        for k := ExportFields.Count - 1 downto 10 do
          ExportFields.Delete(k);
      end;
    end;
  end;
end;

procedure ExportCSVResults(FileName: string);
var
  csvfilename: string;
begin
  csvfilename := FileName;

  if FileExists(FileName) then
  begin
    if MessageDlg(rsCSVResultsFileExists, mtWarning, [mbYes, mbNo], 0) <> mrYes then
      exit;
  end;

  with MainForm.CSVResultsExporter do
  begin
    Dataset := MainForm.MainDataSource1.DataSet;
    FileName := csvfilename;
    Log(FileName);
    try
      Execute;
    except
      On E: Exception do
      begin
        MessageDlg(rsCSVResultsExportError + E.Message, mtError, [mbOK], 0);
        Log(rsCSVResultsExportError + E.Message);
      end;
    end;
  end;
end;

procedure ParseSerial(Str: string);
var
  parse: string;
  LoRacorrection: integer;
  ParseList: TStringList;
  LoRaStartTime, FinishTime: TDateTime;
begin
  //есть пакет от старта $_#
  if (Pos('$', Str) > 0) and (Pos('#', Str) > 0) then
  begin
    parse := Copy(Str, Pos('$', Str) + 1, Pos('#', Str) - Pos('$', Str) - 1);
    ParseList := TStringList.Create;
    try
      ParseList.Delimiter := ';';
      ParseList.DelimitedText := parse;
      if TryStrToTime(ParseList[0], LoRaStartTime) then
      begin
        if TryStrToInt(ParseList[1], LoRacorrection) then
        begin
          SetLoRaTime(LoRaStartTime, ParseList[1]);
          Print('Start -> ' + ParseList[0] + ', ' + ParseList[1]);
        end
        //не удалось разобрать пакет, ошибка в поправке
        else
          Print('Raw -> ' + Str);
      end
      //не удалось разобрать пакет, ошибка во времени старта
      else
        Print('Raw -> ' + Str);
    finally
      ParseList.Free;
    end;
  end
  else
  begin
    //есть пакет от финиша F_#
    if (Pos('F', Str) > 0) and (Pos('#', Str) > 0) then
    begin
      parse := Copy(Str, Pos('F', Str) + 1, Pos('#', Str) - Pos('F', Str) - 1);
      begin
        if TryStrToTime(parse, FinishTime) then
        begin
          GetFinishTime(FinishTime);
          Print('Finish -> ' + parse);
        end
        //не удалось разобрать пакет, ошибка во времени финиша
        else
          Print('Raw -> ' + Str);
      end;
    end
    //не удалось разобрать пакет
    else
      Print('Raw -> ' + Str);
  end;
end;

procedure SQLQueryToCSV(FileName: string; Query: TSQLQuery; headers: boolean);
var
  ocsvStrings: TStringList;
  s: string;
  i: integer;
begin
  if dbopen then
  begin
    try
      ocsvStrings := TStringList.Create;
      Query.Close;
      Query.Open;
      if headers then
      begin
        s := '#';
        for i := 0 to Query.Fields.Count - 1 do
        begin
          s := s + Query.Fields.Fields[i].FieldName;
          s := s + ';';
        end;
        Delete(s, Length(s), 1);
        ocsvStrings.Add(s);
      end;
      while not Query.EOF do
      begin
        s := '';
        for i := 0 to Query.Fields.Count - 1 do
        begin
          s := s + Query.Fields.Fields[i].AsString;
          s := s + ';';
        end;
        //обрезаем последнюю точку с запятой
        Delete(s, Length(s), 1);
        ocsvStrings.Add(s);
        Query.Next;
      end;
      Query.Close;
      // на win10 Executor почему-то вопросы при конвертации
      // при этом в notepad++ аналогично
      //{$IFDEF Windows}
      //ocsvStrings.Text :=
      //  UTF8ToWinCP(ocsvStrings.Text);
      //{$ENDIF}
      ocsvStrings.SaveToFile(FileName);
    finally
      ocsvStrings.Free;
      Query.SQLTransaction.Active := False;
    end;
  end;
end;

procedure AddDayResult(FileName: string);
var
  ocsvStrings: TStringList;
  i, k: integer;
begin
  if dbopen then
  begin
    Screen.Cursor := crSQLWait;
    try
      TLoadSql.ExecDeleteLoad(MainForm.SQLQuery1);

      ocsvStrings := TStringList.Create;
      try
        ocsvStrings.LoadFromFile(FileName);
        MainForm.SQLQuery1.SQL.Clear;
        MainForm.SQLQuery1.SQL.Add(TLoadSql.AddDayInsertLoadHeader);
        for  i := ocsvStrings.Count - 1 downto 0 do
        begin
          //удаляем комментарии (#)
          if Pos('#', Trim(ocsvStrings.ValueFromIndex[i])) = 1 then
          begin
            ocsvStrings.Delete(i);
            continue;
          end;
          k := CountOccurrences(';', ocsvStrings.ValueFromIndex[i]);
          //остатки от копирования
          //TODO: посчитать реальное значение, сделать обработку возможной ошибки
          //считаем кол-во разделителей(;), чтобы понять сколько стартовых времён
          if k < 13 then
          begin
            //экранируем ' в SQL запросе
            ocsvStrings.ValueFromIndex[i] :=
              ReplaceStr(ocsvStrings.ValueFromIndex[i], '''', '''''');
            ocsvStrings.ValueFromIndex[i] :=
              ReplaceStr(ocsvStrings.ValueFromIndex[i], ';', ''',''');
          end;
          MainForm.SQLQuery1.SQL.Add(
            TLoadSql.ValuesRowFromEscaped(ocsvStrings.ValueFromIndex[i]));
          //если строка не последняя(первая, т.к. загрузка в обратном порядке) ставим запятую
          //if i <> ocsvStrings.Count - 1 then
          //if i <> 0 then
          MainForm.SQLQuery1.SQL.Add(TLoadSql.SqlComma);
        end;
        MainForm.SQLQuery1.SQL.Delete(MainForm.SQLQuery1.SQL.LastIndexOf(','));
        MainForm.SQLQuery1.SQL.Add(TLoadSql.SqlSemicolon);
        {$IFDEF Windows}
        MainForm.SQLQuery1.SQL.Text :=
          WinCPToUTF8(MainForm.SQLQuery1.SQL.Text);
        {$ENDIF}
        try
          begin
            MainForm.SQLQuery1.Close;
            MainForm.SQLQuery1.ExecSQL;
            //ставим результат ноль, если DNS/DNF/DSQ
            MainForm.SQLQuery1.SQL.Text := TLoadSql.AddDayNormalizeResult;
            MainForm.SQLQuery1.Close;
            MainForm.SQLQuery1.ExecSQL;
            MainForm.SQLQuery1.SQL.Text := TLoadSql.AddDayNormalizeStages;
            MainForm.SQLQuery1.Close;
            MainForm.SQLQuery1.ExecSQL;
            MainForm.SQLQuery1.SQL.Text := TLoadSql.AddDayNormalizeStatus;
            MainForm.SQLQuery1.Close;
            MainForm.SQLQuery1.ExecSQL;
            MainForm.SQLQuery1.SQLTransaction.Commit;
          end;
        except
          On E: Exception do
          begin
            MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
            Log(rsDatabaseOpenError + E.Message);
          end;
        end;
        MainForm.SQLQuery1.Close;
      finally
        ocsvStrings.Free;
      end;

      with MainForm.SQLQuery1 do
      begin
        SQL.Text := TLoadSql.AddDayUpsertSumdays;
        Close;
        ExecSQL;
        SQLTransaction.Commit;
        Close;
      end;

      //ToDo: если время не время (например, DNF/DSQ), то при конвертации получается NULL и соответственно сумма тоже NULL
      //В этом случае нужно ставить время 00:00:00 (SQL или программно)

      //INSERT into sumdays (number, sumresult, sumstages, status)
      //SELECT number, starttime1, age, starttime2 FROM load WHERE number NOTNULL
      //ON CONFLICT (number) DO UPDATE SET
      //sumresult = strftime('%H:%M:%f',julianday(excluded.sumresult) + julianday(sumresult) +0.5),
      //sumstages = excluded.sumstages + sumstages,
      //status = excluded.status + status

      Screen.Cursor := crDefault;
    except
      On E: Exception do
      begin
        MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(rsDatabaseOpenError + E.Message);
        Screen.Cursor := crDefault;
      end;
    end;
  end;
end;

procedure Print(Str: string);
begin
  MainForm.Memo.Lines.Add(Str);
end;

procedure Print(Int: integer);
begin
  MainForm.Memo.Lines.Add(IntToStr(Int));
end;

procedure Print(Bool: boolean);
begin
  if bool then
    MainForm.Memo.Lines.Add('True')
  else
    MainForm.Memo.Lines.Add('False');
end;

function CountOccurrences(ASubString: string; AString: string): integer;
var
  offset: integer;
begin
  Result := 0;
  offset := PosEx(ASubString, AString, 1);
  while offset <> 0 do
  begin
    Inc(Result);
    offset := PosEx(ASubString, AString, offset + length(ASubString));
  end;
end;

function CatStartList: TStringList;
  //var
  //  i, k: integer;
  //  s: integer = 0;
begin
  with MainForm.SQLQuery1 do
  begin
    Close;
    //sql запрос на список категорий
    SQL.Text := TMainSql.SelectCategoryGroupedOrderedByStartTime(ActiveStageIndex);
    //открываем
    Open;
    //перегоняем в стринглист список категорий
    //k := RecordCount;
    try
      Result := TStringList.Create;
      while not EOF do
      begin
        Result.Add(Fields.Fields[0].AsString);
        Next;
      end;
      Close;
      MainForm.SQLTransaction1.Active := False;
      //сортируем категории по порядку категорий, показываемых в окне результатов
      //категории, которых нет в этом списке, будут первыми
      //s := 0;
      //for i := VISIBLECAT downto 1 do
      //begin
      //  k := Result.IndexOf(cat[i]);
      //  if k > -1 then
      //  begin
      //    Result.Exchange(k, (Result.Count - 1) - s);
      //    s := s + 1;
      //  end;
      //end;
      //MainForm.Memo.Lines.Add(Result.Text);
    except
      on E: Exception do
      begin
        MessageDlg(E.Message, mtError, [mbOK], 0);
        MainForm.SQLTransaction1.Active := False;
      end;
    end;
  end;
end;

function GetAllStageStatus(stage: integer): TStringList;
  //список номеров с установленным статусом
begin
  try
    if dbnotempty then
    begin
      MainForm.SQLQuery1.Close;
      if stage = 0 then
      begin
        MainForm.SQLQuery1.SQL.Text := TMainSql.SelectStatusAll
      end
      else
      begin
        MainForm.SQLQuery1.SQL.Text := TMainSql.SelectStatusByStage(stage);
      end;
      MainForm.SQLQuery1.Open();
      Result := TStringList.Create;
      while not MainForm.SQLQuery1.EOF do
      begin
        Result.Add(MainForm.SQLQuery1.FieldByName('number').AsString);
        MainForm.SQLQuery1.Next;
      end;
      MainForm.SQLQuery1.Close;
      MainForm.SQLTransaction1.Active := False;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

function CheckPenaltyInput(key: char): char;
  //в штрафе разрешаем только ввод цифр и спец.символов
begin
  //последние в свою очередь переводим в двоеточие
  Result := key;
  case key of
    '0'..'9': ;
    #8: ;           //backspace разрешаем:
    ',', '.', '/', '\', ':', '*', '-', '+', '?': Result := ':';
    else
      Result := #0;
      //все остальные символы запрещаем
  end;
end;

// Количество активных СУ
//function ActiveStagesCount: integer;
//var
//  i: integer;
//begin
//  Result := 0;
//  for i := 1 to maxstages do
//    if stages[i].isActive then
//      Inc(Result);
//end;

//высчитываем номер СУ, где стоит выделение
function GetSelectedStage: integer;
var
  co, i: integer;
begin
  Result := 1;
  //ставим первый если курсор на общей информации
  co := MainForm.RxDBGrid1.SelectedIndex;
  for i := 1 to maxstages do
  begin
    if (co > COMMON_COLS + STAGE_COLS * (i - 1)) and
      (co <= COMMON_COLS + STAGE_COLS * i) then
      Result := i;
  end;
end;

//высчитывает номер СУ, активное на данный момент
function ActiveStageIndex: integer;
var
  i: integer;
begin
  Result := 1;
  for i := 1 to maxstages do
  begin
    if MainForm.CurrentSU.Buttons[i - 1].Checked then
    begin
      Result := i;
      Break;
    end;
  end;
end;

function IsFinishesExists(stageIndex: integer): boolean;
begin
  Result := False;
  try
    if dbnotempty then
    begin
      Result := TMainSql.GetFinishCount(MainForm.SQLQuery1, stageIndex) > 0;
      MainForm.SQLTransaction1.Active := False;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(rsDatabaseOpenError + E.Message);
    end;
  end;
end;

function BackupBD: boolean;
var
  backupfolder: string = 'backup';
  backupfile: string;
begin
  Result := True;
  if not DirectoryExists(ExtractFilePath(fName) + backupfolder) then
  begin
    if not CreateDir(ExtractFilePath(fName) + backupfolder) then
    begin
      Result := False;
      Exit;
    end;
  end;
  backupfile := CreateAbsolutePath(FormatDateTime('YYYY-MM-DD hh-mm-ss', now) +
    ' ' + ExtractFileName(fname), ExtractFilePath(fName) + backupfolder);

  MainForm.SQLite3Connection1.Close();
  MainForm.SQLite3Connection1.ExecuteDirect(TSchemaSql.EndTransaction);
  MainForm.SQLite3Connection1.ExecuteDirect(TSchemaSql.VacuumInto(backupfile));
  MainForm.SQLite3Connection1.ExecuteDirect(TSchemaSql.BeginTransaction);
  MainForm.SQLTransaction1.Commit;
  MainForm.SQLTransaction1.Active := False;

  if (FileExists(backupfile)) and (FileSize(backupfile) > 0) then
  begin
    Result := True;
    Log(Format(rsBackupCreated, [backupfile]));
  end
  else
  begin
    Result := False;
  end;
end;

function HideLeadingZeroHour(Sender: TField): string;
var
  t, hour: TDateTime;
  fs: TFormatSettings;
  aText: string;
begin
  aText := (Sender as TField).AsString;
  if zerohour then
  begin
    if aText <> '' then
    begin
      fs.TimeSeparator := ':';
      fs.DecimalSeparator := '.';
      fs.ShortTimeFormat := 'hh:nn:ss.zzz';
      if TryStrToTime(aText, t, fs) then
      begin
        hour := EncodeTime(1, 0, 0, 0);
        if t < hour then
          aText := FormatDateTime('nn:ss.zzz', t);
      end;
    end;
  end;
  Result := aText;
end;

function HideLeadingZeroHour(time: string): string;
begin
  Result := time;
  if Pos('00:', Result) = 1 then
  begin
    Delete(Result, 1, 3);
  end;
end;

function FormatNumber(number: integer): string;
begin
  Result := Format('%3d', [number]);
end;

function FormatTime(time: string): string;
begin
  //9 правых символов в отсечке времени (отрезаем часы)
  Delete(time, 1, Length(time) - 9);
  if Pos('0', time) = 1 then
  begin
    Delete(time, 1, 1);
  end;
  Result := Format('%9s', [time]);
end;

function FormatDiff(diff: string; diffsign: string = ' '): string;
begin
  if (not diff.IsEmpty) then                                 //00:00:00.000
  begin
    //если разница во времени больше часа
    if (StrToInt(Copy(diff, 1, 2)) > 0) then
    begin
      Result := Copy(diff, 2, 7);
    end
    //если разница во времени больше десяти минуты
    else if (StrToInt(Copy(diff, 4, 2)) > 9) then
    begin
      Result := Copy(diff, 4, 7);
    end
    //если разница во времени меньше десяти минут но больше минуты
    else if (StrToInt(Copy(diff, 4, 2)) > 0) then
    begin
      Result := diffsign + Copy(diff, 5, 6);
    end
    //если разница во времени меньше минуты
    else
    begin
      //6 правых символов в отсечке времени (оставляем только секунды и тысычные)
      Delete(diff, 1, Length(diff) - 6);
      if Pos('0', diff) = 1 then
      begin
        Delete(diff, 1, 1);
      end;
      Result := diffsign + Format('%6s', [diff]);
    end;
  end
  else
  begin
    Result := diffsign + Format('%6s', [diff]);
  end;
end;

function FormatPlace(place: integer): string;
begin
  Result := FormatNumber(place);
end;

function FormatLEDLine(number: integer; time: string; diff: string;
  place: integer; diffsign: string = ' '): string;
begin
  Result := FormatNumber(number) + ' ' + FormatTime(time) + ' ' +
    FormatDiff(diff, diffsign) + ' ' + FormatPlace(place);

end;


function dbopen: boolean;
  //просто два коротких синонима
begin
  if MainForm.MainDataset1.Active then
    Result := True
  else
    Result := False;
end;

function dbnotempty: boolean;
begin
  if MainForm.MainDataset1.IsEmpty then
    Result := False
  else
    Result := True;
end;

{ BackupThread }

procedure BackupThread.Execute;
begin

end;

end.
