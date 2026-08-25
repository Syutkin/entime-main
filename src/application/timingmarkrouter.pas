unit TimingMarkRouter;

{$mode ObjFPC}{$H+}

interface

uses
  TimingMark, StartMark, FinishMark;

type
  TStartMarkEvent = procedure(Sender: TObject;
    const AMark: TStartMark) of object;
  TFinishMarkEvent = procedure(Sender: TObject;
    const AMark: TFinishMark) of object;

  { TTimingMarkRouter }

  TTimingMarkRouter = class
  private
    FOnStartMark: TStartMarkEvent;
    FOnFinishMark: TFinishMarkEvent;
  public
    procedure Route(const AMark: TTimingMark; const AStageIndex: integer);
    property OnStartMark: TStartMarkEvent read FOnStartMark write FOnStartMark;
    property OnFinishMark: TFinishMarkEvent read FOnFinishMark
      write FOnFinishMark;
  end;

implementation

procedure TTimingMarkRouter.Route(const AMark: TTimingMark;
  const AStageIndex: integer);
var
  Finish: TFinishMark;
  Start: TStartMark;
begin
  case AMark.Kind of
    tmkStart:
      begin
        Start := TStartMark.FromTimingMark(AMark, AStageIndex);
        if Assigned(FOnStartMark) then
          FOnStartMark(Self, Start);
      end;
    tmkFinish:
      begin
        Finish := TFinishMark.FromTimingMark(AMark, AStageIndex);
        if Assigned(FOnFinishMark) then
          FOnFinishMark(Self, Finish);
      end;
  end;
end;

end.
