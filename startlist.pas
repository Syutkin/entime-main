unit Startlist;

{$mode objfpc}{$H+}

interface

uses
  Implement,
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  ButtonPanel, SpinEx, CheckBoxThemed, i18n, LCLTranslator, ExtCtrls;

type

  { TStartlistForm }

  TStartlistForm = class(TForm)
    ButtonPanel1: TButtonPanel;
    cbDNS: TCheckBoxThemed;
    cbDNF: TCheckBoxThemed;
    cbDSQ: TCheckBoxThemed;
    ComboBox1: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    ListBox1: TListBox;
    Panel1: TPanel;
    Panel2: TPanel;
    SpinEditEx1: TSpinEditEx;
    SpinEditEx2: TSpinEditEx;
    TimeEdit1: TTimeEdit;
    procedure FormCreate(Sender: TObject);
    procedure ListBox1DragDrop(Sender, Source: TObject; X, Y: integer);
    procedure ListBox1DragOver(Sender, Source: TObject; X, Y: integer; State: TDragState; var Accept: boolean);
    procedure ListBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure GenerateStartlist(startCatList: string; startTime: TDateTime; delayBetweenRacers: integer;
      delayBetweenCategories: integer; sortBy: StartListSortBy);
  private

  public

  end;



function RunStartlist(qualifier: boolean = False): boolean;

var
  StartlistForm: TStartlistForm;
  StartingPoint: TPoint;

implementation

uses Main{, Implement};

function RunStartlist(qualifier: boolean): boolean;
var
  sortBy: StartListSortBy;
begin
  Result := False;
  with TStartlistForm.Create(Application) do
  begin
    try
      if qualifier then
      begin
        ComboBox1.Items[0] := sQualificationResults;
        ComboBox1.Text := ComboBox1.Items[0];
        ComboBox1.Enabled := False;
      end
      else
      begin
        Label6.Visible := False;
        Panel1.Visible := False;
      end;

      ShowModal;

      if ModalResult = mrOk then
      begin
        Result := True;
        startTime := TimeEdit1.Time;
        delayBetweenRacers := SpinEditEx1.Value;
        delayBetweenCategories := SpinEditEx2.Value;
        if qualifier then
        begin
          sortBy := slByResult;
        end
        else
        begin
          case ComboBox1.ItemIndex of
            0: sortBy := slByNumberAsc;
            1: sortBy := slByNumberDesc;
            2: sortBy := slByNameAsc;
            3: sortBy := slByNameDesc;
          end;
        end;
        GenerateStartlist(ListBox1.Items.Text, startTime, delayBetweenRacers,
          delayBetweenCategories, sortBy);
        Log(sGenerateStartList + ': ' + ComboBox1.Text);
      end;
    finally
      Free;
    end;
  end;
end;




{$R *.lfm}

{ TStartlistForm }

procedure TStartlistForm.FormCreate(Sender: TObject);
var
  startlist: TStringList;
begin
  startlist := CatStartList;
  ListBox1.Items.Text := startlist.Text;
  startlist.Free;
  TimeEdit1.Time := startTime;
  SpinEditEx1.Value := delayBetweenRacers;
  SpinEditEx2.Value := delayBetweenCategories;
end;

procedure TStartlistForm.ListBox1DragDrop(Sender, Source: TObject; X, Y: integer);
var
  DropPosition, StartPosition: integer;
  DropPoint: TPoint;
begin
  DropPoint.X := X;
  DropPoint.Y := Y;
  with Source as TListBox do
  begin
    StartPosition := ItemAtPos(StartingPoint, True);
    DropPosition := ItemAtPos(DropPoint, True);
    Items.Move(StartPosition, DropPosition);
  end;
end;

procedure TStartlistForm.ListBox1DragOver(Sender, Source: TObject; X, Y: integer; State: TDragState;
  var Accept: boolean);
begin
  Accept := Source is TListBox;
end;

procedure TStartlistForm.ListBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  StartingPoint.X := X;
  StartingPoint.Y := Y;
end;

procedure TStartlistForm.GenerateStartlist(startCatList: string; startTime: TDateTime;
  delayBetweenRacers: integer; delayBetweenCategories: integer; sortBy: StartListSortBy);
var
  i, min, sec: integer;
  number: string;
  CatList: TStringList;
begin
  with MainForm.SQLQuery1 do
  begin
    try
      CatList := TStringList.Create;
      CatList.Text := startCatList;
      //удаляем текущее время старта, оставшееся от файла квалификации
      SQL.Text := ('UPDATE main SET starttime' + IntToStr(CurrentStage) + ' = NULL');
      ExecSQL;
      SQLTransaction.Commit;
      Close;
      MainForm.SQLTransaction1.Active := False;
      //для каждой категории делаем выборку и ставим время старта
      for i := 0 to CatList.Count - 1 do
      begin
        SQL.Clear;
        SQL.Text := 'SELECT number FROM main WHERE category IS "' + CatList.Strings[i] + '"';
        if sortBy = slByResult then
        begin
          SQL.Add('AND result' + IntToStr(CurrentStage) + ' NOTNULL');
          if not cbDNS.Checked then
            SQL.Add('AND result' + IntToStr(CurrentStage) + ' <> ''DNS''');
          if not cbDNF.Checked then
            SQL.Add('AND result' + IntToStr(CurrentStage) + ' <> ''DNF''');
          if not cbDSQ.Checked then
            SQL.Add('AND result' + IntToStr(CurrentStage) + ' <> ''DSQ''');
          SQL.Add('ORDER BY status DESC, place' + IntToStr(CurrentStage) + ' DESC');
        end;
        if sortBy = slByNumberAsc then
          SQL.Add('ORDER BY number ASC');
        if sortBy = slByNumberDesc then
          SQL.Add('ORDER BY number DESC');
        if sortBy = slByNameAsc then
          SQL.Add('ORDER BY name ASC');
        if sortBy = slByNameDesc then
          SQL.Add('ORDER BY name DESC');
        Open;
        while not EOF do
        begin
          number := Fields.Fields[0].AsString;
          Next;
          MainForm.SQLQuery2.SQL.Text :=
            'UPDATE main SET starttime' + IntToStr(CurrentStage) + ' = "' +
            FormatDateTime('hh:nn:ss', startTime) + '" WHERE number =' + number;
          MainForm.SQLQuery2.ExecSQL;
          min := delayBetweenRacers div 60;
          //кол-во минут
          sec := delayBetweenRacers - min * 60;
          startTime := startTime + EncodeTime(0, min, sec, 0);
        end;
        startTime := startTime + EncodeTime(0, delayBetweenCategories, 0, 0);
        Close;
        MainForm.SQLTransaction1.Active := False;
        MainForm.SQLQuery2.SQLTransaction.Commit;
        MainForm.SQLQuery2.Close;
        MainForm.SQLTransaction2.Active := False;
      end;

      UpdateResults;
      //а то не обновляло в основном окне

    finally
      CatList.Free;
    end;
  end;
end;

end.
