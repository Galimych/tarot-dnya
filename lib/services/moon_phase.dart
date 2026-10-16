/// Вычисляет текущую фазу луны по дате (без сторонних пакетов).
/// Основано на синодическом месяце ≈ 29.53059 дня от известного
/// новолуния (6 января 2000, 18:14 UTC).
class MoonPhase {
  final String name;
  final String emoji;

  const MoonPhase(this.name, this.emoji);

  static MoonPhase forDate(DateTime date) {
    const synodicMonth = 29.53058867;
    final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
    final daysSince = date.toUtc().difference(knownNewMoon).inHours / 24.0;
    final phase = (daysSince % synodicMonth) / synodicMonth; // 0..1

    if (phase < 0.03 || phase >= 0.97) return const MoonPhase('Новолуние', '🌑');
    if (phase < 0.22) return const MoonPhase('Растущий серп', '🌒');
    if (phase < 0.28) return const MoonPhase('Первая четверть', '🌓');
    if (phase < 0.47) return const MoonPhase('Растущая луна', '🌔');
    if (phase < 0.53) return const MoonPhase('Полнолуние', '🌕');
    if (phase < 0.72) return const MoonPhase('Убывающая луна', '🌖');
    if (phase < 0.78) return const MoonPhase('Последняя четверть', '🌗');
    return const MoonPhase('Убывающий серп', '🌘');
  }
}
