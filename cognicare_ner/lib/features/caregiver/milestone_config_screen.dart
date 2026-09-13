import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/game_content.dart';
import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_card.dart';
import '../../core/widgets/platform_media.dart';

/// Caregiver editor for Game 2 (Milestone & Life Events Recall). Each memory
/// carries a photo, a short story, a question, the true answer, gentle
/// distractors, and optionally a recorded/uploaded story clip (else TTS reads it).
class MilestoneConfigScreen extends StatelessWidget {
  const MilestoneConfigScreen({super.key});

  Future<void> _addOrEdit(BuildContext context, {Milestone? existing}) async {
    final picker = ImagePicker();
    final titleCtl = TextEditingController(text: existing?.title ?? '');
    final storyCtl = TextEditingController(text: existing?.story ?? '');
    final questionCtl = TextEditingController(text: existing?.question ?? '');
    final answerCtl = TextEditingController(text: existing?.answer ?? '');
    final distractorsCtl =
        TextEditingController(text: (existing?.distractors ?? <String>[]).join(', '));
    String? imagePath = existing?.imagePath;
    String imageUrl = existing?.imageUrl ?? '';
    String? audioPath = existing?.audioPath;
    String audioUrl = existing?.audioUrl ?? '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add memory' : 'Edit memory',
              style: AppText.title()),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final XFile? img =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (img != null) {
                          setLocal(() {
                            imagePath = img.path;
                            imageUrl = '';
                          });
                        }
                      },
                      child: Container(
                        width: 180,
                        height: 130,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (imagePath?.isNotEmpty ?? false) || imageUrl.isNotEmpty
                            ? MediaImage(
                                src: (imagePath?.isNotEmpty ?? false) ? imagePath : imageUrl,
                                fit: BoxFit.cover)
                            : const Icon(Icons.add_a_photo_rounded,
                                size: 44, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(titleCtl, 'Title (e.g. Wedding day, 1971)'),
                  _field(storyCtl, 'Story to tell', maxLines: 3),
                  _field(questionCtl, 'Question (e.g. Who is beside you?)'),
                  _field(answerCtl, 'Correct answer'),
                  _field(distractorsCtl, 'Other options (comma separated)'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: Icon(
                        (audioPath?.isNotEmpty ?? false) || audioUrl.isNotEmpty
                            ? Icons.check_circle
                            : Icons.audiotrack_rounded),
                    label: Text(
                      (audioPath?.isNotEmpty ?? false) || audioUrl.isNotEmpty
                          ? 'Story audio added'
                          : 'Add story audio (optional)',
                      style: AppText.body(),
                    ),
                    onPressed: () async {
                      final FilePickerResult? res = await FilePicker.platform
                          .pickFiles(type: FileType.audio);
                      final String? p = res?.files.single.path;
                      if (p != null) {
                        setLocal(() {
                          audioPath = p;
                          audioUrl = '';
                        });
                      }
                    },
                  ),
                  Text('If no audio is added, the app reads the story aloud.',
                      style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 12)),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppText.body()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (answerCtl.text.trim().isEmpty || questionCtl.text.trim().isEmpty) {
                  return;
                }
                final List<String> distractors = distractorsCtl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                await GameContent.saveMilestone(Milestone(
                  id: existing?.id ?? const Uuid().v4(),
                  title: titleCtl.text.trim(),
                  story: storyCtl.text.trim(),
                  question: questionCtl.text.trim(),
                  answer: answerCtl.text.trim(),
                  distractors: distractors,
                  imagePath: imagePath,
                  imageUrl: imageUrl,
                  audioPath: audioPath,
                  audioUrl: audioUrl,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('Save', style: AppText.body().copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          style: AppText.body(),
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memories to recall')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add memory'),
      ),
      body: ValueListenableBuilder<Box<dynamic>>(
        valueListenable:
            LocalDb.appStateBox.listenable(keys: <String>[GameContentKeys.milestones]),
        builder: (context, _, __) {
          final List<Milestone> items = GameContent.milestones();
          if (items.isEmpty) return _empty();
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final Milestone m = items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BigCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: MediaImage(
                            src: m.imageSrc, width: 64, height: 64, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(m.title.isEmpty ? m.question : m.title,
                                style: AppText.title().copyWith(fontSize: 18)),
                            const SizedBox(height: 4),
                            Text('Answer: ${m.answer}',
                                style: AppText.body(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () => _addOrEdit(context, existing: m),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => GameContent.deleteMilestone(m.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.auto_stories_rounded, size: 80, color: AppColors.secondary),
              const SizedBox(height: 16),
              Text('No memories yet', style: AppText.title(), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Add special life events — a wedding, a first grandchild, a festival — '
                'with a photo and a question. The app tells the story and asks about it.',
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
}
