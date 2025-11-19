import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../models/boleta.dart';
import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';
import '../models/distancia_cama.dart';
import '../models/distancia_planta.dart';
import '../services/outbox_service.dart';

class EditarBoletaScreen extends StatefulWidget {
  final Boleta boleta;
  final String? token;
  const EditarBoletaScreen({super.key, required this.boleta, this.token});

  @override
  State<EditarBoletaScreen> createState() => _EditarBoletaScreenState();
}

/// Permite solo dígitos y un único separador decimal ('.' o ',')
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

class _EditarBoletaScreenState extends State<EditarBoletaScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _areaCtrl = TextEditingController();
  // Nuevo controlador para lotesSemilla
  final TextEditingController _lotesSemillaController = TextEditingController();

  List<Finca> fincas = [];
  List<Lote> lotes = [];
  List<Valvula> valvulas = [];
  List<Variedad> variedades = [];
  List<DistanciaCama> distanciasCama = [];
  List<DistanciaPlanta> distanciasPlanta = [];

  Finca? fincaSeleccionada;
  Lote? loteSeleccionado;
  Valvula? valvulaSeleccionada;
  Variedad? variedadSeleccionada;
  DistanciaCama? distanciaCamaSeleccionada;
  DistanciaPlanta? distanciaPlantaSeleccionada;

  DateTime? fechaSiembra;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Asegura boxes abiertos
    final boxFincas = await Hive.openBox<Finca>('fincas');
    final boxLotes = await Hive.openBox<Lote>('lotes');
    final boxValvulas = await Hive.openBox<Valvula>('valvulas');
    final boxVariedades = await Hive.openBox<Variedad>('variedades');
    final boxDistCama = await Hive.openBox<DistanciaCama>('distancias_cama');
    final boxDistPlanta = await Hive.openBox<DistanciaPlanta>(
      'distancias_planta',
    );

    final b = widget.boleta;

    // Catálogos base (puedes refiltrar variedades por productor si aplica)
    fincas = boxFincas.values
        .where((f) => f.productorId == b.productorId)
        .toList();
    lotes = boxLotes.values.where((l) => l.fincaId == b.fincaId).toList();
    valvulas = boxValvulas.values.where((v) => v.loteId == b.loteId).toList();
    variedades = boxVariedades.values.toList();
    distanciasCama = boxDistCama.values.toList();
    distanciasPlanta = boxDistPlanta.values.toList();

    // Finca
    final fincaMatch = fincas.where((f) => f.id == b.fincaId);
    fincaSeleccionada = fincaMatch.isNotEmpty
        ? fincaMatch.first
        : (fincas.isNotEmpty ? fincas.first : null);

    // Lote
    final loteMatch = lotes.where((l) => l.id == b.loteId);
    loteSeleccionado = loteMatch.isNotEmpty
        ? loteMatch.first
        : (lotes.isNotEmpty ? lotes.first : null);

    // Válvula
    final valvulaMatch = valvulas.where((v) => v.id == b.valvulaId);
    valvulaSeleccionada = valvulaMatch.isNotEmpty
        ? valvulaMatch.first
        : (valvulas.isNotEmpty ? valvulas.first : null);

    // Variedad
    final variedadMatch = variedades.where((v) => v.id == b.variedadId);
    variedadSeleccionada = variedadMatch.isNotEmpty
        ? variedadMatch.first
        : (variedades.isNotEmpty ? variedades.first : null);

    // Distancia cama
    final distCamaMatch = distanciasCama.where(
      (d) => d.valor == b.distanciaCama,
    );
    distanciaCamaSeleccionada = distCamaMatch.isNotEmpty
        ? distCamaMatch.first
        : (distanciasCama.isNotEmpty ? distanciasCama.first : null);

    // Distancia planta
    final distPlantaMatch = distanciasPlanta.where(
      (d) => d.valor == b.distanciaPlanta,
    );
    distanciaPlantaSeleccionada = distPlantaMatch.isNotEmpty
        ? distPlantaMatch.first
        : (distanciasPlanta.isNotEmpty ? distanciasPlanta.first : null);

    _areaCtrl.text = b.areaReal.toString().replaceAll(
      '.',
      ',',
    ); // legible para usuario
    fechaSiembra = b.fechaSiembra;
    _lotesSemillaController.text = b.lotesSemilla ?? '';
    setState(() {});
  }

  double? _parseArea(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return null;
    return double.tryParse(t);
  }

  double? _areaMaximaValvula() =>
      valvulaSeleccionada?.area; // el campo en BD es 'area'

  /// Calcula el área ya sembrada en la válvula seleccionada
  double _areaSembradaEnValvula(int valvulaId) {
    final boxBoletas = Hive.box<Boleta>('boletas');
    return boxBoletas.values
        .where((b) => b.valvulaId == valvulaId)
        .where((b) => b.id != widget.boleta.id) // excluye la boleta actual
        .fold(0.0, (sum, b) => sum + b.areaReal);
  }

  Future<void> _cambiarFinca(Finca? finca) async {
    if (finca == null) return;
    final boxLotes = Hive.box<Lote>('lotes');
    final nuevosLotes = boxLotes.values
        .where((l) => l.fincaId == finca.id)
        .toList();

    setState(() {
      fincaSeleccionada = finca;

      lotes = nuevosLotes;
      loteSeleccionado = null;

      valvulas = [];
      valvulaSeleccionada = null;
    });
  }

  Future<void> _cambiarLote(Lote? lote) async {
    if (lote == null) return;
    final boxValvulas = Hive.box<Valvula>('valvulas');
    final nuevasValvulas = boxValvulas.values
        .where((v) => v.loteId == lote.id)
        .toList();

    setState(() {
      loteSeleccionado = lote;

      valvulas = nuevasValvulas;
      valvulaSeleccionada = null;
    });
  }

  Future<void> _guardarCambios() async {
    final b = widget.boleta;

    // Regla de negocio: solo editar si fue creada HOY
    if (b.createdAt == null || !_isSameDay(b.createdAt!, DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puede editar boletas creadas hoy')),
      );
      return;
    }

    if (!_formKey.currentState!.validate() ||
        fincaSeleccionada == null ||
        loteSeleccionado == null ||
        valvulaSeleccionada == null ||
        variedadSeleccionada == null ||
        distanciaCamaSeleccionada == null ||
        distanciaPlantaSeleccionada == null ||
        fechaSiembra == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete todos los campos')),
      );
      return;
    }

    final areaParsed = _parseArea(_areaCtrl.text);
    final max = _areaMaximaValvula();
    if (areaParsed == null || areaParsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Área inválida: debe ser > 0 y con . o ,'),
        ),
      );
      return;
    }
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

    // ==== NUEVA VALIDACIÓN: suma de áreas ya sembradas ====
    final areaYaSembrada = _areaSembradaEnValvula(valvulaSeleccionada!.id);
    final areaTotal = areaYaSembrada + areaParsed;
    if (areaTotal > max) {
      final disponible = (max - areaYaSembrada).clamp(0, max);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Área excede el área disponible en la válvula. '
            'Disponible: ${disponible.toStringAsFixed(2)}',
          ),
        ),
      );
      return;
    }

    try {
      // Actualiza los campos de la boleta existente
      b
        ..productorId = fincaSeleccionada!.productorId
        ..fincaId = fincaSeleccionada!.id
        ..loteId = loteSeleccionado!.id
        ..valvulaId = valvulaSeleccionada!.id
        ..distanciaCama = distanciaCamaSeleccionada!.valor
        ..distanciaPlanta = distanciaPlantaSeleccionada!.valor
        ..variedad = variedadSeleccionada!.nombre
        ..variedadId = variedadSeleccionada!.id
        ..areaReal = areaParsed
        ..fechaSiembra = fechaSiembra!
        ..updatedAt = DateTime.now()
        ..lotesSemilla = _lotesSemillaController.text.trim();
      await b.save(); // Guarda en Hive

      // Encolar para sincronización (usa updateOrCreate por client_uuid en backend)
      await OutboxService.enqueueBoleta(b);
      await OutboxService.trySyncAll();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar cambios: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxValvula = _areaMaximaValvula();

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Boleta')),
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
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 16),

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
                      onChanged: (valvula) =>
                          setState(() => valvulaSeleccionada = valvula),
                      validator: (v) =>
                          v == null ? 'Seleccione una válvula' : null,
                    ),
                    const SizedBox(height: 8),

                    if (valvulaSeleccionada != null && maxValvula != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Área máx. válvula: ${maxValvula.toStringAsFixed(2)}',
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
                      onChanged: (variedad) =>
                          setState(() => variedadSeleccionada = variedad),
                      validator: (v) =>
                          v == null ? 'Seleccione una variedad' : null,
                    ),
                    const SizedBox(height: 12),

                    // Campo Autocomplete para lotes_semilla (sugiere coincidencias de otras boletas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final input = textEditingValue.text.toLowerCase();
                          if (input.isEmpty)
                            return const Iterable<String>.empty();
                          if (!Hive.isBoxOpen('boletas'))
                            return const Iterable<String>.empty();
                          final box = Hive.box<Boleta>('boletas');
                          final all = box.values
                              .whereType<Boleta>()
                              .map((b) => b.lotesSemilla)
                              .where((s) => s != null && s.isNotEmpty)
                              .map((s) => s!)
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
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Ingrese el lote de semilla';
                                  }
                                  return null;
                                },
                              );
                            },
                        onSelected: (selection) {
                          _lotesSemillaController.text = selection;
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Distancia Cama
                    DropdownButtonFormField<DistanciaCama>(
                      decoration: const InputDecoration(
                        labelText: 'Distancia Cama',
                      ),
                      value: distanciaCamaSeleccionada,
                      items: distanciasCama
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(d.valor.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (d) =>
                          setState(() => distanciaCamaSeleccionada = d),
                      validator: (v) =>
                          v == null ? 'Seleccione una distancia de cama' : null,
                    ),
                    const SizedBox(height: 16),

                    // Distancia Planta
                    DropdownButtonFormField<DistanciaPlanta>(
                      decoration: const InputDecoration(
                        labelText: 'Distancia Planta',
                      ),
                      value: distanciaPlantaSeleccionada,
                      items: distanciasPlanta
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(d.valor.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (d) =>
                          setState(() => distanciaPlantaSeleccionada = d),
                      validator: (v) => v == null
                          ? 'Seleccione una distancia de planta'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Área
                    TextFormField(
                      controller: _areaCtrl,
                      decoration: const InputDecoration(labelText: 'Área real'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        SingleDecimalSeparatorFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingrese el área';
                        }
                        final area = _parseArea(value);
                        if (area == null) {
                          return 'Formato inválido. Use números con . o ,';
                        }
                        if (area <= 0) return 'El área debe ser mayor a 0';
                        final max = _areaMaximaValvula();
                        if (max == null)
                          return 'Seleccione una válvula con área válida';
                        if (area > max) {
                          return 'No puede ser mayor al área de la válvula (${max.toStringAsFixed(2)})';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fecha siembra (editable 3 días atrás -> hoy)
                    ListTile(
                      title: Text(
                        fechaSiembra == null
                            ? 'Seleccione la fecha de siembra'
                            : 'Fecha: ${fechaSiembra!.day}/${fechaSiembra!.month}/${fechaSiembra!.year}',
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
                          setState(() => fechaSiembra = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _guardarCambios,
                      child: const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
