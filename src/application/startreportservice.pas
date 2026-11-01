unit StartReportService;
{$mode objfpc}{$H+}
interface

uses CompetitionDbContext, StageModel, StartReportModel, ProtocolDocumentModel;

type
  TStartReportReadOutcome = record
    State: TProtocolReadState;
    Snapshot: TProtocolDocument;
    Rows: TStartReportRows;
    Stages: TStartStageInfos;
    ErrorText: string;
  end;

  TStartReportService = class
  public
    class function Read(const Context: TCompetitionDbContext;
      const Stages: TStages; const Options: TStartReportOptions;
      const FormedAt: TDateTime; const Identity: QWord = 0;
      const Generation: QWord = 0): TStartReportReadOutcome; static;
  end;

implementation

uses SysUtils, SQLDB, StartReportRepository;

class function TStartReportService.Read(const Context: TCompetitionDbContext;
  const Stages: TStages; const Options: TStartReportOptions;
  const FormedAt: TDateTime; const Identity: QWord;
  const Generation: QWord): TStartReportReadOutcome;
var
  D: TProtocolDocument;
  Q: TSQLQuery;
  OwnTransaction: boolean;
  Signature, Race: string;
  ReadIdentity, ReadGeneration: QWord;
begin
  Result := Default(TStartReportReadOutcome);
  Result.State := prsSessionChanged;
  if (Context = nil) or not Context.Connection.Connected then Exit;
  if ((Identity <> 0) and (Identity <> Context.Identity)) or
    ((Generation <> 0) and (Generation <> Context.SessionGeneration)) then Exit;
  Result.State := prsBusy;
  if Context.UnitOfWorkActive then Exit;
  Result.State := prsError;
  if Stages = nil then
  begin
    Result.ErrorText := 'Missing stage configuration';
    Exit;
  end;
  if Stages.ActiveStagesCount = 0 then
  begin
    Result.State := prsNoStages;
    Exit;
  end;
  if ((Options.Mode = srmSingleStage) and not Options.AllSingleStages and
    not Stages.IsActiveIndex(Options.View.StageIndex)) or
    ((Options.Mode = srmAllStages) and (Options.Order = sroTime) and
    (Options.SortStageIndex <> 0) and not Stages.IsActiveIndex(
    Options.SortStageIndex)) then
  begin
    Result.ErrorText := 'Selected stage is not active';
    Exit;
  end;
  D := nil;
  Q := nil;
  try
    try
      ReadIdentity := Context.Identity;
      ReadGeneration := Context.SessionGeneration;
      Signature := StageConfigurationSignature(Stages);
      OwnTransaction := not Context.Transaction.Active;
      Q := Context.CreateQuery(nil);
      try
        if OwnTransaction then Context.Transaction.StartTransaction;
        ReadStartRows(Q, Stages, Options, Race, Result.Stages, Result.Rows);
      finally
        Q.Close;
        FreeAndNil(Q);
        if OwnTransaction and Context.Transaction.Active then
          Context.Transaction.Rollback;
      end;
      if not Context.Connection.Connected or (ReadIdentity <> Context.Identity) or
        (ReadGeneration <> Context.SessionGeneration) or
        (Signature <> StageConfigurationSignature(Stages)) then
      begin
        Result.State := prsSessionChanged;
        Exit;
      end;
      D := PrepareStartProtocol(Result.Rows, Result.Stages, Options);
      D.RaceName := Race;
      D.FormedAt := FormedAt;
      D.ContextIdentity := ReadIdentity;
      D.SessionGeneration := ReadGeneration;
      D.StageSignature := Signature;
      if Length(D.Rows) = 0 then
      begin
        Result.State := prsEmpty;
        Exit;
      end;
      Result.State := prsReady;
      Result.Snapshot := D;
      D := nil;
    except
      on E: Exception do
      begin
        Result.State := prsError;
        Result.ErrorText := E.Message;
      end;
    end;
  finally
    D.Free;
    Q.Free;
  end;
end;

end.
