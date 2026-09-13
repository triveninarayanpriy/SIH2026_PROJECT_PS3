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

/// Caregiver editor for Game 3 (Daily Routine Sequencing): an ordered list of
/// routine steps, each a label + optional photo. Order defines the answer.
class RoutineConfigScreen extends StatelessWidget {
  const RoutineConfigScreen({super.key});

  Future<void> _addOrEdit(BuildContext context, {RoutineStep? existing}) async {
    final picker = ImagePicker();
    final labelCtl = TextEditingController(text: existing?.label ?? '');
    String? imagePath = existing?.imagePath;
    String imageUrl = existing?.imageUrl ?? '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add step' : 'Edit step',
              style: AppText.title()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GestureDetector(
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
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.secondarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (imagePath?.isNotEmpty ?? false) || imageUrl.isNotEmpty
                        ? MediaImage(
                            src: (imagePath?.isNotEmpty ?? false) ? imagePath : imageUrl,
                            fit: BoxFit.cover)
                        : const Icon(Icons.add_a_photo_rounded,
                            size: 40, color: AppColors.secondary),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Photo is optional', style: AppText.body(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                TextField(
                  controller: labelCtl,
                  style: AppText.body(),
                  decoration: const InputDecoration(
                    labelText: 'Step (e.g. Drink tea)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppText.body()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (labelCtl.text.trim().isEmpty) return;
                final List<RoutineStep> all = GameContent.routine();
                final int order = existing?.order ??
                    (all.isEmpty ? 0 : all.last.order + 1);
                await GameContent.saveRoutineStep(RoutineStep(
                  id: existing?.id ?? const Uuid().v4(),
                  label: labelCtl.text.trim(),
                  order: order,
                  imagePath: imagePath,
                  imageUrl: imageUrl,
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

  Future<void> _swap(List<RoutineStep> steps, int a, int b) async {
    if (a < 0 || b < 0 || a >= steps.length || b >= steps.length) return;
    final int oa = steps[a].order;
    final RoutineStep sa = steps[a];
    final RoutineStep sb = steps[b];
    await GameContent.saveRoutineStep(RoutineStep(
      id: sa.id, label: sa.label, order: sb.order,
      imagePath: sa.imagePath, imageUrl: sa.imageUrl,
    ));
    await GameContent.saveRoutineStep(RoutineStep(
      id: sb.id, label: sb.label, order: oa,
      imagePath: sb.imagePath, imageUrl: sb.imageUrl,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily routine')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add step'),
      ),
      body: ValueListenableBuilder<Box<dynamic>>(
        valueListenable:
            LocalDb.appStateBox.listenable(keys: <String>[GameContentKeys.routine]),
        builder: (context, _, __) {
          final List<RoutineStep> steps = GameContent.routine();
          if (steps.isEmpty) {
            return _empty();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            itemCount: steps.length,
            itemBuilder: (context, i) {
              final RoutineStep s = steps[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BigCard(
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text('${i + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      if (s.imageSrc.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: MediaImage(
                              src: s.imageSrc, width: 48, height: 48, fit: BoxFit.cover),
                        )
                      else
                        const Icon(Icons.schedule_rounded, color: AppColors.secondary, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.label, style: AppText.title().copyWith(fontSize: 20)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: i == 0 ? null : () => _swap(steps, i, i - 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward),
                        onPressed:
                            i == steps.length - 1 ? null : () => _swap(steps, i, i + 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () => _addOrEdit(context, existing: s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => GameContent.deleteRoutineStep(s.id),
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
              const Icon(Icons.checklist_rounded, size: 80, color: AppColors.primary),
              const SizedBox(height: 16),
              Text('No routine yet', style: AppText.title(), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Add the daily routine in order — wake up, tea, medicine, walk… '
                'The patient practises putting them in the right sequence.',
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
}
