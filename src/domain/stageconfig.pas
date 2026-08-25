unit StageConfig;

{$mode ObjFPC}{$H+}

interface

const
  DEFAULT_STAGE_COUNT = 1;
  MIN_STAGE_COUNT = 1;
  MAX_SUPPORTED_STAGE_COUNT = 32;

function IsValidStageCount(const Value: integer): boolean;
function NormalizeStageCount(const Value, DefaultValue: integer): integer;

implementation

function IsValidStageCount(const Value: integer): boolean;
begin
  Result := (Value >= MIN_STAGE_COUNT) and
    (Value <= MAX_SUPPORTED_STAGE_COUNT);
end;

function NormalizeStageCount(const Value, DefaultValue: integer): integer;
begin
  if IsValidStageCount(Value) then
    Exit(Value);
  if IsValidStageCount(DefaultValue) then
    Exit(DefaultValue);
  Result := DEFAULT_STAGE_COUNT;
end;

end.
