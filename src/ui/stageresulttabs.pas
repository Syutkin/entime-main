unit StageResultTabs;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, Controls, ComCtrls, DB, DBGrids,
  Graphics, SQLDB, rxdbgrid, DbSql;

type
  TStageResultView = class(TComponent)
  private
    FActive: boolean;
    FContext: TCompetitionDbContext;
    FDataSource: TDataSource;
    FGrid: TRxDBGrid;
    FQuery: TSQLQuery;
    FSheet: TTabSheet;
    FStageCount: integer;
    FStageIndex: integer;
    function AddColumn(const AFieldName, ATitle: string;
      const AWidth: integer; const AAlignment: TAlignment;
      const ABold: boolean = False): TRxColumn;
    function GetContentCreated: boolean;
    function GetDataSource: TDataSource;
    function GetGrid: TRxDBGrid;
    function GetQuery: TSQLQuery;
  public
    constructor Create(const APageControl: TPageControl;
      const AContext: TCompetitionDbContext;
      const AStageIndex, AStageCount: integer); reintroduce;
    procedure EnsureContent;
    procedure Configure(const ADisplayName: string; const AActive: boolean);
    property Active: boolean read FActive;
    property ContentCreated: boolean read GetContentCreated;
    property DataSource: TDataSource read GetDataSource;
    property Grid: TRxDBGrid read GetGrid;
    property Query: TSQLQuery read GetQuery;
    property Sheet: TTabSheet read FSheet;
    property StageIndex: integer read FStageIndex;
  end;

  TStageResultViewList = specialize TObjectList<TStageResultView>;

  TStageResultTabs = class
  private
    FContext: TCompetitionDbContext;
    FItems: TStageResultViewList;
    FPageControl: TPageControl;
    FPreviousPageChange: TNotifyEvent;
    FQueriesEnabled: boolean;
    function FindBySheet(const ASheet: TTabSheet): TStageResultView;
    function GetCount: integer;
    function GetItem(const AStageIndex: integer): TStageResultView;
    procedure OpenViewQuery(const AView: TStageResultView);
    procedure PageControlChange(Sender: TObject);
  public
    constructor Create(const APageControl: TPageControl;
      const AContext: TCompetitionDbContext);
    destructor Destroy; override;
    procedure ActivateStage(const AStageIndex: integer);
    procedure Rebuild(const AStageCount: integer);
    procedure ConfigureStage(const AStageIndex: integer;
      const ADisplayName: string; const AActive: boolean);
    function RefreshQueries(out AErrors: string; out AQueryCount: integer): integer;
    property Count: integer read GetCount;
    property Items[const AStageIndex: integer]: TStageResultView read GetItem; default;
  end;

  TStageResultSumColumns = class
  private
    FColumns: TList;
    FGrid: TRxDBGrid;
    procedure Clear;
    function GetCount: integer;
    function GetColumn(const AStageIndex: integer): TRxColumn;
  public
    constructor Create(const AGrid: TRxDBGrid);
    destructor Destroy; override;
    procedure Rebuild(const AStageCount: integer);
    procedure ConfigureStage(const AStageIndex: integer;
      const ADisplayName: string; const AActive: boolean);
    property Columns[const AStageIndex: integer]: TRxColumn read GetColumn;
    property Count: integer read GetCount;
  end;

implementation

uses
  i18n, StageConfig;

constructor TStageResultView.Create(const APageControl: TPageControl;
  const AContext: TCompetitionDbContext; const AStageIndex, AStageCount: integer);
var
  StageSuffix: string;
begin
  inherited Create(nil);
  if APageControl = nil then
    raise EArgumentNilException.Create('APageControl');
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if not IsValidStageCount(AStageCount) or (AStageIndex < 1) or
    (AStageIndex > AStageCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index %d is outside the configured range 1..%d.',
      [AStageIndex, AStageCount]);

  FStageIndex := AStageIndex;
  FStageCount := AStageCount;
  FContext := AContext;
  StageSuffix := IntToStr(AStageIndex);

  FSheet := TTabSheet.Create(Self);
  FSheet.Name := 'SheetStage' + StageSuffix;
  FSheet.ParentFont := False;
  FSheet.PageControl := APageControl;
end;

procedure TStageResultView.EnsureContent;
var
  StageSuffix: string;
begin
  if FQuery <> nil then
    Exit;

  StageSuffix := IntToStr(FStageIndex);
  try
    FDataSource := TDataSource.Create(Self);
    FDataSource.Name := 'ResultDataSource' + StageSuffix;

    FQuery := FContext.CreateQuery(Self);
    FQuery.Name := 'ResultDataset' + StageSuffix;
    FContext.RegisterUiQuery(FQuery);
    TDatasetSql.ConfigureResultStage(FQuery, FStageIndex, FStageCount);
    FDataSource.DataSet := FQuery;

    FGrid := TRxDBGrid.Create(Self);
    FGrid.Name := 'GridResult' + StageSuffix;
    FGrid.Align := alClient;
    FGrid.AutoSort := True;
    FGrid.FooterOptions.DrawFullLine := False;
    FGrid.OptionsRx := [];
    FGrid.Color := clWindow;
    FGrid.SelectedColor := clHighlight;
    FGrid.FixedCols := 0;
    FGrid.Options := [dgTitles, dgColumnResize, dgColLines, dgRowLines,
      dgAlwaysShowSelection, dgConfirmDelete, dgCancelOnExit, dgDblClickAutoSize];
    FGrid.ParentFont := False;
    FGrid.ReadOnly := True;
    FGrid.DataSource := FDataSource;

    AddColumn('category', rsCategory, 100, taLeftJustify);
    AddColumn('place' + StageSuffix, rsPlace, 45, taCenter);
    AddColumn('number', rsNumber, 45, taCenter, True);
    AddColumn('name', rsName, 151, taLeftJustify);
    AddColumn('penalty' + StageSuffix, rsPenalty, 64, taLeftJustify);
    AddColumn('result' + StageSuffix, rsResult, 100, taCenter, True);
    AddColumn('diffleader' + StageSuffix, rsDiffleader, 75, taCenter);

    FGrid.Parent := FSheet;
  except
    FreeAndNil(FGrid);
    FreeAndNil(FQuery);
    FreeAndNil(FDataSource);
    raise;
  end;
end;

function TStageResultView.GetContentCreated: boolean;
begin
  Result := FQuery <> nil;
end;

function TStageResultView.GetDataSource: TDataSource;
begin
  EnsureContent;
  Result := FDataSource;
end;

function TStageResultView.GetGrid: TRxDBGrid;
begin
  EnsureContent;
  Result := FGrid;
end;

function TStageResultView.GetQuery: TSQLQuery;
begin
  EnsureContent;
  Result := FQuery;
end;

function TStageResultView.AddColumn(const AFieldName, ATitle: string;
  const AWidth: integer; const AAlignment: TAlignment; const ABold: boolean): TRxColumn;
begin
  Result := FGrid.Columns.Add;
  Result.FieldName := AFieldName;
  Result.Alignment := AAlignment;
  Result.Title.Alignment := taCenter;
  Result.Title.Caption := ATitle;
  Result.Width := AWidth;
  if ABold then
    Result.Font.Style := [fsBold];
end;

procedure TStageResultView.Configure(const ADisplayName: string;
  const AActive: boolean);
begin
  FActive := AActive;
  FSheet.Caption := ADisplayName;
  FSheet.TabVisible := AActive;
  if (not AActive) and (FQuery <> nil) then
    FQuery.Close;
end;

constructor TStageResultTabs.Create(const APageControl: TPageControl;
  const AContext: TCompetitionDbContext);
begin
  inherited Create;
  if APageControl = nil then
    raise EArgumentNilException.Create('APageControl');
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  FPageControl := APageControl;
  FContext := AContext;
  FItems := TStageResultViewList.Create(True);
  FPreviousPageChange := FPageControl.OnChange;
  FPageControl.OnChange := @PageControlChange;
end;

destructor TStageResultTabs.Destroy;
begin
  FPageControl.OnChange := FPreviousPageChange;
  FItems.Free;
  inherited Destroy;
end;

function TStageResultTabs.FindBySheet(const ASheet: TTabSheet): TStageResultView;
var
  View: TStageResultView;
begin
  Result := nil;
  if ASheet = nil then
    Exit;
  for View in FItems do
    if View.Sheet = ASheet then
      Exit(View);
end;

procedure TStageResultTabs.PageControlChange(Sender: TObject);
var
  View: TStageResultView;
begin
  if Assigned(FPreviousPageChange) then
    FPreviousPageChange(Sender);
  View := FindBySheet(FPageControl.ActivePage);
  OpenViewQuery(View);
end;

procedure TStageResultTabs.OpenViewQuery(const AView: TStageResultView);
begin
  if (not FQueriesEnabled) or (not FContext.Connection.Connected) then
    Exit;
  if (AView = nil) or (not AView.Active) then
    Exit;
  AView.EnsureContent;
  if not AView.FQuery.Active then
    AView.FQuery.Open;
end;

function TStageResultTabs.GetCount: integer;
begin
  Result := FItems.Count;
end;

function TStageResultTabs.GetItem(const AStageIndex: integer): TStageResultView;
begin
  if (AStageIndex < 1) or (AStageIndex > FItems.Count) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage result view index must be in the range 1..%d, got %d.',
      [FItems.Count, AStageIndex]);
  Result := FItems[AStageIndex - 1];
end;

procedure TStageResultTabs.ActivateStage(const AStageIndex: integer);
var
  View: TStageResultView;
begin
  View := Items[AStageIndex];
  if not View.Active then
    raise EArgumentException.CreateFmt('Stage %d is not active.', [AStageIndex]);
  FPageControl.ActivePage := View.Sheet;
  OpenViewQuery(View);
end;

procedure TStageResultTabs.Rebuild(const AStageCount: integer);
type
  TStaticPageState = record
    Sheet: TTabSheet;
    TabVisible: boolean;
  end;
var
  StageIndex, I, StaticPageCount: integer;
  StaticPages: array of TStaticPageState;
begin
  if not IsValidStageCount(AStageCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      rsStageCountRangeError, [IntToStr(AStageCount), MIN_STAGE_COUNT,
      MAX_SUPPORTED_STAGE_COUNT]);
  // Append in final display order. Moving new pages ahead of existing pages
  // can leave Qt's page order/selection out of sync with LCL after rebuilding.
  SetLength(StaticPages, FPageControl.PageCount);
  StaticPageCount := 0;
  for I := 0 to FPageControl.PageCount - 1 do
    if FindBySheet(FPageControl.Pages[I]) = nil then
    begin
      StaticPages[StaticPageCount].Sheet := FPageControl.Pages[I];
      StaticPages[StaticPageCount].TabVisible := FPageControl.Pages[I].TabVisible;
      Inc(StaticPageCount);
    end;
  SetLength(StaticPages, StaticPageCount);
  FQueriesEnabled := False;
  FPageControl.DisableAlign;
  try
    FItems.Clear;
    for I := 0 to High(StaticPages) do StaticPages[I].Sheet.PageControl := nil;
    try
      FItems.Capacity := AStageCount;
      for StageIndex := 1 to AStageCount do
        FItems.Add(TStageResultView.Create(FPageControl, FContext,
          StageIndex, AStageCount));
    finally
      for I := 0 to High(StaticPages) do
      begin
        // LCL clears TabVisible when removing a page from its page control.
        StaticPages[I].Sheet.TabVisible := StaticPages[I].TabVisible;
        StaticPages[I].Sheet.PageControl := FPageControl;
      end;
    end;
  finally
    FPageControl.EnableAlign;
  end;
end;

procedure TStageResultTabs.ConfigureStage(const AStageIndex: integer;
  const ADisplayName: string; const AActive: boolean);
begin
  Items[AStageIndex].Configure(ADisplayName, AActive);
end;

function TStageResultTabs.RefreshQueries(out AErrors: string;
  out AQueryCount: integer): integer;
var
  Queries: array of TSQLQuery;
  QueryCount: integer;
  View: TStageResultView;
begin
  Queries := nil;
  View := FindBySheet(FPageControl.ActivePage);
  if (View <> nil) and View.Active then
    View.EnsureContent;

  SetLength(Queries, Count);
  QueryCount := 0;
  for View in FItems do
    if View.Active and (View.FQuery <> nil) then
    begin
      Queries[QueryCount] := View.FQuery;
      Inc(QueryCount);
    end;
  SetLength(Queries, QueryCount);
  AQueryCount := QueryCount;
  Result := FContext.RefreshQueries(Queries, AErrors);
  FQueriesEnabled := FContext.Connection.Connected;
end;

constructor TStageResultSumColumns.Create(const AGrid: TRxDBGrid);
begin
  inherited Create;
  if AGrid = nil then
    raise EArgumentNilException.Create('AGrid');
  FGrid := AGrid;
  FColumns := TList.Create;
end;

destructor TStageResultSumColumns.Destroy;
begin
  Clear;
  FColumns.Free;
  inherited Destroy;
end;

procedure TStageResultSumColumns.Clear;
var
  Index: integer;
begin
  for Index := FColumns.Count - 1 downto 0 do
    TObject(FColumns[Index]).Free;
  FColumns.Clear;
end;

function TStageResultSumColumns.GetCount: integer;
begin
  Result := FColumns.Count;
end;

function TStageResultSumColumns.GetColumn(const AStageIndex: integer): TRxColumn;
begin
  if (AStageIndex < 1) or (AStageIndex > FColumns.Count) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage summary column index must be in the range 1..%d, got %d.',
      [FColumns.Count, AStageIndex]);
  Result := TRxColumn(FColumns[AStageIndex - 1]);
end;

procedure TStageResultSumColumns.Rebuild(const AStageCount: integer);
var
  Column: TRxColumn;
  InsertIndex, StageIndex: integer;
begin
  if not IsValidStageCount(AStageCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      rsStageCountRangeError, [IntToStr(AStageCount), MIN_STAGE_COUNT,
      MAX_SUPPORTED_STAGE_COUNT]);
  Clear;
  FColumns.Capacity := AStageCount;
  if FGrid.ColumnByFieldName('sumresult') = nil then
    raise EDatabaseError.Create('The summary column "sumresult" is missing.');
  InsertIndex := FGrid.ColumnByFieldName('sumresult').Index;
  for StageIndex := 1 to AStageCount do
  begin
    Column := FGrid.Columns.Add;
    Column.Index := InsertIndex;
    Column.FieldName := 'result' + IntToStr(StageIndex);
    Column.Alignment := taCenter;
    Column.Title.Alignment := taCenter;
    Column.Title.Caption := Format(rsSUFormat, [StageIndex]);
    Column.Width := 100;
    Column.Visible := True;
    FColumns.Add(Column);
    Inc(InsertIndex);
  end;
end;

procedure TStageResultSumColumns.ConfigureStage(const AStageIndex: integer;
  const ADisplayName: string; const AActive: boolean);
begin
  Columns[AStageIndex].Title.Caption := ADisplayName;
  Columns[AStageIndex].Visible := AActive;
end;

end.
