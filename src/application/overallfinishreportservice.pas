unit OverallFinishReportService;
{$mode objfpc}{$H+}
interface

uses CompetitionDbContext, StageModel, OverallFinishReportModel, ProtocolDocumentModel;

type
  TOverallReportReadState = (orrReady, orrEmpty, orrBusy, orrNoStages,
    orrSessionChanged, orrError);

  TOverallReportReadOutcome = record
    State: TOverallReportReadState;
    Snapshot: TProtocolDocument;
    Rows: TOverallReportRows;
    Stages: TOverallStageInfos;
    ErrorText: string;
  end;

  TOverallFinishReportService = class
  public
    class function Read(const Context: TCompetitionDbContext; const Stages: TStages;
      const Options: TOverallReportOptions; const FormedAt: TDateTime;
      const Identity: QWord = 0; const Generation: QWord = 0): TOverallReportReadOutcome; static;
  end;

implementation

uses SysUtils, SQLDB, OverallFinishReportRepository, StageFinishReportService;

class function TOverallFinishReportService.Read(const Context: TCompetitionDbContext;
  const Stages: TStages; const Options: TOverallReportOptions; const FormedAt: TDateTime;
  const Identity: QWord; const Generation: QWord): TOverallReportReadOutcome;
var
  D: TProtocolDocument;
  Q: TSQLQuery;
  OwnTransaction: boolean;
  Signature, Race: string;
  ReadIdentity, ReadGeneration: QWord;
begin
  Result := Default(TOverallReportReadOutcome);
  Result.State := orrSessionChanged;
  if (Context = nil) or not Context.Connection.Connected then Exit;
  if ((Identity <> 0) and (Identity <> Context.Identity)) or
    ((Generation <> 0) and (Generation <> Context.SessionGeneration)) then Exit;
  Result.State := orrBusy;
  if Context.UnitOfWorkActive then Exit;
  Result.State := orrError;
  if Stages = nil then
  begin
    Result.ErrorText := 'Missing stage configuration';
    Exit;
  end;
  if Stages.ActiveStagesCount = 0 then
  begin
    Result.State := orrNoStages;
    Exit;
  end;
  D := nil;
  Q := nil;
  try
    try
      ReadIdentity := Context.Identity;
      ReadGeneration := Context.SessionGeneration;
      Signature := ReportStageSignature(Stages);
      OwnTransaction := not Context.Transaction.Active;
      Q := Context.CreateQuery(nil);
      try
        if OwnTransaction then Context.Transaction.StartTransaction;
        ReadOverallRows(Q, Stages, Race, Result.Stages, Result.Rows);
      finally
        Q.Close;
        FreeAndNil(Q);
        if OwnTransaction and Context.Transaction.Active then Context.Transaction.Rollback;
      end;
      if not Context.Connection.Connected or (ReadIdentity <> Context.Identity) or
        (ReadGeneration <> Context.SessionGeneration) or
        (Signature <> ReportStageSignature(Stages)) then
      begin
        Result.State := orrSessionChanged;
        Exit;
      end;
      D := PrepareOverallProtocol(Result.Rows, Result.Stages, Options);
      D.RaceName := Race;
      D.FormedAt := FormedAt;
      D.ContextIdentity := ReadIdentity;
      D.SessionGeneration := ReadGeneration;
      D.StageSignature := Signature;
      if Length(D.Rows) = 0 then
      begin
        Result.State := orrEmpty;
        Exit;
      end;
      Result.State := orrReady;
      Result.Snapshot := D;
      D := nil;
    except
      on E: Exception do
      begin
        Result.State := orrError;
        Result.ErrorText := E.Message;
      end;
    end;
  finally
    D.Free;
    Q.Free;
  end;
end;

end.
