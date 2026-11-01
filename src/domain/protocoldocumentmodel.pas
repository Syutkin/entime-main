unit ProtocolDocumentModel;
{$mode objfpc}{$H+}
interface

uses ReportTemplateModel;

type
  TReportLanguage = (rlRussian, rlEnglish);
  TReportOrientation = (roPortrait, roLandscape);
  TReportCategories = array of string;

  TProtocolViewOptions = record
    StageIndex: integer;
    AllCategories, IncludeMissing, ShowHeadings, ShowHeader, ShowFooter: boolean;
    Categories: TReportCategories;
    Orientation: TReportOrientation;
    Language: TReportLanguage;
  end;
  TProtocolReadState = (prsReady, prsEmpty, prsBusy, prsSessionChanged,
    prsError, prsNoStages);
  TProtocolColumnRole = (pcrText, pcrNumber, pcrTime);

  TProtocolColumn = record
    Caption, GroupCaption: string;
    StageIndex: integer;
    Role: TProtocolColumnRole;
    Width: single;
  end;
  TProtocolColumns = array of TProtocolColumn;
  TProtocolCells = array of string;

  TProtocolRow = record
    Id, Number: integer;
    Category: string;
    Cells: TProtocolCells;
  end;
  TProtocolRows = array of TProtocolRow;

  TProtocolOptions = record
    Landscape, ShowHeadings, ShowHeader, ShowFooter, FitToWidth, HideCategories: boolean;
    TableFontSize: integer;
  end;

  TProtocolLabels = record
    Title, Competition, NoCategory, Page, OfPages: string;
  end;

  TProtocolDocument = class;
  TProtocolDocuments = array of TProtocolDocument;

  TProtocolDocument = class
  private
    FTemplate: TReportTemplate;
    function GetTemplate: TReportTemplate;
    procedure SetTemplate(const Value: TReportTemplate);
  public
    ContextIdentity, SessionGeneration: QWord;
    StageSignature, RaceName, Heading: string;
    FormedAt: TDateTime;
    Options: TProtocolOptions;
    Labels: TProtocolLabels;
    Columns: TProtocolColumns;
    Rows: TProtocolRows;
    Sections: TProtocolDocuments;
    SheetName: string;
    destructor Destroy; override;
    property Template: TReportTemplate read GetTemplate write SetTemplate;
  end;

  TProtocolReadOutcome = record
    State: TProtocolReadState;
    Snapshot: TProtocolDocument;
    ErrorText: string;
  end;
  TProtocolWidths = array of single;

function ProtocolFontSize(const D: TProtocolDocument): integer;
function ProtocolWidths(const D: TProtocolDocument): TProtocolWidths;

function DefaultProtocolViewOptions: TProtocolViewOptions;
function ProtocolLabels(Language: TReportLanguage): TProtocolLabels;

implementation

destructor TProtocolDocument.Destroy;
var
  D: TProtocolDocument;
begin
  for D in Sections do D.Free;
  inherited Destroy;
end;

function ProtocolFontSize(const D: TProtocolDocument): integer;
begin
  Result := D.Options.TableFontSize;
  if Result <= 0 then Result := 8;
end;

function DefaultProtocolViewOptions: TProtocolViewOptions;
begin
  Result := Default(TProtocolViewOptions);
  Result.StageIndex := 1;
  Result.AllCategories := True;
  Result.IncludeMissing := True;
  Result.ShowHeadings := True;
  Result.ShowHeader := True;
  Result.ShowFooter := True;
end;

function ProtocolLabels(Language: TReportLanguage): TProtocolLabels;
begin
  Result := Default(TProtocolLabels);
  if Language = rlEnglish then
  begin
    Result.Competition := 'Competition';
    Result.NoCategory := 'No category';
    Result.Page := 'Page';
    Result.OfPages := 'of';
  end
  else
  begin
    Result.Competition := 'Соревнование';
    Result.NoCategory := 'Без категории';
    Result.Page := 'Страница';
    Result.OfPages := 'из';
  end;
end;

function TProtocolDocument.GetTemplate: TReportTemplate;
begin
  Result := CloneReportTemplate(FTemplate);
end;

procedure TProtocolDocument.SetTemplate(const Value: TReportTemplate);
begin
  FTemplate := CloneReportTemplate(Value);
end;

function ProtocolWidths(const D: TProtocolDocument): TProtocolWidths;
var
  I: integer;
begin
  Result := nil;
  SetLength(Result, Length(D.Columns));
  for I := 0 to High(Result) do Result[I] := D.Columns[I].Width;
end;

end.
