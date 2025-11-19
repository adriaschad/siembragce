import 'package:hive/hive.dart';

part 'distancia_planta.g.dart';

@HiveType(typeId: 7)
class DistanciaPlanta extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  double valor;

  DistanciaPlanta({required this.id, required this.valor});
}
