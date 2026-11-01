unit OverallFinishReportRepository;
{$mode objfpc}{$H+}
interface

uses SQLDB, StageModel, OverallFinishReportModel;

procedure ReadOverallRows(Q: TSQLQuery; const Stages: TStages;
  out RaceName: string; out Infos: TOverallStageInfos; out Rows: TOverallReportRows);

implementation

uses Classes, SysUtils, ConfigRepository;

procedure ReadOverallRows(Q: TSQLQuery; const Stages: TStages;
  out RaceName: string; out Infos: TOverallStageInfos; out Rows: TOverallReportRows);
var
  Active: TStageIndexArray;
  Config: TStringList;
  SQL, S: string;
  I, N: integer;
begin
  Rows := nil;
  Infos := nil;
  Q.ReadOnly := True;
  Q.PacketRecords := -1;
  Active := Stages.ActiveIndices;
  Config := TStringList.Create;
  try
    TConfigSql.LoadAll(Q, Config);
    RaceName := TConfigSql.StringValue(Config, 'racename', '');
    SetLength(Infos, Length(Active));
    for I := 0 to High(Active) do
    begin
      Infos[I].Index := Active[I];
      Infos[I].Name := TConfigSql.StringValue(Config, 'stagename' +
        IntToStr(Active[I]), Stages[Active[I]].Name);
    end;
  finally
    Config.Free;
  end;
  SQL := 'SELECT id,number,name,team,category,sumresult,sumplace,sumdiffleader,sumstages';
  for I := 0 to High(Active) do
  begin
    S := IntToStr(Active[I]);
    SQL := SQL + ',result' + S + ',status' + S + ',place' + S +
      ',diffleader' + S + ',penalty' + S;
  end;
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
      Rows[N].ResultValue := Q.FieldByName('sumresult').AsString;
      Rows[N].Place := Q.FieldByName('sumplace').AsString;
      Rows[N].Gap := Q.FieldByName('sumdiffleader').AsString;
      Rows[N].CompletedStages := Q.FieldByName('sumstages').AsString;
      SetLength(Rows[N].Stages, Length(Active));
      for I := 0 to High(Active) do
      begin
        S := IntToStr(Active[I]);
        Rows[N].Stages[I].ResultValue := Q.FieldByName('result' + S).AsString;
        Rows[N].Stages[I].Status := Q.FieldByName('status' + S).AsString;
        Rows[N].Stages[I].Place := Q.FieldByName('place' + S).AsString;
        Rows[N].Stages[I].Gap := Q.FieldByName('diffleader' + S).AsString;
        Rows[N].Stages[I].Penalty := Q.FieldByName('penalty' + S).AsString;
      end;
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Close;
  end;
end;

end.
