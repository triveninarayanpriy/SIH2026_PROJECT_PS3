import 'package:flutter/material.dart';

import '../../../core/models/media_item.dart';
import '../../../core/services/local_db.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/big_button.dart';

/// A family member assembled from labelled [MediaItem]s (grouped by label).
@immutable
class FamilyMember {
  const FamilyMember({
    required this.name,
    required this.hasFace,
    required this.hasVoice,
    this.photo,
    this.voice,
  });

  final String name;

  /// A labelled face media exists (photo/familyFace).
  final bool hasFace;

  /// A labelled voice media exists (familyVoice/voice).
  final bool hasVoice;

  /// Usable display source for the face (http url preferred), may be null.
  final String? photo;

  /// Usable audio source for the voice clip, may be null.
  final String? voice;
}

String? _usableSrc(MediaItem m) {
  if (m.url.isNotEmpty) return m.url;
  if (m.localPath != null && m.localPath!.isNotEmpty) return m.localPath;
  return null;
}

class _Acc {
  bool hasFace = false;
  bool hasVoice = false;
  String? photo;
  String? voice;
}

/// Builds the family roster from the local media store, grouped by label.
List<FamilyMember> collectFamily() {
  final Map<String, _Acc> byName = <String, _Acc>{};
  for (final MediaItem m in LocalDb.allMedia()) {
    final String? name = m.label;
    if (name == null || name.trim().isEmpty) continue;
    final _Acc acc = byName.putIfAbsent(name, _Acc.new);
    final String? src = _usableSrc(m);
    if (m.type == 'familyFace' || m.type == 'photo') {
      acc.hasFace = true;
      acc.photo ??= src;
    } else if (m.type == 'familyVoice' || m.type == 'voice' || m.type == 'music') {
      acc.hasVoice = true;
      acc.voice ??= src;
    }
  }
  return [
    for (final MapEntry<String, _Acc> e in byName.entries)
      FamilyMember(
        name: e.key,
        hasFace: e.value.hasFace,
        hasVoice: e.value.hasVoice,
        photo: e.value.photo,
        voice: e.value.voice,
      ),
  ];
}

/// A round family photo (network image when available, else a warm avatar).
class FamilyPhoto extends StatelessWidget {
  const FamilyPhoto({super.key, required this.src, required this.size, this.name});

  final String? src;
  final double size;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final String? s = src;
    if (s != null && (s.startsWith('http') || s.startsWith('assets/'))) {
      final ImageProvider provider =
          s.startsWith('http') ? NetworkImage(s) : AssetImage(s);
      return ClipOval(
        child: Image(
          image: provider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final String initial =
        (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.secondarySoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: initial.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.5, color: AppColors.secondary)
          : Text(
              initial,
              style: AppText.gameQuestion(color: AppColors.secondary)
                  .copyWith(fontSize: size * 0.4),
            ),
    );
  }
}

/// Friendly full-screen fallback when a game doesn't have enough family media.
class AddMoreCard extends StatelessWidget {
  const AddMoreCard({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.photo_library_rounded,
                  size: 96, color: AppColors.secondary),
              const SizedBox(height: 24),
              Text(message, textAlign: TextAlign.center, style: AppText.title()),
              const SizedBox(height: 32),
              BigButton(
                label: 'Go back',
                icon: Icons.arrow_back_rounded,
                color: AppColors.secondary,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
