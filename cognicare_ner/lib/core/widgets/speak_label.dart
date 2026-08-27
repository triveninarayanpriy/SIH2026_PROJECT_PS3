import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Large text paired with a big (>= 72dp) speaker button.
///
/// Tapping the speaker plays the recorded clip at [audioPath] when provided,
/// otherwise speaks [text] via [TtsService]. Single tap only.
class SpeakLabel extends StatelessWidget {
  const SpeakLabel({
    super.key,
    required this.text,
    this.audioPath,
    this.textStyle,
  });

  final String text;
  final String? audioPath;
  final TextStyle? textStyle;

  Future<void> _speak() async {
    // Primary: the caregiver-recorded clip at audioPath (or a clip mapped to
    // this text); fallback: device TTS.
    await TtsService.instance.play(text, audioPath: audioPath);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(text, style: textStyle ?? AppText.title()),
        ),
        const SizedBox(width: 16),
        Semantics(
          button: true,
          label: 'Listen',
          child: Material(
            color: AppColors.secondarySoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _speak,
              child: const SizedBox(
                width: AppTheme.minTapTarget,
                height: AppTheme.minTapTarget,
                child: Icon(
                  Icons.volume_up_rounded,
                  size: AppTheme.iconSize,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
