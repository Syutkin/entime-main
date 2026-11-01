unit StartList;

{$mode objfpc}{$H+}

interface

uses
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
    StartlistScrollBox: TScrollBox;
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
    //СУ, активированный при формировании, или 0.
    activatedStageIndex: integer;
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
    (rsByNumberAsc, rsByNumberDesc, rsByNameAsc, rsByNameDesc, rsByResult);



function RunStartlist(var config: TStartlistConfig): boolean;

var
  StartlistForm: TStartlistForm;
  StartingPoint: TPoint;

implementation

uses Main, AppLogger, InputDialogs, CompetitionResultsService;

function LoadStartListCategories: TStringList;
begin
  Result := TStringList.Create;
  try
    TCompetitionStartListService.LoadCategories(MainForm.CompetitionDb,
      MainForm.CurrentStageIndex, stages.Count, Result);
  except
    on E: Exception do
    begin
      Result.Free;
      Result := TStringList.Create;
      AppLog(Format(rsCategoryListLoadError, [E.Message]), allError,
        alvStatus, alsDatabase);
      AskMessageDlg(Format(rsCategoryListLoadError, [E.Message]), mtError,
        [mbOK], 0);
    end;
  end;
end;

function StageHasFinishes(const AStageIndex: integer): boolean;
begin
  Result := False;
  try
    if CompetitionHasParticipants then
    begin
      if not stages.IsValidIndex(AStageIndex) then
        raise EArgumentOutOfRangeException.CreateFmt(
          'Stage index %d is outside the competition range.', [AStageIndex]);
      Result := TCompetitionStartListService.HasFinishes(
        MainForm.CompetitionDb, AStageIndex, stages.Count);
    end;
  except
    on E: Exception do
    begin
      AppLog(Format(rsFinishResultsCheckError, [E.Message]), allError,
        alvStatus, alsResults);
      AskMessageDlg(Format(rsFinishResultsCheckError, [E.Message]), mtError,
        [mbOK], 0);
    end;
  end;
end;

function RunStartlist(var config: TStartlistConfig): boolean;
var
  generation: TStartListGeneration;
  i, selectedStageIndex: integer;
begin
  Result := False;
  with TStartlistForm.Create(Application) do
  begin
    try
      if config.categories.Text.IsEmpty then
        config.categories := LoadStartListCategories;
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
      for i := 1 to stages.Count do
      begin
        ComboBoxStageSelection.Items.Add(stages[i].Name);
      end;

      if not stages.IsValidIndex(config.selectedStage + 1) then
        config.selectedStage := -1;
      if config.selectedStage < 0 then
      begin
        //если спецучасток не выбран, ищем первый без финишных результатов
        for i := 1 to ComboBoxStageSelection.Items.Count do
        begin
          if not StageHasFinishes(i) then
          begin
            config.selectedStage := i - 1;
            Break;
          end;
        end;
      end;
      if config.selectedStage < 0 then
        config.selectedStage := stages.FirstActiveIndex - 1;
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
        config.activatedStageIndex := 0;
        selectedStageIndex := ComboBoxStageSelection.ItemIndex + 1;
        if not stages.IsValidIndex(selectedStageIndex) then
          Exit;
        config.selectedStage := selectedStageIndex - 1;
        config.startTime := TimeEdit1.Time;
        config.delayBetweenRacers := SpinEditEx1.Value;
        config.delayBetweenCategories := SpinEditEx2.Value;
        config.categories.Text := ListBox1.Items.Text;
        config.sortByIndex := ComboBoxSortBy.ItemIndex;
        config.addDNS := cbDNS.Checked;
        config.addDNF := cbDNF.Checked;
        config.addDSQ := cbDSQ.Checked;

        // проверяем есть ли результаты в выбранном спецучастке
        // если есть, то запрашиваем подтверждение
        if (not StageHasFinishes(selectedStageIndex)) or
          (AskMessageDlg(Format(rsFinishResultsNotEmpty,
          [ComboBoxStageSelection.Text]), mtWarning, [mbYes, mbNo], 0) =
          mrYes) then
        begin
          generation := Default(TStartListGeneration);
          generation.StageIndex := selectedStageIndex;
          generation.StartTime := config.startTime;
          generation.DelayBetweenRacersSeconds :=
            config.delayBetweenRacers;
          generation.DelayBetweenCategoriesMinutes :=
            config.delayBetweenCategories;
          generation.SortBy := config.sortByIndex;
          generation.IncludeDNS := config.addDNS;
          generation.IncludeDNF := config.addDNF;
          generation.IncludeDSQ := config.addDSQ;
          generation.ActivateStage := not stages[selectedStageIndex].isActive;
          TCompetitionStartListService.GenerateStartTimes(
            MainForm.CompetitionDb, stages, config.categories, generation);
          Result := True;
          AppLog(Format(rsGenerateStartList, [ComboBoxSortBy.Text]),
            allInfo, alvStatus, alsResults);

          //Если спецучасток с формируемым на нём временем не активен,
          //то активируем его
          if not stages[selectedStageIndex].isActive then
          begin
            stages[selectedStageIndex].isActive := True;
            config.activatedStageIndex := selectedStageIndex;
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
  activatedStageIndex := 0;
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
