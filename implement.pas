unit Implement;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, rxdbgrid, Sqlite3DS, i18n, Dialogs,
  ComCtrls, StdCtrls, strutils, sqldb, sqlite3conn, LazUTF8, Forms,
  ButtonPanel, Math, fileutil, LazFileUtils, DB, dateutils, DateTimePicker,
  csvdocument;

type
  TMyDBGrid = class(TRxDBGrid);

  StartListSortBy =
    (
    slByResult,
    slByNumberAsc,
    slByNumberDesc,
    slByNameAsc,
    slByNameDesc
    );

procedure RefreshAll;
procedure RefreshResults;
procedure LoadIni;
procedure LoadIniCategory;
procedure SetfName(fName: string);
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
procedure UpdateSumResultsNew;
procedure UpdateThruResults;
procedure ClearResults(silent: boolean = False);
procedure SetDNSFromCorrection;
procedure SetStarttimeFromPopup;
procedure SetDNFFromOnTrace;
procedure LoadParticipantsList(FileName: string);
procedure LoadFinishTime(FileName: string);
procedure ExportFinishTime(FileName: string);
procedure ExportAllResults(FileName: string);
procedure ExportSumDays(FileName: string);
procedure GetFinishTime(FinishTime: TDateTime);
procedure SetLoRaTime(StartTime: TDateTime; correction: string);
procedure GenerateStartlistFromQualifier(FileName: string);
procedure ExportBDStartList(FileName: string);
procedure ParseSerial(Str: string);
procedure SQLQueryToCSV(FileName: string; Query: TSQLQuery; headers: boolean = False);
procedure AddDayResult(FileName: string);
procedure Print(Str: string);


function CatStartList: TStringList;
function GetAllStageStatus(stage: integer): TStringList;
function CountOccurrences(ASubString: string; AString: string): integer;
function CheckPenaltyInput(key: char): char;
function SelectedStage: integer;
function CurrentStage: integer;
function BackupBD: boolean;
function HideLeadingZeroHour(Sender: TField): string;
function dbopen: boolean;
function dbnotempty: boolean;

implementation

uses Main, Result, Startlist;

{$I include/my.inc}

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
    //и основном гриде
    row := TMyDBGrid(MainForm.RxDBGrid1).Row;
  end;
  for n := 0 to MainForm.ComponentCount - 1 do
  begin
    c := MainForm.Components[n];
    if c is TSqlite3Dataset then
    begin
      TSqlite3Dataset(c).Close;
      try
        TSqlite3Dataset(c).Open;
      except
        On E: Exception do
        begin
          MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
          Log(sDatabaseOpenError + E.Message);
        end;
      end;
    end;
  end;
  RefreshResults;
  if db then
  begin
    MainForm.MainDataset1.Locate('id', id, []);
    //восстанавливаем положение курсора
    MainForm.RxDBGrid1.DataSource.DataSet.MoveBy(-row + 1);
    //и основного грида после открытия
    MainForm.RxDBGrid1.DataSource.DataSet.MoveBy(row - 1);
    //(на остальные забили)
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
      TSqlite3Dataset(c).Close;
      try
        TSqlite3Dataset(c).Open;
      except
        On E: Exception do
        begin
          MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
          Log(sDatabaseOpenError + E.Message);
        end;
      end;
    end;
  end;
end;

procedure LoadIni;
var
  c: TComponent;
  i: integer;
begin
  Screen.Cursor := crHourGlass;
  try
    if FileExists(fName) then
    begin
      //пока датасеты закрыты, проверяем наличие файла соревнований
      for i := 1 to visiblecat do
      begin
        MainForm.SQLQuery1.Close;
        MainForm.SQLQuery1.SQL.Text :=
          'SELECT * FROM config WHERE key = "catname' + IntToStr(i) + '";';
        MainForm.SQLQuery1.Open();
        cat[i] := MainForm.SQLQuery1.FieldByName('value').AsString;
      end;
      for i := 1 to maxstages do
      begin
        MainForm.SQLQuery1.Close;
        MainForm.SQLQuery1.SQL.Text :=
          'SELECT * FROM config WHERE key = "stage' + IntToStr(i) + '";';
        MainForm.SQLQuery1.Open();
        stage[i] := MainForm.SQLQuery1.FieldByName('value').AsBoolean;
        MainForm.SQLQuery1.Close;
        MainForm.SQLQuery1.SQL.Text :=
          'SELECT * FROM config WHERE key = "stagename' + IntToStr(i) + '";';
        MainForm.SQLQuery1.Open();
        sname[i] := MainForm.SQLQuery1.FieldByName('value').AsString;
      end;
      MainForm.SQLQuery1.Close;
      MainForm.SQLQuery1.SQL.Text :=
        'SELECT * FROM config WHERE key = "activestage";';
      MainForm.SQLQuery1.Open();
      astage := MainForm.SQLQuery1.FieldByName('value').AsString;
      if astage = '' then
        astage := '1';

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
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;

  //  RxIniPropStorage1.Restore;

  if sname[1] = '' then
    sname[1] := sSU1;
  if sname[2] = '' then
    sname[2] := sSU2;
  if sname[3] = '' then
    sname[3] := sSU3;
  if sname[4] = '' then
    sname[4] := sSU4;
  if sname[5] = '' then
    sname[5] := sSU5;
  if sname[6] = '' then
    sname[6] := sSU6;

  for i := 1 to maxstages do
  begin
    c := MainForm.FindComponent('SheetStage' + IntToStr(i));
    TTabSheet(c).Caption := sname[i];

    with MainForm.GridResult8 do
    begin
      ColumnByFieldName('result' + IntToStr(i)).Title.Caption := sname[i];
      if stage[i] then
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
        sname[i] + '|' + scorrection;
      ColumnByFieldName('starttime' + IntToStr(i)).Title.Caption :=
        sname[i] + '|' + sstarttime;
      ColumnByFieldName('finishtime' + IntToStr(i)).Title.Caption :=
        sname[i] + '|' + sfinishtime;
      ColumnByFieldName('penalty' + IntToStr(i)).Title.Caption :=
        sname[i] + '|' + spenalty;
      ColumnByFieldName('result' + IntToStr(i)).Title.Caption :=
        sname[i] + '|' + sresult;
      ColumnByFieldName('diffleader' + IntToStr(i)).Title.Caption :=
        sname[i] + '|' + sdiffleader;
      ColumnByFieldName('place' + IntToStr(i)).Title.Caption :=
        sname[i] + '|' + splace;
    end;
    //скрываем неиспользуемые СУ
    if stage[i] then
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
      c := MainForm.FindComponent('RadioCur' + IntToStr(i));
      TRadioButton(c).Enabled := True;
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
      c := MainForm.FindComponent('RadioCur' + IntToStr(i));
      TRadioButton(c).Enabled := False;
      c := MainForm.FindComponent('SheetStage' + IntToStr(i));
      TTabSheet(c).TabVisible := False;
    end;
  end;

  //настройка для работы с одним этапом
  if (not stage[2]) and (not stage[3]) and (not stage[4]) and
    (not stage[5]) and (not stage[6]) then
  begin
    MainForm.CurrentSU.Visible := False;
    MainForm.RadioCur1.Checked := True;
    MainForm.SheetStageSum.TabVisible := False;
    MainForm.SheetStage1.Caption := stotal;
    MainForm.GridResult8.ColumnByFieldName('result1').Visible := False;
    with MainForm.RxDBGrid1 do
    begin
      ColumnByFieldName('correction1').Title.Caption := scorrection;
      ColumnByFieldName('starttime1').Title.Caption := sstarttime;
      ColumnByFieldName('finishtime1').Title.Caption := sfinishtime;
      ColumnByFieldName('penalty1').Title.Caption := spenalty;
      ColumnByFieldName('result1').Title.Caption := sresult;
      ColumnByFieldName('diffleader1').Title.Caption := sdiffleader;
      ColumnByFieldName('place1').Title.Caption := splace;
      ColumnByFieldName('place1').Visible := False;
      //RxDBGrid1.ColumnByFieldName('sumresult').Visible:=false;
      //RxDBGrid1.ColumnByFieldName('sumdiffleader').Visible:=false;
      ColumnByFieldName('sumresult').Visible := True;
      ColumnByFieldName('sumdiffleader').Visible := True;
      ColumnByFieldName('result1').Visible := False;
      ColumnByFieldName('diffleader1').Visible := False;
    end;
  end
  else
  begin
    MainForm.CurrentSU.Visible := True;
    MainForm.RxDBGrid1.ColumnByFieldName('sumresult').Visible := True;
    MainForm.RxDBGrid1.ColumnByFieldName('sumdiffleader').Visible := True;
    MainForm.SheetStageSum.TabVisible := True;
  end;
  Screen.Cursor := crDefault;
end;

procedure LoadIniCategory;
var
  c: TComponent;
  i: integer;
begin
  for i := 1 to visiblecat do
  begin
    c := ResultsForm.FindComponent('GroupBox' + IntToStr(i));
    TGroupBox(c).Caption := cat[i];
    c := ResultsForm.FindComponent('CatDataset' + IntToStr(i));
    TSqlite3Dataset(c).SQL :=
      'Select number, name, result' + astage + ' as result, diffleader' +
      astage + ' as diffleader, place' + astage +
      ' as place from main WHERE category = ' + '''' + cat[i] + '''' +
      ' AND result' + astage + ' > 0 ORDER BY status ASC, result' + astage + ' ASC';
  end;
  ResultsForm.ResultDataset.SQL :=
    'Select number, name, category, result' + astage + ' as result, place' +
    astage + ' as place from main WHERE finishtime' + astage +
    ' > 0 AND status ISNULL ORDER BY finishtime' + astage + ' DESC';
  ResultsForm.GroupBoxResults.Caption :=
    sCurrentResults + ': ' + sname[StrToInt(astage)];
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
//  LoadIni;
//  LoadIniCategory;
//  // --> close-open dataset в Main и затем в settings (RefreshResults)
//  RefreshAll;
//  Log(sDBFileOpen + ' ' + fName);
//end;

procedure SetStatus(const status: string);
var
  n: string;
begin
  if dbnotempty then
  begin
    n := MainForm.MainDataset1.FieldByName('number').AsString;
    SetSQLStatus(SelectedStage, status, n);
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
        logstatus := sDidNotStart;
      end
      else
      begin
        s := '1';
        logstatus := sDidNotFinish;
      end;
      if (not stage[2]) and (not stage[3]) and (not stage[4]) and
        (not stage[5]) and (not stage[6]) then
      begin
        d := sSureWithNumber + ' ' + n + ' ' + logstatus + '?';
        l := sParticipantWithNumber + ' ' + n + ' ' + logstatus;
      end
      else
      begin
        if sSU + ' ' + IntToStr(i) = sname[i] then
        begin
          d := sSureWithNumber + ' ' + n + ' ' + logstatus + ' ' +
            sOnStage + ' ' + IntToStr(i) + '?';
          l := sParticipantWithNumber + ' ' + n + ' ' + logstatus +
            ' ' + sOnStage + ' ' + IntToStr(i);
        end
        else
        begin
          d := sSureWithNumber + ' ' + n + ' ' + logstatus + ' ' +
            sOnStage + ' ' + IntToStr(i) + ': ' + sname[i] + '?';
          l := sParticipantWithNumber + ' ' + n + ' ' + logstatus +
            ' ' + sOnStage + ' ' + IntToStr(i) + ': ' + sname[i];
        end;
      end;
      if MessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
      begin
        with MainForm.SQLQuery1 do
        begin
          SQL.Clear;
          SQL.Add('UPDATE main SET place' + IntToStr(i) + ' = NULL, result' +
            IntToStr(i) + ' = "' + status + '", diffleader' + IntToStr(i) +
            ' = NULL, status' + IntToStr(i) + ' = ' + s + ' WHERE number = :NUMBER;');
          ParamByName('NUMBER').AsString := n;
          ExecSQL;
          SQLTransaction.Commit;
          Close;
        end;
        SetGlobalStatus(n);
        UpdateResults;
        Log(l);
      end;
    end
    else
    begin
      if MessageDlg(sReallyDisqualifyNumber + ' ' + n + '?', mtWarning,
        [mbYes, mbNo], 0) = mrYes then
      begin
        with MainForm.SQLQuery1 do
        begin
          SQL.Clear;
          //        SQL.Add('UPDATE main SET place1 = NULL, result1 = "DSQ", diffleader1 = NULL, status = 3 WHERE number = :NUMBER;');
          SQL.Add('UPDATE main SET status = 3 WHERE number = :NUMBER;');
          ParamByName('NUMBER').AsString := n;
          ExecSQL;
          SQLTransaction.Commit;
          Close;
        end;
        UpdateResults;
        Log(sParticipantWithNumber + ' ' + n + ' ' + sDisqualified);
      end;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure SetGlobalStatus(n: string);
//высчитывает глобальный статус (status) на основе статусов СУ
var
  stat: string = 'NULL';
  st: array[0..6] of integer;
  k: integer;
begin
  try
    with MainForm.SQLQuery1 do
    begin
      SQL.Clear;
      SQL.Add('SELECT * from main where number = :NUMBER;');
      ParamByName('NUMBER').AsString := n;
      Open;
      if FieldByName('status').AsString <> '3' then
      begin
        //если не общий дисквал, то считаем
        for k := 1 to maxstages do
        begin
          if stage[k] then
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
        Close;
        SQL.Clear;
        SQL.Add('UPDATE main SET status = ' + stat + ' WHERE number = :NUMBER;');
        ParamByName('NUMBER').AsString := n;
        ExecSQL;
        SQLTransaction.Commit;
      end;
      Close;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
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
        //MainForm.Memo.Lines.Add(n[i]);
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
      if (not stage[2]) and (not stage[3]) and (not stage[4]) and
        (not stage[5]) and (not stage[6]) then
      begin
        d := sClearAllStatus + ' ' + n + '?';
        l := sClearAllStatusLog + ' ' + n;
        if MessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          with MainForm.SQLQuery1 do
          begin
            SQL.Clear;
            SQL.Add('UPDATE main SET place' + IntToStr(i) + ' = NULL, result' +
              IntToStr(i) + ' = NULL, diffleader' + IntToStr(i) +
              ' = NULL, status' + IntToStr(i) +
              ' = NULL, status = NULL WHERE number = :NUMBER;');
            ParamByName('NUMBER').AsString := n;
            ExecSQL;
            SQLTransaction.Commit;
            Close;
          end;
          SetGlobalStatus(n);
          UpdateResults;
          Log(l);
          Print('1');
        end;
      end
      else
      // выделение в общих результатах
      if (co > commoncols + stagecols * maxstages) then
      begin
        d := sClearDSQ + ' ' + n + '?';
        l := sClearDSQLog + ' ' + n;
        if MessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          with MainForm.SQLQuery1 do
          begin
            SQL.Clear;
            SQL.Add('UPDATE main SET status = NULL WHERE number = :NUMBER;');
            ParamByName('NUMBER').AsString := n;
            ExecSQL;
            SQLTransaction.Commit;
            Close;
          end;
          SetGlobalStatus(n);
          UpdateResults;
          Log(l);
          Print('2');
        end;
      end
      else
      begin
        i := SelectedStage;
        if sSU + ' ' + IntToStr(i) = sname[i] then
        begin
          d := sClearStatus + ' ' + n + ' ' + sOnStage + ' ' + IntToStr(i) + '?';
          l := sClearStatusLog + ' ' + n + ' ' + sOnStage + ' ' + IntToStr(i);
        end
        else
        begin
          d := sClearStatus + ' ' + n + ' ' + sOnStage + ' ' +
            IntToStr(i) + ': ' + sname[i] + '?';
          l := sClearStatusLog + ' ' + n + ' ' + sOnStage + ' ' +
            IntToStr(i) + ': ' + sname[i];
        end;
        if MessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          with MainForm.SQLQuery1 do
          begin
            SQL.Clear;
            SQL.Add('UPDATE main SET place' + IntToStr(i) + ' = NULL, result' +
              IntToStr(i) + ' = NULL, diffleader' + IntToStr(i) +
              ' = NULL, status' + IntToStr(i) + ' = NULL WHERE number = :NUMBER;');
            ParamByName('NUMBER').AsString := n;
            ExecSQL;
            SQLTransaction.Commit;
            Close;
          end;
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
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
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
        MainForm.SQLite3Connection1.ExecuteDirect('CREATE TABLE "main" (' +
          ' "id"	    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,' +
          ' "category"	    VARCHAR,' + ' "sumplace"	  INTEGER,' +
          ' "number"	    INTEGER UNIQUE,' + ' "rfid"   INTEGER,' +
          ' "name"          VARCHAR,' + ' "nickname"	  VARCHAR,' +
          ' "age"           VARCHAR,' + ' "team"          VARCHAR,' +
          ' "city"          VARCHAR,' + ' "starttime1"	  VARCHAR,' +
          ' "correction1"   INTEGER,' + ' "finishtime1"   VARCHAR,' +
          ' "penalty1"	    VARCHAR,' + ' "result1"	  VARCHAR,' +
          ' "diffleader1"   VARCHAR,' + ' "place1"	  INTEGER,' +
          ' "status1"       VARCHAR,' + ' "starttime2"	  VARCHAR,' +
          ' "correction2"   INTEGER,' + ' "finishtime2"   VARCHAR,' +
          ' "penalty2"	    VARCHAR,' + ' "result2"	  VARCHAR,' +
          ' "diffleader2"   VARCHAR,' + ' "place2"        INTEGER,' +
          ' "status2"       VARCHAR,' + ' "starttime3"    VARCHAR,' +
          ' "correction3"   INTEGER,' + ' "finishtime3"   VARCHAR,' +
          ' "penalty3"	    VARCHAR,' + ' "result3"	  VARCHAR,' +
          ' "diffleader3"   VARCHAR,' + ' "place3"        INTEGER,' +
          ' "status3"       VARCHAR,' + ' "starttime4"	  VARCHAR,' +
          ' "correction4"   INTEGER,' + ' "finishtime4"   VARCHAR,' +
          ' "penalty4"	    VARCHAR,' + ' "result4"       VARCHAR,' +
          ' "diffleader4"   VARCHAR,' + ' "place4"        INTEGER,' +
          ' "status4"       VARCHAR,' + ' "starttime5"	  VARCHAR,' +
          ' "correction5"   INTEGER,' + ' "finishtime5"   VARCHAR,' +
          ' "penalty5"	    VARCHAR,' + ' "result5"	  VARCHAR,' +
          ' "diffleader5"   VARCHAR,' + ' "place5"        INTEGER,' +
          ' "status5"       VARCHAR,' + ' "starttime6"    VARCHAR,' +
          ' "correction6"   INTEGER,' + ' "finishtime6"   VARCHAR,' +
          ' "penalty6"	    VARCHAR,' + ' "result6"	  VARCHAR,' +
          ' "diffleader6"   VARCHAR,' + ' "place6"        INTEGER,' +
          ' "status6"       VARCHAR,' + ' "sumresult"     VARCHAR,' +
          ' "sumdiffleader" VARCHAR,' + ' "sumstages"     INTEGER,' +
          ' "thrudiff"      VARCHAR,' + ' "thruplace"     VARCHAR,' +
          ' "status"	    VARCHAR);');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect('CREATE TABLE "load" (' +
          ' "category"	 VARCHAR,' + ' "number"	    INTEGER,' +
          ' "name"	 VARCHAR,' + ' "nickname"   VARCHAR,' +
          ' "age"        VARCHAR,' + ' "team"	    VARCHAR,' +
          ' "city"       VARCHAR,' + ' "starttime1" VARCHAR,' +
          ' "starttime2" VARCHAR,' + ' "starttime3" VARCHAR,' +
          ' "starttime4" VARCHAR,' + ' "starttime5" VARCHAR,' +
          ' "starttime6" VARCHAR);');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect(
          'CREATE TABLE "loadresult" (' + ' "number"  INTEGER UNIQUE,' +
          ' "starttime"	  VARCHAR,' + ' "correction"  INTEGER,' +
          ' "finishtime"  VARCHAR,' + ' "penalty"     VARCHAR,' +
          ' "status"	  VARCHAR' + ');');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect('CREATE TABLE "start" (' +
          '"id"	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,' +
          '"number"	INTEGER UNIQUE,' + '"starttime"  	   TEXT,' +
          '"automaticstarttime"	TEXT,' + '"automaticcorrection"    INTEGER,' +
          '"automaticphonetime"	TEXT,' + '"manualstarttime"        TEXT,' +
          '"manualcorrection"	INTEGER,' + '"finishtime"          TEXT);');

        //'CREATE TABLE "start" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,' +
        //'"number" INTEGER UNIQUE,' + '"starttime" TEXT,' + '"gotime" TEXT,' +
        //'"correction" INTEGER,' + '"finishtime" TEXT);');




        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect(
          'CREATE TABLE "finish" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,'
          + '"number" INTEGER UNIQUE,' + '"finishtime" TEXT,' +
          '"phonetime"	TEXT,' + '"set" INTEGER,' + '"manual" INTEGER);');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect('CREATE TABLE "config" (' +
          ' "key"	          VARCHAR UNIQUE,' + ' "value"	  VARCHAR);');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect('CREATE TABLE "lora" (' +
          ' "id"	  INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,' +
          ' "number"	  INTEGER,' + ' "starttime"          VARCHAR,' +
          ' "correction"  VARCHAR,' + ' "isset"              INTEGER,' +
          ' "timemark"	  VARCHAR' + ');');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect(
          'INSERT INTO config (key, value) VALUES' + '("activestage", "1"),' +
          '("stage1", "True"),' + '("catname1", "' + sCat1 + '"),' +
          '("catname2", "' + sCat2 + '"),' + '("catname3", "' + sCat3 +
          '"),' + '("catname4", "' + sCat4 + '"),' + '("catname5", "' +
          sCat5 + '")' + ';');
        MainForm.SQLTransaction1.Commit;

        Log(sNewFileCreated + ': ' + fName);
      except
        MessageDlg(sNewFileNotCreated, mtError, [mbOK], 0);
        Log(sNewFileNotCreated);
        Screen.Cursor := crDefault;
        // Если файл не создан, не пытаемся его открыть
        Exit;
      end;
      Screen.Cursor := crDefault;
    end;

    //OpenDB;
    LoadIni;
    LoadIniCategory;
    // --> close-open dataset в Main и затем в settings (RefreshResults)
    RefreshAll;
    Log(sDBFileOpen + ' ' + fName);
  except
    MessageDlg(sNewFileExistUnknow, mtError, [mbOK], 0);
    Log(sNewFileExistUnknow);
  end;
end;

procedure SetFinish;
var
  row, number, i: integer;
  setfinish: boolean = False;
  c: TComponent;
begin
  Screen.Cursor := crSQLWait;
  try
    for row := MainForm.sGridResult.RowCount - 1 downto 1 do
    begin
      if (TryStrToInt(MainForm.sGridResult.Cells[1, row], number)) and (number > 0) then
      begin
        MainForm.SQLQuery1.Active := False;
        MainForm.SQLQuery1.SQL.Text :=
          'select * from main where number = :NUMBER;';
        MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := number;
        MainForm.SQLQuery1.Active := True;
        if MainForm.SQLQuery1.FieldByName('number').AsInteger = number then
        begin
          //проверяем что номер есть в таблице результатов
          MainForm.SQLite3Connection2.Open;
          MainForm.SQLTransaction2.Active := True;
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
            if MessageDlg(sNumber + ' ' + IntToStr(number) + ' ' +
              sDidNotStartSetFinish, mtWarning, [mbYes, mbNo], 0) = mrYes then
              setfinish := True
            else
              setfinish := False;
          end
          else
            setfinish := True;
          MainForm.SQLQuery2.Active := False;
          MainForm.SQLite3Connection2.Close;
          MainForm.SQLTransaction2.Active := False;
          for i := 1 to maxstages do
          begin
            c := MainForm.FindComponent('RadioCur' + IntToStr(i));
            if TRadioButton(c).Checked and setfinish then
            begin
              //проверяем в какой этап заносить результат
              if MainForm.SQLQuery1.FieldByName('result' + IntToStr(i)).AsString <> '' then
              begin
                if MessageDlg(sUpdateFinishTime + ' ' + IntToStr(number) +
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
            MainForm.SQLQuery1.SQL.Clear;
            MainForm.SQLQuery1.SQL.Add('UPDATE main');
            for i := 1 to maxstages do
            begin
              c := MainForm.FindComponent('RadioCur' + IntToStr(i));
              if TRadioButton(c).Checked then
                MainForm.SQLQuery1.SQL.Add('SET finishtime' + IntToStr(i) +
                  ' = :TIME' + ', status' + IntToStr(i) + ' = NULL');
            end;
            MainForm.SQLQuery1.SQL.Add('WHERE number = :NUMBER;');
            MainForm.SQLQuery1.ParamByName('TIME').Text :=
              MainForm.sGridResult.Cells[0, row];
            MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := number;
            MainForm.SQLQuery1.ExecSQL;
            //ставим время финиша для номера
            UpdateResults;
            //ставим результат
            MainForm.sGridResult.DeleteRow(row);
            Log(sFinishTimeSet + ' ' + IntToStr(number));
          end;
        end
        else
          Log(sNumber + ' ' + IntToStr(number) + ' ' + sDoNotExist);
      end;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;
  Screen.Cursor := crDefault;
end;

procedure SetCorrectionFromLoRa;
var
  n, correction, id: string;
  setcorrection: boolean;
begin
  if dbopen and not MainForm.DatasetLoRa.IsEmpty then
  begin
    n := MainForm.DatasetLoRa.FieldByName('number').AsString;
    correction := MainForm.DatasetLoRa.FieldByName('correction').AsString;
    id := MainForm.DatasetLoRa.FieldByName('id').AsString;
    if n <> '' then
    begin
      with MainForm.SQLQuery1 do
      begin
        Close;
        SQL.Text := 'SELECT * FROM main WHERE number = ' + n + ';';
        Open;
        //проверяем что номер есть в таблице результатов
        if FieldByName('number').AsString = n then
        begin
          if FieldByName('correction' + IntToStr(CurrentStage)).AsString = '' then
            //если поправки нет
          begin
            setcorrection := True;
          end
          else
            //если поправка есть спрашиваем переписать или нет
          begin
            if MessageDlg(sNumberu + ' ' + n + ' ' + sCorrectionAlreadySet,
              mtWarning, [mbYes, mbNo], 0) = mrYes then
              setcorrection := True
            else
              setcorrection := False;
          end;
          if setcorrection then
          begin
            Close;
            SQL.Text := 'UPDATE main SET correction' + IntToStr(CurrentStage) +
              ' = ' + correction + ' WHERE number = ' + n + ';';
            ExecSQL;
            Close;
            SQL.Text := 'UPDATE lora SET isset = 1 WHERE id = ' + id + ';';
            ExecSQL;
            SQLTransaction.Commit;
            Close;
            UpdateResults;
          end;
        end
        else
        begin
          Log(sNumber + ' ' + n + ' ' + sDoNotExist);
        end;
        Close;
        MainForm.SQLite3Connection1.Close;
        MainForm.SQLTransaction1.Active := False;
      end;
    end;
  end;
end;

procedure UpdateResults;
begin
  Screen.Cursor := crSQLWait;

  UpdateStageResults;
  UpdateSumResultsNew;
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
      if stage[i] then
        with MainForm.SQLQuery1 do
        begin
          SQL.Clear;

          //ставим результат
          SQL.Add('UPDATE main SET result' + IntToStr(i) + ' = CASE');
          SQL.Add('WHEN status IS "3" THEN "DSQ"');
          SQL.Add('WHEN status' + IntToStr(i) + ' IS "1" THEN "DNF"');
          SQL.Add('WHEN status' + IntToStr(i) + ' IS "2" THEN "DNS"');
          //      SQL.Add('WHEN status'+IntToStr(i)+' IS "3" THEN "DSQ"');
          SQL.Add('WHEN correction' + IntToStr(i) + ' IS NULL AND penalty' +
            IntToStr(i) + ' IS NULL AND status' + IntToStr(i) +
            ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
            IntToStr(i) + ') - julianday(starttime' + IntToStr(i) + ') +1.5)');
          SQL.Add('WHEN correction' + IntToStr(i) + ' < 0 AND penalty' +
            IntToStr(i) + ' IS NULL AND status' + IntToStr(i) +
            ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
            IntToStr(i) + ') - julianday(starttime' + IntToStr(i) +
            ') +1.5 - julianday(-correction' + IntToStr(i) + '/86400000.0))');
          SQL.Add('WHEN correction' + IntToStr(i) + ' >= 0 AND penalty' +
            IntToStr(i) + ' IS NULL AND status' + IntToStr(i) +
            ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
            IntToStr(i) + ') - julianday(starttime' + IntToStr(i) +
            ') +1.5 + julianday(correction' + IntToStr(i) + '/86400000.0))');
          SQL.Add('WHEN correction' + IntToStr(i) + ' IS NULL AND penalty' +
            IntToStr(i) + ' > 0 AND status' + IntToStr(i) +
            ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
            IntToStr(i) + ') - julianday(starttime' + IntToStr(i) +
            ') + julianday(penalty' + IntToStr(i) + ') -0.5 +1.5)');
          SQL.Add('WHEN correction' + IntToStr(i) + ' < 0 AND penalty' +
            IntToStr(i) + ' > 0 AND status' + IntToStr(i) +
            ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
            IntToStr(i) + ') - julianday(starttime' + IntToStr(i) +
            ') +1.5 + julianday(penalty' + IntToStr(i) +
            ')-0.5 - julianday(-correction' + IntToStr(i) + '/86400000.0))');
          SQL.Add('WHEN correction' + IntToStr(i) + ' >= 0 AND penalty' +
            IntToStr(i) + ' > 0 AND status' + IntToStr(i) +
            ' ISNULL THEN strftime(''%H:%M:%f'',julianday(finishtime' +
            IntToStr(i) + ') - julianday(starttime' + IntToStr(i) +
            ') +1.5 + julianday(penalty' + IntToStr(i) +
            ')-0.5 + julianday(correction' + IntToStr(i) + '/86400000.0))');
          SQL.Add('END,');
          SQL.Add('finishtime' + IntToStr(i) + ' = CASE WHEN status' +
            IntToStr(i) + ' NOTNULL THEN NULL ELSE finishtime' + IntToStr(i) + ' END;');
          ExecSQL;
          SQL.Clear;

          //обнуляем места (а вдруг были) для dsq/dnf/dns (сейчас для всех)
          SQL.Add('UPDATE main SET place' + IntToStr(i) + ' = NULL, diffleader' +
            IntToStr(i) + ' = NULL;');
          //WHERE status NOTNULL;');
          ExecSQL;
          SQL.Clear;

          //обновляем места
          SQL.Add('INSERT into main (number, place' + IntToStr(i) + ')');
          SQL.Add(
            'SELECT number, row_number() over(partition BY category ORDER BY result' +
            IntToStr(i) + ') as place' + IntToStr(i) + ' FROM main WHERE result' +
            IntToStr(i) + ' > 0 AND status' + IntToStr(i) +
            ' ISNULL AND (status IS NULL OR status <> 3) ORDER BY finishtime' +
            IntToStr(i) + ' DESC');
          SQL.Add('ON CONFLICT(number) DO UPDATE SET place' + IntToStr(i) +
            ' = excluded.place' + IntToStr(i) + ';');
          ExecSQL;
          SQL.Clear;

          //обнуляем отставание для первых номеров
          SQL.Add('UPDATE main SET diffleader' + IntToStr(i) +
            ' = NULL WHERE place' + IntToStr(i) + ' = 1;');
          ExecSQL;
          SQL.Clear;

          //ставим отставание от лидера категории
          SQL.Add('WITH');
          SQL.Add('t1(leader1, cat1, num1) AS (SELECT julianday(result' +
            IntToStr(i) + '), category, number FROM main WHERE place' +
            IntToStr(i) + ' = 1),');
          SQL.Add('t2(current,cat2, num2) AS (SELECT julianday(result' +
            IntToStr(i) + '), category, number FROM main WHERE place' +
            IntToStr(i) + ' > 1)');
          SQL.Add('INSERT into main (diffleader' + IntToStr(i) + ', number)');
          SQL.Add(
            'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), t2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2');
          SQL.Add('ON CONFLICT(number) DO UPDATE SET diffleader' +
            IntToStr(i) + '= excluded.diffleader' + IntToStr(i) + ';');
          ExecSQL;
          SQLTransaction.Commit;
          Close;
        end;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure UpdateSumResults;           //для суммы этапов
var
  i: integer;
begin
  try
    with MainForm.SQLQuery1 do
    begin
      SQL.Clear;
      SQL.Add('UPDATE main SET sumresult = CASE');
      //      SQL.Add('WHEN status IS "1" THEN "DNF"');
      //      SQL.Add('WHEN status IS "2" THEN "DNS"');
      SQL.Add('WHEN status IS "3" THEN "DSQ"');
      SQL.Add('ELSE strftime(''%H:%M:%f'',0.5');
      for i := 1 to maxstages do
      begin
        if stage[i] then
          SQL.Add('+ julianday(result' + IntToStr(i) + ') -2451543.5');
      end;
      SQL.Add(')END;');
      ExecSQL;
      //ставим общий результат
      SQL.Clear;
      SQL.Add('UPDATE main SET sumplace = NULL, sumdiffleader = NULL;');
      // WHERE status NOTNULL;');
      ExecSQL;
      //обнуляем места (а вдруг были) для dsq/dnf/dns
      SQL.Clear;
      SQL.Add('INSERT into main (number, sumplace)');
      SQL.Add(
        'SELECT number, row_number() over(partition BY category ORDER BY sumresult) as sumplace FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY sumresult DESC');
      SQL.Add('ON CONFLICT(number) DO UPDATE SET sumplace = excluded.sumplace;');
      ExecSQL;
      //обновляем места
      SQL.Clear;
      SQL.Add('UPDATE main SET sumdiffleader = NULL WHERE sumplace = 1;');
      ExecSQL;
      //обнуляем отставание для первых номеров
      SQL.Clear;
      SQL.Add('WITH');
      SQL.Add(
        't1(leader1, cat1, num1) AS (SELECT julianday(sumresult), category, number FROM main WHERE sumplace = 1),');
      SQL.Add(
        't2(current,cat2, num2) AS (SELECT julianday(sumresult), category, number FROM main WHERE sumplace > 1)');
      SQL.Add('INSERT into main (sumdiffleader, number)');
      SQL.Add(
        'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), t2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2');
      SQL.Add(
        'ON CONFLICT(number) DO UPDATE SET sumdiffleader= excluded.sumdiffleader;');
      ExecSQL;
      //ставим отставание от лидера категории
      SQLTransaction.Commit;
      Close;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure UpdateSumResultsNew;
var
  sumtime, outtime: TDateTime;
  stringtime: string;
  i, sumstages: integer;
begin
  try
    with MainForm.SQLQuery1 do
    begin
      Close;
      SQL.Text := 'SELECT * FROM main';
      Open;
      while not EOF do
      begin
        sumtime := 0;
        sumstages := 0;
        for i := 1 to maxstages do
        begin
          if stage[i] then
          begin
            stringtime := FieldByName('result' + IntToStr(i)).AsString;
            if stringtime <> '' then
            begin
              stringtime :=
                StringReplace(stringtime, '.', DefaultFormatSettings.DecimalSeparator,
                [rfReplaceAll]);
              if TryStrToTime(stringtime, outtime) then
              begin
                sumtime := sumtime + outtime;
                sumstages := sumstages + 1;
              end;
            end;
          end;
        end;
        Edit;
        if FieldByName('status').AsString = '3' then
        begin
          FieldByName('sumresult').AsString := 'DSQ';
          FieldByName('sumstages').Clear;
        end
        else
        begin
          if sumtime <> 0 then
          begin
            FieldByName('sumresult').AsString :=
              FormatDateTime('hh:nn:ss.zzz', sumtime);
            FieldByName('sumstages').AsInteger := sumstages;
            FieldByName('status').Clear;
          end
          else
          begin
            FieldByName('sumresult').Clear;
            FieldByName('sumstages').Clear;
            if (FieldByName('status').AsString) = '1' then
            begin
              FieldByName('sumresult').AsString := 'DNF';
            end;
            if (FieldByName('status').AsString) = '2' then
            begin
              FieldByName('sumresult').AsString := 'DNS';
            end;
          end;
        end;
        ApplyUpdates;
        Next;
      end;
      SQLTransaction.Commit;
      Close;
      SQL.Clear;
      //обнуляем места (а вдруг были) для dsq/dnf/dns
      SQL.Add('UPDATE main SET sumplace = NULL, sumdiffleader = NULL;');
      // WHERE status NOTNULL;');
      ExecSQL;
      SQL.Clear;

      //ставим место только тем, у кого есть результаты на всех активных СУ
      //и не было DNS/DNF
      //обновляем места
      SQL.Add('INSERT into main (number, sumplace)');
      SQL.Add(
        'SELECT number, row_number() over(partition BY category ORDER BY sumresult) as sumplace FROM main WHERE sumresult > 0 AND status ISNULL');
      for i := 1 to maxstages do
      begin
        if stage[i] then
        begin
          SQL.Add('AND result' + IntToStr(i) + ' NOTNULL');
          SQL.Add('AND status' + IntToStr(i) + ' IS NULL');
        end;
      end;
      SQL.Add('ORDER BY sumresult DESC');
      SQL.Add('ON CONFLICT(number) DO UPDATE SET sumplace = excluded.sumplace;');
      ExecSQL;
      SQL.Clear;

      //обнуляем отставание для первых номеров
      SQL.Add('UPDATE main SET sumdiffleader = NULL WHERE sumplace = 1;');
      ExecSQL;
      SQL.Clear;

      //ставим отставание от лидера категории
      SQL.Add('WITH');
      SQL.Add(
        't1(leader1, cat1, num1) AS (SELECT julianday(sumresult), category, number FROM main WHERE sumplace = 1),');
      SQL.Add(
        't2(current,cat2, num2) AS (SELECT julianday(sumresult), category, number FROM main WHERE sumplace > 1)');
      SQL.Add('INSERT into main (sumdiffleader, number)');
      SQL.Add(
        'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), t2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2');
      SQL.Add(
        'ON CONFLICT(number) DO UPDATE SET sumdiffleader= excluded.sumdiffleader;');
      ExecSQL;
      SQL.Clear;

      //ставим отставание в количестве СУ
      SQL.Add('WITH');
      SQL.Add(
        't1(sumstages1, cat1, num1) AS (SELECT sumstages, category, number FROM main WHERE sumplace = 1),');
      SQL.Add(
        't2(current,cat2, num2) AS (SELECT sumstages, category, number FROM main WHERE sumplace IS NULL AND sumstages NOT NULL AND (status < 3 OR status IS NULL))');
      SQL.Add('INSERT into main (sumdiffleader, number)');
      SQL.Add('SELECT ''+'' || (t1.sumstages1 - t2.current) || ''' +
        ' ' + sSU + ''', t2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2');
      SQL.Add(
        'ON CONFLICT(number) DO UPDATE SET sumdiffleader= excluded.sumdiffleader;');
      ExecSQL;
      SQLTransaction.Commit;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure UpdateThruResults;                     //для сквозного
begin
  try
    with MainForm.SQLQuery1 do
    begin
      SQL.Clear;

      //обнуляем отставание и место для всех
      SQL.Add('UPDATE main SET thrudiff = NULL, thruplace = NULL;');
      ExecSQL;
      SQL.Clear;

      //обновляем места
      SQL.Add('INSERT into main (number, thruplace)');
      SQL.Add(
        'SELECT number, row_number() over(ORDER BY sumresult) as thruplace FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY thruplace');
      SQL.Add('ON CONFLICT(number) DO UPDATE SET thruplace = excluded.thruplace;');
      ExecSQL;
      SQL.Clear;

      //ставим отставание от лидера общего протокола
      SQL.Add('WITH');
      SQL.Add(
        'tthru(sumresult, number, thruplace) AS (SELECT sumresult, number, thruplace FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY thruplace),');
      SQL.Add(
        't1(leader1, num1) AS (SELECT julianday(sumresult), number FROM tthru WHERE thruplace = 1),');
      SQL.Add(
        't2(current, num2) AS (SELECT julianday(sumresult), number FROM tthru WHERE thruplace > 1)');
      SQL.Add('INSERT into main (thrudiff, number)');
      SQL.Add(
        'SELECT strftime(''%H:%M:%f'',(t2.current - t1.leader1 + 0.5)), t2.num2 from t1, t2, tthru WHERE t2.num2 = tthru.number ORDER BY thruplace');
      SQL.Add('ON CONFLICT(number) DO UPDATE SET thrudiff= excluded.thrudiff;');
      ExecSQL;
      SQLTransaction.Commit;
      Close;
    end;
  except
    On E: Exception do
    begin
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure ClearResults(silent: boolean);
var
  i: integer;
begin
  if silent or (MessageDlg(sClearResults, mtWarning, [mbYes, mbNo], 0) = mrYes) then
  begin
    try
      with MainForm.SQLQuery1 do
      begin
        SQL.Clear;
        SQL.Add('UPDATE main SET');
        for i := 1 to maxstages do
        begin
          SQL.Add('correction' + IntToStr(i) + '=NULL, finishtime' +
            IntToStr(i) + '=NULL, penalty' + IntToStr(i) + '=NULL,');
          SQL.Add('result' + IntToStr(i) + '=NULL, diffleader' +
            IntToStr(i) + '=NULL, place' + IntToStr(i) + '=NULL, status' +
            IntToStr(i) + '=NULL,');
        end;
        SQL.Add(
          'sumplace=NULL, sumresult=NULL, sumdiffleader=NULL, thrudiff=NULL, status=NULL;');
        ExecSQL;
        SQLTransaction.Commit;
        Close;
        RefreshAll;
      end;
      Log(sResultsCleared);
    except
      On E: Exception do
      begin
        MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(sDatabaseOpenError + E.Message);
      end;
    end;
  end;
end;

procedure SetDNSFromCorrection;
var
  n: string;
  c: TComponent;
  i: integer;
begin
  if dbopen then
  begin
    if not MainForm.CorrectionDataset.IsEmpty then
    begin
      for i := 1 to maxstages do
      begin
        c := MainForm.FindComponent('RadioCur' + IntToStr(i));
        if TRadioButton(c).Checked then
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
    st := SelectedStage;
    t := InputDateTime(sTimeToStart, sEnterStartTime + ' ' + n + ' ' +
      sOnStage + ': ' + sname[st]);
    if t > 0 then
    begin
      with MainForm.SQLQuery1 do
      begin
        SQL.Clear;
        SQL.Add('UPDATE main SET status' + IntToStr(st) + ' = NULL, starttime' +
          IntToStr(st) + ' = "' + TimeToStr(t) + '" WHERE number = ' + n + ';');
        ExecSQL;
        SQLTransaction.Commit;
        Close;
      end;
      UpdateResults;
    end;
  end;
end;

procedure SetDNFFromOnTrace;
var
  n: string;
  c: TComponent;
  i: integer;
begin
  if not MainForm.StatDataset2.IsEmpty then
  begin
    for i := 1 to maxstages do
    begin
      c := MainForm.FindComponent('RadioCur' + IntToStr(i));
      if TRadioButton(c).Checked then
      begin
        n := MainForm.StatDataset2.FieldByName('number').AsString;
        SetSQLStatus(i, 'DNF', n);
      end;
    end;
  end;
end;

procedure LoadParticipantsList(FileName: string);
var
  ocsvStrings: TStringList;
  i, k: integer;
begin
  if dbopen then
  begin
    Screen.Cursor := crSQLWait;
    try
      with MainForm.SQLQuery1 do
      begin
        SQL.Clear;
        SQL.Add('DELETE from load');
        ExecSQL;
        SQLTransaction.Commit;
        Close;
      end;

      ocsvStrings := TStringList.Create;
      try
        ocsvStrings.LoadFromFile(FileName);
        MainForm.SQLQuery1.SQL.Clear;
        MainForm.SQLQuery1.SQL.Add(
          'INSERT INTO load (category, number, name, nickname, age, team, city, starttime1, starttime2, starttime3, starttime4, starttime5, starttime6)');
        MainForm.SQLQuery1.SQL.Add('VALUES');
        for i := 1 to ocsvStrings.Count - 1 do
          //от 1 чтобы убрать заголовки в файле
        begin
          //ocsvStrings.ValueFromIndex[i] := WinCPToUTF8(ocsvStrings.ValueFromIndex[i]);
          k := CountOccurrences(';', ocsvStrings.ValueFromIndex[i]);
          //считаем кол-во разделителей(;), чтобы понять сколько стартовых времён
          //ToDo: добавить проверку чтобы значений было не больше 12
          if k < 13 then
          begin
            for k := 12 - k downto 1 do
            begin
              ocsvStrings.ValueFromIndex[i] :=
                ocsvStrings.ValueFromIndex[i] + ';';
              //если стартов не 6, то ставим ';', т.е. заполняем отсутствующие времена стартов (null) на оставшиеся СУ
            end;
            ocsvStrings.ValueFromIndex[i] :=
              ReplaceStr(ocsvStrings.ValueFromIndex[i], '''', '''''');
            //экранируем ' в SQL запросе
            ocsvStrings.ValueFromIndex[i] :=
              ReplaceStr(ocsvStrings.ValueFromIndex[i], ';', ''',''');
          end;
          MainForm.SQLQuery1.SQL.Add('(''' + ocsvStrings.ValueFromIndex[i] + ''')');
          if i <> ocsvStrings.Count - 1 then
            MainForm.SQLQuery1.SQL.Add(',');
          //если строка не последняя ставим запятую
        end;
        MainForm.SQLQuery1.SQL.Add(';');
        {$IFDEF Windows}
        MainForm.SQLQuery1.SQL.Text :=
          WinCPToUTF8(MainForm.SQLQuery1.SQL.Text);
        {$ENDIF}
        try
          MainForm.SQLQuery1.ExecSQL;
          MainForm.SQLQuery1.SQLTransaction.Commit;
        except
          On E: Exception do
          begin
            MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
            Log(sDatabaseOpenError + E.Message);
          end;
        end;
        MainForm.SQLQuery1.Close;
      finally
        ocsvStrings.Free;
      end;

      with MainForm.SQLQuery1 do
      begin
        SQL.Clear;
        SQL.Add(
          'INSERT into main (category, number, name, nickname, age, team, city, starttime1, starttime2, starttime3, starttime4, starttime5, starttime6)');
        SQL.Add(
          'SELECT category, number, name, nickname, age, team, city, starttime1, starttime2, starttime3, starttime4, starttime5, starttime6 FROM load WHERE number NOTNULL AND number != ""');
        SQL.Add('ON CONFLICT(number) DO UPDATE SET');
        SQL.Add(
          'category = excluded.category, name = excluded.name, nickname = excluded.nickname, age = excluded.age, team = excluded.team, city = excluded.city, starttime1 = excluded.starttime1,');
        SQL.Add(
          'starttime2 = excluded.starttime2, starttime3 = excluded.starttime3, starttime4 = excluded.starttime4, starttime5 = excluded.starttime5, starttime6 = excluded.starttime6;');
        ExecSQL;
        SQLTransaction.Commit;
        Close;
      end;

      if MessageDlg(sSetCategoryName, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      begin
        //записывать ли первые несколько* категорий из списка участников
        with MainForm.SQLQuery1 do
        begin
          //в окно результатов и в конфиг БД
          Close;
          //*несколько равно количеству категорий, показываемых в окне результатов
          SQL.Text := 'SELECT category FROM main GROUP BY category';
          Open;
          k := RecordCount;
          if k > visiblecat then
            k := visiblecat;
          for i := 1 to k do
          begin
            cat[i] := Fields.Fields[0].AsString;
            Next;
          end;
          Close;
          SQL.Clear;
          SQL.Add('INSERT INTO config (key, value) VALUES');
          for i := 1 to visiblecat do
          begin
            SQL.Add('("catname' + IntToStr(i) + '", "' + cat[i] + '")');
            if i < visiblecat then
              SQL.Add(',');
          end;
          SQL.Add('ON CONFLICT(key) DO UPDATE SET value = excluded.value;');
          ExecSQL;
          SQLTransaction.Commit;
          Close;
        end;
        LoadIniCategory;
      end;
      RefreshAll;
      Log(sLoadCSVParticipants);
      Screen.Cursor := crDefault;
    except
      On E: Exception do
      begin
        MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(sDatabaseOpenError + E.Message);
      end;
    end;
  end;
end;

//procedure LoadFinishTime(FileName: string);
//var
//  importfinish: integer;
//  ocsvStrings: TStringList;
//  i: integer;
//  k: integer = -1;
//  strlst: TStringList;
//  c: TComponent;
//begin
//  strlst := TStringList.Create;
//  for i := 1 to maxstages do
//  begin
//    c := MainForm.FindComponent('RadioCur' + IntToStr(i));
//    if TRadioButton(c).Enabled then
//    begin
//      strlst.add(sname[i]);
//      if TRadioButton(c).Checked then
//      begin
//        k := strlst.Count - 1;
//      end;
//    end;
//  end;
//  importfinish := MyInputCombo(sImportFinish, sSetTimeToSU, strlst, k) + 1;
//  //вводим номер СУ для ввода финишных результатов
//  if importfinish > 0 then
//  begin
//    Screen.Cursor := crSQLWait;
//    if dbopen then
//    begin
//      try
//        with MainForm.SQLQuery1 do
//        begin
//          SQL.Clear;
//          SQL.Add('DELETE from loadresult');
//          ExecSQL;
//          SQLTransaction.Commit;
//          Close;
//        end;

//        ocsvStrings := TStringList.Create;
//        try
//          ocsvStrings.LoadFromFile(FileName);
//          MainForm.SQLQuery1.SQL.Clear;
//          MainForm.SQLQuery1.SQL.Add(
//            'INSERT INTO loadresult (number, result)');
//          MainForm.SQLQuery1.SQL.Add('VALUES');
//          for i := 1 to ocsvStrings.Count - 1 do
//            //от 1 чтобы убрать заголовки в файле
//          begin
//            //ToDo: добавить проверку чтобы значений было не больше 2
//            ocsvStrings.ValueFromIndex[i] :=
//              ReplaceStr(ocsvStrings.ValueFromIndex[i], ';', ''',''');
//            MainForm.SQLQuery1.SQL.Add('(''' +
//              ocsvStrings.ValueFromIndex[i] + ''')');
//            if i <> ocsvStrings.Count - 1 then
//              MainForm.SQLQuery1.SQL.Add(',');
//            //если строка не последняя ставим запятую
//          end;
//          MainForm.SQLQuery1.SQL.Add(';');
//          MainForm.SQLQuery1.ExecSQL;
//          MainForm.SQLQuery1.SQLTransaction.Commit;
//          MainForm.SQLQuery1.Close;
//        finally
//          ocsvStrings.Free;
//        end;

//        with MainForm.SQLQuery1 do
//        begin
//          SQL.Clear;
//          SQL.Add('INSERT into main (number,');
//          SQL.Add('finishtime' + IntToStr(importfinish));
//          SQL.Add(')');
//          SQL.Add('SELECT number, result FROM loadresult WHERE number NOTNULL');
//          SQL.Add('ON CONFLICT(number) DO UPDATE SET');
//          SQL.Add('finishtime' + IntToStr(importfinish) +
//            ' = excluded.finishtime' + IntToStr(importfinish));
//          //        Memo.Lines.Add(SQL.Text);
//          ExecSQL;
//          SQLTransaction.Commit;
//          Close;
//        end;
//        UpdateResults;
//        Log(sImportFinishtime + ' ' + IntToStr(importfinish) +
//          ': ' + sname[importfinish] + ' ' + sLoaded);
//      except
//        On E: Exception do
//        begin
//          MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
//          Log(sDatabaseOpenError + E.Message);
//        end;
//      end;
//    end;
//    Screen.Cursor := crDefault;
//  end;
//  strlst.Free;
//end;

procedure LoadFinishTime(FileName: string);
var
  importfinish: integer;
  ocsvStrings: TStringList;
  i, col, row: integer;
  k: integer = -1;
  strlst: TStringList;
  c: TComponent;
  csvDoc: TCSVDocument;
  sqlStr: string;
  dns: boolean = False;
  dnf: boolean = False;
begin
  try
    strlst := TStringList.Create;
    for i := 1 to maxstages do
    begin
      c := MainForm.FindComponent('RadioCur' + IntToStr(i));
      if TRadioButton(c).Enabled then
      begin
        strlst.add(sname[i]);
        if TRadioButton(c).Checked then
        begin
          k := strlst.Count - 1;
        end;
      end;
    end;
    importfinish := MyInputCombo(sImportFinish, sSetTimeToSU, strlst, k) + 1;
    //вводим номер СУ для ввода финишных результатов
    if importfinish > 0 then
    begin
      Screen.Cursor := crSQLWait;
      if dbopen then
      begin
        try
          with MainForm.SQLQuery1 do
          begin
            SQL.Clear;
            SQL.Add('DELETE from loadresult');
            ExecSQL;
            SQLTransaction.Commit;
            Close;
          end;

          try
            ocsvStrings := TStringList.Create;
            ocsvStrings.LoadFromFile(FileName);
            csvDoc := TCSVDocument.Create;
            csvDoc.Delimiter := ';';
            //удаляем комментарии (#)
            for  i := ocsvStrings.Count - 1 downto 0 do
            begin
              if Pos('#', Trim(ocsvStrings.ValueFromIndex[i])) = 1 then
              begin
                ocsvStrings.Delete(i);
              end;
            end;
            csvDoc.CSVText := ocsvStrings.Text;
            //считаем количество значений
            col := csvDoc.MaxColCount;
            //если значений 6 (number, starttime, correction, finishtime, penalty, status)
            //то загрузка результатов этапа, например из другого компа на другом СУ
            //Print('RowCount: ' + IntToStr(csvDoc.RowCount));
            if col = 6 then
            begin
              if not BackupBD then
              begin
                if MessageDlg(sCanNotBackup, mtWarning, [mbYes, mbNo], 0) = mrNo then
                begin
                  Screen.Cursor := crDefault;
                  Exit;
                end;
              end;
              MainForm.SQLQuery1.SQL.Clear;
              MainForm.SQLQuery1.SQL.Add(
                'INSERT INTO loadresult (number, starttime, correction, finishtime, penalty, status)');
              MainForm.SQLQuery1.SQL.Add('VALUES');
              for row := 0 to csvDoc.RowCount - 1 do
              begin
                MainForm.SQLQuery1.SQL.Add('(');
                //соединяем строку в sql формат
                for i := 0 to col - 1 do
                begin
                  sqlStr := csvDoc.Cells[i, row];
                  //в пустые ячейки ставим NULL
                  if sqlStr = '' then
                    sqlStr := 'NULL'
                  else
                    //непустые ячейки обрамляем двойными кавычками (")
                    sqlStr := '"' + sqlStr + '"';

                  MainForm.SQLQuery1.SQL.Add(sqlStr);
                  //если ячейка не последняя ставим запятую
                  if i <> col - 1 then
                    MainForm.SQLQuery1.SQL.Add(',');

                end;
                MainForm.SQLQuery1.SQL.Add(')');
                //если строка не последняя ставим запятую
                if row <> csvDoc.RowCount - 1 then
                  MainForm.SQLQuery1.SQL.Add(',');
              end;
              MainForm.SQLQuery1.SQL.Add(';');
              //Print(MainForm.SQLQuery1.SQL.Text);
              MainForm.SQLQuery1.ExecSQL;
              MainForm.SQLQuery1.SQLTransaction.Commit;
              MainForm.SQLQuery1.Close;

              with MainForm.SQLQuery1 do
              begin
                SQL.Clear;
                SQL.Add('INSERT into main (number,');
                SQL.Add('starttime' + IntToStr(importfinish) + ',');
                SQL.Add('correction' + IntToStr(importfinish) + ',');
                SQL.Add('finishtime' + IntToStr(importfinish) + ',');
                SQL.Add('penalty' + IntToStr(importfinish) + ',');
                SQL.Add('status' + IntToStr(importfinish));
                SQL.Add(')');
                SQL.Add(
                  'SELECT number, starttime, correction, finishtime, penalty, status FROM loadresult WHERE number NOTNULL');
                SQL.Add('ON CONFLICT (number) DO UPDATE SET');
                SQL.Add('starttime' + IntToStr(importfinish) +
                  ' = excluded.starttime' + IntToStr(importfinish) + ',');
                SQL.Add('correction' + IntToStr(importfinish) +
                  ' = excluded.correction' + IntToStr(importfinish) + ',');
                SQL.Add('finishtime' + IntToStr(importfinish) +
                  ' = excluded.finishtime' + IntToStr(importfinish) + ',');
                SQL.Add('penalty' + IntToStr(importfinish) +
                  ' = excluded.penalty' + IntToStr(importfinish) + ',');
                SQL.Add('status' + IntToStr(importfinish) +
                  ' = excluded.status' + IntToStr(importfinish));
                ExecSQL;
                SQLTransaction.Commit;
                Close;
                MainForm.SQLTransaction1.Active := False;
              end;
              RecalculateStatus(GetAllStageStatus(importfinish));
              UpdateResults;
              Log(sImportFinishtime + ' ' + IntToStr(importfinish) +
                ': ' + sname[importfinish] + ' ' + sLoaded_o);
            end
            //если значений 3 (number, starttime, correction)
            //то загрузка из стартового телефона
            else if col = 3 then
            begin
              if not BackupBD then
              begin
                if MessageDlg(sCanNotBackup, mtWarning, [mbYes, mbNo], 0) = mrNo then
                begin
                  Screen.Cursor := crDefault;
                  Exit;
                end;
              end;
              MainForm.SQLQuery1.SQL.Clear;
              MainForm.SQLQuery1.SQL.Add(
                'INSERT INTO loadresult (number, starttime, correction, status)');
              MainForm.SQLQuery1.SQL.Add('VALUES');

              for row := 0 to csvDoc.RowCount - 1 do
              begin
                //пропускаем строку с заголовками
                if csvDoc.Cells[i, row] = 'number' then
                  Continue;
                MainForm.SQLQuery1.SQL.Add('(');
                //соединяем строку в sql формат
                dns := False;
                for i := 0 to col - 1 do
                begin
                  sqlStr := csvDoc.Cells[i, row];
                  //в пустые ячейки ставим NULL
                  if sqlStr = '' then
                    sqlStr := 'NULL'
                  else if sqlStr = 'DNS' then
                  begin
                    sqlStr := 'NULL';
                    dns := True;
                  end
                  else
                  begin
                    //разделитель целой и дробной части меняем на точку
                    sqlStr :=
                      ReplaceStr(sqlStr, DefaultFormatSettings.DecimalSeparator, '.');
                    //непустые ячейки обрамляем двойными кавычками (")
                    sqlStr := '"' + sqlStr + '"';
                  end;

                  MainForm.SQLQuery1.SQL.Add(sqlStr);
                  ////если ячейка не последняя ставим запятую
                  //if i <> col - 1 then
                  MainForm.SQLQuery1.SQL.Add(',');
                end;
                //если есть DNS, то ставим в статус 2
                if dns then
                  MainForm.SQLQuery1.SQL.Add('2')
                else
                  MainForm.SQLQuery1.SQL.Add('NULL');
                MainForm.SQLQuery1.SQL.Add(')');
                //если строка не последняя ставим запятую
                if row <> csvDoc.RowCount - 1 then
                  MainForm.SQLQuery1.SQL.Add(',');
              end;

              MainForm.SQLQuery1.SQL.Add(';');
              MainForm.SQLQuery1.ExecSQL;
              MainForm.SQLQuery1.SQLTransaction.Commit;
              MainForm.SQLQuery1.Close;

              with MainForm.SQLQuery1 do
              begin
                SQL.Clear;
                SQL.Add('INSERT into main (number,');
                SQL.Add('starttime' + IntToStr(importfinish) + ',');
                SQL.Add('correction' + IntToStr(importfinish) + ',');
                SQL.Add('status' + IntToStr(importfinish));
                SQL.Add(')');
                SQL.Add(
                  'SELECT number, starttime, correction, status FROM loadresult WHERE number NOTNULL');
                SQL.Add('ON CONFLICT (number) DO UPDATE SET');
                SQL.Add('starttime' + IntToStr(importfinish) +
                  ' = excluded.starttime' + IntToStr(importfinish) + ',');
                SQL.Add('correction' + IntToStr(importfinish) +
                  ' = excluded.correction' + IntToStr(importfinish) + ',');
                SQL.Add('status' + IntToStr(importfinish) +
                  ' = excluded.status' + IntToStr(importfinish));
                //Print(SQL.Text);
                ExecSQL;
                SQLTransaction.Commit;
                Close;
                MainForm.SQLTransaction1.Active := False;
              end;
              //SetGlobalStatus(n);
              UpdateResults;
              Log(sImportStarttime + ' ' + IntToStr(importfinish) +
                ': ' + sname[importfinish] + ' ' + sLoaded);
            end
            //если значений 2 (number, finishtime)
            //то загрузка из финишного телефона
            else if col = 2 then
            begin
              if not BackupBD then
              begin
                if MessageDlg(sCanNotBackup, mtWarning, [mbYes, mbNo], 0) = mrNo then
                begin
                  Screen.Cursor := crDefault;
                  Exit;
                end;
              end;
              MainForm.SQLQuery1.SQL.Clear;
              MainForm.SQLQuery1.SQL.Add(
                'INSERT INTO loadresult (number, finishtime, status)');
              MainForm.SQLQuery1.SQL.Add('VALUES');
              for row := 0 to csvDoc.RowCount - 1 do
              begin
                //пропускаем строку с заголовками
                if csvDoc.Cells[i, row] = 'number' then
                  Continue;
                MainForm.SQLQuery1.SQL.Add('(');
                //соединяем строку в sql формат
                dnf := False;
                for i := 0 to col - 1 do
                begin
                  sqlStr := csvDoc.Cells[i, row];
                  //в пустые ячейки ставим NULL
                  if sqlStr = '' then
                    sqlStr := 'NULL'
                  else if sqlStr = 'DNF' then
                  begin
                    sqlStr := 'NULL';
                    dnf := True;
                  end
                  else
                  begin
                    //разделитель целой и дробной части меняем на точку
                    sqlStr :=
                      ReplaceStr(sqlStr, DefaultFormatSettings.DecimalSeparator, '.');
                    //непустые ячейки обрамляем двойными кавычками (")
                    sqlStr := '"' + sqlStr + '"';
                  end;
                  MainForm.SQLQuery1.SQL.Add(sqlStr);
                  ////если ячейка не последняя ставим запятую
                  //if i <> col - 1 then
                  MainForm.SQLQuery1.SQL.Add(',');
                end;
                //если есть DNF, то ставим в статус 1
                if dnf then
                  MainForm.SQLQuery1.SQL.Add('1')
                else
                  MainForm.SQLQuery1.SQL.Add('NULL');
                MainForm.SQLQuery1.SQL.Add(')');
                //если строка не последняя ставим запятую
                if row <> csvDoc.RowCount - 1 then
                  MainForm.SQLQuery1.SQL.Add(',');
              end;

              MainForm.SQLQuery1.SQL.Add(';');
              MainForm.SQLQuery1.ExecSQL;
              MainForm.SQLQuery1.SQLTransaction.Commit;
              MainForm.SQLQuery1.Close;

              with MainForm.SQLQuery1 do
              begin
                SQL.Clear;
                SQL.Add('INSERT into main (number,');
                SQL.Add('finishtime' + IntToStr(importfinish) + ',');
                SQL.Add('status' + IntToStr(importfinish));
                SQL.Add(')');
                SQL.Add(
                  'SELECT number, finishtime, status FROM loadresult WHERE number NOTNULL');
                SQL.Add('ON CONFLICT (number) DO UPDATE SET');
                SQL.Add('finishtime' + IntToStr(importfinish) +
                  ' = excluded.finishtime' + IntToStr(importfinish) + ',');
                SQL.Add('status' + IntToStr(importfinish) +
                  ' = excluded.status' + IntToStr(importfinish));
                ExecSQL;
                SQLTransaction.Commit;
                Close;
                MainForm.SQLTransaction1.Active := False;
              end;
              //SetGlobalStatus(n);
              UpdateResults;
              Log(sImportFinishtime + ' ' + IntToStr(importfinish) +
                ': ' + sname[importfinish] + ' ' + sLoaded_o);
            end
            else
              MessageDlg(sFinishTimeOpenError, mtError, [mbOK], 0);
          finally
            ocsvStrings.Free;
            csvDoc.Free;
          end;
        except
          On E: Exception do
          begin
            MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
            Log(sDatabaseOpenError + E.Message);
          end;
        end;
      end;
      Screen.Cursor := crDefault;
    end;
  finally
    strlst.Free;
  end;
end;

procedure ExportFinishTime(FileName: string);
begin
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, starttime' + IntToStr(CurrentStage) + ', correction' +
    IntToStr(CurrentStage) + ', finishtime' + IntToStr(CurrentStage) +
    ', penalty' + IntToStr(CurrentStage) + ', status' + IntToStr(CurrentStage) +
    ' FROM main' + ';';
  SQLQueryToCSV(FileName, MainForm.SQLQuery1);
end;

procedure ExportAllResults(FileName: string);
begin
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, sumresult, sumstages, status FROM main;';
  SQLQueryToCSV(FileName, MainForm.SQLQuery1, True);
end;

procedure ExportSumDays(FileName: string);
begin
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT main.category, sumdays.place, sumdays.number, main.name, main.nickname, main.age, main.team, main.city, sumdays.sumresult, sumdays.sumstages, sumdays.status ' + 'FROM sumdays, main WHERE sumdays.number = main.number ORDER BY category, sumdays.sumstages DESC, sumdays.sumresult;';
  SQLQueryToCSV(FileName, MainForm.SQLQuery1, True);
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
  number: string;
begin
  if dbopen then
  begin
    seconds := 15 / 24 / 60 / 60; //15 секунд
    timeAfter := StartTime + seconds;
    timeBefore := StartTime - seconds;
    //определяем подходящий номер
    with MainForm.SQLQuery1 do
    begin
      SQL.Text := 'SELECT number FROM main WHERE starttime' +
        IntToStr(CurrentStage) + ' BETWEEN "' +
        FormatDateTime('hh:nn:ss.zzz', timeBefore) + '" AND "' +
        FormatDateTime('hh:nn:ss.zzz', timeAfter) + '";';
      Open;
      if not EOF then
      begin
        number := Fields.Fields[0].AsString;
      end
      else
        number := 'NULL';
      Close;
      //записываем номер-время-поправка-текущее время
      //если номер не найден, то просто номер = NULL
      SQL.Text := 'INSERT INTO lora (number, starttime, correction, timemark) ' +
        'VALUES (' + number + ', "' + FormatDateTime('hh:nn:ss.zzz', StartTime) +
        '", ' + correction + ', "' + FormatDateTime('hh:nn:ss', Now) + '");';
      ExecSQL;
      SQLTransaction.Commit;
      Close;
      //обновляем датасет
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
end;

procedure GenerateStartlistFromQualifier(FileName: string);
var
  prevfName: string;
  fileExistsBefore: boolean;
begin
  if fName <> FileName then
  begin
    fileExistsBefore := FileExists(FileName);
    if fileExistsBefore and (MessageDlg(sFinalFileExists, mtWarning,
      [mbOK, mbCancel], 0) = mrCancel) then
      Exit;
    prevfName := fName;
    //1. закрываем текущее соревнование
    MainForm.FileCloseExecute(nil);
    SetfName('');
    //2. копируем файл
    try
      CopyFile(fName, FileName, False, True);
      //3. открываем новый файл
      //fName := FileName;
      //SetfName(fName);
      //OpenDB;
      InitDB(FileName);
      //4 формируем порядок старта категорий
      if RunStartlist(True) then
      begin
        //5. удаляем результаты
        ClearResults(True);
        //уведомление что стартовый протокол создан
        MessageDlg(sGenerateStartList + ': ' + FileName,
          mtInformation, [mbOK], 0);
      end
      else
      begin
        MainForm.FileCloseExecute(nil);
        if not fileExistsBefore then
          DeleteFile(FileName);
        //fName := prevfName;
        //SetfName(fName);
        //OpenDB;
        InitDB(prevfName);
      end;
    except
      on E: Exception do
      begin
        MessageDlg(sFileCopyError + ':' + #13#10 + E.Message,
          mtError, [mbOK], 0);
      end;
    end;
  end
  else
    MessageDlg(sFilesAreEqual, mtError, [mbOK], 0);
end;

procedure ExportBDStartList(FileName: string);
var
  bdfilename: string;
begin
  if fName <> FileName then
  begin
    if FileExists(FileName) then
    begin
      if MessageDlg(sBDStartListFileExists, mtWarning, [mbYes, mbNo], 0) = mrYes then
      begin
        if not DeleteFile(FileName) then
        begin
          MessageDlg(sStartFileCopyError + ':' + #13#10 + sCanNotDeleteFile,
            mtError, [mbOK], 0);
          exit;
        end;
      end
      else
        exit;
    end;
    //запоминаем текущее имя бд
    bdfilename := fName;
    //закрываем текущее соревнование
    MainForm.FileCloseExecute(nil);
    SetfName('');
    //копируем файл
    try
      CopyFile(fName, FileName, False, True);
      //открываем новый файл
      //fName := FileName;
      //SetfName(fName);
      //OpenDB;
      InitDB(FileName);
      //создаём starttime и gotime
      with MainForm.SQLQuery1 do
      begin
        //удаляем всё из "start"
        SQL.Text := 'DELETE from start';
        ExecSQL;
        //копируем number, starttime(текущий) в start table
        SQL.Text :=
          'INSERT INTO start (number, starttime) ' + 'SELECT number, starttime' +
          IntToStr(CurrentStage) + ' FROM main WHERE true ' +
          'ON CONFLICT(number) DO UPDATE SET starttime = excluded.starttime;';
        ExecSQL;
        SQLTransaction.Commit;
        Close;
      end;
      //удаляем результаты
      ClearResults(True);
      //открываем прежднюю дб
      MainForm.FileCloseExecute(nil);
      //fName := bdfilename;
      //OpenDB;
      InitDB(bdfilename);
      //уведомление что стартовый протокол для телефона создан
      MessageDlg(sStartFileCreated + ': ' + FileName,
        mtInformation, [mbOK], 0);
    except
      on E: Exception do
      begin
        MessageDlg(sStartFileCopyError + ':' + #13#10 + E.Message,
          mtError, [mbOK], 0);
      end;
    end;
  end
  else
    MessageDlg(sFilesAreEqual, mtError, [mbOK], 0);
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
      with MainForm.SQLQuery1 do
      begin
        SQL.Text := 'DELETE from load';
        ExecSQL;
        SQLTransaction.Commit;
        Close;
      end;

      ocsvStrings := TStringList.Create;
      try
        ocsvStrings.LoadFromFile(FileName);
        MainForm.SQLQuery1.SQL.Clear;
        MainForm.SQLQuery1.SQL.Add(
          // 'SELECT number, sumresult, sumstages, status FROM main;';
          'INSERT INTO load (number, starttime1, age, starttime2)');
        MainForm.SQLQuery1.SQL.Add('VALUES');
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
          MainForm.SQLQuery1.SQL.Add('(''' + ocsvStrings.ValueFromIndex[i] + ''')');
          //если строка не последняя(первая, т.к. загрузка в обратном порядке) ставим запятую
          //if i <> ocsvStrings.Count - 1 then
          //if i <> 0 then
          MainForm.SQLQuery1.SQL.Add(',');
        end;
        MainForm.SQLQuery1.SQL.Delete(MainForm.SQLQuery1.SQL.LastIndexOf(','));
        MainForm.SQLQuery1.SQL.Add(';');
        {$IFDEF Windows}
        MainForm.SQLQuery1.SQL.Text :=
          WinCPToUTF8(MainForm.SQLQuery1.SQL.Text);
        {$ENDIF}
        try
          begin
            MainForm.SQLQuery1.ExecSQL;
            //ставим результат ноль, если DNS/DNF/DSQ
            MainForm.SQLQuery1.SQL.Text :=
              'UPDATE load SET starttime1 = "00:00:00.000" WHERE starttime1 = "DSQ" OR starttime1 = "DNF" OR starttime1 = "DNS" OR starttime1 ISNULL OR starttime1 = "";';
            MainForm.SQLQuery1.ExecSQL;
            MainForm.SQLQuery1.SQL.Text :=
              'UPDATE load SET age = "0" WHERE age = "";';
            MainForm.SQLQuery1.ExecSQL;
            MainForm.SQLQuery1.SQL.Text :=
              'UPDATE load SET starttime2 = "0" WHERE starttime2 = "";';
            MainForm.SQLQuery1.ExecSQL;
            MainForm.SQLQuery1.SQLTransaction.Commit;
          end;
        except
          On E: Exception do
          begin
            MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
            Log(sDatabaseOpenError + E.Message);
          end;
        end;
        MainForm.SQLQuery1.Close;
      finally
        ocsvStrings.Free;
      end;

      with MainForm.SQLQuery1 do
      begin
        SQL.Clear;
        SQL.Add(
          'INSERT into sumdays (number, sumresult, sumstages, status)');
        SQL.Add(
          'SELECT number, starttime1, age, starttime2 FROM load WHERE number NOTNULL AND number != ""');
        SQL.Add('ON CONFLICT(number) DO UPDATE SET');
        SQL.Add(
          'sumresult = strftime(''%H:%M:%f'',julianday(excluded.sumresult) + julianday(sumresult) +0.5),');
        SQL.Add(
          'sumstages = excluded.sumstages + sumstages,');
        SQL.Add(
          'status = excluded.status + status;');
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
        MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
        Log(sDatabaseOpenError + E.Message);
        Screen.Cursor := crDefault;
      end;
    end;
  end;
end;

procedure Print(Str: string);
begin
  MainForm.Memo.Lines.Add(Str);
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
var
  i, k: integer;
  s: integer = 0;
begin
  with MainForm.SQLQuery1 do
  begin
    Close;
    //sql запрос на список категорий
    SQL.Text := 'SELECT category FROM main GROUP BY category';
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
      //сортируем категории по порядку категорий, показываемых в окне результатов
      //категории, которых нет в этом списке, будут первыми
      //s := 0;
      for i := visiblecat downto 1 do
      begin
        k := Result.IndexOf(cat[i]);
        if k > -1 then
        begin
          Result.Exchange(k, (Result.Count - 1) - s);
          s := s + 1;
        end;
      end;
      //MainForm.Memo.Lines.Add(Result.Text);
    except
      on E: Exception do
      begin
        MessageDlg(E.Message, mtError, [mbOK], 0);
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
        MainForm.SQLQuery1.SQL.Text :=
          'SELECT * FROM main WHERE status NOTNULL;'
      else
        MainForm.SQLQuery1.SQL.Text :=
          'SELECT * FROM main WHERE status' + IntToStr(stage) + ' NOTNULL;';
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
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
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

function SelectedStage: integer;
  //высчитываем номер СУ, где стоит выделение
var
  co, i: integer;
begin
  Result := 1;
  //ставим первый если курсор на общей информации
  co := MainForm.RxDBGrid1.SelectedIndex;
  for i := 1 to maxstages do
  begin
    if (co > commoncols + stagecols * (i - 1)) and
      (co <= commoncols + stagecols * i) then
      Result := i;
  end;
end;

function CurrentStage: integer;
  //высчитывает номер СУ, активное на данный момент
var
  i: integer;
  c: TComponent;
begin
  Result := 1;
  for i := 1 to maxstages do
  begin
    c := MainForm.FindComponent('RadioCur' + IntToStr(i));
    if TRadioButton(c).Checked then
    begin
      Result := i;
      Break;
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
  MainForm.FileCloseExecute(nil);
  SetfName('');
  if not CopyFile(fName, backupfile, False, False) then
    Result := False;
  //SetfName(fName);
  //OpenDB;
  InitDB(fName);
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

end.
