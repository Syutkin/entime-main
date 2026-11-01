unit ProtocolTableLayout;
{$mode objfpc}{$H+}
interface

uses ProtocolDocumentModel;

type
  TProtocolDocuments = ProtocolDocumentModel.TProtocolDocuments;

procedure FitProtocolWidths(var Widths: TProtocolWidths; PageWidth: single);
function ProtocolPrintViews(const D: TProtocolDocument): TProtocolDocuments;
procedure FreeProtocolDocuments(var Documents: TProtocolDocuments);
function ProtocolColumnCaption(const D: TProtocolDocument; Index: integer): string;

function ProtocolGroupEnd(const D: TProtocolDocument; First: integer): integer;
function ProtocolHasGroupedHeaders(const D: TProtocolDocument): boolean;

implementation

uses SysUtils, Math, ReportTemplateModel;

type
  TIndexes = array of integer;

procedure FitProtocolWidths(var Widths: TProtocolWidths; PageWidth: single);
var
  Total, Scale: single;
  I: integer;
begin
  Total := 0;
  for I := 0 to High(Widths) do Total := Total + Widths[I];
  if Total <= 0 then Exit;
  Scale := PageWidth / Total;
  for I := 0 to High(Widths) do Widths[I] := Widths[I] * Scale;
end;

function ProtocolGroupEnd(const D: TProtocolDocument; First: integer): integer;
begin
  Result := First;
  if D.Columns[First].StageIndex = 0 then Exit;
  while (Result < High(D.Columns)) and (D.Columns[Result + 1].StageIndex =
      D.Columns[First].StageIndex) do Inc(Result);
end;

function ProtocolHasGroupedHeaders(const D: TProtocolDocument): boolean;
var
  I: integer;
begin
  I := 0;
  while I < Length(D.Columns) do
  begin
    if ProtocolGroupEnd(D, I) > I then Exit(True);
    Inc(I);
  end;
  Result := False;
end;

procedure FreeProtocolDocuments(var Documents: TProtocolDocuments);
var
  D: TProtocolDocument;
begin
  for D in Documents do D.Free;
  Documents := nil;
end;

function ProtocolColumnCaption(const D: TProtocolDocument; Index: integer): string;
begin
  Result := D.Columns[Index].Caption;
  if (D.Columns[Index].StageIndex > 0) and (ProtocolGroupEnd(D, Index) = Index) and
    ((Index = 0) or (D.Columns[Index - 1].StageIndex <>
    D.Columns[Index].StageIndex)) then
    Result := D.Columns[Index].GroupCaption;
end;

function ProtocolPrintViews(const D: TProtocolDocument): TProtocolDocuments;
var
  Width, Total, Base, MaxGroup, GW, Used, TextWidth, Allowed: single;
  I, J, N, Start, Finish: integer;
  Groups: array of TIndexes;
  Widths: TProtocolWidths;
  View: TProtocolDocument;
  T: TReportTemplate;
  Parts: TProtocolDocuments;
  Part: TProtocolDocument;
  Scale: single;

  procedure AddIndex(var A: TIndexes; V: integer);
  var
    N: integer;
  begin
    N := Length(A);
    SetLength(A, N + 1);
    A[N] := V;
  end;

  procedure AddView(RowFirst, RowLast, GroupFirst, GroupLast: integer);
  var
    Selected: TIndexes;
    I, J, N: integer;
  begin
    Selected := nil;
    for I := 0 to High(D.Columns) do
    begin
      if D.Columns[I].StageIndex = 0 then AddIndex(Selected, I)
      else
        for J := GroupFirst to GroupLast do
          if (J >= 0) and (J < Length(Groups)) and
            (D.Columns[I].StageIndex = D.Columns[Groups[J][0]].StageIndex) then
          begin
            AddIndex(Selected, I);
            Break;
          end;
    end;
    View := TProtocolDocument.Create;
    try
      View.ContextIdentity := D.ContextIdentity;
      View.SessionGeneration := D.SessionGeneration;
      View.StageSignature := D.StageSignature;
      View.RaceName := D.RaceName;
      View.Heading := D.Heading;
      View.FormedAt := D.FormedAt;
      View.Options := D.Options;
      View.Labels := D.Labels;
      SetLength(View.Columns, Length(Selected));
      for I := 0 to High(Selected) do
      begin
        View.Columns[I] := D.Columns[Selected[I]];
        View.Columns[I].Width := Widths[Selected[I]];
      end;
      SetLength(View.Rows, RowLast - RowFirst + 1);
      for I := RowFirst to RowLast do
      begin
        N := I - RowFirst;
        View.Rows[N].Id := D.Rows[I].Id;
        View.Rows[N].Number := D.Rows[I].Number;
        View.Rows[N].Category := D.Rows[I].Category;
        SetLength(View.Rows[N].Cells, Length(Selected));
        for J := 0 to High(Selected) do View.Rows[N].Cells[J] :=
            D.Rows[I].Cells[Selected[J]];
      end;
      N := Length(Result);
      SetLength(Result, N + 1);
      Result[N] := View;
      View := nil;
    finally
      View.Free;
    end;
  end;

begin
  Result := nil;
  Parts := nil;
  if Length(D.Sections) > 0 then
  begin
    try
      for Part in D.Sections do
      begin
        Parts := ProtocolPrintViews(Part);
        for I := 0 to High(Parts) do
        begin
          View := Parts[I];
          View.RaceName := D.RaceName;
          View.FormedAt := D.FormedAt;
          View.ContextIdentity := D.ContextIdentity;
          View.SessionGeneration := D.SessionGeneration;
          View.StageSignature := D.StageSignature;
          View.Template := D.Template;
          View.SheetName := Part.SheetName;
          N := Length(Result);
          SetLength(Result, N + 1);
          Result[N] := View;
          Parts[I] := nil;
        end;
        FreeProtocolDocuments(Parts);
      end;
    except
      FreeProtocolDocuments(Parts);
      FreeProtocolDocuments(Result);
      raise;
    end;
    Exit;
  end;
  Groups := nil;
  Width := 190;
  if D.Options.Landscape then Width := 277;
  Widths := ProtocolWidths(D);
  Total := 0;
  Base := 0;
  MaxGroup := 0;
  for I := 0 to High(D.Columns) do
  begin
    Total := Total + Widths[I];
    if D.Columns[I].StageIndex = 0 then Base := Base + Widths[I]
    else
    begin
      if (I = 0) or (D.Columns[I].StageIndex <> D.Columns[I - 1].StageIndex) then
        SetLength(Groups, Length(Groups) + 1);
      AddIndex(Groups[High(Groups)], I);
    end;
  end;
  for I := 0 to High(Groups) do
  begin
    GW := 0;
    for J in Groups[I] do GW := GW + Widths[J];
    if GW > MaxGroup then MaxGroup := GW;
  end;
  if D.Options.FitToWidth and (Total > 0) then
  begin
    Scale := Width / Total;
    FitProtocolWidths(Widths, Width);
    try
      AddView(0, High(D.Rows), 0, High(Groups));
      Result[0].Options.TableFontSize :=
        Max(1, Trunc(ProtocolFontSize(D) * Min(1, Scale)));
      Result[0].Template := D.Template;
    except
      FreeProtocolDocuments(Result);
      raise;
    end;
    Exit;
  end;
  if (Total > Width) and (MaxGroup > 0) then
  begin
    TextWidth := 0;
    for I := 0 to High(D.Columns) do
      if (D.Columns[I].StageIndex = 0) and (D.Columns[I].Role = pcrText) then
        TextWidth := TextWidth + Widths[I];
    N := Trunc((Width - (Base - TextWidth) - 40) / MaxGroup);
    if N < 1 then N := 1;
    Allowed := Width - N * MaxGroup - (Base - TextWidth);
    if Allowed > TextWidth then Allowed := TextWidth;
    if (TextWidth = 0) or (Allowed < 30) then
      raise EArgumentException.Create('Protocol column group does not fit on the page');
    for I := 0 to High(D.Columns) do
      if (D.Columns[I].StageIndex = 0) and (D.Columns[I].Role = pcrText) then
        Widths[I] := Widths[I] * Allowed / TextWidth;
    Base := Base - TextWidth + Allowed;
  end;
  try
    if (Total <= Width) or (Length(Groups) = 0) then
    begin
      if Total > Width then raise EArgumentException.Create(
          'Protocol columns do not fit on the page');
      AddView(0, High(D.Rows), 0, High(Groups));
    end
    else
    begin
      Start := 0;
      while Start < Length(Groups) do
      begin
        Finish := Start - 1;
        Used := Base;
        while Finish < High(Groups) do
        begin
          GW := 0;
          for J in Groups[Finish + 1] do GW := GW + Widths[J];
          if (Used + GW > Width + 0.01) and (Finish >= Start) then Break;
          Used := Used + GW;
          Inc(Finish);
        end;
        AddView(0, High(D.Rows), Start, Finish);
        Start := Finish + 1;
      end;
    end;
    for I := 0 to High(Result) do
    begin
      T := D.Template;
      if I <> 0 then T.Header := nil;
      if I <> High(Result) then T.Footer := nil;
      Result[I].Template := T;
      Result[I].Options.ShowHeadings := D.Options.ShowHeadings and (I = 0);
    end;
  except
    FreeProtocolDocuments(Result);
    raise;
  end;
end;

end.
