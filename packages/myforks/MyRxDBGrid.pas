unit MyRxDBGrid;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Grids, RxDBGrid;

type
  TMyRxDBGrid = class;

  { TMyRxDbGridColumns }

  TMyRxDbGridColumns = class(TRxDbGridColumns)
  protected
    procedure Notify(Item: TCollectionItem;
      Action: TCollectionNotification); override;
  end;

  { TMyRxDBGrid }

  TMyRxDBGrid = class(TRxDBGrid)
  private
    FColumnsUpdateDepth: integer;
    FColumnSortListDirty: boolean;
    FTitleCalculationDeferred: boolean;
    FSavedFixedRowCount: integer;
    FSavedRowCount: integer;
    procedure ColumnCollectionChanged;
    procedure DeferTitleCalculation;
    procedure RefreshColumnSortList;
    procedure RestoreTitleCalculation;
  protected
    function CreateColumns: TGridColumns; override;
  public
    procedure BeginColumnsUpdate;
    procedure EndColumnsUpdate;
    function GetRow: Integer;
    procedure RestoreCurrentRow(const ASavedRow: integer);
  end;

procedure Register;

implementation

procedure TMyRxDbGridColumns.Notify(Item: TCollectionItem;
  Action: TCollectionNotification);
begin
  // TRxDbGridColumns.Notify unconditionally performs a full scan of every
  // column. TCollection.Notify currently has no additional behaviour, so the
  // inherited Rx implementation is intentionally replaced here. Recheck this
  // assumption when updating the Rx package.
  if Grid is TMyRxDBGrid then
    TMyRxDBGrid(Grid).ColumnCollectionChanged;
end;

function TMyRxDBGrid.CreateColumns: TGridColumns;
begin
  Result := TMyRxDbGridColumns.Create(Self, TRxColumn);
end;

procedure TMyRxDBGrid.ColumnCollectionChanged;
begin
  if FColumnsUpdateDepth > 0 then
    FColumnSortListDirty := True
  else
    RefreshColumnSortList;
end;

procedure TMyRxDBGrid.RefreshColumnSortList;
begin
  if SortColumns <> nil then
    CollumnSortListUpdate;
  FColumnSortListDirty := False;
end;

procedure TMyRxDBGrid.DeferTitleCalculation;
begin
  FTitleCalculationDeferred := HandleAllocated and (RowCount > 0);
  if not FTitleCalculationDeferred then
    Exit;

  FSavedFixedRowCount := FixedRows;
  FSavedRowCount := RowCount;
  // TRxColumnTitle.SetCaption calls the non-virtual full-grid CalcTitle after
  // every caption assignment. CalcTitle is a no-op while RowCount is zero.
  // TCustomGrid supports restoring its row structure after a zero row count,
  // so keep it empty only for the duration of the outer column batch.
  try
    FixedRows := 0;
    RowCount := 0;
  except
    try
      if RowCount = 0 then
        RowCount := FSavedRowCount;
      FixedRows := FSavedFixedRowCount;
    finally
      FTitleCalculationDeferred := False;
    end;
    raise;
  end;
end;

procedure TMyRxDBGrid.RestoreTitleCalculation;
var
  Column: TRxColumn;
begin
  if not FTitleCalculationDeferred then
    Exit;

  try
    RowCount := FSavedRowCount;
    FixedRows := FSavedFixedRowCount;
  finally
    FTitleCalculationDeferred := False;
  end;

  // Rx recalculates all multi-line title links even when the assigned caption
  // is unchanged. Reassign one caption after restoring RowCount to request
  // exactly one final CalcTitle for the complete collection.
  if Columns.Count > 0 then
  begin
    Column := TRxColumn(Columns[0]);
    Column.Title.Caption := Column.Title.Caption;
  end;
end;

procedure TMyRxDBGrid.BeginColumnsUpdate;
begin
  if FColumnsUpdateDepth = 0 then
  begin
    BeginUpdate;
    try
      BeginLayout;
      try
        DeferTitleCalculation;
      except
        EndLayout;
        raise;
      end;
    except
      EndUpdate;
      raise;
    end;
  end;
  Inc(FColumnsUpdateDepth);
end;

procedure TMyRxDBGrid.EndColumnsUpdate;
begin
  if FColumnsUpdateDepth <= 0 then
    raise EInvalidOperation.Create(
      'EndColumnsUpdate called without matching BeginColumnsUpdate.');

  Dec(FColumnsUpdateDepth);
  if FColumnsUpdateDepth > 0 then
    Exit;

  try
    try
      Columns.LinkFields;
      if FColumnSortListDirty then
        RefreshColumnSortList;
    finally
      try
        RestoreTitleCalculation;
      finally
        EndLayout;
      end;
    end;
  finally
    EndUpdate;
  end;
end;

function TMyRxDBGrid.GetRow: Integer;
begin
  Result := Row;
end;

procedure TMyRxDBGrid.RestoreCurrentRow(const ASavedRow: integer);
var
  movedRows, rowsBelow: integer;
begin
  if (DataLink = nil) or not DataLink.Active then
    Exit;

  rowsBelow := RowCount - 1 - ASavedRow;
  if rowsBelow <= 0 then
    Exit;

  // Fill the buffer below the current record before returning to it. Walking
  // upward first can pin the record to the bottom of the visible grid.
  movedRows := DataLink.DataSet.MoveBy(rowsBelow);
  DataLink.DataSet.MoveBy(-movedRows);
end;

procedure Register;
begin
  RegisterComponents('MyForks', [TMyRxDBGrid]);
end;

end.
