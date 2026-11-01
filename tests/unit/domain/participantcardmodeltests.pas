unit ParticipantCardModelTests;
{$mode objfpc}{$H+}
interface

uses SysUtils, fpcunit, testregistry, ParticipantCardModel, TimingMark,
  StageFieldNames, ProtocolBalance;

type
  TParticipantCardModelTests = class(TTestCase)
  published
    procedure NullableValuesKeepZeroSignsAndOriginalText;
    procedure PreferredStageKeepsInactiveAndFallsBackToActive;
    procedure AppliedStartUsesAppliedStageAndLegacyUsesReceivedStage;
    procedure MarkKeysAndFiltersKeepDifferentKindsSeparate;
    procedure ReceiptOrderIgnoresEventTimeAndBreaksTies;
    procedure StageClassificationUsesExistingBalanceRules;
  end;

implementation

procedure TParticipantCardModelTests.NullableValuesKeepZeroSignsAndOriginalText;
begin
  AssertTrue(TCardValue.Null.Empty);
  AssertFalse(TCardValue.Value('0').Empty);
  AssertEquals('-125', TCardValue.Value('-125').Text);
  AssertEquals(' invalid ', TCardValue.Value(' invalid ').Text);
  AssertTrue(TCardValue.Value('   ').Empty);
end;

procedure TParticipantCardModelTests.PreferredStageKeepsInactiveAndFallsBackToActive;
var
  C: TParticipantCardSnapshot;
begin
  C := TParticipantCardSnapshot.Create;
  try
    SetLength(C.Stages, 3);
    C.Stages[0].Index := 1;
    C.Stages[1].Index := 9;
    C.Stages[2].Index := 32;
    C.Stages[1].Active := True;
    AssertEquals(32, C.PreferredStage(32));
    AssertEquals(9, C.PreferredStage(8));
    C.Stages[1].Active := False;
    AssertEquals(1, C.PreferredStage(0));
    SetLength(C.Stages, 0);
    AssertEquals(0, C.PreferredStage(1));
  finally
    C.Free;
  end;
end;

procedure TParticipantCardModelTests.
AppliedStartUsesAppliedStageAndLegacyUsesReceivedStage;
var
  M: TCardMark;
begin
  M := Default(TCardMark);
  M.Key.Kind := tmkStart;
  M.ReceivedStage := 2;
  M.HasAppliedStage := True;
  M.AppliedStage := 9;
  M.Status := 'pending';
  AssertEquals(2, M.EffectiveStage);
  M.Status := 'applied';
  AssertEquals(9, M.EffectiveStage);
  M.HasAppliedStage := False;
  AssertEquals(2, M.EffectiveStage);
  M.HasAppliedStage := True;
  M.Key.Kind := tmkFinish;
  AssertEquals(2, M.EffectiveStage);
end;

procedure TParticipantCardModelTests.MarkKeysAndFiltersKeepDifferentKindsSeparate;
var
  C: TParticipantCardSnapshot;
  K: TCardMarkKey;
begin
  C := TParticipantCardSnapshot.Create;
  try
    SetLength(C.Marks, 2);
    C.Marks[0].Key.Kind := tmkStart;
    C.Marks[0].Key.Id := 7;
    C.Marks[0].ReceivedStage := 2;
    C.Marks[1].Key.Kind := tmkFinish;
    C.Marks[1].Key.Id := 7;
    C.Marks[1].ReceivedStage := 99;
    C.Marks[1].Status := 'future-status';
    K := C.Marks[1].Key;
    AssertEquals(1, C.FindMark(K));
    AssertTrue(C.Marks[0].MatchesStage(2, False));
    AssertFalse(C.Marks[1].MatchesStage(2, False));
    AssertTrue(C.Marks[1].MatchesStage(2, True));
    K.Id := 99;
    AssertEquals(-1, C.FindMark(K));
  finally
    C.Free;
  end;
end;

procedure TParticipantCardModelTests.ReceiptOrderIgnoresEventTimeAndBreaksTies;
var
  A: TCardMarks;
begin
  SetLength(A, 4);
  A[0].Key.Id := 1;
  A[0].ReceivedAt := '2026-10-29T23:59:59.999';
  A[0].EventTime := '23:59:59.999';
  A[1].Key.Id := 2;
  A[1].ReceivedAt := '2026-10-30T00:00:00.000';
  A[1].EventTime := '00:00:00.000';
  A[2] := A[1];
  A[2].Key.Id := 3;
  A[3] := A[1];
  A[3].Key.Kind := tmkFinish;
  SortCardMarks(A);
  AssertEquals(3, A[0].Key.Id);
  AssertEquals(2, A[1].Key.Id);
  AssertEquals(Ord(tmkFinish), Ord(A[2].Key.Kind));
  AssertEquals(1, A[3].Key.Id);
end;

procedure TParticipantCardModelTests.StageClassificationUsesExistingBalanceRules;
var
  S: TCardStage;
  C: TProtocolBalanceClassification;
begin
  S := Default(TCardStage);
  S.Values[sfkFinishTime] := TCardValue.Value('12:00:00.000');
  C := ClassifyCardStage(S, TCardValue.Null);
  AssertEquals(Ord(pbrFinishWithoutStart), Ord(C.Reason));
  S.Values[sfkStatus] := TCardValue.Value('2');
  C := ClassifyCardStage(S, TCardValue.Null);
  AssertEquals(Ord(pbgDNF), Ord(C.Group));
  C := ClassifyCardStage(S, TCardValue.Value('3'));
  AssertEquals(Ord(pbgDSQ), Ord(C.Group));
end;

initialization
  RegisterTest(TParticipantCardModelTests);
end.
