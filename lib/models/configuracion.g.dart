// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'configuracion.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConfiguracionAdapter extends TypeAdapter<Configuracion> {
  @override
  final int typeId = 0;

  @override
  Configuracion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Configuracion(
      id: fields[0] as int,
      empresa: fields[1] as String,
      temporada: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Configuracion obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.empresa)
      ..writeByte(2)
      ..write(obj.temporada);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfiguracionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
