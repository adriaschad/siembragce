import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

// Modelos tipados
import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';
import '../models/variedad_productor.dart';
import '../models/distancia_cama.dart';
import '../models/distancia_planta.dart';
import '../models/boleta.dart';
//import '../models/configuracion.dart';
import '../models/productor_distancia_cama.dart';
import '../models/productor_distancia_planta.dart';

class SyncService {
  /// Entrada principal
  static Future<void> sincronizarCatalogos(
    String token,
    dynamic productorId,
  ) async {
    final String? pid = productorId?.toString();
    final qpPid = (pid != null && pid.isNotEmpty)
        ? {'productor_id': pid}
        : null;

    await _safeSync(
      () => _syncTypedCollection<Finca>(
        path: '/api/fincas',
        boxName: 'fincas',
        token: token,
        query: qpPid,
        fromMap: (m) => Finca(
          id: _asInt(m['id']),
          productorId: _asInt(m['productor_id']),
          nombre: (m['nombre'] ?? m['name'] ?? '').toString(),
        ),
      ),
      'fincas',
    );

    await _safeSync(
      () => _syncTypedCollection<Lote>(
        path: '/api/lotes',
        boxName: 'lotes',
        token: token,
        query: qpPid,
        fromMap: (m) => Lote(
          id: _asInt(m['id']),
          fincaId: _asInt(m['finca_id']),
          nombre: (m['nombre'] ?? m['name'] ?? '').toString(),
        ),
      ),
      'lotes',
    );

    await _safeSync(
      () => _syncTypedCollection<Valvula>(
        path: '/api/valvulas',
        boxName: 'valvulas',
        token: token,
        query: qpPid,
        fromMap: (m) => Valvula(
          id: _asInt(m['id']),
          loteId: _asInt(m['lote_id']),
          nombre: (m['nombre'] ?? m['name'] ?? '').toString(),
          area: _asDouble(m['area']),
        ),
      ),
      'valvulas',
    );

    await _safeSync(
      () => _syncTypedCollection<Variedad>(
        path: '/api/variedades',
        boxName: 'variedades',
        token: token,
        fromMap: (m) => Variedad(
          id: _asInt(m['id']),
          nombre: (m['nombre'] ?? m['name'] ?? '').toString(),
        ),
      ),
      'variedades',
    );

    await _safeSync(
      () => _syncTypedCollection<VariedadProductor>(
        path: '/api/variedad_productor',
        boxName: 'variedad_productor',
        token: token,
        // Si tu backend no filtra por productor, opcionalmente pon query: qpPid,
        fromMap: (m) => VariedadProductor(
          id: m['id'] != null
              ? _asInt(m['id'])
              : _composeId(m, ['productor_id', 'variedad_id']),
          productorId: _asInt(m['productor_id']),
          variedadId: _asInt(m['variedad_id']),
        ),
        keyFor: (m, i) {
          // Clave estable si no hay id en la tabla pivote
          if (m['id'] != null) return m['id'].toString();
          return '${m['productor_id']}-${m['variedad_id']}';
        },
      ),
      'variedad_productor',
    );

    await _safeSync(
      () => _syncTypedCollection<DistanciaCama>(
        path: '/api/distancias_cama',
        boxName: 'distancias_cama',
        token: token,
        fromMap: (m) =>
            DistanciaCama(id: _asInt(m['id']), valor: _asDouble(m['valor'])),
      ),
      'distancias_cama',
    );

    await _safeSync(
      () => _syncTypedCollection<DistanciaPlanta>(
        path: '/api/distancias_planta',
        boxName: 'distancias_planta',
        token: token,
        fromMap: (m) =>
            DistanciaPlanta(id: _asInt(m['id']), valor: _asDouble(m['valor'])),
      ),
      'distancias_planta',
    );

    await _safeSync(
      () => _syncTypedCollection<Boleta>(
        path: '/api/boletas',
        boxName: 'boletas',
        token: token,
        query: qpPid,
        fromMap: (m) => Boleta(
          id: _asInt(m['id']),
          productorId: _asInt(m['productor_id']),
          fincaId: _asInt(m['finca_id']),
          loteId: _asInt(m['lote_id']),
          valvulaId: _asInt(m['valvula_id']),
          distanciaCama: _asDouble(m['distancia_cama']),
          distanciaPlanta: _asDouble(m['distancia_planta']),
          variedadId: _asInt(m['variedad_id']),
          variedad: (m['variedad_nombre'] ?? m['variedad'] ?? '').toString(),
          areaReal: _asDouble(m['area_real']),
          fechaSiembra: DateTime.tryParse(m['fecha_siembra']) ?? DateTime.now(),
          createdBy: _asInt(m['created_by']),
          createdAt: DateTime.tryParse(m['created_at'] ?? ''),
          updatedAt: DateTime.tryParse(m['updated_at'] ?? ''),
          lotesSemilla: (m['lotes_semilla'] ?? m['lotesSemilla'] ?? '')
              .toString(), // <--- mapeo nuevo
        ),
      ),
      'boletas',
    );

    /*await _safeSync(
      () => _syncTypedCollection<Configuracion>(
        path: '/api/configuraciones',
        boxName: 'configuraciones',
        token: token,
        fromMap: (m) => Configuracion.fromMap(m),
      ),
      'configuraciones',
    );*/

    await _safeSync(
      () => _syncTypedCollection<ProductorDistanciaCama>(
        path: '/api/productor_distancia_cama',
        boxName: 'productor_distancia_cama',
        token: token,
        fromMap: (m) => ProductorDistanciaCama.fromMap(m),
      ),
      'productor_distancia_cama',
    );

    await _safeSync(
      () => _syncTypedCollection<ProductorDistanciaPlanta>(
        path: '/api/productor_distancia_planta',
        boxName: 'productor_distancia_planta',
        token: token,
        fromMap: (m) => ProductorDistanciaPlanta.fromMap(m),
      ),
      'productor_distancia_planta',
    );

    // Marca tiempos de sync global (opcional)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_at', DateTime.now().toIso8601String());
  }

  // ---------- Infra de sync tipada ----------

  static Future<void> _safeSync(
    Future<void> Function() task,
    String name,
  ) async {
    try {
      await task();
      debugPrint('[SYNC] $name OK');
    } on ApiException catch (e) {
      if (e.statusCode == 401) rethrow;
      debugPrint('[SYNC] $name ApiException ${e.statusCode}: ${e.message}');
    } catch (e) {
      debugPrint('[SYNC] $name ERROR: $e');
    }
  }

  static Future<void> _syncTypedCollection<T>({
    required String path,
    required String boxName,
    required String token,
    required T Function(Map<String, dynamic> map) fromMap,
    Map<String, String>? query,
    String Function(Map<String, dynamic> map, int index)? keyFor,
  }) async {
    debugPrint('[SYNC] Fetch $path query=$query');
    final List<dynamic> all = await _fetchAll(
      path: path,
      token: token,
      query: query,
    );
    debugPrint('[SYNC] $boxName received ${all.length} items');

    final box = await _openTypedBox<T>(boxName);
    await box.clear();

    for (var i = 0; i < all.length; i++) {
      final item = all[i];
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final obj = fromMap(map);
        final key = keyFor != null
            ? keyFor(map, i)
            : (map['id'] ?? map['uuid'] ?? map['codigo'] ?? i).toString();
        await box.put(key, obj);
      } else {
        // Si el backend mandó algo no-Map, ignóralo o loguéalo
        debugPrint('[SYNC] $boxName item[$i] no es Map, se ignora');
      }
    }
    await box.flush();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_sync_$boxName',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<List<dynamic>> _fetchAll({
    required String path,
    required String token,
    Map<String, String>? query,
  }) async {
    final List<dynamic> result = [];
    int page = 1;
    int? lastPage;

    while (true) {
      final q = {if (query != null) ...query, 'page': '$page'};

      final resp = await ApiService.get(path, token: token, query: q);

      if (resp is List) {
        result
          ..clear()
          ..addAll(resp);
        break;
      } else if (resp is Map) {
        final data = resp['data'];
        if (data is List) {
          result.addAll(data);
          lastPage = (resp['last_page'] is int)
              ? resp['last_page'] as int
              : lastPage;
          final currentPage = (resp['current_page'] is int)
              ? resp['current_page'] as int
              : page;

          if (lastPage != null) {
            if (currentPage >= lastPage) break;
          } else if (data.isEmpty) {
            break;
          }

          page += 1;
          continue;
        } else if (resp.values.isEmpty) {
          break;
        } else {
          // Mapa inesperado → lo añadimos como 1 ítem
          result.add(resp);
          break;
        }
      } else {
        break;
      }
    }

    return result;
  }

  // ---------- Utilidades ----------

  static Future<Box<T>> _openTypedBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      // Si ya está abierta con el tipo correcto, la reusamos.
      final b = Hive.box(name);
      return b as Box<T>;
    }
    return Hive.openBox<T>(name);
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  static int _composeId(Map<String, dynamic> m, List<String> keys) {
    return m.entries
        .where((e) => keys.contains(e.key))
        .map((e) => e.value)
        .join('-')
        .hashCode;
  }
}
