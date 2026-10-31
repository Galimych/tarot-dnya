import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:sweph/sweph.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../data/natal_interpretations.dart';

/// Место рождения: координаты и часовой пояс.
class BirthPlace {
  final String name;
  final double latitude;
  final double longitude;

  /// Идентификатор зоны из базы IANA (например, Europe/Moscow). Если он
  /// задан, смещение от UTC на дату рождения берётся из базы с историей.
  final String? timeZoneId;

  /// Смещение от UTC в часах — используется, если зона не задана
  /// (ручной ввод координат) или не найдена в базе.
  final double fallbackOffset;

  const BirthPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.timeZoneId,
    required this.fallbackOffset,
  });

  BirthPlace withOffset(double offset) => BirthPlace(
        name: name,
        latitude: latitude,
        longitude: longitude,
        timeZoneId: timeZoneId,
        fallbackOffset: offset,
      );
}

/// Системы домов. Для полярных широт Плацидус и Кох не определены —
/// тогда автоматически берётся система Порфирия.
enum HouseSystemOption {
  placidus('Плацидус', 'Самая распространённая система'),
  koch('Кох', 'Популярна в Европе'),
  porphyry('Порфирий', 'Простое деление четвертей на три части'),
  equal('Равнодомная', 'Дома по 30° от асцендента'),
  wholeSign('По знакам', 'Каждый дом — целый знак зодиака');

  final String label;
  final String description;
  const HouseSystemOption(this.label, this.description);
}

/// Положение небесного тела или точки в натальной карте.
class PlanetPosition {
  final String planetName;
  final String emoji;
  final double longitude; // 0..360
  final int signIndex; // 0..11
  final String zodiacSign;
  final double degreeInSign;
  final int house; // 1..12, 0 — если дома не рассчитаны
  final bool retrograde;

  const PlanetPosition({
    required this.planetName,
    required this.emoji,
    required this.longitude,
    required this.signIndex,
    required this.zodiacSign,
    required this.degreeInSign,
    this.house = 0,
    this.retrograde = false,
  });
}

/// Аспект — угловая связь между двумя точками карты.
class ChartAspect {
  final PlanetPosition a;
  final PlanetPosition b;
  final AspectType type;
  final double deviation;

  const ChartAspect(this.a, this.b, this.type, this.deviation);
}

class NatalChart {
  final List<PlanetPosition> planets;
  final List<PlanetPosition> extras; // узел, Лилит, Хирон
  final PlanetPosition? ascendant;
  final PlanetPosition? midheaven;
  final List<double>? houseCusps; // 12 значений, начало каждого дома
  final String houseSystemLabel;
  final String? houseNote;
  final List<int> elementCounts;
  final List<ChartAspect> aspects;
  final List<String> warnings; // что не удалось рассчитать и почему

  const NatalChart({
    required this.planets,
    required this.extras,
    required this.ascendant,
    required this.midheaven,
    required this.houseCusps,
    required this.houseSystemLabel,
    required this.houseNote,
    required this.elementCounts,
    required this.aspects,
    this.warnings = const [],
  });

  bool get hasHouses => houseCusps != null && ascendant != null;

  int get dominantElement {
    var best = 0;
    for (var i = 1; i < elementCounts.length; i++) {
      if (elementCounts[i] > elementCounts[best]) best = i;
    }
    return best;
  }
}

/// Расчёт натальной карты через Swiss Ephemeris — тот же стандарт точности,
/// что у профессиональных астрологических программ. Работает офлайн.
class NatalChartService {
  static bool _initialized = false;

  /// Где лежат файлы эфемерид и сколько их — показывается в сообщении об
  /// ошибке, если какая-то точка не рассчиталась (для диагностики).
  static String? _epheDebug;

  static const zodiacSigns = [
    'Овен', 'Телец', 'Близнецы', 'Рак', 'Лев', 'Дева',
    'Весы', 'Скорпион', 'Стрелец', 'Козерог', 'Водолей', 'Рыбы',
  ];

  // \uFE0E принуждает показывать символ текстом, а не цветным эмодзи.
  static const zodiacGlyphs = [
    '♈\uFE0E', '♉\uFE0E', '♊\uFE0E', '♋\uFE0E', '♌\uFE0E', '♍\uFE0E',
    '♎\uFE0E', '♏\uFE0E', '♐\uFE0E', '♑\uFE0E', '♒\uFE0E', '♓\uFE0E',
  ];

  static final List<(HeavenlyBody, String, String, bool)> _planets = [
    (HeavenlyBody.SE_SUN, 'Солнце', '☉\uFE0E', false),
    (HeavenlyBody.SE_MOON, 'Луна', '☽\uFE0E', false),
    (HeavenlyBody.SE_MERCURY, 'Меркурий', '☿\uFE0E', true),
    (HeavenlyBody.SE_VENUS, 'Венера', '♀\uFE0E', true),
    (HeavenlyBody.SE_MARS, 'Марс', '♂\uFE0E', true),
    (HeavenlyBody.SE_JUPITER, 'Юпитер', '♃\uFE0E', true),
    (HeavenlyBody.SE_SATURN, 'Сатурн', '♄\uFE0E', true),
    (HeavenlyBody.SE_URANUS, 'Уран', '♅\uFE0E', true),
    (HeavenlyBody.SE_NEPTUNE, 'Нептун', '♆\uFE0E', true),
    (HeavenlyBody.SE_PLUTO, 'Плутон', '♇\uFE0E', true),
  ];

  static final List<(HeavenlyBody, String, bool)> _extras = [
    (HeavenlyBody.SE_MEAN_NODE, 'Северный узел', false),
    (HeavenlyBody.SE_MEAN_APOG, 'Лилит', false),
    (HeavenlyBody.SE_CHIRON, 'Хирон', true),
  ];

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await Sweph.init(
      epheAssets: [
        "packages/sweph/assets/ephe/sepl_18.se1",
        "packages/sweph/assets/ephe/semo_18.se1",
        "packages/sweph/assets/ephe/seas_18.se1",
      ],
      // Папка, куда копируются файлы эфемерид и откуда библиотека их читает.
      // Без этого параметра она искала файлы по пути по умолчанию
      // (/users/ephe/) и не находила — из-за этого не считался Хирон.
      epheFilesPath: 'ephe_files',
    );

    // Подстраховка: явно указываем библиотеке папку с файлами эфемерид и
    // записываем, что в ней лежит. Без этого Хирон (ему нужен файл
    // seas_18.se1, запасного расчёта нет) не считается.
    try {
      final support = await getApplicationSupportDirectory();
      final dir = '${support.path}/ephe_files';
      final folder = Directory(dir);
      final names = folder.existsSync()
          ? folder.listSync().map((e) => e.path.split('/').last).toList()
          : <String>[];
      _epheDebug = 'папка $dir, файлов: ${names.length} (${names.join(', ')})';
      if (names.isNotEmpty) {
        Sweph.swe_set_ephe_path(dir);
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      _epheDebug = 'не удалось проверить папку эфемерид: $e';
    }
    _initialized = true;
  }

  static Hsys _hsys(HouseSystemOption option) {
    switch (option) {
      case HouseSystemOption.placidus:
        return Hsys.P;
      case HouseSystemOption.koch:
        return Hsys.K;
      case HouseSystemOption.porphyry:
        return Hsys.O;
      case HouseSystemOption.equal:
        return Hsys.E;
      case HouseSystemOption.wholeSign:
        return Hsys.W;
    }
  }

  /// Переводит местное время рождения в UTC. Если известна зона из базы
  /// IANA, учитывается реальное смещение на ту дату (летнее время,
  /// исторические изменения поясов); иначе — введённое вручную смещение.
  static DateTime _toUtc(DateTime local, BirthPlace place) {
    final id = place.timeZoneId;
    if (id != null) {
      final names = [id, if (id == 'Europe/Kyiv') 'Europe/Kiev'];
      for (final name in names) {
        try {
          final location = tz.getLocation(name);
          final t = tz.TZDateTime(
            location, local.year, local.month, local.day, local.hour, local.minute,
          );
          return t.toUtc();
        } catch (_) {
          // пробуем следующее имя или запасное смещение
        }
      }
    }
    final minutes = (place.fallbackOffset * 60).round();
    return DateTime.utc(local.year, local.month, local.day, local.hour, local.minute)
        .subtract(Duration(minutes: minutes));
  }

  static double _julianDay(DateTime utc) {
    final hour = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;
    return Sweph.swe_julday(utc.year, utc.month, utc.day, hour, CalendarType.SE_GREG_CAL);
  }

  static double _longitude(double jd, HeavenlyBody body) =>
      Sweph.swe_calc_ut(jd, body, SwephFlag.SEFLG_SWIEPH).longitude % 360;

  /// Ретроградность определяем сравнением положения чуть до и чуть после
  /// момента рождения — так не нужны дополнительные флаги расчёта скорости.
  static bool _isRetrograde(double jd, HeavenlyBody body) {
    final before = _longitude(jd - 0.05, body);
    final after = _longitude(jd + 0.05, body);
    final delta = ((after - before + 540) % 360) - 180;
    return delta < 0;
  }

  static int _houseOf(double lon, List<double> cusps) {
    for (var i = 0; i < 12; i++) {
      final start = cusps[i];
      final end = cusps[(i + 1) % 12];
      final span = (end - start + 360) % 360;
      final pos = (lon - start + 360) % 360;
      if (pos < span) return i + 1;
    }
    return 1;
  }

  static PlanetPosition _position(
    String name,
    String glyph,
    double longitude, {
    List<double>? cusps,
    bool retrograde = false,
    int? forcedHouse,
  }) {
    final signIndex = (longitude / 30).floor() % 12;
    return PlanetPosition(
      planetName: name,
      emoji: glyph,
      longitude: longitude,
      signIndex: signIndex,
      zodiacSign: zodiacSigns[signIndex],
      degreeInSign: longitude % 30,
      house: forcedHouse ?? (cusps == null ? 0 : _houseOf(longitude, cusps)),
      retrograde: retrograde,
    );
  }

  static Future<NatalChart> calculate({
    required DateTime localBirth,
    required BirthPlace place,
    required HouseSystemOption system,
    required bool timeKnown,
  }) async {
    await _ensureInitialized();

    final utc = _toUtc(localBirth, place);
    final jd = _julianDay(utc);

    // Дома и оси карты — только если время рождения известно.
    List<double>? cusps;
    double? ascLon;
    double? mcLon;
    String systemLabel = system.label;
    String? note;

    if (timeKnown) {
      dynamic data;
      try {
        data = Sweph.swe_houses(jd, place.latitude, place.longitude, _hsys(system));
      } catch (_) {
        // За полярным кругом Плацидус и Кох не определены.
        data = Sweph.swe_houses(jd, place.latitude, place.longitude, Hsys.O);
        systemLabel = HouseSystemOption.porphyry.label;
        note = 'На этой широте выбранная система домов не определена, '
            'поэтому использована система Порфирия.';
      }
      final List<double> raw = List<double>.from(data.cusps);
      final offset = raw.length > 12 ? 1 : 0;
      cusps = List.generate(12, (i) => raw[i + offset] % 360);
      ascLon = (data.ascmc[0] as double) % 360;
      mcLon = (data.ascmc[1] as double) % 360;
    }

    final planets = <PlanetPosition>[];
    for (final (body, name, glyph, canRetro) in _planets) {
      final lon = _longitude(jd, body);
      planets.add(_position(
        name,
        glyph,
        lon,
        cusps: cusps,
        retrograde: canRetro && _isRetrograde(jd, body),
      ));
    }

    // Узел, Лилит и Хирон — каждый в отдельной защите: если для какой-то
    // точки не хватит данных, основная карта всё равно построится, а причина
    // будет показана на экране.
    final extras = <PlanetPosition>[];
    final warnings = <String>[];
    for (final (body, name, canRetro) in _extras) {
      try {
        final lon = _longitude(jd, body);
        final isNode = name == 'Северный узел';
        extras.add(_position(
          name,
          '',
          lon,
          cusps: cusps,
          // Средний лунный узел всегда движется «назад» по зодиаку.
          retrograde: isNode || (canRetro && _isRetrograde(jd, body)),
        ));
        if (isNode) {
          extras.add(_position(
            'Южный узел',
            '',
            (lon + 180) % 360,
            cusps: cusps,
            retrograde: true,
          ));
        }
      } catch (e) {
        warnings.add('$name: $e${_epheDebug == null ? '' : ' [$_epheDebug]'}');
      }
    }

    PlanetPosition? asc;
    PlanetPosition? mc;
    if (ascLon != null && mcLon != null) {
      asc = _position('Асцендент', 'ASC', ascLon, forcedHouse: 1);
      mc = _position('Середина неба (MC)', 'MC', mcLon, cusps: cusps);
    }

    // Баланс стихий считаем по десяти основным планетам.
    final elements = [0, 0, 0, 0];
    for (final p in planets) {
      elements[p.signIndex % 4]++;
    }

    return NatalChart(
      planets: planets,
      extras: extras,
      ascendant: asc,
      midheaven: mc,
      houseCusps: cusps,
      houseSystemLabel: systemLabel,
      houseNote: note,
      elementCounts: elements,
      aspects: _findAspects([...planets, if (asc != null) asc, if (mc != null) mc]),
      warnings: warnings,
    );
  }

  static List<ChartAspect> _findAspects(List<PlanetPosition> points) {
    final found = <ChartAspect>[];
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        // Асцендент и MC — оси карты, их аспект друг с другом не показываем.
        final bothAngles = points[i].emoji == 'ASC' && points[j].emoji == 'MC';
        if (bothAngles) continue;
        var diff = (points[i].longitude - points[j].longitude).abs();
        if (diff > 180) diff = 360 - diff;
        for (final type in aspectTypes) {
          final deviation = (diff - type.angle).abs();
          if (deviation <= type.orb) {
            found.add(ChartAspect(points[i], points[j], type, deviation));
            break;
          }
        }
      }
    }
    found.sort((x, y) => x.deviation.compareTo(y.deviation));
    return found;
  }

  /// Градусы и минуты: 12°34′
  static String formatDegrees(double value) {
    final deg = value.floor();
    final min = ((value - deg) * 60).floor();
    return '$deg°${min.toString().padLeft(2, '0')}′';
  }

  /// Угол на круге для долготы. Асцендент всегда слева, дальше против часовой.
  static double angleFor(double longitude, double ascendant) =>
      pi + (longitude - ascendant) * pi / 180;
}
