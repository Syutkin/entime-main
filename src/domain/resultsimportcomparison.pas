unit ResultsImportComparison;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses SysUtils, Contnrs;

type
  TImportField = (ifStart, ifCorrection, ifFinish, ifPenalty, ifStatus);
  TImportFields = set of TImportField;
  TImportChangeKind = (ickSame, ickFill, ickReplace, ickClear);

  TImportValue = record
    IsNull: boolean;
    Text: string;
    class function Null: TImportValue; static;
    class function Value(const AText: string): TImportValue; static;
    function Empty(const AField: TImportField): boolean;
    function Equivalent(const AOther: TImportValue; const AField: TImportField): boolean;
  end;
  TImportValues = array[TImportField] of TImportValue;

  TImportParticipant = class
  private
    FFields, FSelected: TImportFields;
    FCreateSelected: boolean;
  public
    Id, Number, SourceRow: integer;
    Name: string;
    Current, Proposed: TImportValues;
    procedure AddField(const AField: TImportField;
      const ACurrent, AProposed: TImportValue);
    function Kind(const AField: TImportField): TImportChangeKind;
    procedure Select(const AField: TImportField; const ASelected: boolean);
    procedure ConfirmCreation(const ASelected: boolean);
    property Fields: TImportFields read FFields;
    property Selected: TImportFields read FSelected;
    property CreateSelected: boolean read FCreateSelected;
  end;

  TResultsImportComparison = class
  private
    FParticipants: TFPObjectList;
    function GetCount: integer;
    function GetItem(const AIndex: integer): TImportParticipant;
  public
    StageIndex: integer;
    SessionGeneration: QWord;
    ContextIdentity: QWord;
    StageSignature: string;
    constructor Create;
    destructor Destroy; override;
    function Add(const AId, ANumber, ASourceRow: integer;
      const AName: string): TImportParticipant;
    procedure SelectAll;
    procedure ClearSelection;
    procedure RestoreSelection(const APrevious: TResultsImportComparison);
    function SelectedFieldCount: integer;
    function CreationCount: integer;
    function SelectedParticipantCount: integer;
    function ChangeCount(const AKind: TImportChangeKind): integer;
    function HasSelection: boolean;
    property Count: integer read GetCount;
    property Items[const AIndex: integer]: TImportParticipant read GetItem; default;
  end;

implementation

uses Validators, ParticipantStatus;

function ValueKey(const AValue: TImportValue; const AField: TImportField): string;
var
  Text: string;
  Number: int64;
  Status: TParticipantStatus;
begin
  if AValue.Empty(AField) then Exit('null');
  Text := Trim(AValue.Text);
  case AField of
    ifStart, ifFinish:
      if TryNormalizeTime(Text, Result) then
      begin
        if Length(Result) = 5 then Result := Result + ':00';
        if Length(Result) = 8 then Result := Result + '.000';
        Exit('time:' + Result);
      end;
    ifPenalty:
      if TryNormalizeDuration(Text, Result) or TryNormalizeTime(Text, Result) then
      begin
        if Length(Result) = 5 then Result := Result + ':00';
        if Length(Result) = 8 then Result := Result + '.000';
        Exit('duration:' + Result);
      end;
    ifCorrection:
      if TryStrToInt64(Text, Number) then Exit('integer:' + IntToStr(Number));
    ifStatus:
      if TryParseParticipantStatus(Text, Status) then
        Exit('status:' + ParticipantStatusToDbValue(Status));
  end;
  Result := 'raw:' + AValue.Text;
end;

class function TImportValue.Null: TImportValue;
begin
  Result := Default(TImportValue);
  Result.IsNull := True;
end;

class function TImportValue.Value(const AText: string): TImportValue;
begin
  Result.IsNull := False;
  Result.Text := AText;
end;

function TImportValue.Empty(const AField: TImportField): boolean;
begin
  Result := IsNull or ((AField <> ifCorrection) and (Trim(Text) = ''));
end;

function TImportValue.Equivalent(const AOther: TImportValue;
  const AField: TImportField): boolean;
begin
  Result := ValueKey(Self, AField) = ValueKey(AOther, AField);
end;

procedure TImportParticipant.AddField(const AField: TImportField;
  const ACurrent, AProposed: TImportValue);
begin
  Include(FFields, AField);
  Current[AField] := ACurrent;
  Proposed[AField] := AProposed;
  if (Id > 0) and (Kind(AField) = ickFill) then Include(FSelected, AField);
end;

function TImportParticipant.Kind(const AField: TImportField): TImportChangeKind;
begin
  if not (AField in FFields) or Current[AField].Equivalent(Proposed[AField], AField) then
    Exit(ickSame);
  if Proposed[AField].Empty(AField) then Exit(ickClear);
  if Current[AField].Empty(AField) then Exit(ickFill);
  Result := ickReplace;
end;

procedure TImportParticipant.Select(const AField: TImportField;
  const ASelected: boolean);
begin
  if ASelected and ((Id > 0) or FCreateSelected) and (AField in FFields) and
    (Kind(AField) <> ickSame) then
    Include(FSelected, AField)
  else
    Exclude(FSelected, AField);
end;

procedure TImportParticipant.ConfirmCreation(const ASelected: boolean);
var
  Field: TImportField;
begin
  if Id > 0 then Exit;
  if ASelected and not FCreateSelected then
    for Field in FFields do
      if Kind(Field) = ickFill then Include(FSelected, Field);
  FCreateSelected := ASelected;
  if not ASelected then FSelected := [];
end;

constructor TResultsImportComparison.Create;
begin
  inherited Create;
  FParticipants := TFPObjectList.Create(True);
end;

destructor TResultsImportComparison.Destroy;
begin
  FParticipants.Free;
  inherited Destroy;
end;

function TResultsImportComparison.GetCount: integer;
begin
  Result := FParticipants.Count;
end;

function TResultsImportComparison.GetItem(const AIndex: integer): TImportParticipant;
begin
  Result := TImportParticipant(FParticipants[AIndex]);
end;

function TResultsImportComparison.Add(const AId, ANumber, ASourceRow: integer;
  const AName: string): TImportParticipant;
begin
  Result := TImportParticipant.Create;
  Result.Id := AId;
  Result.Number := ANumber;
  Result.SourceRow := ASourceRow;
  Result.Name := AName;
  FParticipants.Add(Result);
end;

procedure TResultsImportComparison.SelectAll;
var
  I: integer;
  Field: TImportField;
begin
  for I := 0 to Count - 1 do
    for Field in Items[I].Fields do Items[I].Select(Field, True);
end;

procedure TResultsImportComparison.ClearSelection;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    Items[I].FSelected := [];
    Items[I].FCreateSelected := False;
  end;
end;

procedure TResultsImportComparison.RestoreSelection(
  const APrevious: TResultsImportComparison);
var
  I, J: integer;
  Field: TImportField;
  P, Old: TImportParticipant;
begin
  ClearSelection;
  if (APrevious = nil) or (APrevious.StageIndex <> StageIndex) or
    (APrevious.ContextIdentity <> ContextIdentity) or
    (APrevious.SessionGeneration <> SessionGeneration) then Exit;
  for I := 0 to Count - 1 do
  begin
    P := Items[I];
    for J := 0 to APrevious.Count - 1 do
    begin
      Old := APrevious[J];
      if (P.Id <> Old.Id) or (P.Number <> Old.Number) then Continue;
      P.FCreateSelected := Old.CreateSelected;
      for Field in P.Fields * Old.Fields do
        if (Field in Old.Selected) and P.Current[Field].Equivalent(
          Old.Current[Field], Field) and P.Proposed[Field].Equivalent(
          Old.Proposed[Field], Field) then
          P.Select(Field, True);
      Break;
    end;
  end;
end;

function TResultsImportComparison.SelectedFieldCount: integer;
var
  I: integer;
  Field: TImportField;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    for Field in Items[I].Selected do Inc(Result);
end;

function TResultsImportComparison.CreationCount: integer;
var
  I: integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do if Items[I].CreateSelected then Inc(Result);
end;

function TResultsImportComparison.SelectedParticipantCount: integer;
var
  I: integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    if Items[I].CreateSelected or (Items[I].Selected <> []) then Inc(Result);
end;

function TResultsImportComparison.ChangeCount(const AKind: TImportChangeKind): integer;
var
  I: integer;
  Field: TImportField;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    for Field in Items[I].Fields do if Items[I].Kind(Field) = AKind then Inc(Result);
end;

function TResultsImportComparison.HasSelection: boolean;
begin
  Result := (SelectedFieldCount > 0) or (CreationCount > 0);
end;

end.
