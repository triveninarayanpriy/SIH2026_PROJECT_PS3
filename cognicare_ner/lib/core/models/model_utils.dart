/// Shared, null-safe parsing helpers for model `fromMap` factories.
///
/// DateTimes are serialized to Firestore/Hive as ISO-8601 strings by every
/// `toMap()`, and parsed back defensively here (also tolerating int epoch
/// millis or a raw DateTime) so a malformed field never throws.
library;

DateTime parseDate(Object? value) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

List<String> stringList(Object? value) =>
    value is List ? value.map((e) => e.toString()).toList() : <String>[];
