unit TimingPacketMarkMapperTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, FPCUnit, TestRegistry, TimingProtocol, TimingMark,
  TimingPacketMarkMapper;

type
  TTimingPacketMarkMapperTests = class(TTestCase)
  published
    procedure Map_StartPreservesPacketAndContext;
    procedure Map_FinishDropsCorrectionFields;
    procedure Map_SamePacketPreservesDomainFieldsAndDistinguishesSource;
  end;

implementation

procedure TTimingPacketMarkMapperTests.Map_StartPreservesPacketAndContext;
var
  Packet: TTimingPacket;
  ReceivedAt: TDateTime;
  Mark: TTimingMark;
begin
  Packet := Default(TTimingPacket);
  Packet.Kind := tpkStart;
  Packet.EventTime := EncodeTime(12, 1, 2, 3);
  Packet.HasCorrection := True;
  Packet.CorrectionMs := -9;
  ReceivedAt := EncodeDateTime(2026, 8, 13, 12, 1, 3, 4);

  Mark := TimingMarkFromTimingPacket(Packet, TTimingMarkSource.Serial('COM4'),
    ReceivedAt);

  AssertEquals(Ord(tmkStart), Ord(Mark.Kind));
  AssertEquals(Packet.EventTime, Mark.EventTime);
  AssertTrue(Mark.HasCorrection);
  AssertEquals(-9, Mark.CorrectionMs);
  AssertEquals('COM4', Mark.Source.DeviceId);
  AssertEquals(ReceivedAt, Mark.ReceivedAt);
end;

procedure TTimingPacketMarkMapperTests.Map_FinishDropsCorrectionFields;
var
  Packet: TTimingPacket;
  Mark: TTimingMark;
begin
  Packet := Default(TTimingPacket);
  Packet.Kind := tpkFinish;
  Packet.EventTime := EncodeTime(13, 2, 3, 4);
  Packet.HasCorrection := True;
  Packet.CorrectionMs := 99;

  Mark := TimingMarkFromTimingPacket(Packet, TTimingMarkSource.Ble('device-5'),
    EncodeDateTime(2026, 8, 13, 13, 2, 4, 5));

  AssertEquals(Ord(tmkFinish), Ord(Mark.Kind));
  AssertFalse(Mark.HasCorrection);
  AssertEquals(0, Mark.CorrectionMs);
end;

procedure TTimingPacketMarkMapperTests.
Map_SamePacketPreservesDomainFieldsAndDistinguishesSource;
var
  BleMark, SerialMark: TTimingMark;
  Packet: TTimingPacket;
  ReceivedAt: TDateTime;
begin
  Packet := Default(TTimingPacket);
  Packet.Kind := tpkStart;
  Packet.EventTime := EncodeTime(14, 3, 4, 5);
  Packet.HasCorrection := True;
  Packet.CorrectionMs := 17;
  ReceivedAt := EncodeDateTime(2026, 8, 13, 14, 3, 5, 6);

  SerialMark := TimingMarkFromTimingPacket(Packet, TTimingMarkSource.Serial('COM8'),
    ReceivedAt);
  BleMark := TimingMarkFromTimingPacket(Packet, TTimingMarkSource.Ble('device-8'),
    ReceivedAt);

  AssertEquals(Ord(SerialMark.Kind), Ord(BleMark.Kind));
  AssertEquals(SerialMark.EventTime, BleMark.EventTime);
  AssertEquals(SerialMark.CorrectionMs, BleMark.CorrectionMs);
  AssertEquals(SerialMark.ReceivedAt, BleMark.ReceivedAt);
  AssertEquals(Ord(tmskSerial), Ord(SerialMark.Source.Kind));
  AssertEquals(Ord(tmskBle), Ord(BleMark.Source.Kind));
  AssertEquals('COM8', SerialMark.Source.DeviceId);
  AssertEquals('device-8', BleMark.Source.DeviceId);
end;

initialization
  RegisterTest(TTimingPacketMarkMapperTests);

end.
