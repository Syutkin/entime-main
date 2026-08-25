unit ConfigRepository;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, SQLDB;

type
  TConfigSql = record
  private
    class function SelectByKey: string; static;
  public
    class function UpsertByKey: string; static;
    class procedure ExecUpsertByKey(Q: TSQLQuery; const Key, Value: string);
      static;
    class procedure LoadAll(Q: TSQLQuery; Values: TStrings); static;
    class function StringValue(const Values: TStrings; const Key,
      DefaultValue: string): string; static;
    class function BoolValue(const Values: TStrings; const Key: string;
      const DefaultValue: boolean): boolean; static;
    class function GetString(Q: TSQLQuery; const Key,
      DefaultValue: string): string; static;
    class function GetInteger(Q: TSQLQuery; const Key: string;
      const DefaultValue: integer): integer; static;
    class function GetBool(Q: TSQLQuery; const Key: string;
      const DefaultValue: boolean): boolean; static;
  end;

implementation

function ParseBoolText(const Value: string;
  const DefaultValue: boolean): boolean;
var
  intValue: integer;
begin
  if SameText(Value, '1') or SameText(Value, 'true') then
    Exit(True);
  if SameText(Value, '0') or SameText(Value, 'false') then
    Exit(False);
  if TryStrToInt(Value, intValue) then
    Exit(intValue <> 0);
  Result := DefaultValue;
end;

class function TConfigSql.SelectByKey: string;
begin
  Result := 'SELECT * FROM config WHERE key = :KEY;';
end;

class function TConfigSql.UpsertByKey: string;
begin
  Result := 'INSERT INTO config (key, value) VALUES (:KEY, :VALUE) ' +
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value;';
end;

class procedure TConfigSql.ExecUpsertByKey(Q: TSQLQuery;
  const Key, Value: string);
begin
  Q.SQL.Text := UpsertByKey;
  Q.ParamByName('KEY').AsString := Key;
  Q.ParamByName('VALUE').AsString := Value;
  Q.Close;
  Q.ExecSQL;
  Q.Close;
end;

class procedure TConfigSql.LoadAll(Q: TSQLQuery; Values: TStrings);
var
  keyText, valueText: string;
begin
  if Values = nil then
    raise EArgumentNilException.Create('Values');

  Values.BeginUpdate;
  try
    Values.Clear;
    Q.Close;
    Q.SQL.Text := 'SELECT key, value FROM config;';
    Q.Open;
    try
      while not Q.EOF do
      begin
        keyText := Q.FieldByName('key').AsString;
        if Q.FieldByName('value').IsNull then
          valueText := ''
        else
          valueText := Q.FieldByName('value').AsString;
        Values.Add(keyText + Values.NameValueSeparator + valueText);
        Q.Next;
      end;
    finally
      Q.Close;
    end;
  finally
    Values.EndUpdate;
  end;
end;

class function TConfigSql.StringValue(const Values: TStrings;
  const Key, DefaultValue: string): string;
var
  valueIndex: integer;
begin
  Result := DefaultValue;
  if Values = nil then
    Exit;
  valueIndex := Values.IndexOfName(Key);
  if valueIndex < 0 then
    Exit;
  Result := Values.ValueFromIndex[valueIndex];
  if Result = '' then
    Result := DefaultValue;
end;

class function TConfigSql.BoolValue(const Values: TStrings;
  const Key: string; const DefaultValue: boolean): boolean;
var
  valueIndex: integer;
  valueText: string;
begin
  Result := DefaultValue;
  if Values = nil then
    Exit;
  valueIndex := Values.IndexOfName(Key);
  if valueIndex < 0 then
    Exit;
  valueText := Trim(Values.ValueFromIndex[valueIndex]);
  if valueText <> '' then
    Result := ParseBoolText(valueText, DefaultValue);
end;

class function TConfigSql.GetString(Q: TSQLQuery; const Key,
  DefaultValue: string): string;
begin
  Result := DefaultValue;
  Q.Close;
  Q.SQL.Text := SelectByKey;
  Q.ParamByName('KEY').AsString := Key;
  Q.Open;
  try
    if (not Q.EOF) and (not Q.FieldByName('value').IsNull) then
    begin
      Result := Q.FieldByName('value').AsString;
      if Result = '' then
        Result := DefaultValue;
    end;
  finally
    Q.Close;
  end;
end;

class function TConfigSql.GetInteger(Q: TSQLQuery; const Key: string;
  const DefaultValue: integer): integer;
var
  valueText: string;
begin
  Result := DefaultValue;
  valueText := Trim(GetString(Q, Key, ''));
  if (valueText <> '') and (not TryStrToInt(valueText, Result)) then
    Result := DefaultValue;
end;

class function TConfigSql.GetBool(Q: TSQLQuery; const Key: string;
  const DefaultValue: boolean): boolean;
var
  valueText: string;
begin
  Result := DefaultValue;
  Q.Close;
  Q.SQL.Text := SelectByKey;
  Q.ParamByName('KEY').AsString := Key;
  Q.Open;
  try
    if (not Q.EOF) and (not Q.FieldByName('value').IsNull) then
    begin
      valueText := Trim(Q.FieldByName('value').AsString);
      if valueText <> '' then
        Result := ParseBoolText(valueText, DefaultValue);
    end;
  finally
    Q.Close;
  end;
end;

end.
