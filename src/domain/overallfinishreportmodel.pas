unit OverallFinishReportModel;
{$mode objfpc}{$H+}
interface

uses ProtocolDocumentModel, StageFinishReportModel;

type
  TOverallStageInfo = record
    Index: integer;
    Name: string;
  end;
  TOverallStageInfos = array of TOverallStageInfo;

  TOverallStageValue = record
    ResultValue, Status, Place, Gap, Penalty: string;
  end;
  TOverallStageValues = array of TOverallStageValue;

  TOverallReportRow = record
    Id, Number: integer;
    Name, Team, Category, ResultValue, Place, Gap, CompletedStages: string;
    Stages: TOverallStageValues;
  end;
  TOverallReportRows = array of TOverallReportRow;

  TOverallReportOptions = record
    Display: TStageReportOptions;
    Detailed, StagePlaces, StageGaps, StagePenalties, FitToWidth: boolean;
  end;

function DefaultOverallReportOptions: TOverallReportOptions;
function PrepareOverallProtocol(const Rows: TOverallReportRows;
  const Stages: TOverallStageInfos;
  const Options: TOverallReportOptions): TProtocolDocument;
function OverallCategories(const Rows: TOverallReportRows): TReportCategories;

implementation

uses SysUtils, Classes, ParticipantStatus;

function DefaultOverallReportOptions: TOverallReportOptions;
begin
  Result := Default(TOverallReportOptions);
  Result.Display := DefaultReportOptions;
  Result.Detailed := True;
end;

function CategoryKey(const S: string): string;
begin
  if Trim(S) = '' then Result := ''
  else
    Result := S;
end;

function OverallCategories(const Rows: TOverallReportRows): TReportCategories;
var
  L: TStringList;
  R: TOverallReportRow;
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
    for R in Rows do if CategoryKey(R.Category) = '' then Empty := True
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

function PlaceOf(const R: TOverallReportRow): integer;
begin
  if not TryStrToInt(R.Place, Result) or (Result < 1) then Result := 0;
end;

function GroupOf(const R: TOverallReportRow): integer;
begin
  if PlaceOf(R) > 0 then Exit(0);
  case UpperCase(Trim(R.ResultValue)) of
    'DNS': Result := 2;
    'DNF': Result := 3;
    'DSQ': Result := 4;
    '': Result := 5;
    else
      Result := 1;
  end;
end;

function CompareRows(const A, B: TOverallReportRow): integer;
var
  CA, CB: string;
  CountA, CountB: integer;
  HasA, HasB: boolean;
begin
  CA := CategoryKey(A.Category);
  CB := CategoryKey(B.Category);
  if (CA = '') and (CB <> '') then Exit(1);
  if (CB = '') and (CA <> '') then Exit(-1);
  Result := CompareStr(CA, CB);
  if Result <> 0 then Exit;
  Result := GroupOf(A) - GroupOf(B);
  if Result <> 0 then Exit;
  if GroupOf(A) = 0 then
  begin
    Result := PlaceOf(A) - PlaceOf(B);
    if Result <> 0 then Exit;
  end;
  if GroupOf(A) = 1 then
  begin
    HasA := TryStrToInt(A.CompletedStages, CountA);
    HasB := TryStrToInt(B.CompletedStages, CountB);
    if HasA and not HasB then Exit(-1);
    if HasB and not HasA then Exit(1);
    if HasA and HasB then
    begin
      if CountA > CountB then Exit(-1);
      if CountA < CountB then Exit(1);
      // Saved HH:MM:SS.zzz totals use the same ordering as SQLite standings.
      Result := CompareStr(A.ResultValue, B.ResultValue);
      if Result <> 0 then Exit;
    end;
  end;
  if A.Number < B.Number then Exit(-1);
  if A.Number > B.Number then Exit(1);
  if A.Id < B.Id then Exit(-1);
  if A.Id > B.Id then Exit(1);
  Result := 0;
end;

procedure Sort(var Rows: TOverallReportRows; L, R: integer);
var
  I, J: integer;
  P, T: TOverallReportRow;
begin
  I := L;
  J := R;
  P := Rows[L + (R - L) div 2];
  repeat
    while CompareRows(Rows[I], P) < 0 do Inc(I);
    while CompareRows(Rows[J], P) > 0 do Dec(J);
    if I <= J then
    begin
      T := Rows[I];
      Rows[I] := Rows[J];
      Rows[J] := T;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if L < J then Sort(Rows, L, J);
  if I < R then Sort(Rows, I, R);
end;

function Selected(const Category: string; const O: TStageReportOptions): boolean;
var
  S: string;
begin
  if O.AllCategories then Exit(True);
  for S in O.Categories do if CategoryKey(S) = Category then Exit(True);
  Result := False;
end;

function DisplayValue(const S: string): string;
begin
  if Trim(S) = '' then Result := '—'
  else
    Result := S;
end;

function PrepareOverallProtocol(const Rows: TOverallReportRows;
  const Stages: TOverallStageInfos;
  const Options: TOverallReportOptions): TProtocolDocument;
var
  L: TReportLabels;
  Sorted: TOverallReportRows;
  I, J, N, K: integer;
  TotalCaption: string;
  C: TReportColumn;
  V: TOverallStageValue;
  Status: TParticipantStatus;

  procedure AddColumn(const Caption, GroupCaption: string; Stage: integer;
    Role: TProtocolColumnRole; Width: single);
  var
    X: integer;
  begin
    X := Length(Result.Columns);
    SetLength(Result.Columns, X + 1);
    Result.Columns[X].Caption := Caption;
    Result.Columns[X].GroupCaption := GroupCaption;
    Result.Columns[X].StageIndex := Stage;
    Result.Columns[X].Role := Role;
    Result.Columns[X].Width := Width;
  end;

  procedure Cell(const Text: string);
  begin
    Result.Rows[N].Cells[K] := Text;
    Inc(K);
  end;

  procedure StageColumn(const Info: TOverallStageInfo; Kind: TReportColumn);
  var
    Caption: string;
    Role: TProtocolColumnRole;
    W: single;
  begin
    Caption := Trim(Info.Name);
    if Caption = '' then Caption := L.Stage + ' ' + IntToStr(Info.Index);
    Role := pcrTime;
    W := 22;
    if Kind = rcPlace then
    begin
      Role := pcrNumber;
      W := 13;
    end;
    AddColumn(L.Columns[Kind], Caption, Info.Index, Role, W);
  end;

begin
  Result := TProtocolDocument.Create;
  try
    L := ReportLabels(Options.Display.Language);
    Result.Heading := 'Общий финишный протокол';
    if Options.Display.Language = rlEnglish then
      Result.Heading := 'Overall finish protocol';
    Result.Labels.Title := Result.Heading;
    Result.Labels.Competition := L.Competition;
    Result.Labels.NoCategory := L.NoCategory;
    Result.Labels.Page := L.Page;
    Result.Labels.OfPages := L.OfPages;
    Result.Options.Landscape := Options.Display.Orientation = roLandscape;
    Result.Options.ShowHeader := Options.Display.ShowHeader;
    Result.Options.ShowHeadings := Options.Display.ShowHeadings;
    Result.Options.ShowFooter := Options.Display.ShowFooter;
    Result.Options.FitToWidth := Options.FitToWidth;
    AddColumn(L.Columns[rcPlace], '', 0, pcrNumber, 13);
    AddColumn(L.Columns[rcNumber], '', 0, pcrNumber, 10);
    AddColumn(L.Columns[rcName], '', 0, pcrText, 40);
    AddColumn(L.Columns[rcTeam], '', 0, pcrText, 30);
    if Options.Detailed then for I := 0 to High(Stages) do
      begin
        StageColumn(Stages[I], rcResult);
        if Options.StagePlaces then StageColumn(Stages[I], rcPlace);
        if Options.StageGaps then StageColumn(Stages[I], rcGap);
        if Options.StagePenalties then StageColumn(Stages[I], rcPenalty);
      end;
    TotalCaption := L.Columns[rcResult];
    if Options.Detailed then
    begin
      TotalCaption := 'Итог';
      if Options.Display.Language = rlEnglish then TotalCaption := 'Total';
    end;
    AddColumn(TotalCaption, '', 0, pcrTime, 25);
    AddColumn(L.Columns[rcGap], '', 0, pcrTime, 25);
    Sorted := Copy(Rows);
    if Length(Sorted) > 1 then Sort(Sorted, 0, High(Sorted));
    SetLength(Result.Rows, Length(Sorted));
    N := 0;
    for I := 0 to High(Sorted) do
    begin
      if not Selected(CategoryKey(Sorted[I].Category), Options.Display) then Continue;
      if (Trim(Sorted[I].ResultValue) = '') and not
        Options.Display.IncludeIncomplete then
        Continue;
      Result.Rows[N].Id := Sorted[I].Id;
      Result.Rows[N].Number := Sorted[I].Number;
      Result.Rows[N].Category := CategoryKey(Sorted[I].Category);
      SetLength(Result.Rows[N].Cells, Length(Result.Columns));
      K := 0;
      Cell(DisplayValue(Sorted[I].Place));
      Cell(IntToStr(Sorted[I].Number));
      Cell(Sorted[I].Name);
      Cell(DisplayValue(Sorted[I].Team));
      if Options.Detailed then for J := 0 to High(Stages) do
        begin
          V := Default(TOverallStageValue);
          if J < Length(Sorted[I].Stages) then V := Sorted[I].Stages[J];
          if Trim(V.Status) <> '' then
          begin
            if TryParseParticipantStatus(V.Status, Status) then
              Cell(ParticipantStatusToToken(Status))
            else
              Cell(V.Status);
          end
          else if Trim(V.ResultValue) = '' then Cell(L.NoResult)
          else
            Cell(DisplayReportTime(V.ResultValue));
          if Options.StagePlaces then Cell(DisplayValue(V.Place));
          if Options.StageGaps then Cell(DisplayReportTime(V.Gap));
          if Options.StagePenalties then Cell(DisplayReportTime(V.Penalty));
        end;
      if Trim(Sorted[I].ResultValue) = '' then Cell(L.NoResult)
      else
        Cell(DisplayReportTime(Sorted[I].ResultValue));
      Cell(DisplayReportTime(Sorted[I].Gap));
      Inc(N);
    end;
    SetLength(Result.Rows, N);
  except
    Result.Free;
    raise;
  end;
end;

end.
