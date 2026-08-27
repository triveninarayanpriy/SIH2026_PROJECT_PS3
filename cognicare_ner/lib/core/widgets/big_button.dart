import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Full-width, >= 72dp-tall primary action with a large label and optional
/// icon.
///
/// Single tap only — no long-press, double-tap, or swipe. A screen should have
/// one BigButton as its single primary action.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color bg = color ?? AppColors.primary;
    final Color fg = AppColors.onColor(bg);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          // Single tap only: no onLongPress / onDoubleTap handlers.
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTheme.minTapTarget,
              minWidth: double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
                vertical: 18,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppTheme.iconSize, color: fg),
                    const SizedBox(width: 16),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppText.button(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
