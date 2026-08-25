unit FakeHttpTransport;

{$mode ObjFPC}{$H+}

interface

uses
  HttpTransport;

type
  TFakeHttpTransport = class(TInterfacedObject, IHttpTransport)
  private
    FResponses: array of THttpResponse;
    FRequests: array of THttpRequest;
    FCancelled: Boolean;
    FCancelCount: Integer;
    function GetRequest(const AIndex: Integer): THttpRequest;
  public
    procedure QueueResponse(const AResponse: THttpResponse);
    function Execute(const ARequest: THttpRequest): THttpResponse;
    procedure Cancel;
    function RequestCount: Integer;
    property Requests[const AIndex: Integer]: THttpRequest read GetRequest;
    property Cancelled: Boolean read FCancelled;
    property CancelCount: Integer read FCancelCount;
  end;

  TFakeHttpTransportFactory = class(TInterfacedObject, IHttpTransportFactory)
  private
    FResponses: array of THttpResponse;
    FTransportInterfaces: array of IHttpTransport;
    FTransports: array of TFakeHttpTransport;
    function GetTransport(const AIndex: Integer): TFakeHttpTransport;
  public
    procedure QueueResponse(const AResponse: THttpResponse);
    function CreateTransport: IHttpTransport;
    function TransportCount: Integer;
    property Transports[const AIndex: Integer]: TFakeHttpTransport
      read GetTransport;
  end;

implementation

function CancelledResponse: THttpResponse;
begin
  Result := Default(THttpResponse);
  Result.ErrorKind := hekCancelled;
  Result.ErrorMessage := 'HTTP operation was cancelled';
end;

function MissingResponse: THttpResponse;
begin
  Result := Default(THttpResponse);
  Result.ErrorKind := hekProtocol;
  Result.ErrorMessage := 'No fake HTTP response was queued';
end;

procedure RemoveFirstResponse(var AResponses: array of THttpResponse);
var
  Index: Integer;
begin
  for Index := 1 to High(AResponses) do
    AResponses[Index - 1] := AResponses[Index];
end;

function TFakeHttpTransport.GetRequest(const AIndex: Integer): THttpRequest;
begin
  Result := CloneHttpRequest(FRequests[AIndex]);
end;

procedure TFakeHttpTransport.QueueResponse(const AResponse: THttpResponse);
var
  Index: Integer;
begin
  Index := Length(FResponses);
  SetLength(FResponses, Index + 1);
  FResponses[Index] := CloneHttpResponse(AResponse);
end;

function TFakeHttpTransport.Execute(
  const ARequest: THttpRequest): THttpResponse;
var
  RequestIndex: Integer;
begin
  if FCancelled then
    Exit(CancelledResponse);

  RequestIndex := Length(FRequests);
  SetLength(FRequests, RequestIndex + 1);
  FRequests[RequestIndex] := CloneHttpRequest(ARequest);

  if Length(FResponses) = 0 then
    Exit(MissingResponse);

  Result := CloneHttpResponse(FResponses[0]);
  RemoveFirstResponse(FResponses);
  SetLength(FResponses, Length(FResponses) - 1);
end;

procedure TFakeHttpTransport.Cancel;
begin
  FCancelled := True;
  Inc(FCancelCount);
end;

function TFakeHttpTransport.RequestCount: Integer;
begin
  Result := Length(FRequests);
end;

function TFakeHttpTransportFactory.GetTransport(
  const AIndex: Integer): TFakeHttpTransport;
begin
  Result := FTransports[AIndex];
end;

procedure TFakeHttpTransportFactory.QueueResponse(
  const AResponse: THttpResponse);
var
  Index: Integer;
begin
  Index := Length(FResponses);
  SetLength(FResponses, Index + 1);
  FResponses[Index] := CloneHttpResponse(AResponse);
end;

function TFakeHttpTransportFactory.CreateTransport: IHttpTransport;
var
  Index: Integer;
  Transport: TFakeHttpTransport;
begin
  Transport := TFakeHttpTransport.Create;
  if Length(FResponses) > 0 then
  begin
    Transport.QueueResponse(FResponses[0]);
    RemoveFirstResponse(FResponses);
    SetLength(FResponses, Length(FResponses) - 1);
  end;

  Result := Transport;
  Index := Length(FTransports);
  SetLength(FTransports, Index + 1);
  SetLength(FTransportInterfaces, Index + 1);
  FTransports[Index] := Transport;
  FTransportInterfaces[Index] := Result;
end;

function TFakeHttpTransportFactory.TransportCount: Integer;
begin
  Result := Length(FTransports);
end;

end.
