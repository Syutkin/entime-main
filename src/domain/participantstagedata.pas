unit ParticipantStageData;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, ParticipantStatus;

type
  { TParticipantStageData }
  TParticipantStageData = record
  private
    FStageIndex: integer;
  public
    StartTime: string;
    HasCorrection: boolean;
    Correction: integer;
    FinishTime: string;
    Penalty: string;
    ResultValue: string;
    DiffLeader: string;
    HasPlace: boolean;
    Place: integer;
    Status: TParticipantStatus;
    class function Create(const AStageIndex: integer): TParticipantStageData;
      static;
    property StageIndex: integer read FStageIndex;
  end;

implementation

class function TParticipantStageData.Create(
  const AStageIndex: integer): TParticipantStageData;
begin
  if AStageIndex < 1 then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index %d must be greater than zero.', [AStageIndex]);

  Result.FStageIndex := AStageIndex;
  Result.StartTime := '';
  Result.HasCorrection := False;
  Result.Correction := 0;
  Result.FinishTime := '';
  Result.Penalty := '';
  Result.ResultValue := '';
  Result.DiffLeader := '';
  Result.HasPlace := False;
  Result.Place := 0;
  Result.Status := psNone;
end;

end.
