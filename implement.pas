unit Implement;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, rxdbgrid, Sqlite3DS, i18n, Dialogs,
  ComCtrls, StdCtrls, strutils, sqldb, sqlite3conn, LazUTF8, Forms,
  ButtonPanel, Math, fileutil, LazFileUtils, DB, dateutils, DateTimePicker,
  csvdocument, opensslsockets, fphttpclient, nsCore, chsdIntf, fpcsvexport,
  fpstypes, fpspreadsheet, LCLIntf, LConvEncoding;

procedure RefreshAll;
procedure RefreshResults;
procedure LoadConfig;
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

uses Main, Result, Startlist, StartItemModel;

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
    //и основном гриде (GetRow из MyDBGrid)
    row := MainForm.RxDBGrid1.GetRow;
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
      TSqlite3Dataset(c).Close;
      try
        TSqlite3Dataset(c).Open;
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
      MainForm.SQLQuery1.Close;
      MainForm.SQLQuery1.SQL.Text :=
        'SELECT * FROM config WHERE key = "racename";';
      MainForm.SQLQuery1.Open();
      raceName := MainForm.SQLQuery1.FieldByName('value').AsString;

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
        stages[i].isActive := MainForm.SQLQuery1.FieldByName('value').AsBoolean;
        MainForm.SQLQuery1.Close;
        MainForm.SQLQuery1.SQL.Text :=
          'SELECT * FROM config WHERE key = "stagename' + IntToStr(i) + '";';
        MainForm.SQLQuery1.Open();
        stages[i].Name := MainForm.SQLQuery1.FieldByName('value').AsString;
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

  for i := 1 to maxstages do
  begin
    c := MainForm.FindComponent('SheetStage' + IntToStr(i));
    TTabSheet(c).Caption := stages[i].Name;

    with MainForm.GridResult8 do
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
    MainForm.GridResult8.ColumnByFieldName('result' + iStr).Visible := False;
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

  // Если активных СУ больше одного, включаем показ кол-ва пройденных СУ
  // в сквозном протоколе
  if stages.ActiveStagesCount > 1 then
    (MainForm.FindComponent('GridResult7') as
      TRxDBGrid).ColumnByFieldName('sumstages').Visible := True
  else
    (MainForm.FindComponent('GridResult7') as
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
        (not stages[6].isActive) then
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
        with MainForm.SQLQuery1 do
        begin
          SQL.Clear;
          SQL.Add('UPDATE main SET place' + IntToStr(i) + ' = NULL, result' +
            IntToStr(i) + ' = "' + status + '", diffleader' + IntToStr(i) +
            ' = NULL, status' + IntToStr(i) + ' = ' + s + ' WHERE number = :NUMBER;');
          ParamByName('NUMBER').AsString := n;
          Close;
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
      if MessageDlg(rsReallyDisqualifyNumber + ' ' + n + '?', mtWarning,
        [mbYes, mbNo], 0) = mrYes then
      begin
        with MainForm.SQLQuery1 do
        begin
          SQL.Clear;
          //        SQL.Add('UPDATE main SET place1 = NULL, result1 = "DSQ", diffleader1 = NULL, status = 3 WHERE number = :NUMBER;');
          SQL.Add('UPDATE main SET status = 3 WHERE number = :NUMBER;');
          ParamByName('NUMBER').AsString := n;
          Close;
          ExecSQL;
          SQLTransaction.Commit;
          Close;
        end;
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
        Close;
        SQL.Clear;
        SQL.Add('UPDATE main SET status = ' + stat + ' WHERE number = :NUMBER;');
        ParamByName('NUMBER').AsString := n;
        Close;
        ExecSQL;
        SQLTransaction.Commit;
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
      if (not stages[2].isActive) and (not stages[3].isActive) and
        (not stages[4].isActive) and (not stages[5].isActive) and
        (not stages[6].isActive) then
      begin
        d := rsClearAllStatus + ' ' + n + '?';
        l := rsClearAllStatusLog + ' ' + n;
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
            Close;
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
        d := rsClearDSQ + ' ' + n + '?';
        l := rsClearDSQLog + ' ' + n;
        if MessageDlg(d, mtWarning, [mbYes, mbNo], 0) = mrYes then
        begin
          with MainForm.SQLQuery1 do
          begin
            SQL.Clear;
            SQL.Add('UPDATE main SET status = NULL WHERE number = :NUMBER;');
            ParamByName('NUMBER').AsString := n;
            Close;
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
          with MainForm.SQLQuery1 do
          begin
            SQL.Clear;
            SQL.Add('UPDATE main SET place' + IntToStr(i) + ' = NULL, result' +
              IntToStr(i) + ' = NULL, diffleader' + IntToStr(i) +
              ' = NULL, status' + IntToStr(i) + ' = NULL WHERE number = :NUMBER;');
            ParamByName('NUMBER').AsString := n;
            Close;
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
        MainForm.SQLite3Connection1.ExecuteDirect('CREATE TABLE "main" (' +
          ' "id"	    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,' +
          ' "category"	    VARCHAR,' + ' "sumplace"	  INTEGER,' +
          ' "number"	    INTEGER NOT NULL UNIQUE,' +
          ' "rfid"          INTEGER,' + ' "name"          VARCHAR,' +
          ' "nickname"	    VARCHAR,' + ' "age"           VARCHAR,' +
          ' "team"          VARCHAR,' + ' "city"          VARCHAR,' +
          ' "phone"         VARCHAR,' + ' "email"         VARCHAR,' +
          ' "comment"       VARCHAR,' + ' "starttime1"    VARCHAR,' +
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
          ' "thrudiff"      VARCHAR,' + ' "thruplace"     INTEGER,' +
          ' "status"	    VARCHAR);');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect('CREATE TABLE "load" (' +
          ' "category"	 VARCHAR,' + ' "number"	    INTEGER,' +
          ' "name"	 VARCHAR,' + ' "nickname"   VARCHAR,' +
          ' "age"        VARCHAR,' + ' "team"	    VARCHAR,' +
          ' "city"       VARCHAR,' + ' "phone"      VARCHAR,' +
          ' "email"      VARCHAR,' + ' "comment"    VARCHAR,' +
          ' "starttime1" VARCHAR,' + ' "starttime2" VARCHAR,' +
          ' "starttime3" VARCHAR,' + ' "starttime4" VARCHAR,' +
          ' "starttime5" VARCHAR,' + ' "starttime6" VARCHAR);');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect(
          'CREATE TABLE "loadresult" (' + ' "number"  INTEGER UNIQUE,' +
          ' "starttime"	  VARCHAR,' + ' "correction"  INTEGER,' +
          ' "finishtime"  VARCHAR,' + ' "penalty"     VARCHAR,' +
          ' "status"	  VARCHAR' + ');');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect('CREATE TABLE "start" (' +
          '"id"	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,' +
          '"number"	INTEGER NOT NULL UNIQUE,' + '"starttime"  	   TEXT,' +
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
          ' "key"	          VARCHAR NOT NULL UNIQUE,' + ' "value"	  VARCHAR);');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect('CREATE TABLE "lora" (' +
          ' "id"	  INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,' +
          ' "number"     INTEGER,' + ' "starttime"          VARCHAR,' +
          ' "correction"  VARCHAR,' + ' "isset"             INTEGER,' +
          ' "timemark"	  VARCHAR' + ');');
        MainForm.SQLTransaction1.Commit;

        MainForm.SQLite3Connection1.ExecuteDirect(
          'INSERT INTO config (key, value) VALUES' + '("activestage", "1"),' +
          '("stage1", "True"),' + '("catname1", "' + rsCat1 + '"),' +
          '("catname2", "' + rsCat2 + '"),' + '("catname3", "' +
          rsCat3 + '"),' + '("catname4", "' + rsCat4 + '"),' +
          '("catname5", "' + rsCat5 + '")' + ';');
        MainForm.SQLTransaction1.Commit;

        with MainForm.SQLQuery1 do
        begin
          SQL.Clear;
          SQL.Add('INSERT INTO config (key, value) VALUES');
          SQL.Add('("racename", :RACENAME)');
          SQL.Add('ON CONFLICT(key) DO UPDATE SET value = excluded.value;');
          ParamByName('RACENAME').AsString := ExtractFileNameOnly(fName);
          Close;
          ExecSQL;
        end;
        MainForm.SQLTransaction1.Commit;
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
  currentresult, bottomline, currentcategory, st, leaderresult, upperline, Name: string;
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
  try
    try
      for row := MainForm.sGridResult.RowCount - 1 downto 1 do
      begin
        if (TryStrToInt(MainForm.sGridResult.Cells[1, row], number)) and
          (number > 0) then
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
              if MessageDlg(rsNumber + ' ' + IntToStr(number) + ' ' +
                rsDidNotStartSetFinish, mtWarning, [mbYes, mbNo], 0) = mrYes then
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
                Name := MainForm.SQLQuery1.FieldByName('name').AsString;
                MainForm.SQLQuery1.Active := False;
                MainForm.SQLQuery1.SQL.Text :=
                  'select * from main where category = "' + currentcategory +
                  '" AND place' + st + ' = 1;';
                MainForm.SQLQuery1.Active := True;
                leaderresult := MainForm.SQLQuery1.FieldByName('result' + st).AsString;
                leadernumber := MainForm.SQLQuery1.FieldByName('number').AsInteger;
              end;

              MainForm.SQLQuery1.SQL.Clear;
              MainForm.SQLQuery1.SQL.Add('UPDATE main');
              for i := 1 to maxstages do
              begin
                if MainForm.CurrentSU.Buttons[i - 1].Checked then
                  MainForm.SQLQuery1.SQL.Add('SET finishtime' +
                    IntToStr(i) + ' = :TIME' + ', status' + IntToStr(i) + ' = NULL');
              end;
              MainForm.SQLQuery1.SQL.Add('WHERE number = :NUMBER;');
              MainForm.SQLQuery1.ParamByName('TIME').Text :=
                MainForm.sGridResult.Cells[0, row];
              MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := number;
              // ToDo: Без close падает, что за ExecSQL тут вообще?
              MainForm.SQLQuery1.Close;
              MainForm.SQLQuery1.ExecSQL;
              //ставим время финиша для номера
              UpdateResults;
              //ставим результат
              MainForm.sGridResult.DeleteRow(row);
              Log(rsFinishTimeSet + ' ' + IntToStr(number));

              //если используется LED панель или телеграм бот, добываем для них данные
              if Mainform.AcLEDPanel.Checked or Mainform.AcTelegramBot.Checked then
              begin
                //результаты текущего участника
                MainForm.SQLQuery1.Active := False;
                MainForm.SQLQuery1.SQL.Text :=
                  'select * from main where number = :NUMBER;';
                MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := number;
                MainForm.SQLQuery1.Active := True;

                currentresult := MainForm.SQLQuery1.FieldByName('result' + st).AsString;
                currentplace := MainForm.SQLQuery1.FieldByName('place' + st).AsInteger;

                //если текущий участник занял первое место
                if currentplace = 1 then
                begin

                  // ToDo: фоматирование

                  //результаты лидера категории для определения, насколько обогнал предыдущего лидера текущий участник
                  if leadernumber > 0 then
                  begin
                    MainForm.SQLQuery1.Active := False;
                    MainForm.SQLQuery1.SQL.Text :=
                      'select * from main where number = ' +
                      IntToStr(leadernumber) + ';';
                    MainForm.SQLQuery1.Active := True;
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
                    if not Name.IsEmpty then
                      Values['name'] := EncodeURLElement(Name);
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
                  MainForm.Memo.Lines.Append(IntToStr(ResponseStatusCode) +
                    ' ' + ResponseStatusText);
                  MainForm.Memo.Lines.Append(ResponseHeaders.Text);
                  MainForm.Memo.Lines.Append(l.DataString);

                finally
                  MainForm.Memo.Lines.Append(AURL);
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
    MainForm.SQLTransaction1.Active := False;
    MainForm.SQLQuery2.Active := False;
    MainForm.SQLTransaction2.Active := False;
    Screen.Cursor := crDefault;
  end;
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
          if FieldByName('correction' + IntToStr(ActiveStageIndex)).AsString = '' then
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
            Close;
            SQL.Text := 'UPDATE main SET correction' + IntToStr(ActiveStageIndex) +
              ' = ' + correction + ' WHERE number = ' + n + ';';
            Close;
            ExecSQL;
            Close;
            SQL.Text := 'UPDATE lora SET isset = 1 WHERE id = ' + id + ';';
            Close;
            ExecSQL;
            SQLTransaction.Commit;
            Close;
            UpdateResults;
          end;
        end
        else
        begin
          Log(rsNumber + ' ' + n + ' ' + rsDoNotExist);
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
      if stages[i].isActive then
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
          Close;
          ExecSQL;
          SQL.Clear;

          //обнуляем места (а вдруг были) для dsq/dnf/dns (сейчас для всех)
          SQL.Add('UPDATE main SET place' + IntToStr(i) + ' = NULL, diffleader' +
            IntToStr(i) + ' = NULL;');
          //WHERE status NOTNULL;');
          Close;
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
          Close;
          ExecSQL;
          SQL.Clear;

          //обнуляем отставание для первых номеров
          SQL.Add('UPDATE main SET diffleader' + IntToStr(i) +
            ' = NULL WHERE place' + IntToStr(i) + ' = 1;');
          Close;
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
        if stages[i].isActive then
          SQL.Add('+ julianday(result' + IntToStr(i) + ') -2451543.5');
      end;
      SQL.Add(')END;');
      Close;
      ExecSQL;
      //ставим общий результат
      SQL.Clear;
      SQL.Add('UPDATE main SET sumplace = NULL, sumdiffleader = NULL;');
      // WHERE status NOTNULL;');
      Close;
      ExecSQL;
      //обнуляем места (а вдруг были) для dsq/dnf/dns
      SQL.Clear;
      SQL.Add('INSERT into main (number, sumplace)');
      SQL.Add(
        'SELECT number, row_number() over(partition BY category ORDER BY sumresult) as sumplace FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY sumresult DESC');
      SQL.Add('ON CONFLICT(number) DO UPDATE SET sumplace = excluded.sumplace;');
      Close;
      ExecSQL;
      //обновляем места
      SQL.Clear;
      SQL.Add('UPDATE main SET sumdiffleader = NULL WHERE sumplace = 1;');
      Close;
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
      Close;
      ExecSQL;
      //ставим отставание от лидера категории
      SQLTransaction.Commit;
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
          if stages[i].isActive then
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
      Close;
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
        if stages[i].isActive then
        begin
          SQL.Add('AND result' + IntToStr(i) + ' NOTNULL');
          SQL.Add('AND status' + IntToStr(i) + ' IS NULL');
        end;
      end;
      SQL.Add('ORDER BY sumresult DESC');
      SQL.Add('ON CONFLICT(number) DO UPDATE SET sumplace = excluded.sumplace;');
      Close;
      ExecSQL;
      SQL.Clear;

      //обнуляем отставание для первых номеров
      SQL.Add('UPDATE main SET sumdiffleader = NULL WHERE sumplace = 1;');
      Close;
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
      Close;
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
        ' ' + rsSU + ''', t2.num2 from t1, t2 WHERE t1.cat1 = t2.cat2');
      SQL.Add(
        'ON CONFLICT(number) DO UPDATE SET sumdiffleader= excluded.sumdiffleader;');
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

procedure UpdateThruResults;                     //для сквозного
begin
  try
    with MainForm.SQLQuery1 do
    begin
      SQL.Clear;

      //обнуляем отставание и место для всех
      SQL.Add('UPDATE main SET thrudiff = NULL, thruplace = NULL;');
      Close;
      ExecSQL;
      SQL.Clear;

      //обновляем места
      SQL.Add('INSERT into main (number, thruplace)');
      SQL.Add(
        'SELECT number, row_number() over(ORDER BY sumstages DESC, sumresult) as thruplace FROM main WHERE sumresult > 0 AND status ISNULL ORDER BY thruplace');
      SQL.Add('ON CONFLICT(number) DO UPDATE SET thruplace = excluded.thruplace;');
      Close;
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
      Close;
      ExecSQL;
      SQL.Clear;

      //ставим отставание в количестве СУ
      SQL.Add('WITH');
      SQL.Add('t1(sumstages1, num1) AS');
      SQL.Add('(SELECT sumstages, number FROM main WHERE thruplace = 1),');
      SQL.Add('t2(current, num2) AS');
      SQL.Add(
        '(SELECT sumstages, number FROM main WHERE sumplace IS NULL AND sumstages NOT NULL AND (status < 3 OR status IS NULL))');
      SQL.Add('INSERT into main (thrudiff, number)');
      SQL.Add('SELECT ''+'' || (t1.sumstages1 - t2.current) || ''' +
        ' ' + rsSU + ''', t2.num2 from t1, t2 WHERE TRUE');
      SQL.Add('ON CONFLICT(number) DO UPDATE SET thrudiff= excluded.thrudiff;');
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
      with MainForm.SQLQuery1 do
      begin
        SQL.Clear;
        SQL.Add('UPDATE main SET status' + IntToStr(st) + ' = NULL, starttime' +
          IntToStr(st) + ' = "' + TimeToStr(t) + '" WHERE number = ' + n + ';');
        Close;
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
  ocsvStrings: TStringList;
  i, k, num: integer;
  startItem: TStartItemModel;
  startItems: TList;
  legend: TStringList;
  item: TStringList;
  legendItem: string;
  legendMap: TLegend;
  sql: string;
  about: rAboutHolder;
  fileStream: TFilestream;
  Info: rCharsetInfo;
  S: pchar;
  isNumberColumnExists: boolean = False;
begin
  if dbopen then
  begin
    Screen.Cursor := crSQLWait;
    try
      with MainForm.SQLQuery1 do
      begin
        SQL.Clear;
        SQL.Add('DELETE from load');
        Close;
        ExecSQL;
        SQLTransaction.Commit;
        Close;
      end;
      csd_GetAbout(about);
      Print(about.About);
      fileStream := TFilestream.Create(FileName, fmOpenRead);
      try
        S := AllocMem(fileStream.Size);
        fileStream.ReadBuffer(S^, fileStream.Size);
        csd_Reset;
        csd_HandleData(S, fileStream.Size);
        if not csd_Done then csd_DataEnd;
        Info := csd_GetDetectedCharset();
        Print('Open startlist file: ' + FileName);
        Print('Codepage: ' + Info.Name);
      finally
        FreeMem(S);
        fileStream.Free;
      end;

      ocsvStrings := TStringList.Create;
      legend := TStringList.Create;
      legend.Delimiter := ';';
      legend.StrictDelimiter := True;
      item := TStringList.Create;
      item.Delimiter := ';';
      item.StrictDelimiter := True;
      legendMap := TLegend.Create;
      startItems := TList.Create;

      try
        ocsvStrings.LoadFromFile(FileName);
        if ContainsText(Info.Name, 'windows') then
        begin
          if ContainsText(Info.Name, '1251') then
            ocsvStrings.Text := CP1251ToUTF8(ocsvStrings.Text)
          else if ContainsText(Info.Name, '1252') then
            ocsvStrings.Text := CP1252ToUTF8(ocsvStrings.Text)
          else if ContainsText(Info.Name, '1253') then
            ocsvStrings.Text := CP1253ToUTF8(ocsvStrings.Text)
          else if ContainsText(Info.Name, '1255') then
            ocsvStrings.Text := CP1255ToUTF8(ocsvStrings.Text)
          else
            ocsvStrings.Text := WinCPToUTF8(ocsvStrings.Text);
        end;

        legend.DelimitedText := ocsvStrings[0];

        // Проверяем что есть обязательные поля (номер)
        for legendItem in legend do
        begin
          if legendMap.number.IndexOf(legendItem.ToLower) >= 0 then
          begin
            isNumberColumnExists := True;
            break;
          end;
        end;
        if not isNumberColumnExists then
          raise Exception.Create(rsNumberColumnNotFound);

        // Собираем названия СУ
        for legendItem in legend do
        begin
          if (legendMap.number.IndexOf(legendItem.ToLower) < 0) and
            (legendMap.Name.IndexOf(legendItem.ToLower) < 0) and
            (legendMap.category.IndexOf(legendItem.ToLower) < 0) and
            (legendMap.nickname.IndexOf(legendItem.ToLower) < 0) and
            (legendMap.birthday.IndexOf(legendItem.ToLower) < 0) and
            (legendMap.team.IndexOf(legendItem.ToLower) < 0) and
            (legendMap.city.IndexOf(legendItem.ToLower) < 0) and
            (legendMap.phone.IndexOf(legendItem.ToLower) < 0) and
            (legendMap.email.IndexOf(legendItem.ToLower) < 0) and
            (legendMap.comment.IndexOf(legendItem.ToLower) < 0) then
          begin
            legendMap.stageNames.add(legendItem);
          end;
        end;

        if (legendMap.stageNames.Count > 0) then
        begin
          with MainForm.SQLQuery1 do
          begin
            SQL.Clear;
            SQL.Add('INSERT INTO config (key, value) VALUES ');
            for i := 0 to legendMap.stageNames.Count - 1 do
            begin
              SQL.Add('("stagename' + IntToStr(i + 1) + '", "' +
                legendMap.stageNames[i] + '"),');
              SQL.Add('("stage' + IntToStr(i + 1) + '", "True")');
              SQL.Add(',');
            end;
            SQL.Delete(SQL.Count - 1);
            SQL.Add('ON CONFLICT(key) DO UPDATE SET value = excluded.value;');
            ExecSQL;
            SQLTransaction.Commit;
            Close;
          end;
        end;

        for i := 1 to ocsvStrings.Count - 1 do
        begin
          item.DelimitedText := ocsvStrings[i];
          startItem := TStartItemModel.Create;
          for legendItem in legend do
          begin
            if legendMap.number.IndexOf(legendItem.ToLower) >= 0 then
              if TryStrToInt(item[legend.IndexOf(legendItem)], num) then
                startItem.number := num
              else
                break
            else if legendMap.Name.IndexOf(legendItem.ToLower) >= 0 then
              startItem.Name := item[legend.IndexOf(legendItem)]
            else if legendMap.category.IndexOf(legendItem.ToLower) >= 0 then
              startItem.category := item[legend.IndexOf(legendItem)]
            else if legendMap.nickname.IndexOf(legendItem.ToLower) >= 0 then
              startItem.nickname := item[legend.IndexOf(legendItem)]
            else if legendMap.birthday.IndexOf(legendItem.ToLower) >= 0 then
              startItem.birthday := item[legend.IndexOf(legendItem)]
            else if legendMap.team.IndexOf(legendItem.ToLower) >= 0 then
              startItem.team := item[legend.IndexOf(legendItem)]
            else if legendMap.city.IndexOf(legendItem.ToLower) >= 0 then
              startItem.city := item[legend.IndexOf(legendItem)]
            else if legendMap.phone.IndexOf(legendItem.ToLower) >= 0 then
              startItem.phone := item[legend.IndexOf(legendItem)]
            else if legendMap.email.IndexOf(legendItem.ToLower) >= 0 then
              startItem.email := item[legend.IndexOf(legendItem)]
            else if legendMap.comment.IndexOf(legendItem.ToLower) >= 0 then
              startItem.comment := item[legend.IndexOf(legendItem)]
            else
              startItem.startTimes.Add(item[legend.IndexOf(legendItem)]);
          end;
          startItems.Add(startItem);
        end;

        MainForm.SQLQuery1.SQL.Clear;
        MainForm.SQLQuery1.SQL.Add(
          'INSERT INTO load (category, number, name, nickname, age, team, city, phone, email, comment, starttime1, starttime2, starttime3, starttime4, starttime5, starttime6)');
        MainForm.SQLQuery1.SQL.Add('VALUES');
        for i := 0 to startItems.Count - 1 do
        begin
          item.Free;
          item := TStringList.Create;
          item.Delimiter := ';';
          item.QuoteChar := #0;
          item.add(TStartItemModel(startItems[i]).category);
          item.add(TStartItemModel(startItems[i]).number.toString);
          item.add(TStartItemModel(startItems[i]).Name);
          item.add(TStartItemModel(startItems[i]).nickname);
          item.add(TStartItemModel(startItems[i]).birthday);
          item.add(TStartItemModel(startItems[i]).team);
          item.add(TStartItemModel(startItems[i]).city);
          item.add(TStartItemModel(startItems[i]).phone);
          item.add(TStartItemModel(startItems[i]).email);
          item.add(TStartItemModel(startItems[i]).comment);

          //считаем кол-во стартовых времён
          k := TStartItemModel(startItems[i]).startTimes.Count;
          if k < 6 then
          begin
            for k := 6 - k downto 1 do
            begin
              //если стартов не 6, то заполняем до шести
              TStartItemModel(startItems[i]).startTimes.Add('');

            end;
          end;
          item.AddStrings(TStartItemModel(startItems[i]).startTimes);
          sql := item.DelimitedText;
          //экранируем ' в SQL запросе
          sql := ReplaceStr(sql, '''', '''''');
          sql := ReplaceStr(sql, ';', ''',''');

          MainForm.SQLQuery1.SQL.Add('(''' + sql + ''')');
          //если строка не последняя ставим запятую
          if i <> startItems.Count - 1 then
            MainForm.SQLQuery1.SQL.Add(',');
        end;
        MainForm.SQLQuery1.SQL.Add(';');
        MainForm.SQLQuery1.Close;
        MainForm.SQLQuery1.ExecSQL;
        MainForm.SQLQuery1.SQLTransaction.Commit;

        // Запись в основную таблицу
        with MainForm.SQLQuery1 do
        begin
          SQL.Clear;
          SQL.Add(
            'INSERT into main (category, number, name, nickname, age, team, city, phone, email, comment, starttime1, starttime2, starttime3, starttime4, starttime5, starttime6)');
          SQL.Add(
            'SELECT category, number, name, nickname, age, team, city, phone, email, comment, starttime1, starttime2, starttime3, starttime4, starttime5, starttime6 FROM load WHERE number NOTNULL AND number != "" AND number != 0');
          SQL.Add('ON CONFLICT(number) DO UPDATE SET');
          SQL.Add(
            'category = excluded.category, name = excluded.name, nickname = excluded.nickname, age = excluded.age, team = excluded.team, city = excluded.city, phone = excluded.phone, email = excluded.email, comment = excluded.comment, starttime1 = excluded.starttime1,');
          SQL.Add(
            'starttime2 = excluded.starttime2, starttime3 = excluded.starttime3, starttime4 = excluded.starttime4, starttime5 = excluded.starttime5, starttime6 = excluded.starttime6;');
          Close;
          ExecSQL;
          SQLTransaction.Commit;
          Close;
        end;

        if MessageDlg(rsSetCategoryName, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
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
            Close;
            ExecSQL;
            SQLTransaction.Commit;
            Close;
          end;
          LoadConfig;
          LoadIniCategory;
        end;
        RefreshAll;
        Log(rsLoadCSVParticipants);
        Screen.Cursor := crDefault;
        MainForm.SQLQuery1.Close;
      finally
        begin
          ocsvStrings.Free;
          legend.Free;
          item.Free;
          legendMap.Free;
          for i := 0 to startItems.Count - 1 do
          begin
            TStartItemModel(startItems[i]).Free;
          end;
          startItems.Free;
        end;
      end;
    except
      On E: Exception do
      begin
        MessageDlg(rsLoadParticipantsListError + E.Message, mtError, [mbOK], 0);
        Log(rsLoadParticipantsListError + E.Message);
      end;
    end;
    Screen.Cursor := crDefault;
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
//      strlst.add(stages[i].Name);
//      if TRadioButton(c).Checked then
//      begin
//        k := strlst.Count - 1;
//      end;
//    end;
//  end;
//  importfinish := MyInputCombo(rsImportFinish, rsSetTimeToSU, strlst, k) + 1;
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
//        Log(rsImportFinishtime + ' ' + IntToStr(importfinish) +
//          ': ' + stageName[importfinish] + ' ' + rsLoaded);
//      except
//        On E: Exception do
//        begin
//          MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
//          Log(rsDatabaseOpenError + E.Message);
//        end;
//      end;
//    end;
//    Screen.Cursor := crDefault;
//  end;
//  strlst.Free;
//end;

function InputComboSelectStage(const ACaption, APrompt: string): integer;
var
  strlst: TStringList;
  i, index: integer;
  k: integer = -1;
begin
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
    Result := ActiveStageIndex();
  strlst.Free;
end;

procedure LoadFinishTime(FileName: string);
var
  importfinish: integer;
  ocsvStrings: TStringList;
  i, col, row, num: integer;
  csvDoc: TCSVDocument;
  sqlStr: string;
  dns: boolean = False;
  dnf: boolean = False;
begin
  importfinish := InputComboSelectStage(rsImportFinish, rsSetTimeToSU);

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
          Close;
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
              if MessageDlg(rsCanNotBackup, mtWarning, [mbYes, mbNo], 0) = mrNo then
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
            MainForm.SQLQuery1.Close;
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
              Close;
              ExecSQL;
              SQLTransaction.Commit;
              Close;
              MainForm.SQLTransaction1.Active := False;
            end;
            RecalculateStatus(GetAllStageStatus(importfinish));
            UpdateResults;
            Log(rsImportFinishtime + ' ' + IntToStr(importfinish) +
              ': ' + stages[importfinish].Name + ' ' + rsLoaded_o);
          end
          //если значений 3 (number, starttime, correction)
          //то загрузка из стартового телефона
          else if col = 3 then
          begin
            if not BackupBD then
            begin
              if MessageDlg(rsCanNotBackup, mtWarning, [mbYes, mbNo], 0) = mrNo then
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
              //пропускаем строку с заголовками (если первое значение не номер)
              if not trystrtoint(csvDoc.Cells[0, row], num) then
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
            MainForm.SQLQuery1.Close;
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
              Close;
              ExecSQL;
              SQLTransaction.Commit;
              Close;
              MainForm.SQLTransaction1.Active := False;
            end;
            //SetGlobalStatus(n);
            UpdateResults;
            Log(rsImportStarttime + ' ' + IntToStr(importfinish) +
              ': ' + stages[importfinish].Name + ' ' + rsLoaded);
          end
          //если значений 2 (number, finishtime)
          //то загрузка из финишного телефона
          else if col = 2 then
          begin
            if not BackupBD then
            begin
              if MessageDlg(rsCanNotBackup, mtWarning, [mbYes, mbNo], 0) = mrNo then
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
              //пропускаем строку с заголовками (если первое значение не номер)
              if not trystrtoint(csvDoc.Cells[0, row], num) then
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
            MainForm.SQLQuery1.Close;
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
              Close;
              ExecSQL;
              SQLTransaction.Commit;
              Close;
              MainForm.SQLTransaction1.Active := False;
            end;
            //SetGlobalStatus(n);
            UpdateResults;
            Log(rsImportFinishtime + ' ' + IntToStr(importfinish) +
              ': ' + stages[importfinish].Name + ' ' + rsLoaded_o);
          end
          else
            MessageDlg(rsFinishTimeOpenError, mtError, [mbOK], 0);
        finally
          ocsvStrings.Free;
          csvDoc.Free;
        end;
      except
        On E: Exception do
        begin
          MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
          Log(rsDatabaseOpenError + E.Message);
        end;
      end;
    end;
    Screen.Cursor := crDefault;
  end;
end;

procedure ExportFinishTime(FileName: string; stageIndex: integer);
var
  index: string;
begin
  index := IntToStr(stageIndex);
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, starttime' + index + ', correction' + index +
    ', finishtime' + index + ', penalty' + index + ', status' + index + ' FROM main;';
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
    with MainForm.SQLQuery1 do
    begin
      Close;
      SQL.Text := 'SELECT COUNT(*) FROM main ' +
        'GROUP BY penalty1, penalty2, penalty3, penalty4, penalty5, penalty6;';
      Open();
      First;
      i := 0;
      while not EOF do
      begin
        Inc(i);
        Next;
      end;
    end;
    print(IntToStr(i));
    if (i > 1) then
    begin
      showPenalty := True;
      stageColumnCount := 4;
    end;

    if (stages.ActiveStagesCount > 1) then
    begin
      // Колонки для активных СУ
      for i := 1 to maxstages do
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
      SQL.Text := 'SELECT category FROM main GROUP BY category ORDER BY starttime1;';
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
        SQL.Text :=
          'SELECT ' + exportColumns.CommaText + ' FROM main ' +
          'WHERE category IS :CATEGORY ' +
          //манёвр с 'toend' чтобы результат NULL был в конце
          'ORDER BY IFNULL(sumplace,''toend''), IFNULL(sumresult,''toend'');';
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
    with MainForm.ResultDataset7 do
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
        IntToStr(ActiveStageIndex) + ' BETWEEN "' +
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
      Close;
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
          MessageDlg(rsDatabaseOpenError + E.Message, mtError, [mbOK], 0);
          Log(rsDatabaseOpenError + E.Message);
        end;
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
    for i := 1 to 6 do
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
      with MainForm.SQLQuery1 do
      begin
        SQL.Text := 'DELETE from load';
        Close;
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
            MainForm.SQLQuery1.Close;
            MainForm.SQLQuery1.ExecSQL;
            //ставим результат ноль, если DNS/DNF/DSQ
            MainForm.SQLQuery1.SQL.Text :=
              'UPDATE load SET starttime1 = "00:00:00.000" WHERE starttime1 = "DSQ" OR starttime1 = "DNF" OR starttime1 = "DNS" OR starttime1 ISNULL OR starttime1 = "";';
            MainForm.SQLQuery1.Close;
            MainForm.SQLQuery1.ExecSQL;
            MainForm.SQLQuery1.SQL.Text :=
              'UPDATE load SET age = "0" WHERE age = "";';
            MainForm.SQLQuery1.Close;
            MainForm.SQLQuery1.ExecSQL;
            MainForm.SQLQuery1.SQL.Text :=
              'UPDATE load SET starttime2 = "0" WHERE starttime2 = "";';
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
    SQL.Text := 'SELECT category FROM main GROUP BY category ORDER BY starttime' +
      IntToStr(ActiveStageIndex);
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
      //for i := visiblecat downto 1 do
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
    if (co > commoncols + stagecols * (i - 1)) and
      (co <= commoncols + stagecols * i) then
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
var
  c: integer = 0;
begin
  Result := False;
  try
    if dbnotempty then
    begin
      MainForm.SQLQuery1.Close;
      MainForm.SQLQuery1.SQL.Text :=
        'SELECT * FROM main WHERE finishtime' + IntToStr(stageIndex) +
        ' NOTNULL AND finishtime' + IntToStr(stageIndex) + ' <> ''''';
      MainForm.SQLQuery1.Open;
      while not MainForm.SQLQuery1.EOF do
      begin
        Inc(c);
        MainForm.SQLQuery1.Next;
      end;
      MainForm.SQLQuery1.Close;
      MainForm.SQLTransaction1.Active := False;
      if c > 0 then Result := True;
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

end.
