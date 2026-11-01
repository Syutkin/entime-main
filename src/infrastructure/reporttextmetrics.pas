unit ReportTextMetrics;
{$mode objfpc}{$H+}
interface

uses Classes, fpreport;

type
  TReportText = class(TFPReportMemo)
  private
    FLineHeight: single;
    procedure RepairWrappedLines(Lines: TStrings; Width: single);
  public
    function LineHeight: single;
    procedure Wrap(const Value: string; Width: single; Dest: TStrings;
      const FontName: string = ''; const FontSize: integer = 8;
      const MarginScale: single = 1);
  end;

implementation

uses StageFinishReportBackend, fpTTF;

procedure TReportText.RepairWrappedLines(Lines: TStrings; Width: single);
var
  I, P: integer;
  Current, Next: string;
  Available: single;
  Face: TFPFontCacheItem;
begin
  Face := gTTFontCache.FindFont(Font.Name);
  Available := Width - TextAlignment.LeftMargin - TextAlignment.RightMargin;
  I := 0;
  while I < Lines.Count do
  begin
    Current := Lines[I];
    Next := '';
    if I + 1 < Lines.Count then Next := Lines[I + 1];
    if (Next <> '') and ((Ord(Next[1]) and $C0) = $80) then
    begin
      P := Length(Current);
      while (P > 0) and ((Ord(Current[P]) and $C0) = $80) do Dec(P);
      Next := Copy(Current, P, MaxInt) + Next;
      SetLength(Current, P - 1);
    end;
    // Moving a UTF-8 fragment also changes the following line's width. Use the
    // same font cache as FPReport to keep whole characters inside the text area.
    while (Current <> '') and (Face.TextWidth(Current, Font.Size) *
        25.4 / gTTFontCache.DPI > Available) do
    begin
      P := Length(Current);
      while (P > 1) and ((Ord(Current[P]) and $C0) = $80) do Dec(P);
      if P = 1 then Break;
      Next := Copy(Current, P, MaxInt) + Next;
      SetLength(Current, P - 1);
    end;
    Lines[I] := Current;
    if I + 1 < Lines.Count then Lines[I + 1] := Next
    else if Next <> '' then Lines.Add(Next);
    Inc(I);
  end;
end;

procedure TReportText.Wrap(const Value: string; Width: single;
  Dest: TStrings; const FontName: string; const FontSize: integer;
  const MarginScale: single);
var
  J: integer;
  Source, Wrapped: TStringList;
  H: single;
begin
  TextAlignment.LeftMargin := MarginScale;
  TextAlignment.RightMargin := MarginScale;
  Layout.Width := Width;
  Layout.Height := 5;
  StretchMode := smActualHeight;
  if FontName = '' then Font.Name := ReportRegularFont
  else
    Font.Name := FontName;
  Font.Size := FontSize;
  WordOverflow := woSplit;
  Options := [moDisableExpressions];
  Source := TStringList.Create;
  Wrapped := TStringList.Create;
  Dest.Clear;
  FLineHeight := 0;
  try
    Source.Text := Value;
    if (Source.Count = 0) or ((Value <> '') and (Value[Length(Value)] = #10)) then
      Source.Add('');
    // FPReport drops empty lines in WrapText. Measure each explicit line using
    // its layout engine and retain empty lines separately.
    for J := 0 to Source.Count - 1 do
    begin
      Text := Source[J];
      if Text = '' then Text := ' ';
      if RTLayout = nil then CreateRTLayout
      else
        RTLayout.Assign(Layout);
      RecalcLayout;
      H := RTLayout.Height;
      if TextLines.Count > 0 then H := H / TextLines.Count;
      if H > FLineHeight then FLineHeight := H;
      if Source[J] = '' then Dest.Add('')
      else
      begin
        Wrapped.Assign(TextLines);
        RepairWrappedLines(Wrapped, Width);
        Dest.AddStrings(Wrapped);
      end;
    end;
  finally
    Wrapped.Free;
    Source.Free;
  end;
end;

function TReportText.LineHeight: single;
begin
  Result := FLineHeight;
end;

end.
