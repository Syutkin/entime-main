unit ProtocolDocumentModelTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  TProtocolDocumentModelTests = class(TTestCase)
  published
    procedure StageProjectionPreservesCellsAndHeading;
    procedure NeutralDocumentHasNoRequiredFinishColumns;
    procedure TemplateIsCopied;
  end;

implementation

uses SysUtils, ProtocolDocumentModel, StageFinishReportModel, ReportTemplateModel;

procedure TProtocolDocumentModelTests.StageProjectionPreservesCellsAndHeading;
var
  S: TStageReportSnapshot;
  D: TProtocolDocument;
begin
  S := TStageReportSnapshot.Create;
  try
    S.Options := DefaultReportOptions;
    S.Options.ShowPenalty := False;
    S.Labels := ReportLabels(rlEnglish);
    S.StageName := 'Forest';
    SetLength(S.Rows, 1);
    S.Rows[0].Number := 123;
    S.Rows[0].Category := 'A';
    S.Rows[0].Cells[rcNumber] := '123';
    S.Rows[0].Cells[rcResult] := '00:00.000';
    D := StageProtocolDocument(S);
    try
      AssertEquals('Finish protocol — Stage 1 — Forest', D.Heading);
      AssertEquals(6, Length(D.Columns));
      AssertEquals('123', D.Rows[0].Cells[1]);
      AssertEquals('00:00.000', D.Rows[0].Cells[4]);
      AssertEquals('A', D.Rows[0].Category);
      D.Rows[0].Cells[1] := '9';
      AssertEquals('123', S.Rows[0].Cells[rcNumber]);
    finally
      D.Free;
    end;
  finally
    S.Free;
  end;
end;

procedure TProtocolDocumentModelTests.NeutralDocumentHasNoRequiredFinishColumns;
var
  D: TProtocolDocument;
begin
  D := TProtocolDocument.Create;
  try
    SetLength(D.Columns, 1);
    D.Columns[0].Caption := 'Start';
    D.Columns[0].Role := pcrTime;
    SetLength(D.Rows, 1);
    SetLength(D.Rows[0].Cells, 1);
    D.Rows[0].Cells[0] := '10:00:00';
    AssertEquals('10:00:00', D.Rows[0].Cells[0]);
    AssertEquals(1, Length(D.Columns));
  finally
    D.Free;
  end;
end;

procedure TProtocolDocumentModelTests.TemplateIsCopied;
var
  D: TProtocolDocument;
  T: TReportTemplate;
begin
  D := TProtocolDocument.Create;
  try
    T := Default(TReportTemplate);
    SetLength(T.Header, 1);
    T.Header[0].Text := 'Original';
    D.Template := T;
    T.Header[0].Text := 'Changed';
    T := D.Template;
    AssertEquals('Original', T.Header[0].Text);
    T.Header[0].Text := 'Again';
    T := D.Template;
    AssertEquals('Original', T.Header[0].Text);
  finally
    D.Free;
  end;
end;

initialization
  RegisterTest(TProtocolDocumentModelTests);
end.
