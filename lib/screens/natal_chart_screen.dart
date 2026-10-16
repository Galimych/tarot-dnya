import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  DateTime? _birthDate;
  TimeOfDay _birthTime = const TimeOfDay(hour: 12, minute: 0);
  int _utcOffset = DateTime.now().timeZoneOffset.inHours;

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
    if (dateStr == null) return;
    setState(() {
      _birthDate = DateTime.tryParse(dateStr);
      _birthTime = TimeOfDay(
        hour: prefs.getInt(_kHour) ?? 12,
        minute: prefs.getInt(_kMinute) ?? 0,
      );
      _utcOffset = prefs.getInt(_kOffset) ?? _utcOffset;
    });
    if (_birthDate != null) {
      _calculate();
    }
  }

  Future<void> _saveInput() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDate, _birthDate!.toIso8601String());
    await prefs.setInt(_kHour, _birthTime.hour);
    await prefs.setInt(_kMinute, _birthTime.minute);
    await prefs.setInt(_kOffset, _utcOffset);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1800, 1, 1),
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

  Future<void> _calculate() async {
    if (_birthDate == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Переводим введённое местное время в UTC, вычитая смещение
      // часового пояса (пользователь задаёт его вручную).
      final local = DateTime(
        _birthDate!.year,
        _birthDate!.month,
        _birthDate!.day,
        _birthTime.hour,
        _birthTime.minute,
      );
      final utc = local.subtract(Duration(hours: _utcOffset));

      final chart = await NatalChartService.calculate(utc);
      await _saveInput();
      setState(() {
        _chart = chart;
        _editing = false;
      });
    } catch (e) {
      setState(() => _error = 'Не удалось рассчитать карту. Попробуй ещё раз.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String get _birthSummary {
    final date = DateFormat('d MMMM y', 'ru').format(_birthDate!);
    final time =
        '${_birthTime.hour.toString().padLeft(2, '0')}:${_birthTime.minute.toString().padLeft(2, '0')}';
    final offset = _utcOffset >= 0 ? 'UTC+$_utcOffset' : 'UTC$_utcOffset';
    return '$date, $time ($offset)';
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
                Text(_birthSummary, style: const TextStyle(color: AppColors.textWarm, fontSize: 13)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Укажи дату, время и часовой пояс места рождения — чем точнее данные, тем точнее расчёт положения планет. Данные сохранятся на этом телефоне.',
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
          value:
              '${_birthTime.hour.toString().padLeft(2, '0')}:${_birthTime.minute.toString().padLeft(2, '0')}',
          onTap: _pickTime,
        ),
        const SizedBox(height: 10),
        _FieldTile(
          label: 'Часовой пояс (UTC)',
          value: _utcOffset >= 0 ? 'UTC+$_utcOffset' : 'UTC$_utcOffset',
          onTap: _showUtcOffsetPicker,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _birthDate == null || _isLoading ? null : _calculate,
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
    final dominant = chart.dominantElement;
    final maxCount = chart.elementCounts.reduce((a, b) => a > b ? a : b);

    return [
      const SizedBox(height: 20),
      NatalWheel(chart: chart),
      const SizedBox(height: 20),

      // Главное в двух строках.
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
            Text(
              'Солнце в знаке ${sun.zodiacSign}',
              style: const TextStyle(color: AppColors.goldBright, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Луна в знаке ${moon.zodiacSign}',
              style: const TextStyle(color: AppColors.goldBright, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Солнце показывает, кто ты по сути, а Луна — что ты чувствуешь и в чём находишь покой.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),

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
                child: Text(elementNames[i], style: const TextStyle(color: AppColors.textWarm, fontSize: 13)),
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
              Text('${chart.elementCounts[i]}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      const SizedBox(height: 4),
      Text(elementMeaning[dominant], style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),

      // Планеты с толкованиями.
      const SizedBox(height: 28),
      const Text('Планеты в знаках', style: TextStyle(color: AppColors.goldBright, fontSize: 16)),
      const SizedBox(height: 12),
      ...chart.planets.map(_buildPlanetCard),

      // Аспекты.
      const SizedBox(height: 20),
      const Text('Аспекты', style: TextStyle(color: AppColors.goldBright, fontSize: 16)),
      const SizedBox(height: 6),
      const Text(
        'Аспекты — это углы между планетами. Они показывают, как разные части твоей личности взаимодействуют друг с другом.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 12),
      if (chart.aspects.isEmpty)
        const Text('Заметных аспектов не найдено.', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
      else
        ...chart.aspects.take(10).map(_buildAspectTile),

      const SizedBox(height: 20),
      const Text(
        'Это упрощённая версия натальной карты: без домов и асцендента, которым нужны координаты места рождения. Толкования носят развлекательный характер.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
      ),
      const SizedBox(height: 10),
      const Text(
        'Положения планет рассчитаны с помощью Swiss Ephemeris (Astrodienst AG, лицензия AGPL). Исходный код приложения: github.com/galimych/tarot-dnya',
        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildPlanetCard(PlanetPosition p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: AppColors.gold.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(p.emoji, style: const TextStyle(fontSize: 20, color: AppColors.goldBright)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.planetName, style: const TextStyle(color: AppColors.textWarm, fontSize: 15)),
                ),
                Text(
                  '${p.zodiacSign} ${p.degreeInSign.toStringAsFixed(1)}°',
                  style: const TextStyle(color: AppColors.goldBright, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              planetMeaning[p.planetName] ?? '',
              style: const TextStyle(color: AppColors.textWarm, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 6),
            Text(
              signStyle[p.zodiacSign] ?? '',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.45),
            ),
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
            Text(
              aspect.type.meaning,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
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
}

class _FieldTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _FieldTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            Text(value, style: const TextStyle(color: AppColors.textWarm, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
