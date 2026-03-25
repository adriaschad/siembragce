import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';
import '../models/variedad_productor.dart';
import '../models/boleta_resiembra.dart';
import '../services/boxes.dart';
import '../services/outbox_service.dart';

class CrearBoletaResiembraScreen extends StatefulWidget {
  final String? token;
  final int productorId;
  const CrearBoletaResiembraScreen({
    super.key,
    required this.productorId,
    this.token,
  });

  @override
  State<CrearBoletaResiembraScreen> createState() =>
      _CrearBoletaResiembraScreenState();
}

class _CrearBoletaResiembraScreenState
    extends State<CrearBoletaResiembraScreen> {
  List<Finca> fincas = [];
  List<Lote> lotes = [];
  List<Valvula> valvulas = [];
  List<Variedad> variedades = [];
  List<VariedadProductor> variedadProductores = [];

  Finca? fincaSeleccionada;
  Lote? loteSeleccionado;
  Valvula? valvulaSeleccionada;
  Variedad? variedadSeleccionada;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cantidadSemillasController =
      TextEditingController();
  final TextEditingController _lotesSemillaController = TextEditingController();

  DateTime? fechaResiembra;

  @override
  void initState() {
    super.initState();
    cargarCatalogos();
    fechaResiembra = DateTime.now();
  }

  Future<void> cargarCatalogos() async {
    final boxFincas = await Hive.openBox<Finca>('fincas');
    final boxVariedades = await Hive.openBox<Variedad>('variedades');
    final boxVariedadProductor = await Hive.openBox<VariedadProductor>(
      'variedad_productor',
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
    });
  }

  void filtrarValvulasPorLote(int loteId) async {
    final boxValvulas = await Hive.openBox<Valvula>('valvulas');
    setState(() {
      valvulas = boxValvulas.values.where((v) => v.loteId == loteId).toList();
      valvulaSeleccionada = null;
    });
  }

  double? _areaValvulaSeleccionada() {
    return valvulaSeleccionada?.area;
  }

  Future<int> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remembered_email');
    if (email == null) return 1;
    return prefs.getInt_notnull('offline_userId_$email');
  }

  /// En el offline no sabemos la temporada actual de la tabla configuraciones,
  /// puedes:
  /// - leerla de algún Box de configuraciones, o
  /// - dejar un valor por defecto (ej. 2026) y que el backend la reajuste.
  int _temporadaActualLocal() {
    // TODO: si tienes una box de configuraciones offline, léela aquí.
    return 2026;
  }

  Future<void> guardarBoletaResiembra() async {
    try {
      if (!_formKey.currentState!.validate() ||
          fincaSeleccionada == null ||
          loteSeleccionado == null ||
          valvulaSeleccionada == null ||
          variedadSeleccionada == null ||
          fechaResiembra == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa todos los campos')),
        );
        return;
      }

      // Validar cantidad de semillas
      final rawCant = _cantidadSemillasController.text.trim();
      final cant = int.tryParse(rawCant);
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

      final boxResiembra = await Hive.openBox<BoletaResiembra>(
        'boletas_resiembra',
      );
      final userId = await getCurrentUserId();
      final ahora = DateTime.now();

      final nueva = BoletaResiembra(
        id: ahora.millisecondsSinceEpoch,
        productorId: widget.productorId,
        fincaId: fincaSeleccionada!.id,
        loteId: loteSeleccionado!.id,
        valvulaId: valvulaSeleccionada!.id,
        variedad: variedadSeleccionada!.nombre,
        variedadId: variedadSeleccionada!.id,
        fechaSiembra: fechaResiembra!, // fecha de resiembra
        areaValvula: areaValvula,
        temporada: _temporadaActualLocal(),
        createdBy: userId,
        createdAt: ahora,
        updatedAt: ahora,
        lotesSemilla: _lotesSemillaController.text,
        cantidadSemillas: cant,
      );

      await boxResiembra.add(nueva);

      // Encolar para envío al servidor (Outbox)
      await OutboxService.enqueueBoletaResiembra(nueva);
      await OutboxService.trySyncAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Boleta de resiembra guardada localmente'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error al guardar boleta resiembra: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar boleta: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final areaValvula = _areaValvulaSeleccionada();

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Boleta de Resiembra')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
                onChanged: (finca) {
                  setState(() {
                    fincaSeleccionada = finca;
                    loteSeleccionado = null;
                    valvulaSeleccionada = null;
                    variedadSeleccionada = null;
                  });
                  if (finca != null) filtrarLotesPorFinca(finca.id);
                },
                validator: (value) =>
                    value == null ? 'Seleccione una finca' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<Lote>(
                decoration: const InputDecoration(labelText: 'Lote'),
                value: loteSeleccionado,
                items: lotes
                    .map(
                      (l) => DropdownMenuItem(value: l, child: Text(l.nombre)),
                    )
                    .toList(),
                onChanged: (lote) {
                  setState(() {
                    loteSeleccionado = lote;
                    valvulaSeleccionada = null;
                  });
                  if (lote != null) filtrarValvulasPorLote(lote.id);
                },
                validator: (value) =>
                    value == null ? 'Seleccione un lote' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<Valvula>(
                decoration: const InputDecoration(labelText: 'Válvula'),
                value: valvulaSeleccionada,
                items: valvulas
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text(v.nombre)),
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

              if (valvulaSeleccionada != null && areaValvula != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Área válvula: ${areaValvula.toStringAsFixed(2)}',
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
                onChanged: (variedad) {
                  setState(() {
                    variedadSeleccionada = variedad;
                  });
                },
                validator: (value) =>
                    value == null ? 'Seleccione una variedad' : null,
              ),
              const SizedBox(height: 12),

              // Lote de semilla (similar a boleta de siembra)
              TextFormField(
                controller: _lotesSemillaController,
                decoration: const InputDecoration(labelText: 'Lote de semilla'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese el lote de semilla';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Cantidad de semillas adicionales
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
                    return 'La cantidad debe ser un número entero mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fecha de resiembra
              ListTile(
                title: Text(
                  fechaResiembra == null
                      ? 'Seleccione la fecha de resiembra'
                      : 'Fecha: ${fechaResiembra!.day}/${fechaResiembra!.month}/${fechaResiembra!.year}',
                ),
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
                onPressed: guardarBoletaResiembra,
                child: const Text('Guardar Boleta de Resiembra'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
