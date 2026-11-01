unit ParticipantCardForm;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Grids,
  ActnList, ParticipantCardModel;

type
  TCardJournalEvent = procedure(Sender: TObject; const Key: TCardMarkKey) of object;
  TCardParticipantEvent = procedure(Sender: TObject;
    const ParticipantId, StageIndex: integer) of object;

  TParticipantCardForm = class(TForm)
    HeaderPanel, FooterPanel, StagePanel, MarksPanel, MarksHeaderPanel: TPanel;
    TitleLabel, MetaLabel, SummaryLabel, StateLabel, MarksLabel,
    ScopeNoticeLabel: TLabel;
    Pages: TPageControl;
    ResultsPage, PersonalPage: TTabSheet;
    StagesGrid, MarksGrid: TStringGrid;
    StageSplitter: TSplitter;
    ScopeComboBox: TComboBox;
    DetailMemo, PersonalMemo: TMemo;
    JournalButton, ParticipantButton, RefreshButton, CloseButton: TButton;
    Actions: TActionList;
    JournalAction, ParticipantAction, RefreshAction, CloseAction: TAction;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure StageSelect(Sender: TObject; ACol, ARow: integer; var CanSelect: boolean);
    procedure MarkSelect(Sender: TObject; ACol, ARow: integer; var CanSelect: boolean);
    procedure ScopeChange(Sender: TObject);
    procedure MarkDblClick(Sender: TObject);
    procedure MarkClick(Sender: TObject);
    procedure MarkKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure CommandExecute(Sender: TObject);
  private
    FSnapshot: TParticipantCardSnapshot;
    FSelectedStage: integer;
    FSelectedMark: TCardMarkKey;
    FMarkRows: array of integer;
    FRendering, FUsable: boolean;
    FOnRefresh: TNotifyEvent;
    FOnJournal: TCardJournalEvent;
    FOnParticipant: TCardParticipantEvent;
    function GetSelectedMark: TCardMarkKey;
    function GetVisibleMarkCount: integer;
    function StageText(const Index: integer): string;
    procedure RenderMarks(const RestoreKey: TCardMarkKey);
    procedure RenderDetail(const Row: integer);
    procedure UpdateCommands;
  public
    procedure SetSnapshot(const ASnapshot: TParticipantCardSnapshot;
      const PreferredStage: integer = 0; const PreserveSelection: boolean = False);
    procedure SetUnavailable(const AMessage: string; const ClearSnapshot: boolean);
    procedure ClearMarkSelection(const AMessage: string);
    procedure UpdateTranslations;
    property Snapshot: TParticipantCardSnapshot read FSnapshot;
    property SelectedStage: integer read FSelectedStage;
    property SelectedMark: TCardMarkKey read GetSelectedMark;
    property VisibleMarkCount: integer read GetVisibleMarkCount;
    property OnRefresh: TNotifyEvent read FOnRefresh write FOnRefresh;
    property OnOpenJournal: TCardJournalEvent read FOnJournal write FOnJournal;
    property OnOpenParticipant: TCardParticipantEvent
      read FOnParticipant write FOnParticipant;
  end;

function CardValueText(const Value: TCardValue): string;

implementation

uses LCLType, StageFieldNames, ParticipantStatus, ProtocolBalance, TimingMark, i18n;
  {$R *.lfm}

function CardValueText(const Value: TCardValue): string;
begin
  if Value.Empty then Result := '—'
  else
    Result := Value.Text;
end;

function NonemptyText(const Value: string): string;
begin
  if Value = '' then Result := '—'
  else
    Result := Value;
end;

function ParticipantStatusText(const Value: TCardValue): string;
var
  Status: TParticipantStatus;
begin
  if not Value.Empty and TryParticipantStatusFromDbValue(Value.Text, Status) then
    Result := NonemptyText(ParticipantStatusToToken(Status))
  else
    Result := CardValueText(Value);
end;

function MarkStatusText(const Value: string): string;
begin
  case Value of
    'pending': Result := rsCardPending;
    'applied': Result := rsCardApplied;
    'hidden': Result := rsCardHidden;
    'conflict': Result := rsCardConflict;
    'error': Result := rsCardError;
    'ignored_debounce': Result := rsCardIgnored;
    else
      Result := NonemptyText(Value);
  end;
end;

function AssignmentText(const Value: string): string;
begin
  case Value of
    'manual': Result := rsCardManual;
    'automatic': Result := rsCardAutomatic;
    else
      Result := NonemptyText(Value);
  end;
end;

function StageReason(const Stage: TCardStage): string;
begin
  case Stage.Classification.Reason of
    pbrNone:
      case Stage.Classification.Group of
        pbgWithResult: Result := rsProtocolBalanceWithResult;
        pbgDNS: Result := 'DNS';
        pbgDNF: Result := 'DNF';
        pbgDSQ: Result := 'DSQ';
        else
          Result := '';
      end;
    pbrNoStageData: Result := rsProtocolBalanceNoStageData;
    pbrMissingFinish: Result := rsProtocolBalanceMissingFinish;
    pbrFinishWithoutStart: Result := rsProtocolBalanceFinishWithoutStart;
    pbrMissingOrInvalidResult: Result := rsProtocolBalanceMissingResult;
    pbrUnknownStageStatus: Result :=
        Format(rsProtocolBalanceUnknownStatus, [Stage.Values[sfkStatus].Text]);
  end;
end;

procedure TParticipantCardForm.FormCreate(Sender: TObject);
begin
  UpdateTranslations;
end;

procedure TParticipantCardForm.UpdateTranslations;
var
  SavedKey: TCardMarkKey;
  SavedScope: integer;
begin
  SavedKey := SelectedMark;
  SavedScope := ScopeComboBox.ItemIndex;
  FRendering := True;
  Caption := rsCardTitle;
  ResultsPage.Caption := rsCardResults;
  PersonalPage.Caption := rsCardPersonal;
  JournalAction.Caption := rsCardOpenJournal;
  ParticipantAction.Caption := rsCardGoParticipant;
  RefreshAction.Caption := rsCardRefresh;
  RefreshAction.Hint := rsCardRefreshHint;
  CloseAction.Caption := rsCardClose;
  ScopeNoticeLabel.Caption := rsCardNumberScope;
  ScopeComboBox.Items.Clear;
  ScopeComboBox.Items.Add(rsCardMarkScope);
  ScopeComboBox.Items.Add(rsCardAllStages);
  if SavedScope < 0 then SavedScope := 0;
  ScopeComboBox.ItemIndex := SavedScope;
  StagesGrid.Columns[0].Title.Caption := rsSU;
  StagesGrid.Columns[1].Title.Caption := rsStarttime;
  StagesGrid.Columns[2].Title.Caption := rsFinishtime;
  StagesGrid.Columns[3].Title.Caption := rsCorrection;
  StagesGrid.Columns[4].Title.Caption := rsPenalty;
  StagesGrid.Columns[5].Title.Caption := rsResult;
  StagesGrid.Columns[6].Title.Caption := rsPlace;
  StagesGrid.Columns[7].Title.Caption := rsDiffleader;
  StagesGrid.Columns[8].Title.Caption := rsStatus;
  StagesGrid.Columns[9].Title.Caption := rsProtocolBalanceState;
  MarksGrid.Columns[0].Title.Caption := rsCardMarkKind;
  MarksGrid.Columns[1].Title.Caption := rsSU;
  MarksGrid.Columns[2].Title.Caption := rsTime;
  MarksGrid.Columns[3].Title.Caption := rsCorrection;
  MarksGrid.Columns[4].Title.Caption := rsTransport;
  MarksGrid.Columns[5].Title.Caption := rsStatus;
  MarksGrid.Columns[6].Title.Caption := rsAssignmentMode;
  StateLabel.Caption := rsCardSaved;
  FRendering := False;
  if FSnapshot <> nil then RenderMarks(SavedKey);
  UpdateCommands;
end;

procedure TParticipantCardForm.FormDestroy(Sender: TObject);
begin
  FSnapshot.Free;
end;

function TParticipantCardForm.StageText(const Index: integer): string;
var
  StagePos: integer;
begin
  StagePos := -1;
  if FSnapshot <> nil then StagePos := FSnapshot.StagePosition(Index);
  if StagePos < 0 then Exit(Format(rsCardStageOutside, [Index]));
  Result := IntToStr(Index) + ' — ' + FSnapshot.Stages[StagePos].Name;
  if not FSnapshot.Stages[StagePos].Active then
    Result := Result + ' (' + rsCardInactive + ')';
end;

procedure TParticipantCardForm.SetSnapshot(const ASnapshot: TParticipantCardSnapshot;
  const PreferredStage: integer; const PreserveSelection: boolean);
const
  Fields: array[1..8] of TStageFieldKind = (sfkStartTime, sfkFinishTime,
    sfkCorrection, sfkPenalty, sfkResult, sfkPlace, sfkDiffLeader, sfkStatus);
var
  I, J, DesiredStage: integer;
  SavedKey: TCardMarkKey;
  S: TCardStage;

  procedure Personal(const LabelText: string; const Field: TCardParticipantField);
  begin
    PersonalMemo.Lines.Add(LabelText + ': ' + CardValueText(FSnapshot.Fields[Field]));
  end;

begin
  SavedKey := Default(TCardMarkKey);
  DesiredStage := PreferredStage;
  if PreserveSelection then
  begin
    SavedKey := SelectedMark;
    if DesiredStage = 0 then DesiredStage := FSelectedStage;
  end;
  FSnapshot.Free;
  FSnapshot := ASnapshot;
  FUsable := FSnapshot <> nil;
  if FSnapshot = nil then
  begin
    SetUnavailable('', True);
    Exit;
  end;
  FSelectedStage := FSnapshot.PreferredStage(DesiredStage);
  FRendering := True;
  StagesGrid.BeginUpdate;
  try
    TitleLabel.Caption := Format('№ %d — %s', [FSnapshot.Number,
      CardValueText(FSnapshot.Fields[cpfName])]);
    MetaLabel.Caption := rsCategory + ': ' +
      CardValueText(FSnapshot.Fields[cpfCategory]) + ' · ' + rsTeam +
      ': ' + CardValueText(FSnapshot.Fields[cpfTeam]) + ' · ' + rsCity +
      ': ' + CardValueText(FSnapshot.Fields[cpfCity]);
    SummaryLabel.Caption := rsSumresult + ': ' +
      CardValueText(FSnapshot.Fields[cpfSumResult]) + ' · ' + rsPlace +
      ': ' + CardValueText(FSnapshot.Fields[cpfSumPlace]) + ' · ' +
      rsDiffleader + ': ' + CardValueText(FSnapshot.Fields[cpfSumDiff]) +
      ' · ' + rsStatus + ': ' + ParticipantStatusText(FSnapshot.Fields[cpfStatus]);
    StagesGrid.RowCount := Length(FSnapshot.Stages) + 1;
    for I := 0 to High(FSnapshot.Stages) do
    begin
      S := FSnapshot.Stages[I];
      StagesGrid.Cells[0, I + 1] := StageText(S.Index);
      for J := 1 to 8 do StagesGrid.Cells[J, I + 1] := CardValueText(S.Values[Fields[J]]);
      StagesGrid.Cells[8, I + 1] := ParticipantStatusText(S.Values[sfkStatus]);
      StagesGrid.Cells[9, I + 1] := StageReason(S);
      if S.Index = FSelectedStage then StagesGrid.Row := I + 1;
    end;
    PersonalMemo.Clear;
    Personal(rsName, cpfName);
    Personal(rsCategory, cpfCategory);
    Personal('RFID', cpfRfid);
    Personal(rsNickname, cpfNickname);
    Personal(rsAge, cpfAge);
    Personal(rsTeam, cpfTeam);
    Personal(rsCity, cpfCity);
    Personal(rsCardPhone, cpfPhone);
    Personal(rsCardEmail, cpfEmail);
    Personal(rsCardComment, cpfComment);
    Personal(rsCardStageCount, cpfSumStages);
    Personal(rsCardThruPlace, cpfThruPlace);
    Personal(rsCardThruGap, cpfThruDiff);
    StateLabel.Caption := rsCardSaved;
  finally
    StagesGrid.EndUpdate;
    FRendering := False;
  end;
  RenderMarks(SavedKey);
  UpdateCommands;
end;

function TParticipantCardForm.GetSelectedMark: TCardMarkKey;
begin
  Result := FSelectedMark;
end;

function TParticipantCardForm.GetVisibleMarkCount: integer;
begin
  Result := Length(FMarkRows);
end;

procedure TParticipantCardForm.RenderMarks(const RestoreKey: TCardMarkKey);
var
  I, J, SelectedRow: integer;
  M: TCardMark;
begin
  FRendering := True;
  MarksGrid.BeginUpdate;
  try
    MarksGrid.Clean([gzNormal]);
    SetLength(FMarkRows, 0);
    SelectedRow := 0;
    if FSnapshot <> nil then
    begin
      MarksLabel.Caption := Format(rsCardMarks, [FSnapshot.Number]);
      SetLength(FMarkRows, Length(FSnapshot.Marks));
      J := 0;
      for I := 0 to High(FSnapshot.Marks) do
        if FSnapshot.Marks[I].MatchesStage(FSelectedStage,
          ScopeComboBox.ItemIndex = 1) then
        begin
          FMarkRows[J] := I;
          Inc(J);
        end;
      SetLength(FMarkRows, J);
    end;
    MarksGrid.RowCount := Length(FMarkRows) + 1;
    if MarksGrid.RowCount < 2 then MarksGrid.RowCount := 2;
    for I := 0 to High(FMarkRows) do
    begin
      M := FSnapshot.Marks[FMarkRows[I]];
      if M.Key.Kind = tmkStart then MarksGrid.Cells[0, I + 1] := rsStarttime
      else
        MarksGrid.Cells[0, I + 1] := rsFinishtime;
      MarksGrid.Cells[1, I + 1] := StageText(M.EffectiveStage);
      MarksGrid.Cells[2, I + 1] := NonemptyText(M.EventTime);
      MarksGrid.Cells[3, I + 1] := CardValueText(M.Correction);
      MarksGrid.Cells[4, I + 1] := NonemptyText(M.SourceKind);
      MarksGrid.Cells[5, I + 1] := MarkStatusText(M.Status);
      MarksGrid.Cells[6, I + 1] := AssignmentText(M.AssignmentMode);
      if M.Key.Equals(RestoreKey) then SelectedRow := I + 1;
    end;
    FSelectedMark := Default(TCardMarkKey);
    if (SelectedRow = 0) and (RestoreKey.Id = 0) and (Length(FMarkRows) > 0) then
      SelectedRow := 1;
    if SelectedRow > 0 then
    begin
      MarksGrid.Row := SelectedRow;
      FSelectedMark := FSnapshot.Marks[FMarkRows[SelectedRow - 1]].Key;
    end
    else
      MarksGrid.Row := 1;
    // A vanished selection is not replaced by a different record with the same id.

  finally
    MarksGrid.EndUpdate;
    FRendering := False;
  end;
  RenderDetail(SelectedRow);
  UpdateCommands;
end;

procedure TParticipantCardForm.RenderDetail(const Row: integer);
var
  M: TCardMark;
begin
  DetailMemo.Clear;
  if (FSnapshot = nil) or (Row < 1) or (Row > Length(FMarkRows)) then Exit;
  M := FSnapshot.Marks[FMarkRows[Row - 1]];
  DetailMemo.Lines.Add(rsId + ': ' + IntToStr(M.Key.Id) + ' · ' +
    rsDevice + ': ' + NonemptyText(M.DeviceId));
  DetailMemo.Lines.Add(rsReceivedStage + ': ' + StageText(M.ReceivedStage));
  if M.HasAppliedStage then DetailMemo.Lines.Add(rsAppliedStage +
      ': ' + StageText(M.AppliedStage));
  DetailMemo.Lines.Add(rsReceivedAt + ': ' + NonemptyText(M.ReceivedAt));
  DetailMemo.Lines.Add(rsAppliedAt + ': ' + NonemptyText(M.AppliedAt));
  DetailMemo.Lines.Add(rsDiagnostic + ': ' + NonemptyText(M.Diagnostic));
end;

procedure TParticipantCardForm.UpdateCommands;
begin
  JournalAction.Enabled := FUsable and (SelectedMark.Id > 0);
  ParticipantAction.Enabled := FUsable and (FSnapshot <> nil) and (FSelectedStage > 0);
end;

procedure TParticipantCardForm.ClearMarkSelection(const AMessage: string);
begin
  FSelectedMark := Default(TCardMarkKey);
  DetailMemo.Clear;
  StateLabel.Caption := AMessage;
  UpdateCommands;
end;

procedure TParticipantCardForm.SetUnavailable(const AMessage: string;
  const ClearSnapshot: boolean);
begin
  FUsable := False;
  StateLabel.Caption := AMessage;
  if ClearSnapshot then
  begin
    FreeAndNil(FSnapshot);
    FSelectedStage := 0;
    FSelectedMark := Default(TCardMarkKey);
    SetLength(FMarkRows, 0);
    TitleLabel.Caption := rsCardTitle;
    MetaLabel.Caption := '';
    SummaryLabel.Caption := '';
    StagesGrid.Clean([gzNormal]);
    StagesGrid.RowCount := 2;
    MarksGrid.Clean([gzNormal]);
    MarksGrid.RowCount := 2;
    DetailMemo.Clear;
    PersonalMemo.Clear;
    MarksLabel.Caption := '';
  end;
  UpdateCommands;
end;

procedure TParticipantCardForm.StageSelect(Sender: TObject; ACol, ARow: integer;
  var CanSelect: boolean);
begin
  if FRendering or (FSnapshot = nil) or (ARow < 1) or (ARow > Length(FSnapshot.Stages))
  then Exit;
  FSelectedStage := FSnapshot.Stages[ARow - 1].Index;
  RenderMarks(Default(TCardMarkKey));
end;

procedure TParticipantCardForm.MarkSelect(Sender: TObject; ACol, ARow: integer;
  var CanSelect: boolean);
begin
  if FRendering then Exit;
  if (FSnapshot <> nil) and (ARow > 0) and (ARow <= Length(FMarkRows)) then
    FSelectedMark := FSnapshot.Marks[FMarkRows[ARow - 1]].Key
  else
    FSelectedMark := Default(TCardMarkKey);
  RenderDetail(ARow);
  UpdateCommands;
end;

procedure TParticipantCardForm.MarkClick(Sender: TObject);
var
  CanSelect: boolean;
begin
  CanSelect := True;
  MarkSelect(Sender, 0, MarksGrid.Row, CanSelect);
end;

procedure TParticipantCardForm.ScopeChange(Sender: TObject);
begin
  if not FRendering then RenderMarks(Default(TCardMarkKey));
end;

procedure TParticipantCardForm.CommandExecute(Sender: TObject);
begin
  if Sender = CloseAction then Close
  else if Sender = RefreshAction then
  begin
    if Assigned(FOnRefresh) then FOnRefresh(Self);
  end
  else if (Sender = JournalAction) and JournalAction.Enabled and
    Assigned(FOnJournal) then
    FOnJournal(Self, SelectedMark)
  else if (Sender = ParticipantAction) and ParticipantAction.Enabled and
    Assigned(FOnParticipant) then
    FOnParticipant(Self, FSnapshot.ParticipantId, FSelectedStage);
end;

procedure TParticipantCardForm.MarkDblClick(Sender: TObject);
begin
  UpdateCommands;
  JournalAction.Execute;
end;

procedure TParticipantCardForm.MarkKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    MarkDblClick(Sender);
  end;
end;

procedure TParticipantCardForm.FormKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Key := 0;
    Close;
  end;
end;

end.
