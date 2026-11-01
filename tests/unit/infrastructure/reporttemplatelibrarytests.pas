unit ReportTemplateLibraryTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry;

type
  TReportTemplateLibraryTests = class(TTestCase)
  published
    procedure NativeHtmlReaderKeepsParagraphsAndEntities;
    procedure TitleAndSummaryChildrenFlowAcrossPages;
  end;

implementation

uses SAX, SAX_HTML, fpreport, StageFinishReportBackend;

type
  TCollector = class
    Paragraphs: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure StartElement(Sender: TObject;
      const URI, Local, Raw: SAXString; Attr: TSAXAttributes);
    procedure Characters(Sender: TObject; const Ch: PSAXChar; Start, Count: integer);
  end;

constructor TCollector.Create;
begin
  Paragraphs := TStringList.Create;
end;

destructor TCollector.Destroy;
begin
  Paragraphs.Free;
  inherited;
end;

procedure TCollector.StartElement(Sender: TObject;
  const URI, Local, Raw: SAXString; Attr: TSAXAttributes);
begin
  if Local = 'p' then Paragraphs.Add('');
end;

procedure TCollector.Characters(Sender: TObject; const Ch: PSAXChar; Start, Count: integer);
var
  S: SAXString;
  I: integer;
begin
  SetString(S, Ch + Start, Count);
  I := Paragraphs.Count - 1;
  if I >= 0 then Paragraphs[I] := Paragraphs[I] + UTF8Encode(S);
end;

procedure TReportTemplateLibraryTests.NativeHtmlReaderKeepsParagraphsAndEntities;
var
  Stream: TStringStream;
  Reader: THTMLReader;
  C: TCollector;
begin
  Stream := TStringStream.Create(
    '<p>Шапка &amp; мир<br>строка</p><p>{{RESULTS}}</p><p>Подвал</p>');
  Reader := THTMLReader.Create;
  C := TCollector.Create;
  try
    Reader.OnStartElement := @C.StartElement;
    Reader.OnCharacters := @C.Characters;
    Reader.OnIgnorableWhitespace := @C.Characters;
    Reader.ParseStream(Stream);
    AssertEquals(3, C.Paragraphs.Count);
    AssertEquals('Шапка & мирстрока', C.Paragraphs[0]);
    AssertEquals('{{RESULTS}}', C.Paragraphs[1]);
    AssertEquals('Подвал', C.Paragraphs[2]);
  finally
    C.Free;
    Reader.Free;
    Stream.Free;
  end;
end;

procedure TReportTemplateLibraryTests.TitleAndSummaryChildrenFlowAcrossPages;
var
  D: TPreparedStageReport;
  Page: TFPReportPage;
  Band, Previous: TFPReportCustomBand;
  M: TFPReportMemo;
  I, J, N: integer;
  Text, Token: string;
begin
  D := TPreparedStageReport.Create;
  try
    Page := TFPReportPage.Create(D.Report);
    Page.PageSize.PaperName := 'A4';
    Page.Font.Name := ReportRegularFont;
    for J := 0 to 1 do
    begin
      Previous := nil;
      for I := 1 to 100 do
      begin
        if I = 1 then
        begin
          if J = 0 then
          begin
            Band := TFPReportTitleBand.Create(Page);
            TFPReportTitleBand(Band).KeepTogetherWithChildren := False;
          end
          else
          begin
            Band := TFPReportSummaryBand.Create(Page);
            TFPReportSummaryBand(Band).KeepTogetherWithChildren := False;
          end;
        end
        else
        begin
          Band := TFPReportChildBand.Create(Page);
          Previous.ChildBand := TFPReportChildBand(Band);
        end;
        Band.Layout.Height := 5;
        M := TFPReportMemo.Create(Band);
        M.Layout.Width := 180;
        M.Layout.Height := 5;
        M.Text := 'BLOCK' + IntToStr(J) + 'TOKEN' + Format('%.4d', [I]);
        Previous := Band;
      end;
    end;
    D.Prepare;
    AssertTrue('Long header and signatures span pages', D.PageCount > 2);
    Text := '';
    for I := 0 to D.PageCount - 1 do Text := Text + D.PageText(I);
    for J := 0 to 1 do for I := 1 to 100 do
      begin
        Token := 'BLOCK' + IntToStr(J) + 'TOKEN' + Format('%.4d', [I]);
        N := Pos(Token, Text);
        AssertTrue(Token, N > 0);
        Delete(Text, N, Length(Token));
        AssertEquals(0, Pos(Token, Text));
      end;
  finally
    D.Free;
  end;
end;

initialization
  RegisterTest(TReportTemplateLibraryTests);
end.
