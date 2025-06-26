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
  updater;

  {$R *.res}

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
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TResultsForm, ResultsForm);
  //Application.CreateForm(TLoRaForm, LoRaForm);
  Application.Run;
end.
