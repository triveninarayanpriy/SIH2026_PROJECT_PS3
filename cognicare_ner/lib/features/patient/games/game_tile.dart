import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import 'game_models.dart';

/// A decorated, optionally single-tap box holding arbitrary [child] content.
///
/// Big by default (min 96x88 target). Pass [width]/[height] for fixed square
/// tiles (e.g. the pattern sequence); leave them null to size to the content
/// (e.g. a name pill).
class GameTile extends StatelessWidget {
  const GameTile({
    super.key,
    required this.child,
    this.onTap,
    this.width,
    this.height,
    this.highlight = false,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool highlight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final BoxDecoration decoration = BoxDecoration(
      color: highlight ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      border: Border.all(
        color: highlight ? AppColors.primary : AppColors.border,
        width: highlight ? 2.5 : 1.5,
      ),
    );

    final Widget box = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, minHeight: 88),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        alignment: Alignment.center,
        decoration: decoration,
        child: child,
      ),
    );

    if (onTap == null) return box;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: box,
        ),
      ),
    );
  }
}

/// Inner content for a [GameItem] (big icon + label).
class GameItemContent extends StatelessWidget {
  const GameItemContent({super.key, required this.item, this.iconSize = 56});

  final GameItem item;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: iconSize, color: item.color ?? AppColors.text),
        const SizedBox(height: 8),
        Text(
          item.label,
          textAlign: TextAlign.center,
          style: AppText.body().copyWith(fontSize: 18),
        ),
      ],
    );
  }
}
