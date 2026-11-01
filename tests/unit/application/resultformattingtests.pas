unit ResultFormattingTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DB, MemDS, fpcunit, testregistry,
  ResultFormatting;

type
  TResultFormattingTests = class(TTestCase)
  private
    FDataSet: TMemDataset;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure HideLeadingZeroHour_StringPreservesExistingContract;
    procedure HideLeadingZeroHour_FieldHonorsEnabledFlag;
    procedure NumberAndPlaceFormatting_PreserveFixedWidthContract;
    procedure TimeFormatting_RemovesLeadingZeroComponents;
    procedure DifferenceFormatting_RemovesLeadingZerosAndPreservesSign;
    procedure LedLine_PreservesLegacyShortLayout;
    procedure LedLine_ClipsFractionFromRight;
    procedure LedLine_LargeSignedDifferenceUsesLineSlack;
    procedure PenaltyInput_AcceptsDigitsBackspaceAndNormalizesSeparators;
  end;

implementation

procedure TResultFormattingTests.SetUp;
begin
  FDataSet := TMemDataset.Create(nil);
  FDataSet.FieldDefs.Add('value', ftString, 20);
  FDataSet.Open;
  FDataSet.Append;
end;

procedure TResultFormattingTests.TearDown;
begin
  FDataSet.Free;
end;

procedure TResultFormattingTests.HideLeadingZeroHour_StringPreservesExistingContract;
begin
  AssertEquals('', HideLeadingZeroHour(''));
  AssertEquals('05:06.789', HideLeadingZeroHour('00:05:06.789'));
  AssertEquals('01:05:06.789', HideLeadingZeroHour('01:05:06.789'));
  AssertEquals('DNF', HideLeadingZeroHour('DNF'));
end;

procedure TResultFormattingTests.HideLeadingZeroHour_FieldHonorsEnabledFlag;
begin
  FDataSet.FieldByName('value').AsString := '00:05:06.789';
  AssertEquals('05:06.789', HideLeadingZeroHour(
    FDataSet.FieldByName('value'), True));
  AssertEquals('00:05:06.789', HideLeadingZeroHour(
    FDataSet.FieldByName('value'), False));

  FDataSet.FieldByName('value').AsString := '01:05:06.789';
  AssertEquals('01:05:06.789', HideLeadingZeroHour(
    FDataSet.FieldByName('value'), True));
  FDataSet.FieldByName('value').AsString := 'DNF';
  AssertEquals('DNF', HideLeadingZeroHour(FDataSet.FieldByName('value'), True));
end;

procedure TResultFormattingTests.NumberAndPlaceFormatting_PreserveFixedWidthContract;
begin
  AssertEquals('  7', FormatNumber(7));
  AssertEquals('1234', FormatNumber(1234));
  AssertEquals('  7', FormatPlace(7));
end;

procedure TResultFormattingTests.TimeFormatting_RemovesLeadingZeroComponents;
const
  Values: array[0..9] of string = ('', '00:00:00.000', '00:02:34.567',
    '00:59:59.999', '01:00:00.000', '01:02:03.456', '10:02:03.456',
    '25:02:03.456', '100:02:03.456', '00:00:03.456');
  Expected: array[0..9] of string = ('', '0.000', '2:34.567',
    '59:59.999', '1:00:00.000', '1:02:03.456', '10:02:03.456',
    '25:02:03.456', '100:02:03.456', '3.456');
var
  I: integer;
begin
  for I := Low(Values) to High(Values) do
    AssertEquals('Remove only leading zero components: ' + Values[I],
      Expected[I], FormatTime(Values[I]));
end;

procedure TResultFormattingTests.
DifferenceFormatting_RemovesLeadingZerosAndPreservesSign;
begin
  AssertEquals('1:02:03.456', FormatDiff('01:02:03.456', ''));
  AssertEquals('-10:02:03.456', FormatDiff('10:02:03.456', '-'));
  AssertEquals('+100:02:03.456', FormatDiff('100:02:03.456', '+'));
  AssertEquals('12:03.456', FormatDiff('00:12:03.456', ''));
  AssertEquals('-2:03.456', FormatDiff('00:02:03.456', '-'));
  AssertEquals('-3.456', FormatDiff('00:00:03.456', '-'));
  AssertEquals('       ', FormatDiff(''));
end;

procedure TResultFormattingTests.LedLine_PreservesLegacyShortLayout;
begin
  AssertEquals('  7  2:34.567 - 3.456   2',
    FormatLEDLine(7, '00:02:34.567', '00:00:03.456', 2, '-'));
  AssertEquals('  7 12:34.567 12:03.4   2',
    FormatLEDLine(7, '00:12:34.567', '00:12:03.456', 2));
end;

procedure TResultFormattingTests.LedLine_ClipsFractionFromRight;
begin
  AssertEquals('  7 1:02:03.4 - 3.456   2',
    FormatLEDLine(7, '01:02:03.456', '00:00:03.456', 2, '-'));
  AssertEquals('  7  10:02:03 - 3.456   2',
    FormatLEDLine(7, '10:02:03.456', '00:00:03.456', 2, '-'));
  AssertEquals('  7 1:02:03.4 - 12:03   2',
    FormatLEDLine(7, '01:02:03.456', '00:12:03.456', 2, '-'));
end;

procedure TResultFormattingTests.LedLine_LargeSignedDifferenceUsesLineSlack;
var
  Line: string;
begin
  Line := FormatLEDLine(7, '10:02:03.456', '10:02:03.456', 2, '-');
  AssertEquals('  7 10:02:03 -10:02:03   2', Line);
  AssertEquals('A complete line must fit 26 full glyphs on the panel', 26, Length(Line));
  AssertEquals('1234  1:02:03 -1:02:03   2',
    FormatLEDLine(1234, '01:02:03.456', '01:02:03.456', 2, '-'));
  AssertEquals('7 100:02:03 -100:02:03   2',
    FormatLEDLine(7, '100:02:03.456', '100:02:03.456', 2, '-'));
  AssertEquals('123 100:02:03 -100:02:03 2',
    FormatLEDLine(123, '100:02:03.456', '100:02:03.456', 2, '-'));
end;

procedure TResultFormattingTests.
PenaltyInput_AcceptsDigitsBackspaceAndNormalizesSeparators;
const
  Separators: array[0..8] of char = (
    ',', '.', '/', '\', ':', '*', '-', '+', '?'
    );
var
  Separator: char;
begin
  AssertEquals(Ord('0'), Ord(CheckPenaltyInput('0')));
  AssertEquals(Ord('9'), Ord(CheckPenaltyInput('9')));
  AssertEquals(8, Ord(CheckPenaltyInput(#8)));
  for Separator in Separators do
    AssertEquals(Ord(':'), Ord(CheckPenaltyInput(Separator)));
  AssertEquals(0, Ord(CheckPenaltyInput('A')));
  AssertEquals(0, Ord(CheckPenaltyInput(' ')));
end;

initialization
  RegisterTest(TResultFormattingTests);

end.
