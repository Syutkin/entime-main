unit ResultsImportComparisonTests;
{$mode objfpc}{$H+}
interface

uses SysUtils, fpcunit, testregistry, ResultsImportComparison;

type
  TResultsImportComparisonTests = class(TTestCase)
  published
    procedure Values_UseSemanticEqualityAndKeepNullDistinctFromZero;
    procedure Changes_ClassifyAndSelectOnlyKnownFills;
    procedure NewNumbers_RequireExplicitCreationAndCanCreateOnlyNumber;
    procedure Selection_IgnoresSameFieldsAndUnconfirmedNumbers;
    procedure Refresh_RestoresOnlyUnchangedOperationsAndIdentity;
    procedure Refresh_DoesNotCarryChoicesBetweenStagesOrSessions;
  end;

implementation

procedure TResultsImportComparisonTests.
Values_UseSemanticEqualityAndKeepNullDistinctFromZero;
begin
  AssertTrue(TImportValue.Value('12:00:00').Equivalent(
    TImportValue.Value('12:00:00.000'), ifFinish));
  AssertTrue(TImportValue.Value('12:00').Equivalent(
    TImportValue.Value('12:00:00'), ifStart));
  AssertTrue(TImportValue.Null.Equivalent(TImportValue.Value(' '), ifFinish));
  AssertFalse(TImportValue.Null.Equivalent(TImportValue.Value('0'), ifCorrection));
  AssertFalse(TImportValue.Null.Equivalent(TImportValue.Value('00:00:00'), ifPenalty));
  AssertTrue(TImportValue.Value('-015').Equivalent(TImportValue.Value('-15'),
    ifCorrection));
  AssertFalse(TImportValue.Value('-15').Equivalent(TImportValue.Value('15'),
    ifCorrection));
  AssertTrue(TImportValue.Value('1').Equivalent(TImportValue.Value('DNS'), ifStatus));
  AssertTrue(TImportValue.Value('invalid').Equivalent(
    TImportValue.Value('invalid'), ifStart));
  AssertFalse(TImportValue.Value('invalid').Equivalent(TImportValue.Null, ifStart));
end;

procedure TResultsImportComparisonTests.Changes_ClassifyAndSelectOnlyKnownFills;
var
  C: TResultsImportComparison;
  P: TImportParticipant;
begin
  C := TResultsImportComparison.Create;
  try
    P := C.Add(7, 123, 2, 'Rider');
    P.AddField(ifStart, TImportValue.Null, TImportValue.Value('10:00:00'));
    P.AddField(ifCorrection, TImportValue.Value('15'), TImportValue.Value('-15'));
    P.AddField(ifFinish, TImportValue.Value('11:00:00'), TImportValue.Null);
    P.AddField(ifStatus, TImportValue.Value('1'), TImportValue.Value('DNS'));
    AssertEquals(Ord(ickFill), Ord(P.Kind(ifStart)));
    AssertEquals(Ord(ickReplace), Ord(P.Kind(ifCorrection)));
    AssertEquals(Ord(ickClear), Ord(P.Kind(ifFinish)));
    AssertEquals(Ord(ickSame), Ord(P.Kind(ifStatus)));
    AssertTrue(P.Selected = [ifStart]);
    AssertEquals(1, C.ChangeCount(ickReplace));
    C.SelectAll;
    AssertTrue(P.Selected = [ifStart, ifCorrection, ifFinish]);
    AssertEquals(3, C.SelectedFieldCount);
    C.ClearSelection;
    AssertFalse(C.HasSelection);
  finally
    C.Free;
  end;
end;

procedure TResultsImportComparisonTests.
NewNumbers_RequireExplicitCreationAndCanCreateOnlyNumber;
var
  C: TResultsImportComparison;
  P: TImportParticipant;
begin
  C := TResultsImportComparison.Create;
  try
    P := C.Add(0, 9, 1, '');
    P.AddField(ifFinish, TImportValue.Null, TImportValue.Value('10:00:00'));
    C.SelectAll;
    AssertFalse(C.HasSelection);
    P.ConfirmCreation(True);
    AssertEquals(1, C.CreationCount);
    AssertEquals(1, C.SelectedFieldCount);
    P.Select(ifFinish, False);
    AssertTrue(C.HasSelection);
    AssertEquals(1, C.SelectedParticipantCount);
    C.ClearSelection;
    AssertFalse(C.HasSelection);
  finally
    C.Free;
  end;
end;

procedure TResultsImportComparisonTests.Selection_IgnoresSameFieldsAndUnconfirmedNumbers;
var
  C: TResultsImportComparison;
  P: TImportParticipant;
begin
  C := TResultsImportComparison.Create;
  try
    P := C.Add(0, 9, 1, '');
    P.AddField(ifFinish, TImportValue.Null, TImportValue.Value('10:00:00'));
    P.Select(ifFinish, True);
    AssertTrue(P.Selected = []);
    P.ConfirmCreation(True);
    P.AddField(ifStatus, TImportValue.Null, TImportValue.Null);
    P.Select(ifStatus, True);
    AssertFalse(ifStatus in P.Selected);
    P.ConfirmCreation(False);
    AssertTrue(P.Selected = []);
  finally
    C.Free;
  end;
end;

procedure TResultsImportComparisonTests.
Refresh_RestoresOnlyUnchangedOperationsAndIdentity;
var
  Old, Fresh: TResultsImportComparison;
  P: TImportParticipant;
begin
  Old := TResultsImportComparison.Create;
  Fresh := TResultsImportComparison.Create;
  try
    P := Old.Add(1, 9, 2, 'Rider');
    P.AddField(ifStart, TImportValue.Null, TImportValue.Value('10:00:00'));
    P.AddField(ifFinish, TImportValue.Value('11:00:00'), TImportValue.Value('11:01:00'));
    Old.SelectAll;
    P := Fresh.Add(1, 9, 2, 'Renamed');
    P.AddField(ifStart, TImportValue.Null, TImportValue.Value('10:00:00.000'));
    P.AddField(ifFinish, TImportValue.Null, TImportValue.Value('11:01:00'));
    Fresh.RestoreSelection(Old);
    AssertTrue(P.Selected = [ifStart]);
    P.Id := 2;
    Fresh.RestoreSelection(Old);
    AssertFalse(Fresh.HasSelection);
  finally
    Fresh.Free;
    Old.Free;
  end;
end;

procedure TResultsImportComparisonTests.
Refresh_DoesNotCarryChoicesBetweenStagesOrSessions;
var
  Old, Fresh: TResultsImportComparison;
  P: TImportParticipant;
begin
  Old := TResultsImportComparison.Create;
  Fresh := TResultsImportComparison.Create;
  try
    P := Old.Add(1, 9, 2, 'Rider');
    P.AddField(ifStart, TImportValue.Null, TImportValue.Value('10:00:00'));
    P := Fresh.Add(1, 9, 2, 'Rider');
    P.AddField(ifStart, TImportValue.Null, TImportValue.Value('10:00:00'));
    Fresh.StageIndex := 2;
    Fresh.RestoreSelection(Old);
    AssertFalse(Fresh.HasSelection);
    Fresh.StageIndex := Old.StageIndex;
    Fresh.SessionGeneration := 2;
    Fresh.RestoreSelection(Old);
    AssertFalse(Fresh.HasSelection);
  finally
    Fresh.Free;
    Old.Free;
  end;
end;

initialization
  RegisterTest(TResultsImportComparisonTests);
end.
