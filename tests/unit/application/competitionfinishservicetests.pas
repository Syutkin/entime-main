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
    procedure Batch_CalculatesOnceAndReturnsFinalPlaces;
    procedure Batch_InvalidRequestRollsBackEarlierFinishes;
    procedure Batch_CalculationFailureRollsBackAllMarks;
    procedure Batch_EmptyDoesNotWrite;
    procedure TelegramNotifier_BuildsEncodedRequest;
    procedure TelegramNotifier_UsesCompactTimesWithoutLosingPrecision;
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
  Request := TFinishRequest.Create(503, 1, '00:09:00.000', ftpRequireOnTrack,
    fopRejectExisting);

  AssertTrue(TFinishService.TrySave(FContext, FStages, Request, Saved, Failure));

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
  Request := TFinishRequest.Create(504, 1, '10:11:00.000', ftpRequireOnTrack,
    fopRejectExisting);

  AssertFalse(TFinishService.TrySave(FContext, FStages, Request, Saved, Failure));
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
  Request := TFinishRequest.Create(505, 1, '10:12:00.000', ftpAllowNotOnTrack,
    fopRejectExisting);

  AssertFalse(TFinishService.TrySave(FContext, FStages, Request, Saved, Failure));
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
    'INSERT INTO main (number, starttime1) VALUES ' + '(506, ''00:00:00.000'');');
  ExecSql(
    'CREATE TRIGGER fail_result_update BEFORE UPDATE OF result1 ON main ' +
    'WHEN NEW.number = 506 BEGIN ' +
    'SELECT RAISE(ABORT, ''forced calculation failure''); END;');
  Request := TFinishRequest.Create(506, 1, '00:10:00.000', ftpRequireOnTrack,
    fopRejectExisting);

  AssertFalse(TFinishService.TrySave(FContext, FStages, Request, Saved, Failure));
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

    AssertTrue(TFinishService.TrySave(FContext, FStages, Request, Saved, Failure));

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
    'INSERT INTO main (number, starttime1) VALUES ' + '(508, ''00:00:00.000'');');
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

    AssertFalse(TFinishService.TrySave(FContext, FStages, Request, Saved, Failure));

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
    'INSERT INTO main (number, starttime1) VALUES ' + '(509, ''00:00:00.000'');');
  Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
    EncodeTime(0, 9, 0, 0), TTimingMarkSource.Serial('COM7'),
    EncodeDateTime(2026, 8, 15, 10, 0, 0, 0)), 1);
  AssertTrue(Mark.TryApply(99, EncodeDateTime(2026, 8, 15, 10, 0, 1, 0)));
  Repository := TFinishMarkRepository.Create(FContext);
  try
    InsertedMark := Repository.Insert(Mark);
    Request := TFinishRequest.CreateForMark(InsertedMark.Id, 509,
      ftpRequireOnTrack, fopRejectExisting, EncodeDateTime(2026,
      8, 15, 10, 0, 2, 0));

    AssertFalse(TFinishService.TrySave(FContext, FStages, Request, Saved, Failure));

    AssertEquals(Ord(ffkFinishMarkNotPending), Ord(Failure.Kind));
    FQuery.SQL.Text := 'SELECT finishtime1 FROM main WHERE number = 509;';
    FQuery.Open;
    AssertTrue(FQuery.FieldByName('finishtime1').IsNull);
    FQuery.Close;
  finally
    Repository.Free;
  end;
end;

procedure TCompetitionFinishServiceTests.Batch_CalculatesOnceAndReturnsFinalPlaces;
var
  Requests: TFinishRequests;
  Saved: TFinishResults;
  Failure: TFinishFailure;
  FailedIndex: integer;
begin
  ExecSql('INSERT INTO main (number, category, starttime1) VALUES ' +
    '(1, ''A'', ''00:00:00.000''), (2, ''A'', ''00:00:00.000'');');
  FStages[2].isActive := True;
  ExecSql('CREATE TRIGGER forbid_unaffected BEFORE UPDATE OF result2 ON main ' +
    'BEGIN SELECT RAISE(ABORT, ''unaffected stage recalculated''); END;');
  ExecSql('CREATE TABLE calculation_count (n INTEGER);');
  ExecSql('INSERT INTO calculation_count VALUES (0);');
  ExecSql('CREATE TRIGGER count_calculation AFTER UPDATE OF result1 ON main ' +
    'BEGIN UPDATE calculation_count SET n = n + 1; END;');
  SetLength(Requests, 2);
  Requests[0] := TFinishRequest.Create(1, 1, '00:15:00.000',
    ftpRequireOnTrack, fopRejectExisting);
  Requests[1] := TFinishRequest.Create(2, 1, '00:10:00.000',
    ftpRequireOnTrack, fopRejectExisting);
  AssertTrue(TFinishService.TrySaveBatch(FContext, FStages, Requests,
    Saved, Failure, FailedIndex));
  AssertEquals(-1, FailedIndex);
  AssertEquals(2, Length(Saved));
  AssertEquals(2, Saved[0].Place);
  AssertEquals('00:05:00.000', Saved[0].Difference);
  AssertEquals(1, Saved[1].Place);
  FQuery.SQL.Text := 'SELECT n FROM calculation_count;';
  FQuery.Open;
  AssertEquals('Each participant is calculated once per batch', 2,
    FQuery.Fields[0].AsInteger);
end;

procedure TCompetitionFinishServiceTests.Batch_InvalidRequestRollsBackEarlierFinishes;
var
  Requests: TFinishRequests;
  Saved: TFinishResults;
  Failure: TFinishFailure;
  FailedIndex: integer;
begin
  ExecSql('INSERT INTO main (number, starttime1) VALUES (1, ''00:00:00.000'');');
  SetLength(Requests, 2);
  Requests[0] := TFinishRequest.Create(1, 1, '00:10:00.000',
    ftpRequireOnTrack, fopRejectExisting);
  Requests[1] := TFinishRequest.Create(999, 1, '00:11:00.000',
    ftpAllowNotOnTrack, fopRejectExisting);
  AssertFalse(TFinishService.TrySaveBatch(FContext, FStages, Requests,
    Saved, Failure, FailedIndex));
  AssertEquals(1, FailedIndex);
  AssertEquals(Ord(ffkParticipantMissing), Ord(Failure.Kind));
  AssertEquals(0, Length(Saved));
  FQuery.SQL.Text := 'SELECT finishtime1, result1 FROM main WHERE number = 1;';
  FQuery.Open;
  AssertTrue(FQuery.Fields[0].IsNull);
  AssertTrue(FQuery.Fields[1].IsNull);
end;

procedure TCompetitionFinishServiceTests.Batch_CalculationFailureRollsBackAllMarks;
var
  Requests: TFinishRequests;
  Saved: TFinishResults;
  Failure: TFinishFailure;
  FailedIndex, I: integer;
  Repository: TFinishMarkRepository;
  Mark, Loaded: TFinishMark;
  MarkIds: array[0..1] of int64;
begin
  ExecSql('INSERT INTO main (number, starttime1) VALUES ' +
    '(1, ''00:00:00.000''), (2, ''00:00:00.000'');');
  // Fail only after both finishes have been written, so a sequential path
  // would already have committed the first mark.
  ExecSql('CREATE TRIGGER fail_batch BEFORE UPDATE OF result1 ON main ' +
    'WHEN NEW.number = 2 AND NEW.finishtime1 IS NOT NULL ' +
    'BEGIN SELECT RAISE(ABORT, ''batch failure''); END;');
  Repository := TFinishMarkRepository.Create(FContext);
  try
    SetLength(Requests, 2);
    for I := 0 to 1 do
    begin
      Mark := TFinishMark.FromTimingMark(TTimingMark.Finish(
        EncodeTime(0, 10 + I, 0, 0), TTimingMarkSource.Serial('test'), Now), 1);
      Mark := Repository.Insert(Mark);
      MarkIds[I] := Mark.Id;
      Requests[I] := TFinishRequest.CreateForMark(Mark.Id, I + 1,
        ftpRequireOnTrack, fopRejectExisting, Now);
    end;
    AssertFalse(TFinishService.TrySaveBatch(FContext, FStages, Requests,
      Saved, Failure, FailedIndex));
    AssertEquals(0, Length(Saved));
    for I := 0 to 1 do
    begin
      AssertTrue(Repository.TryLoadById(MarkIds[I], Loaded));
      AssertEquals(Ord(fmsPending), Ord(Loaded.Status));
      AssertFalse(Loaded.HasAppliedAt);
    end;
    FQuery.SQL.Text := 'SELECT COUNT(*) FROM main WHERE finishtime1 IS NOT NULL;';
    FQuery.Open;
    AssertEquals(0, FQuery.Fields[0].AsInteger);
  finally
    Repository.Free;
  end;
end;

procedure TCompetitionFinishServiceTests.Batch_EmptyDoesNotWrite;
var
  Saved: TFinishResults;
  Failure: TFinishFailure;
  FailedIndex: integer;
begin
  AssertTrue(TFinishService.TrySaveBatch(FContext, FStages, [], Saved,
    Failure, FailedIndex));
  AssertEquals(0, Length(Saved));
  AssertEquals(-1, FailedIndex);
  AssertFalse(FContext.Transaction.Active);
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
TelegramNotifier_UsesCompactTimesWithoutLosingPrecision;
const
  Times: array[0..6] of string = ('00:02:34.567', '00:59:59.999',
    '01:00:00.000', '01:02:03.456', '10:02:03.456',
    '00:00:03.456', '00:00:00.000');
  Expected: array[0..6] of string = ('2:34.567', '59:59.999',
    '1:00:00.000', '1:02:03.456', '10:02:03.456', '3.456', '0.000');
var
  Finish: TFinishResult;
  Request: THttpRequest;
  I, Place: integer;
  Sign: string;
begin
  Finish := CreateNotificationResult;
  for I := Low(Times) to High(Times) do
    for Place := 1 to 2 do
    begin
      Finish.ResultValue := Times[I];
      Finish.Difference := Times[I];
      Finish.Place := Place;
      if Place = 1 then Sign := '-'
      else
        Sign := '';
      Request := TTelegramResultNotifier.BuildRequest(Finish,
        'https://example.invalid/notify');
      AssertTrue('Telegram must omit leading zeros and retain milliseconds: ' + Times[I],
        Pos('result=' + string(FormUrlEncode(Expected[I])) + '&', Request.Url) > 0);
      AssertTrue('Telegram difference must retain its full value and sign',
        Pos('diff=' + string(FormUrlEncode(Sign + Expected[I])) + '&', Request.Url) > 0);
    end;
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
