unit HtmlReportTemplateReader;
{$mode objfpc}{$H+}
interface

uses SysUtils, ReportTemplateModel;

type
  EReportTemplateError = class(Exception);

function ReadHtmlReportTemplate(const Html: string): TReportTemplate;

implementation

uses Classes, SAX, SAX_HTML, i18n;

type
  TTemplateReader = class(THTMLReader)
  public
    procedure Finish;
  end;

  TTemplateParser = class
  private
    FReader: TTemplateReader;
    FTemplate: TReportTemplate;
    FParagraph: TReportParagraph;
    FInside, FMarker, FSpace, FHasBreak: boolean;
    FHead, FTitles: integer;
    FInTable, FInRow, FInCell, FCellHasParagraph: boolean;
    FCellIndex: integer;
    FCells: array[0..1] of TReportParagraph;
    FOutside, FError: string;
    procedure StartElement(Sender: TObject;
      const URI, Local, Raw: SAXString; Attr: TSAXAttributes);
    procedure EndElement(Sender: TObject; const URI, Local, Raw: SAXString);
    procedure Characters(Sender: TObject; const Ch: PSAXChar; Start, Count: integer);
    procedure DoStartElement(Sender: TObject;
      const URI, Local, Raw: SAXString; Attr: TSAXAttributes);
    procedure DoEndElement(Sender: TObject; const URI, Local, Raw: SAXString);
    procedure DoCharacters(Sender: TObject; const Ch: PSAXChar; Start, Count: integer);
    procedure AppendParagraph(const Value: TReportParagraph);
    procedure CloseParagraph;
    procedure FlushOutside;
    procedure Marker;
    procedure Attributes(const Tag: string; Attr: TSAXAttributes);
    procedure Style(const Value: string);
  public
    function Parse(const Html: string): TReportTemplate;
  end;

procedure Fail(const Message: string);
begin
  raise EReportTemplateError.Create(Message);
end;

procedure TTemplateReader.Finish;
begin
  if ScannerContext in [scTag, scComment, scScript] then Fail(rsTemplateIncompleteHtml);
  EnterNewScannerContext(scUnknown);
end;

function UnicodeEntity(const Entity: string): string;
var
  Code: longint;
  S: string;
  W: unicodestring;
begin
  S := Copy(Entity, 2, MaxInt);
  if (S <> '') and (S[1] in ['x', 'X']) then S := '$' + Copy(S, 2, MaxInt);
  if not TryStrToInt(S, Code) or (Code <= 0) or (Code > $10FFFF) or
    ((Code >= $D800) and (Code <= $DFFF)) then Fail(Format(rsTemplateInvalidUnicode, [Entity]));
  if Code < $10000 then W := widechar(Code)
  else
  begin
    Dec(Code, $10000);
    W := widechar($D800 + (Code shr 10)) + widechar($DC00 + (Code and $3FF));
  end;
  Result := UTF8Encode(W);
end;

function AsciiHtml(const Html: string): string;
var
  W: unicodestring;
  I, Code: integer;
begin
  if UTF8Encode(UTF8Decode(Html)) <> Html then Fail(rsTemplateInvalidUtf8);
  if Pos(#0, Html) > 0 then Fail(rsTemplateInvalidUtf8 + ': NUL');
  W := UTF8Decode(Html);
  Result := '';
  I := 1;
  if (Length(W) > 0) and (W[1] = #$FEFF) then Inc(I);
  // SAX_HTML converts its byte buffer using the system codepage. Feed ASCII
  // character references so UTF-8 files behave identically on Windows and Unix.
  while I <= Length(W) do
  begin
    Code := Ord(W[I]);
    if (Code >= $D800) and (Code <= $DBFF) and (I < Length(W)) then
    begin
      Inc(I);
      Code := $10000 + ((Code - $D800) shl 10) + Ord(W[I]) - $DC00;
    end;
    if Code < 128 then Result := Result + Chr(Code)
    else
      Result := Result + '&#' + IntToStr(Code) + ';';
    Inc(I);
  end;
end;

procedure TTemplateParser.Marker;
begin
  if FMarker then Fail(rsTemplateOneMarker);
  FMarker := True;
end;

procedure TTemplateParser.FlushOutside;
var
  S: string;
begin
  S := Trim(FOutside);
  FOutside := '';
  if S = '' then Exit;
  if S = '{{RESULTS}}' then Marker
  else
    Fail(Format(rsTemplateOutsideText, [S]));
end;

procedure TTemplateParser.AppendParagraph(const Value: TReportParagraph);
var
  N: integer;
begin
  if not FMarker then
  begin
    N := Length(FTemplate.Header);
    SetLength(FTemplate.Header, N + 1);
    FTemplate.Header[N] := Value;
  end
  else
  begin
    N := Length(FTemplate.Footer);
    SetLength(FTemplate.Footer, N + 1);
    FTemplate.Footer[N] := Value;
  end;
end;

procedure TTemplateParser.CloseParagraph;
begin
  if not FInside then Exit;
  FInside := False;
  if Pos('{{RESULTS}}', FParagraph.Text) > 0 then
  begin
    if FInTable or (FParagraph.Text <> '{{RESULTS}}') or FHasBreak then
      Fail(rsTemplateSeparateMarker);
    Marker;
    Exit;
  end;
  if FInCell then
  begin
    if FCellHasParagraph then Fail(rsTemplateTable);
    FCells[FCellIndex] := FParagraph;
    FCellHasParagraph := True;
  end
  else
    AppendParagraph(FParagraph);
end;

procedure TTemplateParser.Style(const Value: string);
var
  Items: TStringList;
  I, P, Size: integer;
  Key, V: string;
begin
  Items := TStringList.Create;
  try
    Items.StrictDelimiter := True;
    Items.Delimiter := ';';
    Items.DelimitedText := Value;
    for I := 0 to Items.Count - 1 do
    begin
      V := Trim(Items[I]);
      if V = '' then Continue;
      P := Pos(':', V);
      if P = 0 then Fail(Format(rsTemplateInvalidCss, [V]));
      Key := LowerCase(Trim(Copy(V, 1, P - 1)));
      V := LowerCase(Trim(Copy(V, P + 1, MaxInt)));
      if Key = 'font-size' then
      begin
        if (Copy(V, Length(V) - 1, 2) <> 'pt') or not TryStrToInt(Trim(Copy(V, 1, Length(V) - 2)), Size)
        then Fail(Format(rsTemplateFontSize, [V]));
        if (Size < 6) or (Size > 36) then Fail(Format(rsTemplateFontSize, [V]));
        FParagraph.FontSize := Size;
      end
      else if Key = 'text-align' then
      begin
        if V = 'left' then FParagraph.Alignment := rpaLeft
        else if V = 'right' then FParagraph.Alignment := rpaRight
        else if V = 'center' then FParagraph.Alignment := rpaCenter
        else
          Fail(Format(rsTemplateAlignment, [V]));
      end
      else
        Fail(Format(rsTemplateUnsupportedCss, [Key]));
    end;
  finally
    Items.Free;
  end;
end;

procedure TTemplateParser.Attributes(const Tag: string; Attr: TSAXAttributes);
var
  I: integer;
  Key, V: string;
begin
  if Attr = nil then Exit;
  for I := 0 to Attr.GetLength - 1 do
  begin
    Key := LowerCase(UTF8Encode(Attr.GetLocalName(I)));
    V := UTF8Encode(Attr.GetValue(I));
    if (Tag = 'p') and (Key = 'style') then Style(V)
    else if (Tag = 'meta') and (Key = 'charset') and (LowerCase(V) = 'utf-8') then
    else
      Fail(Format(rsTemplateAttribute, [Tag, Key]));
  end;
  if (Tag = 'meta') and (Attr.GetLength <> 1) then Fail(rsTemplateMeta);
end;

procedure TTemplateParser.DoStartElement(Sender: TObject;
  const URI, Local, Raw: SAXString; Attr: TSAXAttributes);
var
  Tag: string;
begin
  Tag := LowerCase(UTF8Encode(Local));
  if Tag = 'table' then
  begin
    if FInTable or (FHead > 0) then Fail(rsTemplateTable);
    CloseParagraph;
    FlushOutside;
    FInTable := True;
  end
  else if Tag = 'tr' then
  begin
    if not FInTable or FInRow then Fail(rsTemplateTable);
    FlushOutside;
    FInRow := True;
    FCellIndex := 0;
  end
  else if Tag = 'td' then
  begin
    if not FInRow or FInCell or (FCellIndex > 1) then Fail(rsTemplateTable);
    FlushOutside;
    FInCell := True;
    FCellHasParagraph := False;
  end
  else if Tag = 'p' then
  begin
    if FInTable and (not FInCell or FCellHasParagraph) then Fail(rsTemplateTable);
    if FHead > 0 then Fail(Format(rsTemplateHeadElement, ['p']));
    CloseParagraph;
    FlushOutside;
    FParagraph := ReportParagraph('');
    FInside := True;
    FSpace := False;
    FHasBreak := False;
  end
  else if Tag = 'br' then
  begin
    if not FInside then Fail(Format(rsTemplateOutsideElement, ['br', 'p']));
    FParagraph.Text := FParagraph.Text + #10;
    FSpace := False;
    FHasBreak := True;
  end
  else if Tag = 'head' then
  begin
    CloseParagraph;
    FlushOutside;
    Inc(FHead);
  end
  else if Tag = 'title' then
  begin
    if FHead = 0 then Fail(Format(rsTemplateOutsideElement, ['title', 'head']));
    Inc(FTitles);
  end
  else if Tag = 'meta' then
  begin
    if FHead = 0 then Fail(Format(rsTemplateOutsideElement, ['meta', 'head']));
  end
  else if (Tag = 'html') or (Tag = 'body') then
  begin
    CloseParagraph;
    FlushOutside;
  end
  else
    Fail(Format(rsTemplateElement, [Tag]));
  Attributes(Tag, Attr);
end;

procedure TTemplateParser.DoEndElement(Sender: TObject; const URI, Local, Raw: SAXString);
var
  Tag: string;
begin
  Tag := LowerCase(UTF8Encode(Local));
  if Tag = 'td' then
  begin
    CloseParagraph;
    FlushOutside;
    if not FInCell or not FCellHasParagraph then Fail(rsTemplateTable);
    FInCell := False;
    Inc(FCellIndex);
  end
  else if Tag = 'tr' then
  begin
    if not FInRow or FInCell or (FCellIndex <> 2) then Fail(rsTemplateTable);
    FlushOutside;
    FInRow := False;
    AppendParagraph(ReportParagraphPair(FCells[0], FCells[1]));
  end
  else if Tag = 'table' then
  begin
    if not FInTable or FInRow then Fail(rsTemplateTable);
    FlushOutside;
    FInTable := False;
  end
  else if Tag = 'p' then CloseParagraph
  else if Tag = 'head' then
  begin
    if FHead > 0 then Dec(FHead);
  end
  else if Tag = 'title' then
  begin
    if FTitles > 0 then Dec(FTitles);
  end
  else if (Tag = 'body') or (Tag = 'html') then
  begin
    CloseParagraph;
    FlushOutside;
  end
  else if (Tag <> 'br') and (Tag <> 'meta') then Fail(Format(rsTemplateElement, [Tag]));
end;

procedure TTemplateParser.DoCharacters(Sender: TObject;
  const Ch: PSAXChar; Start, Count: integer);
var
  W: SAXString;
  S, Entity: string;
  I: integer;
begin
  if FHead > 0 then Exit;
  SetString(W, Ch + Start, Count);
  S := UTF8Encode(W);
  if FReader.ScannerContext = scEntityReference then
  begin
    Entity := UTF8Encode(FReader.TokenText);
    if (Entity <> '') and (Entity[1] = '#') then S := UnicodeEntity(Entity)
    else if Entity = 'apos' then S := '''';
  end;
  if not FInside then
  begin
    FOutside := FOutside + S;
    Exit;
  end;
  for I := 1 to Length(S) do
    if S[I] in [#9, #10, #13, ' ', #12] then FSpace := True
    else
    begin
      if FSpace and (FParagraph.Text <> '') and
        (FParagraph.Text[Length(FParagraph.Text)] <> #10) then
        FParagraph.Text := FParagraph.Text + ' ';
      FParagraph.Text := FParagraph.Text + S[I];
      FSpace := False;
    end;
end;

procedure TTemplateParser.StartElement(Sender: TObject;
  const URI, Local, Raw: SAXString; Attr: TSAXAttributes);
begin
  if FError <> '' then Exit;
  try
    DoStartElement(Sender, URI, Local, Raw, Attr);
  except
    on E: EReportTemplateError do
    begin
      FError := E.Message;
      FReader.Abort;
    end;
  end;
end;

procedure TTemplateParser.EndElement(Sender: TObject; const URI, Local, Raw: SAXString);
begin
  if FError <> '' then Exit;
  try
    DoEndElement(Sender, URI, Local, Raw);
  except
    on E: EReportTemplateError do
    begin
      FError := E.Message;
      FReader.Abort;
    end;
  end;
end;

procedure TTemplateParser.Characters(Sender: TObject;
  const Ch: PSAXChar; Start, Count: integer);
begin
  if FError <> '' then Exit;
  try
    DoCharacters(Sender, Ch, Start, Count);
  except
    on E: EReportTemplateError do
    begin
      FError := E.Message;
      FReader.Abort;
    end;
  end;
end;

function TTemplateParser.Parse(const Html: string): TReportTemplate;
var
  Stream: TStringStream;
begin
  Stream := TStringStream.Create(AsciiHtml(Html));
  FReader := TTemplateReader.Create;
  try
    FReader.OnStartElement := @StartElement;
    FReader.OnEndElement := @EndElement;
    FReader.OnCharacters := @Characters;
    FReader.OnIgnorableWhitespace := @Characters;
    FReader.ParseStream(Stream);
    if FError <> '' then Fail(FError);
    FReader.Finish;
    if FError <> '' then Fail(FError);
    CloseParagraph;
    FlushOutside;
    if FInTable then Fail(rsTemplateTable);
    if not FMarker then Fail(rsTemplateMissingMarker);
    Result := FTemplate;
  finally
    FReader.Free;
    Stream.Free;
  end;
end;

function ReadHtmlReportTemplate(const Html: string): TReportTemplate;
var
  Parser: TTemplateParser;
begin
  Parser := TTemplateParser.Create;
  try
    Result := Parser.Parse(Html);
  finally
    Parser.Free;
  end;
end;

end.
