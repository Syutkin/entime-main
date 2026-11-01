unit DbSql;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SQLDB, ParticipantStatus, StageConfig, ConfigRepository,
  CompetitionSchemaMigrator, StartMarkRepository, FinishMarkRepository,
  CompetitionQueryProvider,
  ParticipantRepository, StageResultRepository, ResultCalculationRepository,
  CompetitionImportRepository, CompetitionDbContext, ParticipantStageData;

const
  CURRENT_COMPETITION_SCHEMA_VERSION =
    CompetitionSchemaMigrator.CURRENT_COMPETITION_SCHEMA_VERSION;
  STARTLIST_SORT_BY_NUMBER_ASC = CompetitionQueryProvider.STARTLIST_SORT_BY_NUMBER_ASC;
  STARTLIST_SORT_BY_NUMBER_DESC = CompetitionQueryProvider.STARTLIST_SORT_BY_NUMBER_DESC;
  STARTLIST_SORT_BY_NAME_ASC = CompetitionQueryProvider.STARTLIST_SORT_BY_NAME_ASC;
  STARTLIST_SORT_BY_NAME_DESC = CompetitionQueryProvider.STARTLIST_SORT_BY_NAME_DESC;
  STARTLIST_SORT_BY_RESULT = CompetitionQueryProvider.STARTLIST_SORT_BY_RESULT;
  srifFullStage = CompetitionImportRepository.srifFullStage;
  srifStart = CompetitionImportRepository.srifStart;
  srifFinish = CompetitionImportRepository.srifFinish;
  smjfAll = StartMarkRepository.smjfAll;
  smjfPending = StartMarkRepository.smjfPending;
  smjfApplied = StartMarkRepository.smjfApplied;
  smjfHidden = StartMarkRepository.smjfHidden;
  smjfConflictOrError = StartMarkRepository.smjfConflictOrError;
  smjfLast15Minutes = StartMarkRepository.smjfLast15Minutes;
  smjfCurrentStage = StartMarkRepository.smjfCurrentStage;

type
  ECompetitionSchemaError =
    CompetitionSchemaMigrator.ECompetitionSchemaError;
  TCompetitionDbContext = CompetitionDbContext.TCompetitionDbContext;
  TCompetitionUnitOfWork = CompetitionDbContext.TCompetitionUnitOfWork;
  TParticipantStatusArray = ParticipantRepository.TParticipantStatusArray;
  TParticipantStatusRow = ParticipantRepository.TParticipantStatusRow;
  TParticipantStatusRows = ParticipantRepository.TParticipantStatusRows;
  TParticipantStageData = ParticipantStageData.TParticipantStageData;
  TQuerySnapshot = CompetitionQueryProvider.TQuerySnapshot;
  TConfigSql = ConfigRepository.TConfigSql;
  TStartMarkJournalFilter = StartMarkRepository.TStartMarkJournalFilter;
  TFinishMarkJournalFilter = FinishMarkRepository.TFinishMarkJournalFilter;

  TMainSql = record
  public
    class function SelectAll: string; static;
    class function SelectNumbers: string; static;
    class function ResetStartTime(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function UpdateStartTime(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function SelectMinStartTime(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function SelectMaxNumber: string; static;
    class function SelectCategoryGrouped: string; static;
    class function SelectCategoryGroupedOrderedByStartTime(
      const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function SelectCategoryResults(const ColumnsCsv: string): string; static;
    class function SelectStatusAll: string; static;
    class function SelectStatusByStage(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function ExportFinishTime(const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;

    class function OpenByNumber(Q: TSQLQuery; const Number: integer): boolean;
      static;
    class function TryGetCurrentId(Q: TSQLQuery; out Id: integer): boolean; static;
    class function TryGetCurrentNumber(Q: TSQLQuery; out Number: string): boolean;
      static;
    class function TryLoadIdentity(Q: TSQLQuery; const Number: integer;
      out ParticipantName, Category: string): boolean; static;
    class function LoadStatuses(Q: TSQLQuery; const Number, StageCount: integer;
      out GlobalStatus: TParticipantStatus;
      out StageStatuses: TParticipantStatusArray): boolean; static;
    class procedure LoadAllStatuses(Q: TSQLQuery; const StageCount: integer;
      const ActiveStageIndexes: array of integer;
      out Rows: TParticipantStatusRows); static;
    class function TryLoadParticipantStageData(Q: TSQLQuery;
      const Number, StageIndex, StageCount: integer;
      out Data: TParticipantStageData): boolean; static;
    class function TryLoadCategoryLeaderStageData(Q: TSQLQuery;
      const StageIndex: integer; const Category: string;
      out LeaderNumber: integer; out Data: TParticipantStageData;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): boolean; static;
    class function OpenByCategoryLeader(Q: TSQLQuery; const StageIndex: integer;
      const Category: string; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT):
      boolean; static;
    class function TryGetNumberByStartTimeBetween(Q: TSQLQuery;
      const StageIndex: integer; const TimeBefore, TimeAfter: string;
      out Number: integer; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT):
      boolean; static;
    class function GetPenaltyGroupsCount(Q: TSQLQuery;
      const StageCount: integer): integer; static;
    class function GetFinishCount(Q: TSQLQuery; const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): integer; static;
    class function GetMaxNumber(Q: TSQLQuery): integer; static;
    class function GetMinStartTime(Q: TSQLQuery; const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): string; static;
    class function HasAnyDataInStageRange(Q: TSQLQuery;
      const FirstStageIndex, LastStageIndex, StageCount: integer): boolean; static;
    class function IsParticipantOnTrack(Q: TSQLQuery;
      const StageIndex, Number: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT): boolean; static;
    class procedure LoadCategories(Q: TSQLQuery; Categories: TStrings); static;
    class procedure LoadNumbers(Q: TSQLQuery; Numbers: TStrings); static;
    class procedure LoadGroupedCategories(Q: TSQLQuery; Categories: TStrings;
      const MaxCount: integer = 0); static;
    class procedure LoadCategoriesOrderedByStartTime(Q: TSQLQuery;
      const StageIndex, StageCount: integer; Categories: TStrings); static;
    class procedure LoadStatusNumbers(Q: TSQLQuery;
      const StageIndex, StageCount: integer; Numbers: TStrings); static;
    class procedure ConfigureFinishExport(Q: TSQLQuery;
      const StageIndex, StageCount: integer); static;
    class procedure ConfigureCategoryResults(Q: TSQLQuery;
      const ColumnsCsv, Category: string); static;

    class procedure ExecResetStartTime(Q: TSQLQuery; const StageIndex: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecUpdateStartTime(Q: TSQLQuery; const StageIndex: integer;
      const StartTime: string; const Number: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecUpdateStageStatus(Q: TSQLQuery;
      const StageIndex: integer; const Status: TParticipantStatus;
      const Number: string; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT);
      static;
    class procedure ExecUpdateOnlyGlobalStatusDsq(Q: TSQLQuery;
      const Number: string); static;
    class procedure ExecUpdateGlobalStatus(Q: TSQLQuery;
      const Status: TParticipantStatus; const Number: string); static;
    class procedure PrepareGlobalStatusUpdates(Q: TSQLQuery); static;
    class procedure ExecPreparedGlobalStatusUpdate(Q: TSQLQuery;
      const Status: TParticipantStatus; const Number: integer); static;
    class procedure FinishPreparedGlobalStatusUpdates(Q: TSQLQuery); static;
    class procedure ExecClearStatusAllForStage(Q: TSQLQuery;
      const StageIndex: integer; const Number: string;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecClearOnlyGlobalStatus(Q: TSQLQuery;
      const Number: string); static;
    class procedure ExecClearStageStatus(Q: TSQLQuery;
      const StageIndex: integer; const Number: string;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecUpdateStartTimeForNumber(Q: TSQLQuery;
      const StageIndex: integer; const StartTime: string;
      const Number: integer; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT);
      static;
    class procedure ExecUpdateCorrection(Q: TSQLQuery;
      const StageIndex, Correction, Number: integer;
      const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT); static;
    class procedure ExecUpdateFinishForCheckedStages(Q: TSQLQuery;
      const CheckedStages: array of integer; const TimeValue: string;
      const Number: integer; const StageCount: integer = MAX_SUPPORTED_STAGE_COUNT);
      static;
  end;

  TStartMarkSql = StartMarkRepository.TStartMarkSql;
  TFinishMarkSql = FinishMarkRepository.TFinishMarkSql;
  TDatasetSql = CompetitionQueryProvider.TDatasetSql;
  TStartlistSql = CompetitionQueryProvider.TStartlistSql;
  TSumCalculationRow = ResultCalculationRepository.TSumCalculationRow;
  TResultsSql = ResultCalculationRepository.TResultCalculationRepository;
  TStageResultImportFormat =
    CompetitionImportRepository.TStageResultImportFormat;
  TStageResultImportRow = CompetitionImportRepository.TStageResultImportRow;
  TImportSql = CompetitionImportRepository.TCompetitionImportRepository;
  TSchemaSql = CompetitionSchemaMigrator.TSchemaSql;

implementation

class function TMainSql.SelectAll: string;
begin
  Result := TParticipantRepository.SelectAll;
end;

class function TMainSql.SelectNumbers: string;
begin
  Result := TParticipantRepository.SelectNumbers;
end;

class function TMainSql.ResetStartTime(const StageIndex, StageCount: integer): string;
begin
  Result := TStageResultRepository.ResetStartTime(StageIndex, StageCount);
end;

class function TMainSql.UpdateStartTime(const StageIndex, StageCount: integer): string;
begin
  Result := TStageResultRepository.UpdateStartTime(StageIndex, StageCount);
end;

class function TMainSql.SelectMinStartTime(
  const StageIndex, StageCount: integer): string;
begin
  Result := TStageResultRepository.SelectMinStartTime(StageIndex, StageCount);
end;

class function TMainSql.SelectMaxNumber: string;
begin
  Result := TParticipantRepository.SelectMaxNumber;
end;

class function TMainSql.SelectCategoryGrouped: string;
begin
  Result := TParticipantRepository.SelectCategoryGrouped;
end;

class function TMainSql.SelectCategoryGroupedOrderedByStartTime(
  const StageIndex, StageCount: integer): string;
begin
  Result := TStageResultRepository.SelectCategoryGroupedOrderedByStartTime(
    StageIndex, StageCount);
end;

class function TMainSql.SelectCategoryResults(const ColumnsCsv: string): string;
begin
  Result := TParticipantRepository.SelectCategoryResults(ColumnsCsv);
end;

class function TMainSql.SelectStatusAll: string;
begin
  Result := TParticipantRepository.SelectStatusAll;
end;

class function TMainSql.SelectStatusByStage(
  const StageIndex, StageCount: integer): string;
begin
  Result := TStageResultRepository.SelectStatusByStage(StageIndex, StageCount);
end;

class function TMainSql.ExportFinishTime(
  const StageIndex, StageCount: integer): string;
begin
  Result := TStageResultRepository.ExportFinishTime(StageIndex, StageCount);
end;

class function TMainSql.OpenByNumber(Q: TSQLQuery; const Number: integer): boolean;
begin
  Result := TParticipantRepository.OpenByNumber(Q, Number);
end;

class function TMainSql.TryGetCurrentId(Q: TSQLQuery; out Id: integer): boolean;
begin
  Result := TParticipantRepository.TryGetCurrentId(Q, Id);
end;

class function TMainSql.TryGetCurrentNumber(Q: TSQLQuery; out Number: string): boolean;
begin
  Result := TParticipantRepository.TryGetCurrentNumber(Q, Number);
end;

class function TMainSql.TryLoadIdentity(Q: TSQLQuery; const Number: integer;
  out ParticipantName, Category: string): boolean;
begin
  Result := TParticipantRepository.TryLoadIdentity(Q, Number,
    ParticipantName, Category);
end;

class function TMainSql.LoadStatuses(Q: TSQLQuery; const Number, StageCount: integer;
  out GlobalStatus: TParticipantStatus;
  out StageStatuses: TParticipantStatusArray): boolean;
begin
  Result := TParticipantRepository.LoadStatuses(Q, Number, StageCount,
    GlobalStatus, StageStatuses);
end;

class procedure TMainSql.LoadAllStatuses(Q: TSQLQuery; const StageCount: integer;
  const ActiveStageIndexes: array of integer; out Rows: TParticipantStatusRows);
begin
  TParticipantRepository.LoadAllStatuses(Q, StageCount, ActiveStageIndexes,
    Rows);
end;

class function TMainSql.TryLoadParticipantStageData(Q: TSQLQuery;
  const Number, StageIndex, StageCount: integer;
  out Data: TParticipantStageData): boolean;
begin
  Result := TStageResultRepository.TryLoadParticipantStageData(Q,
    Number, StageIndex, StageCount, Data);
end;

class function TMainSql.TryLoadCategoryLeaderStageData(Q: TSQLQuery;
  const StageIndex: integer; const Category: string; out LeaderNumber: integer;
  out Data: TParticipantStageData; const StageCount: integer): boolean;
begin
  Result := TStageResultRepository.TryLoadCategoryLeaderStageData(Q,
    StageIndex, Category, LeaderNumber, Data, StageCount);
end;

class function TMainSql.OpenByCategoryLeader(Q: TSQLQuery;
  const StageIndex: integer; const Category: string;
  const StageCount: integer): boolean;
begin
  Result := TStageResultRepository.OpenByCategoryLeader(Q, StageIndex,
    Category, StageCount);
end;

class function TMainSql.TryGetNumberByStartTimeBetween(Q: TSQLQuery;
  const StageIndex: integer; const TimeBefore, TimeAfter: string;
  out Number: integer; const StageCount: integer): boolean;
begin
  Result := TStageResultRepository.TryGetNumberByStartTimeBetween(Q,
    StageIndex, TimeBefore, TimeAfter, Number, StageCount);
end;

class function TMainSql.GetPenaltyGroupsCount(Q: TSQLQuery;
  const StageCount: integer): integer;
begin
  Result := TStageResultRepository.GetPenaltyGroupsCount(Q, StageCount);
end;

class function TMainSql.GetFinishCount(Q: TSQLQuery;
  const StageIndex, StageCount: integer): integer;
begin
  Result := TStageResultRepository.GetFinishCount(Q, StageIndex, StageCount);
end;

class function TMainSql.GetMaxNumber(Q: TSQLQuery): integer;
begin
  Result := TParticipantRepository.GetMaxNumber(Q);
end;

class function TMainSql.GetMinStartTime(Q: TSQLQuery;
  const StageIndex, StageCount: integer): string;
begin
  Result := TStageResultRepository.GetMinStartTime(Q, StageIndex, StageCount);
end;

class function TMainSql.HasAnyDataInStageRange(Q: TSQLQuery;
  const FirstStageIndex, LastStageIndex, StageCount: integer): boolean;
begin
  Result := TStageResultRepository.HasAnyDataInStageRange(Q,
    FirstStageIndex, LastStageIndex, StageCount);
end;

class function TMainSql.IsParticipantOnTrack(Q: TSQLQuery;
  const StageIndex, Number, StageCount: integer): boolean;
begin
  Result := TStageResultRepository.IsParticipantOnTrack(Q, StageIndex,
    Number, StageCount);
end;

class procedure TMainSql.LoadCategories(Q: TSQLQuery; Categories: TStrings);
begin
  TParticipantRepository.LoadCategories(Q, Categories);
end;

class procedure TMainSql.LoadNumbers(Q: TSQLQuery; Numbers: TStrings);
begin
  TParticipantRepository.LoadNumbers(Q, Numbers);
end;

class procedure TMainSql.LoadGroupedCategories(Q: TSQLQuery;
  Categories: TStrings; const MaxCount: integer);
begin
  TParticipantRepository.LoadGroupedCategories(Q, Categories, MaxCount);
end;

class procedure TMainSql.LoadCategoriesOrderedByStartTime(Q: TSQLQuery;
  const StageIndex, StageCount: integer; Categories: TStrings);
begin
  TStageResultRepository.LoadCategoriesOrderedByStartTime(Q, StageIndex,
    StageCount, Categories);
end;

class procedure TMainSql.LoadStatusNumbers(Q: TSQLQuery;
  const StageIndex, StageCount: integer; Numbers: TStrings);
begin
  if StageIndex = 0 then
    TParticipantRepository.LoadGlobalStatusNumbers(Q, Numbers)
  else
    TStageResultRepository.LoadStageStatusNumbers(Q, StageIndex, StageCount,
      Numbers);
end;

class procedure TMainSql.ConfigureFinishExport(Q: TSQLQuery;
  const StageIndex, StageCount: integer);
begin
  TStageResultRepository.ConfigureFinishExport(Q, StageIndex, StageCount);
end;

class procedure TMainSql.ConfigureCategoryResults(Q: TSQLQuery;
  const ColumnsCsv, Category: string);
begin
  TParticipantRepository.ConfigureCategoryResults(Q, ColumnsCsv, Category);
end;

class procedure TMainSql.ExecResetStartTime(Q: TSQLQuery;
  const StageIndex, StageCount: integer);
begin
  TStageResultRepository.ExecResetStartTime(Q, StageIndex, StageCount);
end;

class procedure TMainSql.ExecUpdateStartTime(Q: TSQLQuery;
  const StageIndex: integer; const StartTime: string;
  const Number, StageCount: integer);
begin
  TStageResultRepository.ExecUpdateStartTime(Q, StageIndex, StartTime, Number,
    StageCount);
end;

class procedure TMainSql.ExecUpdateStageStatus(Q: TSQLQuery;
  const StageIndex: integer; const Status: TParticipantStatus;
  const Number: string; const StageCount: integer);
begin
  TStageResultRepository.ExecUpdateStageStatus(Q, StageIndex, Status, Number,
    StageCount);
end;

class procedure TMainSql.ExecUpdateOnlyGlobalStatusDsq(Q: TSQLQuery;
  const Number: string);
begin
  TParticipantRepository.ExecUpdateOnlyGlobalStatusDsq(Q, Number);
end;

class procedure TMainSql.ExecUpdateGlobalStatus(Q: TSQLQuery;
  const Status: TParticipantStatus; const Number: string);
begin
  TParticipantRepository.ExecUpdateGlobalStatus(Q, Status, Number);
end;

class procedure TMainSql.PrepareGlobalStatusUpdates(Q: TSQLQuery);
begin
  TParticipantRepository.PrepareGlobalStatusUpdates(Q);
end;

class procedure TMainSql.ExecPreparedGlobalStatusUpdate(Q: TSQLQuery;
  const Status: TParticipantStatus; const Number: integer);
begin
  TParticipantRepository.ExecPreparedGlobalStatusUpdate(Q, Status, Number);
end;

class procedure TMainSql.FinishPreparedGlobalStatusUpdates(Q: TSQLQuery);
begin
  TParticipantRepository.FinishPreparedGlobalStatusUpdates(Q);
end;

class procedure TMainSql.ExecClearStatusAllForStage(Q: TSQLQuery;
  const StageIndex: integer; const Number: string; const StageCount: integer);
begin
  TStageResultRepository.ExecClearStatusAllForStage(Q, StageIndex, Number,
    StageCount);
end;

class procedure TMainSql.ExecClearOnlyGlobalStatus(Q: TSQLQuery; const Number: string);
begin
  TParticipantRepository.ExecClearOnlyGlobalStatus(Q, Number);
end;

class procedure TMainSql.ExecClearStageStatus(Q: TSQLQuery;
  const StageIndex: integer; const Number: string; const StageCount: integer);
begin
  TStageResultRepository.ExecClearStageStatus(Q, StageIndex, Number,
    StageCount);
end;

class procedure TMainSql.ExecUpdateStartTimeForNumber(Q: TSQLQuery;
  const StageIndex: integer; const StartTime: string;
  const Number, StageCount: integer);
begin
  TStageResultRepository.ExecUpdateStartTimeForNumber(Q, StageIndex,
    StartTime, Number, StageCount);
end;

class procedure TMainSql.ExecUpdateCorrection(Q: TSQLQuery;
  const StageIndex, Correction, Number, StageCount: integer);
begin
  TStageResultRepository.ExecUpdateCorrection(Q, StageIndex, Correction,
    Number, StageCount);
end;

class procedure TMainSql.ExecUpdateFinishForCheckedStages(Q: TSQLQuery;
  const CheckedStages: array of integer; const TimeValue: string;
  const Number, StageCount: integer);
begin
  TStageResultRepository.ExecUpdateFinishForCheckedStages(Q, CheckedStages,
    TimeValue, Number, StageCount);
end;

end.
