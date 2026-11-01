unit FpHttpTransport;

{$mode ObjFPC}{$H+}

{ Stock FPC 3.2.2 OpenSSL bindings can work with the OpenSSL 3 ABI, but their
  dynamic loader does not know the OpenSSL 3 filenames used by Win64 and Linux
  x86_64. Enable the compatibility shim only for that compiler version and
  those validated targets. Newer FPC versions provide this lookup themselves. }
{$IF FPC_FULLVERSION = 30202}
{$IFDEF WIN64}
    {$DEFINE CONFIGURE_OPENSSL3_RUNTIME}
{$ENDIF}
{$IFDEF LINUX}
    {$IFDEF CPUX86_64}
      {$DEFINE CONFIGURE_OPENSSL3_RUNTIME}
      {$DEFINE CONFIGURE_OPENSSL3_LINUX}
    {$ENDIF}
{$ENDIF}
{$ENDIF}

interface

uses
  Classes, SysUtils, FpHttpClient, HttpTransport;

type
  TFpHttpTransport = class(TInterfacedObject, IHttpTransport)
  private
    FClient: TFPHTTPClient;
    FStateLock: TRTLCriticalSection;
    FUsed: boolean;
    FCancelled: boolean;
    function IsCancelled: boolean;
    function TryBeginExecute(out AResponse: THttpResponse): boolean;
    function ValidateRequest(const ARequest: THttpRequest;
      out AResponse: THttpResponse): boolean;
    procedure ConfigureClient(const ARequest: THttpRequest);
    procedure CopyResponseHeaders(out AHeaders: THttpHeaders);
  protected
    function ExceptionResponse(const AException: Exception;
      const ARequest: THttpRequest; const AElapsedMs: QWord): THttpResponse;
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(const ARequest: THttpRequest): THttpResponse;
    procedure Cancel;
  end;

  TFpHttpTransportFactory = class(TInterfacedObject, IHttpTransportFactory)
  public
    function CreateTransport: IHttpTransport;
  end;

implementation

uses
  SSockets, OpenSSLSockets
  {$IFDEF CONFIGURE_OPENSSL3_RUNTIME}, OpenSSL{$ENDIF};

{$IFDEF CONFIGURE_OPENSSL3_RUNTIME}
procedure ConfigureOpenSsl3Runtime;
{$IFDEF CONFIGURE_OPENSSL3_LINUX}
var
  CandidateIndex: Integer;
  VersionIndex: Integer;
{$ENDIF}
begin
  { Library names must be configured before OpenSSL resolves and caches its
    dynamic-library handles. If another subsystem has already loaded OpenSSL,
    changing these variables can no longer affect the active runtime. }
  if IsSSLLoaded then
    Exit;

  {$IFDEF CONFIGURE_OPENSSL3_LINUX}
  { Move the .3 soname to the front while retaining the existing unversioned
    and legacy fallbacks. When .3 is absent from the fixed-size FPC array, the
    oldest fallback is discarded to make room for it. LoadLib will therefore
    try libssl.so.3 and libcrypto.so.3 first. }
  CandidateIndex := -1;
  for VersionIndex := Low(DLLVersions) to High(DLLVersions) do
    if DLLVersions[VersionIndex] = '.3' then
    begin
      CandidateIndex := VersionIndex;
      Break;
    end;
  if CandidateIndex = Low(DLLVersions) then
    Exit;
  if CandidateIndex < 0 then
    CandidateIndex := High(DLLVersions);
  for VersionIndex := CandidateIndex downto Low(DLLVersions) + 1 do
    DLLVersions[VersionIndex] := DLLVersions[VersionIndex - 1];
  DLLVersions[Low(DLLVersions)] := '.3';
  {$ELSE}
  { Replace every Win64 fallback alias so the loader consistently uses the
    bundled OpenSSL 3 pair placed next to Entime.exe. This also prevents a
    machine-wide OpenSSL 1.1 installation from being selected accidentally. }
  DLLSSLName := 'libssl-3-x64.dll';
  DLLSSLName2 := DLLSSLName;
  DLLSSLName3 := DLLSSLName;
  DLLUtilName := 'libcrypto-3-x64.dll';
  DLLUtilName2 := DLLUtilName;
  {$ENDIF}
end;
{$ENDIF}

function ErrorResponse(const AKind: THttpErrorKind;
  const AMessage: string): THttpResponse;
begin
  Result := Default(THttpResponse);
  Result.ErrorKind := AKind;
  Result.ErrorMessage := AMessage;
end;

function HttpMethodName(const AMethod: THttpMethod): string;
begin
  case AMethod of
    hmGet: Result := 'GET';
    hmPost: Result := 'POST';
  end;
end;

constructor TFpHttpTransport.Create;
begin
  inherited Create;
  InitCriticalSection(FStateLock);
  FClient := TFPHTTPClient.Create(nil);
end;

destructor TFpHttpTransport.Destroy;
begin
  Cancel;
  FreeAndNil(FClient);
  DoneCriticalSection(FStateLock);
  inherited Destroy;
end;

function TFpHttpTransport.IsCancelled: boolean;
begin
  EnterCriticalSection(FStateLock);
  try
    Result := FCancelled;
  finally
    LeaveCriticalSection(FStateLock);
  end;
end;

function TFpHttpTransport.TryBeginExecute(out AResponse: THttpResponse): boolean;
begin
  EnterCriticalSection(FStateLock);
  try
    if FCancelled then
    begin
      AResponse := ErrorResponse(hekCancelled, 'HTTP operation was cancelled');
      Exit(False);
    end;
    if FUsed then
    begin
      AResponse := ErrorResponse(hekProtocol,
        'HTTP transport instances can execute only one request');
      Exit(False);
    end;
    FUsed := True;
    Result := True;
  finally
    LeaveCriticalSection(FStateLock);
  end;
end;

function TFpHttpTransport.ValidateRequest(const ARequest: THttpRequest;
  out AResponse: THttpResponse): boolean;
var
  LowerUrl: string;
begin
  Result := False;
  if (ARequest.ConnectTimeoutMs <= 0) or (ARequest.ReadTimeoutMs <= 0) then
  begin
    AResponse := ErrorResponse(hekProtocol,
      'HTTP timeouts must be positive and finite');
    Exit;
  end;
  LowerUrl := LowerCase(ARequest.Url);
  if (Copy(LowerUrl, 1, 7) <> 'http://') and (Copy(LowerUrl, 1, 8) <> 'https://') then
  begin
    AResponse := ErrorResponse(hekProtocol, 'Unsupported HTTP protocol');
    Exit;
  end;
  Result := True;
end;

procedure TFpHttpTransport.ConfigureClient(const ARequest: THttpRequest);
var
  Header: THttpHeader;
begin
  FClient.ConnectTimeout := ARequest.ConnectTimeoutMs;
  FClient.IOTimeout := ARequest.ReadTimeoutMs;
  FClient.AllowRedirect := ARequest.AllowRedirects;
  FClient.RequestHeaders.Clear;
  for Header in ARequest.Headers do
    FClient.AddHeader(Header.Name, Header.Value);
end;

procedure TFpHttpTransport.CopyResponseHeaders(out AHeaders: THttpHeaders);
var
  HeaderLine: string;
  HeaderIndex: integer;
  SeparatorPosition: SizeInt;
begin
  AHeaders := nil;
  for HeaderIndex := 0 to FClient.ResponseHeaders.Count - 1 do
  begin
    HeaderLine := FClient.ResponseHeaders[HeaderIndex];
    SeparatorPosition := Pos(':', HeaderLine);
    if SeparatorPosition <= 0 then
      Continue;
    SetLength(AHeaders, Length(AHeaders) + 1);
    AHeaders[High(AHeaders)] :=
      HttpHeader(Trim(Copy(HeaderLine, 1, SeparatorPosition - 1)),
      Trim(Copy(HeaderLine, SeparatorPosition + 1, MaxInt)));
  end;
end;

function TFpHttpTransport.ExceptionResponse(const AException: Exception;
  const ARequest: THttpRequest; const AElapsedMs: QWord): THttpResponse;
var
  SocketException: ESocketError;
  TimeoutThreshold: QWord;
begin
  if IsCancelled then
    Exit(ErrorResponse(hekCancelled, 'HTTP operation was cancelled'));

  if AException is ESocketError then
  begin
    SocketException := ESocketError(AException);
    if SocketException.Code in [seConnectTimeout, seIOTimeout] then
      Exit(ErrorResponse(hekTimeout, 'HTTP request timed out'));
    Exit(ErrorResponse(hekNetwork, 'HTTP network operation failed'));
  end;

  TimeoutThreshold := QWord(ARequest.ReadTimeoutMs) * 4 div 5;
  if (AException is EHTTPClient) and (FClient.ResponseStatusCode = 0) and
    (AElapsedMs >= TimeoutThreshold) then
    Exit(ErrorResponse(hekTimeout, 'HTTP request timed out'));

  if (AException is EHTTPClient) and (FClient.ResponseStatusCode = 0) then
    Exit(ErrorResponse(hekNetwork, 'HTTP network operation failed'));

  Result := ErrorResponse(hekProtocol, 'HTTP protocol operation failed');
end;

function TFpHttpTransport.Execute(const ARequest: THttpRequest): THttpResponse;
var
  BodyStream: TRawByteStringStream;
  ResponseStream: TMemoryStream;
  StartedAt: QWord;
begin
  Result := Default(THttpResponse);
  if not TryBeginExecute(Result) then
    Exit;
  if not ValidateRequest(ARequest, Result) then
    Exit;

  BodyStream := nil;
  ResponseStream := TMemoryStream.Create;
  try
    ConfigureClient(ARequest);
    if ARequest.Method = hmPost then
    begin
      BodyStream := TRawByteStringStream.Create(ARequest.Body);
      FClient.RequestBody := BodyStream;
    end;

    StartedAt := GetTickCount64;
    try
      FClient.HTTPMethod(HttpMethodName(ARequest.Method), ARequest.Url,
        ResponseStream, []);
      if IsCancelled then
        Exit(ErrorResponse(hekCancelled, 'HTTP operation was cancelled'));

      Result := Default(THttpResponse);
      Result.Completed := True;
      Result.StatusCode := FClient.ResponseStatusCode;
      Result.StatusText := FClient.ResponseStatusText;
      CopyResponseHeaders(Result.Headers);
      SetLength(Result.Body, ResponseStream.Size);
      if ResponseStream.Size > 0 then
      begin
        ResponseStream.Position := 0;
        ResponseStream.ReadBuffer(Result.Body[1], ResponseStream.Size);
      end;
    except
      on E: Exception do
        Result := ExceptionResponse(E, ARequest, GetTickCount64 - StartedAt);
    end;
  finally
    FClient.RequestBody := nil;
    BodyStream.Free;
    ResponseStream.Free;
  end;
end;

procedure TFpHttpTransport.Cancel;
begin
  { TFPHTTPClient.Terminate sets a flag and cannot guarantee immediate
    interruption of a socket read. Finite request timeouts bound the wait. }
  EnterCriticalSection(FStateLock);
  try
    FCancelled := True;
    if Assigned(FClient) then
      FClient.Terminate;
  finally
    LeaveCriticalSection(FStateLock);
  end;
end;

function TFpHttpTransportFactory.CreateTransport: IHttpTransport;
begin
  Result := TFpHttpTransport.Create;
end;

{$IFDEF CONFIGURE_OPENSSL3_RUNTIME}
initialization
  ConfigureOpenSsl3Runtime;
{$ENDIF}

end.
