import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'big_button.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final String languageCode;
  final String name;
  final ValueChanged<String> onRecordingComplete;

  const VoiceRecorderWidget({
    Key? key,
    required this.languageCode,
    this.name = '',
    required this.onRecordingComplete,
  }) : super(key: key);

  @override
  _VoiceRecorderWidgetState createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _audioPath;
  
  late AnimationController _pulseController;

  final Map<String, String> _prompts = {
    'en': 'I am {name}, your family member',
    'hi': 'मैं {name} हूँ, आपका परिवार का सदस्य',
    'as': 'মই {name}, তোমাৰ পৰিয়ালৰ সদস্য',
    'bn': 'আমি {name}, তোমার পরিবার',
    'mni': 'ꯑꯩ {name} ꯅꯤ, ꯅꯍꯥꯛꯀꯤ ꯏꯃꯨꯡ ꯃꯅꯨꯡ',
    'brx': 'आं {name} नो, नोंथांनि गोहो'
  };

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String get _promptText {
    final template = _prompts[widget.languageCode] ?? _prompts['en']!;
    final displayName = widget.name.isNotEmpty ? widget.name : '[Name]';
    return template.replaceAll('{name}', displayName);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      if (path != null) {
        widget.onRecordingComplete(path);
      }
    } else {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        return;
      }
      
      final Directory tempDir = Directory.systemTemp;
      final String path = '${tempDir.path}/record_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      
      setState(() {
        _isRecording = true;
        _audioPath = null;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_audioPath == null) return;
    
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.setFilePath(_audioPath!);
      await _audioPlayer.play();
      setState(() => _isPlaying = true);
    }
  }

  void _discardRecording() {
    setState(() {
      _audioPath = null;
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Please say:',
            style: AppText.body().copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _promptText,
              style: AppText.title().copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          if (_audioPath == null) ...[
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red.withOpacity(0.3 + (_pulseController.value * 0.4)) : AppColors.primary,
                      boxShadow: _isRecording ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 15 * _pulseController.value,
                          spreadRadius: 5 * _pulseController.value,
                        )
                      ] : [],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: AppTheme.iconSize,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isRecording ? 'Tap to stop' : 'Tap to record',
              style: AppText.body(),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BigButton(
                  label: _isPlaying ? 'Stop' : 'Play',
                  icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                  onTap: _togglePlayback,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 16),
                BigButton(
                  label: 'Redo',
                  icon: Icons.refresh,
                  onTap: _discardRecording,
                  color: AppColors.gentleWarning,
                ),
              ],
            )
          ],
        ],
      ),
    );
  }
}
