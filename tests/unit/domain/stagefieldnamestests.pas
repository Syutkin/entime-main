unit StageFieldNamesTests;

{$mode ObjFPC}{$H+}

interface

uses
  fpcunit, testregistry, StageFieldNames;

type
  TStageFieldNamesTests = class(TTestCase)
  published
    procedure Parser_RecognizesEveryStageFieldKind;
    procedure Parser_ReadsFullSupportedSuffix;
    procedure Parser_RejectsMalformedAndUnsupportedNames;
  end;

implementation

procedure TStageFieldNamesTests.Parser_RecognizesEveryStageFieldKind;
var
  Kind, ParsedKind: TStageFieldKind;
  StageIndex: integer;
begin
  for Kind := Succ(sfkUnknown) to High(TStageFieldKind) do
  begin
    AssertTrue(StageFieldPrefix(Kind), TryParseStageFieldName(
      StageFieldPrefix(Kind) + '8', ParsedKind, StageIndex));
    AssertEquals(Ord(Kind), Ord(ParsedKind));
    AssertEquals(8, StageIndex);
  end;
end;

procedure TStageFieldNamesTests.Parser_ReadsFullSupportedSuffix;
var
  Kind: TStageFieldKind;
  StageIndex: integer;
begin
  AssertTrue(TryParseStageFieldName('penalty12', Kind, StageIndex));
  AssertEquals(Ord(sfkPenalty), Ord(Kind));
  AssertEquals(12, StageIndex);

  AssertTrue(TryParseStageFieldName('status32', Kind, StageIndex));
  AssertEquals(Ord(sfkStatus), Ord(Kind));
  AssertEquals(32, StageIndex);

  AssertTrue(TryGetStageIndexFromFieldName('StartTime1', StageIndex));
  AssertEquals(1, StageIndex);
end;

procedure TStageFieldNamesTests.Parser_RejectsMalformedAndUnsupportedNames;
var
  Kind: TStageFieldKind;
  StageIndex: integer;
begin
  AssertFalse(TryParseStageFieldName('penalty', Kind, StageIndex));
  AssertFalse(TryParseStageFieldName('penalty0', Kind, StageIndex));
  AssertFalse(TryParseStageFieldName('penalty01', Kind, StageIndex));
  AssertFalse(TryParseStageFieldName('penalty33', Kind, StageIndex));
  AssertFalse(TryParseStageFieldName('penalty12x', Kind, StageIndex));
  AssertFalse(TryParseStageFieldName('sumresult', Kind, StageIndex));
  AssertFalse(TryParseStageFieldName('participant12', Kind, StageIndex));
  AssertEquals(Ord(sfkUnknown), Ord(Kind));
  AssertEquals(0, StageIndex);
end;

initialization
  RegisterTest(TStageFieldNamesTests);

end.
