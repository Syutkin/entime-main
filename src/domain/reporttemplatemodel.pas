unit ReportTemplateModel;
{$mode objfpc}{$H+}
interface

type
  TReportParagraphAlignment = (rpaLeft, rpaRight, rpaCenter);

  TReportParagraph = record
    Text: string;
    FontSize: integer;
    Alignment: TReportParagraphAlignment;
    IsPair: boolean;
    RightText: string;
    RightFontSize: integer;
    RightAlignment: TReportParagraphAlignment;
  end;
  TReportParagraphs = array of TReportParagraph;

  TReportTemplate = record
    Header, Footer: TReportParagraphs;
  end;

function ReportParagraph(const Text: string; FontSize: integer = 10;
  Alignment: TReportParagraphAlignment = rpaLeft): TReportParagraph;
function ReportParagraphPair(const Left, Right: TReportParagraph): TReportParagraph;
function CloneReportTemplate(const Value: TReportTemplate): TReportTemplate;

implementation

uses SysUtils;

function ReportParagraph(const Text: string; FontSize: integer;
  Alignment: TReportParagraphAlignment): TReportParagraph;
begin
  if (FontSize < 6) or (FontSize > 36) then
    raise ERangeError.Create('Report font size must be 6–36 pt');
  Result := Default(TReportParagraph);
  Result.Text := Text;
  Result.FontSize := FontSize;
  Result.Alignment := Alignment;
end;

function ReportParagraphPair(const Left, Right: TReportParagraph): TReportParagraph;
begin
  Result := Left;
  Result.IsPair := True;
  Result.RightText := Right.Text;
  Result.RightFontSize := Right.FontSize;
  Result.RightAlignment := Right.Alignment;
end;

function CloneReportTemplate(const Value: TReportTemplate): TReportTemplate;
begin
  Result.Header := Copy(Value.Header);
  Result.Footer := Copy(Value.Footer);
end;

end.
