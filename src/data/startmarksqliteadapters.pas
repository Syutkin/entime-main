unit StartMarkSqliteAdapters;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, CompetitionDbContext, StageModel, StartMark, StartMarkMatcher,
  StartMarkService, StartMarkRepository;

type
  { TSqliteStartMarkPersistence }

  TSqliteStartMarkPersistence = class(TInterfacedObject,
    IStartMarkPersistence)
  private
    FRepository: TStartMarkRepository;
  public
    constructor Create(const AContext: TCompetitionDbContext);
    destructor Destroy; override;
    function Insert(const AMark: TStartMark): TStartMark;
    function TryLoadById(const AMarkId: int64;
      out AMark: TStartMark): boolean;
    function HideWorkQueue: integer;
    procedure Update(const AMark: TStartMark);
  end;

  { TSqliteStartMarkCandidateProvider }

  TSqliteStartMarkCandidateProvider = class(TInterfacedObject,
    IStartMarkCandidateProvider)
  private
    FContext: TCompetitionDbContext;
    FStages: TStages;
  public
    constructor Create(const AContext: TCompetitionDbContext;
      const AStages: TStages);
    procedure LoadCandidates(const AStageIndex: integer;
      out ACandidates: TStartMarkCandidateArray);
  end;

  { TSqliteStartMarkApplyPort }

  TSqliteStartMarkApplyPort = class(TInterfacedObject,
    IStartMarkApplyPort)
  private
    FContext: TCompetitionDbContext;
    FStages: TStages;
  public
    constructor Create(const AContext: TCompetitionDbContext;
      const AStages: TStages);
    function TryApply(const ARequest: TStartMarkApplyRequest;
      out AFailure: TStartMarkApplyFailure;
      out ADiagnostic: string): boolean;
  end;

implementation

uses
  DB, SQLDB, DbSql, ParticipantStageData, CompetitionResultsService;

function TryParseStartTime(const AText: string;
  out AValue: TDateTime): boolean;
var
  Hour, Millisecond, Minute, Second: integer;
  Text: string;
begin
  AValue := 0;
  Text := Trim(AText);
  Result := ((Length(Text) = 8) or (Length(Text) = 12)) and
    (Text[3] = ':') and (Text[6] = ':') and
    TryStrToInt(Copy(Text, 1, 2), Hour) and
    TryStrToInt(Copy(Text, 4, 2), Minute) and
    TryStrToInt(Copy(Text, 7, 2), Second);
  if not Result then
    Exit;

  Millisecond := 0;
  if Length(Text) = 12 then
  begin
    Result := (Text[9] in ['.', ',']) and
      TryStrToInt(Copy(Text, 10, 3), Millisecond);
    if not Result then
      Exit;
  end;
  Result := TryEncodeTime(Hour, Minute, Second, Millisecond, AValue);
end;

{ TSqliteStartMarkPersistence }

constructor TSqliteStartMarkPersistence.Create(
  const AContext: TCompetitionDbContext);
begin
  inherited Create;
  FRepository := TStartMarkRepository.Create(AContext);
end;

destructor TSqliteStartMarkPersistence.Destroy;
begin
  FRepository.Free;
  inherited Destroy;
end;

function TSqliteStartMarkPersistence.Insert(
  const AMark: TStartMark): TStartMark;
begin
  Result := FRepository.Insert(AMark);
end;

function TSqliteStartMarkPersistence.TryLoadById(const AMarkId: int64;
  out AMark: TStartMark): boolean;
begin
  Result := FRepository.TryLoadById(AMarkId, AMark);
end;

function TSqliteStartMarkPersistence.HideWorkQueue: integer;
begin
  Result := FRepository.HideWorkQueue;
end;

procedure TSqliteStartMarkPersistence.Update(const AMark: TStartMark);
begin
  FRepository.Update(AMark);
end;

{ TSqliteStartMarkCandidateProvider }

constructor TSqliteStartMarkCandidateProvider.Create(
  const AContext: TCompetitionDbContext; const AStages: TStages);
begin
  inherited Create;
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  FContext := AContext;
  FStages := AStages;
end;

procedure TSqliteStartMarkCandidateProvider.LoadCandidates(
  const AStageIndex: integer; out ACandidates: TStartMarkCandidateArray);
var
  CandidateTime: TDateTime;
  Q: TSQLQuery;
begin
  ACandidates := nil;
  if not FStages.IsValidIndex(AStageIndex) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index %d is outside the range 1..%d.',
      [AStageIndex, FStages.Count]);

  Q := FContext.CreateQuery(nil);
  try
    Q.SQL.Text := Format(
      'SELECT number, starttime%d AS start_time FROM main ' +
      'WHERE number IS NOT NULL AND starttime%d IS NOT NULL ' +
      'ORDER BY number;', [AStageIndex, AStageIndex]);
    Q.Open;
    while not Q.EOF do
    begin
      if TryParseStartTime(Q.FieldByName('start_time').AsString,
        CandidateTime) then
      begin
        SetLength(ACandidates, Length(ACandidates) + 1);
        ACandidates[High(ACandidates)] := TStartMarkCandidate.Create(
          Q.FieldByName('number').AsInteger, AStageIndex, CandidateTime);
      end;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

{ TSqliteStartMarkApplyPort }

constructor TSqliteStartMarkApplyPort.Create(
  const AContext: TCompetitionDbContext; const AStages: TStages);
begin
  inherited Create;
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  if AStages = nil then
    raise EArgumentNilException.Create('AStages');
  FContext := AContext;
  FStages := AStages;
end;

function TSqliteStartMarkApplyPort.TryApply(
  const ARequest: TStartMarkApplyRequest;
  out AFailure: TStartMarkApplyFailure;
  out ADiagnostic: string): boolean;
var
  AppliedMark: TStartMark;
  Q: TSQLQuery;
  StageData: TParticipantStageData;
  UnitOfWork: TCompetitionUnitOfWork;
begin
  Result := False;
  AFailure := smafNone;
  ADiagnostic := '';
  Q := FContext.CreateQuery(nil);
  UnitOfWork := nil;
  try
    try
      if not FStages.IsValidIndex(ARequest.StageIndex) then
        raise EArgumentOutOfRangeException.CreateFmt(
          'Stage index %d is outside the range 1..%d.',
          [ARequest.StageIndex, FStages.Count]);

      UnitOfWork := FContext.BeginUnitOfWork;
      if not TMainSql.TryLoadParticipantStageData(Q,
        ARequest.ParticipantNumber, ARequest.StageIndex, FStages.Count,
        StageData) then
      begin
        AFailure := smafParticipantNotFound;
        ADiagnostic := StartMarkApplyFailureCode(AFailure);
        Exit;
      end;
      if StageData.HasCorrection and
        not ARequest.OverwriteExistingCorrection then
      begin
        AFailure := smafExistingCorrection;
        ADiagnostic := StartMarkApplyFailureCode(AFailure);
        Exit;
      end;

      TMainSql.ExecUpdateCorrection(Q, ARequest.StageIndex,
        ARequest.CorrectionMs, ARequest.ParticipantNumber, FStages.Count);

      AppliedMark := Default(TStartMark);
      AppliedMark.Id := ARequest.MarkId;
      AppliedMark.HasAppliedStageIndex := True;
      AppliedMark.AppliedStageIndex := ARequest.StageIndex;
      AppliedMark.HasParticipantNumber := True;
      AppliedMark.ParticipantNumber := ARequest.ParticipantNumber;
      AppliedMark.HasMatchDeltaMs := ARequest.HasMatchDeltaMs;
      AppliedMark.MatchDeltaMs := ARequest.MatchDeltaMs;
      AppliedMark.HasAssignmentMode := True;
      AppliedMark.AssignmentMode := ARequest.AssignmentMode;
      AppliedMark.Status := smsApplied;
      AppliedMark.HasAppliedAt := True;
      AppliedMark.AppliedAt := ARequest.AppliedAt;
      TStartMarkSql.ExecUpdate(Q, AppliedMark);

      TResultCalculationService.RecalculateAllInCurrentTransaction(
        FContext, FStages);
      UnitOfWork.Commit;
      Result := True;
    except
      on E: Exception do
      begin
        AFailure := smafApplicationError;
        ADiagnostic := E.Message;
      end;
    end;
  finally
    UnitOfWork.Free;
    Q.Free;
  end;
end;

end.
