unit LoRa;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, Sqlite3DS, Forms, Controls, Graphics, Dialogs,
  rxdbgrid, i18n, DBGrids, Menus, ActnList, Clipbrd;

type

  { TLoRaForm }

  TLoRaForm = class(TForm)
    AcCopy: TAction;
    ActionList1: TActionList;
    DataSourceLoRa: TDataSource;
    MenuItemCopy: TMenuItem;
    PopupMenu1: TPopupMenu;
    RxDBGridLoRa: TRxDBGrid;
    Sqlite3DatasetLoRa: TSqlite3Dataset;
    procedure AcCopyExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

procedure RunLoRa;

var
  LoRaForm: TLoRaForm;

implementation

uses Main, Implement;

procedure RunLoRa;
begin
  with TLoRaForm.Create(Application) do
  begin
    try
      ShowModal;
    finally
      Free;
    end;
  end;
end;

{$R *.lfm}

{ TLoRaForm }

procedure TLoRaForm.FormCreate(Sender: TObject);
begin
  Sqlite3DatasetLoRa.FileName := fName;
  try
    Sqlite3DatasetLoRa.Open;
  except
    On E: Exception do
    begin
      MessageDlg(sDatabaseOpenError + E.Message, mtError, [mbOK], 0);
      Log(sDatabaseOpenError + E.Message);
    end;
  end;
end;

procedure TLoRaForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Sqlite3DatasetLoRa.Close;
end;

procedure TLoRaForm.AcCopyExecute(Sender: TObject);
begin
  if dbopen and not Sqlite3DatasetLoRa.IsEmpty then
  begin
    Clipboard.AsText := Sqlite3DatasetLoRa.FieldByName(RxDBGridLoRa.SelectedColumn.FieldName).AsString;
  end;
end;

end.
