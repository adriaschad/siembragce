import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intencion_siembra/services/outbox_service.dart';

import '../../models/boleta_muestreo.dart';
import '../../models/finca.dart';
import '../../models/lote.dart';
import '../../models/valvula.dart';
import '../../models/variedad.dart';

class VerBoletasMuestreoScreen extends StatefulWidget {
  final String? token;
  final int productorId;

  const VerBoletasMuestreoScreen({
    Key? key,
    this.token,
    required this.productorId,
  }) : super(key: key);

  @override
  State<VerBoletasMuestreoScreen> createState() =>
      _VerBoletasMuestreoScreenState();
}

class _VerBoletasMuestreoScreenState extends State<VerBoletasMuestreoScreen> {
  List<Map<String, dynamic>> _boletas = [];
  Map<int, String> _mapFincas = {};
  Map<int, String> _mapLotes = {};
  Map<int, String> _mapValvulas = {};
  Map<int, String> _mapVariedades = {};

  bool _loading = true;
  String? _lastSourceBox;

  static const List<String> _candidateBoxes = [
    'boletas_muestreo',
    'boletas',
    'outbox',
    'outbox_boletas_muestreo',
    'outbox_muestreo',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _lastSourceBox = null;
    });

    try {
      await _loadCatalogs();

      List<Map<String, dynamic>> result = [];
      String? usedBox;

      for (final boxName in _candidateBoxes) {
        final list = await _tryLoadFromBox(boxName);
        if (list.isNotEmpty) {
          result = list;
          usedBox = boxName;
          break;
        }
      }

      if (usedBox == null) {
        try {
          final b = await Hive.openBox('boletas_muestreo');
          usedBox = (b.isEmpty) ? null : 'boletas_muestreo';
          await b.close();
        } catch (_) {}
      }

      final pid = widget.productorId;
      final filtered = result.where((b) {
        final prod = b['productor_id'] ?? b['productorId'];
        if (prod == null) return false;
        try {
          return prod == pid;
        } catch (_) {
          return false;
        }
      }).toList();

      filtered.sort((a, b) {
        DateTime da =
            _parseDateTime(a['fecha']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        DateTime db =
            _parseDateTime(b['fecha']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        _boletas = filtered;
        _lastSourceBox = usedBox;
      });
    } catch (e, st) {
      debugPrint('Error loading boletas muestreo: $e\n$st');
      if (!mounted) return;
      setState(() {
        _boletas = [];
        _lastSourceBox = null;
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _tryLoadFromBox(String boxName) async {
    try {
      final box = await Hive.openBox(boxName);
      if (box.isEmpty) {
        await box.close();
        return [];
      }
      final raw = box.values.toList();

      final List<Map<String, dynamic>> normalized = [];
      for (final item in raw) {
        try {
          if (item == null) continue;
          if (item is Map) {
            normalized.add(Map<String, dynamic>.from(item));
            continue;
          }
          if (item is BoletaMuestreo) {
            final b = item;
            normalized.add({
              'client_id': b.id,
              'productor_id': b.productorId,
              'finca_id': b.fincaId,
              'lote_id': b.loteId,
              'valvula_id': b.valvulaId,
              'variedad': b.variedad,
              'observacion': b.observacion,
              'fecha': b.fecha?.toIso8601String(),
              'brix_lecturas': b.brixLecturas,
              'fotos': b.fotos,
            });
            continue;
          }
          final dyn = item as dynamic;
          final converted = <String, dynamic>{};
          try {
            converted['client_id'] = dyn.client_id ?? dyn.clientId ?? dyn.id;
          } catch (_) {}
          try {
            converted['productor_id'] = dyn.productorId ?? dyn.productor_id;
          } catch (_) {}
          try {
            converted['finca_id'] = dyn.fincaId ?? dyn.finca_id;
          } catch (_) {}
          try {
            converted['lote_id'] = dyn.loteId ?? dyn.lote_id;
          } catch (_) {}
          try {
            converted['valvula_id'] = dyn.valvulaId ?? dyn.valvula_id;
          } catch (_) {}
          try {
            converted['variedad'] =
                dyn.variedad ?? dyn.variedad_id ?? dyn.variedadName;
          } catch (_) {}
          try {
            converted['observacion'] =
                dyn.observacion ?? dyn.observacion_general ?? '';
          } catch (_) {}
          try {
            final f = dyn.fecha ?? dyn.fechaSiembra ?? dyn.createdAt;
            if (f is DateTime)
              converted['fecha'] = f.toIso8601String();
            else if (f is String)
              converted['fecha'] = f;
          } catch (_) {}
          try {
            converted['brix_lecturas'] =
                dyn.brixLecturas ?? dyn.brix_lecturas ?? [];
          } catch (_) {}
          try {
            converted['fotos'] = dyn.fotos ?? dyn.photos ?? [];
          } catch (_) {}
          normalized.add(converted);
        } catch (e) {
          debugPrint('Error normalizing item from $boxName: $e');
        }
      }

      await box.close();
      if (normalized.isNotEmpty) {
        debugPrint(
          'Loaded ${normalized.length} entries from Hive box "$boxName"',
        );
      }
      return normalized;
    } catch (e) {
      debugPrint('Could not open/parse box "$boxName": $e');
      return [];
    }
  }

  Future<void> _loadCatalogs() async {
    try {
      final Map<int, String> fincasMap = {};
      final Map<int, String> lotesMap = {};
      final Map<int, String> valvulasMap = {};
      final Map<int, String> variedadesMap = {};

      try {
        final boxF = await Hive.openBox<Finca>('fincas');
        for (var f in boxF.values) {
          try {
            fincasMap[f.id] = f.nombre;
          } catch (_) {}
        }
        await boxF.close();
      } catch (_) {}

      try {
        final boxL = await Hive.openBox<Lote>('lotes');
        for (var l in boxL.values) {
          try {
            lotesMap[l.id] = l.nombre;
          } catch (_) {}
        }
        await boxL.close();
      } catch (_) {}

      try {
        final boxV = await Hive.openBox<Valvula>('valvulas');
        for (var v in boxV.values) {
          try {
            valvulasMap[v.id] = v.nombre;
          } catch (_) {}
        }
        await boxV.close();
      } catch (_) {}

      try {
        final boxVar = await Hive.openBox<Variedad>('variedades');
        for (var vv in boxVar.values) {
          try {
            variedadesMap[vv.id] = vv.nombre;
          } catch (_) {}
        }
        await boxVar.close();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _mapFincas = fincasMap;
        _mapLotes = lotesMap;
        _mapValvulas = valvulasMap;
        _mapVariedades = variedadesMap;
      });
    } catch (e) {
      debugPrint('_loadCatalogs error: $e');
    }
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) {
      final isSeconds = v < 100000000000;
      return DateTime.fromMillisecondsSinceEpoch(isSeconds ? v * 1000 : v);
    }
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  String _fmtDate(dynamic v) {
    final d = _parseDateTime(v);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _brixSummary(List? brixList) {
    if (brixList == null || brixList.isEmpty) return '-';
    try {
      final parts = brixList.map((e) {
        final calibre = e['calibre'] ?? e['calibre']?.toString() ?? '';
        final b = e['brix'] ?? e['brix']?.toString() ?? '';
        return '${calibre.toString()} ${b.toString()}°';
      }).toList();
      return parts.join(', ');
    } catch (_) {
      return '-';
    }
  }

  Widget _leadingThumbnail(Map<String, dynamic> bo) {
    try {
      final fotos = bo['fotos'];
      if (fotos is List && fotos.isNotEmpty) {
        final first = fotos.first;
        final thumb = (first is Map)
            ? (first['thumb'] ?? first['path'])
            : (first.toString());
        if (thumb != null && thumb is String && File(thumb).existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(thumb),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          );
        }
      }
    } catch (_) {}
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey.shade200,
      ),
      child: const Icon(Icons.photo, color: Colors.grey),
    );
  }

  Future<dynamic> _findOriginalItemById(dynamic idVal) async {
    try {
      for (final boxName in _candidateBoxes) {
        try {
          final box = await Hive.openBox(boxName);
          if (box.containsKey(idVal)) {
            final v = box.get(idVal);
            await box.close();
            return v;
          }
          for (final v in box.values) {
            try {
              if (v == null) continue;
              if (v is Map) {
                final mid = v['client_id'] ?? v['id'] ?? v['clientId'];
                if (mid != null && mid.toString() == idVal.toString()) {
                  await box.close();
                  return v;
                }
              } else if (v is BoletaMuestreo) {
                if (v.id.toString() == idVal.toString()) {
                  await box.close();
                  return v;
                }
              } else {
                final dyn = v as dynamic;
                try {
                  final mid = dyn.client_id ?? dyn.clientId ?? dyn.id;
                  if (mid != null && mid.toString() == idVal.toString()) {
                    await box.close();
                    return v;
                  }
                } catch (_) {}
              }
            } catch (_) {}
          }
          await box.close();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('_findOriginalItemById error: $e');
    }
    return null;
  }

  Future<void> _onEditBoleta(Map<String, dynamic> bo) async {
    dynamic original;
    final clientId = bo['client_id'] ?? bo['id'] ?? bo['clientId'];
    if (clientId != null) {
      original = await _findOriginalItemById(clientId);
    }

    final args = {
      'token': widget.token,
      'productorId': widget.productorId,
      'boletaMuestreo': original ?? bo,
    };

    final r = await Navigator.pushNamed(
      context,
      '/crear_boleta_muestreo',
      arguments: args,
    );
    if (r == true) await _loadAll();
  }

  Future<void> _onDeleteBoleta(Map<String, dynamic> bo) async {
    final clientId = bo['client_id'] ?? bo['id'] ?? bo['clientId'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Eliminar esta boleta localmente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      for (final boxName in _candidateBoxes) {
        try {
          final box = await Hive.openBox(boxName);
          if (clientId != null && box.containsKey(clientId)) {
            await box.delete(clientId);
            await box.close();
            break;
          }
          final keysToDelete = <dynamic>[];
          for (final key in box.keys) {
            try {
              final v = box.get(key);
              if (v is Map) {
                final mid = v['client_id'] ?? v['id'] ?? v['clientId'];
                if (mid != null && mid.toString() == clientId.toString())
                  keysToDelete.add(key);
              } else if (v is BoletaMuestreo) {
                if (v.id.toString() == clientId.toString())
                  keysToDelete.add(key);
              } else {
                final dyn = v as dynamic;
                try {
                  final mid = dyn.client_id ?? dyn.clientId ?? dyn.id;
                  if (mid != null && mid.toString() == clientId.toString())
                    keysToDelete.add(key);
                } catch (_) {}
              }
            } catch (_) {}
          }
          for (final k in keysToDelete) {
            await box.delete(k);
          }
          await box.close();
        } catch (_) {}
      }

      await _loadAll();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boleta eliminada localmente')),
        );
    } catch (e) {
      debugPrint('Error deleting boleta: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar la boleta')),
        );
    }
  }

  void _showDetails(Map<String, dynamic> bo) {
    final fecha = _fmtDate(bo['fecha']);
    final fincaName = _lookupName(_mapFincas, bo['finca_id']);
    final loteName = _lookupName(_mapLotes, bo['lote_id']);
    final valvulaName = _lookupName(_mapValvulas, bo['valvula_id']);
    final variedadName =
        bo['variedad'] ?? _lookupName(_mapVariedades, bo['variedad_id']);
    final brix = _brixSummary(List.from(bo['brix_lecturas'] ?? []));
    final fotos = List.from(bo['fotos'] ?? []);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = MediaQuery.of(context).size.width * 0.92;
        return AlertDialog(
          title: Text(variedadName ?? 'Boleta'),
          content: SizedBox(
            width: dialogWidth,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (fotos.isNotEmpty)
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: PageView(
                          children: fotos.map((f) {
                            final path = (f is Map)
                                ? (f['path'] ?? f['thumb'])
                                : f.toString();
                            if (path != null &&
                                path is String &&
                                File(path).existsSync()) {
                              return SizedBox(
                                width: double.infinity,
                                height: 200,
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 200,
                                ),
                              );
                            }
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, size: 64),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text('Fecha: $fecha'),
                    const SizedBox(height: 6),
                    Text('Finca: ${fincaName ?? '-'}'),
                    const SizedBox(height: 6),
                    Text('Lote: ${loteName ?? '-'}'),
                    const SizedBox(height: 6),
                    Text('Válvula: ${valvulaName ?? '-'}'),
                    const SizedBox(height: 6),
                    Text('Observación: ${bo['observacion'] ?? '-'}'),
                    const SizedBox(height: 6),
                    Text('Lecturas Brix: $brix'),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _onEditBoleta(bo);
              },
              child: const Text('Editar'),
            ),
            /*TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _onDeleteBoleta(bo);
              },
              child: const Text('Eliminar'),
            ),*/
          ],
        );
      },
    );
  }

  String? _lookupName(Map<int, String> map, dynamic idVal) {
    try {
      if (idVal == null) return null;
      final id = idVal is int ? idVal : int.tryParse(idVal.toString());
      if (id == null) return null;
      return map[id];
    } catch (_) {
      return null;
    }
  }

  Future<void> _onRefresh() async {
    try {
      await OutboxService.trySyncAll();
    } catch (_) {}
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ver Boletas Muestreo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await _onRefresh();
            },
            tooltip: 'Sincronizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: _boletas.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        const Center(child: Text('No hay boletas de muestreo')),
                        if (_lastSourceBox != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Última fuente inspeccionada: $_lastSourceBox',
                            ),
                          ),
                        ],
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _boletas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final bo = _boletas[idx];
                        final fecha = _fmtDate(bo['fecha']);
                        final variedadDisplay =
                            bo['variedad'] ??
                            _lookupName(_mapVariedades, bo['variedad_id']) ??
                            'Variedad';
                        final fincaDisplay =
                            _lookupName(_mapFincas, bo['finca_id']) ?? '-';
                        final loteDisplay =
                            _lookupName(_mapLotes, bo['lote_id']) ?? '-';
                        final valvulaDisplay =
                            _lookupName(_mapValvulas, bo['valvula_id']) ?? '-';
                        final brix = _brixSummary(
                          List.from(bo['brix_lecturas'] ?? []),
                        );

                        return ListTile(
                          leading: _leadingThumbnail(bo),
                          title: Text(variedadDisplay),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$fincaDisplay • $loteDisplay • $valvulaDisplay',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fecha: $fecha  •  Brix: $brix',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => _showDetails(bo),
                        );
                      },
                    ),
            ),
    );
  }
}
