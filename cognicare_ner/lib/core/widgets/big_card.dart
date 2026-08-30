import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Soft, high-contrast card with generous padding and a gentle (never harsh)
/// shadow.
class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.gradientBorder,
    this.title,
    this.icon,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Gradient? gradientBorder;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowDark,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || icon != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 32, color: AppColors.primary),
                  const SizedBox(width: 12),
                ],
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: AppText.title().copyWith(fontSize: 24),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );

    if (gradientBorder != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: gradientBorder,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius + 2),
        ),
        padding: const EdgeInsets.all(2), // border width
        child: cardContent,
      );
    }

    return cardContent;
  }
}
