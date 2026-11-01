unit CompetitionBackupServiceTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpcunit, testregistry, DbSql,
  CompetitionBackupService;

type
  TCoordinatedBackupThread = class(TThread)
  private
    FAction: TCompetitionBackupAction;
    FCoordinator: TCompetitionBackupCoordinator;
    FRequest: TCompetitionBackupRequest;
    FResult: TCompetitionBackupResult;
  protected
    procedure Execute; override;
  public
    constructor Create(const ACoordinator: TCompetitionBackupCoordinator;
      const ARequest: TCompetitionBackupRequest; AAction: TCompetitionBackupAction);
    property BackupResult: TCompetitionBackupResult read FResult;
  end;

  TCompetitionBackupServiceTests = class(TTestCase)
  private
    FController: TCompetitionBackupController;
    FDatabaseFile: string;
    FTempDirectory: string;
    FCompletionCount: integer;
    FCompletionThreadId: TThreadID;
    FCompletedResult: TCompetitionBackupResult;
    function BackupDirectory: string;
    function FixtureBackupFileName(const AKind: TCompetitionBackupKind;
      const AReason: TCompetitionBackupReason; const ABackupTime: TDateTime;
      const ADatabaseFile: string; const ACollisionIndex: integer = 0): string;
    procedure CheckCleanupIsolation(const AKind: TCompetitionBackupKind;
      const AUseQuota: boolean);
    procedure BackupCompleted(Sender: TObject;
      const AResult: TCompetitionBackupResult);
    procedure CreateFixtureFile(const AFileName: string; const ASize: integer = 1);
    procedure CreateCompetitionFile;
    procedure DeleteBackupFiles;
    procedure WaitForCompletion;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure CreateBackup_CreatesTimestampedDatabaseCopy;
    procedure CreateBackup_MissingDatabaseReturnsFailure;
    procedure CreateBackup_SameMillisecondUsesUniqueNames;
    procedure AutomaticBackup_PrunesByAgeAndDayButPreservesOtherKinds;
    procedure AutomaticBackup_QuotaPreservesNewBackupAndReportsOverflow;
    procedure SafetyBackup_PreservesMinimumCopiesAndPrunesOlderFiles;
    procedure SafetyBackup_KeepsOnePerWeekWithinArchiveWindow;
    procedure FailedBackup_DoesNotPruneExistingFiles;
    procedure Cleanup_DoesNotTouchAnotherDatabase;
    procedure AutomaticBackup_AgeCleanupPreservesMatchingDatabaseSuffix;
    procedure SafetyBackup_AgeCleanupPreservesMatchingDatabaseSuffix;
    procedure AutomaticBackup_QuotaIgnoresMatchingDatabaseSuffix;
    procedure SafetyBackup_QuotaIgnoresMatchingDatabaseSuffix;
    procedure Controller_QueuesCompletionAndRejectsConcurrentStart;
    procedure Controller_CancelWaitsAndSuppressesCompletion;
    procedure Coordinator_SafetyWaitsAndAutomaticBackupsAreSkipped;
  end;

implementation

var
  FakeBackupShouldBlock: boolean;
  FakeBackupStarted: PRTLEvent;
  FakeBackupRelease: PRTLEvent;
  CoordinatedAutomaticCallCount: integer;
  CoordinatedAutomaticRelease: PRTLEvent;
  CoordinatedAutomaticStarted: PRTLEvent;
  CoordinatedSafetyCallCount: integer;
  CoordinatedSafetyRelease: PRTLEvent;
  CoordinatedSafetyStarted: PRTLEvent;

function FakeCreateBackup(const ARequest: TCompetitionBackupRequest):
TCompetitionBackupResult;
begin
  RTLEventSetEvent(FakeBackupStarted);
  if FakeBackupShouldBlock then
    RTLEventWaitFor(FakeBackupRelease);
  Result := Default(TCompetitionBackupResult);
  Result.Status := cbsCreated;
  Result.BackupFileName := ARequest.DatabaseFile + '.backup';
  Result.ErrorMessage := '';
end;

function CoordinatedFakeCreateBackup(const ARequest: TCompetitionBackupRequest):
TCompetitionBackupResult;
begin
  case ARequest.Kind of
    cbkAutomatic:
    begin
      InterlockedIncrement(CoordinatedAutomaticCallCount);
      RTLEventSetEvent(CoordinatedAutomaticStarted);
      RTLEventWaitFor(CoordinatedAutomaticRelease);
    end;
    cbkSafety:
    begin
      InterlockedIncrement(CoordinatedSafetyCallCount);
      RTLEventSetEvent(CoordinatedSafetyStarted);
      RTLEventWaitFor(CoordinatedSafetyRelease);
    end;
  end;
  Result := Default(TCompetitionBackupResult);
  Result.Status := cbsCreated;
  Result.BackupFileName := ARequest.DatabaseFile + '.backup';
end;

{ TCoordinatedBackupThread }

constructor TCoordinatedBackupThread.Create(
  const ACoordinator: TCompetitionBackupCoordinator;
  const ARequest: TCompetitionBackupRequest; AAction: TCompetitionBackupAction);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FCoordinator := ACoordinator;
  FRequest := ARequest;
  FAction := AAction;
  FResult := Default(TCompetitionBackupResult);
  FResult.Status := cbsCancelled;
end;

procedure TCoordinatedBackupThread.Execute;
begin
  FResult := FCoordinator.Execute(FRequest, FAction);
end;

function TCompetitionBackupServiceTests.BackupDirectory: string;
begin
  Result := IncludeTrailingPathDelimiter(FTempDirectory) + 'backup';
end;

function TCompetitionBackupServiceTests.FixtureBackupFileName(
  const AKind: TCompetitionBackupKind; const AReason: TCompetitionBackupReason;
  const ABackupTime: TDateTime; const ADatabaseFile: string;
  const ACollisionIndex: integer): string;
var
  Prefix: string;
begin
  case AKind of
    cbkAutomatic: Prefix := 'auto';
    cbkSafety:
      case AReason of
        cbrBeforeImport: Prefix := 'safety_before-import';
        cbrBeforeClear: Prefix := 'safety_before-clear';
        cbrBeforeMigration: Prefix := 'safety_before-migration';
        cbrBeforeStageExpansion: Prefix := 'safety_before-stage-expansion';
        else
          Prefix := 'safety_unspecified';
      end;
    else
      Prefix := 'manual';
  end;
  Result := IncludeTrailingPathDelimiter(BackupDirectory) + Prefix +
    '_' + FormatDateTime('yyyy-mm-dd_hh-nn-ss-zzz', ABackupTime);
  if ACollisionIndex > 0 then
    Result := Result + '_' + IntToStr(ACollisionIndex);
  Result := Result + ' ' + ExtractFileName(ADatabaseFile);
end;

procedure TCompetitionBackupServiceTests.CreateFixtureFile(const AFileName: string;
  const ASize: integer);
var
  ByteValue: byte;
  Stream: TFileStream;
begin
  if not DirectoryExists(BackupDirectory) then
    AssertTrue(CreateDir(BackupDirectory));
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    ByteValue := 1;
    while Stream.Size < ASize do
      Stream.WriteBuffer(ByteValue, SizeOf(ByteValue));
  finally
    Stream.Free;
  end;
end;

procedure TCompetitionBackupServiceTests.DeleteBackupFiles;
var
  Search: TSearchRec;
begin
  if not DirectoryExists(BackupDirectory) then
    Exit;
  if FindFirst(IncludeTrailingPathDelimiter(BackupDirectory) + '*',
    faAnyFile, Search) = 0 then
  try
    repeat
      if (Search.Name <> '.') and (Search.Name <> '..') and
        ((Search.Attr and faDirectory) = 0) then
        DeleteFile(IncludeTrailingPathDelimiter(BackupDirectory) + Search.Name);
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  RemoveDir(BackupDirectory);
end;

procedure TCompetitionBackupServiceTests.SetUp;
begin
  inherited SetUp;
  FTempDirectory := GetTempFileName(GetTempDir(False), 'entime-backup-');
  DeleteFile(FTempDirectory);
  AssertTrue(CreateDir(FTempDirectory));
  FDatabaseFile := IncludeTrailingPathDelimiter(FTempDirectory) +
    'competition.sqlite';
  FCompletionCount := 0;
  FCompletionThreadId := 0;
  FCompletedResult := Default(TCompetitionBackupResult);
  FakeBackupShouldBlock := False;
  FakeBackupStarted := RTLEventCreate;
  FakeBackupRelease := RTLEventCreate;
  CoordinatedAutomaticCallCount := 0;
  CoordinatedSafetyCallCount := 0;
  CoordinatedAutomaticStarted := RTLEventCreate;
  CoordinatedAutomaticRelease := RTLEventCreate;
  CoordinatedSafetyStarted := RTLEventCreate;
  CoordinatedSafetyRelease := RTLEventCreate;
end;

procedure TCompetitionBackupServiceTests.TearDown;
begin
  RTLEventSetEvent(FakeBackupRelease);
  RTLEventSetEvent(CoordinatedAutomaticRelease);
  RTLEventSetEvent(CoordinatedSafetyRelease);
  FreeAndNil(FController);
  RTLEventDestroy(FakeBackupStarted);
  RTLEventDestroy(FakeBackupRelease);
  RTLEventDestroy(CoordinatedAutomaticStarted);
  RTLEventDestroy(CoordinatedAutomaticRelease);
  RTLEventDestroy(CoordinatedSafetyStarted);
  RTLEventDestroy(CoordinatedSafetyRelease);
  DeleteBackupFiles;
  if FileExists(FDatabaseFile) then
    DeleteFile(FDatabaseFile);
  if DirectoryExists(FTempDirectory) then
    RemoveDir(FTempDirectory);
  inherited TearDown;
end;

procedure TCompetitionBackupServiceTests.CreateCompetitionFile;
var
  Context: TCompetitionDbContext;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Context := TCompetitionDbContext.Create;
  try
    Context.OpenFile(FDatabaseFile);
    UnitOfWork := Context.BeginUnitOfWork;
    try
      TSchemaSql.ExecCreateTables(Context.Connection, 2,
        'A', 'B', 'C', 'D', 'E', 'Backup test');
      UnitOfWork.Commit;
    finally
      UnitOfWork.Free;
    end;
  finally
    Context.Free;
  end;
end;

procedure TCompetitionBackupServiceTests.BackupCompleted(Sender: TObject;
  const AResult: TCompetitionBackupResult);
begin
  Inc(FCompletionCount);
  FCompletionThreadId := GetCurrentThreadID;
  FCompletedResult := AResult;
end;

procedure TCompetitionBackupServiceTests.WaitForCompletion;
var
  Deadline: QWord;
begin
  Deadline := GetTickCount64 + 2000;
  while (FCompletionCount = 0) and (GetTickCount64 < Deadline) do
  begin
    CheckSynchronize(10);
    Sleep(1);
  end;
  AssertEquals('Backup did not complete in time', 1, FCompletionCount);
end;

procedure TCompetitionBackupServiceTests.
CreateBackup_CreatesTimestampedDatabaseCopy;
var
  Result: TCompetitionBackupResult;
  BackupStream: TFileStream;
begin
  CreateCompetitionFile;

  Result := TCompetitionBackupService.CreateBackup(FDatabaseFile,
    EncodeDateTime(2026, 8, 13, 10, 11, 12, 0));

  AssertEquals(Ord(cbsCreated), Ord(Result.Status));
  AssertEquals(IncludeTrailingPathDelimiter(FTempDirectory) + 'backup' +
    DirectorySeparator + 'manual_2026-08-13_10-11-12-000 competition.sqlite',
    Result.BackupFileName);
  AssertTrue(FileExists(Result.BackupFileName));
  BackupStream := TFileStream.Create(Result.BackupFileName, fmOpenRead or
    fmShareDenyNone);
  try
    AssertTrue(BackupStream.Size > 0);
  finally
    BackupStream.Free;
  end;
  AssertEquals('', Result.ErrorMessage);
end;

procedure TCompetitionBackupServiceTests.
CreateBackup_MissingDatabaseReturnsFailure;
var
  Result: TCompetitionBackupResult;
begin
  Result := TCompetitionBackupService.CreateBackup(FDatabaseFile,
    EncodeDateTime(2026, 8, 13, 10, 11, 12, 0));

  AssertEquals(Ord(cbsFailed), Ord(Result.Status));
  AssertTrue(Result.ErrorMessage <> '');
  AssertFalse(FileExists(Result.BackupFileName));
end;

procedure TCompetitionBackupServiceTests.
CreateBackup_SameMillisecondUsesUniqueNames;
var
  FirstResult, SecondResult: TCompetitionBackupResult;
  BackupTime: TDateTime;
begin
  CreateCompetitionFile;
  BackupTime := EncodeDateTime(2026, 8, 13, 10, 11, 12, 123);

  FirstResult := TCompetitionBackupService.CreateBackup(FDatabaseFile, BackupTime);
  SecondResult := TCompetitionBackupService.CreateBackup(FDatabaseFile, BackupTime);

  AssertEquals(Ord(cbsCreated), Ord(FirstResult.Status));
  AssertEquals(Ord(cbsCreated), Ord(SecondResult.Status));
  AssertTrue(FirstResult.BackupFileName <> SecondResult.BackupFileName);
  AssertTrue(FileExists(FirstResult.BackupFileName));
  AssertTrue(FileExists(SecondResult.BackupFileName));
  AssertTrue(Pos('_1 ' + ExtractFileName(FDatabaseFile),
    SecondResult.BackupFileName) > 0);
end;

procedure TCompetitionBackupServiceTests.
AutomaticBackup_PrunesByAgeAndDayButPreservesOtherKinds;
var
  DailyKept, DailyRemoved, ExpiredAuto, ManualFile, RecentAuto, SafetyFile: string;
  Policy: TBackupRetentionPolicy;
  Request: TCompetitionBackupRequest;
  Result: TCompetitionBackupResult;
  ReferenceTime: TDateTime;
begin
  CreateCompetitionFile;
  ReferenceTime := EncodeDateTime(2026, 8, 16, 12, 0, 0, 0);
  RecentAuto := FixtureBackupFileName(cbkAutomatic, cbrNone,
    IncHour(ReferenceTime, -1), FDatabaseFile);
  DailyKept := FixtureBackupFileName(cbkAutomatic, cbrNone,
    EncodeDateTime(2026, 8, 14, 18, 0, 0, 0), FDatabaseFile);
  DailyRemoved := FixtureBackupFileName(cbkAutomatic, cbrNone,
    EncodeDateTime(2026, 8, 14, 8, 0, 0, 0), FDatabaseFile);
  ExpiredAuto := FixtureBackupFileName(cbkAutomatic, cbrNone,
    IncDay(ReferenceTime, -31), FDatabaseFile);
  ManualFile := FixtureBackupFileName(cbkManual, cbrNone,
    IncDay(ReferenceTime, -60), FDatabaseFile);
  SafetyFile := FixtureBackupFileName(cbkSafety, cbrBeforeImport,
    IncDay(ReferenceTime, -200), FDatabaseFile);
  CreateFixtureFile(RecentAuto);
  CreateFixtureFile(DailyKept);
  CreateFixtureFile(DailyRemoved);
  CreateFixtureFile(ExpiredAuto);
  CreateFixtureFile(ManualFile);
  CreateFixtureFile(SafetyFile);
  Policy := DefaultBackupRetentionPolicy;
  Policy.AutomaticMaxTotalBytes := 1024 * 1024;
  Request := NewCompetitionBackupRequest(FDatabaseFile, ReferenceTime,
    cbkAutomatic, cbrNone, Policy);

  Result := TCompetitionBackupService.CreateBackup(Request);

  AssertEquals(Ord(cbsCreated), Ord(Result.Status));
  AssertEquals(2, Result.Cleanup.DeletedCount);
  AssertTrue(FileExists(Result.BackupFileName));
  AssertTrue(FileExists(RecentAuto));
  AssertTrue(FileExists(DailyKept));
  AssertFalse(FileExists(DailyRemoved));
  AssertFalse(FileExists(ExpiredAuto));
  AssertTrue(FileExists(ManualFile));
  AssertTrue(FileExists(SafetyFile));
end;

procedure TCompetitionBackupServiceTests.
AutomaticBackup_QuotaPreservesNewBackupAndReportsOverflow;
var
  OldAuto: string;
  Policy: TBackupRetentionPolicy;
  Request: TCompetitionBackupRequest;
  Result: TCompetitionBackupResult;
  ReferenceTime: TDateTime;
begin
  CreateCompetitionFile;
  ReferenceTime := EncodeDateTime(2026, 8, 16, 12, 0, 0, 0);
  OldAuto := FixtureBackupFileName(cbkAutomatic, cbrNone,
    IncHour(ReferenceTime, -1), FDatabaseFile);
  CreateFixtureFile(OldAuto, 10);
  Policy := DefaultBackupRetentionPolicy;
  Policy.AutomaticMaxTotalBytes := 1;
  Request := NewCompetitionBackupRequest(FDatabaseFile, ReferenceTime,
    cbkAutomatic, cbrNone, Policy);

  Result := TCompetitionBackupService.CreateBackup(Request);

  AssertEquals(Ord(cbsCreated), Ord(Result.Status));
  AssertTrue(FileExists(Result.BackupFileName));
  AssertFalse(FileExists(OldAuto));
  AssertTrue('Protected new backup must report an exceeded quota',
    Pos('quota', LowerCase(Result.Cleanup.WarningMessage)) > 0);
end;

procedure TCompetitionBackupServiceTests.
SafetyBackup_PreservesMinimumCopiesAndPrunesOlderFiles;
var
  FileName: string;
  I: integer;
  Policy: TBackupRetentionPolicy;
  Request: TCompetitionBackupRequest;
  Result: TCompetitionBackupResult;
  ReferenceTime: TDateTime;
begin
  CreateCompetitionFile;
  ReferenceTime := EncodeDateTime(2026, 8, 16, 12, 0, 0, 0);
  for I := 1 to 6 do
  begin
    FileName := FixtureBackupFileName(cbkSafety, cbrBeforeImport,
      IncDay(ReferenceTime, -(200 + I)), FDatabaseFile);
    CreateFixtureFile(FileName);
  end;
  Policy := DefaultBackupRetentionPolicy;
  Policy.SafetyMaxTotalBytes := 1024 * 1024;
  Request := NewCompetitionBackupRequest(FDatabaseFile, ReferenceTime,
    cbkSafety, cbrBeforeClear, Policy);

  Result := TCompetitionBackupService.CreateBackup(Request);

  AssertEquals(Ord(cbsCreated), Ord(Result.Status));
  AssertEquals(2, Result.Cleanup.DeletedCount);
  AssertTrue(FileExists(Result.BackupFileName));
  for I := 1 to 4 do
  begin
    FileName := FixtureBackupFileName(cbkSafety, cbrBeforeImport,
      IncDay(ReferenceTime, -(200 + I)), FDatabaseFile);
    AssertTrue('Five newest safety backups must be preserved',
      FileExists(FileName));
  end;
  for I := 5 to 6 do
  begin
    FileName := FixtureBackupFileName(cbkSafety, cbrBeforeImport,
      IncDay(ReferenceTime, -(200 + I)), FDatabaseFile);
    AssertFalse(FileExists(FileName));
  end;
end;

procedure TCompetitionBackupServiceTests.
SafetyBackup_KeepsOnePerWeekWithinArchiveWindow;
var
  NewerSameWeek, OlderSameWeek, OtherWeek, Expired: string;
  Policy: TBackupRetentionPolicy;
  Request: TCompetitionBackupRequest;
  Result: TCompetitionBackupResult;
  ReferenceTime: TDateTime;
begin
  CreateCompetitionFile;
  ReferenceTime := EncodeDateTime(2026, 8, 16, 12, 0, 0, 0);
  NewerSameWeek := FixtureBackupFileName(cbkSafety, cbrBeforeImport,
    EncodeDateTime(2026, 7, 8, 18, 0, 0, 0), FDatabaseFile);
  OlderSameWeek := FixtureBackupFileName(cbkSafety, cbrBeforeClear,
    EncodeDateTime(2026, 7, 7, 8, 0, 0, 0), FDatabaseFile);
  OtherWeek := FixtureBackupFileName(cbkSafety, cbrBeforeMigration,
    EncodeDateTime(2026, 6, 30, 8, 0, 0, 0), FDatabaseFile);
  Expired := FixtureBackupFileName(cbkSafety, cbrBeforeStageExpansion,
    IncDay(ReferenceTime, -181), FDatabaseFile);
  CreateFixtureFile(NewerSameWeek);
  CreateFixtureFile(OlderSameWeek);
  CreateFixtureFile(OtherWeek);
  CreateFixtureFile(Expired);
  Policy := DefaultBackupRetentionPolicy;
  Policy.SafetyMinCopies := 1;
  Policy.SafetyMaxTotalBytes := 1024 * 1024;
  Request := NewCompetitionBackupRequest(FDatabaseFile, ReferenceTime,
    cbkSafety, cbrBeforeImport, Policy);

  Result := TCompetitionBackupService.CreateBackup(Request);

  AssertEquals(Ord(cbsCreated), Ord(Result.Status));
  AssertEquals(2, Result.Cleanup.DeletedCount);
  AssertTrue(FileExists(Result.BackupFileName));
  AssertTrue(FileExists(NewerSameWeek));
  AssertFalse(FileExists(OlderSameWeek));
  AssertTrue(FileExists(OtherWeek));
  AssertFalse(FileExists(Expired));
end;

procedure TCompetitionBackupServiceTests.
FailedBackup_DoesNotPruneExistingFiles;
var
  ExistingFile: string;
  Policy: TBackupRetentionPolicy;
  Request: TCompetitionBackupRequest;
  Result: TCompetitionBackupResult;
  ReferenceTime: TDateTime;
begin
  ReferenceTime := EncodeDateTime(2026, 8, 16, 12, 0, 0, 0);
  ExistingFile := FixtureBackupFileName(cbkAutomatic, cbrNone,
    IncDay(ReferenceTime, -60), FDatabaseFile);
  CreateFixtureFile(ExistingFile);
  Policy := DefaultBackupRetentionPolicy;
  Request := NewCompetitionBackupRequest(FDatabaseFile, ReferenceTime,
    cbkAutomatic, cbrNone, Policy);

  Result := TCompetitionBackupService.CreateBackup(Request);

  AssertEquals(Ord(cbsFailed), Ord(Result.Status));
  AssertTrue(FileExists(ExistingFile));
end;

procedure TCompetitionBackupServiceTests.
Cleanup_DoesNotTouchAnotherDatabase;
var
  OtherDatabase, OtherFile, ThisFile: string;
  Policy: TBackupRetentionPolicy;
  Request: TCompetitionBackupRequest;
  Result: TCompetitionBackupResult;
  ReferenceTime: TDateTime;
begin
  CreateCompetitionFile;
  ReferenceTime := EncodeDateTime(2026, 8, 16, 12, 0, 0, 0);
  OtherDatabase := IncludeTrailingPathDelimiter(FTempDirectory) + 'other.sqlite';
  OtherFile := FixtureBackupFileName(cbkAutomatic, cbrNone,
    IncDay(ReferenceTime, -60), OtherDatabase);
  ThisFile := FixtureBackupFileName(cbkAutomatic, cbrNone,
    IncDay(ReferenceTime, -60), FDatabaseFile);
  CreateFixtureFile(OtherFile);
  CreateFixtureFile(ThisFile);
  Policy := DefaultBackupRetentionPolicy;
  Request := NewCompetitionBackupRequest(FDatabaseFile, ReferenceTime,
    cbkAutomatic, cbrNone, Policy);

  Result := TCompetitionBackupService.CreateBackup(Request);

  AssertEquals(Ord(cbsCreated), Ord(Result.Status));
  AssertFalse(FileExists(ThisFile));
  AssertTrue(FileExists(OtherFile));
end;

procedure TCompetitionBackupServiceTests.
CheckCleanupIsolation(const AKind: TCompetitionBackupKind; const AUseQuota: boolean);
var
  OwnFiles, OtherFiles, UnrecognizedFiles: array[0..1] of string;
  OtherDatabase, ManualFile, Prefix: string;
  Policy: TBackupRetentionPolicy;
  Result: TCompetitionBackupResult;
  ReferenceTime, OwnTime, OtherTime: TDateTime;
  Stream: TFileStream;
  QuotaBytes: int64;
  I: integer;
begin
  FDatabaseFile := IncludeTrailingPathDelimiter(FTempDirectory) + 'short race.sqlite';
  OtherDatabase := IncludeTrailingPathDelimiter(FTempDirectory) +
    'long short race.sqlite';
  CreateCompetitionFile;
  ReferenceTime := EncodeDateTime(2026, 8, 16, 12, 0, 0, 0);
  // Measure a real backup so both own recent copies fit exactly in the quota.
  Result := TCompetitionBackupService.CreateBackup(FDatabaseFile, ReferenceTime);
  AssertEquals(Ord(cbsCreated), Ord(Result.Status));
  ManualFile := Result.BackupFileName;
  Stream := TFileStream.Create(ManualFile, fmOpenRead or fmShareDenyNone);
  try
    QuotaBytes := Stream.Size + 20;
  finally
    Stream.Free;
  end;
  if AUseQuota then
  begin
    OwnTime := IncHour(ReferenceTime, -1);
    OtherTime := IncHour(ReferenceTime, 1);
  end
  else
  begin
    OwnTime := IncDay(ReferenceTime, -200);
    OtherTime := IncDay(ReferenceTime, -201);
  end;
  for I := 0 to 1 do
  begin
    OwnFiles[I] := FixtureBackupFileName(AKind, cbrBeforeImport,
      OwnTime, FDatabaseFile, I);
    OtherFiles[I] := FixtureBackupFileName(AKind, cbrBeforeMigration,
      OtherTime, OtherDatabase, I);
    CreateFixtureFile(OwnFiles[I], 10);
    CreateFixtureFile(OtherFiles[I], 1024);
  end;
  if AKind = cbkAutomatic then Prefix := 'auto'
  else
    Prefix := 'safety_before-clear';
  UnrecognizedFiles[0] := IncludeTrailingPathDelimiter(BackupDirectory) +
    Prefix + '_invalid_2025-01-01_00-00-00-000 ' + ExtractFileName(FDatabaseFile);
  UnrecognizedFiles[1] := IncludeTrailingPathDelimiter(BackupDirectory) +
    Prefix + '_2025-01-01_00-00-00-000_x ' + ExtractFileName(FDatabaseFile);
  for I := 0 to 1 do
    CreateFixtureFile(UnrecognizedFiles[I], 1024);
  Policy := DefaultBackupRetentionPolicy;
  Policy.SafetyMinCopies := 1;
  if AUseQuota then
  begin
    Policy.AutomaticMaxTotalBytes := QuotaBytes;
    Policy.SafetyMaxTotalBytes := QuotaBytes;
  end;

  Result := TCompetitionBackupService.CreateBackup(NewCompetitionBackupRequest(
    FDatabaseFile, ReferenceTime, AKind, cbrBeforeClear, Policy));

  AssertEquals(Ord(cbsCreated), Ord(Result.Status));
  AssertTrue(FileExists(Result.BackupFileName));
  AssertTrue('Manual backups must be preserved', FileExists(ManualFile));
  for I := 0 to 1 do
  begin
    AssertTrue('Another database backup must be preserved: ' + OtherFiles[I],
      FileExists(OtherFiles[I]));
    AssertEquals('Only own expired backups may be removed: ' + OwnFiles[I],
      AUseQuota, FileExists(OwnFiles[I]));
    AssertTrue('Unrecognized backup names must be preserved',
      FileExists(UnrecognizedFiles[I]));
  end;
  if AUseQuota then
    AssertEquals('Foreign files must not count towards the quota',
      0, Result.Cleanup.DeletedCount)
  else
    AssertEquals('Both own expired copies, including the collision, must rotate',
      2, Result.Cleanup.DeletedCount);
  AssertEquals('', Result.Cleanup.WarningMessage);
end;

procedure TCompetitionBackupServiceTests.
AutomaticBackup_AgeCleanupPreservesMatchingDatabaseSuffix;
begin
  CheckCleanupIsolation(cbkAutomatic, False);
end;

procedure TCompetitionBackupServiceTests.
SafetyBackup_AgeCleanupPreservesMatchingDatabaseSuffix;
begin
  CheckCleanupIsolation(cbkSafety, False);
end;

procedure TCompetitionBackupServiceTests.
AutomaticBackup_QuotaIgnoresMatchingDatabaseSuffix;
begin
  CheckCleanupIsolation(cbkAutomatic, True);
end;

procedure TCompetitionBackupServiceTests.
SafetyBackup_QuotaIgnoresMatchingDatabaseSuffix;
begin
  CheckCleanupIsolation(cbkSafety, True);
end;

procedure TCompetitionBackupServiceTests.
Controller_QueuesCompletionAndRejectsConcurrentStart;
var
  MainThreadId: TThreadID;
begin
  MainThreadId := GetCurrentThreadID;
  FakeBackupShouldBlock := True;
  FController := TCompetitionBackupController.Create(
    @FakeCreateBackup, @BackupCompleted);

  AssertTrue(FController.Start(FDatabaseFile, EncodeDateTime(2026,
    8, 13, 10, 11, 12, 0)));
  RTLEventWaitFor(FakeBackupStarted, 1000);
  AssertTrue(FController.Busy);
  AssertFalse(FController.Start(FDatabaseFile, Now));
  RTLEventSetEvent(FakeBackupRelease);
  WaitForCompletion;

  AssertFalse(FController.Busy);
  AssertEquals(MainThreadId, FCompletionThreadId);
  AssertEquals(Ord(cbsCreated), Ord(FCompletedResult.Status));
end;

procedure TCompetitionBackupServiceTests.
Controller_CancelWaitsAndSuppressesCompletion;
begin
  FakeBackupShouldBlock := True;
  FController := TCompetitionBackupController.Create(
    @FakeCreateBackup, @BackupCompleted);
  AssertTrue(FController.Start(FDatabaseFile, Now));
  RTLEventWaitFor(FakeBackupStarted, 1000);

  RTLEventSetEvent(FakeBackupRelease);
  FController.Cancel;
  CheckSynchronize(10);

  AssertFalse(FController.Busy);
  AssertEquals(0, FCompletionCount);
end;

procedure TCompetitionBackupServiceTests.
Coordinator_SafetyWaitsAndAutomaticBackupsAreSkipped;
var
  AutomaticRequest, SafetyRequest: TCompetitionBackupRequest;
  AutomaticThread, SafetyThread: TCoordinatedBackupThread;
  Coordinator: TCompetitionBackupCoordinator;
  Policy: TBackupRetentionPolicy;
  SkippedResult: TCompetitionBackupResult;
begin
  Policy := DefaultBackupRetentionPolicy;
  AutomaticRequest := NewCompetitionBackupRequest(FDatabaseFile, Now,
    cbkAutomatic, cbrNone, Policy);
  SafetyRequest := NewCompetitionBackupRequest(FDatabaseFile, Now,
    cbkSafety, cbrBeforeImport, Policy);
  Coordinator := TCompetitionBackupCoordinator.Create;
  AutomaticThread := TCoordinatedBackupThread.Create(Coordinator,
    AutomaticRequest, @CoordinatedFakeCreateBackup);
  SafetyThread := TCoordinatedBackupThread.Create(Coordinator,
    SafetyRequest, @CoordinatedFakeCreateBackup);
  try
    AutomaticThread.Start;
    RTLEventWaitFor(CoordinatedAutomaticStarted, 1000);
    AssertEquals(1, CoordinatedAutomaticCallCount);

    SafetyThread.Start;
    Sleep(20);
    AssertEquals('Safety backup must wait for the automatic backup', 0,
      CoordinatedSafetyCallCount);

    SkippedResult := Coordinator.Execute(AutomaticRequest,
      @CoordinatedFakeCreateBackup);
    AssertEquals(Ord(cbsSkipped), Ord(SkippedResult.Status));
    AssertEquals(1, CoordinatedAutomaticCallCount);

    RTLEventSetEvent(CoordinatedAutomaticRelease);
    AutomaticThread.WaitFor;
    RTLEventWaitFor(CoordinatedSafetyStarted, 1000);
    AssertEquals(1, CoordinatedSafetyCallCount);

    SkippedResult := Coordinator.Execute(AutomaticRequest,
      @CoordinatedFakeCreateBackup);
    AssertEquals(Ord(cbsSkipped), Ord(SkippedResult.Status));
    AssertEquals(1, CoordinatedAutomaticCallCount);

    RTLEventSetEvent(CoordinatedSafetyRelease);
    SafetyThread.WaitFor;
    Coordinator.WaitForIdle;

    AssertEquals(Ord(cbsCreated),
      Ord(AutomaticThread.BackupResult.Status));
    AssertEquals(Ord(cbsCreated), Ord(SafetyThread.BackupResult.Status));
    AssertFalse(Coordinator.Busy);
  finally
    RTLEventSetEvent(CoordinatedAutomaticRelease);
    RTLEventSetEvent(CoordinatedSafetyRelease);
    AutomaticThread.WaitFor;
    SafetyThread.WaitFor;
    AutomaticThread.Free;
    SafetyThread.Free;
    Coordinator.Free;
  end;
end;

initialization
  RegisterTest(TCompetitionBackupServiceTests);

end.
