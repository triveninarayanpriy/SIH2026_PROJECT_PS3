import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import 'game_models.dart';

/// A large item tile (big icon + label). Display-only when [onTap] is null;
/// a huge single-tap answer target when [onTap] is set. Pass [item] = null to
/// draw the "?" slot at the end of a sequence.
class GameTile extends StatelessWidget {
  const GameTile({
    super.key,
    this.item,
    this.onTap,
    this.size = 132,
    this.highlight = false,
  });

  final GameItem? item;
  final VoidCallback? onTap;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final GameItem? it = item;
    final double iconSize = size * 0.44;
    final Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          it?.icon ?? Icons.help_outline_rounded,
          size: iconSize,
          color: it == null ? AppColors.primary : AppColors.text,
        ),
        if (it != null) ...[
          const SizedBox(height: 8),
          Text(
            it.label,
            textAlign: TextAlign.center,
            style: AppText.body().copyWith(fontSize: 18),
          ),
        ],
      ],
    );

    final BoxDecoration decoration = BoxDecoration(
      color: highlight ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      border: Border.all(
        color: highlight ? AppColors.primary : AppColors.border,
        width: highlight ? 2.5 : 1.5,
      ),
    );

    if (onTap == null) {
      return Container(
        width: size,
        height: size,
        decoration: decoration,
        child: content,
      );
    }

    return Semantics(
      button: true,
      label: it?.label ?? 'answer',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Container(
            width: size,
            height: size,
            decoration: decoration,
            child: content,
          ),
        ),
      ),
    );
  }
}
