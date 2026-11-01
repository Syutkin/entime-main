unit ParticipantCardCoordinator;
{$mode objfpc}{$H+}
interface

uses Classes, Forms, CompetitionDbContext, StageModel, ParticipantCardModel,
  ParticipantCardService, ParticipantCardForm;

type
  TCardStagesProvider = function: TStages of object;

  TParticipantCardCoordinator = class
  private
    FOwner: TComponent;
    FContext: TCompetitionDbContext;
    FStages: TCardStagesProvider;
    FForm: TParticipantCardForm;
    FParticipantId, FPreferredStage: integer;
    FIdentity, FGeneration: QWord;
    FDirty, FRefreshQueued: boolean;
    FOnJournal: TCardJournalEvent;
    FOnParticipant: TCardParticipantEvent;
    procedure QueuedRefresh(Data: PtrInt);
    procedure FormClosed(Sender: TObject; var Action: TCloseAction);
    procedure RefreshRequested(Sender: TObject);
    procedure JournalRequested(Sender: TObject; const Key: TCardMarkKey);
    procedure ParticipantRequested(Sender: TObject;
      const ParticipantId, StageIndex: integer);
    procedure Load(const PreserveSelection: boolean);
  public
    constructor Create(const Owner: TComponent; const Context: TCompetitionDbContext;
      const Stages: TCardStagesProvider);
    destructor Destroy; override;
    procedure Open(const ParticipantId, PreferredStage: integer);
    procedure Close;
    procedure Refresh;
    procedure InvalidateData;
    procedure UpdateTranslations;
    property Form: TParticipantCardForm read FForm;
    property OnOpenJournal: TCardJournalEvent read FOnJournal write FOnJournal;
    property OnOpenParticipant: TCardParticipantEvent
      read FOnParticipant write FOnParticipant;
  end;

implementation

uses SysUtils, i18n, AppLogger;

constructor TParticipantCardCoordinator.Create(const Owner: TComponent;
  const Context: TCompetitionDbContext; const Stages: TCardStagesProvider);
begin
  inherited Create;
  FOwner := Owner;
  FContext := Context;
  FStages := Stages;
end;

destructor TParticipantCardCoordinator.Destroy;
begin
  Close;
  inherited Destroy;
end;

procedure TParticipantCardCoordinator.Open(const ParticipantId, PreferredStage: integer);
begin
  if (FContext = nil) or not FContext.Connection.Connected or (ParticipantId <= 0) then
    Exit;
  if (FIdentity <> FContext.Identity) or (FGeneration <> FContext.SessionGeneration) then
    Close;
  if FForm = nil then
  begin
    FForm := TParticipantCardForm.Create(FOwner);
    FForm.OnClose := @FormClosed;
    FForm.OnRefresh := @RefreshRequested;
    FForm.OnOpenJournal := @JournalRequested;
    FForm.OnOpenParticipant := @ParticipantRequested;
  end;
  if FParticipantId <> ParticipantId then FForm.SetUnavailable('', True);
  Application.RemoveAsyncCalls(Self);
  FDirty := False;
  FRefreshQueued := False;
  FParticipantId := ParticipantId;
  FPreferredStage := PreferredStage;
  FIdentity := FContext.Identity;
  FGeneration := FContext.SessionGeneration;
  Load(False);
  if FForm <> nil then
  begin
    FForm.Show;
    FForm.BringToFront;
  end;
end;

procedure TParticipantCardCoordinator.Close;
begin
  Application.RemoveAsyncCalls(Self);
  FDirty := False;
  FRefreshQueued := False;
  if FForm <> nil then
  begin
    FForm.OnClose := nil;
    FreeAndNil(FForm);
  end;
  FParticipantId := 0;
  FIdentity := 0;
  FGeneration := 0;
end;

procedure TParticipantCardCoordinator.FormClosed(Sender: TObject;
  var Action: TCloseAction);
begin
  Application.RemoveAsyncCalls(Self);
  FDirty := False;
  FRefreshQueued := False;
  FForm := nil;
  Action := caFree;
end;

procedure TParticipantCardCoordinator.Load(const PreserveSelection: boolean);
var
  R: TCardReadOutcome;
  Preferred: integer;
begin
  if FForm = nil then Exit;
  R := TParticipantCardService.Read(FContext, FStages(), FParticipantId,
    FIdentity, FGeneration);
  case R.State of
    crsReady:
    begin
      FDirty := False;
      Preferred := FPreferredStage;
      if PreserveSelection then Preferred := 0;
      FForm.SetSnapshot(R.Snapshot, Preferred, PreserveSelection);
    end;
    crsMissing: FForm.SetUnavailable(rsCardDeleted, True);
    crsSessionChanged: Close;
    crsBusy: begin
      FDirty := True;
      FForm.SetUnavailable(rsCardBusy, False);
    end;
    crsError:
    begin
      FForm.SetUnavailable(Format(rsCardReadError, [R.ErrorText]), False);
      AppLog(Format(rsCardReadError, [R.ErrorText]), allWarning,
        alvDetails, alsDatabase);
    end;
  end;
end;

procedure TParticipantCardCoordinator.InvalidateData;
begin
  if FForm = nil then Exit;
  FDirty := True;
  FForm.SetUnavailable(rsCardStale, False);
  if FRefreshQueued then Exit;
  FRefreshQueued := True;
  Application.QueueAsyncCall(@QueuedRefresh, 0);
end;

procedure TParticipantCardCoordinator.QueuedRefresh(Data: PtrInt);
begin
  FRefreshQueued := False;
  if (FForm = nil) or not FDirty then Exit;
  FDirty := False;
  Load(True);
end;

procedure TParticipantCardCoordinator.UpdateTranslations;
begin
  if FForm = nil then Exit;
  FForm.UpdateTranslations;
  Refresh;
end;

procedure TParticipantCardCoordinator.Refresh;
begin
  Application.RemoveAsyncCalls(Self);
  FRefreshQueued := False;
  FDirty := False;
  Load(True);
end;

procedure TParticipantCardCoordinator.RefreshRequested(Sender: TObject);
begin
  Refresh;
end;

procedure TParticipantCardCoordinator.JournalRequested(Sender: TObject;
  const Key: TCardMarkKey);
var
  Mark: TCardMark;
begin
  if FForm = nil then Exit;
  if not TParticipantCardService.TryCurrentMark(FForm.Snapshot, Key,
    FContext, FStages(), Mark) then
  begin
    Refresh;
    if FForm <> nil then FForm.ClearMarkSelection(rsCardMarkChanged);
    Exit;
  end;
  if Assigned(FOnJournal) then FOnJournal(Sender, Key);
end;

procedure TParticipantCardCoordinator.ParticipantRequested(Sender: TObject;
  const ParticipantId, StageIndex: integer);
begin
  if (FForm <> nil) and TParticipantCardService.SessionMatches(FForm.Snapshot,
    FContext) and Assigned(FOnParticipant) then
    FOnParticipant(Sender, ParticipantId, StageIndex);
end;

end.
