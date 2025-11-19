import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class InboxService {
  static const _inboxName = 'inbox_boletas';

  // Descargar boletas del servidor y guardarlas localmente evitando duplicados.
  static Future<void> syncFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');
    if (token == null || token.isEmpty) {
      debugPrint('[INBOX] No token → skip sync');
      return;
    }

    try {
      // 1. Descarga todas las boletas del usuario (ajusta endpoint si es necesario)
      final List<dynamic> serverBoletas =
          await ApiService.get('/api/boletas', token: token) as List<dynamic>;

      final box = await _openInbox();
      final localIds = box.keys.toSet();

      int newCount = 0;
      for (final b in serverBoletas) {
        final serverId = b['id'].toString();
        if (!localIds.contains(serverId)) {
          await box.put(serverId, b);
          newCount++;
        }
      }
      await box.flush();

      debugPrint('[INBOX] Descargadas $newCount nuevas boletas.');
    } catch (e) {
      debugPrint('[INBOX] Error al sincronizar: $e');
    }
  }

  static Future<Box> _openInbox() async {
    if (Hive.isBoxOpen(_inboxName)) return Hive.box(_inboxName);
    return Hive.openBox(_inboxName); // dinámica (Map)
  }
}
