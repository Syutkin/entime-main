unit TimingProtocolTests;

{$mode ObjFPC}{$H+}

interface

uses
  FPCUnit, TestRegistry, TimingProtocol;

type
  { TTimingProtocolTests }

  TTimingProtocolTests = class(TTestCase)
  private
    procedure AssertPacketTime(const APacket: TTimingPacket;
      const AHour, AMinute, ASecond, AMillisecond: word);
    procedure AssertParseError(const ARawPacket: string;
      const AExpectedError: TTimingPacketParseError);
  published
    procedure Parser_AcceptsStartWithSignedCorrection;
    procedure Parser_AcceptsStartWithoutCorrection;
    procedure Parser_AcceptsCorrectionBounds;
    procedure Parser_AcceptsFinish;
    procedure Parser_AcceptsTimeWithoutMilliseconds;
    procedure Parser_AcceptsTimeBounds;
    procedure Parser_RejectsDotAsFractionSeparator;
    procedure Parser_RejectsUnsupportedTimeStructuresAndRanges;
    procedure Parser_ReportsPacketStructureErrors;
    procedure Parser_RejectsInvalidCorrections;
    procedure Parser_ErrorCodesAreStable;
    procedure Logging_EscapesAndBoundsRawPacket;
  end;

implementation

uses
  SysUtils;

procedure TTimingProtocolTests.AssertPacketTime(const APacket: TTimingPacket;
  const AHour, AMinute, ASecond, AMillisecond: word);
var
  hour, millisecond, minute, second: word;
begin
  DecodeTime(APacket.EventTime, hour, minute, second, millisecond);
  AssertEquals('Hour', AHour, hour);
  AssertEquals('Minute', AMinute, minute);
  AssertEquals('Second', ASecond, second);
  AssertEquals('Millisecond', AMillisecond, millisecond);
end;

procedure TTimingProtocolTests.AssertParseError(const ARawPacket: string;
  const AExpectedError: TTimingPacketParseError);
var
  error: TTimingPacketParseError;
  packet: TTimingPacket;
begin
  AssertFalse('Packet must be rejected: ' + ARawPacket,
    TryParseTimingPacket(ARawPacket, packet, error));
  AssertEquals('Unexpected parse error for: ' + ARawPacket,
    Ord(AExpectedError), Ord(error));
end;

procedure TTimingProtocolTests.Parser_AcceptsStartWithSignedCorrection;
var
  error: TTimingPacketParseError;
  packet: TTimingPacket;
begin
  AssertTrue(TryParseTimingPacket('$12:34:56,789;-1234#', packet, error));
  AssertEquals(Ord(tppeNone), Ord(error));
  AssertEquals(Ord(tpkStart), Ord(packet.Kind));
  AssertTrue(packet.HasCorrection);
  AssertEquals(-1234, packet.CorrectionMs);
  AssertEquals('$12:34:56,789;-1234#', packet.RawText);
  AssertPacketTime(packet, 12, 34, 56, 789);

  AssertTrue(TryParseTimingPacket('$01:02:03,004;+5#', packet, error));
  AssertTrue(packet.HasCorrection);
  AssertEquals(5, packet.CorrectionMs);
  AssertPacketTime(packet, 1, 2, 3, 4);

  AssertTrue(TryParseTimingPacket('$01:02:03,004;0#', packet, error));
  AssertTrue(packet.HasCorrection);
  AssertEquals(0, packet.CorrectionMs);
end;

procedure TTimingProtocolTests.Parser_AcceptsStartWithoutCorrection;
var
  error: TTimingPacketParseError;
  packet: TTimingPacket;
begin
  AssertTrue(TryParseTimingPacket('$12:34:56,789#', packet, error));
  AssertEquals(Ord(tpkStart), Ord(packet.Kind));
  AssertFalse(packet.HasCorrection);
  AssertEquals(0, packet.CorrectionMs);
  AssertPacketTime(packet, 12, 34, 56, 789);
end;

procedure TTimingProtocolTests.Parser_AcceptsCorrectionBounds;
var
  error: TTimingPacketParseError;
  packet: TTimingPacket;
begin
  AssertTrue(TryParseTimingPacket('$00:00:00,000;60000#', packet, error));
  AssertEquals(TIMING_CORRECTION_LIMIT_MS, packet.CorrectionMs);

  AssertTrue(TryParseTimingPacket('$23:59:59,999;-60000#', packet, error));
  AssertEquals(-TIMING_CORRECTION_LIMIT_MS, packet.CorrectionMs);

  AssertTrue(TryParseTimingPacket('$12:00:00,000;+00060000#', packet, error));
  AssertEquals(TIMING_CORRECTION_LIMIT_MS, packet.CorrectionMs);
end;

procedure TTimingProtocolTests.Parser_AcceptsFinish;
var
  error: TTimingPacketParseError;
  packet: TTimingPacket;
begin
  AssertTrue(TryParseTimingPacket('F23:59:59,999#', packet, error));
  AssertEquals(Ord(tpkFinish), Ord(packet.Kind));
  AssertFalse(packet.HasCorrection);
  AssertPacketTime(packet, 23, 59, 59, 999);
end;

procedure TTimingProtocolTests.Parser_AcceptsTimeWithoutMilliseconds;
var
  error: TTimingPacketParseError;
  packet: TTimingPacket;
begin
  AssertTrue(TryParseTimingPacket('$12:34:56;0#', packet, error));
  AssertPacketTime(packet, 12, 34, 56, 0);

  AssertTrue(TryParseTimingPacket('F01:02:03#', packet, error));
  AssertPacketTime(packet, 1, 2, 3, 0);
end;

procedure TTimingProtocolTests.Parser_AcceptsTimeBounds;
var
  error: TTimingPacketParseError;
  packet: TTimingPacket;
begin
  AssertTrue(TryParseTimingPacket('$00:00:00,000;0#', packet, error));
  AssertPacketTime(packet, 0, 0, 0, 0);

  AssertTrue(TryParseTimingPacket('F23:59:59,999#', packet, error));
  AssertPacketTime(packet, 23, 59, 59, 999);
end;

procedure TTimingProtocolTests.Parser_RejectsDotAsFractionSeparator;
begin
  AssertParseError('$12:34:56.789;0#', tppeInvalidTime);
  AssertParseError('F12:34:56.789#', tppeInvalidTime);
end;

procedure TTimingProtocolTests.Parser_RejectsUnsupportedTimeStructuresAndRanges;
begin
  AssertParseError('$1:2:3;0#', tppeInvalidTime);
  AssertParseError('$12:34;0#', tppeInvalidTime);
  AssertParseError('$12-34-56,789;0#', tppeInvalidTime);
  AssertParseError('$12:34:56,78;0#', tppeInvalidTime);
  AssertParseError('$12:34:56,0789;0#', tppeInvalidTime);
  AssertParseError('$12:34:56,abc;0#', tppeInvalidTime);
  AssertParseError('$24:00:00,000;0#', tppeInvalidTime);
  AssertParseError('$12:60:00,000;0#', tppeInvalidTime);
  AssertParseError('$12:00:60,000;0#', tppeInvalidTime);
  AssertParseError('$12:00:00,1000;0#', tppeInvalidTime);
end;

procedure TTimingProtocolTests.Parser_ReportsPacketStructureErrors;
begin
  AssertParseError('', tppeMissingTerminator);
  AssertParseError('12:34:56,789#', tppeUnknownHeader);
  AssertParseError('X12:34:56,789#', tppeUnknownHeader);
  AssertParseError('$12:34:56,789;0', tppeMissingTerminator);
  AssertParseError('$12:34:56,789;0#tail', tppeUnexpectedData);
  AssertParseError('#$12:34:56,789;0#', tppeUnexpectedData);
  AssertParseError('$12:34:56,789;0##', tppeUnexpectedData);
  AssertParseError('$12:34:56,789;1;2#', tppeInvalidFieldCount);
  AssertParseError('F12:34:56,789;1#', tppeInvalidFieldCount);
  AssertParseError('$12:34:56,789:1#', tppeInvalidTime);
end;

procedure TTimingProtocolTests.Parser_RejectsInvalidCorrections;
begin
  AssertParseError('$12:34:56,789;#', tppeInvalidCorrection);
  AssertParseError('$12:34:56,789;1.5#', tppeInvalidCorrection);
  AssertParseError('$12:34:56,789; 1#', tppeInvalidCorrection);
  AssertParseError('$12:34:56,789;abc#', tppeInvalidCorrection);
  AssertParseError('$12:34:56,789;+#', tppeInvalidCorrection);
  AssertParseError('$12:34:56,789;-#', tppeInvalidCorrection);
  AssertParseError('$12:34:56,789;60001#', tppeInvalidCorrection);
  AssertParseError('$12:34:56,789;-60001#', tppeInvalidCorrection);
  AssertParseError('$12:34:56,789;4294907296#', tppeInvalidCorrection);
end;

procedure TTimingProtocolTests.Parser_ErrorCodesAreStable;
begin
  AssertEquals('none', TimingPacketParseErrorCode(tppeNone));
  AssertEquals('unknown_header',
    TimingPacketParseErrorCode(tppeUnknownHeader));
  AssertEquals('missing_terminator',
    TimingPacketParseErrorCode(tppeMissingTerminator));
  AssertEquals('invalid_field_count',
    TimingPacketParseErrorCode(tppeInvalidFieldCount));
  AssertEquals('invalid_time', TimingPacketParseErrorCode(tppeInvalidTime));
  AssertEquals('invalid_correction',
    TimingPacketParseErrorCode(tppeInvalidCorrection));
  AssertEquals('unexpected_data',
    TimingPacketParseErrorCode(tppeUnexpectedData));
end;

procedure TTimingProtocolTests.Logging_EscapesAndBoundsRawPacket;
var
  logValue: string;
begin
  logValue := TimingPacketLogValue('$bad' + #9#10#13#0 + '\' +
    StringOfChar('X', TIMING_LOG_VALUE_MAX_LENGTH));

  AssertTrue(Pos('\t', logValue) > 0);
  AssertTrue(Pos('\n', logValue) > 0);
  AssertTrue(Pos('\r', logValue) > 0);
  AssertTrue(Pos('\x00', logValue) > 0);
  AssertTrue(Pos('\\', logValue) > 0);
  AssertTrue(Length(logValue) <= TIMING_LOG_VALUE_MAX_LENGTH);
  AssertEquals('...', Copy(logValue, Length(logValue) - 2, 3));
end;

initialization
  RegisterTest(TTimingProtocolTests);

end.
