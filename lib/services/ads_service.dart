import 'dart:async';
import 'package:yandex_mobileads/mobile_ads.dart';

/// Обёртка над Yandex Mobile Ads SDK для показа rewarded-видео.
///
/// _adUnitId — реальный рекламный блок из кабинета Yandex Ads
/// (partner.yandex.ru). Если блок будет заархивирован или удалён там —
/// реклама в приложении перестанет загружаться без каких-либо ошибок
/// в этом коде (проверено на практике).
class AdsService {
  static const _adUnitId = 'R-M-19986688-1';

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;
  Timer? _watchdogTimer;

  /// Инициализация SDK — вызывается один раз при старте приложения.
  Future<void> initialize() async {
    await MobileAds.initialize();
    // Разрешаем показ рекламы с учётом согласия пользователя на обработку
    // данных — в реальном проекте здесь нужно подключить экран согласия
    // (GDPR/152-ФЗ) перед первым показом.
    await preload();

    // "Сторожевой" таймер — независимая подстраховка на случай, если
    // колбэки onAdLoaded/onAdFailedToLoad по какой-то причине вообще не
    // срабатывают после показа предыдущей рекламы (бывает с некоторыми
    // версиями рекламных SDK). Раз в 5 секунд просто проверяет, готова
    // ли реклама, и пробует загрузить заново, если нет — независимо от
    // того, сработал ли явный повтор через _scheduleRetry.
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!isReady && !_isLoading) {
        preload();
      }
    });
  }

  /// Заранее загружает объявление, чтобы показ был мгновенным.
  Future<void> preload() async {
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;

    // Колбэки onAdLoaded/onAdFailedToLoad могут в редких случаях вообще
    // не сработать (ни успех, ни ошибка) — тогда _isLoading застревает
    // в true навсегда, и больше никакие попытки загрузки не проходят.
    // Этот таймер — гарантия: если за 8 секунд ни один из колбэков не
    // вызвался, считаем попытку проваленной и пробуем снова.
    bool callbackFired = false;
    Timer(const Duration(seconds: 8), () {
      if (!callbackFired && _isLoading) {
        _isLoading = false;
        _scheduleRetry();
      }
    });

    try {
      final loader = await RewardedAdLoader.create(
        onAdLoaded: (ad) {
          callbackFired = true;
          _rewardedAd = ad;
          _isLoading = false;
          _retryAttempt = 0;
          _retryTimer?.cancel();
        },
        onAdFailedToLoad: (error) {
          callbackFired = true;
          _isLoading = false;
          _scheduleRetry();
        },
      );
      await loader.loadAd(adRequestConfiguration: AdRequestConfiguration(adUnitId: _adUnitId));
    } catch (_) {
      callbackFired = true;
      _isLoading = false;
      _scheduleRetry();
    }
  }

  /// Раньше при неудачной первой загрузке реклама навсегда оставалась
  /// в состоянии "не готова" — повторных попыток никто не запускал.
  /// Теперь при ошибке сам сервис пробует снова: первая повторная
  /// попытка — почти мгновенно, следующие — с интервалом 1-5 секунд.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryAttempt++;
    final delay = _retryAttempt == 1
        ? const Duration(milliseconds: 300)
        : Duration(seconds: _retryAttempt.clamp(1, 5));
    _retryTimer = Timer(delay, preload);
  }

  bool get isReady => _rewardedAd != null;

  /// Показывает rewarded-видео. Возвращает true, если пользователь
  /// досмотрел ролик и заслужил награду (дополнительный расклад).
  Future<bool> showRewardedAd() async {
    final ad = _rewardedAd;
    if (ad == null) return false;

    // Раньше функция возвращала результат сразу после вызова ad.show(),
    // не дожидаясь закрытия рекламы — награда приходила позже (в колбэке
    // onRewarded/onAdDismissed) и терялась. Completer решает эту проблему:
    // функция теперь ждёт, пока реклама реально не закроется.
    final completer = Completer<bool>();
    bool rewarded = false;

    ad.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown: () {},
        onAdFailedToShow: (error) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onAdClicked: () {},
        onAdDismissed: () {
          _rewardedAd = null;
          // Сразу подгружаем следующее объявление на будущее.
          preload();
          if (!completer.isCompleted) completer.complete(rewarded);
        },
        onAdImpression: (impressionData) {},
        onRewarded: (reward) {
          rewarded = true;
        },
      ),
    );

    await ad.show();
    return completer.future;
  }
}
