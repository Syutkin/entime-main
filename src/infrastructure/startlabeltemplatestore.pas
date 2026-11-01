unit StartLabelTemplateStore;
{$mode objfpc}{$H+}
interface

uses Classes, StartLabelModel, StartLabelTemplates, StageFinishReportFiles;

type
  TStartLabelTemplateFile = record
    Name, FileName: string;
  end;
  TStartLabelTemplateFiles = array of TStartLabelTemplateFile;

  TStartLabelTemplateStore = class
  private
    FDirectory: string;
    FFiles: TStageReportFiles;
    function Path(const FileName: string): string;
    function Write(const FileName, Name: string;
      const Paper: TStartLabelPaper): TStartLabelTemplate;
  public
    constructor Create(const Directory: string; Files: TStageReportFiles = nil);
    function List: TStartLabelTemplateFiles;
    function Load(const FileName: string): TStartLabelTemplate;
    function CreateTemplate(const Name: string;
      const Paper: TStartLabelPaper): TStartLabelTemplate;
    function Save(const FileName: string;
      const Paper: TStartLabelPaper): TStartLabelTemplate;
  end;

implementation

uses SysUtils, IniFiles, i18n;

type
  TTemplateWriter = class
    Name: string;
    Paper: TStartLabelPaper;
    procedure WriteTo(const FileName: string);
  end;

procedure TTemplateWriter.WriteTo(const FileName: string);
begin
  WriteStartLabelTemplate(FileName, Name, Paper);
end;

constructor TStartLabelTemplateStore.Create(const Directory: string;
  Files: TStageReportFiles);
begin
  inherited Create;
  FDirectory := Directory;
  FFiles := Files;
end;

function TStartLabelTemplateStore.Path(const FileName: string): string;
begin
  if (FDirectory = '') or (FileName = '') or (FileName <> ExtractFileName(FileName)) or
    not SameText(ExtractFileExt(FileName), '.ini') then
    raise EStartLabelTemplate.Create(Format(rsLabelTemplateInvalidField,
      ['TemplateFile']));
  Result := IncludeTrailingPathDelimiter(FDirectory) + FileName;
end;

function TStartLabelTemplateStore.List: TStartLabelTemplateFiles;
var
  Search: TSearchRec;
  Item, Swap: TStartLabelTemplateFile;
  Ini: TMemIniFile;
  I, J, N: integer;
begin
  Result := nil;
  if (FDirectory = '') or not DirectoryExists(FDirectory) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(FDirectory) + '*', faAnyFile,
    Search) <> 0 then
    Exit;
  try
    repeat
      if ((Search.Attr and faDirectory) <> 0) or not
        SameText(ExtractFileExt(Search.Name), '.ini') then Continue;
      Item.FileName := Search.Name;
      Item.Name := ChangeFileExt(Search.Name, '');
    try
      Ini := TMemIniFile.Create(Path(Search.Name));
      try
        Item.Name := Trim(Ini.ReadString('StartLabels', 'Name', Item.Name));
      finally
        Ini.Free;
      end;
    except
      on E: Exception do Item.Name := ChangeFileExt(Search.Name, '');
    end;
      if Item.Name = '' then Item.Name := ChangeFileExt(Search.Name, '');
      N := Length(Result);
      SetLength(Result, N + 1);
      Result[N] := Item;
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  for I := 1 to High(Result) do
  begin
    J := I;
    while J > 0 do
    begin
      N := CompareStr(Result[J - 1].Name, Result[J].Name);
      if N = 0 then N := CompareStr(Result[J - 1].FileName, Result[J].FileName);
      if N <= 0 then Break;
      Swap := Result[J - 1];
      Result[J - 1] := Result[J];
      Result[J] := Swap;
      Dec(J);
    end;
  end;
end;

function TStartLabelTemplateStore.Load(const FileName: string): TStartLabelTemplate;
begin
  Result := ReadStartLabelTemplate(Path(FileName));
  Result.FileName := FileName;
end;

function TStartLabelTemplateStore.Write(const FileName, Name: string;
  const Paper: TStartLabelPaper): TStartLabelTemplate;
var
  Writer: TTemplateWriter;
begin
  Writer := TTemplateWriter.Create;
  try
    Writer.Name := Name;
    Writer.Paper := Paper;
    SaveStageReportFile(Path(FileName), @Writer.WriteTo, FFiles);
  finally
    Writer.Free;
  end;
  Result := Load(FileName);
end;

function TStartLabelTemplateStore.CreateTemplate(const Name: string;
  const Paper: TStartLabelPaper): TStartLabelTemplate;
var
  Base, FileName: string;
  N: integer;
  F: TFormatSettings;
begin
  if FDirectory = '' then Path('labels.ini');
  if not ForceDirectories(FDirectory) then
    raise EInOutError.Create(FDirectory + ': ' + rsLabelTemplateDirectoryError);
  F := DefaultFormatSettings;
  F.DecimalSeparator := '.';
  Base := FormatFloat('0.###', Paper.Width / StartLabelUnitsPerMM, F) +
    'x' + FormatFloat('0.###', Paper.Height / StartLabelUnitsPerMM, F);
  FileName := Base + '.ini';
  N := 2;
  while FileExists(Path(FileName)) do
  begin
    FileName := Base + '-' + IntToStr(N) + '.ini';
    Inc(N);
  end;
  Result := Write(FileName, Name, Paper);
end;

function TStartLabelTemplateStore.Save(const FileName: string;
  const Paper: TStartLabelPaper): TStartLabelTemplate;
var
  Previous: TStartLabelTemplate;
begin
  Previous := Load(FileName);
  Result := Write(FileName, Previous.Name, Paper);
end;

end.
