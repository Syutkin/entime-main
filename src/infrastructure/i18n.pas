unit i18n;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

resourcestring
  rsLabelTemplateSaveAs = 'Сохранить как…';
  rsLabelTemplateSaveChanges = 'Сохранить изменения';
  rsLabelTemplateName = 'Название шаблона';
  rsLabelTemplateActions = 'Действия с шаблоном';
  rsLabelTemplateLabel = 'Шаблон';
  rsLabelCurrentSettings = 'Текущие настройки';
  rsLabelTemplateInvalidField =
    'Некорректный или отсутствующий параметр: %s';
  rsLabelTemplateDirectoryError = 'Не удалось создать каталог шаблонов.';
  rsLabelTemplateMissingFile = 'Файл шаблона не найден.';
  rsStartLabels = 'Стартовые наклейки';
  rsLabelPaper = 'Наклейка, мм';
  rsLabelMargins = 'Поля листа, мм';
  rsLabelGaps = 'Промежутки, мм';
  rsLabelContents = 'Содержимое';
  rsLabelWidth = 'Ширина';
  rsLabelHeight = 'Высота';
  rsLabelLeft = 'Слева';
  rsLabelRight = 'Справа';
  rsLabelTop = 'Сверху';
  rsLabelBottom = 'Снизу';
  rsLabelGapX = 'Между колонками';
  rsLabelGapY = 'Между рядами';
  rsLabelPadding = 'Внутренний отступ, мм';
  rsLabelFont = 'Шрифт таблицы, пт';
  rsLabelMinFont = 'Минимальный шрифт, пт';
  rsLabelFirst = 'Первая наклейка';
  rsLabelStartColumns = 'Колонки стартов';
  rsLabelBorders = 'Печатать границы наклеек';
  rsLabelPrintHint =
    'Печатайте PDF в масштабе 100% / «Фактический размер», без подгонки к странице.';
  rsLabelMarginsHint =
    'Слева и сверху — начало сетки; справа и снизу — минимальные поля. Остаток остаётся справа и снизу.';
  rsLabelFirstHint =
    'Заполнение слева направо, сверху вниз. Выбранная ячейка используется только на первом листе.';
  rsLabelGrid = '%d × %d, %d наклеек на листе';
  rsLabelReady =
    'Участников: %d; страниц: %d; шрифт таблицы: %d пт.';
  rsLabelFontReduced =
    'Шрифт уменьшен с %d до %d пт, чтобы вместить содержимое.';
  rsLabelIncomplete = 'Заполните параметры наклеек.';
  rsLabelInvalidSize =
    'Размеры наклейки должны быть положительными и не превышать A4.';
  rsLabelInvalidMargins =
    'Поля должны быть неотрицательными и оставлять место на A4.';
  rsLabelInvalidGaps =
    'Промежутки должны быть неотрицательными и не превышать размер листа.';
  rsLabelInvalidPadding =
    'Внутренний отступ должен оставлять место для содержимого наклейки.';
  rsLabelInvalidFont =
    'Размер шрифта: от 1 до 36 пт; минимум не больше обычного размера.';
  rsLabelNoSpace =
    'На листе не помещается ни одна наклейка. Проверьте размеры и поля.';
  rsLabelFirstReset =
    'Первая наклейка сброшена на 1: вместимость листа изменилась.';
  rsLabelOverflow =
    'Наклеек с переполнением: %d. Увеличьте размер наклейки или уменьшите отступы.';
  rsLabelBuildError = 'Не удалось сформировать наклейки: %s';
  rsLabelSettingsError =
    'Не удалось сохранить настройки наклеек: %s';
  rsLabelSaveError = 'Не удалось сохранить наклейки: %s';
  rsLabelSaved = 'Наклейки сохранены: %s';
  rsLabelSavePdf = 'Сохранить PDF…';
  rsLabelEmpty = 'Нет участников для печати наклеек.';
  rsPrintMode = 'Протокол';
  rsPrintOverall = 'Общий';
  rsPrintSingleStage = 'Отдельный СУ';
  rsStartFitWidth = 'Вместить по горизонтали';
  rsStartEveryStage = 'Все СУ';
  rsStartPrintTitle = 'Стартовый протокол';
  rsStartMode = 'Протокол';
  rsStartSingleStage = 'Отдельный СУ';
  rsStartOrder = 'Порядок';
  rsStartByTime = 'По времени старта';
  rsStartByNumber = 'По номеру';
  rsStartSortStage = 'Сортировать по старту СУ';
  rsStartIncludeMissing = 'Участники без времени старта';
  rsStartHeadingsHint =
    'Название соревнования и строка с видом стартового протокола.';
  rsStartHeaderHint =
    'Вид стартового протокола на каждой странице.';
  rsOverallStageResults = 'Результаты СУ';
  rsOverallStagePlaces = 'Места на СУ';
  rsOverallStageGaps = 'Отставания на СУ';
  rsOverallStagePenalties = 'Штрафы на СУ';
  rsOverallNoStages = 'Нет активных СУ.';
  rsOverallHeadingsHint =
    'Название соревнования и вид протокола в основном тексте.';
  rsOverallHeaderHint = 'Вид протокола на каждой странице.';

  rsTemplateTable =
    'В table допускаются строки tr из двух td с одним p в каждой.';
  rsPrintTemplate = 'Шаблон';
  rsPrintNoTemplate = 'Без шаблона';
  rsPrintBrowseTemplate = 'Выбрать…';
  rsPrintHeadings = 'Заголовки протокола';
  rsPrintHeadingsHint =
    'Название соревнования и строка с видом протокола и СУ в основном тексте.';
  rsPrintFooterHint =
    'Дата и номер страницы. Подписи берутся из шаблона.';
  rsPrintChooseTemplate = 'Выбрать HTML-шаблон';
  rsPrintTemplateFilter = 'HTML-шаблоны|*.html;*.htm';
  rsTemplateIncompleteHtml = 'Незавершённый HTML';
  rsTemplateInvalidUtf8 = 'Некорректный UTF-8';
  rsTemplateInvalidUnicode = 'Недопустимая сущность Unicode: &%s;';
  rsTemplateOneMarker = 'Требуется ровно одна метка {{RESULTS}}';
  rsTemplateSeparateMarker =
    'Метка {{RESULTS}} должна быть отдельным абзацем';
  rsTemplateOutsideText =
    'Текст вне абзаца: %s; {{RESULTS}} должна стоять отдельно';
  rsTemplateInvalidCss = 'Некорректный CSS: %s';
  rsTemplateUnsupportedCss = 'Неподдерживаемый CSS: %s';
  rsTemplateFontSize = 'Неподдерживаемый font-size: %s';
  rsTemplateAlignment = 'Неподдерживаемый text-align: %s';
  rsTemplateAttribute = 'Неподдерживаемый атрибут %s: %s';
  rsTemplateMeta = 'Поддерживается только meta charset="utf-8"';
  rsTemplateHeadElement = 'Неподдерживаемый элемент head: %s';
  rsTemplateOutsideElement = 'Элемент %s вне %s';
  rsTemplateElement = 'Неподдерживаемый элемент HTML: %s';
  rsTemplateMissingMarker = 'Отсутствует метка {{RESULTS}}';
  rsPrintNotImplemented =
    'Формирование этого протокола пока не реализовано.';
  rsPrintCategories = 'Категории';
  rsPrintAll = 'Выбрать все';
  rsPrintNone = 'Снять выбор';
  rsPrintOrientation = 'Ориентация A4';
  rsPrintPortrait = 'Книжная';
  rsPrintLandscape = 'Альбомная';
  rsPrintIncomplete = 'Участники без результата';
  rsPrintHeader = 'Верхний колонтитул';
  rsPrintHeaderHint =
    'Вид протокола и СУ на каждой странице.';
  rsPrintFooter = 'Нижний колонтитул';
  rsPrintPenalty = 'Штраф';
  rsPrintSave = 'Сохранить…';
  rsPrintEmpty =
    'Нет участников для выбранных параметров.';
  rsPrintBusy =
    'Дождитесь завершения текущей операции и повторите формирование.';
  rsPrintError = 'Не удалось сформировать протокол: %s';
  rsPrintSaveError = 'Не удалось сохранить протокол: %s';
  rsPrintFit = 'По ширине';
  rsPrintFirst = 'Первая страница';
  rsPrintPrevious = 'Предыдущая страница';
  rsPrintNext = 'Следующая страница';
  rsPrintLast = 'Последняя страница';
  rsPrintPending =
    'Есть несохранённые правки. Сформировать протокол по последним сохранённым данным? Правки сохранятся в редакторе.';
  rsPrintExported = 'Протокол сохранён: %s';
  rsBleNoClient = 'Клиент BLE не назначен';
  rsBleNoDevice = 'Устройство не выбрано';
  rsBleChecking = 'Проверка доступности Bluetooth…';
  rsBleUnavailable = 'Bluetooth недоступен';
  rsBleUnavailableDetail = 'Bluetooth недоступен: %s';
  rsBleScanning = 'Поиск устройств Bluetooth…';
  rsBleDisconnected = 'Отключено';
  rsBleConnecting = 'Подключение…';
  rsBleProfiles = 'Подготовка служб…';
  rsBleConnected = 'Подключено';
  rsBleWaiting = 'Ожидание повторного подключения…';
  rsBleDisconnecting = 'Отключение…';
  rsBleError = 'Ошибка подключения';
  rsBleErrorDetail = 'Ошибка подключения: %s';
  rsBleDisconnect = 'Отключить';
  rsBleConnect = 'Подключить';
  rsCardTitle = 'Карточка участника';
  rsCardResults = 'Результаты';
  rsCardPersonal = 'Сведения';
  rsCardSaved = 'Показаны сохранённые данные.';
  rsCardMarkKind = 'Тип отсечки';
  rsCardMarks = 'Отсечки с номером %d';
  rsCardMarkScope = 'Выбранный СУ';
  rsCardAllStages = 'Все СУ';
  rsCardNumberScope =
    'Записи связаны с текущим сохранённым номером. История прежних номеров и происхождения результатов не восстанавливается.';
  rsCardInactive = 'неактивен';
  rsCardStageOutside = 'СУ %d (вне конфигурации)';
  rsCardOpenJournal = 'Открыть в журнале';
  rsCardGoParticipant = 'Перейти к участнику';
  rsCardRefresh = 'Обновить';
  rsCardRefreshHint =
    'Перечитать сохранённые данные участника и отсечки с его текущим номером.';
  rsCardClose = 'Закрыть';
  rsCardReadError = 'Не удалось обновить карточку: %s';
  rsCardStale =
    'Данные изменились. Карточка обновляется…';
  rsCardBusy = 'Дождитесь завершения текущей операции.';
  rsCardMarkChanged =
    'Отсечка изменилась или больше не найдена. Проверьте обновлённые данные и выберите запись заново.';
  rsCardDeleted =
    'Участник больше не найден в соревновании.';
  rsCardPending = 'Ожидает';
  rsCardApplied = 'Применена';
  rsCardHidden = 'Скрыта';
  rsCardConflict = 'Конфликт';
  rsCardError = 'Ошибка';
  rsCardIgnored = 'Подавлена антидребезгом';
  rsCardAutomatic = 'Автоматически';
  rsCardManual = 'Вручную';
  rsCardPhone = 'Телефон';
  rsCardEmail = 'Email';
  rsCardComment = 'Комментарий';
  rsCardStageCount = 'СУ с результатом';
  rsCardThruPlace = 'Место в сквозном протоколе';
  rsCardThruGap = 'Отставание в сквозном протоколе';

  rsImportPreview = 'Сравнение перед импортом';
  rsImportPreviewFile = 'Файл: %s';
  rsImportPreviewStage = 'СУ %d — %s · %s';
  rsImportPreviewFinishFormat = 'Финиши';
  rsImportPreviewStartFormat = 'Старты и поправки';
  rsImportPreviewFullFormat = 'Полный СУ';
  rsImportPreviewSelectAllHint =
    'Выбрать изменения во всём файле для известных и подтверждённых новых участников.';
  rsImportPreviewClearHint =
    'Снять выбор всех полей и создание новых номеров.';
  rsImportPreviewChanges = 'Изменения';
  rsImportPreviewUnknown = 'Неизвестные номера';
  rsImportPreviewSelect = 'Применить';
  rsImportPreviewCurrent = 'Сейчас';
  rsImportPreviewProposed = 'Из файла';
  rsImportPreviewField = 'Поле';
  rsImportPreviewAction = 'Действие';
  rsImportPreviewFill = 'Заполнить';
  rsImportPreviewReplace = 'Заменить';
  rsImportPreviewClear = 'Очистить';
  rsImportPreviewSame = 'Без изменений';
  rsImportPreviewAll = 'Все изменения';
  rsImportPreviewShowSame = 'Показать без изменений';
  rsImportPreviewSelectAll = 'Выбрать все изменения';
  rsImportPreviewClearSelection = 'Снять выбор';
  rsImportPreviewRefresh = 'Обновить сравнение';
  rsImportPreviewRefreshHint =
    'Заново сравнить сохранённые данные соревнования с уже загруженным CSV.'#10'Выбор неизменившихся значений сохранится; изменившиеся нужно выбрать заново.';
  rsImportPreviewConfirmAll =
    'Создать все неизвестные номера';
  rsImportPreviewCreate = 'Создать';
  rsImportPreviewSourceRow = 'Строка файла';
  rsImportPreviewApply = 'Применить выбранное';
  rsImportPreviewCancel = 'Отмена';
  rsImportPreviewSummary =
    'Заполнений: %d · Замен: %d · Очисток: %d · Без изменений: %d · Неизвестных номеров: %d';
  rsImportPreviewSelected =
    'Выбрано полей: %d · Участников: %d · Создать: %d';
  rsImportPreviewReady =
    'Проверьте значения и выберите изменения. После импорта результаты и производные статусы пересчитываются по действующим правилам.';
  rsImportPreviewEmpty = 'Нет изменений для применения.';
  rsImportPreviewStale =
    'Данные изменились. Сравнение обновлено; проверьте и заново выберите изменившиеся значения.';
  rsImportPreviewSessionChanged =
    'Соревнование или выбранный СУ изменились. Откройте сравнение заново.';
  rsImportPreviewError = 'Не удалось выполнить импорт: %s';
  rsImportPreviewApplied =
    'Импорт СУ %d: изменено полей %d, участников %d, создано %d, пропущено %d.';
  rsImportPreviewApplying =
    'Импорт СУ %d: выбрано полей %d, создать %d.';
  rsImportPreviewCancelled = 'Импорт отменён.';
  rsImportPreviewEditorSaveError =
    'Не удалось сохранить текущие правки: %s';
  rsImportPreviewSaveEditor =
    'Сохранить изменения в основной таблице перед сравнением импорта?';
  rsImportPreviewSavedRefreshError =
    'Импорт сохранён. Не удалось обновить отображение: %s';
  //имена колонок
  rsCorrection = 'Поправка';
  rsStarttime = 'Старт';
  rsFinishtime = 'Финиш';
  rsPenalty = 'Штраф';
  rsResult = 'Результат';
  rsDiffleader = 'Отставание';
  rsPlace = 'Место';
  rsStatus = 'Статус';
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
  rsSUFormat = 'СУ %d';

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
  rsSettingsTimingInput = 'Источник отсечек';
  rsSettingsLEDPanel = 'LED панель';
  rsSettingsTelegramBot = 'Телеграм бот';
  rsTimingInputMode = 'Тип подключения';
  rsTimingInputSerial = 'Serial (COM-порт)';
  rsTimingInputBle = 'BLE';
  rsTimingInputSerialSettings = 'Настройки Serial';
  rsBleDeviceNeedsScan =
    'Устройство не найдено. Нажмите на его название и повторите поиск.';
  rsTimingInputBleSettings = 'Настройки BLE';
  rsTimingInputBleDevice = 'Устройство';
  rsTimingInputBleDeviceId = 'Идентификатор';
  rsTimingInputSelectDevice = 'Выбрать…';
  rsTimingInputDeviceNotSelected = 'Не выбрано';
  rsStartMarkSettings = 'Стартовые отметки';
  rsStartMarkMatchDeltaSeconds = 'Допуск, секунд (±)';
  rsStartMarkMatchDeltaHint =
    'Максимальная разница между временем отметки и стартовым временем'#10'участника для автоматической подстановки номера.';
  rsStartMarkAutomaticApply = 'Применять автоматически';
  rsStartMarkAutomaticApplyHint =
    'При однозначном совпадении автоматически применить поправку к участнику.'#10'Существующая поправка не перезаписывается.';
  rsStartMarks = 'Стартовые отметки';
  rsFinishMarks = 'Финишные отметки';
  rsOpenStartMarksWindow = 'В новом окне';
  rsOpenStartMarksWindowHint =
    'Открыть журнал стартовых отметок';
  rsOpenFinishMarksWindow = 'В новом окне';
  rsOpenFinishMarksWindowHint =
    'Открыть журнал финишных отметок';
  rsTime = 'Время';
  rsId = 'ID';
  rsReceivedStage = 'Этап приёма';
  rsAppliedStage = 'Этап применения';
  rsMatchDeltaMs = 'Дельта, мс';
  rsTransport = 'Транспорт';
  rsDevice = 'Устройство';
  rsAssignmentMode = 'Режим назначения';
  rsReceivedAt = 'Получено';
  rsAppliedAt = 'Применено';
  rsDiagnostic = 'Диагностика';
  rsStartMarkJournalFilter = 'Фильтр';
  rsStartMarkJournalFilterAll = 'Все';
  rsStartMarkJournalFilterPending = 'Ожидающие';
  rsStartMarkJournalFilterApplied = 'Применённые';
  rsStartMarkJournalFilterHidden = 'Скрытые';
  rsStartMarkJournalFilterConflictOrError =
    'Конфликтные и ошибочные';
  rsStartMarkJournalFilterLast15Minutes = 'Последние 15 минут';
  rsStartMarkJournalFilterCurrentStage = 'С начала текущего этапа';
  rsStartMarkJournalFilterPendingOrConflict =
    'К разбору (ожидающие и конфликтные)';
  rsStartMarkJournalFilterError = 'Ошибочные';
  rsStartMarkJournalRefreshWarning =
    'Не удалось обновить журнал стартовых отметок: %s';
  rsFinishMarkJournalFilter = 'Фильтр';
  rsFinishMarkJournalFilterAll = 'Все';
  rsFinishMarkJournalFilterPending = 'Ожидающие';
  rsFinishMarkJournalFilterApplied = 'Применённые';
  rsFinishMarkJournalFilterIgnoredDebounce = 'Отброшенные debounce';
  rsFinishMarkJournalFilterHidden = 'Скрытые';
  rsFinishMarkJournalFilterError = 'Ошибочные';
  rsFinishMarkJournalFilterLast15Minutes = 'Последние 15 минут';
  rsFinishMarkJournalFilterCurrentStage = 'С начала текущего этапа';
  rsFinishMarkJournalRefreshWarning =
    'Не удалось обновить журнал финишных отметок: %s';
  rsCopy = 'Копировать';
  rsClear = 'Очистить';
  rsWrite = 'Записать';
  rsStartMarkNumberSaveError =
    'Не удалось сохранить номер стартовой отметки: %s';
  rsStartMarkStageChoiceTitle = 'Выбор этапа';
  rsStartMarkStageChoiceMessage =
    'Стартовая отметка номера %d принята на этапе %d — %s, а сейчас выбран этап %d — %s. К какому этапу применить поправку?';
  rsApplyToReceivedStage = 'Применить к исходному этапу %d';
  rsApplyToCurrentStage = 'Применить к текущему этапу %d';
  rsStartMarkCorrectionMissing =
    'В стартовой отметке номера %d отсутствует поправка';
  rsStartMarkApplyError =
    'Не удалось применить стартовую отметку номера %d: %s';
  rsStartMarkApplied =
    'Стартовая отметка номера %d применена: этап приёма %d, этап применения %d, поправка %d';
  rsStartMarkRefreshWarning =
    'Отметка применена, но не удалось обновить списки: %s';
  rsStartMarksHidden = 'Стартовые отметки скрыты: %d';
  rsStartMarksHideError =
    'Не удалось скрыть стартовые отметки: %s';
  rsStartMarksHideRefreshWarning =
    'Отметки скрыты, но не удалось обновить список: %s';
  rsFinishMarkNumberSaveError =
    'Не удалось сохранить номер финишной отметки: %s';
  rsParticipantNumberMustBePositive =
    'Номер участника должен быть больше нуля';
  rsFinishMarksHidden = 'Финишные отметки скрыты: %d';
  rsFinishMarksHideError =
    'Не удалось скрыть финишные отметки: %s';
  rsFinishMarksHideRefreshWarning =
    'Финишные отметки скрыты, но не удалось обновить список: %s';
  rsUpdateEveryTime = 'Каждый раз';
  rsUpdateDaily = 'Один раз в сутки';
  rsUpdateWeekly = 'Один раз в неделю';
  rsUpdateMonthly = 'Один раз в месяц';

  //баланс протокола
  rsStatisticsOverview = 'Обзор';
  rsProtocolBalance = 'Баланс протокола';
  rsProtocolBalanceNotConnected =
    'Данные баланса пока не подключены.';
  rsProtocolBalanceRefresh = 'Обновить';
  rsProtocolBalanceStageNotSelected = 'СУ не выбран';
  rsProtocolBalanceShow = 'Показать:';
  rsProtocolBalanceRecordCountUnavailable = 'Записей: —';
  rsProtocolBalanceParticipants = 'Участников';
  rsProtocolBalanceWithResult = 'С результатом';
  rsProtocolBalanceUnresolved = 'Без итога';
  rsProtocolBalanceAllParticipants = 'Все участники';
  rsProtocolBalanceFinishWithoutStart = 'Финиш без старта';
  rsProtocolBalanceGroup = 'Группа';
  rsProtocolBalanceState = 'Состояние';
  rsProtocolBalanceIncoming = 'Входящие отсечки';
  rsProtocolBalancePendingStartsUnavailable = 'Старты к разбору: —';
  rsProtocolBalancePendingFinishesUnavailable = 'Финиши к разбору: —';
  rsProtocolBalanceStartErrorsUnavailable = 'Ошибки стартов: —';
  rsProtocolBalanceFinishErrorsUnavailable = 'Ошибки финишей: —';
  rsProtocolBalanceOpenParticipant = 'Перейти к участнику';
  rsProtocolBalanceOpenCompetition = 'Откройте соревнование.';
  rsProtocolBalanceNoActiveStages = 'Нет активных СУ.';
  rsProtocolBalanceNoParticipants =
    'В соревновании нет участников.';
  rsProtocolBalanceNoMatchingParticipants =
    'В выбранной группе нет участников.';
  rsProtocolBalanceReady =
    'Показаны сохранённые данные соревнования.';
  rsProtocolBalanceStale =
    'Данные изменились; ожидается обновление.';
  rsProtocolBalanceReadError = 'Не удалось загрузить баланс: %s';
  rsProtocolBalanceRecordCount = 'Записей: %d';
  rsProtocolBalancePendingStarts = 'Старты к разбору: %d';
  rsProtocolBalancePendingFinishes = 'Финиши к разбору: %d';
  rsProtocolBalanceStartErrors = 'Ошибки стартов: %d';
  rsProtocolBalanceFinishErrors = 'Ошибки финишей: %d';
  rsProtocolBalanceNoStageData = 'Нет данных по СУ';
  rsProtocolBalanceMissingFinish = 'Нет финиша и статуса';
  rsProtocolBalanceMissingResult =
    'Результат отсутствует или некорректен';
  rsProtocolBalanceInvalidResult = 'Некорректный результат: %s';
  rsProtocolBalanceUnknownStatus = 'Неизвестный статус: %s';
  rsProtocolBalanceSaveBeforeNavigation =
    'Сохранить изменения в основной таблице перед переходом?';
  rsProtocolBalanceParticipantMissing =
    'Участник больше не найден в соревновании.';
  rsProtocolBalanceStageUnavailable =
    'Выбранный СУ больше не активен.';
  rsProtocolBalanceNavigationError =
    'Не удалось открыть запись: %s';

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
  rsCompetitionSettingsSaveError =
    'Не удалось сохранить настройки соревнования: %s';
  rsStageCount = 'Количество спецучастков';
  rsStageCountRangeError =
    'Недопустимое количество СУ: %s. Допустимый диапазон: %d..%d';
  rsAtLeastOneActiveStageRequired =
    'Должен быть включён хотя бы один спецучасток';
  rsStageCountReductionWarning =
    'При уменьшении количества СУ с %d до %d результаты скрываемых СУ останутся в файле, но не будут учитываться и отображаться. Продолжить?';
  rsStageCapacityExpansionBackupError =
    'Расширение количества СУ отменено: не удалось создать резервную копию файла "%s"';
  rsStageResultsCalculationError =
    'Не удалось пересчитать результаты СУ: %s';
  rsSumResultsCalculationError =
    'Не удалось пересчитать суммарные результаты: %s';
  rsSumDurationLimitExceeded =
    'Суммарное время участника %s достигло или превысило 24 часа; текущий формат результата не отображает полные сутки';
  rsThruResultsCalculationError =
    'Не удалось пересчитать сквозные результаты: %s';
  rsResultsClearError =
    'Не удалось удалить результаты соревнования: %s';
  rsCategoryListLoadError =
    'Не удалось загрузить список категорий: %s';
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
  rsUpdateFinishTime =
    'Обновить финишное время для номера %d?';
  rsSetIntervalWarning =
    'Интервал задаётся как целое неотрицательное число миллисекунд';
  rsPenaltyTimeFormat =
    'Штрафное время вводится в формате сс, мм:сс или чч:мм:сс';
  rsParticipantStatusValueFormat =
    'Некорректный статус. Допустимы DNF, DNS, DSQ, коды 1, 2, 3 или пустое значение';
  rsFinishTimeSetForStages =
    'Установлено финишное время для номера %d; СУ: %s';
  rsDeleteNumber =
    'Действительно удалить участника c номером %s?';
  rsParticipantDeleted = 'Участник с номером %s удалён';
  rsParticipantUpdated =
    'Данные участника с номером %s изменены';
  rsParticipantFieldUpdated = 'Номеру %s изменено поле «%s»';
  rsParticipantFieldValueChanged =
    'Номеру %s изменено поле «%s»: %s → %s';
  rsParticipantNumberChanged =
    'Номер участника изменён с %s на %s';
  rsEmptyLogValue = '(пусто)';
  rsParticipantCorrectionSet =
    'Номеру %s установлена поправка на СУ %d: %s';
  rsParticipantStartTimeSet =
    'Номеру %s установлено время старта на СУ %d: %s';
  rsParticipantStageValueChanged =
    'Номеру %s изменено поле «%s» на СУ %d: %s → %s';
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
  rsLEDPanelTestSucceeded =
    'Проверка LED-панели выполнена успешно';
  rsLEDPanelInvalidAddress =
    'Некорректный адрес LED-панели: укажите host[:port]';
  rsTelegramBotEnabled = 'Telegram-бот включён';
  rsTelegramBotDisabled = 'Telegram-бот выключен';
  rsTelegramBotTestSucceeded =
    'Проверка Telegram-бота выполнена успешно';
  rsTelegramRetryEnabled = 'Повторять при ошибке';
  rsTelegramRetryCount = 'Количество повторов';
  rsTelegramRetryDelaySeconds = 'Интервал, секунд';
  rsTelegramQueueItemDropped =
    'Очередь Telegram переполнена: удалено ожидающее уведомление участника %d, поставленное %s';
  rsTelegramQueueCleared =
    'При закрытии удалено ожидающих уведомлений Telegram: %d';
  rsHTTPRequestMetadata = 'HTTP-запрос: %s; параметров: %d';
  rsHTTPResponseMetadata =
    'HTTP-ответ: %d %s; заголовков: %d; байт: %d';
  rsHTTPResponseReceived = 'Получен HTTP-ответ: %d байт';
  rsHTTPRequestNotStarted = 'не удалось запустить HTTP-запрос';
  rsOpenStartListFile =
    'Открытие файла стартового протокола: %s';
  rsOpenResultsFile = 'Открытие файла результатов: %s';
  rsTimingFinish = 'Финиш -> %s';
  rsSerialRaw = 'Исходные данные -> %s';
  rsSerialPacketRejected =
    'Serial-пакет отклонён: причина=%s; данные=%s';
  rsTimingStart = 'Старт -> %s, %s';
  rsTelegramBotError = 'Ошибка Telegram-бота: %s';
  rsLoadCSVParticipants = 'Список участников загружен';
  rsImportFinishtime =
    'Финишное время для СУ %d: %s загружено';
  rsImportStarttime =
    'Стартовый протокол для СУ %d: %s загружен';
  rsParticipantsImported =
    'Участники импортированы: %d; файл: %s';
  rsResultsImported =
    'Результаты импортированы для СУ %d (%s): %d; файл: %s';
  rsResultsImportPartial =
    'Результаты импортированы частично для СУ %d (%s): %d из %d; файл: %s';
  rsResultsImportFormat =
    'Формат файла результатов: %d колонок';
  rsDBFileClosed = 'Файл соревнований закрыт: %s';
  rsDBFileOpen = 'Файл соревнований открыт: %s';
  rsLogDirectoryOpenError =
    'Не удалось открыть каталог журнала: %s';
  rsLogFileOpenError = 'Не удалось открыть файл журнала: %s';
  rsResultsCleared = 'Результаты соревнований удалены!';
  rsResultsExportedToFile =
    'Финишный протокол экспортирован в файл %s';
  rsStageResultsExported =
    'Результаты СУ %d (%s) экспортированы: %s';
  rsStartListExported =
    'Стартовый протокол экспортирован: %s';
  rsCSVResultsExported = 'Результаты экспортированы в CSV: %s';
  rsFullResultsExported =
    'Итоговый протокол экспортирован: %s';
  rsExportFileError = 'Не удалось экспортировать файл "%s": %s';
  rsExportReportParameters =
    'Параметры отчёта: групп штрафов — %d';
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
  rsParticipantDisqualified =
    'Участник с номером %s дисквалифицирован';
  rsParticipantDoesNotExist = 'Номер %s не существует';
  rsFinishSkippedParticipantMissing =
    'Финиш пропущен: участник с номером %s отсутствует';
  rsCurrentResults = 'Текущие результаты';
  rsClearStatus =
    'Действительно убрать DNS/DNF с участника номер %s на СУ %d?';
  rsClearStatusLog =
    'DNS/DNF убрано с участника номер %s на СУ %d';
  rsClearNamedStageStatus =
    'Действительно убрать DNS/DNF с участника номер %s на СУ %d: %s?';
  rsClearNamedStageStatusLog =
    'DNS/DNF убрано с участника номер %s на СУ %d: %s';
  rsClearAllStatus =
    'Действительно убрать DNS/DNF/DSQ с участника номер %s?';
  rsClearAllStatusLog = 'DNS/DNF/DSQ убрано с участника номер %s';
  rsClearDSQ =
    'Действительно убрать DSQ с участника номер %s?';
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
  rsConnectToPort = 'Подключиться к порту %s';
  rsDisconnectFromPort = 'Отключиться от порта %s';
  rsNoAvailableSerialPorts = 'Доступные порты не найдены';
  rsPortClosed = 'Порт %s закрыт';
  rsPortConnected = 'Порт %s подключён';
  rsPortConnectionLost =
    'Потеряна связь с портом %s; ожидается автоматическое восстановление';
  rsPortConnectionRestored = 'Связь с портом %s восстановлена';
  rsPortUnavailable = 'Порт %s недоступен';
  rsModuleSynchronized =
    'Синхронизация модуля через порт %s завершена: %d';
  rsModuleSynchronizationError =
    'Не удалось синхронизировать модуль через порт %s: %s';
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
  rsBackupCreated =
    'Создание резервной копии успешно завершено: %s';
  rsBackupDirectoryCreateError =
    'Не удалось создать каталог резервных копий: %s; резервная копия пропущена';
  rsBackupCreateError =
    'Не удалось создать резервную копию "%s": %s; резервная копия пропущена';
  rsBackupFileInvalid =
    'Резервная копия не создана или пуста: %s; резервная копия пропущена';
  rsBackupCleanupCompleted =
    'Удалено старых резервных копий: %d, освобождено: %d байт';
  rsBackupCleanupWarning =
    'Очистка резервных копий завершена с предупреждением: %s';
  rsBackupRetentionLabel = 'Хранить автоматические копии';
  rsDays = 'дней';
  rsBackupMaxSizeMbLabel = 'Максимальный объём копий';
  rsMegabytes = 'МБ';
  rsSchemaMigrationStarted =
    'Начата миграция схемы файла "%s": версия %d → %d';
  rsSchemaMigrationCompleted =
    'Миграция схемы файла "%s" завершена: версия %d, СУ: %d, ёмкость: %d';
  rsSchemaMigrationError =
    'Не удалось мигрировать схему файла "%s": %s';
  rsSchemaMigrationBackupError =
    'Миграция отменена: не удалось создать резервную копию файла "%s"';
  rsSchemaVersionTooNew =
    'Версия схемы %d новее поддерживаемой версии %d';
  rsLoadResultsError =
    'Ошибка загрузки результатов: ';
  rsWriteResultsDatabaseError =
    'Ошибка записи результатов в базу: ';
  rsParticipantsImportError =
    'Не удалось импортировать участников из файла "%s": %s';
  rsResultsImportError =
    'Не удалось импортировать результаты из файла "%s": %s';
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
  rsParticipantStagesApplied =
    'Активные СУ из списка участников: %s; выключено ранее активных СУ: %d';
  rsParticipantStageCountExpanded =
    'Количество СУ расширено по списку участников: %d → %d';
  rsNewVersionAvailable =
    'Доступна новая версия программы: %0:s. Перейти на сайт?';
  rsNewVersionFound = 'Доступна новая версия программы: %s';
  // Сведения на вкладке «Общие» окна «О программе».
  rsAboutDialogCaption = 'О программе';
  rsAboutLibraries = 'Библиотеки:';
  rsAboutChsdetVersion = 'chsdet: %d.%d.%d';
  rsAboutSQLiteVersion = 'SQLite: %s';
  rsAboutTLazSerialVersion = 'TLazSerial: %s';
  rsAboutLazBleVersion = 'LazBle: %s';
  rsAboutBleBackend = 'Бекэнд BLE: %s';
  rsAboutSimpleCbleVersion = 'SimpleCBLE: %s';
  rsAboutNativeVersionNotObtained = 'версия не получена';
  rsAboutVersionNotObtainedWithReason = 'версия не получена (%s)';
  rsAboutBleAdapter = 'Адаптер BLE: %s';
  rsAboutBleError = 'Ошибка BLE: %s';
  rsAboutIconSet = 'Набор иконок: Fugue Icons';
  rsCheckForUpdates = 'Проверить обновления ...';
  rsCheckingForUpdates = 'Проверка обновлений ...';
  rsUpdateAvailable = 'Доступно обновление ...';
  rsUpdateCheckFailed =
    'Не удалось проверить обновления: %s';
  rsAutomaticUpdateCheckFailed =
    'Автоматическая проверка обновлений не выполнена; приложение продолжает работу: %s';
  rsManualUpdateCheckStarted =
    'Запущена ручная проверка обновлений';
  rsAutomaticUpdateCheckStarted =
    'Запущена автоматическая проверка обновлений';
  rsUpdateCheckStartFailed =
    'Не удалось запустить проверку обновлений';
  rsUpdateCheckCancelled = 'Проверка обновлений отменена';
  rsUpdatesNotFound = 'Нет доступных обновлений.';
  rsUnknownFileEncoding =
    'Не удалось определить кодировку файла. Продолжить?';
  rsUnknownFileEncodingContinued =
    'Кодировка файла не определена; импорт продолжен без преобразования';
  rsUnsupportedFileEncoding =
    'Неподдерживаемая кодировка файла: %s';
  rsTooManyParticipantStages =
    'В файле найдено %d СУ, но поддерживается не более %d';
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
