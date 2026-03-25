import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intencion_siembra/services/boxes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';
import '../models/variedad_productor.dart';
import '../models/boleta.dart';
import '../models/distancia_cama.dart';
import '../models/distancia_planta.dart';
import '../services/outbox_service.dart';
import '../models/caracteristica_siembra.dart';

class CrearBoletaScreen extends StatefulWidget {
  final String? token;
  final int productorId;
  const CrearBoletaScreen({super.key, required this.productorId, this.token});

  @override
  State<CrearBoletaScreen> createState() => _CrearBoletaScreenState();
}

/// Permite solo dígitos y un único separador decimal ('.' o ',')
class SingleDecimalSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    // Solo dígitos y . ,
    if (!RegExp(r'^[0-9.,]*$').hasMatch(text)) return oldValue;

    // No más de un separador entre . o ,
    final separators = RegExp(r'[.,]').allMatches(text).length;
    if (separators > 1) return oldValue;

    return newValue;
  }
}

class _CrearBoletaScreenState extends State<CrearBoletaScreen> {
  List<Finca> fincas = [];
  List<Lote> lotes = [];
  List<Valvula> valvulas = [];
  List<Variedad> variedades = [];
  List<VariedadProductor> variedadProductores = [];
  List<DistanciaCama> distanciasCama = [];
  List<DistanciaPlanta> distanciasPlanta = [];
  List<CaracteristicaSiembra> caracteristicas = [];
  List<CaracteristicaSiembra> caracteristicasFiltradas = [];

  Finca? fincaSeleccionada;
  Lote? loteSeleccionado;
  Valvula? valvulaSeleccionada;
  Variedad? variedadSeleccionada;
  DistanciaCama? distanciaCamaSeleccionada;
  DistanciaPlanta? distanciaPlantaSeleccionada;
  CaracteristicaSiembra? caracteristicaSeleccionada;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _lotesSemillaController = TextEditingController();
  DateTime? fechaSiembra;

  bool _saving = false; // <-- nuevo flag

  @override
  void initState() {
    super.initState();
    cargarCatalogos();
    fechaSiembra = DateTime.now();
  }

  /// Parseo que acepta coma o punto como separador decimal
  double? _parseArea(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    // Debe ser: enteros o decimales con punto (ya normalizado)
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return null;
    return double.tryParse(t);
  }

  /// Retorna el área máxima de la válvula seleccionada
  double? _areaMaximaValvula() {
    // Asegúrate que tu modelo Valvula tenga 'double area;'
    return valvulaSeleccionada?.area;
  }

  Future<void> cargarCatalogos() async {
    final boxFincas = await Hive.openBox<Finca>('fincas');
    final boxVariedades = await Hive.openBox<Variedad>('variedades');
    final boxVariedadProductor = await Hive.openBox<VariedadProductor>(
      'variedad_productor',
    );

    final boxCaracteristicas = await Hive.openBox<CaracteristicaSiembra>(
      'caracteristicas_siembra',
    );

    // Por defecto, sin variedad seleccionada, puedes mostrar todas
    caracteristicasFiltradas = caracteristicas;
    caracteristicaSeleccionada = null;

    // Helpers para distancias asociadas al productor
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

      // cargar características desde Hive
      caracteristicas = boxCaracteristicas.values
          .where((c) => c.activo != false)
          .toList();

      // al inicio NO hay variedad seleccionada → no mostrar ninguna característica
      caracteristicasFiltradas = [];
      caracteristicaSeleccionada = null;
    });
  }

  void filtrarLotesPorFinca(int fincaId) async {
    final boxLotes = await Hive.openBox<Lote>('lotes');
    setState(() {
      lotes = boxLotes.values.where((l) => l.fincaId == fincaId).toList();
      loteSeleccionado = null;
      valvulas = [];
      valvulaSeleccionada = null;
      variedadSeleccionada = null; // Limpia la variedad al cambiar finca
    });
  }

  void filtrarValvulasPorLote(int loteId) async {
    final boxValvulas = await Hive.openBox<Valvula>('valvulas');
    setState(() {
      valvulas = boxValvulas.values.where((v) => v.loteId == loteId).toList();
      valvulaSeleccionada = null;
    });
  }

  Future<int> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remembered_email');
    if (email == null) return 1;
    return prefs.getInt_notnull('offline_userId_$email');
  }

  Future<void> guardarBoleta() async {
    if (_saving) return; // evita doble tap
    setState(() => _saving = true);

    try {
      // Validación del formulario base
      if (!_formKey.currentState!.validate() ||
          fincaSeleccionada == null ||
          loteSeleccionado == null ||
          valvulaSeleccionada == null ||
          variedadSeleccionada == null ||
          distanciaCamaSeleccionada == null ||
          distanciaPlantaSeleccionada == null ||
          fechaSiembra == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa todos los campos')),
        );
        return;
      }

      // Validaciones adicionales del área (defensa en profundidad)
      final areaParsed = _parseArea(_areaController.text);
      final max = _areaMaximaValvula();

      if (areaParsed == null || areaParsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Área inválida: debe ser > 0 y con . o ,'),
          ),
        );
        return;
      }
      if (valvulaSeleccionada == null || max == null) {
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

      // NUEVA VALIDACIÓN: suma de áreas ya sembradas (ignorando polinizadores)
      if (variedadSeleccionada == null ||
          variedadSeleccionada!.esPolinizador == false) {
        final areaUsada = _areaUsadaEnValvula(valvulaSeleccionada!.id);
        final areaDisponible = valvulaSeleccionada!.area - areaUsada;
        if (areaParsed > areaDisponible) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'El área excede el disponible en la válvula '
                '(Disponible: ${areaDisponible.toStringAsFixed(2)})',
              ),
            ),
          );
          //return 'El área excede el disponible en la válvula (Disponible: ${areaDisponible.toStringAsFixed(2)})';
          return;
        }
      }
      final boxBoletas = Hive.box<Boleta>('boletas');
      final userId = await getCurrentUserId();

      final nuevaBoleta = Boleta(
        id: DateTime.now().millisecondsSinceEpoch,
        productorId: widget.productorId,
        fincaId: fincaSeleccionada!.id,
        loteId: loteSeleccionado!.id,
        valvulaId: valvulaSeleccionada!.id,
        distanciaCama: distanciaCamaSeleccionada!.valor,
        distanciaPlanta: distanciaPlantaSeleccionada!.valor,
        variedad: variedadSeleccionada!.nombre,
        variedadId: variedadSeleccionada!.id,
        areaReal: areaParsed,
        fechaSiembra: (fechaSiembra ?? DateTime.now()),
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lotesSemilla: _lotesSemillaController.text,
        caracteristicaId: caracteristicaSeleccionada?.id,
      );

      await boxBoletas.add(nuevaBoleta);

      await OutboxService.enqueueBoleta(nuevaBoleta);
      await OutboxService.trySyncAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Boleta guardada localmente')),
      );
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error al guardar boleta: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar boleta: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxValvula = _areaMaximaValvula();

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Boleta')),
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

              // Ayuda visual con el área máxima de la válvula
              if (valvulaSeleccionada != null && maxValvula != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Área máx. válvula: ${maxValvula.toStringAsFixed(2)}',
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
                    caracteristicaSeleccionada =
                        null; // limpiar selección al cambiar variedad

                    if (variedad == null) {
                      // sin variedad: no mostrar nada
                      caracteristicasFiltradas = [];
                    } else if (variedad.esPolinizador == true) {
                      // SOLO tipo POLINIZADOR_RATIO
                      caracteristicasFiltradas = caracteristicas
                          .where((c) => c.tipo == 'POLINIZADOR_RATIO')
                          .toList();
                    } else {
                      // variedad NO polinizadora: quitar POLINIZADOR_RATIO
                      caracteristicasFiltradas = caracteristicas
                          .where((c) => c.tipo != 'POLINIZADOR_RATIO')
                          .toList();
                    }
                  });
                },
                validator: (value) =>
                    value == null ? 'Seleccione una variedad' : null,
              ),
              const SizedBox(height: 12),
              // Campo Autocomplete para lotes_semilla (sugiere coincidencias de otras boletas)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final input = textEditingValue.text.toLowerCase();
                    if (input.isEmpty) return const Iterable<String>.empty();
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<DistanciaCama>(
                      decoration: const InputDecoration(
                        labelText: 'Dist. Cama (cm)',
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
                      onChanged: (d) {
                        setState(() {
                          distanciaCamaSeleccionada = d;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Seleccione una distancia de cama'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<DistanciaPlanta>(
                      decoration: const InputDecoration(
                        labelText: 'Dist. Planta (cm)',
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
                      onChanged: (d) {
                        setState(() {
                          distanciaPlantaSeleccionada = d;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Seleccione una distancia de planta'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Característica de siembra
              DropdownButtonFormField<CaracteristicaSiembra>(
                decoration: const InputDecoration(
                  labelText: 'Característica de siembra',
                ),
                value: caracteristicaSeleccionada,
                items: caracteristicasFiltradas
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.nombre} '),
                      ),
                    )
                    .toList(),
                onChanged: (c) {
                  setState(() {
                    caracteristicaSeleccionada = c;
                  });
                },
                // Si quieres que sea opcional, no pongas validator
                // validator: (value) =>
                //     value == null ? 'Seleccione una característica' : null,
              ),
              const SizedBox(height: 16),
              // ===== CAMPO ÁREA con inputFormatters y validator =====
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Área real'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  // Solo dígitos y un separador decimal . o ,
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
                  if (area <= 0) {
                    return 'El área debe ser mayor a 0';
                  }
                  final max = _areaMaximaValvula();
                  if (valvulaSeleccionada == null || max == null) {
                    return 'Seleccione una válvula con área válida';
                  }
                  if (area > max) {
                    return 'No puede ser mayor al área de la válvula (${max.toStringAsFixed(2)})';
                  }

                  if (variedadSeleccionada == null ||
                      variedadSeleccionada!.esPolinizador == false) {
                    final areaIngresada = double.parse(
                      _areaController.text.replaceAll(',', '.'),
                    );

                    final areaUsada = _areaUsadaEnValvula(
                      valvulaSeleccionada!.id,
                    );
                    final areaDisponible =
                        valvulaSeleccionada!.area - areaUsada;

                    if (areaIngresada > areaDisponible) {
                      return 'Área excede el disponible en válvula (Disponible: ${areaDisponible.toStringAsFixed(2)})';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              ListTile(
                title: Text(
                  fechaSiembra == null
                      ? 'Seleccione la fecha de siembra'
                      : 'Fecha: ${fechaSiembra!.day}/${fechaSiembra!.month}/${fechaSiembra!.year}',
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
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saving ? null : guardarBoleta,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar Boleta'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _areaUsadaEnValvula(int valvulaId, {int? excluirBoletaId}) {
    final boxBoletas = Hive.box<Boleta>('boletas');
    final boxVariedades = Hive.box<Variedad>('variedades');

    double sum = 0.0;

    for (final b in boxBoletas.values) {
      if (b.valvulaId != valvulaId) continue;

      // 👉 En edición, excluir la boleta actual
      if (excluirBoletaId != null && b.id == excluirBoletaId) continue;

      try {
        final variedad = boxVariedades.values.firstWhere(
          (v) => v.id == b.variedadId,
          orElse: () => Variedad(id: -1, nombre: '', esPolinizador: false),
        );
        // 👉 Polinizadores NO consumen área
        if (variedad.esPolinizador == true) continue;
      } catch (_) {
        // compatibilidad hacia atrás
      }

      sum += b.areaReal;
    }

    return sum;
  }
}
