unit ProtocolPrintForm;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, CheckLst, Spin, Dialogs,
  fpreportlclexport, CompetitionDbContext, StageModel,
  StageFinishReportBackend, ProtocolDocumentModel;

type
  TProtocolPrintForm = class(TForm)
    ParametersPanel, NavigationPanel, FooterPanel, SelectionPanel, TemplatePanel: TPanel;
    TemplateLabel: TLabel;
    TemplateCombo: TComboBox;
    BrowseTemplateButton: TButton;
    HeadingsCheck: TCheckBox;
    TemplateDialog: TOpenDialog;
    StageLabel, CategoryLabel, OrientationLabel, StateLabel, PageCountLabel: TLabel;
    StageCombo, OrientationCombo, ZoomCombo: TComboBox;
    IncompleteCheck, HeaderCheck, FooterCheck: TCheckBox;
    CategoriesList: TCheckListBox;
    AllButton, ClearButton, SaveButton, CloseButton: TButton;
    FirstButton, PreviousButton, NextButton, LastButton: TButton;
    PageSpin: TSpinEdit;
    PreviewScroll: TScrollBox;
    PageCanvas: TPaintBox;
    SaveDialog: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ParametersChange(Sender: TObject);
    procedure SelectionClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure BrowseTemplateClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure NavigateClick(Sender: TObject);
    procedure PageChange(Sender: TObject);
    procedure ZoomChange(Sender: TObject);
    procedure PaintPage(Sender: TObject);
  protected
    FContext: TCompetitionDbContext;
    FStages: TStages;
    FIdentity, FGeneration: QWord;
    FLanguage: TReportLanguage;
    FProtocol: TProtocolDocument;
    FDocument: TPreparedStageReport;
    FRenderer: TFPReportExportCanvas;
    FCategoryKeys: TReportCategories;
    FRendering, FBusy, FSessionClosed: boolean;
    FLastError: string;
    FTemplatePaths: TStringList;
    function ValidSession: boolean;
    function ViewOptions: TProtocolViewOptions;
    procedure FillCategoryKeys(const Keys: TReportCategories;
      const Selection: TProtocolViewOptions);
    procedure ConfigureSource(PreferredStage: integer); virtual;
    procedure ClearSource; virtual;
    procedure ProtocolTemplatePrepared(D: TProtocolDocument); virtual;
    function ReadProtocol(ReloadCategories: boolean): TProtocolReadOutcome;
      virtual; abstract;
    function DefaultFilePrefix: string; virtual; abstract;
    procedure ClearDocument;
    procedure Rebuild(const ReloadCategories: boolean);
    procedure UpdateState;
    procedure UpdateCanvas;
  public
    procedure Configure(const Context: TCompetitionDbContext;
      const Stages: TStages; const PreferredStage: integer;
      const Language: TReportLanguage; const TemplateDirectory: string = '');
    procedure EndSession;
    function SelectedStage: integer; virtual;
    function SaveTo(const Path: string): boolean;
    property Document: TPreparedStageReport read FDocument;
    property Protocol: TProtocolDocument read FProtocol;
    property LastError: string read FLastError;
  end;

implementation

uses Graphics, Math, i18n, InputDialogs, StageFinishReportBuilder,
  StageFinishPdfWriter, StageFinishDocxWriter, StageFinishXlsxWriter,
  ReportTemplateFiles, ReportPreview;
  {$R *.lfm}

procedure TProtocolPrintForm.ConfigureSource(PreferredStage: integer);
begin
end;

procedure TProtocolPrintForm.ClearSource;
begin
end;

procedure TProtocolPrintForm.ProtocolTemplatePrepared(D: TProtocolDocument);
begin
end;

procedure TProtocolPrintForm.FormCreate(Sender: TObject);
begin
  FTemplatePaths := TStringList.Create;
  TemplateLabel.Caption := rsPrintTemplate;
  BrowseTemplateButton.Caption := rsPrintBrowseTemplate;
  HeadingsCheck.Caption := rsPrintHeadings;
  HeadingsCheck.Hint := rsPrintHeadingsHint;
  FooterCheck.Hint := rsPrintFooterHint;
  TemplateDialog.Title := rsPrintChooseTemplate;
  TemplateDialog.Filter := rsPrintTemplateFilter;
  Caption := '';
  StageLabel.Caption := rsSU;
  CategoryLabel.Caption := rsPrintCategories;
  OrientationLabel.Caption := rsPrintOrientation;
  OrientationCombo.Items.Add(rsPrintPortrait);
  OrientationCombo.Items.Add(rsPrintLandscape);
  OrientationCombo.ItemIndex := 0;
  HeaderCheck.Caption := rsPrintHeader;
  HeaderCheck.Hint := rsPrintHeaderHint;
  FooterCheck.Caption := rsPrintFooter;
  AllButton.Caption := rsPrintAll;
  ClearButton.Caption := rsPrintNone;
  SaveButton.Caption := rsPrintSave;
  SaveDialog.Filter := 'PDF|*.pdf|DOCX|*.docx|XLSX|*.xlsx';
  SaveDialog.DefaultExt := '';
  SaveDialog.Options := SaveDialog.Options - [ofOverwritePrompt];
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
  StateLabel.Caption := '';
  UpdateState;
end;

procedure TProtocolPrintForm.FormDestroy(Sender: TObject);
begin
  FTemplatePaths.Free;
  FRenderer.Free;
  FDocument.Free;
  ClearSource;
  FProtocol.Free;
end;

function TProtocolPrintForm.ValidSession: boolean;
begin
  Result := not FSessionClosed and (FContext <> nil) and
    FContext.Connection.Connected and (FIdentity = FContext.Identity) and
    (FGeneration = FContext.SessionGeneration);
end;

procedure TProtocolPrintForm.EndSession;
begin
  FSessionClosed := True;
  UpdateState;
  ModalResult := mrCancel;
  if not (fsModal in FormState) then Close;
end;

procedure TProtocolPrintForm.Configure(const Context: TCompetitionDbContext;
  const Stages: TStages; const PreferredStage: integer;
  const Language: TReportLanguage; const TemplateDirectory: string);
var
  I: integer;
begin
  FContext := Context;
  FStages := Stages;
  FLanguage := Language;
  FIdentity := Context.Identity;
  FGeneration := Context.SessionGeneration;
  FRendering := True;
  try
    ListReportTemplates(TemplateDirectory, FTemplatePaths);
    TemplateCombo.Items.Clear;
    for I := 0 to FTemplatePaths.Count - 1 do
      TemplateCombo.Items.Add(ExtractFileName(FTemplatePaths[I]));
    FTemplatePaths.Insert(0, '');
    TemplateCombo.Items.Insert(0, rsPrintNoTemplate);
    TemplateCombo.ItemIndex := 0;
    ConfigureSource(PreferredStage);
  finally
    FRendering := False;
  end;
  Rebuild(True);
end;

procedure TProtocolPrintForm.FillCategoryKeys(const Keys: TReportCategories;
  const Selection: TProtocolViewOptions);
var
  I: integer;
  S, Selected: string;
  Checked: boolean;
begin
  FCategoryKeys := Copy(Keys);
  CategoriesList.Clear;
  for I := 0 to High(FCategoryKeys) do
  begin
    S := FCategoryKeys[I];
    if S = '' then S := ProtocolLabels(FLanguage).NoCategory;
    CategoriesList.Items.Add(S);
    Checked := Selection.AllCategories;
    for Selected in Selection.Categories do if Selected = FCategoryKeys[I] then
        Checked := True;
    CategoriesList.Checked[I] := Checked;
  end;
end;

procedure TProtocolPrintForm.ClearDocument;
begin
  FreeAndNil(FRenderer);
  FreeAndNil(FDocument);
  ClearSource;
  FreeAndNil(FProtocol);
  FRendering := True;
  try
    PageSpin.Value := 1;
    PageSpin.MaxValue := 1;
    PageCountLabel.Caption := '/ 0';
  finally
    FRendering := False;
  end;
  PageCanvas.Invalidate;
end;

function TProtocolPrintForm.SelectedStage: integer;
begin
  Result := StageCombo.ItemIndex + 1;
end;

procedure TProtocolPrintForm.UpdateState;
var
  Ready, Valid: boolean;
begin
  Valid := ValidSession;
  Ready := (FDocument <> nil) and not FBusy and Valid;
  SaveButton.Enabled := Ready;
  NavigationPanel.Enabled := Ready;
  FirstButton.Enabled := Ready and (PageSpin.Value > 1);
  PreviousButton.Enabled := FirstButton.Enabled;
  LastButton.Enabled := Ready and (PageSpin.Value < PageSpin.MaxValue);
  NextButton.Enabled := LastButton.Enabled;
  ParametersPanel.Enabled := Valid;
end;

procedure TProtocolPrintForm.ParametersChange(Sender: TObject);
begin
  if FRendering then Exit;
  Rebuild(False);
end;

procedure TProtocolPrintForm.SelectionClick(Sender: TObject);
var
  I: integer;
begin
  FRendering := True;
  try
    for I := 0 to CategoriesList.Count - 1 do
      CategoriesList.Checked[I] := Sender = AllButton;
  finally
    FRendering := False;
  end;
  ParametersChange(Sender);
end;

procedure TProtocolPrintForm.Rebuild(const ReloadCategories: boolean);
var
  R: TProtocolReadOutcome;
  D: TPreparedStageReport;
  O: TProtocolViewOptions;
begin
  if FBusy or not ValidSession then Exit;
  O := ViewOptions;
  ClearDocument;
  FLastError := '';
  if not O.AllCategories and (Length(O.Categories) = 0) then
  begin
    StateLabel.Caption := rsPrintEmpty;
    UpdateState;
    Exit;
  end;
  FBusy := True;
  UpdateState;
  R := Default(TProtocolReadOutcome);
  D := nil;
  try
    try
      R := ReadProtocol(ReloadCategories);
      case R.State of
        prsReady: begin
          if TemplateCombo.ItemIndex >= 0 then
            PrepareProtocolTemplate(R.Snapshot, FTemplatePaths[TemplateCombo.ItemIndex]);
          ProtocolTemplatePrepared(R.Snapshot);
          D := BuildProtocolReport(R.Snapshot);
          FDocument := D;
          D := nil;
          FProtocol := R.Snapshot;
          R.Snapshot := nil;
          FRenderer := TFPReportExportCanvas.Create(nil);
          FRenderer.Report := FDocument.Report;
          FRenderer.Canvas := PageCanvas.Canvas;
          FRenderer.HDPI := Screen.PixelsPerInch;
          FRenderer.VDPI := Screen.PixelsPerInch;
          FRenderer.Execute;
          FRendering := True;
          try
            PageSpin.MaxValue := FDocument.PageCount;
            PageSpin.Value := 1;
            PageCountLabel.Caption := '/ ' + IntToStr(FDocument.PageCount);
          finally
            FRendering := False;
          end;
          StateLabel.Caption := '';
          UpdateCanvas;
        end;
        prsEmpty: StateLabel.Caption := rsPrintEmpty;
        prsNoStages: StateLabel.Caption := rsOverallNoStages;
        prsBusy: begin
          FLastError := rsPrintBusy;
          StateLabel.Caption := FLastError;
        end;
        prsSessionChanged: EndSession;
        prsError: begin
          FLastError := Format(rsPrintError, [R.ErrorText]);
          StateLabel.Caption := FLastError;
        end;
      end;
    except
      on E: Exception do
      begin
        ClearDocument;
        FLastError := Format(rsPrintError, [E.Message]);
        StateLabel.Caption := FLastError;
      end;
    end;
  finally
    R.Snapshot.Free;
    D.Free;
    FBusy := False;
    UpdateState;
  end;
end;

function TProtocolPrintForm.SaveTo(const Path: string): boolean;
begin
  Result := False;
  if not ValidSession or FBusy or (FDocument = nil) then Exit;
  FBusy := True;
  UpdateState;
  try
    try
      if SameText(ExtractFileExt(Path), '.docx') then
        Result := SaveProtocolDocx(FProtocol, Path)
      else if SameText(ExtractFileExt(Path), '.xlsx') then
        Result := SaveProtocolXlsx(FProtocol, Path)
      else
        Result := SaveStageFinishPdf(FDocument, Path);
      FLastError := '';
      if Result then StateLabel.Caption := Format(rsPrintExported, [Path]);
    except
      on E: Exception do
      begin
        FLastError := Format(rsPrintSaveError, [E.Message]);
        StateLabel.Caption := FLastError;
      end;
    end;
  finally
    FBusy := False;
    UpdateState;
  end;
end;

procedure TProtocolPrintForm.BrowseTemplateClick(Sender: TObject);
var
  Path: string;
  Index: integer;
begin
  if not ValidSession or FBusy then Exit;
  if not TemplateDialog.Execute then Exit;
  if not ValidSession then Exit;
  Path := ExpandFileName(TemplateDialog.FileName);
  Index := FTemplatePaths.IndexOf(Path);
  FRendering := True;
  try
    if Index < 0 then
    begin
      Index := FTemplatePaths.Add(Path);
      TemplateCombo.Items.Add(Path);
    end;
    TemplateCombo.ItemIndex := Index;
  finally
    FRendering := False;
  end;
  Rebuild(False);
end;

procedure TProtocolPrintForm.CloseClick(Sender: TObject);
begin
  Close;
end;

procedure TProtocolPrintForm.SaveClick(Sender: TObject);
const
  Exts: array[1..3] of string = ('.pdf', '.docx', '.xlsx');
var
  Path, Ext: string;
begin
  if not SaveButton.Enabled then Exit;
  SaveDialog.FileName := DefaultFilePrefix + '-' + FormatDateTime(
    'yyyy-mm-dd_hhnn', FProtocol.FormedAt);
  if not SaveDialog.Execute then Exit;
  Path := SaveDialog.FileName;
  if Path = '' then Exit;
  Ext := ExtractFileExt(Path);
  if not SameText(Ext, '.pdf') and not SameText(Ext, '.docx') and not
    SameText(Ext, '.xlsx') then
    Path := Path + Exts[EnsureRange(SaveDialog.FilterIndex, 1, 3)];
  SaveDialog.FileName := Path;
  // Check the final path once, after resolving its extension, on every widgetset.
  if FileExists(Path) and (AskMessageDlg(rsFileExists, mtWarning, [mbOK, mbCancel], 0) <>
    mrOk) then Exit;
  SaveTo(Path);
end;

procedure TProtocolPrintForm.NavigateClick(Sender: TObject);
begin
  if FRenderer = nil then Exit;
  if Sender = FirstButton then PageSpin.Value := 1
  else if Sender = LastButton then PageSpin.Value := PageSpin.MaxValue
  else if Sender = NextButton then PageSpin.Value := PageSpin.Value + 1
  else
    PageSpin.Value := PageSpin.Value - 1;
end;

procedure TProtocolPrintForm.PageChange(Sender: TObject);
begin
  if FRendering or (FRenderer = nil) then Exit;
  FRenderer.PageIndex := EnsureRange(PageSpin.Value - 1, 0, FRenderer.PageCount - 1);
  UpdateCanvas;
  UpdateState;
end;

procedure TProtocolPrintForm.ZoomChange(Sender: TObject);
begin
  if not FRendering then UpdateCanvas;
end;

procedure TProtocolPrintForm.UpdateCanvas;
begin
  ResizeReportPreview(FRenderer, ZoomCombo.ItemIndex, PreviewScroll, PageCanvas);
end;

procedure TProtocolPrintForm.PaintPage(Sender: TObject);
begin
  PaintReportPreview(FRenderer, PageCanvas);
end;

function TProtocolPrintForm.ViewOptions: TProtocolViewOptions;
var
  I, N: integer;
begin
  Result := DefaultProtocolViewOptions;
  Result.StageIndex := SelectedStage;
  Result.Language := FLanguage;
  Result.IncludeMissing := IncompleteCheck.Checked;
  Result.ShowHeadings := HeadingsCheck.Checked;
  Result.ShowHeader := HeaderCheck.Checked;
  Result.ShowFooter := FooterCheck.Checked;
  if OrientationCombo.ItemIndex = 1 then Result.Orientation := roLandscape;
  Result.AllCategories := True;
  for I := 0 to CategoriesList.Count - 1 do if not CategoriesList.Checked[I] then
      Result.AllCategories := False;
  if Result.AllCategories then Exit;
  SetLength(Result.Categories, CategoriesList.Count);
  N := 0;
  for I := 0 to CategoriesList.Count - 1 do if CategoriesList.Checked[I] then
    begin
      Result.Categories[N] := FCategoryKeys[I];
      Inc(N);
    end;
  SetLength(Result.Categories, N);
end;

end.
