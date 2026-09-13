import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ai/anomaly_detector.dart';
import '../../../core/models/alert.dart';
import '../../../core/models/game_result.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/local_db.dart';
import '../../../core/services/nawal_remote.dart';
import '../../../core/services/stt_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/big_progress_dots.dart';
import '../../../core/widgets/gentle_feedback.dart';
import '../../../core/widgets/remote_status_chip.dart';
import '../../../core/widgets/speak_label.dart';
import '../../../l10n/app_localizations.dart';
import '../calm_mode.dart';
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
  final AudioPlayer _chime = AudioPlayer();

  // Frustration protocol: 3 wrong in a row, or this much idle time, gently
  // switches to Calm mode.
  static const Duration _idleTimeout = Duration(seconds: 30);

  int _index = 0;
  int _correct = 0;
  int _wrongStreak = 0;
  bool _roundScored = false; // first attempt on this round has been counted
  bool _locked = false; // ignore taps while feedback / advance runs
  bool _finished = false;
  bool _leaving = false; // switching to Calm mode
  bool _listening = false; // optional voice-answer state
  bool _speaking = false; // prompt / feedback audio is playing
  Timer? _idleTimer;
  Timer? _listenTimer;
  StreamSubscription<RemoteButton>? _remoteSub;
  late final DateTime _start;

  int get _total => widget.rounds.length;
  GameRound get _round => widget.rounds[_index];

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    // The NAWAL BLE remote drives the same game (Android only; silent on web).
    _remoteSub = NawalRemote.instance.buttons.listen(_onRemote);
    // Present the first round once the first frame is up (needs context for
    // localized prompts).
    WidgetsBinding.instance.addPostFrameCallback((_) => _presentRound());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _listenTimer?.cancel();
    _remoteSub?.cancel();
    _chime.dispose();
    super.dispose();
  }

  /// Route a NAWAL remote press to the same actions a tap would trigger.
  ///
  ///  - 1-9   select the option at that position (if it exists)
  ///  - back  / sound  replay the spoken prompt (and family voice if mapped)
  ///  - hint  gentle nudge + replay
  ///  - call  fire a caregiver SOS alert
  /// next / pageUp / pageDown are handled by paged/menu screens, not here.
  void _onRemote(RemoteButton b) {
    if (!mounted || _finished || _leaving) return;
    final int? optionIndex = remoteButtonOptionIndex(b);
    if (optionIndex != null) {
      if (!_locked && optionIndex < _round.choices.length) {
        _answer(_round.choices[optionIndex].id);
      }
      return;
    }
    switch (b) {
      case RemoteButton.back:
      case RemoteButton.sound:
        _repeatPrompt();
        break;
      case RemoteButton.hint:
        _hint('Take your time — listen again, then pick the matching answer.');
        _repeatPrompt();
        break;
      case RemoteButton.call:
        _fireSos();
        break;
      default:
        break;
    }
  }

  /// Patient-triggered "I need help" — records a caregiver SOS alert.
  Future<void> _fireSos() async {
    try {
      await SyncService.instance.saveAlert(
        Alert(
          id: _uuid.v4(),
          patientId: widget.patientId,
          type: 'sos',
          domain: '',
          deltaPct: 0,
          at: DateTime.now(),
          seen: false,
        ),
      );
      if (mounted) _hint('We let your caregiver know you need help. 💛');
    } catch (_) {}
  }

  Future<void> _playChime(String asset) async {
    try {
      await _chime.setAsset(asset);
      await _chime.seek(Duration.zero);
      await _chime.play();
    } catch (_) {
      // Chime asset missing/unsupported — ignore.
    }
  }

  /// Restart the idle countdown after any interaction / new round.
  void _resetIdle() {
    _idleTimer?.cancel();
    if (_finished || _leaving) return;
    _idleTimer = Timer(_idleTimeout, _toCalm);
  }

  /// Gently leave the game for Calm mode (frustration protocol).
  void _toCalm() {
    if (!mounted || _finished || _leaving) return;
    _leaving = true;
    _idleTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const CalmModeScreen()),
    );
  }

  /// The game prompt in the active language.
  String _localizedPrompt(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    switch (widget.game) {
      case 'pattern':
        return t.whatComesNext;
      case 'faces':
        return t.whoIsThis;
      case 'voice':
        return t.whoseVoiceIsThis;
      default:
        return _round.prompt;
    }
  }

  /// Present the current round: speak the prompt FULLY, then open one voice
  /// listen window. Strictly sequential so the prompt and feedback audio never
  /// overlap with the microphone (which was the source of the demo glitches).
  Future<void> _presentRound() async {
    if (!mounted || _finished || _leaving) return;
    _resetIdle();
    // Make sure the mic is off before we speak.
    _listenTimer?.cancel();
    if (_listening) {
      await SttService.instance.stop();
      if (mounted) setState(() => _listening = false);
    }
    _locked = false;
    if (mounted) setState(() => _speaking = true);
    final String prompt = _localizedPrompt(context);
    await TtsService.instance.play(prompt, audioPath: _round.promptAudioPath);
    if (!mounted || _finished || _leaving) return;
    setState(() => _speaking = false);
    // After the prompt finishes, offer one hands-free listen window. Tapping is
    // always available regardless.
    _startListenWindow();
  }

  /// Replays the current prompt fully (Sound / Back on the remote, or tap).
  Future<void> _repeatPrompt() async {
    if (!mounted || _finished || _leaving || _locked) return;
    await _presentRound();
  }

  /// One bounded voice-listen window (no infinite re-listen loop). On silence it
  /// simply stops; the patient can tap an answer or tap the mic to try again.
  Future<void> _startListenWindow() async {
    if (_locked || _leaving || _finished || _speaking) return;
    final bool ok = await SttService.instance.ensureInit();
    if (!mounted) return;
    if (!ok) return; // voice unavailable here — tapping still works.
    setState(() => _listening = true);
    _listenTimer?.cancel();
    _listenTimer = Timer(const Duration(seconds: 6), () async {
      if (!mounted || !_listening) return;
      await SttService.instance.stop();
      if (mounted) setState(() => _listening = false);
    });
    await SttService.instance.listen(
      listenFor: const Duration(seconds: 6),
      onResult: (String text) {
        _listenTimer?.cancel();
        if (!mounted || _locked || _leaving) return;
        setState(() => _listening = false);
        _matchSpoken(text);
      },
    );
  }

  Future<void> _answer(String choiceId) async {
    if (_locked || _leaving) return;
    _locked = true; // lock immediately: no double-taps while feedback plays
    _resetIdle();
    final AppLocalizations t = AppLocalizations.of(context);
    final bool isCorrect = choiceId == _round.answerId;

    // Score only the first attempt of each round.
    if (!_roundScored) {
      _roundScored = true;
      if (isCorrect) _correct++;
    }

    // Stop listening + any in-progress prompt so feedback audio plays clean.
    _listenTimer?.cancel();
    if (mounted) setState(() => _listening = false);
    await SttService.instance.stop();
    await TtsService.instance.stop();
    if (mounted) setState(() => _speaking = false);

    if (isCorrect) {
      _wrongStreak = 0;
      await _playChime('assets/sounds/correct.wav');
      if (!mounted) return;
      GentleFeedback.correct(context);
      // Play the praise FULLY before moving on — this matters in demos.
      await TtsService.instance.play(
        t.veryGood,
        audioPath: LocalDb.mediaByType('game_prompt_correct').firstOrNull?.localPath,
      );
      if (!mounted || _leaving) return;
      _advance();
    } else {
      _wrongStreak++;
      await _playChime('assets/sounds/tryagain.wav');
      if (!mounted) return;
      GentleFeedback.tryAgain(context);
      await TtsService.instance.play(
        t.letsTryAgain,
        audioPath: LocalDb.mediaByType('game_prompt_wrong').firstOrNull?.localPath,
      );
      if (!mounted || _leaving) return;
      if (_wrongStreak >= 3) {
        _toCalm();
      } else {
        // Re-present the same round (replays the prompt fully, then listens).
        _presentRound();
      }
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
    _presentRound();
  }

  Future<void> _finish() async {
    _idleTimer?.cancel();
    _listenTimer?.cancel();
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
    // Guarded so a save/detector hiccup never blocks the reward screen.
    try {
      await SyncService.instance.saveGameResult(result);
      // Check each domain for a cognitive drop (caregiver/doctor only — the
      // patient is never alarmed). Runs on the just-updated local history.
      await AnomalyDetector.instance.runForPatient(widget.patientId);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return _RewardView(correct: _correct, total: _total);
    }
    final String prompt = _localizedPrompt(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: const <Widget>[
          Center(child: RemoteStatusChip(compact: true)),
          SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            children: [
              BigProgressDots(total: _total, current: _index),
              const SizedBox(height: 20),
              SpeakLabel(
                text: prompt,
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
              const SizedBox(height: 12),
              _micButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Optional voice answer. Tapping is always the guaranteed path; this only
  /// adds a hands-free shortcut. Disabled while the prompt/feedback is speaking.
  Widget _micButton() {
    final bool busy = _speaking || _locked;
    final String label = _speaking
        ? 'Listen…'
        : (_listening ? 'Listening…' : 'Answer by voice');
    return BigButton(
      label: label,
      icon: _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
      color: _listening ? AppColors.primary : AppColors.secondarySoft,
      onTap: busy ? null : _startListenWindow,
    );
  }

  /// Match a spoken phrase to a choice label. On no match, gently invite a
  /// retry (no auto-loop — the patient taps an answer or the mic to try again).
  void _matchSpoken(String spoken) {
    final String s = spoken.trim().toLowerCase();
    if (s.isNotEmpty) {
      for (final GameChoice c in _round.choices) {
        final String? label = c.label?.trim().toLowerCase();
        if (label == null || label.isEmpty) continue;
        if (s == label || s.contains(label) || label.contains(s)) {
          _answer(c.id);
          return;
        }
      }
    }
    if (mounted && !_leaving && !_locked) {
      _hint("I didn't catch that — tap an answer, or tap the mic to try again.");
    }
  }

  void _hint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
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



