unit Settings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  i18n, rxspin, LCLTranslator, Buttons, DBCtrls, ButtonPanel, ComCtrls, Spin,
  LazSerial, Lazsynaser, DividerBevel, CheckBoxThemed, translations;

type

  { TSettingsForm }

  TSettingsForm = class(TForm)
    ButtonPanel1: TButtonPanel;
    CheckBoxHideZeroHour: TCheckBoxThemed;
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
    Edit1: TComboBox;
    Edit2: TComboBox;
    Edit3: TComboBox;
    Edit4: TComboBox;
    Edit5: TComboBox;
    Edit6: TComboBox;
    EditCOMSetStr: TEdit;
    EditCOMSetTime: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Notebook1: TNotebook;
    Page1: TPage;
    Page2: TPage;
    Page3: TPage;
    Page4: TPage;
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
    TreeView1: TTreeView;
    procedure ComboBoxAStageDropDown(Sender: TObject);
    procedure ComboBoxLanguageChange(Sender: TObject);
    procedure EditDropDown(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Label1Click(Sender: TObject);
    procedure Page2BeforeShow(ASender: TObject; ANewPage: TPage; ANewIndex: Integer);
    procedure RunSettings;
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
  for i := 1 to maxstages do
  begin
    c := FindComponent('Edit' + IntToStr(i));
    TEdit(c).Text := cat[i];
    c := FindComponent('SUEdit' + IntToStr(i));
    TEdit(c).Text := sname[i];
  end;
  DelayEdit.Text := IntToStr(checkinterval);
  if lang = 'ru' then
    ComboBoxLanguage.Text := sRussian;
  if lang = 'en' then
    ComboBoxLanguage.Text := sEnglish;
  for i := 1 to maxstages do
    if stage[i] then
      CheckGroup1.Checked[i - 1] := True;

  CheckBoxHideZeroHour.Checked := zerohour;

  //if timemark = 'str' then RadioButtonCOMSetStr.Checked := true
  //else RadioButtonCOMSetTime.Checked := true;

  //EditCOMSetStr.Text := timemarkstr;
  //EditCOMSetTime.Text:= timemarkformat;

  ComboBoxAStage.Items.Add(astage);
  ComboBoxAStage.Text := astage;

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

procedure TSettingsForm.Page2BeforeShow(ASender: TObject; ANewPage: TPage; ANewIndex: Integer);
begin

end;

//разбить запись на процедуры?
procedure TSettingsForm.RunSettings;
var
  i: integer;
begin
  with TSettingsForm.Create(nil) do
  begin
    try
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
        if ComboBoxLanguage.Text = sRussian then
          lang := 'ru';
        if ComboBoxLanguage.Text = sEnglish then
          lang := 'en';

        //if RadioButtonCOMSetStr.Checked then timemark := 'str' else timemark := 'time';
        //timemarkstr := EditCOMSetStr.Text;
        //timemarkformat := EditCOMSetTime.Text;

        astage := ComboBoxAStage.Text;
        if astage = '' then
          astage := '1';
        //эта дичь определяет был ли переход от работы с одним этапом на несколько
        if (not stage[2]) and (not stage[3]) and (not stage[4]) and (not stage[5]) and
          (not stage[6]) and (CheckGroup1.Checked[1] or CheckGroup1.Checked[2] or
          CheckGroup1.Checked[3] or CheckGroup1.Checked[4] or CheckGroup1.Checked[5]) then
          //для того, чтобы освободить место для таблицы с вводом поправки
          //без этого в текущей организации GUI были коллизии
          MainForm.Splitter1.Top := MainForm.Splitter1.Top + MainForm.CurrentSU.Height;
        for i := 1 to maxstages do
          //сохраняем статус СУ (вкл/выкл) и его название
        begin
          if CheckGroup1.Checked[i - 1] then
            stage[i] := True
          else

            stage[i] := False;
          sname[i] := (FindComponent('SUEdit' + IntToStr(i)) as TEdit).Text;
        end;
        for i := 1 to visiblecat do
        begin
          //сохраняем название категорий, которые будут выводиться на окно результатов
          cat[i] := (FindComponent('Edit' + IntToStr(i)) as TComboBox).Text;
        end;

        zerohour := CheckBoxHideZeroHour.Checked;

        if dbopen then
        begin
          with MainForm.SQLQuery1 do
          begin
            SQL.Clear;
            SQL.Add('INSERT INTO config (key, value) VALUES');
            for i := 1 to visiblecat do
            begin
              SQL.Add('("catname' + IntToStr(i) + '", "' + cat[i] + '"),');
            end;
            for i := 1 to maxstages do
            begin
              SQL.Add('("stage' + IntToStr(i) + '", "' + BoolToStr(stage[i], True) + '"),');
              SQL.Add('("stagename' + IntToStr(i) + '", "' + sname[i] + '"),');
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
        LoadIni;
        LoadIniCategory;
        if dbopen then
        begin
          //пересчитываем глобальный статус у тех, у кого он был, в связи с возможным изменением количества активных СУ
          RecalculateStatus(GetAllStageStatus(0));
          UpdateResults;
        end;
        Log(sShownCategories + ' ' + cat[1] + ', ' + cat[2] + ', ' + cat[3] + ', ' +
          cat[4] + ', ' + cat[5] + ', ' + cat[6]);
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

procedure TSettingsForm.ComboBoxLanguageChange(Sender: TObject);
begin
  if ComboBoxLanguage.Text = sRussian then
  begin
    SetDefaultLang('ru');
    TranslateUnitResourceStrings('rxconst', 'languages/rxconst.ru.po');
  end;
  if ComboBoxLanguage.Text = sEnglish then
    SetDefaultLang('en');
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
