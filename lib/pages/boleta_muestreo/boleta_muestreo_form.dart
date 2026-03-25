import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

import '../../models/boleta_muestreo.dart';
import '../../services/outbox_service.dart';
import '../../utils/image_utils.dart';

import '../../models/finca.dart';
import '../../models/lote.dart';
import '../../models/valvula.dart';
import '../../models/variedad.dart';
import '../../models/variedad_productor.dart';

class BoletaMuestreoForm extends StatefulWidget {
  final String? token;
  final int productorId;
  final dynamic
  boletaMuestreo; // puede ser BoletaMuestreo, Map o elemento crudo de Hive (dynamic)

  const BoletaMuestreoForm({
    Key? key,
    required this.productorId,
    this.token,
    this.boletaMuestreo,
  }) : super(key: key);

  @override
  _BoletaMuestreoFormState createState() => _BoletaMuestreoFormState();
}

class _BoletaMuestreoFormState extends State<BoletaMuestreoForm> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final ImagePicker _picker = ImagePicker();

  // --- Catálogos para combos ---
  List<Finca> fincas = [];
  List<Lote> lotes = [];
  List<Valvula> valvulas = [];
  List<Variedad> variedades = [];
  List<VariedadProductor> variedadProductores = [];

  Finca? fincaSeleccionada;
  Lote? loteSeleccionado;
  Valvula? valvulaSeleccionada;
  Variedad? variedadSeleccionada;

  // Campos (no mostramos productorId como campo editable)
  String? observacion;
  DateTime fecha = DateTime.now();

  // Lecturas Brix y fotos
  List<Map<String, dynamic>> brixLecturas = [];
  List<Map<String, dynamic>> fotos = []; // items: { path, thumb, observacion }

  // UI
  bool _isCompressing = false;
  String? _compressingFileName;

  // Candidate Hive boxes to look for existing items when editing
  static const List<String> _candidateBoxes = [
    'boletas_muestreo',
    'boletas',
    'outbox',
    'outbox_boletas_muestreo',
    'outbox_muestreo',
  ];

  // originalClientId (string/int) if editing
  dynamic _originalClientId;

  @override
  void initState() {
    super.initState();

    // if widget contains basic data, normalize brix/fotos immediately so UI shows quickly
    if (widget.boletaMuestreo != null) {
      _extractBasicFields(widget.boletaMuestreo);
    }

    // load catalogs and then finish prefill (selections require catalogs)
    cargarCatalogos().then((_) {
      _prefillIfEditing();
    });
  }

  // Extract brix/fotos/observacion/fecha quickly from provided object (best-effort)
  void _extractBasicFields(dynamic bm) {
    try {
      if (bm is BoletaMuestreo) {
        observacion = bm.observacion;
        fecha = bm.fecha ?? DateTime.now();
        brixLecturas = _normalizeBrixList(bm.brixLecturas);
        fotos = _normalizeFotosList(bm.fotos);
        _originalClientId = bm.id;
      } else if (bm is Map) {
        observacion =
            bm['observacion']?.toString() ??
            bm['observacion_general']?.toString();
        final f =
            bm['fecha'] ??
            bm['fecha_siembra'] ??
            bm['createdAt'] ??
            bm['fechaMuestreo'];
        final dt = _parseDateTime(f);
        if (dt != null) fecha = dt;
        brixLecturas = _normalizeBrixList(
          bm['brix_lecturas'] ?? bm['brixLecturas'] ?? bm['lecturas'] ?? [],
        );
        fotos = _normalizeFotosList(
          bm['fotos'] ?? bm['photos'] ?? bm['imagenes'] ?? [],
        );
        _originalClientId = bm['client_id'] ?? bm['id'] ?? bm['clientId'];
      } else {
        final dyn = bm as dynamic;
        try {
          observacion = dyn.observacion ?? dyn.observacion_general;
        } catch (_) {}
        try {
          final f = dyn.fecha ?? dyn.fechaSiembra ?? dyn.createdAt;
          final dt = _parseDateTime(f);
          if (dt != null) fecha = dt;
        } catch (_) {}
        try {
          brixLecturas = _normalizeBrixList(
            dyn.brixLecturas ?? dyn.brix_lecturas ?? [],
          );
        } catch (_) {}
        try {
          fotos = _normalizeFotosList(dyn.fotos ?? dyn.photos ?? []);
        } catch (_) {}
        try {
          _originalClientId = dyn.client_id ?? dyn.clientId ?? dyn.id;
        } catch (_) {}
      }
      // ensure UI updated if initState extracted data
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error extracting basic fields: $e');
    }
  }

  Future<void> _prefillIfEditing() async {
    final bm = widget.boletaMuestreo;
    if (bm == null) return;

    try {
      // finca/lote/valvula/variedad selection: attempt to resolve IDs/names into selection objects
      int? fincaId;
      int? loteId;
      int? valvulaId;
      String? variedadName;

      if (bm is BoletaMuestreo) {
        fincaId = bm.fincaId;
        loteId = bm.loteId;
        valvulaId = bm.valvulaId;
        variedadName = bm.variedad;
      } else if (bm is Map) {
        fincaId = _toInt(bm['finca_id'] ?? bm['fincaId'] ?? bm['finca']);
        loteId = _toInt(bm['lote_id'] ?? bm['loteId'] ?? bm['lote']);
        valvulaId = _toInt(
          bm['valvula_id'] ?? bm['valvulaId'] ?? bm['valvula'],
        );
        variedadName =
            (bm['variedad'] ?? bm['variedad_name'] ?? bm['variedadNombre'])
                ?.toString();
      } else {
        final dyn = bm as dynamic;
        try {
          fincaId = dyn.fincaId ?? dyn.finca_id;
        } catch (_) {}
        try {
          loteId = dyn.loteId ?? dyn.lote_id;
        } catch (_) {}
        try {
          valvulaId = dyn.valvulaId ?? dyn.valvula_id;
        } catch (_) {}
        try {
          variedadName = dyn.variedad ?? dyn.variedadName;
        } catch (_) {}
      }

      // selections (safe lookups)
      if (fincaId != null) {
        final foundFinca = _firstWhereOrNull<Finca>(
          fincas,
          (f) => f.id == fincaId,
        );
        if (foundFinca != null) {
          if (!mounted) return;
          setState(() => fincaSeleccionada = foundFinca);
          await filtrarLotesPorFinca(foundFinca.id);
          if (loteId != null) {
            final foundLote = _firstWhereOrNull<Lote>(
              lotes,
              (l) => l.id == loteId,
            );
            if (foundLote != null) {
              if (!mounted) return;
              setState(() => loteSeleccionado = foundLote);
              await filtrarValvulasPorLote(foundLote.id);
              if (valvulaId != null) {
                final foundVal = _firstWhereOrNull<Valvula>(
                  valvulas,
                  (v) => v.id == valvulaId,
                );
                if (foundVal != null) {
                  if (!mounted) return;
                  setState(() => valvulaSeleccionada = foundVal);
                }
              }
            }
          }
        }
      }

      if (variedadName != null) {
        final foundVar = _firstWhereOrNull<Variedad>(
          variedades,
          (v) => v.nombre == variedadName,
        );
        if (foundVar != null) {
          if (!mounted) return;
          setState(() => variedadSeleccionada = foundVar);
        }
      }

      // Ensure brixLecturas and fotos are fully normalized and applied (in case catalogs loading changed state)
      final normalizedBrix = _normalizeBrixList(_extractPossibleBrix(bm));
      final normalizedFotos = _normalizeFotosList(_extractPossibleFotos(bm));
      if (!mounted) return;
      setState(() {
        brixLecturas = normalizedBrix;
        fotos = normalizedFotos;
      });
    } catch (e, st) {
      debugPrint('Error pre-filling selections: $e\n$st');
    }
  }

  // ----------------------------
  // Carga y filtrado de catálogos
  // ----------------------------
  Future<void> cargarCatalogos() async {
    try {
      final boxFincas = await Hive.openBox<Finca>('fincas');
      final boxVariedades = await Hive.openBox<Variedad>('variedades');
      final boxVarRel = await Hive.openBox<VariedadProductor>(
        'variedad_productor',
      );

      final relaciones = boxVarRel.values
          .where((vp) => vp.productorId == widget.productorId)
          .map((vp) => vp.variedadId)
          .toSet();

      if (!mounted) return;
      setState(() {
        fincas = boxFincas.values
            .where((f) => f.productorId == widget.productorId)
            .toList();
        variedades = boxVariedades.values
            .where((v) => relaciones.contains(v.id))
            .toList();
        variedadProductores = boxVarRel.values.toList();
      });

      await boxFincas.close();
      await boxVariedades.close();
      await boxVarRel.close();
    } catch (e, st) {
      debugPrint('cargarCatalogos error: $e\n$st');
    }
  }

  Future<void> filtrarLotesPorFinca(int fincaId) async {
    try {
      final boxLotes = await Hive.openBox<Lote>('lotes');
      final fetched = boxLotes.values
          .where((l) => l.fincaId == fincaId)
          .toList();
      await boxLotes.close();
      if (!mounted) return;
      setState(() {
        lotes = fetched;
        loteSeleccionado = null;
        valvulas = [];
        valvulaSeleccionada = null;
      });
    } catch (e) {
      debugPrint('filtrarLotesPorFinca error: $e');
    }
  }

  Future<void> filtrarValvulasPorLote(int loteId) async {
    try {
      final boxValvulas = await Hive.openBox<Valvula>('valvulas');
      final fetched = boxValvulas.values
          .where((v) => v.loteId == loteId)
          .toList();
      await boxValvulas.close();
      if (!mounted) return;
      setState(() {
        valvulas = fetched;
        valvulaSeleccionada = null;
      });
    } catch (e) {
      debugPrint('filtrarValvulasPorLote error: $e');
    }
  }

  // -----------------------
  // Imagenes / compresión
  // -----------------------
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 100);
    if (picked == null) return;

    setState(() {
      _isCompressing = true;
      _compressingFileName = picked.name;
    });

    try {
      final compressedPath = await ImageUtils.compressAndSave(
        picked.path,
        maxWidth: 1600,
        quality: 80,
        prefix: 'bm',
      );
      final thumbPath = await ImageUtils.generateThumbnail(
        compressedPath,
        width: 300,
        quality: 65,
      );

      setState(() {
        fotos.add({
          'path': compressedPath,
          'thumb': thumbPath,
          'observacion': '',
        });
      });
    } catch (e, st) {
      debugPrint('Error compressing image: $e\n$st');
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final target = File(
          '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}',
        );
        await File(picked.path).copy(target.path);
        setState(() {
          fotos.add({'path': target.path, 'thumb': null, 'observacion': ''});
        });
      } catch (e2) {
        debugPrint('Error copying original image: $e2');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al procesar la imagen.')),
          );
        }
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isCompressing = false;
        _compressingFileName = null;
      });
    }
  }

  void _addBrixRow() {
    setState(() {
      brixLecturas.add({'calibre': '', 'brix': null, 'nota': ''});
    });
  }

  void _removeBrixRow(int idx) {
    setState(() {
      if (idx >= 0 && idx < brixLecturas.length) brixLecturas.removeAt(idx);
    });
  }

  void _removePhoto(int idx) {
    setState(() {
      if (idx >= 0 && idx < fotos.length) {
        fotos.removeAt(idx);
      }
    });
  }

  // -----------------------
  // Submit / Outbox (create or edit)
  // -----------------------
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Validaciones de combos: finca/lote/valvula/variedad
    if (fincaSeleccionada == null ||
        loteSeleccionado == null ||
        valvulaSeleccionada == null ||
        variedadSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione finca, lote, válvula y variedad'),
        ),
      );
      return;
    }

    // Mantener el id original si venimos a editar, si no generar nuevo
    final clientId = _originalClientId ?? _uuid.v4();

    final boletaMap = {
      'client_id': clientId,
      'productor_id': widget.productorId,
      'finca_id': fincaSeleccionada?.id,
      'lote_id': loteSeleccionado?.id,
      'valvula_id': valvulaSeleccionada?.id,
      'variedad': variedadSeleccionada?.nombre,
      'observacion': observacion,
      'fecha': fecha.toIso8601String(),
      'brix_lecturas': brixLecturas
          .map(
            (e) => {
              'calibre': e['calibre']?.toString(),
              'brix': e['brix'] is num
                  ? e['brix']
                  : (e['brix'] != null
                        ? double.tryParse(
                            e['brix'].toString().replaceAll(',', '.'),
                          )
                        : null),
              'nota': e['nota']?.toString(),
            },
          )
          .toList(),
      'fotos': fotos
          .map(
            (f) => {
              'path': f['path']?.toString(),
              'thumb': f['thumb']?.toString(),
              'observacion': f['observacion']?.toString() ?? '',
            },
          )
          .toList(),
      'createdBy': 'app',
    };

    try {
      if (widget.boletaMuestreo != null && clientId != null) {
        final updated = await _saveEditedBoleta(clientId, boletaMap);
        if (updated) {
          try {
            // try enqueue typed object if model supports it
            await OutboxService.enqueueBoletaMuestreo(
              BoletaMuestreo.fromMap(boletaMap),
            );
          } catch (_) {}
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Boleta actualizada localmente')),
          );
          Navigator.of(context).pop(true);
          return;
        } else {
          try {
            await OutboxService.enqueueBoletaMuestreo(
              BoletaMuestreo.fromMap(boletaMap),
            );
          } catch (_) {}
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Boleta encolada (actualizar en servidor)'),
            ),
          );
          Navigator.of(context).pop(true);
          return;
        }
      } else {
        await OutboxService.enqueueBoletaMuestreo(
          BoletaMuestreo.fromMap(boletaMap),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Boleta guardada localmente y encolada para sincronización',
            ),
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }
    } catch (e, st) {
      debugPrint('Error saving boleta (create/edit): $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar la boleta')),
      );
    }
  }

  /// Try to find the box and key where an item with clientId is stored.
  Future<MapEntry<String, dynamic>?> _findBoxAndKeyForClientId(
    dynamic clientId,
  ) async {
    try {
      for (final boxName in _candidateBoxes) {
        try {
          final box = await Hive.openBox(boxName);
          if (box.containsKey(clientId)) {
            await box.close();
            return MapEntry(boxName, clientId);
          }
          for (final key in box.keys) {
            try {
              final v = box.get(key);
              if (v is Map) {
                final mid = v['client_id'] ?? v['id'] ?? v['clientId'];
                if (mid != null && mid.toString() == clientId.toString()) {
                  await box.close();
                  return MapEntry(boxName, key);
                }
              } else if (v is BoletaMuestreo) {
                if (v.id.toString() == clientId.toString()) {
                  await box.close();
                  return MapEntry(boxName, key);
                }
              } else {
                final dyn = v as dynamic;
                try {
                  final mid = dyn.client_id ?? dyn.clientId ?? dyn.id;
                  if (mid != null && mid.toString() == clientId.toString()) {
                    await box.close();
                    return MapEntry(boxName, key);
                  }
                } catch (_) {}
              }
            } catch (_) {}
          }
          await box.close();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('_findBoxAndKeyForClientId error: $e');
    }
    return null;
  }

  Future<bool> _saveEditedBoleta(
    dynamic clientId,
    Map<String, dynamic> boletaMap,
  ) async {
    try {
      final found = await _findBoxAndKeyForClientId(clientId);
      if (found == null) return false;
      final boxName = found.key;
      final key = found.value;
      final box = await Hive.openBox(boxName);
      await box.put(key, boletaMap);
      await box.close();
      return true;
    } catch (e) {
      debugPrint('_saveEditedBoleta error: $e');
      return false;
    }
  }

  // -----------------------
  // Helpers: normalization
  // -----------------------
  List<Map<String, dynamic>> _normalizeBrixList(dynamic raw) {
    final out = <Map<String, dynamic>>[];
    try {
      if (raw == null) return out;
      if (raw is List) {
        for (final e in raw) {
          if (e == null) continue;
          if (e is Map) {
            out.add({
              'calibre':
                  e['calibre']?.toString() ?? e['calibre']?.toString() ?? '',
              'brix': e['brix'] is num
                  ? e['brix']
                  : (e['brix'] != null
                        ? double.tryParse(
                            e['brix'].toString().replaceAll(',', '.'),
                          )
                        : null),
              'nota': e['nota']?.toString() ?? '',
            });
          } else {
            // maybe simple values
            out.add({'calibre': e.toString(), 'brix': null, 'nota': ''});
          }
        }
      }
    } catch (e) {
      debugPrint('_normalizeBrixList error: $e');
    }
    return out;
  }

  List<Map<String, dynamic>> _normalizeFotosList(dynamic raw) {
    final out = <Map<String, dynamic>>[];
    try {
      if (raw == null) return out;
      if (raw is List) {
        for (final f in raw) {
          if (f == null) continue;
          if (f is Map) {
            out.add({
              'path': f['path']?.toString() ?? f['uri']?.toString(),
              'thumb': f['thumb']?.toString(),
              'observacion': f['observacion']?.toString() ?? '',
            });
          } else {
            // simple string path
            out.add({'path': f.toString(), 'thumb': null, 'observacion': ''});
          }
        }
      }
    } catch (e) {
      debugPrint('_normalizeFotosList error: $e');
    }
    return out;
  }

  dynamic _extractPossibleBrix(dynamic bm) {
    try {
      if (bm is BoletaMuestreo) return bm.brixLecturas;
      if (bm is Map)
        return bm['brix_lecturas'] ?? bm['brixLecturas'] ?? bm['lecturas'];
      final dyn = bm as dynamic;
      try {
        return dyn.brixLecturas ?? dyn.brix_lecturas;
      } catch (_) {}
    } catch (_) {}
    return null;
  }

  dynamic _extractPossibleFotos(dynamic bm) {
    try {
      if (bm is BoletaMuestreo) return bm.fotos;
      if (bm is Map) return bm['fotos'] ?? bm['photos'] ?? bm['imagenes'];
      final dyn = bm as dynamic;
      try {
        return dyn.fotos ?? dyn.photos;
      } catch (_) {}
    } catch (_) {}
    return null;
  }

  T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      try {
        if (test(item)) return item;
      } catch (_) {}
    }
    return null;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final s = v.toString();
    return int.tryParse(s);
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

  // Photo preview tile
  Widget _photoTile(int idx, Map<String, dynamic> f) {
    final thumbPath = f['thumb']?.toString();
    final imgPath = f['path']?.toString();
    final obsController = TextEditingController(text: f['observacion'] ?? '');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 90,
              color: Colors.grey[200],
              child: thumbPath != null && File(thumbPath).existsSync()
                  ? Image.file(
                      File(thumbPath),
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                    )
                  : (imgPath != null && File(imgPath).existsSync()
                        ? Image.file(
                            File(imgPath),
                            width: 120,
                            height: 90,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          )),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: InkWell(
                onTap: () => _removePhoto(idx),
                child: Container(
                  color: Colors.black38,
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 120,
          child: TextFormField(
            controller: obsController,
            decoration: const InputDecoration(
              labelText: 'Obs. foto',
              isDense: true,
            ),
            onChanged: (v) => f['observacion'] = v,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.boletaMuestreo != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Boleta de Muestreo' : 'Nueva Boleta de Muestreo',
        ),
        actions: [
          IconButton(
            onPressed: _addBrixRow,
            icon: const Icon(Icons.add_chart),
            tooltip: 'Agregar lectura Brix',
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'camera') await _pickImage(ImageSource.camera);
              if (v == 'gallery') await _pickImage(ImageSource.gallery);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'camera', child: Text('Tomar foto')),
              PopupMenuItem(
                value: 'gallery',
                child: Text('Seleccionar desde galería'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Finca -> Lote -> Válvula -> Variedad (combos)
              DropdownButtonFormField<Finca>(
                decoration: const InputDecoration(labelText: 'Finca'),
                value: fincaSeleccionada,
                items: fincas
                    .map(
                      (f) => DropdownMenuItem(value: f, child: Text(f.nombre)),
                    )
                    .toList(),
                onChanged: (f) async {
                  setState(() {
                    fincaSeleccionada = f;
                    loteSeleccionado = null;
                    valvulaSeleccionada = null;
                  });
                  if (f != null) await filtrarLotesPorFinca(f.id);
                },
                validator: (v) => v == null ? 'Seleccione una finca' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Lote>(
                decoration: const InputDecoration(labelText: 'Lote'),
                value: loteSeleccionado,
                items: lotes
                    .map(
                      (l) => DropdownMenuItem(value: l, child: Text(l.nombre)),
                    )
                    .toList(),
                onChanged: (l) async {
                  setState(() {
                    loteSeleccionado = l;
                    valvulaSeleccionada = null;
                  });
                  if (l != null) await filtrarValvulasPorLote(l.id);
                },
                validator: (v) => v == null ? 'Seleccione un lote' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Valvula>(
                decoration: const InputDecoration(labelText: 'Válvula'),
                value: valvulaSeleccionada,
                items: valvulas
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text(v.nombre)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => valvulaSeleccionada = val),
                validator: (v) => v == null ? 'Seleccione una válvula' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Variedad>(
                decoration: const InputDecoration(labelText: 'Variedad'),
                value: variedadSeleccionada,
                items: variedades
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text(v.nombre)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => variedadSeleccionada = v),
                validator: (v) => v == null ? 'Seleccione una variedad' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Observación general',
                ),
                onSaved: (v) => observacion = v,
                initialValue: observacion,
              ),
              const SizedBox(height: 12),
              // Brix rows
              Text(
                'Lecturas Brix',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              if (brixLecturas.isEmpty)
                const Text(
                  'No hay lecturas. Pulsa + para añadir.',
                  style: TextStyle(color: Colors.grey),
                ),
              ...brixLecturas.asMap().entries.map((e) {
                final i = e.key;
                final row = e.value;
                final calibreController = TextEditingController(
                  text: row['calibre']?.toString() ?? '',
                );
                final brixController = TextEditingController(
                  text: row['brix']?.toString() ?? '',
                );
                final notaController = TextEditingController(
                  text: row['nota']?.toString() ?? '',
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: calibreController,
                          decoration: const InputDecoration(
                            labelText: 'Calibre',
                          ),
                          onChanged: (val) => row['calibre'] = val,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: brixController,
                          decoration: const InputDecoration(labelText: '°Brix'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (val) => row['brix'] = double.tryParse(
                            val.replaceAll(',', '.'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: notaController,
                          decoration: const InputDecoration(
                            labelText: 'Nota',
                            isDense: true,
                          ),
                          onChanged: (val) => row['nota'] = val,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeBrixRow(i),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 12),
              Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (_isCompressing)
                ListTile(
                  leading: const CircularProgressIndicator(),
                  title: Text(
                    'Procesando imagen: ${_compressingFileName ?? ''}',
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fotos.asMap().entries.map((e) {
                  final i = e.key;
                  final f = e.value;
                  return _photoTile(i, f);
                }).toList(),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save),
                label: Text(isEditing ? 'Actualizar boleta' : 'Guardar boleta'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _pickImage(ImageSource.camera);
        },
        child: const Icon(Icons.camera_alt),
        tooltip: 'Tomar foto rápida',
      ),
    );
  }
}
