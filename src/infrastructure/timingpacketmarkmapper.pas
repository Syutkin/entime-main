unit TimingPacketMarkMapper;

{$mode ObjFPC}{$H+}

interface

uses
  TimingProtocol, TimingMark;

function TimingMarkFromTimingPacket(const APacket: TTimingPacket;
  const ASource: TTimingMarkSource; const AReceivedAt: TDateTime): TTimingMark;

implementation

function TimingMarkFromTimingPacket(const APacket: TTimingPacket;
  const ASource: TTimingMarkSource; const AReceivedAt: TDateTime): TTimingMark;
begin
  case APacket.Kind of
    tpkStart:
      Result := TTimingMark.Start(APacket.EventTime, APacket.HasCorrection,
        APacket.CorrectionMs, ASource, AReceivedAt);
    tpkFinish:
      Result := TTimingMark.Finish(APacket.EventTime, ASource, AReceivedAt);
  end;
end;

end.
