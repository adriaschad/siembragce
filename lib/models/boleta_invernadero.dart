import 'package:hive/hive.dart';

part 'boleta_invernadero.g.dart';

@HiveType(typeId: 41)
class BoletaInvernadero extends HiveObject {
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

  // nombre para UI
  @HiveField(5)
  String variedad;

  // opcional: id de variedad
  @HiveField(6)
  int? variedadId;

  // cantidad de bandejas
  @HiveField(7)
  int cantidadBandejas;

  // fechas
  @HiveField(8)
  DateTime fechaSiembra;

  @HiveField(9)
  DateTime fechaTransplante;

  // lote(s) de semilla (texto libre)
  @HiveField(10)
  String? lotesSemilla;

  @HiveField(11)
  double area;

  @HiveField(12)
  int createdBy;

  @HiveField(13)
  DateTime? createdAt;

  @HiveField(14)
  DateTime? updatedAt;

  BoletaInvernadero({
    required this.id,
    required this.productorId,
    required this.fincaId,
    required this.loteId,
    required this.valvulaId,
    required this.variedad,
    this.variedadId,
    required this.cantidadBandejas,
    required this.fechaSiembra,
    DateTime? fechaTransplante,
    this.lotesSemilla,
    required this.area,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : fechaTransplante =
           fechaTransplante ?? fechaSiembra.add(const Duration(days: 12)),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}
