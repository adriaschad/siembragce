// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'productor_distancia_planta.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductorDistanciaPlantaAdapter
    extends TypeAdapter<ProductorDistanciaPlanta> {
  @override
  final int typeId = 21;

  @override
  ProductorDistanciaPlanta read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductorDistanciaPlanta(
      id: fields[0] as int,
      productorId: fields[1] as int,
      distanciaPlantaId: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ProductorDistanciaPlanta obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productorId)
      ..writeByte(2)
      ..write(obj.distanciaPlantaId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductorDistanciaPlantaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
