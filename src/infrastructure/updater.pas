unit Updater;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpjson, jsonparser, HttpTransport;

const
  UPDATE_HTTP_TIMEOUT_MS = 5000;

type
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
    ReleaseUrl: string;
    ErrorMessage: string;
  end;

  IUpdateChecker = interface
    ['{B77162FC-E3E9-4719-913D-04C6C17F7BC0}']
    function CheckForUpdates(const ACurrentVersion: string): TUpdateCheckResult;
    procedure Cancel;
  end;

  TUpdateCheckerFactory = function: IUpdateChecker;
  TUpdateCheckCompletedEvent = procedure(Sender: TObject;
    AMode: TUpdateCheckMode; const AResult: TUpdateCheckResult) of object;

  { TUpdater }

  TUpdater = class(TInterfacedObject, IUpdateChecker)
  private
    FUrl: string;
    FTransportFactory: IHttpTransportFactory;
    FActiveTransport: IHttpTransport;
    FStateLock: TRTLCriticalSection;
    FCancelled: boolean;
    procedure Initialize(const ATransportFactory: IHttpTransportFactory);
  public
    constructor Create; overload;
    constructor Create(const ATransportFactory: IHttpTransportFactory); overload;
    destructor Destroy; override;
    property URL: string read FUrl write FUrl;
    function CheckForUpdates(const ACurrentVersion: string): TUpdateCheckResult;
    function EvaluateReleaseResponse(
      const ACurrentVersion, AJson: string): TUpdateCheckResult;
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
    function Start(const ACurrentVersion: string; AMode: TUpdateCheckMode): boolean;
  public
    constructor Create(ACheckerFactory: TUpdateCheckerFactory;
      AOnCompleted: TUpdateCheckCompletedEvent);
    destructor Destroy; override;
    function StartAutomatic(const ACurrentVersion: string; AEnabled: boolean;
      AIntervalInDays: integer; ALastCheck, ANow: TDateTime): boolean;
    function StartManual(const ACurrentVersion: string): boolean;
    procedure Cancel;
    function Busy: boolean;
  end;

function CreateDefaultUpdateChecker: IUpdateChecker;
function IsAutomaticUpdateCheckDue(AEnabled: boolean; AIntervalInDays: integer;
  ALastCheck, ANow: TDateTime): boolean;
function IsNewerVersion(const ACurrentVersion, ALastVersion: string): boolean;
function UpdateCheckSucceeded(AStatus: TUpdateCheckStatus): boolean;
function UpdateCheckNotification(AMode: TUpdateCheckMode;
  AStatus: TUpdateCheckStatus): TUpdateCheckNotification;

implementation

uses
  FpHttpTransport;

function FailedResult(const AMessage: string): TUpdateCheckResult;
begin
  Result.Status := ucsFailed;
  Result.LastVersion := '';
  Result.ReleaseUrl := '';
  Result.ErrorMessage := AMessage;
end;

function CancelledResult: TUpdateCheckResult;
begin
  Result.Status := ucsCancelled;
  Result.LastVersion := '';
  Result.ReleaseUrl := '';
  Result.ErrorMessage := '';
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
    if not TryStrToInt(parts[0], AMajor) or not TryStrToInt(parts[1], AMinor) or
      not TryStrToInt(parts[2], APatch) then
      Exit;
    Result := (AMajor >= 0) and (AMinor >= 0) and (APatch >= 0);
  finally
    parts.Free;
  end;
end;

function TryNormalizeReleaseVersion(const ATagName: string;
  out AVersion: string): boolean;
var
  dotCount, index: integer;
  major, minor, patch: integer;
begin
  Result := False;
  AVersion := Trim(ATagName);
  if (Length(AVersion) > 1) and ((AVersion[1] = 'v') or (AVersion[1] = 'V')) then
    Delete(AVersion, 1, 1);

  dotCount := 0;
  for index := 1 to Length(AVersion) do
    if AVersion[index] = '.' then
      Inc(dotCount);
  if dotCount <> 2 then
    Exit;

  Result := TryParseVersion(AVersion, major, minor, patch);
  if not Result then
    AVersion := '';
end;

function IsNewerVersion(const ACurrentVersion, ALastVersion: string): boolean;
var
  currentMajor, currentMinor, currentPatch: integer;
  lastMajor, lastMinor, lastPatch: integer;
begin
  Result := False;
  if not TryParseVersion(ACurrentVersion, currentMajor, currentMinor, currentPatch) or
    not TryParseVersion(ALastVersion, lastMajor, lastMinor, lastPatch) then
    Exit;

  if lastMajor <> currentMajor then
    Exit(lastMajor > currentMajor);
  if lastMinor <> currentMinor then
    Exit(lastMinor > currentMinor);
  Result := lastPatch > currentPatch;
end;

function IsAutomaticUpdateCheckDue(AEnabled: boolean; AIntervalInDays: integer;
  ALastCheck, ANow: TDateTime): boolean;
begin
  Result := AEnabled and ((AIntervalInDays < 0) or
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

function TUpdater.EvaluateReleaseResponse(
  const ACurrentVersion, AJson: string): TUpdateCheckResult;
var
  JsonData, tagData, urlData: TJSONData;
  lastVersion, releaseUrl: string;
  major, minor, patch: integer;
begin
  JsonData := nil;
  try
    try
      JsonData := GetJSON(AJson);
    except
      on E: Exception do
        Exit(FailedResult('The update server returned invalid JSON: ' +
          E.Message));
    end;

    if JsonData.JSONType <> jtObject then
      Exit(FailedResult('The update server response must be a JSON object'));

    tagData := JsonData.FindPath('tag_name');
    if not Assigned(tagData) or (tagData.JSONType <> jtString) then
      Exit(FailedResult(
        'The update server response does not contain a string tag_name'));
    if not TryNormalizeReleaseVersion(tagData.AsString, lastVersion) then
      Exit(FailedResult(
        'The update server returned an invalid tag_name version'));

    urlData := JsonData.FindPath('html_url');
    if not Assigned(urlData) or (urlData.JSONType <> jtString) then
      Exit(FailedResult(
        'The update server response does not contain a string html_url'));
    releaseUrl := Trim(urlData.AsString);
    if releaseUrl = '' then
      Exit(FailedResult('The update server returned an empty html_url'));

    if not TryParseVersion(ACurrentVersion, major, minor, patch) then
      Exit(FailedResult('The current application version is invalid'));

    Result.LastVersion := lastVersion;
    Result.ReleaseUrl := releaseUrl;
    Result.ErrorMessage := '';
    if IsNewerVersion(ACurrentVersion, lastVersion) then
      Result.Status := ucsUpdateAvailable
    else
      Result.Status := ucsUpToDate;
  finally
    JsonData.Free;
  end;
end;

constructor TUpdater.Create;
begin
  inherited Create;
  Initialize(TFpHttpTransportFactory.Create);
end;

constructor TUpdater.Create(const ATransportFactory: IHttpTransportFactory);
begin
  inherited Create;
  Initialize(ATransportFactory);
end;

procedure TUpdater.Initialize(const ATransportFactory: IHttpTransportFactory);
begin
  if not Assigned(ATransportFactory) then
    raise EArgumentNilException.Create('ATransportFactory');
  InitCriticalSection(FStateLock);
  FTransportFactory := ATransportFactory;
  URL := 'https://codeberg.org/api/v1/repos/syutkin/entime/releases/latest';
end;

destructor TUpdater.Destroy;
begin
  Cancel;
  FActiveTransport := nil;
  FTransportFactory := nil;
  DoneCriticalSection(FStateLock);
  inherited Destroy;
end;

function TUpdater.CheckForUpdates(const ACurrentVersion: string): TUpdateCheckResult;
var
  ErrorMessage, Json: string;
  AlreadyActive: boolean;
  Fields: THttpFormFields;
  RegisteredTransport: boolean;
  Request: THttpRequest;
  Response: THttpResponse;
  Transport: IHttpTransport;
  WasCancelled: boolean;
begin
  Fields := nil;
  Json := '';
  Request := BuildHttpGetRequest(URL, Fields, UPDATE_HTTP_TIMEOUT_MS,
    UPDATE_HTTP_TIMEOUT_MS);

  RegisteredTransport := False;
  Transport := nil;
  try
    try
      Transport := FTransportFactory.CreateTransport;
      AlreadyActive := False;
      WasCancelled := False;
      EnterCriticalSection(FStateLock);
      try
        WasCancelled := FCancelled;
        AlreadyActive := Assigned(FActiveTransport);
        if not WasCancelled and not AlreadyActive then
        begin
          FActiveTransport := Transport;
          RegisteredTransport := True;
        end;
      finally
        LeaveCriticalSection(FStateLock);
      end;
      if WasCancelled then
      begin
        Transport.Cancel;
        Exit(CancelledResult);
      end;
      if AlreadyActive then
        Exit(FailedResult('An update check is already active'));

      Response := Transport.Execute(Request);
      if Response.ErrorKind = hekCancelled then
        Exit(CancelledResult);
      if not Response.Completed or (Response.ErrorKind <> hekNone) then
      begin
        ErrorMessage := Response.ErrorMessage;
        if ErrorMessage = '' then
          ErrorMessage := 'Network request failed';
        Exit(FailedResult(ErrorMessage));
      end;

      if not IsHttpSuccessStatus(Response.StatusCode) then
        Exit(FailedResult(Format('HTTP error %d: %s',
          [Response.StatusCode, Response.StatusText])));

      Json := string(Response.Body);
      Result := EvaluateReleaseResponse(ACurrentVersion, Json);
    except
      on E: Exception do
        Result := FailedResult(E.Message);
    end;
  finally
    if RegisteredTransport then
    begin
      EnterCriticalSection(FStateLock);
      try
        FActiveTransport := nil;
      finally
        LeaveCriticalSection(FStateLock);
      end;
    end;
    Transport := nil;
  end;
end;

procedure TUpdater.Cancel;
var
  ActiveTransport: IHttpTransport;
begin
  EnterCriticalSection(FStateLock);
  try
    FCancelled := True;
    ActiveTransport := FActiveTransport;
  finally
    LeaveCriticalSection(FStateLock);
  end;
  if Assigned(ActiveTransport) then
    ActiveTransport.Cancel;
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
  FResult.ReleaseUrl := '';
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
    FResult.ReleaseUrl := '';
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

constructor TUpdateCheckController.Create(ACheckerFactory: TUpdateCheckerFactory;
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
  FWorker := TUpdateCheckThread.Create(checker, ACurrentVersion, @WorkerFinished);
  try
    FWorker.Start;
    Result := True;
  except
    FreeAndNil(FWorker);
    raise;
  end;
end;

function TUpdateCheckController.StartAutomatic(const ACurrentVersion: string;
  AEnabled: boolean; AIntervalInDays: integer; ALastCheck, ANow: TDateTime): boolean;
begin
  if not IsAutomaticUpdateCheckDue(AEnabled, AIntervalInDays, ALastCheck, ANow) then
    Exit(False);
  Result := Start(ACurrentVersion, ucmAutomatic);
end;

function TUpdateCheckController.StartManual(const ACurrentVersion: string): boolean;
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
