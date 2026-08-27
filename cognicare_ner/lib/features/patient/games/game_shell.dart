import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ai/anomaly_detector.dart';
import '../../../core/models/game_result.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/local_db.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/big_progress_dots.dart';
import '../../../core/widgets/gentle_feedback.dart';
import '../../../core/widgets/speak_label.dart';
import 'game_models.dart';
import 'game_tile.dart';

/// Shared shell every patient game runs inside.
///
/// Renders the question area (BigProgressDots on top, spoken prompt, the
/// sequence with a "?" slot, and big single-tap answer tiles), handles the
/// round flow with gentle feedback (no timers, no buzzers), and on finish
/// writes a [GameResult] to LocalDb (+ sync queue) and shows a reward screen.
class GameShell extends StatefulWidget {
  const GameShell({
    super.key,
    required this.title,
    required this.game,
    required this.domain,
    required this.difficulty,
    required this.rounds,
    required this.patientId,
  });

  final String title;

  /// Uniform GameResult fields.
  final String game; // e.g. 'pattern'
  final String domain; // e.g. 'attention'
  final int difficulty;

  final List<GameRound> rounds;
  final String patientId;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final Uuid _uuid = const Uuid();

  int _index = 0;
  int _correct = 0;
  bool _roundScored = false; // first attempt on this round has been counted
  bool _locked = false; // ignore taps while a correct answer advances
  bool _finished = false;
  late final DateTime _start;

  int get _total => widget.rounds.length;
  GameRound get _round => widget.rounds[_index];

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _speakPrompt();
  }

  void _speakPrompt() {
    // Caregiver clip when available, otherwise the TTS stub. Never blocks.
    TtsService.instance.speak(_round.prompt);
  }

  Future<void> _answer(String choiceId) async {
    if (_locked) return;
    final bool isCorrect = choiceId == _round.answerId;

    // Score only the first attempt of each round.
    if (!_roundScored) {
      _roundScored = true;
      if (isCorrect) _correct++;
    }

    if (isCorrect) {
      _locked = true;
      GentleFeedback.correct(context);
      TtsService.instance.speak('Very good');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      _advance();
    } else {
      GentleFeedback.tryAgain(context);
      TtsService.instance.speak("Let's try again");
    }
  }

  void _advance() {
    if (_index + 1 >= _total) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _roundScored = false;
      _locked = false;
    });
    _speakPrompt();
  }

  Future<void> _finish() async {
    final GameResult result = GameResult(
      id: _uuid.v4(),
      patientId: widget.patientId,
      game: widget.game,
      domain: widget.domain,
      correct: _correct,
      total: _total,
      durationMs: DateTime.now().difference(_start).inMilliseconds,
      difficulty: widget.difficulty,
      at: DateTime.now(),
    );
    // Write-through: local first (+ enqueue for cloud). Never blocks the UI.
    await SyncService.instance.saveGameResult(result);
    // Check each domain for a cognitive drop (caregiver/doctor only — the
    // patient is never alarmed). Runs on the just-updated local history.
    await AnomalyDetector.instance.runForPatient(widget.patientId);
    if (!mounted) return;
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return _RewardView(correct: _correct, total: _total);
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            children: [
              BigProgressDots(total: _total, current: _index),
              const SizedBox(height: 20),
              SpeakLabel(
                text: _round.prompt,
                audioPath: _round.promptAudioPath,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    // Bounded, non-scrolling: keeps a tall stimulus on one screen
                    // without ever forcing the patient to scroll to the answers.
                    physics: const NeverScrollableScrollPhysics(),
                    child: _round.stimulus,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _answers(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answers() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final GameChoice choice in _round.choices)
          GameTile(
            width: choice.width,
            height: choice.height,
            onTap: () => _answer(choice.id),
            child: choice.content,
          ),
      ],
    );
  }
}

/// Celebration screen: stars, a family photo (when available), and a warm line.
class _RewardView extends StatelessWidget {
  const _RewardView({required this.correct, required this.total});

  final int correct;
  final int total;

  int get _stars {
    if (total == 0) return 1;
    final double ratio = correct / total;
    if (ratio >= 0.9) return 3;
    if (ratio >= 0.5) return 2;
    return 1;
  }

  String get _message {
    switch (_stars) {
      case 3:
        return 'Wonderful! You did it.';
      case 2:
        return 'Great effort. Well done!';
      default:
        return 'Good try. You finished the game!';
    }
  }

  MediaItem? _familyPhoto() {
    for (final MediaItem m in <MediaItem>[
      ...LocalDb.mediaByType('familyFace'),
      ...LocalDb.mediaByType('photo'),
    ]) {
      if (m.url.startsWith('http')) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final MediaItem? photo = _familyPhoto();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < _stars
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 72,
                        color: AppColors.reward,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              _photo(photo),
              const SizedBox(height: 28),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: AppText.gameQuestion(),
              ),
              const SizedBox(height: 8),
              Text(
                'You got $correct out of $total.',
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              BigButton(
                label: 'Done',
                icon: Icons.check_rounded,
                color: AppColors.success,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo(MediaItem? photo) {
    const double d = 160;
    if (photo != null) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.network(
            photo.url,
            width: d,
            height: d,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _photoPlaceholder(d),
          ),
        ),
      );
    }
    return Center(child: _photoPlaceholder(d));
  }

  Widget _photoPlaceholder(double d) {
    return Container(
      width: d,
      height: d,
      decoration: const BoxDecoration(
        color: AppColors.secondarySoft,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.favorite_rounded,
          size: 72, color: AppColors.secondary),
    );
  }
}
