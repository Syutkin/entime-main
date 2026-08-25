unit ParticipantStageDataTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, ParticipantStatus, ParticipantStageData;

type
  TParticipantStageDataTests = class(TTestCase)
  published
    procedure Create_InitializesEmptyStageData;
    procedure Create_RejectsNonPositiveStageIndex;
    procedure OptionalIntegers_DistinguishZeroFromMissingValue;
  end;

implementation

procedure TParticipantStageDataTests.Create_InitializesEmptyStageData;
var
  Data: TParticipantStageData;
begin
  Data := TParticipantStageData.Create(12);

  AssertEquals(12, Data.StageIndex);
  AssertEquals('', Data.StartTime);
  AssertFalse(Data.HasCorrection);
  AssertEquals(0, Data.Correction);
  AssertEquals('', Data.FinishTime);
  AssertEquals('', Data.Penalty);
  AssertEquals('', Data.ResultValue);
  AssertEquals('', Data.DiffLeader);
  AssertFalse(Data.HasPlace);
  AssertEquals(0, Data.Place);
  AssertEquals(Ord(psNone), Ord(Data.Status));
end;

procedure TParticipantStageDataTests.Create_RejectsNonPositiveStageIndex;
begin
  try
    TParticipantStageData.Create(0);
    Fail('Expected an exception for stage index zero');
  except
    on E: EArgumentOutOfRangeException do
      AssertTrue(True);
  end;
end;

procedure TParticipantStageDataTests.OptionalIntegers_DistinguishZeroFromMissingValue;
var
  Data: TParticipantStageData;
begin
  Data := TParticipantStageData.Create(1);

  Data.HasCorrection := True;
  Data.Correction := 0;
  Data.HasPlace := True;
  Data.Place := 0;

  AssertTrue(Data.HasCorrection);
  AssertEquals(0, Data.Correction);
  AssertTrue(Data.HasPlace);
  AssertEquals(0, Data.Place);
end;

initialization
  RegisterTest(TParticipantStageDataTests);

end.
