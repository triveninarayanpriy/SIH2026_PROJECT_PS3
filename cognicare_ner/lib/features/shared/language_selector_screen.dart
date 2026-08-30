import 'package:flutter/material.dart';

import '../../core/services/local_db.dart';
import '../../core/services/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';

class LanguageSelectorScreen extends StatelessWidget {
  const LanguageSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Language'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        itemCount: LocaleController.supportedLanguages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final lang = LocaleController.supportedLanguages[index];
          final code = lang['code']!;
          final name = lang['name']!;
          final nativeName = lang['nativeName']!;

          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              onTap: () async {
                await LocalDb.putSetting('app_locale', code);
                LocaleController.setLocale(Locale(code));
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nativeName,
                            style: AppText.button(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: AppText.body(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.border,
                      size: 32,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
