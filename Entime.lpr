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
  sqlite3laz,
  lazcontrols,
  datetimectrls,
  lazdbexport,
  Result,
  HistoryLazarus,
  db_sql,
  rxapputils,
  app_logger,
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
  if FileExists('heaptrace.trc') then
  begin
    DeleteFile('heaptrace.trc');
  end;
  SetHeapTraceOutput('heaptrace.trc');
  globalSkipIfNoLeaks := true;
  {$ENDIF DEBUG}
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
      Application.CreateForm(TResultsForm, ResultsForm);
      //Application.CreateForm(TLoRaForm, LoRaForm);
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
