unit StageFieldFactoryTests;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, DB, MemDS,
  StageConfig, StageFieldFactory;

type
  { TStageFieldEventRecorder }

  TStageFieldEventRecorder = class
  public
    ChangeCount: integer;
    CorrectionText: string;
    PenaltyText: string;
    procedure FieldChanged(Sender: TField);
    procedure CorrectionSetText(Sender: TField; const AText: string);
    procedure PenaltySetText(Sender: TField; const AText: string);
    procedure ResultGetText(Sender: TField; var AText: string;
      DisplayText: boolean);
  end;

  { TStageFieldFactoryTests }

  TStageFieldFactoryTests = class(TTestCase)
  private
    FDataSet: TMemDataset;
    FEventRecorder: TStageFieldEventRecorder;
    FFactory: TStageFieldFactory;
    FHandlers: TStageFieldHandlers;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure EnsureStageCount_CreatesEightTypedFieldsPerStage;
    procedure EnsureStageCount_ReusesExistingPersistentFields;
    procedure EnsureStageCount_AssignsEditableAndDisplayHandlers;
    procedure EnsureStageCount_RemovesOnlyFactoryCreatedFieldsWhenShrinking;
    procedure EnsureStageIndexes_CreatesOnlySparseFields;
    procedure EnsureStageCount_RejectsUnsupportedCount;
    procedure EnsureStageFields_RejectsMismatchedExistingType;
  end;

implementation

procedure TStageFieldEventRecorder.FieldChanged(Sender: TField);
begin
  Inc(ChangeCount);
end;

procedure TStageFieldFactoryTests.EnsureStageIndexes_CreatesOnlySparseFields;
begin
  FFactory.EnsureStageIndexes([1, 3, 5]);

  AssertEquals(3 * 8, FDataSet.FieldCount);
  AssertNotNull(FDataSet.FindField('starttime1'));
  AssertNotNull(FDataSet.FindField('status3'));
  AssertNotNull(FDataSet.FindField('place5'));
  AssertNull(FDataSet.FindField('starttime2'));
  AssertNull(FDataSet.FindField('status4'));
end;

procedure TStageFieldEventRecorder.CorrectionSetText(Sender: TField;
  const AText: string);
begin
  CorrectionText := AText;
end;

procedure TStageFieldEventRecorder.PenaltySetText(Sender: TField;
  const AText: string);
begin
  PenaltyText := AText;
end;

procedure TStageFieldEventRecorder.ResultGetText(Sender: TField;
  var AText: string; DisplayText: boolean);
begin
  AText := 'displayed';
end;

procedure TStageFieldFactoryTests.SetUp;
begin
  FDataSet := TMemDataset.Create(nil);
  FEventRecorder := TStageFieldEventRecorder.Create;
  FHandlers.OnEditableFieldChange := @FEventRecorder.FieldChanged;
  FHandlers.OnCorrectionSetText := @FEventRecorder.CorrectionSetText;
  FHandlers.OnPenaltySetText := @FEventRecorder.PenaltySetText;
  FHandlers.OnResultGetText := @FEventRecorder.ResultGetText;
  FFactory := TStageFieldFactory.Create(FDataSet, FHandlers);
end;

procedure TStageFieldFactoryTests.TearDown;
begin
  FFactory.Free;
  FEventRecorder.Free;
  FDataSet.Free;
end;

procedure TStageFieldFactoryTests.EnsureStageCount_CreatesEightTypedFieldsPerStage;
begin
  FFactory.EnsureStageCount(12);

  AssertEquals(12 * 8, FDataSet.FieldCount);
  AssertEquals(12 * 8, FFactory.CreatedFieldCount);
  AssertTrue(FDataSet.FieldByName('starttime12') is TStringField);
  AssertTrue(FDataSet.FieldByName('correction12') is TLongintField);
  AssertTrue(FDataSet.FieldByName('finishtime12') is TStringField);
  AssertTrue(FDataSet.FieldByName('penalty12') is TStringField);
  AssertTrue(FDataSet.FieldByName('result12') is TStringField);
  AssertTrue(FDataSet.FieldByName('diffleader12') is TStringField);
  AssertTrue(FDataSet.FieldByName('place12') is TLongintField);
  AssertTrue(FDataSet.FieldByName('status12') is TStringField);
  AssertEquals(255, TStringField(FDataSet.FieldByName('status12')).Size);
end;

procedure TStageFieldFactoryTests.EnsureStageCount_ReusesExistingPersistentFields;
var
  ExistingStartTime: TStringField;
begin
  ExistingStartTime := TStringField.Create(FDataSet);
  ExistingStartTime.FieldName := 'starttime1';
  ExistingStartTime.DataSet := FDataSet;

  FFactory.EnsureStageCount(1);

  AssertSame(ExistingStartTime, FDataSet.FieldByName('starttime1'));
  AssertEquals(7, FFactory.CreatedFieldCount);
  AssertEquals(8, FDataSet.FieldCount);
end;

procedure TStageFieldFactoryTests.EnsureStageCount_AssignsEditableAndDisplayHandlers;
var
  DisplayText: string;
begin
  FFactory.EnsureStageCount(1);

  FDataSet.FieldByName('starttime1').OnChange(
    FDataSet.FieldByName('starttime1'));
  FDataSet.FieldByName('correction1').OnSetText(
    FDataSet.FieldByName('correction1'), '123');
  FDataSet.FieldByName('penalty1').OnSetText(
    FDataSet.FieldByName('penalty1'), '00:00:05');
  DisplayText := '';
  FDataSet.FieldByName('result1').OnGetText(
    FDataSet.FieldByName('result1'), DisplayText, True);

  AssertEquals(1, FEventRecorder.ChangeCount);
  AssertEquals('123', FEventRecorder.CorrectionText);
  AssertEquals('00:00:05', FEventRecorder.PenaltyText);
  AssertEquals('displayed', DisplayText);
end;

procedure TStageFieldFactoryTests.
  EnsureStageCount_RemovesOnlyFactoryCreatedFieldsWhenShrinking;
var
  BootstrapFactory: TStageFieldFactory;
begin
  FFactory.Free;
  FFactory := nil;
  BootstrapFactory := TStageFieldFactory.Create(FDataSet, FHandlers);
  BootstrapFactory.EnsureStageCount(DEFAULT_STAGE_COUNT);
  BootstrapFactory.Free;

  FFactory := TStageFieldFactory.Create(FDataSet, FHandlers);
  FFactory.EnsureStageCount(12);
  AssertEquals((12 - DEFAULT_STAGE_COUNT) * 8,
    FFactory.CreatedFieldCount);
  AssertEquals(96, FDataSet.FieldCount);

  FFactory.EnsureStageCount(DEFAULT_STAGE_COUNT);
  AssertEquals(0, FFactory.CreatedFieldCount);
  AssertEquals(DEFAULT_STAGE_COUNT * 8, FDataSet.FieldCount);
  AssertTrue(FDataSet.FindField(
    'status' + IntToStr(DEFAULT_STAGE_COUNT + 1)) = nil);
  AssertTrue(FDataSet.FindField(
    'status' + IntToStr(DEFAULT_STAGE_COUNT)) <> nil);
end;

procedure TStageFieldFactoryTests.EnsureStageCount_RejectsUnsupportedCount;
begin
  try
    FFactory.EnsureStageCount(MAX_SUPPORTED_STAGE_COUNT + 1);
    Fail('Expected an exception for an unsupported stage count');
  except
    on E: EArgumentOutOfRangeException do
      AssertTrue(True);
  end;
end;

procedure TStageFieldFactoryTests.EnsureStageFields_RejectsMismatchedExistingType;
var
  WrongField: TLongintField;
begin
  WrongField := TLongintField.Create(FDataSet);
  WrongField.FieldName := 'starttime1';
  WrongField.DataSet := FDataSet;

  try
    FFactory.EnsureStageFields(1);
    Fail('Expected an exception for a mismatched existing field type');
  except
    on E: EDatabaseError do
      AssertTrue(Pos('starttime1', E.Message) > 0);
  end;
end;

initialization
  RegisterTest(TStageFieldFactoryTests);

end.
