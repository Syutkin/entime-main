unit CompetitionBackupService;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, SyncObjs;

const
  DEFAULT_AUTOMATIC_BACKUP_RECENT_HOURS = 24;
  DEFAULT_AUTOMATIC_BACKUP_RETENTION_DAYS = 30;
  DEFAULT_AUTOMATIC_BACKUP_MAX_SIZE_MB = 2048;
  DEFAULT_SAFETY_BACKUP_FULL_RETENTION_DAYS = 30;
  DEFAULT_SAFETY_BACKUP_WEEKLY_RETENTION_DAYS = 180;
  DEFAULT_SAFETY_BACKUP_MIN_COPIES = 5;
  DEFAULT_SAFETY_BACKUP_MAX_SIZE_MB = 5120;

type
  TCompetitionBackupStatus = (cbsCreated, cbsFailed, cbsCancelled,
    cbsSkipped);
  TCompetitionBackupFailure = (cbfNone, cbfInvalidSource,
    cbfDirectoryCreate, cbfCreate, cbfInvalidFile);
  TCompetitionBackupKind = (cbkAutomatic, cbkManual, cbkSafety);
  TCompetitionBackupReason = (cbrNone, cbrBeforeImport, cbrBeforeClear,
    cbrBeforeMigration, cbrBeforeStageExpansion);

  TBackupCleanupResult = record
    DeletedCount: integer;
    FreedBytes: Int64;
    WarningMessage: string;
  end;

  TBackupRetentionPolicy = record
    AutomaticRecentHours: integer;
    AutomaticRetentionDays: integer;
    AutomaticMaxTotalBytes: Int64;
    SafetyFullRetentionDays: integer;
    SafetyWeeklyRetentionDays: integer;
    SafetyMinCopies: integer;
    SafetyMaxTotalBytes: Int64;
  end;

  TCompetitionBackupRequest = record
    DatabaseFile: string;
    BackupTime: TDateTime;
    Kind: TCompetitionBackupKind;
    Reason: TCompetitionBackupReason;
    RetentionPolicy: TBackupRetentionPolicy;
  end;

  TCompetitionBackupResult = record
    Status: TCompetitionBackupStatus;
    Failure: TCompetitionBackupFailure;
    BackupFileName: string;
    ErrorMessage: string;
    Cleanup: TBackupCleanupResult;
  end;

  TCompetitionBackupAction = function(
    const ARequest: TCompetitionBackupRequest): TCompetitionBackupResult;
  TCompetitionBackupCompletedEvent = procedure(Sender: TObject;
    const AResult: TCompetitionBackupResult) of object;

  TCompetitionBackupCoordinator = class
  private
    FActive: boolean;
    FIdleEvent: TEvent;
    FLock: TCriticalSection;
    FPriorityWaiters: integer;
    procedure BeginPriorityOperation;
    procedure EndOperation;
    function TryBeginAutomaticOperation: boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Busy: boolean;
    function Execute(const ARequest: TCompetitionBackupRequest;
      AAction: TCompetitionBackupAction): TCompetitionBackupResult;
    procedure WaitForIdle;
  end;

  TCompetitionBackupService = record
  public
    class function CreateBackup(const ADatabaseFile: string;
      const ABackupTime: TDateTime): TCompetitionBackupResult; static; overload;
    class function CreateBackup(const ARequest: TCompetitionBackupRequest):
      TCompetitionBackupResult; static; overload;
  end;

  TCompetitionBackupThread = class(TThread)
  private
    FAction: TCompetitionBackupAction;
    FCoordinator: TCompetitionBackupCoordinator;
    FOnFinished: TThreadMethod;
    FRequest: TCompetitionBackupRequest;
    FResult: TCompetitionBackupResult;
  protected
    procedure Execute; override;
  public
    constructor Create(AAction: TCompetitionBackupAction;
      const ARequest: TCompetitionBackupRequest; AOnFinished: TThreadMethod;
      ACoordinator: TCompetitionBackupCoordinator);
    procedure Cancel;
    property BackupResult: TCompetitionBackupResult read FResult;
  end;

  TCompetitionBackupController = class
  private
    FAction: TCompetitionBackupAction;
    FCoordinator: TCompetitionBackupCoordinator;
    FOnCompleted: TCompetitionBackupCompletedEvent;
    FWorker: TCompetitionBackupThread;
    procedure WorkerFinished;
  public
    constructor Create(AAction: TCompetitionBackupAction;
      AOnCompleted: TCompetitionBackupCompletedEvent;
      ACoordinator: TCompetitionBackupCoordinator = nil);
    destructor Destroy; override;
    function Start(const ARequest: TCompetitionBackupRequest): boolean; overload;
    function Start(const ADatabaseFile: string; const ABackupTime: TDateTime):
      boolean; overload;
    function Start(const ADatabaseFile: string; const ABackupTime: TDateTime;
      const ARetentionPolicy: TBackupRetentionPolicy): boolean; overload;
    procedure Cancel;
    function Busy: boolean;
  end;

function DefaultBackupRetentionPolicy: TBackupRetentionPolicy;
function DefaultCompetitionBackupCoordinator: TCompetitionBackupCoordinator;
function NewCompetitionBackupRequest(const ADatabaseFile: string;
  const ABackupTime: TDateTime; const AKind: TCompetitionBackupKind;
  const AReason: TCompetitionBackupReason;
  const ARetentionPolicy: TBackupRetentionPolicy): TCompetitionBackupRequest;

implementation

uses
  DateUtils, StrUtils, LazFileUtils, DbSql, CompetitionDbContext;

const
  BACKUP_BUSY_TIMEOUT_MS = DEFAULT_SQLITE_BUSY_TIMEOUT_MS;
  BackupFolder = 'backup';
  Megabyte = Int64(1024) * 1024;

type
  TBackupFileInfo = record
    FileName: string;
    CreatedAt: TDateTime;
    Size: Int64;
    Keep: boolean;
    IsNew: boolean;
    DeleteAttempted: boolean;
    Deleted: boolean;
  end;

  TBackupFileInfoArray = array of TBackupFileInfo;

var
  GDefaultBackupCoordinator: TCompetitionBackupCoordinator;

function DefaultCompetitionBackupCoordinator: TCompetitionBackupCoordinator;
begin
  Result := GDefaultBackupCoordinator;
end;

function DefaultBackupRetentionPolicy: TBackupRetentionPolicy;
begin
  Result.AutomaticRecentHours := DEFAULT_AUTOMATIC_BACKUP_RECENT_HOURS;
  Result.AutomaticRetentionDays := DEFAULT_AUTOMATIC_BACKUP_RETENTION_DAYS;
  Result.AutomaticMaxTotalBytes :=
    Int64(DEFAULT_AUTOMATIC_BACKUP_MAX_SIZE_MB) * Megabyte;
  Result.SafetyFullRetentionDays :=
    DEFAULT_SAFETY_BACKUP_FULL_RETENTION_DAYS;
  Result.SafetyWeeklyRetentionDays :=
    DEFAULT_SAFETY_BACKUP_WEEKLY_RETENTION_DAYS;
  Result.SafetyMinCopies := DEFAULT_SAFETY_BACKUP_MIN_COPIES;
  Result.SafetyMaxTotalBytes :=
    Int64(DEFAULT_SAFETY_BACKUP_MAX_SIZE_MB) * Megabyte;
end;

function NewCompetitionBackupRequest(const ADatabaseFile: string;
  const ABackupTime: TDateTime; const AKind: TCompetitionBackupKind;
  const AReason: TCompetitionBackupReason;
  const ARetentionPolicy: TBackupRetentionPolicy): TCompetitionBackupRequest;
begin
  Result.DatabaseFile := ADatabaseFile;
  Result.BackupTime := ABackupTime;
  Result.Kind := AKind;
  Result.Reason := AReason;
  Result.RetentionPolicy := ARetentionPolicy;
end;

function FailedBackup(const AFailure: TCompetitionBackupFailure;
  const AFileName, AMessage: string): TCompetitionBackupResult;
begin
  Result := Default(TCompetitionBackupResult);
  Result.Status := cbsFailed;
  Result.Failure := AFailure;
  Result.BackupFileName := AFileName;
  Result.ErrorMessage := AMessage;
end;

function SkippedBackup: TCompetitionBackupResult;
begin
  Result := Default(TCompetitionBackupResult);
  Result.Status := cbsSkipped;
  Result.Failure := cbfNone;
end;

{ TCompetitionBackupCoordinator }

constructor TCompetitionBackupCoordinator.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FIdleEvent := TEvent.Create(nil, True, True, '');
end;

destructor TCompetitionBackupCoordinator.Destroy;
begin
  WaitForIdle;
  FIdleEvent.Free;
  FLock.Free;
  inherited Destroy;
end;

function TCompetitionBackupCoordinator.TryBeginAutomaticOperation: boolean;
begin
  FLock.Acquire;
  try
    Result := not FActive and (FPriorityWaiters = 0);
    if Result then
    begin
      FActive := True;
      FIdleEvent.ResetEvent;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TCompetitionBackupCoordinator.BeginPriorityOperation;
var
  Acquired: boolean;
begin
  FLock.Acquire;
  try
    Inc(FPriorityWaiters);
  finally
    FLock.Release;
  end;

  try
    repeat
      if FIdleEvent.WaitFor(INFINITE) <> wrSignaled then
        raise ESyncObjectException.Create(
          'Failed while waiting for the backup coordinator');
      Acquired := False;
      FLock.Acquire;
      try
        if not FActive then
        begin
          FActive := True;
          Dec(FPriorityWaiters);
          FIdleEvent.ResetEvent;
          Acquired := True;
        end;
      finally
        FLock.Release;
      end;
    until Acquired;
  except
    FLock.Acquire;
    try
      Dec(FPriorityWaiters);
      if not FActive then
        FIdleEvent.SetEvent;
    finally
      FLock.Release;
    end;
    raise;
  end;
end;

procedure TCompetitionBackupCoordinator.EndOperation;
begin
  FLock.Acquire;
  try
    FActive := False;
    FIdleEvent.SetEvent;
  finally
    FLock.Release;
  end;
end;

function TCompetitionBackupCoordinator.Execute(
  const ARequest: TCompetitionBackupRequest;
  AAction: TCompetitionBackupAction): TCompetitionBackupResult;
var
  OperationStarted: boolean;
begin
  if ARequest.Kind = cbkAutomatic then
  begin
    OperationStarted := TryBeginAutomaticOperation;
    if not OperationStarted then
      Exit(SkippedBackup);
  end
  else
  begin
    BeginPriorityOperation;
    OperationStarted := True;
  end;

  try
    if not Assigned(AAction) then
      Result := FailedBackup(cbfCreate, '',
        'Backup action is not configured')
    else
      Result := AAction(ARequest);
  finally
    if OperationStarted then
      EndOperation;
  end;
end;

function TCompetitionBackupCoordinator.Busy: boolean;
begin
  FLock.Acquire;
  try
    Result := FActive or (FPriorityWaiters > 0);
  finally
    FLock.Release;
  end;
end;

procedure TCompetitionBackupCoordinator.WaitForIdle;
var
  IsIdle: boolean;
begin
  repeat
    FLock.Acquire;
    try
      IsIdle := not FActive and (FPriorityWaiters = 0);
    finally
      FLock.Release;
    end;
    if not IsIdle then
    begin
      FIdleEvent.WaitFor(10);
      Sleep(1);
    end;
  until IsIdle;
end;

function NonEmptyFile(const AFileName: string): boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  if not FileExists(AFileName) then
    Exit;
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    Result := Stream.Size > 0;
  finally
    Stream.Free;
  end;
end;

function BackupKindToken(const AKind: TCompetitionBackupKind): string;
begin
  case AKind of
    cbkAutomatic: Result := 'auto';
    cbkSafety: Result := 'safety';
  else
    Result := 'manual';
  end;
end;

function BackupReasonToken(const AReason: TCompetitionBackupReason): string;
begin
  case AReason of
    cbrBeforeImport: Result := 'before-import';
    cbrBeforeClear: Result := 'before-clear';
    cbrBeforeMigration: Result := 'before-migration';
    cbrBeforeStageExpansion: Result := 'before-stage-expansion';
  else
    Result := 'unspecified';
  end;
end;

function BackupFilePrefix(const AKind: TCompetitionBackupKind;
  const AReason: TCompetitionBackupReason): string;
begin
  Result := BackupKindToken(AKind);
  if AKind = cbkSafety then
    Result := Result + '_' + BackupReasonToken(AReason);
end;

function UniqueBackupFileName(const ABackupDirectory, ASourceFileName: string;
  const ABackupTime: TDateTime; const AKind: TCompetitionBackupKind;
  const AReason: TCompetitionBackupReason): string;
var
  BaseName, Candidate, CollisionSuffix: string;
  CollisionIndex: integer;
begin
  BaseName := BackupFilePrefix(AKind, AReason) + '_' +
    FormatDateTime('yyyy-mm-dd_hh-nn-ss-zzz', ABackupTime);
  CollisionIndex := 0;
  repeat
    if CollisionIndex = 0 then
      CollisionSuffix := ''
    else
      CollisionSuffix := '_' + IntToStr(CollisionIndex);
    Candidate := IncludeTrailingPathDelimiter(ABackupDirectory) + BaseName +
      CollisionSuffix + ' ' + ASourceFileName;
    Inc(CollisionIndex);
  until not FileExists(Candidate);
  Result := Candidate;
end;

function IsDigitAt(const AValue: string; const AIndex: integer): boolean;
begin
  Result := (AIndex >= 1) and (AIndex <= Length(AValue)) and
    (AValue[AIndex] in ['0'..'9']);
end;

function TryParseTimestampAt(const AValue: string; const AStart: integer;
  out ATimestamp: TDateTime): boolean;
var
  Day, Hour, Millisecond, Minute, Month, Second, Year: integer;
begin
  Result := False;
  if AStart + 22 > Length(AValue) then
    Exit;
  if not (IsDigitAt(AValue, AStart) and
    IsDigitAt(AValue, AStart + 1) and IsDigitAt(AValue, AStart + 2) and
    IsDigitAt(AValue, AStart + 3) and (AValue[AStart + 4] = '-') and
    IsDigitAt(AValue, AStart + 5) and IsDigitAt(AValue, AStart + 6) and
    (AValue[AStart + 7] = '-') and IsDigitAt(AValue, AStart + 8) and
    IsDigitAt(AValue, AStart + 9) and (AValue[AStart + 10] = '_') and
    IsDigitAt(AValue, AStart + 11) and IsDigitAt(AValue, AStart + 12) and
    (AValue[AStart + 13] = '-') and IsDigitAt(AValue, AStart + 14) and
    IsDigitAt(AValue, AStart + 15) and (AValue[AStart + 16] = '-') and
    IsDigitAt(AValue, AStart + 17) and IsDigitAt(AValue, AStart + 18) and
    (AValue[AStart + 19] = '-') and IsDigitAt(AValue, AStart + 20) and
    IsDigitAt(AValue, AStart + 21) and IsDigitAt(AValue, AStart + 22)) then
    Exit;
  if not TryStrToInt(Copy(AValue, AStart, 4), Year) then
    Exit;
  if not TryStrToInt(Copy(AValue, AStart + 5, 2), Month) then
    Exit;
  if not TryStrToInt(Copy(AValue, AStart + 8, 2), Day) then
    Exit;
  if not TryStrToInt(Copy(AValue, AStart + 11, 2), Hour) then
    Exit;
  if not TryStrToInt(Copy(AValue, AStart + 14, 2), Minute) then
    Exit;
  if not TryStrToInt(Copy(AValue, AStart + 17, 2), Second) then
    Exit;
  if not TryStrToInt(Copy(AValue, AStart + 20, 3), Millisecond) then
    Exit;
  Result := TryEncodeDateTime(Year, Month, Day, Hour, Minute, Second,
    Millisecond, ATimestamp);
end;

function TryExtractBackupTimestamp(const AFileName: string;
  out ATimestamp: TDateTime): boolean;
var
  Index: integer;
begin
  Result := False;
  for Index := 1 to Length(AFileName) - 22 do
    if TryParseTimestampAt(AFileName, Index, ATimestamp) then
      Exit(True);
end;

procedure AppendBackupFile(var AFiles: TBackupFileInfoArray;
  const AFileName: string; const ACreatedAt: TDateTime; const ASize: Int64;
  const AIsNew: boolean);
var
  Index: integer;
begin
  Index := Length(AFiles);
  SetLength(AFiles, Index + 1);
  AFiles[Index] := Default(TBackupFileInfo);
  AFiles[Index].FileName := AFileName;
  AFiles[Index].CreatedAt := ACreatedAt;
  AFiles[Index].Size := ASize;
  AFiles[Index].IsNew := AIsNew;
end;

procedure SortBackupFilesNewestFirst(var AFiles: TBackupFileInfoArray);
var
  Current: TBackupFileInfo;
  I, J: integer;
begin
  for I := 1 to High(AFiles) do
  begin
    Current := AFiles[I];
    J := I - 1;
    while (J >= 0) and (AFiles[J].CreatedAt < Current.CreatedAt) do
    begin
      AFiles[J + 1] := AFiles[J];
      Dec(J);
    end;
    AFiles[J + 1] := Current;
  end;
end;

function BackupKindFilePrefix(const AKind: TCompetitionBackupKind): string;
begin
  Result := BackupKindToken(AKind) + '_';
end;

function CollectBackupFiles(const ABackupDirectory, ASourceFile,
  ANewBackupFile: string; const AKind: TCompetitionBackupKind):
  TBackupFileInfoArray;
var
  CreatedAt: TDateTime;
  FullName, SourceSuffix: string;
  Search: TSearchRec;
begin
  Result := nil;
  SourceSuffix := ' ' + ExtractFileName(ASourceFile);
  if FindFirst(IncludeTrailingPathDelimiter(ABackupDirectory) + '*',
    faAnyFile, Search) <> 0 then
    Exit;
  try
    repeat
      if (Search.Name = '.') or (Search.Name = '..') or
        ((Search.Attr and faDirectory) <> 0) or
        (not StartsStr(BackupKindFilePrefix(AKind), Search.Name)) or
        (not EndsStr(SourceSuffix, Search.Name)) or
        (not TryExtractBackupTimestamp(Search.Name, CreatedAt)) then
        Continue;
      FullName := IncludeTrailingPathDelimiter(ABackupDirectory) + Search.Name;
      if FileIsSymlink(FullName) then
        Continue;
      AppendBackupFile(Result, FullName, CreatedAt, Search.Size,
        SameFileName(FullName, ANewBackupFile));
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  SortBackupFilesNewestFirst(Result);
end;

procedure AppendCleanupWarning(var AResult: TBackupCleanupResult;
  const AMessage: string);
begin
  if AResult.WarningMessage <> '' then
    AResult.WarningMessage := AResult.WarningMessage + LineEnding;
  AResult.WarningMessage := AResult.WarningMessage + AMessage;
end;

function DeleteBackupFile(var AFile: TBackupFileInfo;
  var AResult: TBackupCleanupResult): boolean;
begin
  AFile.DeleteAttempted := True;
  Result := DeleteFile(AFile.FileName);
  if Result then
  begin
    AFile.Deleted := True;
    Inc(AResult.DeletedCount);
    Inc(AResult.FreedBytes, AFile.Size);
  end
  else
    AppendCleanupWarning(AResult,
      'Cannot delete expired backup file: ' + AFile.FileName);
end;

function BackupAgeDays(const ANow, ACreatedAt: TDateTime): double;
begin
  Result := ANow - ACreatedAt;
  if Result < 0 then
    Result := 0;
end;

function CalendarWeekKey(const AValue: TDateTime): string;
var
  Week, WeekYear: word;
begin
  Week := WeekOfTheYear(AValue, WeekYear);
  Result := Format('%d-%.2d', [WeekYear, Week]);
end;

procedure MarkAutomaticBackupsToKeep(var AFiles: TBackupFileInfoArray;
  const ANow: TDateTime; const APolicy: TBackupRetentionPolicy);
var
  AgeDays: double;
  DayKey: string;
  I: integer;
  KeptDays: TStringList;
begin
  KeptDays := TStringList.Create;
  try
    KeptDays.Sorted := True;
    KeptDays.Duplicates := dupIgnore;
    for I := 0 to High(AFiles) do
    begin
      AgeDays := BackupAgeDays(ANow, AFiles[I].CreatedAt);
      AFiles[I].Keep := AFiles[I].IsNew or
        (AgeDays * HoursPerDay <= APolicy.AutomaticRecentHours);
      if (not AFiles[I].Keep) and
        (AgeDays <= APolicy.AutomaticRetentionDays) then
      begin
        DayKey := FormatDateTime('yyyy-mm-dd', AFiles[I].CreatedAt);
        if KeptDays.IndexOf(DayKey) < 0 then
        begin
          KeptDays.Add(DayKey);
          AFiles[I].Keep := True;
        end;
      end;
    end;
    if Length(AFiles) > 0 then
      AFiles[0].Keep := True;
  finally
    KeptDays.Free;
  end;
end;

procedure MarkSafetyBackupsToKeep(var AFiles: TBackupFileInfoArray;
  const ANow: TDateTime; const APolicy: TBackupRetentionPolicy);
var
  AgeDays: double;
  I: integer;
  KeptWeeks: TStringList;
  WeekKey: string;
begin
  KeptWeeks := TStringList.Create;
  try
    KeptWeeks.Sorted := True;
    KeptWeeks.Duplicates := dupIgnore;
    for I := 0 to High(AFiles) do
    begin
      AgeDays := BackupAgeDays(ANow, AFiles[I].CreatedAt);
      AFiles[I].Keep := AFiles[I].IsNew or
        (I < APolicy.SafetyMinCopies) or
        (AgeDays <= APolicy.SafetyFullRetentionDays);
      if (not AFiles[I].Keep) and
        (AgeDays <= APolicy.SafetyWeeklyRetentionDays) then
      begin
        WeekKey := CalendarWeekKey(AFiles[I].CreatedAt);
        if KeptWeeks.IndexOf(WeekKey) < 0 then
        begin
          KeptWeeks.Add(WeekKey);
          AFiles[I].Keep := True;
        end;
      end;
    end;
    if Length(AFiles) > 0 then
      AFiles[0].Keep := True;
  finally
    KeptWeeks.Free;
  end;
end;

function TotalRemainingSize(const AFiles: TBackupFileInfoArray): Int64;
var
  I: integer;
begin
  Result := 0;
  for I := 0 to High(AFiles) do
    if not AFiles[I].Deleted then
      Inc(Result, AFiles[I].Size);
end;

function IsQuotaProtected(const AFiles: TBackupFileInfoArray;
  const AIndex: integer; const AKind: TCompetitionBackupKind;
  const APolicy: TBackupRetentionPolicy): boolean;
begin
  Result := AFiles[AIndex].IsNew or (AIndex = 0);
  if (not Result) and (AKind = cbkSafety) then
    Result := AIndex < APolicy.SafetyMinCopies;
end;

procedure EnforceSizeQuota(var AFiles: TBackupFileInfoArray;
  const AKind: TCompetitionBackupKind; const APolicy: TBackupRetentionPolicy;
  var AResult: TBackupCleanupResult);
var
  I: integer;
  MaxBytes, TotalBytes: Int64;
begin
  if AKind = cbkAutomatic then
    MaxBytes := APolicy.AutomaticMaxTotalBytes
  else
    MaxBytes := APolicy.SafetyMaxTotalBytes;
  if MaxBytes <= 0 then
    Exit;

  TotalBytes := TotalRemainingSize(AFiles);
  for I := High(AFiles) downto 0 do
  begin
    if TotalBytes <= MaxBytes then
      Break;
    if AFiles[I].Deleted or AFiles[I].DeleteAttempted or
      IsQuotaProtected(AFiles, I, AKind, APolicy) then
      Continue;
    if DeleteBackupFile(AFiles[I], AResult) then
      Dec(TotalBytes, AFiles[I].Size);
  end;
  if TotalBytes > MaxBytes then
    AppendCleanupWarning(AResult, Format(
      'Backup quota remains exceeded: %d bytes used, %d bytes allowed',
      [TotalBytes, MaxBytes]));
end;

function CleanupBackups(const ABackupDirectory, ASourceFile,
  ANewBackupFile: string; const AKind: TCompetitionBackupKind;
  const ANow: TDateTime; const APolicy: TBackupRetentionPolicy):
  TBackupCleanupResult;
var
  Files: TBackupFileInfoArray;
  I: integer;
begin
  Result := Default(TBackupCleanupResult);
  if not (AKind in [cbkAutomatic, cbkSafety]) then
    Exit;
  try
    Files := CollectBackupFiles(ABackupDirectory, ASourceFile,
      ANewBackupFile, AKind);
    if AKind = cbkAutomatic then
      MarkAutomaticBackupsToKeep(Files, ANow, APolicy)
    else
      MarkSafetyBackupsToKeep(Files, ANow, APolicy);
    for I := 0 to High(Files) do
      if not Files[I].Keep then
        DeleteBackupFile(Files[I], Result);
    EnforceSizeQuota(Files, AKind, APolicy, Result);
  except
    on E: Exception do
      AppendCleanupWarning(Result, 'Backup cleanup failed: ' + E.Message);
  end;
end;

function ExecuteBackupRequestCore(const ARequest: TCompetitionBackupRequest):
  TCompetitionBackupResult;
var
  BackupDirectory, BackupFile, SourceFile: string;
  Context: TCompetitionDbContext;
begin
  SourceFile := ExpandFileName(ARequest.DatabaseFile);
  BackupDirectory := IncludeTrailingPathDelimiter(ExtractFilePath(SourceFile)) +
    BackupFolder;
  BackupFile := UniqueBackupFileName(BackupDirectory,
    ExtractFileName(SourceFile), ARequest.BackupTime, ARequest.Kind,
    ARequest.Reason);

  if (ARequest.DatabaseFile = '') or not FileExists(SourceFile) then
    Exit(FailedBackup(cbfInvalidSource, BackupFile,
      'Competition database file does not exist: ' + SourceFile));

  if not DirectoryExists(BackupDirectory) and
    not CreateDir(BackupDirectory) then
    Exit(FailedBackup(cbfDirectoryCreate, BackupFile,
      'Cannot create backup directory: ' + BackupDirectory));

  Context := TCompetitionDbContext.Create;
  try
    try
      Context.OpenFile(SourceFile);
      TSchemaSql.ExecCreateBackup(Context.Connection, BackupFile,
        BACKUP_BUSY_TIMEOUT_MS);
      if not NonEmptyFile(BackupFile) then
        Exit(FailedBackup(cbfInvalidFile, BackupFile,
          'Created backup file is missing or empty'));
      Result := Default(TCompetitionBackupResult);
      Result.Status := cbsCreated;
      Result.Failure := cbfNone;
      Result.BackupFileName := BackupFile;
      Result.Cleanup := CleanupBackups(BackupDirectory, SourceFile, BackupFile,
        ARequest.Kind, ARequest.BackupTime, ARequest.RetentionPolicy);
    except
      on E: Exception do
        Result := FailedBackup(cbfCreate, BackupFile, E.Message);
    end;
  finally
    Context.Free;
  end;
end;

class function TCompetitionBackupService.CreateBackup(
  const ADatabaseFile: string;
  const ABackupTime: TDateTime): TCompetitionBackupResult;
var
  Request: TCompetitionBackupRequest;
begin
  Request := NewCompetitionBackupRequest(ADatabaseFile, ABackupTime,
    cbkManual, cbrNone, DefaultBackupRetentionPolicy);
  Result := CreateBackup(Request);
end;

class function TCompetitionBackupService.CreateBackup(
  const ARequest: TCompetitionBackupRequest): TCompetitionBackupResult;
begin
  Result := DefaultCompetitionBackupCoordinator.Execute(ARequest,
    @ExecuteBackupRequestCore);
end;

constructor TCompetitionBackupThread.Create(AAction: TCompetitionBackupAction;
  const ARequest: TCompetitionBackupRequest; AOnFinished: TThreadMethod;
  ACoordinator: TCompetitionBackupCoordinator);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FAction := AAction;
  FCoordinator := ACoordinator;
  if not Assigned(FCoordinator) then
    FCoordinator := DefaultCompetitionBackupCoordinator;
  FRequest := ARequest;
  FOnFinished := AOnFinished;
  FResult := Default(TCompetitionBackupResult);
  FResult.Status := cbsCancelled;
end;

procedure TCompetitionBackupThread.Execute;
begin
  try
    if not Terminated then
      if Assigned(FAction) then
        FResult := FCoordinator.Execute(FRequest, FAction)
      else
        FResult := FailedBackup(cbfCreate, '',
          'Backup action is not configured');
  except
    on E: Exception do
      FResult := FailedBackup(cbfCreate, '', E.Message);
  end;

  if Terminated then
  begin
    FResult := Default(TCompetitionBackupResult);
    FResult.Status := cbsCancelled;
  end;
  if not Terminated and Assigned(FOnFinished) then
    Queue(FOnFinished);
end;

procedure TCompetitionBackupThread.Cancel;
begin
  Terminate;
end;

constructor TCompetitionBackupController.Create(
  AAction: TCompetitionBackupAction;
  AOnCompleted: TCompetitionBackupCompletedEvent;
  ACoordinator: TCompetitionBackupCoordinator);
begin
  inherited Create;
  FCoordinator := ACoordinator;
  if not Assigned(FCoordinator) then
    FCoordinator := DefaultCompetitionBackupCoordinator;
  if Assigned(AAction) then
    FAction := AAction
  else
    FAction := @ExecuteBackupRequestCore;
  FOnCompleted := AOnCompleted;
end;

destructor TCompetitionBackupController.Destroy;
begin
  Cancel;
  inherited Destroy;
end;

function TCompetitionBackupController.Start(
  const ARequest: TCompetitionBackupRequest): boolean;
begin
  Result := False;
  if Busy then
    Exit;
  FWorker := TCompetitionBackupThread.Create(FAction, ARequest,
    @WorkerFinished, FCoordinator);
  try
    FWorker.Start;
    Result := True;
  except
    FreeAndNil(FWorker);
    raise;
  end;
end;

function TCompetitionBackupController.Start(const ADatabaseFile: string;
  const ABackupTime: TDateTime): boolean;
begin
  Result := Start(ADatabaseFile, ABackupTime, DefaultBackupRetentionPolicy);
end;

function TCompetitionBackupController.Start(const ADatabaseFile: string;
  const ABackupTime: TDateTime;
  const ARetentionPolicy: TBackupRetentionPolicy): boolean;
begin
  Result := Start(NewCompetitionBackupRequest(ADatabaseFile, ABackupTime,
    cbkAutomatic, cbrNone, ARetentionPolicy));
end;

procedure TCompetitionBackupController.WorkerFinished;
var
  CompletedResult: TCompetitionBackupResult;
  CompletedWorker: TCompetitionBackupThread;
begin
  CompletedWorker := FWorker;
  if not Assigned(CompletedWorker) then
    Exit;
  CompletedWorker.WaitFor;
  CompletedResult := CompletedWorker.BackupResult;
  FWorker := nil;
  CompletedWorker.Free;
  if Assigned(FOnCompleted) then
    FOnCompleted(Self, CompletedResult);
end;

procedure TCompetitionBackupController.Cancel;
var
  ActiveWorker: TCompetitionBackupThread;
begin
  ActiveWorker := FWorker;
  if not Assigned(ActiveWorker) then
    Exit;
  TThread.RemoveQueuedEvents(ActiveWorker, @WorkerFinished);
  ActiveWorker.Cancel;
  ActiveWorker.WaitFor;
  FWorker := nil;
  ActiveWorker.Free;
end;

function TCompetitionBackupController.Busy: boolean;
begin
  Result := Assigned(FWorker);
end;

initialization
  GDefaultBackupCoordinator := TCompetitionBackupCoordinator.Create;

finalization
  FreeAndNil(GDefaultBackupCoordinator);

end.
