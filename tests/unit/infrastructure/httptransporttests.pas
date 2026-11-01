unit HttpTransportTests;

{$mode ObjFPC}{$H+}
{$codepage UTF8}

interface

uses
  SysUtils, fpcunit, testregistry, HttpTransport, FakeHttpTransport;

type
  THttpTransportTests = class(TTestCase)
  published
    procedure FormUrlEncode_EncodesUtf8AndReservedCharacters;
    procedure BuildGetRequest_AppendsEncodedQueryAndPreservesFragment;
    procedure BuildFormPostRequest_SetsBodyContentTypeAndTimeouts;
    procedure HttpSuccessStatus_AcceptsOnlyTwoHundreds;
    procedure CloneRequestAndResponse_CopyHeaderStorage;
    procedure FakeTransport_ReturnsQueuedResponsesAndCapturesRequests;
    procedure FakeTransport_CapturesAnIndependentRequestCopy;
    procedure FakeTransport_CancelPreventsExecution;
    procedure FakeFactory_CreatesSeparateTransports;
  end;

implementation

procedure THttpTransportTests.FormUrlEncode_EncodesUtf8AndReservedCharacters;
begin
  AssertEquals('A+B%2B%26%2F%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82',
    string(FormUrlEncode('A B+&/Привет')));
  AssertEquals('-._~azAZ09', string(FormUrlEncode('-._~azAZ09')));
end;

procedure THttpTransportTests.BuildGetRequest_AppendsEncodedQueryAndPreservesFragment;
var
  Fields: THttpFormFields;
  Request: THttpRequest;
begin
  SetLength(Fields, 2);
  Fields[0] := HttpFormField('name', 'Alice & Bob');
  Fields[1] := HttpFormField('empty', '');

  Request := BuildHttpGetRequest('https://example.test/path?existing=yes#details',
    Fields, 3000, 5000, False);

  AssertEquals(Ord(hmGet), Ord(Request.Method));
  AssertEquals(
    'https://example.test/path?existing=yes&name=Alice+%26+Bob&empty=#details',
    Request.Url);
  AssertEquals(3000, Request.ConnectTimeoutMs);
  AssertEquals(5000, Request.ReadTimeoutMs);
  AssertFalse(Request.AllowRedirects);
  AssertEquals(0, Length(Request.Headers));
  AssertEquals('', string(Request.Body));
end;

procedure THttpTransportTests.BuildFormPostRequest_SetsBodyContentTypeAndTimeouts;
var
  Fields: THttpFormFields;
  Request: THttpRequest;
begin
  SetLength(Fields, 2);
  Fields[0] := HttpFormField('chat_id', '-100 42');
  Fields[1] := HttpFormField('text', 'Готово!');

  Request := BuildHttpFormPostRequest('https://example.test/send',
    Fields, 1000, 2000);

  AssertEquals(Ord(hmPost), Ord(Request.Method));
  AssertEquals('https://example.test/send', Request.Url);
  AssertEquals('chat_id=-100+42&text=%D0%93%D0%BE%D1%82%D0%BE%D0%B2%D0%BE%21',
    string(Request.Body));
  AssertEquals(1, Length(Request.Headers));
  AssertEquals('Content-Type', Request.Headers[0].Name);
  AssertEquals('application/x-www-form-urlencoded; charset=utf-8',
    Request.Headers[0].Value);
  AssertEquals(1000, Request.ConnectTimeoutMs);
  AssertEquals(2000, Request.ReadTimeoutMs);
  AssertTrue(Request.AllowRedirects);
end;

procedure THttpTransportTests.HttpSuccessStatus_AcceptsOnlyTwoHundreds;
begin
  AssertFalse(IsHttpSuccessStatus(199));
  AssertTrue(IsHttpSuccessStatus(200));
  AssertTrue(IsHttpSuccessStatus(204));
  AssertTrue(IsHttpSuccessStatus(299));
  AssertFalse(IsHttpSuccessStatus(300));
end;

procedure THttpTransportTests.CloneRequestAndResponse_CopyHeaderStorage;
var
  Request, RequestCopy: THttpRequest;
  Response, ResponseCopy: THttpResponse;
begin
  Request := Default(THttpRequest);
  SetLength(Request.Headers, 1);
  Request.Headers[0] := HttpHeader('Authorization', 'first');
  RequestCopy := CloneHttpRequest(Request);
  RequestCopy.Headers[0].Value := 'second';
  AssertEquals('first', Request.Headers[0].Value);

  Response := Default(THttpResponse);
  SetLength(Response.Headers, 1);
  Response.Headers[0] := HttpHeader('X-Test', 'original');
  ResponseCopy := CloneHttpResponse(Response);
  ResponseCopy.Headers[0].Value := 'changed';
  AssertEquals('original', Response.Headers[0].Value);
end;

procedure THttpTransportTests.FakeTransport_ReturnsQueuedResponsesAndCapturesRequests;
var
  Fake: TFakeHttpTransport;
  Transport: IHttpTransport;
  Request: THttpRequest;
  FirstResponse, SecondResponse, Actual: THttpResponse;
begin
  Fake := TFakeHttpTransport.Create;
  Transport := Fake;
  FirstResponse := Default(THttpResponse);
  FirstResponse.Completed := True;
  FirstResponse.StatusCode := 204;
  SecondResponse := Default(THttpResponse);
  SecondResponse.Completed := True;
  SecondResponse.StatusCode := 500;
  SecondResponse.Body := 'failure';
  Fake.QueueResponse(FirstResponse);
  Fake.QueueResponse(SecondResponse);

  Request := BuildHttpGetRequest('https://example.test/one', [], 100, 200);
  Actual := Transport.Execute(Request);
  AssertEquals(204, Actual.StatusCode);
  Request.Url := 'https://example.test/two';
  Actual := Transport.Execute(Request);

  AssertEquals(500, Actual.StatusCode);
  AssertEquals('failure', string(Actual.Body));
  AssertEquals(2, Fake.RequestCount);
  AssertEquals('https://example.test/one', Fake.Requests[0].Url);
  AssertEquals('https://example.test/two', Fake.Requests[1].Url);
end;

procedure THttpTransportTests.FakeTransport_CapturesAnIndependentRequestCopy;
var
  Fake: TFakeHttpTransport;
  Transport: IHttpTransport;
  Request: THttpRequest;
  Response: THttpResponse;
begin
  Fake := TFakeHttpTransport.Create;
  Transport := Fake;
  Response := Default(THttpResponse);
  Response.Completed := True;
  Fake.QueueResponse(Response);
  Request := Default(THttpRequest);
  SetLength(Request.Headers, 1);
  Request.Headers[0] := HttpHeader('X-Test', 'before');

  Transport.Execute(Request);
  Request.Headers[0].Value := 'after';

  AssertEquals('before', Fake.Requests[0].Headers[0].Value);
end;

procedure THttpTransportTests.FakeTransport_CancelPreventsExecution;
var
  Fake: TFakeHttpTransport;
  Transport: IHttpTransport;
  Request: THttpRequest;
  Response: THttpResponse;
begin
  Fake := TFakeHttpTransport.Create;
  Transport := Fake;
  Transport.Cancel;
  Request := Default(THttpRequest);

  Response := Transport.Execute(Request);

  AssertFalse(Response.Completed);
  AssertEquals(Ord(hekCancelled), Ord(Response.ErrorKind));
  AssertEquals(1, Fake.CancelCount);
  AssertEquals(0, Fake.RequestCount);
end;

procedure THttpTransportTests.FakeFactory_CreatesSeparateTransports;
var
  Factory: TFakeHttpTransportFactory;
  FactoryIntf: IHttpTransportFactory;
  First, Second: IHttpTransport;
  Response: THttpResponse;
begin
  Factory := TFakeHttpTransportFactory.Create;
  FactoryIntf := Factory;
  Response := Default(THttpResponse);
  Response.Completed := True;
  Response.StatusCode := 200;
  Factory.QueueResponse(Response);
  Response.StatusCode := 201;
  Factory.QueueResponse(Response);

  First := FactoryIntf.CreateTransport;
  Second := FactoryIntf.CreateTransport;

  AssertTrue(First <> Second);
  AssertEquals(2, Factory.TransportCount);
  AssertEquals(200, First.Execute(Default(THttpRequest)).StatusCode);
  AssertEquals(201, Second.Execute(Default(THttpRequest)).StatusCode);
end;

initialization
  RegisterTest(THttpTransportTests);

end.
