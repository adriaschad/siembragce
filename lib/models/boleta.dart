import 'package:hive/hive.dart';

part 'boleta.g.dart'; // 👈 debe existir esta línea y el nombre debe coincidir con el archivo

@HiveType(
  typeId: 40,
) // 👈 usa el MISMO typeId que ya usabas (cámbialo si el tuyo era otro)
class Boleta extends HiveObject {
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
  double distanciaCama;
  @HiveField(6)
  double distanciaPlanta;
  @HiveField(7)
  String variedad; // nombre para UI
  @HiveField(8)
  double areaReal;
  @HiveField(9)
  DateTime? fechaSiembra;
  @HiveField(10)
  int createdBy;
  @HiveField(11)
  int? variedadId; // 👈 nuevo campo
  @HiveField(12)
  DateTime? createdAt;
  @HiveField(13)
  DateTime? updatedAt;
  @HiveField(14)
  String? lotesSemilla; // <--- NUEVO CAMPO

  Boleta({
    required this.id,
    required this.productorId,
    required this.fincaId,
    required this.loteId,
    required this.valvulaId,
    required this.distanciaCama,
    required this.distanciaPlanta,
    required this.variedad,
    required this.areaReal,
    required this.fechaSiembra,
    required this.createdBy,
    this.variedadId,
    required this.createdAt,
    required this.updatedAt,
    this.lotesSemilla,
  });
}
