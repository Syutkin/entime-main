program Entime;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  Main,
  LazSerialPort,
  rxnew,
  sqlite3laz,
  lazcontrols,
  datetimectrls,
  lazdbexport,
  Result,
  HistoryLazarus;

  {$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TResultsForm, ResultsForm);
  //Application.CreateForm(TLoRaForm, LoRaForm);
  Application.Run;
end.
