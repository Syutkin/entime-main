unit test_validators;

{$mode ObjFPC}{$H+}

interface

uses
  fpcunit, testregistry;

type
  TValidatorsTests = class(TTestCase)
  private
    procedure AssertValidTime(const AValue, AExpectedValue: string);
    procedure AssertInvalidTime(const AValue: string);
    procedure AssertValidDuration(const AValue, AExpectedValue: string);
    procedure AssertInvalidDuration(const AValue: string);
  published
    procedure TryParseParticipantNumber_AcceptsPositiveIntegers;
    procedure TryParseParticipantNumber_RejectsInvalidValues;
    procedure TryNormalizeTime_AcceptsSupportedFormats;
    procedure TryNormalizeTime_TrimsOuterWhitespace;
    procedure TryNormalizeTime_RejectsInvalidStructure;
    procedure TryNormalizeTime_RejectsValuesOutsideTimeRange;
    procedure TryNormalizeDuration_AcceptsSupportedFormats;
    procedure TryNormalizeDuration_TrimsOuterWhitespace;
    procedure TryNormalizeDuration_RejectsHoursOutsideTimeRange;
    procedure TryNormalizeDuration_RejectsInvalidValues;
  end;

implementation

uses
  SysUtils, Validators;

procedure TValidatorsTests.TryParseParticipantNumber_AcceptsPositiveIntegers;
var
  number: integer;
begin
  AssertTrue(TryParseParticipantNumber('1', number));
  AssertEquals(1, number);

  AssertTrue(TryParseParticipantNumber(' 42 ', number));
  AssertEquals(42, number);

  AssertTrue(TryParseParticipantNumber(IntToStr(MaxInt), number));
  AssertEquals(MaxInt, number);
end;

procedure TValidatorsTests.TryParseParticipantNumber_RejectsInvalidValues;
var
  number: integer;
begin
  AssertFalse(TryParseParticipantNumber('', number));
  AssertEquals(0, number);

  AssertFalse(TryParseParticipantNumber('text', number));
  AssertEquals(0, number);

  AssertFalse(TryParseParticipantNumber('12x', number));
  AssertEquals(0, number);

  AssertFalse(TryParseParticipantNumber('0', number));
  AssertEquals(0, number);

  AssertFalse(TryParseParticipantNumber('-1', number));
  AssertEquals(0, number);

  AssertFalse(TryParseParticipantNumber('999999999999999999999', number));
  AssertEquals(0, number);
end;

procedure TValidatorsTests.AssertValidTime(const AValue,
  AExpectedValue: string);
var
  normalizedValue: string;
begin
  AssertTrue('Expected valid time: ' + AValue,
    TryNormalizeTime(AValue, normalizedValue));
  AssertEquals(AExpectedValue, normalizedValue);
end;

procedure TValidatorsTests.AssertInvalidTime(const AValue: string);
var
  normalizedValue: string;
begin
  normalizedValue := 'previous value';
  AssertFalse('Expected invalid time: ' + AValue,
    TryNormalizeTime(AValue, normalizedValue));
  AssertEquals('', normalizedValue);
end;

procedure TValidatorsTests.AssertValidDuration(
  const AValue, AExpectedValue: string);
var
  normalizedValue: string;
begin
  AssertTrue('Expected valid duration: ' + AValue,
    TryNormalizeDuration(AValue, normalizedValue));
  AssertEquals(AExpectedValue, normalizedValue);
end;

procedure TValidatorsTests.AssertInvalidDuration(const AValue: string);
var
  normalizedValue: string;
begin
  normalizedValue := 'previous value';
  AssertFalse('Expected invalid duration: ' + AValue,
    TryNormalizeDuration(AValue, normalizedValue));
  AssertEquals('', normalizedValue);
end;

procedure TValidatorsTests.TryNormalizeTime_AcceptsSupportedFormats;
begin
  AssertValidTime('09:15', '09:15');
  AssertValidTime('09:15:42', '09:15:42');
  AssertValidTime('09:15:42,123', '09:15:42.123');
  AssertValidTime('09:15:42.123', '09:15:42.123');
  AssertValidTime('00:00:00.000', '00:00:00.000');
  AssertValidTime('23:59:59.999', '23:59:59.999');
end;

procedure TValidatorsTests.TryNormalizeTime_TrimsOuterWhitespace;
begin
  AssertValidTime(' 09:15:42,123 ', '09:15:42.123');
end;

procedure TValidatorsTests.TryNormalizeTime_RejectsInvalidStructure;
begin
  AssertInvalidTime('');
  AssertInvalidTime('9:15');
  AssertInvalidTime('09:5');
  AssertInvalidTime('09-15');
  AssertInvalidTime('09:15:');
  AssertInvalidTime('09:15:42.12');
  AssertInvalidTime('09:15:42.1234');
  AssertInvalidTime('09:15:42;123');
  AssertInvalidTime('09:15:42.+12');
  AssertInvalidTime('+1:00');
  AssertInvalidTime('text');
end;

procedure TValidatorsTests.TryNormalizeTime_RejectsValuesOutsideTimeRange;
begin
  AssertInvalidTime('24:00');
  AssertInvalidTime('12:60');
  AssertInvalidTime('12:00:60');
  AssertInvalidTime('-1:00');
end;

procedure TValidatorsTests.TryNormalizeDuration_AcceptsSupportedFormats;
begin
  AssertValidDuration('1', '00:00:01');
  AssertValidDuration('09', '00:00:09');
  AssertValidDuration('59', '00:00:59');
  AssertValidDuration('05:30', '00:05:30');
  AssertValidDuration('00:05:30', '00:05:30');
  AssertValidDuration('01:05:30', '01:05:30');
  AssertValidDuration('1:05:30', '01:05:30');
  AssertValidDuration('23:59:59', '23:59:59');
end;

procedure TValidatorsTests.TryNormalizeDuration_TrimsOuterWhitespace;
begin
  AssertValidDuration(' 7 ', '00:00:07');
  AssertValidDuration(' 05:30 ', '00:05:30');
  AssertValidDuration(' 23:05:30 ', '23:05:30');
end;

procedure TValidatorsTests.TryNormalizeDuration_RejectsHoursOutsideTimeRange;
begin
  AssertInvalidDuration('24:00:00');
  AssertInvalidDuration('25:05:30');
  AssertInvalidDuration('123:59:59');
end;

procedure TValidatorsTests.TryNormalizeDuration_RejectsInvalidValues;
begin
  AssertInvalidDuration('');
  AssertInvalidDuration('text');
  AssertInvalidDuration('0');
  AssertInvalidDuration('00');
  AssertInvalidDuration('60');
  AssertInvalidDuration('001');
  AssertInvalidDuration('+1');
  AssertInvalidDuration('5:30');
  AssertInvalidDuration('05:3');
  AssertInvalidDuration('60:00');
  AssertInvalidDuration('05:60');
  AssertInvalidDuration('01:60:00');
  AssertInvalidDuration('01:00:60');
  AssertInvalidDuration('-1:00:00');
  AssertInvalidDuration('01:05:30.125');
  AssertInvalidDuration('01:05:30,125');
  AssertInvalidDuration('01:00:00:00');
end;

initialization
  RegisterTest(TValidatorsTests);

end.
