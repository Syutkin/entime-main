unit FinishMarkServiceTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DateUtils, FPCUnit, TestRegistry, TimingMark, FinishMark,
  FinishMarkService;

type
  TFakeFinishMarkPersistence = class(TInterfacedObject,
    IFinishMarkPersistence)
  private
    FInsertCount: integer;
    FFailInsert: boolean;
    FLastInserted: TFinishMark;
    FStoredMark: TFinishMark;
  public
    function Insert(const AMark: TFinishMark): TFinishMark;
    function TryLoadById(const AMarkId: int64; out AMark: TFinishMark): boolean;
    function HideWorkQueue: integer;
    procedure Update(const AMark: TFinishMark);
    property InsertCount: integer read FInsertCount;
    property FailInsert: boolean read FFailInsert write FFailInsert;
    property LastInserted: TFinishMark read FLastInserted;
    property StoredMark: TFinishMark read FStoredMark;
  end;

  TFinishMarkServiceTests = class(TTestCase)
  private
    FChangedCount: integer;
    FLastChangedId: int64;
    FPersistence: TFakeFinishMarkPersistence;
    FPersistenceInterface: IFinishMarkPersistence;
    FService: TFinishMarkService;
    function MarkAt(const ATime: TDateTime): TFinishMark;
    procedure MarkChanged(Sender: TObject; const AMarkId: int64);
    procedure RaisingMarkChanged(Sender: TObject; const AMarkId: int64);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Handle_PreservesCurrentDebounceBoundary;
    procedure Handle_IgnoredMarkDoesNotMoveAcceptedBoundary;
    procedure Handle_EmptySequenceResetsDebounce;
    procedure Handle_PersistsPendingMarkAndReturnsStableId;
    procedure Handle_PersistsDebouncedMarkWithDiagnostic;
    procedure SetParticipantNumber_LoadsAndPersistsDraftWithoutApplying;
    procedure HideWorkQueue_DelegatesToPersistenceAndResetsSequence;
    procedure Handle_NotifiesAfterPersistence;
    procedure Mutations_NotifyOnlyAfterStoredChanges;
    procedure ObserverError_DoesNotFailPersistedChange;
    procedure PersistenceError_DoesNotNotify;
  end;

implementation

function TFakeFinishMarkPersistence.Insert(const AMark: TFinishMark): TFinishMark;
begin
  if FFailInsert then
    raise Exception.Create('insert failed');
  Inc(FInsertCount);
  FLastInserted := AMark;
  Result := AMark;
  Result.Id := 73;
  FStoredMark := Result;
end;

function TFakeFinishMarkPersistence.TryLoadById(const AMarkId: int64;
  out AMark: TFinishMark): boolean;
begin
  Result := (AMarkId > 0) and (FStoredMark.Id = AMarkId);
  if Result then
    AMark := FStoredMark
  else
    AMark := Default(TFinishMark);
end;

function TFakeFinishMarkPersistence.HideWorkQueue: integer;
begin
  if FStoredMark.Status <> fmsPending then
    Exit(0);
  FStoredMark.Hide;
  Result := 1;
end;

procedure TFakeFinishMarkPersistence.Update(const AMark: TFinishMark);
begin
  FStoredMark := AMark;
end;

procedure TFinishMarkServiceTests.SetUp;
begin
  inherited SetUp;
  FChangedCount := 0;
  FLastChangedId := 0;
  FPersistence := TFakeFinishMarkPersistence.Create;
  FPersistenceInterface := FPersistence;
  FService := TFinishMarkService.Create(FPersistenceInterface, 250);
end;

procedure TFinishMarkServiceTests.MarkChanged(Sender: TObject; const AMarkId: int64);
begin
  Inc(FChangedCount);
  FLastChangedId := AMarkId;
  AssertEquals(AMarkId, FPersistence.StoredMark.Id);
end;

procedure TFinishMarkServiceTests.RaisingMarkChanged(Sender: TObject;
  const AMarkId: int64);
begin
  raise Exception.Create('observer failed');
end;

procedure TFinishMarkServiceTests.TearDown;
begin
  FService.Free;
  FPersistenceInterface := nil;
  FPersistence := nil;
  inherited TearDown;
end;

function TFinishMarkServiceTests.MarkAt(const ATime: TDateTime): TFinishMark;
begin
  Result := TFinishMark.FromTimingMark(TTimingMark.Finish(ATime,
    TTimingMarkSource.Serial('COM1'), EncodeDateTime(2026, 8, 13, 10, 0, 0, 0)), 1);
end;

procedure TFinishMarkServiceTests.Handle_PreservesCurrentDebounceBoundary;
var
  BaseTime: TDateTime;
  ResultMark: TFinishMark;
begin
  BaseTime := EncodeTime(10, 0, 0, 0);

  ResultMark := FService.Handle(MarkAt(BaseTime), True);
  AssertEquals(Ord(fmsPending), Ord(ResultMark.Status));

  ResultMark := FService.Handle(MarkAt(IncMilliSecond(BaseTime, 250)), False);
  AssertEquals(Ord(fmsIgnoredDebounce), Ord(ResultMark.Status));

  ResultMark := FService.Handle(MarkAt(IncMilliSecond(BaseTime, 251)), False);
  AssertEquals(Ord(fmsPending), Ord(ResultMark.Status));
end;

procedure TFinishMarkServiceTests.Handle_IgnoredMarkDoesNotMoveAcceptedBoundary;
var
  BaseTime: TDateTime;
  ResultMark: TFinishMark;
begin
  BaseTime := EncodeTime(10, 0, 0, 0);
  FService.Handle(MarkAt(BaseTime), True);
  FService.Handle(MarkAt(IncMilliSecond(BaseTime, 200)), False);

  ResultMark := FService.Handle(MarkAt(IncMilliSecond(BaseTime, 251)), False);

  AssertEquals(Ord(fmsPending), Ord(ResultMark.Status));
end;

procedure TFinishMarkServiceTests.Handle_EmptySequenceResetsDebounce;
var
  BaseTime: TDateTime;
  ResultMark: TFinishMark;
begin
  BaseTime := EncodeTime(10, 0, 0, 0);
  FService.Handle(MarkAt(BaseTime), True);
  FService.Handle(MarkAt(IncMilliSecond(BaseTime, 100)), False);

  ResultMark := FService.Handle(MarkAt(BaseTime), True);

  AssertEquals(Ord(fmsPending), Ord(ResultMark.Status));
end;

procedure TFinishMarkServiceTests.
Handle_PersistsPendingMarkAndReturnsStableId;
var
  ResultMark: TFinishMark;
begin
  ResultMark := FService.Handle(MarkAt(EncodeTime(10, 0, 0, 0)), True);

  AssertEquals(1, FPersistence.InsertCount);
  AssertEquals(73, ResultMark.Id);
  AssertEquals(Ord(fmsPending), Ord(FPersistence.LastInserted.Status));
end;

procedure TFinishMarkServiceTests.
Handle_PersistsDebouncedMarkWithDiagnostic;
var
  BaseTime: TDateTime;
  ResultMark: TFinishMark;
begin
  BaseTime := EncodeTime(10, 0, 0, 0);
  FService.Handle(MarkAt(BaseTime), True);

  ResultMark := FService.Handle(MarkAt(IncMilliSecond(BaseTime, 100)), False);

  AssertEquals(2, FPersistence.InsertCount);
  AssertEquals(73, ResultMark.Id);
  AssertEquals(Ord(fmsIgnoredDebounce),
    Ord(FPersistence.LastInserted.Status));
  AssertEquals('debounce_interval_ms=250; elapsed_ms=100',
    FPersistence.LastInserted.Diagnostic);
end;

procedure TFinishMarkServiceTests.
SetParticipantNumber_LoadsAndPersistsDraftWithoutApplying;
var
  Mark: TFinishMark;
begin
  Mark := FService.Handle(MarkAt(EncodeTime(10, 0, 0, 0)), True);

  Mark := FService.SetParticipantNumber(Mark.Id, True, 42);

  AssertTrue(Mark.HasParticipantNumber);
  AssertEquals(42, Mark.ParticipantNumber);
  AssertFalse(Mark.HasAssignmentMode);
  AssertEquals(Ord(fmsPending), Ord(Mark.Status));
  AssertEquals(42, FPersistence.StoredMark.ParticipantNumber);
end;

procedure TFinishMarkServiceTests.
HideWorkQueue_DelegatesToPersistenceAndResetsSequence;
var
  BaseTime: TDateTime;
  Mark: TFinishMark;
begin
  BaseTime := EncodeTime(10, 0, 0, 0);
  FService.Handle(MarkAt(BaseTime), True);

  AssertEquals(1, FService.HideWorkQueue);
  AssertEquals(Ord(fmsHidden), Ord(FPersistence.StoredMark.Status));
  Mark := FService.Handle(MarkAt(IncMilliSecond(BaseTime, 100)), True);
  AssertEquals(Ord(fmsPending), Ord(Mark.Status));
end;

procedure TFinishMarkServiceTests.Handle_NotifiesAfterPersistence;
begin
  FService.OnChanged := @MarkChanged;

  FService.Handle(MarkAt(EncodeTime(10, 0, 0, 0)), True);

  AssertEquals(1, FChangedCount);
  AssertEquals(73, FLastChangedId);
end;

procedure TFinishMarkServiceTests.Mutations_NotifyOnlyAfterStoredChanges;
var
  Mark: TFinishMark;
begin
  FService.OnChanged := @MarkChanged;
  Mark := FService.Handle(MarkAt(EncodeTime(10, 0, 0, 0)), True);
  FService.SetParticipantNumber(Mark.Id, True, 42);
  AssertEquals(2, FChangedCount);
  AssertEquals(Mark.Id, FLastChangedId);

  AssertEquals(1, FService.HideWorkQueue);
  AssertEquals(3, FChangedCount);
  AssertEquals(0, FLastChangedId);

  AssertEquals(0, FService.HideWorkQueue);
  AssertEquals(3, FChangedCount);
end;

procedure TFinishMarkServiceTests.ObserverError_DoesNotFailPersistedChange;
var
  Mark: TFinishMark;
begin
  FService.OnChanged := @RaisingMarkChanged;

  Mark := FService.Handle(MarkAt(EncodeTime(10, 0, 0, 0)), True);

  AssertEquals(73, Mark.Id);
  AssertEquals(1, FPersistence.InsertCount);
end;

procedure TFinishMarkServiceTests.PersistenceError_DoesNotNotify;
begin
  FService.OnChanged := @MarkChanged;
  FPersistence.FailInsert := True;

  try
    FService.Handle(MarkAt(EncodeTime(10, 0, 0, 0)), True);
    Fail('Expected the persistence error.');
  except
    on E: Exception do
      AssertEquals('insert failed', E.Message);
  end;
  AssertEquals(0, FChangedCount);
end;

initialization
  RegisterTest(TFinishMarkServiceTests);

end.
