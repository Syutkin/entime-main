unit FinishMark;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, TimingMark;

type
  TFinishMarkAssignmentMode = (fmamManual);
  TFinishMarkStatus = (fmsPending, fmsApplied, fmsIgnoredDebounce, fmsHidden,
    fmsError);

  { TFinishMark }

  TFinishMark = record
    Id: int64;
    StageIndex: integer;
    EventTime: TDateTime;
    HasParticipantNumber: boolean;
    ParticipantNumber: integer;
    Source: TTimingMarkSource;
    ReceivedAt: TDateTime;
    HasAssignmentMode: boolean;
    AssignmentMode: TFinishMarkAssignmentMode;
    Status: TFinishMarkStatus;
    HasAppliedAt: boolean;
    AppliedAt: TDateTime;
    Diagnostic: string;
    class function FromTimingMark(const AMark: TTimingMark;
      const AStageIndex: integer): TFinishMark; static;
    procedure SetParticipantNumber(const AHasParticipantNumber: boolean;
      const AParticipantNumber: integer);
    function TryApply(const AParticipantNumber: integer;
      const AAppliedAt: TDateTime): boolean;
    procedure MarkIgnoredDebounce(const ADiagnostic: string);
    procedure MarkError(const ADiagnostic: string);
    procedure Hide;
  end;

function FinishMarkStatusCode(const AStatus: TFinishMarkStatus): string;

implementation

function FinishMarkStatusCode(const AStatus: TFinishMarkStatus): string;
begin
  case AStatus of
    fmsPending: Result := 'pending';
    fmsApplied: Result := 'applied';
    fmsIgnoredDebounce: Result := 'ignored_debounce';
    fmsHidden: Result := 'hidden';
    fmsError: Result := 'error';
  end;
end;

class function TFinishMark.FromTimingMark(const AMark: TTimingMark;
  const AStageIndex: integer): TFinishMark;
begin
  if AMark.Kind <> tmkFinish then
    raise EArgumentException.Create(
      'Only a finish timing mark can create TFinishMark.');
  if AStageIndex < 1 then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index %d must be greater than zero.', [AStageIndex]);

  Result := Default(TFinishMark);
  Result.StageIndex := AStageIndex;
  Result.EventTime := AMark.EventTime;
  Result.Source := AMark.Source;
  Result.ReceivedAt := AMark.ReceivedAt;
  Result.Status := fmsPending;
end;

procedure TFinishMark.SetParticipantNumber(
  const AHasParticipantNumber: boolean; const AParticipantNumber: integer);
begin
  if Status <> fmsPending then
    raise EInvalidOp.CreateFmt(
      'A finish mark in status %s cannot change its participant number.',
      [FinishMarkStatusCode(Status)]);
  if AHasParticipantNumber and (AParticipantNumber < 1) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Participant number %d must be greater than zero.',
      [AParticipantNumber]);
  HasParticipantNumber := AHasParticipantNumber;
  if AHasParticipantNumber then
    ParticipantNumber := AParticipantNumber
  else
    ParticipantNumber := 0;
end;

function TFinishMark.TryApply(const AParticipantNumber: integer;
  const AAppliedAt: TDateTime): boolean;
begin
  if Status = fmsApplied then
    Exit(False);
  if Status <> fmsPending then
    raise EInvalidOp.CreateFmt(
      'A finish mark in status %s cannot be applied.',
      [FinishMarkStatusCode(Status)]);
  if AParticipantNumber < 1 then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Participant number %d must be greater than zero.',
      [AParticipantNumber]);
  if AAppliedAt <= 0 then
    raise EArgumentOutOfRangeException.Create(
      'AppliedAt must be a valid date and time.');

  HasParticipantNumber := True;
  ParticipantNumber := AParticipantNumber;
  HasAssignmentMode := True;
  AssignmentMode := fmamManual;
  HasAppliedAt := True;
  AppliedAt := AAppliedAt;
  Diagnostic := '';
  Status := fmsApplied;
  Result := True;
end;

procedure TFinishMark.MarkIgnoredDebounce(const ADiagnostic: string);
begin
  if Status <> fmsPending then
    raise EInvalidOp.CreateFmt(
      'A finish mark in status %s cannot be ignored by debounce.',
      [FinishMarkStatusCode(Status)]);
  Status := fmsIgnoredDebounce;
  Diagnostic := ADiagnostic;
end;

procedure TFinishMark.MarkError(const ADiagnostic: string);
begin
  if Status <> fmsPending then
    raise EInvalidOp.CreateFmt(
      'A finish mark in status %s cannot become an error.',
      [FinishMarkStatusCode(Status)]);
  Status := fmsError;
  Diagnostic := ADiagnostic;
end;

procedure TFinishMark.Hide;
begin
  if Status = fmsHidden then
    Exit;
  Status := fmsHidden;
end;

end.
