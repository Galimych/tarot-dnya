import 'package:flutter/material.dart';
import '../data/cards_data.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class CollectionScreen extends StatelessWidget {
  final StorageService storage;
  const CollectionScreen({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    final discovered = storage.getDiscoveredCardNumbers();
    final total = allCards.length;
    final openedCount = discovered.length;
    final progress = total == 0 ? 0.0 : openedCount / total;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: Text('Коллекция', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Открыто $openedCount из $total карт',
                      style: const TextStyle(color: AppColors.textWarm, fontSize: 14),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(color: AppColors.goldBright, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
                if (openedCount == total) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '✨ Ты собрал всю колоду!',
                    style: TextStyle(color: AppColors.goldBright, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.62,
              ),
              itemCount: allCards.length,
              itemBuilder: (context, index) {
                final card = allCards[index];
                final isOpen = discovered.contains(card.number);
                return _CollectionCell(isOpen: isOpen, cardName: isOpen ? card.name : null);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionCell extends StatelessWidget {
  final bool isOpen;
  final String? cardName;
  const _CollectionCell({required this.isOpen, required this.cardName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOpen ? AppColors.gold : AppColors.textMuted.withOpacity(0.25),
          width: isOpen ? 1.4 : 1,
        ),
        gradient: isOpen
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.cardGradientTop, AppColors.cardGradientBottom],
              )
            : null,
        color: isOpen ? null : Colors.white.withOpacity(0.02),
      ),
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      child: isOpen
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.goldBright, size: 14),
                const SizedBox(height: 4),
                Text(
                  cardName ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textWarm, fontSize: 9),
                ),
              ],
            )
          : Text(
              '?',
              style: TextStyle(color: AppColors.textMuted.withOpacity(0.4), fontSize: 22),
            ),
    );
  }
}
