import 'package:hive/hive.dart';
import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';
import '../models/distancia_cama.dart';
import '../models/distancia_planta.dart';
import '../models/productor_distancia_cama.dart';
import '../models/productor_distancia_planta.dart';
import '../models/boleta_invernadero.dart';
import '../models/caracteristica_siembra.dart';

class Boxes {
  static Future<Box<T>> open<T>(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<T>(name);
    return Hive.openBox<T>(name);
  }

  static Future<Box<Finca>> fincas() => open<Finca>('fincas');
  static Future<Box<Lote>> lotes() => open<Lote>('lotes');
  static Future<Box<Valvula>> valvulas() => open<Valvula>('valvulas');
  static Future<Box<Variedad>> variedades() => open<Variedad>('variedades');
  static Future<Box<DistanciaCama>> distanciasCama() =>
      open<DistanciaCama>('distancias_cama');
  static Future<Box<DistanciaPlanta>> distanciasPlanta() =>
      open<DistanciaPlanta>('distancias_planta');
  static Future<Box<ProductorDistanciaCama>> productorDistanciaCama() =>
      open<ProductorDistanciaCama>('productor_distancia_cama');
  static Future<Box<ProductorDistanciaPlanta>> productorDistanciaPlanta() =>
      open<ProductorDistanciaPlanta>('productor_distancia_planta');

  // Boletas (siembra)
  static Future<Box> boletas() => open('boletas');

  // Nuevo: Boletas Invernadero (tipada)
  static Future<Box<BoletaInvernadero>> boletasInvernadero() =>
      open<BoletaInvernadero>('boletas_invernadero');

  // Outbox helpers
  static Future<Box> outboxBoletas() => open('outbox_boletas');

  // Nuevo: outbox para boletas invernadero
  static Future<Box> outboxBoletasInvernadero() =>
      open('outbox_boletas_invernadero');

  static Future<Box<CaracteristicaSiembra>> caracteristicasSiembra() =>
      open<CaracteristicaSiembra>('caracteristicas_siembra');

  /// Helpers para obtener solo las distancias de cama asociadas a un productor
  static Future<List<DistanciaCama>> distanciasCamaPorProductor(
    int productorId,
  ) async {
    final boxCama = await distanciasCama();
    final boxRel = await productorDistanciaCama();
    final ids = boxRel.values
        .where((pdc) => pdc.productorId == productorId)
        .map((pdc) => pdc.distanciaCamaId)
        .toSet();
    return boxCama.values
        .where((d) => ids.contains(d.id))
        .toList()
        .cast<DistanciaCama>();
  }

  /// Helpers para obtener solo las distancias de planta asociadas a un productor
  static Future<List<DistanciaPlanta>> distanciasPlantaPorProductor(
    int productorId,
  ) async {
    final boxPlanta = await distanciasPlanta();
    final boxRel = await productorDistanciaPlanta();
    final ids = boxRel.values
        .where((pdp) => pdp.productorId == productorId)
        .map((pdp) => pdp.distanciaPlantaId)
        .toSet();
    return boxPlanta.values
        .where((d) => ids.contains(d.id))
        .toList()
        .cast<DistanciaPlanta>();
  }
}
