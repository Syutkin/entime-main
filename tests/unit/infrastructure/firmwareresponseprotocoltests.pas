unit FirmwareResponseProtocolTests;

{$mode ObjFPC}{$H+}

interface

uses
  FPCUnit, TestRegistry, TimingMark, FirmwareResponseProtocol;

type
  TFirmwareResponseProtocolTests = class(TTestCase)
  published
    procedure TryParse_PreservesRawJsonSourceAndReceivedAt;
    procedure TryParse_RejectsInvalidJsonWithoutCreatingResponse;
  end;

implementation

procedure TFirmwareResponseProtocolTests.
  TryParse_PreservesRawJsonSourceAndReceivedAt;
const
  ReceivedAt: TDateTime = 45678.25;
var
  Error: TFirmwareResponseParseError;
  Parser: TFirmwareResponseParser;
  Response: TFirmwareResponse;
  Source: TTimingMarkSource;
begin
  Parser := TFirmwareResponseParser.Create;
  try
    Source := TTimingMarkSource.Ble('ENTime-1');

    AssertTrue(Parser.TryParse('{"status":"ok"}', Source, ReceivedAt,
      Response, Error));

    AssertEquals(Ord(frpeNone), Ord(Error));
    AssertEquals('{"status":"ok"}', Response.RawJson);
    AssertEquals(Ord(tmskBle), Ord(Response.Source.Kind));
    AssertEquals('ENTime-1', Response.Source.DeviceId);
    AssertEquals(ReceivedAt, Response.ReceivedAt);
  finally
    Parser.Free;
  end;
end;

procedure TFirmwareResponseProtocolTests.
  TryParse_RejectsInvalidJsonWithoutCreatingResponse;
var
  Error: TFirmwareResponseParseError;
  Parser: TFirmwareResponseParser;
  Response: TFirmwareResponse;
begin
  Parser := TFirmwareResponseParser.Create;
  try
    AssertFalse(Parser.TryParse('{invalid}',
      TTimingMarkSource.Serial('COM1'), 123, Response, Error));
    AssertEquals(Ord(frpeInvalidJson), Ord(Error));
    AssertEquals('', Response.RawJson);
  finally
    Parser.Free;
  end;
end;

initialization
  RegisterTest(TFirmwareResponseProtocolTests);

end.
