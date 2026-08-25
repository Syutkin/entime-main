unit TimingMarkTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, FPCUnit, TestRegistry, TimingMark;

type
  TTimingMarkTests = class(TTestCase)
  published
    procedure Sources_PreserveKindAndDeviceId;
    procedure StartFactory_PreservesInputWithoutReadingClock;
    procedure FinishFactory_DoesNotInventCorrection;
  end;

implementation

procedure TTimingMarkTests.Sources_PreserveKindAndDeviceId;
var
  Source: TTimingMarkSource;
begin
  Source := TTimingMarkSource.Serial('/dev/ttyUSB0');
  AssertEquals(Ord(tmskSerial), Ord(Source.Kind));
  AssertEquals('/dev/ttyUSB0', Source.DeviceId);

  Source := TTimingMarkSource.Ble('ENTime-1');
  AssertEquals(Ord(tmskBle), Ord(Source.Kind));
  AssertEquals('ENTime-1', Source.DeviceId);

  Source := TTimingMarkSource.Manual;
  AssertEquals(Ord(tmskManual), Ord(Source.Kind));
  AssertEquals('', Source.DeviceId);
end;

procedure TTimingMarkTests.StartFactory_PreservesInputWithoutReadingClock;
var
  EventTime, ReceivedAt: TDateTime;
  Mark: TTimingMark;
begin
  EventTime := EncodeTime(10, 11, 12, 345);
  ReceivedAt := EncodeDateTime(2026, 8, 13, 10, 11, 13, 456);

  Mark := TTimingMark.Start(EventTime, True, -17,
    TTimingMarkSource.Serial('COM7'), ReceivedAt);

  AssertEquals(Ord(tmkStart), Ord(Mark.Kind));
  AssertEquals(EventTime, Mark.EventTime);
  AssertTrue(Mark.HasCorrection);
  AssertEquals(-17, Mark.CorrectionMs);
  AssertEquals(Ord(tmskSerial), Ord(Mark.Source.Kind));
  AssertEquals('COM7', Mark.Source.DeviceId);
  AssertEquals(ReceivedAt, Mark.ReceivedAt);
end;

procedure TTimingMarkTests.FinishFactory_DoesNotInventCorrection;
var
  Mark: TTimingMark;
begin
  Mark := TTimingMark.Finish(EncodeTime(11, 12, 13, 14),
    TTimingMarkSource.Ble('device-2'),
    EncodeDateTime(2026, 8, 13, 11, 12, 14, 15));

  AssertEquals(Ord(tmkFinish), Ord(Mark.Kind));
  AssertFalse(Mark.HasCorrection);
  AssertEquals(0, Mark.CorrectionMs);
end;

initialization
  RegisterTest(TTimingMarkTests);

end.
