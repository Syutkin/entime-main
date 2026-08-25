unit TransportStreamProcessorTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, FPCUnit, TestRegistry, TimingProtocol, TimingMark,
  FirmwareResponseProtocol, TransportStreamProcessor;

type
  TTransportStreamProcessorTests = class(TTestCase)
  private
    FCallbacks: TStringList;
    FLastFirmwareResponse: TFirmwareResponse;
    FProcessor: TTransportStreamProcessor;
    procedure FirmwareResponseReceived(Sender: TObject;
      const AResponse: TFirmwareResponse);
    procedure PacketReceived(Sender: TObject; const APacket: TTimingPacket;
      const ASource: TTimingMarkSource);
    procedure Rejected(Sender: TObject;
      const ARejected: TTransportStreamRejected);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Feed_RoutesTimingAndFirmwareFramesWithSource;
    procedure Feed_ReportsInvalidMessagesAndContinues;
    procedure Reset_DropsIncompleteFrame;
  end;

implementation

procedure TTransportStreamProcessorTests.SetUp;
begin
  inherited SetUp;
  FCallbacks := TStringList.Create;
  FProcessor := TTransportStreamProcessor.Create;
  FProcessor.OnTimingPacket := @PacketReceived;
  FProcessor.OnFirmwareResponse := @FirmwareResponseReceived;
  FProcessor.OnRejected := @Rejected;
end;

procedure TTransportStreamProcessorTests.TearDown;
begin
  FProcessor.Free;
  FCallbacks.Free;
  inherited TearDown;
end;

procedure TTransportStreamProcessorTests.PacketReceived(Sender: TObject;
  const APacket: TTimingPacket; const ASource: TTimingMarkSource);
begin
  AssertSame(FProcessor, Sender);
  FCallbacks.Add('packet:' + APacket.RawText + ':' + ASource.DeviceId);
end;

procedure TTransportStreamProcessorTests.FirmwareResponseReceived(
  Sender: TObject; const AResponse: TFirmwareResponse);
begin
  AssertSame(FProcessor, Sender);
  FLastFirmwareResponse := AResponse;
  FCallbacks.Add('json:' + AResponse.Source.DeviceId);
end;

procedure TTransportStreamProcessorTests.Rejected(Sender: TObject;
  const ARejected: TTransportStreamRejected);
begin
  AssertSame(FProcessor, Sender);
  FCallbacks.Add('rejected:' + TransportStreamRejectedCode(ARejected) + ':' +
    ARejected.Source.DeviceId);
end;

procedure TTransportStreamProcessorTests.
  Feed_RoutesTimingAndFirmwareFramesWithSource;
const
  ReceivedAt: TDateTime = 45678.5;
var
  Source: TTimingMarkSource;
begin
  Source := TTimingMarkSource.Ble('ENTime-1');
  FProcessor.Feed('$01:02', Source, ReceivedAt);
  FProcessor.Feed(':03#' + '{"status":"ok"}' + #10, Source, ReceivedAt);

  AssertEquals(2, FCallbacks.Count);
  AssertEquals('packet:$01:02:03#:ENTime-1', FCallbacks[0]);
  AssertEquals('json:ENTime-1', FCallbacks[1]);
  AssertEquals('{"status":"ok"}', FLastFirmwareResponse.RawJson);
  AssertEquals(ReceivedAt, FLastFirmwareResponse.ReceivedAt);
end;

procedure TTransportStreamProcessorTests.
  Feed_ReportsInvalidMessagesAndContinues;
var
  Source: TTimingMarkSource;
begin
  Source := TTimingMarkSource.Serial('COM1');
  FProcessor.Feed('boot' + #10 + '$invalid#' + '{invalid}' + #10 +
    'F12:34:56#', Source, 123);

  AssertEquals(4, FCallbacks.Count);
  AssertEquals('rejected:diagnostic:COM1', FCallbacks[0]);
  AssertEquals('rejected:timing_invalid_time:COM1', FCallbacks[1]);
  AssertEquals('rejected:firmware_invalid_json:COM1', FCallbacks[2]);
  AssertEquals('packet:F12:34:56#:COM1', FCallbacks[3]);
end;

procedure TTransportStreamProcessorTests.Reset_DropsIncompleteFrame;
var
  Source: TTimingMarkSource;
begin
  Source := TTimingMarkSource.Serial('COM1');
  FProcessor.Feed('$01:02', Source, 123);
  FProcessor.Reset;
  FProcessor.Feed(':03#F02:03:04#', Source, 124);

  AssertEquals(2, FCallbacks.Count);
  AssertEquals('rejected:diagnostic:COM1', FCallbacks[0]);
  AssertEquals('packet:F02:03:04#:COM1', FCallbacks[1]);
end;

initialization
  RegisterTest(TTransportStreamProcessorTests);

end.
