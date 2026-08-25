unit ParticipantsCsvParser;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, StartItemModel, CsvParser;

type
  EParticipantsCsvParseError = class(ECsvParserError);

  ENumberColumnNotFound = class(EParticipantsCsvParseError);

  EMultipleNumberColumns = class(EParticipantsCsvParseError)
  private
    FColumnCount: integer;
  public
    constructor Create(const AColumnCount: integer);
    property ColumnCount: integer read FColumnCount;
  end;

  EEmptyColumnName = class(EParticipantsCsvParseError)
  private
    FColumnIndex: integer;
  public
    constructor Create(const AColumnIndex: integer);
    property ColumnIndex: integer read FColumnIndex;
  end;

  EDuplicateColumnName = class(EParticipantsCsvParseError)
  private
    FColumnName: string;
  public
    constructor Create(const AColumnName: string);
    property ColumnName: string read FColumnName;
  end;

  EParticipantRowsNotFound = class(EParticipantsCsvParseError);

  ERowFieldCountMismatch = class(EParticipantsCsvParseError)
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

  EInvalidParticipantNumber = class(EParticipantsCsvParseError)
  private
    FNumberText: string;
    FRowNumber: integer;
  public
    constructor Create(const ANumberText: string; const ARowNumber: integer);
    property NumberText: string read FNumberText;
    property RowNumber: integer read FRowNumber;
  end;

  EInvalidParticipantStartTime = class(EParticipantsCsvParseError)
  private
    FTimeText: string;
    FRowNumber: integer;
    FColumnName: string;
  public
    constructor Create(const ATimeText: string; const ARowNumber: integer;
      const AColumnName: string);
    property TimeText: string read FTimeText;
    property RowNumber: integer read FRowNumber;
    property ColumnName: string read FColumnName;
  end;

  EDuplicateParticipantNumber = class(EParticipantsCsvParseError)
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

  EUnsupportedFileEncoding = CsvParser.EUnsupportedFileEncoding;

  TParticipantsCsvParseResult = class
  private
    FStartItems: TList;
    FStageNames: TStringList;
    FDetectedStageCount: integer;
  public
    constructor Create;
    destructor Destroy; override;

    property StartItems: TList read FStartItems;
    property StageNames: TStringList read FStageNames;
    property DetectedStageCount: integer read FDetectedStageCount;
  end;

  TParticipantsCsvParser = class(TCsvParser)
  public
    function Parse(const ACsvText: string;
      const AMaxStages: integer): TParticipantsCsvParseResult;
  end;


implementation

uses
  CsvDocument, htmlelements, Validators;

constructor EMultipleNumberColumns.Create(const AColumnCount: integer);
begin
  FColumnCount := AColumnCount;
  inherited CreateFmt('Found %d participant number columns', [AColumnCount]);
end;

constructor EEmptyColumnName.Create(const AColumnIndex: integer);
begin
  FColumnIndex := AColumnIndex;
  inherited CreateFmt('Column name at position %d is empty', [AColumnIndex]);
end;

constructor EDuplicateColumnName.Create(const AColumnName: string);
begin
  FColumnName := AColumnName;
  inherited CreateFmt('Duplicate column name: %s', [AColumnName]);
end;

constructor ERowFieldCountMismatch.Create(const ARowNumber,
  AActualFieldCount, AExpectedFieldCount: integer);
begin
  FRowNumber := ARowNumber;
  FActualFieldCount := AActualFieldCount;
  FExpectedFieldCount := AExpectedFieldCount;
  inherited CreateFmt('Row %d has %d fields, expected %d',
    [ARowNumber, AActualFieldCount, AExpectedFieldCount]);
end;

constructor EInvalidParticipantNumber.Create(const ANumberText: string;
  const ARowNumber: integer);
begin
  FNumberText := ANumberText;
  FRowNumber := ARowNumber;
  inherited CreateFmt(
    'Invalid participant number "%s" in row %d: expected a positive integer',
    [ANumberText, ARowNumber]);
end;

constructor EInvalidParticipantStartTime.Create(const ATimeText: string;
  const ARowNumber: integer; const AColumnName: string);
begin
  FTimeText := ATimeText;
  FRowNumber := ARowNumber;
  FColumnName := AColumnName;
  inherited CreateFmt('Invalid start time "%s" in row %d, column "%s"',
    [ATimeText, ARowNumber, AColumnName]);
end;

constructor EDuplicateParticipantNumber.Create(const AParticipantNumber,
  AFirstRowNumber, ADuplicateRowNumber: integer);
begin
  FParticipantNumber := AParticipantNumber;
  FFirstRowNumber := AFirstRowNumber;
  FDuplicateRowNumber := ADuplicateRowNumber;
  inherited CreateFmt('Duplicate participant number %d in rows %d and %d',
    [AParticipantNumber, AFirstRowNumber, ADuplicateRowNumber]);
end;

constructor TParticipantsCsvParseResult.Create;
begin
  inherited Create;
  FStartItems := TList.Create;
  FStageNames := TStringList.Create;
end;

destructor TParticipantsCsvParseResult.Destroy;
var
  i: integer;
begin
  if Assigned(FStartItems) then
    for i := 0 to FStartItems.Count - 1 do
      TObject(FStartItems[i]).Free;

  FStartItems.Free;
  FStageNames.Free;
  inherited Destroy;
end;

function TParticipantsCsvParser.Parse(const ACsvText: string;
  const AMaxStages: integer): TParticipantsCsvParseResult;
var
  csvDocument: TCSVDocument;
  legend, participantRows: TStringList;
  legendMap: TLegend;
  numberColumnCount: integer;
  legendItem: string;
  column, row, k, firstParticipantRow, headerRow, numberIndex: integer;
  startItem: TStartItemModel;
  num: longint;
  csvText, cellValue, normalizedTime, numberKey, numberText: string;
begin
  Result := nil;
  csvText := NormalizeText(ACsvText);

  Result := TParticipantsCsvParseResult.Create;
  try
    csvDocument := nil;
    legend := nil;
    participantRows := nil;
    legendMap := nil;
    try
      csvDocument := TCSVDocument.Create;
      csvDocument.Delimiter := ';';
      csvDocument.EqualColCountPerRow := False;
      csvDocument.CSVText := csvText;

      legend := TStringList.Create;
      participantRows := TStringList.Create;
      participantRows.NameValueSeparator := '=';
      legendMap := TLegend.Create;

      // Комментарии и пустые строки перед заголовком сохраняют свои позиции.
      headerRow := -1;
      for row := 0 to csvDocument.RowCount - 1 do
        if not IsEmptyRow(csvDocument, row) then
        begin
          headerRow := row;
          Break;
        end;

      if headerRow < 0 then
        raise EEmptyCsv.Create('CSV text is empty');

      for column := 0 to csvDocument.ColCount[headerRow] - 1 do
        legend.Add(Trim(csvDocument.Cells[column, headerRow]));

      // Внешние пробелы не должны влиять на распознавание колонок.
      for column := 0 to legend.Count - 1 do
      begin
        // У каждой колонки должно быть непустое название.
        if legend[column] = '' then
          raise EEmptyColumnName.Create(column + 1);
      end;

      // Названия колонок должны быть уникальны без учёта регистра.
      for column := 0 to legend.Count - 2 do
        for k := column + 1 to legend.Count - 1 do
          if SameText(legend[column], legend[k]) then
            raise EDuplicateColumnName.Create(legend[column]);

      // Должна присутствовать ровно одна колонка с номером участника.
      numberColumnCount := 0;
      for column := 0 to legend.Count - 1 do
      begin
        legendItem := legend[column];
        if legendMap.number.IndexOf(legendItem.ToLower) >= 0 then
          Inc(numberColumnCount);
      end;

      if numberColumnCount = 0 then
        raise ENumberColumnNotFound.Create(
          'Column with participants numbers not found')
      else if numberColumnCount > 1 then
        raise EMultipleNumberColumns.Create(numberColumnCount);

      // Собираем названия СУ
      for column := 0 to legend.Count - 1 do
      begin
        legendItem := legend[column];
        if (legendMap.number.IndexOf(legendItem.ToLower) < 0) and
          (legendMap.Name.IndexOf(legendItem.ToLower) < 0) and
          (legendMap.category.IndexOf(legendItem.ToLower) < 0) and
          (legendMap.nickname.IndexOf(legendItem.ToLower) < 0) and
          (legendMap.birthday.IndexOf(legendItem.ToLower) < 0) and
          (legendMap.team.IndexOf(legendItem.ToLower) < 0) and
          (legendMap.city.IndexOf(legendItem.ToLower) < 0) and
          (legendMap.phone.IndexOf(legendItem.ToLower) < 0) and
          (legendMap.email.IndexOf(legendItem.ToLower) < 0) and
          (legendMap.comment.IndexOf(legendItem.ToLower) < 0) then
        begin
          legendMap.stageNames.Add(legendItem);
        end;
      end;

      // В результат включаем не больше поддерживаемого количества СУ.
      Result.FDetectedStageCount := legendMap.stageNames.Count;
      for column := 0 to legendMap.stageNames.Count - 1 do
        if column < AMaxStages then
          Result.FStageNames.Add(legendMap.stageNames[column]);

      for row := headerRow + 1 to csvDocument.RowCount - 1 do
      begin
        // Полностью пустые строки не являются строками участников.
        if IsEmptyRow(csvDocument, row) then
          Continue;

        // В строке должно быть столько же полей, сколько в заголовке.
        if csvDocument.ColCount[row] <> legend.Count then
          raise ERowFieldCountMismatch.Create(
            row + 1, csvDocument.ColCount[row], legend.Count);

        startItem := TStartItemModel.Create;
        try
          for column := 0 to legend.Count - 1 do
          begin
            legendItem := legend[column];
            // HTML-сущности декодируются только после разделения CSV на поля.
            cellValue := UnescapeHTML(csvDocument.Cells[column, row]);
            if legendMap.number.IndexOf(legendItem.ToLower) >= 0 then
            begin
              numberText := cellValue;
              // Номер участника должен быть целым числом больше нуля.
              if not TryParseParticipantNumber(numberText, num) then
                raise EInvalidParticipantNumber.Create(numberText, row + 1);

              // Номера участников не должны повторяться.
              numberKey := IntToStr(num);
              numberIndex := participantRows.IndexOfName(numberKey);
              if numberIndex >= 0 then
              begin
                firstParticipantRow := StrToInt(
                  participantRows.ValueFromIndex[numberIndex]);
                raise EDuplicateParticipantNumber.Create(
                  num, firstParticipantRow, row + 1);
              end;
              participantRows.Add(numberKey + '=' + IntToStr(row + 1));

              startItem.number := num;
            end
            else if legendMap.Name.IndexOf(legendItem.ToLower) >= 0 then
              startItem.Name := cellValue
            else if legendMap.category.IndexOf(legendItem.ToLower) >= 0 then
              startItem.category := cellValue
            else if legendMap.nickname.IndexOf(legendItem.ToLower) >= 0 then
              startItem.nickname := cellValue
            else if legendMap.birthday.IndexOf(legendItem.ToLower) >= 0 then
              startItem.birthday := cellValue
            else if legendMap.team.IndexOf(legendItem.ToLower) >= 0 then
              startItem.team := cellValue
            else if legendMap.city.IndexOf(legendItem.ToLower) >= 0 then
              startItem.city := cellValue
            else if legendMap.phone.IndexOf(legendItem.ToLower) >= 0 then
              startItem.phone := cellValue
            else if legendMap.email.IndexOf(legendItem.ToLower) >= 0 then
              startItem.email := cellValue
            else if legendMap.comment.IndexOf(legendItem.ToLower) >= 0 then
              startItem.comment := cellValue
            else
            begin
              // Пустое стартовое время допустимо, остальные значения проверяются.
              if Trim(cellValue) = '' then
                normalizedTime := ''
              else if not TryNormalizeTime(cellValue, normalizedTime) then
                raise EInvalidParticipantStartTime.Create(
                  cellValue, row + 1, legendItem);

              if startItem.startTimes.Count < AMaxStages then
                startItem.startTimes.Add(normalizedTime);
            end;
          end;

          Result.FStartItems.Add(startItem);
          startItem := nil;
        finally
          startItem.Free;
        end;
      end;

      // В файле должна быть хотя бы одна непустая строка с участником.
      if Result.FStartItems.Count = 0 then
        raise EParticipantRowsNotFound.Create('Participant rows not found');
    finally
      csvDocument.Free;
      legend.Free;
      participantRows.Free;
      legendMap.Free;
    end;
  except
    Result.Free;
    Result := nil;
    raise;
  end;
end;

end.
