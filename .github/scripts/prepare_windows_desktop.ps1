$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class EntimeTestDesktop {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct Mode {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        public ushort SpecVersion, DriverVersion, Size, DriverExtra;
        public uint Fields;
        public int PositionX, PositionY;
        public uint DisplayOrientation, DisplayFixedOutput;
        public short Color, Duplex, YResolution, TTOption, Collate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string FormName;
        public ushort LogPixels;
        public uint BitsPerPel, Width, Height, DisplayFlags, DisplayFrequency;
        public uint ICMMethod, ICMIntent, MediaType, DitherType;
        public uint Reserved1, Reserved2, PanningWidth, PanningHeight;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool EnumDisplaySettings(string device, int number, ref Mode mode);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int ChangeDisplaySettings(ref Mode mode, uint flags);
    public static Mode Current() {
        Mode mode = new Mode();
        mode.Size = (ushort)Marshal.SizeOf(typeof(Mode));
        if (!EnumDisplaySettings(null, -1, ref mode))
            throw new InvalidOperationException("Could not read desktop display mode.");
        return mode;
    }
    public static int Resize(uint width, uint height) {
        Mode mode = Current();
        mode.Fields = 0x00180000;
        mode.Width = width;
        mode.Height = height;
        return ChangeDisplaySettings(ref mode, 0);
    }
}
'@
$mode = [EntimeTestDesktop]::Current()
Write-Host "Windows GUI desktop before tests: $($mode.Width)x$($mode.Height), $($mode.BitsPerPel) bpp"
if ($mode.Width -lt 1600 -or $mode.Height -lt 1000) {
    $result = [EntimeTestDesktop]::Resize(1920, 1080)
    if ($result -ne 0) { throw "Could not set GUI test display mode: ChangeDisplaySettings=$result" }
    $mode = [EntimeTestDesktop]::Current()
}
Write-Host "Windows GUI desktop selected: $($mode.Width)x$($mode.Height)"
if ($mode.Width -lt 1600 -or $mode.Height -lt 1000) {
    throw 'The Windows GUI runner desktop is too small for the interactive test session.'
}
