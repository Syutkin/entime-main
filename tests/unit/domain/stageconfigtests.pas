unit StageConfigTests;

{$mode ObjFPC}{$H+}

interface

uses
  fpcunit, testregistry, StageConfig;

type
  TStageConfigTests = class(TTestCase)
  published
    procedure IsValidStageCount_AcceptsConfiguredBounds;
    procedure IsValidStageCount_RejectsValuesOutsideBounds;
    procedure NormalizeStageCount_UsesValidValueOrFallback;
  end;

implementation

procedure TStageConfigTests.IsValidStageCount_AcceptsConfiguredBounds;
begin
  AssertTrue(IsValidStageCount(MIN_STAGE_COUNT));
  AssertTrue(IsValidStageCount(DEFAULT_STAGE_COUNT));
  AssertTrue(IsValidStageCount(MAX_SUPPORTED_STAGE_COUNT));
end;

procedure TStageConfigTests.IsValidStageCount_RejectsValuesOutsideBounds;
begin
  AssertFalse(IsValidStageCount(MIN_STAGE_COUNT - 1));
  AssertFalse(IsValidStageCount(MAX_SUPPORTED_STAGE_COUNT + 1));
end;

procedure TStageConfigTests.NormalizeStageCount_UsesValidValueOrFallback;
begin
  AssertEquals(12, NormalizeStageCount(12, DEFAULT_STAGE_COUNT));
  AssertEquals(DEFAULT_STAGE_COUNT,
    NormalizeStageCount(0, DEFAULT_STAGE_COUNT));
  AssertEquals(DEFAULT_STAGE_COUNT,
    NormalizeStageCount(MAX_SUPPORTED_STAGE_COUNT + 1, 0));
end;

initialization
  RegisterTest(TStageConfigTests);

end.
