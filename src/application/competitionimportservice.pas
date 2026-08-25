unit CompetitionImportService;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, DbSql, StageModel;

type
  ECompetitionImportValidationError = class(Exception);
  ECompetitionImportBackupError = class(Exception);

  TCompetitionResultsImportFormat = (crifFullStage, crifStart, crifFinish);
  TParticipantNumberArray = array of integer;

  TParticipantsImportPlan = class
  private
    FEncodingName: string;
    FDetectedStageCount: integer;
    FDetectedStageNamesText: string;
    FRowCount: integer;
    FStageNames: TStringList;
    FParseResult: TObject;
    class function CreateFromParseResult(
      const AEncodingName: string; const AParseResult: TObject):
      TParticipantsImportPlan; static;
    function GetStageNames: TStrings;
  public
    destructor Destroy; override;
    function TargetStageCount(const ACurrentStageCount: integer): integer;
    property EncodingName: string read FEncodingName;
    property DetectedStageCount: integer read FDetectedStageCount;
    property DetectedStageNamesText: string read FDetectedStageNamesText;
    property RowCount: integer read FRowCount;
    property StageNames: TStrings read GetStageNames;
  end;

  TResultsImportPlan = class
  private
    FEncodingName: string;
    FImportFormat: TCompetitionResultsImportFormat;
    FFormatColumnCount: integer;
    FRowCount: integer;
    FParseResult: TObject;
    class function CreateFromParseResult(
      const AEncodingName: string; const AParseResult: TObject):
      TResultsImportPlan; static;
  public
    destructor Destroy; override;
    property EncodingName: string read FEncodingName;
    property ImportFormat: TCompetitionResultsImportFormat read FImportFormat;
    property FormatColumnCount: integer read FFormatColumnCount;
    property RowCount: integer read FRowCount;
  end;

  TParticipantsImportRequest = record
    StoredActiveStageIndex: integer;
    CategoryLimit: integer;
    ImportCategories: boolean;
    ExpansionBackupCreated: boolean;
  end;

  TResultsImportInspection = record
    KnownParticipantCount: integer;
    UnknownParticipantNumbers: TParticipantNumberArray;
  end;

  TResultsImportRequest = record
    StageIndex: integer;
    AcceptedUnknownParticipantNumbers: TParticipantNumberArray;
    BackupCreated: boolean;
    ContinueWithoutBackup: boolean;
  end;

  TParticipantsImportOutcome = record
    RowCount: integer;
    PreviousStageCount: integer;
    TargetStageCount: integer;
    DeactivatedStageCount: integer;
    ImportedCategoryCount: integer;
    CategoryNamesAccepted: boolean;
    StageDefinitionsApplied: boolean;
  end;

  TResultsImportOutcome = record
    ImportedRowCount: integer;
    TotalRowCount: integer;
    SkippedRowCount: integer;
    StageIndex: integer;
    StatusProcessedCount: integer;
    StatusChangedCount: integer;
  end;

  TCompetitionImportService = record
  public
    class function PrepareParticipantsFile(const AFileName: string;
      const AMaxStageCount: integer):
      TParticipantsImportPlan; static;
    class function RequiresStageCapacityExpansion(
      const APlan: TParticipantsImportPlan;
      const AContext: TCompetitionDbContext;
      const AStages: TStages): boolean; static;
    class function ApplyParticipants(const APlan: TParticipantsImportPlan;
      const AContext: TCompetitionDbContext; const AStages: TStages;
      const ARequest: TParticipantsImportRequest):
      TParticipantsImportOutcome; static;
    class function PrepareResultsFile(const AFileName: string):
      TResultsImportPlan; static;
    class function InspectResultsParticipants(const APlan: TResultsImportPlan;
      const AContext: TCompetitionDbContext): TResultsImportInspection; static;
    class function ApplyResults(const APlan: TResultsImportPlan;
      const AContext: TCompetitionDbContext; const AStages: TStages;
      const ARequest: TResultsImportRequest):
      TResultsImportOutcome; static;
  end;

implementation

uses
  SQLDB, CsvParser, ParticipantsCsvParser, ResultsCsvParser, StartItemModel,
  CompetitionResultsService, i18n;

function FormatParticipantsCsvError(const E: ECsvParserError): string;
begin
  if E is EUnsupportedFileEncoding then
    Result := Format(rsUnsupportedFileEncoding,
      [EUnsupportedFileEncoding(E).EncodingName])
  else if E is EEmptyCsv then
    Result := rsParticipantsCsvEmpty
  else if E is ENumberColumnNotFound then
    Result := rsNumberColumnNotFound
  else if E is EMultipleNumberColumns then
    Result := Format(rsMultipleNumberColumns,
      [EMultipleNumberColumns(E).ColumnCount])
  else if E is EEmptyColumnName then
    Result := Format(rsEmptyParticipantColumnName,
      [EEmptyColumnName(E).ColumnIndex])
  else if E is EDuplicateColumnName then
    Result := Format(rsDuplicateParticipantColumnName,
      [EDuplicateColumnName(E).ColumnName])
  else if E is EParticipantRowsNotFound then
    Result := rsParticipantRowsNotFound
  else if E is ERowFieldCountMismatch then
    Result := Format(rsParticipantRowFieldCountMismatch, [
      ERowFieldCountMismatch(E).RowNumber,
      ERowFieldCountMismatch(E).ActualFieldCount,
      ERowFieldCountMismatch(E).ExpectedFieldCount
    ])
  else if E is EInvalidParticipantNumber then
    Result := Format(rsInvalidParticipantNumber, [
      EInvalidParticipantNumber(E).NumberText,
      EInvalidParticipantNumber(E).RowNumber
    ])
  else if E is EInvalidParticipantStartTime then
    Result := Format(rsInvalidParticipantStartTime, [
      EInvalidParticipantStartTime(E).TimeText,
      EInvalidParticipantStartTime(E).RowNumber,
      EInvalidParticipantStartTime(E).ColumnName
    ])
  else if E is EDuplicateParticipantNumber then
    Result := Format(rsDuplicateParticipantNumber, [
      EDuplicateParticipantNumber(E).ParticipantNumber,
      EDuplicateParticipantNumber(E).FirstRowNumber,
      EDuplicateParticipantNumber(E).DuplicateRowNumber
    ])
  else
    Result := E.Message;
end;

function FormatResultsCsvError(const E: ECsvParserError): string;
var
  FieldName: string;
begin
  if E is EUnsupportedFileEncoding then
    Result := Format(rsUnsupportedFileEncoding,
      [EUnsupportedFileEncoding(E).EncodingName])
  else if E is EEmptyCsv then
    Result := rsResultsCsvEmpty
  else if E is EUnsupportedResultsColumnCount then
    Result := Format(rsUnsupportedResultsColumnCount,
      [EUnsupportedResultsColumnCount(E).ColumnCount])
  else if E is EResultsRowFieldCountMismatch then
    Result := Format(rsResultsRowFieldCountMismatch, [
      EResultsRowFieldCountMismatch(E).RowNumber,
      EResultsRowFieldCountMismatch(E).ActualFieldCount,
      EResultsRowFieldCountMismatch(E).ExpectedFieldCount
    ])
  else if E is EResultsRowsNotFound then
    Result := rsResultsRowsNotFound
  else if E is EInvalidResultParticipantNumber then
    Result := Format(rsInvalidResultParticipantNumber, [
      EInvalidResultParticipantNumber(E).NumberText,
      EInvalidResultParticipantNumber(E).RowNumber
    ])
  else if E is EDuplicateResultParticipantNumber then
    Result := Format(rsDuplicateResultParticipantNumber, [
      EDuplicateResultParticipantNumber(E).ParticipantNumber,
      EDuplicateResultParticipantNumber(E).FirstRowNumber,
      EDuplicateResultParticipantNumber(E).DuplicateRowNumber
    ])
  else if E is EInvalidResultTime then
  begin
    FieldName := EInvalidResultTime(E).FieldName;
    if SameText(FieldName, 'starttime') then
      FieldName := rsStarttime
    else if SameText(FieldName, 'finishtime') then
      FieldName := rsFinishtime;
    Result := Format(rsInvalidResultTime, [
      EInvalidResultTime(E).TimeText,
      EInvalidResultTime(E).RowNumber,
      FieldName
    ]);
  end
  else if E is EInvalidResultCorrection then
    Result := Format(rsInvalidResultCorrection, [
      EInvalidResultCorrection(E).CorrectionText,
      EInvalidResultCorrection(E).RowNumber
    ])
  else if E is EInvalidResultPenalty then
    Result := Format(rsInvalidResultPenalty, [
      EInvalidResultPenalty(E).PenaltyText,
      EInvalidResultPenalty(E).RowNumber
    ])
  else if E is EInvalidResultStatus then
    Result := Format(rsInvalidResultStatus, [
      EInvalidResultStatus(E).StatusText,
      EInvalidResultStatus(E).RowNumber
    ])
  else
    Result := E.Message;
end;

function RequireContext(const AContext: TCompetitionDbContext):
  TCompetitionDbContext;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('Competition database context');
  Result := AContext;
end;

function RequireStages(const AStages: TStages): TStages;
begin
  if AStages = nil then
    raise EArgumentNilException.Create('Competition stages');
  Result := AStages;
end;

{ TParticipantsImportPlan }

class function TParticipantsImportPlan.CreateFromParseResult(
  const AEncodingName: string; const AParseResult: TObject):
  TParticipantsImportPlan;
var
  StageIndex: integer;
  ParseResult: TParticipantsCsvParseResult;
begin
  if not (AParseResult is TParticipantsCsvParseResult) then
    raise EArgumentException.Create('Participants parse result is required.');
  Result := TParticipantsImportPlan.Create;
  try
    Result.FEncodingName := AEncodingName;
    Result.FStageNames := TStringList.Create;
    ParseResult := TParticipantsCsvParseResult(AParseResult);
    Result.FStageNames.Assign(ParseResult.StageNames);
    Result.FDetectedStageCount := ParseResult.DetectedStageCount;
    Result.FRowCount := ParseResult.StartItems.Count;
    Result.FDetectedStageNamesText := '';
    for StageIndex := 0 to Result.FStageNames.Count - 1 do
    begin
      if Result.FDetectedStageNamesText <> '' then
        Result.FDetectedStageNamesText :=
          Result.FDetectedStageNamesText + ', ';
      Result.FDetectedStageNamesText := Result.FDetectedStageNamesText +
        Result.FStageNames[StageIndex];
    end;
    Result.FParseResult := AParseResult;
  except
    Result.Free;
    raise;
  end;
end;

destructor TParticipantsImportPlan.Destroy;
begin
  FParseResult.Free;
  FStageNames.Free;
  inherited Destroy;
end;

function TParticipantsImportPlan.GetStageNames: TStrings;
begin
  Result := FStageNames;
end;

function TParticipantsImportPlan.TargetStageCount(
  const ACurrentStageCount: integer): integer;
begin
  Result := ACurrentStageCount;
  if FDetectedStageCount > Result then
    Result := FDetectedStageCount;
end;

{ TResultsImportPlan }

class function TResultsImportPlan.CreateFromParseResult(
  const AEncodingName: string; const AParseResult: TObject):
  TResultsImportPlan;
var
  ParseResult: TResultsCsvParseResult;
begin
  if not (AParseResult is TResultsCsvParseResult) then
    raise EArgumentException.Create('Results parse result is required.');
  Result := TResultsImportPlan.Create;
  try
    Result.FEncodingName := AEncodingName;
    ParseResult := TResultsCsvParseResult(AParseResult);
    Result.FRowCount := ParseResult.Items.Count;
    case ParseResult.Format of
      rcfFullStage:
        begin
          Result.FImportFormat := crifFullStage;
          Result.FFormatColumnCount := 6;
        end;
      rcfStart:
        begin
          Result.FImportFormat := crifStart;
          Result.FFormatColumnCount := 3;
        end;
      rcfFinish:
        begin
          Result.FImportFormat := crifFinish;
          Result.FFormatColumnCount := 2;
        end;
    end;
    Result.FParseResult := AParseResult;
  except
    Result.Free;
    raise;
  end;
end;

destructor TResultsImportPlan.Destroy;
begin
  FParseResult.Free;
  inherited Destroy;
end;

function ToRepositoryImportFormat(
  const AFormat: TCompetitionResultsImportFormat): TStageResultImportFormat;
begin
  case AFormat of
    crifFullStage: Result := srifFullStage;
    crifStart: Result := srifStart;
    crifFinish: Result := srifFinish;
  end;
end;

function ToImportRow(const AItem: TResultImportItem): TStageResultImportRow;
begin
  Result := Default(TStageResultImportRow);
  Result.ParticipantNumber := AItem.ParticipantNumber;
  Result.StartTime := AItem.StartTime;
  Result.HasCorrection := AItem.HasCorrection;
  Result.Correction := AItem.Correction;
  Result.FinishTime := AItem.FinishTime;
  Result.Penalty := AItem.Penalty;
  Result.HasStatus := AItem.HasStatus;
  Result.Status := AItem.Status;
end;

{ TCompetitionImportService }

class function TCompetitionImportService.PrepareParticipantsFile(
  const AFileName: string; const AMaxStageCount: integer):
  TParticipantsImportPlan;
var
  CanonicalFileName, CsvText, EncodingName: string;
  Parser: TParticipantsCsvParser;
  ParseResult: TParticipantsCsvParseResult;
begin
  Result := nil;
  Parser := TParticipantsCsvParser.Create;
  ParseResult := nil;
  CanonicalFileName := ExpandFileName(AFileName);
  try
    try
      CsvText := Parser.ReadFile(CanonicalFileName, EncodingName);
      ParseResult := Parser.Parse(CsvText, AMaxStageCount);
      if ParseResult.DetectedStageCount > AMaxStageCount then
        raise ECompetitionImportValidationError.Create(Format(
          rsTooManyParticipantStages,
          [ParseResult.DetectedStageCount, AMaxStageCount]));
      Result := TParticipantsImportPlan.CreateFromParseResult(EncodingName,
        ParseResult);
      ParseResult := nil;
    except
      on E: ECsvParserError do
        raise ECompetitionImportValidationError.Create(
          FormatParticipantsCsvError(E));
    end;
  finally
    ParseResult.Free;
    Parser.Free;
  end;
end;

class function TCompetitionImportService.RequiresStageCapacityExpansion(
  const APlan: TParticipantsImportPlan;
  const AContext: TCompetitionDbContext; const AStages: TStages): boolean;
var
  Query: TSQLQuery;
begin
  if APlan = nil then
    raise EArgumentNilException.Create('Participants import plan');
  RequireContext(AContext);
  RequireStages(AStages);
  Query := AContext.CreateQuery(nil);
  try
    Result := APlan.TargetStageCount(AStages.Count) >
      TSchemaSql.DetectStageCapacity(Query);
  finally
    Query.Free;
  end;
end;

class function TCompetitionImportService.ApplyParticipants(
  const APlan: TParticipantsImportPlan;
  const AContext: TCompetitionDbContext; const AStages: TStages;
  const ARequest: TParticipantsImportRequest):
  TParticipantsImportOutcome;
var
  ParseResult: TParticipantsCsvParseResult;
  Query: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
  ImportedCategories, CategoryNames: TStringList;
  StartItem: TStartItemModel;
  TargetStageCount, PhysicalStageCapacity, ImportedActiveStageIndex,
    ItemIndex, CategoryIndex: integer;
  PhysicalExpansionRequired: boolean;
begin
  Result := Default(TParticipantsImportOutcome);
  if APlan = nil then
    raise EArgumentNilException.Create('Participants import plan');
  RequireContext(AContext);
  RequireStages(AStages);
  if ARequest.CategoryLimit < 0 then
    raise EArgumentOutOfRangeException.Create(
      'Category limit cannot be negative.');

  Result.PreviousStageCount := AStages.Count;
  TargetStageCount := APlan.TargetStageCount(Result.PreviousStageCount);
  Result.TargetStageCount := TargetStageCount;
  Result.RowCount := APlan.RowCount;
  Result.StageDefinitionsApplied := APlan.StageNames.Count > 0;
  if Result.StageDefinitionsApplied then
  begin
    ImportedActiveStageIndex := ARequest.StoredActiveStageIndex;
    if (ImportedActiveStageIndex < 1) or
      (ImportedActiveStageIndex > APlan.StageNames.Count) then
      ImportedActiveStageIndex := 1;
    for ItemIndex := APlan.StageNames.Count + 1 to AStages.Count do
      if AStages[ItemIndex].isActive then
        Inc(Result.DeactivatedStageCount);
  end;

  Result.CategoryNamesAccepted := ARequest.ImportCategories;
  Query := AContext.CreateQuery(nil);
  PhysicalExpansionRequired := False;
  try
    if TargetStageCount > Result.PreviousStageCount then
    begin
      PhysicalStageCapacity := TSchemaSql.DetectStageCapacity(Query);
      PhysicalExpansionRequired := TargetStageCount > PhysicalStageCapacity;
      if PhysicalExpansionRequired and
        (not ARequest.ExpansionBackupCreated) then
        raise ECompetitionImportBackupError.Create(Format(
          rsStageCapacityExpansionBackupError,
          [AContext.Connection.DatabaseName]));
    end;
    ParseResult := TParticipantsCsvParseResult(APlan.FParseResult);
    UnitOfWork := AContext.BeginUnitOfWork;
    ImportedCategories := nil;
    CategoryNames := nil;
    try
      if PhysicalExpansionRequired then
        TSchemaSql.EnsureStageCapacity(Query, TargetStageCount);
      if Result.StageDefinitionsApplied then
      begin
        TImportSql.ExecApplyStageDefinitions(Query, APlan.StageNames,
          TargetStageCount);
        TConfigSql.ExecUpsertByKey(Query, 'activestage',
          IntToStr(ImportedActiveStageIndex));
      end;

      try
        TImportSql.PrepareParticipantRows(Query, TargetStageCount);
        for ItemIndex := 0 to ParseResult.StartItems.Count - 1 do
        begin
          StartItem := TStartItemModel(ParseResult.StartItems[ItemIndex]);
          TImportSql.ExecPreparedParticipantRow(Query, StartItem,
            TargetStageCount);
        end;
      finally
        TImportSql.FinishPreparedRows(Query);
      end;

      if ARequest.ImportCategories and (ARequest.CategoryLimit > 0) then
      begin
        ImportedCategories := TStringList.Create;
        CategoryNames := TStringList.Create;
        for CategoryIndex := 0 to ARequest.CategoryLimit - 1 do
          CategoryNames.Add(TConfigSql.GetString(Query, 'catname' +
            IntToStr(CategoryIndex + 1), ''));
        TMainSql.LoadGroupedCategories(Query, ImportedCategories,
          ARequest.CategoryLimit);
        Result.ImportedCategoryCount := ImportedCategories.Count;
        for CategoryIndex := 0 to ImportedCategories.Count - 1 do
          CategoryNames[CategoryIndex] := ImportedCategories[CategoryIndex];
        for CategoryIndex := 0 to CategoryNames.Count - 1 do
          TConfigSql.ExecUpsertByKey(Query, 'catname' +
            IntToStr(CategoryIndex + 1), CategoryNames[CategoryIndex]);
      end;

      UnitOfWork.Commit;
    finally
      CategoryNames.Free;
      ImportedCategories.Free;
      UnitOfWork.Free;
    end;
  finally
    Query.Free;
  end;
end;

class function TCompetitionImportService.PrepareResultsFile(
  const AFileName: string): TResultsImportPlan;
var
  CanonicalFileName, CsvText, EncodingName: string;
  Parser: TResultsCsvParser;
  ParseResult: TResultsCsvParseResult;
begin
  Result := nil;
  Parser := TResultsCsvParser.Create;
  ParseResult := nil;
  CanonicalFileName := ExpandFileName(AFileName);
  try
    try
      CsvText := Parser.ReadFile(CanonicalFileName, EncodingName);
      ParseResult := Parser.Parse(CsvText);
      Result := TResultsImportPlan.CreateFromParseResult(EncodingName,
        ParseResult);
      ParseResult := nil;
    except
      on E: ECsvParserError do
        raise ECompetitionImportValidationError.Create(
          FormatResultsCsvError(E));
    end;
  finally
    ParseResult.Free;
    Parser.Free;
  end;
end;

function ContainsParticipantNumber(const ANumbers: TParticipantNumberArray;
  const AParticipantNumber: integer): boolean;
var
  Index: integer;
begin
  for Index := Low(ANumbers) to High(ANumbers) do
    if ANumbers[Index] = AParticipantNumber then
      Exit(True);
  Result := False;
end;

class function TCompetitionImportService.InspectResultsParticipants(
  const APlan: TResultsImportPlan;
  const AContext: TCompetitionDbContext): TResultsImportInspection;
var
  ExistingNumbers: TStringList;
  Item: TResultImportItem;
  ItemIndex: integer;
  ParseResult: TResultsCsvParseResult;
  Query: TSQLQuery;
begin
  Result := Default(TResultsImportInspection);
  if APlan = nil then
    raise EArgumentNilException.Create('Results import plan');
  RequireContext(AContext);
  Query := AContext.CreateQuery(nil);
  ExistingNumbers := TStringList.Create;
  try
    TMainSql.LoadNumbers(Query, ExistingNumbers);
    ExistingNumbers.Sort;
    ExistingNumbers.Sorted := True;
    ParseResult := TResultsCsvParseResult(APlan.FParseResult);
    for ItemIndex := 0 to ParseResult.Items.Count - 1 do
    begin
      Item := TResultImportItem(ParseResult.Items[ItemIndex]);
      if ExistingNumbers.IndexOf(IntToStr(Item.ParticipantNumber)) >= 0 then
        Inc(Result.KnownParticipantCount)
      else
      begin
        SetLength(Result.UnknownParticipantNumbers,
          Length(Result.UnknownParticipantNumbers) + 1);
        Result.UnknownParticipantNumbers[
          High(Result.UnknownParticipantNumbers)] := Item.ParticipantNumber;
      end;
    end;
  finally
    ExistingNumbers.Free;
    Query.Free;
  end;
end;

class function TCompetitionImportService.ApplyResults(
  const APlan: TResultsImportPlan; const AContext: TCompetitionDbContext;
  const AStages: TStages; const ARequest: TResultsImportRequest):
  TResultsImportOutcome;
var
  ParseResult: TResultsCsvParseResult;
  ItemsToImport: TList;
  ExistingNumbers: TStringList;
  Query: TSQLQuery;
  UnitOfWork: TCompetitionUnitOfWork;
  Item: TResultImportItem;
  ImportRow: TStageResultImportRow;
  ImportFormat: TStageResultImportFormat;
  ItemIndex: integer;
  ParticipantExists: boolean;
  StatusOutcome: TStatusRecalculationOutcome;
begin
  Result := Default(TResultsImportOutcome);
  if APlan = nil then
    raise EArgumentNilException.Create('Results import plan');
  RequireContext(AContext);
  RequireStages(AStages);
  Result.TotalRowCount := APlan.RowCount;
  if not AStages.IsActiveIndex(ARequest.StageIndex) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Import stage %d is not active.', [ARequest.StageIndex]);
  if (not ARequest.BackupCreated) and
    (not ARequest.ContinueWithoutBackup) then
    raise EArgumentException.Create(
      'Results import requires a backup decision.');
  Result.StageIndex := ARequest.StageIndex;

  ParseResult := TResultsCsvParseResult(APlan.FParseResult);
  ItemsToImport := TList.Create;
  ExistingNumbers := TStringList.Create;
  Query := AContext.CreateQuery(nil);
  try
    TMainSql.LoadNumbers(Query, ExistingNumbers);
    ExistingNumbers.Sort;
    ExistingNumbers.Sorted := True;
    for ItemIndex := 0 to ParseResult.Items.Count - 1 do
    begin
      Item := TResultImportItem(ParseResult.Items[ItemIndex]);
      ParticipantExists := ExistingNumbers.IndexOf(
        IntToStr(Item.ParticipantNumber)) >= 0;
      if ParticipantExists or ContainsParticipantNumber(
        ARequest.AcceptedUnknownParticipantNumbers,
        Item.ParticipantNumber) then
        ItemsToImport.Add(Item);
    end;
    Result.ImportedRowCount := ItemsToImport.Count;
    Result.SkippedRowCount := Result.TotalRowCount - Result.ImportedRowCount;
    if ItemsToImport.Count = 0 then
      raise EArgumentException.Create(
        'Results import does not contain accepted participants.');

    ImportFormat := ToRepositoryImportFormat(APlan.ImportFormat);
    UnitOfWork := AContext.BeginUnitOfWork;
    try
      try
        TImportSql.PrepareStageResultRows(Query, ImportFormat,
          ARequest.StageIndex,
          AStages.Count);
        for ItemIndex := 0 to ItemsToImport.Count - 1 do
        begin
          Item := TResultImportItem(ItemsToImport[ItemIndex]);
          ImportRow := ToImportRow(Item);
          TImportSql.ExecPreparedStageResultRow(Query, ImportRow,
            ImportFormat);
        end;
      finally
        TImportSql.FinishPreparedRows(Query);
      end;

      if APlan.ImportFormat = crifFullStage then
      begin
        StatusOutcome :=
          TParticipantStatusService.RecalculateAllInCurrentTransaction(
            AContext, AStages);
        Result.StatusProcessedCount := StatusOutcome.ProcessedCount;
        Result.StatusChangedCount := StatusOutcome.ChangedCount;
      end;
      TResultCalculationService.RecalculateAllInCurrentTransaction(
        AContext, AStages);
      UnitOfWork.Commit;
    finally
      UnitOfWork.Free;
    end;
  finally
    Query.Free;
    ExistingNumbers.Free;
    ItemsToImport.Free;
  end;
end;

end.
