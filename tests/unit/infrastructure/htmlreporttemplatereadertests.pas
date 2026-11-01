unit HtmlReportTemplateReaderTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  THtmlReportTemplateReaderTests = class(TTestCase)
  published
    procedure CenterAlignmentInParagraphsAndBothColumns;
    procedure InvalidColumnRowsAreRejected;
    procedure TwoColumnRowsKeepParagraphStyles;
    procedure FullDocumentAndFragment;
    procedure WhitespaceEntitiesBreaksAndEmptyParagraphs;
    procedure StandaloneMarkerAndOptionalClosingParagraphs;
    procedure InvalidMarkersAndUnsupportedFormatting;
    procedure InvalidEncodingAndNumericEntities;
  end;

implementation

uses SysUtils, ReportTemplateModel, HtmlReportTemplateReader;

procedure THtmlReportTemplateReaderTests.FullDocumentAndFragment;
var
  A, B: TReportTemplate;
  S: string;
begin
  S := '<P STYLE="TEXT-ALIGN: right; FONT-SIZE: 14pt">Шапка</P><p>{{RESULTS}}</p><p>Подпись</p>';
  A := ReadHtmlReportTemplate(S);
  B := ReadHtmlReportTemplate(#239#187#191 +
    '<html><head><meta charset="utf-8"><title>ignored</title></head><body>' +
    S + '</body></html>');
  AssertEquals(1, Length(A.Header));
  AssertEquals(A.Header[0].Text, B.Header[0].Text);
  AssertEquals(14, A.Header[0].FontSize);
  AssertEquals(Ord(rpaRight), Ord(A.Header[0].Alignment));
  AssertEquals('Подпись', A.Footer[0].Text);
  AssertEquals(10, A.Footer[0].FontSize);
end;

procedure THtmlReportTemplateReaderTests.WhitespaceEntitiesBreaksAndEmptyParagraphs;
var
  T: TReportTemplate;
begin
  T := ReadHtmlReportTemplate('<p>  Кубок' + #10 +
    ' города &amp; &lt; &gt; &quot; &apos; &nbsp;&#1046;&#x1F3C1;<br><br/> конец </p><p></p><!--{{RESULTS}}--><p>{{RESULTS}}</p><p>[PageNo] =SUM(A1) {x}</p>');
  AssertEquals('Кубок города & < > " '' ' + #194#160 + 'Ж🏁' +
    #10#10 + 'конец', T.Header[0].Text);
  AssertEquals('', T.Header[1].Text);
  AssertEquals('[PageNo] =SUM(A1) {x}', T.Footer[0].Text);
end;

procedure THtmlReportTemplateReaderTests.StandaloneMarkerAndOptionalClosingParagraphs;
var
  T: TReportTemplate;
begin
  T := ReadHtmlReportTemplate('<p>Один<p>Два</p> {{RESULTS}} <p>Три');
  AssertEquals(2, Length(T.Header));
  AssertEquals('Один', T.Header[0].Text);
  AssertEquals('Два', T.Header[1].Text);
  AssertEquals('Три', T.Footer[0].Text);
  T := ReadHtmlReportTemplate('{{RESULTS}}');
  AssertEquals(0, Length(T.Header));
  AssertEquals(0, Length(T.Footer));
end;

procedure Reject(const S, Part: string);
begin
  try
    ReadHtmlReportTemplate(S);
  except
    on E: EReportTemplateError do
    begin
      if Pos(Part, E.Message) = 0 then
        raise Exception.Create('Expected ' + Part + ' in ' + E.Message);
      Exit;
    end;
  end;
  raise Exception.Create('Accepted invalid HTML: ' + S);
end;

procedure THtmlReportTemplateReaderTests.InvalidMarkersAndUnsupportedFormatting;
begin
  Reject('<p>No marker</p>', '{{RESULTS}}');
  Reject('<p>{{RESULTS}}{{RESULTS}}</p>', '{{RESULTS}}');
  Reject('<p>{{RESULTS}}</p>{{RESULTS}}', '{{RESULTS}}');
  Reject('<p>text {{RESULTS}}</p>', '{{RESULTS}}');
  Reject('<p>{{RESULTS}}<br></p>', '{{RESULTS}}');
  Reject('text<p>{{RESULTS}}</p>', 'text');
  Reject('<p style="font-size:37pt">X</p>{{RESULTS}}', 'font-size');
  Reject('<p style="font-size:10px">X</p>{{RESULTS}}', 'font-size');
  Reject('<p style="text-align:justify">X</p>{{RESULTS}}', 'text-align');
  Reject('<p style="color:red">X</p>{{RESULTS}}', 'color');
  Reject('<p align="right">X</p>{{RESULTS}}', 'align');
  Reject('<img src="x"><p>{{RESULTS}}</p>', 'img');
  Reject('<b>X</b>{{RESULTS}}', 'b');
  Reject('<script>alert(1)</script>{{RESULTS}}', 'script');
  Reject('<style>p{}</style>{{RESULTS}}', 'style');
  Reject('<p>{{RESULTS}}</p><p bad', 'HTML');
end;

procedure THtmlReportTemplateReaderTests.InvalidEncodingAndNumericEntities;
var
  T: TReportTemplate;
begin
  Reject('<p>' + #255 + '</p>{{RESULTS}}', 'UTF-8');
  Reject('<p>&#xD800;</p>{{RESULTS}}', 'Unicode');
  Reject('<p>&#1114112;</p>{{RESULTS}}', 'Unicode');
  Reject('<p>&#0;</p>{{RESULTS}}', 'Unicode');
  T := ReadHtmlReportTemplate('<p>Ж 🏁 &unknown;</p>{{RESULTS}}');
  AssertEquals('Ж 🏁 &unknown;', T.Header[0].Text);
end;

procedure THtmlReportTemplateReaderTests.TwoColumnRowsKeepParagraphStyles;
var
  T: TReportTemplate;
begin
  T := ReadHtmlReportTemplate(
    '<table><tr><td><p>Left &amp;</p></td><td><p style="text-align:right;font-size:12pt">Right<br>Second</p></td></tr></table>{{RESULTS}}<table><tr><td><p>Judge</p></td><td><p style="text-align:right">Secretary</p></td></tr></table>');
  AssertEquals(1, Length(T.Header));
  AssertTrue(T.Header[0].IsPair);
  AssertEquals('Left &', T.Header[0].Text);
  AssertEquals('Right' + #10 + 'Second', T.Header[0].RightText);
  AssertEquals(12, T.Header[0].RightFontSize);
  AssertEquals(Ord(rpaRight), Ord(T.Header[0].RightAlignment));
  AssertEquals('Secretary', T.Footer[0].RightText);
end;

procedure THtmlReportTemplateReaderTests.InvalidColumnRowsAreRejected;
begin
  Reject('<table><tr><td><p>Only one</p></td></tr></table>{{RESULTS}}', 'table');
  Reject('<table><tr><td><p>A</p><p>B</p></td><td><p>C</p></td></tr></table>{{RESULTS}}',
    'table');
  Reject('<table><tr><td><p>{{RESULTS}}</p></td><td><p>C</p></td></tr></table>',
    '{{RESULTS}}');
  Reject('<table><tr><td><p>A</p></td><td><p>B</p></td><td><p>C</p></td></tr></table>{{RESULTS}}', 'table');
  Reject('<table><tr><td><table></table></td></tr></table>{{RESULTS}}', 'table');
  Reject('<table><tr><td>raw text</td><td><p>B</p></td></tr></table>{{RESULTS}}',
    'raw text');
end;

procedure THtmlReportTemplateReaderTests.CenterAlignmentInParagraphsAndBothColumns;
var
  T: TReportTemplate;
begin
  T := ReadHtmlReportTemplate(
    '<p style="TEXT-ALIGN: CENTER">Center</p>{{RESULTS}}<table><tr><td><p style="text-align:center">Left cell</p></td><td><p style="text-align: center">Right cell</p></td></tr></table>');
  AssertEquals(Ord(rpaCenter), Ord(T.Header[0].Alignment));
  AssertTrue(T.Footer[0].IsPair);
  AssertEquals(Ord(rpaCenter), Ord(T.Footer[0].Alignment));
  AssertEquals(Ord(rpaCenter), Ord(T.Footer[0].RightAlignment));
end;

initialization
  RegisterTest(THtmlReportTemplateReaderTests);
end.
