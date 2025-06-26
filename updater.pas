unit updater;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, httpsend, ssl_openssl3, fpjson, jsonparser;

type
  THttpMethods = (httpGet, httpPost);

  { TUpdater }

  TUpdater = class
  private
    FUrl: string;
    FMethod: THttpMethods;
    HTTPSender: THTTPSend;
    function CompareVersions(const CurrentVersion, LastVersion: string): boolean;
    function GetLastVersion(const Json: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    property URL: string read FUrl write FUrl;
    property Method: THttpMethods read FMethod write FMethod;
    function NewVersionAvailable(const CurrentVersion: string;
      out LastVersion: string): boolean;

  end;

implementation

{ TUpdater }

function TUpdater.CompareVersions(const CurrentVersion, LastVersion: string): boolean;
var
  CurrentList, LastList: TStringList;
  i: integer;
begin
  Result := False;
  if string.IsNullOrEmpty(CurrentVersion) or string.IsNullOrEmpty(LastVersion) then exit;
  CurrentList := TStringList.Create;
  LastList := TStringList.Create;
  try
    CurrentList.AddDelimitedText(CurrentVersion, '.', True);
    LastList.AddDelimitedText(LastVersion, '.', True);
    try
      for i := 0 to 2 do
      begin
        if StrToInt(CurrentList[i]) < StrToInt(LastList[i]) then
        begin
          Result := True;
          break;
        end
        else if StrToInt(CurrentList[i]) > StrToInt(LastList[i]) then
        begin
          Result := False;
          break;
        end;
      end;
    except
    end;
  finally
    CurrentList.Free;
    LastList.Free;
  end;
end;

function TUpdater.GetLastVersion(const Json: string): string;
var
  JsonData: TJSONData;
begin
  Result := '';
  try
    JsonData := GetJSON(Json);
    Result := JsonData.FindPath('name').AsString;
  finally
    FreeAndNil(JsonData);
  end;
end;


constructor TUpdater.Create;
begin
  HTTPSender := THTTPSend.Create;
  Method := httpGet;
  URL := 'https://codeberg.org/api/v1/repos/syutkin/entime/releases/latest';
end;

destructor TUpdater.Destroy;
begin
  HTTPSender.Free;
  inherited Destroy;
end;

function TUpdater.NewVersionAvailable(const CurrentVersion: string;
  out LastVersion: string): boolean;
var
  sMethod, Json: string;
  HTTPGetResult: boolean;
begin
  sMethod := 'GET';
  Json := '';
  LastVersion := '';
  Result := False;
  if Method = httpPost then
  begin
    sMethod := 'POST';
    HTTPSender.MimeType := 'application/x-www-form-urlencoded';
  end;

  try
    HTTPGetResult := HTTPSender.HTTPMethod(sMethod, Url);
    if HTTPGetResult and (HTTPSender.ResultCode >= 100) and
      (HTTPSender.ResultCode <= 299) then
    begin
      SetLength(Json, HTTPSender.Document.Size);
      HTTPSender.Document.Read(Json[1], Length(Json));
      // Parse Json
      LastVersion := GetLastVersion(Json);
      // Compare version
      Result := CompareVersions(CurrentVersion, LastVersion);
    end;
  except
    Result := False;
  end;
end;

end.
