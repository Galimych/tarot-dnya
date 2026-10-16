import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Ежедневное напоминание "Твоя карта дня готова" — полностью локальное,
/// без сервера, без Firebase, без RuStore Push API. Само устройство
/// планирует показ уведомления в нужное время — никакой внешней
/// инфраструктуры, которая может смениться доменом или сертификатом,
/// здесь нет и не будет.
class NotificationsService {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    // На Android 13+ показ уведомлений требует разрешения в рантайме.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _scheduleDailyReminder();
  }

  /// Планирует ежедневное напоминание на 10:00 по местному времени.
  /// Время пока зашито в коде — вынести в настройки можно будет позже,
  /// когда в приложении появится отдельный экран настроек.
  Future<void> _scheduleDailyReminder({int hour = 10, int minute = 0}) async {
    await _plugin.zonedSchedule(
      0,
      'Твоя карта дня готова ✨',
      'Загляни, что приготовила тебе сегодня колода',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_card_channel',
          'Карта дня',
          channelDescription: 'Ежедневное напоминание открыть карту дня',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // inexactAllowWhileIdle не требует отдельного разрешения
      // SCHEDULE_EXACT_ALARM — уведомление может прийти с небольшим
      // отклонением по времени, что вполне приемлемо для напоминания.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
