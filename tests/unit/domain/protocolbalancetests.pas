unit ProtocolBalanceTests;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, ParticipantStatus, ProtocolBalance;

type
  TProtocolBalanceTests = class(TTestCase)
  private
    function Data(const AStart: string = ''; const AFinish: string = '';
      const AResult: string = ''; const AStageStatus: string = '';
      const AGlobalStatus: string = ''): TProtocolBalanceStageInput;
    procedure AssertClassification(const AData: TProtocolBalanceStageInput;
      const AGroup: TProtocolBalanceGroup; const AReason: TProtocolBalanceReason;
      const AFinishWithoutStart: boolean = False);
  published
    procedure EmptyAndWhitespaceValues_HaveNoStageData;
    procedure StartWithoutFinish_IsUnresolvedIncludingMidnight;
    procedure FinishWithoutStart_IsUnresolvedIncludingZeroTime;
    procedure BothTimesWithoutResult_HaveMissingResult;
    procedure NumericResults_AreRecognizedIncludingZero;
    procedure MalformedResults_AreUnresolved;
    procedure ResultStatusTokens_DoNotInferStageStatus;
    procedure StageStatuses_OverrideRemainingNumericResult;
    procedure GlobalDsq_OverridesStageStatusAndResult;
    procedure GlobalDnsAndDnf_DoNotPropagateToOtherStages;
    procedure UnknownStageStatus_OverridesNumericResult;
    procedure TerminalGroups_KeepIndependentFinishWithoutStartFlag;
    procedure Summarize_EmptyInputHasZeroCounts;
    procedure Summarize_GroupsAreExclusiveAndMatchFilters;
    procedure Summarize_DoesNotAccumulateBetweenCalls;
    procedure Classification_IsIndependentOfSystemLocale;
    procedure Classification_PreservesOriginalInput;
  end;

implementation

function TProtocolBalanceTests.Data(
  const AStart, AFinish, AResult, AStageStatus, AGlobalStatus: string):
TProtocolBalanceStageInput;
begin
  Result.StartTime := AStart;
  Result.FinishTime := AFinish;
  Result.ResultValue := AResult;
  Result.StageStatusValue := AStageStatus;
  Result.GlobalStatusValue := AGlobalStatus;
end;

procedure TProtocolBalanceTests.AssertClassification(
  const AData: TProtocolBalanceStageInput; const AGroup: TProtocolBalanceGroup;
  const AReason: TProtocolBalanceReason; const AFinishWithoutStart: boolean);
var
  Classification: TProtocolBalanceClassification;
begin
  Classification := ClassifyProtocolBalance(AData);
  AssertEquals('Group', Ord(AGroup), Ord(Classification.Group));
  AssertEquals('Reason', Ord(AReason), Ord(Classification.Reason));
  AssertEquals('Finish without start', AFinishWithoutStart,
    Classification.FinishWithoutStart);
end;

procedure TProtocolBalanceTests.EmptyAndWhitespaceValues_HaveNoStageData;
begin
  AssertClassification(Default(TProtocolBalanceStageInput),
    pbgUnresolved, pbrNoStageData);
  AssertClassification(Data(' '#9, #10' ', ' '#13, #9, ' '),
    pbgUnresolved, pbrNoStageData);
end;

procedure TProtocolBalanceTests.StartWithoutFinish_IsUnresolvedIncludingMidnight;
var
  StartTime: string;
begin
  for StartTime in ['12:00:00.000', '00:00:00.000', '23:59:59.999'] do
    AssertClassification(Data(StartTime, ' '), pbgUnresolved, pbrMissingFinish);
end;

procedure TProtocolBalanceTests.FinishWithoutStart_IsUnresolvedIncludingZeroTime;
begin
  AssertClassification(Data('', '12:00:00.000'),
    pbgUnresolved, pbrFinishWithoutStart, True);
  AssertClassification(Data(' '#9, '00:00:00.000'),
    pbgUnresolved, pbrFinishWithoutStart, True);
end;

procedure TProtocolBalanceTests.BothTimesWithoutResult_HaveMissingResult;
begin
  AssertClassification(Data('23:59:00.000', '00:01:00.000'),
    pbgUnresolved, pbrMissingOrInvalidResult);
  AssertClassification(Data('00:00:00.000', '00:00:00.000', ' '#9),
    pbgUnresolved, pbrMissingOrInvalidResult);
end;

procedure TProtocolBalanceTests.NumericResults_AreRecognizedIncludingZero;
var
  ResultValue: string;
begin
  for ResultValue in ['00:00:00.000', '00:00:00', '01:02:03.4',
      '01:02:03.45', '01:02:03.456', '23:59:59.999', ' 00:01:00.000 '] do
    AssertClassification(Data('', '', ResultValue), pbgWithResult, pbrNone);
end;

procedure TProtocolBalanceTests.MalformedResults_AreUnresolved;
var
  ResultValue: string;
begin
  for ResultValue in ['garbage', '0', '00:01', '1:02:03', '24:00:00.000',
      '00:60:00.000', '00:00:60.000', '00:00:00.', '00:00:00.1234',
      '00:00:00,123', '-00:00:00.100', '00:00:00.000x', '2026-10-29 00:01:00',
      '12:00:00 PM', '00:0x:00', '00/00/00'] do
    AssertClassification(Data('', '', ResultValue),
      pbgUnresolved, pbrMissingOrInvalidResult);
end;

procedure TProtocolBalanceTests.ResultStatusTokens_DoNotInferStageStatus;
var
  ResultValue: string;
begin
  for ResultValue in ['DNS', 'DNF', 'DSQ', ' dns '] do
    AssertClassification(Data('', '', ResultValue),
      pbgUnresolved, pbrMissingOrInvalidResult);
end;

procedure TProtocolBalanceTests.StageStatuses_OverrideRemainingNumericResult;
const
  GROUPS: array[psDNS..psDSQ] of TProtocolBalanceGroup =
    (pbgDNS, pbgDNF, pbgDSQ);
var
  Status: TParticipantStatus;
begin
  for Status := psDNS to psDSQ do
  begin
    AssertClassification(Data('', '', '00:01:00.000',
      ParticipantStatusToDbValue(Status)), GROUPS[Status], pbrNone);
    AssertClassification(Data('', '', '', ' ' +
      ParticipantStatusToDbValue(Status) + #9), GROUPS[Status], pbrNone);
  end;
end;

procedure TProtocolBalanceTests.GlobalDsq_OverridesStageStatusAndResult;
var
  StageStatus: string;
begin
  for StageStatus in ['', '1', '2', '3', 'unknown'] do
  begin
    AssertClassification(Data('', '', '00:01:00.000', StageStatus, '3'),
      pbgDSQ, pbrNone);
    AssertClassification(Data('', '', 'broken', StageStatus, ' 3 '),
      pbgDSQ, pbrNone);
  end;
end;

procedure TProtocolBalanceTests.GlobalDnsAndDnf_DoNotPropagateToOtherStages;
var
  GlobalStatus: string;
begin
  for GlobalStatus in ['1', '2'] do
  begin
    AssertClassification(Data('', '', '00:01:00.000', '', GlobalStatus),
      pbgWithResult, pbrNone);
    AssertClassification(Data('', '', '', '', GlobalStatus),
      pbgUnresolved, pbrNoStageData);
    AssertClassification(Data('', '', '', '3', GlobalStatus), pbgDSQ, pbrNone);
  end;
end;

procedure TProtocolBalanceTests.UnknownStageStatus_OverridesNumericResult;
var
  StageStatus: string;
begin
  for StageStatus in ['unknown', '0', '4', 'DNS'] do
    AssertClassification(Data('', '12:00:00.000', '00:01:00.000', StageStatus),
      pbgUnresolved, pbrUnknownStageStatus, True);
end;

procedure TProtocolBalanceTests.TerminalGroups_KeepIndependentFinishWithoutStartFlag;
begin
  AssertClassification(Data('', '12:00:00.000', '00:01:00.000'),
    pbgWithResult, pbrNone, True);
  AssertClassification(Data('', '12:00:00.000', '', '1'),
    pbgDNS, pbrNone, True);
  AssertClassification(Data('', '12:00:00.000', '', '', '3'),
    pbgDSQ, pbrNone, True);
end;

procedure TProtocolBalanceTests.Summarize_EmptyInputHasZeroCounts;
var
  Summary: TProtocolBalanceSummary;
  Group: TProtocolBalanceGroup;
begin
  Summary := SummarizeProtocolBalance([]);
  AssertEquals(0, Summary.ParticipantCount);
  AssertEquals(0, Summary.FinishWithoutStartCount);
  for Group := Low(TProtocolBalanceGroup) to High(TProtocolBalanceGroup) do
    AssertEquals(0, Summary.GroupCounts[Group]);
end;

procedure TProtocolBalanceTests.Summarize_GroupsAreExclusiveAndMatchFilters;
const
  GROUP_FILTERS: array[TProtocolBalanceGroup] of TProtocolBalanceFilter =
    (pbfUnresolved, pbfWithResult, pbfDNS, pbfDNF, pbfDSQ);
var
  Classifications: array[0..7] of TProtocolBalanceClassification;
  Summary: TProtocolBalanceSummary;
  Group: TProtocolBalanceGroup;
  Filter: TProtocolBalanceFilter;
  I, Count, GroupTotal, MatchingGroups: integer;
begin
  Classifications[0] := ClassifyProtocolBalance(Data('', '', '00:01:00.000'));
  Classifications[1] := ClassifyProtocolBalance(Data('', '12:00:00', '', '1'));
  Classifications[2] := ClassifyProtocolBalance(Data('', '', '', '2'));
  Classifications[3] := ClassifyProtocolBalance(Data('', '', '', '', '3'));
  Classifications[4] := ClassifyProtocolBalance(Data);
  Classifications[5] := ClassifyProtocolBalance(Data('12:00:00'));
  Classifications[6] := ClassifyProtocolBalance(Data('', '12:00:00'));
  Classifications[7] := ClassifyProtocolBalance(Data('', '12:00:00', '', '?'));

  Summary := SummarizeProtocolBalance(Classifications);
  AssertEquals(8, Summary.ParticipantCount);
  AssertEquals(4, Summary.GroupCounts[pbgUnresolved]);
  AssertEquals(3, Summary.FinishWithoutStartCount);
  GroupTotal := 0;
  for Group := Low(TProtocolBalanceGroup) to High(TProtocolBalanceGroup) do
  begin
    Count := 0;
    for I := Low(Classifications) to High(Classifications) do
      if MatchesProtocolBalanceFilter(Classifications[I], GROUP_FILTERS[Group]) then
        Inc(Count);
    AssertEquals('Detail count matches summary', Summary.GroupCounts[Group], Count);
    Inc(GroupTotal, Count);
  end;
  AssertEquals(Summary.ParticipantCount, GroupTotal);

  for I := Low(Classifications) to High(Classifications) do
  begin
    AssertTrue(MatchesProtocolBalanceFilter(Classifications[I], pbfAll));
    MatchingGroups := 0;
    for Group := Low(TProtocolBalanceGroup) to High(TProtocolBalanceGroup) do
      if MatchesProtocolBalanceFilter(Classifications[I], GROUP_FILTERS[Group]) then
        Inc(MatchingGroups);
    AssertEquals('Exactly one outcome per participant', 1, MatchingGroups);
  end;

  for Filter in [pbfAll, pbfFinishWithoutStart] do
  begin
    Count := 0;
    for I := Low(Classifications) to High(Classifications) do
      if MatchesProtocolBalanceFilter(Classifications[I], Filter) then
        Inc(Count);
    if Filter = pbfAll then
      AssertEquals(Summary.ParticipantCount, Count)
    else
      AssertEquals(Summary.FinishWithoutStartCount, Count);
  end;
end;

procedure TProtocolBalanceTests.Summarize_DoesNotAccumulateBetweenCalls;
var
  Summary: TProtocolBalanceSummary;
begin
  Summary := SummarizeProtocolBalance([ClassifyProtocolBalance(Data)]);
  AssertEquals(1, Summary.ParticipantCount);
  Summary := SummarizeProtocolBalance(
    [ClassifyProtocolBalance(Data('', '', '00:01:00.000'))]);
  AssertEquals(1, Summary.ParticipantCount);
  AssertEquals(0, Summary.GroupCounts[pbgUnresolved]);
  AssertEquals(1, Summary.GroupCounts[pbgWithResult]);
end;

procedure TProtocolBalanceTests.Classification_IsIndependentOfSystemLocale;
var
  SavedSettings: TFormatSettings;
begin
  SavedSettings := DefaultFormatSettings;
  try
    DefaultFormatSettings.TimeSeparator := '/';
    DefaultFormatSettings.DecimalSeparator := ',';
    DefaultFormatSettings.ShortTimeFormat := 'h/nn AM/PM';
    AssertClassification(Data('', '', '01:02:03.456'), pbgWithResult, pbrNone);
    AssertClassification(Data('', '', '01:02:03,456'),
      pbgUnresolved, pbrMissingOrInvalidResult);
  finally
    DefaultFormatSettings := SavedSettings;
  end;
end;

procedure TProtocolBalanceTests.Classification_PreservesOriginalInput;
var
  Input: TProtocolBalanceStageInput;
begin
  Input := Data(' 00:00:00.000 ', '', ' DNF ', ' unknown ', ' 1 ');
  AssertClassification(Input, pbgUnresolved, pbrUnknownStageStatus);
  AssertEquals(' 00:00:00.000 ', Input.StartTime);
  AssertEquals('', Input.FinishTime);
  AssertEquals(' DNF ', Input.ResultValue);
  AssertEquals(' unknown ', Input.StageStatusValue);
  AssertEquals(' 1 ', Input.GlobalStatusValue);
end;

initialization
  RegisterTest(TProtocolBalanceTests);

end.
