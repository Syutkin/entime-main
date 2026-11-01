unit StageFinishReportModel;
{$mode objfpc}{$H+}
interface

uses SysUtils, ProtocolDocumentModel, ReportTemplateModel, StageModel,
  StageFieldNames, ProtocolBalance;

type
  TReportColumn = (rcPlace, rcNumber, rcName, rcTeam, rcResult, rcPenalty, rcGap);
  TReportCells = array[TReportColumn] of string;
  TReportLanguage = ProtocolDocumentModel.TReportLanguage;
  TReportOrientation = ProtocolDocumentModel.TReportOrientation;
  TReportCategories = ProtocolDocumentModel.TReportCategories;

  TStageReportOptions = record
    StageIndex: integer;
    AllCategories, IncludeIncomplete, ShowFooter, ShowPenalty,
    ShowHeadings, ShowHeader: boolean;
    Categories: TReportCategories;
    Orientation: TReportOrientation;
    Language: TReportLanguage;
  end;

  TReportLabels = record
    Title, Competition, Stage, NoCategory, NoResult, InvalidData: string;
    Page, OfPages: string;
    Columns: TReportCells;
  end;

  TStageReportRow = record
    Id, Number: integer;
    Name, Team, Category, GlobalStatus: string;
    Values: array[TStageFieldKind] of string;
    // NULL/empty display alike; explicit zero stays a value.
    Classification: TProtocolBalanceClassification;
    SavedPlace, SortGroup: integer;
    Cells: TReportCells;
  end;
  TStageReportRows = array of TStageReportRow;

  TStageReportSnapshot = class
  private
    FTemplate: TReportTemplate;
    function GetTemplate: TReportTemplate;
    procedure SetTemplate(const Value: TReportTemplate);
  public
    ContextIdentity, SessionGeneration: QWord;
    StageSignature, RaceName, StageName: string;
    FormedAt: TDateTime;
    Options: TStageReportOptions;
    Labels: TReportLabels;
    Rows: TStageReportRows;
    property Template: TReportTemplate read GetTemplate write SetTemplate;
  end;

const
  rlRussian = ProtocolDocumentModel.rlRussian;
  rlEnglish = ProtocolDocumentModel.rlEnglish;
  roPortrait = ProtocolDocumentModel.roPortrait;
  roLandscape = ProtocolDocumentModel.roLandscape;

function StageProtocolDocument(const S: TStageReportSnapshot): TProtocolDocument;
function StageReportHeading(const S: TStageReportSnapshot): string;
function DefaultReportOptions: TStageReportOptions;
function DefaultReportStage(const Stages: TStages; const Current: integer): integer;
function ReportLabels(const Language: TReportLanguage): TReportLabels;
function ReportCategories(const Rows: TStageReportRows): TReportCategories;
function SelectReportRows(const Rows: TStageReportRows;
  const Options: TStageReportOptions): TStageReportRows;
function DisplayReportTime(const Value: string): string;

implementation

uses Classes, ResultFormatting;

function StageReportHeading(const S: TStageReportSnapshot): string;
begin
  Result := S.Labels.Title + ' — ' + S.Labels.Stage + ' ' +
    IntToStr(S.Options.StageIndex);
  if Trim(S.StageName) <> '' then Result := Result + ' — ' + S.StageName;
end;

function StageProtocolDocument(const S: TStageReportSnapshot): TProtocolDocument;
const
  Widths: array[TReportColumn] of single = (13, 11, 57, 36, 25, 23, 25);
var
  C: TReportColumn;
  I, J: integer;
  W: single;
begin
  Result := TProtocolDocument.Create;
  try
    Result.ContextIdentity := S.ContextIdentity;
    Result.SessionGeneration := S.SessionGeneration;
    Result.StageSignature := S.StageSignature;
    Result.RaceName := S.RaceName;
    Result.Heading := StageReportHeading(S);
    Result.FormedAt := S.FormedAt;
    Result.Template := S.Template;
    Result.Options.Landscape := S.Options.Orientation = roLandscape;
    Result.Options.ShowHeadings := S.Options.ShowHeadings;
    Result.Options.ShowHeader := S.Options.ShowHeader;
    Result.Options.ShowFooter := S.Options.ShowFooter;
    Result.Labels.Title := S.Labels.Title;
    Result.Labels.Competition := S.Labels.Competition;
    Result.Labels.NoCategory := S.Labels.NoCategory;
    Result.Labels.Page := S.Labels.Page;
    Result.Labels.OfPages := S.Labels.OfPages;
    for C := Low(C) to High(C) do
    begin
      if (C = rcPenalty) and not S.Options.ShowPenalty then Continue;
      J := Length(Result.Columns);
      SetLength(Result.Columns, J + 1);
      Result.Columns[J].Caption := S.Labels.Columns[C];
      W := Widths[C];
      if S.Options.Orientation = roLandscape then
      begin
        if C = rcName then W := W + 52;
        if C = rcTeam then W := W + 35;
      end;
      if not S.Options.ShowPenalty then
      begin
        if C = rcName then W := W + 14;
        if C = rcTeam then W := W + 9;
      end;
      Result.Columns[J].Width := W;
      if C in [rcNumber, rcPlace] then Result.Columns[J].Role := pcrNumber
      else if C in [rcResult, rcPenalty, rcGap] then Result.Columns[J].Role := pcrTime;
    end;
    SetLength(Result.Rows, Length(S.Rows));
    for I := 0 to High(S.Rows) do
    begin
      Result.Rows[I].Id := S.Rows[I].Id;
      Result.Rows[I].Number := S.Rows[I].Number;
      Result.Rows[I].Category := S.Rows[I].Category;
      SetLength(Result.Rows[I].Cells, Length(Result.Columns));
      J := 0;
      for C := Low(C) to High(C) do
      begin
        if (C = rcPenalty) and not S.Options.ShowPenalty then Continue;
        Result.Rows[I].Cells[J] := S.Rows[I].Cells[C];
        Inc(J);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TStageReportSnapshot.GetTemplate: TReportTemplate;
begin
  Result := CloneReportTemplate(FTemplate);
end;

procedure TStageReportSnapshot.SetTemplate(const Value: TReportTemplate);
begin
  FTemplate := CloneReportTemplate(Value);
end;

function DefaultReportOptions: TStageReportOptions;
begin
  Result := Default(TStageReportOptions);
  Result.StageIndex := 1;
  Result.AllCategories := True;
  Result.IncludeIncomplete := True;
  Result.ShowHeader := True;
  Result.ShowFooter := True;
  Result.ShowPenalty := True;
  Result.ShowHeadings := True;
end;

function DefaultReportStage(const Stages: TStages; const Current: integer): integer;
begin
  Result := 0;
  if (Stages = nil) or (Stages.Count = 0) then Exit;
  if Stages.IsValidIndex(Current) then Exit(Current);
  Result := Stages.FirstActiveIndex;
  if Result = 0 then Result := 1;
end;

function ReportLabels(const Language: TReportLanguage): TReportLabels;
begin
  if Language = rlEnglish then
  begin
    Result.Title := 'Finish protocol';
    Result.Competition := 'Competition';
    Result.Stage := 'Stage';
    Result.NoCategory := 'No category';
    Result.NoResult := 'No result';
    Result.InvalidData := 'Check data';
    Result.Page := 'Page';
    Result.OfPages := 'of';
    Result.Columns[rcPlace] := 'Place';
    Result.Columns[rcNumber] := 'No.';
    Result.Columns[rcName] := 'Participant';
    Result.Columns[rcTeam] := 'Team';
    Result.Columns[rcResult] := 'Result';
    Result.Columns[rcPenalty] := 'Penalty';
    Result.Columns[rcGap] := 'Gap';
  end
  else
  begin
    Result.Title := 'Финишный протокол';
    Result.Competition := 'Соревнование';
    Result.Stage := 'СУ';
    Result.NoCategory := 'Без категории';
    Result.NoResult := 'Нет результата';
    Result.InvalidData := 'Проверьте данные';
    Result.Page := 'Страница';
    Result.OfPages := 'из';
    Result.Columns[rcPlace] := 'Место';
    Result.Columns[rcNumber] := '№';
    Result.Columns[rcName] := 'Участник';
    Result.Columns[rcTeam] := 'Команда';
    Result.Columns[rcResult] := 'Результат';
    Result.Columns[rcPenalty] := 'Штраф';
    Result.Columns[rcGap] := 'Отставание';
  end;
end;

function CategoryKey(const S: string): string;
begin
  if Trim(S) = '' then Result := ''
  else
    Result := S;
end;

function CompareCategory(const A, B: string): integer;
begin
  if (A = '') and (B <> '') then Exit(1);
  if (B = '') and (A <> '') then Exit(-1);
  Result := CompareStr(A, B);
  // Case-sensitive UTF-8 byte ordering, independent of locale.
end;

function DisplayReportTime(const Value: string): string;
var
  S, Sign: string;
begin
  S := Trim(Value);
  if S = '' then Exit('—');
  Sign := '';
  if S[1] in ['+', '-'] then
  begin
    Sign := S[1];
    Delete(S, 1, 1);
  end;
  Result := Sign + HideLeadingZeroHour(S);
end;

function CompareRows(const A, B: TStageReportRow): integer;
begin
  Result := CompareCategory(A.Category, B.Category);
  if Result <> 0 then Exit;
  Result := A.SortGroup - B.SortGroup;
  if Result <> 0 then Exit;
  if A.SortGroup = 0 then
  begin
    Result := A.SavedPlace - B.SavedPlace;
    if Result <> 0 then Exit;
  end;
  if A.Number < B.Number then Exit(-1);
  if A.Number > B.Number then Exit(1);
  if A.Id < B.Id then Exit(-1);
  if A.Id > B.Id then Exit(1);
  Result := 0;
end;

procedure SortRows(var Rows: TStageReportRows);

  procedure Sort(L, R: integer);
  var
    I, J: integer;
    P, T: TStageReportRow;
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
    if L < J then Sort(L, J);
    if I < R then Sort(I, R);
  end;

begin
  if Length(Rows) > 1 then Sort(0, High(Rows));
end;

function ReportCategories(const Rows: TStageReportRows): TReportCategories;
var
  CopyRows: TStageReportRows;
  I, N: integer;
  S: string;
begin
  Result := nil;
  CopyRows := Copy(Rows);
  for I := 0 to High(CopyRows) do CopyRows[I].Category :=
      CategoryKey(CopyRows[I].Category);
  SortRows(CopyRows);
  for I := 0 to High(CopyRows) do
  begin
    S := CopyRows[I].Category;
    N := Length(Result);
    if (N = 0) or (Result[N - 1] <> S) then
    begin
      SetLength(Result, N + 1);
      Result[N] := S;
    end;
  end;
end;

function Selected(const Category: string; const O: TStageReportOptions): boolean;
var
  S: string;
begin
  if O.AllCategories then Exit(True);
  for S in O.Categories do if CategoryKey(S) = Category then Exit(True);
  Result := False;
end;

function SelectReportRows(const Rows: TStageReportRows;
  const Options: TStageReportOptions): TStageReportRows;
var
  Row: TStageReportRow;
  Input: TProtocolBalanceStageInput;
  L: TReportLabels;
  C: TReportColumn;
  N, I: integer;
begin
  Result := nil;
  L := ReportLabels(Options.Language);
  SetLength(Result, Length(Rows));
  N := 0;
  for I := 0 to High(Rows) do
  begin
    Row := Rows[I];
    Row.Category := CategoryKey(Row.Category);
    if not Selected(Row.Category, Options) then Continue;
    Input.StartTime := Row.Values[sfkStartTime];
    Input.FinishTime := Row.Values[sfkFinishTime];
    Input.ResultValue := Row.Values[sfkResult];
    Input.StageStatusValue := Row.Values[sfkStatus];
    Input.GlobalStatusValue := Row.GlobalStatus;
    Row.Classification := ClassifyProtocolBalance(Input);
    if (Row.Classification.Group = pbgUnresolved) and not Options.IncludeIncomplete then
      Continue;
    for C := Low(C) to High(C) do Row.Cells[C] := '—';
    Row.Cells[rcNumber] := IntToStr(Row.Number);
    Row.Cells[rcName] := Row.Name;
    if Row.Team <> '' then Row.Cells[rcTeam] := Row.Team;
    Row.Cells[rcPenalty] := DisplayReportTime(Row.Values[sfkPenalty]);
    Row.SavedPlace := 0;
    case Row.Classification.Group of
      pbgWithResult: begin
        Row.Cells[rcResult] := DisplayReportTime(Row.Values[sfkResult]);
        Row.Cells[rcGap] := DisplayReportTime(Row.Values[sfkDiffLeader]);
        if TryStrToInt(Row.Values[sfkPlace], Row.SavedPlace) and
          (Row.SavedPlace > 0) then
        begin
          Row.SortGroup := 0;
          Row.Cells[rcPlace] := IntToStr(Row.SavedPlace);
        end
        else
        begin
          Row.SavedPlace := 0;
          Row.SortGroup := 1;
        end;
      end;
      pbgDNS: begin
        Row.SortGroup := 2;
        Row.Cells[rcResult] := 'DNS';
      end;
      pbgDNF: begin
        Row.SortGroup := 3;
        Row.Cells[rcResult] := 'DNF';
      end;
      pbgDSQ: begin
        Row.SortGroup := 4;
        Row.Cells[rcResult] := 'DSQ';
      end;
      pbgUnresolved: begin
        Row.SortGroup := 5;
        if Row.Classification.Reason in [pbrUnknownStageStatus,
          pbrMissingOrInvalidResult, pbrFinishWithoutStart] then
          Row.Cells[rcResult] := L.InvalidData
        else
          Row.Cells[rcResult] := L.NoResult;
      end;
    end;
    Result[N] := Row;
    Inc(N);
  end;
  SetLength(Result, N);
  SortRows(Result);
end;

end.
