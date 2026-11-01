unit FirmwareResponseProtocol;

{$mode ObjFPC}{$H+}

interface

uses
  TimingMark;

type
  TFirmwareResponseParseError = (frpeNone, frpeEmpty, frpeInvalidJson);

  TFirmwareResponse = record
    RawJson: string;
    Source: TTimingMarkSource;
    ReceivedAt: TDateTime;
  end;

  { TFirmwareResponseParser }

  TFirmwareResponseParser = class
  public
    function TryParse(const ARawJson: string; const ASource: TTimingMarkSource;
      const AReceivedAt: TDateTime; out AResponse: TFirmwareResponse;
      out AError: TFirmwareResponseParseError): boolean;
  end;

function FirmwareResponseParseErrorCode(
  const AError: TFirmwareResponseParseError): string;

implementation

uses
  SysUtils, FPJson, JsonParser;

function FirmwareResponseParseErrorCode(
  const AError: TFirmwareResponseParseError): string;
begin
  case AError of
    frpeNone: Result := 'none';
    frpeEmpty: Result := 'empty';
    frpeInvalidJson: Result := 'invalid_json';
  end;
end;

function TFirmwareResponseParser.TryParse(const ARawJson: string;
  const ASource: TTimingMarkSource; const AReceivedAt: TDateTime;
  out AResponse: TFirmwareResponse; out AError: TFirmwareResponseParseError): boolean;
var
  Json: TJSONData;
  JsonText: string;
begin
  AResponse := Default(TFirmwareResponse);
  AError := frpeNone;
  JsonText := Trim(ARawJson);
  if JsonText = '' then
  begin
    AError := frpeEmpty;
    Exit(False);
  end;

  Json := nil;
  try
    try
      Json := GetJSON(JsonText);
      if not (Json.JSONType in [jtObject, jtArray]) then
      begin
        AError := frpeInvalidJson;
        Exit(False);
      end;
    except
      AError := frpeInvalidJson;
      Exit(False);
    end;

    AResponse.RawJson := ARawJson;
    AResponse.Source := ASource;
    AResponse.ReceivedAt := AReceivedAt;
    Result := True;
  finally
    Json.Free;
  end;
end;

end.
