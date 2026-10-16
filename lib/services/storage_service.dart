import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/cards_data.dart';
import '../models/tarot_card.dart';

/// Отвечает за всё локальное состояние: карта дня, стрик, история,
/// статус подписки, лимит бесплатных дополнительных раскладов.
class StorageService {
  static const _kTodayCardNumber = 'today_card_number';
  static const _kTodayDate = 'today_date';
  static const _kStreak = 'streak';
  static const _kLastOpenDate = 'last_open_date';
  static const _kHistory = 'history';
  static const _kIsSubscribed = 'is_subscribed';
  static const _kFreeSpreadUsedDate = 'free_spread_used_date';
  static const _kDiscoveredCards = 'discovered_cards';
  static const _kCelebratedMilestones = 'celebrated_milestones';
  static const _kLastMonthlyCardMonth = 'last_monthly_card_month';
  static const _kMonthlyCardNumber = 'monthly_card_number';
  static const _kGuessCorrect = 'guess_correct_count';
  static const _kGuessTotal = 'guess_total_count';

  /// Рубежи стрика, за которые показывается небольшое поздравление.
  static const streakMilestones = [7, 30, 100, 365];

  /// Если сегодня впервые достигнут один из рубежей — здесь будет его
  /// значение (чтобы HomeScreen показал поздравление один раз).
  int? justReachedMilestone;

  final SharedPreferences _prefs;
  StorageService._(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// true, если карта дня уже была сгенерирована сегодня раньше (то есть
  /// это не первое открытие приложения за день). Нужно вызывать ДО
  /// getOrCreateTodayCard(), чтобы понять, стоит ли предлагать игру
  /// "Угадай карту" перед показом — она имеет смысл только один раз
  /// в день, при самом первом открытии.
  bool isTodayCardAlreadyRevealed() {
    return _prefs.getString(_kTodayDate) == _todayKey();
  }

  /// Возвращает карту дня, генерируя новую, если сегодняшняя ещё не выбрана.
  Future<TarotCard> getOrCreateTodayCard() async {
    final todayKey = _todayKey();
    final storedDate = _prefs.getString(_kTodayDate);

    if (storedDate == todayKey) {
      final number = _prefs.getInt(_kTodayCardNumber);
      if (number != null) return cardByNumber(number);
    }

    // Новый день — выбираем новую карту и обновляем стрик.
    final random = Random();
    final card = allCards[random.nextInt(allCards.length)];
    await _prefs.setInt(_kTodayCardNumber, card.number);
    await _prefs.setString(_kTodayDate, todayKey);

    await _updateStreak();
    await _addToHistory(card);
    await markCardsDiscovered([card.number]);

    return card;
  }

  Future<void> _updateStreak() async {
    final lastOpen = _prefs.getString(_kLastOpenDate);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';

    int streak = _prefs.getInt(_kStreak) ?? 0;
    if (lastOpen == yesterdayKey) {
      streak += 1;
    } else if (lastOpen != _todayKey()) {
      streak = 1;
    }
    await _prefs.setInt(_kStreak, streak);
    await _prefs.setString(_kLastOpenDate, _todayKey());

    if (streakMilestones.contains(streak)) {
      final celebrated = _prefs.getStringList(_kCelebratedMilestones) ?? [];
      if (!celebrated.contains(streak.toString())) {
        celebrated.add(streak.toString());
        await _prefs.setStringList(_kCelebratedMilestones, celebrated);
        justReachedMilestone = streak;
      }
    }
  }

  int getStreak() => _prefs.getInt(_kStreak) ?? 0;

  Future<void> _addToHistory(TarotCard card) async {
    final history = _prefs.getStringList(_kHistory) ?? [];
    final entry = CardHistoryEntry(card: card, date: DateTime.now());
    history.insert(0, jsonEncode(entry.toJson()));
    // Храним последние 60 записей — достаточно для истории на экране.
    final trimmed = history.take(60).toList();
    await _prefs.setStringList(_kHistory, trimmed);
  }

  List<CardHistoryEntry> getHistory() {
    final raw = _prefs.getStringList(_kHistory) ?? [];
    return raw.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      final card = cardByNumber(json['cardNumber'] as int);
      return CardHistoryEntry.fromJson(json, card);
    }).toList();
  }

  /// Сохраняет личную заметку пользователя к конкретной записи истории,
  /// определяя запись по дате (одна карта дня на дату — уникальный ключ).
  Future<void> saveNoteForDate(DateTime date, String note) async {
    final raw = _prefs.getStringList(_kHistory) ?? [];
    final updated = raw.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      final entryDate = DateTime.parse(json['date'] as String);
      if (entryDate.year == date.year &&
          entryDate.month == date.month &&
          entryDate.day == date.day) {
        json['note'] = note;
      }
      return jsonEncode(json);
    }).toList();
    await _prefs.setStringList(_kHistory, updated);
  }

  bool isSubscribed() => _prefs.getBool(_kIsSubscribed) ?? false;

  Future<void> setSubscribed(bool value) async {
    await _prefs.setBool(_kIsSubscribed, value);
  }

  /// Бесплатный пользователь может открыть один дополнительный расклад в день.
  bool canUseFreeSpreadToday() {
    final usedDate = _prefs.getString(_kFreeSpreadUsedDate);
    return usedDate != _todayKey();
  }

  Future<void> markFreeSpreadUsed() async {
    await _prefs.setString(_kFreeSpreadUsedDate, _todayKey());
  }

  /// Отмечает карты как встреченные — для отслеживания прогресса
  /// коллекционирования колоды. Не завязано на историю (которая хранит
  /// только последние 60 записей), поэтому прогресс не теряется со временем.
  Future<void> markCardsDiscovered(List<int> cardNumbers) async {
    final current = _prefs.getStringList(_kDiscoveredCards) ?? [];
    final set = current.toSet();
    set.addAll(cardNumbers.map((n) => n.toString()));
    await _prefs.setStringList(_kDiscoveredCards, set.toList());
  }

  /// Номера всех когда-либо встреченных карт.
  Set<int> getDiscoveredCardNumbers() {
    final raw = _prefs.getStringList(_kDiscoveredCards) ?? [];
    return raw.map(int.parse).toSet();
  }

  /// Карта месяца — отдельный, более редкий ритуал по сравнению с картой
  /// дня. Выбирается один раз в начале месяца и остаётся неизменной до
  /// следующего месяца.
  Future<TarotCard> getOrCreateMonthlyCard() async {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month}';
    final storedMonth = _prefs.getString(_kLastMonthlyCardMonth);

    if (storedMonth == monthKey) {
      final number = _prefs.getInt(_kMonthlyCardNumber);
      if (number != null) return cardByNumber(number);
    }

    final random = Random();
    final card = allCards[random.nextInt(allCards.length)];
    await _prefs.setInt(_kMonthlyCardNumber, card.number);
    await _prefs.setString(_kLastMonthlyCardMonth, monthKey);
    await markCardsDiscovered([card.number]);

    return card;
  }

  /// Мини-игра "Угадай карту": пользователь пытается угадать карту дня
  /// до того, как она перевёрнута. Записываем статистику для отображения
  /// процента угаданных карт.
  Future<void> recordGuess(bool correct) async {
    final total = (_prefs.getInt(_kGuessTotal) ?? 0) + 1;
    final right = (_prefs.getInt(_kGuessCorrect) ?? 0) + (correct ? 1 : 0);
    await _prefs.setInt(_kGuessTotal, total);
    await _prefs.setInt(_kGuessCorrect, right);
  }

  /// (сколько угадано, всего попыток).
  (int, int) getGuessStats() {
    return (_prefs.getInt(_kGuessCorrect) ?? 0, _prefs.getInt(_kGuessTotal) ?? 0);
  }
}
