unit StageFinishPdfWriterTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry, StageFinishReportBackend;

type
  TStageFinishPdfWriterTests = class(TTestCase)
  private
    D: TPreparedStageReport;
    Dir, Target: string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SafeOverwriteAndUnicodePath;
    procedure ExportFailurePreservesOldTargetAndCleansTemp;
    procedure ReplacementFailurePreservesOldTargetAndAllowsRetry;
    procedure EmptyPathCreatesNothing;
  end;

implementation

uses StageFinishPdfWriter, fpreport;

type
  TFailingReport = class(TPreparedStageReport)
    procedure WritePdf(const FileName: string); override;
  end;

  TFailingFiles = class(TStagePdfFiles)
    procedure Replace(const Temp, Target: string); override;
  end;

procedure TFailingReport.WritePdf(const FileName: string);
var
  F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmCreate);
  F.Free;
  raise EWriteError.Create('Simulated full disk');
end;

procedure TFailingFiles.Replace(const Temp, Target: string);
begin
  raise EInOutError.Create('Simulated locked destination');
end;

function Content(const P: string): string;
var
  F: TFileStream;
begin
  F := TFileStream.Create(P, fmOpenRead);
  try
    SetLength(Result, F.Size);
    if F.Size > 0 then F.ReadBuffer(Result[1], F.Size);
  finally
    F.Free;
  end;
end;

procedure OldFile(const P: string);
var
  F: TFileStream;
  S: string;
begin
  F := TFileStream.Create(P, fmCreate);
  try
    S := 'old PDF';
    F.WriteBuffer(S[1], Length(S));
  finally
    F.Free;
  end;
end;

procedure TStageFinishPdfWriterTests.SetUp;
var
  P: TFPReportPage;
  B: TFPReportTitleBand;
  M: TFPReportMemo;
begin
  Dir := GetTempFileName;
  DeleteFile(Dir);
  Dir := Dir + ' Гонка';
  CreateDir(Dir);
  Target := Dir + DirectorySeparator + 'Финиш гонки.pdf';
  D := TPreparedStageReport.Create;
  P := TFPReportPage.Create(D.Report);
  P.PageSize.PaperName := 'A4';
  P.Font.Name := ReportRegularFont;
  B := TFPReportTitleBand.Create(P);
  B.Layout.Height := 20;
  M := TFPReportMemo.Create(B);
  M.Layout.Width := 180;
  M.Layout.Height := 10;
  M.Text := 'Иван Иванов 123 DNS';
  D.Prepare;
end;

procedure TStageFinishPdfWriterTests.TearDown;
var
  R: TSearchRec;
begin
  D.Free;
  if FindFirst(Dir + DirectorySeparator + '*', faAnyFile, R) = 0 then
  begin
    repeat
      if (R.Name <> '.') and (R.Name <> '..') then DeleteFile(Dir + DirectorySeparator + R.Name);
    until FindNext(R) <> 0;
    FindClose(R);
  end;
  RemoveDir(Dir);
end;

procedure TStageFinishPdfWriterTests.SafeOverwriteAndUnicodePath;
var
  Count: integer;
begin
  OldFile(Target);
  Count := D.PageCount;
  SaveStageFinishPdf(D, Target);
  AssertEquals('%PDF-', Copy(Content(Target), 1, 5));
  SaveStageFinishPdf(D, Target);
  AssertEquals(Count, D.PageCount);
end;

procedure TStageFinishPdfWriterTests.ExportFailurePreservesOldTargetAndCleansTemp;
var
  F: TFailingReport;
  Raised: boolean;
  R: TSearchRec;
  Count: integer;
begin
  OldFile(Target);
  F := TFailingReport.Create;
  Raised := False;
  try
    try
      SaveStageFinishPdf(F, Target);
    except
      on E: EWriteError do Raised := True;
    end;
  finally
    F.Free;
  end;
  AssertTrue(Raised);
  AssertEquals('old PDF', Content(Target));
  Count := 0;
  if FindFirst(Dir + DirectorySeparator + '*', faAnyFile, R) = 0 then
  begin
    repeat
      if (R.Name <> '.') and (R.Name <> '..') then Inc(Count);
    until FindNext(R) <> 0;
    FindClose(R);
  end;
  AssertEquals(1, Count);
end;

procedure TStageFinishPdfWriterTests.ReplacementFailurePreservesOldTargetAndAllowsRetry;
var
  F: TFailingFiles;
  Raised: boolean;
begin
  OldFile(Target);
  F := TFailingFiles.Create;
  Raised := False;
  try
    try
      SaveStageFinishPdf(D, Target, F);
    except
      on E: EInOutError do Raised := True;
    end;
  finally
    F.Free;
  end;
  AssertTrue(Raised);
  AssertEquals('old PDF', Content(Target));
  SaveStageFinishPdf(D, Target);
  AssertEquals('%PDF-', Copy(Content(Target), 1, 5));
end;

procedure TStageFinishPdfWriterTests.EmptyPathCreatesNothing;
begin
  AssertFalse(SaveStageFinishPdf(D, ''));
end;

initialization
  RegisterTest(TStageFinishPdfWriterTests);
end.
