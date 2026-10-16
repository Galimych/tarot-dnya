import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../data/cards_data.dart';
import '../models/tarot_card.dart';
import '../services/ads_service.dart';
import '../services/moon_phase.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flip_card.dart';
import 'history_screen.dart';
import 'spreads_screen.dart';
import 'collection_screen.dart';
import 'monthly_card_screen.dart';
import 'natal_chart_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final AdsService ads;
  const HomeScreen({super.key, required this.storage, required this.ads});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TarotCard? _card;
  bool _isRevealed = false;
  int _streak = 0;

  // Игра "Угадай карту" — предлагается один раз в день, перед самым
  // первым открытием карты дня (повторные заходы в тот же день её
  // не показывают снова).
  bool _showGuessPrompt = false;
  List<TarotCard>? _guessOptions;
  bool? _lastGuessCorrect;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Важно проверить ДО создания карты — иначе всегда будет "уже показана".
    final alreadyShownToday = widget.storage.isTodayCardAlreadyRevealed();
    final card = await widget.storage.getOrCreateTodayCard();

    setState(() {
      _card = card;
      _streak = widget.storage.getStreak();
      _isRevealed = alreadyShownToday;
      _showGuessPrompt = !alreadyShownToday;
      if (_showGuessPrompt) {
        _guessOptions = _buildGuessOptions(card);
      }
    });

    final milestone = widget.storage.justReachedMilestone;
    if (milestone != null && mounted) {
      _showMilestoneCelebration(milestone);
    }
  }

  /// Четыре варианта на выбор: правильная карта + три случайные "обманки".
  List<TarotCard> _buildGuessOptions(TarotCard correct) {
    final decoys = List.of(allCards)..removeWhere((c) => c.number == correct.number);
    decoys.shuffle();
    final options = [correct, ...decoys.take(3)];
    options.shuffle();
    return options;
  }

  Future<void> _submitGuess(TarotCard guessed) async {
    final correct = guessed.number == _card!.number;
    await widget.storage.recordGuess(correct);
    setState(() {
      _lastGuessCorrect = correct;
      _showGuessPrompt = false;
      _isRevealed = true;
    });
  }

  void _showMilestoneCelebration(int days) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold.withOpacity(0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 14),
              Text(
                '$days дней подряд!',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 20),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ты держишь ритуал уже так долго — это настоящая верность себе.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDark,
                  ),
                  child: const Text('Спасибо'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reveal() {
    setState(() => _isRevealed = true);
  }

  void _share() {
    if (_card == null) return;
    Share.share(
      '${_card!.name}\n\n"${_card!.keyMessage}"\n\nМоя карта дня в приложении «Таро дня»',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_card == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Таро дня', style: Theme.of(context).textTheme.titleLarge),
                  _MoonPhaseBadge(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    FlipCardWidget(
                      card: _card!,
                      isRevealed: _isRevealed,
                      onTap: _showGuessPrompt ? () {} : _reveal,
                    ),
                    const SizedBox(height: 14),
                    if (_showGuessPrompt) ...[
                      const Text(
                        'Угадай, какая карта выпадет сегодня',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: (_guessOptions ?? []).map((option) {
                            return OutlinedButton(
                              onPressed: () => _submitGuess(option),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textWarm,
                                side: BorderSide(color: AppColors.gold.withOpacity(0.4)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text(option.name, style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                        ),
                      ),
                    ] else if (_isRevealed) ...[
                      if (_lastGuessCorrect != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: (_lastGuessCorrect! ? AppColors.gold : AppColors.indigo).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _lastGuessCorrect! ? '✨ Угадал!' : 'Не в этот раз — но чутьё растёт',
                            style: const TextStyle(color: AppColors.goldBright, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _card!.fullText,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                        ),
                        child: Text(
                          '$_streak ${_streakLabel(_streak)} подряд',
                          style: const TextStyle(color: AppColors.goldBright, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MonthlyCardScreen(storage: widget.storage),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 14, color: AppColors.textMuted),
                        label: const Text(
                          'Карта месяца',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                      Builder(builder: (context) {
                        final (correct, total) = widget.storage.getGuessStats();
                        if (total == 0) return const SizedBox.shrink();
                        final percent = ((correct / total) * 100).round();
                        return Text(
                          'Угадываешь в $percent% случаев',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                        );
                      }),
                    ] else
                      const Text(
                        'Нажми на карту',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ),
            if (_isRevealed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share_outlined, size: 16, color: AppColors.goldBright),
                        label: const Text('Поделиться'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.goldBright,
                          side: const BorderSide(color: AppColors.gold),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SpreadsScreen(storage: widget.storage, ads: widget.ads),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.bgDark,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Ещё расклады'),
                      ),
                    ),
                  ],
                ),
              ),
            _BottomNav(storage: widget.storage),
          ],
        ),
      ),
    );
  }

  String _streakLabel(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) return 'дня';
    return 'дней';
  }
}

class _BottomNav extends StatelessWidget {
  final StorageService storage;
  const _BottomNav({required this.storage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x33D4AF37))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.nightlight_round, color: AppColors.goldBright, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NatalChartScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.style_outlined, color: AppColors.textMuted, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HistoryScreen(storage: storage)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_outlined, color: AppColors.textMuted, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CollectionScreen(storage: storage)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Показывает текущую фазу луны — небольшой атмосферный штрих в шапке,
/// без обращения к сети или сторонним пакетам.
class _MoonPhaseBadge extends StatelessWidget {
  const _MoonPhaseBadge();

  @override
  Widget build(BuildContext context) {
    final moon = MoonPhase.forDate(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(moon.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            moon.name,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
