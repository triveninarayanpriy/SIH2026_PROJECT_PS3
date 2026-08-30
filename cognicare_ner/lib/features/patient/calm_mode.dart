import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/models/media_item.dart';
import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';
import '../../l10n/app_localizations.dart';

class CalmModeScreen extends StatefulWidget {
  const CalmModeScreen({super.key});

  @override
  State<CalmModeScreen> createState() => _CalmModeScreenState();
}

class _CalmModeScreenState extends State<CalmModeScreen> {
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Column(
                  children: [
                    Text('Relax & Unwind', style: AppText.title().copyWith(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text('Take a moment to feel at peace.', style: AppText.body(color: AppColors.secondary)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
                  children: [
                    _buildCategoryCard(
                      context,
                      'Breathing Exercise',
                      Icons.air,
                      AppColors.success,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _BreathingExerciseScreen())),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryCard(
                      context,
                      'Family Photos',
                      Icons.photo_library,
                      AppColors.primary,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _SlideshowScreen())),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryCard(
                      context,
                      'Music',
                      Icons.music_note,
                      AppColors.secondary,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _MusicPlayerScreen())),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryCard(
                      context,
                      'Videos',
                      Icons.video_library,
                      AppColors.gentleWarning,
                      () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No videos available.')));
                      }
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: BigButton(
                  label: AppLocalizations.of(context).home,
                  icon: Icons.home_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: BigCard(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(title, style: AppText.title().copyWith(fontSize: 28)),
              ),
              Icon(Icons.arrow_forward_ios, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreathingExerciseScreen extends StatefulWidget {
  const _BreathingExerciseScreen();

  @override
  State<_BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<_BreathingExerciseScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 100.0, end: 250.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Breathe'), backgroundColor: AppColors.primarySoft, elevation: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primarySoft, AppColors.secondarySoft],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    width: _animation.value,
                    height: _animation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withOpacity(0.3),
                      border: Border.all(color: AppColors.secondary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _controller.status == AnimationStatus.forward ? 'Inhale' : 'Exhale',
                        style: AppText.title().copyWith(color: AppColors.secondary, fontSize: 32),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideshowScreen extends StatefulWidget {
  const _SlideshowScreen();
  
  @override
  State<_SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<_SlideshowScreen> {
  late List<MediaItem> _photos;
  int _currentIndex = 0;
  Timer? _timer;
  final AudioPlayer _player = AudioPlayer();
  
  @override
  void initState() {
    super.initState();
    _photos = LocalDb.mediaByType('familyFace');
    if (_photos.isEmpty) _photos = LocalDb.mediaByType('photo');
    
    if (_photos.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _photos.length;
        });
      });
    }
    _playBackgroundMusic();
  }

  Future<void> _playBackgroundMusic() async {
    final musicList = LocalDb.mediaByType('music');
    if (musicList.isNotEmpty) {
      final m = musicList.first;
      if (m.localPath != null && m.localPath!.isNotEmpty) {
        try {
          await _player.setFilePath(m.localPath!);
          await _player.setLoopMode(LoopMode.all);
          _player.play();
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Photos'), backgroundColor: AppColors.primarySoft, elevation: 0),
        body: Center(child: Text('No photos found.', style: AppText.body())),
      );
    }
    
    final currentPhoto = _photos[_currentIndex];
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(seconds: 1),
            child: (currentPhoto.localPath != null && currentPhoto.localPath!.isNotEmpty)
                ? Image.file(
                    File(currentPhoto.localPath!),
                    key: ValueKey<String>(currentPhoto.id),
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    currentPhoto.url,
                    key: ValueKey<String>(currentPhoto.id),
                    fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => const Icon(Icons.error, color: Colors.white, size: 50),
                  ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              currentPhoto.label ?? '',
              textAlign: TextAlign.center,
              style: AppText.title().copyWith(color: Colors.white, fontSize: 36, shadows: [const Shadow(blurRadius: 4, color: Colors.black)]),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 40),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicPlayerScreen extends StatefulWidget {
  const _MusicPlayerScreen();

  @override
  State<_MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<_MusicPlayerScreen> {
  List<MediaItem> _tracks = [];
  final AudioPlayer _player = AudioPlayer();
  int? _playingIndex;

  @override
  void initState() {
    super.initState();
    _tracks = LocalDb.mediaByType('music');
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playTrack(int index) async {
    final track = _tracks[index];
    if (track.localPath != null && track.localPath!.isNotEmpty) {
      if (_playingIndex == index) {
        if (_player.playing) {
          _player.pause();
        } else {
          _player.play();
        }
      } else {
        await _player.setFilePath(track.localPath!);
        _player.play();
      }
      setState(() {
        _playingIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music'), backgroundColor: AppColors.primarySoft, elevation: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primarySoft, AppColors.secondarySoft],
          ),
        ),
        child: _tracks.isEmpty
            ? Center(child: Text('No music found.', style: AppText.body()))
            : ListView.builder(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                itemCount: _tracks.length,
                itemBuilder: (context, index) {
                  final track = _tracks[index];
                  final isPlaying = _playingIndex == index && _player.playing;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.secondary.withOpacity(0.2),
                        child: Icon(Icons.music_note, color: AppColors.secondary),
                      ),
                      title: Text(track.label ?? 'Unknown Track', style: AppText.title().copyWith(fontSize: 24)),
                      trailing: IconButton(
                        icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 48, color: AppColors.primary),
                        onPressed: () => _playTrack(index),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
