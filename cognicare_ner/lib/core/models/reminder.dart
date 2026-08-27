import 'package:hive/hive.dart';

part 'reminder.g.dart';

/// A scheduled reminder played in the caregiver's recorded voice.
@HiveType(typeId: 2)
class Reminder {
  Reminder({
    required this.id,
    required this.type,
    required this.title,
    required this.time,
    this.audioClipUrl,
    this.audioLocalPath,
    required this.repeatDaily,
  });

  @HiveField(0)
  final String id;

  /// 'medicine' | 'hydration' | 'meal' | 'appointment'
  @HiveField(1)
  final String type;

  @HiveField(2)
  final String title;

  /// Time of day, 'HH:mm' (24h).
  @HiveField(3)
  final String time;

  @HiveField(4)
  final String? audioClipUrl;

  /// On-device path of the recorded clip (plays offline).
  @HiveField(5)
  final String? audioLocalPath;

  @HiveField(6)
  final bool repeatDaily;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'title': title,
        'time': time,
        'audioClipUrl': audioClipUrl,
        'audioLocalPath': audioLocalPath,
        'repeatDaily': repeatDaily,
      };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
        id: (map['id'] as String?) ?? '',
        type: (map['type'] as String?) ?? 'medicine',
        title: (map['title'] as String?) ?? '',
        time: (map['time'] as String?) ?? '00:00',
        audioClipUrl: map['audioClipUrl'] as String?,
        audioLocalPath: map['audioLocalPath'] as String?,
        repeatDaily: (map['repeatDaily'] as bool?) ?? false,
      );
}
