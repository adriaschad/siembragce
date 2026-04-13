import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intencion_siembra/services/outbox_service.dart';

import '../models/boleta_invernadero.dart';
import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';

/// Pantalla para editar una boleta invernadero.
/// Espera en arguments: {'token': String?, 'boleta': dynamic (BoletaInvernadero o Map)}
class EditarBoletaInvernaderoScreen extends StatefulWidget {
  final dynamic boleta;
  final String? token;
  const EditarBoletaInvernaderoScreen({
    super.key,
    required this.boleta,
    this.token,
  });

  @override
  State<EditarBoletaInvernaderoScreen> createState() =>
      _EditarBoletaInvernaderoScreenState();
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

class _EditarBoletaInvernaderoScreenState
    extends State<EditarBoletaInvernaderoScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Finca> fincas = [];
  List<Lote> lotes = [];
  List<Valvula> valvulas = [];
  List<Variedad> variedades = [];

  Finca? fincaSeleccionada;
  Lote? loteSeleccionado;
  Valvula? valvulaSeleccionada;
  Variedad? variedadSeleccionada;

  final TextEditingController _areaCtrl = TextEditingController();
  final TextEditingController _lotesSemillaController = TextEditingController();
  final TextEditingController _cantidadBandejasController =
      TextEditingController();

  DateTime? fechaSiembra;
  DateTime? fechaTransplante;

  dynamic get _b => widget.boleta;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _lotesSemillaController.dispose();
    _cantidadBandejasController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Abrir boxes necesarios
    final boxF = await Hive.openBox<Finca>('fincas');
    final boxL = await Hive.openBox<Lote>('lotes');
    final boxV = await Hive.openBox<Valvula>('valvulas');
    final boxVar = await Hive.openBox<Variedad>('variedades');

    fincas = boxF.values.toList();
    lotes = boxL.values.toList();
    valvulas = boxV.values.toList();
    variedades = boxVar.values.toList();

    // Rellenar selects a partir de la boleta (soporta objeto tipado o Map)
    try {
      final b = _b;
      int? fincaId;
      int? loteId;
      int? valvulaId;
      int? variedadId;
      DateTime? fs;
      DateTime? ft;
      int? cantidad;

      if (b is BoletaInvernadero) {
        fincaId = b.fincaId;
        loteId = b.loteId;
        valvulaId = b.valvulaId;
        variedadId = b.variedadId;
        fs = b.fechaSiembra;
        ft = b.fechaTransplante;
        cantidad = b.cantidadBandejas;
        _lotesSemillaController.text = (b.lotesSemilla ?? '');
        final areaVal = (b.area ?? 0);
        _areaCtrl.text = (areaVal is num)
            ? areaVal.toStringAsFixed(2)
            : areaVal.toString();
      } else if (b is Map) {
        fincaId = (b['finca_id'] ?? b['fincaId']) as int?;
        loteId = (b['lote_id'] ?? b['loteId']) as int?;
        valvulaId = (b['valvula_id'] ?? b['valvulaId']) as int?;
        variedadId = (b['variedad_id'] ?? b['variedadId']) as int?;
        final fsRaw = (b['fecha_siembra'] ?? b['fechaSiembra']);
        if (fsRaw is String)
          fs = DateTime.tryParse(fsRaw);
        else if (fsRaw is DateTime)
          fs = fsRaw;
        final ftRaw = (b['fecha_transplante'] ?? b['fechaTransplante']);
        if (ftRaw is String)
          ft = DateTime.tryParse(ftRaw);
        else if (ftRaw is DateTime)
          ft = ftRaw;
        cantidad =
            (b['cantidad_bandejas'] ?? b['cantidadBandejas'] ?? 0) as int?;
        _lotesSemillaController.text =
            (b['lotes_semilla'] ?? b['lotesSemilla'] ?? '')?.toString() ?? '';
        final areaRaw = (b['area'] ?? 0);
        _areaCtrl.text = (areaRaw is num)
            ? areaRaw.toStringAsFixed(2)
            : (areaRaw?.toString() ?? '');
      }

      fechaSiembra = fs ?? DateTime.now();
      fechaTransplante = ft ?? fechaSiembra!.add(const Duration(days: 12));
      if (cantidad != null)
        _cantidadBandejasController.text = cantidad.toString();

      if (fincaId != null) {
        fincaSeleccionada = fincas.firstWhere(
          (x) => x.id == fincaId,
          orElse: () => Finca(id: -1, nombre: '-', productorId: -1),
        );
        // filtrar lotes por finca seleccionada
        lotes = lotes.where((l) => l.fincaId == fincaSeleccionada?.id).toList();
      }
      if (loteId != null) {
        loteSeleccionado = lotes.firstWhere(
          (x) => x.id == loteId,
          orElse: () => Lote(id: -1, nombre: '-', fincaId: -1),
        );
        // filtrar válvulas por lote
        valvulas = valvulas
            .where((v) => v.loteId == loteSeleccionado?.id)
            .toList();
      }
      if (valvulaId != null) {
        valvulaSeleccionada = valvulas.firstWhere(
          (x) => x.id == valvulaId,
          orElse: () => Valvula(id: -1, nombre: '-', loteId: -1, area: 0.0),
        );
      }
      if (variedadId != null) {
        variedadSeleccionada = variedades.firstWhere(
          (x) => x.id == variedadId,
          orElse: () => Variedad(id: -1, nombre: '-', esPolinizador: false),
        );
      }
    } catch (_) {
      // ignore
    }

    setState(() {});
  }

  double? _parseArea(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return null;
    return double.tryParse(t);
  }

  double? _areaMaximaValvula() => valvulaSeleccionada?.area;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _canEdit(dynamic b) {
    try {
      DateTime? created;
      if (b is BoletaInvernadero) {
        created = (b.createdAt is DateTime) ? b.createdAt : null;
      } else if (b is Map) {
        final c = b['created_at'] ?? b['createdAt'];
        if (c is String)
          created = DateTime.tryParse(c);
        else if (c is DateTime)
          created = c;
      }
      final fs = (b is BoletaInvernadero)
          ? b.fechaSiembra
          : (b['fecha_siembra'] ?? b['fechaSiembra']);
      final compare =
          created ??
          (fs is DateTime ? fs : (fs is String ? DateTime.tryParse(fs) : null));
      if (compare == null) return false;
      return _isSameDay(compare, DateTime.now());
    } catch (_) {
      return false;
    }
  }

  Future<void> _cambiarFinca(Finca? finca) async {
    if (finca == null) return;
    final boxL = await Hive.openBox<Lote>('lotes');
    final nuevos = boxL.values.where((l) => l.fincaId == finca.id).toList();
    setState(() {
      fincaSeleccionada = finca;
      lotes = nuevos;
      loteSeleccionado = null;
      valvulas = [];
      valvulaSeleccionada = null;
    });
  }

  Future<void> _cambiarLote(Lote? lote) async {
    if (lote == null) return;
    final boxV = await Hive.openBox<Valvula>('valvulas');
    final nuevas = boxV.values.where((v) => v.loteId == lote.id).toList();
    setState(() {
      loteSeleccionado = lote;
      valvulas = nuevas;
      valvulaSeleccionada = null;
    });
  }

  Future<void> _guardarCambios() async {
    final b = _b;
    if (!_canEdit(b)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se pueden editar boletas creadas hoy'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate() ||
        fincaSeleccionada == null ||
        loteSeleccionado == null ||
        valvulaSeleccionada == null ||
        variedadSeleccionada == null ||
        fechaSiembra == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete todos los campos')),
      );
      return;
    }

    final areaParsed = _parseArea(_areaCtrl.text);
    if (areaParsed == null || areaParsed <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Área inválida')));
      return;
    }

    final max = _areaMaximaValvula();
    if (max == null || areaParsed > max) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El área no puede exceder el área de la válvula (${max?.toStringAsFixed(2) ?? '-'})',
          ),
        ),
      );
      return;
    }

    final cant = int.tryParse(_cantidadBandejasController.text.trim()) ?? 0;
    if (cant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese la cantidad de bandejas válida')),
      );
      return;
    }

    try {
      if (b is BoletaInvernadero) {
        // Actualiza modelo tipado y guarda
        b
          ..fincaId = fincaSeleccionada!.id
          ..loteId = loteSeleccionado!.id
          ..valvulaId = valvulaSeleccionada!.id
          ..variedad = variedadSeleccionada!.nombre
          ..variedadId = variedadSeleccionada!.id
          ..cantidadBandejas = cant
          ..fechaSiembra = fechaSiembra!
          ..fechaTransplante =
              fechaTransplante ?? fechaSiembra!.add(const Duration(days: 12))
          ..lotesSemilla = _lotesSemillaController.text.trim()
          ..area = areaParsed
          ..updatedAt = DateTime.now();
        await b.save();
        await OutboxService.enqueueBoletaInvernadero(b);
        await OutboxService.trySyncAll();
      } else if (b is Map) {
        // Construimos un objeto BoletaInvernadero temporal para encolarlo
        final idFromMap = b['id'] is int
            ? b['id'] as int
            : DateTime.now().millisecondsSinceEpoch;
        final updatedBoleta = BoletaInvernadero(
          id: idFromMap,
          productorId: (b['productor_id'] ?? b['productorId'] ?? 0) as int,
          fincaId: fincaSeleccionada!.id,
          loteId: loteSeleccionado!.id,
          valvulaId: valvulaSeleccionada!.id,
          variedad: variedadSeleccionada!.nombre,
          variedadId: variedadSeleccionada!.id,
          cantidadBandejas: cant,
          fechaSiembra: fechaSiembra!,
          fechaTransplante:
              fechaTransplante ?? fechaSiembra!.add(const Duration(days: 12)),
          lotesSemilla: _lotesSemillaController.text.trim(),
          area: areaParsed,
          createdBy: (b['created_by'] ?? b['createdBy'] ?? 0) as int,
          createdAt:
              DateTime.tryParse((b['created_at'] ?? b['createdAt'] ?? '')) ??
              DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await OutboxService.enqueueBoletaInvernadero(updatedBoleta);
        await OutboxService.trySyncAll();
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error guardar cambios boleta invernadero: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar cambios: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _canEdit(_b);
    final maxValvula = _areaMaximaValvula();

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Boleta Invernadero')),
      body: fincas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Finca
                    DropdownButtonFormField<Finca>(
                      decoration: const InputDecoration(labelText: 'Finca'),
                      value: fincaSeleccionada,
                      items: fincas
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(f.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (f) => _cambiarFinca(f),
                      validator: (v) =>
                          v == null ? 'Seleccione una finca' : null,
                    ),
                    const SizedBox(height: 12),

                    // Lote
                    DropdownButtonFormField<Lote>(
                      decoration: const InputDecoration(labelText: 'Lote'),
                      value: loteSeleccionado,
                      items: lotes
                          .map(
                            (l) => DropdownMenuItem(
                              value: l,
                              child: Text(l.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (l) => _cambiarLote(l),
                      validator: (v) => v == null ? 'Seleccione un lote' : null,
                    ),
                    const SizedBox(height: 12),

                    // Válvula
                    DropdownButtonFormField<Valvula>(
                      decoration: const InputDecoration(labelText: 'Válvula'),
                      value: valvulaSeleccionada,
                      items: valvulas
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          valvulaSeleccionada = val;
                        });
                        // rellenar área sugerida (editable)
                        if (val != null && (val as Valvula).area != null) {
                          final text = (val.area).toStringAsFixed(2);
                          _areaCtrl.text = text;
                          _areaCtrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: text.length),
                          );
                        }
                      },
                      validator: (v) =>
                          v == null ? 'Seleccione una válvula' : null,
                    ),
                    if (valvulaSeleccionada != null && maxValvula != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 12),
                        child: Text(
                          'Área válvula: ${maxValvula.toStringAsFixed(2)} ha',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),

                    // Variedad
                    DropdownButtonFormField<Variedad>(
                      decoration: const InputDecoration(labelText: 'Variedad'),
                      value: variedadSeleccionada,
                      items: variedades
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => variedadSeleccionada = v),
                      validator: (v) =>
                          v == null ? 'Seleccione una variedad' : null,
                    ),
                    const SizedBox(height: 12),

                    // Lotes semilla (oculto por defecto)
                    /* Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TextFormField(
                        controller: _lotesSemillaController,
                        decoration: const InputDecoration(
                          labelText: 'Lotes semilla (opcional)',
                        ),
                      ),
                    ),*/
                    const SizedBox(height: 12),

                    // Cantidad bandejas
                    TextFormField(
                      controller: _cantidadBandejasController,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad de bandejas',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final n = int.tryParse(val ?? '');
                        if (n == null || n <= 0)
                          return 'Ingrese cantidad válida';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Área
                    TextFormField(
                      controller: _areaCtrl,
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
                        final tresDiasAtras = hoy.subtract(
                          const Duration(days: 3),
                        );
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fechaSiembra ?? hoy,
                          firstDate: tresDiasAtras,
                          lastDate: hoy,
                        );
                        if (picked != null) {
                          setState(() {
                            fechaSiembra = picked;
                            fechaTransplante = picked.add(
                              const Duration(days: 12),
                            );
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
                              (fechaSiembra ?? DateTime.now()).add(
                                const Duration(days: 12),
                              ),
                          firstDate: (fechaSiembra ?? DateTime.now()),
                          lastDate: DateTime.now().add(
                            const Duration(days: 60),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            fechaTransplante = picked;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: canEdit ? _guardarCambios : null,
                      child: const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
