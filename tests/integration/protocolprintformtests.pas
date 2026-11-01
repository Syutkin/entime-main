unit ProtocolPrintFormTests;
{$mode objfpc}{$H+}
interface

uses fpcunit, testregistry;

type
  TProtocolPrintFormTests = class(TTestCase)
  published
    procedure NeutralDocumentOpensSavesAndCloses;
  end;

implementation

uses Classes, SysUtils, Forms, Controls, LCLType, ProtocolPrintForm, ProtocolDocumentModel,
  CompetitionDbContext, StageModel, GuiTestSupport, FileUtil;

type
  TClockForm = class(TProtocolPrintForm)
  protected
    function ReadProtocol(ReloadCategories: boolean): TProtocolReadOutcome; override;
    function DefaultFilePrefix: string; override;
  end;

function TClockForm.DefaultFilePrefix: string;
begin
  Result := 'clock';
end;

function TClockForm.ReadProtocol(ReloadCategories: boolean): TProtocolReadOutcome;
begin
  Result := Default(TProtocolReadOutcome);
  Result.State := prsReady;
  Result.Snapshot := TProtocolDocument.Create;
  Result.Snapshot.Labels := ProtocolLabels(rlRussian);
  Result.Snapshot.Heading := 'Start';
  SetLength(Result.Snapshot.Columns, 1);
  Result.Snapshot.Columns[0].Caption := 'Старт';
  Result.Snapshot.Columns[0].Role := pcrTime;
  Result.Snapshot.Columns[0].Width := 190;
  SetLength(Result.Snapshot.Rows, 1);
  SetLength(Result.Snapshot.Rows[0].Cells, 1);
  Result.Snapshot.Rows[0].Cells[0] := '00:00:00.123';
end;

procedure TProtocolPrintFormTests.NeutralDocumentOpensSavesAndCloses;
var
  F: TClockForm;
  C: TCompetitionDbContext;
  S: TStages;
  Gui: TGuiTestSession;
  Dir, Ext: string;
begin
  C := TCompetitionDbContext.Create;
  C.OpenFile(':memory:');
  S := TStages.Create(1);
  Gui := TGuiTestSession.Create;
  F := TClockForm.Create(nil);
  Dir := GetTempFileName;
  DeleteFile(Dir);
  ForceDirectories(Dir);
  try
    F.Configure(C, S, 1, rlRussian);
    F.Show;
    Gui.Drain('Open neutral protocol');
    AssertTrue(F.SaveButton.Enabled);
    AssertEquals('00:00:00.123', F.Protocol.Rows[0].Cells[0]);
    for Ext in ['.pdf', '.docx', '.xlsx'] do
      AssertTrue(Ext + ': ' + F.LastError, F.SaveTo(Dir + '/clock' + Ext));
    F.CloseButton.SetFocus;
    Gui.Drain('Close neutral protocol');
    Gui.PressKey(F.CloseButton, VK_ESCAPE);
    AssertFalse(F.Visible);
    F.Show;
    Gui.Drain('Reopen neutral protocol');
    AssertTrue(F.SaveButton.Enabled);
    F.EndSession;
    AssertFalse(F.SaveTo(Dir + '/closed.pdf'));
  finally
    F.Free;
    Gui.Free;
    S.Free;
    C.Free;
    DeleteDirectory(Dir, False);
  end;
end;

initialization
  RegisterTest(TProtocolPrintFormTests);
end.
