unit CompetitionFinishServiceTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, DB, SQLDB, fpcunit, testregistry, DbSql,
  StageModel,
  CompetitionResultsService, CompetitionFinishService, TimingMark,
  FinishMark, FinishMarkRepository, HttpTransport, FakeHttpTransport;

type
  TCompetitionFinishServiceTests = class(TTestCase)
  private
    FContext: TCompetitionDbContext;
    FQuery: TSQLQuery;
    FStages: TStages;
    procedure CreateSchema;
    procedure ExecSql(const ASql: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Inspect_ReturnsParticipantTrackAndOverwriteState;
    procedure TrySave_CommitsFinishCalculationAndNotificationData;
    procedure TrySave_RejectsNotOnTrackWithoutExplicitPolicy;
    procedure TrySave_RejectsExistingResultWithoutOverwritePolicy;
    procedure TrySave_CalculationFailureRollsBackFinish;
    procedure TrySaveMark_CommitsResultAndAppliedMarkAtomically;
    procedure TrySaveMark_CalculationFailureRollsBackMarkAndResult;
    procedure TrySaveMark_RejectsAlreadyAppliedMark;
    procedure TelegramNotifier_BuildsEncodedRequest;
    procedure TelegramNotifier_RedactsEndpointOnFailure;
  end;

implementation

function CreateNotificationResult: TFinishResult;
begin
  Result.ParticipantNumber := 503;
  Result.ParticipantName := 'Runner Name';
  Result.Category := 'Open Class';
  Result.StageIndex := 1;
  Result.FinishTime := '10:09:00.000';
  Result.ResultValue := '00:09:00.000';
  Result.Place := 1;
  Result.Difference := '00:01:00.000';
  Result.PreviousLeaderNumber := 502;
  Result.PreviousLeaderResult := '00:10:00.000';
end;

procedure TCompetitionFinishServiceTests.SetUp;
begin
  FContext := TCompetitionDbContext.Create;
  FContext.OpenFile(':memory:');
  FQuery := FContext.CreateQuery(nil);
  FStages := TStages.Create(2);
  CreateSchema;
end;

procedure TCompetitionFinishServiceTests.TearDown;
begin
  FStages.Free;
  FQuery.Free;
  FContext.Free;
end;

procedure TCompetitionFinishServiceTests.CreateSchema;
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

procedure TCompetitionFinishServiceTests.ExecSql(const ASql: string);
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  UnitOfWork := FContext.BeginUnitOfWork;
  try
    FQuery.Close;
    FQuery.SQL.Text := ASql;
    FQuery.ExecSQL;
    UnitOfWork.Commit;
  finally
    UnitOfWork.Free;
  end;
end;

procedure TCompetitionFinishServiceTests.
  Inspect_ReturnsParticipantTrackAndOverwriteState;
var
  Inspection: TFinishInspection;
begin
  ExecSql(
    'INSERT INTO main (number, name, category, starttime1, result1) VALUES ' +
    '(501, ''Runner'', ''Open'', ''00:00:00.000'', ''00:10:00.000'');');

  Inspection := TFinishService.Inspect(FContext, FStages, 501, 1);

  AssertTrue(Inspection.ParticipantExists);
  AssertTrue(Inspection.IsOnTrack);
  AssertTrue(Inspection.HasExistingResult);
end;

procedure TCompetitionFinishServiceTests.
  TrySave_CommitsFinishCalculationAndNotificationData;
var
  Failure: TFinishFailure;
  Request: TFinishRequest;
  Saved: TFinishResult;
begin
  ExecSql(
    'INSERT INTO main (number, name, category, starttime1, finishtime1) ' +
    'VALUES (502, ''Leader'', ''Open'', ''00:00:00.000'', ' +
    '''00:10:00.000''), (503, ''Winner'', ''Open'', ''00:00:00.000'', NULL);');
  TResultCalculationService.RecalculateAll(FContext, FStages);
  Request := TFinishRequest.Create(503, 1, '00:09:00.000',
    ftpRequireOnTrack, fopRejectExisting);

  AssertTrue(TFinishService.TrySave(FContext, FStages, Request,
    Saved, Failure));

  AssertEquals(503, Saved.ParticipantNumber);
  AssertEquals('Winner', Saved.ParticipantName);
  AssertEquals('Open', Saved.Category);
  AssertEquals('00:09:00.000', Saved.FinishTime);
  AssertEquals('00:09:00.000', Saved.ResultValue);
  AssertEquals(1, Saved.Place);
  AssertEquals(502, Saved.PreviousLeaderNumber);
  AssertEquals('00:10:00.000', Saved.PreviousLeaderResult);
  AssertEquals('00:01:00.000', Saved.Difference);

  FQuery.SQL.Text :=
    'SELECT finishtime1, result1, place1 FROM main WHERE number = 503;';
  FQuery.Open;
  AssertEquals('00:09:00.000', FQuery.FieldByName('finishtime1').AsString);
  AssertEquals('00:09:00.000', FQuery.FieldByName('result1').AsString);
  AssertEquals(1, FQuery.FieldByName('place1').AsInteger);
end;

procedure TCompetitionFinishServiceTests.
  TrySave_RejectsNotOnTrackWithoutExplicitPolicy;
var
  Failure: TFinishFailure;
  Request: TFinishRequest;
  Saved: TFinishResult;
begin
  ExecSql('INSERT INTO main (number, name) VALUES (504, ''Runner'');');
  Request := TFinishRequest.Create(504, 1, '10:11:00.000',
    ftpRequireOnTrack, fopRejectExisting);

  AssertFalse(TFinishService.TrySave(FContext, FStages, Request,
    Saved, Failure));
  AssertEquals(Ord(ffkNotOnTrack), Ord(Failure.Kind));

  FQuery.SQL.Text := 'SELECT finishtime1 FROM main WHERE number = 504;';
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('finishtime1').IsNull);
end;

procedure TCompetitionFinishServiceTests.
  TrySave_RejectsExistingResultWithoutOverwritePolicy;
var
  Failure: TFinishFailure;
  Request: TFinishRequest;
  Saved: TFinishResult;
begin
  ExecSql(
    'INSERT INTO main (number, starttime1, finishtime1, result1) VALUES ' +
    '(505, ''10:00:00.000'', ''10:10:00.000'', ''00:10:00.000'');');
  Request := TFinishRequest.Create(505, 1, '10:12:00.000',
    ftpAllowNotOnTrack, fopRejectExisting);

  AssertFalse(TFinishService.TrySave(FContext, FStages, Request,
    Saved, Failure));
  AssertEquals(Ord(ffkExistingResult), Ord(Failure.Kind));

  FQuery.SQL.Text := 'SELECT finishtime1 FROM main WHERE number = 505;';
  FQuery.Open;
  AssertEquals('10:10:00.000',
    FQuery.FieldByName('finishtime1').AsString);
end;

procedure TCompetitionFinishServiceTests.
  TrySave_CalculationFailureRollsBackFinish;
var
  Failure: TFinishFailure;
  Request: TFinishRequest;
  Saved: TFinishResult;
begin
  ExecSql(
    'INSERT INTO main (number, starttime1) VALUES ' +
    '(506, ''00:00:00.000'');');
  ExecSql(
    'CREATE TRIGGER fail_result_update BEFORE UPDATE OF result1 ON main ' +
    'WHEN NEW.number = 506 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced calculation failure''); END;');
  Request := TFinishRequest.Create(506, 1, '00:10:00.000',
    ftpRequireOnTrack, fopRejectExisting);

  AssertFalse(TFinishService.TrySave(FContext, FStages, Request,
    Saved, Failure));
  AssertEquals(Ord(ffkDatabase), Ord(Failure.Kind));
  AssertTrue(Pos('forced calculation failure', Failure.SafeMessage) > 0);

  FQuery.SQL.Text :=
    'SELECT finishtime1, result1 FROM main WHERE number = 506;';
  FQuery.Open;
  AssertTrue(FQuery.FieldByName('finishtime1').IsNull);
  AssertTrue(FQuery.FieldByName('result1').IsNull);
end;

procedure TCompetitionFinishServiceTests.
  TrySaveMark_CommitsResultAndAppliedMarkAtomically;
var
  AppliedAt: TDateTime;
  Failure: TFinishFailure;
  InsertedMark, LoadedMark, Mark: TFinishMark;
  Repository: TFinishMarkRepository;
  Request: TFinishRequest;
  Saved: TFinishResult;
begin
  ExecSql(
    'INSERT INTO main (number, name, category, starttime1) VALUES ' +
    '(507, ''Runner'', ''Open'', ''00:00:00.000'');');
  Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
    EncodeTime(0, 12, 34, 567), TTimingMarkSource.Serial('COM7'),
    EncodeDateTime(2026, 8, 15, 10, 0, 0, 0)), 1);
  Repository := TFinishMarkRepository.Create(FContext);
  try
    InsertedMark := Repository.Insert(Mark);
    AppliedAt := EncodeDateTime(2026, 8, 15, 10, 0, 2, 0);
    Request := TFinishRequest.CreateForMark(InsertedMark.Id, 507,
      ftpRequireOnTrack, fopRejectExisting, AppliedAt);

    AssertTrue(TFinishService.TrySave(FContext, FStages, Request,
      Saved, Failure));

    AssertEquals('00:12:34.567', Saved.FinishTime);
    FQuery.SQL.Text :=
      'SELECT finishtime1, result1 FROM main WHERE number = 507;';
    FQuery.Open;
    AssertEquals('00:12:34.567',
      FQuery.FieldByName('finishtime1').AsString);
    AssertEquals('00:12:34.567', FQuery.FieldByName('result1').AsString);
    FQuery.Close;
    AssertTrue(Repository.TryLoadById(InsertedMark.Id, LoadedMark));
    AssertEquals(Ord(fmsApplied), Ord(LoadedMark.Status));
    AssertTrue(LoadedMark.HasParticipantNumber);
    AssertEquals(507, LoadedMark.ParticipantNumber);
    AssertTrue(LoadedMark.HasAssignmentMode);
    AssertEquals(Ord(fmamManual), Ord(LoadedMark.AssignmentMode));
    AssertTrue(LoadedMark.HasAppliedAt);
    AssertEquals(AppliedAt, LoadedMark.AppliedAt);
  finally
    Repository.Free;
  end;
end;

procedure TCompetitionFinishServiceTests.
  TrySaveMark_CalculationFailureRollsBackMarkAndResult;
var
  AppliedAt: TDateTime;
  Failure: TFinishFailure;
  InsertedMark, LoadedMark, Mark: TFinishMark;
  Repository: TFinishMarkRepository;
  Request: TFinishRequest;
  Saved: TFinishResult;
begin
  ExecSql(
    'INSERT INTO main (number, starttime1) VALUES ' +
    '(508, ''00:00:00.000'');');
  ExecSql(
    'CREATE TRIGGER fail_marked_result_update BEFORE UPDATE OF result1 ON main ' +
    'WHEN NEW.number = 508 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced marked calculation failure''); END;');
  Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
    EncodeTime(0, 10, 0, 0), TTimingMarkSource.Ble('ENTime-8'),
    EncodeDateTime(2026, 8, 15, 10, 0, 0, 0)), 1);
  Repository := TFinishMarkRepository.Create(FContext);
  try
    InsertedMark := Repository.Insert(Mark);
    AppliedAt := EncodeDateTime(2026, 8, 15, 10, 0, 2, 0);
    Request := TFinishRequest.CreateForMark(InsertedMark.Id, 508,
      ftpRequireOnTrack, fopRejectExisting, AppliedAt);

    AssertFalse(TFinishService.TrySave(FContext, FStages, Request,
      Saved, Failure));

    AssertEquals(Ord(ffkDatabase), Ord(Failure.Kind));
    FQuery.SQL.Text :=
      'SELECT finishtime1, result1 FROM main WHERE number = 508;';
    FQuery.Open;
    AssertTrue(FQuery.FieldByName('finishtime1').IsNull);
    AssertTrue(FQuery.FieldByName('result1').IsNull);
    FQuery.Close;
    AssertTrue(Repository.TryLoadById(InsertedMark.Id, LoadedMark));
    AssertEquals(Ord(fmsPending), Ord(LoadedMark.Status));
    AssertFalse(LoadedMark.HasParticipantNumber);
    AssertFalse(LoadedMark.HasAppliedAt);
  finally
    Repository.Free;
  end;
end;

procedure TCompetitionFinishServiceTests.
  TrySaveMark_RejectsAlreadyAppliedMark;
var
  Failure: TFinishFailure;
  InsertedMark, Mark: TFinishMark;
  Repository: TFinishMarkRepository;
  Request: TFinishRequest;
  Saved: TFinishResult;
begin
  ExecSql(
    'INSERT INTO main (number, starttime1) VALUES ' +
    '(509, ''00:00:00.000'');');
  Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
    EncodeTime(0, 9, 0, 0), TTimingMarkSource.Serial('COM7'),
    EncodeDateTime(2026, 8, 15, 10, 0, 0, 0)), 1);
  AssertTrue(Mark.TryApply(99,
    EncodeDateTime(2026, 8, 15, 10, 0, 1, 0)));
  Repository := TFinishMarkRepository.Create(FContext);
  try
    InsertedMark := Repository.Insert(Mark);
    Request := TFinishRequest.CreateForMark(InsertedMark.Id, 509,
      ftpRequireOnTrack, fopRejectExisting,
      EncodeDateTime(2026, 8, 15, 10, 0, 2, 0));

    AssertFalse(TFinishService.TrySave(FContext, FStages, Request,
      Saved, Failure));

    AssertEquals(Ord(ffkFinishMarkNotPending), Ord(Failure.Kind));
    FQuery.SQL.Text := 'SELECT finishtime1 FROM main WHERE number = 509;';
    FQuery.Open;
    AssertTrue(FQuery.FieldByName('finishtime1').IsNull);
    FQuery.Close;
  finally
    Repository.Free;
  end;
end;

procedure TCompetitionFinishServiceTests.
  TelegramNotifier_BuildsEncodedRequest;
var
  Notification: TFinishNotificationOutcome;
  Response: THttpResponse;
  Transport: IHttpTransport;
  TransportObject: TFakeHttpTransport;
begin
  TransportObject := TFakeHttpTransport.Create;
  Transport := TransportObject;
  Response := Default(THttpResponse);
  Response.Completed := True;
  Response.StatusCode := 200;
  Response.StatusText := 'OK';
  SetLength(Response.Headers, 2);
  Response.Body := 'accepted';
  TransportObject.QueueResponse(Response);

  Notification := TTelegramResultNotifier.Notify(CreateNotificationResult,
    'https://example.invalid/bot-token', Transport);

  AssertTrue(Notification.Success);
  AssertEquals(200, Notification.ResponseStatusCode);
  AssertEquals(1, TransportObject.RequestCount);
  AssertEquals(Ord(hmGet), Ord(TransportObject.Requests[0].Method));
  AssertEquals(3000, TransportObject.Requests[0].ConnectTimeoutMs);
  AssertEquals(5000, TransportObject.Requests[0].ReadTimeoutMs);
  AssertTrue(Pos('number=503', TransportObject.Requests[0].Url) > 0);
  AssertEquals(0, Pos('Runner Name', TransportObject.Requests[0].Url));
  AssertEquals(0, Pos('Open Class', TransportObject.Requests[0].Url));
end;

procedure TCompetitionFinishServiceTests.
  TelegramNotifier_RedactsEndpointOnFailure;
const
  SecretEndpoint = 'https://example.invalid/secret-token';
var
  Notification: TFinishNotificationOutcome;
  Response: THttpResponse;
  Transport: IHttpTransport;
  TransportObject: TFakeHttpTransport;
begin
  TransportObject := TFakeHttpTransport.Create;
  Transport := TransportObject;
  Response := Default(THttpResponse);
  Response.ErrorKind := hekNetwork;
  Response.ErrorMessage := 'delivery failed for ' + SecretEndpoint;
  TransportObject.QueueResponse(Response);

  Notification := TTelegramResultNotifier.Notify(CreateNotificationResult,
    SecretEndpoint, Transport);

  AssertFalse(Notification.Success);
  AssertEquals(Ord(hekNetwork), Ord(Notification.TransportErrorKind));
  AssertEquals(0, Pos(SecretEndpoint, Notification.SafeErrorMessage));
  AssertEquals(0, Pos('secret-token', Notification.SafeErrorMessage));
  AssertTrue(Pos('[redacted]', Notification.SafeErrorMessage) > 0);
end;

initialization
  RegisterTest(TCompetitionFinishServiceTests);

end.
