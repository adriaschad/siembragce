// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boleta_resiembra.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BoletaResiembraAdapter extends TypeAdapter<BoletaResiembra> {
  @override
  final int typeId = 8;

  @override
  BoletaResiembra read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BoletaResiembra(
      id: fields[0] as int,
      productorId: fields[1] as int,
      fincaId: fields[2] as int,
      loteId: fields[3] as int,
      valvulaId: fields[4] as int,
      variedad: fields[5] as String,
      variedadId: fields[6] as int,
      fechaSiembra: fields[7] as DateTime,
      areaValvula: fields[8] as double,
      temporada: fields[9] as int,
      createdBy: fields[10] as int,
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      lotesSemilla: fields[13] as String,
      cantidadSemillas: fields[14] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BoletaResiembra obj) {
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
      ..write(obj.fechaSiembra)
      ..writeByte(8)
      ..write(obj.areaValvula)
      ..writeByte(9)
      ..write(obj.temporada)
      ..writeByte(10)
      ..write(obj.createdBy)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.lotesSemilla)
      ..writeByte(14)
      ..write(obj.cantidadSemillas);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoletaResiembraAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
