program EntimeTests;

{$mode objfpc}{$H+}

{$R *.res}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  consoletestrunner,
  AppLoggerTests,
  CompetitionDbContextTests,
  DataLayerSplitTests,
  DbSqlTests,
  DbSqlFacadeTests,
  StartMarkRepositoryTests,
  FinishMarkRepositoryTests,
  FinishMarkSqliteAdapterTests,
  ParticipantStatusTests,
  ParticipantStageDataTests,
  TimingMarkTests,
  StartMarkTests,
  FinishMarkTests,
  StageConfigTests,
  StageFieldNamesTests,
  StageFieldFactoryTests,
  StageModelTests,
  ResultFormattingTests,
  CompetitionImportServiceTests,
  CompetitionResultsServiceTests,
  CompetitionFinishServiceTests,
  TelegramNotificationCoordinatorTests,
  LedPanelClientTests,
  LedPanelCoordinatorTests,
  FinishMarkServiceTests,
  StartMarkMatcherTests,
  StartMarkServiceTests,
  StartMarkSqliteAdapterTests,
  TimingMarkRouterTests,
  TimingTransportControllerTests,
  CompetitionLifecycleServiceTests,
  CompetitionBackupServiceTests,
  CompetitionRefreshCoordinatorTests,
  ParticipantsCsvParserTests,
  ResultsCsvParserTests,
  SerialDeviceProviderTests,
  SerialTimingTransportTests,
  BleTimingTransportTests,
  TimingPacketMarkMapperTests,
  TimingProtocolTests,
  TransportStreamFramerTests,
  FirmwareResponseProtocolTests,
  TransportStreamProcessorTests,
  HttpTransportTests,
  FpHttpTransportTests,
  ValidatorsTests,
  UpdaterTests;

var
  App: TTestRunner;
begin
  App := TTestRunner.Create(nil);
  App.Initialize;
  App.Run;
  App.Free;
end.
