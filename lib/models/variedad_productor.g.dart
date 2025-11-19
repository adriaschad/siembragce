// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variedad_productor.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VariedadProductorAdapter extends TypeAdapter<VariedadProductor> {
  @override
  final int typeId = 5;

  @override
  VariedadProductor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VariedadProductor(
      id: fields[0] as int,
      productorId: fields[1] as int,
      variedadId: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, VariedadProductor obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productorId)
      ..writeByte(2)
      ..write(obj.variedadId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariedadProductorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
