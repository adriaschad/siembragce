import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // trae listenable()
import 'package:hive/hive.dart';
import 'package:intencion_siembra/services/boxes.dart';

import '../models/boleta_invernadero.dart';
import '../models/finca.dart';
import '../models/lote.dart';
import '../models/valvula.dart';
import '../models/variedad.dart';

class VerBoletasInvernaderoScreen extends StatefulWidget {
  final String? token;
  final int productorId;
  const VerBoletasInvernaderoScreen({
    super.key,
    this.token,
    required this.productorId,
  });

  @override
  State<VerBoletasInvernaderoScreen> createState() =>
      _VerBoletasInvernaderoScreenState();
}

class _VerBoletasInvernaderoScreenState
    extends State<VerBoletasInvernaderoScreen> {
  Box? _box;
  List<Finca> _fincas = [];
  List<Lote> _lotes = [];
  List<Valvula> _valvulas = [];
  List<Variedad> _variedades = [];
  String _query = '';
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _openBoxes();
    final hoy = DateTime.now();
    _desde = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(const Duration(days: 30));
    _hasta = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
  }

  Future<void> _openBoxes() async {
    _box = await Boxes.boletasInvernadero();

    // cargar fincas primero (necesario para filtrar lotes)
    try {
      final boxF = await Hive.openBox<Finca>('fincas');
      _fincas = boxF.values
          .where((f) => f.productorId == widget.productorId)
          .toList();
    } catch (_) {
      _fincas = [];
    }

    try {
      final boxL = await Hive.openBox<Lote>('lotes');
      // filtrar lotes que pertenecen a alguna finca del productor
      final fincaIds = _fincas.map((f) => f.id).toSet();
      _lotes = boxL.values.where((l) => fincaIds.contains(l.fincaId)).toList();
    } catch (_) {
      _lotes = [];
    }

    try {
      final boxV = await Hive.openBox<Valvula>('valvulas');
      _valvulas = boxV.values.toList();
    } catch (_) {
      _valvulas = [];
    }

    try {
      final boxVar = await Hive.openBox<Variedad>('variedades');
      _variedades = boxVar.values.toList();
    } catch (_) {
      _variedades = [];
    }

    setState(() {});
  }

  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) {
      final isSeconds = v < 100000000000;
      return DateTime.fromMillisecondsSinceEpoch(isSeconds ? v * 1000 : v);
    }
    if (v is String) {
      // intenta ISO y "yyyy-MM-dd HH:mm:ss"
      final iso = DateTime.tryParse(v);
      if (iso != null) return iso;
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

  bool _inRange(DateTime d) {
    if (_desde != null && d.isBefore(_desde!)) return false;
    if (_hasta != null && d.isAfter(_hasta!)) return false;
    return true;
  }

  List _filterAndSort(Iterable items) {
    final pid = widget.productorId;
    final q = _query.trim().toLowerCase();
    final list = items.where((raw) {
      try {
        final b = raw;
        final prodId = (b is BoletaInvernadero)
            ? b.productorId
            : (b['productor_id'] ?? b['productorId']);
        if (prodId != pid) return false;
        final fs = _asDateTime(
          (b is BoletaInvernadero)
              ? b.fechaSiembra
              : (b['fecha_siembra'] ?? b['fechaSiembra']),
        );
        if (fs == null) return false;
        if (!_inRange(fs)) return false;

        if (q.isEmpty) return true;

        final loteName = _lookupLoteName(b);
        final valvulaName = _lookupValvulaName(b);
        final variedad = _lookupVariedadName(b);
        final lotesSem = (b is BoletaInvernadero)
            ? (b.lotesSemilla ?? '')
            : ((b['lotes_semilla'] ?? '')?.toString() ?? '');

        return ('$loteName $valvulaName $variedad $lotesSem')
            .toLowerCase()
            .contains(q);
      } catch (_) {
        return false;
      }
    }).toList();

    list.sort((a, b) {
      final da = _asDateTime(
        (a is BoletaInvernadero)
            ? a.fechaSiembra
            : (a['fecha_siembra'] ?? a['fechaSiembra']),
      )!;
      final db = _asDateTime(
        (b is BoletaInvernadero)
            ? b.fechaSiembra
            : (b['fecha_siembra'] ?? b['fechaSiembra']),
      )!;
      return db.compareTo(da); // descendente
    });

    return list;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _lookupFincaName(dynamic b) {
    try {
      final fincaId = (b is BoletaInvernadero)
          ? b.fincaId
          : (b['finca_id'] ?? b['fincaId']);
      final f = _fincas.firstWhere(
        (x) => x.id == fincaId,
        orElse: () => Finca(id: -1, nombre: '-', productorId: -1),
      );
      return f.nombre;
    } catch (_) {
      return '-';
    }
  }

  String _lookupLoteName(dynamic b) {
    try {
      final loteId = (b is BoletaInvernadero)
          ? b.loteId
          : (b['lote_id'] ?? b['loteId']);
      final l = _lotes.firstWhere(
        (x) => x.id == loteId,
        orElse: () => Lote(id: -1, nombre: '-', fincaId: -1),
      );
      return l.nombre;
    } catch (_) {
      try {
        return (b is BoletaInvernadero)
            ? '-'
            : (b['lote'] ?? b['lote_name'] ?? '-').toString();
      } catch (_) {
        return '-';
      }
    }
  }

  String _lookupValvulaName(dynamic b) {
    try {
      final valvId = (b is BoletaInvernadero)
          ? b.valvulaId
          : (b['valvula_id'] ?? b['valvulaId']);
      for (final x in _valvulas) {
        try {
          if (x.id == valvId) return x.nombre;
        } catch (_) {}
      }
      if (b is Map) {
        try {
          return (b['valvula'] ?? '-').toString();
        } catch (_) {}
      }
      return '-';
    } catch (_) {
      return '-';
    }
  }

  String _lookupVariedadName(dynamic b) {
    try {
      final varId = (b is BoletaInvernadero)
          ? b.variedadId
          : (b['variedad_id'] ?? b['variedadId']);
      final v = _variedades.firstWhere(
        (x) => x.id == varId,
        orElse: () => Variedad(id: -1, nombre: '-', esPolinizador: false),
      );
      return v.nombre;
    } catch (_) {
      try {
        return (b is BoletaInvernadero)
            ? (b.variedad ?? '-')
            : (b['variedad'] ?? '-').toString();
      } catch (_) {
        return '-';
      }
    }
  }

  double _lookupArea(dynamic b) {
    try {
      final a = (b is BoletaInvernadero)
          ? b.area
          : (b['area'] ?? b['area_valvula'] ?? b['area_real'] ?? 0);
      if (a is num) return a.toDouble();
      return double.tryParse(a.toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isEditable(dynamic b) {
    // editable sólo si createdAt (o fecha siembra si createdAt no está) es del mismo día que hoy
    final created = _asDateTime(
      (b is BoletaInvernadero)
          ? b.createdAt
          : (b['created_at'] ?? b['createdAt']),
    );
    final fs = _asDateTime(
      (b is BoletaInvernadero)
          ? b.fechaSiembra
          : (b['fecha_siembra'] ?? b['fechaSiembra']),
    );
    final compare = created ?? fs;
    if (compare == null) return false;
    return _isSameDay(compare, DateTime.now());
  }

  int _lookupContenedores(dynamic b) {
    try {
      if (b is BoletaInvernadero) {
        final dyn = b as dynamic;
        final c1 = (dyn.contenedores_1 ?? dyn.contenedores1 ?? 0) as num?;
        final c2 = (dyn.contenedores_2 ?? dyn.contenedores2 ?? 0) as num?;
        final total = ((c1 ?? 0) + (c2 ?? 0)).toInt();
        return total;
      } else {
        final c1 = (b['contenedores_1'] ?? b['contenedores1'] ?? 0);
        final c2 = (b['contenedores_2'] ?? b['contenedores2'] ?? 0);
        final n1 = (c1 is num) ? c1.toInt() : int.tryParse(c1.toString()) ?? 0;
        final n2 = (c2 is num) ? c2.toInt() : int.tryParse(c2.toString()) ?? 0;
        return n1 + n2;
      }
    } catch (_) {
      return 0;
    }
  }

  Widget _buildTile(dynamic b) {
    final fecha = _asDateTime(
      (b is BoletaInvernadero)
          ? b.fechaSiembra
          : (b['fecha_siembra'] ?? b['fechaSiembra']),
    );
    final fincaName = _lookupFincaName(b);
    final loteName = _lookupLoteName(b);
    final valvulaName = _lookupValvulaName(b);
    final variedad = _lookupVariedadName(b);
    final area = _lookupArea(b);
    final editable = _isEditable(b);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(_fmtDate(fecha)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Finca: $fincaName · Lote: $loteName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Válvula: $valvulaName · Variedad: $variedad',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // mostramos el área
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                '${area.toStringAsFixed(2)} ha',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            // icono de edición activo sólo si editable
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: editable
                  ? 'Editar boleta invernadero'
                  : 'Solo se puede editar boletas creadas hoy',
              onPressed: editable
                  ? () async {
                      final r = await Navigator.pushNamed(
                        context,
                        '/editar_boleta_invernadero',
                        arguments: {'token': widget.token, 'boleta': b},
                      );
                      if (r == true) setState(() {});
                    }
                  : null,
            ),
          ],
        ),
        onTap: () async {
          // si se toca la tarjeta, abrimos la edición solo si editable; si no, mostramos detalle (por ahora abrimos la misma pantalla en modo sólo lectura)
          if (editable) {
            final r = await Navigator.pushNamed(
              context,
              '/editar_boleta_invernadero',
              arguments: {'token': widget.token, 'boleta': b},
            );
            if (r == true) setState(() {});
          } else {
            // abrir detalle o mostrar mensaje
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Boleta'),
                content: const Text(
                  'Esta boleta no puede editarse (no fue creada hoy).',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _pickRange(BuildContext ctx) async {
    final picked = await showDateRangePicker(
      context: ctx,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _desde != null && _hasta != null
          ? DateTimeRange(start: _desde!, end: _hasta!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _desde = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        _hasta = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_box == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Boletas Invernadero')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Boletas Invernadero')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // filtros en dos líneas: búsqueda arriba, botones abajo
            Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText:
                        'Buscar por lote / válvula / variedad / lotes semilla',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickRange(context),
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          '${_desde != null ? _fmtDate(_desde) : '-'} → ${_hasta != null ? _fmtDate(_hasta) : '-'}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _box!.listenable(),
                builder: (_, __, ___) {
                  final all = _box!.values;
                  final filtered = _filterAndSort(all);
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay boletas de invernadero en el periodo',
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildTile(filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Crear Boleta Invernadero',
        onPressed: () async {
          final r = await Navigator.pushNamed(
            context,
            '/crear_boleta_invernadero',
            arguments: {
              'token': widget.token,
              'productorId': widget.productorId,
            },
          );
          if (r == true) setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
