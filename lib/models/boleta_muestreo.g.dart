// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boleta_muestreo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BoletaMuestreoAdapter extends TypeAdapter<BoletaMuestreo> {
  @override
  final int typeId = 42;

  @override
  BoletaMuestreo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BoletaMuestreo(
      id: fields[0] as String,
      productorId: fields[1] as int?,
      fincaId: fields[2] as int?,
      loteId: fields[3] as int?,
      valvulaId: fields[4] as int?,
      variedad: fields[5] as String?,
      observacion: fields[6] as String?,
      fecha: fields[7] as DateTime?,
      brixLecturas: (fields[8] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      fotos: (fields[9] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      createdBy: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BoletaMuestreo obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productorId)
      ..writeByte(2)
      ..write(obj.fincaId)
      ..writeByte(3)
      ..write(obj.loteId)
      ..writeByte(4)
      ..write(obj.valvulaId)
      ..writeByte(5)
      ..write(obj.variedad)
      ..writeByte(6)
      ..write(obj.observacion)
      ..writeByte(7)
      ..write(obj.fecha)
      ..writeByte(8)
      ..write(obj.brixLecturas)
      ..writeByte(9)
      ..write(obj.fotos)
      ..writeByte(10)
      ..write(obj.createdBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoletaMuestreoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
