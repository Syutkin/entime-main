unit CompetitionDbContext;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, DB, sqlite3conn, sqldb;

const
  DEFAULT_SQLITE_BUSY_TIMEOUT_MS = 3000;

procedure ConfigureSQLiteBusyTimeout(const AConnection: TSQLite3Connection;
  const ATimeoutMs: integer = DEFAULT_SQLITE_BUSY_TIMEOUT_MS);

type
  TSqlQueryList = specialize TList<TSQLQuery>;
  TCompetitionDbContext = class;

  { TCompetitionUnitOfWork }

  TCompetitionUnitOfWork = class
  private
    FContext: TCompetitionDbContext;
    FCompleted: boolean;
  public
    constructor Create(const AContext: TCompetitionDbContext);
    destructor Destroy; override;
    procedure Commit;
    procedure Rollback;
    property Completed: boolean read FCompleted;
  end;

  { TCompetitionDbContext }

  TCompetitionDbContext = class(TComponent)
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQueries: TSqlQueryList;
    FUnitOfWorkActive: boolean;
    procedure BeginWrite;
    procedure CommitWrite;
    procedure RollbackWrite;
    procedure FinishUnitOfWork(const ACommit: boolean);
    procedure CloseRegisteredDatasets;
    procedure ConfigureQuery(const AQuery: TSQLQuery);
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent = nil); override;
    destructor Destroy; override;
    procedure AttachQuery(const AQuery: TSQLQuery);
    procedure RegisterUiQuery(const AQuery: TSQLQuery);
    function CreateQuery(const AOwner: TComponent): TSQLQuery;
    procedure SetDatabaseFile(const AFileName: string);
    procedure OpenConnection;
    procedure OpenFile(const AFileName: string);
    procedure CloseFile;
    function BeginUnitOfWork: TCompetitionUnitOfWork;
    procedure ConfigureEditableQuery(const AQuery: TSQLQuery;
      const ATableName, AKeyField: string);
    procedure ApplyUpdatesAndRefreshUi(const AQuery: TSQLQuery);
    procedure RefreshQuery(const AQuery: TSQLQuery);
    procedure RefreshQueries(const AQueries: array of TSQLQuery); overload;
    function RefreshQueries(const AQueries: array of TSQLQuery;
      out AErrors: string): integer; overload;
    property Connection: TSQLite3Connection read FConnection;
    property Transaction: TSQLTransaction read FTransaction;
  end;

implementation

uses
  SqlValueHelpers, sqlite3dyn;

procedure ConfigureSQLiteBusyTimeout(const AConnection: TSQLite3Connection;
  const ATimeoutMs: integer);
var
  SQLiteResult: integer;
begin
  if not Assigned(AConnection) then
    raise EArgumentNilException.Create('AConnection');
  if ATimeoutMs < 0 then
    raise EArgumentOutOfRangeException.Create('ATimeoutMs');
  if not AConnection.Connected then
    AConnection.Open;
  SQLiteResult := sqlite3_busy_timeout(psqlite3(AConnection.Handle),
    ATimeoutMs);
  if SQLiteResult <> SQLITE_OK then
    raise EDatabaseError.CreateFmt(
      'Cannot configure SQLite busy timeout: error %d', [SQLiteResult]);
end;

{ TCompetitionUnitOfWork }

constructor TCompetitionUnitOfWork.Create(
  const AContext: TCompetitionDbContext);
begin
  inherited Create;
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  FContext := AContext;
end;

destructor TCompetitionUnitOfWork.Destroy;
begin
  try
    if not FCompleted then
      Rollback;
  finally
    inherited Destroy;
  end;
end;

procedure TCompetitionUnitOfWork.Commit;
begin
  if FCompleted then
    Exit;
  try
    FContext.FinishUnitOfWork(True);
  finally
    FCompleted := True;
    FContext := nil;
  end;
end;

procedure TCompetitionUnitOfWork.Rollback;
begin
  if FCompleted then
    Exit;
  try
    FContext.FinishUnitOfWork(False);
  finally
    FCompleted := True;
    FContext := nil;
  end;
end;

procedure TCompetitionDbContext.CloseRegisteredDatasets;
var
  Query: TSQLQuery;
begin
  for Query in FQueries do
    Query.Close;
end;

procedure TCompetitionDbContext.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent is TSQLQuery) and
    Assigned(FQueries) then
    FQueries.Remove(TSQLQuery(AComponent));
end;

procedure TCompetitionDbContext.ConfigureQuery(const AQuery: TSQLQuery);
begin
  AQuery.Close;
  AQuery.Database := FConnection;
  AQuery.Transaction := FTransaction;
end;

constructor TCompetitionDbContext.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FQueries := TSqlQueryList.Create;
  FConnection := TSQLite3Connection.Create(nil);
  FConnection.LoginPrompt := False;
  FConnection.KeepConnection := True;
  FTransaction := TSQLTransaction.Create(nil);
  FTransaction.Database := FConnection;
  FConnection.Transaction := FTransaction;
end;

destructor TCompetitionDbContext.Destroy;
begin
  CloseFile;
  FreeAndNil(FQueries);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
  inherited Destroy;
end;

procedure TCompetitionDbContext.AttachQuery(const AQuery: TSQLQuery);
begin
  if AQuery = nil then
    Exit;
  ConfigureQuery(AQuery);
  if FQueries.IndexOf(AQuery) < 0 then
  begin
    FQueries.Add(AQuery);
    AQuery.FreeNotification(Self);
  end;
end;

procedure TCompetitionDbContext.RegisterUiQuery(const AQuery: TSQLQuery);
begin
  AttachQuery(AQuery);
  if AQuery <> nil then
    AQuery.Options := AQuery.Options + [sqoKeepOpenOnCommit];
end;

function TCompetitionDbContext.CreateQuery(const AOwner: TComponent): TSQLQuery;
begin
  Result := TSQLQuery.Create(AOwner);
  AttachQuery(Result);
end;

procedure TCompetitionDbContext.SetDatabaseFile(const AFileName: string);
begin
  CloseFile;
  FConnection.DatabaseName := AFileName;
end;

procedure TCompetitionDbContext.OpenConnection;
begin
  if FConnection.DatabaseName = '' then
    raise EDatabaseError.Create('Database file must be assigned before opening');
  if not FConnection.Connected then
  begin
    FConnection.Open;
    ConfigureSQLiteBusyTimeout(FConnection);
  end;
end;

procedure TCompetitionDbContext.OpenFile(const AFileName: string);
begin
  SetDatabaseFile(AFileName);
  if AFileName <> '' then
    OpenConnection;
end;

procedure TCompetitionDbContext.CloseFile;
begin
  CloseRegisteredDatasets;
  if FTransaction.Active then
    FTransaction.Rollback;
  FUnitOfWorkActive := False;
  if FConnection.Connected then
    FConnection.Close;
  FConnection.DatabaseName := '';
end;

procedure TCompetitionDbContext.BeginWrite;
begin
  OpenConnection;
  if not FTransaction.Active then
    FTransaction.StartTransaction;
end;

procedure TCompetitionDbContext.CommitWrite;
begin
  if FTransaction.Active then
    FTransaction.Commit;
end;

procedure TCompetitionDbContext.RollbackWrite;
begin
  if FTransaction.Active then
    FTransaction.Rollback;
end;

procedure TCompetitionDbContext.FinishUnitOfWork(const ACommit: boolean);
begin
  if not FUnitOfWorkActive then
    Exit;
  try
    if ACommit then
    begin
      try
        CommitWrite;
      except
        try
          RollbackWrite;
        except
          // Preserve the commit error; the context is finalized below.
        end;
        raise;
      end;
    end
    else
      RollbackWrite;
  finally
    FUnitOfWorkActive := False;
  end;
end;

function TCompetitionDbContext.BeginUnitOfWork: TCompetitionUnitOfWork;
begin
  if FUnitOfWorkActive then
    raise EDatabaseError.Create('A database unit of work is already active');
  BeginWrite;
  FUnitOfWorkActive := True;
  try
    Result := TCompetitionUnitOfWork.Create(Self);
  except
    FinishUnitOfWork(False);
    raise;
  end;
end;

procedure TCompetitionDbContext.ConfigureEditableQuery(const AQuery: TSQLQuery;
  const ATableName, AKeyField: string);
var
  Field: TField;
  FieldNames, FieldValues, FieldAssignments: TStringList;
  QuotedTableName, QuotedKeyField, QuotedFieldName,
    QuotedOldKeyParameter: string;

  function JoinSqlParts(const Values: TStrings): string;
  var
    Index: Integer;
  begin
    Result := '';
    for Index := 0 to Values.Count - 1 do
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + Values[Index];
    end;
  end;
begin
  if AQuery = nil then
    Exit;
  if AQuery.Active then
    raise EDatabaseError.Create('Editable query must be inactive while configured');
  QuotedTableName := SqlIdentifier(ATableName);
  QuotedKeyField := SqlIdentifier(AKeyField);
  QuotedOldKeyParameter := SqlIdentifier('OLD_' + AKeyField);

  FieldNames := TStringList.Create;
  FieldValues := TStringList.Create;
  FieldAssignments := TStringList.Create;
  try
    for Field in AQuery.Fields do
      if SameText(Field.FieldName, AKeyField) then
        Field.ProviderFlags := [pfInKey, pfRefreshOnInsert]
      else if not Field.ReadOnly then
      begin
        Field.ProviderFlags := [pfInUpdate];
        QuotedFieldName := SqlIdentifier(Field.FieldName);
        FieldNames.Add(QuotedFieldName);
        FieldValues.Add(':' + QuotedFieldName);
        FieldAssignments.Add(QuotedFieldName + '=:' + QuotedFieldName);
      end
      else
        Field.ProviderFlags := [];

    AQuery.Options := AQuery.Options + [sqoKeepOpenOnCommit];
    AQuery.UsePrimaryKeyAsKey := True;
    AQuery.InsertSQL.Text := 'INSERT INTO ' + QuotedTableName + ' (' +
      JoinSqlParts(FieldNames) + ') VALUES (' + JoinSqlParts(FieldValues) + ')';
    AQuery.UpdateSQL.Text := 'UPDATE ' + QuotedTableName + ' SET ' +
      JoinSqlParts(FieldAssignments) +
      ' WHERE ' + QuotedKeyField + '=:' + QuotedOldKeyParameter;
    AQuery.DeleteSQL.Text := 'DELETE FROM ' + QuotedTableName + ' WHERE ' +
      QuotedKeyField + '=:' + QuotedOldKeyParameter;
    AQuery.RefreshSQL.Text := 'SELECT * FROM ' + QuotedTableName + ' WHERE ' +
      QuotedKeyField + '=:' + QuotedKeyField;
  finally
    FieldAssignments.Free;
    FieldValues.Free;
    FieldNames.Free;
  end;
end;

procedure TCompetitionDbContext.ApplyUpdatesAndRefreshUi(
  const AQuery: TSQLQuery);
var
  UnitOfWork: TCompetitionUnitOfWork;
begin
  if AQuery = nil then
    Exit;
  UnitOfWork := nil;
  try
    try
      if AQuery.State in [dsEdit, dsInsert] then
        AQuery.Post;
      UnitOfWork := BeginUnitOfWork;
      AQuery.ApplyUpdates;
      UnitOfWork.Commit;
    except
      if AQuery.Active and (AQuery.ChangeCount > 0) then
        AQuery.CancelUpdates;
      raise;
    end;
  finally
    UnitOfWork.Free;
  end;
end;

procedure TCompetitionDbContext.RefreshQuery(const AQuery: TSQLQuery);
begin
  if (AQuery <> nil) and AQuery.Active then
  begin
    AQuery.Close;
    AQuery.Open;
  end;
end;

procedure TCompetitionDbContext.RefreshQueries(
  const AQueries: array of TSQLQuery);
var
  Errors: string;
begin
  if RefreshQueries(AQueries, Errors) > 0 then
    raise EDatabaseError.Create(Errors);
end;

function TCompetitionDbContext.RefreshQueries(
  const AQueries: array of TSQLQuery; out AErrors: string): integer;
var
  Query: TSQLQuery;
begin
  Result := 0;
  AErrors := '';
  for Query in AQueries do
  begin
    if Query = nil then
      Continue;
    try
      Query.Close;
      Query.Open;
    except
      on E: Exception do
      begin
        Inc(Result);
        if AErrors <> '' then
          AErrors := AErrors + LineEnding;
        if Query.Name <> '' then
          AErrors := AErrors + Query.Name + ': ' + E.Message
        else
          AErrors := AErrors + E.Message;
      end;
    end;
  end;
end;

end.
