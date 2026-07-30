unit i18n;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

resourcestring
  //имена колонок
  rsCorrection = 'Поправка';
  rsStarttime = 'Старт';
  rsFinishtime = 'Финиш';
  rsPenalty = 'Штраф';
  rsResult = 'Результат';
  rsDiffleader = 'Отставание';
  rsPlace = 'Место';
  rsTotal = 'Общий';
  rsSumresult = 'Итог';
  rsSumstages = 'Кол-во СУ';

  rsNumber = 'Номер';
  rsNumberu = 'Номеру';
  rsName = 'Имя';
  rsNickname = 'Ник';
  rsAge = 'ГР';
  rsTeam = 'Команда';
  rsCity = 'Город';
  rsCategory = 'Категория';

  //имена СУ по умолчанию
  rsSU = 'СУ';
  rsSU1 = 'СУ 1';
  rsSU2 = 'СУ 2';
  rsSU3 = 'СУ 3';
  rsSU4 = 'СУ 4';
  rsSU5 = 'СУ 5';
  rsSU6 = 'СУ 6';
  rsSU7 = 'СУ 7';
  rsSU8 = 'СУ 8';

  //категории по умолчанию
  rsCat1 = 'Девушки';
  rsCat2 = 'Юниоры';
  rsCat3 = 'Любители';
  rsCat4 = 'Мастера';
  rsCat5 = 'Элита';
  rsCat6 = 'Электро';

  //языки
  rsSystemDefault = 'Системный';

  //разделы настроек
  rsSettingsGeneral = 'Общие';
  rsSettingsView = 'Вид';
  rsSettingsCompetition = 'Соревнование';
  rsSettingsCOMPort = 'COM порт';
  rsSettingsLEDPanel = 'LED панель';
  rsSettingsTelegramBot = 'Телеграм бот';
  rsUpdateEveryTime = 'Каждый раз';
  rsUpdateDaily = 'Один раз в сутки';
  rsUpdateWeekly = 'Один раз в неделю';
  rsUpdateMonthly = 'Один раз в месяц';

  //экспорт
  rsStartProtocol = 'Стартовый протокол';
  rsFinishProtocol = 'Финишный протокол';
  rsFinishThruProtocol = 'Сквозной протокол';
  rsResults = 'Результаты';
  rsFinal = 'Финал';

  //сортировка при генерации стартового протокола
  rsByNumberAsc = 'По номерам по возрастанию';
  rsByNumberDesc = 'По номерам по убыванию';
  rsByNameAsc = 'По именам А-Я';
  rsByNameDesc = 'По именам Я-А';
  rsByResult = 'По текущим результатам';

  //остальное
  rsIncorrectCorrection =
    'Некорректное значение поправки, введите верное значение';
  rsUpdateError = 'Ошибка обновления результатов: ';
  rsDatabaseOpenError = 'Ошибка открытия базы: ';
  rsTelegramBotSendingError =
    'Ошибка отправки данных в телеграм бота: ';
  rsNewFileCreated = 'Файл соревнований создан';
  rsNewFileNotCreated =
    'Не удалось создать файл соревнований';
  rsNewFileExistUnknow =
    'Не удалось проверить существование указанного файла';
  rsClearResults = 'Действительно удалить все результаты?';
  rsUpdateFinishTime = 'Обновить финишное время для номера';
  rsDoNotExist = 'не существует';
  rsSetIntervalWarning =
    'Интервал задаётся как целое неотрицательное число миллисекунд';
  rsPenaltyTimeFormat =
    'Штрафное время вводится в формате сс, мм:сс или чч:мм:сс';
  rsFinishTimeSet =
    'Установлено финишное время для номера';
  rsDeleteNumber =
    'Действительно удалить участника c номером';
  rsLoadingConfig = 'Загрузка настроек из файла';
  rsConfigNotFound =
    'Файл настроек не найден, создание файла настроек по умолчанию';
  rsShownCategories =
    'Категории для показа в окне результатов:';
  rsStartProgram = 'Запуск программы';
  rsLoadCSVParticipants = 'Список участников загружен';
  rsImportFinishtime = 'Финишное время для СУ';
  rsImportStarttime = 'Стартовый протокол для СУ';
  rsLoaded = 'загружен';
  rsLoaded_o = 'загружено';
  rsDBFileClosed = 'Файл соревнований закрыт:';
  rsDBFileOpen = 'Файл соревнований открыт:';
  rsResultsCleared = 'Результаты соревнований удалены!';
  rsResultsExportedToFile =
    'Финишный протокол экспортирован в файл';
  rsResultsThruExportedToFile =
    'Сквозной протокол экспортирован в файл';
  rsParticipantWithNumber = 'Участник с номером';
  rsDidNotStart = 'не стартовал';
  rsOnStage = 'на СУ';
  rsDidNotFinish = 'не финишировал';
  rsDeleted = 'удалён';
  rsSureWithNumber = 'Уверены, что участник под номером';
  rsReallyDisqualifyNumber =
    'Действительно дисквалифицировать участника под номером';
  rsDisqualified = 'дисквалифицирован';
  rsCurrentResults = 'Текущие результаты';
  rsClearStatus =
    'Действительно убрать DNS/DNF с участника номер';
  rsClearStatusLog = 'DNS/DNF убрано с участника номер';
  rsClearAllStatus =
    'Действительно убрать DNS/DNF/DSQ с участника номер';
  rsClearAllStatusLog = 'DNS/DNF/DSQ убрано с участника номер';
  rsClearDSQ = 'Действительно убрать DSQ с участника номер';
  rsClearDSQLog = 'DSQ убрана с участника номер';
  rsDidNotStartSetFinish =
    'не числится в списке стартовавших, но не финишировавших. Всё равно установить финишное время?';
  rsImportFinish = 'Импорт результатов';
  rsSetTimeToSU = 'Проставить результаты для СУ:';
  rsExportFinish = 'Экспорт результатов';
  rsExportTimeToSU = 'Экспортировать результаты СУ:';
  rsSetCategoryName =
    'Проставить категории из списка участников в окно результатов?';
  rsFilesAreEqual =
    'Имя файла финала должно отличаться от имени файла квалификации';
  rsFileCopyError = 'Ошибка создания файла финала';
  rsStartFileCopyError = 'Ошибка создания стартового файла';
  rsGenerateStartList =
    'Стартовый протокол финального заезда сформирован';
  rsQualificationResults = 'По результатам квалификации';
  rsStartFileCreated = 'Файл для стартовых ворот создан';
  rsCorrectionAlreadySet =
    'поправка уже установлена. Перезаписать значение?';
  rsCOMOpenError = 'Не удалось открыть порт';
  rsPortClosed = 'Порт %s закрыт';
  rsPortConnected = 'Порт %s подключён';
  rsSerialCanRead = 'Чтение доступно: %s';
  rsSerialCanWrite = 'Запись доступна: %s';
  rsSerialReadCount = 'Прочитано: %s';
  rsSerialWriteCount = 'Записано: %s';
  rsSerialWait = 'Ожидание: %s';
  rsFinishTimeOpenError =
    'Неверный формат файла с результатами СУ';
  rsCanNotBackup = 'Не удалось сделать резервную копию!';
  rsBackupCreated = 'Создание резервной копии успешно завершено: %s';
  rsContinueWithLoadingResults =
    'Продолжить загрузку результатов?';
  rsLoadResultsError =
    'Ошибка загрузки результатов: ';
  rsWriteResultsDatabaseError =
    'Ошибка записи результатов в базу: ';
  rsAddUnknownResultParticipant =
    'Участник с номером %d отсутствует в списке участников. Добавить его и загрузить результат?';
  rsClearResultsWOBackup = 'Всё равно очистить результаты?';
  rsFileExists = 'Файл уже существует. Перезаписать?';
  rsFinalFileExists =
    'Файл финала уже существует. Перезаписать?';
  rsStartListFileExists =
    'Файл стартового протокола уже существует. Перезаписать?';
  rsCSVResultsFileExists =
    'Файл с результатами уже существует. Перезаписать?';
  rsCSVResultsExportError =
    'Ошибка создания финишных результатов: ';
  rsCanNotDeleteFile = 'Не удалось перезаписать файл';
  rsTimeToStart = 'Время старта';
  rsEnterStartTime =
    'Введите новое время старта для номера';
  rsAddDayResults = 'Добавить результаты дня';
  rsSaveResults = 'Сохранить результаты?';
  rsFinishResultsNotEmpty =
    'результаты финиша не пусты. Вы уверены что хотите сформировать стартовый протокол для данного спецучастка?';
  rsLoadParticipantsListError =
    'Ошибка загрузки списка участников: ';
  rsWriteParticipantsDatabaseError =
    'Ошибка записи списка участников в базу: ';
  rsParticipantsCsvEmpty =
    'Файл списка участников пуст';
  rsNumberColumnNotFound =
    'Не найдена колонка с номерами участников';
  rsMultipleNumberColumns =
    'Найдено колонок с номерами участников: %d. Допустима только одна колонка';
  rsEmptyParticipantColumnName =
    'Название колонки %d не должно быть пустым';
  rsDuplicateParticipantColumnName =
    'Название колонки повторяется: %s';
  rsParticipantRowsNotFound =
    'В файле нет строк с участниками';
  rsParticipantRowFieldCountMismatch =
    'В строке %d найдено полей: %d, ожидалось: %d';
  rsInvalidParticipantNumber =
    'Некорректный номер участника "%s" в строке %d: требуется целое число больше нуля';
  rsInvalidParticipantStartTime =
    'Некорректное время старта "%s" в строке %d, колонка "%s". Допустимые форматы: чч:мм, чч:мм:сс, чч:мм:сс.ммм или чч:мм:сс,ммм';
  rsDuplicateParticipantNumber =
    'Номер участника %d повторяется в строках %d и %d';
  rsDetectedParticipantStages =
    'Обнаруженные СУ:';
  rsNewVersionAvailable = 'Доступна новая версия программы: %0:s. Перейти на сайт?';
  rsUpdateAvailable = 'Доступно обновление ...';
  rsUpdatesNotFound = 'Нет доступных обновлений.';
  rsUnknownFileEncoding =
    'Не удалось определить кодировку файла. Продолжить?';
  rsUnsupportedFileEncoding =
    'Неподдерживаемая кодировка файла: %s';
  rsTooManyParticipantStages =
    'В файле найдено %d СУ, но поддерживается не более %d. Лишние СУ будут пропущены. Продолжить?';
  rsResultsCsvEmpty =
    'Файл результатов пуст';
  rsUnsupportedResultsColumnCount =
    'Неподдерживаемое количество колонок: %d. Ожидалось 2, 3 или 6';
  rsResultsRowFieldCountMismatch =
    'В строке %d найдено полей: %d, ожидалось: %d';
  rsResultsRowsNotFound =
    'В файле нет строк с результатами';
  rsInvalidResultParticipantNumber =
    'Некорректный номер участника "%s" в строке %d: требуется целое число больше нуля';
  rsDuplicateResultParticipantNumber =
    'Номер участника %d повторяется в строках %d и %d';
  rsInvalidResultTime =
    'Некорректное время "%s" в строке %d, поле "%s". Допустимые форматы: чч:мм, чч:мм:сс, чч:мм:сс.ммм или чч:мм:сс,ммм';
  rsInvalidResultCorrection =
    'Некорректная поправка "%s" в строке %d: требуется целое число';
  rsInvalidResultPenalty =
    'Некорректный штраф "%s" в строке %d. Допустимые форматы: сс, мм:сс или чч:мм:сс';
  rsInvalidResultStatus =
    'Некорректный статус "%s" в строке %d. Допустимы DNF, DNS, DSQ или числовые коды 1..3';

const
  rsRussian: string = 'Русский';
  rsEnglish: string = 'English';

implementation

end.
