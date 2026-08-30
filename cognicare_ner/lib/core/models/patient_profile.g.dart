// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patient_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PatientProfileAdapter extends TypeAdapter<PatientProfile> {
  @override
  final int typeId = 0;

  @override
  PatientProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PatientProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      age: fields[2] as int,
      stage: fields[3] as int,
      languages: (fields[4] as List).cast<String>(),
      region: fields[5] as String,
      createdAt: fields[6] as DateTime,
      clinicalNotes: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PatientProfile obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.age)
      ..writeByte(3)
      ..write(obj.stage)
      ..writeByte(4)
      ..write(obj.languages)
      ..writeByte(5)
      ..write(obj.region)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.clinicalNotes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
