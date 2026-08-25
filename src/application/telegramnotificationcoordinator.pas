unit TelegramNotificationCoordinator;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, HttpTransport, CompetitionFinishService;

const
  TELEGRAM_MAX_PENDING = 100;
  TELEGRAM_RETRY_DEFAULT_ENABLED = False;
  TELEGRAM_RETRY_DEFAULT_COUNT = 2;
  TELEGRAM_RETRY_DEFAULT_DELAY_SECONDS = 5;
  TELEGRAM_RETRY_MIN_COUNT = 1;
  TELEGRAM_RETRY_MAX_COUNT = 10;
  TELEGRAM_RETRY_MIN_DELAY_SECONDS = 1;
  TELEGRAM_RETRY_MAX_DELAY_SECONDS = 300;

type
  TTelegramRetryPolicy = record
    Enabled: Boolean;
    RetryCount: Integer;
    DelaySeconds: Integer;
    class function Create(const AEnabled: Boolean; const ARetryCount,
      ADelaySeconds: Integer): TTelegramRetryPolicy; static;
    class function Disabled: TTelegramRetryPolicy; static;
  end;

  TTelegramQueueItemInfo = record
    ParticipantNumber: Integer;
    EnqueuedAt: TDateTime;
    IsTest: Boolean;
  end;

  TTelegramDeliveryResult = record
    Item: TTelegramQueueItemInfo;
    Outcome: TFinishNotificationOutcome;
    AttemptCount: Integer;
  end;

  TTelegramCompletedEvent = procedure(Sender: TObject;
    const ADelivery: TTelegramDeliveryResult) of object;
  TTelegramDroppedEvent = procedure(Sender: TObject;
    const AItem: TTelegramQueueItemInfo) of object;

  TTelegramNotificationCoordinator = class;

  TTelegramNotificationWorker = class(TThread)
  private
    FOwner: TTelegramNotificationCoordinator;
  protected
    procedure Execute; override;
  public
    constructor Create(const AOwner: TTelegramNotificationCoordinator);
  end;

  TTelegramNotificationCoordinator = class
  private type
    TQueueItem = record
      Info: TTelegramQueueItemInfo;
      Endpoint: string;
      Request: THttpRequest;
      RetryPolicy: TTelegramRetryPolicy;
    end;
    TQueueItems = array of TQueueItem;
    TQueuedEventKind = (qekCompleted, qekDropped);
    TQueuedEvent = record
      Kind: TQueuedEventKind;
      Delivery: TTelegramDeliveryResult;
      DroppedItem: TTelegramQueueItemInfo;
    end;
    TQueuedEvents = array of TQueuedEvent;
  private
    FFactory: IHttpTransportFactory;
    FLock: TRTLCriticalSection;
    FWorkEvent: PRTLEvent;
    FCancelEvent: PRTLEvent;
    FQueue: TQueueItems;
    FEvents: TQueuedEvents;
    FWorker: TTelegramNotificationWorker;
    FActiveTransport: IHttpTransport;
    FActive: Boolean;
    FClosing: Boolean;
    FOnCompleted: TTelegramCompletedEvent;
    FOnDropped: TTelegramDroppedEvent;
    function EnqueueItem(const AItem: TQueueItem): Boolean;
    function TakeNext(out AItem: TQueueItem): Boolean;
    function IsClosing: Boolean;
    procedure SetActiveTransport(const ATransport: IHttpTransport);
    procedure ClearActiveTransport;
    procedure FinishItem(const AItem: TQueueItem;
      const AOutcome: TFinishNotificationOutcome;
      const AAttemptCount: Integer);
    procedure QueueDropped(const AItem: TTelegramQueueItemInfo);
    procedure QueueCompleted(const ADelivery: TTelegramDeliveryResult);
    procedure DeliverNextEvent;
    procedure ExecuteItem(const AItem: TQueueItem);
    class function IsRetryable(
      const AOutcome: TFinishNotificationOutcome): Boolean; static;
    function GetPendingCount: Integer;
  public
    constructor Create(const AFactory: IHttpTransportFactory);
    destructor Destroy; override;
    function EnqueueResult(const AResult: TFinishResult;
      const AEndpoint: string; const ARetryPolicy: TTelegramRetryPolicy):
      Boolean;
    function EnqueueFields(const AFields: THttpFormFields;
      const AEndpoint: string; const ARetryPolicy: TTelegramRetryPolicy):
      Boolean;
    function Shutdown: Integer;
    property PendingCount: Integer read GetPendingCount;
    property OnCompleted: TTelegramCompletedEvent read FOnCompleted
      write FOnCompleted;
    property OnDropped: TTelegramDroppedEvent read FOnDropped
      write FOnDropped;
  end;

implementation

function ClampOrDefault(const AValue, AMinimum, AMaximum,
  ADefault: Integer): Integer;
begin
  if (AValue < AMinimum) or (AValue > AMaximum) then
    Result := ADefault
  else
    Result := AValue;
end;

class function TTelegramRetryPolicy.Create(const AEnabled: Boolean;
  const ARetryCount, ADelaySeconds: Integer): TTelegramRetryPolicy;
begin
  Result.Enabled := AEnabled;
  Result.RetryCount := ClampOrDefault(ARetryCount,
    TELEGRAM_RETRY_MIN_COUNT, TELEGRAM_RETRY_MAX_COUNT,
    TELEGRAM_RETRY_DEFAULT_COUNT);
  Result.DelaySeconds := ClampOrDefault(ADelaySeconds,
    TELEGRAM_RETRY_MIN_DELAY_SECONDS, TELEGRAM_RETRY_MAX_DELAY_SECONDS,
    TELEGRAM_RETRY_DEFAULT_DELAY_SECONDS);
end;

class function TTelegramRetryPolicy.Disabled: TTelegramRetryPolicy;
begin
  Result := Create(False, TELEGRAM_RETRY_DEFAULT_COUNT,
    TELEGRAM_RETRY_DEFAULT_DELAY_SECONDS);
end;

constructor TTelegramNotificationWorker.Create(
  const AOwner: TTelegramNotificationCoordinator);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

procedure TTelegramNotificationWorker.Execute;
var
  Item: TTelegramNotificationCoordinator.TQueueItem;
begin
  while not Terminated do
  begin
    if FOwner.TakeNext(Item) then
      FOwner.ExecuteItem(Item)
    else
    begin
      if FOwner.IsClosing then
        Exit;
      RTLEventWaitFor(FOwner.FWorkEvent);
    end;
  end;
end;

constructor TTelegramNotificationCoordinator.Create(
  const AFactory: IHttpTransportFactory);
begin
  inherited Create;
  if not Assigned(AFactory) then
    raise EArgumentNilException.Create('AFactory');
  FFactory := AFactory;
  InitCriticalSection(FLock);
  FWorkEvent := RTLEventCreate;
  FCancelEvent := RTLEventCreate;
  FWorker := TTelegramNotificationWorker.Create(Self);
  try
    FWorker.Start;
  except
    FreeAndNil(FWorker);
    RTLEventDestroy(FCancelEvent);
    RTLEventDestroy(FWorkEvent);
    DoneCriticalSection(FLock);
    raise;
  end;
end;

destructor TTelegramNotificationCoordinator.Destroy;
begin
  Shutdown;
  FreeAndNil(FWorker);
  RTLEventDestroy(FCancelEvent);
  RTLEventDestroy(FWorkEvent);
  DoneCriticalSection(FLock);
  FFactory := nil;
  inherited Destroy;
end;

function TTelegramNotificationCoordinator.EnqueueResult(
  const AResult: TFinishResult; const AEndpoint: string;
  const ARetryPolicy: TTelegramRetryPolicy): Boolean;
var
  Item: TQueueItem;
begin
  Item := Default(TQueueItem);
  Item.Info.ParticipantNumber := AResult.ParticipantNumber;
  Item.Info.EnqueuedAt := Now;
  Item.Endpoint := AEndpoint;
  Item.Request := TTelegramResultNotifier.BuildRequest(AResult, AEndpoint);
  Item.RetryPolicy := ARetryPolicy;
  Result := EnqueueItem(Item);
end;

function TTelegramNotificationCoordinator.EnqueueFields(
  const AFields: THttpFormFields; const AEndpoint: string;
  const ARetryPolicy: TTelegramRetryPolicy): Boolean;
var
  Item: TQueueItem;
begin
  Item := Default(TQueueItem);
  Item.Info.EnqueuedAt := Now;
  Item.Info.IsTest := True;
  Item.Endpoint := AEndpoint;
  Item.Request := TTelegramResultNotifier.BuildRequest(AEndpoint, AFields);
  Item.RetryPolicy := ARetryPolicy;
  Result := EnqueueItem(Item);
end;

function TTelegramNotificationCoordinator.EnqueueItem(
  const AItem: TQueueItem): Boolean;
var
  Dropped: TTelegramQueueItemInfo;
  HasDropped: Boolean;
  Index: Integer;
begin
  Result := False;
  HasDropped := False;
  EnterCriticalSection(FLock);
  try
    if FClosing then
      Exit;
    if Length(FQueue) = TELEGRAM_MAX_PENDING then
    begin
      Dropped := FQueue[0].Info;
      for Index := 1 to High(FQueue) do
        FQueue[Index - 1] := FQueue[Index];
      SetLength(FQueue, Length(FQueue) - 1);
      HasDropped := True;
    end;
    SetLength(FQueue, Length(FQueue) + 1);
    FQueue[High(FQueue)] := AItem;
    RTLEventSetEvent(FWorkEvent);
    Result := True;
  finally
    LeaveCriticalSection(FLock);
  end;
  if HasDropped then
    QueueDropped(Dropped);
end;

function TTelegramNotificationCoordinator.TakeNext(
  out AItem: TQueueItem): Boolean;
var
  Index: Integer;
begin
  Result := False;
  AItem := Default(TQueueItem);
  EnterCriticalSection(FLock);
  try
    if FClosing or (Length(FQueue) = 0) then
    begin
      RTLEventResetEvent(FWorkEvent);
      Exit;
    end;
    AItem := FQueue[0];
    for Index := 1 to High(FQueue) do
      FQueue[Index - 1] := FQueue[Index];
    SetLength(FQueue, Length(FQueue) - 1);
    FActive := True;
    if Length(FQueue) = 0 then
      RTLEventResetEvent(FWorkEvent);
    Result := True;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTelegramNotificationCoordinator.IsClosing: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := FClosing;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TTelegramNotificationCoordinator.SetActiveTransport(
  const ATransport: IHttpTransport);
begin
  EnterCriticalSection(FLock);
  try
    FActiveTransport := ATransport;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TTelegramNotificationCoordinator.ClearActiveTransport;
begin
  EnterCriticalSection(FLock);
  try
    FActiveTransport := nil;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

class function TTelegramNotificationCoordinator.IsRetryable(
  const AOutcome: TFinishNotificationOutcome): Boolean;
begin
  if AOutcome.TransportErrorKind <> hekNone then
    Exit(AOutcome.TransportErrorKind <> hekCancelled);
  Result := (AOutcome.ResponseStatusCode = 408) or
    (AOutcome.ResponseStatusCode = 429) or
    ((AOutcome.ResponseStatusCode >= 500) and
    (AOutcome.ResponseStatusCode <= 599));
end;

procedure TTelegramNotificationCoordinator.ExecuteItem(
  const AItem: TQueueItem);
var
  Attempt, MaximumAttempts: Integer;
  Outcome: TFinishNotificationOutcome;
  Transport: IHttpTransport;
begin
  MaximumAttempts := 1;
  if AItem.RetryPolicy.Enabled then
    Inc(MaximumAttempts, AItem.RetryPolicy.RetryCount);
  Attempt := 0;
  Outcome := Default(TFinishNotificationOutcome);
  while (Attempt < MaximumAttempts) and not IsClosing do
  begin
    Inc(Attempt);
    Transport := FFactory.CreateTransport;
    SetActiveTransport(Transport);
    try
      Outcome := TTelegramResultNotifier.Send(AItem.Request,
        AItem.Endpoint, Transport);
    finally
      ClearActiveTransport;
      Transport := nil;
    end;
    if Outcome.Success or not IsRetryable(Outcome) or
      (Attempt >= MaximumAttempts) then
      Break;
    RTLEventWaitFor(FCancelEvent,
      Cardinal(AItem.RetryPolicy.DelaySeconds) * 1000);
  end;
  FinishItem(AItem, Outcome, Attempt);
end;

procedure TTelegramNotificationCoordinator.FinishItem(
  const AItem: TQueueItem; const AOutcome: TFinishNotificationOutcome;
  const AAttemptCount: Integer);
var
  Delivery: TTelegramDeliveryResult;
  Closing: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    FActive := False;
    Closing := FClosing;
  finally
    LeaveCriticalSection(FLock);
  end;
  if Closing then
    Exit;
  Delivery := Default(TTelegramDeliveryResult);
  Delivery.Item := AItem.Info;
  Delivery.Outcome := AOutcome;
  Delivery.AttemptCount := AAttemptCount;
  QueueCompleted(Delivery);
end;

procedure TTelegramNotificationCoordinator.QueueDropped(
  const AItem: TTelegramQueueItemInfo);
var
  Event: TQueuedEvent;
begin
  Event := Default(TQueuedEvent);
  Event.Kind := qekDropped;
  Event.DroppedItem := AItem;
  EnterCriticalSection(FLock);
  try
    if FClosing then
      Exit;
    SetLength(FEvents, Length(FEvents) + 1);
    FEvents[High(FEvents)] := Event;
  finally
    LeaveCriticalSection(FLock);
  end;
  TThread.ForceQueue(FWorker, @DeliverNextEvent);
end;

procedure TTelegramNotificationCoordinator.QueueCompleted(
  const ADelivery: TTelegramDeliveryResult);
var
  Event: TQueuedEvent;
begin
  Event := Default(TQueuedEvent);
  Event.Kind := qekCompleted;
  Event.Delivery := ADelivery;
  EnterCriticalSection(FLock);
  try
    if FClosing then
      Exit;
    SetLength(FEvents, Length(FEvents) + 1);
    FEvents[High(FEvents)] := Event;
  finally
    LeaveCriticalSection(FLock);
  end;
  TThread.ForceQueue(FWorker, @DeliverNextEvent);
end;

procedure TTelegramNotificationCoordinator.DeliverNextEvent;
var
  Event: TQueuedEvent;
  Index: Integer;
begin
  Event := Default(TQueuedEvent);
  EnterCriticalSection(FLock);
  try
    if FClosing or (Length(FEvents) = 0) then
      Exit;
    Event := FEvents[0];
    for Index := 1 to High(FEvents) do
      FEvents[Index - 1] := FEvents[Index];
    SetLength(FEvents, Length(FEvents) - 1);
  finally
    LeaveCriticalSection(FLock);
  end;
  case Event.Kind of
    qekCompleted:
      if Assigned(FOnCompleted) then
        FOnCompleted(Self, Event.Delivery);
    qekDropped:
      if Assigned(FOnDropped) then
        FOnDropped(Self, Event.DroppedItem);
  end;
end;

function TTelegramNotificationCoordinator.GetPendingCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := Length(FQueue);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTelegramNotificationCoordinator.Shutdown: Integer;
var
  ActiveTransport: IHttpTransport;
begin
  Result := 0;
  if not Assigned(FWorker) then
    Exit;
  EnterCriticalSection(FLock);
  try
    if not FClosing then
    begin
      FClosing := True;
      Result := Length(FQueue);
      FQueue := nil;
    end;
    ActiveTransport := FActiveTransport;
    FOnCompleted := nil;
    FOnDropped := nil;
  finally
    LeaveCriticalSection(FLock);
  end;
  FWorker.Terminate;
  RTLEventSetEvent(FWorkEvent);
  RTLEventSetEvent(FCancelEvent);
  if Assigned(ActiveTransport) then
    ActiveTransport.Cancel;
  TThread.RemoveQueuedEvents(FWorker, @DeliverNextEvent);
  FWorker.WaitFor;
  TThread.RemoveQueuedEvents(FWorker, @DeliverNextEvent);
  EnterCriticalSection(FLock);
  try
    FEvents := nil;
    FActiveTransport := nil;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

end.
