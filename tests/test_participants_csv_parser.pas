unit test_participants_csv_parser;

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

    function BuildCsv(const ALines: array of string): string;
    procedure WriteCsv(const ALines: array of string;
      const AUseCp1251: boolean = False);
    procedure AssertParseError(const ACsvText: string);
    procedure AssertDuplicateParticipantNumber(const ACsvText: string;
      const AParticipantNumber, AFirstRowNumber,
      ADuplicateRowNumber: integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Parse_EmptyText_RaisesValidationError;
    procedure Parse_EmptyHeader_RaisesValidationError;
    procedure Parse_HeaderOnly_RaisesValidationError;
    procedure Parse_EmptyRows_AreSkipped;
    procedure Parse_CommentRows_AreRemoved;
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
    procedure Parse_Utf8RussianHeaders_MapsParticipantFields;
    procedure Parse_EnglishHeaders_MapsParticipantFields;
    procedure Parse_HtmlEntities_DecodesTextFields;
    procedure Parse_QuotedMultilineField_IsReadAsSingleCell;
    procedure ReadFile_Cp1251Content_DecodesForParse;
  end;

implementation

const
  TEST_MAX_STAGES = 8;

function TParticipantsCsvParserTests.BuildCsv(
  const ALines: array of string): string;
var
  i: integer;
begin
  Result := '';
  for i := Low(ALines) to High(ALines) do
  begin
    if Result <> '' then
      Result := Result + LineEnding;
    Result := Result + ALines[i];
  end;
end;

procedure TParticipantsCsvParserTests.WriteCsv(const ALines: array of string;
  const AUseCp1251: boolean);
var
  content: string;
  encodedContent: string;
  fileStream: TFileStream;
begin
  content := BuildCsv(ALines);

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
  AssertParseError(BuildCsv([
    'number;;name',
    '12;;Alice'
  ]));
end;

procedure TParticipantsCsvParserTests.Parse_HeaderOnly_RaisesValidationError;
begin
  AssertParseError('number;name');
end;

procedure TParticipantsCsvParserTests.Parse_EmptyRows_AreSkipped;
var
  parseResult: TParticipantsCsvParseResult;
begin
  parseResult := FParser.Parse(BuildCsv([
    'number;name',
    '',
    '12;Alice',
    '   ',
    '13;Bob'
  ]), TEST_MAX_STAGES);
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
  parseResult := FParser.Parse(BuildCsv([
    '# CSV comment before the header',
    '   # another comment',
    'number;name',
    '12;Alice #1',
    '# comment between participant rows',
    '13;Bob'
  ]), TEST_MAX_STAGES);
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

procedure TParticipantsCsvParserTests.Parse_NulCharacters_AreRemoved;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(BuildCsv([
    'num' + #0 + 'ber;name;Stage 1',
    '12;Al' + #0 + 'ice;09:15:42' + #0
  ]), TEST_MAX_STAGES);
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
  parseResult := FParser.Parse(UTF8BOM + BuildCsv([
    'number;name;Stage 1',
    '12;Alice;09:15:42'
  ]), TEST_MAX_STAGES);
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
  AssertParseError(BuildCsv([
    'name;category;Stage 1',
    'Alice;Open;10:00:00'
  ]));
end;

procedure TParticipantsCsvParserTests.Parse_MultipleNumberColumns_RaisesValidationError;
begin
  AssertParseError(BuildCsv([
    'number;№;name',
    '12;12;Alice'
  ]));
end;

procedure TParticipantsCsvParserTests.Parse_DuplicateHeaders_RaisesValidationError;
begin
  AssertParseError(BuildCsv([
    'number;Номер;name',
    '12;12;Alice'
  ]));

  AssertParseError(BuildCsv([
    'number;name;Name',
    '12;Alice;Alice'
  ]));

  AssertParseError(BuildCsv([
    'number; name ;NAME',
    '12;Alice;Alice'
  ]));
end;

procedure TParticipantsCsvParserTests.Parse_HeadersWithWhitespace_AreNormalized;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(BuildCsv([
    ' Номер ; Имя ; Категория ; СУ 1 ',
    '21;Алиса Иванова;Элита;09:15:00'
  ]), TEST_MAX_STAGES);
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

procedure TParticipantsCsvParserTests.Parse_RowCellCountDiffersFromHeader_RaisesValidationError;
begin
  AssertParseError(BuildCsv([
    'number;name;Stage 1',
    '12;Alice'
  ]));

  AssertParseError(BuildCsv([
    'number;name',
    '12;Alice;unexpected'
  ]));
end;

procedure TParticipantsCsvParserTests.Parse_NonNumericNumber_RaisesValidationError;
begin
  AssertParseError(BuildCsv([
    'number;name',
    'not-a-number;Alice'
  ]));

  AssertParseError(BuildCsv([
    'number;name',
    '1.5;Alice'
  ]));
end;

procedure TParticipantsCsvParserTests.Parse_ZeroNumber_RaisesValidationError;
begin
  AssertParseError(BuildCsv([
    'number;name',
    '0;Alice'
  ]));
end;

procedure TParticipantsCsvParserTests.Parse_NegativeNumber_RaisesValidationError;
begin
  AssertParseError(BuildCsv([
    'number;name',
    '-1;Alice'
  ]));
end;

procedure TParticipantsCsvParserTests.Parse_DuplicateNumber_RaisesValidationError;
begin
  AssertDuplicateParticipantNumber(BuildCsv([
    '# comment before header',
    'number;name',
    '12;Alice',
    '# comment between participants',
    '12;Bob'
  ]), 12, 3, 5);

  AssertDuplicateParticipantNumber(BuildCsv([
    'number;name',
    '1;Alice',
    '01;Bob'
  ]), 1, 2, 3);
end;

procedure TParticipantsCsvParserTests.Parse_ValidStartTimes_AreNormalized;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(BuildCsv([
    'number;Stage 1;Stage 2;Stage 3;Stage 4',
    '12;09:15;09:15:42;09:15:42,123;09:15:42.456'
  ]), TEST_MAX_STAGES);
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
  parseResult := FParser.Parse(BuildCsv([
    'number;Stage 1;Stage 2',
    '12;;   '
  ]), TEST_MAX_STAGES);
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
      parseResult := FParser.Parse(BuildCsv([
        'number;Stage 1',
        '12;25:00'
      ]), TEST_MAX_STAGES);
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
  parseResult := FParser.Parse(BuildCsv([
    'number;Stage 1;Stage 2;Stage 3;Stage 4;Stage 5;Stage 6;Stage 7;Stage 8;Stage 9',
    '12;10:00;10:01;10:02;10:03;10:04;10:05;10:06;10:07;10:08'
  ]), TEST_MAX_STAGES);
  try
    AssertEquals(9, parseResult.DetectedStageCount);
    AssertEquals(TEST_MAX_STAGES, parseResult.StageNames.Count);

    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals(TEST_MAX_STAGES, participant.startTimes.Count);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.Parse_Utf8RussianHeaders_MapsParticipantFields;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
begin
  parseResult := FParser.Parse(BuildCsv([
    'Номер;ФИО;Категория;Ник;Год рождения;Команда;Город;Телефон;Почта;Комментарий;СУ 1',
    '21;Алиса Иванова;Элита;alisa;1995;Вектор;Пермь;+79990000000;alisa@example.test;Гость;09:15:00'
  ]), TEST_MAX_STAGES);
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
  parseResult := FParser.Parse(BuildCsv([
    'number;name;category;nickname;birthday;team;city;phone;email;comment;Prologue',
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
  parseResult := FParser.Parse(BuildCsv([
    'number;name;team;city;comment;Stage 1',
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
  parseResult := FParser.Parse(BuildCsv([
    'number;name;comment',
    '12;Alice;"First line',
    'Second line"'
  ]), TEST_MAX_STAGES);
  try
    AssertEquals(1, parseResult.StartItems.Count);
    participant := TStartItemModel(parseResult.StartItems[0]);
    AssertEquals('First line' + LineEnding + 'Second line',
      participant.comment);
  finally
    parseResult.Free;
  end;
end;

procedure TParticipantsCsvParserTests.ReadFile_Cp1251Content_DecodesForParse;
var
  parseResult: TParticipantsCsvParseResult;
  participant: TStartItemModel;
  csvText: string;
  encodingName: string;
begin
  WriteCsv([
    'Номер;Имя;Категория;Пролог',
    '7;Борис Петров;Мастера;11:00:00'
  ], True);

  csvText := FParser.ReadFile(FFilePath, encodingName);
  AssertTrue('ReadFile must return the detected encoding name',
    encodingName <> '');
  parseResult := FParser.Parse(csvText, TEST_MAX_STAGES);
  try
    AssertEquals(1, parseResult.StartItems.Count);
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

initialization
  RegisterTest(TParticipantsCsvParserTests);

end.
