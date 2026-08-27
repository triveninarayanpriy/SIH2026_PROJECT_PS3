import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Large progress dots for game steps.
///
/// Shows how many steps are done — never a countdown or timer. Completed steps
/// are green, the current step is highlighted, upcoming steps are muted.
class BigProgressDots extends StatelessWidget {
  const BigProgressDots({
    super.key,
    required this.total,
    required this.current,
  });

  /// Total number of steps.
  final int total;

  /// Count of completed steps (0..total); index [current] is the active step.
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(total, (int i) {
        final bool done = i < current;
        final bool active = i == current;
        final double size = active ? 28 : 22;
        final Color color = done
            ? AppColors.success
            : active
                ? AppColors.primary
                : AppColors.border;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      }),
    );
  }
}
