unit StartProtocolPrintForm;
{$mode objfpc}{$H+}
interface

uses Classes, StdCtrls, ExtCtrls, ProtocolPrintForm, ProtocolDocumentModel,
  CompetitionDbContext, StageModel, StartReportModel;

type
  TStartProtocolPrintForm = class(TProtocolPrintForm)
    SourcePanel, ModePanel, SingleStagePanel, OrderPanel, SortPanel: TPanel;
    ModeLabel, StartStageLabel, OrderLabel, SortStageLabel: TLabel;
    ModeCombo, StartStageCombo, OrderCombo, SortStageCombo: TComboBox;
    FitWidthCheck, TeamCheck: TCheckBox;
    procedure StartCreate(Sender: TObject);
    procedure SourceChange(Sender: TObject);
  protected
    FActive: TStageIndexArray;
    procedure ConfigureSource(PreferredStage: integer); override;
    function ReadProtocol(ReloadCategories: boolean): TProtocolReadOutcome; override;
    function DefaultFilePrefix: string; override;
    procedure UpdateSourceControls;
    function Options: TStartReportOptions;
  public
    procedure ConfigureStart(const Context: TCompetitionDbContext;
      const Stages: TStages; Mode: TStartReportMode; PreferredStage: integer;
      Language: TReportLanguage; const TemplateDirectory: string = '');
    function SelectedStage: integer; override;
  end;

implementation

uses SysUtils, i18n, StartReportService;
  {$R *.lfm}

procedure TStartProtocolPrintForm.StartCreate(Sender: TObject);
begin
  inherited FormCreate(Sender);
  Caption := rsStartPrintTitle;
  FitWidthCheck.Caption := rsStartFitWidth;
  TeamCheck.Caption := rsTeam;
  ModeLabel.Caption := rsStartMode;
  ModeCombo.Items.Add(rsPrintOverall);
  ModeCombo.Items.Add(rsStartSingleStage);
  ModeCombo.ItemIndex := 0;
  OrderLabel.Caption := rsStartOrder;
  OrderCombo.Items.Add(rsStartByTime);
  OrderCombo.Items.Add(rsStartByNumber);
  OrderCombo.ItemIndex := 0;
  StartStageLabel.Caption := rsSU;
  SortStageLabel.Caption := rsStartSortStage;
  IncompleteCheck.Caption := rsStartIncludeMissing;
  HeadingsCheck.Hint := rsStartHeadingsHint;
  HeaderCheck.Hint := rsStartHeaderHint;
  UpdateSourceControls;
end;

procedure TStartProtocolPrintForm.ConfigureStart(const Context: TCompetitionDbContext;
  const Stages: TStages; Mode: TStartReportMode; PreferredStage: integer;
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

procedure TStartProtocolPrintForm.ConfigureSource(PreferredStage: integer);
var
  I: integer;
  S: string;
  Info: TStartStageInfo;
begin
  FActive := FStages.ActiveIndices;
  StartStageCombo.Clear;
  StartStageCombo.Items.Add(rsStartEveryStage);
  SortStageCombo.Clear;
  for I := 0 to High(FActive) do
  begin
    Info := Default(TStartStageInfo);
    Info.Index := FActive[I];
    Info.Name := FStages[FActive[I]].Name;
    S := StartStageCaption(Info, FLanguage);
    StartStageCombo.Items.Add(S);
    SortStageCombo.Items.Add(S);
  end;
  if Length(FActive) > 0 then
  begin
    StartStageCombo.ItemIndex := 1;
    SortStageCombo.ItemIndex := 0;
    for I := 0 to High(FActive) do if FActive[I] = PreferredStage then
        StartStageCombo.ItemIndex := I + 1;
  end;
  UpdateSourceControls;
end;

procedure TStartProtocolPrintForm.UpdateSourceControls;
begin
  FitWidthCheck.Visible := ModeCombo.ItemIndex = Ord(srmAllStages);
  FitWidthCheck.Enabled := FitWidthCheck.Visible;
  SingleStagePanel.Visible := ModeCombo.ItemIndex = Ord(srmSingleStage);
  SortPanel.Visible := (ModeCombo.ItemIndex = Ord(srmAllStages)) and
    (OrderCombo.ItemIndex = Ord(sroTime));
  StartStageCombo.Enabled := SingleStagePanel.Visible;
  SortStageCombo.Enabled := SortPanel.Visible;
end;

procedure TStartProtocolPrintForm.SourceChange(Sender: TObject);
begin
  if FRendering then Exit;
  UpdateSourceControls;
  ParametersChange(Sender);
end;

function TStartProtocolPrintForm.SelectedStage: integer;
begin
  Result := 0;
  if (StartStageCombo.ItemIndex > 0) and (StartStageCombo.ItemIndex <=
    Length(FActive)) then
    Result := FActive[StartStageCombo.ItemIndex - 1];
end;

function TStartProtocolPrintForm.Options: TStartReportOptions;
begin
  Result := DefaultStartReportOptions;
  Result.View := ViewOptions;
  Result.FitToWidth := FitWidthCheck.Checked;
  Result.ShowTeam := TeamCheck.Checked;
  if ModeCombo.ItemIndex = 1 then Result.Mode := srmSingleStage;
  Result.AllSingleStages := (Result.Mode = srmSingleStage) and
    (StartStageCombo.ItemIndex = 0);
  if OrderCombo.ItemIndex = 1 then Result.Order := sroNumber;
  if (SortStageCombo.ItemIndex >= 0) and (SortStageCombo.ItemIndex <
    Length(FActive)) then
    Result.SortStageIndex := FActive[SortStageCombo.ItemIndex];
end;

function TStartProtocolPrintForm.ReadProtocol(ReloadCategories:
  boolean): TProtocolReadOutcome;
var
  O, Request: TStartReportOptions;
  R: TStartReportReadOutcome;
  D: TProtocolDocument;
begin
  UpdateSourceControls;
  O := Options;
  Request := O;
  Request.View.AllCategories := True;
  Request.View.IncludeMissing := True;
  Result := Default(TProtocolReadOutcome);
  D := nil;
  R := TStartReportService.Read(FContext, FStages, Request, Now, FIdentity, FGeneration);
  try
    Result.State := R.State;
    Result.ErrorText := R.ErrorText;
    if ReloadCategories and (R.State in [prsReady, prsEmpty]) then
    begin
      FRendering := True;
      try
        FillCategoryKeys(StartReportCategories(R.Rows), O.View);
      finally
        FRendering := False;
      end;
    end;
    if R.State <> prsReady then Exit;
    D := PrepareStartProtocol(R.Rows, R.Stages, O);
    D.RaceName := R.Snapshot.RaceName;
    D.FormedAt := R.Snapshot.FormedAt;
    D.ContextIdentity := R.Snapshot.ContextIdentity;
    D.SessionGeneration := R.Snapshot.SessionGeneration;
    D.StageSignature := R.Snapshot.StageSignature;
    if Length(D.Rows) = 0 then
    begin
      Result.State := prsEmpty;
      Exit;
    end;
    Result.Snapshot := D;
    D := nil;
  finally
    D.Free;
    R.Snapshot.Free;
  end;
end;

function TStartProtocolPrintForm.DefaultFilePrefix: string;
begin
  Result := 'start-overall';
  if ModeCombo.ItemIndex = 1 then
  begin
    Result := 'start-all-SU';
    if SelectedStage > 0 then Result := 'start-SU-' + IntToStr(SelectedStage);
  end;
end;

end.
