// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlertAdapter extends TypeAdapter<Alert> {
  @override
  final int typeId = 5;

  @override
  Alert read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Alert(
      id: fields[0] as String,
      patientId: fields[1] as String,
      type: fields[2] as String,
      domain: fields[3] as String,
      deltaPct: fields[4] as double,
      at: fields[5] as DateTime,
      seen: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Alert obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.domain)
      ..writeByte(4)
      ..write(obj.deltaPct)
      ..writeByte(5)
      ..write(obj.at)
      ..writeByte(6)
      ..write(obj.seen);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
