unit StageSettingsFrame;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls;

type

  { TStageSettingsFrame }

  TStageSettingsFrame = class(TFrame)
    ActiveCheckBox: TCheckBox;
    StageLabel: TLabel;
    StageNameEdit: TEdit;
    procedure ControlChange(Sender: TObject);
  private
    FStageIndex: integer;
    FOnStageChange: TNotifyEvent;
    function GetActive: boolean;
    function GetStageName: string;
    procedure SetActive(const AValue: boolean);
    procedure SetStageName(const AValue: string);
  public
    procedure Configure(const AStageIndex: integer; const AStageName: string;
      const AActive: boolean);
    procedure UpdateTranslation;
    property StageIndex: integer read FStageIndex;
    property Active: boolean read GetActive write SetActive;
    property StageName: string read GetStageName write SetStageName;
    property OnStageChange: TNotifyEvent read FOnStageChange write FOnStageChange;
  end;

implementation

uses
  i18n;

{$R *.lfm}

{ TStageSettingsFrame }

procedure TStageSettingsFrame.ControlChange(Sender: TObject);
begin
  if Assigned(FOnStageChange) then
    FOnStageChange(Self);
end;

function TStageSettingsFrame.GetActive: boolean;
begin
  Result := ActiveCheckBox.Checked;
end;

function TStageSettingsFrame.GetStageName: string;
begin
  Result := StageNameEdit.Text;
end;

procedure TStageSettingsFrame.SetActive(const AValue: boolean);
begin
  ActiveCheckBox.Checked := AValue;
end;

procedure TStageSettingsFrame.SetStageName(const AValue: string);
begin
  StageNameEdit.Text := AValue;
end;

procedure TStageSettingsFrame.Configure(const AStageIndex: integer;
  const AStageName: string; const AActive: boolean);
begin
  if AStageIndex < 1 then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Stage index must be positive, got %d.', [AStageIndex]);
  FStageIndex := AStageIndex;
  UpdateTranslation;
  StageName := AStageName;
  Active := AActive;
end;

procedure TStageSettingsFrame.UpdateTranslation;
begin
  if FStageIndex > 0 then
    StageLabel.Caption := Format(rsSUFormat, [FStageIndex])
  else
    StageLabel.Caption := rsSU;
end;

end.
