unit ProtocolBalanceFrame;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, Forms, Controls, StdCtrls, ExtCtrls, ActnList, Menus, DB, DBGrids,
  MemDS, rxdbgrid, CompetitionDbContext, StageModel, ProtocolBalance;

type
  TProtocolBalanceJournalKind = (pbjkPendingStarts, pbjkPendingFinishes,
    pbjkStartErrors, pbjkFinishErrors);
  TProtocolBalanceParticipantEvent = procedure(Sender: TObject;
    const AParticipantId, AStageIndex: integer) of object;
  TProtocolBalanceJournalEvent = procedure(Sender: TObject;
    const AStageIndex: integer; const AKind: TProtocolBalanceJournalKind) of object;

  TProtocolBalanceFrame = class(TFrame)
    ActionList: TActionList;
    RefreshAction: TAction;
    OpenParticipantAction: TAction;
    OpenCardAction: TAction;
    CardPopupMenu: TPopupMenu;
    CardMenuItem: TMenuItem;
    OpenPendingStartsAction: TAction;
    OpenPendingFinishesAction: TAction;
    OpenStartErrorsAction: TAction;
    OpenFinishErrorsAction: TAction;
    HeaderPanel: TPanel;
    TitleLabel: TLabel;
    StateLabel: TLabel;
    RefreshButton: TButton;
    ContentPanel: TPanel;
    SummaryPanel: TPanel;
    SummaryGrid: TRxDBGrid;
    SummarySplitter: TSplitter;
    DetailsPanel: TPanel;
    FilterPanel: TPanel;
    StageLabel: TLabel;
    FilterLabel: TLabel;
    FilterComboBox: TComboBox;
    RecordCountLabel: TLabel;
    DetailsGrid: TRxDBGrid;
    ActionsPanel: TPanel;
    IncomingGroup: TGroupBox;
    PendingStartsButton: TButton;
    PendingFinishesButton: TButton;
    StartErrorsButton: TButton;
    FinishErrorsButton: TButton;
    SummaryData: TMemDataset;
    DetailsData: TMemDataset;
    SummarySource: TDataSource;
    DetailsSource: TDataSource;
    procedure OpenCardActionExecute(Sender: TObject);
    procedure RefreshActionExecute(Sender: TObject);
    procedure FilterComboBoxChange(Sender: TObject);
    procedure SummaryDataAfterScroll(DataSet: TDataSet);
    procedure SummaryGridCellClick(Column: TColumn);
    procedure SummaryGridKeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);
    procedure NavigationActionUpdate(Sender: TObject);
    procedure OpenParticipantActionExecute(Sender: TObject);
    procedure OpenJournalActionExecute(Sender: TObject);
    procedure DetailsGridDblClick(Sender: TObject);
    procedure DetailsGridKeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);
  private
    FContext: TCompetitionDbContext;
    FStages: TStages;
    FSnapshot: TProtocolBalanceSnapshot;
    FHasSnapshot, FUpdating: boolean;
    FDirty, FRefreshQueued, FViewActive: boolean;
    FGeneration: PtrInt;
    FSavedStage, FSavedParticipant, FSavedDetailPosition: integer;
    FReadError: string;
    FOnOpenParticipant: TProtocolBalanceParticipantEvent;
    FOnOpenCard: TProtocolBalanceParticipantEvent;
    FOnOpenJournal: TProtocolBalanceJournalEvent;
    function NavigationReady: boolean;
    procedure DisplayFieldText(Sender: TField; var AText: string;
      DisplayText: boolean);
    function SelectedStagePosition: integer;
    procedure ApplySummaryFilter(const AColumn: TColumn);
    procedure ShowDetails(const AParticipantId: integer = 0;
      const AFallbackPosition: integer = 1);
    procedure ShowUnavailableCounts;
    procedure CancelQueuedRefresh;
    procedure QueueRefresh;
    procedure RunQueuedRefresh(AGeneration: PtrInt);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Configure(const AContext: TCompetitionDbContext;
      const AStages: TStages);
    procedure Clear;
    procedure RefreshData;
    procedure InvalidateData;
    procedure SetViewActive(const AActive: boolean);
    procedure UpdateTranslations;
    property OnOpenCard: TProtocolBalanceParticipantEvent
      read FOnOpenCard write FOnOpenCard;
    property OnOpenParticipant: TProtocolBalanceParticipantEvent
      read FOnOpenParticipant write FOnOpenParticipant;
    property OnOpenJournal: TProtocolBalanceJournalEvent
      read FOnOpenJournal write FOnOpenJournal;
  end;

implementation

uses
  SysUtils, LCLType, i18n, ProtocolBalanceRepository, AppLogger;

  {$R *.lfm}

constructor TProtocolBalanceFrame.Create(AOwner: TComponent);
var
  Field: TField;
begin
  inherited Create(AOwner);
  SummaryData.CreateTable;
  SummaryData.Open;
  DetailsData.CreateTable;
  DetailsData.Open;
  for Field in SummaryData.Fields do
    if Field.DataType = ftMemo then Field.OnGetText := @DisplayFieldText;
  for Field in DetailsData.Fields do
    if Field.DataType = ftMemo then Field.OnGetText := @DisplayFieldText;
  Clear;
  UpdateTranslations;
end;

procedure TProtocolBalanceFrame.UpdateTranslations;
var
  SavedFilter, SavedParticipant, SavedPosition: integer;
  WasUpdating: boolean;
begin
  SavedFilter := FilterComboBox.ItemIndex;
  SavedParticipant := 0;
  SavedPosition := 1;
  if not DetailsData.IsEmpty then
  begin
    SavedParticipant := DetailsData.FieldByName('participant_id').AsInteger;
    SavedPosition := DetailsData.RecNo;
  end;
  TitleLabel.Caption := rsProtocolBalance;
  RefreshAction.Caption := rsProtocolBalanceRefresh;
  StageLabel.Caption := rsProtocolBalanceStageNotSelected;
  FilterLabel.Caption := rsProtocolBalanceShow;
  RecordCountLabel.Caption := rsProtocolBalanceRecordCountUnavailable;
  IncomingGroup.Caption := rsProtocolBalanceIncoming;
  OpenParticipantAction.Caption := rsProtocolBalanceOpenParticipant;
  OpenCardAction.Caption := rsCardTitle;
  OpenPendingStartsAction.Caption := rsProtocolBalancePendingStartsUnavailable;
  OpenPendingFinishesAction.Caption := rsProtocolBalancePendingFinishesUnavailable;
  OpenStartErrorsAction.Caption := rsProtocolBalanceStartErrorsUnavailable;
  OpenFinishErrorsAction.Caption := rsProtocolBalanceFinishErrorsUnavailable;

  WasUpdating := FUpdating;
  FUpdating := True;
  FilterComboBox.Items.BeginUpdate;
  try
    FilterComboBox.Items.Clear;
    FilterComboBox.Items.Add(rsProtocolBalanceAllParticipants);
    FilterComboBox.Items.Add(rsProtocolBalanceWithResult);
    FilterComboBox.Items.Add('DNS');
    FilterComboBox.Items.Add('DNF');
    FilterComboBox.Items.Add('DSQ');
    FilterComboBox.Items.Add(rsProtocolBalanceUnresolved);
    FilterComboBox.Items.Add(rsProtocolBalanceFinishWithoutStart);
    FilterComboBox.ItemIndex := SavedFilter;
  finally
    FilterComboBox.Items.EndUpdate;
    FUpdating := WasUpdating;
  end;

  SummaryGrid.Columns[0].Title.Caption := rsSU;
  SummaryGrid.Columns[1].Title.Caption := rsProtocolBalanceParticipants;
  SummaryGrid.Columns[2].Title.Caption := rsProtocolBalanceWithResult;
  SummaryGrid.Columns[6].Title.Caption := rsProtocolBalanceUnresolved;
  DetailsGrid.Columns[0].Title.Caption := rsNumber;
  DetailsGrid.Columns[1].Title.Caption := rsName;
  DetailsGrid.Columns[2].Title.Caption := rsCategory;
  DetailsGrid.Columns[3].Title.Caption := rsStarttime;
  DetailsGrid.Columns[4].Title.Caption := rsFinishtime;
  DetailsGrid.Columns[5].Title.Caption := rsResult;
  DetailsGrid.Columns[6].Title.Caption := rsProtocolBalanceGroup;
  DetailsGrid.Columns[7].Title.Caption := rsProtocolBalanceState;

  if FHasSnapshot then ShowDetails(SavedParticipant, SavedPosition)
  else if FReadError <> '' then
    StateLabel.Caption := Format(rsProtocolBalanceReadError, [FReadError])
  else if FDirty then
    StateLabel.Caption := rsProtocolBalanceStale
  else
    StateLabel.Caption := rsProtocolBalanceOpenCompetition;
end;

destructor TProtocolBalanceFrame.Destroy;
begin
  CancelQueuedRefresh;
  inherited Destroy;
end;

procedure TProtocolBalanceFrame.CancelQueuedRefresh;
begin
  Application.RemoveAsyncCalls(Self);
  FRefreshQueued := False;
end;

procedure TProtocolBalanceFrame.QueueRefresh;
begin
  if FViewActive and FDirty and not FRefreshQueued and not
    (csDestroying in ComponentState) and (FContext <> nil) and
    FContext.Connection.Connected then
  begin
    FRefreshQueued := True;
    Application.QueueAsyncCall(@RunQueuedRefresh, FGeneration);
  end;
end;

procedure TProtocolBalanceFrame.RunQueuedRefresh(AGeneration: PtrInt);
begin
  if AGeneration <> FGeneration then Exit;
  FRefreshQueued := False;
  if FViewActive and FDirty then RefreshData;
end;

procedure TProtocolBalanceFrame.InvalidateData;
begin
  if (FContext = nil) or not FContext.Connection.Connected then Exit;
  FDirty := True;
  StateLabel.Caption := rsProtocolBalanceStale;
  RefreshAction.Enabled := True;
  QueueRefresh;
end;

procedure TProtocolBalanceFrame.SetViewActive(const AActive: boolean);
begin
  FViewActive := AActive;
  if not AActive then CancelQueuedRefresh
  else
  begin
    if not FHasSnapshot then FDirty := True;
    QueueRefresh;
  end;
end;

function BalanceGroupText(const AGroup: TProtocolBalanceGroup): string;
begin
  case AGroup of
    pbgUnresolved: Result := rsProtocolBalanceUnresolved;
    pbgWithResult: Result := rsProtocolBalanceWithResult;
    pbgDNS: Result := 'DNS';
    pbgDNF: Result := 'DNF';
    pbgDSQ: Result := 'DSQ';
  end;
end;

function BalanceReasonText(const ARow: TProtocolBalanceParticipantRow): string;
begin
  case ARow.Classification.Reason of
    pbrNone: Result := '';
    pbrNoStageData: Result := rsProtocolBalanceNoStageData;
    pbrMissingFinish: Result := rsProtocolBalanceMissingFinish;
    pbrFinishWithoutStart: Result := rsProtocolBalanceFinishWithoutStart;
    pbrMissingOrInvalidResult:
      if Trim(ARow.Data.ResultValue) = '' then
        Result := rsProtocolBalanceMissingResult
      else
        Result := Format(rsProtocolBalanceInvalidResult, [ARow.Data.ResultValue]);
    pbrUnknownStageStatus:
      Result := Format(rsProtocolBalanceUnknownStatus, [ARow.Data.StageStatusValue]);
  end;
end;

function BalanceDisplayValue(const AValue: string): string;
begin
  if Trim(AValue) = '' then Result := '—'
  else
    Result := AValue;
end;

procedure TProtocolBalanceFrame.DisplayFieldText(Sender: TField;
  var AText: string; DisplayText: boolean);
begin
  AText := Sender.AsString;
  if DisplayText and (Trim(AText) = '') then AText := '—';
end;

procedure TProtocolBalanceFrame.Configure(const AContext: TCompetitionDbContext;
  const AStages: TStages);
begin
  FContext := AContext;
  FStages := AStages;
  Clear;
end;

procedure TProtocolBalanceFrame.ShowUnavailableCounts;
begin
  OpenPendingStartsAction.Caption := rsProtocolBalancePendingStartsUnavailable;
  OpenPendingFinishesAction.Caption := rsProtocolBalancePendingFinishesUnavailable;
  OpenStartErrorsAction.Caption := rsProtocolBalanceStartErrorsUnavailable;
  OpenFinishErrorsAction.Caption := rsProtocolBalanceFinishErrorsUnavailable;
end;

procedure TProtocolBalanceFrame.Clear;
begin
  CancelQueuedRefresh;
  Inc(FGeneration);
  FDirty := False;
  FReadError := '';
  FSavedStage := 0;
  FSavedParticipant := 0;
  FSavedDetailPosition := 1;
  FHasSnapshot := False;
  FSnapshot := Default(TProtocolBalanceSnapshot);
  FUpdating := True;
  SummaryData.DisableControls;
  DetailsData.DisableControls;
  try
    SummaryData.Clear(False);
    DetailsData.Clear(False);
    FilterComboBox.ItemIndex := Ord(pbfUnresolved);
    FilterComboBox.Enabled := False;
    RefreshAction.Enabled := False;
    StageLabel.Caption := rsProtocolBalanceStageNotSelected;
    RecordCountLabel.Caption := rsProtocolBalanceRecordCountUnavailable;
    StateLabel.Caption := rsProtocolBalanceOpenCompetition;
    ShowUnavailableCounts;
  finally
    DetailsData.EnableControls;
    SummaryData.EnableControls;
    FUpdating := False;
  end;
end;

function TProtocolBalanceFrame.SelectedStagePosition: integer;
var
  I, StageIndex: integer;
begin
  Result := -1;
  if not FHasSnapshot or SummaryData.IsEmpty then Exit;
  StageIndex := SummaryData.FieldByName('stage_index').AsInteger;
  for I := 0 to High(FSnapshot.Stages) do
    if FSnapshot.Stages[I].StageIndex = StageIndex then Exit(I);
end;

procedure TProtocolBalanceFrame.RefreshData;
var
  Snapshot: TProtocolBalanceSnapshot;
  Stage: TProtocolBalanceStageSnapshot;
  SavedFilter: integer;
begin
  if FUpdating then Exit;
  CancelQueuedRefresh;
  if (FContext = nil) or (FStages = nil) or not FContext.Connection.Connected then
  begin
    Clear;
    Exit;
  end;
  if not SummaryData.IsEmpty then
    FSavedStage := SummaryData.FieldByName('stage_index').AsInteger;
  if not DetailsData.IsEmpty then
  begin
    FSavedParticipant := DetailsData.FieldByName('participant_id').AsInteger;
    FSavedDetailPosition := DetailsData.RecNo;
  end
  else if FHasSnapshot then
  begin
    FSavedParticipant := 0;
    FSavedDetailPosition := 1;
  end;
  SavedFilter := FilterComboBox.ItemIndex;
  RefreshAction.Enabled := True;
  try
    if not TProtocolBalanceRepository.TryLoadSaved(FContext, FStages, Snapshot) then
    begin
      FDirty := True;
      StateLabel.Caption := rsProtocolBalanceStale;
      Exit;
    end;
    FUpdating := True;
    SummaryData.DisableControls;
    try
      FSnapshot := Snapshot;
      FHasSnapshot := True;
      FDirty := False;
      FReadError := '';
      SummaryData.Clear(False);
      for Stage in FSnapshot.Stages do
        SummaryData.AppendRecord([Stage.StageIndex,
          Format('%d — %s', [Stage.StageIndex, Stage.StageName]),
          Stage.Summary.ParticipantCount, Stage.Summary.GroupCounts[pbgWithResult],
          Stage.Summary.GroupCounts[pbgDNS], Stage.Summary.GroupCounts[pbgDNF],
          Stage.Summary.GroupCounts[pbgDSQ], Stage.Summary.GroupCounts[pbgUnresolved]]);
      if not SummaryData.Locate('stage_index', FSavedStage, []) then
        SummaryData.First;
    finally
      SummaryData.EnableControls;
      FUpdating := False;
    end;
    ShowDetails(FSavedParticipant, FSavedDetailPosition);
  except
    on E: Exception do
    begin
      // Clear the failed display without discarding the user's selection.
      FHasSnapshot := False;
      FSnapshot := Default(TProtocolBalanceSnapshot);
      FDirty := True;
      FUpdating := True;
      SummaryData.DisableControls;
      DetailsData.DisableControls;
      try
        SummaryData.Clear(False);
        DetailsData.Clear(False);
        FilterComboBox.ItemIndex := SavedFilter;
        FilterComboBox.Enabled := False;
        StageLabel.Caption := rsProtocolBalanceStageNotSelected;
        RecordCountLabel.Caption := rsProtocolBalanceRecordCountUnavailable;
        ShowUnavailableCounts;
      finally
        DetailsData.EnableControls;
        SummaryData.EnableControls;
        FUpdating := False;
      end;
      RefreshAction.Enabled := True;
      FReadError := E.Message;
      StateLabel.Caption := Format(rsProtocolBalanceReadError, [FReadError]);
      AppLog(StateLabel.Caption, allError, alvNone, alsDatabase);
    end;
  end;
end;

procedure TProtocolBalanceFrame.ShowDetails(const AParticipantId: integer;
  const AFallbackPosition: integer);
var
  Position: integer;
  Row: TProtocolBalanceParticipantRow;
  Filter: TProtocolBalanceFilter;
begin
  Position := SelectedStagePosition;
  DetailsData.DisableControls;
  try
    DetailsData.Clear(False);
    FilterComboBox.Enabled := Position >= 0;
    if Position < 0 then
    begin
      StageLabel.Caption := rsProtocolBalanceStageNotSelected;
      RecordCountLabel.Caption := rsProtocolBalanceRecordCountUnavailable;
      StateLabel.Caption := rsProtocolBalanceNoActiveStages;
      ShowUnavailableCounts;
      Exit;
    end;
    Filter := TProtocolBalanceFilter(FilterComboBox.ItemIndex);
    for Row in FSnapshot.Stages[Position].Participants do
      if MatchesProtocolBalanceFilter(Row.Classification, Filter) then
        DetailsData.AppendRecord([Row.ParticipantId, Row.Number,
          BalanceDisplayValue(Row.Name), BalanceDisplayValue(Row.Category),
          BalanceDisplayValue(Row.Data.StartTime),
          BalanceDisplayValue(Row.Data.FinishTime), BalanceDisplayValue(
          Row.Data.ResultValue), BalanceGroupText(Row.Classification.Group),
          BalanceReasonText(Row)]);
    if not DetailsData.Locate('participant_id', AParticipantId, []) then
    begin
      DetailsData.First;
      if (AFallbackPosition > 1) and not DetailsData.IsEmpty then
        if AFallbackPosition <= DetailsData.RecordCount then
          DetailsData.RecNo := AFallbackPosition
        else
          DetailsData.Last;
    end;
    StageLabel.Caption := SummaryData.FieldByName('stage_name').AsString;
    RecordCountLabel.Caption :=
      Format(rsProtocolBalanceRecordCount, [DetailsData.RecordCount]);
    OpenPendingStartsAction.Caption :=
      Format(rsProtocolBalancePendingStarts,
      [FSnapshot.Stages[Position].Marks.PendingStarts]);
    OpenPendingFinishesAction.Caption :=
      Format(rsProtocolBalancePendingFinishes,
      [FSnapshot.Stages[Position].Marks.PendingFinishes]);
    OpenStartErrorsAction.Caption :=
      Format(rsProtocolBalanceStartErrors,
      [FSnapshot.Stages[Position].Marks.StartErrors]);
    OpenFinishErrorsAction.Caption :=
      Format(rsProtocolBalanceFinishErrors,
      [FSnapshot.Stages[Position].Marks.FinishErrors]);
    if FDirty then
      StateLabel.Caption := rsProtocolBalanceStale
    else if FSnapshot.Stages[Position].Summary.ParticipantCount = 0 then
      StateLabel.Caption := rsProtocolBalanceNoParticipants
    else if DetailsData.IsEmpty then
      StateLabel.Caption := rsProtocolBalanceNoMatchingParticipants
    else
      StateLabel.Caption := rsProtocolBalanceReady;
  finally
    DetailsData.EnableControls;
  end;
end;

procedure TProtocolBalanceFrame.RefreshActionExecute(Sender: TObject);
begin
  RefreshData;
end;

procedure TProtocolBalanceFrame.FilterComboBoxChange(Sender: TObject);
begin
  if not FUpdating and FHasSnapshot then ShowDetails;
end;

procedure TProtocolBalanceFrame.SummaryDataAfterScroll(DataSet: TDataSet);
begin
  if not FUpdating and FHasSnapshot then ShowDetails;
end;

procedure TProtocolBalanceFrame.ApplySummaryFilter(const AColumn: TColumn);
var
  Filter: TProtocolBalanceFilter;
begin
  if (AColumn = nil) or not FHasSnapshot or SummaryData.IsEmpty then Exit;
  case AColumn.FieldName of
    'participant_count': Filter := pbfAll;
    'result_count': Filter := pbfWithResult;
    'dns_count': Filter := pbfDNS;
    'dnf_count': Filter := pbfDNF;
    'dsq_count': Filter := pbfDSQ;
    'unresolved_count': Filter := pbfUnresolved;
    else
      Exit;
  end;
  FilterComboBox.ItemIndex := Ord(Filter);
  ShowDetails;
end;

procedure TProtocolBalanceFrame.SummaryGridCellClick(Column: TColumn);
begin
  ApplySummaryFilter(Column);
end;

procedure TProtocolBalanceFrame.SummaryGridKeyDown(Sender: TObject;
  var Key: word; Shift: TShiftState);
begin
  if (Key in [VK_RETURN, VK_SPACE]) and (Shift = []) then
  begin
    ApplySummaryFilter(SummaryGrid.SelectedColumn);
    Key := 0;
  end;
end;

function TProtocolBalanceFrame.NavigationReady: boolean;
begin
  Result := FHasSnapshot and not FUpdating and not FDirty and
    (FContext <> nil) and FContext.Connection.Connected;
end;

procedure TProtocolBalanceFrame.NavigationActionUpdate(Sender: TObject);
begin
  if Sender = OpenCardAction then
    TAction(Sender).Enabled :=
      NavigationReady and not DetailsData.IsEmpty and Assigned(FOnOpenCard)
  else if Sender = OpenParticipantAction then
    TAction(Sender).Enabled :=
      NavigationReady and not DetailsData.IsEmpty and Assigned(FOnOpenParticipant)
  else
    TAction(Sender).Enabled :=
      NavigationReady and (SelectedStagePosition >= 0) and Assigned(FOnOpenJournal);
end;

procedure TProtocolBalanceFrame.OpenCardActionExecute(Sender: TObject);
var
  StagePos: integer;
begin
  if not NavigationReady or DetailsData.IsEmpty or not Assigned(FOnOpenCard) then Exit;
  StagePos := SelectedStagePosition;
  if StagePos >= 0 then FOnOpenCard(Self, DetailsData.FieldByName(
      'participant_id').AsInteger,
      FSnapshot.Stages[StagePos].StageIndex);
end;

procedure TProtocolBalanceFrame.OpenParticipantActionExecute(Sender: TObject);
var
  Position: integer;
begin
  if not NavigationReady or DetailsData.IsEmpty or not
    Assigned(FOnOpenParticipant) then Exit;
  Position := SelectedStagePosition;
  if Position >= 0 then
    FOnOpenParticipant(Self, DetailsData.FieldByName('participant_id').AsInteger,
      FSnapshot.Stages[Position].StageIndex);
end;

procedure TProtocolBalanceFrame.DetailsGridDblClick(Sender: TObject);
begin
  OpenParticipantAction.Execute;
end;

procedure TProtocolBalanceFrame.DetailsGridKeyDown(Sender: TObject;
  var Key: word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    OpenParticipantAction.Execute;
  end;
end;

procedure TProtocolBalanceFrame.OpenJournalActionExecute(Sender: TObject);
var
  Position: integer;
  Kind: TProtocolBalanceJournalKind;
begin
  if not NavigationReady or not Assigned(FOnOpenJournal) then Exit;
  Position := SelectedStagePosition;
  if Position < 0 then Exit;
  if Sender = OpenPendingStartsAction then Kind := pbjkPendingStarts
  else if Sender = OpenPendingFinishesAction then Kind := pbjkPendingFinishes
  else if Sender = OpenStartErrorsAction then Kind := pbjkStartErrors
  else if Sender = OpenFinishErrorsAction then Kind := pbjkFinishErrors
  else
    Exit;
  FOnOpenJournal(Self, FSnapshot.Stages[Position].StageIndex, Kind);
end;

initialization
  RegisterClass(TMemDataset);
  RegisterClass(TProtocolBalanceFrame);

end.
