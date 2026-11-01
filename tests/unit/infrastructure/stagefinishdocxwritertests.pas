unit StageFinishDocxWriterTests;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, fpcunit, testregistry, DOM, StageFinishReportModel;

type
  TStageFinishDocxWriterTests = class(TTestCase)
  private
    S: TStageReportSnapshot;
    Dir, Target, Unpacked: string;
    procedure Extract;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure PageCounterUsesRightAlignedFooterCell;
    procedure CenterStylesRemainDistinctFromLeftAndRight;
    procedure PairedSignaturesAreAnEditableBorderlessRow;
    procedure OptionalPageHeaderAndBodyOrder;
    procedure TemplateParagraphsAreEditableBodyContent;
    procedure EditableTablesPreserveCompleteSavedRows;
    procedure OrientationFooterAndPenaltyOptions;
    procedure FailedReplacementPreservesTargetAndAllowsRetry;
    procedure InvalidSnapshotAndEmptyPathDoNotReplaceTarget;
  end;

implementation

uses ReportTemplateModel, StageFinishDocxWriter, StageFinishReportFiles,
  StageFinishReportBackend, StageFieldNames,
  zipper, XMLRead, FileUtil;

type
  TLockedReportFiles = class(TStageReportFiles)
    procedure Replace(const Temp, Target: string); override;
  end;

procedure TLockedReportFiles.Replace(const Temp, Target: string);
begin
  raise EInOutError.Create('Destination locked');
end;

function Count(const Root: TDOMElement; const Tag: string): integer;
var
  Nodes: TDOMNodeList;
begin
  Nodes := Root.GetElementsByTagName(Tag);
  try
    Result := Nodes.Count;
  finally
    Nodes.Free;
  end;
end;

function ReadText(const Path: string): string;
var
  F: TStringList;
begin
  F := TStringList.Create;
  try
    F.LoadFromFile(Path);
    Result := F.Text;
  finally
    F.Free;
  end;
end;

procedure TStageFinishDocxWriterTests.SetUp;
var
  I: integer;
begin
  Dir := GetTempFileName;
  DeleteFile(Dir);
  Dir := Dir + ' Протокол';
  ForceDirectories(Dir);
  Target := Dir + DirectorySeparator + 'Финиш.docx';
  Unpacked := Dir + DirectorySeparator + 'unpacked';
  S := TStageReportSnapshot.Create;
  S.Options := DefaultReportOptions;
  S.Labels := ReportLabels(rlRussian);
  S.RaceName := 'Гонка <&> [PageNo]';
  S.StageName := 'Лес';
  S.FormedAt := EncodeDate(2026, 10, 31);
  SetLength(S.Rows, 150);
  for I := 0 to High(S.Rows) do
  begin
    S.Rows[I].Number := I + 1;
    S.Rows[I].Name := 'Участник' + Format('%.4d', [I + 1]);
    S.Rows[I].Team := 'Команда & клуб';
    if I < 70 then S.Rows[I].Category := 'Категория A'
    else if I < 140 then S.Rows[I].Category := 'Категория B';
    S.Rows[I].Values[sfkResult] := '01:02:03.456';
    S.Rows[I].Values[sfkPlace] := IntToStr(I + 1);
    S.Rows[I].Values[sfkPenalty] := '00:00:05.000';
  end;
  S.Rows[0].Name := StringOfChar('X', 900) + 'Жю [PageNo] <&>';
  S.Rows[1].Values[sfkStatus] := '1';
  S.Rows[2].Values[sfkStatus] := '2';
  S.Rows[3].GlobalStatus := '3';
  S.Rows := SelectReportRows(S.Rows, S.Options);
end;

procedure TStageFinishDocxWriterTests.TearDown;
begin
  S.Free;
  DeleteDirectory(Dir, False);
end;

procedure TStageFinishDocxWriterTests.Extract;
var
  Z: TUnZipper;
begin
  DeleteDirectory(Unpacked, False);
  ForceDirectories(Unpacked);
  Z := TUnZipper.Create;
  try
    Z.FileName := Target;
    Z.OutputPath := Unpacked + DirectorySeparator;
    Z.UnZipAllFiles;
  finally
    Z.Free;
  end;
end;

procedure TStageFinishDocxWriterTests.EditableTablesPreserveCompleteSavedRows;
var
  D: TXMLDocument;
  Nodes: TDOMNodeList;
  I: integer;
  AllText, Cell: string;
  F: TSearchRec;
begin
  AssertTrue(SaveStageFinishDocx(S, Target));
  Extract;
  D := nil;
  ReadXMLFile(D, Unpacked + '/word/document.xml');
  try
    AssertEquals('One editable table per category', 3, Count(D.DocumentElement, 'w:tbl'));
    AssertEquals('One table row per rider and category column headings',
      153, Count(D.DocumentElement, 'w:tr'));
    AssertEquals(153 * 7, Count(D.DocumentElement, 'w:tc'));
    AssertEquals('No positioned text boxes', 0, Count(D.DocumentElement, 'w:txbxContent'));
    AssertEquals('No images instead of editable text', 0, Count(
      D.DocumentElement, 'w:drawing'));
    Nodes := D.DocumentElement.GetElementsByTagName('w:t');
    AllText := '';
    try
      for I := 0 to Nodes.Count - 1 do AllText := AllText + UTF8Encode(Nodes[I].TextContent) + #10;
    finally
      Nodes.Free;
    end;
    for I := 0 to High(S.Rows) do
    begin
      Cell := S.Rows[I].Cells[rcName];
      AssertTrue('Complete rider name ' + IntToStr(I), Pos(Cell, AllText) > 0);
      AssertTrue('Result or status', Pos(S.Rows[I].Cells[rcResult], AllText) > 0);
    end;
    AssertTrue(Pos('DNS', AllText) > 0);
    AssertTrue(Pos('DNF', AllText) > 0);
    AssertTrue(Pos('DSQ', AllText) > 0);
    AssertTrue(Pos('Без категории' + #10, AllText) > 0);
    AssertEquals('No participant counts in category captions', 0, Pos(
      'Категория A (70)', AllText));
    AssertTrue(Pos('Категория A' + #10 + S.Labels.Columns[rcPlace] + #10, AllText) > 0);
    AssertTrue(Pos('Категория B' + #10 + S.Labels.Columns[rcPlace] + #10, AllText) > 0);
  finally
    D.Free;
  end;
  ReadXMLFile(D, Unpacked + '/word/styles.xml');
  try
    Nodes := D.DocumentElement.GetElementsByTagName('w:rFonts');
    try
      AssertTrue('Document has font styles', Nodes.Count > 0);
      for I := 0 to Nodes.Count - 1 do
        AssertEquals('Use the system report font', ReportFontFamily,
          UTF8Encode(TDOMElement(Nodes[I]).GetAttribute('w:ascii')));
    finally
      Nodes.Free;
    end;
  finally
    D.Free;
  end;
  AssertEquals(0, FindFirst(Unpacked + '/word/header*.xml', faAnyFile, F));
  try
    ReadXMLFile(D, Unpacked + '/word/' + F.Name);
    try
      AssertEquals(0, Pos(S.RaceName, UTF8Encode(D.DocumentElement.TextContent)));
      AssertTrue(Pos(S.Labels.Title, UTF8Encode(D.DocumentElement.TextContent)) > 0);
    finally
      D.Free;
    end;
  finally
    FindClose(F);
  end;
  AssertEquals('Source row remains complete', 900 + Length('Жю [PageNo] <&>'),
    Length(S.Rows[0].Name));
end;

procedure TStageFinishDocxWriterTests.OrientationFooterAndPenaltyOptions;
var
  O, F, P: integer;
  D: TXMLDocument;
  R: TSearchRec;
  HasFooter: boolean;
  Styles, Text: string;
begin
  for O := 0 to 1 do for F := 0 to 1 do for P := 0 to 1 do
      begin
        S.Options.Orientation := TReportOrientation(O);
        S.Options.ShowFooter := F = 1;
        S.Options.ShowPenalty := P = 1;
        S.Options.Language := TReportLanguage(O);
        S.Labels := ReportLabels(S.Options.Language);
        AssertTrue(SaveStageFinishDocx(S, Target));
        Extract;
        D := nil;
        ReadXMLFile(D, Unpacked + '/word/document.xml');
        try
          AssertEquals(153 * (6 + P), Count(D.DocumentElement, 'w:tc'));
          AssertEquals('Repeating column headings', 3, Count(D.DocumentElement, 'w:tblHeader'));
          Text := UTF8Encode(D.DocumentElement.TextContent);
          AssertEquals(P = 1, Pos(S.Labels.Columns[rcPenalty], Text) > 0);
        finally
          D.Free;
        end;
        Styles := ReadText(Unpacked + '/word/document.xml');
        if O = 1 then AssertTrue(Pos('w:w="16838"', Styles) > 0)
        else
          AssertTrue(Pos('w:w="11906"', Styles) > 0);
        HasFooter := FindFirst(Unpacked + '/word/footer*.xml', faAnyFile, R) = 0;
        AssertEquals(F = 1, HasFooter);
        if HasFooter then
        begin
          try
            ReadXMLFile(D, Unpacked + '/word/' + R.Name);
            try
              Text := UTF8Encode(D.DocumentElement.TextContent);
              AssertTrue(Pos('2026-10-31 00:00:00', Text) > 0);
              AssertTrue(Pos('NUMPAGES', Text) > 0);
              AssertTrue(Pos(' PAGE ', Text) > 0);
            finally
              D.Free;
            end;
          finally
            FindClose(R);
          end;
        end;
        if GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') <> '' then
        begin
          Text := GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') +
            '/finish-docx-' + IntToStr(O) + '-' + IntToStr(F) + '-' + IntToStr(P) + '.docx';
          CopyFile(Target, Text);
        end;
      end;
end;

procedure TStageFinishDocxWriterTests.FailedReplacementPreservesTargetAndAllowsRetry;
var
  Files: TLockedReportFiles;
  Old: TStringList;
  Raised: boolean;
  R: TSearchRec;
  N: integer;
begin
  Old := TStringList.Create;
  try
    Old.Text := 'old document';
    Old.SaveToFile(Target);
  finally
    Old.Free;
  end;
  Files := TLockedReportFiles.Create;
  Raised := False;
  try
    try
      SaveStageFinishDocx(S, Target, Files);
    except
      on E: EInOutError do Raised := True;
    end;
  finally
    Files.Free;
  end;
  AssertTrue(Raised);
  AssertEquals('old document' + LineEnding, ReadText(Target));
  N := 0;
  if FindFirst(Dir + '/*', faAnyFile, R) = 0 then
  begin
    repeat
      if (R.Name <> '.') and (R.Name <> '..') then Inc(N);
    until FindNext(R) <> 0;
    FindClose(R);
  end;
  AssertEquals('No temporary files left', 1, N);
  AssertTrue(SaveStageFinishDocx(S, Target));
  Extract;
end;

procedure TStageFinishDocxWriterTests.InvalidSnapshotAndEmptyPathDoNotReplaceTarget;
var
  Raised: boolean;
  Old: TStringList;
begin
  AssertFalse(SaveStageFinishDocx(S, ''));
  AssertFalse(FileExists(Target));
  Raised := False;
  Old := TStringList.Create;
  try
    Old.Text := 'old document';
    Old.SaveToFile(Target);
  finally
    Old.Free;
  end;
  try
    SaveStageFinishDocx(nil, Target);
  except
    on E: EArgumentNilException do Raised := True;
  end;
  AssertTrue(Raised);
  AssertEquals('old document' + LineEnding, ReadText(Target));
  S.Rows := nil;
  Raised := False;
  try
    SaveStageFinishDocx(S, Target);
  except
    on E: EArgumentException do Raised := True;
  end;
  AssertTrue(Raised);
  AssertEquals('old document' + LineEnding, ReadText(Target));
end;

procedure TStageFinishDocxWriterTests.TemplateParagraphsAreEditableBodyContent;
var
  T: TReportTemplate;
  D: TXMLDocument;
  Text, Styles, Header: string;
  R: TSearchRec;
begin
  SetLength(T.Header, 3);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('ШАПКА [PageNo] & < >' + #10#10 +
    'Далее', 14, rpaRight);
  T.Header[1] := ReportParagraph('');
  T.Header[2] := ReportParagraph('Ещё абзац', 14, rpaRight);
  T.Footer[0] := ReportParagraph('=ПОДПИСЬ', 12);
  S.Template := T;
  AssertTrue(SaveStageFinishDocx(S, Target));
  Extract;
  D := nil;
  ReadXMLFile(D, Unpacked + '/word/document.xml');
  try
    Text := UTF8Encode(D.DocumentElement.TextContent);
    AssertTrue(Pos('ШАПКА [PageNo] & < >', Text) > 0);
    AssertTrue(Pos('ШАПКА', Text) < Pos('Категория A', Text));
    AssertTrue(Pos('Участник0150', Text) < Pos('=ПОДПИСЬ', Text));
    AssertEquals(2, Count(D.DocumentElement, 'w:br'));
    AssertEquals(3, Count(D.DocumentElement, 'w:tbl'));
    AssertEquals(153, Count(D.DocumentElement, 'w:tr'));
  finally
    D.Free;
  end;
  Styles := ReadText(Unpacked + '/word/styles.xml');
  AssertTrue(Pos('w:val="28"', Styles) > 0);
  AssertTrue(Pos('w:val="right"', Styles) > 0);
  AssertTrue('Template paragraph styles', Pos('Template 14 right', Styles) > 0);
  AssertEquals(0, FindFirst(Unpacked + '/word/header*.xml', faAnyFile, R));
  try
    Header := ReadText(Unpacked + '/word/' + R.Name);
    AssertEquals(0, Pos('ШАПКА', Header));
  finally
    FindClose(R);
  end;
  if GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') <> '' then
    CopyFile(Target, GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') +
      '/html-template.docx');
end;

procedure TStageFinishDocxWriterTests.OptionalPageHeaderAndBodyOrder;
var
  T: TReportTemplate;
  D: TXMLDocument;
  R: TSearchRec;
  Text, Header: string;
  H, BodyOn: integer;
  HasHeader: boolean;
begin
  SetLength(T.Header, 1);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('CUSTOMHEADER');
  T.Footer[0] := ReportParagraph('CUSTOMFOOTER');
  S.Template := T;
  for H := 0 to 1 do for BodyOn := 0 to 1 do
    begin
      S.Options.ShowHeader := H = 1;
      S.Options.ShowHeadings := BodyOn = 1;
      S.Options.ShowFooter := False;
      AssertTrue(SaveStageFinishDocx(S, Target));
      Extract;
      D := nil;
      ReadXMLFile(D, Unpacked + '/word/document.xml');
      try
        Text := UTF8Encode(D.DocumentElement.TextContent);
        AssertEquals(BodyOn = 1, Pos(S.RaceName, Text) > 0);
        if BodyOn = 1 then
        begin
          AssertTrue(Pos('CUSTOMHEADER', Text) < Pos(S.RaceName, Text));
          AssertTrue(Pos(S.RaceName, Text) < Pos('Категория A', Text));
        end;
        AssertTrue(Pos('Участник0150', Text) < Pos('CUSTOMFOOTER', Text));
        AssertEquals(BodyOn = 1, Pos(S.Labels.Title, Text) > 0);
      finally
        D.Free;
      end;
      HasHeader := FindFirst(Unpacked + '/word/header*.xml', faAnyFile, R) = 0;
      AssertEquals(H = 1, HasHeader);
      if HasHeader then
      try
        ReadXMLFile(D, Unpacked + '/word/' + R.Name);
        Header := UTF8Encode(D.DocumentElement.TextContent);
        D.Free;
        AssertTrue(Pos(S.Labels.Title, Header) > 0);
        AssertEquals(0, Pos(S.RaceName, Header));
      finally
        FindClose(R);
      end;
    end;
end;

procedure TStageFinishDocxWriterTests.PairedSignaturesAreAnEditableBorderlessRow;
var
  T: TReportTemplate;
  D: TXMLDocument;
  Rows, Tables: TDOMNodeList;
  I: integer;
  Found: boolean;
  Text: string;
  Borders: TDOMNode;
begin
  SetLength(T.Footer, 1);
  T.Footer[0] := ReportParagraphPair(ReportParagraph('JUDGETOKEN', 12),
    ReportParagraph('SECRETARYTOKEN', 10, rpaRight));
  S.Template := T;
  AssertTrue(SaveStageFinishDocx(S, Target));
  Extract;
  D := nil;
  ReadXMLFile(D, Unpacked + '/word/document.xml');
  try
    Found := False;
    Rows := D.DocumentElement.GetElementsByTagName('w:tr');
    try
      for I := 0 to Rows.Count - 1 do
      begin
        Text := UTF8Encode(Rows[I].TextContent);
        if (Pos('JUDGETOKEN', Text) > 0) and (Pos('SECRETARYTOKEN', Text) > 0) then Found := True;
      end;
    finally
      Rows.Free;
    end;
    AssertTrue('Both editable signatures occupy the same table row', Found);
    Tables := D.DocumentElement.GetElementsByTagName('w:tbl');
    try
      Borders := Tables[Tables.Count - 1].FindNode('w:tblPr').FindNode('w:tblBorders');
      AssertTrue(Borders <> nil);
      AssertEquals('The signature row has no table borders', 0, Count(
        TDOMElement(Borders), 'w:top'));
      AssertEquals(0, Count(TDOMElement(Borders), 'w:left'));
      AssertEquals(0, Count(TDOMElement(Borders), 'w:insideV'));
      Borders := Tables[Tables.Count - 1].PreviousSibling;
      while (Borders <> nil) and (Borders.NodeType <> ELEMENT_NODE) do
        Borders := Borders.PreviousSibling;
      AssertTrue(Borders <> nil);
      AssertEquals('Signature table remains separate from results', 'w:p',
        UTF8Encode(Borders.NodeName));
    finally
      Tables.Free;
    end;
  finally
    D.Free;
  end;
  if GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') <> '' then
    CopyFile(Target, GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') +
      '/paired-signatures.docx');
end;

procedure TStageFinishDocxWriterTests.CenterStylesRemainDistinctFromLeftAndRight;
var
  T: TReportTemplate;
  D, Styles: TXMLDocument;
  Paragraphs, StyleNodes: TDOMNodeList;
  I: integer;

  function AlignmentFor(const Text: string): string;
  var
    J, K: integer;
    StyleId: DOMString;
    Pr, Node: TDOMNode;
  begin
    Result := 'missing paragraph';
    for J := 0 to Paragraphs.Count - 1 do if UTF8Encode(Paragraphs[J].TextContent) = Text then
      begin
        Pr := Paragraphs[J].FindNode('w:pPr');
        if Pr = nil then Exit;
        Node := Pr.FindNode('w:pStyle');
        if Node = nil then Exit;
        StyleId := TDOMElement(Node).GetAttribute('w:val');
        for K := 0 to StyleNodes.Count - 1 do
          if TDOMElement(StyleNodes[K]).GetAttribute('w:styleId') = StyleId then
          begin
            Pr := StyleNodes[K].FindNode('w:pPr');
            if Pr = nil then Exit;
            Node := Pr.FindNode('w:jc');
            if Node = nil then Exit;
            Exit(UTF8Encode(TDOMElement(Node).GetAttribute('w:val')));
          end;
      end;
  end;

begin
  SetLength(T.Header, 3);
  SetLength(T.Footer, 1);
  T.Header[0] := ReportParagraph('LEFTTOKEN', 10, rpaLeft);
  T.Header[1] := ReportParagraph('CENTERWHOLE', 10, rpaCenter);
  T.Header[2] := ReportParagraph('RIGHTTOKEN', 10, rpaRight);
  T.Footer[0] := ReportParagraphPair(ReportParagraph('CENTERLEFT', 10, rpaCenter),
    ReportParagraph('CENTERRIGHT', 10, rpaCenter));
  S.Template := T;
  SetLength(S.Rows, 2);
  for I := 0 to 1 do S.Rows[I].Cells[rcName] := 'Participant ' + IntToStr(I + 1);
  AssertTrue(SaveStageFinishDocx(S, Target));
  Extract;
  D := nil;
  Styles := nil;
  try
    ReadXMLFile(D, Unpacked + '/word/document.xml');
    ReadXMLFile(Styles, Unpacked + '/word/styles.xml');
    Paragraphs := D.DocumentElement.GetElementsByTagName('w:p');
    StyleNodes := Styles.DocumentElement.GetElementsByTagName('w:style');
    try
      AssertEquals('left', AlignmentFor('LEFTTOKEN'));
      AssertEquals('center', AlignmentFor('CENTERWHOLE'));
      AssertEquals('right', AlignmentFor('RIGHTTOKEN'));
      AssertEquals('center', AlignmentFor('CENTERLEFT'));
      AssertEquals('center', AlignmentFor('CENTERRIGHT'));
    finally
      StyleNodes.Free;
      Paragraphs.Free;
    end;
  finally
    Styles.Free;
    D.Free;
  end;
  if GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') <> '' then
    CopyFile(Target, GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR') +
      '/template-center.docx');
end;

procedure TStageFinishDocxWriterTests.PageCounterUsesRightAlignedFooterCell;
var
  D, Styles: TXMLDocument;
  Tables, Cells, StyleNodes: TDOMNodeList;
  R: TSearchRec;
  O, L, I: integer;
  Pr, Node: TDOMNode;
  StyleId: DOMString;
  Text, Path: string;
  Found: boolean;
begin
  for O := 0 to 1 do for L := 0 to 1 do
    begin
      S.Options.Orientation := TReportOrientation(O);
      S.Options.Language := TReportLanguage(L);
      S.Labels := ReportLabels(S.Options.Language);
      AssertTrue(SaveStageFinishDocx(S, Target));
      Extract;
      D := nil;
      Styles := nil;
      AssertEquals(0, FindFirst(Unpacked + '/word/footer*.xml', faAnyFile, R));
      try
        ReadXMLFile(D, Unpacked + '/word/' + R.Name);
        ReadXMLFile(Styles, Unpacked + '/word/styles.xml');
        Tables := D.DocumentElement.GetElementsByTagName('w:tbl');
        Cells := D.DocumentElement.GetElementsByTagName('w:tc');
        StyleNodes := Styles.DocumentElement.GetElementsByTagName('w:style');
        try
          AssertEquals('A full-width footer separates date and page fields', 1, Tables.Count);
          AssertEquals(2, Cells.Count);
          Pr := Tables[0].FindNode('w:tblPr');
          Node := Pr.FindNode('w:tblW');
          AssertTrue(Node <> nil);
          AssertEquals('pct', UTF8Encode(TDOMElement(Node).GetAttribute('w:type')));
          AssertEquals('5000', UTF8Encode(TDOMElement(Node).GetAttribute('w:w')));
          for I := 0 to 1 do
          begin
            Pr := Cells[I].FindNode('w:tcPr').FindNode('w:tcMar');
            AssertEquals('Footer text reaches the left/right content edges',
              '0', UTF8Encode(TDOMElement(Pr.FindNode('w:start')).GetAttribute('w:w')));
            AssertEquals('0', UTF8Encode(TDOMElement(Pr.FindNode('w:end')).GetAttribute('w:w')));
          end;
          Text := UTF8Encode(Cells[0].TextContent);
          AssertTrue(Pos('2026-10-31 00:00:00', Text) > 0);
          AssertEquals(0, Pos(' PAGE ', Text));
          Text := UTF8Encode(Cells[1].TextContent);
          AssertTrue(Pos(S.Labels.Page, Text) > 0);
          AssertTrue(Pos(S.Labels.OfPages, Text) > 0);
          AssertTrue(Pos(' PAGE ', Text) > 0);
          AssertTrue(Pos('NUMPAGES', Text) > 0);
          AssertEquals(0, Pos('2026-10-31', Text));
          Pr := Cells[1].FindNode('w:p').FindNode('w:pPr');
          Node := Pr.FindNode('w:pStyle');
          StyleId := TDOMElement(Node).GetAttribute('w:val');
          Found := False;
          for I := 0 to StyleNodes.Count - 1 do
            if TDOMElement(StyleNodes[I]).GetAttribute('w:styleId') = StyleId then
            begin
              Pr := StyleNodes[I].FindNode('w:pPr');
              Node := Pr.FindNode('w:jc');
              AssertTrue(Node <> nil);
              AssertEquals('right', UTF8Encode(TDOMElement(Node).GetAttribute('w:val')));
              Found := True;
            end;
          AssertTrue('Page counter style is present and right aligned', Found);
        finally
          StyleNodes.Free;
          Cells.Free;
          Tables.Free;
        end;
      finally
        Styles.Free;
        D.Free;
        FindClose(R);
      end;
      Path := GetEnvironmentVariable('ENTIME_REPORT_ARTIFACT_DIR');
      if Path <> '' then CopyFile(Target, Path + '/footer-' + IntToStr(O) + '-' + IntToStr(L) + '.docx');
    end;
end;

initialization
  RegisterTest(TStageFinishDocxWriterTests);
end.
