unit StageGridColumnFactory;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DB, Graphics, rxdbgrid, MyRxDBGrid;

type
  { TStageGridColumnFactory }

  TStageGridColumnFactory = class
  private
    FCreatedColumns: TList;
    FGrid: TMyRxDBGrid;
    function AddColumn(const AFieldName, ATitle: string;
      const AWidth: integer; const AAlignment: TAlignment;
      const AColor: TColor = clDefault): TRxColumn;
    procedure SetColumnCaption(const AColumn: TRxColumn;
      const ACaption: string);
    function StageColumn(const AStageIndex, AColumnOffset: integer): TRxColumn;
  public
    constructor Create(const AGrid: TMyRxDBGrid);
    destructor Destroy; override;
    procedure BeginColumnUpdate;
    procedure ConfigureSingleStage(const AStageIndex: integer;
      const AShowStageName: boolean);
    procedure ConfigureStage(const AStageIndex: integer;
      const ADisplayName: string; const AActive: boolean);
    procedure EndColumnUpdate;
    procedure Rebuild(const AStageCount: integer);
    function CreatedColumnCount: integer;
  end;

implementation

uses
  AppLogger, i18n, StageConfig;

const
  STAGE_GRID_COLUMN_COUNT = 7;
  STAGE_COLUMN_CORRECTION = 0;
  STAGE_COLUMN_START_TIME = 1;
  STAGE_COLUMN_FINISH_TIME = 2;
  STAGE_COLUMN_PENALTY = 3;
  STAGE_COLUMN_RESULT = 4;
  STAGE_COLUMN_DIFF_LEADER = 5;
  STAGE_COLUMN_PLACE = 6;
  RESULT_COLUMN_COLOR = 9568145;

constructor TStageGridColumnFactory.Create(const AGrid: TMyRxDBGrid);
begin
  inherited Create;
  if AGrid = nil then
    raise EArgumentNilException.Create('AGrid');
  FGrid := AGrid;
  FCreatedColumns := TList.Create;
end;

destructor TStageGridColumnFactory.Destroy;
begin
  FCreatedColumns.Free;
  inherited Destroy;
end;

function TStageGridColumnFactory.AddColumn(const AFieldName, ATitle: string;
  const AWidth: integer; const AAlignment: TAlignment;
  const AColor: TColor): TRxColumn;
begin
  Result := FGrid.Columns.Add;
  Result.FieldName := AFieldName;
  Result.Alignment := AAlignment;
  Result.Title.Alignment := taCenter;
  Result.Title.Caption := ATitle;
  Result.Width := AWidth;
  Result.Visible := True;
  if AColor <> clDefault then
    Result.Color := AColor;
  FCreatedColumns.Add(Result);
end;

procedure TStageGridColumnFactory.SetColumnCaption(const AColumn: TRxColumn;
  const ACaption: string);
begin
  // TRxColumnTitle rebuilds all multi-line title links even for an identical
  // value, so avoid turning a no-op config projection into a full grid scan.
  if AColumn.Title.Caption <> ACaption then
    AColumn.Title.Caption := ACaption;
end;

procedure TStageGridColumnFactory.BeginColumnUpdate;
begin
  FGrid.BeginColumnsUpdate;
end;

function TStageGridColumnFactory.StageColumn(const AStageIndex,
  AColumnOffset: integer): TRxColumn;
var
  columnIndex: integer;
begin
  if (AStageIndex < 1) or
    (AStageIndex > FCreatedColumns.Count div STAGE_GRID_COLUMN_COUNT) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index %d has no grid columns.', [AStageIndex]);
  if (AColumnOffset < 0) or
    (AColumnOffset >= STAGE_GRID_COLUMN_COUNT) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage column offset %d is outside the range 0..%d.',
      [AColumnOffset, STAGE_GRID_COLUMN_COUNT - 1]);
  columnIndex := (AStageIndex - 1) * STAGE_GRID_COLUMN_COUNT + AColumnOffset;
  Result := TRxColumn(FCreatedColumns[columnIndex]);
end;

procedure TStageGridColumnFactory.ConfigureStage(const AStageIndex: integer;
  const ADisplayName: string; const AActive: boolean);
begin
  SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_CORRECTION),
    ADisplayName + '|' + rsCorrection);
  SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_START_TIME),
    ADisplayName + '|' + rsStarttime);
  SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_FINISH_TIME),
    ADisplayName + '|' + rsFinishtime);
  SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_PENALTY),
    ADisplayName + '|' + rsPenalty);
  SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_RESULT),
    ADisplayName + '|' + rsResult);
  SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_DIFF_LEADER),
    ADisplayName + '|' + rsDiffleader);
  SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_PLACE),
    ADisplayName + '|' + rsPlace);

  StageColumn(AStageIndex, STAGE_COLUMN_CORRECTION).Visible := AActive;
  StageColumn(AStageIndex, STAGE_COLUMN_START_TIME).Visible := AActive;
  StageColumn(AStageIndex, STAGE_COLUMN_FINISH_TIME).Visible := AActive;
  StageColumn(AStageIndex, STAGE_COLUMN_PENALTY).Visible := AActive;
  StageColumn(AStageIndex, STAGE_COLUMN_RESULT).Visible := AActive;
  StageColumn(AStageIndex, STAGE_COLUMN_DIFF_LEADER).Visible := AActive;
  StageColumn(AStageIndex, STAGE_COLUMN_PLACE).Visible := AActive;
end;

procedure TStageGridColumnFactory.ConfigureSingleStage(
  const AStageIndex: integer; const AShowStageName: boolean);
begin
  if not AShowStageName then
  begin
    SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_CORRECTION),
      rsCorrection);
    SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_START_TIME),
      rsStarttime);
    SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_FINISH_TIME),
      rsFinishtime);
    SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_PENALTY),
      rsPenalty);
    SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_RESULT), rsResult);
    SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_DIFF_LEADER),
      rsDiffleader);
    SetColumnCaption(StageColumn(AStageIndex, STAGE_COLUMN_PLACE), rsPlace);
  end;
  StageColumn(AStageIndex, STAGE_COLUMN_PLACE).Visible := False;
  StageColumn(AStageIndex, STAGE_COLUMN_RESULT).Visible := False;
  StageColumn(AStageIndex, STAGE_COLUMN_DIFF_LEADER).Visible := False;
end;

procedure TStageGridColumnFactory.EndColumnUpdate;
begin
  FGrid.EndColumnsUpdate;
end;

procedure TStageGridColumnFactory.Rebuild(const AStageCount: integer);
var
  AddedColumnCount, PreviousColumnCount, RemovedColumnCount: integer;
  StageIndex, TailIndex, TargetColumnCount: integer;
  StageName, StageSuffix: string;
  ColumnObject: TObject;
  performanceTrace: TPerformanceTrace;
  SummaryColumn: TRxColumn;
  TailColumns: TList;
begin
  if not IsValidStageCount(AStageCount) then
    raise ERangeError.CreateFmt(rsStageCountRangeError,
      [IntToStr(AStageCount), MIN_STAGE_COUNT, MAX_SUPPORTED_STAGE_COUNT]);

  PreviousColumnCount := FCreatedColumns.Count;
  TailColumns := TList.Create;
  performanceTrace := TPerformanceTrace.Create(
    'ui.stage_grid_columns.rebuild', alsApplication,
    'stage_count=' + IntToStr(AStageCount) +
    ' previous_column_count=' + IntToStr(PreviousColumnCount));
  try
    try
      TargetColumnCount := AStageCount * STAGE_GRID_COLUMN_COUNT;
      if PreviousColumnCount = TargetColumnCount then
      begin
        performanceTrace.Finish('ok',
          'created_column_count=' + IntToStr(FCreatedColumns.Count) +
          ' structure_changed=false');
        Exit;
      end;

      SummaryColumn := FGrid.ColumnByFieldName('sumresult');
      if SummaryColumn = nil then
        raise EDatabaseError.Create(
          'The summary column "sumresult" is missing.');

      if PreviousColumnCount < TargetColumnCount then
        for TailIndex := SummaryColumn.Index to FGrid.Columns.Count - 1 do
          TailColumns.Add(FGrid.Columns[TailIndex]);

      BeginColumnUpdate;
      try
        while FCreatedColumns.Count > TargetColumnCount do
        begin
          ColumnObject := TObject(
            FCreatedColumns[FCreatedColumns.Count - 1]);
          FCreatedColumns.Delete(FCreatedColumns.Count - 1);
          ColumnObject.Free;
        end;
        RemovedColumnCount := PreviousColumnCount - FCreatedColumns.Count;
        performanceTrace.Step('columns.remove',
          'removed_column_count=' + IntToStr(RemovedColumnCount));

        FCreatedColumns.Capacity := TargetColumnCount;

        for StageIndex := FCreatedColumns.Count div STAGE_GRID_COLUMN_COUNT + 1
          to AStageCount do
        begin
          StageSuffix := IntToStr(StageIndex);
          StageName := Format(rsSUFormat, [StageIndex]);
          AddColumn('correction' + StageSuffix, StageName + '|' + rsCorrection,
            67, taRightJustify);
          AddColumn('starttime' + StageSuffix, StageName + '|' + rsStarttime,
            67, taCenter);
          AddColumn('finishtime' + StageSuffix, StageName + '|' + rsFinishtime,
            80, taCenter);
          AddColumn('penalty' + StageSuffix, StageName + '|' + rsPenalty,
            67, taRightJustify);
          AddColumn('result' + StageSuffix, StageName + '|' + rsResult,
            80, taCenter, RESULT_COLUMN_COLOR);
          AddColumn('diffleader' + StageSuffix,
            StageName + '|' + rsDiffleader, 80, taCenter);
          AddColumn('place' + StageSuffix, StageName + '|' + rsPlace,
            45, taCenter);
          performanceTrace.Step('stage_columns.add',
            'stage_index=' + IntToStr(StageIndex) +
            ' created_column_count=' + IntToStr(FCreatedColumns.Count));
        end;

        AddedColumnCount := FCreatedColumns.Count -
          (PreviousColumnCount - RemovedColumnCount);
        performanceTrace.Step('columns.append',
          'added_column_count=' + IntToStr(AddedColumnCount));

        for TailIndex := 0 to TailColumns.Count - 1 do
          TRxColumn(TailColumns[TailIndex]).Index :=
            FGrid.Columns.Count - 1;
        performanceTrace.Step('columns.tail_reorder',
          'moved_column_count=' + IntToStr(TailColumns.Count));
      finally
        EndColumnUpdate;
      end;
      performanceTrace.Step('layout.refresh');
      performanceTrace.Finish('ok',
        'created_column_count=' + IntToStr(FCreatedColumns.Count) +
        ' structure_changed=true');
    except
      on E: Exception do
      begin
        performanceTrace.FinishError(E,
          'created_column_count=' + IntToStr(FCreatedColumns.Count));
        raise;
      end;
    end;
  finally
    performanceTrace.Free;
    TailColumns.Free;
  end;
end;

function TStageGridColumnFactory.CreatedColumnCount: integer;
begin
  Result := FCreatedColumns.Count;
end;

end.
