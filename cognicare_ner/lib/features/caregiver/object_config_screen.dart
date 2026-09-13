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

/// Caregiver editor for Game 4 (Object Identification): curate familiar /
/// culturally-relevant objects, each a photo + name.
class ObjectConfigScreen extends StatelessWidget {
  const ObjectConfigScreen({super.key});

  Future<void> _addOrEdit(BuildContext context, {CulturalObject? existing}) async {
    final picker = ImagePicker();
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    String? imagePath = existing?.imagePath;
    String imageUrl = existing?.imageUrl ?? '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add object' : 'Edit object',
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
                    width: 160,
                    height: 160,
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
                            size: 48, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtl,
                  style: AppText.body(),
                  decoration: const InputDecoration(
                    labelText: 'Name of the object',
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
                if (nameCtl.text.trim().isEmpty) return;
                await GameContent.saveObject(CulturalObject(
                  id: existing?.id ?? const Uuid().v4(),
                  name: nameCtl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objects to identify')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add object'),
      ),
      body: ValueListenableBuilder<Box<dynamic>>(
        valueListenable:
            LocalDb.appStateBox.listenable(keys: <String>[GameContentKeys.objects]),
        builder: (context, _, __) {
          final List<CulturalObject> items = GameContent.objects();
          if (items.isEmpty) {
            return _empty();
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final CulturalObject o = items[i];
              return BigCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MediaImage(src: o.imageSrc, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(o.name,
                        textAlign: TextAlign.center,
                        style: AppText.title().copyWith(fontSize: 20)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.primary),
                          onPressed: () => _addOrEdit(context, existing: o),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => GameContent.deleteObject(o.id),
                        ),
                      ],
                    ),
                  ],
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
              const Icon(Icons.category_rounded, size: 80, color: AppColors.secondary),
              const SizedBox(height: 16),
              Text('No objects yet',
                  style: AppText.title(), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Add familiar things — a betel-nut box, a gamosa, a favourite cup — '
                'with their names. The patient picks the right name from the photo.',
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
}
