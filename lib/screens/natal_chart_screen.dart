import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/cities_data.dart';
import '../data/natal_interpretations.dart';
import '../services/natal_chart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/natal_wheel.dart';

class NatalChartScreen extends StatefulWidget {
  const NatalChartScreen({super.key});

  @override
  State<NatalChartScreen> createState() => _NatalChartScreenState();
}

class _NatalChartScreenState extends State<NatalChartScreen> {
  static const _kDate = 'natal_birth_date';
  static const _kHour = 'natal_birth_hour';
  static const _kMinute = 'natal_birth_minute';
  static const _kOffset = 'natal_utc_offset';
  static const _kTimeKnown = 'natal_time_known';
  static const _kPlaceName = 'natal_place_name';
  static const _kPlaceLat = 'natal_place_lat';
  static const _kPlaceLon = 'natal_place_lon';
  static const _kPlaceTz = 'natal_place_tz';
  static const _kPlaceOffset = 'natal_place_offset';
  static const _kSystem = 'natal_house_system';

  DateTime? _birthDate;
  TimeOfDay _birthTime = const TimeOfDay(hour: 12, minute: 0);
  bool _timeKnown = true;
  BirthPlace? _place;
  int _utcOffset = DateTime.now().timeZoneOffset.inHours;
  HouseSystemOption _system = HouseSystemOption.placidus;

  bool _isLoading = false;
  bool _editing = true;
  NatalChart? _chart;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSaved();
  }

  /// Если данные рождения уже вводились — подставляем их и сразу считаем карту.
  Future<void> _restoreSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_kDate);
    final placeName = prefs.getString(_kPlaceName);
    final lat = prefs.getDouble(_kPlaceLat);
    final lon = prefs.getDouble(_kPlaceLon);

    setState(() {
      _birthTime = TimeOfDay(
        hour: prefs.getInt(_kHour) ?? 12,
        minute: prefs.getInt(_kMinute) ?? 0,
      );
      _timeKnown = prefs.getBool(_kTimeKnown) ?? true;
      _utcOffset = prefs.getInt(_kOffset) ?? _utcOffset;
      final systemIndex = prefs.getInt(_kSystem) ?? 0;
      if (systemIndex >= 0 && systemIndex < HouseSystemOption.values.length) {
        _system = HouseSystemOption.values[systemIndex];
      }
      if (dateStr != null) _birthDate = DateTime.tryParse(dateStr);
      if (placeName != null && lat != null && lon != null) {
        _place = BirthPlace(
          name: placeName,
          latitude: lat,
          longitude: lon,
          timeZoneId: prefs.getString(_kPlaceTz),
          fallbackOffset: prefs.getDouble(_kPlaceOffset) ?? 0,
        );
      }
    });

    if (_birthDate != null && _place != null) {
      _calculate();
    }
  }

  Future<void> _saveInput() async {
    final prefs = await SharedPreferences.getInstance();
    final place = _place!;
    await prefs.setString(_kDate, _birthDate!.toIso8601String());
    await prefs.setInt(_kHour, _birthTime.hour);
    await prefs.setInt(_kMinute, _birthTime.minute);
    await prefs.setBool(_kTimeKnown, _timeKnown);
    await prefs.setInt(_kOffset, _utcOffset);
    await prefs.setInt(_kSystem, _system.index);
    await prefs.setString(_kPlaceName, place.name);
    await prefs.setDouble(_kPlaceLat, place.latitude);
    await prefs.setDouble(_kPlaceLon, place.longitude);
    await prefs.setDouble(_kPlaceOffset, place.fallbackOffset);
    if (place.timeZoneId != null) {
      await prefs.setString(_kPlaceTz, place.timeZoneId!);
    } else {
      await prefs.remove(_kPlaceTz);
    }
  }

  /// Для ручных координат смещение берём из выбранного пояса.
  BirthPlace? get _effectivePlace {
    final place = _place;
    if (place == null) return null;
    return place.timeZoneId == null ? place.withOffset(_utcOffset.toDouble()) : place;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1801, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Дата рождения',
      locale: const Locale('ru'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _birthTime,
      helpText: 'Время рождения',
    );
    if (picked != null) setState(() => _birthTime = picked);
  }

  Future<void> _pickPlace() async {
    final result = await showModalBottomSheet<BirthPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgMid,
      builder: (_) => const _CityPickerSheet(),
    );
    if (result != null) setState(() => _place = result);
  }

  Future<void> _calculate() async {
    final place = _effectivePlace;
    if (_birthDate == null || place == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Если время неизвестно, берём полдень: планеты считаются с точностью
      // до градуса, а Луна — с погрешностью, дома и асцендент не строятся.
      final local = DateTime(
        _birthDate!.year,
        _birthDate!.month,
        _birthDate!.day,
        _timeKnown ? _birthTime.hour : 12,
        _timeKnown ? _birthTime.minute : 0,
      );
      final chart = await NatalChartService.calculate(
        localBirth: local,
        place: place,
        system: _system,
        timeKnown: _timeKnown,
      );
      await _saveInput();
      setState(() {
        _chart = chart;
        _editing = false;
      });
    } catch (e) {
      setState(() => _error = 'Не удалось рассчитать карту: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String get _birthSummary {
    final date = DateFormat('d MMMM y', 'ru').format(_birthDate!);
    final time = _timeKnown
        ? '${_birthTime.hour.toString().padLeft(2, '0')}:${_birthTime.minute.toString().padLeft(2, '0')}'
        : 'время неизвестно';
    return '$date, $time\n${_place?.name ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final showForm = _editing || _chart == null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: Text('Натальная карта', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showForm) _buildForm() else _buildSavedHeader(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            if (_chart != null && !showForm) ..._buildChart(_chart!),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Данные рождения', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 3),
                Text(_birthSummary, style: const TextStyle(color: AppColors.textWarm, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _editing = true),
            child: const Text('Изменить'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final isManual = _place != null && _place!.timeZoneId == null;
    final canCalculate = _birthDate != null && _place != null && !_isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Для полной карты с домами и асцендентом нужны дата, точное время и место рождения. Данные сохранятся только на этом телефоне.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _FieldTile(
          label: 'Дата рождения',
          value: _birthDate == null ? 'Не выбрана' : DateFormat('d MMMM y', 'ru').format(_birthDate!),
          onTap: _pickDate,
        ),
        const SizedBox(height: 10),
        _FieldTile(
          label: 'Время рождения',
          value: _timeKnown
              ? '${_birthTime.hour.toString().padLeft(2, '0')}:${_birthTime.minute.toString().padLeft(2, '0')}'
              : 'Неизвестно',
          onTap: _timeKnown ? _pickTime : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppColors.gold,
          title: const Text(
            'Время рождения неизвестно',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          subtitle: const Text(
            'Тогда дома и асцендент не рассчитываются: без точного времени они были бы неверными.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          value: !_timeKnown,
          onChanged: (value) => setState(() => _timeKnown = !value),
        ),
        const SizedBox(height: 6),
        _FieldTile(
          label: 'Место рождения',
          value: _place?.name ?? 'Не выбрано',
          onTap: _pickPlace,
        ),
        if (isManual) ...[
          const SizedBox(height: 10),
          _FieldTile(
            label: 'Часовой пояс (UTC)',
            value: _utcOffset >= 0 ? 'UTC+$_utcOffset' : 'UTC$_utcOffset',
            onTap: _showUtcOffsetPicker,
          ),
        ] else if (_place != null) ...[
          const SizedBox(height: 6),
          Text(
            'Часовой пояс определяется автоматически: ${_place!.timeZoneId} (с учётом летнего времени и исторических изменений).',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
        if (_timeKnown) ...[
          const SizedBox(height: 10),
          _FieldTile(
            label: 'Система домов',
            value: _system.label,
            onTap: _showSystemPicker,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canCalculate ? _calculate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bgDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDark),
                  )
                : const Text('Рассчитать'),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChart(NatalChart chart) {
    final sun = chart.planets[0];
    final moon = chart.planets[1];
    final asc = chart.ascendant;
    final mc = chart.midheaven;
    final dominant = chart.dominantElement;
    final maxCount = chart.elementCounts.reduce((a, b) => a > b ? a : b);
    final hasRetro = chart.planets.any((p) => p.retrograde) ||
        chart.extras.any((p) => p.retrograde);

    return [
      const SizedBox(height: 20),
      NatalWheel(chart: chart),
      const SizedBox(height: 20),

      // Главное в нескольких строках.
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.gold.withOpacity(0.08),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Солнце в знаке ${sun.zodiacSign}',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Луна в знаке ${moon.zodiacSign}',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 15)),
            if (asc != null) ...[
              const SizedBox(height: 4),
              Text('Асцендент в знаке ${asc.zodiacSign}',
                  style: const TextStyle(color: AppColors.goldBright, fontSize: 15)),
            ],
            const SizedBox(height: 8),
            Text(
              asc != null
                  ? 'Солнце — твоя суть, Луна — твои чувства, Асцендент — то, как тебя видят другие.'
                  : 'Солнце показывает, кто ты по сути, а Луна — что ты чувствуешь и в чём находишь покой.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),

      // Оси карты.
      if (asc != null && mc != null) ...[
        const SizedBox(height: 24),
        const Text('Оси карты', style: TextStyle(color: AppColors.goldBright, fontSize: 16)),
        const SizedBox(height: 12),
        _buildAngleCard(
          title: 'Асцендент (ASC)',
          point: asc,
          general: ascendantGeneral,
          specific: ascendantMeaning[asc.zodiacSign] ?? '',
        ),
        _buildAngleCard(
          title: 'Середина неба (MC)',
          point: mc,
          general: midheavenGeneral,
          specific: signStyle[mc.zodiacSign] ?? '',
        ),
        Text(
          'Десцендент (DSC) — ${NatalChartService.zodiacSigns[(asc.signIndex + 6) % 12]}, '
          'Imum Coeli (IC) — ${NatalChartService.zodiacSigns[(mc.signIndex + 6) % 12]}.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],

      // Баланс стихий.
      const SizedBox(height: 24),
      const Text('Баланс стихий', style: TextStyle(color: AppColors.goldBright, fontSize: 16)),
      const SizedBox(height: 12),
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(width: 26, child: Text(elementEmoji[i])),
              SizedBox(
                width: 64,
                child: Text(elementNames[i],
                    style: const TextStyle(color: AppColors.textWarm, fontSize: 13)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxCount == 0 ? 0 : chart.elementCounts[i] / maxCount,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.07),
                    valueColor: AlwaysStoppedAnimation(
                      i == dominant ? AppColors.gold : AppColors.indigo,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${chart.elementCounts[i]}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      const SizedBox(height: 4),
      Text(elementMeaning[dominant],
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),

      // Планеты.
      const SizedBox(height: 28),
      const Text('Планеты в знаках и домах',
          style: TextStyle(color: AppColors.goldBright, fontSize: 16)),
      const SizedBox(height: 12),
      ...chart.planets.map(_buildPlanetCard),
      if (hasRetro) ...[
        const SizedBox(height: 4),
        const Text(retrogradeNote,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
      ],

      // Дополнительные точки.
      if (chart.extras.isNotEmpty || chart.warnings.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text('Дополнительные точки',
            style: TextStyle(color: AppColors.goldBright, fontSize: 16)),
        const SizedBox(height: 12),
        ...chart.extras.map(_buildExtraCard),
        for (final warning in chart.warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Не удалось рассчитать — $warning',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
      ],

      // Дома.
      if (chart.hasHouses) ...[
        const SizedBox(height: 24),
        Text('Дома (система: ${chart.houseSystemLabel})',
            style: const TextStyle(color: AppColors.goldBright, fontSize: 16)),
        if (chart.houseNote != null) ...[
          const SizedBox(height: 6),
          Text(chart.houseNote!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < 12; i++) _buildHouseRow(i, chart),
      ],

      // Аспекты.
      const SizedBox(height: 24),
      const Text('Аспекты', style: TextStyle(color: AppColors.goldBright, fontSize: 16)),
      const SizedBox(height: 6),
      const Text(
        'Аспекты — это углы между планетами и осями карты. Они показывают, как разные части твоей личности взаимодействуют друг с другом.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 12),
      if (chart.aspects.isEmpty)
        const Text('Заметных аспектов не найдено.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13))
      else
        ...chart.aspects.take(14).map(_buildAspectTile),

      const SizedBox(height: 20),
      Text(
        chart.hasHouses
            ? 'Положения рассчитаны по времени и месту рождения; точность асцендента и домов целиком зависит от точности введённого времени. Толкования носят развлекательный характер.'
            : 'Время рождения не указано, поэтому дома и асцендент не рассчитаны. Положение Луны приблизительное. Толкования носят развлекательный характер.',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
      ),
      const SizedBox(height: 10),
      const Text(
        'Положения планет рассчитаны с помощью Swiss Ephemeris (Astrodienst AG, лицензия AGPL). Исходный код приложения: github.com/galimych/tarot-dnya',
        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _card({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: AppColors.gold.withOpacity(0.2)),
        ),
        child: child,
      ),
    );
  }

  Widget _buildAngleCard({
    required String title,
    required PlanetPosition point,
    required String general,
    required String specific,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(color: AppColors.textWarm, fontSize: 15)),
              ),
              Text(
                '${point.zodiacSign} ${NatalChartService.formatDegrees(point.degreeInSign)}',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(general, style: const TextStyle(color: AppColors.textWarm, fontSize: 12, height: 1.45)),
          const SizedBox(height: 6),
          Text(specific, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }

  Widget _buildPlanetCard(PlanetPosition p) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(p.emoji, style: const TextStyle(fontSize: 20, color: AppColors.goldBright)),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text(p.planetName, style: const TextStyle(color: AppColors.textWarm, fontSize: 15)),
                    if (p.retrograde) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.indigo.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('ретроградна',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${p.zodiacSign} ${NatalChartService.formatDegrees(p.degreeInSign)}',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 13),
              ),
            ],
          ),
          if (p.house > 0) ...[
            const SizedBox(height: 6),
            Text(
              'В ${p.house} доме: ${houseThemes[p.house - 1]}.',
              style: const TextStyle(color: AppColors.goldBright, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          Text(planetMeaning[p.planetName] ?? '',
              style: const TextStyle(color: AppColors.textWarm, fontSize: 12, height: 1.45)),
          const SizedBox(height: 6),
          Text(signStyle[p.zodiacSign] ?? '',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }

  Widget _buildExtraCard(PlanetPosition p) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(p.planetName, style: const TextStyle(color: AppColors.textWarm, fontSize: 15)),
                    if (p.retrograde) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.indigo.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('ретроградна',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${p.zodiacSign} ${NatalChartService.formatDegrees(p.degreeInSign)}',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 13),
              ),
            ],
          ),
          if (p.house > 0) ...[
            const SizedBox(height: 6),
            Text('В ${p.house} доме: ${houseThemes[p.house - 1]}.',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 8),
          Text(extraMeaning[p.planetName] ?? '',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }

  Widget _buildHouseRow(int index, NatalChart chart) {
    final cusp = chart.houseCusps![index];
    final signIndex = (cusp / 30).floor() % 12;
    final inHouse = chart.planets.where((p) => p.house == index + 1).map((p) => p.planetName).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${index + 1} дом',
                      style: const TextStyle(color: AppColors.textWarm, fontSize: 13)),
                ),
                Text(
                  '${NatalChartService.zodiacSigns[signIndex]} ${NatalChartService.formatDegrees(cusp % 30)}',
                  style: const TextStyle(color: AppColors.goldBright, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(houseThemes[index],
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
            if (inHouse.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('Здесь: ${inHouse.join(', ')}',
                  style: const TextStyle(color: AppColors.textWarm, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAspectTile(ChartAspect aspect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${aspect.a.planetName} — ${aspect.type.name} — ${aspect.b.planetName}',
              style: const TextStyle(color: AppColors.textWarm, fontSize: 13),
            ),
            const SizedBox(height: 3),
            Text(aspect.type.meaning,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showUtcOffsetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgMid,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: 27,
            itemBuilder: (context, index) {
              final offset = index - 12;
              return ListTile(
                title: Text(
                  offset >= 0 ? 'UTC+$offset' : 'UTC$offset',
                  style: const TextStyle(color: AppColors.textWarm),
                ),
                onTap: () {
                  setState(() => _utcOffset = offset);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showSystemPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgMid,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in HouseSystemOption.values)
                ListTile(
                  title: Text(option.label, style: const TextStyle(color: AppColors.textWarm)),
                  subtitle: Text(option.description,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: option == _system
                      ? const Icon(Icons.check, color: AppColors.goldBright)
                      : null,
                  onTap: () {
                    setState(() => _system = option);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FieldTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _FieldTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withOpacity(enabled ? 0.3 : 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: enabled ? AppColors.textWarm : AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Окно выбора места рождения: поиск по встроенному списку городов
/// или ввод собственных координат.
class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

  Future<void> _enterManually() async {
    final latController = TextEditingController();
    final lonController = TextEditingController();

    final result = await showDialog<BirthPlace>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppColors.bgMid,
            title: const Text('Свои координаты',
                style: TextStyle(color: AppColors.textWarm, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Координаты можно узнать на карте: зажми точку и скопируй числа. Север и восток — плюс, юг и запад — минус.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: const TextStyle(color: AppColors.textWarm),
                  decoration: const InputDecoration(labelText: 'Широта (например, 55.75)'),
                ),
                TextField(
                  controller: lonController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: const TextStyle(color: AppColors.textWarm),
                  decoration: const InputDecoration(labelText: 'Долгота (например, 37.62)'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  final lat = double.tryParse(latController.text.trim().replaceAll(',', '.'));
                  final lon = double.tryParse(lonController.text.trim().replaceAll(',', '.'));
                  if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
                    setDialogState(() => error =
                        'Проверь числа: широта от -90 до 90, долгота от -180 до 180.');
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    BirthPlace(
                      name: 'Координаты ${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}',
                      latitude: lat,
                      longitude: lon,
                      timeZoneId: null,
                      fallbackOffset: 0,
                    ),
                  );
                },
                child: const Text('Готово'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final q = _norm(_query.trim());
    final filtered = q.isEmpty
        ? cities
        : cities.where((c) => _norm(c.name).contains(q) || _norm(c.country).contains(q)).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: false,
                style: const TextStyle(color: AppColors.textWarm),
                decoration: const InputDecoration(
                  hintText: 'Найти город',
                  prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined, color: AppColors.goldBright),
              title: const Text('Моего города нет — ввести координаты',
                  style: TextStyle(color: AppColors.goldBright, fontSize: 14)),
              onTap: _enterManually,
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Такого города нет в списке. Нажми «Моего города нет» и введи координаты.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final city = filtered[index];
                        return ListTile(
                          title: Text(city.name, style: const TextStyle(color: AppColors.textWarm)),
                          subtitle: Text(city.country,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          onTap: () => Navigator.pop(
                            context,
                            BirthPlace(
                              name: '${city.name}, ${city.country}',
                              latitude: city.lat,
                              longitude: city.lon,
                              timeZoneId: city.tz,
                              fallbackOffset: city.offset,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
