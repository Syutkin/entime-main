unit GuiTestSupport;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Forms, ComCtrls, Controls, Dialogs
  {$IFDEF LCLWIN32}, ExtCtrls{$ENDIF};

type
  { Scoped exception capture and an event-queue barrier, not a paint delay.
    A process timeout must additionally guard a blocked UI thread. }
  TGuiTestSession = class
  private
    FPreviousException: TExceptionEvent;
    FError, FAction: string;
    FReached: boolean;
    {$IFDEF LCLWIN32}
    FDialogTimer: TTimer;
    FDialog: TFileDialog;
    FDialogAction: TDataEvent;
    FDialogDeadline: QWord;
    procedure CheckFileDialog(Sender: TObject);
    {$ENDIF}
    procedure CaptureException(Sender: TObject; E: Exception);
    procedure Barrier(Data: PtrInt);
    procedure WaitForReady(const AControl: TWinControl);
    procedure ClickControl(const AControl: TWinControl; const AX, AY: integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Drain(const AAction: string);
    procedure WhenFileDialogReady(const ADialog: TFileDialog;
      const AAction: TDataEvent);
    procedure SelectTab(const ASheet: TTabSheet);
    procedure Click(const AControl: TWinControl; const AX, AY: integer);
    procedure ClickSpinArrow(const AControl: TWinControl; Up: boolean = True);
    procedure PressKey(const AControl: TWinControl; const AKey: word);
    procedure TypeText(const AControl: TWinControl; const AText: string);
    procedure ClickAndWaitForFocus(const AControl: TWinControl;
      const AX, AY: integer);
  end;

implementation

uses Types, LCLType
  {$IFDEF LCLWIN32}, Windows, Win32Proc, Spin, ActiveX, ShlObj{$ENDIF}
  {$IFDEF LCLQT6}, Qt6, QtWidgets{$ENDIF};

  {$IFDEF LCLQT6}
// Read-only Qt widgets discard non-spontaneous key events before LCL sees
// them. Deliver through Qt's native spontaneous-event entry point.
function QtSendSpontaneousEvent(Receiver: QObjectH; Event: QEventH): boolean; cdecl;
  external 'Qt6Core' name '_ZN16QCoreApplication20sendSpontaneousEventEP7QObjectP6QEvent';
  {$ENDIF}

  {$IF not defined(LCLWIN32) and not defined(LCLQT6)}
type
  TWinControlAccess = class(TWinControl);
  {$ENDIF}

constructor TGuiTestSession.Create;
begin
  inherited Create;
  FPreviousException := Application.OnException;
  Application.OnException := @CaptureException;
end;

destructor TGuiTestSession.Destroy;
begin
  {$IFDEF LCLWIN32}
  FDialogTimer.Free;
  {$ENDIF}
  Application.RemoveAsyncCalls(Self);
  Application.OnException := FPreviousException;
  inherited Destroy;
end;

procedure TGuiTestSession.WhenFileDialogReady(const ADialog: TFileDialog;
  const AAction: TDataEvent);
begin
  {$IFDEF LCLWIN32}
  // OnShow precedes IFileDialog.Show. Its first message loop may still have
  // the owner active, so wait for this dialog's own visible native window.
  if FDialogTimer = nil then
  begin
    FDialogTimer := TTimer.Create(nil);
    FDialogTimer.Enabled := False;
    FDialogTimer.Interval := 10;
    FDialogTimer.OnTimer := @CheckFileDialog;
  end;
  FDialog := ADialog;
  FDialogAction := AAction;
  FDialogDeadline := GetTickCount64 + 5000;
  FDialogTimer.Enabled := True;
  {$ELSE}
  Application.QueueAsyncCall(AAction, 0);
  {$ENDIF}
end;

{$IFDEF LCLWIN32}
procedure TGuiTestSession.CheckFileDialog(Sender: TObject);
var
  NativeDialog: IFileDialog;
  OleWindow: IOleWindow;
  Window: HWND;
  Action: TDataEvent;
begin
  NativeDialog := IFileDialog(FDialog.Handle);
  Window := 0;
  if Supports(NativeDialog, IOleWindow, OleWindow) and
    Succeeded(OleWindow.GetWindow(Window)) and (Window <> 0) and
    Windows.IsWindowVisible(Window) then
  begin
    FDialogTimer.Enabled := False;
    Action := FDialogAction;
    FDialog := nil;
    FDialogAction := nil;
    Action(PtrInt(Window));
  end
  else if GetTickCount64 >= FDialogDeadline then
  begin
    FDialogTimer.Enabled := False;
    FError := 'Native file dialog did not become visible: ' + FDialog.Name;
    NativeDialog.Close(HRESULT(-2147023673)); // HRESULT_FROM_WIN32(ERROR_CANCELLED)
  end;
end;
{$ENDIF}

procedure TGuiTestSession.CaptureException(Sender: TObject; E: Exception);
begin
  if FError = '' then FError := E.ClassName + ': ' + E.Message;
end;

procedure TGuiTestSession.Barrier(Data: PtrInt);
begin
  FReached := True;
end;

procedure TGuiTestSession.Drain(const AAction: string);
var
  Deadline: QWord;
begin
  FAction := AAction;
  FReached := False;
  Deadline := GetTickCount64 + 5000;
  Application.QueueAsyncCall(@Barrier, 0);
  repeat
  try
    Application.ProcessMessages;
  except
    on E: Exception do CaptureException(Application, E);
  end;
    if FError <> '' then
      raise Exception.Create(FAction + ': GUI exception: ' + FError);
    if GetTickCount64 > Deadline then
      raise Exception.Create(FAction + ': event queue did not respond');
  until FReached;
end;

procedure TGuiTestSession.WaitForReady(const AControl: TWinControl);
var
  Deadline: QWord;
begin
  Deadline := GetTickCount64 + 5000;
  repeat
    Drain('Wait for ' + AControl.Name);
    if AControl.HandleAllocated and AControl.Showing and AControl.Enabled and
      AControl.CanFocus and (AControl.ClientWidth > 0) and
      (AControl.ClientHeight > 0) then
      Exit;
    if GetTickCount64 >= Deadline then
      raise Exception.Create('Control is not ready: ' + AControl.Name);
    Sleep(1);
  until False;
end;

procedure TGuiTestSession.ClickControl(const AControl: TWinControl;
  const AX, AY: integer);
{$IFDEF LCLWIN32}
var
  Form: TCustomForm;
  Position: TPoint;
  Target: HWND;
  Inputs: array[0..1] of TInput;
  I, ScreenWidth, ScreenHeight: integer;
{$ENDIF}
{$IFDEF LCLQT6}
var Widget: TQtWidget; Target: QWidgetH; Event: QMouseEventH;
  Local, Global: TQtPointF; ScreenPoint: TPoint;
{$ENDIF}
{$IFDEF LCLWIN32}
  function IsSpinArrow: boolean;
  var Info:PWin32WindowInfo;
  begin
    Result:=False;
    if not (AControl is TCustomFloatSpinEdit) then Exit;
    // Native Win32 spin arrows are a sibling window of the edit.
    Info:=GetWin32WindowInfo(AControl.Handle);
    Result:=(Info<>nil) and (Info^.UpDown=Target);
  end;
{$ENDIF}
begin
  WaitForReady(AControl);
  {$IFDEF LCLWIN32}
  Form := GetParentForm(AControl);
  Form.BringToFront;
  Windows.SetForegroundWindow(Form.Handle);
  Drain('Activate ' + Form.Name);
  if Windows.GetForegroundWindow <> Form.Handle then
    raise Exception.Create('Could not activate form: ' + Form.Name);
  Position := AControl.ClientToScreen(Types.Point(AX, AY));
  Target := Windows.WindowFromPoint(Position);
  if (Target <> AControl.Handle) and
    not Windows.IsChild(AControl.Handle, Target) and not IsSpinArrow then
    raise Exception.Create('Click target is obscured: ' + AControl.Name);
  ScreenWidth := GetSystemMetrics(SM_CXVIRTUALSCREEN);
  ScreenHeight := GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if (ScreenWidth <= 1) or (ScreenHeight <= 1) then
    raise Exception.Create('No desktop available for mouse input');
  FillChar(Inputs, SizeOf(Inputs), 0);
  for I := 0 to High(Inputs) do
  begin
    Inputs[I]._Type := INPUT_MOUSE;
    Inputs[I].mi.dx := Round((Position.X - GetSystemMetrics(SM_XVIRTUALSCREEN)) *
      65535.0 / (ScreenWidth - 1));
    Inputs[I].mi.dy := Round((Position.Y - GetSystemMetrics(SM_YVIRTUALSCREEN)) *
      65535.0 / (ScreenHeight - 1));
    Inputs[I].mi.dwFlags := MOUSEEVENTF_MOVE or MOUSEEVENTF_ABSOLUTE or
      MOUSEEVENTF_VIRTUALDESK;
  end;
  Inputs[0].mi.dwFlags := Inputs[0].mi.dwFlags or MOUSEEVENTF_LEFTDOWN;
  Inputs[1].mi.dwFlags := Inputs[1].mi.dwFlags or MOUSEEVENTF_LEFTUP;
  // Deliver native mouse activation and button messages, not just LCL handlers.
  if Windows.SendInput(Length(Inputs), @Inputs[0], SizeOf(TInput)) <>
    Length(Inputs) then
    raise Exception.Create('Could not send mouse input: ' + AControl.Name);
  {$ELSE}
  {$IFDEF LCLQT6}
  Widget := TQtWidget(AControl.Handle);
  Target := Widget.Widget;
  if Widget is TQtAbstractButton then
  begin
    // Qt's offscreen platform does not assign mouse focus to a synthetic
    // button event. Activate the native button, preserving its enabled state
    // and clicked signal instead of invoking an LCL handler directly.
    // Qt handles point to C++ objects, not Pascal objects checked by -CR.
    QAbstractButton_click(QAbstractButtonH(Pointer(Target)));
    Drain('Click ' + AControl.Name);
    Exit;
  end;
  if Widget is TQtAbstractScrollArea then Target := TQtAbstractScrollArea(Widget).viewportWidget;
  Local.X := AX; Local.Y := AY;
  ScreenPoint := AControl.ClientToScreen(Types.Point(AX, AY));
  Global.X := ScreenPoint.X; Global.Y := ScreenPoint.Y;
  Event := QMouseEvent_Create(QEventMouseButtonPress, @Local, @Global,
    QtLeftButton, QtLeftButton, QtNoModifier);
  try QCoreApplication_sendEvent(Target, Event); finally QMouseEvent_Destroy(Event); end;
  Event := QMouseEvent_Create(QEventMouseButtonRelease, @Local, @Global,
    QtLeftButton, QtNoButton, QtNoModifier);
  try QCoreApplication_sendEvent(Target, Event); finally QMouseEvent_Destroy(Event); end;
  {$ELSE}
  TWinControlAccess(AControl).MouseDown(mbLeft, [], AX, AY);
  TWinControlAccess(AControl).MouseUp(mbLeft, [], AX, AY);
  {$ENDIF}
  {$ENDIF}
  Drain('Click ' + AControl.Name);
end;

procedure TGuiTestSession.ClickSpinArrow(const AControl: TWinControl; Up: boolean);
var
  P: TPoint;
  {$IFDEF LCLWIN32}
var Info:PWin32WindowInfo; R:TRect;
  {$ENDIF}
begin
  WaitForReady(AControl);
  {$IFDEF LCLWIN32}
  Info:=GetWin32WindowInfo(AControl.Handle);
  if (Info=nil) or (Info^.UpDown=0) or not Windows.GetWindowRect(Info^.UpDown,R) then
    raise Exception.Create('Spin arrows are unavailable: '+AControl.Name);
  P.X:=(R.Left+R.Right) div 2;
  if Up then P.Y:=R.Top+(R.Bottom-R.Top) div 4
  else P.Y:=R.Bottom-(R.Bottom-R.Top) div 4;
  P:=AControl.ScreenToClient(P);
  {$ELSE}
  P.X := AControl.Width - 8;
  if Up then P.Y := AControl.ClientHeight div 4
  else
    P.Y := AControl.ClientHeight * 3 div 4;
  {$ENDIF}
  Click(AControl, P.X, P.Y);
end;

procedure TGuiTestSession.Click(const AControl: TWinControl; const AX, AY: integer);
begin
  ClickControl(AControl, AX, AY);
end;

procedure TGuiTestSession.PressKey(const AControl: TWinControl; const AKey: word);
{$IFDEF LCLWIN32}
var Inputs: array[0..1] of TInput;
{$ENDIF}
{$IFDEF LCLQT6}
var Event: QKeyEventH; Key: integer;
{$ENDIF}
begin
  if not AControl.Focused then
    raise Exception.Create('Keyboard target is not focused: ' + AControl.Name);
  {$IFDEF LCLWIN32}
  FillChar(Inputs, SizeOf(Inputs), 0);
  Inputs[0]._Type := INPUT_KEYBOARD; Inputs[0].ki.wVk := AKey;
  Inputs[1] := Inputs[0]; Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;
  if Windows.SendInput(2, @Inputs[0], SizeOf(TInput)) <> 2 then
    raise Exception.Create('Could not send keyboard input');
  {$ELSE}
  {$IFDEF LCLQT6}
  case AKey of
    LCLType.VK_RETURN: Key := QtKey_Return;
    LCLType.VK_ESCAPE: Key := QtKey_Escape;
    LCLType.VK_TAB: Key := QtKey_Tab;
    LCLType.VK_F2: Key := QtKey_F2;
    LCLType.VK_F5: Key := QtKey_F5;
    LCLType.VK_UP: Key := QtKey_Up;
    LCLType.VK_DOWN: Key := QtKey_Down;
    LCLType.VK_LEFT: Key := QtKey_Left;
    LCLType.VK_RIGHT: Key := QtKey_Right;
    else Key := AKey;
  end;
  Event := QKeyEvent_Create(QEventKeyPress, Key, QtNoModifier);
  try QtSendSpontaneousEvent(TQtWidget(AControl.Handle).Widget, Event);
  finally QKeyEvent_Destroy(Event); end;
  Event := QKeyEvent_Create(QEventKeyRelease, Key, QtNoModifier);
  try QtSendSpontaneousEvent(TQtWidget(AControl.Handle).Widget, Event);
  finally QKeyEvent_Destroy(Event); end;
  {$ELSE}
  AControl.Perform(LM_KEYDOWN, AKey, 0);
  AControl.Perform(LM_KEYUP, AKey, 0);
  {$ENDIF}
  {$ENDIF}
  Drain('Keyboard input');
end;

procedure TGuiTestSession.TypeText(const AControl: TWinControl; const AText: string);
var
  Text: unicodestring;
  I: integer;
  {$IFDEF LCLWIN32}
 Inputs: array[0..1] of TInput; 
  {$ENDIF}
  {$IFDEF LCLQT6}
 Event: QKeyEventH; Character: WideString; 
  {$ENDIF}
begin
  if not AControl.Focused then
    raise Exception.Create('Text target is not focused: ' + AControl.Name);
  Text := UTF8Decode(AText);
  for I := 1 to Length(Text) do
  begin
    {$IFDEF LCLWIN32}
    FillChar(Inputs, SizeOf(Inputs), 0);
    Inputs[0]._Type := INPUT_KEYBOARD; Inputs[0].ki.wScan := Ord(Text[I]);
    Inputs[0].ki.dwFlags := KEYEVENTF_UNICODE;
    Inputs[1] := Inputs[0]; Inputs[1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
    if Windows.SendInput(2, @Inputs[0], SizeOf(TInput)) <> 2 then raise Exception.Create('Could not type text');
  {$ENDIF}
    {$IFDEF LCLQT6}
    Character := Text[I];
    Event := QKeyEvent_Create(QEventKeyPress, Ord(UpCase(Text[I])), QtNoModifier, @Character);
    try QtSendSpontaneousEvent(TQtWidget(AControl.Handle).Widget, Event);
    finally QKeyEvent_Destroy(Event); end;
    Event := QKeyEvent_Create(QEventKeyRelease, Ord(UpCase(Text[I])), QtNoModifier, @Character);
    try QtSendSpontaneousEvent(TQtWidget(AControl.Handle).Widget, Event);
    finally QKeyEvent_Destroy(Event); end;
  {$ENDIF}
  end;
  Drain('Type text');
end;

procedure TGuiTestSession.ClickAndWaitForFocus(const AControl: TWinControl;
  const AX, AY: integer);
var
  Deadline: QWord;
begin
  ClickControl(AControl, AX, AY);
  Deadline := GetTickCount64 + 5000;
  repeat
    Drain('Wait for focus on ' + AControl.Name);
    if AControl.Focused then Exit;
    if GetTickCount64 >= Deadline then
      raise Exception.Create('Clicked control did not receive focus: ' +
        AControl.Name);
    Sleep(1);
  until False;
end;

procedure TGuiTestSession.SelectTab(const ASheet: TTabSheet);
{$IFDEF LCLQT6}
var NativeTabs: QTabWidgetH; NativeIndex: integer;
{$ENDIF}
{$IFDEF LCLWIN32}
var TabBounds: TRect;
{$ENDIF}
begin
  if not ASheet.TabVisible then
    raise Exception.Create('Unavailable tab: ' + ASheet.Name);
  {$IFDEF LCLQT6}
  // Exercise the native selection signal and its mapping back to LCL.
  NativeTabs := QTabWidgetH(Pointer(TQtWidget(ASheet.PageControl.Handle).Widget));
  NativeIndex := QTabWidget_indexOf(NativeTabs,
    TQtWidget(ASheet.Handle).Widget);
  if NativeIndex < 0 then
    raise Exception.Create('Missing native tab: ' + ASheet.Name);
  QTabWidget_setCurrentIndex(NativeTabs, NativeIndex);
  {$ELSE}
  {$IFDEF LCLWIN32}
  WaitForReady(ASheet.PageControl);
  TabBounds := ASheet.PageControl.TabRect(
    ASheet.PageControl.PageToTabIndex(ASheet.PageIndex));
  if IsRectEmpty(TabBounds) then
    raise Exception.Create('Missing native tab: ' + ASheet.Name);
  ClickControl(ASheet.PageControl, (TabBounds.Left + TabBounds.Right) div 2,
    (TabBounds.Top + TabBounds.Bottom) div 2);
  {$ELSE}
  ASheet.PageControl.ActivePage := ASheet;
  {$ENDIF}
  {$ENDIF}
  Drain('Select tab ' + ASheet.Name);
  if (ASheet.PageControl.ActivePage <> ASheet) or not ASheet.Showing then
    raise Exception.Create('Selected tab is not showing: ' + ASheet.Name);
end;

end.
