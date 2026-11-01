unit TimingTransport;

{$mode ObjFPC}{$H+}

interface

uses
  TimingMark;

type
  TTimingTransportKind = (ttkSerial, ttkBle);
  TTimingTransportState = (ttsDisconnected, ttsConnecting, ttsConnected,
    ttsDisconnecting, ttsError);
  TTimingSendState = (tssPending, tssSucceeded, tssFailed);
  TTimingSendCompletedEvent = procedure(Sender: TObject) of object;
  TTimingTransportDataEvent = procedure(Sender: TObject;
    const AData: rawbytestring; const ASource: TTimingMarkSource) of object;

  ITimingSendOperation = interface
    ['{9B31D9DC-9536-4D9A-8C36-C92506DF88EC}']
    function GetErrorCode: integer;
    function GetErrorMessage: string;
    function GetOnCompleted: TTimingSendCompletedEvent;
    function GetSource: TTimingMarkSource;
    function GetState: TTimingSendState;
    procedure SetOnCompleted(const AHandler: TTimingSendCompletedEvent);
    property ErrorCode: integer read GetErrorCode;
    property ErrorMessage: string read GetErrorMessage;
    property OnCompleted: TTimingSendCompletedEvent
      read GetOnCompleted write SetOnCompleted;
    property Source: TTimingMarkSource read GetSource;
    property State: TTimingSendState read GetState;
  end;

  ITimingTransport = interface
    ['{1E2990AA-9C99-4025-A216-99F53415C90C}']
    function GetConnected: boolean;
    function GetKind: TTimingTransportKind;
    function GetOnData: TTimingTransportDataEvent;
    function GetSource: TTimingMarkSource;
    function GetTransportState: TTimingTransportState;
    procedure SetOnData(const AHandler: TTimingTransportDataEvent);
    function SendAsync(const AData: rawbytestring): ITimingSendOperation;
    property Connected: boolean read GetConnected;
    property Kind: TTimingTransportKind read GetKind;
    property OnData: TTimingTransportDataEvent read GetOnData write SetOnData;
    property Source: TTimingMarkSource read GetSource;
    property TransportState: TTimingTransportState read GetTransportState;
  end;

  { TTimingSendOperation }

  TTimingSendOperation = class(TInterfacedObject, ITimingSendOperation)
  private
    FErrorCode: integer;
    FErrorMessage: string;
    FOnCompleted: TTimingSendCompletedEvent;
    FSource: TTimingMarkSource;
    FState: TTimingSendState;
    function GetErrorCode: integer;
    function GetErrorMessage: string;
    function GetOnCompleted: TTimingSendCompletedEvent;
    function GetSource: TTimingMarkSource;
    function GetState: TTimingSendState;
    procedure SetOnCompleted(const AHandler: TTimingSendCompletedEvent);
  public
    constructor Create(const ASource: TTimingMarkSource;
      const AState: TTimingSendState; const AErrorCode: integer = 0;
      const AErrorMessage: string = '');
    class function Succeeded(const ASource: TTimingMarkSource):
      ITimingSendOperation;
      static;
    class function Failed(const ASource: TTimingMarkSource;
      const AErrorMessage: string;
      const AErrorCode: integer = 0): ITimingSendOperation; static;
  end;

implementation

constructor TTimingSendOperation.Create(const ASource: TTimingMarkSource;
  const AState: TTimingSendState; const AErrorCode: integer;
  const AErrorMessage: string);
begin
  inherited Create;
  FSource := ASource;
  FState := AState;
  FErrorCode := AErrorCode;
  FErrorMessage := AErrorMessage;
end;

function TTimingSendOperation.GetErrorCode: integer;
begin
  Result := FErrorCode;
end;

function TTimingSendOperation.GetErrorMessage: string;
begin
  Result := FErrorMessage;
end;

function TTimingSendOperation.GetOnCompleted: TTimingSendCompletedEvent;
begin
  Result := FOnCompleted;
end;

function TTimingSendOperation.GetSource: TTimingMarkSource;
begin
  Result := FSource;
end;

function TTimingSendOperation.GetState: TTimingSendState;
begin
  Result := FState;
end;

procedure TTimingSendOperation.SetOnCompleted(
  const AHandler: TTimingSendCompletedEvent);
begin
  FOnCompleted := AHandler;
  if Assigned(FOnCompleted) and (FState <> tssPending) then
    FOnCompleted(Self);
end;

class function TTimingSendOperation.Succeeded(
  const ASource: TTimingMarkSource): ITimingSendOperation;
begin
  Result := TTimingSendOperation.Create(ASource, tssSucceeded);
end;

class function TTimingSendOperation.Failed(const ASource: TTimingMarkSource;
  const AErrorMessage: string; const AErrorCode: integer): ITimingSendOperation;
begin
  Result := TTimingSendOperation.Create(ASource, tssFailed, AErrorCode,
    AErrorMessage);
end;

end.
