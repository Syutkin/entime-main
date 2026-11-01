unit ResultsImportPreview;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Grids,
  CompetitionDbContext, StageModel, CompetitionImportService,
  ResultsImportComparison, ResultsImportPreviewService;

type
  TImportBackupDecision = function(
    out ACreated, AContinueWithoutBackup: boolean): boolean of object;

  TVisibleImportRow = record
    Participant: integer;
    Field: TImportField;
  end;

  TResultsImportPreviewForm = class(TForm)
    HeaderPanel: TPanel;
    FileLabel, StageLabel, SummaryLabel: TLabel;
    Pages: TPageControl;
    ChangesPage, UnknownPage: TTabSheet;
    FilterPanel, CommandsPanel, NewCommandsPanel, FooterPanel: TPanel;
    FilterComboBox: TComboBox;
    ShowSameCheckBox: TCheckBox;
    ChangesGrid, UnknownGrid: TStringGrid;
    SelectAllButton, ClearSelectionButton, RefreshButton, ConfirmAllButton: TButton;
    ApplyButton, CancelButton: TButton;
    StateLabel, SelectionLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FilterChange(Sender: TObject);
    procedure SelectionCommand(Sender: TObject);
    procedure ChangesToggled(Sender: TObject; ACol, ARow: integer;
      AState: TCheckboxState);
    procedure UnknownToggled(Sender: TObject; ACol, ARow: integer;
      AState: TCheckboxState);
    procedure ChangesHeaderClick(Sender: TObject; IsColumn: boolean; Index: integer);
    procedure GridKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure RefreshClick(Sender: TObject);
    procedure ApplyClick(Sender: TObject);
  private
    FPlan: TResultsImportPlan;
    FContext: TCompetitionDbContext;
    FStages: TStages;
    FComparison: TResultsImportComparison;
    FRows: array of TVisibleImportRow;
    FUnknown: array of integer;
    FRendering, FApplying, FDescending: boolean;
    FSortColumn: integer;
    FNotice: string;
    FLastError: string;
    FOutcome: TImportApplyOutcome;
    FOnBackup: TImportBackupDecision;
    function CellText(const P: TImportParticipant; const Field: TImportField;
      const Col: integer): string;
    function ValidSession: boolean;
    procedure UpdateStageCaption;
    procedure Render;
    procedure Rebuild;
  public
    procedure Configure(const APlan: TResultsImportPlan;
      const AContext: TCompetitionDbContext; const AStages: TStages;
      const AStageIndex: integer; const AFileName: string);
    property Comparison: TResultsImportComparison read FComparison;
    property Outcome: TImportApplyOutcome read FOutcome;
    property LastError: string read FLastError;
    property OnPrepareBackup: TImportBackupDecision read FOnBackup write FOnBackup;
  end;

implementation

uses Types, LCLType, ParticipantStatus, AppLogger, i18n;
  {$R *.lfm}

procedure TResultsImportPreviewForm.FormCreate(Sender: TObject);
begin
  Caption := rsImportPreview;
  ChangesPage.Caption := rsImportPreviewChanges;
  UnknownPage.Caption := rsImportPreviewUnknown;
  SelectAllButton.Caption := rsImportPreviewSelectAll;
  ClearSelectionButton.Caption := rsImportPreviewClearSelection;
  SelectAllButton.Hint := rsImportPreviewSelectAllHint;
  ClearSelectionButton.Hint := rsImportPreviewClearHint;
  RefreshButton.Caption := rsImportPreviewRefresh;
  RefreshButton.Hint := rsImportPreviewRefreshHint;
  ConfirmAllButton.Caption := rsImportPreviewConfirmAll;
  ApplyButton.Caption := rsImportPreviewApply;
  CancelButton.Caption := rsImportPreviewCancel;
  ShowSameCheckBox.Caption := rsImportPreviewShowSame;
  FilterComboBox.Items.Add(rsImportPreviewAll);
  FilterComboBox.Items.Add(rsImportPreviewFill);
  FilterComboBox.Items.Add(rsImportPreviewReplace);
  FilterComboBox.Items.Add(rsImportPreviewClear);
  FilterComboBox.ItemIndex := 0;
  ChangesGrid.Columns[0].Title.Caption := rsImportPreviewSelect;
  ChangesGrid.Columns[1].Title.Caption := rsNumber;
  ChangesGrid.Columns[2].Title.Caption := rsName;
  ChangesGrid.Columns[3].Title.Caption := rsImportPreviewField;
  ChangesGrid.Columns[4].Title.Caption := rsImportPreviewCurrent;
  ChangesGrid.Columns[5].Title.Caption := rsImportPreviewProposed;
  ChangesGrid.Columns[6].Title.Caption := rsImportPreviewAction;
  ChangesGrid.Columns[7].Title.Caption := rsImportPreviewSourceRow;
  UnknownGrid.Columns[0].Title.Caption := rsImportPreviewCreate;
  UnknownGrid.Columns[1].Title.Caption := rsNumber;
  UnknownGrid.Columns[2].Title.Caption := rsImportPreviewSourceRow;
  FSortColumn := 1;
  FOutcome.State := iasNoChanges;
end;

procedure TResultsImportPreviewForm.FormDestroy(Sender: TObject);
begin
  Application.RemoveAsyncCalls(Self);
  FComparison.Free;
end;

procedure TResultsImportPreviewForm.FormCloseQuery(Sender: TObject;
  var CanClose: boolean);
begin
  CanClose := not FApplying;
end;

procedure TResultsImportPreviewForm.Configure(const APlan: TResultsImportPlan;
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const AStageIndex: integer; const AFileName: string);
begin
  FPlan := APlan;
  FContext := AContext;
  FStages := AStages;
  FreeAndNil(FComparison);
  FComparison := TResultsImportPreviewService.Build(FPlan, FContext,
    FStages, AStageIndex);
  FileLabel.Caption := Format(rsImportPreviewFile, [AFileName]);
  UpdateStageCaption;
  Render;
end;

procedure TResultsImportPreviewForm.UpdateStageCaption;
var
  FormatName: string;
begin
  case FPlan.ImportFormat of
    crifFinish: FormatName := rsImportPreviewFinishFormat;
    crifStart: FormatName := rsImportPreviewStartFormat;
    else
      FormatName := rsImportPreviewFullFormat;
  end;
  StageLabel.Caption := Format(rsImportPreviewStage,
    [FComparison.StageIndex, FStages[FComparison.StageIndex].Name, FormatName]);
end;

function TResultsImportPreviewForm.ValidSession: boolean;
begin
  Result := (FComparison <> nil) and (FContext <> nil) and
    FContext.Connection.Connected and (FComparison.ContextIdentity =
    FContext.Identity) and (FComparison.SessionGeneration =
    FContext.SessionGeneration) and (FStages <> nil) and
    FStages.IsActiveIndex(FComparison.StageIndex);
end;

function DisplayValue(const Value: TImportValue; const Field: TImportField): string;
var
  Status: TParticipantStatus;
begin
  if Value.Empty(Field) then Exit('—');
  if (Field = ifStatus) and TryParticipantStatusFromDbValue(Value.Text, Status) then
    Exit(ParticipantStatusToToken(Status));
  Result := Value.Text;
end;

function FieldCaption(const Field: TImportField): string;
begin
  case Field of
    ifStart: Result := rsStarttime;
    ifCorrection: Result := rsCorrection;
    ifFinish: Result := rsFinishtime;
    ifPenalty: Result := rsPenalty;
    ifStatus: Result := rsStatus;
  end;
end;

function ChangeCaption(const Kind: TImportChangeKind): string;
begin
  case Kind of
    ickSame: Result := rsImportPreviewSame;
    ickFill: Result := rsImportPreviewFill;
    ickReplace: Result := rsImportPreviewReplace;
    ickClear: Result := rsImportPreviewClear;
  end;
end;

function TResultsImportPreviewForm.CellText(const P: TImportParticipant;
  const Field: TImportField; const Col: integer): string;
begin
  case Col of
    0: if Field in P.Selected then Result := '1'
      else
        Result := '0';
    1: Result := IntToStr(P.Number);
    2: Result := P.Name;
    3: Result := FieldCaption(Field);
    4: Result := DisplayValue(P.Current[Field], Field);
    5: Result := DisplayValue(P.Proposed[Field], Field);
    6: Result := ChangeCaption(P.Kind(Field));
    7: Result := IntToStr(P.SourceRow);
    else
      Result := '';
  end;
end;

procedure TResultsImportPreviewForm.Render;
var
  List: TStringList;
  I, J, K, Code, OldCode, UnknownCount: integer;
  P: TImportParticipant;
  Field: TImportField;
  Key: string;
  Kind: TImportChangeKind;
begin
  if FRendering or (FComparison = nil) then Exit;
  OldCode := -1;
  if (ChangesGrid.Row > 0) and (ChangesGrid.Row <= Length(FRows)) then
    OldCode := FRows[ChangesGrid.Row - 1].Participant * 5 +
      Ord(FRows[ChangesGrid.Row - 1].Field);
  FRendering := True;
  List := TStringList.Create;
  ChangesGrid.BeginUpdate;
  UnknownGrid.BeginUpdate;
  try
    List.Sorted := True;
    List.Duplicates := dupAccept;
    UnknownCount := 0;
    SetLength(FUnknown, FComparison.Count);
    for I := 0 to FComparison.Count - 1 do
    begin
      P := FComparison[I];
      if P.Id = 0 then
      begin
        FUnknown[UnknownCount] := I;
        Inc(UnknownCount);
      end;
      for Field in P.Fields do
      begin
        Kind := P.Kind(Field);
        if (Kind = ickSame) and not ShowSameCheckBox.Checked then Continue;
        if (FilterComboBox.ItemIndex > 0) and
          (Ord(Kind) <> FilterComboBox.ItemIndex) then
          Continue;
        Code := I * 5 + Ord(Field);
        if FSortColumn = 1 then Key := Format('%.10d', [P.Number])
        else if FSortColumn = 7 then Key := Format('%.10d', [P.SourceRow])
        else
          Key := UpperCase(CellText(P, Field, FSortColumn));
        List.AddObject(Key + Format('|%.10d', [Code]), TObject(PtrInt(Code)));
      end;
    end;
    SetLength(FUnknown, UnknownCount);
    SetLength(FRows, List.Count);
    ChangesGrid.Clean;
    if List.Count = 0 then ChangesGrid.RowCount := 2
    else
      ChangesGrid.RowCount := List.Count + 1;
    for J := 0 to List.Count - 1 do
    begin
      K := J;
      if FDescending then K := List.Count - 1 - J;
      Code := PtrInt(List.Objects[K]);
      FRows[J].Participant := Code div 5;
      FRows[J].Field := TImportField(Code mod 5);
      P := FComparison[FRows[J].Participant];
      for I := 0 to ChangesGrid.ColCount - 1 do
        ChangesGrid.Cells[I, J + 1] := CellText(P, FRows[J].Field, I);
      if Code = OldCode then ChangesGrid.Row := J + 1;
    end;
    UnknownGrid.Clean;
    if UnknownCount = 0 then UnknownGrid.RowCount := 2
    else
      UnknownGrid.RowCount := UnknownCount + 1;
    for I := 0 to UnknownCount - 1 do
    begin
      P := FComparison[FUnknown[I]];
      if P.CreateSelected then UnknownGrid.Cells[0, I + 1] := '1'
      else
        UnknownGrid.Cells[0, I + 1] := '0';
      UnknownGrid.Cells[1, I + 1] := IntToStr(P.Number);
      UnknownGrid.Cells[2, I + 1] := IntToStr(P.SourceRow);
    end;
    SummaryLabel.Caption := Format(rsImportPreviewSummary,
      [FComparison.ChangeCount(ickFill), FComparison.ChangeCount(ickReplace),
      FComparison.ChangeCount(ickClear), FComparison.ChangeCount(ickSame),
      UnknownCount]);
    SelectionLabel.Caption := Format(rsImportPreviewSelected,
      [FComparison.SelectedFieldCount, FComparison.SelectedParticipantCount,
      FComparison.CreationCount]);
    if FNotice <> '' then StateLabel.Caption := FNotice
    else if (List.Count = 0) and (UnknownCount = 0) then
      StateLabel.Caption := rsImportPreviewEmpty
    else
      StateLabel.Caption := rsImportPreviewReady;
    ApplyButton.Enabled := not FApplying and ValidSession and FComparison.HasSelection;
    CancelButton.Enabled := not FApplying;
    RefreshButton.Enabled := not FApplying and ValidSession;
    SelectAllButton.Enabled := not FApplying and ValidSession;
    ClearSelectionButton.Enabled := not FApplying;
    ConfirmAllButton.Enabled := not FApplying and ValidSession and (UnknownCount > 0);
    ChangesGrid.Enabled := not FApplying;
    UnknownGrid.Enabled := not FApplying;
  finally
    UnknownGrid.EndUpdate;
    ChangesGrid.EndUpdate;
    List.Free;
    FRendering := False;
  end;
end;

procedure TResultsImportPreviewForm.FilterChange(Sender: TObject);
begin
  Render;
end;

procedure TResultsImportPreviewForm.SelectionCommand(Sender: TObject);
var
  I: integer;
begin
  if FApplying or (FComparison = nil) then Exit;
  if Sender = SelectAllButton then FComparison.SelectAll
  else if Sender = ClearSelectionButton then FComparison.ClearSelection
  else if Sender = ConfirmAllButton then
    for I := 0 to FComparison.Count - 1 do
      if FComparison[I].Id = 0 then FComparison[I].ConfirmCreation(True);
  Render;
end;

procedure TResultsImportPreviewForm.ChangesToggled(Sender: TObject;
  ACol, ARow: integer; AState: TCheckboxState);
begin
  if FRendering or FApplying or (ACol <> 0) or (ARow < 1) or (ARow > Length(FRows)) then
    Exit;
  FComparison[FRows[ARow - 1].Participant].Select(FRows[ARow - 1].Field,
    AState = cbChecked);
  Render;
end;

procedure TResultsImportPreviewForm.UnknownToggled(Sender: TObject;
  ACol, ARow: integer; AState: TCheckboxState);
begin
  if FRendering or FApplying or (ACol <> 0) or (ARow < 1) or (ARow > Length(FUnknown))
  then Exit;
  FComparison[FUnknown[ARow - 1]].ConfirmCreation(AState = cbChecked);
  Render;
end;

procedure TResultsImportPreviewForm.ChangesHeaderClick(Sender: TObject;
  IsColumn: boolean; Index: integer);
begin
  if not IsColumn or (Index < 0) or (Index >= ChangesGrid.ColCount) then Exit;
  if FSortColumn = Index then FDescending := not FDescending
  else
  begin
    FSortColumn := Index;
    FDescending := False;
  end;
  Render;
end;

procedure TResultsImportPreviewForm.GridKeyDown(Sender: TObject;
  var Key: word; Shift: TShiftState);
var
  P: TImportParticipant;
  R: TVisibleImportRow;
begin
  if (Shift <> []) or FApplying then Exit;
  if Key = VK_RETURN then
  begin
    Key := 0;
    Exit;
  end;
  if Key <> VK_SPACE then Exit;
  Key := 0;
  if (Sender = ChangesGrid) and (ChangesGrid.Row > 0) and
    (ChangesGrid.Row <= Length(FRows)) then
  begin
    R := FRows[ChangesGrid.Row - 1];
    P := FComparison[R.Participant];
    P.Select(R.Field, not (R.Field in P.Selected));
  end
  else if (Sender = UnknownGrid) and (UnknownGrid.Row > 0) and
    (UnknownGrid.Row <= Length(FUnknown)) then
  begin
    P := FComparison[FUnknown[UnknownGrid.Row - 1]];
    P.ConfirmCreation(not P.CreateSelected);
  end;
  Render;
end;

procedure TResultsImportPreviewForm.Rebuild;
var
  Fresh: TResultsImportComparison;
begin
  if not ValidSession then
  begin
    FNotice := rsImportPreviewSessionChanged;
    Render;
    Exit;
  end;
  Fresh := TResultsImportPreviewService.Build(FPlan, FContext, FStages,
    FComparison.StageIndex);
  Fresh.RestoreSelection(FComparison);
  FComparison.Free;
  FComparison := Fresh;
  UpdateStageCaption;
  Render;
end;

procedure TResultsImportPreviewForm.RefreshClick(Sender: TObject);
begin
  try
    FNotice := '';
    FLastError := '';
    Rebuild;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FNotice := Format(rsImportPreviewError, [E.Message]);
      Render;
    end;
  end;
end;

procedure TResultsImportPreviewForm.ApplyClick(Sender: TObject);
var
  Created, ContinueWithoutBackup: boolean;
begin
  if FApplying or (FComparison = nil) or not FComparison.HasSelection then Exit;
  FApplying := True;
  FNotice := '';
  FLastError := '';
  Render;
  try
    try
      if not ValidSession then
      begin
        FNotice := rsImportPreviewSessionChanged;
        AppLog(FNotice, allWarning, alvDetails, alsImport);
        Exit;
      end;
      if not TResultsImportPreviewService.IsCurrent(FComparison,
        FPlan, FContext, FStages) then
      begin
        FNotice := rsImportPreviewStale;
        AppLog(FNotice, allWarning, alvDetails, alsImport);
        Rebuild;
        Exit;
      end;
      if not Assigned(FOnBackup) then
        raise EInvalidOperation.Create('Backup decision is not configured');
      Created := False;
      ContinueWithoutBackup := False;
      AppLog(Format(rsImportPreviewApplying, [FComparison.StageIndex,
        FComparison.SelectedFieldCount, FComparison.CreationCount]),
        allDebug, alvDetails, alsImport);
      if not FOnBackup(Created, ContinueWithoutBackup) then Exit;
      FOutcome := TResultsImportPreviewService.Apply(FComparison,
        FPlan, FContext, FStages, Created, ContinueWithoutBackup);
      if FOutcome.State = iasNeedsReview then
      begin
        FNotice := rsImportPreviewStale;
        AppLog(FNotice, allWarning, alvDetails, alsImport);
        Rebuild;
      end
      else if FOutcome.State = iasApplied then ModalResult := mrOk;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        FNotice := Format(rsImportPreviewError, [E.Message]);
        AppLog(FNotice, allError, alvDetails, alsImport);
      end;
    end;
  finally
    FApplying := False;
    Render;
  end;
end;

end.
