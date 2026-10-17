import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/notifications_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ловим необработанные ошибки и показываем их на экране загрузки —
  // иначе при сбое приложение молча зависает с бесконечным кружком.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reportError(details.exceptionAsString());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(error);
    return true;
  };

  try {
    // Без этой инициализации DateFormat('d MMMM', 'ru') в истории карт
    // выбрасывает исключение и приводит к пустому серому экрану.
    await initializeDateFormatting('ru', null);
  } catch (e) {
    reportError(e);
  }
  runApp(const TarotApp());
}

/// Загружает сторонние сервисы (реклама + хранилище + уведомления) до показа UI.
class _AppServices {
  final StorageService storage;
  final AdsService ads;
  _AppServices(this.storage, this.ads);

  static Future<_AppServices> load() async {
    final storage = await StorageService.create().timeout(const Duration(seconds: 15));
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

class TarotApp extends StatefulWidget {
  const TarotApp({super.key});

  @override
  State<TarotApp> createState() => _TarotAppState();
}

class _TarotAppState extends State<TarotApp> {
  // Задача загрузки создаётся ОДИН раз. Раньше она создавалась прямо в build
  // и могла стартовать заново при любой перерисовке.
  late Future<_AppServices> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _AppServices.load();
  }

  void _retry() {
    lastErrorNotifier.value = null;
    setState(() => _servicesFuture = _AppServices.load());
  }

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
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoadingScreen(
              message: 'Не удалось запустить приложение: ${snapshot.error}',
              onRetry: _retry,
            );
          }
          if (!snapshot.hasData) {
            return const LoadingScreen();
          }
          final services = snapshot.data!;
          return HomeScreen(storage: services.storage, ads: services.ads);
        },
      ),
    );
  }
}
