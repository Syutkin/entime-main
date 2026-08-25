unit StartMarkMatcher;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, StartMark;

const
  MAX_START_MARK_MATCH_TOLERANCE_SECONDS = 60;

type
  TStartMarkMatchStatus = (smmMatched, smmNoMatch, smmAmbiguous);

  { TStartMarkCandidate }

  TStartMarkCandidate = record
    ParticipantNumber: integer;
    StageIndex: integer;
    StartTime: TDateTime;
    class function Create(const AParticipantNumber, AStageIndex: integer;
      const AStartTime: TDateTime): TStartMarkCandidate; static;
  end;

  TStartMarkCandidateArray = array of TStartMarkCandidate;

  { TStartMarkMatch }

  TStartMarkMatch = record
    Status: TStartMarkMatchStatus;
    HasParticipantNumber: boolean;
    ParticipantNumber: integer;
    HasDeltaMs: boolean;
    DeltaMs: integer;
    Reason: string;
  end;

  { TStartMarkMatcher }

  TStartMarkMatcher = class
  public
    class function Match(const AMark: TStartMark;
      const ACandidates: array of TStartMarkCandidate;
      const AToleranceSeconds: integer): TStartMarkMatch; static;
  end;

function StartMarkMatchStatusCode(
  const AStatus: TStartMarkMatchStatus): string;

implementation

const
  MILLISECONDS_PER_DAY = int64(24) * 60 * 60 * 1000;

procedure RequirePositive(const AValue: integer; const AName: string);
begin
  if AValue < 1 then
    raise EArgumentOutOfRangeException.CreateFmt(
      '%s %d must be greater than zero.', [AName, AValue]);
end;

function TimeOfDayMilliseconds(const AValue: TDateTime): int64;
var
  TimePart: extended;
begin
  TimePart := Frac(AValue);
  if TimePart < 0 then
    TimePart := TimePart + 1;
  Result := Round(TimePart * MILLISECONDS_PER_DAY);
  if Result = MILLISECONDS_PER_DAY then
    Result := 0;
end;

function CircularDeltaMilliseconds(const AFirst,
  ASecond: TDateTime): integer;
var
  Delta: int64;
begin
  Delta := Abs(TimeOfDayMilliseconds(AFirst) -
    TimeOfDayMilliseconds(ASecond));
  if Delta > MILLISECONDS_PER_DAY div 2 then
    Delta := MILLISECONDS_PER_DAY - Delta;
  Result := Delta;
end;

function StartMarkMatchStatusCode(
  const AStatus: TStartMarkMatchStatus): string;
begin
  case AStatus of
    smmMatched: Result := 'matched';
    smmNoMatch: Result := 'no_match';
    smmAmbiguous: Result := 'ambiguous';
  end;
end;

class function TStartMarkCandidate.Create(const AParticipantNumber,
  AStageIndex: integer; const AStartTime: TDateTime): TStartMarkCandidate;
begin
  RequirePositive(AParticipantNumber, 'Participant number');
  RequirePositive(AStageIndex, 'Stage index');
  Result := Default(TStartMarkCandidate);
  Result.ParticipantNumber := AParticipantNumber;
  Result.StageIndex := AStageIndex;
  Result.StartTime := AStartTime;
end;

class function TStartMarkMatcher.Match(const AMark: TStartMark;
  const ACandidates: array of TStartMarkCandidate;
  const AToleranceSeconds: integer): TStartMarkMatch;
var
  Candidate: TStartMarkCandidate;
  DeltaMs, NearestDeltaMs, ToleranceMs: integer;
  HasNearest, IsAmbiguous: boolean;
  NearestParticipantNumber: integer;
begin
  if (AToleranceSeconds < 0) or
    (AToleranceSeconds > MAX_START_MARK_MATCH_TOLERANCE_SECONDS) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Match tolerance %d seconds must be in the range 0..%d.',
      [AToleranceSeconds, MAX_START_MARK_MATCH_TOLERANCE_SECONDS]);

  ToleranceMs := AToleranceSeconds * 1000;
  HasNearest := False;
  IsAmbiguous := False;
  NearestDeltaMs := 0;
  NearestParticipantNumber := 0;

  for Candidate in ACandidates do
  begin
    if Candidate.StageIndex <> AMark.StageIndex then
      Continue;
    DeltaMs := CircularDeltaMilliseconds(AMark.EventTime,
      Candidate.StartTime);
    if DeltaMs > ToleranceMs then
      Continue;

    if not HasNearest or (DeltaMs < NearestDeltaMs) then
    begin
      HasNearest := True;
      IsAmbiguous := False;
      NearestDeltaMs := DeltaMs;
      NearestParticipantNumber := Candidate.ParticipantNumber;
    end
    else if DeltaMs = NearestDeltaMs then
      IsAmbiguous := True;
  end;

  Result := Default(TStartMarkMatch);
  if not HasNearest then
  begin
    Result.Status := smmNoMatch;
    Result.Reason := StartMarkMatchStatusCode(Result.Status);
    Exit;
  end;

  Result.HasDeltaMs := True;
  Result.DeltaMs := NearestDeltaMs;
  if IsAmbiguous then
  begin
    Result.Status := smmAmbiguous;
    Result.Reason := StartMarkMatchStatusCode(Result.Status);
    Exit;
  end;

  Result.Status := smmMatched;
  Result.HasParticipantNumber := True;
  Result.ParticipantNumber := NearestParticipantNumber;
end;

end.
