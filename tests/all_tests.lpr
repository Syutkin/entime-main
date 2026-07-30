program all_tests;

{$mode objfpc}{$H+}

uses
  consoletestrunner,
  test_db_sql,
  test_participants_csv_parser,
  test_results_csv_parser,
  test_validators;

var
  App: TTestRunner;
begin
  App := TTestRunner.Create(nil);
  App.Initialize;
  App.Run;
  App.Free;
end.
