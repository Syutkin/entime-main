unit SqlQuerySortEngine;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DB, SQLDB, RxDBGrid;

type
  TEntimeSQLQuerySortEngine = class(TRxDBGridSortEngine)
  public
    procedure Sort(FieldName: string; ADataSet: TDataSet; Asc: boolean;
      SortOptions: TRxSortEngineOptions); override;
    procedure SortList(ListField: string; ADataSet: TDataSet;
      Asc: array of boolean; SortOptions: TRxSortEngineOptions); override;
  end;

implementation

uses
  RegExpr, SqlValueHelpers;

function BuildOrderBy(const AListField: string;
  const AAscending: array of boolean): string;
var
  fields: TStringList;
  i: integer;
  fieldName: string;
begin
  Result := '';
  fields := TStringList.Create;
  try
    fields.StrictDelimiter := True;
    fields.Delimiter := ';';
    fields.DelimitedText := AListField;
    for i := 0 to fields.Count - 1 do
    begin
      fieldName := Trim(fields[i]);
      if fieldName = '' then
        Continue;
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + SqlIdentifier(fieldName);
      if (i <= High(AAscending)) and not AAscending[i] then
        Result := Result + ' DESC';
    end;
  finally
    fields.Free;
  end;
end;

function ReplaceOrderBy(const ASql, AOrderBy: string): string;
var
  baseSql: string;
  hadSemicolon: boolean;
  expression: TRegExpr;
begin
  baseSql := TrimRight(ASql);
  hadSemicolon := (baseSql <> '') and (baseSql[Length(baseSql)] = ';');
  if hadSemicolon then
    Delete(baseSql, Length(baseSql), 1);
  baseSql := TrimRight(baseSql);

  expression := TRegExpr.Create;
  try
    expression.Expression := '(?is)\s+order\s+by\s+[^;]+$';
    if expression.Exec(baseSql) then
      baseSql := TrimRight(Copy(baseSql, 1, expression.MatchPos[0] - 1));
  finally
    expression.Free;
  end;

  Result := baseSql + LineEnding + 'ORDER BY ' + AOrderBy;
  if hadSemicolon then
    Result := Result + ';';
end;

procedure TEntimeSQLQuerySortEngine.Sort(FieldName: string;
  ADataSet: TDataSet; Asc: boolean; SortOptions: TRxSortEngineOptions);
begin
  SortList(FieldName, ADataSet, [Asc], SortOptions);
end;

procedure TEntimeSQLQuerySortEngine.SortList(ListField: string;
  ADataSet: TDataSet; Asc: array of boolean;
  SortOptions: TRxSortEngineOptions);
var
  query: TSQLQuery;
  orderBy: string;
  savedParams: TParams;
begin
  if not ((ADataSet is TSQLQuery) and ADataSet.Active) then
    Exit;

  orderBy := BuildOrderBy(ListField, Asc);
  if orderBy = '' then
    Exit;

  query := TSQLQuery(ADataSet);
  savedParams := TParams.Create;
  try
    savedParams.Assign(query.Params);
    query.DisableControls;
    try
      query.Close;
      query.SQL.Text := ReplaceOrderBy(query.SQL.Text, orderBy);
      query.Params.Assign(savedParams);
      query.Open;
    finally
      query.EnableControls;
    end;
  finally
    savedParams.Free;
  end;
end;

initialization
  RegisterRxDBGridSortEngine(TEntimeSQLQuerySortEngine, 'TSQLQuery');

end.
