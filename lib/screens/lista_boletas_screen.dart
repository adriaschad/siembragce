import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/boleta.dart';
import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';

import 'editar_boleta_screen.dart';

class ListaBoletasScreen extends StatefulWidget {
  final String? token;
  final int productorId;
  const ListaBoletasScreen({super.key, required this.productorId, this.token});

  @override
  State<ListaBoletasScreen> createState() => _ListaBoletasScreenState();
}

class _ListaBoletasScreenState extends State<ListaBoletasScreen> {
  List<Boleta> boletas = [];

  // Mapas para traducir IDs -> nombres
  Map<int, String> _fincaNombre = {};
  Map<int, String> _loteNombre = {};
  Map<int, String> _valvulaNombre = {};
  Map<int, String> _variedadNombre = {};

  @override
  void initState() {
    super.initState();
    cargarBoletas();
  }

  // Normaliza String/DateTime -> DateTime?
  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      final iso = DateTime.tryParse(v);
      if (iso != null) return iso;
      // "yyyy-MM-dd HH:mm:ss"
      final parts = v.split(RegExp(r'[\sT]'));
      if (parts.isNotEmpty) {
        final d = parts.first.split('-');
        if (d.length == 3) {
          final y = int.tryParse(d[0]),
              m = int.tryParse(d[1]),
              day = int.tryParse(d[2]);
          if (y != null && m != null && day != null) return DateTime(y, m, day);
        }
      }
    }
    return null;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${_fmtDate(d)} $h:$m';
  }

  Future<void> cargarBoletas() async {
    // Abre cajas necesarias
    final boxBoletas = Hive.box<Boleta>('boletas');
    final boxFincas = await Hive.openBox<Finca>('fincas');
    final boxLotes = await Hive.openBox<Lote>('lotes');
    final boxValvulas = await Hive.openBox<Valvula>('valvulas');
    final boxVariedades = await Hive.openBox<Variedad>('variedades');

    // Construye mapas ID -> nombre (solo del productor actual para evitar colisiones)
    _fincaNombre = {
      for (final f in boxFincas.values.where(
        (f) => f.productorId == widget.productorId,
      ))
        f.id: f.nombre,
    };
    _loteNombre = {for (final l in boxLotes.values) l.id: l.nombre};
    _valvulaNombre = {for (final v in boxValvulas.values) v.id: v.nombre};
    _variedadNombre = {for (final vr in boxVariedades.values) vr.id: vr.nombre};

    // Filtra boletas del productor y con fecha válida
    final lista = boxBoletas.values.where((b) {
      if (b.productorId != widget.productorId) return false;
      return _asDateTime(b.fechaSiembra) != null;
    }).toList();

    // Ordena por fecha de siembra (desc)
    lista.sort((a, b) {
      final fa = _asDateTime(a.fechaSiembra)!;
      final fb = _asDateTime(b.fechaSiembra)!;
      return fb.compareTo(fa);
    });

    setState(() {
      boletas = lista;
    });
  }

  // Acepta DateTime? — si a es null devuelve false (no es misma fecha)
  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _editarBoleta(Boleta boleta) async {
    // Solo edición si fue creada hoy
    final creadaHoy = _isSameDay(boleta.createdAt, DateTime.now());
    if (!creadaHoy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puede editar boletas creadas hoy')),
      );
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditarBoletaScreen(boleta: boleta, token: widget.token),
      ),
    );

    if (updated == true) {
      await cargarBoletas();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Boleta actualizada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boletas guardadas')),
      body: boletas.isEmpty
          ? const Center(child: Text('No hay boletas guardadas'))
          : ListView.separated(
              itemCount: boletas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final b = boletas[index];

                final fechaSiembra = _asDateTime(b.fechaSiembra)!;
                final fechaStr = _fmtDate(fechaSiembra);

                final fincaStr =
                    _fincaNombre[b.fincaId] ?? 'Finca #${b.fincaId}';
                final loteStr = _loteNombre[b.loteId] ?? 'Lote #${b.loteId}';
                final valvulaStr =
                    _valvulaNombre[b.valvulaId] ?? 'Válvula #${b.valvulaId}';

                final variedadStr =
                    _variedadNombre[b.variedadId] ??
                    'Variedad #${b.variedadId}';

                final creadaHoy = _isSameDay(b.createdAt, DateTime.now());

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListTile(
                    isThreeLine: true,
                    // 👇 Ya NO se abre al tocar la Card completa
                    // onTap: () => _editarBoleta(b),
                    title: Text(
                      'Finca: $fincaStr\nLote: $loteStr\nVálvula: $valvulaStr',
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow
                          .visible, // o TextOverflow.clip si prefieres
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Variedad: $variedadStr\n'
                        'Área: ${b.areaReal.toStringAsFixed(2)} ha  •  Siembra: $fechaStr\n'
                        'Creada: ${b.createdAt != null ? _fmtDateTime(b.createdAt!) : 'Fecha desconocida'}',
                      ),
                    ),
                    trailing: creadaHoy
                        ? IconButton(
                            tooltip: 'Editar boleta',
                            icon: const Icon(Icons.edit, color: Colors.green),
                            onPressed: () => _editarBoleta(b),
                          )
                        : const Tooltip(
                            message: 'Solo editable el día de creación',
                            child: Icon(Icons.lock_clock, color: Colors.grey),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
