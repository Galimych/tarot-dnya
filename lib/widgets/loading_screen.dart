import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Последняя возникшая ошибка. Показывается на экране загрузки, чтобы при
/// зависании запуска было видно причину, а не бесконечный кружок.
final ValueNotifier<String?> lastErrorNotifier = ValueNotifier<String?>(null);

/// Сообщает об ошибке в безопасный момент (не во время построения экрана).
void reportError(Object error) {
  Future.microtask(() => lastErrorNotifier.value = error.toString());
}

class LoadingScreen extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const LoadingScreen({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message == null)
                const CircularProgressIndicator(color: AppColors.gold)
              else
                const Icon(Icons.error_outline, color: AppColors.goldBright, size: 36),
              const SizedBox(height: 16),
              if (message != null)
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textWarm, fontSize: 13),
                ),
              ValueListenableBuilder<String?>(
                valueListenable: lastErrorNotifier,
                builder: (context, error, _) {
                  if (error == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Техническая информация: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  );
                },
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDark,
                  ),
                  child: const Text('Повторить'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
