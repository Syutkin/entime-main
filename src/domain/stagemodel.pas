unit StageModel;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, StageConfig, i18n;

type

  TStageIndexArray = array of integer;

  { TStageModel }
  TStageModel = class
  private
    FIndex: integer;
  public
    Name: string;
    isActive: boolean;
    constructor Create(const AIndex: integer; const AName: string = '';
      const Active: boolean = True);
    property Index: integer read FIndex;
  end;

  TStageDictionary = specialize TDictionary<integer, TStageModel>;

  { TStages }
  TStages = class
  private
    FStages: TStageDictionary;
    function GetCount: integer;
    function GetElem(const Index: integer): TStageModel;
    function GetActiveStagesCount: integer;
    function CreateDefaultStage(const Index: integer): TStageModel;
    procedure ValidateIndex(const Index: integer);
    procedure ValidateCount(const NewCount: integer);
  public
    constructor Create(const StageCount: integer = DEFAULT_STAGE_COUNT);
    destructor Destroy; override;
    procedure Resize(const NewCount: integer);
    function IsValidIndex(const Index: integer): boolean;
    function IsActiveIndex(const Index: integer): boolean;
    function ActiveIndices: TStageIndexArray;
    function FirstActiveIndex: integer;
    function NormalizeActiveIndex(const Index: integer): integer;
    procedure EnsureActiveStage;
    property Items[Index: integer]: TStageModel read GetElem; default;
    property Count: integer read GetCount;
    property ActiveStagesCount: integer read GetActiveStagesCount;
  end;

function StageConfigurationSignature(const Stages: TStages): string;

implementation

function StageConfigurationSignature(const Stages: TStages): string;
var
  I: integer;
begin
  Result := IntToStr(Stages.Count);
  for I := 1 to Stages.Count do Result :=
      Result + '|' + IntToStr(Ord(Stages[I].isActive)) + ':' + IntToStr(Length(Stages[I].Name)) +
      ':' + Stages[I].Name;
end;

{ TStageModel }

constructor TStageModel.Create(const AIndex: integer; const AName: string;
  const Active: boolean);
begin
  FIndex := AIndex;
  Name := AName;
  isActive := Active;
end;

{ TStages }

function TStages.CreateDefaultStage(const Index: integer): TStageModel;
begin
  Result := TStageModel.Create(Index, Format(rsSUFormat, [Index]), False);
end;

function TStages.GetCount: integer;
begin
  Result := FStages.Count;
end;

procedure TStages.ValidateIndex(const Index: integer);
begin
  if not IsValidIndex(Index) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index %d is outside the range 1..%d.', [Index, Count]);
end;

procedure TStages.ValidateCount(const NewCount: integer);
begin
  if not IsValidStageCount(NewCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      rsStageCountRangeError, [IntToStr(NewCount), MIN_STAGE_COUNT,
      MAX_SUPPORTED_STAGE_COUNT]);
end;

function TStages.GetElem(const Index: integer): TStageModel;
begin
  ValidateIndex(Index);
  Result := FStages[Index];
end;

function TStages.GetActiveStagesCount: integer;
var
  Stage: TStageModel;
begin
  Result := 0;
  for Stage in FStages.Values do
    if Stage.isActive then
      Inc(Result);
end;

constructor TStages.Create(const StageCount: integer);
begin
  inherited Create;
  FStages := TStageDictionary.Create;
  Resize(StageCount);
  EnsureActiveStage;
end;

destructor TStages.Destroy;
var
  Stage: TStageModel;
begin
  for Stage in FStages.Values do
    Stage.Free;
  FreeAndNil(FStages);
  inherited Destroy;
end;

procedure TStages.Resize(const NewCount: integer);
var
  Index: integer;
  Stage: TStageModel;
begin
  ValidateCount(NewCount);

  for Index := Count downto NewCount + 1 do
  begin
    Stage := FStages[Index];
    FStages.Remove(Index);
    Stage.Free;
  end;

  for Index := Count + 1 to NewCount do
    FStages.Add(Index, CreateDefaultStage(Index));

  EnsureActiveStage;
end;

function TStages.IsValidIndex(const Index: integer): boolean;
begin
  Result := (Index >= 1) and (Index <= Count);
end;

function TStages.IsActiveIndex(const Index: integer): boolean;
begin
  Result := IsValidIndex(Index) and FStages[Index].isActive;
end;

function TStages.ActiveIndices: TStageIndexArray;
var
  Index, ResultIndex: integer;
begin
  Result := nil;
  SetLength(Result, ActiveStagesCount);
  ResultIndex := 0;
  for Index := 1 to Count do
    if FStages[Index].isActive then
    begin
      Result[ResultIndex] := Index;
      Inc(ResultIndex);
    end;
end;

function TStages.FirstActiveIndex: integer;
var
  Index: integer;
begin
  Result := 0;
  for Index := 1 to Count do
    if FStages[Index].isActive then
      Exit(Index);
end;

function TStages.NormalizeActiveIndex(const Index: integer): integer;
begin
  if IsActiveIndex(Index) then
    Result := Index
  else
    Result := FirstActiveIndex;
end;

procedure TStages.EnsureActiveStage;
begin
  if FirstActiveIndex = 0 then
    FStages[1].isActive := True;
end;

end.
