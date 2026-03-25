import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../models/boleta_resiembra.dart';
import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';
import '../models/variedad_productor.dart';
import '../services/outbox_service.dart';

class EditarBoletaResiembraScreen extends StatefulWidget {
  final BoletaResiembra boleta;
  final String? token;

  const EditarBoletaResiembraScreen({
    super.key,
    required this.boleta,
    this.token,
  });

  @override
  State<EditarBoletaResiembraScreen> createState() =>
      _EditarBoletaResiembraScreenState();
}

class _EditarBoletaResiembraScreenState
    extends State<EditarBoletaResiembraScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Finca> fincas = [];
  List<Lote> lotes = [];
  List<Valvula> valvulas = [];
  List<Variedad> variedades = [];
  List<VariedadProductor> variedadProductores = [];

  Finca? fincaSeleccionada;
  Lote? loteSeleccionado;
  Valvula? valvulaSeleccionada;
  Variedad? variedadSeleccionada;

  late TextEditingController _cantidadSemillasController;
  late TextEditingController _lotesSemillaController;
  DateTime? fechaResiembra;

  @override
  void initState() {
    super.initState();
    _cantidadSemillasController = TextEditingController(
      text: widget.boleta.cantidadSemillas.toString(),
    );
    _lotesSemillaController = TextEditingController(
      text: widget.boleta.lotesSemilla,
    );
    fechaResiembra = widget.boleta.fechaSiembra;

    _cargarCatalogosYSeleccionInicial();
  }

  @override
  void dispose() {
    _cantidadSemillasController.dispose();
    _lotesSemillaController.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogosYSeleccionInicial() async {
    final boxFincas = await Hive.openBox<Finca>('fincas');
    final boxLotes = await Hive.openBox<Lote>('lotes');
    final boxValvulas = await Hive.openBox<Valvula>('valvulas');
    final boxVariedades = await Hive.openBox<Variedad>('variedades');
    final boxVariedadProductor = await Hive.openBox<VariedadProductor>(
      'variedad_productor',
    );

    final relaciones = boxVariedadProductor.values
        .where((vp) => vp.productorId == widget.boleta.productorId)
        .map((vp) => vp.variedadId)
        .toSet();

    final allFincas = boxFincas.values
        .where((f) => f.productorId == widget.boleta.productorId)
        .toList();

    final allLotes = boxLotes.values
        .where((l) => l.fincaId == widget.boleta.fincaId)
        .toList();

    final allValvulas = boxValvulas.values
        .where((v) => v.loteId == widget.boleta.loteId)
        .toList();

    final allVariedades = boxVariedades.values
        .where((v) => relaciones.contains(v.id))
        .toList();

    fincaSeleccionada = allFincas.firstWhere(
      (f) => f.id == widget.boleta.fincaId,
      orElse: () => allFincas.isNotEmpty
          ? allFincas.first
          : Finca(
              id: widget.boleta.fincaId,
              nombre: '',
              productorId: widget.boleta.productorId,
            ),
    );

    loteSeleccionado = allLotes.firstWhere(
      (l) => l.id == widget.boleta.loteId,
      orElse: () => allLotes.isNotEmpty
          ? allLotes.first
          : Lote(
              id: widget.boleta.loteId,
              nombre: '',
              fincaId: widget.boleta.fincaId,
            ),
    );

    valvulaSeleccionada = allValvulas.firstWhere(
      (v) => v.id == widget.boleta.valvulaId,
      orElse: () => allValvulas.isNotEmpty
          ? allValvulas.first
          : Valvula(
              id: widget.boleta.valvulaId,
              nombre: '',
              loteId: widget.boleta.loteId,
              area: widget.boleta.areaValvula,
            ),
    );

    variedadSeleccionada = allVariedades.firstWhere(
      (v) => v.id == widget.boleta.variedadId,
      orElse: () => allVariedades.isNotEmpty
          ? allVariedades.first
          : Variedad(
              id: widget.boleta.variedadId,
              nombre: widget.boleta.variedad,
              esPolinizador: false,
            ),
    );

    setState(() {
      fincas = allFincas;
      lotes = allLotes;
      valvulas = allValvulas;
      variedades = allVariedades;
      variedadProductores = boxVariedadProductor.values.toList();
    });
  }

  void _filtrarLotesPorFinca(int fincaId) async {
    final boxLotes = await Hive.openBox<Lote>('lotes');
    setState(() {
      lotes = boxLotes.values.where((l) => l.fincaId == fincaId).toList();
      loteSeleccionado = null;
      valvulas = [];
      valvulaSeleccionada = null;
      variedadSeleccionada = null;
    });
  }

  void _filtrarValvulasPorLote(int loteId) async {
    final boxValvulas = await Hive.openBox<Valvula>('valvulas');
    setState(() {
      valvulas = boxValvulas.values.where((v) => v.loteId == loteId).toList();
      valvulaSeleccionada = null;
    });
  }

  double? _areaValvulaSeleccionada() {
    return valvulaSeleccionada?.area ?? widget.boleta.areaValvula;
  }

  String _fmtFecha(DateTime? d) {
    if (d == null) return 'Seleccione la fecha de resiembra';
    return 'Fecha: ${d.day}/${d.month}/${d.year}';
  }

  Future<void> _guardarCambios() async {
    try {
      if (!_formKey.currentState!.validate() ||
          fincaSeleccionada == null ||
          loteSeleccionado == null ||
          valvulaSeleccionada == null ||
          variedadSeleccionada == null ||
          fechaResiembra == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete todos los campos')),
        );
        return;
      }

      final cant = int.tryParse(_cantidadSemillasController.text.trim());
      if (cant == null || cant <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingrese una cantidad de semillas válida (> 0)'),
          ),
        );
        return;
      }

      final areaValvula = _areaValvulaSeleccionada();
      if (areaValvula == null || areaValvula <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La válvula seleccionada no tiene área válida'),
          ),
        );
        return;
      }

      // Actualizar boleta en memoria
      widget.boleta
        ..fincaId = fincaSeleccionada!.id
        ..loteId = loteSeleccionado!.id
        ..valvulaId = valvulaSeleccionada!.id
        ..variedad = variedadSeleccionada!.nombre
        ..variedadId = variedadSeleccionada!.id
        ..fechaSiembra = fechaResiembra!
        ..areaValvula = areaValvula
        ..lotesSemilla = _lotesSemillaController.text
        ..cantidadSemillas = cant
        ..updatedAt = DateTime.now();

      // Guardar en Hive
      final box = await Hive.openBox<BoletaResiembra>('boletas_resiembra');

      // Buscar por id, si existe reemplazar
      final index = box.values.toList().indexWhere(
        (b) => b.id == widget.boleta.id,
      );
      if (index != -1) {
        await box.putAt(index, widget.boleta);
      } else {
        await box.add(widget.boleta);
      }

      // Re-encolar para enviar al server
      await OutboxService.enqueueBoletaResiembra(widget.boleta);
      await OutboxService.trySyncAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Boleta de resiembra actualizada')),
      );
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error al editar boleta resiembra: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar cambios: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final areaValvula = _areaValvulaSeleccionada();

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Boleta de Resiembra')),
      body:
          fincas.isEmpty &&
              lotes.isEmpty &&
              valvulas.isEmpty &&
              variedades.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
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
                      onChanged: (finca) {
                        setState(() {
                          fincaSeleccionada = finca;
                          loteSeleccionado = null;
                          valvulaSeleccionada = null;
                          variedadSeleccionada = null;
                        });
                        if (finca != null) _filtrarLotesPorFinca(finca.id);
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione una finca' : null,
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
                      onChanged: (lote) {
                        setState(() {
                          loteSeleccionado = lote;
                          valvulaSeleccionada = null;
                        });
                        if (lote != null) _filtrarValvulasPorLote(lote.id);
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione un lote' : null,
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
                      onChanged: (valvula) {
                        setState(() {
                          valvulaSeleccionada = valvula;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione una válvula' : null,
                    ),
                    const SizedBox(height: 8),

                    if (areaValvula != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Área válvula: ${areaValvula.toStringAsFixed(2)}',
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
                      onChanged: (variedad) {
                        setState(() {
                          variedadSeleccionada = variedad;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione una variedad' : null,
                    ),
                    const SizedBox(height: 16),

                    // Lote de semilla
                    TextFormField(
                      controller: _lotesSemillaController,
                      decoration: const InputDecoration(
                        labelText: 'Lote de semilla',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingrese el lote de semilla';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Cantidad de semillas
                    TextFormField(
                      controller: _cantidadSemillasController,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad de semillas adicionales',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                        signed: false,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingrese la cantidad de semillas';
                        }
                        final cant = int.tryParse(value.trim());
                        if (cant == null || cant <= 0) {
                          return 'La cantidad debe ser mayor a 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fecha resiembra
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_fmtFecha(fechaResiembra)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final hoy = DateTime.now();
                        final mesAtras = hoy.subtract(const Duration(days: 30));
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fechaResiembra ?? hoy,
                          firstDate: mesAtras,
                          lastDate: hoy,
                        );
                        if (picked != null) {
                          setState(() {
                            fechaResiembra = picked;
                          });
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
