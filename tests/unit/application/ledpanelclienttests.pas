unit LedPanelClientTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, HttpTransport,
  FakeHttpTransport, CompetitionFinishService, LedPanelClient;

type
  TLedPanelClientTests = class(TTestCase)
  published
    procedure Address_NormalizesHostAndPort;
    procedure Address_RejectsSchemePathAndInvalidPort;
    procedure FinishRequest_UsesEncodedPostAndLanTimeouts;
    procedure FinishRequest_FitsBothLinesWithoutLosingHours;
    procedure Send_AcceptsEveryTwoHundredStatusWithoutBody;
    procedure Send_RejectsClientAndServerErrors;
  end;

implementation

function FinishResult: TFinishResult;
begin
  Result := Default(TFinishResult);
  Result.ParticipantNumber := 25;
  Result.ResultValue := '00:03:43.459';
  Result.Place := 2;
  Result.Difference := '00:01:59.523';
  Result.PreviousLeaderNumber := 17;
  Result.PreviousLeaderResult := '00:01:43.936';
end;

function HttpResponse(const AStatus: integer): THttpResponse;
begin
  Result := Default(THttpResponse);
  Result.Completed := True;
  Result.StatusCode := AStatus;
end;

procedure TLedPanelClientTests.Address_NormalizesHostAndPort;
var
  Endpoint: string;
begin
  AssertTrue(TLedPanelClient.TryBuildEndpoint(' 192.168.1.10 ', Endpoint));
  AssertEquals('http://192.168.1.10/post', Endpoint);
  AssertTrue(TLedPanelClient.TryBuildEndpoint('panel.local:8080', Endpoint));
  AssertEquals('http://panel.local:8080/post', Endpoint);
end;

procedure TLedPanelClientTests.Address_RejectsSchemePathAndInvalidPort;
var
  Endpoint: string;
begin
  AssertFalse(TLedPanelClient.TryBuildEndpoint('http://192.168.1.10', Endpoint));
  AssertFalse(TLedPanelClient.TryBuildEndpoint('192.168.1.10/post', Endpoint));
  AssertFalse(TLedPanelClient.TryBuildEndpoint('panel.local:70000', Endpoint));
  AssertFalse(TLedPanelClient.TryBuildEndpoint('', Endpoint));
end;

procedure TLedPanelClientTests.FinishRequest_UsesEncodedPostAndLanTimeouts;
var
  Request: THttpRequest;
begin
  AssertTrue(TLedPanelClient.TryBuildFinishRequest(FinishResult,
    'panel.local:8080', Request));
  AssertEquals(Ord(hmPost), Ord(Request.Method));
  AssertEquals('http://panel.local:8080/post', Request.Url);
  AssertEquals(1000, Request.ConnectTimeoutMs);
  AssertEquals(2000, Request.ReadTimeoutMs);
  AssertEquals(1, Length(Request.Headers));
  AssertTrue(Pos('upperline=', string(Request.Body)) > 0);
  AssertTrue(Pos('bottomline=', string(Request.Body)) > 0);
  AssertEquals(0, Pos(' ', string(Request.Body)));
end;

procedure TLedPanelClientTests.FinishRequest_FitsBothLinesWithoutLosingHours;
const
  Times: array[0..4] of string = ('00:02:34.567', '00:59:59.999',
    '01:00:00.000', '01:02:03.456', '10:02:03.456');
  TimeFields: array[0..4] of string = (' 2:34.567', '59:59.999',
    '1:00:00.0', '1:02:03.4', ' 10:02:03');
var
  Finish: TFinishResult;
  Request: THttpRequest;
  Fields: TStringList;
  Upper, Bottom: string;
  I, Place: integer;
begin
  Finish := FinishResult;
  Finish.PreviousLeaderResult := '10:02:03.456';
  Finish.Difference := '01:02:03.456';
  Fields := TStringList.Create;
  try
    Fields.StrictDelimiter := True;
    Fields.Delimiter := '&';
    for I := Low(Times) to High(Times) do
      for Place := 1 to 2 do
      begin
        Finish.ResultValue := Times[I];
        Finish.Place := Place;
        AssertTrue(TLedPanelClient.TryBuildFinishRequest(Finish,
          'panel.local', Request));
        Fields.DelimitedText := string(Request.Body);
        if Place = 1 then
        begin
          Upper := ' 25 ' + TimeFields[I] + ' -1:02:03   1';
          Bottom := ' 17  10:02:03' + StringOfChar(' ', 11) + '2';
        end
        else
        begin
          Upper := ' 17  10:02:03' + StringOfChar(' ', 11) + '1';
          Bottom := ' 25 ' + TimeFields[I] + ' 1:02:03   2';
        end;
        AssertTrue(Length(Upper) <= 26);
        AssertTrue(Length(Bottom) <= 26);
        AssertEquals('Upper line for ' + Times[I],
          string(FormUrlEncode(Upper)), Fields.Values['upperline']);
        AssertEquals('Bottom line for ' + Times[I],
          string(FormUrlEncode(Bottom)), Fields.Values['bottomline']);
      end;
  finally
    Fields.Free;
  end;
end;

procedure TLedPanelClientTests.Send_AcceptsEveryTwoHundredStatusWithoutBody;
var
  Outcome: TFinishNotificationOutcome;
  Request: THttpRequest;
  Transport: IHttpTransport;
  TransportObject: TFakeHttpTransport;
begin
  AssertTrue(TLedPanelClient.TryBuildTestRequest('panel.local', '',
    'upper', 'bottom', Request));
  TransportObject := TFakeHttpTransport.Create;
  Transport := TransportObject;
  TransportObject.QueueResponse(HttpResponse(204));

  Outcome := TLedPanelClient.Send(Request, Transport);

  AssertTrue(Outcome.Success);
  AssertEquals(204, Outcome.ResponseStatusCode);
  AssertEquals(0, Outcome.ResponseSize);
end;

procedure TLedPanelClientTests.Send_RejectsClientAndServerErrors;
var
  Outcome: TFinishNotificationOutcome;
  Request: THttpRequest;
  Transport: IHttpTransport;
  TransportObject: TFakeHttpTransport;
begin
  AssertTrue(TLedPanelClient.TryBuildTestRequest('panel.local', 'line',
    '', '', Request));
  TransportObject := TFakeHttpTransport.Create;
  Transport := TransportObject;
  TransportObject.QueueResponse(HttpResponse(400));
  Outcome := TLedPanelClient.Send(Request, Transport);
  AssertFalse(Outcome.Success);
  AssertEquals(400, Outcome.ResponseStatusCode);

  TransportObject := TFakeHttpTransport.Create;
  Transport := TransportObject;
  TransportObject.QueueResponse(HttpResponse(500));
  Outcome := TLedPanelClient.Send(Request, Transport);
  AssertFalse(Outcome.Success);
  AssertEquals(500, Outcome.ResponseStatusCode);
end;

initialization
  RegisterTest(TLedPanelClientTests);

end.
