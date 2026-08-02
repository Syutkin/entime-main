unit app_logger;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  DEFAULT_LOG_FILE_NAME_PREFIX = 'entime';
  DEFAULT_LOG_RETENTION_DAYS = 30;
  DEFAULT_LOG_COMBOBOX_MAX_ITEMS = 300;
  DEFAULT_LOG_MEMO_MAX_LINES = 30000;
  DEFAULT_LOG_MEMO_TRIM_LINES = 3000;
  DEFAULT_LOG_FILE_TIMESTAMP_FORMAT = 'yyyy-mm-dd hh:nn:ss.zzz';
  DEFAULT_LOG_COMBOBOX_TIMESTAMP_FORMAT = 'hh:nn:ss';
  DEFAULT_LOG_MEMO_ADD_TIMESTAMP = False;
  DEFAULT_LOG_FILE_MINIMUM_LEVEL_NAME = 'debug';

type
  TAppLogLevel = (allDebug, allInfo, allWarning, allError);
  TAppLogView = (alvNone, alvStatus, alvDetails);
  TAppLogSource = (alsApplication, alsDatabase, alsImport, alsExport,
    alsResults, alsSerial, alsHTTP, alsTelegram, alsLoRa, alsUpdater);

  TAppLogEntry = record
    CreatedAt: TDateTime;
    Level: TAppLogLevel;
    View: TAppLogView;
    Source: TAppLogSource;
    MessageText: string;
  end;

  TAppLogEvent = procedure(const AEntry: TAppLogEntry) of object;

  TLoggingSettings = record
    FileNamePrefix: string;
    FileMinimumLevel: TAppLogLevel;
    RetentionDays: integer;
    ComboBoxMaxItems: integer;
    MemoMaxLines: integer;
    MemoTrimLines: integer;
    FileTimestampFormat: string;
    ComboBoxTimestampFormat: string;
    MemoAddTimestamp: boolean;
  end;

function DefaultLoggingSettings: TLoggingSettings;
function LoadLoggingSettings(const AIniFileName: string;
  out AWarning: string): TLoggingSettings;
procedure InitializeAppLogger(const ASettings: TLoggingSettings;
  const APrimaryLogDirectory, AFallbackLogDirectory: string;
  const AStartupNotice: string = '');
procedure FinalizeAppLogger;
function CurrentAppLogFileName: string;
function CurrentLoggingSettings: TLoggingSettings;
procedure SetAppLogEvent(AEvent: TAppLogEvent);
procedure AppLog(const AMessage: string; ALevel: TAppLogLevel = allInfo;
  AView: TAppLogView = alvNone; ASource: TAppLogSource = alsApplication);
procedure LogUnhandledException(E: Exception);

implementation

uses
  Classes, IniFiles;

const
  LOGGING_INI_SECTION = 'Logging';
  LOGGING_INI_FILE_NAME_PREFIX = 'FileNamePrefix';
  LOGGING_INI_FILE_MINIMUM_LEVEL = 'FileMinimumLevel';
  LOGGING_INI_RETENTION_DAYS = 'RetentionDays';
  LOGGING_INI_COMBOBOX_MAX_ITEMS = 'ComboBoxMaxItems';
  LOGGING_INI_MEMO_MAX_LINES = 'MemoMaxLines';
  LOGGING_INI_MEMO_TRIM_LINES = 'MemoTrimLines';
  LOGGING_INI_FILE_TIMESTAMP_FORMAT = 'FileTimestampFormat';
  LOGGING_INI_COMBOBOX_TIMESTAMP_FORMAT = 'ComboBoxTimestampFormat';
  LOGGING_INI_MEMO_ADD_TIMESTAMP = 'MemoAddTimestamp';

type
  TQueuedAppLogDelivery = class
  private
    FEntry: TAppLogEntry;
    FEventGeneration: QWord;
  public
    constructor Create(const AEntry: TAppLogEntry; AEventGeneration: QWord);
    procedure Deliver;
  end;

var
  AppLogEvent: TAppLogEvent = nil;
  FileLogStream: TFileStream = nil;
  LogFileName: string = '';
  PendingNotice: string = '';
  PendingNoticeDelivered: boolean = False;
  AppLogEventGeneration: QWord = 0;
  ActiveLoggingSettings: TLoggingSettings;
  LoggerLock: TRTLCriticalSection;

constructor TQueuedAppLogDelivery.Create(const AEntry: TAppLogEntry;
  AEventGeneration: QWord);
begin
  inherited Create;
  FEntry := AEntry;
  FEventGeneration := AEventGeneration;
end;

procedure TQueuedAppLogDelivery.Deliver;
var
  event: TAppLogEvent;
begin
  try
    event := nil;
    EnterCriticalSection(LoggerLock);
    try
      if (FEventGeneration = AppLogEventGeneration) and
        Assigned(AppLogEvent) then
        event := AppLogEvent;
    finally
      LeaveCriticalSection(LoggerLock);
    end;

    try
      if Assigned(event) then
        event(FEntry);
    except
      // Logging UI failures must not interrupt the application message loop.
    end;
  finally
    Free;
  end;
end;

procedure QueueAppLogEntry(const AEntry: TAppLogEntry);
var
  eventGeneration: QWord;
  delivery: TQueuedAppLogDelivery;
begin
  EnterCriticalSection(LoggerLock);
  try
    if not Assigned(AppLogEvent) then
      Exit;
    eventGeneration := AppLogEventGeneration;
  finally
    LeaveCriticalSection(LoggerLock);
  end;

  delivery := TQueuedAppLogDelivery.Create(AEntry, eventGeneration);
  TThread.Queue(nil, @delivery.Deliver);
end;

function LogLevelName(ALevel: TAppLogLevel): string;
begin
  case ALevel of
    allDebug: Result := 'debug';
    allInfo: Result := 'info';
    allWarning: Result := 'warning';
    allError: Result := 'error';
  end;
end;

function LogSourceName(ASource: TAppLogSource): string;
begin
  case ASource of
    alsDatabase: Result := 'Database';
    alsImport: Result := 'Import';
    alsExport: Result := 'Export';
    alsResults: Result := 'Results';
    alsSerial: Result := 'Serial';
    alsHTTP: Result := 'HTTP';
    alsTelegram: Result := 'Telegram';
    alsLoRa: Result := 'LoRa';
    alsUpdater: Result := 'Updater';
  else
    Result := 'Application';
  end;
end;

procedure WriteFileLogEntry(AStream: TStream;
  const ASettings: TLoggingSettings; ACreatedAt: TDateTime;
  ALevel: TAppLogLevel; ASource: TAppLogSource; const AMessage: string);
var
  line: string;
begin
  line := Format('%s [%s] [%s] %s%s', [
    FormatDateTime(ASettings.FileTimestampFormat, ACreatedAt),
    UpperCase(LogLevelName(ALevel)), LogSourceName(ASource), AMessage,
    LineEnding]);
  AStream.WriteBuffer(line[1], Length(line));
end;

function BacktraceAddressText(AAddress: Pointer): string;
begin
  if AAddress = nil then
    Exit('');

  try
    if Assigned(BackTraceStrFunc) then
      Result := BackTraceStrFunc(AAddress)
    else
      Result := SysBackTraceStr(AAddress);
  except
    Result := SysBackTraceStr(AAddress);
  end;
end;

function TryParseLogLevel(const AValue: string;
  out ALevel: TAppLogLevel): boolean;
begin
  Result := True;
  if SameText(Trim(AValue), 'debug') then
    ALevel := allDebug
  else if SameText(Trim(AValue), 'info') then
    ALevel := allInfo
  else if SameText(Trim(AValue), 'warning') then
    ALevel := allWarning
  else if SameText(Trim(AValue), 'error') then
    ALevel := allError
  else
    Result := False;
end;

function BuildLogFileName(const ADirectory, APrefix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ADirectory) + APrefix + '-' +
    FormatDateTime('yyyy-mm-dd_hh-nn-ss', Now) + '-' +
    IntToStr(GetProcessID) + '.log';
end;

procedure DeleteExpiredLogFiles(const ASettings: TLoggingSettings;
  const ADirectory, ACurrentLogFileName: string);
var
  cutoffDate, modifiedAt: TDateTime;
  fileName, fileMask: string;
  search: TSearchRec;
begin
  if (ASettings.RetentionDays <= 0) or not DirectoryExists(ADirectory) then
    Exit;

  cutoffDate := Now - ASettings.RetentionDays;
  fileMask := IncludeTrailingPathDelimiter(ADirectory) +
    ASettings.FileNamePrefix + '-*.log';
  try
    if FindFirst(fileMask, faAnyFile, search) <> 0 then
      Exit;
    try
      repeat
        if (search.Attr and faDirectory) <> 0 then
          Continue;
        fileName := IncludeTrailingPathDelimiter(ADirectory) + search.Name;
        if (ACurrentLogFileName <> '') and
          SameFileName(fileName, ACurrentLogFileName) then
          Continue;
        if FileAge(fileName, modifiedAt) and (modifiedAt < cutoffDate) then
          DeleteFile(fileName);
      until FindNext(search) <> 0;
    finally
      FindClose(search);
    end;
  except
    Exit;
  end;
end;

function TryOpenFileLogger(const ASettings: TLoggingSettings;
  const ADirectory: string; out AError: string): boolean;
var
  logger: TFileStream;
  fileName: string;
begin
  Result := False;
  AError := '';
  logger := nil;

  try
    if Trim(ADirectory) = '' then
      raise EStreamError.Create('Log directory is empty');
    if not ForceDirectories(ADirectory) then
      raise EStreamError.CreateFmt('Unable to create log directory "%s"',
        [ADirectory]);

    fileName := BuildLogFileName(ADirectory, ASettings.FileNamePrefix);
    logger := TFileStream.Create(fileName, fmCreate or fmShareDenyWrite);
    WriteFileLogEntry(logger, ASettings, Now, allInfo, alsApplication,
      'File logger initialized');

    FileLogStream := logger;
    LogFileName := fileName;
    logger := nil;
    Result := True;
  except
    on E: Exception do
      AError := E.Message;
  end;

  logger.Free;
end;

procedure SetPendingNotice(const AMessage: string);
begin
  if AMessage = '' then
    Exit;

  if (PendingNotice = '') or PendingNoticeDelivered then
  begin
    PendingNotice := AMessage;
    PendingNoticeDelivered := False;
  end;
  if (PendingNotice <> AMessage) and
    (Pos(AMessage, PendingNotice) = 0) then
  begin
    PendingNotice := PendingNotice + LineEnding + AMessage;
    PendingNoticeDelivered := False;
  end;
end;

procedure DeliverPendingNotice;
var
  shouldDeliver: boolean;
  entry: TAppLogEntry;
begin
  shouldDeliver := False;
  entry.MessageText := '';

  EnterCriticalSection(LoggerLock);
  try
    if Assigned(AppLogEvent) and (PendingNotice <> '') and
      not PendingNoticeDelivered then
    begin
      shouldDeliver := True;
      PendingNoticeDelivered := True;
      entry.CreatedAt := Now;
      entry.Level := allWarning;
      entry.View := alvDetails;
      entry.Source := alsApplication;
      entry.MessageText := PendingNotice;
    end;
  finally
    LeaveCriticalSection(LoggerLock);
  end;

  if shouldDeliver then
    QueueAppLogEntry(entry);
end;

function DefaultLoggingSettings: TLoggingSettings;
begin
  Result.FileNamePrefix := DEFAULT_LOG_FILE_NAME_PREFIX;
  Result.FileMinimumLevel := allDebug;
  Result.RetentionDays := DEFAULT_LOG_RETENTION_DAYS;
  Result.ComboBoxMaxItems := DEFAULT_LOG_COMBOBOX_MAX_ITEMS;
  Result.MemoMaxLines := DEFAULT_LOG_MEMO_MAX_LINES;
  Result.MemoTrimLines := DEFAULT_LOG_MEMO_TRIM_LINES;
  Result.FileTimestampFormat := DEFAULT_LOG_FILE_TIMESTAMP_FORMAT;
  Result.ComboBoxTimestampFormat := DEFAULT_LOG_COMBOBOX_TIMESTAMP_FORMAT;
  Result.MemoAddTimestamp := DEFAULT_LOG_MEMO_ADD_TIMESTAMP;
end;

function IsValidFileNamePrefix(const AValue: string): boolean;
var
  c: char;
begin
  Result := AValue <> '';
  if not Result then
    Exit;

  for c in AValue do
    if not (c in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_']) then
      Exit(False);
end;

function IsValidTimestampFormat(const AValue: string): boolean;
begin
  Result := AValue <> '';
  if not Result then
    Exit;

  try
    FormatDateTime(AValue, Now);
  except
    on E: EConvertError do
      Result := False;
  end;
end;

function ReadPositiveInteger(AIni: TIniFile; const AKey: string;
  ADefault: integer; var AChanged: boolean): integer;
var
  rawValue: string;
begin
  rawValue := Trim(AIni.ReadString(LOGGING_INI_SECTION, AKey, ''));
  if (not TryStrToInt(rawValue, Result)) or (Result <= 0) then
  begin
    Result := ADefault;
    AIni.WriteInteger(LOGGING_INI_SECTION, AKey, Result);
    AChanged := True;
  end;
end;

function ReadTimestampFormat(AIni: TIniFile; const AKey, ADefault: string;
  var AChanged: boolean): string;
begin
  Result := AIni.ReadString(LOGGING_INI_SECTION, AKey, '');
  if not IsValidTimestampFormat(Result) then
  begin
    Result := ADefault;
    AIni.WriteString(LOGGING_INI_SECTION, AKey, Result);
    AChanged := True;
  end;
end;

function ReadBoolean(AIni: TIniFile; const AKey: string; ADefault: boolean;
  var AChanged: boolean): boolean;
var
  rawValue: string;
begin
  rawValue := Trim(AIni.ReadString(LOGGING_INI_SECTION, AKey, ''));
  if SameText(rawValue, 'true') or (rawValue = '1') then
    Result := True
  else if SameText(rawValue, 'false') or (rawValue = '0') then
    Result := False
  else
  begin
    Result := ADefault;
    if Result then
      rawValue := 'true'
    else
      rawValue := 'false';
    AIni.WriteString(LOGGING_INI_SECTION, AKey, rawValue);
    AChanged := True;
  end;
end;

function ReadLogLevel(AIni: TIniFile; const AKey: string;
  ADefault: TAppLogLevel; var AChanged: boolean): TAppLogLevel;
var
  rawValue: string;
begin
  rawValue := AIni.ReadString(LOGGING_INI_SECTION, AKey, '');
  if not TryParseLogLevel(rawValue, Result) then
  begin
    Result := ADefault;
    AIni.WriteString(LOGGING_INI_SECTION, AKey, LogLevelName(Result));
    AChanged := True;
  end;
end;

function LoadLoggingSettings(const AIniFileName: string;
  out AWarning: string): TLoggingSettings;
var
  ini: TIniFile;
  changed, sectionExisted: boolean;
begin
  Result := DefaultLoggingSettings;
  AWarning := '';
  ini := nil;

  try
    try
      if Trim(AIniFileName) = '' then
        raise Exception.Create('INI file name is empty');

      ini := TIniFile.Create(AIniFileName);
      ini.CacheUpdates := True;
      sectionExisted := ini.SectionExists(LOGGING_INI_SECTION);
      changed := False;

      Result.FileNamePrefix :=
        ini.ReadString(LOGGING_INI_SECTION, LOGGING_INI_FILE_NAME_PREFIX, '');
      if not IsValidFileNamePrefix(Result.FileNamePrefix) then
      begin
        Result.FileNamePrefix := DEFAULT_LOG_FILE_NAME_PREFIX;
        ini.WriteString(LOGGING_INI_SECTION, LOGGING_INI_FILE_NAME_PREFIX,
          Result.FileNamePrefix);
        changed := True;
      end;

      Result.FileMinimumLevel := ReadLogLevel(ini,
        LOGGING_INI_FILE_MINIMUM_LEVEL, allDebug, changed);
      Result.RetentionDays := ReadPositiveInteger(ini,
        LOGGING_INI_RETENTION_DAYS, DEFAULT_LOG_RETENTION_DAYS, changed);
      Result.ComboBoxMaxItems := ReadPositiveInteger(ini,
        LOGGING_INI_COMBOBOX_MAX_ITEMS, DEFAULT_LOG_COMBOBOX_MAX_ITEMS, changed);
      Result.MemoMaxLines := ReadPositiveInteger(ini,
        LOGGING_INI_MEMO_MAX_LINES, DEFAULT_LOG_MEMO_MAX_LINES, changed);
      Result.MemoTrimLines := ReadPositiveInteger(ini,
        LOGGING_INI_MEMO_TRIM_LINES, DEFAULT_LOG_MEMO_TRIM_LINES, changed);

      if Result.MemoTrimLines >= Result.MemoMaxLines then
      begin
        Result.MemoMaxLines := DEFAULT_LOG_MEMO_MAX_LINES;
        Result.MemoTrimLines := DEFAULT_LOG_MEMO_TRIM_LINES;
        ini.WriteInteger(LOGGING_INI_SECTION, LOGGING_INI_MEMO_MAX_LINES,
          Result.MemoMaxLines);
        ini.WriteInteger(LOGGING_INI_SECTION, LOGGING_INI_MEMO_TRIM_LINES,
          Result.MemoTrimLines);
        changed := True;
      end;

      Result.FileTimestampFormat := ReadTimestampFormat(ini,
        LOGGING_INI_FILE_TIMESTAMP_FORMAT,
        DEFAULT_LOG_FILE_TIMESTAMP_FORMAT, changed);
      Result.ComboBoxTimestampFormat := ReadTimestampFormat(ini,
        LOGGING_INI_COMBOBOX_TIMESTAMP_FORMAT,
        DEFAULT_LOG_COMBOBOX_TIMESTAMP_FORMAT, changed);
      Result.MemoAddTimestamp := ReadBoolean(ini,
        LOGGING_INI_MEMO_ADD_TIMESTAMP, DEFAULT_LOG_MEMO_ADD_TIMESTAMP, changed);

      if changed then
      begin
        ini.UpdateFile;
        if sectionExisted then
          AWarning := Format(
            'Invalid logging settings in "%s" were replaced with defaults',
            [AIniFileName]);
      end;
    except
      on E: Exception do
      begin
        Result := DefaultLoggingSettings;
        AWarning := Format('Unable to load logging settings from "%s": %s',
          [AIniFileName, E.Message]);
      end;
    end;
  finally
    ini.Free;
  end;
end;

procedure InitializeAppLogger(const ASettings: TLoggingSettings;
  const APrimaryLogDirectory, AFallbackLogDirectory: string;
  const AStartupNotice: string);
var
  primaryError, fallbackError: string;
begin
  FinalizeAppLogger;

  EnterCriticalSection(LoggerLock);
  try
    PendingNotice := '';
    PendingNoticeDelivered := False;
    ActiveLoggingSettings := ASettings;
    SetPendingNotice(AStartupNotice);

    if TryOpenFileLogger(ASettings, APrimaryLogDirectory, primaryError) then
    begin
      DeleteExpiredLogFiles(ASettings, APrimaryLogDirectory, LogFileName);
      DeleteExpiredLogFiles(ASettings, AFallbackLogDirectory, LogFileName);
      Exit;
    end;

    if TryOpenFileLogger(ASettings, AFallbackLogDirectory, fallbackError) then
    begin
      DeleteExpiredLogFiles(ASettings, APrimaryLogDirectory, LogFileName);
      DeleteExpiredLogFiles(ASettings, AFallbackLogDirectory, LogFileName);
      SetPendingNotice(Format('File logger uses fallback path: %s',
        [LogFileName]));
      Exit;
    end;

    LogFileName := '';
    DeleteExpiredLogFiles(ASettings, APrimaryLogDirectory, LogFileName);
    DeleteExpiredLogFiles(ASettings, AFallbackLogDirectory, LogFileName);
    SetPendingNotice(Format(
      'Unable to create log file. Primary: %s. Fallback: %s',
      [primaryError, fallbackError]));
  finally
    LeaveCriticalSection(LoggerLock);
  end;
end;

procedure FinalizeAppLogger;
begin
  EnterCriticalSection(LoggerLock);
  try
    FreeAndNil(FileLogStream);
  finally
    LeaveCriticalSection(LoggerLock);
  end;
end;

function CurrentAppLogFileName: string;
begin
  EnterCriticalSection(LoggerLock);
  try
    Result := LogFileName;
  finally
    LeaveCriticalSection(LoggerLock);
  end;
end;

function CurrentLoggingSettings: TLoggingSettings;
begin
  EnterCriticalSection(LoggerLock);
  try
    Result := ActiveLoggingSettings;
  finally
    LeaveCriticalSection(LoggerLock);
  end;
end;

procedure SetAppLogEvent(AEvent: TAppLogEvent);
begin
  EnterCriticalSection(LoggerLock);
  try
    AppLogEvent := AEvent;
    Inc(AppLogEventGeneration);
  finally
    LeaveCriticalSection(LoggerLock);
  end;
  DeliverPendingNotice;
end;

procedure AppLog(const AMessage: string; ALevel: TAppLogLevel;
  AView: TAppLogView; ASource: TAppLogSource);
var
  entry: TAppLogEntry;
  writeError: string;
begin
  entry.CreatedAt := Now;
  entry.Level := ALevel;
  entry.View := AView;
  entry.Source := ASource;
  entry.MessageText := AMessage;

  writeError := '';
  EnterCriticalSection(LoggerLock);
  try
    if Assigned(FileLogStream) and
      (Ord(ALevel) >= Ord(ActiveLoggingSettings.FileMinimumLevel)) then
      try
        WriteFileLogEntry(FileLogStream, ActiveLoggingSettings, entry.CreatedAt,
          ALevel, ASource, AMessage);
      except
        on E: Exception do
        begin
          writeError := E.Message;
          FreeAndNil(FileLogStream);
          SetPendingNotice(Format('File logger disabled after write error: %s',
            [writeError]));
        end;
      end;
  finally
    LeaveCriticalSection(LoggerLock);
  end;

  DeliverPendingNotice;
  QueueAppLogEntry(entry);
end;

procedure LogUnhandledException(E: Exception);
var
  frameNumber: integer;
  frames: PPointer;
  traceLine: string;
begin
  if E = nil then
    Exit;

  AppLog(Format('Unhandled exception %s: %s', [E.ClassName, E.Message]),
    allError, alvDetails, alsApplication);

  traceLine := BacktraceAddressText(ExceptAddr);
  if traceLine <> '' then
    AppLog('Stack trace: ' + traceLine, allDebug, alvDetails, alsApplication);

  frames := ExceptFrames;
  for frameNumber := 0 to ExceptFrameCount - 1 do
  begin
    traceLine := BacktraceAddressText(frames[frameNumber]);
    if traceLine <> '' then
      AppLog('Stack trace: ' + traceLine, allDebug, alvDetails,
        alsApplication);
  end;
end;

initialization
  InitCriticalSection(LoggerLock);
  ActiveLoggingSettings := DefaultLoggingSettings;

finalization
  FinalizeAppLogger;
  DoneCriticalSection(LoggerLock);

end.
