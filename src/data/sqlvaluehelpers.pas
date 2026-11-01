unit SqlValueHelpers;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ParticipantStatus;

type
  ESqlIdentifierError = class(EArgumentException);
  EStageIndexError = class(EArgumentOutOfRangeException);

function SqlStatusDbValue(const AStatus: TParticipantStatus): string;
function SqlStatusToken(const AStatus: TParticipantStatus): string;
procedure RequireStageCount(const AStageCount: integer);
procedure RequireStageIndex(const AStageIndex, AStageCount: integer);
procedure RequireSupportedStageIndex(const AStageIndex: integer);
function SqlIdentifier(const AIdentifier: string): string;
function SqlIdentifierCsv(const AIdentifiersCsv: string): string;

implementation

uses
  StageConfig, i18n;

function IsIdentifierStart(const AChar: char): boolean;
begin
  Result := (AChar = '_') or (AChar in ['A'..'Z', 'a'..'z']);
end;

function IsIdentifierPart(const AChar: char): boolean;
begin
  Result := IsIdentifierStart(AChar) or (AChar in ['0'..'9']);
end;

function SqlStatusDbValue(const AStatus: TParticipantStatus): string;
begin
  Result := QuotedStr(ParticipantStatusToDbValue(AStatus));
end;

function SqlStatusToken(const AStatus: TParticipantStatus): string;
begin
  Result := QuotedStr(ParticipantStatusToToken(AStatus));
end;

procedure RequireStageCount(const AStageCount: integer);
begin
  if not IsValidStageCount(AStageCount) then
    raise EStageIndexError.CreateFmt(rsStageCountRangeError,
      [IntToStr(AStageCount), MIN_STAGE_COUNT, MAX_SUPPORTED_STAGE_COUNT]);
end;

procedure RequireStageIndex(const AStageIndex, AStageCount: integer);
begin
  RequireStageCount(AStageCount);
  if (AStageIndex < 1) or (AStageIndex > AStageCount) then
    raise EStageIndexError.CreateFmt(
      'Stage index %d is outside the configured range 1..%d',
      [AStageIndex, AStageCount]);
end;

procedure RequireSupportedStageIndex(const AStageIndex: integer);
begin
  RequireStageIndex(AStageIndex, MAX_SUPPORTED_STAGE_COUNT);
end;

function SqlIdentifier(const AIdentifier: string): string;
var
  I: integer;
begin
  if (AIdentifier = '') or not IsIdentifierStart(AIdentifier[1]) then
    raise ESqlIdentifierError.CreateFmt('Invalid SQL identifier: "%s"',
      [AIdentifier]);
  for I := 2 to Length(AIdentifier) do
    if not IsIdentifierPart(AIdentifier[I]) then
      raise ESqlIdentifierError.CreateFmt('Invalid SQL identifier: "%s"',
        [AIdentifier]);
  Result := '"' + AIdentifier + '"';
end;

function SqlIdentifierCsv(const AIdentifiersCsv: string): string;
var
  Identifiers: TStringList;
  I: integer;
  Identifier: string;
begin
  Result := '';
  Identifiers := TStringList.Create;
  try
    Identifiers.StrictDelimiter := True;
    Identifiers.Delimiter := ',';
    Identifiers.DelimitedText := AIdentifiersCsv;
    if Identifiers.Count = 0 then
      raise ESqlIdentifierError.Create('At least one SQL identifier is required');
    for I := 0 to Identifiers.Count - 1 do
    begin
      Identifier := Trim(Identifiers[I]);
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + SqlIdentifier(Identifier);
    end;
  finally
    Identifiers.Free;
  end;
end;

end.
