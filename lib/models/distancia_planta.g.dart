// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'distancia_planta.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DistanciaPlantaAdapter extends TypeAdapter<DistanciaPlanta> {
  @override
  final int typeId = 7;

  @override
  DistanciaPlanta read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DistanciaPlanta(
      id: fields[0] as int,
      valor: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, DistanciaPlanta obj) {
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
      other is DistanciaPlantaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
