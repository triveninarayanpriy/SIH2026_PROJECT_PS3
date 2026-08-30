import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';


import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import 'patient_home.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  bool _navigated = false;

  Future<void> _initMedia() async {
    final welcomeAudio = LocalDb.mediaByType('welcome_voice').firstOrNull;
    final welcomeVideo = LocalDb.mediaByType('welcome_video').firstOrNull;

    bool willNavigateByVideo = false;
    bool willNavigateByAudio = false;

    if (welcomeVideo != null) {
      if (welcomeVideo.localPath != null) {
        _videoController = VideoPlayerController.file(File(welcomeVideo.localPath!));
      } else if (welcomeVideo.url.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(welcomeVideo.url));
      }
      if (_videoController != null) {
        await _videoController!.initialize();
        _videoController!.play();
        _videoController!.setLooping(false);
        _videoController!.addListener(() {
          if (_videoController!.value.isInitialized &&
              _videoController!.value.duration.inMilliseconds > 0 &&
              _videoController!.value.position >= _videoController!.value.duration) {
            _navigateToHome();
          }
        });
        willNavigateByVideo = true;
        if (mounted) setState(() {});
      }
    }

    if (welcomeAudio != null) {
      try {
        if (welcomeAudio.url.startsWith('http')) {
          await _audioPlayer.setUrl(welcomeAudio.url);
        } else if (welcomeAudio.localPath != null) {
          await _audioPlayer.setFilePath(welcomeAudio.localPath!);
        }
        
        if (!willNavigateByVideo) {
          _audioPlayer.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
              _navigateToHome();
            }
          });
          willNavigateByAudio = true;
        }
        _audioPlayer.play();
      } catch (_) {}
    }

    if (!willNavigateByVideo && !willNavigateByAudio) {
      Future.delayed(const Duration(seconds: 4), _navigateToHome);
    }
  }

  void _navigateToHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PatientHome(patientId: widget.patientId),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final welcomePhoto = LocalDb.mediaByType('welcome_photo').firstOrNull;
    final hasVideo = _videoController != null && _videoController!.value.isInitialized;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primarySoft, AppColors.secondarySoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: hasVideo
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                          : welcomePhoto != null
                              ? TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(seconds: 1),
                                  builder: (context, val, child) {
                                    return Opacity(
                                      opacity: val,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: welcomePhoto.localPath != null
                                          ? Image.file(
                                              File(welcomePhoto.localPath!),
                                              width: double.infinity,
                                              height: 300,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.network(
                                              welcomePhoto.url,
                                              width: double.infinity,
                                              height: 300,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.favorite_rounded,
                                      size: 100,
                                      color: AppColors.secondary,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Welcome back!',
                                      textAlign: TextAlign.center,
                                      style: AppText.title(),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
