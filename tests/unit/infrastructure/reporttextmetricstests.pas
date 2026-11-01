unit ReportTextMetricsTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  TReportTextMetricsTests = class(TTestCase)
  published
    procedure ExplicitBlankLinesArePreserved;
    procedure WrappedUnicodeFitsItsDocumentWidth;
  end;

implementation

uses Classes, SysUtils, fpTTF, ReportTextMetrics, StageFinishReportBackend;

type
  TMeasuredText = class(TReportText)
    function MeasuredWidth(const Value: string): single;
  end;

function TMeasuredText.MeasuredWidth(const Value: string): single;
begin
  Result := gTTFontCache.FindFont(Font.Name).TextWidth(Value, Font.Size) *
    25.4 / gTTFontCache.DPI;
end;

procedure TReportTextMetricsTests.ExplicitBlankLinesArePreserved;
var
  M: TMeasuredText;
  Lines: TStringList;
begin
  LoadReportFonts;
  M := TMeasuredText.Create(nil);
  Lines := TStringList.Create;
  try
    M.Wrap('Один' + #10#10 + 'Два' + #10, 188, Lines, '', 14);
    AssertEquals(4, Lines.Count);
    AssertEquals('Один', Lines[0]);
    AssertEquals('', Lines[1]);
    AssertEquals('Два', Lines[2]);
    AssertEquals('', Lines[3]);
    M.Wrap('', 188, Lines, '', 36);
    AssertEquals(1, Lines.Count);
    AssertEquals('', Lines[0]);
    AssertTrue(M.LineHeight > 0);
  finally
    Lines.Free;
    M.Free;
  end;
end;

procedure TReportTextMetricsTests.WrappedUnicodeFitsItsDocumentWidth;
const
  Widths: array[0..2] of single = (40, 188, 275);
var
  M: TMeasuredText;
  Lines: TStringList;
  word, Text, Line: string;
  I, J, Size: integer;
begin
  LoadReportFonts;
  M := TMeasuredText.Create(nil);
  Lines := TStringList.Create;
  word := '';
  for I := 1 to 60 do word := word + 'ЖюШW';
  try
    for Size := 6 to 36 do for J := 0 to High(Widths) do
      begin
        M.Wrap(word, Widths[J], Lines, '', Size);
        Text := '';
        for Line in Lines do
        begin
          AssertEquals(Line, UTF8Encode(UTF8Decode(Line)));
          Text := Text + Line;
          AssertTrue(Format('Wrapped line: font %d, target %.1f mm, actual %.2f mm',
            [Size, Widths[J], M.MeasuredWidth(Line)]), M.MeasuredWidth(Line) <= Widths[J] + 0.1);
        end;
        AssertEquals(word, Text);
      end;
  finally
    Lines.Free;
    M.Free;
  end;
end;

initialization
  RegisterTest(TReportTextMetricsTests);
end.
