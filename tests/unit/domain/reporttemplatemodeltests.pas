unit ReportTemplateModelTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  TReportTemplateModelTests = class(TTestCase)
  published
    procedure EmptyTemplateAndCompetitionNameDefault;
    procedure SnapshotOwnsParagraphsAndPreservesFormatting;
  end;

implementation

uses ReportTemplateModel, StageFinishReportModel;

procedure TReportTemplateModelTests.EmptyTemplateAndCompetitionNameDefault;
var
  S: TStageReportSnapshot;
  O: TStageReportOptions;
begin
  S := TStageReportSnapshot.Create;
  try
    AssertEquals(0, Length(S.Template.Header));
    AssertEquals(0, Length(S.Template.Footer));
    O := DefaultReportOptions;
    AssertTrue(O.ShowHeader);
    AssertTrue(O.ShowHeadings);
    O.ShowHeadings := False;
    AssertTrue(O.ShowHeader);
    AssertTrue(O.ShowFooter);
    AssertTrue(O.ShowPenalty);
    AssertTrue(O.AllCategories);
  finally
    S.Free;
  end;
end;

procedure TReportTemplateModelTests.SnapshotOwnsParagraphsAndPreservesFormatting;
var
  S, T: TStageReportSnapshot;
  V, CopyValue: TReportTemplate;
begin
  S := TStageReportSnapshot.Create;
  T := TStageReportSnapshot.Create;
  try
    SetLength(V.Header, 2);
    SetLength(V.Footer, 1);
    V.Header[0] := ReportParagraph('Шапка' + #10 + 'строка', 14, rpaRight);
    V.Header[1] := ReportParagraph('');
    V.Footer[0] := ReportParagraphPair(ReportParagraph('Подпись'),
      ReportParagraph('Справа', 12, rpaRight));
    S.Template := V;
    T.Template := V;
    V.Header[0].Text := 'changed';
    CopyValue := S.Template;
    AssertEquals('Шапка' + #10 + 'строка', CopyValue.Header[0].Text);
    AssertEquals(14, CopyValue.Header[0].FontSize);
    AssertEquals(Ord(rpaRight), Ord(CopyValue.Header[0].Alignment));
    AssertEquals('', CopyValue.Header[1].Text);
    AssertEquals(10, CopyValue.Footer[0].FontSize);
    CopyValue.Footer[0].RightText := 'changed';
    AssertEquals('Справа', S.Template.Footer[0].RightText);
    CopyValue.Footer[0].Text := 'changed';
    AssertEquals('Подпись', S.Template.Footer[0].Text);
    AssertEquals('Шапка' + #10 + 'строка', T.Template.Header[0].Text);
  finally
    T.Free;
    S.Free;
  end;
end;

initialization
  RegisterTest(TReportTemplateModelTests);
end.
