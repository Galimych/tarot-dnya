import 'dart:math';
import 'package:sweph/sweph.dart';
import '../data/natal_interpretations.dart';

/// Положение одной планеты в натальной карте.
class PlanetPosition {
  final String planetName;
  final String emoji;
  final double longitude; // 0..360, эклиптическая долгота
  final int signIndex; // 0..11
  final String zodiacSign;
  final double degreeInSign;

  const PlanetPosition({
    required this.planetName,
    required this.emoji,
    required this.longitude,
    required this.signIndex,
    required this.zodiacSign,
    required this.degreeInSign,
  });
}

/// Аспект — угловая связь между двумя планетами.
class ChartAspect {
  final PlanetPosition a;
  final PlanetPosition b;
  final AspectType type;
  final double deviation; // насколько точен аспект (в градусах)

  const ChartAspect(this.a, this.b, this.type, this.deviation);
}

/// Результат расчёта: планеты, баланс стихий и аспекты.
class NatalChart {
  final List<PlanetPosition> planets;
  final List<int> elementCounts; // Огонь, Земля, Воздух, Вода
  final List<ChartAspect> aspects;

  const NatalChart(this.planets, this.elementCounts, this.aspects);

  int get dominantElement {
    var best = 0;
    for (var i = 1; i < elementCounts.length; i++) {
      if (elementCounts[i] > elementCounts[best]) best = i;
    }
    return best;
  }
}

/// Расчёт положения планет на момент рождения через Swiss Ephemeris —
/// тот же стандарт точности, которым пользуются профессиональные
/// астрологические сервисы. Работает полностью офлайн.
///
/// Честное ограничение: дома и асцендент не рассчитываются — для них
/// нужны точное время и координаты места рождения.
class NatalChartService {
  static bool _initialized = false;

  static const zodiacSigns = [
    'Овен', 'Телец', 'Близнецы', 'Рак', 'Лев', 'Дева',
    'Весы', 'Скорпион', 'Стрелец', 'Козерог', 'Водолей', 'Рыбы',
  ];

  // \uFE0E принуждает показывать символ текстом, а не цветным эмодзи.
  static const zodiacGlyphs = [
    '♈\uFE0E', '♉\uFE0E', '♊\uFE0E', '♋\uFE0E', '♌\uFE0E', '♍\uFE0E',
    '♎\uFE0E', '♏\uFE0E', '♐\uFE0E', '♑\uFE0E', '♒\uFE0E', '♓\uFE0E',
  ];

  static final List<(HeavenlyBody, String, String)> _planets = [
    (HeavenlyBody.SE_SUN, 'Солнце', '☉\uFE0E'),
    (HeavenlyBody.SE_MOON, 'Луна', '☽\uFE0E'),
    (HeavenlyBody.SE_MERCURY, 'Меркурий', '☿\uFE0E'),
    (HeavenlyBody.SE_VENUS, 'Венера', '♀\uFE0E'),
    (HeavenlyBody.SE_MARS, 'Марс', '♂\uFE0E'),
    (HeavenlyBody.SE_JUPITER, 'Юпитер', '♃\uFE0E'),
    (HeavenlyBody.SE_SATURN, 'Сатурн', '♄\uFE0E'),
    (HeavenlyBody.SE_URANUS, 'Уран', '♅\uFE0E'),
    (HeavenlyBody.SE_NEPTUNE, 'Нептун', '♆\uFE0E'),
    (HeavenlyBody.SE_PLUTO, 'Плутон', '♇\uFE0E'),
  ];

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await Sweph.init(epheAssets: [
      "packages/sweph/assets/ephe/sepl_18.se1",
      "packages/sweph/assets/ephe/semo_18.se1",
    ]);
    _initialized = true;
  }

  /// [utcDateTime] — момент рождения, уже переведённый в UTC.
  static Future<NatalChart> calculate(DateTime utcDateTime) async {
    await _ensureInitialized();

    final hourDecimal = utcDateTime.hour +
        utcDateTime.minute / 60.0 +
        utcDateTime.second / 3600.0;

    final julianDay = Sweph.swe_julday(
      utcDateTime.year,
      utcDateTime.month,
      utcDateTime.day,
      hourDecimal,
      CalendarType.SE_GREG_CAL,
    );

    final planets = <PlanetPosition>[];
    for (final (body, name, emoji) in _planets) {
      final result = Sweph.swe_calc_ut(julianDay, body, SwephFlag.SEFLG_SWIEPH);
      final longitude = result.longitude % 360;
      final signIndex = (longitude / 30).floor() % 12;
      planets.add(PlanetPosition(
        planetName: name,
        emoji: emoji,
        longitude: longitude,
        signIndex: signIndex,
        zodiacSign: zodiacSigns[signIndex],
        degreeInSign: longitude % 30,
      ));
    }

    // Баланс стихий: знаки идут по кругу Огонь, Земля, Воздух, Вода.
    final elements = [0, 0, 0, 0];
    for (final p in planets) {
      elements[p.signIndex % 4]++;
    }

    return NatalChart(planets, elements, _findAspects(planets));
  }

  static List<ChartAspect> _findAspects(List<PlanetPosition> planets) {
    final found = <ChartAspect>[];
    for (var i = 0; i < planets.length; i++) {
      for (var j = i + 1; j < planets.length; j++) {
        var diff = (planets[i].longitude - planets[j].longitude).abs();
        if (diff > 180) diff = 360 - diff;
        for (final type in aspectTypes) {
          final deviation = (diff - type.angle).abs();
          if (deviation <= type.orb) {
            found.add(ChartAspect(planets[i], planets[j], type, deviation));
            break;
          }
        }
      }
    }
    // Самые точные аспекты — первыми.
    found.sort((x, y) => x.deviation.compareTo(y.deviation));
    return found;
  }

  /// Угол на круге для долготы: 0° Овна слева, дальше против часовой.
  static double angleFor(double longitude) => pi + longitude * pi / 180;
}
