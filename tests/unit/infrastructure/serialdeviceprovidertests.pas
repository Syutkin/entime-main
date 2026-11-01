unit SerialDeviceProviderTests;

{$mode ObjFPC}{$H+}

interface

uses
  fpcunit, testregistry, LazSerialDevices, SerialDeviceProvider;

type
  TSerialDeviceProviderTests = class(TTestCase)
  protected
    procedure TearDown; override;
  published
    procedure Availability_FindsStructuredDeviceWithoutChangingSnapshot;
    procedure Availability_UsesNativeDeviceIdentityRule;
    procedure Availability_RejectsEmptyDeviceName;
    procedure DeviceAvailability_AcceptsCharacterDeviceOnlyOnUnix;
    procedure ProviderOverride_ReturnsStructuredSnapshotForEveryRefresh;
  end;

implementation

uses
  SysUtils;

var
  FakeProviderCallCount: integer = 0;
  FakeProviderValue: TSerialDeviceInfoArray = nil;

function SerialDevice(const ADevice: string; const AVendor: string = '';
  const AModel: string = ''; const ASerialShort: string = ''): TSerialDeviceInfo;
begin
  Result := Default(TSerialDeviceInfo);
  Result.Device := ADevice;
  Result.Vendor := AVendor;
  Result.Model := AModel;
  Result.SerialShort := ASerialShort;
end;

function FakeSerialDevicesProvider: TSerialDeviceInfoArray;
begin
  Inc(FakeProviderCallCount);
  Result := FakeProviderValue;
end;

procedure TSerialDeviceProviderTests.TearDown;
begin
  ResetSerialDevicesProvider;
  FakeProviderValue := nil;
  inherited TearDown;
end;

procedure TSerialDeviceProviderTests.
Availability_FindsStructuredDeviceWithoutChangingSnapshot;
var
  devices: TSerialDeviceInfoArray;
begin
  devices := nil;
  SetLength(devices, 2);
  devices[0] := SerialDevice('/dev/ttyACM0', 'Espressif', 'ESP32');
  devices[1] := SerialDevice('/dev/ttyUSB0', 'QinHeng', 'CH343');

  AssertTrue(SerialDeviceIsAvailable('/dev/ttyUSB0', devices));
  AssertFalse(SerialDeviceIsAvailable('/dev/ttyUSB1', devices));
  AssertEquals('Availability checks must not mutate the snapshot',
    2, Length(devices));
  AssertEquals('Espressif', devices[0].Vendor);
  AssertEquals('CH343', devices[1].Model);
end;

procedure TSerialDeviceProviderTests.Availability_UsesNativeDeviceIdentityRule;
var
  devices: TSerialDeviceInfoArray;
begin
  devices := nil;
  SetLength(devices, 1);
  devices[0] := SerialDevice('COM7');
  {$IFDEF Windows}
  AssertTrue(SerialDeviceIsAvailable('com7', devices));
  {$ELSE}
  AssertFalse(SerialDeviceIsAvailable('com7', devices));
  {$ENDIF}
end;

procedure TSerialDeviceProviderTests.Availability_RejectsEmptyDeviceName;
var
  devices: TSerialDeviceInfoArray;
begin
  devices := nil;
  SetLength(devices, 1);
  devices[0] := SerialDevice('COM1');
  AssertFalse(SerialDeviceIsAvailable('', devices));
end;

procedure TSerialDeviceProviderTests.
DeviceAvailability_AcceptsCharacterDeviceOnlyOnUnix;
var
  devices: TSerialDeviceInfoArray;
begin
  devices := nil;
  {$IFDEF UNIX}
  AssertTrue('An existing character device need not be enumerated',
    SerialDeviceIsAvailable('/dev/null', devices));
  AssertFalse('A regular file must not be accepted as a serial device',
    SerialDeviceIsAvailable(ParamStr(0), devices));
  {$ELSE}
  AssertFalse(SerialDeviceIsAvailable('COM_NOT_ENUMERATED', devices));
  {$ENDIF}
end;

procedure TSerialDeviceProviderTests.
ProviderOverride_ReturnsStructuredSnapshotForEveryRefresh;
var
  devices: TSerialDeviceInfoArray;
begin
  FakeProviderCallCount := 0;
  SetLength(FakeProviderValue, 1);
  FakeProviderValue[0] := SerialDevice('COM1', 'ENTime',
    'USB UART', 'ABC123');
  SetSerialDevicesProvider(@FakeSerialDevicesProvider);

  devices := ReadSerialDevices;
  AssertEquals(1, Length(devices));
  AssertEquals('COM1', devices[0].Device);
  AssertEquals('ENTime', devices[0].Vendor);
  AssertEquals('USB UART', devices[0].Model);
  AssertEquals('ABC123', devices[0].SerialShort);

  FakeProviderValue[0] := SerialDevice('COM3');
  devices := ReadSerialDevices;
  AssertEquals('COM3', devices[0].Device);
  AssertEquals(2, FakeProviderCallCount);
end;

initialization
  RegisterTest(TSerialDeviceProviderTests);

end.
