unit InputDialogs;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, Dialogs;

type
  TStartMarkStageChoice = (smscCancel, smscReceivedStage,
    smscCurrentStage);
  TMessageDlgHandler = function(const Msg: string; DlgType: TMsgDlgType;
    Buttons: TMsgDlgButtons; HelpCtx: longint): integer;
  TStageSelectionHandler = function(const ACaption, APrompt: string): integer;
  TStartMarkStageChoiceHandler = function(const ACaption, AMessage,
    AReceivedStageButton, ACurrentStageButton: string): TStartMarkStageChoice;

procedure SetMessageDlgHandler(AHandler: TMessageDlgHandler);
procedure ResetMessageDlgHandler;
function AskMessageDlg(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: longint): integer;
procedure SetStartMarkStageChoiceHandler(
  AHandler: TStartMarkStageChoiceHandler);
procedure ResetStartMarkStageChoiceHandler;
function AskStartMarkStageChoice(const ACaption, AMessage,
  AReceivedStageButton, ACurrentStageButton: string): TStartMarkStageChoice;
procedure SetStageSelectionHandler(AHandler: TStageSelectionHandler);
procedure ResetStageSelectionHandler;
function TryHandleStageSelection(const ACaption, APrompt: string;
  out AStageIndex: integer): boolean;

function MyDoInputCombo(const ACaption, APrompt: string;
  const AList: TStrings; AIndex: integer; AllowInput: boolean;
  out ASelected: integer; out ASelectedText: string): integer;
function InputDateTime(const ACaption, APrompt: string): TDateTime;

implementation

uses
  SysUtils, Controls, Forms, StdCtrls, ButtonPanel, DateTimePicker, Math,
  DateUtils;

var
  MessageDlgHandler: TMessageDlgHandler = nil;
  StartMarkStageChoiceHandler: TStartMarkStageChoiceHandler = nil;
  StageSelectionHandler: TStageSelectionHandler = nil;

procedure SetMessageDlgHandler(AHandler: TMessageDlgHandler);
begin
  MessageDlgHandler := AHandler;
end;

procedure SetStartMarkStageChoiceHandler(
  AHandler: TStartMarkStageChoiceHandler);
begin
  StartMarkStageChoiceHandler := AHandler;
end;

procedure ResetStartMarkStageChoiceHandler;
begin
  StartMarkStageChoiceHandler := nil;
end;

function AskStartMarkStageChoice(const ACaption, AMessage,
  AReceivedStageButton, ACurrentStageButton: string): TStartMarkStageChoice;
var
  DialogResult: TModalResult;
begin
  if Assigned(StartMarkStageChoiceHandler) then
    Exit(StartMarkStageChoiceHandler(ACaption, AMessage,
      AReceivedStageButton, ACurrentStageButton));

  DialogResult := QuestionDlg(ACaption, AMessage, mtWarning,
    [mrYes, AReceivedStageButton, 'IsDefault',
     mrNo, ACurrentStageButton,
     mrCancel, 'IsCancel'], 0);
  case DialogResult of
    mrYes: Result := smscReceivedStage;
    mrNo: Result := smscCurrentStage;
    else Result := smscCancel;
  end;
end;

procedure ResetMessageDlgHandler;
begin
  MessageDlgHandler := nil;
end;

function AskMessageDlg(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: longint): integer;
begin
  if Assigned(MessageDlgHandler) then
    Result := MessageDlgHandler(Msg, DlgType, Buttons, HelpCtx)
  else
    Result := MessageDlg(Msg, DlgType, Buttons, HelpCtx);
end;

procedure SetStageSelectionHandler(AHandler: TStageSelectionHandler);
begin
  StageSelectionHandler := AHandler;
end;

procedure ResetStageSelectionHandler;
begin
  StageSelectionHandler := nil;
end;

function TryHandleStageSelection(const ACaption, APrompt: string;
  out AStageIndex: integer): boolean;
begin
  Result := Assigned(StageSelectionHandler);
  if Result then
    AStageIndex := StageSelectionHandler(ACaption, APrompt);
end;

function MyDoInputCombo(const ACaption, APrompt: string;
  const AList: TStrings; AIndex: integer; AllowInput: boolean;
  out ASelected: integer; out ASelectedText: string): integer;
const
  CBStyles: array[boolean] of TComboBoxStyle = (csDropDownList, csDropDown);
var
  W, I, Sep, Margin, BW: integer;
  Frm: TForm;
  CBSelect: TComboBox;
  LPrompt: TLabel;
  BP: TButtonPanel;
begin
  Margin := 24;
  Sep := 8;
  Result := mrCancel;
  Frm := TForm.Create(Application);
  try
    BP := TButtonPanel.Create(Frm);
    BP.Parent := Frm;
    BP.ShowButtons := [pbOK, pbCancel];
    BW := Max(BP.OKButton.GetDefaultWidth, BP.OKButton.Width) +
      Max(BP.CancelButton.GetDefaultWidth, BP.CancelButton.Width);
    W := Frm.Canvas.TextWidth(APrompt);
    W := Max(W, Frm.Canvas.TextWidth(ACaption));
    for I := 0 to AList.Count - 1 do
      W := Max(W, Frm.Canvas.TextWidth(AList[I] + 'WWW'));
    Frm.BorderStyle := bsDialog;
    Frm.Caption := ACaption;
    Frm.ClientWidth := Max(W + 2 * Margin, BW + 3 * Sep);
    Frm.Position := poScreenCenter;

    LPrompt := TLabel.Create(Frm);
    LPrompt.Parent := Frm;
    LPrompt.Caption := APrompt;
    LPrompt.SetBounds(Margin, Margin, Frm.ClientWidth - 2 * Margin,
      Frm.Canvas.TextHeight(APrompt));
    LPrompt.WordWrap := True;
    LPrompt.AutoSize := False;

    CBSelect := TComboBox.Create(Frm);
    CBSelect.Parent := Frm;
    CBSelect.Style := CBStyles[AllowInput];
    CBSelect.Items.Assign(AList);
    CBSelect.ItemIndex := AIndex;
    CBSelect.Left := Margin;
    CBSelect.Top := LPrompt.Top + LPrompt.Height + Sep;
    CBSelect.Width := Frm.ClientWidth - 2 * Margin;

    Frm.ClientHeight := LPrompt.Height + CBSelect.Height + BP.Height +
      3 * Sep + Margin;
    Result := Frm.ShowModal;
    if Result = mrOk then
    begin
      ASelected := CBSelect.ItemIndex;
      ASelectedText := CBSelect.Text;
    end;
  finally
    FreeAndNil(Frm);
  end;
end;

function InputDateTime(const ACaption, APrompt: string): TDateTime;
var
  W, Sep, Margin: integer;
  Frm: TForm;
  LPrompt: TLabel;
  BP: TButtonPanel;
  DTPicker: TDateTimePicker;
begin
  Margin := 24;
  Sep := 8;
  Result := 0;
  Frm := TForm.Create(Application);
  try
    W := Frm.Canvas.TextWidth(APrompt);
    W := Max(W, Frm.Canvas.TextWidth(ACaption));
    Frm.BorderStyle := bsDialog;
    Frm.Caption := ACaption;
    Frm.ClientWidth := W + 2 * Margin;
    Frm.Position := poScreenCenter;

    LPrompt := TLabel.Create(Frm);
    LPrompt.Parent := Frm;
    LPrompt.Caption := APrompt;
    LPrompt.SetBounds(Margin, Margin, Frm.ClientWidth - 2 * Margin,
      Frm.Canvas.TextHeight(APrompt));
    LPrompt.WordWrap := True;
    LPrompt.AutoSize := False;

    DTPicker := TDateTimePicker.Create(Frm);
    DTPicker.Parent := Frm;
    DTPicker.Left := Margin;
    DTPicker.Top := LPrompt.Top + LPrompt.Height + Sep;
    DTPicker.Width := Frm.ClientWidth - 2 * Margin;
    DTPicker.Kind := dtkTime;
    DTPicker.Time := Now - SecondOf(Now) / 24 / 60 / 60;

    BP := TButtonPanel.Create(Frm);
    BP.Parent := Frm;
    BP.ShowButtons := [pbOK, pbCancel];
    Frm.ClientHeight := LPrompt.Height + DTPicker.Height + BP.Height +
      2 * Sep + Margin;
    if Frm.ShowModal = mrOk then
      Result := DTPicker.Time;
  finally
    FreeAndNil(Frm);
  end;
end;

end.
