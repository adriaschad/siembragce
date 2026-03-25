import 'package:hive/hive.dart';

part 'boleta_resiembra.g.dart';

@HiveType(typeId: 8) // usa un typeId libre distinto al de Boleta
class BoletaResiembra extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  int productorId;

  @HiveField(2)
  int fincaId;

  @HiveField(3)
  int loteId;

  @HiveField(4)
  int valvulaId;

  @HiveField(5)
  String variedad;

  @HiveField(6)
  int variedadId;

  @HiveField(7)
  DateTime fechaSiembra;

  /// área de la válvula en el momento de la resiembra (para referencia)
  @HiveField(8)
  double areaValvula;

  /// temporada actual (configuraciones.temporada en backend)
  @HiveField(9)
  int temporada;

  @HiveField(10)
  int createdBy;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime updatedAt;

  /// lote de semilla usado en la resiembra
  @HiveField(13)
  String lotesSemilla;

  /// cantidad de semillas adicionales (campo nuevo clave en app)
  @HiveField(14)
  int cantidadSemillas;

  BoletaResiembra({
    required this.id,
    required this.productorId,
    required this.fincaId,
    required this.loteId,
    required this.valvulaId,
    required this.variedad,
    required this.variedadId,
    required this.fechaSiembra,
    required this.areaValvula,
    required this.temporada,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.lotesSemilla,
    required this.cantidadSemillas,
  });
}
