import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Shared NAWAL design-language widgets (reference: sky-blue page, white cards
/// with a bold navy border, black text). These give every screen one look while
/// keeping each screen's own content and behaviour.

/// Centers content at a max width on wide (web) screens; full-width on phones.
/// Use inside a Scaffold body so web pages don't stretch edge-to-edge.
class NawalPage extends StatelessWidget {
  const NawalPage({
    super.key,
    required this.child,
    this.maxWidth = AppTheme.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// White card with the signature bold navy border. Optional [onTap].
class NawalCard extends StatelessWidget {
  const NawalCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.borderWidth = 2.5,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Widget box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.ink, width: borderWidth),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: box,
      ),
    );
  }
}

/// A row list-tile in the NAWAL style: a soft-blue icon box, title + subtitle,
/// and a trailing chevron. Used for game lists and caregiver actions.
class NawalListTile extends StatelessWidget {
  const NawalListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.ink,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return NawalCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.skyBg.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: iconColor),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: AppText.title().copyWith(fontSize: 20, color: AppColors.text)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 15)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink, size: 30),
        ],
      ),
    );
  }
}

/// A big centered "hero" card (reference role cards): icon over title + description.
class NawalHeroCard extends StatelessWidget {
  const NawalHeroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.iconColor = AppColors.ink,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return NawalCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      borderWidth: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.skyBg.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: iconColor),
          ),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.title().copyWith(fontSize: 26, color: AppColors.text)),
          const SizedBox(height: 8),
          Text(description,
              textAlign: TextAlign.center,
              style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}

/// Lays [children] out responsively: a single column on phones, or a grid of
/// [columns] on wide screens. Each child should size to its container.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = 16,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!AppTheme.isWide(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            children[i],
            if (i < children.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final double w = (c.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final Widget child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}
