unit StageModelTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, StageConfig, StageModel;

type
  TStageModelTests = class(TTestCase)
  published
    procedure Create_InitializesContiguousDefaultStages;
    procedure Resize_PreservesExistingStagesAndCreatesDefaults;
    procedure Resize_RejectsUnsupportedStageCount;
    procedure Items_RejectInvalidIndex;
    procedure EnsureActiveStage_ActivatesFirstStageWhenNeeded;
    procedure ActiveIndexHelpers_ValidateAndNormalizeSparseStages;
    procedure ActiveIndices_ReturnsSparseStagesInIndexOrder;
  end;

implementation

procedure TStageModelTests.Create_InitializesContiguousDefaultStages;
const
  STAGE_COUNTS: array[0..2] of integer = (1, 8, 12);
var
  Stages: TStages;
  StageCount: integer;
begin
  for StageCount in STAGE_COUNTS do
  begin
    Stages := TStages.Create(StageCount);
    try
      AssertEquals(StageCount, Stages.Count);
      AssertEquals(1, Stages[1].Index);
      AssertEquals(StageCount, Stages[StageCount].Index);
      AssertEquals('СУ 1', Stages[1].Name);
      AssertEquals(Format('СУ %d', [StageCount]),
        Stages[StageCount].Name);
      AssertEquals(1, Stages.FirstActiveIndex);
      AssertEquals(1, Stages.ActiveStagesCount);
    finally
      Stages.Free;
    end;
  end;
end;

procedure TStageModelTests.ActiveIndices_ReturnsSparseStagesInIndexOrder;
var
  Stages: TStages;
  Indices: TStageIndexArray;
begin
  Stages := TStages.Create(8);
  try
    Stages[1].isActive := True;
    Stages[3].isActive := True;
    Stages[5].isActive := True;
    Indices := Stages.ActiveIndices;
    AssertEquals(3, Length(Indices));
    AssertEquals(1, Indices[0]);
    AssertEquals(3, Indices[1]);
    AssertEquals(5, Indices[2]);
  finally
    Stages.Free;
  end;
end;

procedure TStageModelTests.Resize_PreservesExistingStagesAndCreatesDefaults;
var
  Stages: TStages;
begin
  Stages := TStages.Create(2);
  try
    Stages[2].Name := 'Custom stage';
    Stages[2].isActive := True;
    Stages.Resize(4);

    AssertEquals(4, Stages.Count);
    AssertEquals(2, Stages[2].Index);
    AssertEquals(4, Stages[4].Index);
    AssertEquals('Custom stage', Stages[2].Name);
    AssertEquals('СУ 4', Stages[4].Name);

    Stages.Resize(1);
    AssertEquals(1, Stages.Count);
    AssertEquals(1, Stages.FirstActiveIndex);
  finally
    Stages.Free;
  end;
end;

procedure TStageModelTests.Resize_RejectsUnsupportedStageCount;
var
  Stages: TStages;
begin
  Stages := TStages.Create;
  try
    try
      Stages.Resize(MAX_SUPPORTED_STAGE_COUNT + 1);
      Fail('Expected an exception for an unsupported stage count');
    except
      on E: EArgumentOutOfRangeException do
        AssertTrue(True);
    end;
  finally
    Stages.Free;
  end;
end;

procedure TStageModelTests.Items_RejectInvalidIndex;
var
  Stages: TStages;
begin
  Stages := TStages.Create(1);
  try
    try
      Stages[0].isActive := False;
      Fail('Expected an exception for index zero');
    except
      on E: EArgumentOutOfRangeException do
        AssertTrue(True);
    end;
  finally
    Stages.Free;
  end;
end;

procedure TStageModelTests.EnsureActiveStage_ActivatesFirstStageWhenNeeded;
var
  Stages: TStages;
begin
  Stages := TStages.Create(3);
  try
    Stages[1].isActive := False;
    AssertEquals(0, Stages.FirstActiveIndex);

    Stages.EnsureActiveStage;
    AssertEquals(1, Stages.FirstActiveIndex);
  finally
    Stages.Free;
  end;
end;

procedure TStageModelTests.ActiveIndexHelpers_ValidateAndNormalizeSparseStages;
var
  Stages: TStages;
begin
  Stages := TStages.Create(12);
  try
    Stages[1].isActive := False;
    Stages[12].isActive := True;

    AssertFalse(Stages.IsActiveIndex(0));
    AssertFalse(Stages.IsActiveIndex(1));
    AssertTrue(Stages.IsActiveIndex(12));
    AssertFalse(Stages.IsActiveIndex(13));
    AssertEquals(12, Stages.NormalizeActiveIndex(12));
    AssertEquals(12, Stages.NormalizeActiveIndex(1));
    AssertEquals(12, Stages.NormalizeActiveIndex(32));
  finally
    Stages.Free;
  end;
end;

initialization
  RegisterTest(TStageModelTests);

end.
