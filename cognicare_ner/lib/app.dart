import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/big_button.dart';
import 'core/widgets/theme_preview_screen.dart';

/// Root widget for CogniCare NER.
///
/// The concrete role (`patient` | `caregiver` | `doctor`) is supplied by the
/// role-specific entrypoint. For now the app shows a placeholder home with a
/// shortcut into the design-system preview; feature UIs come later.
class CogniCareApp extends StatelessWidget {
  const CogniCareApp({super.key, required this.role});

  /// One of: `patient`, `caregiver`, `doctor`.
  final String role;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CogniCare NER',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routes: {
        '/theme-preview': (_) => const ThemePreviewScreen(),
      },
      home: _RolePlaceholder(role: role),
    );
  }
}

class _RolePlaceholder extends StatelessWidget {
  const _RolePlaceholder({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final String label = role.isEmpty ? 'unknown' : role;
    return Scaffold(
      appBar: AppBar(title: const Text('CogniCare NER')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            BigButton(
              label: 'Open theme preview',
              icon: Icons.palette_rounded,
              onTap: () => Navigator.of(context).pushNamed('/theme-preview'),
            ),
          ],
        ),
      ),
    );
  }
}
