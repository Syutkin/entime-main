unit StartLabelService;
{$mode objfpc}{$H+}
interface

uses StartLabelModel, ProtocolDocumentModel, CompetitionDbContext, StageModel;

type
  TStartLabelReadOutcome = record
    State: TProtocolReadState;
    Cards: TStartLabelCards;
    ContextIdentity, SessionGeneration: QWord;
    FormedAt: TDateTime;
    ErrorText: string;
  end;

  TStartLabelService = class
  public
    class function Read(const Context: TCompetitionDbContext;
      const Stages: TStages; const FormedAt: TDateTime; const Identity: QWord = 0;
      const Generation: QWord = 0): TStartLabelReadOutcome; static;
  end;

implementation

uses StartReportService, StartReportModel;

class function TStartLabelService.Read(const Context: TCompetitionDbContext;
  const Stages: TStages; const FormedAt: TDateTime; const Identity: QWord;
  const Generation: QWord): TStartLabelReadOutcome;
var
  O: TStartReportOptions;
  R: TStartReportReadOutcome;
begin
  Result := Default(TStartLabelReadOutcome);
  O := DefaultStartReportOptions;
  O.Mode := srmAllStages;
  O.Order := sroNumber;
  O.View.AllCategories := True;
  O.View.IncludeMissing := True;
  R := TStartReportService.Read(Context, Stages, O, FormedAt, Identity, Generation);
  try
    Result.State := R.State;
    Result.ErrorText := R.ErrorText;
    if R.State <> prsReady then Exit;
    Result.Cards := PrepareStartLabels(R.Rows, R.Stages);
    Result.FormedAt := R.Snapshot.FormedAt;
    Result.ContextIdentity := R.Snapshot.ContextIdentity;
    Result.SessionGeneration := R.Snapshot.SessionGeneration;
  finally
    R.Snapshot.Free;
  end;
end;

end.
