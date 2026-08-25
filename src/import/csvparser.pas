unit CsvParser;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, CsvDocument, LConvEncoding, nsCore, chsdIntf;

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
    function ReadFile(const AFileName: string;
      out AEncodingName: string): string;
  end;

implementation

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
  lines: TStringList;
  i: integer;
begin
  // Нулевой символ не несёт данных и мешает сравнению и передаче строк.
  Result := StringReplace(ACsvText, #0, '', [rfReplaceAll]);

  // BOM не должен становиться частью первого значения CSV.
  if Pos(UTF8BOM, Result) = 1 then
    Delete(Result, 1, Length(UTF8BOM));

  lines := TStringList.Create;
  try
    lines.Text := Result;
    // Комментарий заменяется пустой строкой, чтобы не сдвигать номера строк.
    for i := lines.Count - 1 downto 0 do
      if Pos('#', TrimLeft(lines[i])) = 1 then
        lines[i] := '';
    Result := lines.Text;
  finally
    lines.Free;
  end;

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
  csd_Reset;
  csd_HandleData(PChar(rawContent), Length(rawContent));
  if not csd_Done then
    csd_DataEnd;
  info := csd_GetDetectedCharset;
  AEncodingName := info.Name;

  // UTF-8 и ASCII уже совместимы с внутренним представлением текста.
  if SameText(AEncodingName, 'UTF-8') or SameText(AEncodingName, 'ASCII') then
    Result := rawContent
  else if SameText(AEncodingName, 'windows-1251') then
    Result := CP1251ToUTF8(rawContent)
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
    Result := UCS2LEToUTF8(rawContent)
  else if SameText(AEncodingName, 'UTF-16BE') then
    Result := UCS2BEToUTF8(rawContent)
  else if SameText(AEncodingName, 'Unknown') then
    Result := rawContent
  else
    raise EUnsupportedFileEncoding.Create(AEncodingName);
end;

end.
