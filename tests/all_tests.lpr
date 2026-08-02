program all_tests;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  consoletestrunner,
  test_app_logger,
  test_db_sql,
  test_participants_csv_parser,
  test_results_csv_parser,
  test_validators,
  test_updater;

var
  App: TTestRunner;
begin
  App := TTestRunner.Create(nil);
  App.Initialize;
  App.Run;
  App.Free;
end.
