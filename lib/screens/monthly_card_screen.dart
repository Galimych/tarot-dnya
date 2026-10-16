import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tarot_card.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flip_card.dart';

/// Более редкий ритуал, чем карта дня — выбирается раз в месяц и
/// остаётся неизменной до следующего.
class MonthlyCardScreen extends StatefulWidget {
  final StorageService storage;
  const MonthlyCardScreen({super.key, required this.storage});

  @override
  State<MonthlyCardScreen> createState() => _MonthlyCardScreenState();
}

class _MonthlyCardScreenState extends State<MonthlyCardScreen> {
  TarotCard? _card;
  bool _isRevealed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final card = await widget.storage.getOrCreateMonthlyCard();
    setState(() {
      _card = card;
      _isRevealed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('LLLL', 'ru').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: Text('Карта месяца', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: _card == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Твоя карта на $monthName',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FlipCardWidget(
                    card: _card!,
                    isRevealed: _isRevealed,
                    onTap: () => setState(() => _isRevealed = true),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _card!.fullText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Эта карта будет сопровождать тебя весь месяц',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
    );
  }
}
