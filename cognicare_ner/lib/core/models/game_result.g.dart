// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameResultAdapter extends TypeAdapter<GameResult> {
  @override
  final int typeId = 3;

  @override
  GameResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameResult(
      id: fields[0] as String,
      patientId: fields[1] as String,
      game: fields[2] as String,
      domain: fields[3] as String,
      correct: fields[4] as int,
      total: fields[5] as int,
      durationMs: fields[6] as int,
      difficulty: fields[7] as int,
      at: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, GameResult obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.game)
      ..writeByte(3)
      ..write(obj.domain)
      ..writeByte(4)
      ..write(obj.correct)
      ..writeByte(5)
      ..write(obj.total)
      ..writeByte(6)
      ..write(obj.durationMs)
      ..writeByte(7)
      ..write(obj.difficulty)
      ..writeByte(8)
      ..write(obj.at);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
