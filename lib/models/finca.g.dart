// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finca.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FincaAdapter extends TypeAdapter<Finca> {
  @override
  final int typeId = 1;

  @override
  Finca read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Finca(
      id: fields[0] as int,
      nombre: fields[1] as String,
      productorId: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Finca obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.productorId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FincaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
