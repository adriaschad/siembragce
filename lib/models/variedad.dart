import 'package:hive/hive.dart';

part 'variedad.g.dart';

@HiveType(typeId: 4)
class Variedad extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String nombre;

  // Nuevo campo: si esta variedad es polinizador (no contar su área en totales)
  @HiveField(2)
  bool esPolinizador;

  Variedad({
    required this.id,
    required this.nombre,
    this.esPolinizador = false,
  });
}
