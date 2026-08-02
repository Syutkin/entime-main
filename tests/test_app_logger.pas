unit test_app_logger;

{$mode ObjFPC}{$H+}

interface

uses
  fpcunit, testregistry, app_logger;

type
  TAppLoggerTests = class(TTestCase)
  private
    FIniFileName: string;
    FTempDirectory: string;
    FEventCount: integer;
    FLastEventThreadID: TThreadID;
    FLastEntry: TAppLogEntry;
    procedure AssertDefaultSettings(const ASettings: TLoggingSettings);
    procedure ReceiveLogEntry(const AEntry: TAppLogEntry);
    function ReadLog(const AFileName: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure DefaultSettings_ReturnsApprovedValues;
    procedure LoadSettings_MissingSectionWritesDefaults;
    procedure LoadSettings_LoadsValidValuesAndPreservesOtherSections;
    procedure LoadSettings_NormalizesInvalidValues;
    procedure LoadSettings_EmptyPathReturnsDefaultsAndWarning;
    procedure AppLog_UsesDefaultLevelAndView;
    procedure AppLog_PreservesExplicitLevelAndView;
    procedure AppLog_PreservesExplicitSource;
    procedure AppLog_DoesNotDeliverAfterEventIsCleared;
    procedure AppLog_QueuedEventDoesNotDeliverAfterEventIsCleared;
    procedure AppLog_BackgroundEventIsQueuedToMainThread;
    procedure Initialize_CreatesDirectoryAndFile;
    procedure Initialize_ExistingDirectoryCreatesFileAndWritesEntry;
    procedure AppLog_WritesEntriesInCallOrder;
    procedure AppLog_WritesLevelAndMessage;
    procedure AppLog_WritesSourceAndMessage;
    procedure AppLog_WritesExactFileLineFormat;
    procedure AppLog_FileMinimumLevelFiltersOnlyFile;
    procedure AppLog_WritesFullTimestampWithMilliseconds;
    procedure AppLog_PreservesCyrillicText;
    procedure Initialize_UnavailablePrimaryUsesFallback;
    procedure Initialize_FallbackNoticeDeliveredOnceAfterUiConnects;
    procedure Initialize_BothDirectoriesUnavailableDoesNotRaise;
    procedure Initialize_BothDirectoriesUnavailableNotifiesUiOnce;
    procedure Initialize_StartupNoticeDeliveredOnceAfterUiConnects;
    procedure AppLog_AfterFinalizeIsSafe;
    procedure AppLog_ParallelWritesKeepLinesIntact;
    procedure Initialize_RemovesOnlyExpiredMatchingLogs;
    procedure LogUnhandledException_WritesExceptionAndStackTrace;
  end;

implementation

uses
  Classes, SysUtils, IniFiles, DateUtils;

type
  TLogWriterThread = class(TThread)
  private
    FPrefix: string;
    FCount: integer;
  protected
    procedure Execute; override;
  public
    constructor Create(const APrefix: string; ACount: integer);
  end;

  TSingleLogThread = class(TThread)
  protected
    procedure Execute; override;
  end;

  TQueuedLogThread = class(TThread)
  private
    FSubmittedEvent: PRTLEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(ASubmittedEvent: PRTLEvent);
  end;

procedure RemoveTestDirectory(const ADirectory: string);
var
  search: TSearchRec;
  path, itemName: string;
begin
  if not DirectoryExists(ADirectory) then
    Exit;

  path := IncludeTrailingPathDelimiter(ADirectory);
  if FindFirst(path + '*', faAnyFile, search) = 0 then
  try
    repeat
      if (search.Name = '.') or (search.Name = '..') then
        Continue;
      itemName := path + search.Name;
      if (search.Attr and faDirectory) <> 0 then
        RemoveTestDirectory(itemName)
      else
        DeleteFile(itemName);
    until FindNext(search) <> 0;
  finally
    FindClose(search);
  end;
  RemoveDir(ADirectory);
end;

constructor TLogWriterThread.Create(const APrefix: string; ACount: integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPrefix := APrefix;
  FCount := ACount;
end;

procedure TLogWriterThread.Execute;
var
  i: integer;
begin
  for i := 1 to FCount do
    AppLog(Format('%s-%d-END', [FPrefix, i]), allDebug, alvNone);
end;

procedure TSingleLogThread.Execute;
begin
  AppLog('background-entry', allInfo, alvStatus);
end;

constructor TQueuedLogThread.Create(ASubmittedEvent: PRTLEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FSubmittedEvent := ASubmittedEvent;
end;

procedure TQueuedLogThread.Execute;
begin
  AppLog('queued-before-detach', allInfo, alvStatus);
  RTLEventSetEvent(FSubmittedEvent);
end;

procedure TAppLoggerTests.SetUp;
begin
  inherited SetUp;
  FIniFileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    Format('entime-app-logger-%d.ini', [GetTickCount64]);
  FTempDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    Format('entime-app-logger-%d-%d', [GetProcessID, GetTickCount64]);
  if FileExists(FIniFileName) then
    DeleteFile(FIniFileName);
  FEventCount := 0;
  FLastEventThreadID := 0;
  FLastEntry.MessageText := '';
  SetAppLogEvent(nil);
end;

procedure TAppLoggerTests.TearDown;
begin
  FinalizeAppLogger;
  SetAppLogEvent(nil);
  if FileExists(FIniFileName) then
    DeleteFile(FIniFileName);
  RemoveTestDirectory(FTempDirectory);
  inherited TearDown;
end;

function TAppLoggerTests.ReadLog(const AFileName: string): string;
var
  content: TStringList;
begin
  AssertTrue('Logger must expose the log file name', AFileName <> '');
  AssertTrue('The log file must exist', FileExists(AFileName));
  content := TStringList.Create;
  try
    content.LoadFromFile(AFileName);
    Result := content.Text;
  finally
    content.Free;
  end;
end;

procedure TAppLoggerTests.AssertDefaultSettings(
  const ASettings: TLoggingSettings);
begin
  AssertEquals(DEFAULT_LOG_FILE_NAME_PREFIX, ASettings.FileNamePrefix);
  AssertEquals(Ord(allDebug), Ord(ASettings.FileMinimumLevel));
  AssertEquals(DEFAULT_LOG_RETENTION_DAYS, ASettings.RetentionDays);
  AssertEquals(DEFAULT_LOG_COMBOBOX_MAX_ITEMS, ASettings.ComboBoxMaxItems);
  AssertEquals(DEFAULT_LOG_MEMO_MAX_LINES, ASettings.MemoMaxLines);
  AssertEquals(DEFAULT_LOG_MEMO_TRIM_LINES, ASettings.MemoTrimLines);
  AssertEquals(DEFAULT_LOG_FILE_TIMESTAMP_FORMAT,
    ASettings.FileTimestampFormat);
  AssertEquals(DEFAULT_LOG_COMBOBOX_TIMESTAMP_FORMAT,
    ASettings.ComboBoxTimestampFormat);
  AssertEquals(DEFAULT_LOG_MEMO_ADD_TIMESTAMP, ASettings.MemoAddTimestamp);
end;

procedure TAppLoggerTests.ReceiveLogEntry(const AEntry: TAppLogEntry);
begin
  Inc(FEventCount);
  FLastEventThreadID := GetCurrentThreadID;
  FLastEntry := AEntry;
end;

procedure TAppLoggerTests.DefaultSettings_ReturnsApprovedValues;
begin
  AssertDefaultSettings(DefaultLoggingSettings);
end;

procedure TAppLoggerTests.LoadSettings_MissingSectionWritesDefaults;
var
  ini: TIniFile;
  keys: TStringList;
  settings: TLoggingSettings;
  warning: string;
begin
  settings := LoadLoggingSettings(FIniFileName, warning);

  AssertEquals('', warning);
  AssertDefaultSettings(settings);
  AssertTrue(FileExists(FIniFileName));

  ini := TIniFile.Create(FIniFileName);
  keys := TStringList.Create;
  try
    ini.ReadSection('Logging', keys);
    AssertEquals(9, keys.Count);
    AssertTrue(ini.ValueExists('Logging', 'FileNamePrefix'));
    AssertTrue(ini.ValueExists('Logging', 'FileMinimumLevel'));
    AssertTrue(ini.ValueExists('Logging', 'RetentionDays'));
    AssertTrue(ini.ValueExists('Logging', 'ComboBoxMaxItems'));
    AssertTrue(ini.ValueExists('Logging', 'MemoMaxLines'));
    AssertTrue(ini.ValueExists('Logging', 'MemoTrimLines'));
    AssertTrue(ini.ValueExists('Logging', 'FileTimestampFormat'));
    AssertTrue(ini.ValueExists('Logging', 'ComboBoxTimestampFormat'));
    AssertTrue(ini.ValueExists('Logging', 'MemoAddTimestamp'));
  finally
    keys.Free;
    ini.Free;
  end;
end;

procedure TAppLoggerTests.LoadSettings_LoadsValidValuesAndPreservesOtherSections;
var
  ini: TIniFile;
  settings: TLoggingSettings;
  warning: string;
begin
  ini := TIniFile.Create(FIniFileName);
  try
    ini.WriteString('Other', 'KeepMe', 'yes');
    ini.WriteString('Logging', 'FileNamePrefix', 'race_log');
    ini.WriteString('Logging', 'FileMinimumLevel', 'WaRnInG');
    ini.WriteInteger('Logging', 'RetentionDays', 45);
    ini.WriteInteger('Logging', 'ComboBoxMaxItems', 123);
    ini.WriteInteger('Logging', 'MemoMaxLines', 5000);
    ini.WriteInteger('Logging', 'MemoTrimLines', 500);
    ini.WriteString('Logging', 'FileTimestampFormat', 'yyyy-mm-dd');
    ini.WriteString('Logging', 'ComboBoxTimestampFormat', 'hh:nn');
    ini.WriteString('Logging', 'MemoAddTimestamp', 'true');
  finally
    ini.Free;
  end;

  settings := LoadLoggingSettings(FIniFileName, warning);

  AssertEquals('', warning);
  AssertEquals('race_log', settings.FileNamePrefix);
  AssertEquals(Ord(allWarning), Ord(settings.FileMinimumLevel));
  AssertEquals(45, settings.RetentionDays);
  AssertEquals(123, settings.ComboBoxMaxItems);
  AssertEquals(5000, settings.MemoMaxLines);
  AssertEquals(500, settings.MemoTrimLines);
  AssertEquals('yyyy-mm-dd', settings.FileTimestampFormat);
  AssertEquals('hh:nn', settings.ComboBoxTimestampFormat);
  AssertTrue(settings.MemoAddTimestamp);

  ini := TIniFile.Create(FIniFileName);
  try
    AssertEquals('yes', ini.ReadString('Other', 'KeepMe', ''));
  finally
    ini.Free;
  end;
end;

procedure TAppLoggerTests.LoadSettings_NormalizesInvalidValues;
var
  ini: TIniFile;
  settings: TLoggingSettings;
  warning: string;
begin
  ini := TIniFile.Create(FIniFileName);
  try
    ini.WriteString('Logging', 'FileNamePrefix', 'bad/name');
    ini.WriteString('Logging', 'FileMinimumLevel', 'verbose');
    ini.WriteInteger('Logging', 'RetentionDays', -1);
    ini.WriteInteger('Logging', 'ComboBoxMaxItems', 0);
    ini.WriteInteger('Logging', 'MemoMaxLines', 1000);
    ini.WriteInteger('Logging', 'MemoTrimLines', 1000);
    ini.WriteString('Logging', 'FileTimestampFormat', '');
    ini.WriteString('Logging', 'ComboBoxTimestampFormat', '');
    ini.WriteString('Logging', 'MemoAddTimestamp', 'invalid');
  finally
    ini.Free;
  end;

  settings := LoadLoggingSettings(FIniFileName, warning);

  AssertTrue('Normalized invalid values must produce a warning', warning <> '');
  AssertTrue('The warning must identify the affected INI file',
    Pos(FIniFileName, warning) > 0);
  AssertDefaultSettings(settings);

  ini := TIniFile.Create(FIniFileName);
  try
    AssertEquals(DEFAULT_LOG_FILE_NAME_PREFIX,
      ini.ReadString('Logging', 'FileNamePrefix', ''));
    AssertEquals(DEFAULT_LOG_FILE_MINIMUM_LEVEL_NAME,
      ini.ReadString('Logging', 'FileMinimumLevel', ''));
    AssertEquals(DEFAULT_LOG_RETENTION_DAYS,
      ini.ReadInteger('Logging', 'RetentionDays', 0));
    AssertEquals(DEFAULT_LOG_COMBOBOX_MAX_ITEMS,
      ini.ReadInteger('Logging', 'ComboBoxMaxItems', 0));
    AssertEquals(DEFAULT_LOG_MEMO_MAX_LINES,
      ini.ReadInteger('Logging', 'MemoMaxLines', 0));
    AssertEquals(DEFAULT_LOG_MEMO_TRIM_LINES,
      ini.ReadInteger('Logging', 'MemoTrimLines', 0));
    AssertEquals(DEFAULT_LOG_FILE_TIMESTAMP_FORMAT,
      ini.ReadString('Logging', 'FileTimestampFormat', ''));
    AssertEquals(DEFAULT_LOG_COMBOBOX_TIMESTAMP_FORMAT,
      ini.ReadString('Logging', 'ComboBoxTimestampFormat', ''));
    AssertEquals('false',
      ini.ReadString('Logging', 'MemoAddTimestamp', ''));
  finally
    ini.Free;
  end;
end;

procedure TAppLoggerTests.LoadSettings_EmptyPathReturnsDefaultsAndWarning;
var
  settings: TLoggingSettings;
  warning: string;
begin
  settings := LoadLoggingSettings('', warning);

  AssertDefaultSettings(settings);
  AssertTrue('Expected warning for an empty INI path', warning <> '');
end;

procedure TAppLoggerTests.AppLog_UsesDefaultLevelAndView;
var
  startedAt, finishedAt: TDateTime;
begin
  SetAppLogEvent(@ReceiveLogEntry);
  startedAt := Now;
  AppLog('default message');
  finishedAt := Now;

  AssertEquals(1, FEventCount);
  AssertEquals('default message', FLastEntry.MessageText);
  AssertEquals(Ord(allInfo), Ord(FLastEntry.Level));
  AssertEquals(Ord(alvNone), Ord(FLastEntry.View));
  AssertEquals(Ord(alsApplication), Ord(FLastEntry.Source));
  AssertTrue((FLastEntry.CreatedAt >= startedAt) and
    (FLastEntry.CreatedAt <= finishedAt));
end;

procedure TAppLoggerTests.AppLog_PreservesExplicitSource;
begin
  SetAppLogEvent(@ReceiveLogEntry);

  AppLog('database error', allError, alvStatus, alsDatabase);

  AssertEquals(1, FEventCount);
  AssertEquals('database error', FLastEntry.MessageText);
  AssertEquals(Ord(alsDatabase), Ord(FLastEntry.Source));
end;

procedure TAppLoggerTests.AppLog_PreservesExplicitLevelAndView;
begin
  SetAppLogEvent(@ReceiveLogEntry);

  AppLog('error without status', allError, alvNone);

  AssertEquals(1, FEventCount);
  AssertEquals('error without status', FLastEntry.MessageText);
  AssertEquals(Ord(allError), Ord(FLastEntry.Level));
  AssertEquals(Ord(alvNone), Ord(FLastEntry.View));
end;

procedure TAppLoggerTests.AppLog_DoesNotDeliverAfterEventIsCleared;
begin
  SetAppLogEvent(@ReceiveLogEntry);
  AppLog('delivered');
  SetAppLogEvent(nil);

  AppLog('not delivered', allWarning, alvStatus);

  AssertEquals(1, FEventCount);
  AssertEquals('delivered', FLastEntry.MessageText);
end;

procedure TAppLoggerTests.AppLog_QueuedEventDoesNotDeliverAfterEventIsCleared;
var
  submittedEvent: PRTLEvent;
  thread: TQueuedLogThread;
begin
  submittedEvent := RTLEventCreate;
  SetAppLogEvent(@ReceiveLogEntry);
  thread := TQueuedLogThread.Create(submittedEvent);
  try
    thread.Start;
    RTLEventWaitFor(submittedEvent);
    SetAppLogEvent(nil);
    thread.WaitFor;
  finally
    thread.Free;
    RTLEventDestroy(submittedEvent);
  end;

  CheckSynchronize;

  AssertEquals('A queued event must not reach a detached UI handler',
    0, FEventCount);
end;

procedure TAppLoggerTests.AppLog_BackgroundEventIsQueuedToMainThread;
var
  thread: TSingleLogThread;
begin
  SetAppLogEvent(@ReceiveLogEntry);
  thread := TSingleLogThread.Create(True);
  try
    thread.Start;
    thread.WaitFor;
  finally
    thread.Free;
  end;

  CheckSynchronize;

  AssertEquals(1, FEventCount);
  AssertEquals('background-entry', FLastEntry.MessageText);
  AssertTrue('UI event must run in the main thread',
    FLastEventThreadID = MainThreadID);
end;

procedure TAppLoggerTests.Initialize_CreatesDirectoryAndFile;
var
  logDirectory: string;
begin
  logDirectory := IncludeTrailingPathDelimiter(FTempDirectory) + 'logs';

  InitializeAppLogger(DefaultLoggingSettings, logDirectory, '');

  AssertTrue('The log directory must be created', DirectoryExists(logDirectory));
  AssertTrue('A separate log file must be created for this run',
    FileExists(CurrentAppLogFileName));
end;

procedure TAppLoggerTests.Initialize_ExistingDirectoryCreatesFileAndWritesEntry;
var
  content, logFileName: string;
begin
  AssertTrue('The existing log directory must be prepared',
    ForceDirectories(FTempDirectory));

  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '');
  AppLog('existing-directory-entry');
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;

  AssertTrue('A log file must be created in the existing directory',
    FileExists(logFileName));
  content := ReadLog(logFileName);
  AssertTrue('The entry must be written to the created log file',
    Pos('existing-directory-entry', content) > 0);
end;

procedure TAppLoggerTests.AppLog_WritesEntriesInCallOrder;
var
  content, logFileName: string;
begin
  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '');

  AppLog('first-entry');
  AppLog('second-entry');
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;
  content := ReadLog(logFileName);

  AssertTrue('Both entries must be present',
    (Pos('first-entry', content) > 0) and (Pos('second-entry', content) > 0));
  AssertTrue('Entries must retain call order',
    Pos('first-entry', content) < Pos('second-entry', content));
end;

procedure TAppLoggerTests.AppLog_WritesLevelAndMessage;
var
  content, logFileName: string;
begin
  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '');

  AppLog('disk-is-full', allWarning, alvNone);
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;
  content := ReadLog(logFileName);

  AssertTrue('The file line must contain the level, source and message',
    Pos(' [WARNING] [Application] disk-is-full', content) > 0);
end;

procedure TAppLoggerTests.AppLog_FileMinimumLevelFiltersOnlyFile;
var
  content, logFileName: string;
  settings: TLoggingSettings;
begin
  settings := DefaultLoggingSettings;
  settings.FileMinimumLevel := allInfo;
  SetAppLogEvent(@ReceiveLogEntry);
  InitializeAppLogger(settings, FTempDirectory, '');

  AppLog('filtered-debug-entry', allDebug, alvDetails);
  AppLog('included-info-entry', allInfo, alvNone);
  AppLog('included-warning-entry', allWarning, alvNone);
  AppLog('included-error-entry', allError, alvNone);
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;
  content := ReadLog(logFileName);

  AssertEquals('The file threshold must not filter UI delivery', 4, FEventCount);
  AssertTrue('Debug must be excluded from the file',
    Pos('filtered-debug-entry', content) = 0);
  AssertTrue(Pos('included-info-entry', content) > 0);
  AssertTrue(Pos('included-warning-entry', content) > 0);
  AssertTrue(Pos('included-error-entry', content) > 0);
end;

procedure TAppLoggerTests.AppLog_WritesSourceAndMessage;
var
  content, logFileName: string;
begin
  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '');

  AppLog('request completed', allInfo, alvNone, alsHTTP);
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;
  content := ReadLog(logFileName);

  AssertTrue('The file line must contain the source',
    Pos(' [INFO] [HTTP] request completed', content) > 0);
end;

procedure TAppLoggerTests.AppLog_WritesExactFileLineFormat;
var
  lines: TStringList;
  logFileName: string;
  settings: TLoggingSettings;
begin
  settings := DefaultLoggingSettings;
  settings.FileTimestampFormat := '"timestamp"';
  InitializeAppLogger(settings, FTempDirectory, '');

  AppLog('format-check', allError, alvNone, alsImport);
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;

  lines := TStringList.Create;
  try
    lines.LoadFromFile(logFileName);
    AssertTrue('Unexpected file log line format',
      lines.IndexOf('timestamp [ERROR] [Import] format-check') >= 0);
  finally
    lines.Free;
  end;
end;

procedure TAppLoggerTests.AppLog_WritesFullTimestampWithMilliseconds;
var
  content, timestamp, logFileName, line: string;
  lines: TStringList;
  i, timestampStart: integer;
begin
  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '');
  AppLog('timestamp-check');
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;
  content := ReadLog(logFileName);
  line := '';
  lines := TStringList.Create;
  try
    lines.Text := content;
    for i := 0 to lines.Count - 1 do
      if Pos('timestamp-check', lines[i]) > 0 then
      begin
        line := lines[i];
        Break;
      end;
  finally
    lines.Free;
  end;
  AssertTrue('The timestamp test entry must be present', line <> '');
  timestampStart := 1;
  timestamp := Copy(line, timestampStart, 23);

  AssertEquals('Timestamp must use yyyy-mm-dd hh:nn:ss.zzz', 23,
    Length(timestamp));
  AssertTrue((timestamp[5] = '-') and (timestamp[8] = '-') and
    (timestamp[11] = ' ') and (timestamp[14] = ':') and
    (timestamp[17] = ':') and (timestamp[20] = '.'));
  AssertEquals(' [INFO] [Application] timestamp-check',
    Copy(line, 24, MaxInt));
end;

procedure TAppLoggerTests.AppLog_PreservesCyrillicText;
const
  MESSAGE_TEXT = 'Программа запущена';
var
  logFileName: string;
begin
  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '');
  AppLog(MESSAGE_TEXT);
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;

  AssertTrue(Pos(MESSAGE_TEXT, ReadLog(logFileName)) > 0);
end;

procedure TAppLoggerTests.Initialize_UnavailablePrimaryUsesFallback;
var
  blockingFile, fallbackDirectory: string;
  fileStream: TFileStream;
begin
  ForceDirectories(FTempDirectory);
  blockingFile := IncludeTrailingPathDelimiter(FTempDirectory) + 'not-a-directory';
  fileStream := TFileStream.Create(blockingFile, fmCreate);
  fileStream.Free;
  fallbackDirectory := IncludeTrailingPathDelimiter(FTempDirectory) + 'fallback';

  InitializeAppLogger(DefaultLoggingSettings,
    IncludeTrailingPathDelimiter(blockingFile) + 'logs', fallbackDirectory);

  AssertTrue(FileExists(CurrentAppLogFileName));
  AssertEquals(IncludeTrailingPathDelimiter(fallbackDirectory),
    IncludeTrailingPathDelimiter(ExtractFilePath(CurrentAppLogFileName)));
end;

procedure TAppLoggerTests.Initialize_FallbackNoticeDeliveredOnceAfterUiConnects;
var
  blockingFile, fallbackDirectory: string;
  fileStream: TFileStream;
begin
  ForceDirectories(FTempDirectory);
  blockingFile := IncludeTrailingPathDelimiter(FTempDirectory) + 'not-a-directory';
  fileStream := TFileStream.Create(blockingFile, fmCreate);
  fileStream.Free;
  fallbackDirectory := IncludeTrailingPathDelimiter(FTempDirectory) + 'fallback';
  InitializeAppLogger(DefaultLoggingSettings,
    IncludeTrailingPathDelimiter(blockingFile) + 'logs', fallbackDirectory);

  SetAppLogEvent(@ReceiveLogEntry);
  SetAppLogEvent(nil);
  SetAppLogEvent(@ReceiveLogEntry);

  AssertEquals('Fallback notice must be delivered only once', 1, FEventCount);
  AssertEquals(Ord(alvDetails), Ord(FLastEntry.View));
  AssertTrue(Pos(CurrentAppLogFileName, FLastEntry.MessageText) > 0);
end;

procedure TAppLoggerTests.Initialize_BothDirectoriesUnavailableDoesNotRaise;
var
  blockingFile: string;
  fileStream: TFileStream;
begin
  ForceDirectories(FTempDirectory);
  blockingFile := IncludeTrailingPathDelimiter(FTempDirectory) + 'not-a-directory';
  fileStream := TFileStream.Create(blockingFile, fmCreate);
  fileStream.Free;

  InitializeAppLogger(DefaultLoggingSettings,
    IncludeTrailingPathDelimiter(blockingFile) + 'primary',
    IncludeTrailingPathDelimiter(blockingFile) + 'fallback');
  AppLog('application-continues');

  AssertEquals('', CurrentAppLogFileName);
end;

procedure TAppLoggerTests.Initialize_BothDirectoriesUnavailableNotifiesUiOnce;
var
  blockingFile: string;
  fileStream: TFileStream;
begin
  ForceDirectories(FTempDirectory);
  blockingFile := IncludeTrailingPathDelimiter(FTempDirectory) + 'not-a-directory';
  fileStream := TFileStream.Create(blockingFile, fmCreate);
  fileStream.Free;
  InitializeAppLogger(DefaultLoggingSettings,
    IncludeTrailingPathDelimiter(blockingFile) + 'primary',
    IncludeTrailingPathDelimiter(blockingFile) + 'fallback');

  SetAppLogEvent(@ReceiveLogEntry);
  SetAppLogEvent(nil);
  SetAppLogEvent(@ReceiveLogEntry);

  AssertEquals('File error notice must be delivered only once', 1, FEventCount);
  AssertEquals(Ord(allWarning), Ord(FLastEntry.Level));
  AssertEquals(Ord(alvDetails), Ord(FLastEntry.View));
end;

procedure TAppLoggerTests.Initialize_StartupNoticeDeliveredOnceAfterUiConnects;
const
  STARTUP_NOTICE = 'Unable to read logging settings';
begin
  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '',
    STARTUP_NOTICE);

  SetAppLogEvent(@ReceiveLogEntry);
  SetAppLogEvent(nil);
  SetAppLogEvent(@ReceiveLogEntry);

  AssertEquals('Startup notice must be delivered only once', 1, FEventCount);
  AssertEquals(Ord(allWarning), Ord(FLastEntry.Level));
  AssertEquals(Ord(alvDetails), Ord(FLastEntry.View));
  AssertEquals(STARTUP_NOTICE, FLastEntry.MessageText);
end;

procedure TAppLoggerTests.AppLog_AfterFinalizeIsSafe;
begin
  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '');
  FinalizeAppLogger;

  AppLog('late-entry', allInfo, alvNone);

  AssertTrue(True);
end;

procedure TAppLoggerTests.AppLog_ParallelWritesKeepLinesIntact;
const
  ENTRY_COUNT = 50;
var
  firstThread, secondThread: TLogWriterThread;
  content: TStringList;
  i, loggedLineCount: integer;
  logFileName: string;
begin
  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '');
  firstThread := TLogWriterThread.Create('THREAD-A', ENTRY_COUNT);
  secondThread := TLogWriterThread.Create('THREAD-B', ENTRY_COUNT);
  try
    firstThread.Start;
    secondThread.Start;
    firstThread.WaitFor;
    secondThread.WaitFor;
  finally
    firstThread.Free;
    secondThread.Free;
  end;
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;

  content := TStringList.Create;
  try
    content.Text := ReadLog(logFileName);
    loggedLineCount := 0;
    for i := 0 to content.Count - 1 do
      if (Pos('THREAD-A-', content[i]) > 0) or
        (Pos('THREAD-B-', content[i]) > 0) then
      begin
        Inc(loggedLineCount);
        AssertTrue('Each physical line must contain one complete entry',
          (Pos('THREAD-A-', content[i]) > 0) xor
          (Pos('THREAD-B-', content[i]) > 0));
        AssertTrue('The entry terminator must stay on the same line',
          Pos('-END', content[i]) > 0);
      end;
    AssertEquals(ENTRY_COUNT * 2, loggedLineCount);
    for i := 1 to ENTRY_COUNT do
    begin
      AssertTrue(Pos(Format('THREAD-A-%d-END', [i]), content.Text) > 0);
      AssertTrue(Pos(Format('THREAD-B-%d-END', [i]), content.Text) > 0);
    end;
  finally
    content.Free;
  end;
end;

procedure TAppLoggerTests.Initialize_RemovesOnlyExpiredMatchingLogs;
var
  settings: TLoggingSettings;
  fallbackDirectory, oldFallbackLog, oldLog, oldOtherLog, newLog,
    unrelatedFile: string;
  fileStream: TFileStream;
  oldAge: TDateTime;
begin
  ForceDirectories(FTempDirectory);
  oldLog := IncludeTrailingPathDelimiter(FTempDirectory) +
    'entime-2000-01-01_00-00-00-1.log';
  newLog := IncludeTrailingPathDelimiter(FTempDirectory) +
    'entime-2099-01-01_00-00-00-2.log';
  oldOtherLog := IncludeTrailingPathDelimiter(FTempDirectory) +
    'other-2000-01-01_00-00-00-3.log';
  unrelatedFile := IncludeTrailingPathDelimiter(FTempDirectory) + 'keep.txt';
  fallbackDirectory := IncludeTrailingPathDelimiter(FTempDirectory) + 'fallback';
  ForceDirectories(fallbackDirectory);
  oldFallbackLog := IncludeTrailingPathDelimiter(fallbackDirectory) +
    'entime-2000-01-01_00-00-00-4.log';
  fileStream := TFileStream.Create(oldLog, fmCreate);
  fileStream.Free;
  fileStream := TFileStream.Create(newLog, fmCreate);
  fileStream.Free;
  fileStream := TFileStream.Create(oldOtherLog, fmCreate);
  fileStream.Free;
  fileStream := TFileStream.Create(unrelatedFile, fmCreate);
  fileStream.Free;
  fileStream := TFileStream.Create(oldFallbackLog, fmCreate);
  fileStream.Free;
  oldAge := IncDay(Now, -31);
  FileSetDate(oldLog, DateTimeToFileDate(oldAge));
  FileSetDate(oldOtherLog, DateTimeToFileDate(oldAge));
  FileSetDate(oldFallbackLog, DateTimeToFileDate(oldAge));

  settings := DefaultLoggingSettings;
  settings.RetentionDays := 30;
  InitializeAppLogger(settings, FTempDirectory, fallbackDirectory);

  AssertFalse('Expired Entime logs must be deleted', FileExists(oldLog));
  AssertFalse('Expired fallback logs must be deleted',
    FileExists(oldFallbackLog));
  AssertTrue('New Entime logs must be retained', FileExists(newLog));
  AssertTrue('Logs with another prefix must be retained',
    FileExists(oldOtherLog));
  AssertTrue('Unrelated files must be retained', FileExists(unrelatedFile));
  AssertTrue('The current log must never be deleted',
    FileExists(CurrentAppLogFileName));
end;

procedure TAppLoggerTests.LogUnhandledException_WritesExceptionAndStackTrace;
var
  content, logFileName: string;
begin
  InitializeAppLogger(DefaultLoggingSettings, FTempDirectory, '');
  try
    raise Exception.Create('unhandled-test-message');
  except
    on E: Exception do
      LogUnhandledException(E);
  end;
  logFileName := CurrentAppLogFileName;
  FinalizeAppLogger;
  content := ReadLog(logFileName);

  AssertTrue(Pos('[Application] Unhandled exception Exception: ' +
    'unhandled-test-message', content) > 0);
  AssertTrue('The exception address must be written as a stack trace',
    Pos('[Application] Stack trace:', content) > 0);
  AssertTrue('The unhandled exception must keep the error level',
    Pos('[ERROR] [Application] Unhandled exception Exception: ' +
    'unhandled-test-message', content) > 0);
  AssertTrue('Stack trace lines must use the debug level',
    Pos('[DEBUG] [Application] Stack trace:', content) > 0);
  AssertFalse('Stack trace lines must not create additional errors',
    Pos('[ERROR] [Application] Stack trace:', content) > 0);
end;

initialization
  RegisterTest(TAppLoggerTests);

end.
