unit ProtocolBalance;

{$mode ObjFPC}{$H+}

interface

type
  TProtocolBalanceGroup = (pbgUnresolved, pbgWithResult, pbgDNS, pbgDNF, pbgDSQ);
  TProtocolBalanceFilter = (pbfAll, pbfWithResult, pbfDNS, pbfDNF, pbfDSQ,
    pbfUnresolved, pbfFinishWithoutStart);
  TProtocolBalanceReason = (pbrNone, pbrNoStageData, pbrMissingFinish,
    pbrFinishWithoutStart, pbrMissingOrInvalidResult, pbrUnknownStageStatus);

  TProtocolBalanceStageInput = record
    StartTime: string;
    FinishTime: string;
    ResultValue: string;
    // Persisted status values: empty, '1', '2', '3'. The reader maps NULL to ''.
    StageStatusValue: string;
    GlobalStatusValue: string;
  end;

  TProtocolBalanceClassification = record
    Group: TProtocolBalanceGroup;
    Reason: TProtocolBalanceReason;
    FinishWithoutStart: boolean;
  end;

  TProtocolBalanceSummary = record
    ParticipantCount: integer;
    GroupCounts: array[TProtocolBalanceGroup] of integer;
    FinishWithoutStartCount: integer;
  end;

  TProtocolBalanceMarkCounts = record
    PendingStarts: integer;
    PendingFinishes: integer;
    StartErrors: integer;
    FinishErrors: integer;
  end;

  TProtocolBalanceParticipantRow = record
    ParticipantId: integer;
    Number: integer;
    Name: string;
    Category: string;
    Data: TProtocolBalanceStageInput;
    Classification: TProtocolBalanceClassification;
  end;

  TProtocolBalanceStageSnapshot = record
    StageIndex: integer;
    StageName: string;
    Summary: TProtocolBalanceSummary;
    Marks: TProtocolBalanceMarkCounts;
    Participants: array of TProtocolBalanceParticipantRow;
  end;

  TProtocolBalanceSnapshot = record
    Stages: array of TProtocolBalanceStageSnapshot;
  end;

function ClassifyProtocolBalance(
  const AData: TProtocolBalanceStageInput): TProtocolBalanceClassification;
function MatchesProtocolBalanceFilter(
  const AClassification: TProtocolBalanceClassification;
  const AFilter: TProtocolBalanceFilter): boolean;
function SummarizeProtocolBalance(
  const AClassifications: array of TProtocolBalanceClassification):
  TProtocolBalanceSummary;
procedure AddProtocolBalanceClassification(var ASummary: TProtocolBalanceSummary;
  const AClassification: TProtocolBalanceClassification);

implementation

uses
  SysUtils, ParticipantStatus;

function IsStoredStageResult(const AValue: string): boolean;
var
  I, Hours, Minutes, Seconds: integer;
begin
  Result := False;
  // Current storage format is HH:MM:SS with an optional 1..3 digit fraction.
  if (Length(AValue) <> 8) and ((Length(AValue) < 10) or (Length(AValue) > 12)) then
    Exit;
  for I := 1 to Length(AValue) do
    case I of
      3, 6: if AValue[I] <> ':' then Exit;
      9: if AValue[I] <> '.' then Exit;
      else
        if not (AValue[I] in ['0'..'9']) then Exit;
    end;
  Hours := (Ord(AValue[1]) - Ord('0')) * 10 + Ord(AValue[2]) - Ord('0');
  Minutes := (Ord(AValue[4]) - Ord('0')) * 10 + Ord(AValue[5]) - Ord('0');
  Seconds := (Ord(AValue[7]) - Ord('0')) * 10 + Ord(AValue[8]) - Ord('0');
  Result := (Hours < 24) and (Minutes < 60) and (Seconds < 60);
end;

function ClassifyProtocolBalance(
  const AData: TProtocolBalanceStageInput): TProtocolBalanceClassification;
const
  STATUS_GROUPS: array[psDNS..psDSQ] of TProtocolBalanceGroup =
    (pbgDNS, pbgDNF, pbgDSQ);
var
  HasStart, HasFinish: boolean;
  ResultText: string;
  GlobalStatus, StageStatus: TParticipantStatus;
begin
  Result := Default(TProtocolBalanceClassification);
  HasStart := Trim(AData.StartTime) <> '';
  HasFinish := Trim(AData.FinishTime) <> '';
  Result.FinishWithoutStart := HasFinish and not HasStart;

  if TryParticipantStatusFromDbValue(AData.GlobalStatusValue, GlobalStatus) and
    (GlobalStatus = psDSQ) then
  begin
    Result.Group := pbgDSQ;
    Exit;
  end;
  if not TryParticipantStatusFromDbValue(AData.StageStatusValue, StageStatus) then
  begin
    Result.Reason := pbrUnknownStageStatus;
    Exit;
  end;
  if StageStatus <> psNone then
  begin
    Result.Group := STATUS_GROUPS[StageStatus];
    Exit;
  end;

  ResultText := Trim(AData.ResultValue);
  if IsStoredStageResult(ResultText) then
  begin
    Result.Group := pbgWithResult;
    Exit;
  end;

  if Result.FinishWithoutStart then
    Result.Reason := pbrFinishWithoutStart
  else if HasFinish or (ResultText <> '') then
    Result.Reason := pbrMissingOrInvalidResult
  else if HasStart then
    Result.Reason := pbrMissingFinish
  else
    Result.Reason := pbrNoStageData;
end;

function MatchesProtocolBalanceFilter(
  const AClassification: TProtocolBalanceClassification;
  const AFilter: TProtocolBalanceFilter): boolean;
begin
  case AFilter of
    pbfAll: Result := True;
    pbfWithResult: Result := AClassification.Group = pbgWithResult;
    pbfDNS: Result := AClassification.Group = pbgDNS;
    pbfDNF: Result := AClassification.Group = pbgDNF;
    pbfDSQ: Result := AClassification.Group = pbgDSQ;
    pbfUnresolved: Result := AClassification.Group = pbgUnresolved;
    pbfFinishWithoutStart: Result := AClassification.FinishWithoutStart;
  end;
end;

function SummarizeProtocolBalance(
  const AClassifications: array of TProtocolBalanceClassification):
TProtocolBalanceSummary;
var
  Classification: TProtocolBalanceClassification;
begin
  Result := Default(TProtocolBalanceSummary);
  for Classification in AClassifications do
    AddProtocolBalanceClassification(Result, Classification);
end;

procedure AddProtocolBalanceClassification(var ASummary: TProtocolBalanceSummary;
  const AClassification: TProtocolBalanceClassification);
begin
  Inc(ASummary.ParticipantCount);
  Inc(ASummary.GroupCounts[AClassification.Group]);
  if AClassification.FinishWithoutStart then
    Inc(ASummary.FinishWithoutStartCount);
end;

end.
