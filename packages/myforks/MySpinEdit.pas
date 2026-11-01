unit MySpinEdit;

{$mode objfpc}{$H+}

interface

uses Classes, Controls, Spin, LMessages;

type
  {$IFNDEF LCLWIN32}
  TSpinStepState = record
    MouseValue, KeyValue: double;
    MouseActive, KeyActive: boolean;
  end;
  {$ENDIF}

  // OnStep reports arrow input; text editing and Value assignments do not fire it.
  TMyFloatSpinEdit = class(TFloatSpinEdit)
  private
    {$IFNDEF LCLWIN32}
    FStepState: TSpinStepState;
    {$ENDIF}
    FOnStep: TNotifyEvent;
  protected
    {$IFDEF LCLWIN32}
    procedure WndProc(var Message: TLMessage); override;
    {$ELSE}
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: integer); override;
    procedure KeyDown(var Key: word; Shift: TShiftState); override;
    procedure KeyUp(var Key: word; Shift: TShiftState); override;
    {$ENDIF}
    procedure DoStep; virtual;
  published
    property OnStep: TNotifyEvent read FOnStep write FOnStep;
  end;

  TMySpinEdit = class(TSpinEdit)
  private
    {$IFNDEF LCLWIN32}
    FStepState: TSpinStepState;
    {$ENDIF}
    FOnStep: TNotifyEvent;
  protected
    procedure EditingDone; override;
    {$IFDEF LCLWIN32}
    procedure WndProc(var Message: TLMessage); override;
    {$ELSE}
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: integer); override;
    procedure KeyDown(var Key: word; Shift: TShiftState); override;
    procedure KeyUp(var Key: word; Shift: TShiftState); override;
    {$ENDIF}
    procedure DoStep; virtual;
  published
    property OnStep: TNotifyEvent read FOnStep write FOnStep;
  end;

procedure Register;

implementation

uses LCLType, Math, SysUtils
  {$IFDEF LCLWIN32}, CommCtrl{$ENDIF};

{$IFNDEF LCLWIN32}
procedure BeginMouseStep(var State: TSpinStepState; Control: TCustomFloatSpinEdit;
  Button: TMouseButton);
begin
  State.MouseActive := Button = mbLeft;
  if State.MouseActive then State.MouseValue := Control.Value;
end;

function EndMouseStep(var State: TSpinStepState; Control: TCustomFloatSpinEdit;
  Button: TMouseButton): boolean;
begin
  Result := State.MouseActive and (Button = mbLeft) and not
    SameValue(State.MouseValue, Control.Value);
  State.MouseActive := False;
end;

procedure BeginKeyStep(var State: TSpinStepState; Control: TCustomFloatSpinEdit;
  Key: word);
begin
  if not (Key in [VK_UP, VK_DOWN]) or State.KeyActive then Exit;
  State.KeyActive := True;
  State.KeyValue := Control.Value;
end;

function EndKeyStep(var State: TSpinStepState; Control: TCustomFloatSpinEdit;
  Key: word): boolean;
begin
  Result := False;
  if not (Key in [VK_UP, VK_DOWN]) then Exit;
  Result := State.KeyActive and not SameValue(State.KeyValue, Control.Value);
  State.KeyActive := False;
end;
{$ENDIF}

{$IFDEF LCLWIN32}
function IsNativeStep(const Message: TLMessage): boolean;
begin
  // Win32 arrows use a buddy window, whose mouse events bypass the edit.
  Result := (Message.Msg = CN_NOTIFY) and (Message.LParam <> 0) and
    (PNMHdr(Message.LParam)^.code = UDN_DELTAPOS);
end;

procedure TMyFloatSpinEdit.WndProc(var Message: TLMessage);
var
  WasStep: boolean;
  OldValue: double;
begin
  WasStep := IsNativeStep(Message);
  if WasStep then OldValue := Value;
  inherited WndProc(Message);
  if WasStep and not SameValue(OldValue, Value) then DoStep;
end;
{$ELSE}

procedure TMyFloatSpinEdit.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: integer);
begin
  BeginMouseStep(FStepState, Self, Button);
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TMyFloatSpinEdit.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: integer);
var
  DidStep: boolean;
begin
  DidStep := EndMouseStep(FStepState, Self, Button);
  inherited MouseUp(Button, Shift, X, Y);
  if DidStep then DoStep;
end;

procedure TMyFloatSpinEdit.KeyDown(var Key: word; Shift: TShiftState);
begin
  BeginKeyStep(FStepState, Self, Key);
  inherited KeyDown(Key, Shift);
end;

procedure TMyFloatSpinEdit.KeyUp(var Key: word; Shift: TShiftState);
var
  DidStep: boolean;
begin
  DidStep := EndKeyStep(FStepState, Self, Key);
  inherited KeyUp(Key, Shift);
  if DidStep then DoStep;
end;
{$ENDIF}

procedure TMyFloatSpinEdit.DoStep;
begin
  if Assigned(FOnStep) then FOnStep(Self);
end;

procedure TMySpinEdit.EditingDone;
var
  Entered: integer;
begin
  if not ReadOnly and TryStrToInt(Trim(Text), Entered) and (Entered < MinValue) then
    Value := MinValue;
  inherited EditingDone;
end;

{$IFDEF LCLWIN32}
procedure TMySpinEdit.WndProc(var Message: TLMessage);
var
  WasStep: boolean;
  OldValue: double;
begin
  WasStep := IsNativeStep(Message);
  if WasStep then OldValue := Value;
  inherited WndProc(Message);
  if WasStep and not SameValue(OldValue, Value) then DoStep;
end;
{$ELSE}

procedure TMySpinEdit.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: integer);
begin
  BeginMouseStep(FStepState, Self, Button);
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TMySpinEdit.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var
  DidStep: boolean;
begin
  DidStep := EndMouseStep(FStepState, Self, Button);
  inherited MouseUp(Button, Shift, X, Y);
  if DidStep then DoStep;
end;

procedure TMySpinEdit.KeyDown(var Key: word; Shift: TShiftState);
begin
  BeginKeyStep(FStepState, Self, Key);
  inherited KeyDown(Key, Shift);
end;

procedure TMySpinEdit.KeyUp(var Key: word; Shift: TShiftState);
var
  DidStep: boolean;
begin
  DidStep := EndKeyStep(FStepState, Self, Key);
  inherited KeyUp(Key, Shift);
  if DidStep then DoStep;
end;
{$ENDIF}

procedure TMySpinEdit.DoStep;
begin
  if Assigned(FOnStep) then FOnStep(Self);
end;

procedure Register;
begin
  RegisterComponents('MyForks', [TMySpinEdit, TMyFloatSpinEdit]);
end;

initialization
  RegisterClasses([TMySpinEdit, TMyFloatSpinEdit]);
end.
