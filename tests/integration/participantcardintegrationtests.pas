unit ParticipantCardIntegrationTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, Forms, Controls, Grids, Types, LCLType, fpcunit,
  testregistry, ParticipantCardModel, ParticipantCardForm, TimingMark,
  StageFieldNames, GuiTestSupport;

type
  TParticipantCardIntegrationTests = class(TTestCase)
  private
    FForm: TParticipantCardForm;
    FGui: TGuiTestSession;
    FRefreshes, FVisits, FParticipant, FStage: integer;
    FKey: TCardMarkKey;
    function Snapshot: TParticipantCardSnapshot;
    procedure Open;
    procedure ClickCell(const Grid: TStringGrid; const Row: integer);
    procedure Click(const Button: TWinControl);
    procedure Refreshed(Sender: TObject);
    procedure Journal(Sender: TObject; const Key: TCardMarkKey);
    procedure Participant(Sender: TObject; const ParticipantId, StageIndex: integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure OpensNonmodalAndShowsSavedFieldsAndPersonalDetails;
    procedure StageAndMarkFilterKeepInactiveStagesAvailable;
    procedure KeyboardAndButtonsNavigateUsingTypedKeys;
    procedure RefreshPreservesSelectionAndErrorDisablesNavigation;
    procedure EscapeClosesAndWindowCanReopen;
    procedure RemovedSelectionDoesNotSwitchToAnotherKindWithSameId;
  end;

implementation

function TParticipantCardIntegrationTests.Snapshot: TParticipantCardSnapshot;
var
  I: integer;
begin
  Result := TParticipantCardSnapshot.Create;
  Result.ParticipantId := 5;
  Result.Number := 123;
  Result.Fields[cpfName] := TCardValue.Value('Saved rider');
  Result.Fields[cpfComment] := TCardValue.Value('Saved comment');
  Result.Fields[cpfSumResult] := TCardValue.Value('00:07:00.125');
  SetLength(Result.Stages, 3);
  for I := 0 to 2 do Result.Stages[I].Index := I + 1;
  Result.Stages[1].Index := 9;
  Result.Stages[1].Active := True;
  Result.Stages[2].Index := 32;
  Result.Stages[1].Values[sfkCorrection] := TCardValue.Value('-125');
  SetLength(Result.Marks, 3);
  Result.Marks[0].Key.Kind := tmkStart;
  Result.Marks[0].Key.Id := 7;
  Result.Marks[0].ReceivedStage := 1;
  Result.Marks[0].HasAppliedStage := True;
  Result.Marks[0].AppliedStage := 9;
  Result.Marks[0].Status := 'applied';
  Result.Marks[0].Diagnostic := 'Full start diagnostic';
  Result.Marks[1].Key.Kind := tmkFinish;
  Result.Marks[1].Key.Id := 7;
  Result.Marks[1].ReceivedStage := 9;
  Result.Marks[2].Key.Kind := tmkFinish;
  Result.Marks[2].Key.Id := 8;
  Result.Marks[2].ReceivedStage := 32;
end;

procedure TParticipantCardIntegrationTests.SetUp;
begin
  FGui := TGuiTestSession.Create;
  FForm := TParticipantCardForm.Create(nil);
  FForm.OnRefresh := @Refreshed;
  FForm.OnOpenJournal := @Journal;
  FForm.OnOpenParticipant := @Participant;
  FForm.SetSnapshot(Snapshot, 9);
end;

procedure TParticipantCardIntegrationTests.TearDown;
begin
  FForm.Free;
  FGui.Free;
end;

procedure TParticipantCardIntegrationTests.Open;
begin
  FForm.Show;
  FGui.Drain('Open participant card');
end;

procedure TParticipantCardIntegrationTests.ClickCell(const Grid: TStringGrid;
  const Row: integer);
var
  R: TRect;
begin
  R := Grid.CellRect(0, Row);
  FGui.ClickAndWaitForFocus(Grid, (R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2);
end;

procedure TParticipantCardIntegrationTests.Click(const Button: TWinControl);
begin
  FGui.Click(Button, Button.ClientWidth div 2, Button.ClientHeight div 2);
end;

procedure TParticipantCardIntegrationTests.Refreshed(Sender: TObject);
begin
  Inc(FRefreshes);
end;

procedure TParticipantCardIntegrationTests.Journal(Sender: TObject;
  const Key: TCardMarkKey);
begin
  Inc(FVisits);
  FKey := Key;
end;

procedure TParticipantCardIntegrationTests.Participant(Sender: TObject;
  const ParticipantId, StageIndex: integer);
begin
  FParticipant := ParticipantId;
  FStage := StageIndex;
end;

procedure TParticipantCardIntegrationTests.
OpensNonmodalAndShowsSavedFieldsAndPersonalDetails;
begin
  Open;
  AssertFalse(fsModal in FForm.FormState);
  AssertTrue(Pos('Saved rider', FForm.TitleLabel.Caption) > 0);
  AssertEquals(9, FForm.SelectedStage);
  AssertEquals('-125', FForm.StagesGrid.Cells[3, 2]);
  FGui.SelectTab(FForm.PersonalPage);
  AssertTrue(Pos('Saved comment', FForm.PersonalMemo.Text) > 0);
  AssertTrue(FForm.PersonalMemo.ReadOnly);
end;

procedure TParticipantCardIntegrationTests.StageAndMarkFilterKeepInactiveStagesAvailable;
begin
  Open;
  AssertEquals(2, FForm.VisibleMarkCount);
  ClickCell(FForm.StagesGrid, 3);
  AssertEquals(32, FForm.SelectedStage);
  AssertEquals(1, FForm.VisibleMarkCount);
  FGui.PressKey(FForm.StagesGrid, VK_UP);
  AssertEquals(9, FForm.SelectedStage);
  FGui.PressKey(FForm.StagesGrid, VK_DOWN);
  AssertEquals(32, FForm.SelectedStage);
  FForm.ScopeComboBox.ItemIndex := 1;
  FForm.ScopeChange(FForm.ScopeComboBox);
  AssertEquals(3, FForm.VisibleMarkCount);
end;

procedure TParticipantCardIntegrationTests.KeyboardAndButtonsNavigateUsingTypedKeys;
begin
  Open;
  ClickCell(FForm.MarksGrid, 2);
  FGui.PressKey(FForm.MarksGrid, VK_RETURN);
  AssertEquals(1, FVisits);
  AssertEquals(Ord(tmkFinish), Ord(FKey.Kind));
  AssertEquals(7, FKey.Id);
  Click(FForm.ParticipantButton);
  AssertEquals(5, FParticipant);
  AssertEquals(9, FStage);
  Click(FForm.RefreshButton);
  AssertEquals(1, FRefreshes);
  ClickCell(FForm.MarksGrid, 2);
  FGui.PressKey(FForm.MarksGrid, VK_F5);
  AssertEquals(2, FRefreshes);
end;

procedure TParticipantCardIntegrationTests.
RefreshPreservesSelectionAndErrorDisablesNavigation;
var
  S: TParticipantCardSnapshot;
begin
  Open;
  ClickCell(FForm.MarksGrid, 2);
  S := Snapshot;
  S.Marks[0].Diagnostic := 'Changed';
  FForm.SetSnapshot(S, 0, True);
  AssertEquals(Ord(tmkFinish), Ord(FForm.SelectedMark.Kind));
  AssertEquals(7, FForm.SelectedMark.Id);
  FForm.SetUnavailable('Read error', False);
  AssertFalse(FForm.JournalButton.Enabled);
  AssertFalse(FForm.ParticipantButton.Enabled);
  Click(FForm.RefreshButton);
  AssertEquals(1, FRefreshes);
  FForm.SetSnapshot(Snapshot, 9);
  AssertTrue(FForm.ParticipantButton.Enabled);
  FForm.SetUnavailable('Deleted', True);
  AssertTrue(FForm.Snapshot = nil);
  AssertEquals(0, FForm.VisibleMarkCount);
end;

procedure TParticipantCardIntegrationTests.
RemovedSelectionDoesNotSwitchToAnotherKindWithSameId;
var
  S: TParticipantCardSnapshot;
begin
  Open;
  ClickCell(FForm.MarksGrid, 2);
  S := Snapshot;
  SetLength(S.Marks, 1);
  FForm.SetSnapshot(S, 0, True);
  AssertEquals(0, FForm.SelectedMark.Id);
  AssertFalse(FForm.JournalButton.Enabled);
  AssertEquals('', FForm.DetailMemo.Text);
  ClickCell(FForm.MarksGrid, 1);
  AssertTrue(FForm.JournalButton.Enabled);
  FGui.PressKey(FForm.MarksGrid, VK_RETURN);
  AssertEquals(1, FVisits);
  AssertEquals(Ord(tmkStart), Ord(FKey.Kind));
end;

procedure TParticipantCardIntegrationTests.EscapeClosesAndWindowCanReopen;
begin
  Open;
  ClickCell(FForm.StagesGrid, 2);
  FGui.PressKey(FForm.StagesGrid, VK_ESCAPE);
  AssertFalse(FForm.Visible);
  Open;
  AssertTrue(FForm.Visible);
  AssertEquals(9, FForm.SelectedStage);
end;

initialization
  RegisterTest(TParticipantCardIntegrationTests);
end.
