unit test_results_csv_parser;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, CsvParser, ResultsCsvParser;

type
  TResultsCsvParserTests = class(TTestCase)
  private
    FParser: TResultsCsvParser;

    function BuildCsv(const ALines: array of string): string;
    procedure AssertEmptyCsv(const ACsvText: string);
    procedure AssertParseError(const ACsvText: string;
      const AExceptionClass: ExceptClass);
    procedure AssertRowFieldCountMismatch(const ACsvText: string;
      const ARowNumber, AActualFieldCount, AExpectedFieldCount: integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Parse_EmptyText_RaisesValidationError;
    procedure Parse_OnlyComments_RaisesValidationError;
    procedure Parse_TwoColumns_MapsFinishRows;
    procedure Parse_TwoColumns_EmptyFinishTime_RaisesValidationError;
    procedure Parse_ThreeColumns_MapsStartRows;
    procedure Parse_ThreeColumns_EmptyStartTime_RaisesValidationError;
    procedure Parse_ThreeColumns_DnsInStartTime_RaisesValidationError;
    procedure Parse_SixColumns_MapsFullStageRow;
    procedure Parse_FormatIsDeterminedByFirstDataRow;
    procedure Parse_UnsupportedColumnCount_RaisesValidationError;
    procedure Parse_MissingFields_RaisesValidationError;
    procedure Parse_ExtraFields_RaisesValidationError;
    procedure Parse_WithoutResultRows_RaisesValidationError;
    procedure Parse_HeaderRow_IsSkipped;
    procedure Parse_ArbitraryHeaderRow_IsSkipped;
    procedure Parse_InvalidParticipantNumbers_RaiseValidationError;
    procedure Parse_DuplicateParticipantNumber_RaisesValidationError;
    procedure Parse_SupportedTimes_AreNormalized;
    procedure Parse_InvalidTimes_RaiseValidationError;
    procedure Parse_Corrections_MapPositiveNegativeAndZero;
    procedure Parse_InvalidCorrections_RaiseValidationError;
    procedure Parse_SixColumns_InvalidCorrections_RaiseValidationError;
    procedure Parse_ValidPenalties_AreNormalized;
    procedure Parse_InvalidPenalties_RaiseValidationError;
    procedure Parse_TextAndNumericStatuses_AreMapped;
    procedure Parse_InvalidStatuses_RaiseValidationError;
  end;

implementation

function TResultsCsvParserTests.BuildCsv(
  const ALines: array of string): string;
var
  line: string;
begin
  Result := '';
  for line in ALines do
  begin
    if Result <> '' then
      Result := Result + LineEnding;
    Result := Result + line;
  end;
end;

procedure TResultsCsvParserTests.AssertEmptyCsv(const ACsvText: string);
var
  parseResult: TResultsCsvParseResult;
begin
  parseResult := nil;
  try
    try
      parseResult := FParser.Parse(ACsvText);
    except
      on EEmptyCsv do
        Exit;
    end;
    Fail('Expected EEmptyCsv');
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.AssertParseError(const ACsvText: string;
  const AExceptionClass: ExceptClass);
var
  parseResult: TResultsCsvParseResult;
begin
  parseResult := nil;
  try
    try
      parseResult := FParser.Parse(ACsvText);
    except
      on E: Exception do
      begin
        if not E.ClassType.InheritsFrom(AExceptionClass) then
          Fail(Format('Expected %s, got %s',
            [AExceptionClass.ClassName, E.ClassName]));
        Exit;
      end;
    end;
    Fail('Expected ' + AExceptionClass.ClassName);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.AssertRowFieldCountMismatch(
  const ACsvText: string; const ARowNumber, AActualFieldCount,
  AExpectedFieldCount: integer);
var
  parseResult: TResultsCsvParseResult;
begin
  parseResult := nil;
  try
    try
      parseResult := FParser.Parse(ACsvText);
    except
      on E: EResultsRowFieldCountMismatch do
      begin
        AssertEquals(ARowNumber, E.RowNumber);
        AssertEquals(AActualFieldCount, E.ActualFieldCount);
        AssertEquals(AExpectedFieldCount, E.ExpectedFieldCount);
        Exit;
      end;
    end;
    Fail('Expected EResultsRowFieldCountMismatch');
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.SetUp;
begin
  FParser := TResultsCsvParser.Create;
end;

procedure TResultsCsvParserTests.TearDown;
begin
  FParser.Free;
end;

procedure TResultsCsvParserTests.Parse_EmptyText_RaisesValidationError;
begin
  AssertEmptyCsv('');
end;

procedure TResultsCsvParserTests.Parse_OnlyComments_RaisesValidationError;
begin
  AssertEmptyCsv(BuildCsv([
    '# number;finish time',
    '   # another comment'
  ]));
end;

procedure TResultsCsvParserTests.Parse_TwoColumns_MapsFinishRows;
var
  parseResult: TResultsCsvParseResult;
  item: TResultImportItem;
begin
  parseResult := FParser.Parse(BuildCsv([
    '# number;finish time',
    '101;11:00:00.123',
    '102;DNF'
  ]));
  try
    AssertEquals(Ord(rcfFinish), Ord(parseResult.Format));
    AssertEquals(2, parseResult.Items.Count);

    item := TResultImportItem(parseResult.Items[0]);
    AssertEquals(101, item.ParticipantNumber);
    AssertEquals('11:00:00.123', item.FinishTime);
    AssertFalse(item.HasStatus);

    item := TResultImportItem(parseResult.Items[1]);
    AssertEquals(102, item.ParticipantNumber);
    AssertEquals('', item.FinishTime);
    AssertTrue(item.HasStatus);
    AssertEquals(1, item.StatusCode);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_TwoColumns_EmptyFinishTime_RaisesValidationError;
begin
  AssertParseError('103;',
    EInvalidResultTime);
  AssertParseError('104;   ',
    EInvalidResultTime);
end;

procedure TResultsCsvParserTests.Parse_ThreeColumns_MapsStartRows;
var
  parseResult: TResultsCsvParseResult;
  item: TResultImportItem;
begin
  parseResult := FParser.Parse(BuildCsv([
    '# number;start time;correction',
    '201;10:00:00;-250',
    '202;10:01:00;DNS'
  ]));
  try
    AssertEquals(Ord(rcfStart), Ord(parseResult.Format));
    AssertEquals(2, parseResult.Items.Count);

    item := TResultImportItem(parseResult.Items[0]);
    AssertEquals(201, item.ParticipantNumber);
    AssertEquals('10:00:00', item.StartTime);
    AssertTrue(item.HasCorrection);
    AssertEquals(-250, item.Correction);
    AssertFalse(item.HasStatus);

    item := TResultImportItem(parseResult.Items[1]);
    AssertEquals(202, item.ParticipantNumber);
    AssertEquals('10:01:00', item.StartTime);
    AssertFalse(item.HasCorrection);
    AssertTrue(item.HasStatus);
    AssertEquals(2, item.StatusCode);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_ThreeColumns_EmptyStartTime_RaisesValidationError;
begin
  AssertParseError('203;;0',
    EInvalidResultTime);
  AssertParseError('204;   ;0',
    EInvalidResultTime);
end;

procedure TResultsCsvParserTests.Parse_ThreeColumns_DnsInStartTime_RaisesValidationError;
begin
  AssertParseError('205;DNS;',
    EInvalidResultTime);
end;

procedure TResultsCsvParserTests.Parse_SixColumns_MapsFullStageRow;
var
  parseResult: TResultsCsvParseResult;
  item: TResultImportItem;
begin
  parseResult := FParser.Parse(BuildCsv([
    '# number;start time;correction;finish time;penalty;status',
    '301;10:00:00;-250;11:00:00.123;00:00:05;1'
  ]));
  try
    AssertEquals(Ord(rcfFullStage), Ord(parseResult.Format));
    AssertEquals(1, parseResult.Items.Count);

    item := TResultImportItem(parseResult.Items[0]);
    AssertEquals(301, item.ParticipantNumber);
    AssertEquals('10:00:00', item.StartTime);
    AssertTrue(item.HasCorrection);
    AssertEquals(-250, item.Correction);
    AssertEquals('11:00:00.123', item.FinishTime);
    AssertEquals('00:00:05', item.Penalty);
    AssertTrue(item.HasStatus);
    AssertEquals(1, item.StatusCode);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_FormatIsDeterminedByFirstDataRow;
begin
  AssertRowFieldCountMismatch(BuildCsv([
    '401;11:00:00',
    '402;12:00:00;unexpected;value'
  ]), 2, 4, 2);
end;

procedure TResultsCsvParserTests.Parse_UnsupportedColumnCount_RaisesValidationError;
begin
  AssertParseError('501',
    EUnsupportedResultsColumnCount);
  AssertParseError('501;a;b;c',
    EUnsupportedResultsColumnCount);
  AssertParseError('501;a;b;c;d',
    EUnsupportedResultsColumnCount);
  AssertParseError('501;a;b;c;d;e;f',
    EUnsupportedResultsColumnCount);
end;

procedure TResultsCsvParserTests.Parse_MissingFields_RaisesValidationError;
begin
  AssertRowFieldCountMismatch(BuildCsv([
    '601;11:00:00',
    '602'
  ]), 2, 1, 2);
end;

procedure TResultsCsvParserTests.Parse_ExtraFields_RaisesValidationError;
begin
  AssertRowFieldCountMismatch(BuildCsv([
    '611;11:00:00',
    '612;12:00:00;unexpected'
  ]), 2, 3, 2);
end;

procedure TResultsCsvParserTests.Parse_WithoutResultRows_RaisesValidationError;
begin
  AssertParseError(BuildCsv([
    ';',
    ';;'
  ]), EResultsRowsNotFound);
  AssertParseError('number;finishtime',
    EResultsRowsNotFound);
end;

procedure TResultsCsvParserTests.Parse_HeaderRow_IsSkipped;
var
  parseResult: TResultsCsvParseResult;
  item: TResultImportItem;
begin
  parseResult := FParser.Parse(BuildCsv([
    'number;finishtime',
    '901;11:00:00'
  ]));
  try
    AssertEquals(Ord(rcfFinish), Ord(parseResult.Format));
    AssertEquals(1, parseResult.Items.Count);
    item := TResultImportItem(parseResult.Items[0]);
    AssertEquals(901, item.ParticipantNumber);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_ArbitraryHeaderRow_IsSkipped;
var
  parseResult: TResultsCsvParseResult;
  item: TResultImportItem;
begin
  parseResult := FParser.Parse(BuildCsv([
    'Произвольный заголовок;Время финиша',
    '902;11:00:00'
  ]));
  try
    AssertEquals(Ord(rcfFinish), Ord(parseResult.Format));
    AssertEquals(1, parseResult.Items.Count);
    item := TResultImportItem(parseResult.Items[0]);
    AssertEquals(902, item.ParticipantNumber);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_InvalidParticipantNumbers_RaiseValidationError;
begin
  AssertParseError(BuildCsv([
    '900;10:00:00',
    ';11:00:00'
  ]),
    EInvalidResultParticipantNumber);
  AssertParseError(BuildCsv([
    '900;10:00:00',
    '0;11:00:00'
  ]),
    EInvalidResultParticipantNumber);
  AssertParseError(BuildCsv([
    '900;10:00:00',
    '-1;11:00:00'
  ]),
    EInvalidResultParticipantNumber);
  AssertParseError(BuildCsv([
    '900;10:00:00',
    'not-a-number;11:00:00'
  ]),
    EInvalidResultParticipantNumber);
  AssertParseError(BuildCsv([
    '900;10:00:00',
    '999999999999999999999;11:00:00'
  ]),
    EInvalidResultParticipantNumber);
end;

procedure TResultsCsvParserTests.Parse_DuplicateParticipantNumber_RaisesValidationError;
var
  parseResult: TResultsCsvParseResult;
begin
  parseResult := nil;
  try
    try
      parseResult := FParser.Parse(BuildCsv([
        '# comment before results',
        '701;11:00:00',
        '# comment between results',
        '701;12:00:00'
      ]));
    except
      on E: EDuplicateResultParticipantNumber do
      begin
        AssertEquals(701, E.ParticipantNumber);
        AssertEquals(2, E.FirstRowNumber);
        AssertEquals(4, E.DuplicateRowNumber);
        Exit;
      end;
    end;
    Fail('Expected EDuplicateResultParticipantNumber');
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_SupportedTimes_AreNormalized;
var
  parseResult: TResultsCsvParseResult;
  item: TResultImportItem;
begin
  parseResult := FParser.Parse(BuildCsv([
    '801;09:15;;10:20;;',
    '802;09:15:42;;10:20:30;;',
    '803;09:15:42,123;;10:20:30,456;;',
    '804;09:15:42.123;;10:20:30.456;;'
  ]));
  try
    item := TResultImportItem(parseResult.Items[0]);
    AssertEquals('09:15', item.StartTime);
    AssertEquals('10:20', item.FinishTime);

    item := TResultImportItem(parseResult.Items[1]);
    AssertEquals('09:15:42', item.StartTime);
    AssertEquals('10:20:30', item.FinishTime);

    item := TResultImportItem(parseResult.Items[2]);
    AssertEquals('09:15:42.123', item.StartTime);
    AssertEquals('10:20:30.456', item.FinishTime);

    item := TResultImportItem(parseResult.Items[3]);
    AssertEquals('09:15:42.123', item.StartTime);
    AssertEquals('10:20:30.456', item.FinishTime);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_InvalidTimes_RaiseValidationError;
begin
  AssertParseError('811;24:00',
    EInvalidResultTime);
  AssertParseError('812;12:60',
    EInvalidResultTime);
  AssertParseError('813;12:00:60',
    EInvalidResultTime);
  AssertParseError('814;text',
    EInvalidResultTime);
  AssertParseError('815;25:00;0',
    EInvalidResultTime);
end;

procedure TResultsCsvParserTests.Parse_Corrections_MapPositiveNegativeAndZero;
var
  parseResult: TResultsCsvParseResult;
  item: TResultImportItem;
begin
  parseResult := FParser.Parse(BuildCsv([
    '902;10:00;250',
    '903;10:00;-250',
    '904;10:00;0'
  ]));
  try
    item := TResultImportItem(parseResult.Items[0]);
    AssertTrue(item.HasCorrection);
    AssertEquals(250, item.Correction);

    item := TResultImportItem(parseResult.Items[1]);
    AssertTrue(item.HasCorrection);
    AssertEquals(-250, item.Correction);

    item := TResultImportItem(parseResult.Items[2]);
    AssertTrue(item.HasCorrection);
    AssertEquals(0, item.Correction);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_InvalidCorrections_RaiseValidationError;
begin
  AssertParseError('910;10:00;',
    EInvalidResultCorrection);
  AssertParseError('911;10:00;invalid',
    EInvalidResultCorrection);
  AssertParseError('912;10:00;999999999999999999999',
    EInvalidResultCorrection);
end;

procedure TResultsCsvParserTests.Parse_SixColumns_InvalidCorrections_RaiseValidationError;
begin
  AssertParseError('913;10:00;invalid;11:00;;',
    EInvalidResultCorrection);
  AssertParseError('914;10:00;999999999999999999999;11:00;;',
    EInvalidResultCorrection);
end;

procedure TResultsCsvParserTests.Parse_ValidPenalties_AreNormalized;
var
  parseResult: TResultsCsvParseResult;
begin
  parseResult := FParser.Parse(BuildCsv([
    '1001;10:00;;11:00;05:30;',
    '1002;10:00;;11:00;23:05:30;',
    '1003;10:00;;11:00;45;'
  ]));
  try
    AssertEquals('00:05:30',
      TResultImportItem(parseResult.Items[0]).Penalty);
    AssertEquals('23:05:30',
      TResultImportItem(parseResult.Items[1]).Penalty);
    AssertEquals('00:00:45',
      TResultImportItem(parseResult.Items[2]).Penalty);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_InvalidPenalties_RaiseValidationError;
begin
  AssertParseError('1011;10:00;;11:00;05:60;',
    EInvalidResultPenalty);
  AssertParseError('1012;10:00;;11:00;01:60:00;',
    EInvalidResultPenalty);
  AssertParseError('1013;10:00;;11:00;text;',
    EInvalidResultPenalty);
  AssertParseError('1014;10:00;;11:00;01:05:30.125;',
    EInvalidResultPenalty);
  AssertParseError('1015;10:00;;11:00;01:05:30,125;',
    EInvalidResultPenalty);
  AssertParseError('1016;10:00;;11:00;24:00:00;',
    EInvalidResultPenalty);
end;

procedure TResultsCsvParserTests.Parse_TextAndNumericStatuses_AreMapped;
var
  parseResult: TResultsCsvParseResult;
begin
  parseResult := FParser.Parse(BuildCsv([
    '1101;10:00;;11:00;;DNF',
    '1102;10:00;;11:00;;dnf',
    '1103;10:00;;11:00;;DNS',
    '1104;10:00;;11:00;;DSQ',
    '1105;10:00;;11:00;;1',
    '1106;10:00;;11:00;;2',
    '1107;10:00;;11:00;;3',
    '1108;10:00;;11:00;;'
  ]));
  try
    AssertEquals(1, TResultImportItem(parseResult.Items[0]).StatusCode);
    AssertEquals(1, TResultImportItem(parseResult.Items[1]).StatusCode);
    AssertEquals(2, TResultImportItem(parseResult.Items[2]).StatusCode);
    AssertEquals(3, TResultImportItem(parseResult.Items[3]).StatusCode);
    AssertEquals(1, TResultImportItem(parseResult.Items[4]).StatusCode);
    AssertEquals(2, TResultImportItem(parseResult.Items[5]).StatusCode);
    AssertEquals(3, TResultImportItem(parseResult.Items[6]).StatusCode);
    AssertFalse(TResultImportItem(parseResult.Items[7]).HasStatus);
  finally
    parseResult.Free;
  end;
end;

procedure TResultsCsvParserTests.Parse_InvalidStatuses_RaiseValidationError;
begin
  AssertParseError('1111;10:00;;11:00;;0',
    EInvalidResultStatus);
  AssertParseError('1112;10:00;;11:00;;4',
    EInvalidResultStatus);
  AssertParseError('1113;10:00;;11:00;;unknown',
    EInvalidResultStatus);
end;

initialization
  RegisterTest(TResultsCsvParserTests);

end.
