import 'dart:math';
import 'package:flutter/material.dart';
import '../data/cards_data.dart';
import '../models/tarot_card.dart';
import '../services/ads_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SpreadsScreen extends StatelessWidget {
  final StorageService storage;
  final AdsService ads;
  const SpreadsScreen({super.key, required this.storage, required this.ads});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: Text('Ещё расклады', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SpreadCard(
            icon: Icons.favorite_outline,
            title: 'На отношения',
            description: 'Три карты покажут, что происходит между тобой и важным человеком',
            onTap: () => _openSpread(context, _SpreadType.relationship),
          ),
          const SizedBox(height: 12),
          _SpreadCard(
            icon: Icons.calendar_month_outlined,
            title: 'На неделю',
            description: 'Семь карт — по одной на каждый день недели',
            onTap: () => _openSpread(context, _SpreadType.week),
          ),
          const SizedBox(height: 12),
          _SpreadCard(
            icon: Icons.help_outline,
            title: 'Да / нет',
            description: 'Задумай вопрос и вытяни одну карту',
            onTap: () => _openSpread(context, _SpreadType.yesNo),
          ),
          const SizedBox(height: 12),
          _SpreadCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Кельтский крест',
            description: 'Классический расклад из 10 карт — глубокий разбор ситуации',
            onTap: () => _openSpread(context, _SpreadType.celticCross),
          ),
        ],
      ),
    );
  }

  void _openSpread(BuildContext context, _SpreadType type) async {
    final canUseFree = storage.canUseFreeSpreadToday();

    if (canUseFree) {
      await storage.markFreeSpreadUsed();
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => _SpreadResultScreen(type: type, storage: storage)));
      return;
    }

    // Бесплатный лимит на сегодня исчерпан — единственный способ открыть
    // ещё один расклад сейчас — посмотреть rewarded-рекламу.
    if (!context.mounted) return;
    final confirmed = await _showLimitReachedSheet(context);
    if (confirmed != true) return;

    if (!ads.isReady) {
      // На случай, если фоновый автоповтор ещё не запустился — пробуем
      // загрузить рекламу прямо сейчас, по факту нажатия пользователем.
      ads.preload();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Реклама ещё загружается, попробуй через пару секунд')),
      );
      return;
    }
    final rewarded = await ads.showRewardedAd();
    if (rewarded) {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => _SpreadResultScreen(type: type, storage: storage)));
    }
  }

  Future<bool?> _showLimitReachedSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.goldBright, size: 28),
              const SizedBox(height: 12),
              const Text(
                'Бесплатный расклад на сегодня уже использован',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textWarm, fontSize: 15),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.play_circle_outline, size: 18, color: AppColors.bgDark),
                  label: const Text('Посмотреть рекламу и открыть расклад'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _SpreadType { relationship, week, yesNo, celticCross }

class _SpreadCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _SpreadCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: AppColors.gold.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.goldBright, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textWarm, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Показывает результат выбранного расклада.
/// Для MVP используются общие тексты карт (fullText / yesNoText) —
/// отдельные позиционные тексты для расклада "на отношения" добавляются
/// по мере готовности контента (см. tarot-paid-spreads-texts.md).
class _SpreadResultScreen extends StatefulWidget {
  final _SpreadType type;
  final StorageService storage;
  const _SpreadResultScreen({required this.type, required this.storage});

  @override
  State<_SpreadResultScreen> createState() => _SpreadResultScreenState();
}

class _SpreadResultScreenState extends State<_SpreadResultScreen> {
  late final List<TarotCard> _drawn;
  late final List<String> _positions;
  late final String _title;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _title = switch (widget.type) {
      _SpreadType.relationship => 'На отношения',
      _SpreadType.week => 'На неделю',
      _SpreadType.yesNo => 'Да / нет',
      _SpreadType.celticCross => 'Кельтский крест',
    };
    final cardCount = switch (widget.type) {
      _SpreadType.relationship => 3,
      _SpreadType.week => 7,
      _SpreadType.yesNo => 1,
      _SpreadType.celticCross => 10,
    };
    _positions = switch (widget.type) {
      _SpreadType.relationship => ['Ты', 'Партнёр', 'Что между вами'],
      _SpreadType.week => ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      _SpreadType.yesNo => ['Ответ'],
      _SpreadType.celticCross => [
          'Суть ситуации',
          'Препятствие или вызов',
          'Основа, корень вопроса',
          'Недавнее прошлое',
          'Возможное будущее',
          'Ближайшее будущее',
          'Твоё отношение к ситуации',
          'Внешнее влияние, окружение',
          'Надежды и страхи',
          'Итог, к чему всё идёт',
        ],
    };

    final shuffled = List.of(allCards)..shuffle(random);
    _drawn = shuffled.take(cardCount).toList();

    // Отмечаем все вытянутые карты как встреченные — для коллекции.
    widget.storage.markCardsDiscovered(_drawn.map((c) => c.number).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: Text(_title, style: Theme.of(context).textTheme.titleLarge),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _drawn.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final card = _drawn[index];
          final text = widget.type == _SpreadType.yesNo ? card.yesNoText : card.fullText;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.03),
              border: Border.all(color: AppColors.gold.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _positions[index],
                  style: const TextStyle(color: AppColors.goldBright, fontSize: 11, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Text(card.name, style: const TextStyle(color: AppColors.textWarm, fontSize: 15)),
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}
