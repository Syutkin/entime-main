unit StartReportRepository;
{$mode objfpc}{$H+}
interface

uses SQLDB, StageModel, StartReportModel;

procedure ReadStartRows(Q: TSQLQuery; const Stages: TStages;
  const Options: TStartReportOptions; out RaceName: string;
  out Infos: TStartStageInfos; out Rows: TStartReportRows);

implementation

uses Classes, SysUtils, ConfigRepository;

procedure ReadStartRows(Q: TSQLQuery; const Stages: TStages;
  const Options: TStartReportOptions; out RaceName: string;
  out Infos: TStartStageInfos; out Rows: TStartReportRows);
var
  Active: TStageIndexArray;
  Config: TStringList;
  SQL: string;
  I, N: integer;
begin
  Rows := nil;
  Infos := nil;
  Q.ReadOnly := True;
  Q.PacketRecords := -1;
  Active := Stages.ActiveIndices;
  if (Options.Mode = srmSingleStage) and not Options.AllSingleStages then
  begin
    SetLength(Active, 1);
    Active[0] := Options.View.StageIndex;
  end;
  Config := TStringList.Create;
  try
    TConfigSql.LoadAll(Q, Config);
    RaceName := TConfigSql.StringValue(Config, 'racename', '');
    SetLength(Infos, Length(Active));
    for I := 0 to High(Active) do
    begin
      Infos[I].Index := Active[I];
      Infos[I].IsActive := True;
      Infos[I].Name := TConfigSql.StringValue(Config, 'stagename' +
        IntToStr(Active[I]), Stages[Active[I]].Name);
    end;
  finally
    Config.Free;
  end;
  SQL := 'SELECT id,number,name,team,category';
  for I := 0 to High(Active) do SQL := SQL + ',starttime' + IntToStr(Active[I]);
  Q.SQL.Text := SQL + ' FROM main';
  Q.Open;
  try
    SetLength(Rows, Q.RecordCount);
    N := 0;
    while not Q.EOF do
    begin
      Rows[N].Id := Q.FieldByName('id').AsInteger;
      Rows[N].Number := Q.FieldByName('number').AsInteger;
      Rows[N].Name := Q.FieldByName('name').AsString;
      Rows[N].Team := Q.FieldByName('team').AsString;
      Rows[N].Category := Q.FieldByName('category').AsString;
      SetLength(Rows[N].Starts, Length(Active));
      for I := 0 to High(Active) do
        Rows[N].Starts[I] := Q.FieldByName('starttime' + IntToStr(Active[I])).AsString;
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Close;
  end;
end;

end.
