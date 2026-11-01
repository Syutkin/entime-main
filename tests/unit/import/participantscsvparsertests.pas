unit ParticipantsCsvParserTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, CsvParser, LConvEncoding,
  ParticipantsCsvParser, StartItemModel;

type
  TParticipantsCsvParserTests = class(TTestCase)
  private
    FFilePath: string;
    FParser: TParticipantsCsvParser;

    function BuildCsv(const ALines: array of string;
      const ALineEnding: string = LineEnding): string;
    procedure WriteCsv(const ALines: array of string; const ALineEnding: string;
      const AUseCp1251: boolean);
    procedure WriteRawCsv(const AContent: rawbytestring);
    procedure AssertRussianCsvEncoding(const ALineEnding, AExpectedEncoding: string;
      const AUseCp1251: boolean);
    procedure AssertParseError(const ACsvText: string);
    procedure AssertDuplicateParticipantNumber(const ACsvText: string;
      const AParticipantNumber, AFirstRowNumber, ADuplicateRowNumber: integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Parse_EmptyText_RaisesValidationError;
    procedure Parse_EmptyHeader_RaisesValidationError;
    procedure Parse_HeaderOnly_RaisesValidationError;
    procedure Parse_EmptyRows_AreSkipped;
    procedure Parse_CommentRows_AreRemoved;
    procedure Parse_HashLinesInQuotedField_ArePreserved;
    procedure Parse_QuotedFieldClosingOnHashLine_PreservesNextRecord;
    procedure Parse_CommentsWithQuotes_PreserveErrorRowNumbers;
    procedure NormalizeText_PreservesLineEndings;
    procedure Parse_NulCharacters_AreRemoved;
    procedure Parse_Utf8Bom_IsRemoved;
    procedure Parse_MissingNumberColumn_RaisesValidationError;
    procedure Parse_MultipleNumberColumns_RaisesValidationError;
    procedure Parse_DuplicateHeaders_RaisesValidationError;
    procedure Parse_HeadersWithWhitespace_AreNormalized;
    procedure Parse_RowCellCountDiffersFromHeader_RaisesValidationError;
    procedure Parse_NonNumericNumber_RaisesValidationError;
    procedure Parse_ZeroNumber_RaisesValidationError;
    procedure Parse_NegativeNumber_RaisesValidationError;
    procedure Parse_DuplicateNumber_RaisesValidationError;
    procedure Parse_ValidStartTimes_AreNormalized;
    procedure Parse_EmptyStartTime_IsAllowed;
    procedure Parse_InvalidStartTime_RaisesValidationError;
    procedure Parse_MoreThanMaxStages_TruncatesAndReportsCount;
    procedure Parse_StageLimits_OneEightAndTwelve;
    procedure Parse_Utf8RussianHeaders_MapsParticipantFields;
    procedure Parse_EnglishHeaders_MapsParticipantFields;
    procedure Parse_HtmlEntities_DecodesTextFields;
    procedure Parse_QuotedMultilineField_IsReadAsSingleCell;
    procedure ReadFile_Utf8RussianLfContent_DecodesForParse;
    procedure ReadFile_Utf8RussianCrlfContent_DecodesForParse;
    procedure ReadFile_Cp1251RussianLfContent_DecodesForParse;
    procedure ReadFile_Cp1251RussianCrlfContent_DecodesForParse;
    procedure ReadFile_Cp1250PolishContent_DecodesForParse;
    procedure ReadFile_Utf16Variants_DecodeForParse;
    procedure ReadFile_InvalidUtf16_RaisesParserError;
    procedure ReadFile_Utf32Variants_DecodeForParse;
    procedure ReadFile_InvalidUtf32_RaisesParserError;
  end;

implementation

type
  TCsvParserAccess = class(TCsvParser);

const
  TEST_MAX_STAGES = 8;

function TParticipantsCsvParserTests.BuildCsv(const ALines: array of string;
  const ALineEnding: string): string;
var
  i: integer;
begin
  Result := '';
  for i := Low(ALines) to High(ALines) do
  begin
    if Result <> '' then
      Result := Result + ALineEnding;
    Result := Result + ALines[i];
  end;
end;

procedure TParticipantsCsvParserTests.WriteCsv(const ALines: array of string;
  const ALineEnding: string; const AUseCp1251: boolean);
var
  content: string;
  encodedContent: string;
  fileStream: TFileStream;
begin
  content := BuildCsv(ALines, ALineEnding);

  if AUseCp1251 then
    encodedContent := UTF8ToCP1251(content)
  else
    encodedContent := content;

  fileStream := TFileStream.Create(FFilePath, fmCreate);
  try
    if encodedContent <> '' then
      fileStream.WriteBuffer(encodedContent[1], Length(encodedContent));
  finally
    fileStream.Free;
  end;
end;

procedure TParticipantsCsvParserTests.WriteRawCsv(const AContent: rawbytestring);
var
  fileStream: TFileStream;
begin
  fileStream := TFileStream.Create(FFilePath, fmCreate);
  try
    if AContent <> '' then
      fileStream.WriteBuffer(AContent[1], Length(AContent));
  finally
    fileStream.Free;
  end;
end;

procedure AppendUTF32Scalar(var AContent: rawbytestring;
  const ACodePoint: cardinal; const ALittleEndian: boolean);
var
  shift, i: integer;
begin
  for i := 0 to 3 do
  begin
    if ALittleEndian then
      shift := i * 8
    else
      shift := (3 - i) * 8;
    AContent := AContent + ansichar((ACodePoint shr shift) and $FF);
  end;
end;

procedure AppendUTF16Unit(var AContent: rawbytestring; const AUnit: word;
  const ALittleEndian: boolean);
begin
  if ALittleEndian then
    AContent := AContent + ansichar(AUnit and $FF) + ansichar(AUnit shr 8)
  else
    AContent := AContent + ansichar(AUnit shr 8) + ansichar(AUnit and $FF);
end;

procedure AppendUTF16ASCII(var AContent: rawbytestring; const AText: rawbytestring;
  const ALittleEndian: boolean);
var
  i: integer;
begin
  for i := 1 to Length(AText) do
    AppendUTF16Unit(AContent, byte(AText[i]), ALittleEndian);
end;

function BuildUTF16Csv(const ALittleEndian, AWithBOM: boolean): rawbytestring;
begin
  Result := '';
  if AWithBOM then
    AppendUTF16Unit(Result, $FEFF, ALittleEndian);
  AppendUTF16ASCII(Result, 'number;name;Stage 1'#10'12;', ALittleEndian);
  AppendUTF16Unit(Result, $0411, ALittleEndian);
  AppendUTF16Unit(Result, $D83D, ALittleEndian);
  AppendUTF16Unit(Result, $DEB4, ALittleEndian);
  AppendUTF16ASCII(Result, ';09:15:42', ALittleEndian);
end;

procedure AppendUTF32ASCII(var AContent: rawbytestring; const AText: rawbytestring;
  const ALittleEndian: boolean);
var
  i: integer;
begin
  for i := 1 to Length(AText) do
    AppendUTF32Scalar(AContent, byte(AText[i]), ALittleEndian);
end;

function BuildUTF32Csv(const ALittleEndian, AWithBOM: boolean): rawbytestring;
begin
  Result := '';
  if AWithBOM then
    AppendUTF32Scalar(Result, $FEFF, ALittleEndian);
  AppendUTF32ASCII(Result, 'number;name;Stage 1'#10'12;', ALittleEndian);
  AppendUTF32Scalar(Result, $0411, ALittleEndian);
  AppendUTF32Scalar(Result, $1F6B4, ALittleEndian);
  AppendUTF32ASCII(Result, ';09:15:42', ALittleEndian);
end;

procedure TParticipantsCsvParserTests.AssertParseError(const ACsvText: string);
var
  parseResult: TParticipantsCsvParseResult;
begin
  parseResult := nil;
  try
    try
      parseResult := FParser.Parse(ACsvText, TEST_MAX_STAGES);
      Fail('Expected ECsvParserError');
    except
      on E: ECsvParserError do
        ;
    end;
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.AssertDuplicateParticipantNumber(
  const ACsvText: string; const AParticipantNumber, AFirstRowNumber,
  ADuplicateRowNumber: integer);
var
  parseResult: TParticipantsCsvParseResult;
begin
  parseResult := nil;
  try
    try
      parseResult := FParser.Parse(ACsvText, TEST_MAX_STAGES);
    except
      on E: EDuplicateParticipantNumber do
      begin
        AssertEquals(AParticipantNumber, E.ParticipantNumber);
        AssertEquals(AFirstRowNumber, E.FirstRowNumber);
        AssertEquals(ADuplicateRowNumber, E.DuplicateRowNumber);
        Exit;
      end;
    end;
    Fail('Expected EDuplicateParticipantNumber');
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.SetUp;
begin
  FFilePath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    Format('participants-parser-%d.csv', [GetTickCount64]);
  if FileExists(FFilePath) then
    DeleteFile(FFilePath);
  FParser := TParticipantsCsvParser.Create;
end;

procedure TParticipantsCsvParserTests.TearDown;
begin
  FParser.Free;
  if FileExists(FFilePath) then
    DeleteFile(FFilePath);
end;

procedure TParticipantsCsvParserTests.Parse_EmptyText_RaisesValidationError;
begin
  AssertParseError('');
end;

procedure TParticipantsCsvParserTests.Parse_EmptyHeader_RaisesValidationError;
begin
  AssertParseError(BuildCsv(['number;;name', '12;;Alice']));
end;

procedure TParticipantsCsvParserTests.Parse_HeaderOnly_RaisesValidationError;
begin
  AssertParseError('number;name');
end;

procedure TParticipantsCsvParserTests.Parse_EmptyRows_AreSkipped;
var
  parseResult: TParticipantsCsvParseResult;
begin
  parseResult := FParser.Parse(BuildCsv(['number;name', '',
    '12;Alice', '   ', '13;Bob']), TEST_MAX_STAGES);
  try
    AssertEquals(2, parseResult.StartItems.Count);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_CommentRows_AreRemoved;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(
    BuildCsv(['# CSV comment before the header', '   # another comment',
    'number;name', '12;Alice #1', '# comment between participant rows',
    '13;Bob']), TEST_MAX_STAGES);
  try
    AssertEquals(2, parseResult.StartItems.Count);
    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals('Alice #1', participant.Name);
    participant := TStartItemModel(parseResult.StartItems[1]);
    AssertEquals('Bob', participant.Name);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_HashLinesInQuotedField_ArePreserved;
var
  csvLineEnding: string;
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  for csvLineEnding in [#10, #13#10] do
  begin
    parseResult := FParser.Parse(BuildCsv(['# ignored "',
      'number;name;comment', '12;Alice;"First ""quoted"" line',
      '# data;with ""quotes""', '   # indented data', 'last line"',
      '  # ignored "" "', '13;"# Bob";inline # remains'], csvLineEnding),
      TEST_MAX_STAGES);
    try
      AssertEquals(2, parseResult.StartItems.Count);
      participant := TStartItemModel(parseResult.StartItems[0]);
      AssertEquals('First "quoted" line' + LineEnding +
        '# data;with "quotes"' + LineEnding + '   # indented data' +
        LineEnding + 'last line', participant.comment);
      participant := TStartItemModel(parseResult.StartItems[1]);
      AssertEquals('# Bob', participant.Name);
      AssertEquals('inline # remains', participant.comment);
    finally
      parseResult.Free;
    end;
  end;
end;

procedure TParticipantsCsvParserTests.
Parse_QuotedFieldClosingOnHashLine_PreservesNextRecord;
var
  csvLineEnding: string;
  parseResult: TParticipantsCsvParseResult;
begin
  for csvLineEnding in [#10, #13#10] do
  begin
    parseResult := FParser.Parse(BuildCsv(['number;name;comment',
      '12;Alice;"He said ""go""', '# closing ""quote"""', '13;Bob;Done'],
      csvLineEnding), TEST_MAX_STAGES);
    try
      AssertEquals(2, parseResult.StartItems.Count);
      AssertEquals('He said "go"' + LineEnding + '# closing "quote"',
        TStartItemModel(parseResult.StartItems[0]).comment);
      AssertEquals('Done', TStartItemModel(parseResult.StartItems[1]).comment);
    finally
      parseResult.Free;
    end;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_CommentsWithQuotes_PreserveErrorRowNumbers;
var
  csvLineEnding: string;
begin
  for csvLineEnding in [#10, #13#10] do
    AssertDuplicateParticipantNumber(BuildCsv(['# ignored "',
      'number;name', '12;Alice', #9'  # ignored "" "',
      '', '12;Bob'], csvLineEnding), 12, 3, 6);
end;

procedure TParticipantsCsvParserTests.NormalizeText_PreservesLineEndings;
begin
  AssertEquals(#13#10'number;name;comment'#10 + '12;Alice;"first'#13#10'# kept"'#13,
    TCsvParserAccess(FParser).NormalizeText(UTF8BOM + #0 +
    '  # ignored "'#13#10'number;name;comment'#10 +
    '12;Al'#0'ice;"first'#13#10'# kept"'#13'# final comment'));
end;

procedure TParticipantsCsvParserTests.Parse_NulCharacters_AreRemoved;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(
    BuildCsv(['num' + #0 + 'ber;name;Stage 1', '12;Al' + #0 + 'ice;09:15:42' + #0]),
    TEST_MAX_STAGES);
  try
    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals('Alice', participant.Name);
    AssertEquals('09:15:42', participant.startTimes[0]);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_Utf8Bom_IsRemoved;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(UTF8BOM +
    BuildCsv(['number;name;Stage 1', '12;Alice;09:15:42']), TEST_MAX_STAGES);
  try
    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals(12, participant.number);
    AssertEquals('Alice', participant.Name);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_MissingNumberColumn_RaisesValidationError;
begin
  AssertParseError(BuildCsv(['name;category;Stage 1', 'Alice;Open;10:00:00']));
end;

procedure TParticipantsCsvParserTests.Parse_MultipleNumberColumns_RaisesValidationError;
begin
  AssertParseError(BuildCsv(['number;№;name', '12;12;Alice']));
end;

procedure TParticipantsCsvParserTests.Parse_DuplicateHeaders_RaisesValidationError;
begin
  AssertParseError(BuildCsv(['number;Номер;name', '12;12;Alice']));

  AssertParseError(BuildCsv(['number;name;Name', '12;Alice;Alice']));

  AssertParseError(BuildCsv(['number; name ;NAME', '12;Alice;Alice']));
end;

procedure TParticipantsCsvParserTests.Parse_HeadersWithWhitespace_AreNormalized;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(
    BuildCsv([' Номер ; Имя ; Категория ; СУ 1 ',
    '21;Алиса Иванова;Элита;09:15:00']), TEST_MAX_STAGES);
  try
    AssertEquals(1, parseResult.StageNames.Count);
    AssertEquals('СУ 1', parseResult.StageNames[0]);

    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals(21, participant.number);
    AssertEquals('Алиса Иванова', participant.Name);
    AssertEquals('Элита', participant.category);
    AssertEquals('09:15:00', participant.startTimes[0]);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.
Parse_RowCellCountDiffersFromHeader_RaisesValidationError;
begin
  AssertParseError(BuildCsv(['number;name;Stage 1', '12;Alice']));

  AssertParseError(BuildCsv(['number;name', '12;Alice;unexpected']));
end;

procedure TParticipantsCsvParserTests.Parse_NonNumericNumber_RaisesValidationError;
begin
  AssertParseError(BuildCsv(['number;name', 'not-a-number;Alice']));

  AssertParseError(BuildCsv(['number;name', '1.5;Alice']));
end;

procedure TParticipantsCsvParserTests.Parse_ZeroNumber_RaisesValidationError;
begin
  AssertParseError(BuildCsv(['number;name', '0;Alice']));
end;

procedure TParticipantsCsvParserTests.Parse_NegativeNumber_RaisesValidationError;
begin
  AssertParseError(BuildCsv(['number;name', '-1;Alice']));
end;

procedure TParticipantsCsvParserTests.Parse_DuplicateNumber_RaisesValidationError;
begin
  AssertDuplicateParticipantNumber(
    BuildCsv(['# comment before header', 'number;name', '12;Alice',
    '# comment between participants', '12;Bob']), 12, 3, 5);

  AssertDuplicateParticipantNumber(
    BuildCsv(['number;name', '1;Alice', '01;Bob']), 1, 2, 3);
end;

procedure TParticipantsCsvParserTests.Parse_ValidStartTimes_AreNormalized;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(
    BuildCsv(['number;Stage 1;Stage 2;Stage 3;Stage 4',
    '12;09:15;09:15:42;09:15:42,123;09:15:42.456']), TEST_MAX_STAGES);
  try
    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals('09:15', participant.startTimes[0]);
    AssertEquals('09:15:42', participant.startTimes[1]);
    AssertEquals('09:15:42.123', participant.startTimes[2]);
    AssertEquals('09:15:42.456', participant.startTimes[3]);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_EmptyStartTime_IsAllowed;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(BuildCsv(['number;Stage 1;Stage 2', '12;;   ']),
    TEST_MAX_STAGES);
  try
    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals('', participant.startTimes[0]);
    AssertEquals('', participant.startTimes[1]);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_InvalidStartTime_RaisesValidationError;
var
  parseResult: TParticipantsCsvParseResult;
begin
  parseResult := nil;
  try
    try
      parseResult := FParser.Parse(BuildCsv(['number;Stage 1',
        '12;25:00']), TEST_MAX_STAGES);
      Fail('Expected EInvalidParticipantStartTime');
    except
      on E: EInvalidParticipantStartTime do
      begin
        AssertEquals('25:00', E.TimeText);
        AssertEquals(2, E.RowNumber);
        AssertEquals('Stage 1', E.ColumnName);
      end;
    end;
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_MoreThanMaxStages_TruncatesAndReportsCount;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(
    BuildCsv(['number;Stage 1;Stage 2;Stage 3;Stage 4;Stage 5;Stage 6;Stage 7;Stage 8;Stage 9',
    '12;10:00;10:01;10:02;10:03;10:04;10:05;10:06;10:07;10:08']), TEST_MAX_STAGES);
  try
    AssertEquals(9, parseResult.DetectedStageCount);
    AssertEquals(TEST_MAX_STAGES, parseResult.StageNames.Count);

    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals(TEST_MAX_STAGES, participant.startTimes.Count);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_StageLimits_OneEightAndTwelve;
const
  STAGE_COUNTS: array[0..2] of integer = (1, 8, 12);
var
  StageCount: integer;
  StageIndex: integer;
  Header: string;
  Row: string;
  ParseResult: TParticipantsCsvParseResult;
  Participant: TStartItemModel;
begin
  for StageCount in STAGE_COUNTS do
  begin
    Header := 'number';
    Row := '12';
    for StageIndex := 1 to StageCount do
    begin
      Header := Header + ';Stage ' + IntToStr(StageIndex);
      Row := Row + Format(';10:%.2d', [StageIndex]);
    end;

    ParseResult := FParser.Parse(BuildCsv([Header, Row]), StageCount);
    try
      AssertEquals(StageCount, ParseResult.DetectedStageCount);
      AssertEquals(StageCount, ParseResult.StageNames.Count);
      AssertEquals('Stage ' + IntToStr(StageCount),
        ParseResult.StageNames[StageCount - 1]);

      Participant := TStartItemModel(ParseResult.StartItems[0]);
      AssertEquals(StageCount, Participant.startTimes.Count);
      AssertEquals(Format('10:%.2d', [StageCount]),
        Participant.startTimes[StageCount - 1]);
    finally
      ParseResult.Free;
    end;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_Utf8RussianHeaders_MapsParticipantFields;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(
    BuildCsv(['Номер;ФИО;Категория;Ник;Год рождения;Команда;Город;Телефон;Почта;Комментарий;СУ 1', '21;Алиса Иванова;Элита;alisa;1995;Вектор;Пермь;+79990000000;alisa@example.test;Гость;09:15:00']), TEST_MAX_STAGES);
  try
    AssertEquals(1, parseResult.StartItems.Count);
    AssertEquals(1, parseResult.StageNames.Count);
    AssertEquals('СУ 1', parseResult.StageNames[0]);

    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals(21, participant.number);
    AssertEquals('Алиса Иванова', participant.Name);
    AssertEquals('Элита', participant.category);
    AssertEquals('alisa', participant.nickname);
    AssertEquals('1995', participant.birthday);
    AssertEquals('Вектор', participant.team);
    AssertEquals('Пермь', participant.city);
    AssertEquals('+79990000000', participant.phone);
    AssertEquals('alisa@example.test', participant.email);
    AssertEquals('Гость', participant.comment);
    AssertEquals(1, participant.startTimes.Count);
    AssertEquals('09:15:00', participant.startTimes[0]);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_EnglishHeaders_MapsParticipantFields;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(
    BuildCsv(['number;name;category;nickname;birthday;team;city;phone;email;comment;Prologue',
    '42;Alice Rider;Elite;ali;1996;Fast Team;Perm;+79991111111;alice@example.test;Guest;10:30:00'
    ]), TEST_MAX_STAGES);
  try
    AssertEquals(1, parseResult.StartItems.Count);
    AssertEquals(1, parseResult.StageNames.Count);
    AssertEquals('Prologue', parseResult.StageNames[0]);

    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals(42, participant.number);
    AssertEquals('Alice Rider', participant.Name);
    AssertEquals('Elite', participant.category);
    AssertEquals('ali', participant.nickname);
    AssertEquals('1996', participant.birthday);
    AssertEquals('Fast Team', participant.team);
    AssertEquals('Perm', participant.city);
    AssertEquals('+79991111111', participant.phone);
    AssertEquals('alice@example.test', participant.email);
    AssertEquals('Guest', participant.comment);
    AssertEquals(1, participant.startTimes.Count);
    AssertEquals('10:30:00', participant.startTimes[0]);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_HtmlEntities_DecodesTextFields;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(
    BuildCsv(['number;name;team;city;comment;Stage 1',
    '99;"O&#39;Connor";"RiderShop&amp;Service";A & B;"&lt;note&gt; &unknown;";11:30:00'
    ]), TEST_MAX_STAGES);
  try
    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals('O''Connor', participant.Name);
    AssertEquals('RiderShop&Service', participant.team);
    AssertEquals('A & B', participant.city);
    AssertEquals('<note> &unknown;', participant.comment);
    AssertEquals('11:30:00', participant.startTimes[0]);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_QuotedMultilineField_IsReadAsSingleCell;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(BuildCsv(['number;name;comment',
    '12;Alice;"First line', 'Second line"']), TEST_MAX_STAGES);
  try
    AssertEquals(1, parseResult.StartItems.Count);
    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals('First line' + LineEnding + 'Second line',
      participant.comment);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.AssertRussianCsvEncoding(
  const ALineEnding, AExpectedEncoding: string; const AUseCp1251: boolean);
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
  csvText: string;
  encodingName: string;
begin
  WriteCsv(['Номер;Имя;Категория;Команда;Город;Комментарий;Пролог', '7;Борис Петров;Мастера;Север;Пермь;Первый заезд;11:00:00', '12;Анна Соколова;Элита;Вектор;Москва;Основной состав;11:01:30', '18;Виктор Орлов;Любители;Темп;Казань;Дебютный старт;11:03:00', '24;Елена Морозова;Мастера;Высота;Уфа;Повторный заезд;11:04:30', '31;Дмитрий Волков;Элита;Маяк;Самара;Вне зачёта;11:06:00'], ALineEnding, AUseCp1251);

  csvText := FParser.ReadFile(FFilePath, encodingName);
  AssertEquals(LowerCase(AExpectedEncoding), LowerCase(encodingName));
  parseResult := FParser.Parse(csvText, TEST_MAX_STAGES);
  try
    AssertEquals(5, parseResult.StartItems.Count);
    AssertEquals(1, parseResult.StageNames.Count);
    AssertEquals('Пролог', parseResult.StageNames[0]);

    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals(7, participant.number);
    AssertEquals('Борис Петров', participant.Name);
    AssertEquals('Мастера', participant.category);
    AssertEquals('11:00:00', participant.startTimes[0]);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.
ReadFile_Utf8RussianLfContent_DecodesForParse;
begin
  AssertRussianCsvEncoding(#10, 'UTF-8', False);
end;

procedure TParticipantsCsvParserTests.
ReadFile_Utf8RussianCrlfContent_DecodesForParse;
begin
  AssertRussianCsvEncoding(#13#10, 'UTF-8', False);
end;

procedure TParticipantsCsvParserTests.
ReadFile_Cp1251RussianLfContent_DecodesForParse;
begin
  AssertRussianCsvEncoding(#10, 'windows-1251', True);
end;

procedure TParticipantsCsvParserTests.
ReadFile_Cp1251RussianCrlfContent_DecodesForParse;
begin
  AssertRussianCsvEncoding(#13#10, 'windows-1251', True);
end;

procedure TParticipantsCsvParserTests.
ReadFile_Cp1250PolishContent_DecodesForParse;
var
  content, decoded, encodingName: string;
  parseResult: TParticipantsCsvParseResult;
begin
  content := BuildCsv(['Number;Name;Category;Team;City;Comment;Prologue',
    '7;Łukasz Żółty;Senior;Łódź;Łódź;Młodzi zawodnicy;11:00:00',
    '12;Małgorzata Bąk;Senior;Żubry;Gdańsk;Późny start;11:01:30'], #10);
  WriteRawCsv(UTF8ToCP1250(content));

  decoded := FParser.ReadFile(FFilePath, encodingName);
  AssertEquals('windows-1250', LowerCase(encodingName));
  AssertEquals(content, decoded);
  parseResult := FParser.Parse(decoded, TEST_MAX_STAGES);
  try
    AssertEquals(2, parseResult.StartItems.Count);
    AssertEquals('Łukasz Żółty',
      TStartItemModel(parseResult.StartItems[0]).Name);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.ReadFile_Utf16Variants_DecodeForParse;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
  content: rawbytestring;
  csvText, encodingName, expectedEncoding: string;
  littleEndian, withBOM: boolean;
begin
  for littleEndian in [False, True] do
    for withBOM in [False, True] do
    begin
      content := BuildUTF16Csv(littleEndian, withBOM);
      WriteRawCsv(content);
      csvText := FParser.ReadFile(FFilePath, encodingName);
      if littleEndian then
        expectedEncoding := 'UTF-16LE'
      else
        expectedEncoding := 'UTF-16BE';
      AssertEquals(expectedEncoding, encodingName);
      AssertEquals('number;name;Stage 1'#10'12;Б🚴;09:15:42', csvText);
      parseResult := FParser.Parse(csvText, TEST_MAX_STAGES);
      try
        AssertEquals(1, parseResult.StartItems.Count);
        participant := TStartItemModel(parseResult.StartItems[0]);
        AssertEquals('Б🚴', participant.Name);
        AssertEquals('09:15:42', participant.startTimes[0]);
      finally
        parseResult.Free;
      end;
    end;
end;

procedure TParticipantsCsvParserTests.ReadFile_InvalidUtf16_RaisesParserError;
var
  content: rawbytestring;
  encodingName: string;
begin
  content := BuildUTF16Csv(True, True);
  SetLength(content, Length(content) - 1);
  WriteRawCsv(content);
  try
    FParser.ReadFile(FFilePath, encodingName);
    Fail('Expected ECsvParserError for incomplete UTF-16 code unit');
  except
    on E: ECsvParserError do
      AssertEquals('Invalid UTF-16 byte count', E.Message);
  end;

  content := BuildUTF16Csv(False, True);
  content[3] := #$D8;
  content[4] := #$3D;
  WriteRawCsv(content);
  try
    FParser.ReadFile(FFilePath, encodingName);
    Fail('Expected ECsvParserError for unpaired UTF-16 surrogate');
  except
    on E: ECsvParserError do
      AssertEquals('Invalid UTF-16 surrogate pair', E.Message);
  end;
end;

procedure TParticipantsCsvParserTests.ReadFile_Utf32Variants_DecodeForParse;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
  content: rawbytestring;
  csvText, encodingName, expectedEncoding: string;
  littleEndian, withBOM: boolean;
begin
  for littleEndian in [False, True] do
    for withBOM in [False, True] do
    begin
      content := BuildUTF32Csv(littleEndian, withBOM);
      WriteRawCsv(content);
      csvText := FParser.ReadFile(FFilePath, encodingName);
      if littleEndian then
        expectedEncoding := 'UTF-32LE'
      else
        expectedEncoding := 'UTF-32BE';
      AssertEquals(expectedEncoding, encodingName);
      AssertEquals('number;name;Stage 1'#10'12;Б🚴;09:15:42', csvText);
      parseResult := FParser.Parse(csvText, TEST_MAX_STAGES);
      try
        AssertEquals(1, parseResult.StartItems.Count);
        participant := TStartItemModel(parseResult.StartItems[0]);
        AssertEquals('Б🚴', participant.Name);
        AssertEquals('09:15:42', participant.startTimes[0]);
      finally
        parseResult.Free;
      end;
    end;
end;

procedure TParticipantsCsvParserTests.ReadFile_InvalidUtf32_RaisesParserError;
var
  content: rawbytestring;
  encodingName: string;
begin
  content := BuildUTF32Csv(True, True);
  SetLength(content, Length(content) - 1);
  WriteRawCsv(content);
  try
    FParser.ReadFile(FFilePath, encodingName);
    Fail('Expected ECsvParserError for incomplete UTF-32 code point');
  except
    on E: ECsvParserError do
      AssertEquals('Invalid UTF-32 byte count', E.Message);
  end;

  content := BuildUTF32Csv(False, True);
  content[5] := #0;
  content[6] := #0;
  content[7] := #$D8;
  content[8] := #0;
  WriteRawCsv(content);
  try
    FParser.ReadFile(FFilePath, encodingName);
    Fail('Expected ECsvParserError for UTF-32 surrogate');
  except
    on E: ECsvParserError do
      AssertEquals('Invalid UTF-32 code point', E.Message);
  end;
end;

initialization
  RegisterTest(TParticipantsCsvParserTests);

end.
