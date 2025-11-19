// lib/services/outbox_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart' as net;

import '../services/api_service.dart';
import '../models/boleta.dart';

class OutboxService {
  static const _outboxName = 'outbox_boletas';

  // 👇 Tu versión de connectivity_plus emite LISTAS de resultados
  static StreamSubscription<List<net.ConnectivityResult>>? _sub;
  static bool _isSyncing = false;

  static Future<void> enqueueBoleta(Boleta b) async {
    final box = await _openOutbox();
    final clientId = b.id.toString();

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
    };

    await box.put(clientId, payload);
    await box.flush();
    debugPrint('[OUTBOX] Enqueued client_id=$clientId');
  }

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

      final box = await _openOutbox();
      final keys = box.keys.toList();
      if (keys.isEmpty) return;

      debugPrint('[OUTBOX] Pending items: ${keys.length}');

      for (final key in keys) {
        final raw = box.get(key);
        if (raw is! Map) {
          await box.delete(key);
          continue;
        }
        final payload = Map<String, dynamic>.from(raw);

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
    } finally {
      _isSyncing = false;
    }
  }

  /// Escucha cambios de conectividad (lista de resultados) y reintenta al volver online.
  static Future<void> startConnectivitySync() async {
    if (_sub != null) return;

    // Chequeo inicial: lista de estados de conectividad
    final initial = await net.Connectivity().checkConnectivity();
    final initialOnline = initial.any((r) => r != net.ConnectivityResult.none);
    if (initialOnline) {
      await trySyncAll();
    }

    _sub = net.Connectivity().onConnectivityChanged.listen((results) async {
      // results es List<ConnectivityResult>
      final online = results.any((r) => r != net.ConnectivityResult.none);
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

  // ---------- Helpers ----------
  static Future<Box> _openOutbox() async {
    if (Hive.isBoxOpen(_outboxName)) return Hive.box(_outboxName);
    return Hive.openBox(_outboxName); // dinámica (Map)
  }

  static String _asYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
