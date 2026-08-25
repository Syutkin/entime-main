unit ParticipantStatusTests;

{$mode ObjFPC}{$H+}

interface

uses
  fpcunit, testregistry, ParticipantStatus;

type
  TParticipantStatusTests = class(TTestCase)
  published
    procedure Mappings_ReturnStableDatabaseValuesAndTokens;
    procedure Parser_AcceptsTokensCodesWhitespaceAndEmptyValue;
    procedure Parser_RejectsUnsupportedValues;
    procedure DatabaseParser_AcceptsOnlyDatabaseRepresentation;
    procedure GlobalStatus_PreservesManualDsq;
    procedure GlobalStatus_UsesOnlyActiveStages;
    procedure GlobalStatus_UsesExistingStageRules;
  end;

implementation

procedure TParticipantStatusTests.Mappings_ReturnStableDatabaseValuesAndTokens;
begin
  AssertEquals('', ParticipantStatusToDbValue(psNone));
  AssertEquals('1', ParticipantStatusToDbValue(psDNS));
  AssertEquals('2', ParticipantStatusToDbValue(psDNF));
  AssertEquals('3', ParticipantStatusToDbValue(psDSQ));

  AssertEquals('', ParticipantStatusToToken(psNone));
  AssertEquals('DNF', ParticipantStatusToToken(psDNF));
  AssertEquals('DNS', ParticipantStatusToToken(psDNS));
  AssertEquals('DSQ', ParticipantStatusToToken(psDSQ));
end;

procedure TParticipantStatusTests.Parser_AcceptsTokensCodesWhitespaceAndEmptyValue;
var
  status: TParticipantStatus;
begin
  AssertTrue(TryParseParticipantStatus('', status));
  AssertEquals(Ord(psNone), Ord(status));
  AssertTrue(TryParseParticipantStatus(' dnf ', status));
  AssertEquals(Ord(psDNF), Ord(status));
  AssertTrue(TryParseParticipantStatus('1', status));
  AssertEquals(Ord(psDNS), Ord(status));
  AssertTrue(TryParseParticipantStatus('DsQ', status));
  AssertEquals(Ord(psDSQ), Ord(status));
end;

procedure TParticipantStatusTests.Parser_RejectsUnsupportedValues;
var
  status: TParticipantStatus;
begin
  AssertFalse(TryParseParticipantStatus('0', status));
  AssertFalse(TryParseParticipantStatus('4', status));
  AssertFalse(TryParseParticipantStatus('retired', status));
  AssertEquals(Ord(psNone), Ord(status));
end;

procedure TParticipantStatusTests.DatabaseParser_AcceptsOnlyDatabaseRepresentation;
var
  status: TParticipantStatus;
begin
  AssertTrue(TryParticipantStatusFromDbValue('3', status));
  AssertEquals(Ord(psDSQ), Ord(status));
  AssertFalse(TryParticipantStatusFromDbValue('DSQ', status));
  AssertEquals(Ord(psNone), Ord(status));
end;

procedure TParticipantStatusTests.GlobalStatus_PreservesManualDsq;
var
  StageStatuses: array[0..1] of TParticipantStatus;
  ActiveStages: array[0..1] of integer;
begin
  StageStatuses[0] := psNone;
  StageStatuses[1] := psDNF;
  ActiveStages[0] := 1;
  ActiveStages[1] := 2;

  AssertEquals(Ord(psDSQ), Ord(DeriveGlobalParticipantStatus(psDSQ,
    StageStatuses, ActiveStages)));
end;

procedure TParticipantStatusTests.GlobalStatus_UsesOnlyActiveStages;
var
  StageStatuses: array[0..2] of TParticipantStatus;
  ActiveStages: array[0..0] of integer;
begin
  StageStatuses[0] := psNone;
  StageStatuses[1] := psDNF;
  StageStatuses[2] := psNone;
  ActiveStages[0] := 3;

  AssertEquals(Ord(psNone), Ord(DeriveGlobalParticipantStatus(psNone,
    StageStatuses, ActiveStages)));
end;

procedure TParticipantStatusTests.GlobalStatus_UsesExistingStageRules;
var
  StageStatuses: array[0..2] of TParticipantStatus;
  ActiveStages: array[0..2] of integer;
begin
  ActiveStages[0] := 1;
  ActiveStages[1] := 2;
  ActiveStages[2] := 3;

  StageStatuses[0] := psDNS;
  StageStatuses[1] := psNone;
  StageStatuses[2] := psNone;
  AssertEquals(Ord(psDNS), Ord(DeriveGlobalParticipantStatus(psNone,
    StageStatuses, ActiveStages)));

  StageStatuses[0] := psDNF;
  AssertEquals(Ord(psDNF), Ord(DeriveGlobalParticipantStatus(psNone,
    StageStatuses, ActiveStages)));

  StageStatuses[0] := psNone;
  StageStatuses[2] := psDSQ;
  AssertEquals(Ord(psDNF), Ord(DeriveGlobalParticipantStatus(psNone,
    StageStatuses, ActiveStages)));

  StageStatuses[2] := psNone;
  AssertEquals(Ord(psNone), Ord(DeriveGlobalParticipantStatus(psDNF,
    StageStatuses, ActiveStages)));
end;

initialization
  RegisterTest(TParticipantStatusTests);

end.
