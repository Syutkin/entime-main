unit LoopbackHttpServer;

{$mode ObjFPC}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, Sockets, SSockets;

type
  TLoopbackHttpServer = class(TThread)
  private
    FServer: TInetServer;
    FStarted: Boolean;
    FPort: Word;
    FDelayMs: Cardinal;
    FRequestStarted: PRTLEvent;
    FRequestReceived: LongInt;
    FLastMethod: string;
    FLastTarget: string;
    FLastBody: RawByteString;
    FLastRequestHeader: string;
    procedure HandleConnection(Sender: TObject; AStream: TSocketStream);
    function ReadLine(AStream: TStream): RawByteString;
    procedure SendResponse(AStream: TStream; const ACode: Integer;
      const ACodeText, ABody: RawByteString; const AExtraHeader: string = '');
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    function BaseUrl: string;
    function WaitForRequestStarted(const ATimeoutMs: Cardinal): Boolean;
    property DelayMs: Cardinal read FDelayMs write FDelayMs;
    property Port: Word read FPort;
    property LastMethod: string read FLastMethod;
    property LastTarget: string read FLastTarget;
    property LastBody: RawByteString read FLastBody;
    property LastRequestHeader: string read FLastRequestHeader;
  end;

implementation

function HeaderValue(const AHeaders: TStrings; const AName: string): string;
var
  HeaderLine: string;
  Index: Integer;
  SeparatorPosition: SizeInt;
begin
  Result := '';
  for Index := 0 to AHeaders.Count - 1 do
  begin
    HeaderLine := AHeaders[Index];
    SeparatorPosition := Pos(':', HeaderLine);
    if (SeparatorPosition > 0) and SameText(
      Copy(HeaderLine, 1, SeparatorPosition - 1), AName) then
      Exit(Trim(Copy(HeaderLine, SeparatorPosition + 1, MaxInt)));
  end;
end;

constructor TLoopbackHttpServer.Create;
var
  Address: TInetSockAddr;
  AddressLength: TSockLen;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FDelayMs := 250;
  FRequestStarted := RTLEventCreate;
  FServer := TInetServer.Create('127.0.0.1', 0);
  try
    FServer.ReuseAddress := True;
    FServer.MaxConnections := -1;
    FServer.OnConnect := @HandleConnection;
    FServer.Bind;
    AddressLength := SizeOf(Address);
    if fpGetSockName(FServer.Socket, @Address, @AddressLength) <> 0 then
      raise ESocketError.Create(seBindFailed, ['loopback']);
    FPort := ShortNetToHost(Address.sin_port);
    FServer.Listen;
    Start;
    FStarted := True;
  except
    FreeAndNil(FServer);
    RTLEventDestroy(FRequestStarted);
    FRequestStarted := nil;
    raise;
  end;
end;

destructor TLoopbackHttpServer.Destroy;
var
  WakeSocket: TInetSocket;
begin
  if FStarted and Assigned(FServer) then
  begin
    Terminate;
    FServer.StopAccepting(False);
    WakeSocket := TInetSocket.Create('127.0.0.1', FPort);
    try
      try
        WakeSocket.Connect;
      except
        on ESocketError do ;
      end;
    finally
      WakeSocket.Free;
    end;
  end;
  if FStarted then
    WaitFor;
  FreeAndNil(FServer);
  if Assigned(FRequestStarted) then
    RTLEventDestroy(FRequestStarted);
  inherited Destroy;
end;

procedure TLoopbackHttpServer.Execute;
begin
  try
    FServer.StartAccepting;
  except
    if not Terminated then
      raise;
  end;
end;

function TLoopbackHttpServer.ReadLine(AStream: TStream): RawByteString;
var
  Character: AnsiChar;
begin
  Result := '';
  repeat
    if AStream.Read(Character, 1) <> 1 then
      Exit;
    if Character = #10 then
      Exit;
    if Character <> #13 then
      Result := Result + Character;
  until False;
end;

procedure TLoopbackHttpServer.SendResponse(AStream: TStream;
  const ACode: Integer; const ACodeText, ABody: RawByteString;
  const AExtraHeader: string);
var
  Header: RawByteString;
begin
  Header := 'HTTP/1.1 ' + RawByteString(IntToStr(ACode)) + ' ' + ACodeText +
    #13#10 + 'Connection: close'#13#10 +
    'Content-Length: ' + RawByteString(IntToStr(Length(ABody))) + #13#10 +
    'Content-Type: text/plain; charset=utf-8'#13#10;
  if AExtraHeader <> '' then
    Header := Header + RawByteString(AExtraHeader) + #13#10;
  Header := Header + #13#10;
  AStream.WriteBuffer(Header[1], Length(Header));
  if Length(ABody) > 0 then
    AStream.WriteBuffer(ABody[1], Length(ABody));
end;

procedure TLoopbackHttpServer.HandleConnection(Sender: TObject;
  AStream: TSocketStream);
var
  BodyLength: Integer;
  FirstLine: RawByteString;
  HeaderLine: RawByteString;
  Headers: TStringList;
  MethodEnd: SizeInt;
  TargetEnd: SizeInt;
  Path: string;
  Remaining: Integer;
  ReadCount: Integer;
begin
  AStream.IOTimeout := 2000;
  {$IFDEF Linux}
  AStream.WriteFlags := MSG_NOSIGNAL;
  {$ENDIF}
  Headers := TStringList.Create;
  try
    FirstLine := ReadLine(AStream);
    MethodEnd := Pos(' ', FirstLine);
    TargetEnd := Pos(' HTTP/', FirstLine);
    if (MethodEnd <= 0) or (TargetEnd <= MethodEnd) then
      Exit;
    FLastMethod := string(Copy(FirstLine, 1, MethodEnd - 1));
    FLastTarget := string(Copy(FirstLine, MethodEnd + 1,
      TargetEnd - MethodEnd - 1));

    repeat
      HeaderLine := ReadLine(AStream);
      if HeaderLine <> '' then
        Headers.Add(string(HeaderLine));
    until HeaderLine = '';
    FLastRequestHeader := HeaderValue(Headers, 'X-Request');

    BodyLength := StrToIntDef(HeaderValue(Headers, 'Content-Length'), 0);
    SetLength(FLastBody, BodyLength);
    Remaining := BodyLength;
    while Remaining > 0 do
    begin
      ReadCount := AStream.Read(FLastBody[BodyLength - Remaining + 1], Remaining);
      if ReadCount <= 0 then
        Break;
      Dec(Remaining, ReadCount);
    end;

    Path := FLastTarget;
    if Pos('?', Path) > 0 then
      Path := Copy(Path, 1, Pos('?', Path) - 1);
    InterlockedExchange(FRequestReceived, 1);
    RTLEventSetEvent(FRequestStarted);

    if Path = '/get' then
      SendResponse(AStream, 200, 'OK', 'Привет', 'X-Reply: received')
    else if Path = '/post' then
      SendResponse(AStream, 201, 'Created', FLastBody)
    else if Path = '/status/204' then
      SendResponse(AStream, 204, 'No Content', '')
    else if Path = '/status/400' then
      SendResponse(AStream, 400, 'Bad Request', 'bad request')
    else if Path = '/status/500' then
      SendResponse(AStream, 500, 'Server Error', 'server failure')
    else if Path = '/redirect' then
      SendResponse(AStream, 302, 'Found', '', 'Location: /target')
    else if Path = '/target' then
      SendResponse(AStream, 200, 'OK', 'redirected')
    else if Path = '/slow' then
    begin
      Sleep(FDelayMs);
      SendResponse(AStream, 200, 'OK', 'slow');
    end
    else
      SendResponse(AStream, 404, 'Not Found', 'missing');
  finally
    Headers.Free;
    AStream.Free;
  end;
end;

function TLoopbackHttpServer.BaseUrl: string;
begin
  Result := 'http://127.0.0.1:' + IntToStr(FPort);
end;

function TLoopbackHttpServer.WaitForRequestStarted(
  const ATimeoutMs: Cardinal): Boolean;
begin
  RTLEventWaitFor(FRequestStarted, ATimeoutMs);
  Result := InterlockedCompareExchange(FRequestReceived, 0, 0) <> 0;
end;

end.
