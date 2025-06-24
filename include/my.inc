{
 *****************************************************************************
 Форки стандартных компонентов
 
 *****************************************************************************
}

function MyDoInputCombo(const ACaption, APrompt: string; const AList: TStrings;
  AIndex: integer; AllowInput: boolean; Out ASelected: integer;
  Out ASelectedText: string): integer;
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
  //ASelected := -1;
  Frm := TForm.Create(Application);
  try
    // Buttons
    BP := TButtonPanel.Create(Frm);
    BP.Parent := Frm;
    BP.ShowButtons := [pbOK, pbCancel];
    // Determine needed width
    BW := Max(BP.OKButton.GetDefaultWidth, BP.OKButton.Width) +
      Max(BP.CancelButton.GetDefaultWidth, BP.CancelButton.Width);
    W := frm.Canvas.TextWidth(APrompt);
    W := Max(W, frm.Canvas.TextWidth(ACaption));
    for I := 0 to AList.Count - 1 do
      W := Max(W, frm.Canvas.TextWidth(AList[i] + 'WWW')); // WWW is just some extra.
    frm.BorderStyle := bsDialog;
    frm.Caption := ACaption;
    frm.ClientWidth := Max(W + 2 * Margin, BW + 3 * Sep);
    frm.Position := poScreenCenter;
    // Prompt
    LPrompt := TLabel.Create(frm);
    LPrompt.Parent := frm;
    LPrompt.Caption := APrompt;
    LPrompt.SetBounds(Margin, Margin, Frm.ClientWidth - 2 * Margin,
      frm.Canvas.TextHeight(APrompt));
    LPrompt.WordWrap := True;
    LPrompt.AutoSize := False;
    // Selection combobox
    CBSelect := TComboBox.Create(Frm);
    CBSelect.Parent := Frm;
    CBSelect.Style := CBStyles[AllowInput];
    CBSelect.Items.Assign(AList);
    CBSelect.ItemIndex := AIndex;
    CBSelect.Left := Margin;
    CBSelect.Top := LPrompt.Top + LPrompt.Height + Sep;
    CBSelect.Width := Frm.ClientWidth - 2 * Margin;

    Frm.ClientHeight := LPrompt.Height + CBSelect.Height + BP.Height + 3 * Sep + Margin;
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

function MyInputCombo(const ACaption, APrompt: string; const AList: TStrings;
  AIndex: integer; out StageIndex: integer): integer;
var
  i, ASelected: integer;
  ASelectedText: string;
begin
  Result := MyDoInputCombo(ACaption, APrompt, AList, AIndex, False,
    ASelected, ASelectedText);
  if Result = mrOk then
  begin
    for i := 1 to MAXSTAGES do
    begin
      if stages[i].Name = ASelectedText then
      begin
        StageIndex := i;
        exit;
      end;
    end;
  end;
end;

function MyInputCombo(const ACaption, APrompt: string; const AList: array of string;
  AIndex: integer; out StageIndex: integer): integer;
var
  L: TStrings;
  S: string;
begin
  L := TStringList.Create;
  try
    for S in AList do
      L.Add(S);
    Result := MyInputCombo(ACaption, APrompt, L, AIndex, StageIndex);
  finally
    L.Free;
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
    // Determine needed width
    W := frm.Canvas.TextWidth(APrompt);
    W := Max(W, frm.Canvas.TextWidth(ACaption));
    frm.BorderStyle := bsDialog;
    frm.Caption := ACaption;
    frm.ClientWidth := W + 2 * Margin;
    frm.Position := poScreenCenter;
    // Prompt
    LPrompt := TLabel.Create(frm);
    LPrompt.Parent := frm;
    LPrompt.Caption := APrompt;
    LPrompt.SetBounds(Margin, Margin, Frm.ClientWidth - 2 * Margin,
      frm.Canvas.TextHeight(APrompt));
    LPrompt.WordWrap := True;
    LPrompt.AutoSize := False;
    // DateTime Picker
    DTPicker := TDateTimePicker.Create(Frm);
    DTPicker.Parent := Frm;
    DTPicker.Left := Margin;
    DTPicker.Top := LPrompt.Top + LPrompt.Height + Sep;
    DTPicker.Width := Frm.ClientWidth - 2 * Margin;
    DTPicker.Kind := dtkTime;
    DTPicker.Time := now - SecondOf(Now) / 24 / 60 / 60;
    // Buttons
    BP := TButtonPanel.Create(Frm);
    BP.Parent := Frm;
    BP.ShowButtons := [pbOK, pbCancel];
    Frm.ClientHeight := LPrompt.Height + DTPicker.Height + BP.Height + 2 * Sep + Margin;
    if (Frm.ShowModal = mrOk) then
    begin
      Result := DTPicker.Time;
    end;
  finally
    FreeAndNil(Frm);
  end;
end;
