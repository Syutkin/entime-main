unit FinishMarkSqliteAdapters;

{$mode ObjFPC}{$H+}

interface

uses
  CompetitionDbContext, FinishMark, FinishMarkService,
  FinishMarkRepository;

type
  TSqliteFinishMarkPersistence = class(TInterfacedObject,
    IFinishMarkPersistence)
  private
    FRepository: TFinishMarkRepository;
  public
    constructor Create(const AContext: TCompetitionDbContext);
    destructor Destroy; override;
    function Insert(const AMark: TFinishMark): TFinishMark;
    function TryLoadById(const AMarkId: int64; out AMark: TFinishMark): boolean;
    function HideWorkQueue: integer;
    procedure Update(const AMark: TFinishMark);
  end;

implementation

uses
  SysUtils;

constructor TSqliteFinishMarkPersistence.Create(const AContext: TCompetitionDbContext);
begin
  inherited Create;
  if AContext = nil then
    raise EArgumentNilException.Create('AContext');
  FRepository := TFinishMarkRepository.Create(AContext);
end;

destructor TSqliteFinishMarkPersistence.Destroy;
begin
  FRepository.Free;
  inherited Destroy;
end;

function TSqliteFinishMarkPersistence.Insert(const AMark: TFinishMark): TFinishMark;
begin
  Result := FRepository.Insert(AMark);
end;

function TSqliteFinishMarkPersistence.TryLoadById(const AMarkId: int64;
  out AMark: TFinishMark): boolean;
begin
  Result := FRepository.TryLoadById(AMarkId, AMark);
end;

function TSqliteFinishMarkPersistence.HideWorkQueue: integer;
begin
  Result := FRepository.HideWorkQueue;
end;

procedure TSqliteFinishMarkPersistence.Update(const AMark: TFinishMark);
begin
  FRepository.Update(AMark);
end;

end.
