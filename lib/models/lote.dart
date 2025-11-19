import 'package:hive/hive.dart';

part 'lote.g.dart';

@HiveType(typeId: 2)
class Lote extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String nombre;

  @HiveField(2)
  int fincaId;

  Lote({required this.id, required this.nombre, required this.fincaId});
}
