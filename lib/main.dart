import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/notifications_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Без этой инициализации DateFormat('d MMMM', 'ru') в истории карт
  // выбрасывает исключение и приводит к пустому серому экрану в release-сборке.
  await initializeDateFormatting('ru', null);
  runApp(const TarotApp());
}

/// Загружает сторонние сервисы (реклама + хранилище + уведомления) до показа UI.
class _AppServices {
  final StorageService storage;
  final AdsService ads;
  _AppServices(this.storage, this.ads);

  static Future<_AppServices> load() async {
    final storage = await StorageService.create();
    final ads = AdsService();
    // Инициализация рекламы не должна блокировать запуск приложения —
    // если SDK не поднимется (нет сети, регион и т.п.), MVP продолжает
    // работать без rewarded-видео, просто предлагая только подписку.
    unawaited(ads.initialize());
    // Уведомления — полностью локальные, не требуют сети для планирования,
    // но инициализация всё равно не должна блокировать первый кадр UI.
    unawaited(NotificationsService().initialize());
    return _AppServices(storage, ads);
  }
}

class TarotApp extends StatelessWidget {
  const TarotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Таро дня',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // Русский язык для системных окон: календарь, выбор времени, кнопки.
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder<_AppServices>(
        future: _AppServices.load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Color(0xFF0D0221),
              body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
            );
          }
          final services = snapshot.data!;
          return HomeScreen(storage: services.storage, ads: services.ads);
        },
      ),
    );
  }
}
