// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'productor_distancia_cama.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductorDistanciaCamaAdapter
    extends TypeAdapter<ProductorDistanciaCama> {
  @override
  final int typeId = 20;

  @override
  ProductorDistanciaCama read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductorDistanciaCama(
      id: fields[0] as int,
      productorId: fields[1] as int,
      distanciaCamaId: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ProductorDistanciaCama obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productorId)
      ..writeByte(2)
      ..write(obj.distanciaCamaId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductorDistanciaCamaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
