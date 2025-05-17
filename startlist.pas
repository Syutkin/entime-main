unit Startlist;

{$mode objfpc}{$H+}

interface

uses
  Implement,
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  ButtonPanel, SpinEx, CheckBoxThemed, i18n, LCLTranslator, ExtCtrls;

type

  StartListSortBy =
    (
    slByNumberAsc,
    slByNumberDesc,
    slByNameAsc,
    slByNameDesc,
    slByResult
    );

  { TStartlistForm }

  TStartlistForm = class(TForm)
    ButtonPanel1: TButtonPanel;
    cbDNS: TCheckBoxThemed;
    cbDNF: TCheckBoxThemed;
    cbDSQ: TCheckBoxThemed;
    ComboBoxSortBy: TComboBox;
    ComboBoxStageSelection: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    StageSelected: TLabel;
    ListBox1: TListBox;
    Panel1: TPanel;
    Panel2: TPanel;
    SpinEditEx1: TSpinEditEx;
    SpinEditEx2: TSpinEditEx;
    TimeEdit1: TTimeEdit;

    procedure ComboBoxSortByChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ListBox1DragDrop(Sender, Source: TObject; X, Y: integer);
    procedure ListBox1DragOver(Sender, Source: TObject; X, Y: integer;
      State: TDragState; var Accept: boolean);
    procedure ListBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: integer);
    procedure GenerateStartlist(stageIndex: integer; startCatList: string;
      startTime: TDateTime; delayBetweenRacers: integer;
      delayBetweenCategories: integer; sortBy: StartListSortBy);
    procedure EnablePanelWithStatus;
  private

  public
    destructor Destroy; override;

  end;

  { TStartlistConfig }
  TStartlistConfig = class
  public
    //выбранный спецучасток
    selectedStage: integer;
    //время начала заездов
    startTime: TDateTime;
    //время между стартами  (в секундах)
    delayBetweenRacers: integer;
    //время между категориями (в минутах)
    delayBetweenCategories: integer;
    //выбранная сортировка
    sortByIndex: integer;
    //список категорий
    categories: TStringList;
    //добавлять DNS
    addDNS: boolean;
    //добавлять DNF
    addDNF: boolean;
    //добавлять DSQ
    addDSQ: boolean;
    constructor Create;
    destructor Destroy; override;
  end;


const
  StartListSortByStr: array[0..4] of string =
    (sByNumberAsc, sByNumberDesc, sByNameAsc, sByNameDesc, sByResult);



function RunStartlist(var config: TStartlistConfig): boolean;

var
  StartlistForm: TStartlistForm;
  StartingPoint: TPoint;

implementation

uses Main{, Implement};

function RunStartlist(var config: TStartlistConfig): boolean;
var
  sortBy: StartListSortBy;
  i: integer;
begin
  Result := False;
  with TStartlistForm.Create(Application) do
  begin
    try
      if config.categories.Text.IsEmpty then config.categories := CatStartList;
      ListBox1.Items.Text := config.categories.Text;
      TimeEdit1.Time := config.startTime;
      SpinEditEx1.Value := config.delayBetweenRacers;
      SpinEditEx2.Value := config.delayBetweenCategories;
      ComboBoxSortBy.ItemIndex := Ord(config.sortByIndex);
      cbDNS.Checked := config.addDNS;
      cbDNF.Checked := config.addDNF;
      cbDSQ.Checked := config.addDSQ;

      // Заполняем список спецучастков
      ComboBoxStageSelection.Items.Clear;
      for i := 1 to high(stageName) do
      begin
        ComboBoxStageSelection.Items.Add(stageName[i]);
      end;

      if config.selectedStage < 0 then
      begin
        //если спецучасток не выбран, ищем первый без финишных результатов
        for i := 1 to ComboBoxStageSelection.Items.Count do
        begin
          if not IsFinishesExists(i) then
          begin
            config.selectedStage := i - 1;
            Break;
          end;
        end;
      end;
      ComboBoxStageSelection.Text :=
        ComboBoxStageSelection.Items[config.selectedStage];
      ComboBoxStageSelection.ItemIndex := config.selectedStage;

      // Заполняем варианты сортировки
      ComboBoxSortBy.Items.Clear;
      for i := 0 to Ord(high(StartListSortBy)) do
      begin
        ComboBoxSortBy.Items.Add(StartListSortByStr[i]);
      end;
      ComboBoxSortBy.Text := StartListSortByStr[config.sortByIndex];

      EnablePanelWithStatus;

      ShowModal;

      if ModalResult = mrOk then
      begin
        Result := True;
        config.selectedStage := ComboBoxStageSelection.ItemIndex;
        config.startTime := TimeEdit1.Time;
        config.delayBetweenRacers := SpinEditEx1.Value;
        config.delayBetweenCategories := SpinEditEx2.Value;
        config.categories.Text := ListBox1.Items.Text;
        config.sortByIndex := ComboBoxSortBy.ItemIndex;
        config.addDNS := cbDNS.Checked;
        config.addDNF := cbDNF.Checked;
        config.addDSQ := cbDSQ.Checked;

        case config.sortByIndex of
          0: sortBy := slByNumberAsc;
          1: sortBy := slByNumberDesc;
          2: sortBy := slByNameAsc;
          3: sortBy := slByNameDesc;
          4: sortBy := slByResult;
        end;

        // проверяем есть ли результаты в выбранном спецучастке
        // если есть, то запрашиваем подтверждение
        if (not IsFinishesExists(config.selectedStage + 1)) or
          (MessageDlg(ComboBoxStageSelection.Text + ' ' + sFinishResultsNotEmpty,
          mtWarning, [mbYes, mbNo], 0) = mrYes) then
        begin
          GenerateStartlist(
            config.selectedStage + 1,
            config.categories.Text,
            config.startTime,
            config.delayBetweenRacers,
            config.delayBetweenCategories,
            sortBy);
          Log(sGenerateStartList + ': ' + ComboBoxSortBy.Text);

          //Если спецучасток с формируемын на нём временем не активен,
          //то активируем его
          if not stage[config.selectedStage + 1] then
          begin
            stage[config.selectedStage + 1] := True;
            ////эта дичь определяет был ли переход от работы с одним этапом на несколько
            //if (not stage[2]) and (not stage[3]) and (not stage[4]) and
            //  (not stage[5]) and (not stage[6]) and
            //  (config.selectedStage > 0) then
            //  //для того, чтобы освободить место для таблицы с вводом поправки
            //  //без этого в текущей организации GUI были коллизии
            //  MainForm.Splitter1.Top :=
            //    MainForm.Splitter1.Top + MainForm.CurrentSU.Height;

            //сохраняем статус СУ (вкл/выкл)
            if dbopen then
            begin
              with MainForm.SQLQuery1 do
              begin
                SQL.Clear;
                SQL.Add('INSERT INTO config (key, value) VALUES');
                SQL.Add('("stage' + IntToStr(config.selectedStage + 1) +
                  '", "' + BoolToStr(True, True) + '")');
                SQL.Add('ON CONFLICT(key) DO UPDATE SET value = excluded.value;');
                ExecSQL;
                SQLTransaction.Commit;
                Close;
              end;
            end;
            LoadConfig;
            if dbopen then
            begin
              //пересчитываем глобальный статус у тех, у кого он был,
              //в связи с возможным изменением количества активных СУ
              RecalculateStatus(GetAllStageStatus(0));
              UpdateResults;
            end;
          end;
        end;
      end;
    finally
      Free;
    end;
  end;
end;




{$R *.lfm}

{ TStartlistForm }

procedure TStartlistForm.FormCreate(Sender: TObject);
begin

end;

destructor TStartlistForm.Destroy;
begin
  inherited Destroy;
end;

procedure TStartlistForm.ComboBoxSortByChange(Sender: TObject);
begin
  EnablePanelWithStatus;
end;

procedure TStartlistForm.ListBox1DragDrop(Sender, Source: TObject; X, Y: integer);
var
  DropPosition, StartPosition: integer;
  DropPoint: TPoint;
begin
  DropPoint.X := X;
  DropPoint.Y := Y;
  with Source as TListBox do
  begin
    StartPosition := ItemAtPos(StartingPoint, True);
    DropPosition := ItemAtPos(DropPoint, True);
    Items.Move(StartPosition, DropPosition);
  end;
end;

procedure TStartlistForm.ListBox1DragOver(Sender, Source: TObject;
  X, Y: integer; State: TDragState; var Accept: boolean);
begin
  Accept := Source is TListBox;
end;

procedure TStartlistForm.ListBox1MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  StartingPoint.X := X;
  StartingPoint.Y := Y;
end;

procedure TStartlistForm.GenerateStartlist(stageIndex: integer;
  startCatList: string; startTime: TDateTime; delayBetweenRacers: integer;
  delayBetweenCategories: integer; sortBy: StartListSortBy);
var
  i, min, sec: integer;
  number: string;
  CatList: TStringList;
begin
  with MainForm.SQLQuery1 do
  begin
    try
      IsFinishesExists(stageIndex);
      CatList := TStringList.Create;
      CatList.Text := startCatList;
      //удаляем текущее время старта, если было установлено
      SQL.Text := ('UPDATE main SET starttime' + IntToStr(stageIndex) + ' = NULL');
      ExecSQL;
      SQLTransaction.Commit;
      Close;
      MainForm.SQLTransaction1.Active := False;
      //для каждой категории делаем выборку и ставим время старта
      for i := 0 to CatList.Count - 1 do
      begin
        SQL.Clear;
        SQL.Text := 'SELECT number FROM main WHERE category IS "' +
          CatList.Strings[i] + '"';
        case sortBy of
          slByResult:
          begin
            SQL.Add('AND sumresult NOTNULL');
            if not cbDNS.Checked then
              SQL.Add('AND sumresult <> ''DNS''');
            if not cbDNF.Checked then
              SQL.Add('AND sumresult <> ''DNF''');
            if not cbDSQ.Checked then
              SQL.Add('AND sumresult <> ''DSQ''');
            SQL.Add('ORDER BY sumstages DESC, sumresult ASC');
          end;
          slByNumberAsc:
            SQL.Add('ORDER BY number ASC');
          slByNumberDesc:
            SQL.Add('ORDER BY number DESC');
          slByNameAsc:
            SQL.Add('ORDER BY name ASC');
          slByNameDesc:
            SQL.Add('ORDER BY name DESC');
        end;
        Open;
        while not EOF do
        begin
          number := Fields.Fields[0].AsString;
          Next;
          MainForm.SQLQuery2.SQL.Text :=
            'UPDATE main SET starttime' + IntToStr(stageIndex) +
            ' = "' + FormatDateTime('hh:nn:ss', startTime) + '" WHERE number =' + number;
          MainForm.SQLQuery2.ExecSQL;
          //кол-во минут
          min := delayBetweenRacers div 60;
          sec := delayBetweenRacers - min * 60;
          startTime := startTime + EncodeTime(0, min, sec, 0);
        end;
        startTime := startTime + EncodeTime(0, delayBetweenCategories, 0, 0);
        Close;
        MainForm.SQLTransaction1.Active := False;
        MainForm.SQLQuery2.SQLTransaction.Commit;
        MainForm.SQLQuery2.Close;
        MainForm.SQLTransaction2.Active := False;
      end;
      //ToDo: а то не обновляло в основном окне
      UpdateResults;
    finally
      CatList.Free;
    end;
  end;
end;

procedure TStartlistForm.EnablePanelWithStatus;
begin
  if ComboBoxSortBy.ItemIndex <> Ord(slByResult) then
    Panel1.Enabled := False
  else
    Panel1.Enabled := True;
end;

{ TStartlistConfig }

constructor TStartlistConfig.Create;
begin
  // Defaults
  selectedStage := -1;
  startTime := 0.5;
  delayBetweenRacers := 60;
  delayBetweenCategories := 3;
  sortByIndex := 0;
  categories := TStringList.Create;
  addDNS := True;
  addDNF := True;
  addDSQ := False;
end;

destructor TStartlistConfig.Destroy;
begin
  categories.Free;
  inherited Destroy;
end;

end.
