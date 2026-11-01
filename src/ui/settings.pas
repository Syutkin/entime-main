unit Settings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  i18n, rxspin, LCLTranslator, Buttons, DBCtrls, ButtonPanel, ComCtrls, Spin,
  LazSerial, SerialSelector, DividerBevel, CheckBoxThemed,
  rxdbgrid, StageSettingsFrame, LazBleTypes, TimingTransport, HttpTransport,
  TelegramNotificationCoordinator;

type

  TStageSettingsDraft = record
    Name: string;
    Active: boolean;
  end;

  TStageSettingsDraftArray = array of TStageSettingsDraft;
  TStageSettingsFrameArray = array of TStageSettingsFrame;

  TSettingsChangeSet = record
    StageCountChanged: boolean;
    StageActivityChanged: boolean;
    StageNamesChanged: boolean;
    ResultParametersChanged: boolean;
    PresentationChanged: boolean;
    EquipmentChanged: boolean;
    ApplicationSettingsChanged: boolean;
    CompetitionDatabaseChanged: boolean;
    ResultViewQueriesChanged: boolean;
    StageUiChanged: boolean;
    SerialSettingsChanged: boolean;
    TimingInputSettingsChanged: boolean;
    ZeroHourChanged: boolean;
  end;

  { TSettingsForm }

  TSettingsForm = class(TForm)
    ActiveStageLabel: TLabel;
    ButtonLEDTest: TButton;
    ButtonSelectBleDevice: TButton;
    ButtonTelegramTest: TButton;
    ButtonPanel1: TButtonPanel;
    CheckBoxBackup: TCheckBox;
    CheckBoxStartMarkAutomaticApply: TCheckBox;
    CheckBoxUpdateAtStartup: TCheckBox;
    CheckBoxTelegramRetry: TCheckBox;
    CheckBoxHideZeroHour: TCheckBoxThemed;
    CheckBoxShowStageName: TCheckBoxThemed;
    ComboBoxAStage: TComboBox;
    ComboBoxUpdateInterval: TComboBox;
    ComboBoxLanguage: TComboBox;
    CompetitionContentPanel: TPanel;
    CompetitionScrollBox: TScrollBox;
    ComComboBox1: TSerialSelector;
    ComComboBox2: TComboBox;
    ComComboBox3: TComboBox;
    ComComboBox4: TComboBox;
    ComComboBox5: TComboBox;
    ComComboBox6: TComboBox;
    DelayEdit: TSpinEdit;
    DividerBevelCOMSettings1: TDividerBevel;
    DividerBevelBleSettings: TDividerBevel;
    DividerBevelTimingInputMode: TDividerBevel;
    DividerBevelStartMarkSettings: TDividerBevel;
    DividerBevelUpdate: TDividerBevel;
    DividerBackup: TDividerBevel;
    DividerBevelViewOther: TDividerBevel;
    DividerBevelLEDAdress: TDividerBevel;
    DividerBevelTelegramTest: TDividerBevel;
    DividerBevelTelegramBotAdress: TDividerBevel;
    DividerBevelLEDTest: TDividerBevel;
    Edit1: TComboBox;
    Edit2: TComboBox;
    Edit3: TComboBox;
    Edit4: TComboBox;
    Edit5: TComboBox;
    Edit6: TComboBox;
    LabelBackupMaxSizeMb: TLabel;
    LabelBackupMegabytes: TLabel;
    LabelBackupMinutes: TLabel;
    LabelBackupRetentionDays: TLabel;
    LabelBackupRetentionDaysUnit: TLabel;
    NameEdit: TEdit;
    GroupBoxName: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    LabelBleDevice: TLabel;
    LabelBleDeviceId: TLabel;
    LabelName: TLabel;
    LabelSingleline: TLabel;
    LabelCategory: TLabel;
    LabelResult: TLabel;
    LabelDiff: TLabel;
    LabelPlace: TLabel;
    LabelUpperline: TLabel;
    LabelBottomline: TLabel;
    LabelNumber: TLabel;
    LabelTelegramRetryCount: TLabel;
    LabelTelegramRetryDelay: TLabel;
    LeftPanel: TPanel;
    ActiveStagePanel: TPanel;
    PanelBackup: TPanel;
    SpinBackup: TSpinEdit;
    SpinBackupMaxSizeMb: TSpinEdit;
    SpinBackupRetentionDays: TSpinEdit;
    SpinTelegramRetryCount: TSpinEdit;
    SpinTelegramRetryDelay: TSpinEdit;
    TelegramResult: TEdit;
    TelegramDiff: TEdit;
    TelegramPlace: TEdit;
    TelegramName: TEdit;
    TelegramCategory: TEdit;
    TelegramNumber: TEdit;
    PanelTelegramTest: TPanel;
    TelegramBotAdressEdit: TEdit;
    LEDUpperline: TEdit;
    LEDBottomline: TEdit;
    LEDSingleline: TEdit;
    Notebook1: TNotebook;
    Page1Commons: TPage;
    Page2View: TPage;
    Page3Competition: TPage;
    Page4TimingInput: TPage;
    PageTimingInputBle: TPage;
    PageTimingInputSerial: TPage;
    Page5LED: TPage;
    Page6Telegram: TPage;
    PanelLEDTest: TPanel;
    PanelComSettings: TPanel;
    PanelBleLabels: TPanel;
    PanelBleSettings: TPanel;
    PanelBleDeviceValue: TPanel;
    PanelBleValues: TPanel;
    TimingInputModePanel: TPanel;
    StartMarkSettingsPanel: TPanel;
    StartMarkMatchDeltaLabel: TLabel;
    StartMarkMatchDeltaSpin: TSpinEdit;
    DividerBevelLanguage1: TDividerBevel;
    DividerBevelDelay1: TDividerBevel;
    RadioButtonTimingInputBle: TRadioButton;
    RadioButtonTimingInputSerial: TRadioButton;
    GroupBoxCategory: TGroupBox;
    GroupBoxStages: TGroupBox;
    StageCountLabel: TLabel;
    StageCountPanel: TPanel;
    StageCountSpinEdit: TSpinEdit;
    StagesContentPanel: TPanel;
    LEDAdress: TEdit;
    BleDeviceIdEdit: TEdit;
    BleDeviceNameEdit: TEdit;
    TimingInputSettingsNotebook: TNotebook;
    TreeView1: TTreeView;
    procedure ButtonSelectBleDeviceClick(Sender: TObject);
    procedure ButtonLEDTestClick(Sender: TObject);
    procedure ButtonTelegramTestClick(Sender: TObject);
    procedure CheckBoxStartMarkAutomaticApplyChange(Sender: TObject);
    procedure CheckBoxTelegramRetryChange(Sender: TObject);
    procedure CheckBoxUpdateAtStartupChange(Sender: TObject);
    procedure ComboBoxAStageDropDown(Sender: TObject);
    procedure ComboBoxLanguageChange(Sender: TObject);
    procedure EditDropDown(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure Page2ViewBeforeShow(ASender: TObject; ANewPage: TPage; ANewIndex: integer);
    procedure RunSettings(ActivePage: integer = 0);
    procedure StageCountSpinEditChange(Sender: TObject);
    procedure TimingInputModeChanged(Sender: TObject);
    procedure TreeView1Change(Sender: TObject; Node: TTreeNode);
  private
    FStageDraft: TStageSettingsDraftArray;
    FStageRows: TStageSettingsFrameArray;
    FStageDraftCount: integer;
    FInitialStageCount: integer;
    FPhysicalStageCapacity: integer;
    FInitialLanguage: string;
    FReductionConfirmed: boolean;
    FUpdatingStageCount: boolean;
    FUpdatingStageRows: boolean;
    FInitialSerialDevice: string;
    FSelectedBleDevice: TBleDeviceInfo;
    FBleAvailability: TBleAvailability;
    FPreviousBleAvailabilityChanged: TBleAvailabilityEvent;
    procedure BleAvailabilityChanged(Sender: TObject;
      const AAvailability: TBleAvailability);
    procedure ApplyStageDraftToModel;
    procedure BuildStageRows;
    function DetectChanges(const AActiveStageIndex: integer): TSettingsChangeSet;
    function DraftActiveStageIndex: integer;
    function DraftActiveStagesCount: integer;
    function DraftFirstActiveStageIndex: integer;
    procedure InitializeStageDraft;
    procedure RebuildActiveStageItems(const APreferredStageIndex: integer);
    procedure RefreshTimingInputPanels;
    function SelectedSerialDevice: string;
    function SelectedTimingInputTransport: TTimingTransportKind;
    procedure SaveCompetitionSettingsToDatabase(const AActiveStageIndex: integer);
    procedure StageRowChange(Sender: TObject);
    procedure UpdateCollectionTranslations(AUpdateIntervalIndex: integer);
  protected
    function ExecuteBleDeviceSelection(out ADevice: TBleDeviceInfo): boolean;
      virtual;
    procedure ApplyTimingInputSettings;
  public
    destructor Destroy; override;
  end;

var
  SettingsForm: TSettingsForm;

implementation

uses Main, InputDialogs, LazSerialSetup, LazSerialCommon, DbSql,
  AppLogger, StageConfig, Math,
  LazBleDeviceSelectForm, BleTimingUi,
  CompetitionLifecycleService, CompetitionBackupService;

  {$R *.lfm}

const
  STAGE_SETTINGS_ROW_HEIGHT = 34;

  { TSettingsForm }

procedure TSettingsForm.InitializeStageDraft;
var
  i: integer;
  defaultStageName: string;
  Configuration: TCompetitionConfiguration;
  HasDatabaseConfiguration: boolean;
begin
  FInitialStageCount := stages.Count;
  FStageDraftCount := FInitialStageCount;
  FPhysicalStageCapacity := FInitialStageCount;
  HasDatabaseConfiguration := IsCompetitionDatabaseOpen;
  if IsCompetitionDatabaseOpen then
  begin
    FPhysicalStageCapacity :=
      TCompetitionLifecycleService.PhysicalStageCapacity(MainForm.CompetitionDb);
    Configuration := TCompetitionLifecycleService.LoadConfiguration(
      MainForm.CompetitionDb, FPhysicalStageCapacity, 0);
  end;

  SetLength(FStageDraft, MAX_SUPPORTED_STAGE_COUNT + 1);
  for i := 1 to MAX_SUPPORTED_STAGE_COUNT do
  begin
    defaultStageName := Format(rsSUFormat, [i]);
    FStageDraft[i].Name := defaultStageName;
    // A newly added stage immediately participates in the competition.
    FStageDraft[i].Active := i > FInitialStageCount;
    if i <= FInitialStageCount then
    begin
      FStageDraft[i].Name := stages[i].Name;
      FStageDraft[i].Active := stages[i].isActive;
    end
    else if HasDatabaseConfiguration and (i <= FPhysicalStageCapacity) then
    begin
      if Configuration.StageNames[i - 1] <> '' then
        FStageDraft[i].Name := Configuration.StageNames[i - 1];
      // A saved flag means that this is a restored soft-hidden stage.
      // Physical columns without a config flag are only spare capacity.
      if Configuration.StageConfigured[i - 1] then
        FStageDraft[i].Active := Configuration.StageActive[i - 1];
    end;
  end;

  FUpdatingStageCount := True;
  try
    StageCountSpinEdit.MinValue := MIN_STAGE_COUNT;
    StageCountSpinEdit.MaxValue := MAX_SUPPORTED_STAGE_COUNT;
    StageCountSpinEdit.Value := FStageDraftCount;
    StageCountSpinEdit.Enabled := True;
  finally
    FUpdatingStageCount := False;
  end;
end;

function TSettingsForm.SelectedSerialDevice: string;
begin
  Result := ComComboBox1.Device;
end;

procedure TSettingsForm.BuildStageRows;
var
  i: integer;
  row: TStageSettingsFrame;
begin
  if Length(FStageRows) = 0 then
    SetLength(FStageRows, MAX_SUPPORTED_STAGE_COUNT + 1);

  FUpdatingStageRows := True;
  StagesContentPanel.DisableAlign;
  try
    for i := 1 to MAX_SUPPORTED_STAGE_COUNT do
    begin
      row := FStageRows[i];
      if i <= FStageDraftCount then
      begin
        if row = nil then
        begin
          row := TStageSettingsFrame.Create(Self);
          FStageRows[i] := row;
          row.Name := 'StageSettingsFrame' + IntToStr(i);
          row.Visible := False;
          row.SetBounds(0, (i - 1) * STAGE_SETTINGS_ROW_HEIGHT,
            StagesContentPanel.ClientWidth, STAGE_SETTINGS_ROW_HEIGHT);
          row.Anchors := [akTop, akLeft, akRight];
          row.Configure(i, FStageDraft[i].Name, FStageDraft[i].Active);
          row.OnStageChange := @StageRowChange;
          row.Parent := StagesContentPanel;
        end;
        row.Visible := True;
      end
      else if row <> nil then
        row.Visible := False;
    end;
    StagesContentPanel.Height :=
      FStageDraftCount * STAGE_SETTINGS_ROW_HEIGHT;
  finally
    StagesContentPanel.EnableAlign;
    FUpdatingStageRows := False;
  end;
  GroupBoxStages.AdjustSize;
  CompetitionContentPanel.AdjustSize;
  CompetitionScrollBox.UpdateScrollbars;
end;

function TSettingsForm.DraftActiveStagesCount: integer;
var
  i: integer;
begin
  Result := 0;
  for i := 1 to FStageDraftCount do
    if FStageDraft[i].Active then
      Inc(Result);
end;

function TSettingsForm.DraftFirstActiveStageIndex: integer;
var
  i: integer;
begin
  Result := 0;
  for i := 1 to FStageDraftCount do
    if FStageDraft[i].Active then
      Exit(i);
end;

procedure TSettingsForm.RebuildActiveStageItems(const APreferredStageIndex: integer);
var
  i, selectedIndex: integer;
begin
  ComboBoxAStage.Items.BeginUpdate;
  try
    ComboBoxAStage.Items.Clear;
    for i := 1 to FStageDraftCount do
      if FStageDraft[i].Active then
        ComboBoxAStage.Items.Add(IntToStr(i));

    selectedIndex := ComboBoxAStage.Items.IndexOf(IntToStr(APreferredStageIndex));
    if selectedIndex < 0 then
      selectedIndex := 0;

    if ComboBoxAStage.Items.Count > 0 then
    begin
      ComboBoxAStage.ItemIndex := selectedIndex;
      ComboBoxAStage.Enabled := True;
    end
    else
    begin
      ComboBoxAStage.Items.Add('1');
      ComboBoxAStage.ItemIndex := 0;
      ComboBoxAStage.Enabled := False;
    end;
  finally
    ComboBoxAStage.Items.EndUpdate;
  end;
end;

function TSettingsForm.DraftActiveStageIndex: integer;
begin
  if not TryStrToInt(ComboBoxAStage.Text, Result) or (Result < 1) or
    (Result > FStageDraftCount) or (not FStageDraft[Result].Active) then
    Result := DraftFirstActiveStageIndex;
end;

procedure TSettingsForm.StageCountSpinEditChange(Sender: TObject);
var
  preferredStageIndex: integer;
begin
  if FUpdatingStageCount then
    Exit;
  if not TryStrToInt(ComboBoxAStage.Text, preferredStageIndex) then
    preferredStageIndex := DraftFirstActiveStageIndex;
  FStageDraftCount := StageCountSpinEdit.Value;
  BuildStageRows;
  RebuildActiveStageItems(preferredStageIndex);
end;

procedure TSettingsForm.StageRowChange(Sender: TObject);
var
  preferredStageIndex, stageIndex: integer;
  row: TStageSettingsFrame;
begin
  if FUpdatingStageRows or not (Sender is TStageSettingsFrame) then
    Exit;

  row := TStageSettingsFrame(Sender);
  stageIndex := row.StageIndex;
  if (stageIndex < 1) or (stageIndex > FStageDraftCount) then
    Exit;

  FStageDraft[stageIndex].Name := row.StageName;
  FStageDraft[stageIndex].Active := row.Active;
  if not TryStrToInt(ComboBoxAStage.Text, preferredStageIndex) then
    preferredStageIndex := DraftFirstActiveStageIndex;
  RebuildActiveStageItems(preferredStageIndex);
end;

procedure TSettingsForm.ApplyStageDraftToModel;
var
  i: integer;
begin
  stages.Resize(FStageDraftCount);
  for i := 1 to FStageDraftCount do
  begin
    stages[i].Name := FStageDraft[i].Name;
    stages[i].isActive := FStageDraft[i].Active;
  end;
end;

function TSettingsForm.DetectChanges(const AActiveStageIndex: integer):
TSettingsChangeSet;
var
  categoryChanged, currentResultStageChanged, raceNameChanged,
  showStageNameChanged: boolean;
  i, selectedUpdateInterval: integer;
begin
  Result := Default(TSettingsChangeSet);
  Result.StageCountChanged := FStageDraftCount <> FInitialStageCount;
  for i := 1 to Min(FStageDraftCount, stages.Count) do
  begin
    if FStageDraft[i].Active <> stages[i].isActive then
      Result.StageActivityChanged := True;
    if FStageDraft[i].Name <> stages[i].Name then
      Result.StageNamesChanged := True;
  end;

  Result.ResultParametersChanged :=
    Result.StageCountChanged or Result.StageActivityChanged;
  raceNameChanged := NameEdit.Text <> raceName;
  categoryChanged := False;
  for i := 1 to VISIBLECAT do
    if (FindComponent('Edit' + IntToStr(i)) as TComboBox).Text <> cat[i] then
      categoryChanged := True;
  currentResultStageChanged :=
    AActiveStageIndex <> stages.NormalizeActiveIndex(StrToIntDef(astage, 0));
  Result.ZeroHourChanged := CheckBoxHideZeroHour.Checked <> zerohour;
  showStageNameChanged :=
    CheckBoxShowStageName.Checked <> showStageNameForSingleStage;

  Result.PresentationChanged :=
    Result.StageNamesChanged or raceNameChanged or categoryChanged or
    currentResultStageChanged or Result.ZeroHourChanged or showStageNameChanged;
  Result.ResultViewQueriesChanged := categoryChanged or currentResultStageChanged;
  Result.StageUiChanged := Result.ResultParametersChanged or
    Result.StageNamesChanged or showStageNameChanged;
  Result.CompetitionDatabaseChanged :=
    Result.ResultParametersChanged or Result.StageNamesChanged or
    raceNameChanged or categoryChanged or currentResultStageChanged;

  Result.SerialSettingsChanged :=
    (SelectedSerialDevice <> MainForm.Serial.Device) or
    (StrToBaudRate(ComComboBox2.Text) <> MainForm.Serial.BaudRate) or
    (StrToDataBits(ComComboBox3.Text) <> MainForm.Serial.DataBits) or
    (StrToStopBits(ComComboBox4.Text) <> MainForm.Serial.StopBits) or
    (StrToParity(ComComboBox5.Text) <> MainForm.Serial.Parity) or
    (StrToFlowControl(ComComboBox6.Text) <> MainForm.Serial.FlowControl);
  Result.TimingInputSettingsChanged :=
    (SelectedTimingInputTransport <> timingInputTransport) or
    (FSelectedBleDevice.DeviceId <> MainForm.LazBleLclClient1.DeviceId) or
    (FSelectedBleDevice.DeviceName <> MainForm.LazBleLclClient1.DeviceName) or
    (StartMarkMatchDeltaSpin.Value <> startMarkMatchDeltaSeconds) or
    (CheckBoxStartMarkAutomaticApply.Checked <> startMarkAutomaticApply);
  Result.EquipmentChanged := Result.SerialSettingsChanged or
    (LEDAdress.Text <> ledpaneladress) or (TelegramBotAdressEdit.Text <>
    telegrambotadress) or (CheckBoxTelegramRetry.Checked <> telegramRetryEnabled) or
    (SpinTelegramRetryCount.Value <> telegramRetryCount) or
    (SpinTelegramRetryDelay.Value <> telegramRetryDelaySeconds);

  case ComboBoxUpdateInterval.ItemIndex of
    0: selectedUpdateInterval := -1;
    1: selectedUpdateInterval := 1;
    2: selectedUpdateInterval := 7;
    else
      selectedUpdateInterval := 30;
  end;
  Result.ApplicationSettingsChanged :=
    (CheckBoxUpdateAtStartup.Checked <> checkUpdateAtStartup) or
    (selectedUpdateInterval <> checkUpdateIntervalInDays) or
    (CheckBoxBackup.Checked <> doAutomaticBackup) or
    (SpinBackup.Value * 60 * 1000 <> backupPeriod) or
    (SpinBackupRetentionDays.Value <> automaticBackupRetentionDays) or
    (SpinBackupMaxSizeMb.Value <> automaticBackupMaxSizeMb) or
    (DelayEdit.Value <> MainForm.FinishDebounceInterval) or
    (FInitialLanguage <> CurrentLang) or Result.TimingInputSettingsChanged;
end;

procedure TSettingsForm.SaveCompetitionSettingsToDatabase(
  const AActiveStageIndex: integer);
var
  i: integer;
  Configuration: TCompetitionConfiguration;
begin
  Configuration := TCompetitionConfiguration.Create(FStageDraftCount, VISIBLECAT);
  Configuration.RaceName := NameEdit.Text;
  Configuration.ActiveStageIndex := AActiveStageIndex;
  for i := 1 to VISIBLECAT do
    Configuration.Categories[i - 1] :=
      (FindComponent('Edit' + IntToStr(i)) as TComboBox).Text;
  for i := 1 to FStageDraftCount do
  begin
    Configuration.StageActive[i - 1] := FStageDraft[i].Active;
    Configuration.StageNames[i - 1] := FStageDraft[i].Name;
  end;
  FPhysicalStageCapacity := TCompetitionLifecycleService.SaveConfiguration(
    MainForm.CompetitionDb, Configuration, FPhysicalStageCapacity);
end;

procedure TSettingsForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if ModalResult <> mrOk then
    Exit;

  if DraftActiveStagesCount = 0 then
  begin
    AskMessageDlg(rsAtLeastOneActiveStageRequired, mtWarning, [mbOK], 0);
    CanClose := False;
    Exit;
  end;

  if FReductionConfirmed or (not IsCompetitionDatabaseOpen) or
    (FStageDraftCount >= FInitialStageCount) then
    Exit;

  try
    if TMainSql.HasAnyDataInStageRange(MainForm.SQLQuery1, FStageDraftCount +
      1, FInitialStageCount, FPhysicalStageCapacity) then
    begin
      CanClose := AskMessageDlg(Format(rsStageCountReductionWarning,
        [FInitialStageCount, FStageDraftCount]), mtWarning,
        [mbYes, mbNo], 0) = mrYes;
      FReductionConfirmed := CanClose;
    end;
  except
    on E: Exception do
    begin
      CanClose := False;
      AppLog(Format(rsCompetitionSettingsSaveError, [E.Message]),
        allError, alvStatus, alsDatabase);
      AskMessageDlg(Format(rsCompetitionSettingsSaveError, [E.Message]),
        mtError, [mbOK], 0);
    end;
  end;
end;

procedure TSettingsForm.UpdateCollectionTranslations(AUpdateIntervalIndex: integer);
var
  i: integer;
begin
  TreeView1.Items[0].Text := rsSettingsGeneral;
  TreeView1.Items[1].Text := rsSettingsView;
  TreeView1.Items[2].Text := rsSettingsCompetition;
  TreeView1.Items[3].Text := rsSettingsTimingInput;
  TreeView1.Items[4].Text := rsSettingsLEDPanel;
  TreeView1.Items[5].Text := rsSettingsTelegramBot;
  DividerBevelTimingInputMode.Caption := rsTimingInputMode;
  DividerBevelStartMarkSettings.Caption := rsStartMarkSettings;
  StartMarkMatchDeltaLabel.Caption := rsStartMarkMatchDeltaSeconds;
  StartMarkMatchDeltaLabel.Hint := rsStartMarkMatchDeltaHint;
  CheckBoxStartMarkAutomaticApply.Caption := rsStartMarkAutomaticApply;
  CheckBoxStartMarkAutomaticApply.Hint := rsStartMarkAutomaticApplyHint;
  RadioButtonTimingInputSerial.Caption := rsTimingInputSerial;
  RadioButtonTimingInputBle.Caption := rsTimingInputBle;
  DividerBevelCOMSettings1.Caption := rsTimingInputSerialSettings;
  DividerBevelBleSettings.Caption := rsTimingInputBleSettings;
  LabelBleDevice.Caption := rsTimingInputBleDevice;
  LabelBleDeviceId.Caption := rsTimingInputBleDeviceId;
  ButtonSelectBleDevice.Caption := rsTimingInputSelectDevice;
  StageCountLabel.Caption := rsStageCount;
  CheckBoxTelegramRetry.Caption := rsTelegramRetryEnabled;
  LabelTelegramRetryCount.Caption := rsTelegramRetryCount;
  LabelTelegramRetryDelay.Caption := rsTelegramRetryDelaySeconds;

  for i := 1 to High(FStageRows) do
    if Assigned(FStageRows[i]) then
      FStageRows[i].UpdateTranslation;

  if ComboBoxLanguage.Items.Count > 0 then
    ComboBoxLanguage.Items[0] := rsSystemDefault;

  ComboBoxUpdateInterval.Items.BeginUpdate;
  try
    ComboBoxUpdateInterval.Items.Clear;
    ComboBoxUpdateInterval.Items.Add(rsUpdateEveryTime);
    ComboBoxUpdateInterval.Items.Add(rsUpdateDaily);
    ComboBoxUpdateInterval.Items.Add(rsUpdateWeekly);
    ComboBoxUpdateInterval.Items.Add(rsUpdateMonthly);
  finally
    ComboBoxUpdateInterval.Items.EndUpdate;
  end;
  if (AUpdateIntervalIndex >= 0) and (AUpdateIntervalIndex <
    ComboBoxUpdateInterval.Items.Count) then
    ComboBoxUpdateInterval.ItemIndex := AUpdateIntervalIndex;
end;

procedure TSettingsForm.FormCreate(Sender: TObject);
var
  c: TComponent;
  i, preferredStageIndex: integer;
  baudRate: TBaudRate;
  dataBits: TDataBits;
  stopBits: TStopBits;
  parity: TParity;
  flowControl: TFlowControl;
begin
  FInitialLanguage := CurrentLang;
  NameEdit.Text := raceName;

  for i := 1 to VISIBLECAT do
  begin
    c := FindComponent('Edit' + IntToStr(i));
    TComboBox(c).Text := cat[i];
  end;

  InitializeStageDraft;
  BuildStageRows;
  DelayEdit.Text := IntToStr(MainForm.FinishDebounceInterval);

  // Формирование списка языков и выбор текущего
  ComboBoxLanguage.Items.Add(rsSystemDefault);
  ComboBoxLanguage.Items.Add(rsEnglish);
  ComboBoxLanguage.Items.Add(rsRussian);

  if CurrentLang = '' then
    ComboBoxLanguage.Text := rsSystemDefault
  else if CurrentLang = 'ru' then
    ComboBoxLanguage.Text := rsRussian
  else if CurrentLang = 'en' then
    ComboBoxLanguage.Text := rsEnglish;

  // Обновления
  CheckBoxUpdateAtStartup.Checked := checkUpdateAtStartup;
  ComboBoxUpdateInterval.Enabled := checkUpdateAtStartup;
  UpdateCollectionTranslations(ComboBoxUpdateInterval.ItemIndex);
  if checkUpdateIntervalInDays < 0 then
    ComboBoxUpdateInterval.ItemIndex := 0
  else if checkUpdateIntervalInDays < 7 then
    ComboBoxUpdateInterval.ItemIndex := 1
  else if checkUpdateIntervalInDays < 30 then
    ComboBoxUpdateInterval.ItemIndex := 2
  else
    ComboBoxUpdateInterval.ItemIndex := 3;

  // Резервное копирование
  CheckBoxBackup.Checked := doAutomaticBackup;
  SpinBackup.Value := backupPeriod div (60 * 1000);
  SpinBackupRetentionDays.Value := automaticBackupRetentionDays;
  SpinBackupMaxSizeMb.Value := automaticBackupMaxSizeMb;
  LabelBackupRetentionDays.Caption := rsBackupRetentionLabel;
  LabelBackupRetentionDaysUnit.Caption := rsDays;
  LabelBackupMaxSizeMb.Caption := rsBackupMaxSizeMbLabel;
  LabelBackupMegabytes.Caption := rsMegabytes;

  if not TryStrToInt(astage, preferredStageIndex) then
    preferredStageIndex := DraftFirstActiveStageIndex;
  RebuildActiveStageItems(preferredStageIndex);

  CheckBoxHideZeroHour.Checked := zerohour;
  CheckBoxShowStageName.Checked := showStageNameForSingleStage;

  //if timemark = 'str' then RadioButtonCOMSetStr.Checked := true
  //else RadioButtonCOMSetTime.Checked := true;

  //EditCOMSetStr.Text := timemarkstr;
  //EditCOMSetTime.Text:= timemarkformat;

  LEDAdress.Text := ledpaneladress;
  TelegramBotAdressEdit.Text := telegrambotadress;
  CheckBoxTelegramRetry.Checked := telegramRetryEnabled;
  SpinTelegramRetryCount.Value := telegramRetryCount;
  SpinTelegramRetryDelay.Value := telegramRetryDelaySeconds;
  CheckBoxTelegramRetryChange(CheckBoxTelegramRetry);

  Notebook1.PageIndex := 0;

  for baudRate := Low(TBaudRate) to High(TBaudRate) do
    ComComboBox2.Items.Add(BaudRateToStr(baudRate));
  for dataBits := Low(TDataBits) to High(TDataBits) do
    ComComboBox3.Items.Add(DataBitsToStr(dataBits));
  for stopBits := Low(TStopBits) to High(TStopBits) do
    ComComboBox4.Items.Add(StopBitsToStr(stopBits));
  for parity := Low(TParity) to High(TParity) do
    ComComboBox5.Items.Add(ParityToStr(parity));
  for flowControl := Low(TFlowControl) to High(TFlowControl) do
    ComComboBox6.Items.Add(FlowControlToStr(flowControl));

  FInitialSerialDevice := MainForm.Serial.Device;
  ComComboBox1.Device := FInitialSerialDevice;
  ComComboBox2.Text := BaudRateToStr(MainForm.Serial.BaudRate);
  ComComboBox3.Text := DataBitsToStr(MainForm.Serial.DataBits);
  ComComBoBox4.Text := StopBitsToStr(MainForm.Serial.StopBits);
  ComComBoBox5.Text := ParityToStr(MainForm.Serial.Parity);
  ComComBoBox6.Text := FlowControlToStr(MainForm.Serial.FlowControl);

  FSelectedBleDevice := Default(TBleDeviceInfo);
  FSelectedBleDevice.DeviceId := MainForm.LazBleLclClient1.DeviceId;
  FSelectedBleDevice.DeviceName := MainForm.LazBleLclClient1.DeviceName;
  StartMarkMatchDeltaSpin.Value := startMarkMatchDeltaSeconds;
  CheckBoxStartMarkAutomaticApply.Checked := startMarkAutomaticApply;
  RadioButtonTimingInputBle.Checked := timingInputTransport = ttkBle;
  RadioButtonTimingInputSerial.Checked := not RadioButtonTimingInputBle.Checked;
  FBleAvailability := MainForm.LazBleComponent1.Availability;
  FPreviousBleAvailabilityChanged :=
    MainForm.LazBleComponent1.OnAvailabilityChanged;
  MainForm.LazBleComponent1.OnAvailabilityChanged := @BleAvailabilityChanged;
  RefreshTimingInputPanels;

end;

destructor TSettingsForm.Destroy;
var
  CurrentHandler: TBleAvailabilityEvent;
  FormHandler: TBleAvailabilityEvent;
begin
  if Assigned(MainForm) and Assigned(MainForm.LazBleComponent1) then
  begin
    CurrentHandler := MainForm.LazBleComponent1.OnAvailabilityChanged;
    FormHandler := @BleAvailabilityChanged;
    if (TMethod(CurrentHandler).Code = TMethod(FormHandler).Code) and
      (TMethod(CurrentHandler).Data = TMethod(FormHandler).Data) then
      MainForm.LazBleComponent1.OnAvailabilityChanged :=
        FPreviousBleAvailabilityChanged;
  end;
  inherited Destroy;
end;

procedure TSettingsForm.BleAvailabilityChanged(Sender: TObject;
  const AAvailability: TBleAvailability);
var
  PreviousHandler: TBleAvailabilityEvent;
begin
  PreviousHandler := FPreviousBleAvailabilityChanged;
  if Assigned(PreviousHandler) then
    PreviousHandler(Sender, AAvailability);
  FBleAvailability := AAvailability;
  RefreshTimingInputPanels;
end;

function TSettingsForm.SelectedTimingInputTransport: TTimingTransportKind;
begin
  if RadioButtonTimingInputBle.Checked then
    Result := ttkBle
  else
    Result := ttkSerial;
end;

procedure TSettingsForm.RefreshTimingInputPanels;
var
  BleStatus: string;
begin
  RadioButtonTimingInputBle.Caption := rsTimingInputBle;
  RadioButtonTimingInputBle.Hint := '';
  if FBleAvailability in [lbaChecking, lbaUnavailable] then
  begin
    BleStatus := BleTimingStatusText(MainForm.LazBleLclClient1);
    if BleStatus <> '' then
      RadioButtonTimingInputBle.Hint := BleStatus;
  end;
  RadioButtonTimingInputBle.Enabled :=
    FBleAvailability <> lbaUnavailable;
  PanelBleSettings.Enabled := FBleAvailability <> lbaUnavailable;

  if RadioButtonTimingInputBle.Checked then
    TimingInputSettingsNotebook.PageIndex := 1
  else
    TimingInputSettingsNotebook.PageIndex := 0;

  if FSelectedBleDevice.DeviceName <> '' then
    BleDeviceNameEdit.Text := FSelectedBleDevice.DeviceName
  else
    BleDeviceNameEdit.Text := rsTimingInputDeviceNotSelected;
  BleDeviceIdEdit.Text := FSelectedBleDevice.DeviceId;
  ButtonSelectBleDevice.Enabled :=
    (FBleAvailability in [lbaUnknown, lbaAvailable]) and
    BleTimingCanSelectDevice(MainForm.LazBleLclClient1);
end;

procedure TSettingsForm.TimingInputModeChanged(Sender: TObject);
begin
  RefreshTimingInputPanels;
end;

function TSettingsForm.ExecuteBleDeviceSelection(out ADevice: TBleDeviceInfo): boolean;
var
  dialog: TBleDeviceSelectForm;
begin
  ADevice := Default(TBleDeviceInfo);
  dialog := TBleDeviceSelectForm.Create(Self,
    MainForm.LazBleComponent1.ScanController);
  try
    dialog.AdapterId := MainForm.LazBleComponent1.AdapterId;
    dialog.ScanTimeoutMs := MainForm.LazBleComponent1.ScanTimeoutMs;
    Result := dialog.Execute(ADevice);
  finally
    dialog.Free;
  end;
end;

procedure TSettingsForm.ButtonSelectBleDeviceClick(Sender: TObject);
var
  device: TBleDeviceInfo;
begin
  if not ButtonSelectBleDevice.Enabled then
    Exit;
  if ExecuteBleDeviceSelection(device) and (device.DeviceId <> '') then
  begin
    FSelectedBleDevice := device;
    RefreshTimingInputPanels;
  end;
end;

procedure TSettingsForm.ApplyTimingInputSettings;
begin
  timingInputTransport := SelectedTimingInputTransport;
  startMarkMatchDeltaSeconds := StartMarkMatchDeltaSpin.Value;
  startMarkAutomaticApply := CheckBoxStartMarkAutomaticApply.Checked;
  if (FSelectedBleDevice.DeviceId <> MainForm.LazBleLclClient1.DeviceId) or
    (FSelectedBleDevice.DeviceName <> MainForm.LazBleLclClient1.DeviceName) then
    MainForm.LazBleLclClient1.SelectDevice(FSelectedBleDevice);
  MainForm.RefreshTimingInputUi;
end;

procedure TSettingsForm.Page2ViewBeforeShow(ASender: TObject;
  ANewPage: TPage; ANewIndex: integer);
begin

end;

function CreateSettingsBackup: boolean;
var
  BackupRequest: TCompetitionBackupRequest;
  BackupResult: TCompetitionBackupResult;
begin
  BackupRequest := NewCompetitionBackupRequest(fName, Now, cbkSafety,
    cbrBeforeStageExpansion, CurrentBackupRetentionPolicy);
  BackupResult := TCompetitionBackupService.CreateBackup(BackupRequest);
  Result := BackupResult.Status = cbsCreated;
  if Result then
  begin
    AppLog(Format(rsBackupCreated, [BackupResult.BackupFileName]),
      allInfo, alvStatus, alsDatabase);
    if BackupResult.Cleanup.DeletedCount > 0 then
      AppLog(Format(rsBackupCleanupCompleted,
        [BackupResult.Cleanup.DeletedCount, BackupResult.Cleanup.FreedBytes]),
        allInfo, alvDetails, alsDatabase);
    if BackupResult.Cleanup.WarningMessage <> '' then
      AppLog(Format(rsBackupCleanupWarning,
        [BackupResult.Cleanup.WarningMessage]),
        allWarning, alvDetails,
        alsDatabase);
  end
  else
    case BackupResult.Failure of
      cbfDirectoryCreate:
        AppLog(Format(rsBackupDirectoryCreateError,
          [ExtractFilePath(BackupResult.BackupFileName)]), allWarning,
          alvDetails, alsDatabase);
      cbfInvalidFile:
        AppLog(Format(rsBackupFileInvalid, [BackupResult.BackupFileName]),
          allWarning, alvDetails, alsDatabase);
      else
        AppLog(Format(rsBackupCreateError,
          [BackupResult.BackupFileName, BackupResult.ErrorMessage]),
          allWarning, alvDetails, alsDatabase);
    end;
end;

procedure TSettingsForm.RunSettings(ActivePage: integer = 0);
var
  i, activeStageIndex, previousActiveStagesCount, previousCurrentStageIndex,
  previousParticipantId: integer;
  hadOpenDatabase, restoreCurrentParticipant: boolean;
  changes: TSettingsChangeSet;
  messageText: string;
begin
  with TSettingsForm.Create(nil) do
  begin
    try
      TreeView1.Items[ActivePage].Selected := True;
      TreeView1.Items[ActivePage].Focused := True;
      Notebook1.PageIndex := ActivePage;
      ShowModal;
      if ModalResult = mrOk then
      begin
        activeStageIndex := DraftActiveStageIndex;
        hadOpenDatabase := IsCompetitionDatabaseOpen;
        changes := DetectChanges(activeStageIndex);
        previousActiveStagesCount := stages.ActiveStagesCount;
        previousCurrentStageIndex := MainForm.CurrentStageIndex;
        restoreCurrentParticipant :=
          hadOpenDatabase and MainForm.MainDataset1.Active and
          TMainSql.TryGetCurrentId(MainForm.MainDataset1,
          previousParticipantId);

        if hadOpenDatabase and changes.StageCountChanged and
          (FStageDraftCount > FPhysicalStageCapacity) and
          (not CreateSettingsBackup) then
        begin
          messageText := Format(rsStageCapacityExpansionBackupError, [fName]);
          MainForm.RecoverCompetitionAfterSettingsFailure;
          AppLog(messageText, allError, alvStatus, alsDatabase);
          AskMessageDlg(messageText, mtError, [mbOK], 0);
          Exit;
        end;

        if hadOpenDatabase and changes.CompetitionDatabaseChanged then
        try
          SaveCompetitionSettingsToDatabase(activeStageIndex);
        except
          on E: Exception do
          begin
            messageText := Format(rsCompetitionSettingsSaveError,
              [E.Message]);
            if FStageDraftCount > FPhysicalStageCapacity then
              MainForm.RecoverCompetitionAfterSettingsFailure;
            AppLog(messageText, allError, alvStatus, alsDatabase);
            AskMessageDlg(messageText, mtError, [mbOK], 0);
            Exit;
          end;
        end;

        // Глобальное состояние меняется только после успешной записи БД.
        ApplyTimingInputSettings;

        if changes.SerialSettingsChanged then
        begin
          MainForm.Serial.Close;
          MainForm.Serial.Device := SelectedSerialDevice;
          MainForm.Serial.BaudRate := StrToBaudRate(ComComboBox2.Text);
          MainForm.Serial.DataBits := StrToDataBits(ComComboBox3.Text);
          MainForm.Serial.StopBits := StrToStopBits(ComComboBox4.Text);
          MainForm.Serial.Parity := StrToParity(ComComboBox5.Text);
          MainForm.Serial.FlowCOntrol := StrToFlowControl(ComComboBox6.Text);
          MainForm.RefreshSerialPortUi;
        end;

        // Обновление
        checkUpdateAtStartup := CheckBoxUpdateAtStartup.Checked;

        if ComboBoxUpdateInterval.ItemIndex = 0 then
          checkUpdateIntervalInDays := -1
        else if ComboBoxUpdateInterval.ItemIndex = 1 then
          checkUpdateIntervalInDays := 1
        else if ComboBoxUpdateInterval.ItemIndex = 2 then
          checkUpdateIntervalInDays := 7
        else
          checkUpdateIntervalInDays := 30;

        // Резервное копирование
        doAutomaticBackup := CheckBoxBackup.Checked;
        backupPeriod := SpinBackup.Value * 60 * 1000;
        automaticBackupRetentionDays := SpinBackupRetentionDays.Value;
        automaticBackupMaxSizeMb := SpinBackupMaxSizeMb.Value;
        MainForm.BackupTimer.Enabled := doAutomaticBackup;
        MainForm.BackupTimer.Interval := backupPeriod;

        MainForm.FinishDebounceInterval := StrToInt(DelayEdit.Text);
        if ComboBoxLanguage.Text = rsSystemDefault then
          CurrentLang := ''
        else if ComboBoxLanguage.Text = rsRussian then
          CurrentLang := 'ru'
        else if ComboBoxLanguage.Text = rsEnglish then
          CurrentLang := 'en';

        //if RadioButtonCOMSetStr.Checked then timemark := 'str' else timemark := 'time';
        //timemarkstr := EditCOMSetStr.Text;
        //timemarkformat := EditCOMSetTime.Text;

        raceName := NameEdit.Text;
        astage := IntToStr(activeStageIndex);
        // Определяем переход от работы с одним этапом на несколько.
        if changes.ResultParametersChanged and
          (previousActiveStagesCount = 1) and (DraftActiveStagesCount > 1) then
          //для того, чтобы освободить место для таблицы с вводом поправки
          //без этого в текущей организации GUI были коллизии
          MainForm.Splitter1.Top :=
            MainForm.Splitter1.Top + MainForm.CurrentStageGroup.Height;
        for i := 1 to VISIBLECAT do
        begin
          //сохраняем название категорий, которые будут выводиться на окно результатов
          cat[i] := (FindComponent('Edit' + IntToStr(i)) as TComboBox).Text;
        end;

        zerohour := CheckBoxHideZeroHour.Checked;
        showStageNameForSingleStage := CheckBoxShowStageName.Checked;
        ledpaneladress := LEDAdress.Text;
        telegrambotadress := TelegramBotAdressEdit.Text;
        telegramRetryEnabled := CheckBoxTelegramRetry.Checked;
        telegramRetryCount := SpinTelegramRetryCount.Value;
        telegramRetryDelaySeconds := SpinTelegramRetryDelay.Value;
        if changes.ResultParametersChanged or changes.StageNamesChanged then
          ApplyStageDraftToModel;
        if changes.ResultParametersChanged then
          MainForm.ApplyResultParameterChanges(FStageDraftCount,
            previousCurrentStageIndex, previousParticipantId,
            hadOpenDatabase, restoreCurrentParticipant,
            changes.StageCountChanged)
        else
          MainForm.ApplyPresentationChanges(previousCurrentStageIndex,
            hadOpenDatabase, changes.StageUiChanged,
            changes.ResultViewQueriesChanged, changes.StageNamesChanged,
            changes.ZeroHourChanged);
        AppLog(Format(rsShownCategories, [cat[1] + ', ' + cat[2] +
          ', ' + cat[3] + ', ' + cat[4] + ', ' + cat[5] + ', ' + cat[6]]),
          allDebug, alvNone, alsApplication);
        AppLog(rsSettingsSaved, allInfo, alvNone, alsApplication);
      end;
    finally
      Free;
    end;
  end;
end;

procedure TSettingsForm.TreeView1Change(Sender: TObject; Node: TTreeNode);
begin
  Notebook1.PageIndex := Node.Index;
end;

procedure TSettingsForm.ComboBoxAStageDropDown(Sender: TObject);
var
  preferredStageIndex: integer;
begin
  if not TryStrToInt(ComboBoxAStage.Text, preferredStageIndex) then
    preferredStageIndex := DraftFirstActiveStageIndex;
  RebuildActiveStageItems(preferredStageIndex);
end;

procedure TSettingsForm.ButtonLEDTestClick(Sender: TObject);
begin
  MainForm.QueueLedPanelTest(LEDAdress.Text, LEDSingleline.Text,
    LEDUpperline.Text, LEDBottomline.Text);
end;

procedure TSettingsForm.ButtonTelegramTestClick(Sender: TObject);
var
  Fields: THttpFormFields;

  procedure AddField(const AName, AValue: string);
  var
    Index: integer;
  begin
    if AValue = '' then
      Exit;
    Index := Length(Fields);
    SetLength(Fields, Index + 1);
    Fields[Index] := HttpFormField(AName, AValue);
  end;

begin
  Fields := nil;
  AddField('number', TelegramNumber.Text);
  AddField('name', TelegramName.Text);
  AddField('category', TelegramCategory.Text);
  AddField('result', TelegramResult.Text);
  AddField('diff', TelegramDiff.Text);
  AddField('place', TelegramPlace.Text);
  MainForm.QueueTelegramTest(TelegramBotAdressEdit.Text, Fields,
    TTelegramRetryPolicy.Create(CheckBoxTelegramRetry.Checked,
    SpinTelegramRetryCount.Value, SpinTelegramRetryDelay.Value));
end;

procedure TSettingsForm.CheckBoxTelegramRetryChange(Sender: TObject);
begin
  SpinTelegramRetryCount.Enabled := CheckBoxTelegramRetry.Checked;
  SpinTelegramRetryDelay.Enabled := CheckBoxTelegramRetry.Checked;
  LabelTelegramRetryCount.Enabled := CheckBoxTelegramRetry.Checked;
  LabelTelegramRetryDelay.Enabled := CheckBoxTelegramRetry.Checked;
end;

procedure TSettingsForm.CheckBoxStartMarkAutomaticApplyChange(Sender: TObject);
begin

end;

procedure TSettingsForm.CheckBoxUpdateAtStartupChange(Sender: TObject);
begin
  ComboBoxUpdateInterval.Enabled := (Sender as TCheckBox).Checked;
end;

procedure TSettingsForm.ComboBoxLanguageChange(Sender: TObject);
var
  lang: string = '';
  def: boolean = False;
  languageChanged: boolean;
  updateIntervalIndex: integer;
begin
  if (Sender as TComboBox).Text = rsSystemDefault then
    def := True
  else if (Sender as TComboBox).Text = rsRussian then
    lang := 'ru'
  else if (Sender as TComboBox).Text = rsEnglish then
    lang := 'en';
  languageChanged := lang <> CurrentLang;
  updateIntervalIndex := ComboBoxUpdateInterval.ItemIndex;
  MainForm.SetLang(lang);
  UpdateCollectionTranslations(updateIntervalIndex);
  RefreshTimingInputPanels;
  if languageChanged then
  begin
    if lang = '' then
      lang := 'system';
    AppLog(Format(rsLanguageChanged, [lang]), allInfo, alvNone,
      alsApplication);
  end;
  if def then
  begin
    (Sender as TComboBox).Text := rsSystemDefault;
  end;
end;

procedure TSettingsForm.EditDropDown(Sender: TObject);
begin
  if IsCompetitionDatabaseOpen then
    TMainSql.LoadCategories(MainForm.SQLQuery1,
      (Sender as TComboBox).Items);
end;

end.
