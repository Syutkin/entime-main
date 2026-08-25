unit StageFieldNames;

{$mode ObjFPC}{$H+}

interface

type
  TStageFieldKind = (
    sfkUnknown,
    sfkStartTime,
    sfkCorrection,
    sfkFinishTime,
    sfkPenalty,
    sfkResult,
    sfkDiffLeader,
    sfkPlace,
    sfkStatus
  );

function StageFieldPrefix(const AKind: TStageFieldKind): string;
function TryParseStageFieldName(const AFieldName: string;
  out AKind: TStageFieldKind; out AStageIndex: integer): boolean;
function TryGetStageIndexFromFieldName(const AFieldName: string;
  out AStageIndex: integer): boolean;

implementation

uses
  SysUtils, StrUtils, StageConfig;

function StageFieldPrefix(const AKind: TStageFieldKind): string;
begin
  case AKind of
    sfkStartTime: Result := 'starttime';
    sfkCorrection: Result := 'correction';
    sfkFinishTime: Result := 'finishtime';
    sfkPenalty: Result := 'penalty';
    sfkResult: Result := 'result';
    sfkDiffLeader: Result := 'diffleader';
    sfkPlace: Result := 'place';
    sfkStatus: Result := 'status';
    else Result := '';
  end;
end;

function TryParseStageFieldName(const AFieldName: string;
  out AKind: TStageFieldKind; out AStageIndex: integer): boolean;
var
  Kind: TStageFieldKind;
  Prefix, Suffix: string;
begin
  AKind := sfkUnknown;
  AStageIndex := 0;
  for Kind := Succ(sfkUnknown) to High(TStageFieldKind) do
  begin
    Prefix := StageFieldPrefix(Kind);
    if not StartsText(Prefix, AFieldName) then
      Continue;
    Suffix := Copy(AFieldName, Length(Prefix) + 1, MaxInt);
    if TryStrToInt(Suffix, AStageIndex) and
      IsValidStageCount(AStageIndex) and
      (Suffix = IntToStr(AStageIndex)) then
    begin
      AKind := Kind;
      Exit(True);
    end;
    AStageIndex := 0;
  end;
  Result := False;
end;

function TryGetStageIndexFromFieldName(const AFieldName: string;
  out AStageIndex: integer): boolean;
var
  Kind: TStageFieldKind;
begin
  Result := TryParseStageFieldName(AFieldName, Kind, AStageIndex);
end;

end.
