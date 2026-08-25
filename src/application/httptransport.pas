unit HttpTransport;

{$mode ObjFPC}{$H+}

interface

type
  THttpMethod = (hmGet, hmPost);

  THttpHeader = record
    Name: string;
    Value: string;
  end;
  THttpHeaders = array of THttpHeader;

  THttpFormField = record
    Name: string;
    Value: string;
  end;
  THttpFormFields = array of THttpFormField;

  THttpErrorKind = (
    hekNone,
    hekCancelled,
    hekTimeout,
    hekNetwork,
    hekProtocol
  );

  THttpRequest = record
    Method: THttpMethod;
    Url: string;
    Headers: THttpHeaders;
    Body: RawByteString;
    ConnectTimeoutMs: Integer;
    ReadTimeoutMs: Integer;
    AllowRedirects: Boolean;
  end;

  THttpResponse = record
    Completed: Boolean;
    StatusCode: Integer;
    StatusText: string;
    Headers: THttpHeaders;
    Body: RawByteString;
    ErrorKind: THttpErrorKind;
    ErrorMessage: string;
  end;

  IHttpTransport = interface
    ['{D8912407-4415-49D4-B470-F17B53F502C0}']
    function Execute(const ARequest: THttpRequest): THttpResponse;
    procedure Cancel;
  end;

  IHttpTransportFactory = interface
    ['{45396500-9D4B-4C26-A791-FF6E732B1571}']
    function CreateTransport: IHttpTransport;
  end;

function HttpHeader(const AName, AValue: string): THttpHeader;
function HttpFormField(const AName, AValue: string): THttpFormField;
function FormUrlEncode(const AValue: string): RawByteString;
function BuildHttpGetRequest(const AUrl: string;
  const AFields: THttpFormFields; const AConnectTimeoutMs,
  AReadTimeoutMs: Integer; const AAllowRedirects: Boolean = True): THttpRequest;
function BuildHttpFormPostRequest(const AUrl: string;
  const AFields: THttpFormFields; const AConnectTimeoutMs,
  AReadTimeoutMs: Integer; const AAllowRedirects: Boolean = True): THttpRequest;
function CloneHttpHeaders(const AHeaders: THttpHeaders): THttpHeaders;
function CloneHttpRequest(const ARequest: THttpRequest): THttpRequest;
function CloneHttpResponse(const AResponse: THttpResponse): THttpResponse;
function IsHttpSuccessStatus(const AStatusCode: Integer): Boolean;

implementation

const
  HEX_DIGITS: array[0..15] of AnsiChar = '0123456789ABCDEF';

function HttpHeader(const AName, AValue: string): THttpHeader;
begin
  Result.Name := AName;
  Result.Value := AValue;
end;

function HttpFormField(const AName, AValue: string): THttpFormField;
begin
  Result.Name := AName;
  Result.Value := AValue;
end;

function IsUnreservedByte(const AValue: Byte): Boolean;
begin
  Result := ((AValue >= Ord('a')) and (AValue <= Ord('z'))) or
    ((AValue >= Ord('A')) and (AValue <= Ord('Z'))) or
    ((AValue >= Ord('0')) and (AValue <= Ord('9'))) or
    (AValue = Ord('-')) or (AValue = Ord('.')) or
    (AValue = Ord('_')) or (AValue = Ord('~'));
end;

function FormUrlEncode(const AValue: string): RawByteString;
var
  Source: RawByteString;
  SourceByte: Byte;
  Index: Integer;
begin
  Source := UTF8Encode(UnicodeString(AValue));
  Result := '';
  for Index := 1 to Length(Source) do
  begin
    SourceByte := Byte(Source[Index]);
    if IsUnreservedByte(SourceByte) then
      Result := Result + AnsiChar(SourceByte)
    else if SourceByte = Ord(' ') then
      Result := Result + '+'
    else
      Result := Result + '%' + HEX_DIGITS[SourceByte shr 4] +
        HEX_DIGITS[SourceByte and $0F];
  end;
end;

function BuildFormBody(const AFields: THttpFormFields): RawByteString;
var
  Index: Integer;
begin
  Result := '';
  for Index := 0 to High(AFields) do
  begin
    if Index > 0 then
      Result := Result + '&';
    Result := Result + FormUrlEncode(AFields[Index].Name) + '=' +
      FormUrlEncode(AFields[Index].Value);
  end;
end;

function AppendQuery(const AUrl: string;
  const AFields: THttpFormFields): string;
var
  BaseUrl: string;
  Fragment: string;
  FragmentPosition: SizeInt;
  Query: RawByteString;
begin
  if Length(AFields) = 0 then
    Exit(AUrl);

  FragmentPosition := Pos('#', AUrl);
  if FragmentPosition > 0 then
  begin
    BaseUrl := Copy(AUrl, 1, FragmentPosition - 1);
    Fragment := Copy(AUrl, FragmentPosition, MaxInt);
  end
  else
  begin
    BaseUrl := AUrl;
    Fragment := '';
  end;

  Query := BuildFormBody(AFields);
  if Pos('?', BaseUrl) = 0 then
    BaseUrl := BaseUrl + '?'
  else if (BaseUrl = '') or not (BaseUrl[Length(BaseUrl)] in ['?', '&']) then
    BaseUrl := BaseUrl + '&';
  Result := BaseUrl + string(Query) + Fragment;
end;

function BuildHttpGetRequest(const AUrl: string;
  const AFields: THttpFormFields; const AConnectTimeoutMs,
  AReadTimeoutMs: Integer; const AAllowRedirects: Boolean): THttpRequest;
begin
  Result := Default(THttpRequest);
  Result.Method := hmGet;
  Result.Url := AppendQuery(AUrl, AFields);
  Result.ConnectTimeoutMs := AConnectTimeoutMs;
  Result.ReadTimeoutMs := AReadTimeoutMs;
  Result.AllowRedirects := AAllowRedirects;
end;

function BuildHttpFormPostRequest(const AUrl: string;
  const AFields: THttpFormFields; const AConnectTimeoutMs,
  AReadTimeoutMs: Integer; const AAllowRedirects: Boolean): THttpRequest;
begin
  Result := Default(THttpRequest);
  Result.Method := hmPost;
  Result.Url := AUrl;
  SetLength(Result.Headers, 1);
  Result.Headers[0] := HttpHeader('Content-Type',
    'application/x-www-form-urlencoded; charset=utf-8');
  Result.Body := BuildFormBody(AFields);
  Result.ConnectTimeoutMs := AConnectTimeoutMs;
  Result.ReadTimeoutMs := AReadTimeoutMs;
  Result.AllowRedirects := AAllowRedirects;
end;

function CloneHttpHeaders(const AHeaders: THttpHeaders): THttpHeaders;
var
  Index: Integer;
begin
  SetLength(Result, Length(AHeaders));
  for Index := 0 to High(AHeaders) do
    Result[Index] := AHeaders[Index];
end;

function CloneHttpRequest(const ARequest: THttpRequest): THttpRequest;
begin
  Result := ARequest;
  Result.Headers := CloneHttpHeaders(ARequest.Headers);
end;

function CloneHttpResponse(const AResponse: THttpResponse): THttpResponse;
begin
  Result := AResponse;
  Result.Headers := CloneHttpHeaders(AResponse.Headers);
end;

function IsHttpSuccessStatus(const AStatusCode: Integer): Boolean;
begin
  Result := (AStatusCode >= 200) and (AStatusCode <= 299);
end;

end.
