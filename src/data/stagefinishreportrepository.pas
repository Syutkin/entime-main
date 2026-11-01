unit StageFinishReportRepository;
{$mode objfpc}{$H+}
interface

uses SQLDB, StageFinishReportModel;

procedure ReadStageFinishSnapshot(const Q: TSQLQuery;
  const Snapshot: TStageReportSnapshot);

implementation

uses Classes, SysUtils, StageFieldNames, ConfigRepository;

procedure ReadStageFinishSnapshot(const Q: TSQLQuery;
  const Snapshot: TStageReportSnapshot);
var
  K: TStageFieldKind;
  Sql, Suffix: string;
  N: integer;
  Config: TStringList;
begin
  Q.ReadOnly := True;
  Q.PacketRecords := -1;
  Config := TStringList.Create;
  try
    TConfigSql.LoadAll(Q, Config);
    Snapshot.RaceName := TConfigSql.StringValue(Config, 'racename', '');
    Snapshot.StageName := TConfigSql.StringValue(Config, 'stagename' +
      IntToStr(Snapshot.Options.StageIndex), '');
  finally
    Config.Free;
  end;
  Suffix := IntToStr(Snapshot.Options.StageIndex);
  Sql := 'SELECT id, number, name, team, category, status';
  for K := sfkStartTime to sfkStatus do Sql := Sql + ', ' + StageFieldPrefix(K) + Suffix;
  Q.SQL.Text := Sql + ' FROM main';
  Q.Open;
  try
    SetLength(Snapshot.Rows, Q.RecordCount);
    N := 0;
    while not Q.EOF do
    begin
      Snapshot.Rows[N].Id := Q.FieldByName('id').AsInteger;
      Snapshot.Rows[N].Number := Q.FieldByName('number').AsInteger;
      Snapshot.Rows[N].Name := Q.FieldByName('name').AsString;
      Snapshot.Rows[N].Team := Q.FieldByName('team').AsString;
      Snapshot.Rows[N].Category := Q.FieldByName('category').AsString;
      Snapshot.Rows[N].GlobalStatus := Q.FieldByName('status').AsString;
      for K := sfkStartTime to sfkStatus do
        Snapshot.Rows[N].Values[K] := Q.FieldByName(StageFieldPrefix(K) + Suffix).AsString;
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Close;
  end;
  Snapshot.Rows := SelectReportRows(Snapshot.Rows, Snapshot.Options);
end;

end.
