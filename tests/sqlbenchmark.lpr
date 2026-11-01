program SqlBenchmark;

{$mode objfpc}{$H+}
{$R *.res}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes,
  SysUtils,
  SQLDB,
  MD5,
  DbSql,
  StageModel,
  CompetitionResultsService,
  CompetitionFinishService;

type
  TSqlCounter = class
    Statements, Commits, MetadataReads: integer;
    procedure Log(Sender: TSQLConnection; EventType: TDBEventType;
      const Msg: string);
  end;

  procedure TSqlCounter.Log(Sender: TSQLConnection; EventType: TDBEventType;
  const Msg: string);
  begin
    if EventType = detExecute then
    begin
      Inc(Statements);
      if (Pos('pragma_table_info', LowerCase(Msg)) > 0) or
        (Pos('pragma table_info', LowerCase(Msg)) > 0) then
        Inc(MetadataReads);
    end
    else if EventType = detCommit then
      Inc(Commits);
  end;

  function Snapshot(const Query: TSQLQuery): string;
  var
    Values: TStringList;
    I: integer;
  begin
    Values := TStringList.Create;
    try
      Query.SQL.Text := 'SELECT * FROM main ORDER BY number;';
      Query.Open;
      while not Query.EOF do
      begin
        for I := 0 to Query.FieldCount - 1 do
          if Query.Fields[I].IsNull then
            Values.Add('<NULL>')
          else
            Values.Add(Query.Fields[I].AsString);
        Query.Next;
      end;
      Query.Close;
      Result := MD5Print(MD5String(Values.Text));
    finally
      Values.Free;
    end;
  end;

  procedure MeasureSchema(const Rows: integer);
  var
    Context: TCompetitionDbContext;
    Query: TSQLQuery;
    Work: TCompetitionUnitOfWork;
    Counter: TSqlCounter;
    Started, Elapsed: QWord;
    Pass: integer;
    Digest, Expected: string;
  begin
    Expected := '';
    WriteLn('rows,from_stages,to_stages,milliseconds,statements,metadata_reads,checksum');
    for Pass := 1 to 3 do
    begin
      Context := TCompetitionDbContext.Create;
      Query := nil;
      Counter := TSqlCounter.Create;
      try
        Context.OpenFile(':memory:');
        Query := Context.CreateQuery(nil);
        Work := Context.BeginUnitOfWork;
        try
          TSchemaSql.ExecCreateTables(Context.Connection, 8,
            'A', 'B', 'C', 'D', 'E', 'Schema benchmark');
          Query.SQL.Text := Format('WITH RECURSIVE rows(n) AS ' +
            '(SELECT 1 UNION ALL SELECT n + 1 FROM rows WHERE n < %d) ' +
            'INSERT INTO main (number, category, starttime1, finishtime1) ' +
            'SELECT n, ''Category '' || (n %% 5), ''10:00:00'', ''10:10:00'' FROM rows;',
            [Rows]);
          Query.ExecSQL;
          Work.Commit;
        finally
          Work.Free;
        end;
        Context.Connection.OnLog := @Counter.Log;
        Started := GetTickCount64;
        Work := Context.BeginUnitOfWork;
        try
          TSchemaSql.EnsureStageCapacity(Query, 32);
          Work.Commit;
        finally
          Work.Free;
        end;
        Elapsed := GetTickCount64 - Started;
        Context.Connection.OnLog := nil;
        Digest := Snapshot(Query);
        if Expected = '' then
          Expected := Digest
        else if Expected <> Digest then
          raise Exception.Create('Schema snapshots differ.');
        WriteLn(Format('%d,8,32,%d,%d,%d,%s', [Rows, Elapsed,
          Counter.Statements, Counter.MetadataReads, Digest]));
      finally
        Context.Connection.OnLog := nil;
        Counter.Free;
        Query.Free;
        Context.Free;
      end;
    end;
  end;

  procedure Measure(const Rows, StageCount: integer; const Mode: string;
  const WithIndex: boolean; out Digest: string);
  const
    FinishCount = 25;
  var
    Context: TCompetitionDbContext;
    Stages: TStages;
    Query: TSQLQuery;
    Work: TCompetitionUnitOfWork;
    Counter: TSqlCounter;
    Columns, Values: string;
    Requests: TFinishRequests;
    Saved: TFinishResults;
    single: TFinishResult;
    Failure: TFinishFailure;
    I, FailedIndex: integer;
    Started, Elapsed: QWord;
  begin
    Context := TCompetitionDbContext.Create;
    Stages := TStages.Create(StageCount);
    Query := nil;
    Counter := TSqlCounter.Create;
    try
      Context.OpenFile(':memory:');
      Query := Context.CreateQuery(nil);
      Work := Context.BeginUnitOfWork;
      try
        TSchemaSql.ExecCreateTables(Context.Connection, StageCount,
          'A', 'B', 'C', 'D', 'E', 'SQL benchmark');
        Columns := 'number, category';
        Values := 'n, ''Category '' || (n % 5)';
        for I := 1 to StageCount do
        begin
          Stages[I].isActive := True;
          Columns := Columns + ', starttime' + IntToStr(I) +
            ', finishtime' + IntToStr(I);
          Values := Values + ', ''10:00:00.000'', ';
          if I = StageCount then
            Values := Values + 'CASE WHEN n % 7 = 0 THEN NULL ELSE ';
          Values := Values + 'strftime(''%H:%M:%f'', ''10:00:00'', ' +
          '''+'' || (n % 600 + 10) || '' seconds'')';
          if I = StageCount then
            Values := Values + ' END';
        end;
        Query.SQL.Text := Format('WITH RECURSIVE rows(n) AS ' +
          '(SELECT 1 UNION ALL SELECT n + 1 FROM rows WHERE n < %d) ' +
          'INSERT INTO main (%s) SELECT %s FROM rows;', [Rows, Columns, Values]);
        Query.ExecSQL;
        if WithIndex then
        begin
          Query.SQL.Text :=
            'CREATE INDEX idx_main_category_number ON main(category, number);';
          Query.ExecSQL;
        end;
        Work.Commit;
      finally
        Work.Free;
      end;
      TResultCalculationService.RecalculateAll(Context, Stages);
      SetLength(Requests, FinishCount);
      for I := 0 to High(Requests) do
        Requests[I] := TFinishRequest.Create(I + 1, 1, '10:00:30.000',
          ftpAllowNotOnTrack, fopOverwriteExisting);

      Context.Connection.OnLog := @Counter.Log;
      Started := GetTickCount64;
      if Mode = 'plans' then
      begin
        Query.SQL.Text := 'SELECT * FROM main WHERE category = :CATEGORY ORDER BY number;';
        Query.ParamByName('CATEGORY').AsString := 'Category 1';
        for I := 1 to 100 do
        begin
          Query.Open;
          while not Query.EOF do
            Query.Next;
          Query.Close;
        end;
      end
      else if (Mode = 'full') or (Mode = 'stage') then
      begin
        Work := Context.BeginUnitOfWork;
        try
          Query.SQL.Text := 'UPDATE main SET finishtime1 = ''10:00:30.000'' ' +
            'WHERE number BETWEEN 1 AND 25;';
          Query.ExecSQL;
          if Mode = 'full' then
            TResultCalculationService.RecalculateAllInCurrentTransaction(Context, Stages)
          else
            TResultCalculationService.RecalculateStagesInCurrentTransaction(Context,
              Stages, [1]);
          Work.Commit;
        finally
          Work.Free;
        end;
      end
      else if Mode = 'batch' then
      begin
        if not TFinishService.TrySaveBatch(Context, Stages, Requests,
          Saved, Failure, FailedIndex) then
          raise Exception.Create(Failure.SafeMessage);
      end
      else
        for I := 0 to High(Requests) do
          if not TFinishService.TrySave(Context, Stages, Requests[I], single, Failure) then
            raise Exception.Create(Failure.SafeMessage);
      Elapsed := GetTickCount64 - Started;
      Context.Connection.OnLog := nil;
      if Mode = 'plans' then
      begin
        Query.SQL.Text := 'EXPLAIN QUERY PLAN SELECT * FROM main ' +
          'WHERE category = ''Category 1'' ORDER BY number;';
        Query.Open;
        while not Query.EOF do
        begin
          WriteLn('# index=', BoolToStr(WithIndex, True), ' ',
            Query.FieldByName('detail').AsString);
          Query.Next;
        end;
        Query.Close;
      end;
      Digest := Snapshot(Query);
      WriteLn(Format('%d,%d,%s,%s,%d,%d,%d,%s', [Rows, StageCount,
        Mode, BoolToStr(WithIndex, True), Elapsed, Counter.Statements,
        Counter.Commits, Digest]));
    finally
      Context.Connection.OnLog := nil;
      Counter.Free;
      Query.Free;
      Stages.Free;
      Context.Free;
    end;
  end;

const
  Modes: array[0..3] of string = ('full', 'stage', 'sequential', 'batch');
var
  Rows, StageCount, Repeats, Pass, I: integer;
  Digest, Expected: string;
  WithIndex: boolean;
begin
  if ParamStr(1) = 'schema' then
  begin
    Rows := 1000;
    if ParamCount > 1 then
      Rows := StrToInt(ParamStr(2));
    if Rows < 1 then
      raise Exception.Create('A positive participant count is required.');
    MeasureSchema(Rows);
    Exit;
  end;
  if ParamStr(1) = 'plans' then
  begin
    Rows := 5000;
    StageCount := 32;
    if ParamCount > 1 then
      Rows := StrToInt(ParamStr(2));
    if ParamCount > 2 then
      StageCount := StrToInt(ParamStr(3));
    if Rows < 25 then
      raise Exception.Create('At least 25 participants are required.');
    WriteLn('rows,stages,mode,index,milliseconds,statements,commits,checksum');
    Measure(Rows, StageCount, 'plans', False, Expected);
    Measure(Rows, StageCount, 'plans', True, Digest);
    if Expected <> Digest then
      raise Exception.Create('Index changed calculation snapshots.');
    Exit;
  end;
  Rows := 1000;
  StageCount := 8;
  Repeats := 3;
  if ParamCount > 0 then
    Rows := StrToInt(ParamStr(1));
  if ParamCount > 1 then
    StageCount := StrToInt(ParamStr(2));
  if ParamCount > 2 then
    Repeats := StrToInt(ParamStr(3));
  if Rows < 25 then
    raise Exception.Create('At least 25 participants are required.');
  if Repeats < 1 then
    raise Exception.Create('At least one repeat is required.');
  Expected := '';
  WriteLn('rows,stages,mode,index,milliseconds,statements,commits,checksum');
  for WithIndex := False to True do
    for Pass := 1 to Repeats do
      for I := 0 to High(Modes) do
      begin
        Measure(Rows, StageCount, Modes[I], WithIndex, Digest);
        if Expected = '' then
          Expected := Digest
        else if Expected <> Digest then
          raise Exception.Create('Calculation snapshots differ.');
      end;
end.
