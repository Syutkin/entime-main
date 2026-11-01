unit CompetitionExportService;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, DB, SQLDB, fpcsvexport, StageModel;

type
  ECompetitionExportFileError = class(Exception);

  TExportFieldSpec = record
    FieldName: string;
    ExportedName: string;
  end;

  TExportFieldSpecs = array of TExportFieldSpec;

  TCompetitionExportLabels = record
    FinishProtocol: string;
    FinishThruProtocol: string;
    Place: string;
    Number: string;
    ParticipantName: string;
    Nickname: string;
    Age: string;
    Team: string;
    City: string;
    Result: string;
    DiffLeader: string;
    Penalty: string;
    SumResult: string;
    SumStages: string;
    Category: string;
  end;

  TXlsxExportOutcome = record
    CategoryCount: integer;
    FinishRowCount: integer;
    ThroughRowCount: integer;
    PenaltyGroupCount: integer;
  end;

  TCompetitionExportService = record
  public
    class function BuildStartListFieldSpecs(
      const AStages: TStages): TExportFieldSpecs; static;
    class function BuildResultsFieldSpecs(const AStages: TStages;
      const AResultCaption, ADiffLeaderCaption, APlaceCaption,
      ASumResultCaption: string): TExportFieldSpecs; static;
    class procedure ExportDataSetToCsv(const AExporter: TCSVExporter;
      const ADataSet: TDataSet; const AFileName: string;
      const ABaseFieldCount: integer; const AFieldSpecs: TExportFieldSpecs); static;
    class procedure ExportQueryToCsv(const AFileName: string;
      const AQuery: TSQLQuery; const AHeaders: boolean = False); static;
    class procedure ExportStageResultsToCsv(const AFileName: string;
      const AQuery: TSQLQuery; const AStages: TStages;
      const AStageIndex: integer); static;
    class function ExportAllResultsToXlsx(const AFileName: string;
      const AQuery, AThroughResultsQuery: TSQLQuery; const AStages: TStages;
      const ALabels: TCompetitionExportLabels): TXlsxExportOutcome; static;
  end;

implementation

uses
  fpstypes, fpspreadsheet, DbSql, ResultFormatting;

type
  TCategoryExportData = record
    Name: string;
    Snapshot: TQuerySnapshot;
  end;

  TCategoryExportDataArray = array of TCategoryExportData;

  TCompetitionExportData = class
  public
    FinishColumns: TStringList;
    FinishHeaders: TStringList;
    StageNames: TStringList;
    ThroughColumns: TStringList;
    ThroughHeaders: TStringList;
    Categories: TCategoryExportDataArray;
    ThroughSnapshot: TQuerySnapshot;
    PenaltyGroupCount: integer;
    FinishRowCount: integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TCompetitionExportDataLoader = class
  private
    class procedure ConfigureFinishColumns(const AStages: TStages;
      const ALabels: TCompetitionExportLabels; const AShowPenalty: boolean;
      const AData: TCompetitionExportData); static;
    class procedure ConfigureThroughColumns(const AStages: TStages;
      const ALabels: TCompetitionExportLabels;
      const AData: TCompetitionExportData); static;
  public
    class function Load(const AQuery, AThroughResultsQuery: TSQLQuery;
      const AStages: TStages; const ALabels: TCompetitionExportLabels):
      TCompetitionExportData; static;
  end;

  TCompetitionWorkbookBuilder = class
  private
    FWorkbook: TsWorkbook;
    FFinishWorksheet: TsWorksheet;
    FThroughWorksheet: TsWorksheet;
    FData: TCompetitionExportData;
    FStages: TStages;
    FNormalFontIndex: integer;
    FLegendFontIndex: integer;
    FCategoryFontIndex: integer;
    FStageColumnCount: integer;
    procedure ConfigureFonts;
    procedure ConfigureFinishColumnWidth(const AColumn: integer);
    procedure ConfigureThroughColumnWidth(const AColumn: integer);
    procedure WriteFinishHeader(const ARow: integer);
    procedure WriteFinishValue(const ARow, AColumn: integer; const AValue: string);
    procedure WriteFinishSheet;
    procedure WriteThroughSheet;
  public
    constructor Create(const AData: TCompetitionExportData;
      const AStages: TStages; const ALabels: TCompetitionExportLabels);
    destructor Destroy; override;
    procedure SaveToFile(const AFileName: string);
  end;

procedure AppendFieldSpec(var AFieldSpecs: TExportFieldSpecs;
  const AFieldName, AExportedName: string);
var
  Index: integer;
begin
  Index := Length(AFieldSpecs);
  SetLength(AFieldSpecs, Index + 1);
  AFieldSpecs[Index].FieldName := AFieldName;
  AFieldSpecs[Index].ExportedName := AExportedName;
end;

function RequireStages(const AStages: TStages): TStages;
begin
  if AStages = nil then
    raise EArgumentNilException.Create('Competition stages are required.');
  Result := AStages;
end;

function RequireQuery(const AQuery: TSQLQuery; const AParameterName: string): TSQLQuery;
begin
  if AQuery = nil then
    raise EArgumentNilException.Create(AParameterName + ' is required.');
  Result := AQuery;
end;

{ TCompetitionExportData }

constructor TCompetitionExportData.Create;
begin
  inherited Create;
  FinishColumns := TStringList.Create;
  FinishHeaders := TStringList.Create;
  StageNames := TStringList.Create;
  ThroughColumns := TStringList.Create;
  ThroughHeaders := TStringList.Create;
end;

destructor TCompetitionExportData.Destroy;
begin
  ThroughHeaders.Free;
  ThroughColumns.Free;
  StageNames.Free;
  FinishHeaders.Free;
  FinishColumns.Free;
  inherited Destroy;
end;

{ TCompetitionExportDataLoader }

class procedure TCompetitionExportDataLoader.ConfigureFinishColumns(
  const AStages: TStages; const ALabels: TCompetitionExportLabels;
  const AShowPenalty: boolean; const AData: TCompetitionExportData);
var
  StageIndex: integer;
begin
  AData.FinishColumns.Add('sumplace');
  AData.FinishColumns.Add('number');
  AData.FinishColumns.Add('name');
  AData.FinishColumns.Add('nickname');
  AData.FinishColumns.Add('age');
  AData.FinishColumns.Add('team');
  AData.FinishColumns.Add('city');

  AData.FinishHeaders.Add(ALabels.Place);
  AData.FinishHeaders.Add(ALabels.Number);
  AData.FinishHeaders.Add(ALabels.ParticipantName);
  AData.FinishHeaders.Add(ALabels.Nickname);
  AData.FinishHeaders.Add(ALabels.Age);
  AData.FinishHeaders.Add(ALabels.Team);
  AData.FinishHeaders.Add(ALabels.City);

  if AStages.ActiveStagesCount > 1 then
    for StageIndex := 1 to AStages.Count do
      if AStages.IsActiveIndex(StageIndex) then
      begin
        AData.FinishColumns.Add('result' + IntToStr(StageIndex));
        AData.FinishHeaders.Add(ALabels.Result);
        AData.FinishColumns.Add('diffleader' + IntToStr(StageIndex));
        AData.FinishHeaders.Add(ALabels.DiffLeader);
        if AShowPenalty then
        begin
          AData.FinishColumns.Add('penalty' + IntToStr(StageIndex));
          AData.FinishHeaders.Add(ALabels.Penalty);
        end;
        AData.FinishColumns.Add('place' + IntToStr(StageIndex));
        AData.FinishHeaders.Add(ALabels.Place);
        AData.StageNames.Add(AStages[StageIndex].Name);
      end;

  AData.FinishColumns.Add('sumresult');
  AData.FinishHeaders.Add(ALabels.SumResult);
  AData.FinishColumns.Add('sumdiffleader');
  AData.FinishHeaders.Add(ALabels.DiffLeader);
  if AStages.ActiveStagesCount > 1 then
  begin
    AData.FinishColumns.Add('sumstages');
    AData.FinishHeaders.Add(ALabels.SumStages);
  end;
end;

class procedure TCompetitionExportDataLoader.ConfigureThroughColumns(
  const AStages: TStages; const ALabels: TCompetitionExportLabels;
  const AData: TCompetitionExportData);
begin
  AData.ThroughColumns.Add('category');
  AData.ThroughColumns.Add('sumplace');
  AData.ThroughColumns.Add('number');
  AData.ThroughColumns.Add('name');
  AData.ThroughColumns.Add('sumresult');
  AData.ThroughColumns.Add('thrudiff');

  AData.ThroughHeaders.Add(ALabels.Category);
  AData.ThroughHeaders.Add(ALabels.Place);
  AData.ThroughHeaders.Add(ALabels.Number);
  AData.ThroughHeaders.Add(ALabels.ParticipantName);
  AData.ThroughHeaders.Add(ALabels.Result);
  AData.ThroughHeaders.Add(ALabels.DiffLeader);
  if AStages.ActiveStagesCount > 1 then
  begin
    AData.ThroughColumns.Add('sumstages');
    AData.ThroughHeaders.Add(ALabels.SumStages);
  end;
end;

class function TCompetitionExportDataLoader.Load(
  const AQuery, AThroughResultsQuery: TSQLQuery; const AStages: TStages;
  const ALabels: TCompetitionExportLabels): TCompetitionExportData;
var
  Categories: TStringList;
  CategoryIndex: integer;
begin
  RequireQuery(AQuery, 'Export query');
  RequireQuery(AThroughResultsQuery, 'Through-results query');
  RequireStages(AStages);
  Result := TCompetitionExportData.Create;
  Categories := TStringList.Create;
  try
    try
      Result.PenaltyGroupCount :=
        TMainSql.GetPenaltyGroupsCount(AQuery, AStages.Count);
      ConfigureFinishColumns(AStages, ALabels,
        Result.PenaltyGroupCount > 1, Result);
      ConfigureThroughColumns(AStages, ALabels, Result);

      TMainSql.LoadCategoriesOrderedByStartTime(AQuery, 1, AStages.Count,
        Categories);
      SetLength(Result.Categories, Categories.Count);
      for CategoryIndex := 0 to Categories.Count - 1 do
      begin
        Result.Categories[CategoryIndex].Name := Categories[CategoryIndex];
        TMainSql.ConfigureCategoryResults(AQuery,
          Result.FinishColumns.CommaText, Categories[CategoryIndex]);
        Result.Categories[CategoryIndex].Snapshot :=
          TDatasetSql.Capture(AQuery, True, True);
        Inc(Result.FinishRowCount,
          Length(Result.Categories[CategoryIndex].Snapshot.Rows));
      end;
      Result.ThroughSnapshot :=
        TDatasetSql.Capture(AThroughResultsQuery, False, False);
    except
      Result.Free;
      raise;
    end;
  finally
    Categories.Free;
  end;
end;

{ TCompetitionWorkbookBuilder }

constructor TCompetitionWorkbookBuilder.Create(const AData: TCompetitionExportData;
  const AStages: TStages; const ALabels: TCompetitionExportLabels);
begin
  inherited Create;
  if AData = nil then
    raise EArgumentNilException.Create('Export data is required.');
  RequireStages(AStages);
  FData := AData;
  FStages := AStages;
  if FData.PenaltyGroupCount > 1 then
    FStageColumnCount := 4
  else
    FStageColumnCount := 3;
  FWorkbook := TsWorkbook.Create;
  FFinishWorksheet := FWorkbook.AddWorksheet(ALabels.FinishProtocol);
  FThroughWorksheet := FWorkbook.AddWorksheet(ALabels.FinishThruProtocol);
  ConfigureFonts;
end;

destructor TCompetitionWorkbookBuilder.Destroy;
begin
  FWorkbook.Free;
  inherited Destroy;
end;

procedure TCompetitionWorkbookBuilder.ConfigureFonts;
begin
  FNormalFontIndex := FWorkbook.AddFont('Arial', 10.0, [], scBlack);
  FLegendFontIndex := FWorkbook.AddFont('Arial', 10.0,
    [TsFontStyle.fssBold], scBlack);
  FCategoryFontIndex := FWorkbook.AddFont('Arial', 14.0,
    [TsFontStyle.fssBold], scBlack);
end;

procedure TCompetitionWorkbookBuilder.ConfigureFinishColumnWidth(
  const AColumn: integer);
var
  ColumnName: string;
begin
  ColumnName := FData.FinishColumns[AColumn];
  if (Pos('number', ColumnName) > 0) or (Pos('place', ColumnName) > 0) or
    (ColumnName = 'age') or (Pos('penalty', ColumnName) > 0) or
    (ColumnName = 'sumstages') then
    FFinishWorksheet.WriteColWidth(AColumn, 50, TsSizeUnits.suPoints)
  else if ColumnName = 'name' then
    FFinishWorksheet.WriteColWidth(AColumn, 125, TsSizeUnits.suPoints);
end;

procedure TCompetitionWorkbookBuilder.ConfigureThroughColumnWidth(
  const AColumn: integer);
var
  ColumnName: string;
begin
  ColumnName := FData.ThroughColumns[AColumn];
  if (ColumnName = 'sumplace') or (ColumnName = 'number') or
    (ColumnName = 'sumstages') then
    FThroughWorksheet.WriteColWidth(AColumn, 50, TsSizeUnits.suPoints)
  else if ColumnName = 'name' then
    FThroughWorksheet.WriteColWidth(AColumn, 125, TsSizeUnits.suPoints);
end;

procedure TCompetitionWorkbookBuilder.WriteFinishHeader(const ARow: integer);
var
  ColumnIndex: integer;
begin
  for ColumnIndex := 0 to FData.FinishHeaders.Count - 1 do
  begin
    FFinishWorksheet.WriteText(ARow, ColumnIndex,
      FData.FinishHeaders[ColumnIndex]);
    FFinishWorksheet.WriteFont(ARow, ColumnIndex, FLegendFontIndex);
    FFinishWorksheet.WriteHorAlignment(ARow, ColumnIndex, haCenter);
    ConfigureFinishColumnWidth(ColumnIndex);
  end;
end;

procedure TCompetitionWorkbookBuilder.WriteFinishValue(const ARow, AColumn: integer;
  const AValue: string);
var
  ColumnName: string;
begin
  ColumnName := FData.FinishColumns[AColumn];
  if (((Pos('place', ColumnName) > 0) and (AValue <> '')) or
    (ColumnName = 'number') or (ColumnName = 'sumstages')) then
  begin
    FFinishWorksheet.WriteNumber(ARow, AColumn, StrToIntDef(AValue, 0));
    FFinishWorksheet.WriteHorAlignment(ARow, AColumn, haCenter);
  end
  else if (Pos('result', ColumnName) > 0) or (Pos('diff', ColumnName) > 0) or
    (Pos('penalty', ColumnName) > 0) then
  begin
    FFinishWorksheet.WriteText(ARow, AColumn, HideLeadingZeroHour(AValue));
    FFinishWorksheet.WriteHorAlignment(ARow, AColumn, haRight);
    if ColumnName = 'sumresult' then
      FFinishWorksheet.WriteFont(ARow, AColumn, FLegendFontIndex);
  end
  else
  begin
    FFinishWorksheet.WriteText(ARow, AColumn, AValue);
    FFinishWorksheet.WriteFont(ARow, AColumn, FNormalFontIndex);
  end;
end;

procedure TCompetitionWorkbookBuilder.WriteFinishSheet;
var
  CategoryIndex, StageIndex, RowIndex, ColumnIndex, SheetRow: integer;
  Snapshot: TQuerySnapshot;
begin
  SheetRow := 0;
  for CategoryIndex := 0 to High(FData.Categories) do
  begin
    FFinishWorksheet.WriteText(SheetRow, 0,
      FData.Categories[CategoryIndex].Name);
    FFinishWorksheet.WriteFont(SheetRow, 0, FCategoryFontIndex);
    Inc(SheetRow);

    if FStages.ActiveStagesCount > 1 then
    begin
      for StageIndex := 0 to FData.StageNames.Count - 1 do
      begin
        ColumnIndex := 7 + FStageColumnCount * StageIndex;
        FFinishWorksheet.WriteText(SheetRow, ColumnIndex,
          FData.StageNames[StageIndex]);
        FFinishWorksheet.WriteFont(SheetRow, ColumnIndex, FLegendFontIndex);
        FFinishWorksheet.WriteHorAlignment(SheetRow, ColumnIndex, haCenter);
        FFinishWorksheet.MergeCells(SheetRow, ColumnIndex, SheetRow,
          ColumnIndex + FStageColumnCount - 1);
      end;
      Inc(SheetRow);
    end;

    WriteFinishHeader(SheetRow);
    Inc(SheetRow);
    Snapshot := FData.Categories[CategoryIndex].Snapshot;
    for RowIndex := 0 to High(Snapshot.Rows) do
    begin
      for ColumnIndex := 0 to High(Snapshot.Rows[RowIndex]) do
        WriteFinishValue(SheetRow, ColumnIndex,
          Snapshot.Rows[RowIndex][ColumnIndex]);
      Inc(SheetRow);
    end;
    Inc(SheetRow);
  end;
end;

procedure TCompetitionWorkbookBuilder.WriteThroughSheet;
var
  RowIndex, ColumnIndex, SheetRow: integer;
  ColumnName, FieldValue: string;
begin
  SheetRow := 0;
  for ColumnIndex := 0 to FData.ThroughColumns.Count - 1 do
  begin
    FThroughWorksheet.WriteText(SheetRow, ColumnIndex,
      FData.ThroughHeaders[ColumnIndex]);
    FThroughWorksheet.WriteFont(SheetRow, ColumnIndex, FLegendFontIndex);
    FThroughWorksheet.WriteHorAlignment(SheetRow, ColumnIndex, haCenter);
    ConfigureThroughColumnWidth(ColumnIndex);
  end;
  Inc(SheetRow);

  for RowIndex := 0 to High(FData.ThroughSnapshot.Rows) do
  begin
    for ColumnIndex := 0 to FData.ThroughColumns.Count - 1 do
    begin
      ColumnName := FData.ThroughColumns[ColumnIndex];
      FieldValue := FData.ThroughSnapshot.Rows[RowIndex][ColumnIndex];
      if (ColumnName = 'sumplace') or (ColumnName = 'number') or
        (ColumnName = 'sumstages') then
      begin
        FThroughWorksheet.WriteNumber(SheetRow, ColumnIndex,
          StrToIntDef(FieldValue, 0));
        FThroughWorksheet.WriteHorAlignment(SheetRow, ColumnIndex, haCenter);
      end
      else if ColumnName = 'sumresult' then
      begin
        FThroughWorksheet.WriteText(SheetRow, ColumnIndex,
          HideLeadingZeroHour(FieldValue));
        FThroughWorksheet.WriteHorAlignment(SheetRow, ColumnIndex, haRight);
        FThroughWorksheet.WriteFont(SheetRow, ColumnIndex, FLegendFontIndex);
      end
      else if ColumnName = 'thrudiff' then
      begin
        FThroughWorksheet.WriteText(SheetRow, ColumnIndex,
          HideLeadingZeroHour(FieldValue));
        FThroughWorksheet.WriteHorAlignment(SheetRow, ColumnIndex, haRight);
      end
      else
      begin
        FThroughWorksheet.WriteText(SheetRow, ColumnIndex, FieldValue);
        FThroughWorksheet.WriteFont(SheetRow, ColumnIndex, FNormalFontIndex);
      end;
    end;
    Inc(SheetRow);
  end;
end;

procedure TCompetitionWorkbookBuilder.SaveToFile(const AFileName: string);
begin
  WriteFinishSheet;
  WriteThroughSheet;
  FWorkbook.WriteToFile(AFileName, True);
end;

{ TCompetitionExportService }

class function TCompetitionExportService.BuildStartListFieldSpecs(
  const AStages: TStages): TExportFieldSpecs;
var
  StageIndex: integer;
begin
  Result := nil;
  RequireStages(AStages);
  for StageIndex := 1 to AStages.Count do
    if AStages.IsActiveIndex(StageIndex) then
      AppendFieldSpec(Result, 'starttime' + IntToStr(StageIndex),
        AStages[StageIndex].Name);
end;

class procedure TCompetitionExportService.ExportDataSetToCsv(
  const AExporter: TCSVExporter; const ADataSet: TDataSet;
  const AFileName: string; const ABaseFieldCount: integer;
  const AFieldSpecs: TExportFieldSpecs);
var
  FieldIndex, SpecIndex: integer;
begin
  if AExporter = nil then
    raise EArgumentNilException.Create('CSV exporter is required.');
  if ADataSet = nil then
    raise EArgumentNilException.Create('CSV dataset is required.');
  if ABaseFieldCount < 0 then
    raise EArgumentOutOfRangeException.Create(
      'Base CSV export field count cannot be negative.');

  AExporter.DataSet := ADataSet;
  AExporter.FileName := AFileName;
  for FieldIndex := AExporter.ExportFields.Count - 1 downto
    ABaseFieldCount do
    AExporter.ExportFields.Delete(FieldIndex);
  try
    for SpecIndex := 0 to High(AFieldSpecs) do
    begin
      AExporter.ExportFields.AddField(AFieldSpecs[SpecIndex].FieldName);
      FieldIndex := AExporter.ExportFields.IndexOfField(
        AFieldSpecs[SpecIndex].FieldName);
      AExporter.ExportFields.Fields[FieldIndex].ExportedName :=
        AFieldSpecs[SpecIndex].ExportedName;
    end;
    AExporter.Execute;
  finally
    for FieldIndex := AExporter.ExportFields.Count - 1 downto
      ABaseFieldCount do
      AExporter.ExportFields.Delete(FieldIndex);
  end;
end;

class function TCompetitionExportService.BuildResultsFieldSpecs(const AStages: TStages;
  const AResultCaption, ADiffLeaderCaption, APlaceCaption, ASumResultCaption: string):
TExportFieldSpecs;
var
  StageIndex: integer;
begin
  Result := nil;
  RequireStages(AStages);
  for StageIndex := 1 to AStages.Count do
    if AStages.IsActiveIndex(StageIndex) then
    begin
      AppendFieldSpec(Result, 'result' + IntToStr(StageIndex),
        AStages[StageIndex].Name + ' — ' + AResultCaption);
      AppendFieldSpec(Result, 'diffleader' + IntToStr(StageIndex),
        AStages[StageIndex].Name + ' — ' + ADiffLeaderCaption);
      AppendFieldSpec(Result, 'place' + IntToStr(StageIndex),
        AStages[StageIndex].Name + ' — ' + APlaceCaption);
    end;
  AppendFieldSpec(Result, 'sumresult', ASumResultCaption);
  AppendFieldSpec(Result, 'sumdiffleader', ADiffLeaderCaption);
end;

class procedure TCompetitionExportService.ExportQueryToCsv(const AFileName: string;
  const AQuery: TSQLQuery; const AHeaders: boolean);
var
  CsvLines: TStringList;
  Line: string;
  ColumnIndex, RowIndex: integer;
  Snapshot: TQuerySnapshot;
begin
  RequireQuery(AQuery, 'Export query');
  Snapshot := TDatasetSql.Capture(AQuery, True, True);
  CsvLines := TStringList.Create;
  try
    if AHeaders then
    begin
      Line := '#';
      for ColumnIndex := 0 to High(Snapshot.ColumnNames) do
      begin
        if ColumnIndex > 0 then
          Line := Line + ';';
        Line := Line + Snapshot.ColumnNames[ColumnIndex];
      end;
      CsvLines.Add(Line);
    end;
    for RowIndex := 0 to High(Snapshot.Rows) do
    begin
      Line := '';
      for ColumnIndex := 0 to High(Snapshot.Rows[RowIndex]) do
      begin
        if ColumnIndex > 0 then
          Line := Line + ';';
        Line := Line + Snapshot.Rows[RowIndex][ColumnIndex];
      end;
      CsvLines.Add(Line);
    end;
    CsvLines.SaveToFile(AFileName);
  finally
    CsvLines.Free;
  end;
end;

class procedure TCompetitionExportService.ExportStageResultsToCsv(
  const AFileName: string; const AQuery: TSQLQuery; const AStages: TStages;
  const AStageIndex: integer);
begin
  RequireQuery(AQuery, 'Export query');
  RequireStages(AStages);
  if not AStages.IsActiveIndex(AStageIndex) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage %d is not an active competition stage.', [AStageIndex]);
  TMainSql.ConfigureFinishExport(AQuery, AStageIndex, AStages.Count);
  ExportQueryToCsv(AFileName, AQuery);
end;

class function TCompetitionExportService.ExportAllResultsToXlsx(
  const AFileName: string;
  const AQuery, AThroughResultsQuery: TSQLQuery; const AStages: TStages;
  const ALabels: TCompetitionExportLabels): TXlsxExportOutcome;
var
  ExportData: TCompetitionExportData;
  WorkbookBuilder: TCompetitionWorkbookBuilder;
begin
  Result := Default(TXlsxExportOutcome);
  ExportData := TCompetitionExportDataLoader.Load(AQuery, AThroughResultsQuery,
    AStages, ALabels);
  try
    WorkbookBuilder := TCompetitionWorkbookBuilder.Create(ExportData,
      AStages, ALabels);
    try
      try
        WorkbookBuilder.SaveToFile(AFileName);
      except
        on E: Exception do
          raise ECompetitionExportFileError.Create(E.Message);
      end;
    finally
      WorkbookBuilder.Free;
    end;
    Result.CategoryCount := Length(ExportData.Categories);
    Result.FinishRowCount := ExportData.FinishRowCount;
    Result.ThroughRowCount := Length(ExportData.ThroughSnapshot.Rows);
    Result.PenaltyGroupCount := ExportData.PenaltyGroupCount;
  finally
    ExportData.Free;
  end;
end;

end.
