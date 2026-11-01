unit SerialDeviceProvider;

{$mode ObjFPC}{$H+}

interface

uses
  LazSerialDevices;

type
  TSerialDevicesProvider = function: TSerialDeviceInfoArray;

function ReadSerialDevices: TSerialDeviceInfoArray;
function SerialDeviceIsAvailable(const ADevice: string;
  const ADevices: TSerialDeviceInfoArray): boolean;
procedure SetSerialDevicesProvider(const AProvider: TSerialDevicesProvider);
procedure ResetSerialDevicesProvider;

implementation

{$IFDEF UNIX}
uses
  BaseUnix;
{$ENDIF}

var
  SerialDevicesProvider: TSerialDevicesProvider = nil;

function ReadSerialDevices: TSerialDeviceInfoArray;
begin
  if Assigned(SerialDevicesProvider) then
    Result := SerialDevicesProvider()
  else
    Result := GetSerialDevices;
end;

function SerialDeviceIsAvailable(const ADevice: string;
  const ADevices: TSerialDeviceInfoArray): boolean;
  {$IFDEF UNIX}
var
  DeviceInfo: Stat;
  {$ENDIF}
begin
  Result := (ADevice <> '') and ContainsSerialDevice(ADevices, ADevice);
  {$IFDEF UNIX}
  if not Result and (ADevice <> '') then
  begin
    DeviceInfo := Default(Stat);
    Result := (fpStat(PChar(ADevice), DeviceInfo) = 0) and
      fpS_ISCHR(DeviceInfo.st_mode);
  end;
  {$ENDIF}
end;

procedure SetSerialDevicesProvider(const AProvider: TSerialDevicesProvider);
begin
  SerialDevicesProvider := AProvider;
end;

procedure ResetSerialDevicesProvider;
begin
  SerialDevicesProvider := nil;
end;

end.
