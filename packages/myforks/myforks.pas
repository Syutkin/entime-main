{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit MyForks;

{$warn 5023 off : no warning about unused units}
interface

uses
  MyRxDBGrid, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('MyRxDBGrid', @MyRxDBGrid.Register);
end;

initialization
  RegisterPackage('MyForks', @Register);
end.
