import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/models/media_item.dart';
import '../../core/services/local_db.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../l10n/app_localizations.dart';

/// Calm / Home-Simulation mode.
///
/// A gentle full-screen space that slideshows family photos with the patient's
/// favourite music looping and soft caregiver-voice encouragement. No timers on
/// screen, no pressure — just a big "Home" button to leave. Reached from the
/// Relax button or auto-offered by the game frustration protocol.
class CalmModeScreen extends StatefulWidget {
  const CalmModeScreen({super.key});

  @override
  State<CalmModeScreen> createState() => _CalmModeScreenState();
}

class _CalmModeScreenState extends State<CalmModeScreen> {
  static const List<String> _phrases = <String>[
    'You are doing wonderfully.',
    'Relax and enjoy the pictures.',
    'Everything is calm and safe.',
    'You are loved.',
  ];

  final AudioPlayer _music = AudioPlayer();
  final Random _rng = Random();
  Timer? _slideTimer;
  Timer? _voiceTimer;

  List<String> _photos = <String>[];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _photos = _collectPhotos();

    final String? music = _firstMusic();
    if (music != null) {
      try {
        if (music.startsWith('http')) {
          await _music.setUrl(music);
        } else {
          await _music.setFilePath(music);
        }
        await _music.setLoopMode(LoopMode.one);
        _music.play();
      } catch (_) {
        // No/unsupported music — stay quiet.
      }
    }

    if (_photos.length > 1) {
      _slideTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted) {
          setState(() => _index = (_index + 1) % _photos.length);
        }
      });
    }
    // Gentle spoken encouragement, occasionally.
    Future<void>.delayed(const Duration(seconds: 2), _encourage);
    _voiceTimer =
        Timer.periodic(const Duration(seconds: 25), (_) => _encourage());
  }

  void _encourage() {
    if (!mounted) return;
    // Clip-first (caregiver voice) with TTS fallback.
    TtsService.instance.play(_phrases[_rng.nextInt(_phrases.length)]);
  }

  List<String> _collectPhotos() {
    final List<String> out = <String>[];
    for (final MediaItem m in <MediaItem>[
      ...LocalDb.mediaByType('familyFace'),
      ...LocalDb.mediaByType('photo'),
    ]) {
      if (m.url.startsWith('http')) out.add(m.url);
    }
    return out;
  }

  String? _firstMusic() {
    for (final MediaItem m in LocalDb.mediaByType('music')) {
      if (m.url.isNotEmpty) return m.url;
      if (m.localPath != null && m.localPath!.isNotEmpty) return m.localPath;
    }
    return null;
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _voiceTimer?.cancel();
    _music.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primarySoft, AppColors.secondarySoft],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: Column(
              children: [
                Expanded(child: Center(child: _stage(context))),
                const SizedBox(height: 20),
                BigButton(
                  label: AppLocalizations.of(context).home,
                  icon: Icons.home_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stage(BuildContext context) {
    if (_photos.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.self_improvement_rounded,
              size: 140, color: AppColors.secondary),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context).relax,
              textAlign: TextAlign.center, style: AppText.gameQuestion()),
          const SizedBox(height: 8),
          Text(
            'Take a slow, easy breath.',
            textAlign: TextAlign.center,
            style: AppText.body(color: AppColors.textMuted),
          ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      child: ClipRRect(
        key: ValueKey<int>(_index),
        borderRadius: BorderRadius.circular(28),
        child: Image.network(
          _photos[_index],
          width: 320,
          height: 320,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(
            Icons.photo_rounded,
            size: 140,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }
}
