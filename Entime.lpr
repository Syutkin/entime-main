program Entime;

{$mode objfpc}{$H+}

{$IFOPT D+} {$DEFINE DEBUG} {$ENDIF}

uses
  {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  SysUtils,
  Forms,
  Main,
  LazSerialPort,
  rxnew,
  SqlQuerySortEngine,
  lazcontrols,
  datetimectrls,
  lazdbexport,
  Result,
  HistoryLazarus,
  rxapputils,
  AppLogger,
  i18n;

  {$R *.res}

type
  TUnhandledExceptionHandler = class
    procedure HandleException(Sender: TObject; E: Exception);
  end;

var
  loggingSettings: TLoggingSettings;
  iniFileName, loggingWarning: string;
  primaryLogDirectory, fallbackLogDirectory: string;
  unhandledExceptionHandler: TUnhandledExceptionHandler;

procedure TUnhandledExceptionHandler.HandleException(Sender: TObject;
  E: Exception);
begin
  LogUnhandledException(E);
  Application.ShowException(E);
end;

begin
  RequireDerivedFormResource := True;
  {$IFDEF DEBUG}
  if FileExists(IncludeTrailingPathDelimiter(
    ExtractFilePath(ExpandFileName(ParamStr(0)))) + 'heaptrace.trc') then
  begin
    DeleteFile(IncludeTrailingPathDelimiter(
      ExtractFilePath(ExpandFileName(ParamStr(0)))) + 'heaptrace.trc');
  end;
  SetHeapTraceOutput(IncludeTrailingPathDelimiter(
    ExtractFilePath(ExpandFileName(ParamStr(0)))) + 'heaptrace.trc');
  globalSkipIfNoLeaks := true;
  {$ENDIF DEBUG}
  Application.Title:='Entime';
  Application.Scaled:=True;
  Application.Initialize;

  iniFileName := GetDefaultIniName;
  loggingSettings := LoadLoggingSettings(iniFileName, loggingWarning);
  primaryLogDirectory := IncludeTrailingPathDelimiter(
    ExtractFilePath(ExpandFileName(ParamStr(0)))) + 'logs';
  fallbackLogDirectory := IncludeTrailingPathDelimiter(
    ExtractFilePath(iniFileName)) + 'logs';
  InitializeAppLogger(loggingSettings, primaryLogDirectory,
    fallbackLogDirectory, loggingWarning);
  unhandledExceptionHandler := TUnhandledExceptionHandler.Create;
  Application.OnException := @unhandledExceptionHandler.HandleException;
  try
    try
      Application.CreateForm(TMainForm, MainForm);
      MainForm.LazBleComponent1.RefreshAvailability;
      Application.CreateForm(TResultsForm, ResultsForm);
      Application.Run;
    except
      on E: Exception do
      begin
        LogUnhandledException(E);
        Application.ShowException(E);
      end;
    end;
  finally
    Application.OnException := nil;
    unhandledExceptionHandler.Free;
    AppLog(rsApplicationShutdown, allInfo, alvNone, alsApplication);
    FinalizeAppLogger;
  end;
end.
