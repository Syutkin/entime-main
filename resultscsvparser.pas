unit ResultsCsvParser;

{$mode ObjFPC}{$H+}

interface

uses
  Contnrs, CsvParser;

type
  EResultsCsvParseError = class(ECsvParserError);

  EUnsupportedResultsColumnCount = class(EResultsCsvParseError)
  private
    FColumnCount: integer;
  public
    constructor Create(const AColumnCount: integer);
    property ColumnCount: integer read FColumnCount;
  end;

  EResultsRowFieldCountMismatch = class(EResultsCsvParseError)
  private
    FActualFieldCount: integer;
    FExpectedFieldCount: integer;
    FRowNumber: integer;
  public
    constructor Create(const ARowNumber, AActualFieldCount,
      AExpectedFieldCount: integer);
    property ActualFieldCount: integer read FActualFieldCount;
    property ExpectedFieldCount: integer read FExpectedFieldCount;
    property RowNumber: integer read FRowNumber;
  end;

  EResultsRowsNotFound = class(EResultsCsvParseError);

  EInvalidResultParticipantNumber = class(EResultsCsvParseError)
  private
    FNumberText: string;
    FRowNumber: integer;
  public
    constructor Create(const ANumberText: string; const ARowNumber: integer);
    property NumberText: string read FNumberText;
    property RowNumber: integer read FRowNumber;
  end;

  EDuplicateResultParticipantNumber = class(EResultsCsvParseError)
  private
    FDuplicateRowNumber: integer;
    FFirstRowNumber: integer;
    FParticipantNumber: integer;
  public
    constructor Create(const AParticipantNumber, AFirstRowNumber,
      ADuplicateRowNumber: integer);
    property DuplicateRowNumber: integer read FDuplicateRowNumber;
    property FirstRowNumber: integer read FFirstRowNumber;
    property ParticipantNumber: integer read FParticipantNumber;
  end;

  EInvalidResultTime = class(EResultsCsvParseError)
  private
    FFieldName: string;
    FRowNumber: integer;
    FTimeText: string;
  public
    constructor Create(const ATimeText: string; const ARowNumber: integer;
      const AFieldName: string);
    property FieldName: string read FFieldName;
    property RowNumber: integer read FRowNumber;
    property TimeText: string read FTimeText;
  end;

  EInvalidResultCorrection = class(EResultsCsvParseError)
  private
    FCorrectionText: string;
    FRowNumber: integer;
  public
    constructor Create(const ACorrectionText: string;
      const ARowNumber: integer);
    property CorrectionText: string read FCorrectionText;
    property RowNumber: integer read FRowNumber;
  end;

  EInvalidResultPenalty = class(EResultsCsvParseError)
  private
    FPenaltyText: string;
    FRowNumber: integer;
  public
    constructor Create(const APenaltyText: string; const ARowNumber: integer);
    property PenaltyText: string read FPenaltyText;
    property RowNumber: integer read FRowNumber;
  end;

  EInvalidResultStatus = class(EResultsCsvParseError)
  private
    FRowNumber: integer;
    FStatusText: string;
  public
    constructor Create(const AStatusText: string; const ARowNumber: integer);
    property RowNumber: integer read FRowNumber;
    property StatusText: string read FStatusText;
  end;

  TResultsCsvFormat = (
    rcfFullStage,
    rcfStart,
    rcfFinish
  );

  TResultImportItem = class
  private
    FSourceRowNumber: integer;
    FParticipantNumber: integer;
    FStartTime: string;
    FFinishTime: string;
    FPenalty: string;
    FCorrection: integer;
    FHasCorrection: boolean;
    FStatusCode: integer;
    FHasStatus: boolean;
  public
    constructor Create(const ASourceRowNumber, AParticipantNumber: integer);

    property SourceRowNumber: integer read FSourceRowNumber;
    property ParticipantNumber: integer read FParticipantNumber;
    property StartTime: string read FStartTime;
    property FinishTime: string read FFinishTime;
    property Penalty: string read FPenalty;
    property Correction: integer read FCorrection;
    property HasCorrection: boolean read FHasCorrection;
    property StatusCode: integer read FStatusCode;
    property HasStatus: boolean read FHasStatus;
  end;

  TResultsCsvParseResult = class
  private
    FFormat: TResultsCsvFormat;
    FItems: TFPObjectList;
  public
    constructor Create;
    destructor Destroy; override;

    property Format: TResultsCsvFormat read FFormat;
    property Items: TFPObjectList read FItems;
  end;

  TResultsCsvParser = class(TCsvParser)
  public
    function Parse(const ACsvText: string): TResultsCsvParseResult;
  end;

implementation

uses
  Classes, SysUtils, CsvDocument, Validators;

constructor EUnsupportedResultsColumnCount.Create(const AColumnCount: integer);
begin
  FColumnCount := AColumnCount;
  inherited CreateFmt('Unsupported results CSV column count: %d',
    [AColumnCount]);
end;

constructor EResultsRowFieldCountMismatch.Create(const ARowNumber,
  AActualFieldCount, AExpectedFieldCount: integer);
begin
  FRowNumber := ARowNumber;
  FActualFieldCount := AActualFieldCount;
  FExpectedFieldCount := AExpectedFieldCount;
  inherited CreateFmt('Row %d has %d fields, expected %d',
    [ARowNumber, AActualFieldCount, AExpectedFieldCount]);
end;

constructor EInvalidResultParticipantNumber.Create(const ANumberText: string;
  const ARowNumber: integer);
begin
  FNumberText := ANumberText;
  FRowNumber := ARowNumber;
  inherited CreateFmt('Invalid participant number "%s" in row %d',
    [ANumberText, ARowNumber]);
end;

constructor EDuplicateResultParticipantNumber.Create(
  const AParticipantNumber, AFirstRowNumber, ADuplicateRowNumber: integer);
begin
  FParticipantNumber := AParticipantNumber;
  FFirstRowNumber := AFirstRowNumber;
  FDuplicateRowNumber := ADuplicateRowNumber;
  inherited CreateFmt('Duplicate participant number %d in rows %d and %d',
    [AParticipantNumber, AFirstRowNumber, ADuplicateRowNumber]);
end;

constructor EInvalidResultTime.Create(const ATimeText: string;
  const ARowNumber: integer; const AFieldName: string);
begin
  FTimeText := ATimeText;
  FRowNumber := ARowNumber;
  FFieldName := AFieldName;
  inherited CreateFmt('Invalid %s "%s" in row %d',
    [AFieldName, ATimeText, ARowNumber]);
end;

constructor EInvalidResultCorrection.Create(const ACorrectionText: string;
  const ARowNumber: integer);
begin
  FCorrectionText := ACorrectionText;
  FRowNumber := ARowNumber;
  inherited CreateFmt('Invalid correction "%s" in row %d',
    [ACorrectionText, ARowNumber]);
end;

constructor EInvalidResultPenalty.Create(const APenaltyText: string;
  const ARowNumber: integer);
begin
  FPenaltyText := APenaltyText;
  FRowNumber := ARowNumber;
  inherited CreateFmt('Invalid penalty "%s" in row %d',
    [APenaltyText, ARowNumber]);
end;

constructor EInvalidResultStatus.Create(const AStatusText: string;
  const ARowNumber: integer);
begin
  FStatusText := AStatusText;
  FRowNumber := ARowNumber;
  inherited CreateFmt('Invalid status "%s" in row %d',
    [AStatusText, ARowNumber]);
end;

function TryParseStatusCode(const AValue: string;
  out AStatusCode: integer): boolean;
begin
  Result := True;
  if SameText(AValue, 'DNF') then
    AStatusCode := 1
  else if SameText(AValue, 'DNS') then
    AStatusCode := 2
  else if SameText(AValue, 'DSQ') then
    AStatusCode := 3
  else
    Result := TryStrToInt(AValue, AStatusCode) and
      (AStatusCode in [1..3]);

  if not Result then
    AStatusCode := 0;
end;

function NormalizeResultTime(const AValue: string; const ARowNumber: integer;
  const AFieldName: string): string;
var
  value: string;
begin
  value := Trim(AValue);
  if value = '' then
    Exit('');

  if not TryNormalizeTime(value, Result) then
    raise EInvalidResultTime.Create(value, ARowNumber, AFieldName);
end;

constructor TResultImportItem.Create(const ASourceRowNumber,
  AParticipantNumber: integer);
begin
  inherited Create;
  FSourceRowNumber := ASourceRowNumber;
  FParticipantNumber := AParticipantNumber;
end;

constructor TResultsCsvParseResult.Create;
begin
  inherited Create;
  FItems := TFPObjectList.Create(True);
end;

destructor TResultsCsvParseResult.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TResultsCsvParser.Parse(
  const ACsvText: string): TResultsCsvParseResult;
var
  csvDocument: TCSVDocument;
  participantRows: TStringList;
  csvText, numberKey, numberText, value: string;
  columnCount, firstDataRow, firstParticipantRow, numberIndex,
    participantNumber, row: integer;
  item: TResultImportItem;
begin
  csvText := NormalizeText(ACsvText);
  Result := TResultsCsvParseResult.Create;
  try
    participantRows := nil;
    csvDocument := TCSVDocument.Create;
    try
      participantRows := TStringList.Create;
      participantRows.NameValueSeparator := '=';

      csvDocument.Delimiter := ';';
      csvDocument.EqualColCountPerRow := False;
      csvDocument.CSVText := csvText;

      firstDataRow := -1;
      for row := 0 to csvDocument.RowCount - 1 do
        if not IsEmptyRow(csvDocument, row) then
        begin
          firstDataRow := row;
          Break;
        end;

      if firstDataRow < 0 then
        raise EResultsRowsNotFound.Create(
          'Results CSV contains no result rows');

      columnCount := csvDocument.ColCount[firstDataRow];

      case columnCount of
        2: Result.FFormat := rcfFinish;
        3: Result.FFormat := rcfStart;
        6: Result.FFormat := rcfFullStage;
        else
          raise EUnsupportedResultsColumnCount.Create(columnCount);
      end;

      for row := 0 to csvDocument.RowCount - 1 do
      begin
        if IsEmptyRow(csvDocument, row) then
          Continue;

        // Каждая строка данных должна соответствовать выбранному формату CSV.
        if csvDocument.ColCount[row] <> columnCount then
          raise EResultsRowFieldCountMismatch.Create(
            row + 1, csvDocument.ColCount[row], columnCount);

        // Номер участника должен быть указан целым числом больше нуля.
        numberText := Trim(csvDocument.Cells[0, row]);
        if not TryParseParticipantNumber(numberText, participantNumber) then
        begin
          // Первая строка без номера считается произвольным заголовком.
          if row = firstDataRow then
            Continue;
          raise EInvalidResultParticipantNumber.Create(numberText, row + 1);
        end;

        // Номер участника не должен повторяться в пределах файла.
        numberKey := IntToStr(participantNumber);
        numberIndex := participantRows.IndexOfName(numberKey);
        if numberIndex >= 0 then
        begin
          firstParticipantRow := StrToInt(
            participantRows.ValueFromIndex[numberIndex]);
          raise EDuplicateResultParticipantNumber.Create(
            participantNumber, firstParticipantRow, row + 1);
        end;
        participantRows.Add(numberKey + '=' + IntToStr(row + 1));

        item := TResultImportItem.Create(row + 1, participantNumber);
        try
          case Result.FFormat of
            rcfFinish:
              begin
                value := Trim(csvDocument.Cells[1, row]);
                // В двухколоночном формате время финиша обязательно.
                if value = '' then
                  raise EInvalidResultTime.Create(
                    value, row + 1, 'finishtime');

                if SameText(value, 'DNF') then
                begin
                  item.FHasStatus := True;
                  item.FStatusCode := 1;
                end
                else
                  item.FFinishTime := NormalizeResultTime(
                    value, row + 1, 'finishtime');
              end;

            rcfStart:
              begin
                value := Trim(csvDocument.Cells[1, row]);
                // В трёхколоночном формате время старта обязательно.
                if value = '' then
                  raise EInvalidResultTime.Create(
                    value, row + 1, 'starttime');
                item.FStartTime := NormalizeResultTime(
                  value, row + 1, 'starttime');

                // Мобильное приложение записывает DNS в поле поправки.
                value := Trim(csvDocument.Cells[2, row]);
                if SameText(value, 'DNS') then
                begin
                  item.FHasStatus := True;
                  item.FStatusCode := 2;
                end
                else
                begin
                  // Поправка должна быть целым числом; пустое поле недопустимо.
                  if not TryStrToInt(value, item.FCorrection) then
                    raise EInvalidResultCorrection.Create(value, row + 1);
                  item.FHasCorrection := True;
                end;
              end;

            rcfFullStage:
              begin
                item.FStartTime := NormalizeResultTime(
                  csvDocument.Cells[1, row], row + 1, 'starttime');

                value := Trim(csvDocument.Cells[2, row]);
                item.FHasCorrection := value <> '';
                if item.FHasCorrection and
                  (not TryStrToInt(value, item.FCorrection)) then
                  raise EInvalidResultCorrection.Create(value, row + 1);

                item.FFinishTime := NormalizeResultTime(
                  csvDocument.Cells[3, row], row + 1, 'finishtime');

                value := Trim(csvDocument.Cells[4, row]);
                if (value <> '') and
                  (not TryNormalizeDuration(value, item.FPenalty)) then
                  raise EInvalidResultPenalty.Create(value, row + 1);

                value := Trim(csvDocument.Cells[5, row]);
                item.FHasStatus := value <> '';
                if item.FHasStatus and
                  (not TryParseStatusCode(value, item.FStatusCode)) then
                  raise EInvalidResultStatus.Create(value, row + 1);
              end;
          end;

          Result.FItems.Add(item);
          item := nil;
        finally
          item.Free;
        end;
      end;

      if Result.FItems.Count = 0 then
        raise EResultsRowsNotFound.Create(
          'Results CSV contains no result rows');
    finally
      participantRows.Free;
      csvDocument.Free;
    end;
  except
    Result.Free;
    Result := nil;
    raise;
  end;
end;

end.
