program entime_integration_tests;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces,
  Forms,
  consoletestrunner,
  test_main_integration;

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

