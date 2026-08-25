unit TimingMarkJournalUi;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, DB;

function TimingMarkDiagnosticPreview(const AText: string): string;
procedure CopyTimingMarkFieldToClipboard(const AField: TField);
procedure ShowTimingMarkDiagnostic(const AOwner: TComponent;
  const AText, ACaption: string);

implementation

uses
  Forms, Controls, StdCtrls, ButtonPanel, LazUTF8, SysUtils, Clipbrd;

const
  DIAGNOSTIC_PREVIEW_LENGTH = 120;

function TimingMarkDiagnosticPreview(const AText: string): string;
begin
  Result := StringReplace(AText, #13#10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  if UTF8Length(Result) > DIAGNOSTIC_PREVIEW_LENGTH then
    Result := UTF8Copy(Result, 1, DIAGNOSTIC_PREVIEW_LENGTH) + '...';
end;

procedure CopyTimingMarkFieldToClipboard(const AField: TField);
begin
  if Assigned(AField) then
    Clipboard.AsText := AField.AsString;
end;

procedure ShowTimingMarkDiagnostic(const AOwner: TComponent;
  const AText, ACaption: string);
var
  Buttons: TButtonPanel;
  DialogForm: TForm;
  DiagnosticMemo: TMemo;
begin
  DialogForm := TForm.CreateNew(AOwner);
  try
    DialogForm.BorderStyle := bsSizeable;
    DialogForm.Caption := ACaption;
    DialogForm.ClientHeight := 420;
    DialogForm.ClientWidth := 720;
    DialogForm.Position := poMainFormCenter;

    Buttons := TButtonPanel.Create(DialogForm);
    Buttons.Parent := DialogForm;
    Buttons.Align := alBottom;
    Buttons.ShowButtons := [pbClose];

    DiagnosticMemo := TMemo.Create(DialogForm);
    DiagnosticMemo.Parent := DialogForm;
    DiagnosticMemo.Align := alClient;
    DiagnosticMemo.BorderSpacing.Around := 8;
    DiagnosticMemo.ReadOnly := True;
    DiagnosticMemo.ScrollBars := ssAutoBoth;
    DiagnosticMemo.WordWrap := False;
    DiagnosticMemo.Text := AText;
    DialogForm.ActiveControl := DiagnosticMemo;

    DialogForm.ShowModal;
  finally
    DialogForm.Free;
  end;
end;

end.
