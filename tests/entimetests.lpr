program EntimeTests;

{$mode objfpc}{$H+}

{$R *.res}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  consoletestrunner,
  StartLabelModelTests,
  StartLabelServiceTests,
  StartLabelSettingsTests,
  StartLabelTemplateTests,
  StartLabelTemplateStoreTests,
  StartLabelReportTests,
  StartProtocolExportTests,
  StartReportServiceTests,
  StartReportModelTests,
  OverallProtocolExportTests,
  OverallFinishReportServiceTests,
  OverallFinishReportModelTests,
  ProtocolDocumentModelTests,
  ReportTextMetricsTests,
  ReportTemplateFilesTests,
  HtmlReportTemplateReaderTests,
  ReportTemplateModelTests,
  ReportTemplateLibraryTests,
  StageFinishReportServiceTests,
  StageFinishReportModelTests,
  StageFinishReportBuilderTests,
  StageFinishPdfWriterTests,
  StageFinishDocxWriterTests,
  StageFinishXlsxWriterTests,
  StageFinishReportBackendTests,
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
  ProtocolBalanceTests,
  ParticipantCardModelTests,
  ParticipantCardServiceTests,
  ResultsImportComparisonTests,
  ResultsImportPreviewServiceTests,
  ProtocolBalanceRepositoryTests,
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
