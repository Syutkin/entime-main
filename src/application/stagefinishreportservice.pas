unit StageFinishReportService;
{$mode objfpc}{$H+}
interface

uses CompetitionDbContext, StageModel, StageFinishReportModel, ProtocolDocumentModel;

type
  TStageReportReadState = TProtocolReadState;

const
  srrReady = prsReady;
  srrEmpty = prsEmpty;
  srrBusy = prsBusy;
  srrSessionChanged = prsSessionChanged;
  srrError = prsError;

type

  TStageReportReadOutcome = record
    State: TStageReportReadState;
    Snapshot: TStageReportSnapshot; // Caller owns only a ready snapshot.
    ErrorText: string;
  end;

  TStageFinishReportService = class
  public
    class function Read(const Context: TCompetitionDbContext;
      const Stages: TStages; const Options: TStageReportOptions;
      const FormedAt: TDateTime; const Identity: QWord = 0;
      const Generation: QWord = 0): TStageReportReadOutcome; static;
  end;

function ReportStageSignature(const Stages: TStages): string;

implementation

uses SysUtils, SQLDB, StageFinishReportRepository;

function ReportStageSignature(const Stages: TStages): string;
begin
  Result := StageConfigurationSignature(Stages);
end;

class function TStageFinishReportService.Read(const Context: TCompetitionDbContext;
  const Stages: TStages; const Options: TStageReportOptions;
  const FormedAt: TDateTime; const Identity: QWord;
  const Generation: QWord): TStageReportReadOutcome;
var
  S: TStageReportSnapshot;
  Q: TSQLQuery;
  OwnTransaction: boolean;
begin
  Result := Default(TStageReportReadOutcome);
  Result.State := srrSessionChanged;
  if (Context = nil) or not Context.Connection.Connected then Exit;
  if ((Identity <> 0) and (Identity <> Context.Identity)) or
    ((Generation <> 0) and (Generation <> Context.SessionGeneration)) then Exit;
  Result.State := srrBusy;
  if Context.UnitOfWorkActive then Exit;
  Result.State := srrError;
  if (Stages = nil) or not Stages.IsValidIndex(Options.StageIndex) then
  begin
    Result.ErrorText := 'Invalid stage configuration';
    Exit;
  end;
  S := TStageReportSnapshot.Create;
  try
    try
      S.ContextIdentity := Context.Identity;
      S.SessionGeneration := Context.SessionGeneration;
      S.StageSignature := ReportStageSignature(Stages);
      S.FormedAt := FormedAt;
      S.Options := Options;
      S.Options.Categories := Copy(Options.Categories);
      S.Labels := ReportLabels(Options.Language);
      OwnTransaction := not Context.Transaction.Active;
      Q := Context.CreateQuery(nil);
      try
        if OwnTransaction then Context.Transaction.StartTransaction;
        try
          ReadStageFinishSnapshot(Q, S);
        finally
          Q.Close;
          if OwnTransaction and Context.Transaction.Active then
            Context.Transaction.Rollback;
        end;
      finally
        Q.Free;
      end;
      if not Context.Connection.Connected or (S.ContextIdentity <> Context.Identity) or
        (S.SessionGeneration <> Context.SessionGeneration) or
        (S.StageSignature <> ReportStageSignature(Stages)) then
      begin
        Result.State := srrSessionChanged;
        Exit;
      end;
      if Length(S.Rows) = 0 then
      begin
        Result.State := srrEmpty;
        Exit;
      end;
      Result.State := srrReady;
      Result.Snapshot := S;
      S := nil;
    except
      on E: Exception do
      begin
        Result.State := srrError;
        Result.ErrorText := E.Message;
      end;
    end;
  finally
    S.Free;
  end;
end;

end.
