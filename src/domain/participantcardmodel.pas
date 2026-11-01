unit ParticipantCardModel;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses SysUtils, TimingMark, StageFieldNames, ProtocolBalance;

type
  TCardValue = record
    IsNull: boolean;
    Text: string;
    class function Null: TCardValue; static;
    class function Value(const AText: string): TCardValue; static;
    function Empty: boolean;
  end;
  TCardParticipantField = (cpfName, cpfCategory, cpfNickname, cpfAge, cpfTeam,
    cpfCity, cpfPhone, cpfEmail, cpfComment, cpfRfid, cpfSumResult, cpfSumPlace,
    cpfSumDiff, cpfSumStages, cpfThruDiff, cpfThruPlace, cpfStatus);
  TCardParticipantValues = array[TCardParticipantField] of TCardValue;

  TCardStage = record
    Index: integer;
    Name: string;
    Active: boolean;
    Values: array[TStageFieldKind] of TCardValue;
    Classification: TProtocolBalanceClassification;
  end;

  TCardMarkKey = record
    Kind: TTimingMarkKind;
    Id: int64;
    function Equals(const Other: TCardMarkKey): boolean;
  end;

  TCardMark = record
    Key: TCardMarkKey;
    Number, ReceivedStage, AppliedStage: integer;
    HasAppliedStage: boolean;
    EventTime, ReceivedAt, AppliedAt, Status: string;
    SourceKind, DeviceId, AssignmentMode, Diagnostic: string;
    Correction: TCardValue;
    function EffectiveStage: integer;
    function MatchesStage(const AStage: integer; const AAllStages: boolean): boolean;
  end;
  TCardMarks = array of TCardMark;

  TParticipantCardSnapshot = class
  public
    ContextIdentity, SessionGeneration: QWord;
    StageSignature: string;
    ParticipantId, Number: integer;
    Fields: TCardParticipantValues;
    Stages: array of TCardStage;
    Marks: TCardMarks;
    function StagePosition(const AIndex: integer): integer;
    function PreferredStage(const AIndex: integer): integer;
    function FindMark(const AKey: TCardMarkKey): integer;
  end;

function ClassifyCardStage(const AStage: TCardStage;
  const AGlobalStatus: TCardValue): TProtocolBalanceClassification;
procedure SortCardMarks(var AMarks: TCardMarks);

const
  CardParticipantColumns: array[TCardParticipantField] of string =
    ('name', 'category', 'nickname', 'age', 'team', 'city', 'phone',
    'email', 'comment', 'rfid', 'sumresult', 'sumplace', 'sumdiffleader',
    'sumstages', 'thrudiff', 'thruplace', 'status');

implementation

class function TCardValue.Null: TCardValue;
begin
  Result := Default(TCardValue);
  Result.IsNull := True;
end;

class function TCardValue.Value(const AText: string): TCardValue;
begin
  Result.IsNull := False;
  Result.Text := AText;
end;

function TCardValue.Empty: boolean;
begin
  Result := IsNull or (Trim(Text) = '');
end;

function TCardMarkKey.Equals(const Other: TCardMarkKey): boolean;
begin
  Result := (Kind = Other.Kind) and (Id = Other.Id);
end;

function TCardMark.EffectiveStage: integer;
begin
  if (Key.Kind = tmkStart) and (Status = 'applied') and HasAppliedStage and
    (AppliedStage > 0) then Result := AppliedStage
  else
    Result := ReceivedStage;
end;

function TCardMark.MatchesStage(const AStage: integer;
  const AAllStages: boolean): boolean;
begin
  Result := AAllStages or (EffectiveStage = AStage);
end;

function TParticipantCardSnapshot.StagePosition(const AIndex: integer): integer;
var
  I: integer;
begin
  for I := 0 to High(Stages) do
    if Stages[I].Index = AIndex then Exit(I);
  Result := -1;
end;

function TParticipantCardSnapshot.PreferredStage(const AIndex: integer): integer;
var
  I: integer;
begin
  if StagePosition(AIndex) >= 0 then Exit(AIndex);
  for I := 0 to High(Stages) do
    if Stages[I].Active then Exit(Stages[I].Index);
  if Length(Stages) > 0 then Exit(Stages[0].Index);
  Result := 0;
end;

function TParticipantCardSnapshot.FindMark(const AKey: TCardMarkKey): integer;
var
  I: integer;
begin
  for I := 0 to High(Marks) do
    if Marks[I].Key.Equals(AKey) then Exit(I);
  Result := -1;
end;

function ClassifyCardStage(const AStage: TCardStage;
  const AGlobalStatus: TCardValue): TProtocolBalanceClassification;
var
  Input: TProtocolBalanceStageInput;
begin
  Input.StartTime := AStage.Values[sfkStartTime].Text;
  Input.FinishTime := AStage.Values[sfkFinishTime].Text;
  Input.ResultValue := AStage.Values[sfkResult].Text;
  Input.StageStatusValue := AStage.Values[sfkStatus].Text;
  Input.GlobalStatusValue := AGlobalStatus.Text;
  Result := ClassifyProtocolBalance(Input);
end;

function CompareMarks(const A, B: TCardMark): integer;
begin
  Result := CompareStr(B.ReceivedAt, A.ReceivedAt);
  if Result <> 0 then Exit;
  Result := Ord(A.Key.Kind) - Ord(B.Key.Kind);
  if Result <> 0 then Exit;
  if A.Key.Id > B.Key.Id then Result := -1
  else if A.Key.Id < B.Key.Id then Result := 1;
end;

procedure SortCardMarks(var AMarks: TCardMarks);

  procedure Sort(const L, R: integer);
  var
    I, J: integer;
    Pivot, Temp: TCardMark;
  begin
    I := L;
    J := R;
    Pivot := AMarks[L + (R - L) div 2];
    repeat
      while CompareMarks(AMarks[I], Pivot) < 0 do Inc(I);
      while CompareMarks(AMarks[J], Pivot) > 0 do Dec(J);
      if I <= J then
      begin
        Temp := AMarks[I];
        AMarks[I] := AMarks[J];
        AMarks[J] := Temp;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then Sort(L, J);
    if I < R then Sort(I, R);
  end;

begin
  if Length(AMarks) > 1 then Sort(0, High(AMarks));
end;

end.
