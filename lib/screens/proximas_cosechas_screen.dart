import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/boleta.dart';
import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';
import '../services/outbox_service.dart';

class ProximasCosechasScreen extends StatefulWidget {
  final int? productorId; // opcional si quieres filtrar por productor

  const ProximasCosechasScreen({super.key, this.productorId});

  @override
  State<ProximasCosechasScreen> createState() => _ProximasCosechasScreenState();
}

class _ProximasCosechasScreenState extends State<ProximasCosechasScreen> {
  late Future<Box<Boleta>> _boxFuture;

  // catálogos en memoria
  Map<int, String> _fincas = {};
  Map<int, String> _lotes = {};
  Map<int, String> _valvulas = {};
  Map<int, String> _variedades = {};

  @override
  void initState() {
    super.initState();
    _boxFuture = _openBoletasBox();
    _cargarCatalogos();
  }

  Future<Box<Boleta>> _openBoletasBox() async {
    if (Hive.isBoxOpen('boletas')) {
      return Hive.box<Boleta>('boletas');
    }
    return Hive.openBox<Boleta>('boletas');
  }

  Future<void> _cargarCatalogos() async {
    // abrimos cajas necesarias (si no están abiertas)
    final boxFincas = Hive.isBoxOpen('fincas')
        ? Hive.box<Finca>('fincas')
        : await Hive.openBox<Finca>('fincas');
    final boxLotes = Hive.isBoxOpen('lotes')
        ? Hive.box<Lote>('lotes')
        : await Hive.openBox<Lote>('lotes');
    final boxValvulas = Hive.isBoxOpen('valvulas')
        ? Hive.box<Valvula>('valvulas')
        : await Hive.openBox<Valvula>('valvulas');
    final boxVariedades = Hive.isBoxOpen('variedades')
        ? Hive.box<Variedad>('variedades')
        : await Hive.openBox<Variedad>('variedades');

    setState(() {
      _fincas = {for (final f in boxFincas.values) f.id: f.nombre};
      _lotes = {for (final l in boxLotes.values) l.id: l.nombre};
      _valvulas = {for (final v in boxValvulas.values) v.id: v.nombre};
      _variedades = {for (final v in boxVariedades.values) v.id: v.nombre};
    });
  }

  String _fmtFecha(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  int? _diasRestantes(DateTime? fechaEstimada) {
    if (fechaEstimada == null) return null;
    final hoy = DateTime.now();
    final hd = DateTime(hoy.year, hoy.month, hoy.day);
    final fd = DateTime(
      fechaEstimada.year,
      fechaEstimada.month,
      fechaEstimada.day,
    );
    return fd.difference(hd).inDays;
  }

  Future<void> _editarCiclo(Boleta b) async {
    final controller = TextEditingController(
      text: (b.cicloPromedio ?? 0).toString(),
    );

    final nuevo = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar ciclo promedio'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ciclo promedio (días)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final txt = controller.text.trim();
                final val = int.tryParse(txt);
                if (val == null || val <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingrese un número de días válido (> 0)'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, val);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (nuevo == null) return;

    b
      ..cicloPromedio = nuevo
      ..notif32Enviada = null
      ..notif50Enviada = null
      ..updatedAt = DateTime.now();
    await b.save();

    await OutboxService.enqueueBoleta(b);
    await OutboxService.trySyncAll();

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Próximas cosechas')),
      body: FutureBuilder<Box<Boleta>>(
        future: _boxFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error cargando boletas: ${snap.error}'));
          }

          final box = snap.data!;

          // DEBUG: cuántas boletas hay
          /* final all = box.values.toList();
          debugPrint('BOLETAS EN BOX: ${all.length}');
          for (final b in all) {
            debugPrint(
              'Boleta id=${b.id} prod=${b.productorId} '
              'fechaSiembra=${b.fechaSiembra} ciclo=${b.cicloPromedio}',
            );
          }*/

          // Solo productorId (si viene) y que tenga fecha/ciclo válido
          final todas =
              box.values.where((b) {
                if (widget.productorId != null &&
                    b.productorId != widget.productorId) {
                  return false;
                }
                if (b.fechaSiembra == null) return false;
                if (b.cicloPromedio == null || b.cicloPromedio! <= 0) {
                  return false;
                }
                return true;
              }).toList()..sort((a, b) {
                final sa = DateTime(
                  a.fechaSiembra!.year,
                  a.fechaSiembra!.month,
                  a.fechaSiembra!.day,
                ).add(Duration(days: a.cicloPromedio ?? 0));
                final sb = DateTime(
                  b.fechaSiembra!.year,
                  b.fechaSiembra!.month,
                  b.fechaSiembra!.day,
                ).add(Duration(days: b.cicloPromedio ?? 0));
                return sa.compareTo(sb);
              });

          if (todas.isEmpty) {
            return const Center(
              child: Text(
                'No hay boletas con fecha de siembra y ciclo válido.',
              ),
            );
          }

          return ListView.separated(
            itemCount: todas.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final bo = todas[index];
              final siembra = DateTime(
                bo.fechaSiembra!.year,
                bo.fechaSiembra!.month,
                bo.fechaSiembra!.day,
              );
              final cosecha = siembra.add(
                Duration(days: bo.cicloPromedio ?? 0),
              );
              final dias = _diasRestantes(cosecha);

              // nombres desde catálogos
              final fincaNombre = _fincas[bo.fincaId] ?? 'Finca ${bo.fincaId}';
              final loteNombre = _lotes[bo.loteId] ?? 'Lote ${bo.loteId}';
              final valvulaNombre =
                  _valvulas[bo.valvulaId] ?? 'Válvula ${bo.valvulaId}';
              final variedadNombre = bo.variedadId != null
                  ? (_variedades[bo.variedadId!] ??
                        bo.variedad ??
                        'Variedad ${bo.variedadId}')
                  : (bo.variedad ?? '-');

              Color chipColor;
              Color textColor;
              if (dias == null) {
                chipColor = Colors.grey.shade200;
                textColor = Colors.grey.shade800;
              } else if (dias < 0) {
                chipColor = Colors.red.shade100;
                textColor = Colors.red.shade800;
              } else if (dias <= 7) {
                chipColor = Colors.orange.shade100;
                textColor = Colors.orange.shade800;
              } else {
                chipColor = Colors.green.shade100;
                textColor = Colors.green.shade800;
              }

              return ListTile(
                title: Text(
                  '$fincaNombre - $loteNombre - $valvulaNombre',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Variedad: $variedadNombre',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Siembra: ${_fmtFecha(bo.fechaSiembra)}'
                      '  •  Ciclo: ${bo.cicloPromedio ?? '-'} días',
                    ),
                    Text('Cosecha estimada: ${_fmtFecha(cosecha)}'),
                    if (dias != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          dias < 0
                              ? 'Cosecha pasada hace ${-dias} días'
                              : 'Faltan $dias días',
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar ciclo',
                  onPressed: () => _editarCiclo(bo),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
