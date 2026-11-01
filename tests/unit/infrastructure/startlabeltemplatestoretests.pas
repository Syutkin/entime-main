unit StartLabelTemplateStoreTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry, StartLabelTemplateStore;

type
  TStartLabelTemplateStoreTests = class(TTestCase)
  private
    Dir: string;
    Store: TStartLabelTemplateStore;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure FractionalSizesKeepExactFileNames;
    procedure MissingDirectoryAndSafeCreation;
    procedure ListingSortsNamesAndKeepsBrokenFiles;
    procedure SavingPreservesNameAndIgnoresFirstSlot;
    procedure FailedReplacePreservesFileAndRemovesTemp;
    procedure MissingFileCannotBeSilentlyRecreated;
  end;

implementation

uses FileUtil, StartLabelModel, StartLabelTemplates, StageFinishReportFiles;

type
  TFailReplace = class(TStageReportFiles)
    procedure Replace(const Temp, Target: string); override;
  end;

procedure TFailReplace.Replace(const Temp, Target: string);
begin
  raise EWriteError.Create('replace failed');
end;

procedure TStartLabelTemplateStoreTests.SetUp;
begin
  Dir := GetTempFileName;
  DeleteFile(Dir);
  Store := TStartLabelTemplateStore.Create(Dir);
end;

procedure TStartLabelTemplateStoreTests.TearDown;
begin
  Store.Free;
  if DirectoryExists(Dir) then DeleteDirectory(Dir, False);
end;

procedure TStartLabelTemplateStoreTests.FractionalSizesKeepExactFileNames;
var
  P: TStartLabelPaper;
  A: TStartLabelTemplate;
  F: TFormatSettings;
begin
  P := DefaultStartLabelPaper;
  P.Height := 37125;
  F := DefaultFormatSettings;
  DefaultFormatSettings.DecimalSeparator := ',';
  try
    A := Store.CreateTemplate('Точный размер', P);
    AssertEquals('70x37.125.ini', A.FileName);
    AssertEquals(37125, Store.Load(A.FileName).Paper.Height);
    A := Store.CreateTemplate('Тот же размер', P);
    AssertEquals('70x37.125-2.ini', A.FileName);
  finally
    DefaultFormatSettings := F;
  end;
end;

procedure TStartLabelTemplateStoreTests.MissingDirectoryAndSafeCreation;
var
  A, B: TStartLabelTemplate;
begin
  AssertEquals(0, Length(Store.List));
  A := Store.CreateTemplate('Первый', DefaultStartLabelPaper);
  B := Store.CreateTemplate('Второй', DefaultStartLabelPaper);
  AssertEquals('70x37.ini', A.FileName);
  AssertEquals('70x37-2.ini', B.FileName);
  AssertEquals('Первый', Store.Load(A.FileName).Name);
  AssertEquals(2, Length(Store.List));
end;

procedure TStartLabelTemplateStoreTests.ListingSortsNamesAndKeepsBrokenFiles;
var
  A, B: TStartLabelTemplate;
  L: TStartLabelTemplateFiles;
  S: TStringList;
begin
  A := Store.CreateTemplate('Z', DefaultStartLabelPaper);
  B := Store.CreateTemplate('A', DefaultStartLabelPaper);
  Store.CreateTemplate('A', DefaultStartLabelPaper);
  S := TStringList.Create;
  try
    S.Text := '[StartLabels]' + LineEnding + 'Width=broken';
    S.SaveToFile(Dir + '/broken.ini');
    S.SaveToFile(Dir + '/ignore.txt');
  finally
    S.Free;
  end;
  L := Store.List;
  AssertEquals(4, Length(L));
  AssertEquals(B.FileName, L[0].FileName);
  AssertEquals('70x37-3.ini', L[1].FileName);
  AssertEquals(A.FileName, L[2].FileName);
  AssertEquals('broken', L[3].Name);
  try
    Store.Load('broken.ini');
    Fail('Broken file accepted');
  except
    on E: EStartLabelTemplate do ;
  end;
end;

procedure TStartLabelTemplateStoreTests.SavingPreservesNameAndIgnoresFirstSlot;
var
  A: TStartLabelTemplate;
  P: TStartLabelPaper;
begin
  P := DefaultStartLabelPaper;
  A := Store.CreateTemplate('Лист', P);
  P.FirstSlot := 20;
  P.StartColumns := 2;
  P.DrawBorders := True;
  A := Store.Save(A.FileName, P);
  AssertEquals('Лист', A.Name);
  AssertEquals(1, A.Paper.FirstSlot);
  AssertEquals(2, A.Paper.StartColumns);
  AssertTrue(A.Paper.DrawBorders);
end;

procedure TStartLabelTemplateStoreTests.FailedReplacePreservesFileAndRemovesTemp;
var
  A: TStartLabelTemplate;
  P: TStartLabelPaper;
  Files: TFailReplace;
  Failed: TStartLabelTemplateStore;
  Search: TSearchRec;
begin
  P := DefaultStartLabelPaper;
  A := Store.CreateTemplate('Original', P);
  P.FontSize := 12;
  Files := TFailReplace.Create;
  Failed := TStartLabelTemplateStore.Create(Dir, Files);
  try
    try
      Failed.Save(A.FileName, P);
      Fail('Expected failed replace');
    except
      on E: EWriteError do ;
    end;
    AssertEquals(9, Store.Load(A.FileName).Paper.FontSize);
    AssertEquals('Original', Store.Load(A.FileName).Name);
    if FindFirst(Dir + '/.entime-report-*', faAnyFile, Search) = 0 then
    begin
      FindClose(Search);
      Fail('Temporary file leaked');
    end;
  finally
    Failed.Free;
    Files.Free;
  end;
end;

procedure TStartLabelTemplateStoreTests.MissingFileCannotBeSilentlyRecreated;
var
  A: TStartLabelTemplate;
begin
  A := Store.CreateTemplate('Test', DefaultStartLabelPaper);
  DeleteFile(Dir + '/' + A.FileName);
  try
    Store.Save(A.FileName, DefaultStartLabelPaper);
    Fail('Missing file recreated');
  except
    on E: EStartLabelTemplate do ;
  end;
  AssertFalse(FileExists(Dir + '/' + A.FileName));
end;

initialization
  RegisterTest(TStartLabelTemplateStoreTests);
end.
