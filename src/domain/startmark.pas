unit StartMark;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, TimingMark;

type
  TStartMarkAssignmentMode = (smamManual, smamAutomatic);
  TStartMarkStatus = (smsPending, smsApplied, smsHidden, smsConflict, smsError);

  { TStartMark }

  TStartMark = record
    Id: int64;
    StageIndex: integer;
    HasAppliedStageIndex: boolean;
    AppliedStageIndex: integer;
    EventTime: TDateTime;
    HasCorrection: boolean;
    CorrectionMs: integer;
    HasParticipantNumber: boolean;
    ParticipantNumber: integer;
    HasMatchDeltaMs: boolean;
    MatchDeltaMs: integer;
    Source: TTimingMarkSource;
    ReceivedAt: TDateTime;
    HasAssignmentMode: boolean;
    AssignmentMode: TStartMarkAssignmentMode;
    Status: TStartMarkStatus;
    HasAppliedAt: boolean;
    AppliedAt: TDateTime;
    Diagnostic: string;
    class function FromTimingMark(const AMark: TTimingMark;
      const AStageIndex: integer): TStartMark; static;
    procedure SuggestParticipant(const AParticipantNumber: integer);
    procedure SetParticipantNumber(const AHasParticipantNumber: boolean;
      const AParticipantNumber: integer);
    function TryApply(const AParticipantNumber, AAppliedStageIndex: integer;
      const AAssignmentMode: TStartMarkAssignmentMode;
      const AAppliedAt: TDateTime): boolean;
    procedure MarkConflict(const ADiagnostic: string);
    procedure MarkError(const ADiagnostic: string);
    procedure Hide;
  end;

function StartMarkStatusCode(const AStatus: TStartMarkStatus): string;

implementation

function StartMarkStatusCode(const AStatus: TStartMarkStatus): string;
begin
  case AStatus of
    smsPending: Result := 'pending';
    smsApplied: Result := 'applied';
    smsHidden: Result := 'hidden';
    smsConflict: Result := 'conflict';
    smsError: Result := 'error';
  end;
end;

procedure RequirePositive(const AValue: integer; const AName: string);
begin
  if AValue < 1 then
    raise EArgumentOutOfRangeException.CreateFmt(
      '%s %d must be greater than zero.', [AName, AValue]);
end;

class function TStartMark.FromTimingMark(const AMark: TTimingMark;
  const AStageIndex: integer): TStartMark;
begin
  if AMark.Kind <> tmkStart then
    raise EArgumentException.Create(
      'Only a start timing mark can create TStartMark.');
  if AStageIndex < 1 then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index %d must be greater than zero.', [AStageIndex]);

  Result := Default(TStartMark);
  Result.StageIndex := AStageIndex;
  Result.EventTime := AMark.EventTime;
  Result.HasCorrection := AMark.HasCorrection;
  Result.CorrectionMs := AMark.CorrectionMs;
  Result.Source := AMark.Source;
  Result.ReceivedAt := AMark.ReceivedAt;
  Result.Status := smsPending;
end;

procedure TStartMark.SuggestParticipant(const AParticipantNumber: integer);
begin
  if Status <> smsPending then
    raise EInvalidOp.CreateFmt(
      'A start mark in status %s cannot receive a participant proposal.',
      [StartMarkStatusCode(Status)]);
  RequirePositive(AParticipantNumber, 'Participant number');
  HasParticipantNumber := True;
  ParticipantNumber := AParticipantNumber;
end;

procedure TStartMark.SetParticipantNumber(
  const AHasParticipantNumber: boolean; const AParticipantNumber: integer);
begin
  if not (Status in [smsPending, smsConflict]) then
    raise EInvalidOp.CreateFmt(
      'A start mark in status %s cannot change its participant number.',
      [StartMarkStatusCode(Status)]);
  if AHasParticipantNumber then
    RequirePositive(AParticipantNumber, 'Participant number');
  if HasMatchDeltaMs and
    ((not HasParticipantNumber) or (not AHasParticipantNumber) or
    (ParticipantNumber <> AParticipantNumber)) then
  begin
    HasMatchDeltaMs := False;
    MatchDeltaMs := 0;
  end;
  HasParticipantNumber := AHasParticipantNumber;
  if AHasParticipantNumber then
    ParticipantNumber := AParticipantNumber
  else
    ParticipantNumber := 0;
end;

function TStartMark.TryApply(const AParticipantNumber,
  AAppliedStageIndex: integer;
  const AAssignmentMode: TStartMarkAssignmentMode;
  const AAppliedAt: TDateTime): boolean;
begin
  if Status = smsApplied then
    Exit(False);
  if not (Status in [smsPending, smsConflict]) then
    raise EInvalidOp.CreateFmt(
      'A start mark in status %s cannot be applied.',
      [StartMarkStatusCode(Status)]);
  RequirePositive(AParticipantNumber, 'Participant number');
  RequirePositive(AAppliedStageIndex, 'Applied stage index');
  if (AAssignmentMode = smamAutomatic) and
    (AAppliedStageIndex <> StageIndex) then
    raise EArgumentException.CreateFmt(
      'Automatic assignment must use received stage %d, not stage %d.',
      [StageIndex, AAppliedStageIndex]);
  if AAppliedAt <= 0 then
    raise EArgumentOutOfRangeException.Create(
      'AppliedAt must be a valid date and time.');

  HasParticipantNumber := True;
  ParticipantNumber := AParticipantNumber;
  HasAppliedStageIndex := True;
  AppliedStageIndex := AAppliedStageIndex;
  HasAssignmentMode := True;
  AssignmentMode := AAssignmentMode;
  HasAppliedAt := True;
  AppliedAt := AAppliedAt;
  Diagnostic := '';
  Status := smsApplied;
  Result := True;
end;

procedure TStartMark.MarkConflict(const ADiagnostic: string);
begin
  if not (Status in [smsPending, smsConflict]) then
    raise EInvalidOp.CreateFmt(
      'A start mark in status %s cannot become a conflict.',
      [StartMarkStatusCode(Status)]);
  Status := smsConflict;
  Diagnostic := ADiagnostic;
end;

procedure TStartMark.MarkError(const ADiagnostic: string);
begin
  if not (Status in [smsPending, smsConflict]) then
    raise EInvalidOp.CreateFmt(
      'A start mark in status %s cannot become an error.',
      [StartMarkStatusCode(Status)]);
  Status := smsError;
  Diagnostic := ADiagnostic;
end;

procedure TStartMark.Hide;
begin
  if Status = smsHidden then
    Exit;
  if not (Status in [smsPending, smsConflict]) then
    raise EInvalidOp.CreateFmt(
      'A start mark in status %s cannot be hidden.',
      [StartMarkStatusCode(Status)]);
  Status := smsHidden;
end;

end.
