// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'distancia_cama.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DistanciaCamaAdapter extends TypeAdapter<DistanciaCama> {
  @override
  final int typeId = 6;

  @override
  DistanciaCama read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DistanciaCama(
      id: fields[0] as int,
      valor: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, DistanciaCama obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.valor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DistanciaCamaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
