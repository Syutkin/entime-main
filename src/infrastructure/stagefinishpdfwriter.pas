unit StageFinishPdfWriter;
{$mode objfpc}{$H+}
interface

uses StageFinishReportBackend, StageFinishReportFiles;

type
  TStagePdfFiles = TStageReportFiles;

function SaveStageFinishPdf(const Document: TPreparedStageReport;
  const Target: string; Files: TStagePdfFiles = nil): boolean;

implementation

uses Classes, SysUtils;

type
  TPdfOutput = class
    Document: TPreparedStageReport;
    procedure WriteFile(const Path: string);
  end;

procedure TPdfOutput.WriteFile(const Path: string);
var
  Stream: TFileStream;
  Header: array[0..4] of char;
begin
  Document.WritePdf(Path);
  Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    Stream.ReadBuffer(Header, SizeOf(Header));
    if string(Header) <> '%PDF-' then raise EWriteError.Create('Invalid PDF output');
  finally
    Stream.Free;
  end;
end;

function SaveStageFinishPdf(const Document: TPreparedStageReport;
  const Target: string; Files: TStagePdfFiles): boolean;
var
  Output: TPdfOutput;
begin
  Result := False;
  if Target = '' then Exit;
  if Document = nil then raise EArgumentNilException.Create('Document');
  Output := TPdfOutput.Create;
  try
    Output.Document := Document;
    Result := SaveStageReportFile(Target, @Output.WriteFile, Files);
  finally
    Output.Free;
  end;
end;

end.
