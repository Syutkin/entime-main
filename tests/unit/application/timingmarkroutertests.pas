unit TimingMarkRouterTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, FPCUnit, TestRegistry, TimingMark, StartMark, FinishMark,
  TimingMarkRouter;

type
  TTimingMarkRouterTests = class(TTestCase)
  private
    FStartCount: integer;
    FFinishCount: integer;
    FStartMark: TStartMark;
    FFinishMark: TFinishMark;
    FRouter: TTimingMarkRouter;
    procedure StartReceived(Sender: TObject; const AMark: TStartMark);
    procedure FinishReceived(Sender: TObject; const AMark: TFinishMark);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Route_StartCallsOnlyStartHandler;
    procedure Route_FinishCallsOnlyFinishHandler;
  end;

implementation

procedure TTimingMarkRouterTests.SetUp;
begin
  inherited SetUp;
  FRouter := TTimingMarkRouter.Create;
  FRouter.OnStartMark := @StartReceived;
  FRouter.OnFinishMark := @FinishReceived;
end;

procedure TTimingMarkRouterTests.TearDown;
begin
  FRouter.Free;
  inherited TearDown;
end;

procedure TTimingMarkRouterTests.StartReceived(Sender: TObject;
  const AMark: TStartMark);
begin
  AssertSame(FRouter, Sender);
  Inc(FStartCount);
  FStartMark := AMark;
end;

procedure TTimingMarkRouterTests.FinishReceived(Sender: TObject;
  const AMark: TFinishMark);
begin
  AssertSame(FRouter, Sender);
  Inc(FFinishCount);
  FFinishMark := AMark;
end;

procedure TTimingMarkRouterTests.Route_StartCallsOnlyStartHandler;
var
  Input: TTimingMark;
begin
  Input := TTimingMark.Start(EncodeTime(10, 0, 0, 1), True, -3,
    TTimingMarkSource.Serial('COM2'), EncodeDateTime(2026, 8, 13, 10, 0, 1, 2));

  FRouter.Route(Input, 3);

  AssertEquals(1, FStartCount);
  AssertEquals(0, FFinishCount);
  AssertEquals(3, FStartMark.StageIndex);
  AssertEquals(-3, FStartMark.CorrectionMs);
end;

procedure TTimingMarkRouterTests.Route_FinishCallsOnlyFinishHandler;
var
  Input: TTimingMark;
begin
  Input := TTimingMark.Finish(EncodeTime(11, 0, 0, 1),
    TTimingMarkSource.Ble('ENTime-4'), EncodeDateTime(2026, 8, 13, 11, 0, 1, 2));

  FRouter.Route(Input, 5);

  AssertEquals(0, FStartCount);
  AssertEquals(1, FFinishCount);
  AssertEquals(5, FFinishMark.StageIndex);
  AssertEquals('ENTime-4', FFinishMark.Source.DeviceId);
end;

initialization
  RegisterTest(TTimingMarkRouterTests);

end.
