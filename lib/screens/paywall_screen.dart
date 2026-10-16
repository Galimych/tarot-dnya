import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Экран подписки. Оплата здесь не подключена — это UI-заглушка,
/// в реальном проекте сюда встраивается RuStore Pay / другой биллинг.
class PaywallScreen extends StatefulWidget {
  final StorageService storage;
  const PaywallScreen({super.key, required this.storage});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPlan = 0; // 0 = год, 1 = месяц

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 8),
              const Icon(Icons.workspace_premium, color: AppColors.goldBright, size: 34),
              const SizedBox(height: 10),
              Text('Откройся полностью', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Безлимитные расклады и полное послание каждый день',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              const _Feature(text: 'Безлимит карт и раскладов'),
              const _Feature(text: 'Расклад на отношения и неделю'),
              const _Feature(text: 'Без рекламы'),
              const SizedBox(height: 24),
              _PlanTile(
                title: 'Год',
                subtitle: 'выгода 70%',
                price: '2 990 ₽',
                selected: _selectedPlan == 0,
                onTap: () => setState(() => _selectedPlan = 0),
              ),
              const SizedBox(height: 10),
              _PlanTile(
                title: 'Месяц',
                subtitle: null,
                price: '399 ₽',
                selected: _selectedPlan == 1,
                onTap: () => setState(() => _selectedPlan = 1),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Заглушка: в реальном приложении здесь вызов биллинга,
                    // и setSubscribed(true) только после успешной оплаты.
                    await widget.storage.setSubscribed(true);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Продолжить'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Отменить можно в любой момент',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String text;
  const _Feature({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: AppColors.goldBright, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: AppColors.textWarm, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.gold.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.gold.withOpacity(0.25),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textWarm, fontSize: 14)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(color: AppColors.goldBright, fontSize: 10)),
              ],
            ),
            Text(price, style: const TextStyle(color: AppColors.goldBright, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
