unit BleTimingUi;
{$mode objfpc}{$H+}
interface

uses SysUtils, LazBleTypes, LazBleClient, LazBleComponent, LazBleLclScan;

type
  TBleTimingConnectionAction = (lbcaNone, lbcaConnect, lbcaDisconnect);

function BleTimingDeviceText(const AClient: TLazBleLclClient): string;
function BleTimingStatusText(const AClient: TLazBleLclClient): string;
function BleTimingCanSelectDevice(const AClient: TLazBleLclClient): boolean;
function BleTimingConnectionAction(
  const AClient: TLazBleLclClient): TBleTimingConnectionAction;
function BleTimingConnectionActionText(const AClient: TLazBleLclClient): string;

implementation

uses i18n;

function BleTimingDeviceText(const AClient: TLazBleLclClient): string;
begin
  if not Assigned(AClient) then
    Exit(rsBleNoClient);
  if AClient.DeviceName <> '' then
    Exit(AClient.DeviceName);
  if AClient.DeviceId <> '' then
    Exit(AClient.DeviceId);
  Result := rsBleNoDevice;
end;

function BleTimingStatusText(const AClient: TLazBleLclClient): string;
begin
  if not Assigned(AClient) then
    Exit('');
  if Assigned(AClient.LazBle) then
  begin
    case AClient.LazBle.Availability of
      lbaChecking: Exit(rsBleChecking);
      lbaUnavailable:
        if AClient.LazBle.LastErrorMessage <> '' then
          Exit(Format(rsBleUnavailableDetail,
            [AClient.LazBle.LastErrorMessage]))
        else
          Exit(rsBleUnavailable);
    end;
    if AClient.LazBle.ScanState = lblssScanning then
      Exit(rsBleScanning);
  end;
  case AClient.State of
    lbcstDisconnected: Result := rsBleDisconnected;
    lbcstConnecting: Result := rsBleConnecting;
    lbcstAttachingProfiles: Result := rsBleProfiles;
    lbcstReady: Result := rsBleConnected;
    lbcstWaitingToReconnect: Result := rsBleWaiting;
    lbcstDisconnecting: Result := rsBleDisconnecting;
    lbcstError:
      if AClient.LastErrorMessage <> '' then
        Result := Format(rsBleErrorDetail, [AClient.LastErrorMessage])
      else
        Result := rsBleError;
  end;
end;

function BleTimingCanStartNewOperation(const AClient: TLazBleLclClient): boolean;
begin
  Result := Assigned(AClient) and Assigned(AClient.LazBle) and
    (AClient.LazBle.Availability in [lbaUnknown, lbaAvailable]) and
    (AClient.LazBle.ScanState <> lblssScanning);
end;

function BleTimingCanSelectDevice(const AClient: TLazBleLclClient): boolean;
begin
  Result := BleTimingCanStartNewOperation(AClient) and
    (AClient.State in [lbcstDisconnected, lbcstError]);
end;

function BleTimingConnectionAction(const AClient: TLazBleLclClient):
TBleTimingConnectionAction;
begin
  Result := lbcaNone;
  if not Assigned(AClient) or not Assigned(AClient.LazBle) then
    Exit;
  if AClient.State in [lbcstConnecting, lbcstAttachingProfiles,
    lbcstReady, lbcstWaitingToReconnect] then
    Exit(lbcaDisconnect);
  if (AClient.DeviceId <> '') and BleTimingCanStartNewOperation(AClient) and
    (AClient.State in [lbcstDisconnected, lbcstError]) then
    Result := lbcaConnect;
end;

function BleTimingConnectionActionText(const AClient: TLazBleLclClient): string;
begin
  if (BleTimingConnectionAction(AClient) = lbcaDisconnect) or
    (Assigned(AClient) and (AClient.State = lbcstDisconnecting)) then
    Result := rsBleDisconnect
  else
    Result := rsBleConnect;
end;

end.
