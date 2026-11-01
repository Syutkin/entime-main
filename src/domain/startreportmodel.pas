unit StartReportModel;
{$mode objfpc}{$H+}
interface

uses ProtocolDocumentModel;

type
  TStartReportMode = (srmAllStages, srmSingleStage);
  TStartReportOrder = (sroTime, sroNumber);

  TStartStageInfo = record
    Index: integer;
    Name: string;
    IsActive: boolean;
  end;
  TStartStageInfos = array of TStartStageInfo;
  TStartClockValues = array of string;

  TStartReportRow = record
    Id, Number: integer;
    Name, Team, Category: string;
    Starts: TStartClockValues;
  end;
  TStartReportRows = array of TStartReportRow;

  TStartReportOptions = record
    View: TProtocolViewOptions;
    Mode: TStartReportMode;
    Order: TStartReportOrder;
    SortStageIndex: integer;
    FitToWidth, AllSingleStages, ShowTeam: boolean;
  end;

function DefaultStartReportOptions: TStartReportOptions;
function StartStageCaption(const Info: TStartStageInfo;
  Language: TReportLanguage): string;
function StartReportCategories(const Rows: TStartReportRows): TReportCategories;
function PrepareStartProtocol(const Rows: TStartReportRows;
  const Stages: TStartStageInfos; const Options: TStartReportOptions): TProtocolDocument;

implementation

uses Classes, SysUtils, Generics.Collections;

type
  TCategoryStart = record
    Key: string;
    Kind: integer;
  end;
  TCategoryStarts = specialize TDictionary<string, TCategoryStart>;

function DefaultStartReportOptions: TStartReportOptions;
begin
  Result := Default(TStartReportOptions);
  Result.View := DefaultProtocolViewOptions;
  Result.ShowTeam := True;
end;

function StartStageCaption(const Info: TStartStageInfo;
  Language: TReportLanguage): string;
begin
  Result := Trim(Info.Name);
  if Result <> '' then Exit;
  Result := 'СУ ';
  if Language = rlEnglish then Result := 'Stage ';
  Result := Result + IntToStr(Info.Index);
end;

function CatKey(const S: string): string;
begin
  if Trim(S) = '' then Result := ''
  else
    Result := S;
end;

function StartReportCategories(const Rows: TStartReportRows): TReportCategories;
var
  L: TStringList;
  R: TStartReportRow;
  I, N: integer;
  Empty: boolean;
begin
  Result := nil;
  Empty := False;
  L := TStringList.Create;
  try
    L.CaseSensitive := True;
    L.Sorted := True;
    L.Duplicates := dupIgnore;
    for R in Rows do if CatKey(R.Category) = '' then Empty := True
      else
        L.Add(R.Category);
    N := L.Count;
    SetLength(Result, N + Ord(Empty));
    for I := 0 to N - 1 do Result[I] := L[I];
    if Empty then Result[N] := '';
  finally
    L.Free;
  end;
end;

function ClockValue(const R: TStartReportRow; Slot: integer): string;
begin
  Result := '';
  if (Slot >= 0) and (Slot < Length(R.Starts)) then Result := Trim(R.Starts[Slot]);
end;

function ClockKey(const S: string; out Kind: integer): string;
var
  I: integer;
  Canonical: boolean;
begin
  Result := S;
  Kind := 1;
  if S = '' then
  begin
    Kind := 2;
    Exit;
  end;
  // Normalise only the comparison key; never change or reject saved display text.
  Canonical := (Length(S) = 8) or ((Length(S) >= 10) and (Length(S) <= 12));
  if Canonical then for I := 1 to Length(S) do case I of
        3, 6: Canonical := Canonical and (S[I] = ':');
        9: Canonical := Canonical and (S[I] = '.');
        else
          Canonical := Canonical and (S[I] in ['0'..'9']);
      end;
  if not Canonical then Exit;
  Kind := 0;
  Result := S;
  if Length(Result) = 8 then Result := Result + '.';
  while Length(Result) < 12 do Result := Result + '0';
end;

function CompareRows(const A, B: TStartReportRow; Slot: integer;
  Order: TStartReportOrder; const Categories: TCategoryStarts): integer;
var
  CA, CB, KA, KB: string;
  StartA, StartB: TCategoryStart;
  KindA, KindB: integer;
begin
  CA := CatKey(A.Category);
  CB := CatKey(B.Category);
  if (Order = sroTime) and (CA <> CB) then
  begin
    StartA := Categories[CA];
    StartB := Categories[CB];
    Result := StartA.Kind - StartB.Kind;
    if Result <> 0 then Exit;
    Result := CompareStr(StartA.Key, StartB.Key);
    if Result <> 0 then Exit;
    if CA = '' then Exit(1);
    if CB = '' then Exit(-1);
    Exit(CompareStr(CA, CB));
  end;
  if Order = sroTime then
  begin
    KA := ClockKey(ClockValue(A, Slot), KindA);
    KB := ClockKey(ClockValue(B, Slot), KindB);
    Result := KindA - KindB;
    if Result <> 0 then Exit;
    Result := CompareStr(KA, KB);
    if Result <> 0 then Exit;
  end;
  if A.Number < B.Number then Exit(-1);
  if A.Number > B.Number then Exit(1);
  if A.Id < B.Id then Exit(-1);
  if A.Id > B.Id then Exit(1);
  Result := 0;
end;

procedure Sort(var R: TStartReportRows; L, H, Slot: integer;
  Order: TStartReportOrder; const Categories: TCategoryStarts);
var
  I, J: integer;
  P, T: TStartReportRow;
begin
  I := L;
  J := H;
  P := R[L + (H - L) div 2];
  repeat
    while CompareRows(R[I], P, Slot, Order, Categories) < 0 do Inc(I);
    while CompareRows(R[J], P, Slot, Order, Categories) > 0 do Dec(J);
    if I <= J then
    begin
      T := R[I];
      R[I] := R[J];
      R[J] := T;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if L < J then Sort(R, L, J, Slot, Order, Categories);
  if I < H then Sort(R, I, H, Slot, Order, Categories);
end;

procedure SortStartRows(var Rows: TStartReportRows; Slot: integer;
  Order: TStartReportOrder);
var
  Categories: TCategoryStarts;
  R: TStartReportRow;
  C: string;
  Value, Previous: TCategoryStart;
begin
  Categories := TCategoryStarts.Create;
  try
    for R in Rows do
    begin
      C := CatKey(R.Category);
      Value.Key := ClockKey(ClockValue(R, Slot), Value.Kind);
      if not Categories.TryGetValue(C, Previous) or (Value.Kind < Previous.Kind) or
        ((Value.Kind = Previous.Kind) and (CompareStr(Value.Key, Previous.Key) < 0)) then
        Categories.AddOrSetValue(C, Value);
    end;
    Sort(Rows, 0, High(Rows), Slot, Order, Categories);
  finally
    Categories.Free;
  end;
end;

function Selected(const Category: string; const O: TProtocolViewOptions): boolean;
var
  C: string;
begin
  if O.AllCategories then Exit(True);
  for C in O.Categories do if CatKey(C) = Category then Exit(True);
  Result := False;
end;

function PrepareSeparateStages(const Rows: TStartReportRows;
  const Stages: TStartStageInfos; const Options: TStartReportOptions): TProtocolDocument;
var
  O: TStartReportOptions;
  Info: TStartStageInfo;
  Section: TProtocolDocument;
  N, I, Offset: integer;
begin
  Result := TProtocolDocument.Create;
  try
    O := Options;
    O.AllSingleStages := False;
    for Info in Stages do if Info.IsActive then
      begin
        O.View.StageIndex := Info.Index;
        Section := PrepareStartProtocol(Rows, Stages, O);
        if Length(Section.Rows) = 0 then
        begin
          Section.Free;
          Continue;
        end;
        Section.SheetName := 'СУ ';
        if O.View.Language = rlEnglish then Section.SheetName := 'Stage ';
        Section.SheetName := Section.SheetName + IntToStr(Info.Index);
        N := Length(Result.Sections);
        SetLength(Result.Sections, N + 1);
        Result.Sections[N] := Section;
        if N = 0 then
        begin
          Result.Columns := Copy(Section.Columns);
          Result.Options := Section.Options;
          Result.Labels := Section.Labels;
        end;
        Offset := Length(Result.Rows);
        SetLength(Result.Rows, Offset + Length(Section.Rows));
        for I := 0 to High(Section.Rows) do Result.Rows[Offset + I] := Section.Rows[I];
      end;
    Result.Heading := 'Стартовые протоколы СУ';
    if Options.View.Language = rlEnglish then Result.Heading := 'Stage start protocols';
  except
    Result.Free;
    raise;
  end;
end;

function PrepareStartProtocol(const Rows: TStartReportRows;
  const Stages: TStartStageInfos; const Options: TStartReportOptions): TProtocolDocument;
var
  Visible: array of integer;
  Sorted: TStartReportRows;
  I, J, N, Slot, TimeColumn: integer;
  HasTime: boolean;
  NumberLabel, NameLabel, TeamLabel, StartLabel, Caption, Value: string;
  NameWidth, TeamWidth: single;

  procedure Column(const Text, GroupCaption: string; Stage: integer;
    Role: TProtocolColumnRole; W: single);
  var
    N: integer;
  begin
    N := Length(Result.Columns);
    SetLength(Result.Columns, N + 1);
    Result.Columns[N].Caption := Text;
    Result.Columns[N].GroupCaption := GroupCaption;
    Result.Columns[N].StageIndex := Stage;
    Result.Columns[N].Role := Role;
    Result.Columns[N].Width := W;
  end;

begin
  if (Options.Mode = srmSingleStage) and Options.AllSingleStages then
    Exit(PrepareSeparateStages(Rows, Stages, Options));
  Result := TProtocolDocument.Create;
  try
    Result.Labels := ProtocolLabels(Options.View.Language);
    Result.Labels.Title := 'Общий стартовый протокол';
    if Options.Mode = srmSingleStage then
      Result.Labels.Title := 'Стартовый протокол';
    if Options.View.Language = rlEnglish then
    begin
      Result.Labels.Title := 'Overall start protocol';
      if Options.Mode = srmSingleStage then Result.Labels.Title := 'Start protocol';
    end;
    Result.Heading := Result.Labels.Title;
    Result.Options.Landscape := Options.View.Orientation = roLandscape;
    Result.Options.ShowHeadings := Options.View.ShowHeadings;
    Result.Options.ShowHeader := Options.View.ShowHeader;
    Result.Options.ShowFooter := Options.View.ShowFooter;
    Result.Options.HideCategories := Options.Order = sroNumber;
    Result.Options.FitToWidth := (Options.Mode = srmAllStages) and Options.FitToWidth;
    Visible := nil;
    for I := 0 to High(Stages) do
      if Stages[I].IsActive and ((Options.Mode = srmAllStages) or
        (Stages[I].Index = Options.View.StageIndex)) then
      begin
        N := Length(Visible);
        SetLength(Visible, N + 1);
        Visible[N] := I;
      end;
    if Length(Visible) = 0 then Exit;
    Slot := Visible[0];
    for I in Visible do if Stages[I].Index = Options.SortStageIndex then Slot := I;
    if Options.Mode = srmSingleStage then Slot := Visible[0];
    NumberLabel := '№';
    NameLabel := 'Участник';
    TeamLabel := 'Команда';
    StartLabel := 'Старт';
    if Options.View.Language = rlEnglish then
    begin
      NumberLabel := 'No.';
      NameLabel := 'Participant';
      TeamLabel := 'Team';
      StartLabel := 'Start';
    end;
    NameWidth := 57;
    TeamWidth := 36;
    if Options.Mode = srmSingleStage then
    begin
      NameWidth := 100;
      TeamWidth := 54;
      if Result.Options.Landscape then NameWidth := NameWidth + 87;
    end;
    if not Options.ShowTeam and not Result.Options.FitToWidth then
      NameWidth := NameWidth + TeamWidth;
    Column(NumberLabel, '', 0, pcrNumber, 11);
    Column(NameLabel, '', 0, pcrText, NameWidth);
    if Options.ShowTeam then Column(TeamLabel, '', 0, pcrText, TeamWidth);
    TimeColumn := Length(Result.Columns);
    for I in Visible do
    begin
      Caption := StartStageCaption(Stages[I], Options.View.Language);
      if Options.Mode = srmSingleStage then
      begin
        Result.Heading := Result.Heading + ' — ' + Caption;
        Column(StartLabel, '', 0, pcrTime, 25);
      end
      else
        Column(StartLabel, Caption, Stages[I].Index, pcrTime, 25);
    end;
    Sorted := Copy(Rows);
    if Length(Sorted) > 1 then SortStartRows(Sorted, Slot, Options.Order);
    SetLength(Result.Rows, Length(Sorted));
    N := 0;
    for I := 0 to High(Sorted) do
    begin
      if not Selected(CatKey(Sorted[I].Category), Options.View) then Continue;
      HasTime := False;
      for J in Visible do if ClockValue(Sorted[I], J) <> '' then HasTime := True;
      if not HasTime and not Options.View.IncludeMissing then Continue;
      Result.Rows[N].Id := Sorted[I].Id;
      Result.Rows[N].Number := Sorted[I].Number;
      Result.Rows[N].Category := CatKey(Sorted[I].Category);
      SetLength(Result.Rows[N].Cells, Length(Result.Columns));
      Result.Rows[N].Cells[0] := IntToStr(Sorted[I].Number);
      Result.Rows[N].Cells[1] := Sorted[I].Name;
      if Options.ShowTeam then
      begin
        Value := Sorted[I].Team;
        if Trim(Value) = '' then Value := '—';
        Result.Rows[N].Cells[2] := Value;
      end;
      for J := 0 to High(Visible) do
      begin
        Value := ClockValue(Sorted[I], Visible[J]);
        if Value = '' then Value := '—';
        Result.Rows[N].Cells[TimeColumn + J] := Value;
      end;
      Inc(N);
    end;
    SetLength(Result.Rows, N);
  except
    Result.Free;
    raise;
  end;
end;

end.
