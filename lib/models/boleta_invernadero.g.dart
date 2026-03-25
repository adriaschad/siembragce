// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boleta_invernadero.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BoletaInvernaderoAdapter extends TypeAdapter<BoletaInvernadero> {
  @override
  final int typeId = 41;

  @override
  BoletaInvernadero read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BoletaInvernadero(
      id: fields[0] as int,
      productorId: fields[1] as int,
      fincaId: fields[2] as int,
      loteId: fields[3] as int,
      valvulaId: fields[4] as int,
      variedad: fields[5] as String,
      variedadId: fields[6] as int?,
      cantidadBandejas: fields[7] as int,
      fechaSiembra: fields[8] as DateTime,
      fechaTransplante: fields[9] as DateTime?,
      lotesSemilla: fields[10] as String?,
      area: fields[11] as double,
      createdBy: fields[12] as int,
      createdAt: fields[13] as DateTime?,
      updatedAt: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BoletaInvernadero obj) {
    writer
      ..writeByte(15)
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
      ..write(obj.variedadId)
      ..writeByte(7)
      ..write(obj.cantidadBandejas)
      ..writeByte(8)
      ..write(obj.fechaSiembra)
      ..writeByte(9)
      ..write(obj.fechaTransplante)
      ..writeByte(10)
      ..write(obj.lotesSemilla)
      ..writeByte(11)
      ..write(obj.area)
      ..writeByte(12)
      ..write(obj.createdBy)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoletaInvernaderoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
