unit FinishProtocolPrintForm;
{$mode objfpc}{$H+}
interface

uses Classes, StdCtrls, ExtCtrls, ProtocolPrintForm, ProtocolDocumentModel,
  StageFinishReportModel, CompetitionDbContext, StageModel;

type
  TFinishReportMode = (frmOverall, frmSingleStage);

  TFinishProtocolPrintForm = class(TProtocolPrintForm)
    SourcePanel, ModePanel, SingleStagePanel, OptionsPanel, DetailsPanel: TPanel;
    ModeLabel, SelectStageLabel: TLabel;
    ModeCombo, SelectStageCombo: TComboBox;
    PenaltyCheck, DetailedCheck, StagePlacesCheck, StageGapsCheck,
    StagePenaltyCheck, FitWidthCheck: TCheckBox;
    procedure FinishCreate(Sender: TObject);
    procedure SourceChange(Sender: TObject);
  protected
    FSnapshot: TStageReportSnapshot;
    function Options: TStageReportOptions;
    procedure UpdateSourceControls;
    function ReadSingleProtocol(ReloadCategories: boolean): TProtocolReadOutcome;
    function ReadOverallProtocol(ReloadCategories: boolean): TProtocolReadOutcome;
    procedure FillCategories(const Rows: TStageReportRows;
      const Selection: TStageReportOptions);
    procedure ConfigureSource(PreferredStage: integer); override;
    procedure ClearSource; override;
    procedure ProtocolTemplatePrepared(D: TProtocolDocument); override;
    function ReadProtocol(ReloadCategories: boolean): TProtocolReadOutcome; override;
    function DefaultFilePrefix: string; override;
  public
    procedure ConfigureFinish(const Context: TCompetitionDbContext;
      const Stages: TStages; Mode: TFinishReportMode; PreferredStage: integer;
      Language: TReportLanguage; const TemplateDirectory: string = '');
    function SelectedStage: integer; override;
    property Snapshot: TStageReportSnapshot read FSnapshot;
  end;

implementation

uses SysUtils, i18n, StageFinishReportService, OverallFinishReportModel,
  OverallFinishReportService;
  {$R *.lfm}

procedure TFinishProtocolPrintForm.FinishCreate(Sender: TObject);
begin
  inherited FormCreate(Sender);
  Caption := rsFinishProtocol;
  ModeLabel.Caption := rsPrintMode;
  ModeCombo.Items.Add(rsPrintOverall);
  ModeCombo.Items.Add(rsPrintSingleStage);
  ModeCombo.ItemIndex := 0;
  SelectStageLabel.Caption := rsSU;
  PenaltyCheck.Caption := rsPrintPenalty;
  IncompleteCheck.Caption := rsPrintIncomplete;
  DetailedCheck.Caption := rsOverallStageResults;
  StagePlacesCheck.Caption := rsOverallStagePlaces;
  StageGapsCheck.Caption := rsOverallStageGaps;
  StagePenaltyCheck.Caption := rsOverallStagePenalties;
  FitWidthCheck.Caption := rsStartFitWidth;
  UpdateSourceControls;
end;

procedure TFinishProtocolPrintForm.ConfigureFinish(const Context: TCompetitionDbContext;
  const Stages: TStages; Mode: TFinishReportMode; PreferredStage: integer;
  Language: TReportLanguage; const TemplateDirectory: string);
begin
  FRendering := True;
  try
    ModeCombo.ItemIndex := Ord(Mode);
  finally
    FRendering := False;
  end;
  inherited Configure(Context, Stages, PreferredStage, Language, TemplateDirectory);
end;

procedure TFinishProtocolPrintForm.UpdateSourceControls;
var
  single: boolean;
begin
  single := ModeCombo.ItemIndex = Ord(frmSingleStage);
  SingleStagePanel.Visible := single;
  SelectStageCombo.Enabled := single;
  FitWidthCheck.Visible := not single;
  FitWidthCheck.Enabled := not single;
  PenaltyCheck.Visible := single;
  PenaltyCheck.Enabled := single;
  DetailsPanel.Visible := not single;
  DetailedCheck.Enabled := not single;
  StagePlacesCheck.Enabled := not single and DetailedCheck.Checked;
  StageGapsCheck.Enabled := StagePlacesCheck.Enabled;
  StagePenaltyCheck.Enabled := StagePlacesCheck.Enabled;
  if single then
  begin
    HeadingsCheck.Hint := rsPrintHeadingsHint;
    HeaderCheck.Hint := rsPrintHeaderHint;
  end
  else
  begin
    HeadingsCheck.Hint := rsOverallHeadingsHint;
    HeaderCheck.Hint := rsOverallHeaderHint;
  end;
end;

procedure TFinishProtocolPrintForm.SourceChange(Sender: TObject);
begin
  if FRendering then Exit;
  UpdateSourceControls;
  ParametersChange(Sender);
end;

function TFinishProtocolPrintForm.SelectedStage: integer;
begin
  Result := SelectStageCombo.ItemIndex + 1;
end;

procedure TFinishProtocolPrintForm.ConfigureSource(PreferredStage: integer);
var
  I: integer;
  S: string;
begin
  SelectStageCombo.Items.Clear;
  for I := 1 to FStages.Count do
  begin
    S := Format(rsSUFormat, [I]) + ' — ' + FStages[I].Name;
    if not FStages[I].isActive then S := S + ' (' + rsCardInactive + ')';
    SelectStageCombo.Items.Add(S);
  end;
  SelectStageCombo.ItemIndex := DefaultReportStage(FStages, PreferredStage) - 1;
  UpdateSourceControls;
end;

procedure TFinishProtocolPrintForm.ClearSource;
begin
  FreeAndNil(FSnapshot);
end;

procedure TFinishProtocolPrintForm.ProtocolTemplatePrepared(D: TProtocolDocument);
begin
  if FSnapshot <> nil then FSnapshot.Template := D.Template;
end;

function TFinishProtocolPrintForm.Options: TStageReportOptions;
var
  V: TProtocolViewOptions;
begin
  V := ViewOptions;
  Result := DefaultReportOptions;
  Result.StageIndex := V.StageIndex;
  Result.AllCategories := V.AllCategories;
  Result.Categories := Copy(V.Categories);
  Result.IncludeIncomplete := V.IncludeMissing;
  Result.Language := V.Language;
  Result.Orientation := V.Orientation;
  Result.ShowHeadings := V.ShowHeadings;
  Result.ShowHeader := V.ShowHeader;
  Result.ShowFooter := V.ShowFooter;
  Result.ShowPenalty := PenaltyCheck.Checked;
end;

procedure TFinishProtocolPrintForm.FillCategories(const Rows: TStageReportRows;
  const Selection: TStageReportOptions);
var
  V: TProtocolViewOptions;
begin
  V := ViewOptions;
  V.AllCategories := Selection.AllCategories;
  V.Categories := Copy(Selection.Categories);
  FillCategoryKeys(ReportCategories(Rows), V);
end;

function TFinishProtocolPrintForm.ReadSingleProtocol(ReloadCategories: boolean):
TProtocolReadOutcome;
var
  R: TStageReportReadOutcome;
  O, ReadOptions: TStageReportOptions;
begin
  O := Options;
  Result := Default(TProtocolReadOutcome);
  ReadOptions := O;
  ReadOptions.AllCategories := True;
  ReadOptions.IncludeIncomplete := True;
  R := TStageFinishReportService.Read(FContext, FStages, ReadOptions,
    Now, FIdentity, FGeneration);
  try
    Result.State := R.State;
    Result.ErrorText := R.ErrorText;
    if ReloadCategories and (R.State in [srrReady, srrEmpty]) then
    begin
      FRendering := True;
      try
        if R.State = srrReady then FillCategories(R.Snapshot.Rows, O)
        else
          FillCategories(nil, O);
      finally
        FRendering := False;
      end;
    end;
    if R.State <> srrReady then Exit;
    R.Snapshot.Options := O;
    R.Snapshot.Rows := SelectReportRows(R.Snapshot.Rows, O);
    if Length(R.Snapshot.Rows) = 0 then
    begin
      Result.State := srrEmpty;
      Exit;
    end;
    Result.Snapshot := StageProtocolDocument(R.Snapshot);
    FSnapshot := R.Snapshot;
    R.Snapshot := nil;
  finally
    R.Snapshot.Free;
  end;
end;

function TFinishProtocolPrintForm.ReadProtocol(ReloadCategories:
  boolean): TProtocolReadOutcome;
begin
  UpdateSourceControls;
  if ModeCombo.ItemIndex = Ord(frmSingleStage) then
    Result := ReadSingleProtocol(ReloadCategories)
  else
    Result := ReadOverallProtocol(ReloadCategories);
end;

function TFinishProtocolPrintForm.DefaultFilePrefix: string;
begin
  Result := 'finish-overall';
  if ModeCombo.ItemIndex = Ord(frmSingleStage) then
    Result := 'finish-SU-' + IntToStr(SelectedStage);
end;

function TFinishProtocolPrintForm.ReadOverallProtocol(ReloadCategories: boolean):
TProtocolReadOutcome;
var
  O: TStageReportOptions;
  V: TProtocolViewOptions;
  R: TOverallReportReadOutcome;
  Request: TOverallReportOptions;
  D: TProtocolDocument;
begin
  O := Options;
  Result := Default(TProtocolReadOutcome);
  D := nil;
  Request := DefaultOverallReportOptions;
  Request.Display := O;
  Request.Detailed := DetailedCheck.Checked;
  Request.StagePlaces := StagePlacesCheck.Checked;
  Request.StageGaps := StageGapsCheck.Checked;
  Request.StagePenalties := StagePenaltyCheck.Checked;
  Request.FitToWidth := FitWidthCheck.Checked;
  Request.Display.AllCategories := True;
  Request.Display.IncludeIncomplete := True;
  R := TOverallFinishReportService.Read(FContext, FStages, Request,
    Now, FIdentity, FGeneration);
  try
    case R.State of
      orrReady: Result.State := srrReady;
      orrEmpty: Result.State := srrEmpty;
      orrBusy: Result.State := srrBusy;
      orrSessionChanged: Result.State := srrSessionChanged;
      orrNoStages: Result.State := prsNoStages;
      orrError: Result.State := srrError;
    end;
    Result.ErrorText := R.ErrorText;
    if ReloadCategories and (R.State in [orrReady, orrEmpty]) then
    begin
      FRendering := True;
      try
        V := ViewOptions;
        FillCategoryKeys(OverallCategories(R.Rows), V);
      finally
        FRendering := False;
      end;
    end;
    if R.State <> orrReady then Exit;
    Request.Display := O;
    D := PrepareOverallProtocol(R.Rows, R.Stages, Request);
    D.RaceName := R.Snapshot.RaceName;
    D.FormedAt := R.Snapshot.FormedAt;
    D.ContextIdentity := R.Snapshot.ContextIdentity;
    D.SessionGeneration := R.Snapshot.SessionGeneration;
    D.StageSignature := R.Snapshot.StageSignature;
    if Length(D.Rows) = 0 then
    begin
      Result.State := srrEmpty;
      Exit;
    end;
    Result.Snapshot := D;
    D := nil;
  finally
    D.Free;
    R.Snapshot.Free;
  end;
end;

end.
