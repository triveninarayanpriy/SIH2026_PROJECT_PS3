import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

/// A big single-tap button that plays a family voice clip via just_audio.
///
/// [src] may be an http(s) URL or a local file path. Playback errors are
/// swallowed (e.g. missing/offline clip) so the game never crashes.
class AudioPlayButton extends StatefulWidget {
  const AudioPlayButton({super.key, required this.src, this.autoPlay = false});

  final String src;
  final bool autoPlay;

  @override
  State<AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<AudioPlayButton> with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing && state.processingState != ProcessingState.completed;
      if (playing != _isPlaying) {
        setState(() {
          _isPlaying = playing;
        });
        if (playing) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.animateTo(1.0, duration: const Duration(milliseconds: 200));
        }
      }
    });
    // Auto-play when built if requested
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _play();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
          child: ScaleTransition(
            scale: _scaleAnimation,
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
        ),
        const SizedBox(height: 12),
        Text('Tap to listen', style: AppText.body(color: AppColors.textMuted)),
      ],
    );
  }
}
