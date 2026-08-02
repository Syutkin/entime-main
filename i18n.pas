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
  rsDatabaseOpenError = 'Ошибка открытия базы: %s';
  rsDatabaseRefreshError =
    'Не удалось обновить данные (%d ошибок). Первая ошибка: %s';
  rsCompetitionSettingsLoadError =
    'Не удалось загрузить настройки соревнования: %s';
  rsStageResultsCalculationError =
    'Не удалось пересчитать результаты СУ: %s';
  rsSumResultsCalculationError =
    'Не удалось пересчитать суммарные результаты: %s';
  rsThruResultsCalculationError =
    'Не удалось пересчитать сквозные результаты: %s';
  rsResultsClearError =
    'Не удалось удалить результаты соревнования: %s';
  rsCategoryListLoadError = 'Не удалось загрузить список категорий: %s';
  rsParticipantStatusesLoadError =
    'Не удалось загрузить статусы участников: %s';
  rsFinishResultsCheckError =
    'Не удалось проверить наличие финишных результатов: %s';
  rsTelegramBotSendingError =
    'Ошибка отправки данных в Telegram-бота: %s';
  rsNewFileCreated = 'Файл соревнований создан: %s';
  rsNewFileNotCreated =
    'Не удалось создать файл соревнований';
  rsNewFileExistUnknow =
    'Не удалось проверить существование указанного файла';
  rsCompetitionFileCreateError =
    'Не удалось создать файл соревнований "%s": %s';
  rsCompetitionFileOpenError =
    'Не удалось открыть файл соревнований "%s": %s';
  rsClearResults = 'Действительно удалить все результаты?';
  rsUpdateFinishTime = 'Обновить финишное время для номера %d?';
  rsSetIntervalWarning =
    'Интервал задаётся как целое неотрицательное число миллисекунд';
  rsPenaltyTimeFormat =
    'Штрафное время вводится в формате сс, мм:сс или чч:мм:сс';
  rsFinishTimeSetForStages =
    'Установлено финишное время для номера %d; СУ: %s';
  rsDeleteNumber = 'Действительно удалить участника c номером %s?';
  rsParticipantDeleted = 'Участник с номером %s удалён';
  rsParticipantUpdated = 'Данные участника с номером %s изменены';
  rsParticipantCorrectionSet =
    'Номеру %s установлена поправка на СУ %d: %s';
  rsParticipantStartTimeSet =
    'Номеру %s установлено время старта на СУ %d: %s';
  rsParticipantStageValueUpdated =
    'Номеру %s изменено поле «%s» на СУ %d: %s';
  rsParticipantSaveError =
    'Не удалось сохранить данные номера %s: %s';
  rsParticipantStageSaveError =
    'Не удалось сохранить данные номера %s на СУ %d: %s';
  rsParticipantStagesSaveError =
    'Не удалось сохранить данные номера %s на СУ %s: %s';
  rsParticipantStatusesRecalculated =
    'Глобальные статусы пересчитаны: %d';
  rsParticipantStatusRecalculationError =
    'Не удалось пересчитать статус номера %s: %s';
  rsLoadingConfig = 'Загрузка настроек из файла';
  rsConfigNotFound =
    'Файл настроек не найден, создание файла настроек по умолчанию';
  rsShownCategories =
    'Категории для показа в окне результатов: %s';
  rsSettingsLoaded = 'Настройки загружены: %s';
  rsSettingsSaved = 'Настройки сохранены';
  rsLanguageChanged = 'Язык приложения изменён: %s';
  rsStartProgram = 'Запуск программы %s';
  rsApplicationShutdown = 'Завершение работы программы';
  rsCodepage = 'Кодировка: %s';
  rsLEDPanelError = 'Ошибка LED-панели: %s';
  rsLEDPanelEnabled = 'LED-панель включена';
  rsLEDPanelDisabled = 'LED-панель выключена';
  rsLEDPanelTestSucceeded = 'Проверка LED-панели выполнена успешно';
  rsTelegramBotEnabled = 'Telegram-бот включён';
  rsTelegramBotDisabled = 'Telegram-бот выключен';
  rsTelegramBotTestSucceeded = 'Проверка Telegram-бота выполнена успешно';
  rsHTTPRequestMetadata = 'HTTP-запрос: %s; параметров: %d';
  rsHTTPResponseMetadata =
    'HTTP-ответ: %d %s; заголовков: %d; байт: %d';
  rsHTTPResponseReceived = 'Получен HTTP-ответ: %d байт';
  rsHTTPRequestNotStarted = 'не удалось запустить HTTP-запрос';
  rsOpenStartListFile = 'Открытие файла стартового протокола: %s';
  rsSerialFinish = 'Финиш -> %s';
  rsSerialRaw = 'Исходные данные -> %s';
  rsSerialStart = 'Старт -> %s, %s';
  rsTelegramBotError = 'Ошибка Telegram-бота: %s';
  rsLoadCSVParticipants = 'Список участников загружен';
  rsImportFinishtime = 'Финишное время для СУ %d: %s загружено';
  rsImportStarttime = 'Стартовый протокол для СУ %d: %s загружен';
  rsParticipantsImported = 'Участники импортированы: %d; файл: %s';
  rsParticipantsImportPartial =
    'Участники импортированы с пропусками: %d; использовано СУ: %d из %d; файл: %s';
  rsResultsImported =
    'Результаты импортированы для СУ %d (%s): %d; файл: %s';
  rsResultsImportPartial =
    'Результаты импортированы частично для СУ %d (%s): %d из %d; файл: %s';
  rsDayResultsImported = 'Результаты дня импортированы: %d; файл: %s';
  rsResultsImportFormat = 'Формат файла результатов: %d колонок';
  rsDBFileClosed = 'Файл соревнований закрыт: %s';
  rsDBFileOpen = 'Файл соревнований открыт: %s';
  rsLogDirectoryOpenError = 'Не удалось открыть каталог журнала: %s';
  rsLogFileOpenError = 'Не удалось открыть файл журнала: %s';
  rsResultsCleared = 'Результаты соревнований удалены!';
  rsResultsExportedToFile =
    'Финишный протокол экспортирован в файл %s';
  rsStageResultsExported =
    'Результаты СУ %d (%s) экспортированы: %s';
  rsAllResultsExported = 'Все результаты экспортированы: %s';
  rsSumDaysExported = 'Сводные результаты по дням экспортированы: %s';
  rsStartListExported = 'Стартовый протокол экспортирован: %s';
  rsCSVResultsExported = 'Результаты экспортированы в CSV: %s';
  rsFullResultsExported = 'Итоговый протокол экспортирован: %s';
  rsExportFileError = 'Не удалось экспортировать файл "%s": %s';
  rsExportReportParameters = 'Параметры отчёта: групп штрафов — %d';
  rsResultsThruExportedToFile =
    'Сквозной протокол экспортирован в файл';
  rsDidNotStart = 'не стартовал';
  rsDidNotFinish = 'не финишировал';
  rsConfirmParticipantStatus =
    'Уверены, что участник под номером %s %s?';
  rsParticipantStatusSet = 'Участник с номером %s %s';
  rsConfirmParticipantStageStatus =
    'Уверены, что участник под номером %s %s на СУ %d?';
  rsParticipantStageStatusSet = 'Участник с номером %s %s на СУ %d';
  rsConfirmParticipantNamedStageStatus =
    'Уверены, что участник под номером %s %s на СУ %d: %s?';
  rsParticipantNamedStageStatusSet =
    'Участник с номером %s %s на СУ %d: %s';
  rsReallyDisqualifyNumber =
    'Действительно дисквалифицировать участника под номером %s?';
  rsParticipantDisqualified = 'Участник с номером %s дисквалифицирован';
  rsParticipantDoesNotExist = 'Номер %s не существует';
  rsFinishSkippedParticipantMissing =
    'Финиш пропущен: участник с номером %s отсутствует';
  rsLoRaCorrectionSkippedParticipantMissing =
    'Поправка LoRa пропущена: участник с номером %s отсутствует';
  rsCurrentResults = 'Текущие результаты';
  rsClearStatus =
    'Действительно убрать DNS/DNF с участника номер %s на СУ %d?';
  rsClearStatusLog = 'DNS/DNF убрано с участника номер %s на СУ %d';
  rsClearNamedStageStatus =
    'Действительно убрать DNS/DNF с участника номер %s на СУ %d: %s?';
  rsClearNamedStageStatusLog =
    'DNS/DNF убрано с участника номер %s на СУ %d: %s';
  rsClearAllStatus =
    'Действительно убрать DNS/DNF/DSQ с участника номер %s?';
  rsClearAllStatusLog = 'DNS/DNF/DSQ убрано с участника номер %s';
  rsClearDSQ = 'Действительно убрать DSQ с участника номер %s?';
  rsClearDSQLog = 'DSQ убрана с участника номер %s';
  rsDidNotStartSetFinish =
    'Номер %d не числится в списке стартовавших, но не финишировавших. Всё равно установить финишное время?';
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
    'Стартовый протокол финального заезда сформирован: %s';
  rsQualificationResults = 'По результатам квалификации';
  rsStartFileCreated = 'Файл для стартовых ворот создан';
  rsCorrectionAlreadySet =
    'Номеру %s поправка уже установлена. Перезаписать значение?';
  rsCOMOpenErrorDetails = 'Не удалось открыть порт %s: %s';
  rsPortClosed = 'Порт %s закрыт';
  rsPortConnected = 'Порт %s подключён';
  rsPortConnectionLost =
    'Потеряна связь с портом %s; ожидается автоматическое восстановление';
  rsPortConnectionRestored = 'Связь с портом %s восстановлена';
  rsModuleSynchronized =
    'Синхронизация модуля через порт %s завершена: %d';
  rsModuleSynchronizationError =
    'Не удалось синхронизировать модуль через порт %s: %s';
  rsLoRaRecordsReset = 'Состояние записей LoRa сброшено';
  rsLoRaRecordHidden = 'Запись LoRa скрыта: %s';
  rsLoRaRecordsLoadError = 'Не удалось загрузить записи LoRa: %s';
  rsLoRaRecordsRefreshWarning =
    'Изменение сохранено, но список LoRa не обновлён: %s';
  rsSerialCanRead = 'Чтение доступно: %s';
  rsSerialCanWrite = 'Запись доступна: %s';
  rsSerialReadCount = 'Прочитано: %s';
  rsSerialWriteCount = 'Записано: %s';
  rsSerialWait = 'Ожидание: %s';
  rsFinishTimeOpenError =
    'Неверный формат файла с результатами СУ';
  rsCanNotBackup = 'Не удалось сделать резервную копию!';
  rsClearResultsWithoutBackup =
    'Не удалось сделать резервную копию!%sВсё равно очистить результаты?';
  rsContinueLoadingResultsWithoutBackup =
    'Не удалось сделать резервную копию!%sПродолжить загрузку результатов?';
  rsBackupCreated = 'Создание резервной копии успешно завершено: %s';
  rsBackupDirectoryCreateError =
    'Не удалось создать каталог резервных копий: %s; резервная копия пропущена';
  rsBackupCreateError =
    'Не удалось создать резервную копию "%s": %s; резервная копия пропущена';
  rsBackupFileInvalid =
    'Резервная копия не создана или пуста: %s; резервная копия пропущена';
  rsLoadResultsError =
    'Ошибка загрузки результатов: ';
  rsWriteResultsDatabaseError =
    'Ошибка записи результатов в базу: ';
  rsParticipantsImportError =
    'Не удалось импортировать участников из файла "%s": %s';
  rsResultsImportError =
    'Не удалось импортировать результаты из файла "%s": %s';
  rsDayResultsImportError =
    'Не удалось импортировать результаты дня из файла "%s": %s';
  rsDayResultsRowsNotFound = 'Файл не содержит результатов дня';
  rsAddUnknownResultParticipant =
    'Участник с номером %d отсутствует в списке участников. Добавить его и загрузить результат?';
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
    'Введите новое время старта для номера %s на СУ: %s';
  rsAddDayResults = 'Добавить результаты дня %d?';
  rsSaveResults = 'Сохранить результаты?';
  rsFinishResultsNotEmpty =
    'На СУ %s результаты финиша не пусты. Вы уверены что хотите сформировать стартовый протокол для данного спецучастка?';
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
  rsDetectedParticipantStages = 'Обнаруженные СУ: %s';
  rsNewVersionAvailable = 'Доступна новая версия программы: %0:s. Перейти на сайт?';
  rsNewVersionFound = 'Доступна новая версия программы: %s';
  rsCheckForUpdates = 'Проверить обновления ...';
  rsCheckingForUpdates = 'Проверка обновлений ...';
  rsUpdateAvailable = 'Доступно обновление ...';
  rsUpdateCheckFailed = 'Не удалось проверить обновления: %s';
  rsAutomaticUpdateCheckFailed =
    'Автоматическая проверка обновлений не выполнена; приложение продолжает работу: %s';
  rsManualUpdateCheckStarted = 'Запущена ручная проверка обновлений';
  rsAutomaticUpdateCheckStarted = 'Запущена автоматическая проверка обновлений';
  rsUpdateCheckStartFailed = 'Не удалось запустить проверку обновлений';
  rsUpdateCheckCancelled = 'Проверка обновлений отменена';
  rsUpdatesNotFound = 'Нет доступных обновлений.';
  rsUnknownFileEncoding =
    'Не удалось определить кодировку файла. Продолжить?';
  rsUnknownFileEncodingContinued =
    'Кодировка файла не определена; импорт продолжен без преобразования';
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
