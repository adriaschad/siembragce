import 'package:hive/hive.dart';

part 'finca.g.dart';

@HiveType(typeId: 1)
class Finca extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String nombre;

  @HiveField(2)
  int productorId;

  Finca({required this.id, required this.nombre, required this.productorId});
}
