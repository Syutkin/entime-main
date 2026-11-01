unit ReportTemplateFiles;
{$mode objfpc}{$H+}
interface

uses Classes, ProtocolDocumentModel, StageFinishReportModel;

procedure ListReportTemplates(const Directory: string; Paths: TStrings);
procedure PrepareReportTemplate(const Snapshot: TStageReportSnapshot;
  const Path: string);

procedure PrepareProtocolTemplate(const Snapshot: TProtocolDocument; const Path: string);

implementation

uses SysUtils, ReportTemplateModel, HtmlReportTemplateReader;

procedure ListReportTemplates(const Directory: string; Paths: TStrings);
var
  Search: TSearchRec;
  Sorted: TStringList;
  Ext: string;
begin
  Paths.Clear;
  if Directory = '' then Exit;
  Sorted := TStringList.Create;
  try
    Sorted.CaseSensitive := True;
    Sorted.Sorted := True;
    Sorted.Duplicates := dupIgnore;
    if FindFirst(IncludeTrailingPathDelimiter(Directory) + '*',
      faAnyFile, Search) = 0 then
    try
      repeat
        Ext := LowerCase(ExtractFileExt(Search.Name));
        if ((Search.Attr and faDirectory) = 0) and
          ((Ext = '.html') or (Ext = '.htm')) then
          Sorted.Add(ExpandFileName(IncludeTrailingPathDelimiter(Directory) +
            Search.Name));
      until FindNext(Search) <> 0;
    finally
      FindClose(Search);
    end;
    Paths.Assign(Sorted);
  finally
    Sorted.Free;
  end;
end;

procedure PrepareProtocolTemplate(const Snapshot: TProtocolDocument; const Path: string);
var
  Stream: TFileStream;
  Html: string;
  Template: TReportTemplate;
begin
  if Snapshot = nil then raise EArgumentNilException.Create('Snapshot');
  Template := Default(TReportTemplate);
  if Path <> '' then
  try
    Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Html, Stream.Size);
      if Html <> '' then Stream.ReadBuffer(Html[1], Length(Html));
    finally
      Stream.Free;
    end;
    Template := ReadHtmlReportTemplate(Html);
  except
    on E: Exception do raise EReportTemplateError.Create(Path + ': ' + E.Message);
  end;
  Snapshot.Template := Template;
end;

procedure PrepareReportTemplate(const Snapshot: TStageReportSnapshot; const Path: string);
var
  D: TProtocolDocument;
begin
  if Snapshot = nil then raise EArgumentNilException.Create('Snapshot');
  D := TProtocolDocument.Create;
  try
    PrepareProtocolTemplate(D, Path);
    Snapshot.Template := D.Template;
  finally
    D.Free;
  end;
end;

end.
