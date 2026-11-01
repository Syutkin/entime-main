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
    LabelStageScope: TLabel;
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
    FStageScope: integer;
    FParticipantNumber: integer;
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
    function ConfigureParticipantRecord(const ANumber, AReceivedStage: integer;
      const AMarkId: int64): boolean;
    procedure ConfigureScope(const AStageIndex: integer;
      const AFilter: TStartMarkJournalFilter);
    destructor Destroy; override;
  end;

procedure RunStartMarks; overload;
procedure RunStartMarks(const AStageIndex: integer;
  const AFilter: TStartMarkJournalFilter); overload;

var
  StartMarksForm: TStartMarksForm;

implementation

uses Main, InputDialogs, AppLogger, CompetitionQueryProvider,
  TimingMarkJournalUi;

procedure RunStartMarks;
begin
  RunStartMarks(0, smjfAll);
end;

procedure RunStartMarks(const AStageIndex: integer;
  const AFilter: TStartMarkJournalFilter);
var
  Journal: TStartMarksForm;
begin
  Journal := TStartMarksForm.Create(Application);
  try
    Journal.ConfigureScope(AStageIndex, AFilter);
    Journal.ShowModal;
  finally
    Journal.Free;
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

procedure TStartMarksForm.ConfigureScope(const AStageIndex: integer;
  const AFilter: TStartMarkJournalFilter);
begin
  if AStageIndex < 0 then
    raise EArgumentOutOfRangeException.Create('Invalid stage scope.');
  if (FStageScope = AStageIndex) and (CurrentFilter = AFilter) then Exit;
  if ((AStageIndex > 0) or (AFilter in [smjfPendingOrConflict, smjfError])) and
    (ComboBoxJournalFilter.Items.Count = Ord(smjfPendingOrConflict)) then
  begin
    ComboBoxJournalFilter.Items.Add(rsStartMarkJournalFilterPendingOrConflict);
    ComboBoxJournalFilter.Items.Add(rsStartMarkJournalFilterError);
  end;
  FParticipantNumber := 0;
  FStageScope := AStageIndex;
  LabelStageScope.Caption := Format(rsSUFormat, [AStageIndex]);
  LabelStageScope.Visible := AStageIndex > 0;
  if AStageIndex > 0 then
    ComboBoxJournalFilter.Items[Ord(smjfCurrentStage)] := LabelStageScope.Caption
  else
    ComboBoxJournalFilter.Items[Ord(smjfCurrentStage)] :=
      rsStartMarkJournalFilterCurrentStage;
  ComboBoxJournalFilter.ItemIndex := Ord(AFilter);
  RefreshJournal(False);
end;

function TStartMarksForm.ConfigureParticipantRecord(
  const ANumber, AReceivedStage: integer; const AMarkId: int64): boolean;
begin
  if (ANumber <= 0) or (AReceivedStage <= 0) or (AMarkId <= 0) then
    raise EArgumentOutOfRangeException.Create('Invalid participant journal scope');
  FParticipantNumber := ANumber;
  FStageScope := AReceivedStage;
  ComboBoxJournalFilter.ItemIndex := 0;
  LabelStageScope.Caption := Format(rsSUFormat, [AReceivedStage]) +
    ' · ' + rsNumber + ': ' + IntToStr(ANumber);
  LabelStageScope.Visible := True;
  RefreshJournal(False);
  Result := StartMarksDataset.Locate('id', AMarkId, []);
end;

procedure TStartMarksForm.ConfigureJournalDataset;
var
  ReceivedSince: TDateTime;
  StageIndex, OrderPos: integer;
  Sql: string;
begin
  ReceivedSince := 0;
  StageIndex := FStageScope;
  if CurrentFilter = smjfLast15Minutes then
    ReceivedSince := IncMinute(Now, -15);
  if (CurrentFilter = smjfCurrentStage) and (StageIndex = 0) then
    StageIndex := MainForm.CurrentStageIndex;
  TDatasetSql.ConfigureStartMarkJournal(StartMarksDataset, CurrentFilter,
    ReceivedSince, StageIndex);
  if FParticipantNumber > 0 then
  begin
    Sql := StartMarksDataset.SQL.Text;
    OrderPos := Pos(' ORDER BY ', UpperCase(Sql));
    Insert(' AND participant_number = :CARD_NUMBER', Sql, OrderPos);
    StartMarksDataset.SQL.Text := Sql;
    TStartMarkSql.BindJournalParameters(StartMarksDataset, CurrentFilter,
      ReceivedSince, StageIndex);
    StartMarksDataset.ParamByName('CARD_NUMBER').AsInteger := FParticipantNumber;
  end;
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

procedure TStartMarksForm.StartMarkChanged(Sender: TObject; const AMarkId: int64);
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

procedure TStartMarksForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
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
