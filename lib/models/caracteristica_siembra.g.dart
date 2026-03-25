// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caracteristica_siembra.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CaracteristicaSiembraAdapter extends TypeAdapter<CaracteristicaSiembra> {
  @override
  final int typeId = 43;

  @override
  CaracteristicaSiembra read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CaracteristicaSiembra(
      id: fields[0] as int,
      nombre: fields[1] as String,
      tipo: fields[2] as String,
      ratioN: fields[3] as int?,
      activo: fields[4] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, CaracteristicaSiembra obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.tipo)
      ..writeByte(3)
      ..write(obj.ratioN)
      ..writeByte(4)
      ..write(obj.activo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaracteristicaSiembraAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
