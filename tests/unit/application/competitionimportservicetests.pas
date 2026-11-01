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
    procedure Exec(const ASql: string);
    procedure ImportResults(const ACsv: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure PrepareParticipantsFile_ReturnsFormIndependentPlan;
    procedure ApplyParticipants_ImportsWithoutMainForm;
    procedure ApplyResults_ImportsWithoutMainForm;
    procedure ApplyResults_CalculationFailureRollsBackImport;
    procedure ApplyResults_FormatsWriteOnlyTheirFieldsAndClearImplicitStatus;
    procedure ApplyResults_SpecialTokensWriteDnsAndDnf;
    procedure ApplyResults_EmptyCorrectionAndZeroRemainDistinct;
    procedure ApplyResults_UnknownNumbersRequireAcceptance;
    procedure ApplyResults_RequiresBackupDecisionBeforeWriting;
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

function TCompetitionImportServiceTests.CreateCsvFile(const AContent: string): string;
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
  FileName := CreateCsvFile('number;name;Forest;Sprint' +
    LineEnding + '17;Runner;09:00:00;10:00:00');
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
  FileName := CreateCsvFile('number;name;Forest' + LineEnding +
    '18;Runner;08:30:00');
  try
    Plan := TCompetitionImportService.PrepareParticipantsFile(FileName, 32);
    try
      Request := Default(TParticipantsImportRequest);
      Request.StoredActiveStageIndex := 1;
      Request.ExpansionBackupCreated := True;
      Outcome := TCompetitionImportService.ApplyParticipants(Plan,
        FContext, FStages, Request);
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

procedure TCompetitionImportServiceTests.Exec(const ASql: string);
var
  Work: TCompetitionUnitOfWork;
begin
  Work := FContext.BeginUnitOfWork;
  try
    FQuery.Close;
    FQuery.SQL.Text := ASql;
    FQuery.ExecSQL;
    Work.Commit;
  finally
    Work.Free;
  end;
end;

procedure TCompetitionImportServiceTests.ImportResults(const ACsv: string);
var
  FileName: string;
  Plan: TResultsImportPlan;
  Request: TResultsImportRequest;
begin
  FileName := CreateCsvFile(ACsv);
  try
    Plan := TCompetitionImportService.PrepareResultsFile(FileName);
    try
      Request := Default(TResultsImportRequest);
      Request.StageIndex := 2;
      Request.BackupCreated := True;
      TCompetitionImportService.ApplyResults(Plan, FContext, FStages, Request);
    finally
      Plan.Free;
    end;
  finally
    DeleteFile(FileName);
  end;
end;

procedure TCompetitionImportServiceTests.
ApplyResults_FormatsWriteOnlyTheirFieldsAndClearImplicitStatus;
const
  Csv: array[0..2] of string = ('101;10:00:00', '101;09:00:00;-15', '101;;;;;');
var
  I: integer;
begin
  for I := 0 to High(Csv) do
  begin
    Exec('DELETE FROM main;');
    Exec('INSERT INTO main (number, name, starttime1, finishtime1, starttime2, ' +
      'finishtime2, correction2, penalty2, status2) VALUES ' +
      '(101, ''Original'', ''11:00:00'', ''12:00:00'', ''08:00:00'', ''09:00:00'', 7, ''00:00:05'', ''1'');');
    ImportResults(Csv[I]);
    FQuery.SQL.Text := 'SELECT * FROM main WHERE number = 101;';
    FQuery.Open;
    AssertEquals('Original', FQuery.FieldByName('name').AsString);
    AssertEquals('11:00:00', FQuery.FieldByName('starttime1').AsString);
    AssertEquals('12:00:00', FQuery.FieldByName('finishtime1').AsString);
    AssertTrue(FQuery.FieldByName('status2').IsNull);
    case I of
      0: begin
        AssertEquals('08:00:00', FQuery.FieldByName('starttime2').AsString);
        AssertEquals('10:00:00', FQuery.FieldByName('finishtime2').AsString);
        AssertEquals(7, FQuery.FieldByName('correction2').AsInteger);
        AssertEquals('00:00:05', FQuery.FieldByName('penalty2').AsString);
      end;
      1: begin
        AssertEquals('09:00:00', FQuery.FieldByName('starttime2').AsString);
        AssertEquals('09:00:00', FQuery.FieldByName('finishtime2').AsString);
        AssertEquals(-15, FQuery.FieldByName('correction2').AsInteger);
        AssertEquals('00:00:05', FQuery.FieldByName('penalty2').AsString);
      end;
      2: begin
        AssertTrue(FQuery.FieldByName('starttime2').IsNull);
        AssertTrue(FQuery.FieldByName('finishtime2').IsNull);
        AssertTrue(FQuery.FieldByName('correction2').IsNull);
        AssertTrue(FQuery.FieldByName('penalty2').IsNull);
      end;
    end;
    FQuery.Close;
  end;
end;

procedure TCompetitionImportServiceTests.ApplyResults_SpecialTokensWriteDnsAndDnf;
begin
  Exec('INSERT INTO main (number, starttime2, finishtime2, correction2) VALUES ' +
    '(101, ''08:00:00'', ''09:00:00'', 7);');
  ImportResults('101;DNF');
  FQuery.SQL.Text := 'SELECT * FROM main WHERE number = 101;';
  FQuery.Open;
  AssertEquals('2', FQuery.FieldByName('status2').AsString);
  AssertTrue(FQuery.FieldByName('finishtime2').IsNull);
  AssertEquals(7, FQuery.FieldByName('correction2').AsInteger);
  FQuery.Close;
  ImportResults('101;08:30:00;DNS');
  FQuery.SQL.Text := 'SELECT * FROM main WHERE number = 101;';
  FQuery.Open;
  AssertEquals('1', FQuery.FieldByName('status2').AsString);
  AssertEquals('08:30:00', FQuery.FieldByName('starttime2').AsString);
  AssertTrue(FQuery.FieldByName('correction2').IsNull);
end;

procedure TCompetitionImportServiceTests.
ApplyResults_EmptyCorrectionAndZeroRemainDistinct;
begin
  Exec('INSERT INTO main (number) VALUES (101);');
  ImportResults('101;08:00:00;0;09:00:00;;');
  FQuery.SQL.Text := 'SELECT correction2 FROM main WHERE number = 101;';
  FQuery.Open;
  AssertFalse(FQuery.Fields[0].IsNull);
  AssertEquals(0, FQuery.Fields[0].AsInteger);
  FQuery.Close;
  ImportResults('101;08:00:00;;09:00:00;;');
  FQuery.SQL.Text := 'SELECT correction2 FROM main WHERE number = 101;';
  FQuery.Open;
  AssertTrue(FQuery.Fields[0].IsNull);
end;

procedure TCompetitionImportServiceTests.ApplyResults_UnknownNumbersRequireAcceptance;
var
  FileName: string;
  Plan: TResultsImportPlan;
  Request: TResultsImportRequest;
  Outcome: TResultsImportOutcome;
begin
  Exec('INSERT INTO main (number) VALUES (101);');
  FileName := CreateCsvFile('101;10:00:00' + LineEnding + '102;10:01:00');
  try
    Plan := TCompetitionImportService.PrepareResultsFile(FileName);
    try
      Request := Default(TResultsImportRequest);
      Request.StageIndex := 2;
      Request.BackupCreated := True;
      Outcome := TCompetitionImportService.ApplyResults(Plan, FContext,
        FStages, Request);
      AssertEquals(1, Outcome.ImportedRowCount);
      AssertEquals(1, Outcome.SkippedRowCount);
      FQuery.SQL.Text := 'SELECT number FROM main;';
      FQuery.Open;
      AssertEquals(1, FQuery.RecordCount);
      AssertEquals(101, FQuery.Fields[0].AsInteger);
    finally
      Plan.Free;
    end;
  finally
    DeleteFile(FileName);
  end;
end;

procedure TCompetitionImportServiceTests.
ApplyResults_RequiresBackupDecisionBeforeWriting;
var
  FileName: string;
  Plan: TResultsImportPlan;
  Request: TResultsImportRequest;
begin
  Exec('INSERT INTO main (number, finishtime2) VALUES (101, ''09:00:00'');');
  FileName := CreateCsvFile('101;10:00:00');
  try
    Plan := TCompetitionImportService.PrepareResultsFile(FileName);
    try
      Request := Default(TResultsImportRequest);
      Request.StageIndex := 2;
      try
        TCompetitionImportService.ApplyResults(Plan, FContext, FStages, Request);
        Fail('A backup decision is required');
      except
        on E: EArgumentException do ;
      end;
      FQuery.SQL.Text := 'SELECT finishtime2 FROM main WHERE number = 101;';
      FQuery.Open;
      AssertEquals('09:00:00', FQuery.Fields[0].AsString);
    finally
      Plan.Free;
    end;
  finally
    DeleteFile(FileName);
  end;
end;

initialization
  RegisterTest(TCompetitionImportServiceTests);

end.
