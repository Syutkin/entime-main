unit updater;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, httpsend, ssl_openssl3, fpjson, jsonparser;

const
  UPDATE_HTTP_TIMEOUT_MS = 5000;

type
  THttpMethods = (httpGet, httpPost);

  TUpdateCheckStatus = (
    ucsUpdateAvailable,
    ucsUpToDate,
    ucsFailed,
    ucsCancelled
  );

  TUpdateCheckMode = (
    ucmAutomatic,
    ucmManual
  );

  TUpdateCheckNotification = (
    ucnNone,
    ucnUpdateAvailable,
    ucnUpToDate,
    ucnFailure
  );

  TUpdateCheckResult = record
    Status: TUpdateCheckStatus;
    LastVersion: string;
    ErrorMessage: string;
  end;

  IUpdateChecker = interface
    ['{B77162FC-E3E9-4719-913D-04C6C17F7BC0}']
    function CheckForUpdates(
      const ACurrentVersion: string): TUpdateCheckResult;
    procedure Cancel;
  end;

  TUpdateCheckerFactory = function: IUpdateChecker;
  TUpdateCheckCompletedEvent = procedure(Sender: TObject;
    AMode: TUpdateCheckMode; const AResult: TUpdateCheckResult) of object;

  { TUpdater }

  TUpdater = class(TInterfacedObject, IUpdateChecker)
  private
    FUrl: string;
    FMethod: THttpMethods;
    HTTPSender: THTTPSend;
    function GetLastVersion(const Json: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    property URL: string read FUrl write FUrl;
    property Method: THttpMethods read FMethod write FMethod;
    function CheckForUpdates(
      const ACurrentVersion: string): TUpdateCheckResult;
    procedure Cancel;
  end;

  { TUpdateCheckThread }

  TUpdateCheckThread = class(TThread)
  private
    FChecker: IUpdateChecker;
    FCurrentVersion: string;
    FResult: TUpdateCheckResult;
    FOnFinished: TThreadMethod;
  protected
    procedure Execute; override;
  public
    constructor Create(const AChecker: IUpdateChecker;
      const ACurrentVersion: string; AOnFinished: TThreadMethod);
    procedure Cancel;
    property CheckResult: TUpdateCheckResult read FResult;
  end;

  { TUpdateCheckController }

  TUpdateCheckController = class
  private
    FCheckerFactory: TUpdateCheckerFactory;
    FMode: TUpdateCheckMode;
    FOnCompleted: TUpdateCheckCompletedEvent;
    FWorker: TUpdateCheckThread;
    procedure WorkerFinished;
    function Start(const ACurrentVersion: string;
      AMode: TUpdateCheckMode): boolean;
  public
    constructor Create(ACheckerFactory: TUpdateCheckerFactory;
      AOnCompleted: TUpdateCheckCompletedEvent);
    destructor Destroy; override;
    function StartAutomatic(const ACurrentVersion: string;
      AEnabled: boolean; AIntervalInDays: integer;
      ALastCheck, ANow: TDateTime): boolean;
    function StartManual(const ACurrentVersion: string): boolean;
    procedure Cancel;
    function Busy: boolean;
  end;

function CreateDefaultUpdateChecker: IUpdateChecker;
function IsAutomaticUpdateCheckDue(AEnabled: boolean;
  AIntervalInDays: integer; ALastCheck, ANow: TDateTime): boolean;
function IsNewerVersion(const ACurrentVersion, ALastVersion: string): boolean;
function UpdateCheckSucceeded(AStatus: TUpdateCheckStatus): boolean;
function UpdateCheckNotification(AMode: TUpdateCheckMode;
  AStatus: TUpdateCheckStatus): TUpdateCheckNotification;

implementation

function FailedResult(const AMessage: string): TUpdateCheckResult;
begin
  Result.Status := ucsFailed;
  Result.LastVersion := '';
  Result.ErrorMessage := AMessage;
end;

function TryParseVersion(const AVersion: string;
  out AMajor, AMinor, APatch: integer): boolean;
var
  parts: TStringList;
begin
  Result := False;
  AMajor := 0;
  AMinor := 0;
  APatch := 0;
  if AVersion = '' then
    Exit;

  parts := TStringList.Create;
  try
    parts.StrictDelimiter := True;
    parts.Delimiter := '.';
    parts.DelimitedText := AVersion;
    // File versions include a fourth build component, while release names
    // contain only major, minor and patch. Compare the shared first three.
    if parts.Count < 3 then
      Exit;
    if not TryStrToInt(parts[0], AMajor) or
      not TryStrToInt(parts[1], AMinor) or
      not TryStrToInt(parts[2], APatch) then
      Exit;
    Result := (AMajor >= 0) and (AMinor >= 0) and (APatch >= 0);
  finally
    parts.Free;
  end;
end;

function IsNewerVersion(const ACurrentVersion,
  ALastVersion: string): boolean;
var
  currentMajor, currentMinor, currentPatch: integer;
  lastMajor, lastMinor, lastPatch: integer;
begin
  Result := False;
  if not TryParseVersion(ACurrentVersion, currentMajor, currentMinor,
    currentPatch) or
    not TryParseVersion(ALastVersion, lastMajor, lastMinor, lastPatch) then
    Exit;

  if lastMajor <> currentMajor then
    Exit(lastMajor > currentMajor);
  if lastMinor <> currentMinor then
    Exit(lastMinor > currentMinor);
  Result := lastPatch > currentPatch;
end;

function IsAutomaticUpdateCheckDue(AEnabled: boolean;
  AIntervalInDays: integer; ALastCheck, ANow: TDateTime): boolean;
begin
  Result := AEnabled and
    ((AIntervalInDays < 0) or
    (IncDay(ALastCheck, AIntervalInDays) < ANow));
end;

function UpdateCheckSucceeded(AStatus: TUpdateCheckStatus): boolean;
begin
  Result := AStatus in [ucsUpdateAvailable, ucsUpToDate];
end;

function UpdateCheckNotification(AMode: TUpdateCheckMode;
  AStatus: TUpdateCheckStatus): TUpdateCheckNotification;
begin
  case AStatus of
    ucsUpdateAvailable:
      Result := ucnUpdateAvailable;
    ucsUpToDate:
      if AMode = ucmManual then
        Result := ucnUpToDate
      else
        Result := ucnNone;
    ucsFailed:
      if AMode = ucmManual then
        Result := ucnFailure
      else
        Result := ucnNone;
    else
      Result := ucnNone;
  end;
end;

function CreateDefaultUpdateChecker: IUpdateChecker;
begin
  Result := TUpdater.Create;
end;

{ TUpdater }

function TUpdater.GetLastVersion(const Json: string): string;
var
  JsonData: TJSONData;
  versionData: TJSONData;
begin
  Result := '';
  JsonData := GetJSON(Json);
  try
    versionData := JsonData.FindPath('name');
    if Assigned(versionData) then
      Result := versionData.AsString;
  finally
    JsonData.Free;
  end;
end;

constructor TUpdater.Create;
begin
  inherited Create;
  HTTPSender := THTTPSend.Create;
  HTTPSender.Timeout := UPDATE_HTTP_TIMEOUT_MS;
  HTTPSender.Sock.ConnectionTimeout := UPDATE_HTTP_TIMEOUT_MS;
  Method := httpGet;
  URL := 'https://codeberg.org/api/v1/repos/syutkin/entime/releases/latest';
end;

destructor TUpdater.Destroy;
begin
  HTTPSender.Free;
  inherited Destroy;
end;

function TUpdater.CheckForUpdates(
  const ACurrentVersion: string): TUpdateCheckResult;
var
  sMethod, Json, lastVersion, errorMessage: string;
  HTTPGetResult: boolean;
begin
  sMethod := 'GET';
  Json := '';
  if Method = httpPost then
  begin
    sMethod := 'POST';
    HTTPSender.MimeType := 'application/x-www-form-urlencoded';
  end;

  try
    HTTPGetResult := HTTPSender.HTTPMethod(sMethod, URL);
    if not HTTPGetResult then
    begin
      errorMessage := HTTPSender.Sock.LastErrorDesc;
      if errorMessage = '' then
        errorMessage := 'Network request failed';
      Exit(FailedResult(errorMessage));
    end;

    if (HTTPSender.ResultCode < 200) or
      (HTTPSender.ResultCode > 299) then
      Exit(FailedResult(Format('HTTP error %d: %s',
        [HTTPSender.ResultCode, HTTPSender.ResultString])));

    SetLength(Json, HTTPSender.Document.Size);
    HTTPSender.Document.Position := 0;
    if Length(Json) > 0 then
      HTTPSender.Document.ReadBuffer(Json[1], Length(Json));

    lastVersion := GetLastVersion(Json);
    if lastVersion = '' then
      Exit(FailedResult('The update server returned no version'));

    Result.LastVersion := lastVersion;
    Result.ErrorMessage := '';
    if IsNewerVersion(ACurrentVersion, lastVersion) then
      Result.Status := ucsUpdateAvailable
    else
      Result.Status := ucsUpToDate;
  except
    on E: Exception do
      Result := FailedResult(E.Message);
  end;
end;

procedure TUpdater.Cancel;
begin
  HTTPSender.Abort;
end;

{ TUpdateCheckThread }

constructor TUpdateCheckThread.Create(const AChecker: IUpdateChecker;
  const ACurrentVersion: string; AOnFinished: TThreadMethod);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FChecker := AChecker;
  FCurrentVersion := ACurrentVersion;
  FOnFinished := AOnFinished;
  FResult.Status := ucsCancelled;
  FResult.LastVersion := '';
  FResult.ErrorMessage := '';
end;

procedure TUpdateCheckThread.Execute;
begin
  try
    if Terminated then
      Exit;
    if not Assigned(FChecker) then
      FResult := FailedResult('Update checker is not configured')
    else
      FResult := FChecker.CheckForUpdates(FCurrentVersion);
  except
    on E: Exception do
      FResult := FailedResult(E.Message);
  end;

  if Terminated then
  begin
    FResult.Status := ucsCancelled;
    FResult.LastVersion := '';
    FResult.ErrorMessage := '';
  end;

  if not Terminated and Assigned(FOnFinished) then
    Queue(FOnFinished);
end;

procedure TUpdateCheckThread.Cancel;
begin
  Terminate;
  if Assigned(FChecker) then
    FChecker.Cancel;
end;

{ TUpdateCheckController }

constructor TUpdateCheckController.Create(
  ACheckerFactory: TUpdateCheckerFactory;
  AOnCompleted: TUpdateCheckCompletedEvent);
begin
  inherited Create;
  FCheckerFactory := ACheckerFactory;
  FOnCompleted := AOnCompleted;
end;

destructor TUpdateCheckController.Destroy;
begin
  Cancel;
  inherited Destroy;
end;

function TUpdateCheckController.Start(const ACurrentVersion: string;
  AMode: TUpdateCheckMode): boolean;
var
  checker: IUpdateChecker;
begin
  Result := False;
  if Busy or not Assigned(FCheckerFactory) then
    Exit;

  checker := FCheckerFactory();
  if not Assigned(checker) then
    Exit;

  FMode := AMode;
  FWorker := TUpdateCheckThread.Create(
    checker, ACurrentVersion, @WorkerFinished);
  try
    FWorker.Start;
    Result := True;
  except
    FreeAndNil(FWorker);
    raise;
  end;
end;

function TUpdateCheckController.StartAutomatic(
  const ACurrentVersion: string; AEnabled: boolean;
  AIntervalInDays: integer; ALastCheck, ANow: TDateTime): boolean;
begin
  if not IsAutomaticUpdateCheckDue(
    AEnabled, AIntervalInDays, ALastCheck, ANow) then
    Exit(False);
  Result := Start(ACurrentVersion, ucmAutomatic);
end;

function TUpdateCheckController.StartManual(
  const ACurrentVersion: string): boolean;
begin
  Result := Start(ACurrentVersion, ucmManual);
end;

procedure TUpdateCheckController.WorkerFinished;
var
  completedWorker: TUpdateCheckThread;
  completedMode: TUpdateCheckMode;
  completedResult: TUpdateCheckResult;
begin
  completedWorker := FWorker;
  if not Assigned(completedWorker) then
    Exit;

  completedWorker.WaitFor;
  completedMode := FMode;
  completedResult := completedWorker.CheckResult;
  FWorker := nil;
  completedWorker.Free;

  if Assigned(FOnCompleted) then
    FOnCompleted(Self, completedMode, completedResult);
end;

procedure TUpdateCheckController.Cancel;
var
  activeWorker: TUpdateCheckThread;
begin
  activeWorker := FWorker;
  if not Assigned(activeWorker) then
    Exit;

  TThread.RemoveQueuedEvents(activeWorker, @WorkerFinished);
  activeWorker.Cancel;
  activeWorker.WaitFor;
  FWorker := nil;
  activeWorker.Free;
end;

function TUpdateCheckController.Busy: boolean;
begin
  Result := Assigned(FWorker);
end;

end.
