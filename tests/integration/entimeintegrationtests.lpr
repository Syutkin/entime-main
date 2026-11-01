program EntimeIntegrationTests;

{$mode objfpc}{$H+}

{$R *.res}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms,
  SqlQuerySortEngine,
  consoletestrunner,
  MySpinEditIntegrationTests,
  StartLabelsPrintIntegrationTests,
  StartProtocolPrintIntegrationTests,
  ProtocolPrintFormTests,
  OverallFinishPrintIntegrationTests,
  StageFinishPrintIntegrationTests,
  CompetitionExportServiceTests,
  MainIntegrationTests,
  ResultsImportPreviewTests,
  ParticipantCardIntegrationTests;

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
