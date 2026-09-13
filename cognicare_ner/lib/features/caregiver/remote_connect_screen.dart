import 'package:flutter/material.dart';

import '../../core/services/nawal_remote.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';

/// Caregiver screen to pair and check the NAWAL BLE remote, and to see what
/// each button does. Bluetooth is Android-only, so on web it explains that the
/// remote works from the installed Android app.
class RemoteConnectScreen extends StatelessWidget {
  const RemoteConnectScreen({super.key});

  static const List<(String, String)> _map = <(String, String)>[
    ('1 – 9', 'Choose the matching answer'),
    ('Sound', 'Play the question / family voice again'),
    ('Back / Repeat', 'Repeat the prompt'),
    ('Hint', 'Get a gentle clue'),
    ('Next', 'Move to the next step'),
    ('Page ▲ / ▼', 'See more answer choices'),
    ('Call', 'Tell the caregiver help is needed'),
  ];

  @override
  Widget build(BuildContext context) {
    final bool supported = NawalRemote.instance.isSupported;
    return Scaffold(
      appBar: AppBar(title: const Text('NAWAL Remote')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!supported)
              BigCard(
                color: AppColors.primarySoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Use the Android app', style: AppText.title().copyWith(fontSize: 22)),
                    const SizedBox(height: 8),
                    Text(
                      'The physical NAWAL remote connects over Bluetooth, which '
                      'works in the installed Android app. On the web version, '
                      'every game is fully playable by touch.',
                      style: AppText.body(color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              _StatusCard(),
              const SizedBox(height: 16),
              BigButton(
                label: 'Scan again',
                icon: Icons.bluetooth_searching_rounded,
                color: AppColors.primary,
                onTap: () => NawalRemote.instance.start(),
              ),
            ],
            const SizedBox(height: 24),
            Text('What the buttons do', style: AppText.title().copyWith(fontSize: 22)),
            const SizedBox(height: 12),
            BigCard(
              child: Column(
                children: <Widget>[
                  for (final (String, String) e in _map)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 110,
                            child: Text(e.$1,
                                style: AppText.body().copyWith(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(e.$2,
                                style: AppText.body(color: AppColors.textMuted)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RemoteStatus>(
      valueListenable: NawalRemote.instance.statusNotifier,
      builder: (context, RemoteStatus status, _) {
        final bool on = status == RemoteStatus.connected;
        final bool scanning = status == RemoteStatus.scanning;
        final Color color = on
            ? AppColors.success
            : (scanning ? AppColors.gentleWarning : AppColors.textMuted);
        final String label = on
            ? 'Remote connected'
            : (scanning ? 'Searching for the remote…' : 'Remote not connected');
        return BigCard(
          child: Row(
            children: <Widget>[
              Icon(Icons.gamepad_rounded, size: 48, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: AppText.title().copyWith(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      on
                          ? 'The patient can now play games with the remote.'
                          : 'Turn on the remote and keep it nearby.',
                      style: AppText.body(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
