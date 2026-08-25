unit StageFieldFactory;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DB;

type
  TStageFieldChangeEvent = procedure(Sender: TField) of object;
  TStageFieldSetTextEvent = procedure(Sender: TField;
    const AText: string) of object;
  TStageFieldGetTextEvent = procedure(Sender: TField; var AText: string;
    DisplayText: boolean) of object;

  TStageFieldHandlers = record
    OnEditableFieldChange: TStageFieldChangeEvent;
    OnCorrectionSetText: TStageFieldSetTextEvent;
    OnPenaltySetText: TStageFieldSetTextEvent;
    OnResultGetText: TStageFieldGetTextEvent;
  end;

  TStageFields = record
    StartTime: TStringField;
    Correction: TLongintField;
    FinishTime: TStringField;
    Penalty: TStringField;
    ResultValue: TStringField;
    DiffLeader: TStringField;
    Place: TLongintField;
    Status: TStringField;
  end;

  { TStageFieldFactory }

  TStageFieldFactory = class
  private
    FCreatedFields: TList;
    FDataSet: TDataSet;
    FHandlers: TStageFieldHandlers;
    procedure ClearCreatedFields;
    function EnsureLongintField(const AFieldName: string): TLongintField;
    function EnsureStringField(const AFieldName: string): TStringField;
    procedure ConfigureDataField(const AField: TField);
  public
    constructor Create(const ADataSet: TDataSet;
      const AHandlers: TStageFieldHandlers);
    destructor Destroy; override;
    function EnsureStageFields(const AStageIndex: integer): TStageFields;
    procedure EnsureStageIndexes(const AStageIndexes: array of integer);
    procedure EnsureStageCount(const AStageCount: integer);
    function CreatedFieldCount: integer;
  end;

implementation

uses
  StageConfig, i18n;

const
  STAGE_STRING_FIELD_SIZE = 255;

constructor TStageFieldFactory.Create(const ADataSet: TDataSet;
  const AHandlers: TStageFieldHandlers);
begin
  inherited Create;
  if ADataSet = nil then
    raise EArgumentNilException.Create('ADataSet');
  FDataSet := ADataSet;
  FHandlers := AHandlers;
  FCreatedFields := TList.Create;
end;

destructor TStageFieldFactory.Destroy;
begin
  FCreatedFields.Free;
  inherited Destroy;
end;

procedure TStageFieldFactory.ClearCreatedFields;
var
  Index: integer;
begin
  for Index := FCreatedFields.Count - 1 downto 0 do
    TObject(FCreatedFields[Index]).Free;
  FCreatedFields.Clear;
end;

procedure TStageFieldFactory.ConfigureDataField(const AField: TField);
begin
  AField.FieldKind := fkData;
  AField.ProviderFlags := [pfInUpdate, pfInWhere];
  AField.ReadOnly := False;
  AField.Required := False;
end;

function TStageFieldFactory.EnsureStringField(
  const AFieldName: string): TStringField;
var
  ExistingField: TField;
begin
  ExistingField := FDataSet.FindField(AFieldName);
  if ExistingField <> nil then
  begin
    if not (ExistingField is TStringField) then
      raise EDatabaseError.CreateFmt('Field "%s" must be a TStringField.',
        [AFieldName]);
    Result := TStringField(ExistingField);
  end
  else
  begin
    Result := TStringField.Create(FDataSet);
    Result.FieldName := AFieldName;
    Result.DataSet := FDataSet;
    FCreatedFields.Add(Result);
  end;
  ConfigureDataField(Result);
  Result.Size := STAGE_STRING_FIELD_SIZE;
end;

function TStageFieldFactory.EnsureLongintField(
  const AFieldName: string): TLongintField;
var
  ExistingField: TField;
begin
  ExistingField := FDataSet.FindField(AFieldName);
  if ExistingField <> nil then
  begin
    if not (ExistingField is TLongintField) then
      raise EDatabaseError.CreateFmt('Field "%s" must be a TLongintField.',
        [AFieldName]);
    Result := TLongintField(ExistingField);
  end
  else
  begin
    Result := TLongintField.Create(FDataSet);
    Result.FieldName := AFieldName;
    Result.DataSet := FDataSet;
    FCreatedFields.Add(Result);
  end;
  ConfigureDataField(Result);
end;

function TStageFieldFactory.EnsureStageFields(
  const AStageIndex: integer): TStageFields;
var
  StageSuffix: string;
begin
  if not IsValidStageCount(AStageIndex) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index must be in the range %d..%d, got %d.',
      [MIN_STAGE_COUNT, MAX_SUPPORTED_STAGE_COUNT, AStageIndex]);

  StageSuffix := IntToStr(AStageIndex);
  Result.StartTime := EnsureStringField('starttime' + StageSuffix);
  Result.Correction := EnsureLongintField('correction' + StageSuffix);
  Result.FinishTime := EnsureStringField('finishtime' + StageSuffix);
  Result.Penalty := EnsureStringField('penalty' + StageSuffix);
  Result.ResultValue := EnsureStringField('result' + StageSuffix);
  Result.DiffLeader := EnsureStringField('diffleader' + StageSuffix);
  Result.Place := EnsureLongintField('place' + StageSuffix);
  Result.Status := EnsureStringField('status' + StageSuffix);

  Result.StartTime.OnChange := FHandlers.OnEditableFieldChange;
  Result.Correction.OnChange := FHandlers.OnEditableFieldChange;
  Result.FinishTime.OnChange := FHandlers.OnEditableFieldChange;
  Result.Penalty.OnChange := FHandlers.OnEditableFieldChange;
  Result.Correction.OnSetText := FHandlers.OnCorrectionSetText;
  Result.Penalty.OnSetText := FHandlers.OnPenaltySetText;
  Result.ResultValue.OnGetText := FHandlers.OnResultGetText;
  Result.DiffLeader.OnGetText := FHandlers.OnResultGetText;
end;

procedure TStageFieldFactory.EnsureStageCount(const AStageCount: integer);
var
  StageIndexes: array of integer;
  StageIndex: integer;
begin
  if not IsValidStageCount(AStageCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      rsStageCountRangeError,
      [IntToStr(AStageCount), MIN_STAGE_COUNT, MAX_SUPPORTED_STAGE_COUNT]);

  SetLength(StageIndexes, AStageCount);
  for StageIndex := 1 to AStageCount do
    StageIndexes[StageIndex - 1] := StageIndex;
  EnsureStageIndexes(StageIndexes);
end;

procedure TStageFieldFactory.EnsureStageIndexes(
  const AStageIndexes: array of integer);
var
  Seen: array[MIN_STAGE_COUNT..MAX_SUPPORTED_STAGE_COUNT] of boolean;
  ArrayIndex, StageIndex: integer;
begin
  if FDataSet.Active then
    raise EDatabaseError.Create(
      'Stage fields can only be configured while the dataset is closed.');
  if Length(AStageIndexes) = 0 then
    raise EArgumentOutOfRangeException.Create(
      'At least one active stage is required.');

  FillChar(Seen, SizeOf(Seen), 0);
  for ArrayIndex := 0 to High(AStageIndexes) do
  begin
    StageIndex := AStageIndexes[ArrayIndex];
    if not IsValidStageCount(StageIndex) then
      raise EArgumentOutOfRangeException.CreateFmt(
        'Stage index must be in the range %d..%d, got %d.',
        [MIN_STAGE_COUNT, MAX_SUPPORTED_STAGE_COUNT, StageIndex]);
    if Seen[StageIndex] then
      raise EArgumentException.CreateFmt(
        'Duplicate stage index: %d.', [StageIndex]);
    Seen[StageIndex] := True;
  end;

  ClearCreatedFields;
  try
    for ArrayIndex := 0 to High(AStageIndexes) do
    begin
      StageIndex := AStageIndexes[ArrayIndex];
      EnsureStageFields(StageIndex);
    end;
  except
    ClearCreatedFields;
    raise;
  end;
end;

function TStageFieldFactory.CreatedFieldCount: integer;
begin
  Result := FCreatedFields.Count;
end;

end.
