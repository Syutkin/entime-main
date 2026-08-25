unit StartMarkMatcherTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, FPCUnit, TestRegistry, TimingMark, StartMark, StartMarkMatcher;

type
  TStartMarkMatcherTests = class(TTestCase)
  private
    function MarkAt(const ATime: TDateTime;
      const AStageIndex: integer = 2): TStartMark;
    function Candidate(const AParticipantNumber, AStageIndex: integer;
      const AStartTime: TDateTime): TStartMarkCandidate;
  published
    procedure Match_OneCandidateWithinTolerance;
    procedure Match_SelectsNearestCandidateRegardlessOfOrder;
    procedure Match_AcceptsCandidateExactlyAtToleranceBoundary;
    procedure Match_AcceptsMaximumBoundariesAndRejectsOutside;
    procedure Match_RejectsToleranceOutsideSupportedRange;
    procedure Match_NoCandidatesReturnsNoMatch;
    procedure Match_EquallyNearestCandidatesReturnAmbiguous;
    procedure Match_HandlesMidnightWrapInBothDirections;
    procedure Match_IgnoresCandidatesFromOtherStages;
  end;

implementation

function TStartMarkMatcherTests.MarkAt(const ATime: TDateTime;
  const AStageIndex: integer): TStartMark;
begin
  Result := TStartMark.FromTimingMark(TTimingMark.Start(ATime, True, 10,
    TTimingMarkSource.Serial('COM1'), EncodeDate(2026, 8, 13) + ATime),
    AStageIndex);
end;

function TStartMarkMatcherTests.Candidate(const AParticipantNumber,
  AStageIndex: integer; const AStartTime: TDateTime): TStartMarkCandidate;
begin
  Result := TStartMarkCandidate.Create(AParticipantNumber, AStageIndex,
    AStartTime);
end;

procedure TStartMarkMatcherTests.Match_OneCandidateWithinTolerance;
var
  Candidates: array[0..0] of TStartMarkCandidate;
  Match: TStartMarkMatch;
begin
  Candidates[0] := Candidate(17, 2, EncodeTime(10, 0, 10, 250));

  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(10, 0, 0, 0)),
    Candidates, 15);

  AssertEquals(Ord(smmMatched), Ord(Match.Status));
  AssertTrue(Match.HasParticipantNumber);
  AssertEquals(17, Match.ParticipantNumber);
  AssertTrue(Match.HasDeltaMs);
  AssertEquals(10250, Match.DeltaMs);
  AssertEquals('', Match.Reason);
end;

procedure TStartMarkMatcherTests.Match_SelectsNearestCandidateRegardlessOfOrder;
var
  Candidates: array[0..2] of TStartMarkCandidate;
  Match: TStartMarkMatch;
begin
  Candidates[0] := Candidate(30, 2, EncodeTime(9, 59, 50, 0));
  Candidates[1] := Candidate(20, 2, EncodeTime(10, 0, 2, 0));
  Candidates[2] := Candidate(10, 2, EncodeTime(10, 0, 8, 0));

  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(10, 0, 0, 0)),
    Candidates, 15);

  AssertEquals(Ord(smmMatched), Ord(Match.Status));
  AssertEquals(20, Match.ParticipantNumber);
  AssertEquals(2000, Match.DeltaMs);
end;

procedure TStartMarkMatcherTests.Match_AcceptsCandidateExactlyAtToleranceBoundary;
var
  Candidates: array[0..0] of TStartMarkCandidate;
  Match: TStartMarkMatch;
begin
  Candidates[0] := Candidate(17, 2, EncodeTime(10, 0, 15, 0));

  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(10, 0, 0, 0)),
    Candidates, 15);

  AssertEquals(Ord(smmMatched), Ord(Match.Status));
  AssertEquals(15000, Match.DeltaMs);
end;

procedure TStartMarkMatcherTests.Match_AcceptsMaximumBoundariesAndRejectsOutside;
var
  Candidates: array[0..3] of TStartMarkCandidate;
  OutsideCandidates: array[0..1] of TStartMarkCandidate;
  Match: TStartMarkMatch;
begin
  Candidates[0] := Candidate(1, 2, EncodeTime(11, 59, 0, 0));
  Candidates[1] := Candidate(2, 2, EncodeTime(12, 1, 0, 0));
  Candidates[2] := Candidate(3, 2, EncodeTime(11, 58, 59, 999));
  Candidates[3] := Candidate(4, 2, EncodeTime(12, 1, 0, 1));

  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(12, 0, 0, 0)),
    Candidates, 60);

  AssertEquals(Ord(smmAmbiguous), Ord(Match.Status));
  AssertFalse(Match.HasParticipantNumber);
  AssertTrue(Match.HasDeltaMs);
  AssertEquals(60000, Match.DeltaMs);

  OutsideCandidates[0] := Candidates[2];
  OutsideCandidates[1] := Candidates[3];
  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(12, 0, 0, 0)),
    OutsideCandidates, 60);
  AssertEquals(Ord(smmNoMatch), Ord(Match.Status));
end;

procedure TStartMarkMatcherTests.Match_RejectsToleranceOutsideSupportedRange;
var
  Candidates: array of TStartMarkCandidate;
begin
  Candidates := nil;
  try
    TStartMarkMatcher.Match(MarkAt(EncodeTime(10, 0, 0, 0)),
      Candidates, -1);
    Fail('A negative tolerance must be rejected.');
  except
    on E: EArgumentOutOfRangeException do
      AssertTrue(Pos('tolerance', LowerCase(E.Message)) > 0);
  end;

  try
    TStartMarkMatcher.Match(MarkAt(EncodeTime(10, 0, 0, 0)),
      Candidates, 61);
    Fail('A tolerance above 60 seconds must be rejected.');
  except
    on E: EArgumentOutOfRangeException do
      AssertTrue(Pos('tolerance', LowerCase(E.Message)) > 0);
  end;
end;

procedure TStartMarkMatcherTests.Match_NoCandidatesReturnsNoMatch;
var
  Candidates: array[0..1] of TStartMarkCandidate;
  Match: TStartMarkMatch;
begin
  Candidates[0] := Candidate(1, 2, EncodeTime(9, 59, 44, 999));
  Candidates[1] := Candidate(2, 2, EncodeTime(10, 0, 15, 1));

  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(10, 0, 0, 0)),
    Candidates, 15);

  AssertEquals(Ord(smmNoMatch), Ord(Match.Status));
  AssertFalse(Match.HasParticipantNumber);
  AssertFalse(Match.HasDeltaMs);
  AssertEquals('no_match', Match.Reason);
end;

procedure TStartMarkMatcherTests.Match_EquallyNearestCandidatesReturnAmbiguous;
var
  Candidates: array[0..2] of TStartMarkCandidate;
  Match: TStartMarkMatch;
begin
  Candidates[0] := Candidate(10, 2, EncodeTime(9, 59, 55, 0));
  Candidates[1] := Candidate(20, 2, EncodeTime(10, 0, 5, 0));
  Candidates[2] := Candidate(30, 2, EncodeTime(10, 0, 8, 0));

  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(10, 0, 0, 0)),
    Candidates, 15);

  AssertEquals(Ord(smmAmbiguous), Ord(Match.Status));
  AssertFalse(Match.HasParticipantNumber);
  AssertTrue(Match.HasDeltaMs);
  AssertEquals(5000, Match.DeltaMs);
  AssertEquals('ambiguous', Match.Reason);
end;

procedure TStartMarkMatcherTests.Match_HandlesMidnightWrapInBothDirections;
var
  Candidates: array[0..0] of TStartMarkCandidate;
  Match: TStartMarkMatch;
begin
  Candidates[0] := Candidate(1, 2, EncodeTime(0, 0, 5, 0));
  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(23, 59, 55, 0)),
    Candidates, 15);
  AssertEquals(Ord(smmMatched), Ord(Match.Status));
  AssertEquals(10000, Match.DeltaMs);

  Candidates[0] := Candidate(2, 2, EncodeTime(23, 59, 55, 0));
  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(0, 0, 5, 0)),
    Candidates, 15);
  AssertEquals(Ord(smmMatched), Ord(Match.Status));
  AssertEquals(10000, Match.DeltaMs);
end;

procedure TStartMarkMatcherTests.Match_IgnoresCandidatesFromOtherStages;
var
  Candidates: array[0..1] of TStartMarkCandidate;
  Match: TStartMarkMatch;
begin
  Candidates[0] := Candidate(1, 3, EncodeTime(10, 0, 0, 0));
  Candidates[1] := Candidate(2, 2, EncodeTime(10, 0, 4, 0));

  Match := TStartMarkMatcher.Match(MarkAt(EncodeTime(10, 0, 0, 0), 2),
    Candidates, 15);

  AssertEquals(Ord(smmMatched), Ord(Match.Status));
  AssertEquals(2, Match.ParticipantNumber);
  AssertEquals(4000, Match.DeltaMs);
end;

initialization
  RegisterTest(TStartMarkMatcherTests);

end.
