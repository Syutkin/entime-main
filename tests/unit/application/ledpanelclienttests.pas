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

function HttpResponse(const AStatus: Integer): THttpResponse;
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
  AssertFalse(TLedPanelClient.TryBuildEndpoint(
    'http://192.168.1.10', Endpoint));
  AssertFalse(TLedPanelClient.TryBuildEndpoint(
    '192.168.1.10/post', Endpoint));
  AssertFalse(TLedPanelClient.TryBuildEndpoint(
    'panel.local:70000', Endpoint));
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
