unit test_main_integration;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, Forms, Controls, fpcunit, testregistry,
  Main, Result, Settings, Startlist, Implement, i18n, db_sql;

type
  TMainFlowIntegrationTests = class(TTestCase)
  private
    FDbFilePath: string;
    FCsvFilePath: string;
    FImportFilePath: string;
    FExpectedImportedRows: integer;

    class function ResolveRepoRoot: string; static;
    procedure EnsureFormsCreated;
    procedure CreateNewCompetitionFile;
    procedure WriteCsv(const ALines: array of string);
    procedure AssertTableExists(const ATableName: string);
    procedure AssertMainRowCount(const AExpectedCount: integer);
    procedure ConfigureSingleActiveStage(const AStageIndex: integer);
    procedure InsertParticipant(const AParticipantNumber: integer);
    procedure DeleteBackupFiles;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MainForm_SecondaryQuerySharesPrimaryConnectionAndTransaction;
    procedure RefreshAll_ActiveDatasetsRefetchWithoutReopening;
    procedure CreateNewCompetitionFile_ViaMainFormHandler_CreatesDbAndOpensDatasets;
    procedure ImportStartListCp1251_ViaMainFormHandler_LoadsUtf8DataToMainTable;
    procedure ImportStartListCp1251_DoesNotRequireInteractiveDialogsInCI;
    procedure LoadParticipantsList_MinimalUtf8Csv_MapsParticipantAndStage;
    procedure LoadParticipantsList_ReimportExistingNumber_UpdatesWithoutDuplicate;
    procedure LoadParticipantsList_HtmlEntities_AreDecoded;
    procedure LoadParticipantsList_DatabaseError_RollsBackEntireImport;
    procedure LoadParticipantsList_WithoutNumberColumn_ReportsErrorAndImportsNothing;
    procedure LoadParticipantsList_InvalidStartTime_ReportsErrorAndImportsNothing;
    procedure LoadParticipantsList_DuplicateNumber_ReportsBothRows;
    procedure LoadStageResults_TwoColumns_ImportsFinishIntoSelectedStage;
    procedure LoadStageResults_ThreeColumns_ImportsStartIntoSelectedStage;
    procedure LoadStageResults_SixColumns_ImportsFullResultIntoSelectedStage;
    procedure LoadStageResults_DatabaseError_RollsBackEntireImport;
    procedure LoadStageResults_InvalidCsv_DoesNotChangeExistingResults;
    procedure LoadStageResults_InvalidCsv_DoesNotRequestStageSelection;
    procedure LoadStageResults_Reimport_UpdatesWithoutDuplicate;
    procedure LoadStageResults_StageSelectionCancellation_ChangesNothing;
    procedure LoadStageResults_DuplicateNumber_ReportsLocalizedCsvError;
    procedure LoadStageResults_UnknownParticipant_ConfirmationCreatesParticipant;
    procedure LoadStageResults_UnknownParticipant_RejectionSkipsOnlyUnknownResult;
    procedure UpdateSumResults_PreparedSecondaryQueryPreservesStatusSemantics;
    procedure UpdateSumResults_ActiveStageTimesAreSummed;
    procedure SettingsCompetitionPage_UsesScrollableContent;
    procedure StartlistForm_UsesScrollableContent;
  end;

implementation

var
  DialogCallCount: integer = 0;
  LastDialogMessage: string = '';
  ConfirmationDialogResult: integer = mrYes;
  StageSelectionCallCount: integer = 0;
  StageSelectionResult: integer = 2;

function IntegrationMessageDlgHandler(const Msg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: LongInt): Integer;
begin
  Inc(DialogCallCount);
  LastDialogMessage := Msg;
  if Pos(rsSetCategoryName, Msg) > 0 then
    Exit(mrNo);
  if mbYes in Buttons then
    Exit(ConfirmationDialogResult);
  Result := mrOK;
end;

function IntegrationStageSelectionHandler(const ACaption,
  APrompt: string): integer;
begin
  Inc(StageSelectionCallCount);
  Result := StageSelectionResult;
end;

class function TMainFlowIntegrationTests.ResolveRepoRoot: string;
begin
  Result := Trim(GetEnvironmentVariable('ENTIME_ROOT'));
  if Result <> '' then
    Exit(ExpandFileName(Result));

  Result := ExpandFileName(ExtractFileDir(ParamStr(0)) + DirectorySeparator +
    '..' + DirectorySeparator + '..');
end;

procedure TMainFlowIntegrationTests.EnsureFormsCreated;
begin
  if not Assigned(MainForm) then
    Application.CreateForm(TMainForm, MainForm);
  if not Assigned(ResultsForm) then
    Application.CreateForm(TResultsForm, ResultsForm);
end;

procedure TMainFlowIntegrationTests.CreateNewCompetitionFile;
begin
  MainForm.FileNewDB.Dialog.FileName := FDbFilePath;
  MainForm.FileNewDBAccept(MainForm.FileNewDB);
  AssertTrue('Expected DB file to be created: ' + FDbFilePath, FileExists(FDbFilePath));
  AssertTrue('Expected database datasets to be opened after DB creation', dbopen);
end;

procedure TMainFlowIntegrationTests.WriteCsv(const ALines: array of string);
var
  csvLines: TStringList;
  line: string;
begin
  csvLines := TStringList.Create;
  try
    for line in ALines do
      csvLines.Add(line);
    csvLines.SaveToFile(FCsvFilePath);
  finally
    csvLines.Free;
  end;
end;

procedure TMainFlowIntegrationTests.AssertTableExists(const ATableName: string);
begin
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = :table_name;';
  MainForm.SQLQuery1.ParamByName('table_name').AsString := ATableName;
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected table "' + ATableName + '" to exist', MainForm.SQLQuery1.IsEmpty);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.AssertMainRowCount(const AExpectedCount: integer);
begin
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text := 'SELECT COUNT(*) AS row_count FROM main;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Unexpected row count in main table', AExpectedCount,
    MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.ConfigureSingleActiveStage(
  const AStageIndex: integer);
var
  i: integer;
begin
  for i := 1 to MAXSTAGES do
  begin
    stages[i].isActive := i = AStageIndex;
    MainForm.CurrentSU.Buttons[i - 1].Enabled := i = AStageIndex;
  end;
  MainForm.CurrentSU.ItemIndex := AStageIndex - 1;
end;

procedure TMainFlowIntegrationTests.InsertParticipant(
  const AParticipantNumber: integer);
begin
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name) VALUES (:NUMBER, :NAME);';
  MainForm.SQLQuery1.ParamByName('NUMBER').AsInteger := AParticipantNumber;
  MainForm.SQLQuery1.ParamByName('NAME').AsString := 'Test participant';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.Close;
  RefreshAll;
end;

procedure TMainFlowIntegrationTests.DeleteBackupFiles;
var
  backupDirectory, fileMask: string;
  searchRec: TSearchRec;
begin
  if FDbFilePath = '' then
    Exit;

  backupDirectory := IncludeTrailingPathDelimiter(
    ExtractFilePath(FDbFilePath) + 'backup');
  fileMask := backupDirectory + '*' + ExtractFileName(FDbFilePath);

  if FindFirst(fileMask, faAnyFile, searchRec) = 0 then
  begin
    repeat
      if (searchRec.Attr and faDirectory) = 0 then
        DeleteFile(backupDirectory + searchRec.Name);
    until FindNext(searchRec) <> 0;
    FindClose(searchRec);
  end;
end;

procedure TMainFlowIntegrationTests.SetUp;
var
  repoRoot: string;
  fixtureLines: TStringList;
begin
  EnsureFormsCreated;
  MainForm.FileCloseExecute(nil);

  DialogCallCount := 0;
  LastDialogMessage := '';
  ConfirmationDialogResult := mrYes;
  StageSelectionCallCount := 0;
  StageSelectionResult := 2;
  SetMessageDlgHandler(@IntegrationMessageDlgHandler);
  ResetStageSelectionHandler;

  FDbFilePath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    Format('entime-main-integration-%d.db', [GetTickCount64]);
  FCsvFilePath := ChangeFileExt(FDbFilePath, '.csv');
  if FileExists(FDbFilePath) then
    DeleteFile(FDbFilePath);
  if FileExists(FCsvFilePath) then
    DeleteFile(FCsvFilePath);

  repoRoot := ResolveRepoRoot;
  FImportFilePath := IncludeTrailingPathDelimiter(repoRoot) + 'startlist ansi.csv';
  AssertTrue('Missing fixture file: ' + FImportFilePath, FileExists(FImportFilePath));

  fixtureLines := TStringList.Create;
  try
    fixtureLines.LoadFromFile(FImportFilePath);
    FExpectedImportedRows := fixtureLines.Count - 1;
  finally
    fixtureLines.Free;
  end;
end;

procedure TMainFlowIntegrationTests.TearDown;
begin
  ResetStageSelectionHandler;
  ResetMessageDlgHandler;
  MainForm.FileCloseExecute(nil);
  DeleteBackupFiles;
  if FileExists(FDbFilePath) then
    DeleteFile(FDbFilePath);
  if FileExists(FCsvFilePath) then
    DeleteFile(FCsvFilePath);
end;

procedure TMainFlowIntegrationTests.MainForm_SecondaryQuerySharesPrimaryConnectionAndTransaction;
begin
  AssertSame(MainForm.SQLite3Connection1, MainForm.SQLQuery2.Database);
  AssertSame(MainForm.SQLTransaction1, MainForm.SQLQuery2.Transaction);
end;

procedure TMainFlowIntegrationTests.RefreshAll_ActiveDatasetsRefetchWithoutReopening;
var
  mainHandle, correctionHandle, stageSumHandle: Pointer;
begin
  CreateNewCompetitionFile;
  InsertParticipant(401);

  mainHandle := MainForm.MainDataset1.SqliteHandle;
  correctionHandle := MainForm.CorrectionDataset.SqliteHandle;
  stageSumHandle := MainForm.ResultDatasetStageSum.SqliteHandle;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET name = ''Updated participant'' WHERE number = 401;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  RefreshAll;

  AssertTrue('MainDataset1 SQLite handle must be reused',
    mainHandle = MainForm.MainDataset1.SqliteHandle);
  AssertTrue('CorrectionDataset SQLite handle must be reused',
    correctionHandle = MainForm.CorrectionDataset.SqliteHandle);
  AssertTrue('ResultDatasetStageSum SQLite handle must be reused',
    stageSumHandle = MainForm.ResultDatasetStageSum.SqliteHandle);
  AssertTrue(MainForm.MainDataset1.Locate('number', 401, []));
  AssertEquals('Updated participant',
    MainForm.MainDataset1.FieldByName('name').AsString);
end;

procedure TMainFlowIntegrationTests.CreateNewCompetitionFile_ViaMainFormHandler_CreatesDbAndOpensDatasets;
var
  expectedRaceName: string;
begin
  CreateNewCompetitionFile;

  AssertTableExists('main');
  AssertTableExists('config');
  AssertTableExists('load');

  expectedRaceName := ChangeFileExt(ExtractFileName(FDbFilePath), '');
  AssertEquals('Unexpected default race name in config', expectedRaceName,
    TConfigSql.GetString(MainForm.SQLQuery1, 'racename', ''));
end;

procedure TMainFlowIntegrationTests.ImportStartListCp1251_ViaMainFormHandler_LoadsUtf8DataToMainTable;
begin
  CreateNewCompetitionFile;

  MainForm.FileOpenCSV.Dialog.FileName := FImportFilePath;
  MainForm.FileOpenCSVAccept(MainForm.FileOpenCSV);

  AssertMainRowCount(FExpectedImportedRows);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name, city, starttime1, starttime2 FROM main WHERE number = 2;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected row for participant number 2', MainForm.SQLQuery1.IsEmpty);
  AssertEquals('Unexpected participant name after CP1251 import',
    'Алексахина Варвара', MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('Unexpected participant city after CP1251 import',
    'Занаду', MainForm.SQLQuery1.FieldByName('city').AsString);
  AssertEquals('Unexpected starttime1 value', '10:00:00',
    MainForm.SQLQuery1.FieldByName('starttime1').AsString);
  AssertEquals('Unexpected starttime2 value', '11:00:00',
    MainForm.SQLQuery1.FieldByName('starttime2').AsString);
  MainForm.SQLQuery1.Close;

  AssertEquals('Unexpected stage 1 name in config', 'Старт 1',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename1', ''));
  AssertEquals('Unexpected stage 2 name in config', 'Старт 2',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename2', ''));
  AssertTrue('Expected stage1 to be active in config',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage1', False));
  AssertTrue('Expected stage2 to be active in config',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage2', False));
end;

procedure TMainFlowIntegrationTests.ImportStartListCp1251_DoesNotRequireInteractiveDialogsInCI;
begin
  CreateNewCompetitionFile;

  DialogCallCount := 0;
  MainForm.FileOpenCSV.Dialog.FileName := FImportFilePath;
  MainForm.FileOpenCSVAccept(MainForm.FileOpenCSV);

  AssertTrue('Expected at least one dialog call to be handled by the test hook',
    DialogCallCount > 0);
  AssertMainRowCount(FExpectedImportedRows);
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_MinimalUtf8Csv_MapsParticipantAndStage;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'number;name;category;nickname;birthday;team;city;phone;email;comment;Prologue',
    '42;Alice Rider;Elite;ali;1995;Fast Team;Perm;+79990000000;alice@example.test;Guest;09:15:00,123'
  ]);

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT category, name, nickname, age, team, city, phone, email, ' +
    'comment, starttime1 FROM main WHERE number = 42;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 42', MainForm.SQLQuery1.IsEmpty);
  AssertEquals('Elite', MainForm.SQLQuery1.FieldByName('category').AsString);
  AssertEquals('Alice Rider', MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('ali', MainForm.SQLQuery1.FieldByName('nickname').AsString);
  AssertEquals('1995', MainForm.SQLQuery1.FieldByName('age').AsString);
  AssertEquals('Fast Team', MainForm.SQLQuery1.FieldByName('team').AsString);
  AssertEquals('Perm', MainForm.SQLQuery1.FieldByName('city').AsString);
  AssertEquals('+79990000000', MainForm.SQLQuery1.FieldByName('phone').AsString);
  AssertEquals('alice@example.test',
    MainForm.SQLQuery1.FieldByName('email').AsString);
  AssertEquals('Guest', MainForm.SQLQuery1.FieldByName('comment').AsString);
  AssertEquals('09:15:00.123',
    MainForm.SQLQuery1.FieldByName('starttime1').AsString);
  MainForm.SQLQuery1.Close;

  AssertEquals('Prologue',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename1', ''));
  AssertTrue('Expected imported stage to be active',
    TConfigSql.GetBool(MainForm.SQLQuery1, 'stage1', False));
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_ReimportExistingNumber_UpdatesWithoutDuplicate;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'number;name;category;Stage 1',
    '77;First Name;Open;10:00:00'
  ]);
  LoadParticipantsList(FCsvFilePath);

  WriteCsv([
    'number;name;category;Stage 1',
    '77;Updated Name;Masters;10:30:00'
  ]);
  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name, category, starttime1 FROM main WHERE number = 77;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 77', MainForm.SQLQuery1.IsEmpty);
  AssertEquals('Updated Name', MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('Masters', MainForm.SQLQuery1.FieldByName('category').AsString);
  AssertEquals('10:30:00',
    MainForm.SQLQuery1.FieldByName('starttime1').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_HtmlEntities_AreDecoded;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'category;number;name;team;comment;Stage 1',
    'Masters;99;"O&#39;Connor";"RiderShop&amp;Service";"Text; quoted";11:30:00'
  ]);

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT name, team, comment FROM main WHERE number = 99;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 99', MainForm.SQLQuery1.IsEmpty);
  AssertEquals('O''Connor', MainForm.SQLQuery1.FieldByName('name').AsString);
  AssertEquals('RiderShop&Service',
    MainForm.SQLQuery1.FieldByName('team').AsString);
  AssertEquals('Text; quoted',
    MainForm.SQLQuery1.FieldByName('comment').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_DatabaseError_RollsBackEntireImport;
begin
  CreateNewCompetitionFile;
  TConfigSql.ExecUpsertByKey(
    MainForm.SQLQuery1, 'stagename1', 'Existing Stage');

  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO load (number, name) VALUES (500, ''Existing participant'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.SQL.Text :=
    'CREATE TRIGGER reject_participant BEFORE INSERT ON load ' +
    'WHEN NEW.number = 2 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced import failure''); END;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    'number;name;New Stage',
    '1;First participant;10:00:00',
    '2;Second participant;10:01:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(0);
  AssertTrue('Expected database error dialog', DialogCallCount > 0);
  AssertTrue('Expected participant database error prefix, got: ' +
    LastDialogMessage,
    Pos(rsWriteParticipantsDatabaseError, LastDialogMessage) = 1);
  AssertTrue('Expected forced database error, got: ' + LastDialogMessage,
    Pos('forced import failure', LastDialogMessage) > 0);
  AssertEquals('Existing Stage',
    TConfigSql.GetString(MainForm.SQLQuery1, 'stagename1', ''));

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count FROM load WHERE number = 500;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Previous load rows must be restored after rollback',
    1, MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_WithoutNumberColumn_ReportsErrorAndImportsNothing;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'name;category;Stage 1',
    'No Number;Open;10:00:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(0);
  AssertEquals('Expected exactly one import error dialog', 1, DialogCallCount);
  AssertEquals(rsLoadParticipantsListError + rsNumberColumnNotFound,
    LastDialogMessage);
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_InvalidStartTime_ReportsErrorAndImportsNothing;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    'number;name;Stage 1',
    '42;Alice Rider;25:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(0);
  AssertEquals('Expected exactly one import error dialog', 1, DialogCallCount);
  AssertEquals(rsLoadParticipantsListError +
    Format(rsInvalidParticipantStartTime,
      ['25:00', 2, 'Stage 1']), LastDialogMessage);
end;

procedure TMainFlowIntegrationTests.LoadParticipantsList_DuplicateNumber_ReportsBothRows;
begin
  CreateNewCompetitionFile;
  WriteCsv([
    '# participant import',
    'number;name;Stage 1',
    '42;Alice Rider;10:00:00',
    '# duplicate follows',
    '42;Bob Rider;10:01:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadParticipantsList(FCsvFilePath);

  AssertMainRowCount(0);
  AssertEquals('Expected exactly one import error dialog', 1, DialogCallCount);
  AssertEquals(rsLoadParticipantsListError +
    Format(rsDuplicateParticipantNumber, [42, 3, 5]),
    LastDialogMessage);
end;

procedure TMainFlowIntegrationTests.LoadStageResults_TwoColumns_ImportsFinishIntoSelectedStage;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(101);
  WriteCsv([
    '######;',
    '#номер;время финиша',
    '101;11:00:00.123'
  ]);

  LoadStageResults(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime1, finishtime2, status2 FROM main WHERE number = 101;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 101', MainForm.SQLQuery1.IsEmpty);
  AssertTrue('Stage 1 finish time must remain empty',
    MainForm.SQLQuery1.FieldByName('finishtime1').IsNull);
  AssertEquals('11:00:00.123',
    MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  AssertTrue('Finish import without DNF must not set a status',
    MainForm.SQLQuery1.FieldByName('status2').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_ThreeColumns_ImportsStartIntoSelectedStage;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(102);
  WriteCsv([
    '######',
    '#номер;время старта;стартовая поправка',
    '102;10:00:00;-250'
  ]);

  LoadStageResults(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT starttime1, starttime2, correction2, status2 ' +
    'FROM main WHERE number = 102;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 102', MainForm.SQLQuery1.IsEmpty);
  AssertTrue('Stage 1 start time must remain empty',
    MainForm.SQLQuery1.FieldByName('starttime1').IsNull);
  AssertEquals('10:00:00',
    MainForm.SQLQuery1.FieldByName('starttime2').AsString);
  AssertEquals(-250, MainForm.SQLQuery1.FieldByName('correction2').AsInteger);
  AssertTrue('Start import without DNS must not set a status',
    MainForm.SQLQuery1.FieldByName('status2').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_SixColumns_ImportsFullResultIntoSelectedStage;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(103);
  WriteCsv([
    '######',
    '#номер;время старта;стартовая поправка;время финиша;штраф;статус',
    '103;10:00:00;-250;11:00:00.123;00:00:05;'
  ]);

  LoadStageResults(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT starttime1, finishtime1, starttime2, correction2, ' +
    'finishtime2, penalty2, status2 FROM main WHERE number = 103;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Expected participant number 103', MainForm.SQLQuery1.IsEmpty);
  AssertTrue('Stage 1 start time must remain empty',
    MainForm.SQLQuery1.FieldByName('starttime1').IsNull);
  AssertTrue('Stage 1 finish time must remain empty',
    MainForm.SQLQuery1.FieldByName('finishtime1').IsNull);
  AssertEquals('10:00:00',
    MainForm.SQLQuery1.FieldByName('starttime2').AsString);
  AssertEquals(-250, MainForm.SQLQuery1.FieldByName('correction2').AsInteger);
  AssertEquals('11:00:00.123',
    MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  AssertEquals('00:00:05',
    MainForm.SQLQuery1.FieldByName('penalty2').AsString);
  AssertTrue('Full import without a status must leave it empty',
    MainForm.SQLQuery1.FieldByName('status2').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_DatabaseError_RollsBackEntireImport;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(104);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = ''10:30:00'' WHERE number = 104;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO loadresult (number, finishtime) VALUES (999, ''09:00:00'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;
  MainForm.SQLQuery1.SQL.Text :=
    'CREATE TRIGGER reject_result BEFORE UPDATE ON main ' +
    'WHEN NEW.number = 104 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced result import failure''); END;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;finish time',
    '104;11:00:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadStageResults(FCsvFilePath);

  AssertTrue('Expected database error dialog', DialogCallCount > 0);
  AssertTrue('Expected database error prefix, got: ' + LastDialogMessage,
    Pos(rsWriteResultsDatabaseError, LastDialogMessage) = 1);
  AssertTrue('Expected forced result error, got: ' + LastDialogMessage,
    Pos('forced result import failure', LastDialogMessage) > 0);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 104;';
  MainForm.SQLQuery1.Open;
  AssertEquals('10:30:00',
    MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;

  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, finishtime FROM loadresult;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Previous staging row must be restored after rollback',
    1, MainForm.SQLQuery1.RecordCount);
  AssertEquals(999, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('09:00:00',
    MainForm.SQLQuery1.FieldByName('finishtime').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_InvalidCsv_DoesNotChangeExistingResults;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(105);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = ''10:30:00'' WHERE number = 105;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;finish time',
    '105;25:00'
  ]);
  DialogCallCount := 0;
  LastDialogMessage := '';

  LoadStageResults(FCsvFilePath);

  AssertTrue('Expected CSV validation error dialog', DialogCallCount > 0);
  AssertEquals(rsLoadResultsError +
    Format(rsInvalidResultTime, ['25:00', 2, rsFinishtime]),
    LastDialogMessage);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 105;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Existing finish time must survive CSV validation failure',
    '10:30:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_InvalidCsv_DoesNotRequestStageSelection;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(108);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = ''10:30:00'' WHERE number = 108;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;finish time',
    '108;25:00'
  ]);
  SetStageSelectionHandler(@IntegrationStageSelectionHandler);

  LoadStageResults(FCsvFilePath);

  AssertEquals('Invalid CSV must not request stage selection',
    0, StageSelectionCallCount);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 108;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Invalid CSV must not change the existing finish time',
    '10:30:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_Reimport_UpdatesWithoutDuplicate;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(109);

  WriteCsv([
    '# number;finish time',
    '109;10:00:00'
  ]);
  LoadStageResults(FCsvFilePath);

  DeleteBackupFiles;
  WriteCsv([
    '# number;finish time',
    '109;11:00:00'
  ]);
  LoadStageResults(FCsvFilePath);

  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count, MAX(finishtime2) AS finishtime2 ' +
    'FROM main WHERE number = 109;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Reimport must not create a duplicate participant',
    1, MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  AssertEquals('Reimport must replace the existing result',
    '11:00:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_StageSelectionCancellation_ChangesNothing;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(110);

  MainForm.SQLQuery1.SQL.Text :=
    'UPDATE main SET finishtime2 = ''10:30:00'' WHERE number = 110;';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO loadresult (number, finishtime) VALUES (999, ''09:00:00'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLQuery1.SQLTransaction.Commit;

  WriteCsv([
    '# number;finish time',
    '110;11:00:00'
  ]);
  StageSelectionResult := -1;
  SetStageSelectionHandler(@IntegrationStageSelectionHandler);

  LoadStageResults(FCsvFilePath);

  AssertEquals('Expected one stage selection request',
    1, StageSelectionCallCount);
  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 110;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Cancellation must preserve the existing result',
    '10:30:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;

  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, finishtime FROM loadresult;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Cancellation must preserve the staging row',
    1, MainForm.SQLQuery1.RecordCount);
  AssertEquals(999, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('09:00:00',
    MainForm.SQLQuery1.FieldByName('finishtime').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_DuplicateNumber_ReportsLocalizedCsvError;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(107);

  WriteCsv([
    '# number;finish time',
    '107;10:00:00',
    '# duplicate follows',
    '107;11:00:00'
  ]);

  LoadStageResults(FCsvFilePath);

  AssertEquals('Expected exactly one CSV validation error dialog',
    1, DialogCallCount);
  AssertEquals(rsLoadResultsError +
    Format(rsDuplicateResultParticipantNumber, [107, 2, 4]),
    LastDialogMessage);
  AssertEquals('CSV error must not use the database prefix',
    0, Pos(rsDatabaseOpenError, LastDialogMessage));

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 107;';
  MainForm.SQLQuery1.Open;
  AssertTrue('Duplicate CSV must not change the participant result',
    MainForm.SQLQuery1.FieldByName('finishtime2').IsNull);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_UnknownParticipant_ConfirmationCreatesParticipant;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(106);

  WriteCsv([
    '# number;finish time',
    '999;11:00:00'
  ]);

  LoadStageResults(FCsvFilePath);

  AssertTrue('Expected confirmation for unknown participant',
    DialogCallCount > 0);
  AssertTrue('Unexpected confirmation text: ' + LastDialogMessage,
    Pos(Format(rsAddUnknownResultParticipant, [999]),
    LastDialogMessage) > 0);
  AssertMainRowCount(2);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 999;';
  MainForm.SQLQuery1.Open;
  AssertFalse('Confirmed participant must be created',
    MainForm.SQLQuery1.IsEmpty);
  AssertEquals('11:00:00',
    MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.LoadStageResults_UnknownParticipant_RejectionSkipsOnlyUnknownResult;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(2);
  InsertParticipant(106);

  WriteCsv([
    '# number;finish time',
    '106;10:00:00',
    '999;11:00:00'
  ]);
  ConfirmationDialogResult := mrNo;

  LoadStageResults(FCsvFilePath);

  AssertTrue('Expected confirmation for unknown participant',
    DialogCallCount > 0);
  AssertMainRowCount(1);
  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT finishtime2 FROM main WHERE number = 106;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Known participant result must still be imported',
    '10:00:00', MainForm.SQLQuery1.FieldByName('finishtime2').AsString);
  MainForm.SQLQuery1.Close;

  MainForm.SQLQuery1.SQL.Text :=
    'SELECT COUNT(*) AS row_count FROM main WHERE number = 999;';
  MainForm.SQLQuery1.Open;
  AssertEquals('Rejected participant must not be created',
    0, MainForm.SQLQuery1.FieldByName('row_count').AsInteger);
  MainForm.SQLQuery1.Close;
end;

procedure TMainFlowIntegrationTests.UpdateSumResults_PreparedSecondaryQueryPreservesStatusSemantics;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name, result1, status) VALUES ' +
    '(201, ''Calculated'', ''00:10:00.000'', ''1''), ' +
    '(202, ''Did not finish'', NULL, ''1''), ' +
    '(203, ''Did not start'', NULL, ''2''), ' +
    '(204, ''Disqualified'', ''00:05:00.000'', ''3'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  UpdateSumResults;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT number, sumresult, sumstages, status FROM main ORDER BY number;';
  MainForm.SQLQuery1.Open;

  AssertEquals(201, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('00:10:00.000',
    MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertEquals(1, MainForm.SQLQuery1.FieldByName('sumstages').AsInteger);
  AssertTrue(MainForm.SQLQuery1.FieldByName('status').IsNull);

  MainForm.SQLQuery1.Next;
  AssertEquals(202, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('DNF', MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('sumstages').IsNull);
  AssertEquals('1', MainForm.SQLQuery1.FieldByName('status').AsString);

  MainForm.SQLQuery1.Next;
  AssertEquals(203, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('DNS', MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('sumstages').IsNull);
  AssertEquals('2', MainForm.SQLQuery1.FieldByName('status').AsString);

  MainForm.SQLQuery1.Next;
  AssertEquals(204, MainForm.SQLQuery1.FieldByName('number').AsInteger);
  AssertEquals('DSQ', MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertTrue(MainForm.SQLQuery1.FieldByName('sumstages').IsNull);
  AssertEquals('3', MainForm.SQLQuery1.FieldByName('status').AsString);
  MainForm.SQLQuery1.Close;

  AssertEquals('UpdateSumResults must not report database errors',
    0, DialogCallCount);
end;

procedure TMainFlowIntegrationTests.UpdateSumResults_ActiveStageTimesAreSummed;
begin
  CreateNewCompetitionFile;
  ConfigureSingleActiveStage(1);
  stages[2].isActive := True;
  MainForm.CurrentSU.Buttons[1].Enabled := True;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'INSERT INTO main (number, name, result1, result2, result3) VALUES ' +
    '(301, ''Summed result'', ''00:45:30.250'', ''01:20:40.750'', ' +
    '''05:00:00.000'');';
  MainForm.SQLQuery1.ExecSQL;
  MainForm.SQLTransaction1.Commit;

  UpdateSumResults;

  MainForm.SQLQuery1.Close;
  MainForm.SQLQuery1.SQL.Text :=
    'SELECT sumresult, sumstages FROM main WHERE number = 301;';
  MainForm.SQLQuery1.Open;
  AssertFalse(MainForm.SQLQuery1.EOF);
  AssertEquals('02:06:11.000',
    MainForm.SQLQuery1.FieldByName('sumresult').AsString);
  AssertEquals(2, MainForm.SQLQuery1.FieldByName('sumstages').AsInteger);
  MainForm.SQLQuery1.Close;

  AssertEquals('UpdateSumResults must not report database errors',
    0, DialogCallCount);
end;

procedure TMainFlowIntegrationTests.SettingsCompetitionPage_UsesScrollableContent;
var
  form: TSettingsForm;
begin
  form := TSettingsForm.Create(nil);
  try
    AssertSame(form.Page3Competition, form.CompetitionScrollBox.Parent);
    AssertEquals(Ord(alClient), Ord(form.CompetitionScrollBox.Align));
    AssertTrue(form.CompetitionScrollBox.AutoScroll);
    AssertSame(form.CompetitionScrollBox, form.CompetitionContentPanel.Parent);
    AssertSame(form.CompetitionContentPanel, form.LeftPanel.Parent);
    AssertSame(form.CompetitionContentPanel, form.GroupBoxStages.Parent);

    form.Notebook1.PageIndex := 2;
    form.Show;
    Application.ProcessMessages;
    AssertTrue(form.CompetitionScrollBox.VertScrollBar.Range <=
      form.CompetitionScrollBox.ClientHeight);

    form.Height := form.Constraints.MinHeight;
    Application.ProcessMessages;
    AssertTrue(form.CompetitionContentPanel.Height >
      form.CompetitionScrollBox.ClientHeight);
    AssertTrue(form.CompetitionScrollBox.VertScrollBar.Range >
      form.CompetitionScrollBox.ClientHeight);
  finally
    form.Free;
  end;
end;

procedure TMainFlowIntegrationTests.StartlistForm_UsesScrollableContent;
var
  form: TStartlistForm;
begin
  form := TStartlistForm.Create(nil);
  try
    AssertSame(form, form.ButtonPanel1.Parent);
    AssertSame(form, form.StartlistScrollBox.Parent);
    AssertTrue(form.StartlistScrollBox.AutoScroll);
    AssertSame(form.StartlistScrollBox, form.StageSelected.Parent);
    AssertSame(form.StartlistScrollBox, form.Panel1.Parent);
    AssertSame(form.StartlistScrollBox, form.Panel2.Parent);

    form.Show;
    Application.ProcessMessages;
    AssertTrue(form.StartlistScrollBox.VertScrollBar.Range <=
      form.StartlistScrollBox.ClientHeight);

    form.Height := form.Constraints.MinHeight;
    Application.ProcessMessages;
    AssertTrue(form.Panel2.Top + form.Panel2.Height >
      form.StartlistScrollBox.ClientHeight);
    AssertTrue(form.StartlistScrollBox.VertScrollBar.Range >
      form.StartlistScrollBox.ClientHeight);
  finally
    form.Free;
  end;
end;

initialization
  RegisterTest(TMainFlowIntegrationTests);

end.
