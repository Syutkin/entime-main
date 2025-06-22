unit Settings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  i18n, rxspin, LCLTranslator, Buttons, DBCtrls, ButtonPanel, ComCtrls, Spin,
  LazSerial, Lazsynaser, DataPortHTTP, DividerBevel, CheckBoxThemed,
  translations, opensslsockets, fphttpclient, rxdbgrid;

type

  { TSettingsForm }

  TSettingsForm = class(TForm)
    ButtonLEDTest: TButton;
    ButtonTelegramTest: TButton;
    ButtonPanel1: TButtonPanel;
    CheckBoxHideZeroHour: TCheckBoxThemed;
    CheckBoxShowStageName: TCheckBoxThemed;
    CheckGroup1: TCheckGroup;
    ComboBoxLanguage: TComboBox;
    ComboBoxAStage: TComboBox;
    ComComboBox1: TComboBox;
    ComComboBox2: TComboBox;
    ComComboBox3: TComboBox;
    ComComboBox4: TComboBox;
    ComComboBox5: TComboBox;
    ComComboBox6: TComboBox;
    DelayEdit: TSpinEdit;
    DividerBevelCOMSettings1: TDividerBevel;
    DividerBevelCOMSettings2: TDividerBevel;
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
    NameEdit: TEdit;
    EditCOMSetStr: TEdit;
    EditCOMSetTime: TEdit;
    GroupBoxName: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    LabelName: TLabel;
    LabelSingleline: TLabel;
    LabelCategory: TLabel;
    LabelResult: TLabel;
    LabelDiff: TLabel;
    LabelPlace: TLabel;
    LabelUpperline: TLabel;
    LabelBottomline: TLabel;
    LabelNumber: TLabel;
    LeftPanel: TPanel;
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
    Page4COM: TPage;
    Page5LED: TPage;
    Page6Telegram: TPage;
    PanelLEDTest: TPanel;
    PanelComSettings: TPanel;
    DividerBevelLanguage1: TDividerBevel;
    DividerBevelDelay1: TDividerBevel;
    PanelCOMFinishTimeSettings: TPanel;
    RadioButtonCOMSetStr: TRadioButton;
    RadioButtonCOMSetTime: TRadioButton;
    SUEdit4: TEdit;
    SUEdit5: TEdit;
    SUEdit6: TEdit;
    GroupBoxCategory: TGroupBox;
    ActiveStageLabel: TLabel;
    SUEdit1: TEdit;
    SUEdit2: TEdit;
    SUEdit3: TEdit;
    GroupBoxStages: TGroupBox;
    LEDAdress: TEdit;
    TreeView1: TTreeView;
    procedure ButtonLEDTestClick(Sender: TObject);
    procedure ButtonTelegramTestClick(Sender: TObject);
    procedure CheckGroup1ItemClick(Sender: TObject; Index: integer);
    procedure ComboBoxAStageDropDown(Sender: TObject);
    procedure ComboBoxLanguageChange(Sender: TObject);
    procedure EditDropDown(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Label1Click(Sender: TObject);
    procedure Page2ViewBeforeShow(ASender: TObject; ANewPage: TPage; ANewIndex: integer);
    procedure RunSettings(ActivePage: integer = 0);
    procedure TreeView1Change(Sender: TObject; Node: TTreeNode);
  private

  public

  end;

var
  SettingsForm: TSettingsForm;

implementation

uses Main, Implement, LazSerialSetup;

  {$R *.lfm}

  {--------------копия из lazSerialSetup начало----------------------------------}
const
  {$IFDEF UNIX}
  BaudRateStrings: array[TBaudRate] of string =
    ('0', '50', '75', '110', '134', '150', '200', '300', '600', '1200', '1800',
    '2400', '4800', '9600', '19200', '38400', '57600', '115200', '230400'
    {$IFNDEF DARWIN}// LINUX
    , '460800', '500000', '576000', '921600', '1000000', '1152000', '1500000',
    '2000000', '2500000', '3000000', '3500000', '4000000'
    {$ENDIF}  );
  {$ELSE}// MSWINDOWS
  BaudRateStrings: array[TBaudRate] of string = ('110', '300', '600',
    '1200', '2400', '4800', '9600', '14400', '19200', '38400', '56000', '57600',
    '115200', '128000', '230400', '256000', '460800', '921600');
  {$ENDIF}
  StopBitsStrings: array[TStopBits] of string = ('1', '1.5', '2');
  DataBitsStrings: array[TDataBits] of string = ('8', '7', '6', '5');
  ParityBitsStrings: array[TParity] of string = ('None', 'Odd', 'Even',
    'Mark', 'Space');
  FlowControlStrings: array[TFlowControl] of string = ('None',
    'Software', 'HardWare');

procedure StringArrayToList(AList: TStrings; const AStrings: array of string);
var
  Cpt: integer;
begin
  for Cpt := Low(AStrings) to High(AStrings) do
    AList.Add(AStrings[Cpt]);
end;

{--------------копия из lazSerialSetup конец-----------------------------------}

{ TSettingsForm }

procedure TSettingsForm.FormCreate(Sender: TObject);
var
  c: TComponent;
  i: integer;
begin
  NameEdit.Text := raceName;
  for i := 1 to maxstages do
  begin
    c := FindComponent('Edit' + IntToStr(i));
    TComboBox(c).Text := cat[i];
    c := FindComponent('SUEdit' + IntToStr(i));
    TEdit(c).Text := stages[i].Name;
  end;
  DelayEdit.Text := IntToStr(checkinterval);

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

  for i := 1 to maxstages do
    if stages[i].isActive then
      CheckGroup1.Checked[i - 1] := True;

  CheckBoxHideZeroHour.Checked := zerohour;
  CheckBoxShowStageName.Checked := showStageNameForSingleStage;

  //if timemark = 'str' then RadioButtonCOMSetStr.Checked := true
  //else RadioButtonCOMSetTime.Checked := true;

  //EditCOMSetStr.Text := timemarkstr;
  //EditCOMSetTime.Text:= timemarkformat;

  ComboBoxAStage.Items.Add(astage);
  ComboBoxAStage.Text := astage;

  LEDAdress.Text := ledpaneladress;
  TelegramBotAdressEdit.Text := telegrambotadress;

  Notebook1.PageIndex := 0;

  {-------------- скопированно из lazSerialSetup---------------------------------}
  ComComboBox1.Items.CommaText := GetSerialPortNames();
  StringArrayToList(ComComboBox2.Items, BaudRateStrings);
  StringArrayToList(ComComboBox3.Items, DataBitsStrings);
  StringArrayToList(ComComboBox4.Items, StopBitsStrings);
  StringArrayToList(ComComboBox5.Items, ParityBitsStrings);
  StringArrayToList(ComComboBox6.Items, FlowControlStrings);

  ComComboBox1.Text := MainForm.Serial.Device;
  ComComboBox2.Text := BaudRateToStr(MainForm.Serial.BaudRate);
  ComComboBox3.Text := DataBitsToStr(MainForm.Serial.DataBits);
  ComComBoBox4.Text := StopBitsToStr(MainForm.Serial.StopBits);
  ComComBoBox5.Text := ParityToStr(MainForm.Serial.Parity);
  ComComBoBox6.Text := FlowControlToStr(MainForm.Serial.FlowControl);

end;

procedure TSettingsForm.Label1Click(Sender: TObject);
begin

end;

procedure TSettingsForm.Page2ViewBeforeShow(ASender: TObject;
  ANewPage: TPage; ANewIndex: integer);
begin

end;

//разбить запись на процедуры?
procedure TSettingsForm.RunSettings(ActivePage: integer = 0);
var
  i: integer;
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
        MainForm.Serial.Close;
        MainForm.Serial.Device := ComComboBox1.Text;
        MainForm.Serial.BaudRate := StrToBaudRate(ComComboBox2.Text);
        MainForm.Serial.DataBits := StrToDataBits(ComComboBox3.Text);
        MainForm.Serial.StopBits := StrToStopBits(ComComboBox4.Text);
        MainForm.Serial.Parity := StrToParity(ComComboBox5.Text);
        MainForm.Serial.FlowCOntrol := StrToFlowControl(ComComboBox6.Text);
        MainForm.StatusBarLeft.Panels[1].Text := MainForm.Serial.Device;

        checkinterval := StrToInt(DelayEdit.Text);
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
        astage := ComboBoxAStage.Text;
        if astage = '' then
          astage := '1';
        //эта дичь определяет был ли переход от работы с одним этапом на несколько
        if (stages.ActiveStagesCount = 1) and
          (CheckGroup1.Checked[1] or CheckGroup1.Checked[2] or
          CheckGroup1.Checked[3] or CheckGroup1.Checked[4] or
          CheckGroup1.Checked[5]) then
          //для того, чтобы освободить место для таблицы с вводом поправки
          //без этого в текущей организации GUI были коллизии
          MainForm.Splitter1.Top := MainForm.Splitter1.Top + MainForm.CurrentSU.Height;
        //сохраняем статус СУ (вкл/выкл) и его название
        for i := 1 to maxstages do
        begin
          if CheckGroup1.Checked[i - 1] then
            stages[i].isActive := True
          else
            stages[i].isActive := False;
          stages[i].Name := (FindComponent('SUEdit' + IntToStr(i)) as TEdit).Text;
        end;
        for i := 1 to visiblecat do
        begin
          //сохраняем название категорий, которые будут выводиться на окно результатов
          cat[i] := (FindComponent('Edit' + IntToStr(i)) as TComboBox).Text;
        end;

        zerohour := CheckBoxHideZeroHour.Checked;
        showStageNameForSingleStage := CheckBoxShowStageName.Checked;
        ledpaneladress := LEDAdress.Text;
        telegrambotadress := TelegramBotAdressEdit.Text;
        MainForm.DataPortHTTP1.Url := 'http://' + ledpaneladress + '/post';

        if dbopen then
        begin
          with MainForm.SQLQuery1 do
          begin
            SQL.Clear;
            SQL.Add('INSERT INTO config (key, value) VALUES');
            SQL.Add('("racename", :RACENAME),');
            ParamByName('RACENAME').AsString := raceName;
            for i := 1 to visiblecat do
            begin
              SQL.Add('("catname' + IntToStr(i) + '", "' + cat[i] + '"),');
            end;
            for i := 1 to maxstages do
            begin
              SQL.Add('("stage' + IntToStr(i) + '", "' +
                BoolToStr(stages[i].isActive, True) + '"),');
              SQL.Add('("stagename' + IntToStr(i) + '", "' + stages[i].Name + '"),');
            end;
            SQL.Add('("activestage", "' + astage + '")');
            //SQL.Add('("timemark", "'+timemark+'"),');
            //SQL.Add('("timemarkstr", "'+timemarkstr+'"),');
            //SQL.Add('("timemarkformat", "'+timemarkformat+'")');
            SQL.Add('ON CONFLICT(key) DO UPDATE SET value = excluded.value;');
            ExecSQL;
            SQLTransaction.Commit;
            Close;
          end;
        end;
        LoadConfig;
        LoadIniCategory;
        if dbopen then
        begin
          //пересчитываем глобальный статус у тех, у кого он был, в связи с возможным изменением количества активных СУ
          RecalculateStatus(GetAllStageStatus(0));
          UpdateResults;
        end;
        Log(rsShownCategories + ' ' + cat[1] + ', ' + cat[2] + ', ' +
          cat[3] + ', ' + cat[4] + ', ' + cat[5] + ', ' + cat[6]);
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
  i: integer;
  s: string;
begin
  s := ComboBoxAStage.Text;
  ComboBoxAStage.Items.Clear;
  for i := 1 to maxstages do
  begin
    if CheckGroup1.Checked[i - 1] then
    begin
      ComboBoxAStage.Items.Add(IntToStr(i));
    end;
  end;
  ComboBoxAStage.Text := s;
end;

procedure TSettingsForm.ButtonLEDTestClick(Sender: TObject);
begin
  MainForm.DataPortHTTP1.Close();
  ledpaneladress := LEDAdress.Text;
  MainForm.DataPortHTTP1.Url := 'http://' + ledpaneladress + '/post';
  MainForm.DataPortHTTP1.Params.Clear;
  if not string(LEDSingleline.Text).IsEmpty then
  begin
    Print(LEDSingleline.Text);
    MainForm.DataPortHTTP1.Params.Add('singleline=' + LEDSingleline.Text);
  end
  else
  begin
    Print(LEDUpperline.Text);
    Print(LEDBottomline.Text);
    MainForm.DataPortHTTP1.Params.Add('upperline=' + LEDUpperline.Text);
    MainForm.DataPortHTTP1.Params.Add('bottomline=' + LEDBottomline.Text);
  end;
  Print(MainForm.DataPortHTTP1.Params.Text);
  MainForm.DataPortHTTP1.Open();
  MainForm.DataPortHTTP1.Push('');
end;

procedure TSettingsForm.ButtonTelegramTestClick(Sender: TObject);
var
  QueryParams: TStrings = nil;
  AURL: string;
  s: string = '';
  item: string;
  l: TStringstream;
  http: tfphttpclient;
begin
  telegrambotadress := TelegramBotAdressEdit.Text;
  l := TStringStream.Create('');
  http := tfphttpclient.Create(nil);
  with http do
  try
    QueryParams := TStringList.Create;
    //AddHeader('Authorization', 'AccessToken MjtAFOrgYUrsfCC7KPLpAi03N4Od17Bh');
    //AddHeader('X-User-Authorization', 'Basic aW5mb0BzcG1hc2gucnU6NTE0NzU4');
    //AddHeader('Content-Type', 'text/html;charset=UTF-8');
    with QueryParams do
    begin
      if not string(TelegramNumber.Text).IsEmpty then
        Values['number'] := EncodeURLElement(TelegramNumber.Text);
      if not string(TelegramName.Text).IsEmpty then
        Values['name'] := EncodeURLElement(TelegramName.Text);
      if not string(TelegramCategory.Text).IsEmpty then
        Values['category'] := EncodeURLElement(TelegramCategory.Text);
      if not string(TelegramResult.Text).IsEmpty then
        Values['result'] := EncodeURLElement(TelegramResult.Text);
      if not string(TelegramDiff.Text).IsEmpty then
        Values['diff'] := EncodeURLElement(TelegramDiff.Text);
      if not string(TelegramPlace.Text).IsEmpty then
        Values['place'] := EncodeURLElement(TelegramPlace.Text);
    end;
    AURL := telegrambotadress;
    for item in QueryParams do
      s := s + '&' + item;
    AURL := AURL + '?' + s.Substring(1);

    try
      httpmethod('GET', AURL, l, []);
    except
      On E: Exception do
      begin
        Log(rsTelegramBotSendingError + E.Message);
      end;

    end;
    MainForm.Memo.Lines.Append(IntToStr(ResponseStatusCode) + ' ' +
      ResponseStatusText);
    MainForm.Memo.Lines.Append(ResponseHeaders.Text);
    MainForm.Memo.Lines.Append(l.DataString);

  finally
    MainForm.Memo.Lines.Append(AURL);
    Free;
    QueryParams.Free;
    l.Free;
  end;
end;

procedure TSettingsForm.CheckGroup1ItemClick(Sender: TObject; Index: integer);
var
  i: integer;
begin
  if not TryStrToInt(ComboBoxAStage.Text, i) then i := 1;
  if (not (Sender as TCheckGroup).Checked[i - 1]) or (i = 1) then
  begin
    ComboBoxAStage.Items.Clear;
    for i := 1 to maxstages do
    begin
      if CheckGroup1.Checked[i - 1] then
      begin
        ComboBoxAStage.Items.Add(IntToStr(i));
      end;
    end;
    if ComboBoxAStage.items.Count > 0 then
    begin
      ComboBoxAStage.Text := ComboBoxAStage.Items[0];
      ComboBoxAStage.Enabled := True;
    end
    else
    begin
      ComboBoxAStage.Items.Add('1');
      ComboBoxAStage.Text := '1';
      ComboBoxAStage.Enabled := False;
    end;
  end;
end;

procedure TSettingsForm.ComboBoxLanguageChange(Sender: TObject);
var
  lang: string = '';
  def: boolean = False;
begin
  if (Sender as TComboBox).Text = rsSystemDefault then
    def := True
  else if (Sender as TComboBox).Text = rsRussian then
    lang := 'ru'
  else if (Sender as TComboBox).Text = rsEnglish then
    lang := 'en';
  MainForm.SetLang(lang);
  (Sender as TComboBox).Items[0] := rsSystemDefault;
  if def then
  begin
    (Sender as TComboBox).Text := rsSystemDefault;
  end;
end;

procedure TSettingsForm.EditDropDown(Sender: TObject);
var
  i: integer;
begin
  if dbopen then
  begin
    (Sender as TComboBox).Items.Clear;
    with MainForm.SQLQuery1 do
    begin
      //в окно результатов и в конфиг БД
      Close;
      SQL.Text := 'SELECT category FROM main GROUP BY category';
      Open;
      for i := 1 to RecordCount do
      begin
        (Sender as TComboBox).Items.Add(Fields.Fields[0].AsString);
        Next;
      end;
      Close;
    end;
  end;
end;

end.
