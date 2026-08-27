import 'package:hive/hive.dart';

part 'media_item.g.dart';

/// A media asset attached to a patient: a family photo, a music track, or a
/// family face used in recognition games.
@HiveType(typeId: 1)
class MediaItem {
  MediaItem({
    required this.id,
    required this.type,
    required this.url,
    this.localPath,
    this.label,
  });

  @HiveField(0)
  final String id;

  /// 'photo' | 'music' | 'familyFace'
  @HiveField(1)
  final String type;

  @HiveField(2)
  final String url;

  /// On-device cached path (offline-first); null until downloaded/recorded.
  @HiveField(3)
  final String? localPath;

  /// For 'familyFace', the person's name.
  @HiveField(4)
  final String? label;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'url': url,
        'localPath': localPath,
        'label': label,
      };

  factory MediaItem.fromMap(Map<String, dynamic> map) => MediaItem(
        id: (map['id'] as String?) ?? '',
        type: (map['type'] as String?) ?? 'photo',
        url: (map['url'] as String?) ?? '',
        localPath: map['localPath'] as String?,
        label: map['label'] as String?,
      );
}
