import 'package:hive/hive.dart';

part 'boleta_muestreo.g.dart';

@HiveType(typeId: 42)
class BoletaMuestreo extends HiveObject {
  @HiveField(0)
  String id; // client id (puede ser timestamp o uuid)
  @HiveField(1)
  int? productorId;
  @HiveField(2)
  int? fincaId;
  @HiveField(3)
  int? loteId;
  @HiveField(4)
  int? valvulaId;
  @HiveField(5)
  String? variedad;
  @HiveField(6)
  String? observacion;
  @HiveField(7)
  DateTime? fecha;
  @HiveField(8)
  List<Map<String, dynamic>> brixLecturas; // [{ "calibre": "XL", "brix": 8.5 }, ...]
  @HiveField(9)
  List<Map<String, dynamic>> fotos; // [{ "path": "/data/..", "observacion": "..." }, ...]
  @HiveField(10)
  String? createdBy;

  BoletaMuestreo({
    required this.id,
    this.productorId,
    this.fincaId,
    this.loteId,
    this.valvulaId,
    this.variedad,
    this.observacion,
    this.fecha,
    this.brixLecturas = const [],
    this.fotos = const [],
    this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'client_id': id,
      'productor_id': productorId,
      'finca_id': fincaId,
      'lote_id': loteId,
      'valvula_id': valvulaId,
      'variedad': variedad,
      'observacion': observacion,
      'fecha': fecha != null
          ? '${fecha!.year.toString().padLeft(4, '0')}-${fecha!.month.toString().padLeft(2, '0')}-${fecha!.day.toString().padLeft(2, '0')}'
          : null,
      'brix_lecturas': brixLecturas,
      'fotos': fotos, // keep file paths and per-photo obs
      'created_by': createdBy,
    };
  }

  static BoletaMuestreo fromMap(Map m) {
    return BoletaMuestreo(
      id:
          (m['client_id'] ??
                  m['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString())
              .toString(),
      productorId: m['productor_id'],
      fincaId: m['finca_id'],
      loteId: m['lote_id'],
      valvulaId: m['valvula_id'],
      variedad: m['variedad'],
      observacion: m['observacion'],
      fecha: m['fecha'] != null
          ? DateTime.tryParse(m['fecha'].toString())
          : null,
      brixLecturas: List<Map<String, dynamic>>.from(m['brix_lecturas'] ?? []),
      fotos: List<Map<String, dynamic>>.from(m['fotos'] ?? []),
      createdBy: m['created_by']?.toString(),
    );
  }
}
