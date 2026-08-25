unit StartItemModel;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  { TStartItemModel }
  TStartItemModel = class
  private
    FNumber: integer;
    FName: string;
    FCategory: string;
    FNickname: string;
    FBirthday: string;
    FTeam: string;
    FCity: string;
    FPhone: string;
    FEmail: string;
    FComment: string;
    FStartTimes: TStringList;
  public
    constructor Create; overload;
    constructor Create(list: TStringList); overload;
    destructor Destroy; override;
    property number: integer read FNumber write FNumber;
    property Name: string read FName write FName;
    property category: string read FCategory write FCategory;
    property nickname: string read FNickname write FNickname;
    property birthday: string read FBirthday write FBirthday;
    property team: string read FTeam write FTeam;
    property city: string read FCity write FCity;
    property phone: string read FPhone write FPhone;
    property email: string read FEmail write FEmail;
    property comment: string read FComment write FComment;
    property startTimes: TStringList read FStartTimes write FStartTimes;
  end;

  { TLegend }
  TLegend = class
  private
    FNumber: TStringList;
    FName: TStringList;
    FCategory: TStringList;
    FNickname: TStringList;
    FBirthday: TStringList;
    FTeam: TStringList;
    FCity: TStringList;
    FPhone: TStringList;
    FEmail: TStringList;
    FComment: TStringList;
    FStageNames: TStringList;

  public
    constructor Create;
    destructor Destroy; override;
    property number: TStringList read FNumber;
    property Name: TStringList read FName;
    property category: TStringList read FCategory;
    property nickname: TStringList read FNickname;
    property birthday: TStringList read FBirthday;
    property team: TStringList read FTeam;
    property city: TStringList read FCity;
    property phone: TStringList read FPhone;
    property email: TStringList read FEmail;
    property comment: TStringList read FComment;
    property stageNames: TStringList read FStageNames write FStageNames;
  end;

implementation


{ TStartItemModel }

constructor TStartItemModel.Create;
begin
  FStartTimes := TStringList.Create;
end;

constructor TStartItemModel.Create(list: TStringList);
begin
  FStartTimes := TStringList.Create;
end;

destructor TStartItemModel.Destroy;
begin
  FStartTimes.Free;
end;

{ TLegend }

constructor TLegend.Create;
begin
  FNumber := TStringList.Create;
  FNumber.Add('number');
  FNumber.Add('номер');
  FNumber.Add('№');

  FName := TStringList.Create;
  FName.add('имя');
  FName.add('фио');
  FName.add('name');

  FCategory := TStringList.Create;
  FCategory.add('категория');
  FCategory.add('category');

  FNickname := TStringList.Create;
  FNickname.add('ник');
  FNickname.add('никнейм');
  FNickname.add('nickname');

  FBirthday := TStringList.Create;
  FBirthday.add('возраст');
  FBirthday.add('год');
  FBirthday.add('год рождения');
  FBirthday.add('гр');
  FBirthday.add('дата рождения');
  FBirthday.add('age');
  FBirthday.add('birthday');

  FTeam := TStringList.Create;
  FTeam.add('команда');
  FTeam.add('team');

  FCity := TStringList.Create;
  FCity.add('город');
  FCity.add('откуда');
  FCity.add('city');

  FPhone := TStringList.Create;
  FPhone.add('телефон');
  FPhone.add('phone');

  FEmail := TStringList.Create;
  FEmail.add('мыло');
  FEmail.add('почта');
  FEmail.add('емейл');
  FEmail.add('е-мейл');
  FEmail.add('email');
  FEmail.add('e-mail');
  FEmail.add('mail');

  FComment := TStringList.Create;
  FComment.add('комментарий');
  FComment.add('comment');

  FStageNames := TStringList.Create;

end;

destructor TLegend.Destroy;
begin
  FNumber.Free;
  FName.Free;
  FCategory.Free;
  FNickname.Free;
  FBirthday.Free;
  FTeam.Free;
  FCity.Free;
  FPhone.Free;
  FEmail.Free;
  FComment.Free;
  FStageNames.Free;
end;


end.
