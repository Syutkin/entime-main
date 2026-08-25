unit TimingMark;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils;

type
  TTimingMarkKind = (tmkStart, tmkFinish);
  TTimingMarkSourceKind = (tmskSerial, tmskBle, tmskManual);

  { TTimingMarkSource }

  TTimingMarkSource = record
    Kind: TTimingMarkSourceKind;
    DeviceId: string;
    class function Serial(const ADeviceId: string): TTimingMarkSource; static;
    class function Ble(const ADeviceId: string): TTimingMarkSource; static;
    class function Manual: TTimingMarkSource; static;
  end;

  { TTimingMark }

  TTimingMark = record
    Kind: TTimingMarkKind;
    EventTime: TDateTime;
    HasCorrection: boolean;
    CorrectionMs: integer;
    Source: TTimingMarkSource;
    ReceivedAt: TDateTime;
    class function Start(const AEventTime: TDateTime;
      const AHasCorrection: boolean; const ACorrectionMs: integer;
      const ASource: TTimingMarkSource;
      const AReceivedAt: TDateTime): TTimingMark; static;
    class function Finish(const AEventTime: TDateTime;
      const ASource: TTimingMarkSource;
      const AReceivedAt: TDateTime): TTimingMark; static;
  end;

implementation

function CreateSource(const AKind: TTimingMarkSourceKind;
  const ADeviceId: string): TTimingMarkSource;
begin
  Result := Default(TTimingMarkSource);
  Result.Kind := AKind;
  Result.DeviceId := ADeviceId;
end;

class function TTimingMarkSource.Serial(
  const ADeviceId: string): TTimingMarkSource;
begin
  Result := CreateSource(tmskSerial, ADeviceId);
end;

class function TTimingMarkSource.Ble(
  const ADeviceId: string): TTimingMarkSource;
begin
  Result := CreateSource(tmskBle, ADeviceId);
end;

class function TTimingMarkSource.Manual: TTimingMarkSource;
begin
  Result := CreateSource(tmskManual, '');
end;

class function TTimingMark.Start(const AEventTime: TDateTime;
  const AHasCorrection: boolean; const ACorrectionMs: integer;
  const ASource: TTimingMarkSource;
  const AReceivedAt: TDateTime): TTimingMark;
begin
  Result := Default(TTimingMark);
  Result.Kind := tmkStart;
  Result.EventTime := AEventTime;
  Result.HasCorrection := AHasCorrection;
  if AHasCorrection then
    Result.CorrectionMs := ACorrectionMs
  else
    Result.CorrectionMs := 0;
  Result.Source := ASource;
  Result.ReceivedAt := AReceivedAt;
end;

class function TTimingMark.Finish(const AEventTime: TDateTime;
  const ASource: TTimingMarkSource;
  const AReceivedAt: TDateTime): TTimingMark;
begin
  Result := Default(TTimingMark);
  Result.Kind := tmkFinish;
  Result.EventTime := AEventTime;
  Result.HasCorrection := False;
  Result.CorrectionMs := 0;
  Result.Source := ASource;
  Result.ReceivedAt := AReceivedAt;
end;

end.
