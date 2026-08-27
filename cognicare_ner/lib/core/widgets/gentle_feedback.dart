import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Large, friendly, auto-dismissing feedback overlay.
///
/// Never uses a buzzer, harsh sound, haptic jolt, or red. Shows a warm
/// "Very good!" with a green check, or a kind "Let's try again". Fades itself
/// out after a short, unhurried moment.
class GentleFeedback {
  GentleFeedback._();

  static void correct(BuildContext context) => _show(
        context,
        icon: Icons.check_circle_rounded,
        color: AppColors.correct,
        surface: AppColors.correctSurface,
        message: AppLocalizations.of(context).veryGood,
      );

  static void tryAgain(BuildContext context) => _show(
        context,
        icon: Icons.favorite_rounded,
        color: AppColors.tryAgain,
        surface: AppColors.tryAgainSurface,
        message: AppLocalizations.of(context).letsTryAgain,
      );

  static void _show(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required Color surface,
    required String message,
  }) {
    final OverlayState overlay = Overlay.of(context);
    late OverlayEntry entry;
    void remove() {
      if (entry.mounted) entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _FeedbackOverlay(
        icon: icon,
        color: color,
        surface: surface,
        message: message,
        onDone: remove,
      ),
    );
    overlay.insert(entry);
    // Safety net so the overlay never lingers if the host unmounts mid-play.
    Future<void>.delayed(const Duration(seconds: 2), remove);
  }
}

class _FeedbackOverlay extends StatefulWidget {
  const _FeedbackOverlay({
    required this.icon,
    required this.color,
    required this.surface,
    required this.message,
    required this.onDone,
  });

  final IconData icon;
  final Color color;
  final Color surface;
  final String message;
  final VoidCallback onDone;

  @override
  State<_FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<_FeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> pop =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return Positioned.fill(
      // Non-interactive: no time pressure, nothing to dismiss by tapping.
      child: IgnorePointer(
        child: Container(
          color: const Color(0x22000000),
          alignment: Alignment.center,
          child: FadeTransition(
            opacity: _controller,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(pop),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: widget.surface,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius + 8),
                  border: Border.all(color: widget.color, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 96, color: widget.color),
                    const SizedBox(height: 16),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: AppText.title(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
