unit ParticipantCardService;
{$mode objfpc}{$H+}
interface

uses SysUtils, CompetitionDbContext, StageModel, ParticipantCardModel;

type
  TCardReadState = (crsReady, crsMissing, crsSessionChanged, crsBusy, crsError);

  TCardReadOutcome = record
    State: TCardReadState;
    Snapshot: TParticipantCardSnapshot; // Owned by the caller only for crsReady.
    ErrorText: string;
  end;

  TParticipantCardService = class
  public
    class function Read(const Context: TCompetitionDbContext;
      const Stages: TStages; const ParticipantId: integer;
      const ExpectedIdentity: QWord = 0;
      const ExpectedGeneration: QWord = 0): TCardReadOutcome; static;
    class function TryCurrentMark(const Snapshot: TParticipantCardSnapshot;
      const Key: TCardMarkKey; const Context: TCompetitionDbContext;
      const Stages: TStages; out Mark: TCardMark): boolean; static;
    class function SessionMatches(const Snapshot: TParticipantCardSnapshot;
      const Context: TCompetitionDbContext): boolean; static;
  end;

function CardStageSignature(const Stages: TStages): string;

implementation

uses SQLDB, ParticipantCardRepository;

function CardStageSignature(const Stages: TStages): string;
var
  I: integer;
begin
  Result := IntToStr(Stages.Count);
  for I := 1 to Stages.Count do
    Result := Result + '|' + IntToStr(Ord(Stages[I].isActive)) + ':' +
      IntToStr(Length(Stages[I].Name)) + ':' + Stages[I].Name;
end;

class function TParticipantCardService.TryCurrentMark(
  const Snapshot: TParticipantCardSnapshot; const Key: TCardMarkKey;
  const Context: TCompetitionDbContext; const Stages: TStages;
  out Mark: TCardMark): boolean;
var
  R: TCardReadOutcome;
  OldPos, NewPos: integer;
  Old: TCardMark;
begin
  Result := False;
  Mark := Default(TCardMark);
  if not SessionMatches(Snapshot, Context) then Exit;
  OldPos := Snapshot.FindMark(Key);
  if OldPos < 0 then Exit;
  R := Read(Context, Stages, Snapshot.ParticipantId, Snapshot.ContextIdentity,
    Snapshot.SessionGeneration);
  try
    if (R.State <> crsReady) or (R.Snapshot.Number <> Snapshot.Number) then Exit;
    NewPos := R.Snapshot.FindMark(Key);
    if NewPos < 0 then Exit;
    Old := Snapshot.Marks[OldPos];
    Mark := R.Snapshot.Marks[NewPos];
    Result := (Old.ReceivedStage = Mark.ReceivedStage) and
      (Old.HasAppliedStage = Mark.HasAppliedStage) and
      (Old.AppliedStage = Mark.AppliedStage) and (Old.EffectiveStage =
      Mark.EffectiveStage);
  finally
    R.Snapshot.Free;
  end;
end;

class function TParticipantCardService.SessionMatches(
  const Snapshot: TParticipantCardSnapshot;
  const Context: TCompetitionDbContext): boolean;
begin
  Result := (Snapshot <> nil) and (Context <> nil) and
    Context.Connection.Connected and (Snapshot.ContextIdentity = Context.Identity) and
    (Snapshot.SessionGeneration = Context.SessionGeneration);
end;

class function TParticipantCardService.Read(const Context: TCompetitionDbContext;
  const Stages: TStages; const ParticipantId: integer;
  const ExpectedIdentity: QWord; const ExpectedGeneration: QWord): TCardReadOutcome;
var
  S: TParticipantCardSnapshot;
  Q: TSQLQuery;
  OwnTransaction, Found: boolean;
begin
  Result := Default(TCardReadOutcome);
  Result.State := crsSessionChanged;
  if (Context = nil) or not Context.Connection.Connected then Exit;
  if ((ExpectedIdentity <> 0) and (ExpectedIdentity <> Context.Identity)) or
    ((ExpectedGeneration <> 0) and (ExpectedGeneration <> Context.SessionGeneration))
  then Exit;
  Result.State := crsBusy;
  if Context.UnitOfWorkActive then Exit;
  Result.State := crsError;
  if (Stages = nil) or (ParticipantId <= 0) then
  begin
    Result.ErrorText := 'Participant card requires a saved participant and stage configuration';
    Exit;
  end;
  S := TParticipantCardSnapshot.Create;
  try
    try
      S.ContextIdentity := Context.Identity;
      S.SessionGeneration := Context.SessionGeneration;
      S.StageSignature := CardStageSignature(Stages);
      OwnTransaction := not Context.Transaction.Active;
      Q := Context.CreateQuery(nil);
      try
        if OwnTransaction then Context.Transaction.StartTransaction;
        try
          Found := TParticipantCardRepository.Load(Q, Stages, ParticipantId, S);
        finally
          Q.Close;
          if OwnTransaction and Context.Transaction.Active then
            Context.Transaction.Rollback;
        end;
      finally
        Q.Free;
      end;
      if not SessionMatches(S, Context) or (S.StageSignature <>
        CardStageSignature(Stages)) then
      begin
        Result.State := crsSessionChanged;
        Exit;
      end;
      if not Found then
      begin
        Result.State := crsMissing;
        Exit;
      end;
      Result.State := crsReady;
      Result.Snapshot := S;
      S := nil;
    except
      on E: Exception do
      begin
        Result.State := crsError;
        Result.ErrorText := E.Message;
      end;
    end;
  finally
    S.Free;
  end;
end;

end.
