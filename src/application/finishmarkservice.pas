unit FinishMarkService;

{$mode ObjFPC}{$H+}

interface

uses
  FinishMark;

type
  TFinishMarkChangedEvent = procedure(Sender: TObject;
    const AMarkId: int64) of object;

  { IFinishMarkPersistence }

  IFinishMarkPersistence = interface
    ['{F2895487-0FA7-41BB-A753-824EE3DFD07B}']
    function Insert(const AMark: TFinishMark): TFinishMark;
    function TryLoadById(const AMarkId: int64; out AMark: TFinishMark): boolean;
    function HideWorkQueue: integer;
    procedure Update(const AMark: TFinishMark);
  end;

  { TFinishMarkService }

  TFinishMarkService = class
  private
    FDebounceIntervalMs: integer;
    FHasPreviousFinish: boolean;
    FPersistence: IFinishMarkPersistence;
    FPreviousFinish: TDateTime;
    FOnChanged: TFinishMarkChangedEvent;
    procedure NotifyChanged(const AMarkId: int64);
  public
    constructor Create(const APersistence: IFinishMarkPersistence;
      const ADebounceIntervalMs: integer = 250);
    function Handle(const AMark: TFinishMark;
      const ASequenceEmpty: boolean): TFinishMark;
    function SetParticipantNumber(const AMarkId: int64;
      const AHasParticipantNumber: boolean;
      const AParticipantNumber: integer): TFinishMark;
    function TryLoad(const AMarkId: int64; out AMark: TFinishMark): boolean;
    function HideWorkQueue: integer;
    procedure ResetSequence;
    property DebounceIntervalMs: integer read FDebounceIntervalMs
      write FDebounceIntervalMs;
    property OnChanged: TFinishMarkChangedEvent read FOnChanged write FOnChanged;
  end;

implementation

uses
  DateUtils, SysUtils;

constructor TFinishMarkService.Create(const APersistence: IFinishMarkPersistence;
  const ADebounceIntervalMs: integer);
begin
  inherited Create;
  if not Assigned(APersistence) then
    raise EArgumentNilException.Create('Persistence is required.');
  FPersistence := APersistence;
  FDebounceIntervalMs := ADebounceIntervalMs;
  ResetSequence;
end;

procedure TFinishMarkService.NotifyChanged(const AMarkId: int64);
begin
  if not Assigned(FOnChanged) then
    Exit;
  try
    FOnChanged(Self, AMarkId);
  except
    { A presentation observer must not turn a persisted change into a
      reported application failure. }
  end;
end;

function TFinishMarkService.Handle(const AMark: TFinishMark;
  const ASequenceEmpty: boolean): TFinishMark;
var
  AcceptedAsBoundary: boolean;
  ElapsedMs: int64;
begin
  Result := AMark;
  if ASequenceEmpty then
    ResetSequence;

  AcceptedAsBoundary := not FHasPreviousFinish;
  if FHasPreviousFinish then
  begin
    ElapsedMs := MilliSecondsBetween(AMark.EventTime, FPreviousFinish);
    AcceptedAsBoundary := ElapsedMs > FDebounceIntervalMs;
  end
  else
    ElapsedMs := 0;

  if not AcceptedAsBoundary then
    Result.MarkIgnoredDebounce(Format('debounce_interval_ms=%d; elapsed_ms=%d',
      [FDebounceIntervalMs, ElapsedMs]));

  Result := FPersistence.Insert(Result);
  NotifyChanged(Result.Id);
  if AcceptedAsBoundary then
  begin
    FPreviousFinish := AMark.EventTime;
    FHasPreviousFinish := True;
  end;
end;

function TFinishMarkService.SetParticipantNumber(const AMarkId: int64;
  const AHasParticipantNumber: boolean; const AParticipantNumber: integer): TFinishMark;
begin
  if not FPersistence.TryLoadById(AMarkId, Result) then
    raise EArgumentException.CreateFmt('Finish mark %d was not found.', [AMarkId]);
  Result.SetParticipantNumber(AHasParticipantNumber, AParticipantNumber);
  FPersistence.Update(Result);
  NotifyChanged(Result.Id);
end;

function TFinishMarkService.TryLoad(const AMarkId: int64;
  out AMark: TFinishMark): boolean;
begin
  Result := FPersistence.TryLoadById(AMarkId, AMark);
end;

function TFinishMarkService.HideWorkQueue: integer;
begin
  Result := FPersistence.HideWorkQueue;
  if Result > 0 then
  begin
    ResetSequence;
    NotifyChanged(0);
  end;
end;

procedure TFinishMarkService.ResetSequence;
begin
  FHasPreviousFinish := False;
  FPreviousFinish := 0;
end;

end.
