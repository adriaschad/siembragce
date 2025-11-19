import 'package:hive/hive.dart';

part 'valvula.g.dart';

@HiveType(typeId: 3)
class Valvula extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String nombre;

  @HiveField(2)
  int loteId;

  @HiveField(3)
  double area;

  Valvula({
    required this.id,
    required this.nombre,
    required this.loteId,
    required this.area,
  });
}
