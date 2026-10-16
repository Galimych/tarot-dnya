import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tarot_card.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storage;
  const HistoryScreen({super.key, required this.storage});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<CardHistoryEntry> _history;
  final _formatter = DateFormat('d MMMM', 'ru');

  @override
  void initState() {
    super.initState();
    _history = widget.storage.getHistory();
  }

  Future<void> _openNoteEditor(CardHistoryEntry entry, bool isToday) async {
    final controller = TextEditingController(text: entry.note);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.card.name, style: const TextStyle(color: AppColors.goldBright, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                isToday ? 'Сегодня' : _formatter.format(entry.date),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                style: const TextStyle(color: AppColors.textWarm, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Что эта карта значила для тебя сегодня?',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      await widget.storage.saveNoteForDate(entry.date, result);
      setState(() {
        _history = widget.storage.getHistory();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: Text('История карт', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: _history.isEmpty
          ? const Center(
              child: Text(
                'Здесь появится история открытых карт.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = _history[index];
                final isToday = index == 0;
                return GestureDetector(
                  onTap: () => _openNoteEditor(entry, isToday),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withOpacity(isToday ? 0.4 : 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isToday ? AppColors.gold : AppColors.textMuted,
                            ),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.cardGradientTop, AppColors.cardGradientBottom],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.card.name, style: const TextStyle(color: AppColors.textWarm, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                isToday ? 'Сегодня' : _formatter.format(entry.date),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                              if (entry.note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  entry.note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          entry.note.isNotEmpty ? Icons.edit_note : Icons.add_comment_outlined,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
