unit LedPanelClient;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, HttpTransport, CompetitionFinishService;

const
  LED_PANEL_CONNECT_TIMEOUT_MS = 1000;
  LED_PANEL_READ_TIMEOUT_MS = 2000;

type
  TLedPanelClient = record
  private
    class function TryBuildRequest(const AAddress: string;
      const AFields: THttpFormFields; out ARequest: THttpRequest): boolean; static;
  public
    class function TryBuildEndpoint(const AAddress: string;
      out AEndpoint: string): boolean; static;
    class function TryBuildFinishRequest(const AResult: TFinishResult;
      const AAddress: string; out ARequest: THttpRequest): boolean; static;
    class function TryBuildTestRequest(
      const AAddress, ASingleLine, AUpperLine, ABottomLine: string;
      out ARequest: THttpRequest): boolean; static;
    class function Send(const ARequest: THttpRequest;
      const ATransport: IHttpTransport): TFinishNotificationOutcome; static;
  end;

implementation

uses
  i18n, ResultFormatting;

function TryParsePort(const AText: string): boolean;
var
  Port: integer;
begin
  Result := TryStrToInt(AText, Port) and (Port >= 1) and (Port <= 65535);
end;

function ContainsInvalidAddressCharacter(const AValue: string): boolean;
var
  Character: char;
begin
  for Character in AValue do
    if (Character <= ' ') or (Character in ['/', '\', '?', '#', '@']) then
      Exit(True);
  Result := False;
end;

class function TLedPanelClient.TryBuildEndpoint(const AAddress: string;
  out AEndpoint: string): boolean;
var
  Address, Host, PortText: string;
  ClosingBracket, ColonCount, ColonPosition, Index: integer;
begin
  AEndpoint := '';
  Address := Trim(AAddress);
  if (Address = '') or ContainsInvalidAddressCharacter(Address) or
    (Pos('://', Address) > 0) then
    Exit(False);

  if Address[1] = '[' then
  begin
    ClosingBracket := Pos(']', Address);
    if (ClosingBracket <= 2) or
      (Pos(']', Copy(Address, ClosingBracket + 1, MaxInt)) > 0) then
      Exit(False);
    Host := Copy(Address, 1, ClosingBracket);
    PortText := Copy(Address, ClosingBracket + 1, MaxInt);
    if PortText <> '' then
    begin
      if PortText[1] <> ':' then
        Exit(False);
      Delete(PortText, 1, 1);
      if not TryParsePort(PortText) then
        Exit(False);
    end;
  end
  else
  begin
    ColonCount := 0;
    ColonPosition := 0;
    for Index := 1 to Length(Address) do
      if Address[Index] = ':' then
      begin
        Inc(ColonCount);
        ColonPosition := Index;
      end;
    if ColonCount > 1 then
      Exit(False);
    if ColonCount = 1 then
    begin
      Host := Copy(Address, 1, ColonPosition - 1);
      PortText := Copy(Address, ColonPosition + 1, MaxInt);
      if (Host = '') or not TryParsePort(PortText) then
        Exit(False);
    end
    else
      Host := Address;
  end;

  if Host = '' then
    Exit(False);
  AEndpoint := 'http://' + Address + '/post';
  Result := True;
end;

class function TLedPanelClient.TryBuildRequest(const AAddress: string;
  const AFields: THttpFormFields; out ARequest: THttpRequest): boolean;
var
  Endpoint: string;
begin
  ARequest := Default(THttpRequest);
  Result := TryBuildEndpoint(AAddress, Endpoint);
  if not Result then
    Exit;
  ARequest := BuildHttpFormPostRequest(Endpoint, AFields,
    LED_PANEL_CONNECT_TIMEOUT_MS, LED_PANEL_READ_TIMEOUT_MS);
end;

class function TLedPanelClient.TryBuildFinishRequest(const AResult: TFinishResult;
  const AAddress: string; out ARequest: THttpRequest): boolean;
var
  BottomLine, UpperLine: string;
  Fields: THttpFormFields;
begin
  Fields := nil;
  if AResult.Place = 1 then
  begin
    if AResult.PreviousLeaderNumber > 0 then
    begin
      UpperLine := FormatLEDLine(AResult.ParticipantNumber,
        AResult.ResultValue, AResult.Difference, AResult.Place, '-');
      BottomLine := FormatLEDLine(AResult.PreviousLeaderNumber,
        AResult.PreviousLeaderResult, '', 2);
    end
    else
    begin
      UpperLine := FormatLEDLine(AResult.ParticipantNumber,
        AResult.ResultValue, '', AResult.Place);
      BottomLine := '';
    end;
  end
  else
  begin
    UpperLine := FormatLEDLine(AResult.PreviousLeaderNumber,
      AResult.PreviousLeaderResult, '', 1);
    BottomLine := FormatLEDLine(AResult.ParticipantNumber,
      AResult.ResultValue, AResult.Difference, AResult.Place);
  end;
  SetLength(Fields, 2);
  Fields[0] := HttpFormField('upperline', UpperLine);
  Fields[1] := HttpFormField('bottomline', BottomLine);
  Result := TryBuildRequest(AAddress, Fields, ARequest);
end;

class function TLedPanelClient.TryBuildTestRequest(
  const AAddress, ASingleLine, AUpperLine, ABottomLine: string;
  out ARequest: THttpRequest): boolean;
var
  Fields: THttpFormFields;
begin
  Fields := nil;
  if ASingleLine <> '' then
  begin
    SetLength(Fields, 1);
    Fields[0] := HttpFormField('singleline', ASingleLine);
  end
  else
  begin
    SetLength(Fields, 2);
    Fields[0] := HttpFormField('upperline', AUpperLine);
    Fields[1] := HttpFormField('bottomline', ABottomLine);
  end;
  Result := TryBuildRequest(AAddress, Fields, ARequest);
end;

class function TLedPanelClient.Send(const ARequest: THttpRequest;
  const ATransport: IHttpTransport): TFinishNotificationOutcome;
var
  Index: integer;
  Response: THttpResponse;
begin
  Result := Default(TFinishNotificationOutcome);
  if ARequest.Body <> '' then
  begin
    Result.RequestParameterCount := 1;
    for Index := 1 to Length(ARequest.Body) do
      if ARequest.Body[Index] = '&' then
        Inc(Result.RequestParameterCount);
  end;
  if not Assigned(ATransport) then
  begin
    Result.SafeErrorMessage := rsHTTPRequestNotStarted;
    Exit;
  end;
  try
    Response := ATransport.Execute(ARequest);
    Result.ResponseStatusCode := Response.StatusCode;
    Result.ResponseStatusText := Response.StatusText;
    Result.ResponseHeaderCount := Length(Response.Headers);
    Result.ResponseSize := Length(Response.Body);
    Result.TransportErrorKind := Response.ErrorKind;
    Result.Success := Response.Completed and (Response.ErrorKind = hekNone) and
      IsHttpSuccessStatus(Response.StatusCode);
    if Result.Success then
      Exit;
    if Response.ErrorKind <> hekNone then
      Result.SafeErrorMessage := Response.ErrorMessage
    else
      Result.SafeErrorMessage :=
        IntToStr(Response.StatusCode) + ' ' + Response.StatusText;
    Result.SafeErrorMessage :=
      StringReplace(Result.SafeErrorMessage, ARequest.Url, '[redacted]',
      [rfReplaceAll, rfIgnoreCase]);
    if Result.SafeErrorMessage = '' then
      Result.SafeErrorMessage := rsHTTPRequestNotStarted;
  except
    on E: Exception do
      Result.SafeErrorMessage :=
        StringReplace(E.Message, ARequest.Url, '[redacted]',
        [rfReplaceAll, rfIgnoreCase]);
  end;
end;

end.
