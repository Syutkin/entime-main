unit stagemodel;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  Generics.Collections;

type

  { TStageModel }
  TStageModel = class
  public
    Name: string;
    isActive: boolean;
    constructor Create(AName: string = ''; Active: boolean = True);
    destructor Destroy; override;
  end;

  TStageDictionary = specialize TDictionary<integer, TStageModel>;

  {TStages}
  TStages = class
  private
    stages: TStageDictionary;
    function getElem(i: integer): TStageModel;
    function aStagesCount: integer;
    function fActiveStage: TStageDictionary.TDictionaryPair;
  public
    constructor Create(stagesCount: integer = 1);
    destructor Destroy; override;
    procedure Add(key: integer; stage: TStageModel);
    property Items[Index: integer]: TStageModel read getElem; default;
    property ActiveStagesCount: integer read aStagesCount;
    property FirstActiveStage: TStageDictionary.TDictionaryPair read fActiveStage;
  end;


implementation

{ TStageModel }

constructor TStageModel.Create(AName: string; Active: boolean);
begin
  Name := AName;
  isActive := Active;
end;

destructor TStageModel.Destroy;
begin
  inherited Destroy;
end;

{ TStages }

function TStages.getElem(i: integer): TStageModel;
begin
  Result := stages[i];
end;

function TStages.aStagesCount: integer;
var
  stage: TStageModel;
begin
  Result := 0;
  for stage in stages.Values do
    if stage.isActive then
      Inc(Result);
end;

function TStages.fActiveStage: TStageDictionary.TDictionaryPair;
var
  KeyValuePair: TStageDictionary.TDictionaryPair;
  i: integer;
begin
  Result := KeyValuePair.Create(0, nil);
  for i := 1 to stages.Count do
  begin
    if stages[i].isActive then
    begin
      Result.Key := i;
      Result.Value := stages[i];
      Break;
    end;
  end;
end;

constructor TStages.Create(stagesCount: integer);
var
  i: integer;
begin
  stages := TStageDictionary.Create;
  for i := 1 to stagesCount do
  begin
    stages.Add(i, TStageModel.Create('', False));
  end;
  stages[1].isActive := True;
end;

destructor TStages.Destroy;
var
  i: integer;
begin
  for i := 1 to stages.Count do
  begin
    stages[i].Destroy;
  end;
  FreeAndNil(stages);
  inherited Destroy;
end;

procedure TStages.Add(key: integer; stage: TStageModel);
begin
  stages.Add(key, stage);
end;

end.
