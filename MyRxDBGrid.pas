unit MyRxDBGrid;

{$mode objfpc}{$H+}

interface

uses
  Classes, RxDBGrid;

type
  TMyRxDBGrid = class(TRxDBGrid)
  public
    function GetRow: Integer;
  end;

procedure Register;

implementation

function TMyRxDBGrid.GetRow: Integer;
begin
  Result := Row;
end;

procedure Register;
begin
  RegisterComponents('MyForks', [TMyRxDBGrid]);
end;

end.
