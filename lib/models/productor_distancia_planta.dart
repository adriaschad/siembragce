import 'package:hive/hive.dart';

part 'productor_distancia_planta.g.dart';

@HiveType(typeId: 21) // Usa otro typeId único
class ProductorDistanciaPlanta extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  int productorId;

  @HiveField(2)
  int distanciaPlantaId;

  ProductorDistanciaPlanta({
    required this.id,
    required this.productorId,
    required this.distanciaPlantaId,
  });

  factory ProductorDistanciaPlanta.fromMap(Map<String, dynamic> map) {
    return ProductorDistanciaPlanta(
      id: map['id'] is String ? int.parse(map['id']) : map['id'],
      productorId: map['productor_id'] is String
          ? int.parse(map['productor_id'])
          : map['productor_id'],
      distanciaPlantaId: map['distancia_planta_id'] is String
          ? int.parse(map['distancia_planta_id'])
          : map['distancia_planta_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productor_id': productorId,
      'distancia_planta_id': distanciaPlantaId,
    };
  }
}
