import 'package:hive/hive.dart';

part 'variedad.g.dart';

@HiveType(typeId: 4)
class Variedad extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String nombre;

  Variedad({required this.id, required this.nombre});
}
