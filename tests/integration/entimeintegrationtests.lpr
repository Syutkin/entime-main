program EntimeIntegrationTests;

{$mode objfpc}{$H+}

{$R *.res}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces,
  Forms,
  SqlQuerySortEngine,
  consoletestrunner,
  CompetitionExportServiceTests,
  MainIntegrationTests;

var
  App: TTestRunner;
begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;

  App := TTestRunner.Create(nil);
  App.Initialize;
  App.Run;
  App.Free;
end.
