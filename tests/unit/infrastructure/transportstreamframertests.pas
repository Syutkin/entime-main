unit TransportStreamFramerTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, FPCUnit, TestRegistry, TransportStreamFramer;

type
  TTransportStreamFramerTests = class(TTestCase)
  private
    FFramer: TTransportStreamFramer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Feed_ReassemblesFragmentedTimingAndJsonFrames;
    procedure Feed_ReassemblesFramesAtEverySplitPosition;
    procedure Feed_SeparatesInterleavedFramesInOrder;
    procedure Feed_EmitsDiagnosticsAndRecoversAfterOversizedJson;
    procedure Reset_DropsIncompleteFrame;
  end;

implementation

procedure TTransportStreamFramerTests.SetUp;
begin
  inherited SetUp;
  FFramer := TTransportStreamFramer.Create;
end;

procedure TTransportStreamFramerTests.TearDown;
begin
  FFramer.Free;
  inherited TearDown;
end;

procedure TTransportStreamFramerTests.
Feed_ReassemblesFragmentedTimingAndJsonFrames;
var
  Frames: TTransportFrameArray;
begin
  FFramer.Feed('$01:02', Frames);
  AssertEquals(0, Length(Frames));

  FFramer.Feed(':03#' + '{"status":"ok"', Frames);
  AssertEquals(1, Length(Frames));
  AssertEquals(Ord(tfkTimingPacket), Ord(Frames[0].Kind));
  AssertEquals('$01:02:03#', string(Frames[0].Text));

  FFramer.Feed('}' + #13#10, Frames);
  AssertEquals(1, Length(Frames));
  AssertEquals(Ord(tfkFirmwareResponse), Ord(Frames[0].Kind));
  AssertEquals('{"status":"ok"}', string(Frames[0].Text));
end;

procedure TTransportStreamFramerTests.
Feed_ReassemblesFramesAtEverySplitPosition;
const
  WireValues: array[0..2] of rawbytestring = (
    '$12:34:56,789;-1234#',
    'F23:59:59,999#',
    '{"status":"ok"}' + #10
    );
var
  ExpectedKind: TTransportFrameKind;
  ExpectedText: string;
  Frames: TTransportFrameArray;
  MessageIndex, SplitPosition: integer;
begin
  for MessageIndex := Low(WireValues) to High(WireValues) do
    for SplitPosition := 1 to Length(WireValues[MessageIndex]) - 1 do
    begin
      FFramer.Reset;
      FFramer.Feed(Copy(WireValues[MessageIndex], 1, SplitPosition), Frames);
      AssertEquals(0, Length(Frames));
      FFramer.Feed(Copy(WireValues[MessageIndex], SplitPosition + 1,
        MaxInt), Frames);
      AssertEquals(1, Length(Frames));
      if MessageIndex = 2 then
      begin
        ExpectedKind := tfkFirmwareResponse;
        ExpectedText := '{"status":"ok"}';
      end
      else
      begin
        ExpectedKind := tfkTimingPacket;
        ExpectedText := string(WireValues[MessageIndex]);
      end;
      AssertEquals(Ord(ExpectedKind), Ord(Frames[0].Kind));
      AssertEquals(ExpectedText, string(Frames[0].Text));
    end;
end;

procedure TTransportStreamFramerTests.Feed_SeparatesInterleavedFramesInOrder;
var
  Frames: TTransportFrameArray;
begin
  FFramer.Feed('{"id":1}' + #10 + '$01:02:03#' + '{"id":2}' + #10 +
    'F04:05:06#', Frames);

  AssertEquals(4, Length(Frames));
  AssertEquals(Ord(tfkFirmwareResponse), Ord(Frames[0].Kind));
  AssertEquals('{"id":1}', string(Frames[0].Text));
  AssertEquals(Ord(tfkTimingPacket), Ord(Frames[1].Kind));
  AssertEquals('$01:02:03#', string(Frames[1].Text));
  AssertEquals(Ord(tfkFirmwareResponse), Ord(Frames[2].Kind));
  AssertEquals('{"id":2}', string(Frames[2].Text));
  AssertEquals(Ord(tfkTimingPacket), Ord(Frames[3].Kind));
  AssertEquals('F04:05:06#', string(Frames[3].Text));
end;

procedure TTransportStreamFramerTests.
Feed_EmitsDiagnosticsAndRecoversAfterOversizedJson;
var
  Frames: TTransportFrameArray;
  OversizedJson: rawbytestring;
begin
  FFramer.Feed('DEBUG F12:34:56#' + #10 + '$invalid#', Frames);
  AssertEquals(2, Length(Frames));
  AssertEquals(Ord(tfkDiagnostic), Ord(Frames[0].Kind));
  AssertEquals('DEBUG F12:34:56#', string(Frames[0].Text));
  AssertEquals(Ord(tfkTimingPacket), Ord(Frames[1].Kind));
  AssertEquals('$invalid#', string(Frames[1].Text));

  OversizedJson := '{"value":"' + rawbytestring(StringOfChar('x',
    TRANSPORT_STREAM_MAX_MESSAGE_SIZE)) + '"}' + 'F12:34:56#';
  FFramer.Feed(OversizedJson, Frames);

  AssertEquals(2, Length(Frames));
  AssertEquals(Ord(tfkDiagnostic), Ord(Frames[0].Kind));
  AssertEquals(Ord(tfkTimingPacket), Ord(Frames[1].Kind));
  AssertEquals('F12:34:56#', string(Frames[1].Text));
  AssertEquals(1, FFramer.OverflowCount);
end;

procedure TTransportStreamFramerTests.Reset_DropsIncompleteFrame;
var
  Frames: TTransportFrameArray;
begin
  FFramer.Feed('{"old":', Frames);
  FFramer.Reset;
  FFramer.Feed('true}' + #10 + 'F01:02:03#', Frames);

  AssertEquals(2, Length(Frames));
  AssertEquals(Ord(tfkDiagnostic), Ord(Frames[0].Kind));
  AssertEquals('true}', string(Frames[0].Text));
  AssertEquals(Ord(tfkTimingPacket), Ord(Frames[1].Kind));
end;

initialization
  RegisterTest(TTransportStreamFramerTests);

end.
