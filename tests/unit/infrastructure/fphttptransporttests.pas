unit FpHttpTransportTests;

{$mode ObjFPC}{$H+}
{$codepage UTF8}

{ This regression test is relevant only to the compatibility shim. Other
  platforms and newer FPC versions use their native OpenSSL lookup tables. }
{$IF FPC_FULLVERSION = 30202}
  {$IFDEF LINUX}
    {$IFDEF CPUX86_64}
      {$DEFINE TEST_OPENSSL3_LINUX_LOADER}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, HttpTransport, FpHttpTransport,
  LoopbackHttpServer, SSockets
  {$IFDEF TEST_OPENSSL3_LINUX_LOADER}, OpenSSL{$ENDIF};

type
  TFpHttpTransportTests = class(TTestCase)
  private
    FServer: TLoopbackHttpServer;
    function ExecuteRequest(const ARequest: THttpRequest): THttpResponse;
    function ResponseHeader(const AResponse: THttpResponse;
      const AName: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Get_PreservesStatusHeadersBodyAndRequestHeaders;
    procedure Post_SendsRawUtf8Body;
    procedure HttpStatuses_AreCompletedTransportResponses;
    procedure Redirect_RespectsRequestPolicy;
    procedure ConnectionRefused_ReturnsSafeTransportError;
    procedure SocketErrors_AreClassifiedDeterministically;
    procedure ReadTimeout_ReturnsTimeoutWithoutSecretData;
    procedure CancelActiveRequest_ReturnsCancelledWithinReadTimeout;
    procedure Transport_CannotBeReused;
    procedure Factory_CreatesIndependentTransports;
    {$IFDEF TEST_OPENSSL3_LINUX_LOADER}
    procedure OpenSsl3Loader_PrioritizesVersionThreeSoname;
    {$ENDIF}
  end;

implementation

type
  TInspectableFpHttpTransport = class(TFpHttpTransport)
  public
    function MapException(const AException: Exception;
      const ARequest: THttpRequest): THttpResponse;
  end;

  TExecuteThread = class(TThread)
  private
    FTransport: IHttpTransport;
    FRequest: THttpRequest;
    FResponse: THttpResponse;
  protected
    procedure Execute; override;
  public
    constructor Create(const ATransport: IHttpTransport;
      const ARequest: THttpRequest);
    property Response: THttpResponse read FResponse;
  end;

function TInspectableFpHttpTransport.MapException(
  const AException: Exception; const ARequest: THttpRequest): THttpResponse;
begin
  Result := ExceptionResponse(AException, ARequest, 0);
end;

constructor TExecuteThread.Create(const ATransport: IHttpTransport;
  const ARequest: THttpRequest);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FTransport := ATransport;
  FRequest := CloneHttpRequest(ARequest);
end;

procedure TExecuteThread.Execute;
begin
  FResponse := FTransport.Execute(FRequest);
end;

procedure TFpHttpTransportTests.SetUp;
begin
  inherited SetUp;
  FServer := TLoopbackHttpServer.Create;
end;

procedure TFpHttpTransportTests.TearDown;
begin
  FServer.Free;
  inherited TearDown;
end;

function TFpHttpTransportTests.ExecuteRequest(
  const ARequest: THttpRequest): THttpResponse;
var
  Transport: IHttpTransport;
begin
  Transport := TFpHttpTransport.Create;
  Result := Transport.Execute(ARequest);
end;

function TFpHttpTransportTests.ResponseHeader(
  const AResponse: THttpResponse; const AName: string): string;
var
  Header: THttpHeader;
begin
  Result := '';
  for Header in AResponse.Headers do
    if SameText(Header.Name, AName) then
      Exit(Header.Value);
end;

procedure TFpHttpTransportTests.Get_PreservesStatusHeadersBodyAndRequestHeaders;
var
  Request: THttpRequest;
  Response: THttpResponse;
begin
  Request := BuildHttpGetRequest(FServer.BaseUrl + '/get?name=test', [],
    500, 500);
  SetLength(Request.Headers, 1);
  Request.Headers[0] := HttpHeader('X-Request', 'from-test');

  Response := ExecuteRequest(Request);

  AssertTrue(Response.Completed);
  AssertEquals(Ord(hekNone), Ord(Response.ErrorKind));
  AssertEquals(200, Response.StatusCode);
  AssertEquals('OK', Response.StatusText);
  AssertEquals('Привет', string(Response.Body));
  AssertEquals('received', ResponseHeader(Response, 'X-Reply'));
  AssertEquals('GET', FServer.LastMethod);
  AssertEquals('/get?name=test', FServer.LastTarget);
  AssertEquals('from-test', FServer.LastRequestHeader);
end;

procedure TFpHttpTransportTests.Post_SendsRawUtf8Body;
var
  Request: THttpRequest;
  Response: THttpResponse;
begin
  Request := Default(THttpRequest);
  Request.Method := hmPost;
  Request.Url := FServer.BaseUrl + '/post';
  Request.Body := 'text=Готово';
  Request.ConnectTimeoutMs := 500;
  Request.ReadTimeoutMs := 500;
  Request.AllowRedirects := True;
  SetLength(Request.Headers, 1);
  Request.Headers[0] := HttpHeader('Content-Type',
    'application/x-www-form-urlencoded; charset=utf-8');

  Response := ExecuteRequest(Request);

  AssertTrue(Response.Completed);
  AssertEquals(201, Response.StatusCode);
  AssertEquals('text=Готово', string(Response.Body));
  AssertEquals('POST', FServer.LastMethod);
  AssertEquals('text=Готово', string(FServer.LastBody));
end;

procedure TFpHttpTransportTests.HttpStatuses_AreCompletedTransportResponses;
var
  Response: THttpResponse;
begin
  Response := ExecuteRequest(BuildHttpGetRequest(
    FServer.BaseUrl + '/status/204', [], 500, 500));
  AssertTrue(Response.Completed);
  AssertEquals(204, Response.StatusCode);
  AssertEquals('', string(Response.Body));

  Response := ExecuteRequest(BuildHttpGetRequest(
    FServer.BaseUrl + '/status/400', [], 500, 500));
  AssertTrue(Response.Completed);
  AssertEquals(400, Response.StatusCode);
  AssertEquals('bad request', string(Response.Body));

  Response := ExecuteRequest(BuildHttpGetRequest(
    FServer.BaseUrl + '/status/500', [], 500, 500));
  AssertTrue(Response.Completed);
  AssertEquals(500, Response.StatusCode);
  AssertEquals('server failure', string(Response.Body));
end;

procedure TFpHttpTransportTests.Redirect_RespectsRequestPolicy;
var
  Request: THttpRequest;
  Response: THttpResponse;
begin
  Request := BuildHttpGetRequest(FServer.BaseUrl + '/redirect', [],
    500, 500, False);
  Response := ExecuteRequest(Request);
  AssertTrue(Response.Completed);
  AssertEquals(302, Response.StatusCode);

  Request.AllowRedirects := True;
  Response := ExecuteRequest(Request);
  AssertTrue(Response.Completed);
  AssertEquals(200, Response.StatusCode);
  AssertEquals('redirected', string(Response.Body));
end;

procedure TFpHttpTransportTests.ConnectionRefused_ReturnsSafeTransportError;
var
  Request: THttpRequest;
  Response: THttpResponse;
  ClosedPort: Word;
begin
  ClosedPort := FServer.Port;
  FreeAndNil(FServer);
  Request := BuildHttpGetRequest('http://127.0.0.1:' + IntToStr(ClosedPort) +
    '/bot-secret?token=very-secret', [], 1000, 200);

  Response := ExecuteRequest(Request);

  AssertFalse(Response.Completed);
  AssertTrue('A refused connection must be a safe transport error',
    Response.ErrorKind in [hekNetwork, hekTimeout]);
  AssertEquals(0, Response.StatusCode);
  AssertTrue(Pos('very-secret', Response.ErrorMessage) = 0);
  AssertTrue(Pos('bot-secret', Response.ErrorMessage) = 0);
  AssertTrue(Pos(Request.Url, Response.ErrorMessage) = 0);
end;

procedure TFpHttpTransportTests.SocketErrors_AreClassifiedDeterministically;
var
  Request: THttpRequest;
  Response: THttpResponse;
  SocketException: ESocketError;
  Transport: TInspectableFpHttpTransport;

  procedure AssertSocketErrorKind(const ACode: TSocketErrorType;
    const AExpectedKind: THttpErrorKind);
  begin
    SocketException := ESocketError.Create('test socket error');
    SocketException.Code := ACode;
    try
      Response := Transport.MapException(SocketException, Request);
    finally
      SocketException.Free;
    end;
    AssertFalse(Response.Completed);
    AssertEquals(Ord(AExpectedKind), Ord(Response.ErrorKind));
  end;

begin
  Request := BuildHttpGetRequest('http://127.0.0.1/', [], 1000, 200);
  Transport := TInspectableFpHttpTransport.Create;
  try
    AssertSocketErrorKind(seConnectFailed, hekNetwork);
    AssertSocketErrorKind(seConnectTimeout, hekTimeout);
    AssertSocketErrorKind(seIOTimeout, hekTimeout);
  finally
    Transport.Free;
  end;
end;

procedure TFpHttpTransportTests.ReadTimeout_ReturnsTimeoutWithoutSecretData;
var
  Request: THttpRequest;
  Response: THttpResponse;
begin
  FServer.DelayMs := 250;
  Request := BuildHttpGetRequest(FServer.BaseUrl +
    '/slow?token=timeout-secret', [], 500, 50);

  Response := ExecuteRequest(Request);

  AssertFalse(Response.Completed);
  AssertEquals(Ord(hekTimeout), Ord(Response.ErrorKind));
  AssertTrue(Pos('timeout-secret', Response.ErrorMessage) = 0);
  AssertTrue(Pos(Request.Url, Response.ErrorMessage) = 0);
end;

procedure TFpHttpTransportTests.CancelActiveRequest_ReturnsCancelledWithinReadTimeout;
var
  Request: THttpRequest;
  Transport: IHttpTransport;
  Worker: TExecuteThread;
  StartedAt: QWord;
begin
  FServer.DelayMs := 250;
  Request := BuildHttpGetRequest(FServer.BaseUrl + '/slow', [], 500, 500);
  Transport := TFpHttpTransport.Create;
  Worker := TExecuteThread.Create(Transport, Request);
  try
    Worker.Start;
    AssertTrue('Loopback server did not receive the request',
      FServer.WaitForRequestStarted(1000));
    StartedAt := GetTickCount64;
    Transport.Cancel;
    Worker.WaitFor;

    AssertTrue(GetTickCount64 - StartedAt < 750);
    AssertFalse(Worker.Response.Completed);
    AssertEquals(Ord(hekCancelled), Ord(Worker.Response.ErrorKind));
  finally
    Worker.Free;
  end;
end;

procedure TFpHttpTransportTests.Transport_CannotBeReused;
var
  Request: THttpRequest;
  FirstResponse, SecondResponse: THttpResponse;
  Transport: IHttpTransport;
begin
  Request := BuildHttpGetRequest(FServer.BaseUrl + '/get', [], 500, 500);
  Transport := TFpHttpTransport.Create;

  FirstResponse := Transport.Execute(Request);
  SecondResponse := Transport.Execute(Request);

  AssertTrue(FirstResponse.Completed);
  AssertFalse(SecondResponse.Completed);
  AssertEquals(Ord(hekProtocol), Ord(SecondResponse.ErrorKind));
end;

procedure TFpHttpTransportTests.Factory_CreatesIndependentTransports;
var
  Factory: IHttpTransportFactory;
  First, Second: IHttpTransport;
begin
  Factory := TFpHttpTransportFactory.Create;
  First := Factory.CreateTransport;
  Second := Factory.CreateTransport;
  AssertTrue(First <> Second);
end;

{$IFDEF TEST_OPENSSL3_LINUX_LOADER}
procedure TFpHttpTransportTests.
  OpenSsl3Loader_PrioritizesVersionThreeSoname;
begin
  AssertEquals('.3', DLLVersions[Low(DLLVersions)]);
end;
{$ENDIF}

initialization
  RegisterTest(TFpHttpTransportTests);

end.
