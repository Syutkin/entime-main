unit Result;

{$mode objfpc}{$H+}
{$IFOPT D+} {$DEFINE DEBUG} {$ENDIF}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Grids,
  ExtCtrls, rxdbgrid, DB, Sqlite3DS,
  sqlite3conn, sqldb, DBGrids;

type

  { TResultsForm }

  TResultsForm = class(TForm)
    CatDataset1diffleader: TStringField;
    CatDataset1name: TStringField;
    CatDataset1number: TLongintField;
    CatDataset1place: TLongintField;
    CatDataset1result: TStringField;
    CatDataset2diffleader: TStringField;
    CatDataset2name: TStringField;
    CatDataset2number: TLongintField;
    CatDataset2place: TLongintField;
    CatDataset2result: TStringField;
    CatDataset3diffleader: TStringField;
    CatDataset3name: TStringField;
    CatDataset3number: TLongintField;
    CatDataset3place: TLongintField;
    CatDataset3result: TStringField;
    CatDataset4diffleader: TStringField;
    CatDataset4name: TStringField;
    CatDataset4number: TLongintField;
    CatDataset4place: TLongintField;
    CatDataset4result: TStringField;
    CatDataset5diffleader: TStringField;
    CatDataset5name: TStringField;
    CatDataset5number: TLongintField;
    CatDataset5place: TLongintField;
    CatDataset5result: TStringField;
    CatDataset6diffleader: TStringField;
    CatDataset6name: TStringField;
    CatDataset6number: TLongintField;
    CatDataset6place: TLongintField;
    CatDataset6result: TStringField;
    CatDataSource1: TDataSource;
    CatDataSource2: TDataSource;
    CatDataSource3: TDataSource;
    CatDataSource4: TDataSource;
    CatDataSource5: TDataSource;
    CatDataSource6: TDataSource;
    ResultDatasetcategory: TStringField;
    ResultDatasetname: TStringField;
    ResultDatasetnumber: TLongintField;
    ResultDatasetplace: TLongintField;
    ResultDatasetresult: TStringField;
    ResultDataSource: TDataSource;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
    GroupBox5: TGroupBox;
    GroupBox6: TGroupBox;
    GroupBoxResults: TGroupBox;
    RxDBGridCat1: TRxDBGrid;
    RxDBGridCat2: TRxDBGrid;
    RxDBGridCat3: TRxDBGrid;
    RxDBGridCat4: TRxDBGrid;
    RxDBGridCat5: TRxDBGrid;
    RxDBGridCat6: TRxDBGrid;
    RxDBGridResults: TRxDBGrid;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    Splitter3: TSplitter;
    Splitter4: TSplitter;
    CatDataset1: TSqlite3Dataset;
    CatDataset2: TSqlite3Dataset;
    CatDataset3: TSqlite3Dataset;
    CatDataset4: TSqlite3Dataset;
    CatDataset5: TSqlite3Dataset;
    CatDataset6: TSqlite3Dataset;
    ResultDataset: TSqlite3Dataset;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);

    procedure ColorResultCells(Sender: TObject; DataCol: integer;
      Column: TColumn; AState: TGridDrawState);
    procedure HideZeroHour(Sender: TField; var aText: string; DisplayText: boolean);

  private

  public

  end;


var
  ResultsForm: TResultsForm;

implementation

uses Main, Implement;

  {$R *.lfm}

  { TResultsForm }

procedure TResultsForm.FormCreate(Sender: TObject);
begin
  if MainForm.AcViewResults.Checked then
    ResultsForm.Show;

  if FileExists(fName) then
  begin
    //OpenDB;
    InitDB(fName);
  end
  else
  begin
    LoadConfig;
    LoadIniCategory;
  end;
  FormResize(Sender);
end;

procedure TResultsForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  MainForm.AcViewResults.Checked := False;
end;

procedure TResultsForm.FormResize(Sender: TObject);
var
  w, i: integer;
begin
  w := ResultsForm.Width;
  GroupBoxResults.Width := round(w * 0.4);
  GroupBox1.Width := round(w * 0.6 / 2);
  GroupBox3.Width := round(w * 0.6 / 2);
  GroupBox5.Width := round(w * 0.6 / 2);

  w := RxDBGridResults.Width;
  RxDBGridResults.Columns[0].Width := round(w * 0.08);
  RxDBGridResults.Columns[1].Width := round(w * 0.5);
  RxDBGridResults.Columns[2].Width := round(w * 0.15);
  RxDBGridResults.Columns[3].Width := round(w * 0.2);
  RxDBGridResults.Columns[4].Width := round(w * 0.07);

  w := RxDBGridCat1.Width;
  for i := 1 to VISIBLECAT do
  begin
    (FindComponent('RxDBGridCat' + IntToStr(i)) as TRxDBGrid).Columns[0].Width :=
      round(w * 0.1);
    (FindComponent('RxDBGridCat' + IntToStr(i)) as TRxDBGrid).Columns[1].Width :=
      round(w * 0.4);
    (FindComponent('RxDBGridCat' + IntToStr(i)) as TRxDBGrid).Columns[2].Width :=
      round(w * 0.2);
    (FindComponent('RxDBGridCat' + IntToStr(i)) as TRxDBGrid).Columns[3].Width :=
      round(w * 0.2);
    (FindComponent('RxDBGridCat' + IntToStr(i)) as TRxDBGrid).Columns[4].Width :=
      round(w * 0.095);

  end;
end;

procedure TResultsForm.ColorResultCells(Sender: TObject; DataCol: integer;
  Column: TColumn; AState: TGridDrawState);
begin
  if ([gdSelected, gdFocused] * AState = []) then
  begin
    //чтобы не перекрашивать выделенную ячейку
    if (Column.FieldName = 'result') then
    begin
      case Column.Field.AsString of
        '': with (Sender as TRxDBGrid) do
            Canvas.Brush.Color := clWindow;
        'DSQ': with (Sender as TRxDBGrid) do
            Canvas.Brush.Color := clRed;
        'DNF': with (Sender as TRxDBGrid) do
            Canvas.Brush.Color := clYellow;
        'DNS': with (Sender as TRxDBGrid) do
            Canvas.Brush.Color := clGray;
      end;
    end;
  end;
end;

procedure TResultsForm.HideZeroHour(Sender: TField; var aText: string;
  DisplayText: boolean);
begin
  aText := HideLeadingZeroHour(Sender);
end;

end.
