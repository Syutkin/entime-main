unit StartMarks;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, DB, sqldb, Forms, Controls, Graphics,
  Dialogs, StdCtrls, ExtCtrls, rxdbgrid, i18n, DBGrids, Menus, ActnList,
  StartMarkRepository, StartMarkService;

type

  { TStartMarksForm }

  TStartMarksForm = class(TForm)
    AcCopy: TAction;
    ActionList1: TActionList;
    ComboBoxJournalFilter: TComboBox;
    DataSourceStartMarks: TDataSource;
    LabelJournalFilter: TLabel;
    MenuItemCopy: TMenuItem;
    PanelJournalFilter: TPanel;
    PopupMenu1: TPopupMenu;
    RxDBGridStartMarks: TRxDBGrid;
    StartMarksDataset: TSQLQuery;
    procedure AcCopyExecute(Sender: TObject);
    procedure ComboBoxJournalFilterChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure RxDBGridStartMarksDblClick(Sender: TObject);
  private
    procedure ConfigureDiagnosticField;
    function CurrentFilter: TStartMarkJournalFilter;
    procedure DiagnosticFieldGetText(Sender: TField; var AText: string;
      DisplayText: boolean);
    procedure ConfigureJournalDataset;
    procedure RefreshJournal(const APreserveSelection: boolean);
    procedure StartMarkChanged(Sender: TObject; const AMarkId: int64);
  protected
    procedure ShowDiagnostic(const AText: string); virtual;
  public
    destructor Destroy; override;
  end;

procedure RunStartMarks;

var
  StartMarksForm: TStartMarksForm;

implementation

uses Main, InputDialogs, AppLogger, CompetitionQueryProvider,
  TimingMarkJournalUi;

procedure RunStartMarks;
begin
  with TStartMarksForm.Create(Application) do
  begin
    try
      ShowModal;
    finally
      Free;
    end;
  end;
end;

{$R *.lfm}

{ TStartMarksForm }

procedure TStartMarksForm.FormCreate(Sender: TObject);
var
  messageText: string;
begin
  Caption := rsStartMarks;
  AcCopy.Caption := rsCopy;
  LabelJournalFilter.Caption := rsStartMarkJournalFilter;
  ComboBoxJournalFilter.Items.Clear;
  ComboBoxJournalFilter.Items.Add(rsStartMarkJournalFilterAll);
  ComboBoxJournalFilter.Items.Add(rsStartMarkJournalFilterPending);
  ComboBoxJournalFilter.Items.Add(rsStartMarkJournalFilterApplied);
  ComboBoxJournalFilter.Items.Add(rsStartMarkJournalFilterHidden);
  ComboBoxJournalFilter.Items.Add(rsStartMarkJournalFilterConflictOrError);
  ComboBoxJournalFilter.Items.Add(rsStartMarkJournalFilterLast15Minutes);
  ComboBoxJournalFilter.Items.Add(rsStartMarkJournalFilterCurrentStage);
  ComboBoxJournalFilter.ItemIndex := Ord(smjfAll);
  RxDBGridStartMarks.Columns[0].Title.Caption := rsId;
  RxDBGridStartMarks.Columns[1].Title.Caption := rsReceivedStage;
  RxDBGridStartMarks.Columns[2].Title.Caption := rsAppliedStage;
  RxDBGridStartMarks.Columns[3].Title.Caption := rsTime;
  RxDBGridStartMarks.Columns[4].Title.Caption := rsCorrection;
  RxDBGridStartMarks.Columns[5].Title.Caption := rsNumber;
  RxDBGridStartMarks.Columns[6].Title.Caption := rsMatchDeltaMs;
  RxDBGridStartMarks.Columns[7].Title.Caption := rsTransport;
  RxDBGridStartMarks.Columns[8].Title.Caption := rsDevice;
  RxDBGridStartMarks.Columns[9].Title.Caption := rsAssignmentMode;
  RxDBGridStartMarks.Columns[10].Title.Caption := rsStatus;
  RxDBGridStartMarks.Columns[11].Title.Caption := rsReceivedAt;
  RxDBGridStartMarks.Columns[12].Title.Caption := rsAppliedAt;
  RxDBGridStartMarks.Columns[13].Title.Caption := rsDiagnostic;
  ConfigureJournalDataset;
  MainForm.CompetitionDb.RegisterUiQuery(StartMarksDataset);
  if Assigned(MainForm.StartMarkService) then
    MainForm.StartMarkService.OnChanged := @StartMarkChanged;
  try
    StartMarksDataset.Open;
    ConfigureDiagnosticField;
  except
    On E: Exception do
    begin
      messageText := Format(rsDatabaseOpenError, [E.Message]);
      AppLog(messageText, allError, alvStatus, alsStartMarks);
      AskMessageDlg(messageText, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TStartMarksForm.ConfigureDiagnosticField;
var
  DiagnosticField: TField;
begin
  if not StartMarksDataset.Active then
    Exit;
  DiagnosticField := StartMarksDataset.FindField('diagnostic');
  if Assigned(DiagnosticField) then
    DiagnosticField.OnGetText := @DiagnosticFieldGetText;
end;

procedure TStartMarksForm.DiagnosticFieldGetText(Sender: TField;
  var AText: string; DisplayText: boolean);
begin
  AText := Sender.AsString;
  if DisplayText then
    AText := TimingMarkDiagnosticPreview(AText);
end;

destructor TStartMarksForm.Destroy;
begin
  if Assigned(MainForm) and Assigned(MainForm.StartMarkService) then
    MainForm.StartMarkService.OnChanged := nil;
  inherited Destroy;
end;

function TStartMarksForm.CurrentFilter: TStartMarkJournalFilter;
begin
  if (ComboBoxJournalFilter.ItemIndex < Ord(Low(TStartMarkJournalFilter))) or
    (ComboBoxJournalFilter.ItemIndex > Ord(High(TStartMarkJournalFilter))) then
    Exit(smjfAll);
  Result := TStartMarkJournalFilter(ComboBoxJournalFilter.ItemIndex);
end;

procedure TStartMarksForm.ConfigureJournalDataset;
var
  ReceivedSince: TDateTime;
  StageIndex: integer;
begin
  ReceivedSince := 0;
  StageIndex := 0;
  if CurrentFilter = smjfLast15Minutes then
    ReceivedSince := IncMinute(Now, -15)
  else if CurrentFilter = smjfCurrentStage then
    StageIndex := MainForm.CurrentStageIndex;
  TDatasetSql.ConfigureStartMarkJournal(StartMarksDataset, CurrentFilter,
    ReceivedSince, StageIndex);
end;

procedure TStartMarksForm.RefreshJournal(const APreserveSelection: boolean);
var
  HasSelectedId: boolean;
  SelectedId: int64;
begin
  HasSelectedId := APreserveSelection and StartMarksDataset.Active and
    not StartMarksDataset.IsEmpty;
  if HasSelectedId then
    SelectedId := StartMarksDataset.FieldByName('id').AsLargeInt;
  StartMarksDataset.DisableControls;
  try
    ConfigureJournalDataset;
    StartMarksDataset.Open;
    ConfigureDiagnosticField;
    if HasSelectedId then
      StartMarksDataset.Locate('id', SelectedId, []);
  finally
    StartMarksDataset.EnableControls;
  end;
end;

procedure TStartMarksForm.StartMarkChanged(Sender: TObject;
  const AMarkId: int64);
begin
  try
    RefreshJournal(True);
  except
    on E: Exception do
      AppLog(Format(rsStartMarkJournalRefreshWarning, [E.Message]),
        allWarning, alvDetails, alsStartMarks);
  end;
end;

procedure TStartMarksForm.ComboBoxJournalFilterChange(Sender: TObject);
begin
  try
    RefreshJournal(True);
  except
    on E: Exception do
      AppLog(Format(rsStartMarkJournalRefreshWarning, [E.Message]),
        allWarning, alvStatus, alsStartMarks);
  end;
end;

procedure TStartMarksForm.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  StartMarksDataset.Close;
end;

procedure TStartMarksForm.AcCopyExecute(Sender: TObject);
begin
  if IsCompetitionDatabaseOpen and not StartMarksDataset.IsEmpty and
    Assigned(RxDBGridStartMarks.SelectedColumn) then
  begin
    CopyTimingMarkFieldToClipboard(StartMarksDataset.FieldByName(
      RxDBGridStartMarks.SelectedColumn.FieldName));
  end;
end;

procedure TStartMarksForm.RxDBGridStartMarksDblClick(Sender: TObject);
var
  DiagnosticText: string;
begin
  if not IsCompetitionDatabaseOpen or StartMarksDataset.IsEmpty or
    not Assigned(RxDBGridStartMarks.SelectedColumn) or
    (RxDBGridStartMarks.SelectedColumn.FieldName <> 'diagnostic') then
    Exit;
  DiagnosticText := StartMarksDataset.FieldByName('diagnostic').AsString;
  if DiagnosticText <> '' then
    ShowDiagnostic(DiagnosticText);
end;

procedure TStartMarksForm.ShowDiagnostic(const AText: string);
begin
  ShowTimingMarkDiagnostic(Self, AText, rsDiagnostic);
end;

end.
