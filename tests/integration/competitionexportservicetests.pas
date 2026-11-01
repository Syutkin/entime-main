unit CompetitionExportServiceTests;

{$mode objfpc}{$H+}

interface

uses
  fpcunit, testregistry, StageModel, CompetitionExportService;

type
  TCompetitionExportServiceTests = class(TTestCase)
  published
    procedure BuildStartListFieldSpecs_UsesOnlyActiveStagesInIndexOrder;
    procedure BuildResultsFieldSpecs_AddsStageAndSummaryFields;
  end;

implementation

procedure TCompetitionExportServiceTests.
BuildStartListFieldSpecs_UsesOnlyActiveStagesInIndexOrder;
var
  CompetitionStages: TStages;
  FieldSpecs: TExportFieldSpecs;
begin
  CompetitionStages := TStages.Create(12);
  try
    CompetitionStages[1].Name := 'Short';
    CompetitionStages[12].Name := 'Long';
    CompetitionStages[12].isActive := True;

    FieldSpecs := TCompetitionExportService.BuildStartListFieldSpecs(
      CompetitionStages);

    AssertEquals(2, Length(FieldSpecs));
    AssertEquals('starttime1', FieldSpecs[0].FieldName);
    AssertEquals('Short', FieldSpecs[0].ExportedName);
    AssertEquals('starttime12', FieldSpecs[1].FieldName);
    AssertEquals('Long', FieldSpecs[1].ExportedName);
  finally
    CompetitionStages.Free;
  end;
end;

procedure TCompetitionExportServiceTests.
BuildResultsFieldSpecs_AddsStageAndSummaryFields;
var
  CompetitionStages: TStages;
  FieldSpecs: TExportFieldSpecs;
begin
  CompetitionStages := TStages.Create(3);
  try
    CompetitionStages[1].Name := 'Forest';
    CompetitionStages[3].Name := 'Sprint';
    CompetitionStages[3].isActive := True;

    FieldSpecs := TCompetitionExportService.BuildResultsFieldSpecs(
      CompetitionStages, 'Result', 'Behind', 'Place', 'Total');

    AssertEquals(8, Length(FieldSpecs));
    AssertEquals('result1', FieldSpecs[0].FieldName);
    AssertEquals('Forest — Result', FieldSpecs[0].ExportedName);
    AssertEquals('diffleader1', FieldSpecs[1].FieldName);
    AssertEquals('Forest — Behind', FieldSpecs[1].ExportedName);
    AssertEquals('place1', FieldSpecs[2].FieldName);
    AssertEquals('Forest — Place', FieldSpecs[2].ExportedName);
    AssertEquals('result3', FieldSpecs[3].FieldName);
    AssertEquals('Sprint — Result', FieldSpecs[3].ExportedName);
    AssertEquals('sumresult', FieldSpecs[6].FieldName);
    AssertEquals('Total', FieldSpecs[6].ExportedName);
    AssertEquals('sumdiffleader', FieldSpecs[7].FieldName);
    AssertEquals('Behind', FieldSpecs[7].ExportedName);
  finally
    CompetitionStages.Free;
  end;
end;

initialization
  RegisterTest(TCompetitionExportServiceTests);

end.
