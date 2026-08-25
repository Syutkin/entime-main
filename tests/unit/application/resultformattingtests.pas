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
    procedure NumberTimeAndPlaceFormatting_PreserveFixedWidthContract;
    procedure DifferenceFormatting_PreservesEveryMagnitudeBranch;
    procedure LedLine_ComposesFixedWidthFields;
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
  AssertEquals('DNF', HideLeadingZeroHour(
    FDataSet.FieldByName('value'), True));
end;

procedure TResultFormattingTests.NumberTimeAndPlaceFormatting_PreserveFixedWidthContract;
begin
  AssertEquals('  7', FormatNumber(7));
  AssertEquals('1234', FormatNumber(1234));
  AssertEquals(' 2:34.567', FormatTime('00:02:34.567'));
  AssertEquals('12:34.567', FormatTime('00:12:34.567'));
  AssertEquals('  7', FormatPlace(7));
end;

procedure TResultFormattingTests.DifferenceFormatting_PreservesEveryMagnitudeBranch;
begin
  AssertEquals('1:02:03', FormatDiff('01:02:03.456'));
  AssertEquals('12:03.4', FormatDiff('00:12:03.456'));
  AssertEquals('-2:03.4', FormatDiff('00:02:03.456', '-'));
  AssertEquals('- 3.456', FormatDiff('00:00:03.456', '-'));
  AssertEquals('       ', FormatDiff(''));
end;

procedure TResultFormattingTests.LedLine_ComposesFixedWidthFields;
begin
  AssertEquals('  7  2:34.567 - 3.456   2',
    FormatLEDLine(7, '00:02:34.567', '00:00:03.456', 2, '-'));
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
