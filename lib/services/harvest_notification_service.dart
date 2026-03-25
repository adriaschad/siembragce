import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/boleta.dart';
import '../models/variedad.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import 'local_notification_service.dart';

class HarvestNotificationService {
  static bool _isRunning = false;

  static Future<void> checkAndNotify() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      // Boletas
      if (!Hive.isBoxOpen('boletas')) {
        await Hive.openBox<Boleta>('boletas');
      }
      final boxBoletas = Hive.box<Boleta>('boletas');

      // Variedades
      if (!Hive.isBoxOpen('variedades')) {
        await Hive.openBox<Variedad>('variedades');
      }
      final boxVariedades = Hive.box<Variedad>('variedades');
      final variedadesMap = {
        for (final v in boxVariedades.values) v.id: v.nombre,
      };

      // Lotes
      if (!Hive.isBoxOpen('lotes')) {
        await Hive.openBox<Lote>('lotes');
      }
      final boxLotes = Hive.box<Lote>('lotes');
      final lotesMap = {for (final l in boxLotes.values) l.id: l.nombre};

      // Válvulas
      if (!Hive.isBoxOpen('valvulas')) {
        await Hive.openBox<Valvula>('valvulas');
      }
      final boxValvulas = Hive.box<Valvula>('valvulas');
      final valvulasMap = {for (final v in boxValvulas.values) v.id: v.nombre};

      final hoy = DateTime.now();
      final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);

      for (final bo in boxBoletas.values) {
        if (bo.fechaSiembra == null) continue;
        if (bo.cicloPromedio == null || bo.cicloPromedio! <= 0) continue;

        final siembra = DateTime(
          bo.fechaSiembra!.year,
          bo.fechaSiembra!.month,
          bo.fechaSiembra!.day,
        );

        final diasTranscurridos = hoyDate.difference(siembra).inDays;

        final variedadNombre = bo.variedadId != null
            ? (variedadesMap[bo.variedadId!] ??
                  bo.variedad ??
                  'Variedad ${bo.variedadId}')
            : (bo.variedad ?? '-');

        final loteNombre = lotesMap[bo.loteId] ?? 'Lote ${bo.loteId}';
        final valvulaNombre =
            valvulasMap[bo.valvulaId] ?? 'Válvula ${bo.valvulaId}';

        // ---- LÓGICA PARA ALERTA 32 DÍAS ----
        const min32 = 32;
        const max32 = 35;
        final enRango32 =
            diasTranscurridos >= min32 && diasTranscurridos <= max32;

        if (enRango32 && (bo.notif32Enviada != true)) {
          await _notifyDia32(
            bo,
            variedadNombre,
            loteNombre,
            valvulaNombre,
            diasTranscurridos,
          );
          bo.notif32Enviada = true;
          await bo.save();
        }

        // ---- LÓGICA PARA ALERTA 50 DÍAS ----
        const min50 = 50;
        const max50 = 55;
        final enRango50 =
            diasTranscurridos >= min50 && diasTranscurridos <= max50;

        if (enRango50 && (bo.notif50Enviada != true)) {
          await _notifyDia50(
            bo,
            variedadNombre,
            loteNombre,
            valvulaNombre,
            diasTranscurridos,
          );
          bo.notif50Enviada = true;
          await bo.save();
        }
      }
    } catch (e, st) {
      debugPrint('HarvestNotificationService error: $e\n$st');
    } finally {
      _isRunning = false;
    }
  }

  static Future<void> _notifyDia32(
    Boleta b,
    String variedadNombre,
    String loteNombre,
    String valvulaNombre,
    int diasTranscurridos,
  ) async {
    final titulo = 'Alerta: alrededor de 32 días de siembra';
    final cuerpo =
        'Lote $loteNombre, válvula $valvulaNombre, variedad $variedadNombre. '
        'Han pasado $diasTranscurridos días desde la siembra.';

    final notifId = b.id.hashCode ^ 32;

    debugPrint('[NOTIF-32] $titulo => $cuerpo');

    await LocalNotificationService.showNotification(
      id: notifId,
      title: titulo,
      body: cuerpo,
    );
  }

  static Future<void> _notifyDia50(
    Boleta b,
    String variedadNombre,
    String loteNombre,
    String valvulaNombre,
    int diasTranscurridos,
  ) async {
    final titulo = 'Alerta: alrededor de 50 días de siembra';
    final cuerpo =
        'Lote $loteNombre, válvula $valvulaNombre, variedad $variedadNombre. '
        'Han pasado $diasTranscurridos días desde la siembra.';

    final notifId = b.id.hashCode ^ 50;

    debugPrint('[NOTIF-50] $titulo => $cuerpo');

    await LocalNotificationService.showNotification(
      id: notifId,
      title: titulo,
      body: cuerpo,
    );
  }
}
