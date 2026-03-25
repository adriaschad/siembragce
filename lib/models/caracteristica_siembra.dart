import 'package:hive/hive.dart';

part 'caracteristica_siembra.g.dart';

@HiveType(typeId: 43) //
class CaracteristicaSiembra extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String nombre;

  /// 'PATRON_SEMILLAS' o 'POLINIZADOR_RATIO'
  @HiveField(2)
  String tipo;

  /// Para POLINIZADOR_RATIO: valor de N en el ratio (ej. 3 para 3:1)
  @HiveField(3)
  int? ratioN;

  /// Puedes guardar si está activa (si lo necesitas offline)
  @HiveField(4)
  bool? activo;

  CaracteristicaSiembra({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.ratioN,
    this.activo,
  });
}
