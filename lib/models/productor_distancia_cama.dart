import 'package:hive/hive.dart';

part 'productor_distancia_cama.g.dart';

@HiveType(typeId: 20) // Usa un typeId único por modelo Hive
class ProductorDistanciaCama extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  int productorId;

  @HiveField(2)
  int distanciaCamaId;

  ProductorDistanciaCama({
    required this.id,
    required this.productorId,
    required this.distanciaCamaId,
  });

  factory ProductorDistanciaCama.fromMap(Map<String, dynamic> map) {
    return ProductorDistanciaCama(
      id: map['id'] is String ? int.parse(map['id']) : map['id'],
      productorId: map['productor_id'] is String
          ? int.parse(map['productor_id'])
          : map['productor_id'],
      distanciaCamaId: map['distancia_cama_id'] is String
          ? int.parse(map['distancia_cama_id'])
          : map['distancia_cama_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productor_id': productorId,
      'distancia_cama_id': distanciaCamaId,
    };
  }
}
