import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';

import '../models/boleta_resiembra.dart';
import '../models/valvula.dart';
import '../models/lote.dart';
import '../models/finca.dart';
import '../models/variedad.dart';
import '../services/outbox_service.dart';

class VerBoletasResiembraScreen extends StatefulWidget {
  final String? token;
  final int productorId;

  const VerBoletasResiembraScreen({
    super.key,
    this.token,
    required this.productorId,
  });

  @override
  State<VerBoletasResiembraScreen> createState() =>
      _VerBoletasResiembraScreenState();
}

class _VerBoletasResiembraScreenState extends State<VerBoletasResiembraScreen> {
  late Future<Box<BoletaResiembra>> _boxFuture;
  Map<int, String> _mapFincas = {};
  Map<int, String> _mapLotes = {};
  Map<int, String> _mapValvulas = {};
  Map<int, String> _mapVariedades = {};

  @override
  void initState() {
    super.initState();
    _boxFuture = _ensureBox();
    _cargarCatalogos();
  }

  Future<Box<BoletaResiembra>> _ensureBox() async {
    if (Hive.isBoxOpen('boletas_resiembra')) {
      return Hive.box<BoletaResiembra>('boletas_resiembra');
    }
    return Hive.openBox<BoletaResiembra>('boletas_resiembra');
  }

  Future<void> _cargarCatalogos() async {
    final boxFincas = await Hive.openBox<Finca>('fincas');
    final boxLotes = await Hive.openBox<Lote>('lotes');
    final boxValvulas = await Hive.openBox<Valvula>('valvulas');
    final boxVariedades = await Hive.openBox<Variedad>('variedades');

    setState(() {
      _mapFincas = {for (var f in boxFincas.values) f.id: f.nombre};
      _mapLotes = {for (var l in boxLotes.values) l.id: l.nombre};
      _mapValvulas = {for (var v in boxValvulas.values) v.id: v.nombre};
      _mapVariedades = {for (var v in boxVariedades.values) v.id: v.nombre};
    });
  }

  String _fmtFecha(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  bool _esDeHoy(BoletaResiembra b) {
    final hoy = DateTime.now();
    final c = b.createdAt;
    return c.year == hoy.year && c.month == hoy.month && c.day == hoy.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boletas de Resiembra')),
      body: FutureBuilder<Box<BoletaResiembra>>(
        future: _boxFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error abriendo boletas de resiembra: ${snap.error}'),
            );
          }

          final box = snap.data!;

          return RefreshIndicator(
            onRefresh: () async {
              await OutboxService.trySyncAll();
              if (mounted) {
                await _cargarCatalogos();
                setState(() {});
              }
            },
            child: ValueListenableBuilder<Box<BoletaResiembra>>(
              valueListenable: box.listenable(),
              builder: (_, b, __) {
                final todas =
                    b.values
                        .where((bo) => bo.productorId == widget.productorId)
                        .toList()
                      ..sort(
                        (a, b) => b.fechaSiembra.compareTo(a.fechaSiembra),
                      ); // desc

                if (todas.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 40),
                      Center(
                        child: Text('No hay boletas de resiembra registradas.'),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: todas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final bo = todas[index];

                    final fincaNombre =
                        _mapFincas[bo.fincaId] ?? 'Finca ${bo.fincaId}';
                    final loteNombre =
                        _mapLotes[bo.loteId] ?? 'Lote ${bo.loteId}';
                    final valvulaNombre =
                        _mapValvulas[bo.valvulaId] ?? 'Válvula ${bo.valvulaId}';
                    final variedadNombre =
                        _mapVariedades[bo.variedadId] ??
                        bo.variedad ??
                        'Variedad ${bo.variedadId}';

                    return ListTile(
                      title: Text(
                        variedadNombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$fincaNombre • $loteNombre • $valvulaNombre'),
                          const SizedBox(height: 2),
                          Text(
                            'Fecha: ${_fmtFecha(bo.fechaSiembra)}  •  Semillas: ${bo.cantidadSemillas}',
                          ),
                          if (bo.lotesSemilla.isNotEmpty)
                            Text('Lote semilla: ${bo.lotesSemilla}'),
                          Text(
                            'Área válvula: ${bo.areaValvula.toStringAsFixed(2)} ha  •  Temp: ${bo.temporada}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: _esDeHoy(bo)
                          ? IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar',
                              onPressed: () async {
                                final r = await Navigator.pushNamed(
                                  context,
                                  '/editar_boleta_resiembra',
                                  arguments: {
                                    'token': widget.token,
                                    'boletaResiembra': bo,
                                  },
                                );
                                if (r == true && mounted) setState(() {});
                              },
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
