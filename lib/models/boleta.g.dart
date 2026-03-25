// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boleta.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BoletaAdapter extends TypeAdapter<Boleta> {
  @override
  final int typeId = 40;

  @override
  Boleta read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Boleta(
      id: fields[0] as int,
      productorId: fields[1] as int,
      fincaId: fields[2] as int,
      loteId: fields[3] as int,
      valvulaId: fields[4] as int,
      distanciaCama: fields[5] as double,
      distanciaPlanta: fields[6] as double,
      variedad: fields[7] as String,
      areaReal: fields[8] as double,
      fechaSiembra: fields[9] as DateTime?,
      createdBy: fields[10] as int,
      variedadId: fields[11] as int?,
      createdAt: fields[12] as DateTime?,
      updatedAt: fields[13] as DateTime?,
      lotesSemilla: fields[14] as String?,
      cicloPromedio: fields[15] as int?,
      notif32Enviada: fields[16] as bool?,
      notif50Enviada: fields[17] as bool?,
      clientUuid: fields[18] as String?,
      caracteristicaId: fields[19] as int?,
      caracteristicaNombre: fields[20] as String?,
      caracteristicaTipo: fields[21] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Boleta obj) {
    writer
      ..writeByte(22)
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
      ..write(obj.distanciaCama)
      ..writeByte(6)
      ..write(obj.distanciaPlanta)
      ..writeByte(7)
      ..write(obj.variedad)
      ..writeByte(8)
      ..write(obj.areaReal)
      ..writeByte(9)
      ..write(obj.fechaSiembra)
      ..writeByte(10)
      ..write(obj.createdBy)
      ..writeByte(11)
      ..write(obj.variedadId)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.lotesSemilla)
      ..writeByte(15)
      ..write(obj.cicloPromedio)
      ..writeByte(16)
      ..write(obj.notif32Enviada)
      ..writeByte(17)
      ..write(obj.notif50Enviada)
      ..writeByte(18)
      ..write(obj.clientUuid)
      ..writeByte(19)
      ..write(obj.caracteristicaId)
      ..writeByte(20)
      ..write(obj.caracteristicaNombre)
      ..writeByte(21)
      ..write(obj.caracteristicaTipo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoletaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
