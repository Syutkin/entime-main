unit i18n;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

resourcestring
  //имена колонок
  scorrection = 'Поправка';
  sstarttime = 'Старт';
  sfinishtime = 'Финиш';
  spenalty = 'Штраф';
  sresult = 'Результат';
  sdiffleader = 'Отставание';
  splace = 'Место';
  stotal = 'Общий';

  //имена СУ по умолчанию
  sSU  = 'СУ';
  sSU1 = 'СУ 1';
  sSU2 = 'СУ 2';
  sSU3 = 'СУ 3';
  sSU4 = 'СУ 4';
  sSU5 = 'СУ 5';
  sSU6 = 'СУ 6';

  //категории по умолчанию
  sCat1 = 'Девушки';
  sCat2 = 'Юниоры';
  sCat3 = 'Любители';
  sCat4 = 'Мастера';
  sCat5 = 'Элита';
  sCat6 = 'Электро';

  //языки
  sRussian = 'Русский';
  sEnglish = 'English';

  //остальное
  sIncorrectCorrection = 'Некорректное значение поправки, введите верное значение';
  sUpdateError = 'Ошибка обновления результатов: ';
  sDatabaseOpenError = 'Ошибка открытия базы: ';
  sNewFileCreated = 'Файл соревнований создан';
  sNewFileNotCreated = 'Не удалось создать файл соревнований';
  sNewFileExistUnknow = 'Не удалось проверить существование указанного файла';
  sClearResults = 'Действительно удалить все результаты?';
  sUpdateFinishTime = 'Обновить финишное время для номера';
  sNumber = 'Номер';
  sNumberu = 'Номеру';
  sDoNotExist = 'не существует';
  sSetIntervalWarning = 'Интервал задаётся как целое неотрицательное число миллисекунд';
  sPenaltyTimeFormat = 'Штрафное время вводится в формате мм:сс или чч:мм:сс';
  sFinishTimeSet = 'Установлено финишное время для номера';
  sDeleteNumber = 'Действительно удалить участника c номером';
  sLoadingConfig = 'Загрузка настроек из файла';
  sConfigNotFound = 'Файл настроек не найден, создание файла настроек по умолчанию';
  sShownCategories = 'Категории для показа в окне результатов:';
  sStartProgram = 'Запуск программы';
  sLoadCSVParticipants = 'Список участников загружен';
  sImportFinishtime = 'Финишное время для СУ';
  sImportStarttime = 'Стартовый протокол для СУ';
  sLoaded = 'загружен';
  sLoaded_o = 'загружено';
  sDBFileClosed = 'Файл соревнований закрыт:';
  sDBFileOpen = 'Файл соревнований открыт:';
  sResultsCleared = 'Результаты соревнований удалены!';
  sResultsExportedToFile = 'Финишный протокол экспортирован в файл';
  sResultsThruExportedToFile = 'Сквозной протокол экспортирован в файл';
  sParticipantWithNumber = 'Участник с номером';
  sDidNotStart = 'не стартовал';
  sOnStage = 'на СУ';
  sDidNotFinish = 'не финишировал';
  sDeleted = 'удалён';
  sSureWithNumber = 'Уверены, что участник под номером';
  sReallyDisqualifyNumber = 'Действительно дисквалифицировать участника под номером';
  sDisqualified = 'дисквалифицирован';
  sCurrentResults = 'Текущие результаты';
  sClearStatus = 'Действительно убрать DNS/DNF с участника номер';
  sClearStatusLog = 'DNS/DNF убрано с участника номер';
  sClearAllStatus = 'Действительно убрать DNS/DNF/DSQ с участника номер';
  sClearAllStatusLog = 'DNS/DNF/DSQ убрано с участника номер';
  sClearDSQ = 'Действительно убрать DSQ с участника номер';
  sClearDSQLog = 'DSQ убрана с участника номер';
  sDidNotStartSetFinish = 'не числится в списке стартовавших, но не финишировавших. Всё равно установить финишное время?';
  sImportFinish ='Импорт результатов';
  sSetTimeToSU = 'Проставить результаты для СУ:';
  sSetCategoryName = 'Проставить категории из списка участников в окно результатов?';
  sFilesAreEqual = 'Имя файла финала должно отличаться от имени файла квалификации';
  sFileCopyError = 'Ошибка создания файла финала';
  sStartFileCopyError = 'Ошибка создания стартового файла';
  sGenerateStartList = 'Стартовый протокол финального заезда сформирован';
  sQualificationResults = 'По результатам квалификации';
  sStartFileCreated = 'Файл для стартовых ворот создан';
  sCorrectionAlreadySet = 'поправка уже установлена. Перезаписать значение?';
  sCOMOpenError = 'Не удалось открыть порт';
  sFinishTimeOpenError = 'Неверный формат файла с результатами СУ';
  sCanNotBackup = 'Не удалось сделать бэкап, продолжить загрузку результатов?';
  sFinalFileExists = 'Файл финала уже существует. Перезаписать?';
  sBDStartListFileExists = 'Файл стартового протокола уже существует. Перезаписать?';
  sCanNotDeleteFile = 'Не удалось перезаписать файл';
  sTimeToStart = 'Время старта';
  sEnterStartTime = 'Введите новое время старта для номера';
  sAddDayResults = 'Добавить результаты дня';
  sSaveResults = 'Сохранить результаты?';


implementation

end.

