import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/caregiver_note_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Displays the AI-generated weekly note (the 6th AI feature). Shows the cached
/// note immediately, generates one on first view, and offers a refresh. Works
/// offline via the deterministic fallback in [CaregiverNoteService].
class CareNoteCard extends StatefulWidget {
  const CareNoteCard({
    super.key,
    required this.patientId,
    this.clinical = false,
  });

  final String patientId;

  /// Clinician-toned variant for the doctor view.
  final bool clinical;

  @override
  State<CareNoteCard> createState() => _CareNoteCardState();
}

class _CareNoteCardState extends State<CareNoteCard> {
  CareNote? _note;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _note = CaregiverNoteService.instance
        .cached(widget.patientId, clinical: widget.clinical);
    if (_note == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
    }
  }

  Future<void> _generate() async {
    if (_loading) return;
    setState(() => _loading = true);
    final CareNote note = await CaregiverNoteService.instance
        .generate(widget.patientId, clinical: widget.clinical);
    if (!mounted) return;
    setState(() {
      _note = note;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.clinical ? AppColors.primaryDark : AppColors.secondary;
    final String title = widget.clinical ? 'AI clinical summary' : 'This week’s note';
    final bool ai = _note?.isAi ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.clinical ? Colors.white : AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, color: accent, size: 22),
              const SizedBox(width: 8),
              Text(title, style: AppText.title().copyWith(fontSize: 18)),
              const Spacer(),
              _badge(ai),
              IconButton(
                tooltip: 'Refresh note',
                visualDensity: VisualDensity.compact,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh_rounded, color: accent),
                onPressed: _loading ? null : _generate,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _note?.text ??
                (_loading ? 'Writing a summary…' : 'No note yet.'),
            style: AppText.body().copyWith(fontSize: 16, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _badge(bool ai) {
    final bool configured = AiService.instance.isConfigured;
    final String label = ai ? 'AI' : (configured ? 'summary' : 'offline');
    final Color c = ai ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
