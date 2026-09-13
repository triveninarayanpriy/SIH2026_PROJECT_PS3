import 'package:flutter/material.dart';

import '../services/nawal_remote.dart';
import '../theme/app_colors.dart';

/// Small gamepad chip that reflects the NAWAL remote's live connection state.
///
/// Hidden entirely on platforms where the remote can't work (e.g. web), so it
/// never shows a permanently-grey "off" badge where there's no Bluetooth.
class RemoteStatusChip extends StatelessWidget {
  const RemoteStatusChip({super.key, this.compact = false});

  /// When true, shows only the icon (for tight app bars).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!NawalRemote.instance.isSupported) return const SizedBox.shrink();
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
            : (scanning ? 'Searching…' : 'Remote off');
        final Icon icon = Icon(Icons.gamepad_rounded, color: color, size: 20);
        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(message: label, child: icon),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              icon,
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
