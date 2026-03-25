// lib/services/outbox_service.dart
//
// OutboxService actualizado y extendido para soportar:
// - Boletas de siembra
// - Boletas de invernadero
// - Boletas de muestreo (multipart con fotos)
// - Boletas de resiembra (nuevo)
//
// Contiene:
// - Enqueue para cada tipo de boleta.
// - trySyncAll que procesa las 4 colas.
// - Manejo robusto de Map<dynamic,dynamic> -> Map<String,dynamic>.
// - Safe open Hive boxes.
// - Start/stop connectivity listener.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart' as net;

import '../services/api_service.dart';
import '../models/boleta.dart';
import '../models/boleta_invernadero.dart';
import '../models/boleta_muestreo.dart';
import '../models/boleta_resiembra.dart';
//import '../models/caracteristica_siembra.dart';

class OutboxService {
  static const _outboxName = 'outbox_boletas';
  static const _outboxInvernaderoName = 'outbox_boletas_invernadero';
  static const _outboxMuestreoName = 'outbox_boletas_muestreo';
  static const _outboxResiembraName = 'outbox_boletas_resiembra';

  // Tu versión de connectivity_plus emite LISTAS de resultados,
  // por eso usamos StreamSubscription<List<net.ConnectivityResult>>?.
  static StreamSubscription<List<net.ConnectivityResult>>? _sub;
  static bool _isSyncing = false;

  // ---------------------------------------------------------------------------
  // ENQUEUE: Boleta de siembra (existente)
  // ---------------------------------------------------------------------------
  static Future<void> enqueueBoleta(Boleta b) async {
    final box = await _openOutbox();
    final clientId = (b.clientUuid != null && b.clientUuid!.isNotEmpty)
        ? b.clientUuid!
        : b.id.toString();

    final payload = <String, dynamic>{
      'client_id': clientId,
      'productor_id': b.productorId,
      'finca_id': b.fincaId,
      'lote_id': b.loteId,
      'valvula_id': b.valvulaId,
      'distancia_cama': b.distanciaCama,
      'distancia_planta': b.distanciaPlanta,
      'variedad_id': b.variedadId,
      'area_real': b.areaReal,
      'fecha_siembra': b.fechaSiembra != null ? _asYmd(b.fechaSiembra!) : null,
      'created_by': b.createdBy,
      'lotes_semilla': b.lotesSemilla,
      'ciclo_promedio': b.cicloPromedio,
      'caracteristica_id': b.caracteristicaId,
    };

    await box.put(clientId, payload);
    await box.flush();
    debugPrint('[OUTBOX] Enqueued client_id=$clientId payload: $payload');
  }

  // ---------------------------------------------------------------------------
  // ENQUEUE: Boleta Invernadero (existente)
  // ---------------------------------------------------------------------------
  static Future<void> enqueueBoletaInvernadero(BoletaInvernadero b) async {
    final box = await _openOutboxInvernadero();
    final clientId = b.id.toString();

    int? cantidad = b.cantidadBandejas;
    if (cantidad == null) {
      try {
        cantidad = int.tryParse((b.cantidadBandejas ?? 0).toString()) ?? 0;
      } catch (_) {
        cantidad = 0;
      }
    }

    double? areaNormalized;
    try {
      if (b.area != null) {
        final s = b.area.toString().replaceAll(',', '.');
        areaNormalized = double.tryParse(s) ?? 0.0;
      } else {
        areaNormalized = 0.0;
      }
    } catch (_) {
      areaNormalized = 0.0;
    }

    String? fechaSiembraYmd;
    if (b.fechaSiembra != null) fechaSiembraYmd = _asYmd(b.fechaSiembra!);
    String? fechaTransplanteYmd;
    if (b.fechaTransplante != null) {
      fechaTransplanteYmd = _asYmd(b.fechaTransplante!);
    }

    final payload = <String, dynamic>{
      'client_id': clientId,
      'productor_id': b.productorId,
      'finca_id': b.fincaId,
      'lote_id': b.loteId,
      'valvula_id': b.valvulaId,
      'variedad_id': b.variedadId,
      'cantidad_bandejas': cantidad,
      'fecha_siembra': fechaSiembraYmd,
      'fecha_transplante': fechaTransplanteYmd,
      'lotes_semilla': b.lotesSemilla,
      'area': areaNormalized,
      'created_by': b.createdBy,
    };

    await box.put(clientId, payload);
    await box.flush();
    debugPrint(
      '[OUTBOX-INVERNADERO] Enqueued client_id=$clientId payload: $payload',
    );
  }

  // ---------------------------------------------------------------------------
  // ENQUEUE: Boleta Muestreo (existente)
  // ---------------------------------------------------------------------------
  static Future<void> enqueueBoletaMuestreo(BoletaMuestreo b) async {
    final box = await _openOutboxMuestreo();
    final clientId = b.id.toString();

    final brix = (b.brixLecturas ?? []).map((e) {
      return {
        'calibre': e['calibre']?.toString(),
        'brix': e['brix'] is num
            ? e['brix']
            : (e['brix'] != null
                  ? double.tryParse(e['brix'].toString().replaceAll(',', '.'))
                  : null),
        'nota': e['nota']?.toString(),
      };
    }).toList();

    final fotos = (b.fotos ?? []).map((f) {
      return {
        'path': f['path']?.toString(),
        'observacion': f['observacion']?.toString(),
      };
    }).toList();

    final payload = <String, dynamic>{
      'client_id': clientId,
      'productor_id': b.productorId,
      'finca_id': b.fincaId,
      'lote_id': b.loteId,
      'valvula_id': b.valvulaId,
      'variedad': b.variedad,
      'observacion': b.observacion,
      'fecha': b.fecha != null ? _asYmd(b.fecha!) : null,
      'brix_lecturas': brix,
      'fotos': fotos,
      'created_by': b.createdBy,
    };

    await box.put(clientId, payload);
    await box.flush();
    debugPrint(
      '[OUTBOX-MUESTREO] Enqueued client_id=$clientId payload: $payload',
    );
  }

  // ---------------------------------------------------------------------------
  // ENQUEUE NUEVO: Boleta Resiembra
  // ---------------------------------------------------------------------------
  static Future<void> enqueueBoletaResiembra(BoletaResiembra b) async {
    final box = await _openOutboxResiembra();
    final clientId = b.id.toString();

    final payload = <String, dynamic>{
      'client_id': clientId,
      'productor_id': b.productorId,
      'finca_id': b.fincaId,
      'lote_id': b.loteId,
      'valvula_id': b.valvulaId,
      'variedad': b.variedad,
      'variedad_id': b.variedadId,
      'fecha_siembra': _asYmd(b.fechaSiembra),
      'area_valvula': b.areaValvula,
      'temporada': b.temporada,
      'created_by': b.createdBy,
      'lotes_semilla': b.lotesSemilla,
      'cantidad_semillas': b.cantidadSemillas,
    };

    await box.put(clientId, payload);
    await box.flush();
    debugPrint(
      '[OUTBOX-RESIEMBRA] Enqueued client_id=$clientId payload: $payload',
    );
  }

  // ---------------------------------------------------------------------------
  // trySyncAll: procesa las 4 colas (siembra, invernadero, muestreo, resiembra)
  // ---------------------------------------------------------------------------
  static Future<void> trySyncAll() async {
    if (_isSyncing) {
      debugPrint('[OUTBOX] Already syncing, skip');
      return;
    }
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('user_token');
      if (token == null || token.isEmpty) {
        debugPrint('[OUTBOX] No token → skip sync');
        return;
      }

      // 1) Boletas de siembra
      final box = await _openOutbox();
      final keys = box.keys.toList();
      if (keys.isNotEmpty) debugPrint('[OUTBOX] Pending items: ${keys.length}');
      for (final key in keys) {
        final raw = box.get(key);
        final payload = _toMapStringDynamic(raw);
        if (payload.isEmpty) {
          await box.delete(key);
          continue;
        }

        try {
          final resp = await ApiService.post(
            '/api/boletas',
            payload,
            token: token,
          );
          debugPrint(
            '[OUTBOX] Uploaded client_id=${payload['client_id']} server_id=${resp?['id']}',
          );
          await box.delete(key);
        } on ApiException catch (e) {
          if (e.statusCode == 401) {
            debugPrint('[OUTBOX] 401 Unauthorized → abort sync');
            return;
          }
          debugPrint('[OUTBOX] API error ${e.statusCode}: ${e.message}');
        } catch (e) {
          debugPrint('[OUTBOX] Network/parse error: $e');
        }
      }
      await box.flush();

      // 2) Boletas Invernadero
      final boxInv = await _openOutboxInvernadero();
      final keysInv = boxInv.keys.toList();
      if (keysInv.isNotEmpty) {
        debugPrint('[OUTBOX-INVERNADERO] Pending items: ${keysInv.length}');
      }
      for (final key in keysInv) {
        final raw = boxInv.get(key);
        final payload = _toMapStringDynamic(raw);
        if (payload.isEmpty) {
          await boxInv.delete(key);
          continue;
        }

        debugPrint(
          '[OUTBOX-INVERNADERO] POST payload for client_id=${payload['client_id']}: $payload',
        );

        try {
          final resp = await ApiService.post(
            '/api/boletas_invernadero',
            payload,
            token: token,
          );
          debugPrint(
            '[OUTBOX-INVERNADERO] Uploaded client_id=${payload['client_id']} server_id=${resp?['id']}',
          );
          await boxInv.delete(key);
        } on ApiException catch (e) {
          debugPrint(
            '[OUTBOX-INVERNADERO] API error ${e.statusCode}: ${e.message}',
          );
          if (e.statusCode == 401) {
            debugPrint('[OUTBOX-INVERNADERO] 401 Unauthorized → abort sync');
            return;
          }
          if (e.statusCode == 422) {
            debugPrint(
              '[OUTBOX-INVERNADERO] Received 422 → attempting to resolve by finding existing server boleta and retrying update',
            );
            try {
              final resolved = await _resolveDuplicateAndRetry(payload, token);
              if (resolved) {
                debugPrint(
                  '[OUTBOX-INVERNADERO] Resolved and retried successfully for client_id=${payload['client_id']}',
                );
                await boxInv.delete(key);
                continue;
              } else {
                debugPrint(
                  '[OUTBOX-INVERNADERO] Could not resolve duplicate for client_id=${payload['client_id']}',
                );
              }
            } catch (e) {
              debugPrint('[OUTBOX-INVERNADERO] Error resolving duplicate: $e');
            }
          }
        } catch (e) {
          debugPrint('[OUTBOX-INVERNADERO] Network/parse error: $e');
        }
      }
      await boxInv.flush();

      // 3) Boletas Muestreo (multipart con fotos)
      final boxM = await _openOutboxMuestreo();
      final keysM = boxM.keys.toList();
      if (keysM.isNotEmpty) {
        debugPrint('[OUTBOX-MUESTREO] Pending items: ${keysM.length}');
      }
      for (final key in keysM) {
        final raw = boxM.get(key);
        final payload = _toMapStringDynamic(raw);
        if (payload.isEmpty) {
          await boxM.delete(key);
          continue;
        }

        debugPrint(
          '[OUTBOX-MUESTREO] Preparing upload for client_id=${payload['client_id']}',
        );

        try {
          // Normalizar fotos a List<Map<String,dynamic>>
          final fotosRaw = payload['fotos'];
          final fotosList = <Map<String, dynamic>>[];
          if (fotosRaw is List) {
            for (final f in fotosRaw) {
              if (f is Map) {
                fotosList.add(_toMapStringDynamic(f));
              } else {
                fotosList.add({'path': f.toString(), 'observacion': ''});
              }
            }
          }

          // files para ApiService.postMultipart
          final List<Map<String, String>> files = [];
          for (var i = 0; i < fotosList.length; i++) {
            final f = fotosList[i];
            final path = f['path']?.toString();
            if (path != null && File(path).existsSync()) {
              files.add({
                'path': path,
                'field': 'fotos[]',
                'filename': path.split(Platform.pathSeparator).last,
              });
              payload['photo_obs_$i'] = f['observacion']?.toString() ?? '';
            } else {
              payload['photo_obs_$i'] = f['observacion']?.toString() ?? '';
            }
          }

          final sendPayload = Map<String, dynamic>.from(payload);
          if (sendPayload['brix_lecturas'] != null &&
              sendPayload['brix_lecturas'] is! String) {
            try {
              sendPayload['brix_lecturas'] = jsonEncode(
                sendPayload['brix_lecturas'],
              );
            } catch (_) {}
          }
          sendPayload.remove('fotos');

          final resp = await ApiService.postMultipart(
            '/api/boletas_muestreo',
            sendPayload,
            files,
            token: token,
          );

          debugPrint(
            '[OUTBOX-MUESTREO] Uploaded client_id=${payload['client_id']} server_resp=$resp',
          );
          await boxM.delete(key);
        } on ApiException catch (e) {
          debugPrint(
            '[OUTBOX-MUESTREO] API error ${e.statusCode}: ${e.message}',
          );
          if (e.statusCode == 401) {
            debugPrint('[OUTBOX-MUESTREO] 401 Unauthorized → abort sync');
            return;
          }
        } catch (e) {
          debugPrint('[OUTBOX-MUESTREO] Network/other error: $e');
        }
      }
      await boxM.flush();

      // 4) Boletas Resiembra
      final boxR = await _openOutboxResiembra();
      final keysR = boxR.keys.toList();
      if (keysR.isNotEmpty) {
        debugPrint('[OUTBOX-RESIEMBRA] Pending items: ${keysR.length}');
      }
      for (final key in keysR) {
        final raw = boxR.get(key);
        final payload = _toMapStringDynamic(raw);
        if (payload.isEmpty) {
          await boxR.delete(key);
          continue;
        }

        debugPrint(
          '[OUTBOX-RESIEMBRA] POST payload for client_id=${payload['client_id']}: $payload',
        );

        try {
          final resp = await ApiService.post(
            '/api/boletas_resiembra', // endpoint en tu backend Laravel
            payload,
            token: token,
          );
          debugPrint(
            '[OUTBOX-RESIEMBRA] Uploaded client_id=${payload['client_id']} server_id=${resp?['id']}',
          );
          await boxR.delete(key);
        } on ApiException catch (e) {
          debugPrint(
            '[OUTBOX-RESIEMBRA] API error ${e.statusCode}: ${e.message}',
          );
          if (e.statusCode == 401) {
            debugPrint('[OUTBOX-RESIEMBRA] 401 Unauthorized → abort sync');
            return;
          }
        } catch (e) {
          debugPrint('[OUTBOX-RESIEMBRA] Network/parse error: $e');
        }
      }
      await boxR.flush();
    } finally {
      _isSyncing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers internos
  // ---------------------------------------------------------------------------
  static Future<bool> _resolveDuplicateAndRetry(
    Map<String, dynamic> payload,
    String token,
  ) async {
    try {
      final productorId = payload['productor_id'];
      final path =
          '/api/boletas_invernadero?productor_id=${Uri.encodeComponent(productorId.toString())}';
      final respList = await ApiService.get(path, token: token);
      if (respList == null) return false;
      final List items = respList is List
          ? respList
          : (respList['data'] ?? respList);
      final valvulaId = payload['valvula_id'];
      Map? match;
      for (final it in items) {
        try {
          if (it is Map) {
            final vid =
                it['valvula_id'] ??
                it['valvulaId'] ??
                (it['valvula'] is Map ? it['valvula']['id'] : null);
            if (vid == valvulaId) {
              match = Map<String, dynamic>.from(it);
              break;
            }
          }
        } catch (_) {}
      }
      if (match == null) return false;
      final serverClientUuid =
          match['client_uuid'] ??
          match['client_id'] ??
          (match['clientId']?.toString()) ??
          (match['id']?.toString());
      if (serverClientUuid == null) return false;
      final newPayload = Map<String, dynamic>.from(payload);
      newPayload['client_id'] = serverClientUuid.toString();
      final retryResp = await ApiService.post(
        '/api/boletas_invernadero',
        newPayload,
        token: token,
      );
      return retryResp != null;
    } catch (e) {
      debugPrint('[OUTBOX-INVERNADERO] _resolveDuplicateAndRetry error: $e');
      return false;
    }
  }

  // Safe open box helpers
  static Future<Box> _openOutbox() async {
    if (Hive.isBoxOpen(_outboxName)) return Hive.box(_outboxName);
    return Hive.openBox(_outboxName);
  }

  static Future<Box> _openOutboxInvernadero() async {
    if (Hive.isBoxOpen(_outboxInvernaderoName)) {
      return Hive.box(_outboxInvernaderoName);
    }
    return Hive.openBox(_outboxInvernaderoName);
  }

  static Future<Box> _openOutboxMuestreo() async {
    if (Hive.isBoxOpen(_outboxMuestreoName)) {
      return Hive.box(_outboxMuestreoName);
    }
    return Hive.openBox(_outboxMuestreoName);
  }

  static Future<Box> _openOutboxResiembra() async {
    if (Hive.isBoxOpen(_outboxResiembraName)) {
      return Hive.box(_outboxResiembraName);
    }
    return Hive.openBox(_outboxResiembraName);
  }

  /// Convierte dinámicamente Map/dynamic a Map<String,dynamic> de forma segura.
  static Map<String, dynamic> _toMapStringDynamic(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      final out = <String, dynamic>{};
      raw.forEach((k, v) {
        try {
          out[k?.toString() ?? ''] = v;
        } catch (_) {}
      });
      return out;
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return _toMapStringDynamic(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static String _asYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ---------------------------------------------------------------------------
  // Connectivity sync: start/stop
  // ---------------------------------------------------------------------------
  static Future<void> startConnectivitySync() async {
    if (_sub != null) return;

    final initial = await net.Connectivity().checkConnectivity();
    final initialOnline = (initial is List)
        ? initial.any((r) => r != net.ConnectivityResult.none)
        : (initial != net.ConnectivityResult.none);
    if (initialOnline) {
      await trySyncAll();
    }

    _sub = net.Connectivity().onConnectivityChanged.listen((results) async {
      final online = (results is List)
          ? results.any((r) => r != net.ConnectivityResult.none)
          : (results != net.ConnectivityResult.none);
      if (online) {
        debugPrint('[OUTBOX] Connectivity online → trySyncAll');
        await trySyncAll();
      }
    });
  }

  static Future<void> stopConnectivitySync() async {
    await _sub?.cancel();
    _sub = null;
  }
}
