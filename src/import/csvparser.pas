unit CsvParser;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, CsvDocument, LConvEncoding, nsCore,
  nsUniversalDetector;

type
  ECsvParserError = class(Exception);

  EEmptyCsv = class(ECsvParserError);

  EUnsupportedFileEncoding = class(ECsvParserError)
  private
    FEncodingName: string;
  public
    constructor Create(const AEncodingName: string);
    property EncodingName: string read FEncodingName;
  end;

  TCsvParser = class abstract
  protected
    function IsEmptyRow(const ACsvDocument: TCSVDocument;
      const ARow: integer): boolean;
    function NormalizeText(const ACsvText: string): string;
  public
    function ReadFile(const AFileName: string; out AEncodingName: string): string;
  end;

implementation

uses
  LazUTF8;

function UTF16Unit(const AContent: rawbytestring; const AOffset: SizeInt;
  const ALittleEndian: boolean): word;
begin
  if ALittleEndian then
    Result := word(byte(AContent[AOffset])) or
      (word(byte(AContent[AOffset + 1])) shl 8)
  else
    Result := (word(byte(AContent[AOffset])) shl 8) or
      word(byte(AContent[AOffset + 1]));
end;

function UTF16ToUTF8(const AContent: rawbytestring;
  const ALittleEndian: boolean): string;
var
  offset, outputLength, unitCount: SizeInt;
  firstUnit, secondUnit: word;
  codePoint: cardinal;
begin
  if (Length(AContent) mod 2) <> 0 then
    raise ECsvParserError.Create('Invalid UTF-16 byte count');

  unitCount := Length(AContent) div 2;
  if unitCount > High(SizeInt) div 3 then
    raise ECsvParserError.Create('UTF-16 input is too large');
  SetLength(Result, unitCount * 3);
  outputLength := 0;
  offset := 1;
  while offset <= Length(AContent) do
  begin
    firstUnit := UTF16Unit(AContent, offset, ALittleEndian);
    if (firstUnit >= $D800) and (firstUnit <= $DBFF) then
    begin
      if offset + 3 > Length(AContent) then
        raise ECsvParserError.Create('Invalid UTF-16 surrogate pair');
      secondUnit := UTF16Unit(AContent, offset + 2, ALittleEndian);
      if (secondUnit < $DC00) or (secondUnit > $DFFF) then
        raise ECsvParserError.Create('Invalid UTF-16 surrogate pair');
      codePoint := $10000 + (cardinal(firstUnit - $D800) shl 10) +
        cardinal(secondUnit - $DC00);
      Inc(offset, 2);
    end
    else if (firstUnit >= $DC00) and (firstUnit <= $DFFF) then
      raise ECsvParserError.Create('Invalid UTF-16 surrogate pair')
    else
      codePoint := firstUnit;

    if (offset <> 1) or (codePoint <> $FEFF) then
      Inc(outputLength, UnicodeToUTF8(codePoint, @Result[outputLength + 1]));
    Inc(offset, 2);
  end;
  SetLength(Result, outputLength);
end;

function UTF32ToUTF8(const AContent: rawbytestring;
  const ALittleEndian: boolean): string;
var
  offset, outputLength: SizeInt;
  codePoint: cardinal;
begin
  if (Length(AContent) mod 4) <> 0 then
    raise ECsvParserError.Create('Invalid UTF-32 byte count');

  SetLength(Result, Length(AContent));
  outputLength := 0;
  offset := 1;
  while offset <= Length(AContent) do
  begin
    if ALittleEndian then
      codePoint := cardinal(byte(AContent[offset])) or
        (cardinal(byte(AContent[offset + 1])) shl 8) or
        (cardinal(byte(AContent[offset + 2])) shl 16) or
        (cardinal(byte(AContent[offset + 3])) shl 24)
    else
      codePoint := (cardinal(byte(AContent[offset])) shl 24) or
        (cardinal(byte(AContent[offset + 1])) shl 16) or
        (cardinal(byte(AContent[offset + 2])) shl 8) or
        cardinal(byte(AContent[offset + 3]));

    if (codePoint > $10FFFF) or ((codePoint >= $D800) and (codePoint <= $DFFF)) then
      raise ECsvParserError.Create('Invalid UTF-32 code point');
    if (offset <> 1) or (codePoint <> $FEFF) then
      Inc(outputLength, UnicodeToUTF8(codePoint, @Result[outputLength + 1]));
    Inc(offset, 4);
  end;
  SetLength(Result, outputLength);
end;

function TCsvParser.IsEmptyRow(const ACsvDocument: TCSVDocument;
  const ARow: integer): boolean;
var
  column: integer;
begin
  Result := True;
  for column := 0 to ACsvDocument.ColCount[ARow] - 1 do
    if Trim(ACsvDocument.Cells[column, ARow]) <> '' then
      Exit(False);
end;

constructor EUnsupportedFileEncoding.Create(const AEncodingName: string);
begin
  FEncodingName := AEncodingName;
  inherited Create(AEncodingName);
end;

function TCsvParser.NormalizeText(const ACsvText: string): string;
var
  normalizedText: string;
  i, firstNonSpace, outputLength: SizeInt;
  inQuotes, atLineStart: boolean;
begin
  // Нулевой символ не несёт данных и мешает сравнению и передаче строк.
  normalizedText := StringReplace(ACsvText, #0, '', [rfReplaceAll]);

  // BOM не должен становиться частью первого значения CSV.
  if Pos(UTF8BOM, normalizedText) = 1 then
    Delete(normalizedText, 1, Length(UTF8BOM));

  SetLength(Result, Length(normalizedText));
  outputLength := 0;
  i := 1;
  inQuotes := False;
  atLineStart := True;
  while i <= Length(normalizedText) do
  begin
    if atLineStart and not inQuotes then
    begin
      firstNonSpace := i;
      while (firstNonSpace <= Length(normalizedText)) and
        (normalizedText[firstNonSpace] <= ' ') and not
        (normalizedText[firstNonSpace] in [#10, #13]) do
        Inc(firstNonSpace);
      if (firstNonSpace <= Length(normalizedText)) and
        (normalizedText[firstNonSpace] = '#') then
      begin
        // Удаляем комментарий, сохраняя окончание строки для диагностики.
        i := firstNonSpace;
        while (i <= Length(normalizedText)) and not
          (normalizedText[i] in [#10, #13]) do
          Inc(i);
        if i > Length(normalizedText) then
          Break;
      end;
    end;

    Inc(outputLength);
    Result[outputLength] := normalizedText[i];
    atLineStart := normalizedText[i] in [#10, #13];
    if normalizedText[i] = '"' then
      if inQuotes and (i < Length(normalizedText)) and
        (normalizedText[i + 1] = '"') then
      begin
        // Двойная кавычка внутри поля не завершает его.
        Inc(i);
        Inc(outputLength);
        Result[outputLength] := normalizedText[i];
      end
      else
        inQuotes := not inQuotes;
    Inc(i);
  end;
  SetLength(Result, outputLength);

  // После общей нормализации в CSV должны оставаться данные.
  if Trim(Result) = '' then
    raise EEmptyCsv.Create('CSV text is empty');
end;

function TCsvParser.ReadFile(const AFileName: string;
  out AEncodingName: string): string;
var
  rawContent: rawbytestring;
  info: rCharsetInfo;
  fileStream: TFileStream;
  detector: TnsUniversalDetector;
begin
  rawContent := '';
  fileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);

  try
    SetLength(rawContent, fileStream.Size);
    if Length(rawContent) > 0 then
      fileStream.ReadBuffer(rawContent[1], Length(rawContent));
  finally
    fileStream.Free;
  end;

  // Для пустого файла кодировку определить невозможно.
  if rawContent = '' then
  begin
    AEncodingName := '';
    Exit('');
  end;

  // Детектор должен получить исходные байты до преобразования в UTF-8.
  detector := TnsUniversalDetector.Create;
  try
    detector.HandleData(pansichar(rawContent), Length(rawContent));
    if not detector.Done then
      detector.DataEnd;
    info := detector.GetDetectedCharsetInfo;
  finally
    detector.Free;
  end;
  AEncodingName := info.Name;

  // UTF-8 и ASCII уже совместимы с внутренним представлением текста.
  if SameText(AEncodingName, 'UTF-8') or SameText(AEncodingName, 'ASCII') then
    Result := rawContent
  else if SameText(AEncodingName, 'windows-1251') then
    Result := CP1251ToUTF8(rawContent)
  else if SameText(AEncodingName, 'windows-1250') then
    Result := CP1250ToUTF8(rawContent)
  else if SameText(AEncodingName, 'windows-1252') then
    Result := CP1252ToUTF8(rawContent)
  else if SameText(AEncodingName, 'windows-1253') then
    Result := CP1253ToUTF8(rawContent)
  else if SameText(AEncodingName, 'windows-1255') then
    Result := CP1255ToUTF8(rawContent)
  else if SameText(AEncodingName, 'KOI8-R') then
    Result := KOI8RToUTF8(rawContent)
  else if SameText(AEncodingName, 'ISO-8859-5') then
    Result := ISO_8859_5ToUTF8(rawContent)
  else if SameText(AEncodingName, 'ISO-8859-7') then
    Result := ISO_8859_7ToUTF8(rawContent)
  else if SameText(AEncodingName, 'ISO-8859-8') then
    // ISO-8859-8 является подмножеством windows-1255.
    Result := CP1255ToUTF8(rawContent)
  else if SameText(AEncodingName, 'IBM866') then
    Result := CP866ToUTF8(rawContent)
  else if SameText(AEncodingName, 'UTF-16LE') then
    Result := UTF16ToUTF8(rawContent, True)
  else if SameText(AEncodingName, 'UTF-16BE') then
    Result := UTF16ToUTF8(rawContent, False)
  else if SameText(AEncodingName, 'UTF-32LE') then
    Result := UTF32ToUTF8(rawContent, True)
  else if SameText(AEncodingName, 'UTF-32BE') then
    Result := UTF32ToUTF8(rawContent, False)
  else if SameText(AEncodingName, 'Unknown') then
    Result := rawContent
  else
    raise EUnsupportedFileEncoding.Create(AEncodingName);
end;

end.
