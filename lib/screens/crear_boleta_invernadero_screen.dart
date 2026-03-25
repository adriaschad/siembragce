import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intencion_siembra/services/boxes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intencion_siembra/services/outbox_service.dart';

import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';
import '../models/variedad_productor.dart';
import '../models/boleta_invernadero.dart';
import '../models/distancia_cama.dart';
import '../models/distancia_planta.dart';

class CrearBoletaInvernaderoScreen extends StatefulWidget {
  final String? token;
  final int productorId;
  const CrearBoletaInvernaderoScreen({
    super.key,
    required this.productorId,
    this.token,
  });

  @override
  State<CrearBoletaInvernaderoScreen> createState() =>
      _CrearBoletaInvernaderoScreenState();
}

class SingleDecimalSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (!RegExp(r'^[0-9.,]*$').hasMatch(text)) return oldValue;
    final separators = RegExp(r'[.,]').allMatches(text).length;
    if (separators > 1) return oldValue;
    return newValue;
  }
}

class _CrearBoletaInvernaderoScreenState
    extends State<CrearBoletaInvernaderoScreen> {
  List<Finca> fincas = [];
  List<Lote> lotes = [];
  List<Valvula> valvulas = [];
  List<Variedad> variedades = [];
  List<VariedadProductor> variedadProductores = [];
  List<DistanciaCama> distanciasCama = [];
  List<DistanciaPlanta> distanciasPlanta = [];

  Finca? fincaSeleccionada;
  Lote? loteSeleccionado;
  Valvula? valvulaSeleccionada;
  Variedad? variedadSeleccionada;
  DistanciaCama? distanciaCamaSeleccionada;
  DistanciaPlanta? distanciaPlantaSeleccionada;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _lotesSemillaController = TextEditingController();
  final TextEditingController _cantidadBandejasController =
      TextEditingController();

  DateTime? fechaSiembra;
  DateTime? fechaTransplante;

  // Si necesita mostrarse temporalmente, cambiar a true.
  final bool _showLotesSemillaField = false;

  @override
  void initState() {
    super.initState();
    fechaSiembra = DateTime.now();
    fechaTransplante = fechaSiembra!.add(const Duration(days: 12));
    cargarCatalogos();
  }

  @override
  void dispose() {
    _areaController.dispose();
    _lotesSemillaController.dispose();
    _cantidadBandejasController.dispose();
    super.dispose();
  }

  double? _parseArea(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return null;
    return double.tryParse(t);
  }

  double? _areaMaximaValvula() => valvulaSeleccionada?.area;

  Future<void> cargarCatalogos() async {
    final boxFincas = await Hive.openBox<Finca>('fincas');
    final boxVariedades = await Hive.openBox<Variedad>('variedades');
    final boxVariedadProductor = await Hive.openBox<VariedadProductor>(
      'variedad_productor',
    );
    final distanciasCamaFiltradas = await Boxes.distanciasCamaPorProductor(
      widget.productorId,
    );
    final distanciasPlantaFiltradas = await Boxes.distanciasPlantaPorProductor(
      widget.productorId,
    );

    final relaciones = boxVariedadProductor.values
        .where((vp) => vp.productorId == widget.productorId)
        .map((vp) => vp.variedadId)
        .toSet();

    setState(() {
      fincas = boxFincas.values
          .where((f) => f.productorId == widget.productorId)
          .toList();
      lotes = [];
      valvulas = [];
      variedades = boxVariedades.values
          .where((v) => relaciones.contains(v.id))
          .toList();
      variedadProductores = boxVariedadProductor.values.toList();
      distanciasCama = distanciasCamaFiltradas;
      distanciasPlanta = distanciasPlantaFiltradas;
    });
  }

  void filtrarLotesPorFinca(int fincaId) async {
    final boxLotes = await Hive.openBox<Lote>('lotes');
    setState(() {
      lotes = boxLotes.values.where((l) => l.fincaId == fincaId).toList();
      loteSeleccionado = null;
      valvulas = [];
      valvulaSeleccionada = null;
      variedadSeleccionada = null;
      // limpiar campo área al cambiar finca/lote
      _areaController.text = '';
    });
  }

  void filtrarValvulasPorLote(int loteId) async {
    final boxValvulas = await Hive.openBox<Valvula>('valvulas');
    setState(() {
      valvulas = boxValvulas.values.where((v) => v.loteId == loteId).toList();
      valvulaSeleccionada = null;
      _areaController.text = '';
    });
  }

  Future<int> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remembered_email');
    if (email == null) return 1;
    return prefs.getInt_notnull('offline_userId_$email');
  }

  bool _fechaSiembraValida(DateTime day) {
    final hoy = DateTime.now();
    final limiteInferior = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(const Duration(days: 3));
    final comienzo = DateTime(
      limiteInferior.year,
      limiteInferior.month,
      limiteInferior.day,
    );
    final fin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
    return !day.isBefore(comienzo) && !day.isAfter(fin);
  }

  Future<int> _determineTemporada() async {
    try {
      if (Hive.isBoxOpen('configuraciones')) {
        final box = Hive.box('configuraciones');
        if (box.isNotEmpty) {
          final first = box.getAt(0);
          if (first is Map && first.containsKey('temporada'))
            return (first['temporada'] as int);
          try {
            final temp = (first as dynamic).temporada;
            if (temp != null) return temp as int;
          } catch (_) {}
        }
      } else {
        try {
          final box = await Hive.openBox('configuraciones');
          if (box.isNotEmpty) {
            final first = box.getAt(0);
            if (first is Map && first.containsKey('temporada'))
              return (first['temporada'] as int);
            try {
              final temp = (first as dynamic).temporada;
              if (temp != null) return temp as int;
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (_) {}
    final fs = fechaSiembra ?? DateTime.now();
    return fs.year;
  }

  Map<String, Object?> _extractFields(dynamic item) {
    int? productorId;
    int? valvulaId;
    int? temporada;
    DateTime? fechaSiembraLocal;

    if (item == null)
      return {
        'productorId': null,
        'valvulaId': null,
        'temporada': null,
        'fechaSiembra': null,
      };

    if (item is BoletaInvernadero) {
      final dyn = item as dynamic;
      try {
        productorId = item.productorId;
      } catch (_) {}
      try {
        valvulaId = item.valvulaId;
      } catch (_) {}
      try {
        temporada = dyn.temporada as int?;
      } catch (_) {
        temporada = null;
      }
      final fs = item.fechaSiembra;
      if (fs is DateTime) fechaSiembraLocal = fs;
      return {
        'productorId': productorId,
        'valvulaId': valvulaId,
        'temporada': temporada,
        'fechaSiembra': fechaSiembraLocal,
      };
    }

    if (item is Map) {
      try {
        productorId = (item['productor_id'] ?? item['productorId']) as int?;
      } catch (_) {}
      try {
        valvulaId = (item['valvula_id'] ?? item['valvulaId']) as int?;
      } catch (_) {}
      try {
        temporada = (item['temporada'] ?? item['season']) as int?;
      } catch (_) {}
      final fs = item['fecha_siembra'] ?? item['fechaSiembra'];
      if (fs is String) {
        final dt = DateTime.tryParse(fs);
        if (dt != null) fechaSiembraLocal = dt;
      } else if (fs is DateTime) {
        fechaSiembraLocal = fs;
      }
      return {
        'productorId': productorId,
        'valvulaId': valvulaId,
        'temporada': temporada,
        'fechaSiembra': fechaSiembraLocal,
      };
    }

    try {
      final dyn = item as dynamic;
      try {
        productorId = dyn.productorId ?? dyn.productor ?? null;
      } catch (_) {}
      try {
        valvulaId = dyn.valvulaId ?? dyn.valvula ?? null;
      } catch (_) {}
      try {
        temporada = dyn.temporada ?? dyn.season ?? null;
      } catch (_) {}
      try {
        final fsObj = dyn.fechaSiembra ?? dyn.fecha_siembra ?? null;
        if (fsObj is DateTime)
          fechaSiembraLocal = fsObj;
        else if (fsObj is String) {
          final dt = DateTime.tryParse(fsObj);
          if (dt != null) fechaSiembraLocal = dt;
        }
      } catch (_) {}
    } catch (_) {}

    return {
      'productorId': productorId,
      'valvulaId': valvulaId,
      'temporada': temporada,
      'fechaSiembra': fechaSiembraLocal,
    };
  }

  Future<bool> _existsBoletaInvernaderoForValveSeason(
    int valvulaId,
    int temporada,
  ) async {
    try {
      final box = await Boxes.boletasInvernadero();
      for (final item in box.values) {
        final f = _extractFields(item);
        final prod = f['productorId'] as int?;
        final valv = f['valvulaId'] as int?;
        final temp = f['temporada'] as int?;
        final fs = f['fechaSiembra'] as DateTime?;

        if (prod == null || valv == null) continue;
        if (prod != widget.productorId) continue;
        if (valv != valvulaId) continue;

        if ((temp != null && temp == temporada) ||
            (fs != null && fs.year == temporada)) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking existing boletas invernadero: $e');
    }
    return false;
  }

  Future<void> guardarBoleta() async {
    try {
      if (!_formKey.currentState!.validate() ||
          fincaSeleccionada == null ||
          loteSeleccionado == null ||
          valvulaSeleccionada == null ||
          variedadSeleccionada == null ||
          fechaSiembra == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa todos los campos')),
        );
        return;
      }

      final areaParsed = _parseArea(_areaController.text);
      if (areaParsed == null || areaParsed <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Área inválida')));
        return;
      }

      final max = _areaMaximaValvula();
      if (max == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seleccione una válvula con área válida'),
          ),
        );
        return;
      }
      if (areaParsed > max) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El área no puede ser mayor que el área de la válvula (${max.toStringAsFixed(2)})',
            ),
          ),
        );
        return;
      }

      final cant = int.tryParse(_cantidadBandejasController.text.trim()) ?? 0;
      if (cant <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingrese la cantidad de bandejas válida'),
          ),
        );
        return;
      }

      final temporada = await _determineTemporada();
      final exists = await _existsBoletaInvernaderoForValveSeason(
        valvulaSeleccionada!.id,
        temporada,
      );
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ya existe una boleta invernadero para esta válvula en la temporada $temporada',
            ),
          ),
        );
        return;
      }

      final userId = await getCurrentUserId();

      final nueva = BoletaInvernadero(
        id: DateTime.now().millisecondsSinceEpoch,
        productorId: widget.productorId,
        fincaId: fincaSeleccionada!.id,
        loteId: loteSeleccionado!.id,
        valvulaId: valvulaSeleccionada!.id,
        variedad: variedadSeleccionada!.nombre,
        variedadId: variedadSeleccionada!.id,
        cantidadBandejas: cant,
        fechaSiembra: fechaSiembra!,
        fechaTransplante: fechaTransplante,
        lotesSemilla: _lotesSemillaController.text.trim(),
        area: areaParsed,
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final box = await Boxes.boletasInvernadero();

      try {
        (nueva as dynamic).temporada = 0;
      } catch (_) {}

      await box.put(nueva.id.toString(), nueva);

      await OutboxService.enqueueBoletaInvernadero(nueva);
      await OutboxService.trySyncAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Boleta invernadero guardada localmente')),
      );
      Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('Error guardar boleta invernadero: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar boleta: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxValvula = _areaMaximaValvula();
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Boleta Invernadero')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<Finca>(
                decoration: const InputDecoration(labelText: 'Finca'),
                value: fincaSeleccionada,
                items: fincas
                    .map(
                      (f) => DropdownMenuItem(value: f, child: Text(f.nombre)),
                    )
                    .toList(),
                onChanged: (f) {
                  setState(() {
                    fincaSeleccionada = f;
                    loteSeleccionado = null;
                    valvulaSeleccionada = null;
                    variedadSeleccionada = null;
                  });
                  if (f != null) filtrarLotesPorFinca(f.id);
                },
                validator: (v) => v == null ? 'Seleccione una finca' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Lote>(
                decoration: const InputDecoration(labelText: 'Lote'),
                value: loteSeleccionado,
                items: lotes
                    .map(
                      (l) => DropdownMenuItem(value: l, child: Text(l.nombre)),
                    )
                    .toList(),
                onChanged: (l) {
                  setState(() {
                    loteSeleccionado = l;
                    valvulaSeleccionada = null;
                  });
                  if (l != null) filtrarValvulasPorLote(l.id);
                },
                validator: (v) => v == null ? 'Seleccione un lote' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Valvula>(
                decoration: const InputDecoration(labelText: 'Válvula'),
                value: valvulaSeleccionada,
                items: valvulas
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text(v.nombre)),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    valvulaSeleccionada = val;
                  });

                  // Rellenar el campo de área con el área de la válvula (editable por el usuario)
                  if (val?.area != null) {
                    final text = val!.area!.toStringAsFixed(2);
                    _areaController.value = TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                  } else {
                    _areaController.clear();
                  }
                },
                validator: (v) => v == null ? 'Seleccione una válvula' : null,
              ),
              if (valvulaSeleccionada != null && maxValvula != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12),
                  child: Text(
                    'Área válvula: ${maxValvula.toStringAsFixed(2)} ha',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
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
              if (_showLotesSemillaField)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final input = textEditingValue.text.toLowerCase();
                      if (input.isEmpty) return const Iterable<String>.empty();
                      if (!Hive.isBoxOpen('boletas'))
                        return const Iterable<String>.empty();
                      final box = Hive.box('boletas');
                      final all = box.values
                          .map(
                            (b) => (b is Map)
                                ? (b['lotes_semilla'] ?? '')
                                : (b.lotesSemilla ?? ''),
                          )
                          .where((s) => s != null && s.isNotEmpty)
                          .map((s) => s.toString())
                          .toSet()
                          .where((s) => s.toLowerCase().contains(input));
                      return all;
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          controller.text = _lotesSemillaController.text;
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length),
                          );
                          controller.addListener(() {
                            _lotesSemillaController.text = controller.text;
                          });
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Lotes semilla',
                            ),
                          );
                        },
                    onSelected: (selection) {
                      _lotesSemillaController.text = selection;
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cantidadBandejasController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad de bandejas',
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n <= 0) return 'Ingrese cantidad válida';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Área (ha)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  SingleDecimalSeparatorFormatter(),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'Ingrese el área';
                  final a = _parseArea(val);
                  if (a == null) return 'Formato inválido';
                  final max = _areaMaximaValvula();
                  if (max == null) return 'Seleccione una válvula';
                  if (a > max)
                    return 'Area no puede superar área de válvula (${max.toStringAsFixed(2)})';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  fechaSiembra == null
                      ? 'Seleccione fecha de siembra'
                      : 'Fecha siembra: ${fechaSiembra!.day}/${fechaSiembra!.month}/${fechaSiembra!.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final hoy = DateTime.now();
                  final tresDiasAtras = hoy.subtract(const Duration(days: 3));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: fechaSiembra ?? hoy,
                    firstDate: tresDiasAtras,
                    lastDate: hoy,
                  );
                  if (picked != null) {
                    setState(() {
                      fechaSiembra = picked;
                      fechaTransplante = picked.add(const Duration(days: 12));
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  fechaTransplante == null
                      ? 'Seleccione fecha de trasplante'
                      : 'Fecha trasplante: ${fechaTransplante!.day}/${fechaTransplante!.month}/${fechaTransplante!.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final hoy = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        fechaTransplante ??
                        (fechaSiembra ?? hoy).add(const Duration(days: 12)),
                    firstDate: (fechaSiembra ?? hoy).add(
                      const Duration(days: 0),
                    ),
                    lastDate: hoy.add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setState(() {
                      fechaTransplante = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: guardarBoleta,
                child: const Text('Guardar Boleta Invernadero'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
