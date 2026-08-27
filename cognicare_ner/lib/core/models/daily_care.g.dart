// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_care.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyCareAdapter extends TypeAdapter<DailyCare> {
  @override
  final int typeId = 4;

  @override
  DailyCare read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyCare(
      date: fields[0] as String,
      medsTaken: (fields[1] as List).cast<String>(),
      hydrationCount: fields[2] as int,
      mealsLogged: (fields[3] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DailyCare obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.medsTaken)
      ..writeByte(2)
      ..write(obj.hydrationCount)
      ..writeByte(3)
      ..write(obj.mealsLogged);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyCareAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
