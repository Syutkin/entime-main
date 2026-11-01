unit FinishMarks;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, DB, SQLDB, Forms, Controls, Dialogs,
  StdCtrls, ExtCtrls, RxDBGrid, i18n, DBGrids, Menus, ActnList,
  FinishMarkRepository, FinishMarkService;

type
  { TFinishMarksForm }

  TFinishMarksForm = class(TForm)
    AcCopy: TAction;
    ActionList1: TActionList;
    ComboBoxJournalFilter: TComboBox;
    DataSourceFinishMarks: TDataSource;
    FinishMarksDataset: TSQLQuery;
    LabelJournalFilter: TLabel;
    LabelStageScope: TLabel;
    MenuItemCopy: TMenuItem;
    PanelJournalFilter: TPanel;
    PopupMenu1: TPopupMenu;
    RxDBGridFinishMarks: TRxDBGrid;
    procedure AcCopyExecute(Sender: TObject);
    procedure ComboBoxJournalFilterChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure RxDBGridFinishMarksDblClick(Sender: TObject);
  private
    FStageScope: integer;
    FParticipantNumber: integer;
    procedure ConfigureDiagnosticField;
    procedure ConfigureJournalDataset;
    function CurrentFilter: TFinishMarkJournalFilter;
    procedure DiagnosticFieldGetText(Sender: TField; var AText: string;
      DisplayText: boolean);
    procedure FinishMarkChanged(Sender: TObject; const AMarkId: int64);
    procedure RefreshJournal(const APreserveSelection: boolean);
  protected
    procedure ShowDiagnostic(const AText: string); virtual;
  public
    function ConfigureParticipantRecord(const ANumber, AReceivedStage: integer;
      const AMarkId: int64): boolean;
    procedure ConfigureScope(const AStageIndex: integer;
      const AFilter: TFinishMarkJournalFilter);
    destructor Destroy; override;
  end;

procedure RunFinishMarks; overload;
procedure RunFinishMarks(const AStageIndex: integer;
  const AFilter: TFinishMarkJournalFilter); overload;

implementation

uses
  Main, InputDialogs, AppLogger, CompetitionQueryProvider,
  TimingMarkJournalUi;

  {$R *.lfm}

procedure RunFinishMarks;
begin
  RunFinishMarks(0, fmjfAll);
end;

procedure RunFinishMarks(const AStageIndex: integer;
  const AFilter: TFinishMarkJournalFilter);
var
  Journal: TFinishMarksForm;
begin
  Journal := TFinishMarksForm.Create(Application);
  try
    Journal.ConfigureScope(AStageIndex, AFilter);
    Journal.ShowModal;
  finally
    Journal.Free;
  end;
end;

{ TFinishMarksForm }

procedure TFinishMarksForm.FormCreate(Sender: TObject);
var
  MessageText: string;
begin
  Caption := rsFinishMarks;
  AcCopy.Caption := rsCopy;
  LabelJournalFilter.Caption := rsFinishMarkJournalFilter;
  ComboBoxJournalFilter.Items.Clear;
  ComboBoxJournalFilter.Items.Add(rsFinishMarkJournalFilterAll);
  ComboBoxJournalFilter.Items.Add(rsFinishMarkJournalFilterPending);
  ComboBoxJournalFilter.Items.Add(rsFinishMarkJournalFilterApplied);
  ComboBoxJournalFilter.Items.Add(rsFinishMarkJournalFilterIgnoredDebounce);
  ComboBoxJournalFilter.Items.Add(rsFinishMarkJournalFilterHidden);
  ComboBoxJournalFilter.Items.Add(rsFinishMarkJournalFilterError);
  ComboBoxJournalFilter.Items.Add(rsFinishMarkJournalFilterLast15Minutes);
  ComboBoxJournalFilter.Items.Add(rsFinishMarkJournalFilterCurrentStage);
  ComboBoxJournalFilter.ItemIndex := Ord(fmjfAll);

  RxDBGridFinishMarks.Columns[0].Title.Caption := rsId;
  RxDBGridFinishMarks.Columns[1].Title.Caption := rsReceivedStage;
  RxDBGridFinishMarks.Columns[2].Title.Caption := rsTime;
  RxDBGridFinishMarks.Columns[3].Title.Caption := rsNumber;
  RxDBGridFinishMarks.Columns[4].Title.Caption := rsTransport;
  RxDBGridFinishMarks.Columns[5].Title.Caption := rsDevice;
  RxDBGridFinishMarks.Columns[6].Title.Caption := rsAssignmentMode;
  RxDBGridFinishMarks.Columns[7].Title.Caption := rsStatus;
  RxDBGridFinishMarks.Columns[8].Title.Caption := rsReceivedAt;
  RxDBGridFinishMarks.Columns[9].Title.Caption := rsAppliedAt;
  RxDBGridFinishMarks.Columns[10].Title.Caption := rsDiagnostic;

  ConfigureJournalDataset;
  MainForm.CompetitionDb.RegisterUiQuery(FinishMarksDataset);
  if Assigned(MainForm.FinishMarkService) then
    MainForm.FinishMarkService.OnChanged := @FinishMarkChanged;
  try
    FinishMarksDataset.Open;
    ConfigureDiagnosticField;
  except
    on E: Exception do
    begin
      MessageText := Format(rsDatabaseOpenError, [E.Message]);
      AppLog(MessageText, allError, alvStatus, alsFinishMarks);
      AskMessageDlg(MessageText, mtError, [mbOK], 0);
    end;
  end;
end;

destructor TFinishMarksForm.Destroy;
begin
  if Assigned(MainForm) and Assigned(MainForm.FinishMarkService) then
    MainForm.FinishMarkService.OnChanged := nil;
  inherited Destroy;
end;

procedure TFinishMarksForm.ConfigureDiagnosticField;
var
  DiagnosticField: TField;
begin
  if not FinishMarksDataset.Active then
    Exit;
  DiagnosticField := FinishMarksDataset.FindField('diagnostic');
  if Assigned(DiagnosticField) then
    DiagnosticField.OnGetText := @DiagnosticFieldGetText;
end;

procedure TFinishMarksForm.DiagnosticFieldGetText(Sender: TField;
  var AText: string; DisplayText: boolean);
begin
  AText := Sender.AsString;
  if DisplayText then
    AText := TimingMarkDiagnosticPreview(AText);
end;

function TFinishMarksForm.CurrentFilter: TFinishMarkJournalFilter;
begin
  if (ComboBoxJournalFilter.ItemIndex < Ord(Low(TFinishMarkJournalFilter))) or
    (ComboBoxJournalFilter.ItemIndex > Ord(High(TFinishMarkJournalFilter))) then
    Exit(fmjfAll);
  Result := TFinishMarkJournalFilter(ComboBoxJournalFilter.ItemIndex);
end;

procedure TFinishMarksForm.ConfigureScope(const AStageIndex: integer;
  const AFilter: TFinishMarkJournalFilter);
begin
  if AStageIndex < 0 then
    raise EArgumentOutOfRangeException.Create('Invalid stage scope.');
  if (FStageScope = AStageIndex) and (CurrentFilter = AFilter) then Exit;
  FParticipantNumber := 0;
  FStageScope := AStageIndex;
  LabelStageScope.Caption := Format(rsSUFormat, [AStageIndex]);
  LabelStageScope.Visible := AStageIndex > 0;
  if AStageIndex > 0 then
    ComboBoxJournalFilter.Items[Ord(fmjfCurrentStage)] := LabelStageScope.Caption
  else
    ComboBoxJournalFilter.Items[Ord(fmjfCurrentStage)] :=
      rsFinishMarkJournalFilterCurrentStage;
  ComboBoxJournalFilter.ItemIndex := Ord(AFilter);
  RefreshJournal(False);
end;

function TFinishMarksForm.ConfigureParticipantRecord(
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
  Result := FinishMarksDataset.Locate('id', AMarkId, []);
end;

procedure TFinishMarksForm.ConfigureJournalDataset;
var
  ReceivedSince: TDateTime;
  StageIndex, OrderPos: integer;
  Sql: string;
begin
  ReceivedSince := 0;
  StageIndex := FStageScope;
  if CurrentFilter = fmjfLast15Minutes then
    ReceivedSince := IncMinute(Now, -15);
  if (CurrentFilter = fmjfCurrentStage) and (StageIndex = 0) then
    StageIndex := MainForm.CurrentStageIndex;
  TDatasetSql.ConfigureFinishMarkJournal(FinishMarksDataset, CurrentFilter,
    ReceivedSince, StageIndex);
  if FParticipantNumber > 0 then
  begin
    Sql := FinishMarksDataset.SQL.Text;
    OrderPos := Pos(' ORDER BY ', UpperCase(Sql));
    Insert(' AND participant_number = :CARD_NUMBER', Sql, OrderPos);
    FinishMarksDataset.SQL.Text := Sql;
    TFinishMarkSql.BindJournalParameters(FinishMarksDataset, CurrentFilter,
      ReceivedSince, StageIndex);
    FinishMarksDataset.ParamByName('CARD_NUMBER').AsInteger := FParticipantNumber;
  end;
end;

procedure TFinishMarksForm.RefreshJournal(const APreserveSelection: boolean);
var
  HasSelectedId: boolean;
  SelectedId: int64;
begin
  HasSelectedId := APreserveSelection and FinishMarksDataset.Active and
    not FinishMarksDataset.IsEmpty;
  if HasSelectedId then
    SelectedId := FinishMarksDataset.FieldByName('id').AsLargeInt;
  FinishMarksDataset.DisableControls;
  try
    ConfigureJournalDataset;
    FinishMarksDataset.Open;
    ConfigureDiagnosticField;
    if HasSelectedId then
      FinishMarksDataset.Locate('id', SelectedId, []);
  finally
    FinishMarksDataset.EnableControls;
  end;
end;

procedure TFinishMarksForm.FinishMarkChanged(Sender: TObject; const AMarkId: int64);
begin
  try
    RefreshJournal(True);
  except
    on E: Exception do
      AppLog(Format(rsFinishMarkJournalRefreshWarning, [E.Message]),
        allWarning, alvDetails, alsFinishMarks);
  end;
end;

procedure TFinishMarksForm.ComboBoxJournalFilterChange(Sender: TObject);
begin
  try
    RefreshJournal(True);
  except
    on E: Exception do
      AppLog(Format(rsFinishMarkJournalRefreshWarning, [E.Message]),
        allWarning, alvStatus, alsFinishMarks);
  end;
end;

procedure TFinishMarksForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FinishMarksDataset.Close;
end;

procedure TFinishMarksForm.AcCopyExecute(Sender: TObject);
begin
  if IsCompetitionDatabaseOpen and not FinishMarksDataset.IsEmpty and
    Assigned(RxDBGridFinishMarks.SelectedColumn) then
  begin
    CopyTimingMarkFieldToClipboard(FinishMarksDataset.FieldByName(
      RxDBGridFinishMarks.SelectedColumn.FieldName));
  end;
end;

procedure TFinishMarksForm.RxDBGridFinishMarksDblClick(Sender: TObject);
var
  DiagnosticText: string;
begin
  if not IsCompetitionDatabaseOpen or FinishMarksDataset.IsEmpty or
    not Assigned(RxDBGridFinishMarks.SelectedColumn) or
    (RxDBGridFinishMarks.SelectedColumn.FieldName <> 'diagnostic') then
    Exit;
  DiagnosticText := FinishMarksDataset.FieldByName('diagnostic').AsString;
  if DiagnosticText <> '' then
    ShowDiagnostic(DiagnosticText);
end;

procedure TFinishMarksForm.ShowDiagnostic(const AText: string);
begin
  ShowTimingMarkDiagnostic(Self, AText, rsDiagnostic);
end;

end.
