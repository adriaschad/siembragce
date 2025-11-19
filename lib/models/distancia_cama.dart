import 'package:hive/hive.dart';

part 'distancia_cama.g.dart';

@HiveType(typeId: 6)
class DistanciaCama extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  double valor;

  DistanciaCama({required this.id, required this.valor});
}
