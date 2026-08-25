unit ParticipantStatus;

{$mode ObjFPC}{$H+}

interface

type
  TParticipantStatus = (
    psNone,
    psDNS,
    psDNF,
    psDSQ
  );

function ParticipantStatusToDbValue(
  const AStatus: TParticipantStatus): string;
function ParticipantStatusToToken(
  const AStatus: TParticipantStatus): string;
function TryParticipantStatusFromDbValue(const AValue: string;
  out AStatus: TParticipantStatus): boolean;
function TryParseParticipantStatus(const AValue: string;
  out AStatus: TParticipantStatus): boolean;
function DeriveGlobalParticipantStatus(
  const ACurrentGlobalStatus: TParticipantStatus;
  const AStageStatuses: array of TParticipantStatus;
  const AActiveStageIndexes: array of integer): TParticipantStatus;

implementation

uses
  SysUtils;

type
  TParticipantStatusInfo = record
    DbValue: string;
    Token: string;
  end;

const
  ParticipantStatusInfo: array[TParticipantStatus] of TParticipantStatusInfo = (
    (DbValue: ''; Token: ''),
    (DbValue: '1'; Token: 'DNS'),
    (DbValue: '2'; Token: 'DNF'),
    (DbValue: '3'; Token: 'DSQ')
  );

function ParticipantStatusToDbValue(
  const AStatus: TParticipantStatus): string;
begin
  Result := ParticipantStatusInfo[AStatus].DbValue;
end;

function ParticipantStatusToToken(
  const AStatus: TParticipantStatus): string;
begin
  Result := ParticipantStatusInfo[AStatus].Token;
end;

function TryParticipantStatusFromDbValue(const AValue: string;
  out AStatus: TParticipantStatus): boolean;
var
  candidate: TParticipantStatus;
  value: string;
begin
  value := Trim(AValue);
  for candidate := Low(TParticipantStatus) to High(TParticipantStatus) do
    if value = ParticipantStatusInfo[candidate].DbValue then
    begin
      AStatus := candidate;
      Exit(True);
    end;

  AStatus := psNone;
  Result := False;
end;

function TryParseParticipantStatus(const AValue: string;
  out AStatus: TParticipantStatus): boolean;
var
  candidate: TParticipantStatus;
  value: string;
begin
  value := Trim(AValue);
  for candidate := Low(TParticipantStatus) to High(TParticipantStatus) do
    if (value = ParticipantStatusInfo[candidate].DbValue) or
      SameText(value, ParticipantStatusInfo[candidate].Token) then
    begin
      AStatus := candidate;
      Exit(True);
    end;

  AStatus := psNone;
  Result := False;
end;

function DeriveGlobalParticipantStatus(
  const ACurrentGlobalStatus: TParticipantStatus;
  const AStageStatuses: array of TParticipantStatus;
  const AActiveStageIndexes: array of integer): TParticipantStatus;
var
  ActiveIndex, StageIndex: integer;
  StageStatus: TParticipantStatus;
begin
  if ACurrentGlobalStatus = psDSQ then
    Exit(psDSQ);

  Result := psNone;
  for ActiveIndex := 0 to High(AActiveStageIndexes) do
  begin
    StageIndex := AActiveStageIndexes[ActiveIndex];
    if (StageIndex < 1) or (StageIndex > Length(AStageStatuses)) then
      raise EArgumentOutOfRangeException.CreateFmt(
        'Active stage index %d is outside the status range 1..%d.',
        [StageIndex, Length(AStageStatuses)]);

    StageStatus := AStageStatuses[StageIndex - 1];
    if StageIndex = 1 then
    begin
      if StageStatus = psDNS then
        Result := psDNS
      else if StageStatus = psDNF then
        Result := psDNF;
    end
    else if (StageStatus <> psNone) and (Result = psNone) then
      Result := psDNF;
  end;
end;

end.
