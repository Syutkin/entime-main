unit CompetitionRefreshCoordinator;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, SQLDB, DbSql;

type
  TRefreshStageQueries = function(out AErrors: string;
    out AQueryCount: integer): integer of object;

  TCompetitionRefreshOutcome = record
    ErrorCount: integer;
    Errors: string;
    RefreshedQueryCount: integer;
    StageQueryCount: integer;
    HadCurrentParticipant: boolean;
    CurrentParticipantId: integer;
    CurrentParticipantRestored: boolean;
  end;

  TCompetitionRefreshCoordinator = record
  private
    class procedure AppendErrors(var AOutcome: TCompetitionRefreshOutcome;
      const AErrorCount: integer; const AErrors: string); static;
    class procedure RefreshQueryGroup(const AContext: TCompetitionDbContext;
      const AQueries: array of TSQLQuery;
      var AOutcome: TCompetitionRefreshOutcome); static;
    class procedure RefreshMainQuery(const AContext: TCompetitionDbContext;
      const AMainQuery: TSQLQuery; var AOutcome: TCompetitionRefreshOutcome);
      static;
  public
    class function RefreshAll(const AContext: TCompetitionDbContext;
      const AMainQuery: TSQLQuery;
      const ABaseQueries, AResultQueries: array of TSQLQuery;
      const ARefreshStageQueries: TRefreshStageQueries): TCompetitionRefreshOutcome;
      static;
    class function RefreshResults(const AContext: TCompetitionDbContext;
      const AResultQueries: array of TSQLQuery): TCompetitionRefreshOutcome; static;
  end;

implementation

uses
  DB, AppLogger;

class procedure TCompetitionRefreshCoordinator.AppendErrors(
  var AOutcome: TCompetitionRefreshOutcome; const AErrorCount: integer;
  const AErrors: string);
begin
  Inc(AOutcome.ErrorCount, AErrorCount);
  if AErrors = '' then
    Exit;
  if AOutcome.Errors <> '' then
    AOutcome.Errors := AOutcome.Errors + LineEnding;
  AOutcome.Errors := AOutcome.Errors + AErrors;
end;

class procedure TCompetitionRefreshCoordinator.RefreshQueryGroup(
  const AContext: TCompetitionDbContext; const AQueries: array of TSQLQuery;
  var AOutcome: TCompetitionRefreshOutcome);
var
  ErrorCount: integer;
  Errors: string;
begin
  if Length(AQueries) = 0 then
    Exit;
  ErrorCount := AContext.RefreshQueries(AQueries, Errors);
  AppendErrors(AOutcome, ErrorCount, Errors);
  Inc(AOutcome.RefreshedQueryCount, Length(AQueries));
end;

class procedure TCompetitionRefreshCoordinator.RefreshMainQuery(
  const AContext: TCompetitionDbContext; const AMainQuery: TSQLQuery;
  var AOutcome: TCompetitionRefreshOutcome);
var
  ControlsDisabled: boolean;
  ErrorCount: integer;
  Errors, QueryLabel: string;
begin
  if AMainQuery = nil then
    Exit;
  QueryLabel := AMainQuery.Name;
  if QueryLabel = '' then
    QueryLabel := 'TSQLQuery';
  AOutcome.HadCurrentParticipant :=
    AMainQuery.Active and TMainSql.TryGetCurrentId(AMainQuery,
    AOutcome.CurrentParticipantId);
  ControlsDisabled := False;
  try
    try
      AMainQuery.DisableControls;
      ControlsDisabled := True;
    except
      on E: Exception do
        AppendErrors(AOutcome, 1, QueryLabel + ': ' + E.Message);
    end;
    try
      ErrorCount := AContext.RefreshQueries([AMainQuery], Errors);
      AppendErrors(AOutcome, ErrorCount, Errors);
      Inc(AOutcome.RefreshedQueryCount);
      if (ErrorCount = 0) and not AMainQuery.IsEmpty then
      begin
        AMainQuery.Last;
        AMainQuery.First;
      end;
    except
      on E: Exception do
        AppendErrors(AOutcome, 1, QueryLabel + ': ' + E.Message);
    end;
  finally
    if ControlsDisabled then
    begin
      try
        AMainQuery.EnableControls;
      except
        on E: Exception do
          AppendErrors(AOutcome, 1, QueryLabel + ': ' + E.Message);
      end;
    end;
  end;
end;

class function TCompetitionRefreshCoordinator.RefreshAll(
  const AContext: TCompetitionDbContext; const AMainQuery: TSQLQuery;
  const ABaseQueries, AResultQueries: array of TSQLQuery;
  const ARefreshStageQueries: TRefreshStageQueries): TCompetitionRefreshOutcome;
var
  ErrorCount, QueryCount: integer;
  Errors: string;
  PerformanceTrace: TPerformanceTrace;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  Result := Default(TCompetitionRefreshOutcome);
  PerformanceTrace := TPerformanceTrace.Create('ui.refresh_all', alsDatabase);
  try
    RefreshMainQuery(AContext, AMainQuery, Result);
    PerformanceTrace.Step('main_query');
    RefreshQueryGroup(AContext, ABaseQueries, Result);
    PerformanceTrace.Step('base_queries',
      'query_count=' + IntToStr(Length(ABaseQueries)));
    if Assigned(ARefreshStageQueries) then
    begin
      try
        ErrorCount := ARefreshStageQueries(Errors, QueryCount);
      except
        on E: Exception do
        begin
          ErrorCount := 1;
          QueryCount := 0;
          Errors := E.Message;
        end;
      end;
      Result.StageQueryCount := QueryCount;
      Inc(Result.RefreshedQueryCount, QueryCount);
      AppendErrors(Result, ErrorCount, Errors);
    end;
    PerformanceTrace.Step('stage_queries',
      'query_count=' + IntToStr(Result.StageQueryCount));
    RefreshQueryGroup(AContext, AResultQueries, Result);
    PerformanceTrace.Step('result_queries',
      'query_count=' + IntToStr(Length(AResultQueries)));
    if Result.HadCurrentParticipant and AMainQuery.Active then
    try
      Result.CurrentParticipantRestored :=
        AMainQuery.Locate('id', Result.CurrentParticipantId, []);
    except
      on E: Exception do
        AppendErrors(Result, 1, AMainQuery.Name + ': ' + E.Message);
    end;
    if Result.ErrorCount = 0 then
      PerformanceTrace.Finish('ok')
    else
      PerformanceTrace.Finish('error',
        'error_count=' + IntToStr(Result.ErrorCount));
  finally
    PerformanceTrace.Free;
  end;
end;

class function TCompetitionRefreshCoordinator.RefreshResults(
  const AContext: TCompetitionDbContext;
  const AResultQueries: array of TSQLQuery): TCompetitionRefreshOutcome;
begin
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  Result := Default(TCompetitionRefreshOutcome);
  RefreshQueryGroup(AContext, AResultQueries, Result);
end;

end.
