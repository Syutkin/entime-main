unit StartLabelsPrintForm;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Spin,
  MySpinEdit, Dialogs, Menus,
  fpreportlclexport, CompetitionDbContext, StageModel, StartLabelModel,
  StartLabelReportBuilder, StartLabelTemplates, StartLabelTemplateStore;

type

  { TStartLabelsPrintForm }

  TStartLabelsPrintForm = class(TForm)
    NavigationPanel, FooterPanel, FooterActionsPanel, SettingsPanel: TPanel;
    TemplatePanel: TPanel;
    TemplateLabel: TLabel;
    TemplateCombo: TComboBox;
    TemplateMenuButton: TButton;
    TemplateMenu: TPopupMenu;
    SaveTemplateAsItem, SaveTemplateChangesItem: TMenuItem;
    ParametersScroll, PreviewScroll: TScrollBox;
    PaperGroup, MarginsGroup, GapsGroup, TextGroup: TGroupBox;
    WidthLabel, HeightLabel, LeftLabel, RightLabel, TopLabel,
    BottomLabel, GapXLabel, GapYLabel, PaddingLabel, FontLabel,
    MinFontLabel, FirstSlotLabel, StartColumnsLabel, GridLabel, StateLabel,
    PageCountLabel: TLabel;
    LeftEdit, RightEdit, TopEdit, BottomEdit, GapXEdit, GapYEdit,
    PaddingEdit, WidthEdit, HeightEdit: TMyFloatSpinEdit;
    FontEdit, MinFontEdit, FirstSlotEdit: TMySpinEdit;
    PageSpin: TSpinEdit;
    BordersCheck: TCheckBox;
    FirstButton, PreviousButton, NextButton, LastButton, SaveButton,
    CloseButton: TButton;
    ZoomCombo, StartColumnsCombo: TComboBox;
    PageCanvas: TPaintBox;
    SaveDialog: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TemplateChange(Sender: TObject);
    procedure TemplateMenuClick(Sender: TObject);
    procedure SaveTemplateAsClick(Sender: TObject);
    procedure SaveTemplateChangesClick(Sender: TObject);
    procedure ParametersChange(Sender: TObject);
    procedure NavigateClick(Sender: TObject);
    procedure PageChange(Sender: TObject);
    procedure ZoomChange(Sender: TObject);
    procedure PaintPage(Sender: TObject);
    procedure ViewResize(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  private
    FTemplateStore: TStartLabelTemplateStore;
    FTemplateEntries: TStartLabelTemplateFiles;
    FTemplate: TStartLabelTemplate;
    FContext: TCompetitionDbContext;
    FIdentity, FGeneration: QWord;
    FIniName, FLastError: string;
    FCards: TStartLabelCards;
    FPaper: TStartLabelPaper;
    FDocument: TStartLabelReport;
    FRenderer: TFPReportExportCanvas;
    FUpdating, FClosed: boolean;
    FFormedAt: TDateTime;
    procedure RefreshTemplateList;
    procedure UpdateTemplateState;
    procedure SaveTemplateChoice;
    function ValidSession: boolean;
    function ReadPaper(out P: TStartLabelPaper): boolean;
    procedure FillPaper(const P: TStartLabelPaper);
    procedure ClearDocument;
    procedure Rebuild;
    procedure UpdateState;
    procedure UpdateCanvas;
  public
    procedure Configure(Context: TCompetitionDbContext; Stages: TStages;
      const IniName: string; const TemplateDirectory: string = '');
    procedure EndSession;
    function SaveTo(const Path: string): boolean;
    property Document: TStartLabelReport read FDocument;
    property Cards: TStartLabelCards read FCards;
    property Paper: TStartLabelPaper read FPaper;
    property LastError: string read FLastError;
  end;

implementation

uses Math, i18n, InputDialogs, StartLabelService, StartLabelSettings,
  ProtocolDocumentModel, StageFinishPdfWriter, ReportPreview, IniFiles;
  {$R *.lfm}

procedure TStartLabelsPrintForm.TemplateMenuClick(Sender: TObject);
begin
  TemplateMenu.PopUp;
end;

procedure TStartLabelsPrintForm.SaveTemplateAsClick(Sender: TObject);
var
  TemplateName: string;
  P: TStartLabelPaper;
begin
  if not ValidSession or not SaveTemplateAsItem.Enabled then Exit;
  TemplateName := '';
  if not InputQuery(rsLabelTemplateSaveAs, rsLabelTemplateName, TemplateName) then Exit;
  if not ValidSession then Exit;
  try
    if not ReadPaper(P) then raise EStartLabelTemplate.Create(rsLabelIncomplete);
    FTemplate := FTemplateStore.CreateTemplate(TemplateName, P);
    SaveTemplateChoice;
    RefreshTemplateList;
  except
    on E: Exception do AskMessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TStartLabelsPrintForm.SaveTemplateChangesClick(Sender: TObject);
var
  P: TStartLabelPaper;
begin
  if not ValidSession or not SaveTemplateChangesItem.Enabled then Exit;
  try
    if not ReadPaper(P) then raise EStartLabelTemplate.Create(rsLabelIncomplete);
    FTemplate := FTemplateStore.Save(FTemplate.FileName, P);
    SaveTemplateChoice;
    RefreshTemplateList;
  except
    on E: Exception do AskMessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TStartLabelsPrintForm.SaveTemplateChoice;
var
  Ini: TMemIniFile;
begin
  if FIniName = '' then Exit;
  Ini := TMemIniFile.Create(FIniName);
  try
    Ini.WriteString('StartLabels', 'TemplateFile', FTemplate.FileName);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

procedure TStartLabelsPrintForm.RefreshTemplateList;
var
  WasUpdating: boolean;
  I: integer;
begin
  WasUpdating := FUpdating;
  FUpdating := True;
  try
    FTemplateEntries := FTemplateStore.List;
    TemplateCombo.Items.Clear;
    TemplateCombo.Items.Add(rsLabelCurrentSettings);
    for I := 0 to High(FTemplateEntries) do
      TemplateCombo.Items.Add(FTemplateEntries[I].Name);
  finally
    FUpdating := WasUpdating;
  end;
  UpdateTemplateState;
end;

procedure TStartLabelsPrintForm.UpdateTemplateState;
var
  I, J, Index: integer;
  CaptionText: string;
  P: TStartLabelPaper;
  WasUpdating, Readable: boolean;
  G: TStartLabelGrid;
begin
  SaveTemplateAsItem.Enabled := False;
  SaveTemplateChangesItem.Enabled := False;
  TemplateMenuButton.Enabled := ValidSession and (Length(FCards) > 0);
  if FTemplateStore = nil then Exit;
  Readable := ReadPaper(P);
  if Readable then
  begin
    P.FirstSlot := 1;
    Readable := CheckStartLabelPaper(P, G) = lpeNone;
  end;
  SaveTemplateAsItem.Enabled := TemplateMenuButton.Enabled and Readable;
  SaveTemplateChangesItem.Enabled :=
    SaveTemplateAsItem.Enabled and (FTemplate.FileName <> '') and not
    SameStartLabelTemplatePaper(P, FTemplate.Paper);
  WasUpdating := FUpdating;
  FUpdating := True;
  try
    Index := 0;
    for I := 0 to High(FTemplateEntries) do
    begin
      CaptionText := FTemplateEntries[I].Name;
      if FTemplateEntries[I].FileName = FTemplate.FileName then
      begin
        CaptionText := FTemplate.Name;
        Index := I + 1;
      end;
      for J := 0 to High(FTemplateEntries) do
        if (I <> J) and (FTemplateEntries[J].Name = CaptionText) then
        begin
          CaptionText := CaptionText + ' (' + FTemplateEntries[I].FileName + ')';
          Break;
        end;
      if (I + 1 = Index) and (not ReadPaper(P) or not
        SameStartLabelTemplatePaper(P, FTemplate.Paper)) then
        CaptionText := CaptionText + ' *';
      TemplateCombo.Items[I + 1] := CaptionText;
    end;
    TemplateCombo.ItemIndex := Index;
  finally
    FUpdating := WasUpdating;
  end;
end;

procedure TStartLabelsPrintForm.TemplateChange(Sender: TObject);
var
  Chosen: TStartLabelTemplate;
  Index: integer;
begin
  if FUpdating or not ValidSession then Exit;
  Index := TemplateCombo.ItemIndex;
  try
    if Index = 0 then
    begin
      FTemplate := Default(TStartLabelTemplate);
      SaveTemplateChoice;
      UpdateTemplateState;
      Exit;
    end;
    if (Index < 1) or (Index > Length(FTemplateEntries)) then Exit;
    try
      Chosen := FTemplateStore.Load(FTemplateEntries[Index - 1].FileName);
    except
      on E: EStartLabelTemplateMissing do
      begin
        FTemplate := Default(TStartLabelTemplate);
        SaveTemplateChoice;
        RefreshTemplateList;
        Exit;
      end;
    end;
    FTemplate := Chosen;
    FillPaper(Chosen.Paper);
    Rebuild;
    SaveTemplateChoice;
    RefreshTemplateList;
  except
    on E: Exception do
    begin
      UpdateTemplateState;
      AskMessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TStartLabelsPrintForm.FormCreate(Sender: TObject);
begin
  Caption := rsStartLabels;
  TemplateLabel.Caption := rsLabelTemplateLabel;
  SaveTemplateAsItem.Caption := rsLabelTemplateSaveAs;
  SaveTemplateChangesItem.Caption := rsLabelTemplateSaveChanges;
  TemplateMenuButton.Hint := rsLabelTemplateActions;
  TemplateMenuButton.ShowHint := True;
  PaperGroup.Caption := rsLabelPaper;
  MarginsGroup.Caption := rsLabelMargins;
  GapsGroup.Caption := rsLabelGaps;
  TextGroup.Caption := rsLabelContents;
  WidthLabel.Caption := rsLabelWidth;
  HeightLabel.Caption := rsLabelHeight;
  LeftLabel.Caption := rsLabelLeft;
  RightLabel.Caption := rsLabelRight;
  TopLabel.Caption := rsLabelTop;
  BottomLabel.Caption := rsLabelBottom;
  GapXLabel.Caption := rsLabelGapX;
  GapYLabel.Caption := rsLabelGapY;
  PaddingLabel.Caption := rsLabelPadding;
  FontLabel.Caption := rsLabelFont;
  MinFontLabel.Caption := rsLabelMinFont;
  FirstSlotLabel.Caption := rsLabelFirst;
  StartColumnsLabel.Caption := rsLabelStartColumns;
  BordersCheck.Caption := rsLabelBorders;
  MarginsGroup.Hint := rsLabelMarginsHint;
  MarginsGroup.ShowHint := True;
  FirstSlotEdit.Hint := rsLabelFirstHint;
  FirstSlotEdit.ShowHint := True;
  SaveButton.Hint := rsLabelPrintHint;
  SaveButton.Caption := rsLabelSavePdf;
  CloseButton.Caption := rsCardClose;
  FirstButton.Hint := rsPrintFirst;
  PreviousButton.Hint := rsPrintPrevious;
  NextButton.Hint := rsPrintNext;
  LastButton.Hint := rsPrintLast;
  ZoomCombo.Items.Add(rsPrintFit);
  ZoomCombo.Items.Add('50%');
  ZoomCombo.Items.Add('75%');
  ZoomCombo.Items.Add('100%');
  ZoomCombo.Items.Add('125%');
  ZoomCombo.Items.Add('150%');
  ZoomCombo.Items.Add('200%');
  ZoomCombo.ItemIndex := 0;
  SaveDialog.Options := SaveDialog.Options - [ofOverwritePrompt];
  FPaper := DefaultStartLabelPaper;
  FillPaper(FPaper);
  UpdateState;
end;

procedure TStartLabelsPrintForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FTemplateStore);
  FreeAndNil(FRenderer);
  FreeAndNil(FDocument);
end;

function TStartLabelsPrintForm.ValidSession: boolean;
begin
  Result := not FClosed and (FContext <> nil) and FContext.Connection.Connected and
    (FIdentity = FContext.Identity) and (FGeneration = FContext.SessionGeneration);
end;

function TStartLabelsPrintForm.ReadPaper(out P: TStartLabelPaper): boolean;

  function MM(E: TFloatSpinEdit; out Value: integer): boolean;
  var
    V: double;
  begin
    Result := TryStrToFloat(Trim(E.Text), V);
    if Result then Result := not IsNan(V) and not IsInfinite(V) and (Abs(V) <= 10000);
    if Result then Value := Round(V * StartLabelUnitsPerMM);
  end;

  function Int(E: TSpinEdit; out Value: integer): boolean;
  begin
    Result := TryStrToInt(Trim(E.Text), Value);
  end;

begin
  P := Default(TStartLabelPaper);
  Result := MM(WidthEdit, P.Width) and MM(HeightEdit, P.Height) and
    MM(LeftEdit, P.Left) and MM(RightEdit, P.Right) and MM(TopEdit, P.Top) and
    MM(BottomEdit, P.Bottom) and MM(GapXEdit, P.GapX) and MM(GapYEdit, P.GapY) and
    MM(PaddingEdit, P.Padding) and Int(FontEdit, P.FontSize) and
    Int(MinFontEdit, P.MinFontSize) and Int(FirstSlotEdit, P.FirstSlot) and
    (StartColumnsCombo.ItemIndex in [0, 1]);
  P.StartColumns := StartColumnsCombo.ItemIndex + 1;
  P.DrawBorders := BordersCheck.Checked;
end;

procedure TStartLabelsPrintForm.FillPaper(const P: TStartLabelPaper);
var
  WasUpdating: boolean;
begin
  WasUpdating := FUpdating;
  FUpdating := True;
  try
    WidthEdit.Value := P.Width / StartLabelUnitsPerMM;
    HeightEdit.Value := P.Height / StartLabelUnitsPerMM;
    LeftEdit.Value := P.Left / StartLabelUnitsPerMM;
    RightEdit.Value := P.Right / StartLabelUnitsPerMM;
    TopEdit.Value := P.Top / StartLabelUnitsPerMM;
    BottomEdit.Value := P.Bottom / StartLabelUnitsPerMM;
    GapXEdit.Value := P.GapX / StartLabelUnitsPerMM;
    GapYEdit.Value := P.GapY / StartLabelUnitsPerMM;
    PaddingEdit.Value := P.Padding / StartLabelUnitsPerMM;
    MinFontEdit.Value := P.MinFontSize;
    FontEdit.MinValue := MinFontEdit.Value;
    FontEdit.Value := P.FontSize;
    FirstSlotEdit.Value := P.FirstSlot;
    StartColumnsCombo.ItemIndex := P.StartColumns - 1;
    BordersCheck.Checked := P.DrawBorders;
  finally
    FUpdating := WasUpdating;
  end;
end;

procedure TStartLabelsPrintForm.ClearDocument;
begin
  FreeAndNil(FRenderer);
  FreeAndNil(FDocument);
  PageSpin.Value := 1;
  PageSpin.MaxValue := 1;
  PageCountLabel.Caption := '/ 0';
  GridLabel.Caption := '';
  PageCanvas.Invalidate;
end;

procedure TStartLabelsPrintForm.UpdateState;
var
  Ready: boolean;
begin
  Ready := ValidSession and (FDocument <> nil);
  SaveButton.Enabled := Ready and (FDocument.OverflowCount = 0);
  NavigationPanel.Enabled := Ready;
  FirstButton.Enabled := Ready and (PageSpin.Value > 1);
  PreviousButton.Enabled := FirstButton.Enabled;
  LastButton.Enabled := Ready and (PageSpin.Value < PageSpin.MaxValue);
  NextButton.Enabled := LastButton.Enabled;
  ParametersScroll.Enabled := ValidSession and (Length(FCards) > 0);
  UpdateTemplateState;
end;

procedure TStartLabelsPrintForm.Rebuild;
var
  P: TStartLabelPaper;
  G: TStartLabelGrid;
  E: TStartLabelPaperError;
  ResetFirst: boolean;
  SettingsError: string;
begin
  if FUpdating then Exit;
  if not ValidSession then
  begin
    EndSession;
    Exit;
  end;
  if Length(FCards) = 0 then Exit;
  if (FDocument <> nil) and ReadPaper(P) and SameStartLabelPaper(P, FPaper) then Exit;
  FUpdating := True;
  try
    try
      ClearDocument;
      FLastError := '';
      StateLabel.Caption := '';
      if not ReadPaper(P) then
      begin
        FLastError := rsLabelIncomplete;
        Exit;
      end;
      E := CheckStartLabelPaper(P, G);
      ResetFirst := E = lpeFirstSlot;
      if ResetFirst then
      begin
        P.FirstSlot := 1;
        FirstSlotEdit.Value := 1;
        E := CheckStartLabelPaper(P, G);
      end;
      case E of
        lpeNone: ;
        lpeSize: FLastError := rsLabelInvalidSize;
        lpeMargins: FLastError := rsLabelInvalidMargins;
        lpeGaps: FLastError := rsLabelInvalidGaps;
        lpePadding: FLastError := rsLabelInvalidPadding;
        lpeFont: FLastError := rsLabelInvalidFont;
        lpeNoSpace: FLastError := rsLabelNoSpace;
        else
          FLastError := rsLabelIncomplete;
      end;
      if E <> lpeNone then Exit;
      FPaper := P;
      SettingsError := '';
      try
        SaveStartLabelPaper(FIniName, FPaper);
      except
        on Ex: Exception do SettingsError := Format(rsLabelSettingsError, [Ex.Message]);
      end;
      FDocument := BuildStartLabelReport(FCards, FPaper, True);
      FRenderer := TFPReportExportCanvas.Create(nil);
      FRenderer.Report := FDocument.Report;
      FRenderer.Canvas := PageCanvas.Canvas;
      FRenderer.HDPI := Screen.PixelsPerInch;
      FRenderer.VDPI := Screen.PixelsPerInch;
      FRenderer.Execute;
      PageSpin.MaxValue := FDocument.PageCount;
      PageSpin.Value := 1;
      PageCountLabel.Caption := '/ ' + IntToStr(FDocument.PageCount);
      GridLabel.Caption := Format(rsLabelGrid, [G.Columns, G.Rows, G.Capacity]);
      StateLabel.Caption := Format(rsLabelReady,
        [Length(FCards), FDocument.PageCount, FDocument.TableFontSize]);
      if ResetFirst then StateLabel.Caption :=
          rsLabelFirstReset + ' ' + StateLabel.Caption;
      if FDocument.OverflowCount > 0 then
        FLastError := Format(rsLabelOverflow, [FDocument.OverflowCount]);
      if SettingsError <> '' then
      begin
        FLastError := SettingsError;
        StateLabel.Caption := SettingsError;
      end;
    except
      on Ex: EStartLabelsDoNotFit do
      begin
        ClearDocument;
        FLastError := Format(rsLabelOverflow, [Ex.Count]);
      end;
      on Ex: Exception do
      begin
        ClearDocument;
        FLastError := Format(rsLabelBuildError, [Ex.Message]);
      end;
    end;
  finally
    FUpdating := False;
    if FLastError <> '' then StateLabel.Caption := FLastError;
    if (FDocument <> nil) and (FDocument.TableFontSize < FPaper.FontSize) then
      StateLabel.Caption := StateLabel.Caption + ' ' +
        Format(rsLabelFontReduced, [FPaper.FontSize, FDocument.TableFontSize]);
    UpdateCanvas;
    UpdateState;
  end;
end;

procedure TStartLabelsPrintForm.Configure(Context: TCompetitionDbContext;
  Stages: TStages; const IniName: string; const TemplateDirectory: string);
var
  R: TStartLabelReadOutcome;
  Ini: TMemIniFile;
  TemplateFile: string;
begin
  FUpdating := True;
  try
    ClearDocument;
    FreeAndNil(FTemplateStore);
    FTemplateStore := TStartLabelTemplateStore.Create(TemplateDirectory);
    FTemplate := Default(TStartLabelTemplate);
    FCards := nil;
    FClosed := False;
    FLastError := '';
    FContext := Context;
    FIniName := IniName;
    FIdentity := 0;
    FGeneration := 0;
    if Context <> nil then
    begin
      FIdentity := Context.Identity;
      FGeneration := Context.SessionGeneration;
    end;
    FPaper := LoadStartLabelPaper(FIniName);
    FillPaper(FPaper);
    if FIniName <> '' then
    begin
      Ini := TMemIniFile.Create(FIniName);
      try
        TemplateFile := Ini.ReadString('StartLabels', 'TemplateFile', '');
      finally
        Ini.Free;
      end;
      if TemplateFile <> '' then
      try
        FTemplate := FTemplateStore.Load(TemplateFile);
      except
        on E: EStartLabelTemplateMissing do
        begin
          FTemplate := Default(TStartLabelTemplate);
          SaveTemplateChoice;
        end;
        on E: Exception do FTemplate := Default(TStartLabelTemplate);
      end;
    end;
    RefreshTemplateList;
    R := TStartLabelService.Read(Context, Stages, Now, FIdentity, FGeneration);
    FCards := R.Cards;
    FFormedAt := R.FormedAt;
    case R.State of
      prsReady: StateLabel.Caption := '';
      prsEmpty: FLastError := rsLabelEmpty;
      prsNoStages: FLastError := rsOverallNoStages;
      prsBusy: FLastError := rsPrintBusy;
      prsSessionChanged: FClosed := True;
      prsError: FLastError := Format(rsLabelBuildError, [R.ErrorText]);
    end;
    StateLabel.Caption := FLastError;
  finally
    FUpdating := False;
  end;
  Rebuild;
  UpdateState;
end;

procedure TStartLabelsPrintForm.EndSession;
begin
  FClosed := True;
  UpdateState;
  ModalResult := mrCancel;
  if not (fsModal in FormState) then Close;
end;

function TStartLabelsPrintForm.SaveTo(const Path: string): boolean;
begin
  Result := False;
  if not ValidSession then
  begin
    EndSession;
    Exit;
  end;
  if (FDocument = nil) or (Path = '') then Exit;
  if FDocument.OverflowCount > 0 then Exit;
  try
    Result := SaveStageFinishPdf(FDocument, Path);
    if Result then
    begin
      FLastError := '';
      StateLabel.Caption := Format(rsLabelSaved, [Path]);
    end;
  except
    on Ex: Exception do
    begin
      FLastError := Format(rsLabelSaveError, [Ex.Message]);
      StateLabel.Caption := FLastError;
    end;
  end;
end;

procedure TStartLabelsPrintForm.ParametersChange(Sender: TObject);
begin
  if FUpdating then Exit;
  FontEdit.MinValue := MinFontEdit.Value;
  Rebuild;
end;

procedure TStartLabelsPrintForm.NavigateClick(Sender: TObject);
begin
  if FRenderer = nil then Exit;
  if Sender = FirstButton then PageSpin.Value := 1
  else if Sender = LastButton then PageSpin.Value := PageSpin.MaxValue
  else if Sender = NextButton then PageSpin.Value := PageSpin.Value + 1
  else
    PageSpin.Value := PageSpin.Value - 1;
end;

procedure TStartLabelsPrintForm.PageChange(Sender: TObject);
begin
  if FUpdating or (FRenderer = nil) then Exit;
  FRenderer.PageIndex := EnsureRange(PageSpin.Value - 1, 0, FRenderer.PageCount - 1);
  UpdateCanvas;
  UpdateState;
end;

procedure TStartLabelsPrintForm.ZoomChange(Sender: TObject);
begin
  if not FUpdating then UpdateCanvas;
end;

procedure TStartLabelsPrintForm.UpdateCanvas;
begin
  ResizeReportPreview(FRenderer, ZoomCombo.ItemIndex, PreviewScroll, PageCanvas);
end;

procedure TStartLabelsPrintForm.PaintPage(Sender: TObject);
begin
  PaintReportPreview(FRenderer, PageCanvas);
end;

procedure TStartLabelsPrintForm.ViewResize(Sender: TObject);
begin
  if not FUpdating then UpdateCanvas;
end;

procedure TStartLabelsPrintForm.SaveClick(Sender: TObject);
var
  Path: string;
begin
  if not SaveButton.Enabled then Exit;
  SaveDialog.FileName := 'start-labels-' + FormatDateTime(
    'yyyy-mm-dd_hhnn', FFormedAt) + '.pdf';
  if not SaveDialog.Execute then Exit;
  Path := SaveDialog.FileName;
  if Path = '' then Exit;
  if not SameText(ExtractFileExt(Path), '.pdf') then Path := Path + '.pdf';
  if FileExists(Path) and (AskMessageDlg(rsFileExists, mtWarning, [mbOK, mbCancel], 0) <>
    mrOk) then Exit;
  SaveTo(Path);
end;

procedure TStartLabelsPrintForm.CloseClick(Sender: TObject);
begin
  Close;
end;

end.
