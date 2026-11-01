unit StageFinishReportBackend;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpreport;

function ReportRegularFont: string;
function ReportBoldFont: string;
function ReportFontFamily: string;

type
  TPreparedStageReport = class
  private
    FReport: TFPReport;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Prepare;
    procedure WritePdf(const FileName: string); virtual;
    function PageCount: integer;
    function RuntimePage(Index: integer): TFPReportCustomPage;
    function PageText(Index: integer): string;
    property Report: TFPReport read FReport;
  end;

procedure LoadReportFonts;

implementation

uses fpTTF, fpreportpdfexport, fppdf
  {$IFDEF WINDOWS},Windows,Registry{$ENDIF};

type
  TReportAccess = class(TFPReport);

var
  FontFamily, RegularFace, BoldFace: string;

function AddFont(const Path: string): TFPFontCacheItem;
var
  Item: TFPFontCacheItem;
begin
  Item := TFPFontCacheItem.Create(Path);
  try
    Result := gTTFontCache.Find(Item.PostScriptName);
    if Result = nil then
    begin
      Result := Item;
      gTTFontCache.Add(Item);
      Item := nil;
    end;
  finally
    Item.Free;
  end;
end;
{$IFDEF LINUX}
// Fontconfig resolves the system's sans-serif alias, including user overrides.
function FcNameParse(Name:PChar):Pointer;cdecl;external 'fontconfig';
function FcConfigSubstitute(Config,Pattern:Pointer;Kind:integer):LongBool;cdecl;external 'fontconfig';
procedure FcDefaultSubstitute(Pattern:Pointer);cdecl;external 'fontconfig';
function FcFontMatch(Config,Pattern:Pointer;var Status:integer):Pointer;cdecl;external 'fontconfig';
function FcPatternGetString(Pattern:Pointer;Name:PChar;Index:integer;var Value:PChar):integer;cdecl;external 'fontconfig';
procedure FcPatternDestroy(Pattern:Pointer);cdecl;external 'fontconfig';
function SystemFontFile(const Name:string):string;
var Pattern,Match:Pointer;Status:integer;Path:PChar;
begin
 Pattern:=FcNameParse(PChar(Name));Match:=nil;
 if Pattern=nil then raise EFontNotFound.Create('Cannot resolve the system sans-serif font');
 try
  FcConfigSubstitute(nil,Pattern,0);FcDefaultSubstitute(Pattern);
  Match:=FcFontMatch(nil,Pattern,Status);
  if (Match=nil) or (Status<>0) then raise EFontNotFound.Create('System sans-serif font not found');
  if FcPatternGetString(Match,'file',0,Path)<>0 then raise EFontNotFound.Create('System font file not found');
  Result:=Path;
 finally if Match<>nil then FcPatternDestroy(Match);FcPatternDestroy(Pattern);end;
end;
{$ENDIF}
{$IFDEF WINDOWS}
procedure LoadWindowsFontFamily(const Family:string);
const Key='Software\Microsoft\Windows NT\CurrentVersion\Fonts';
 Roots:array[0..1] of HKEY=(HKEY_LOCAL_MACHINE,HKEY_CURRENT_USER);
var Registry:TRegistry;Names:TStringList;Root:HKEY;Name,Path:string;
begin
 Registry:=TRegistry.Create(KEY_READ);Names:=TStringList.Create;
 try
  // Absolute registrations also cover per-user fonts and Wine's system fonts.
  for Root in Roots do begin
   Registry.RootKey:=Root;
   if not Registry.OpenKeyReadOnly(Key) then Continue;
   try
    Names.Clear;Registry.GetValueNames(Names);
    for Name in Names do if SameText(Name,Family+' (TrueType)') or
     SameText(Name,Family+' Regular (TrueType)') or SameText(Name,Family+' Bold (TrueType)') then begin
     Path:=Registry.ReadString(Name);
     if not SameText(ExtractFileExt(Path),'.ttf') then Continue;
     if ExtractFileDrive(Path)='' then Path:=IncludeTrailingPathDelimiter(SysUtils.GetEnvironmentVariable('WINDIR'))+'Fonts\'+Path;
     if FileExists(Path) then AddFont(Path);
    end;
   finally Registry.CloseKey;end;
  end;
 finally Names.Free;Registry.Free;end;
end;
{$ENDIF}

procedure LoadReportFonts;
var
  Regular, Bold: TFPFontCacheItem;
  Family: string;
  {$IFDEF WINDOWS}
Metrics:TNonClientMetrics;
  {$ENDIF}
begin
  if FontFamily <> '' then Exit;
  {$IFDEF LINUX}
 Regular:=AddFont(SystemFontFile('sans-serif:weight=regular:slant=roman:fontformat=TrueType'));
 Family:=Regular.FamilyName;
 Bold:=AddFont(SystemFontFile(Family+':weight=bold:slant=roman:fontformat=TrueType'));
  {$ELSE}
  {$IFDEF WINDOWS}
 FillChar(Metrics,SizeOf(Metrics),0);Metrics.cbSize:=SizeOf(Metrics);
 if not SystemParametersInfo(SPI_GETNONCLIENTMETRICS,SizeOf(Metrics),@Metrics,0) then RaiseLastOSError;
 Family:=StrPas(Metrics.lfMessageFont.lfFaceName);LoadWindowsFontFamily(Family);
  {$ELSE}
  gTTFontCache.BuildFontCacheIgnoresErrors := True;
  gTTFontCache.ReadStandardFonts;
  Family := 'Helvetica';
  if gTTFontCache.Find(Family, False, False) = nil then Family := 'Arial';
  {$ENDIF}
  Regular := gTTFontCache.Find(Family, False, False);
  Bold := gTTFontCache.Find(Family, True, False);
  {$ENDIF}
  if (Regular = nil) or (Bold = nil) then
    raise EFontNotFound.Create('System regular and bold fonts not found: ' + Family);
  if Regular.IsBold or Regular.IsItalic or not Bold.IsBold or Bold.IsItalic or
    not SameText(Regular.FamilyName, Bold.FamilyName) then
    raise EFontNotFound.Create('System font has no matching regular and bold faces: ' +
      Family);
  RegularFace := Regular.PostScriptName;
  BoldFace := Bold.PostScriptName;
  FontFamily := Regular.FamilyName;
end;

function ReportRegularFont: string;
begin
  LoadReportFonts;
  Result := RegularFace;
end;

function ReportBoldFont: string;
begin
  LoadReportFonts;
  Result := BoldFace;
end;

function ReportFontFamily: string;
begin
  LoadReportFonts;
  Result := FontFamily;
end;

constructor TPreparedStageReport.Create;
begin
  inherited Create;
  LoadReportFonts;
  if PaperManager.IndexOfPaper('A4') < 0 then PaperManager.RegisterStandardSizes;
  FReport := TReportAccess.Create(nil);
end;

destructor TPreparedStageReport.Destroy;
begin
  FReport.Free;
  inherited Destroy;
end;

procedure TPreparedStageReport.Prepare;
var
  I: integer;
begin
  for I := 0 to TReportAccess(FReport).PageCount - 1 do
    if (TReportAccess(FReport).Pages[I].PageSize.Width <= 0) or
      (TReportAccess(FReport).Pages[I].PageSize.Height <= 0) then
      raise EArgumentException.Create('Report paper has no dimensions');
  FReport.RunReport;
end;

function TPreparedStageReport.PageCount: integer;
begin
  Result := TReportAccess(FReport).RTObjects.Count;
end;

function TPreparedStageReport.RuntimePage(Index: integer): TFPReportCustomPage;
begin
  if (Index < 0) or (Index >= PageCount) then
    raise EArgumentOutOfRangeException.Create('Report page');
  Result := TFPReportCustomPage(TReportAccess(FReport).RTObjects[Index]);
end;

function TPreparedStageReport.PageText(Index: integer): string;
var
  P: TFPReportCustomPage;
  I, J: integer;
  B: TFPReportCustomBand;
begin
  Result := '';
  P := RuntimePage(Index);
  for I := 0 to P.BandCount - 1 do
  begin
    B := P.Bands[I];
    for J := 0 to B.ChildCount - 1 do if B.Child[J] is TFPReportMemo then
        Result := Result + TFPReportMemo(B.Child[J]).Text + LineEnding;
  end;
end;

procedure TPreparedStageReport.WritePdf(const FileName: string);
var
  E: TFPReportExportPDF;
begin
  if not FReport.Prepared then raise EInvalidOperation.Create('Report is not prepared');
  E := TFPReportExportPDF.Create(nil);
  try
    E.FileName := FileName;
    E.Options := [poCompressText, poCompressFonts, poSubsetFont, poPageOriginAtTop, poUTF16info];
    FReport.RenderReport(E);
  finally
    E.Free;
  end;
end;

end.
