unit StageFinishReportFiles;
{$mode objfpc}{$H+}
interface

type
  TStageReportWriteMethod = procedure(const FileName: string) of object;

  TStageReportFiles = class
  public
    function CreateTemp(const Target: string): string; virtual;
    procedure Replace(const Temp, Target: string); virtual;
    procedure Remove(const Temp: string); virtual;
  end;

function SaveStageReportFile(const Target: string; WriteFile: TStageReportWriteMethod;
  Files: TStageReportFiles = nil): boolean;

implementation

uses Classes, SysUtils{$IFDEF WINDOWS},Windows{$ENDIF};

function TStageReportFiles.CreateTemp(const Target: string): string;
begin
  Result := SysUtils.GetTempFileName(ExtractFileDir(ExpandFileName(Target)),
    '.entime-report-');
  if Result = '' then raise EWriteError.Create('Cannot create temporary report file');
end;

procedure TStageReportFiles.Replace(const Temp, Target: string);
{$IFDEF WINDOWS}var WTemp,WTarget:UnicodeString;{$ENDIF}
begin
  {$IFDEF WINDOWS}
 WTemp:=UTF8Decode(Temp);WTarget:=UTF8Decode(Target);
 if not MoveFileExW(PWideChar(WTemp),PWideChar(WTarget),MOVEFILE_REPLACE_EXISTING) then
  RaiseLastOSError;
  {$ELSE}
  if not RenameFile(Temp, Target) then RaiseLastOSError;
  {$ENDIF}
end;

procedure TStageReportFiles.Remove(const Temp: string);
begin
  if SysUtils.FileExists(Temp) and not SysUtils.DeleteFile(Temp) then RaiseLastOSError;
end;

function SaveStageReportFile(const Target: string; WriteFile: TStageReportWriteMethod;
  Files: TStageReportFiles): boolean;
var
  OwnFiles: boolean;
  Temp: string;
begin
  Result := False;
  if Target = '' then Exit;
  OwnFiles := Files = nil;
  if OwnFiles then Files := TStageReportFiles.Create;
  Temp := '';
  try
    try
      Temp := Files.CreateTemp(Target);
      WriteFile(Temp);
      Files.Replace(Temp, ExpandFileName(Target));
      Temp := '';
      Result := True;
    except
      // Keep the old destination and original exception if export or replacement fails.
      if Temp <> '' then
      try
        Files.Remove(Temp);
      except
        on E: Exception do ;
      end;
      raise;
    end;
  finally
    if OwnFiles then Files.Free;
  end;
end;

end.
