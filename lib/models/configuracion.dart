import 'package:hive/hive.dart';

part 'configuracion.g.dart';

@HiveType(typeId: 0)
class Configuracion extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String empresa;

  @HiveField(2)
  int temporada;

  Configuracion({
    required this.id,
    required this.empresa,
    required this.temporada,
  });

  factory Configuracion.fromMap(Map<String, dynamic> m) => Configuracion(
    id: m['id'],
    empresa: m['empresa'] ?? '',
    temporada: m['temporada'],
  );
}
