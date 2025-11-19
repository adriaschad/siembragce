import 'package:hive/hive.dart';

part 'productor.g.dart';

@HiveType(typeId: 0)
class Productor extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String nombre;

  Productor({required this.id, required this.nombre});
}
