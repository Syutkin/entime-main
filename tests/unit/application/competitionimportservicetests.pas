unit CompetitionImportServiceTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, SQLDB, DbSql, StageModel,
  CompetitionImportService;

type
  TCompetitionImportServiceTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FQuery: TSQLQuery;
    FStages: TStages;
    procedure CreateSchema;
    function CreateCsvFile(const AContent: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure PrepareParticipantsFile_ReturnsFormIndependentPlan;
    procedure ApplyParticipants_ImportsWithoutMainForm;
    procedure ApplyResults_ImportsWithoutMainForm;
    procedure ApplyResults_CalculationFailureRollsBackImport;
  end;

implementation

procedure TCompetitionImportServiceTests.SetUp;
begin
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FQuery := FContext.CreateQuery(nil);
  FStages := TStages.Create(2);
  FStages[2].isActive := True;
  CreateSchema;
end;

procedure TCompetitionImportServiceTests.TearDown;
begin
  FStages.Free;
  FQuery.Free;
  FContext.Free;
end;

procedure TCompetitionImportServiceTests.CreateSchema;
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    TSchemaSql.ExecCreateTables(FContext.Connection, 2,
      'A', 'B', 'C', 'D', 'E', 'Test race');
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
end;

function TCompetitionImportServiceTests.CreateCsvFile(
  const AContent: string): string;
var
  Content: TStringList;
begin
  Result := GetTempFileName(GetTempDir(False), 'entime-import-');
  Content := TStringList.Create;
  try
    Content.Text := AContent;
    Content.SaveToFile(Result);
  finally
    Content.Free;
  end;
end;

procedure TCompetitionImportServiceTests.
  PrepareParticipantsFile_ReturnsFormIndependentPlan;
var
  FileName: string;
  Plan: TParticipantsImportPlan;
begin
  FileName := CreateCsvFile(
    'number;name;Forest;Sprint' + LineEnding +
    '17;Runner;09:00:00;10:00:00');
  try
    Plan := TCompetitionImportService.PrepareParticipantsFile(FileName, 32);
    try
      AssertEquals(1, Plan.RowCount);
      AssertEquals(2, Plan.DetectedStageCount);
      AssertEquals('Forest, Sprint', Plan.DetectedStageNamesText);
      AssertEquals(4, Plan.TargetStageCount(4));
      AssertEquals(5, Plan.TargetStageCount(5));
    finally
      Plan.Free;
    end;
  finally
    DeleteFile(FileName);
  end;
end;

procedure TCompetitionImportServiceTests.
  ApplyParticipants_ImportsWithoutMainForm;
var
  FileName: string;
  Plan: TParticipantsImportPlan;
  Outcome: TParticipantsImportOutcome;
  Request: TParticipantsImportRequest;
begin
  FileName := CreateCsvFile(
    'number;name;Forest' + LineEnding +
    '18;Runner;08:30:00');
  try
    Plan := TCompetitionImportService.PrepareParticipantsFile(FileName, 32);
    try
      Request := Default(TParticipantsImportRequest);
      Request.StoredActiveStageIndex := 1;
      Request.ExpansionBackupCreated := True;
      Outcome := TCompetitionImportService.ApplyParticipants(Plan, FContext,
        FStages, Request);
      AssertEquals(1, Outcome.RowCount);
      AssertTrue(Outcome.StageDefinitionsApplied);
    finally
      Plan.Free;
    end;

    FQuery.SQL.Text :=
      'SELECT name, starttime1 FROM main WHERE number = 18;';
    FQuery.Open;
    AssertFalse(FQuery.EOF);
    AssertEquals('Runner', FQuery.FieldByName('name').AsString);
    AssertEquals('08:30:00', FQuery.FieldByName('starttime1').AsString);
  finally
    DeleteFile(FileName);
  end;
end;

procedure TCompetitionImportServiceTests.ApplyResults_ImportsWithoutMainForm;
var
  FileName: string;
  Plan: TResultsImportPlan;
  Outcome: TResultsImportOutcome;
  Inspection: TResultsImportInspection;
  Request: TResultsImportRequest;
begin
  FileName := CreateCsvFile('101;11:22:33.444');
  try
    Plan := TCompetitionImportService.PrepareResultsFile(FileName);
    try
      Inspection := TCompetitionImportService.InspectResultsParticipants(
        Plan, FContext);
      AssertEquals(0, Inspection.KnownParticipantCount);
      AssertEquals(1, Length(Inspection.UnknownParticipantNumbers));
      AssertEquals(101, Inspection.UnknownParticipantNumbers[0]);
      Request := Default(TResultsImportRequest);
      Request.StageIndex := 2;
      Request.BackupCreated := True;
      Request.AcceptedUnknownParticipantNumbers :=
        Inspection.UnknownParticipantNumbers;
      Outcome := TCompetitionImportService.ApplyResults(Plan, FContext,
        FStages, Request);
      AssertEquals(1, Outcome.ImportedRowCount);
      AssertEquals(2, Outcome.StageIndex);
    finally
      Plan.Free;
    end;

    FQuery.SQL.Text :=
      'SELECT finishtime2 FROM main WHERE number = 101;';
    FQuery.Open;
    AssertFalse(FQuery.EOF);
    AssertEquals('11:22:33.444',
      FQuery.FieldByName('finishtime2').AsString);
  finally
    DeleteFile(FileName);
  end;
end;

procedure TCompetitionImportServiceTests.
  ApplyResults_CalculationFailureRollsBackImport;
var
  FileName: string;
  Plan: TResultsImportPlan;
  Request: TResultsImportRequest;
begin
  FileName := CreateCsvFile('102;12:34:56.789');
  try
    Plan := TCompetitionImportService.PrepareResultsFile(FileName);
    try
      FQuery.SQL.Text :=
        'CREATE TRIGGER fail_import_calculation BEFORE UPDATE OF result2 ' +
        'ON main WHEN NEW.number = 102 BEGIN SELECT RAISE(ABORT, ' +
        '''forced import calculation failure''); END;';
      FQuery.ExecSQL;
      FContext.Transaction.Commit;
      Request := Default(TResultsImportRequest);
      Request.StageIndex := 2;
      Request.BackupCreated := True;
      SetLength(Request.AcceptedUnknownParticipantNumbers, 1);
      Request.AcceptedUnknownParticipantNumbers[0] := 102;
      try
        TCompetitionImportService.ApplyResults(Plan, FContext, FStages,
          Request);
        Fail('Calculation error must leave the import transaction');
      except
        on E: Exception do
          AssertTrue(Pos('forced import calculation failure', E.Message) > 0);
      end;
    finally
      Plan.Free;
    end;

    FQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM main WHERE number = 102;';
    FQuery.Open;
    AssertEquals('Failed calculation must roll back imported rows', 0,
      FQuery.FieldByName('cnt').AsInteger);
  finally
    DeleteFile(FileName);
  end;
end;

initialization
  RegisterTest(TCompetitionImportServiceTests);

end.
