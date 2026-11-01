unit MySpinEditIntegrationTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, Forms, MySpinEdit, GuiTestSupport, fpcunit, testregistry;

type
  TMySpinEditIntegrationTests = class(TTestCase)
  private
    F: TForm;
    I: TMySpinEdit;
    D: TMyFloatSpinEdit;
    Gui: TGuiTestSession;
    Steps: integer;
    LastSender: TObject;
    procedure Step(Sender: TObject);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure IntegerStepIsSeparateFromEditingAndAssignment;
    procedure FloatStepsPreservePrecisionAndRespectLimits;
  end;

implementation

uses Controls, LCLType;

procedure TMySpinEditIntegrationTests.Step(Sender: TObject);
begin
  Inc(Steps);
  LastSender := Sender;
end;

procedure TMySpinEditIntegrationTests.SetUp;
begin
  Steps := 0;
  LastSender := nil;
  Gui := TGuiTestSession.Create;
  F := TForm.CreateNew(nil);
  F.Width := 320;
  F.Height := 140;
  I := TMySpinEdit.Create(F);
  I.Parent := F;
  I.Align := alTop;
  I.MaxValue := 20;
  I.Value := 10;
  I.OnStep := @Step;
  D := TMyFloatSpinEdit.Create(F);
  D.Parent := F;
  D.Align := alTop;
  D.MaxValue := 2;
  D.DecimalPlaces := 2;
  D.Increment := 0.1;
  D.Value := 1.25;
  D.OnStep := @Step;
  F.Show;
  Gui.Drain('Open MyForks spin edits');
end;

procedure TMySpinEditIntegrationTests.TearDown;
begin
  F.Free;
  Gui.Free;
end;

procedure TMySpinEditIntegrationTests.IntegerStepIsSeparateFromEditingAndAssignment;
begin
  I.Value := 11;
  AssertEquals(0, Steps);
  I.SetFocus;
  Gui.Drain('Focus integer spin edit');
  I.SelectAll;
  Gui.TypeText(I, '12');
  AssertEquals(0, Steps);
  Gui.PressKey(I, VK_RETURN);
  AssertEquals(0, Steps);
  Gui.PressKey(I, VK_UP);
  AssertEquals(13, I.Value);
  AssertEquals(1, Steps);
  AssertSame(I, LastSender);
  Gui.ClickSpinArrow(I, False);
  AssertEquals(12, I.Value);
  AssertEquals(2, Steps);
  I.MaxValue := 12;
  Gui.PressKey(I, VK_UP);
  AssertEquals(2, Steps);
  I.ReadOnly := True;
  Gui.PressKey(I, VK_DOWN);
  AssertEquals(12, I.Value);
  AssertEquals(2, Steps);
  I.ReadOnly := False;
  I.MaxValue := 36;
  I.MinValue := 6;
  I.SelectAll;
  Gui.TypeText(I, '2');
  Gui.PressKey(I, VK_RETURN);
  AssertEquals('Finishing a value below the range uses the minimum', 6, I.Value);
  AssertEquals('Finishing text does not become an arrow step', 2, Steps);
end;

procedure TMySpinEditIntegrationTests.FloatStepsPreservePrecisionAndRespectLimits;
begin
  D.SetFocus;
  Gui.Drain('Focus decimal spin edit');
  Gui.PressKey(D, VK_UP);
  AssertEquals(1.35, D.Value, 0.001);
  AssertEquals(1, Steps);
  Gui.ClickSpinArrow(D, False);
  AssertEquals(1.25, D.Value, 0.001);
  AssertEquals(2, Steps);
  AssertSame(D, LastSender);
  D.Value := 2;
  Gui.ClickSpinArrow(D);
  AssertEquals(2, Steps);
  D.Value := 0;
  Gui.ClickSpinArrow(D, False);
  AssertEquals(2, Steps);
  D.SetFocus;
  Gui.Drain('Edit float without stepping');
  D.SelectAll;
  Gui.TypeText(D, FloatToStr(0.75));
  Gui.PressKey(D, VK_RETURN);
  AssertEquals(0.75, D.Value, 0.001);
  AssertEquals(2, Steps);
end;

initialization
  RegisterTest(TMySpinEditIntegrationTests);
end.
