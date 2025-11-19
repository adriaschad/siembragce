// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'valvula.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ValvulaAdapter extends TypeAdapter<Valvula> {
  @override
  final int typeId = 3;

  @override
  Valvula read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Valvula(
      id: fields[0] as int,
      nombre: fields[1] as String,
      loteId: fields[2] as int,
      area: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Valvula obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.loteId)
      ..writeByte(3)
      ..write(obj.area);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValvulaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
