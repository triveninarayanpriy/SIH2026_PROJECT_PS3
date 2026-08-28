import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

/// A big single-tap button that plays a family voice clip via just_audio.
///
/// [src] may be an http(s) URL or a local file path. Playback errors are
/// swallowed (e.g. missing/offline clip) so the game never crashes.
class AudioPlayButton extends StatefulWidget {
  const AudioPlayButton({super.key, required this.src});

  final String src;

  @override
  State<AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<AudioPlayButton> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    try {
      if (widget.src.startsWith('assets/')) {
        await _player.setAsset(widget.src);
      } else if (widget.src.startsWith('http')) {
        await _player.setUrl(widget.src);
      } else {
        await _player.setFilePath(widget.src);
      }
      await _player.seek(Duration.zero);
      // Start playback; don't await completion (the clip may run for seconds).
      _player.play();
    } catch (_) {
      // Missing/unsupported source — stay silent rather than crash.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Play the voice',
          child: Material(
            color: AppColors.secondarySoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _play,
              child: const SizedBox(
                width: 160,
                height: 160,
                child: Icon(Icons.volume_up_rounded,
                    size: 88, color: AppColors.secondary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Tap to listen', style: AppText.body(color: AppColors.textMuted)),
      ],
    );
  }
}
