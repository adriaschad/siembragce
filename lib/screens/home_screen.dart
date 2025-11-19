import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/boleta.dart';
import '../models/variedad.dart';
import '../services/outbox_service.dart';

import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  final String? token;
  final int productorId;
  const HomeScreen({super.key, this.token, required this.productorId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum Periodo { semana, mes, rango }

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<Box<Boleta>> _boxFuture;

  Periodo _periodo = Periodo.semana;
  DateTime? _desde;
  DateTime? _hasta;

  // --- Helpers de saneo ---
  static bool _sanitizedOnce = false;

  // Mapa de id de variedad a nombre de variedad
  Map<int, String> _mapVariedades = {};

  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) {
      // epoch segundos o milisegundos
      final isSeconds = v < 100000000000;
      return DateTime.fromMillisecondsSinceEpoch(isSeconds ? v * 1000 : v);
    }
    if (v is String) {
      final iso = DateTime.tryParse(v);
      if (iso != null) return iso;
      // intenta "yyyy-MM-dd HH:mm:ss"
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

  Future<void> _sanitizeBoletas(Box<Boleta> box) async {
    if (_sanitizedOnce) return;
    _sanitizedOnce = true;

    for (var i = 0; i < box.length; i++) {
      final bo = box.getAt(i);
      if (bo == null) continue;

      var changed = false;

      // fechaSiembra
      final fs = _asDateTime(bo.fechaSiembra);
      if (fs == null) {
        final hoy = DateTime.now();
        bo.fechaSiembra = DateTime(hoy.year, hoy.month, hoy.day);
        changed = true;
      } else if (bo.fechaSiembra is! DateTime) {
        bo.fechaSiembra = fs;
        changed = true;
      }

      // createdAt (si no existe o viene sucio)
      try {
        final ca = _asDateTime(bo.createdAt);
        if (ca == null) {
          bo.createdAt = bo.fechaSiembra;
          changed = true;
        } else if (bo.createdAt is! DateTime) {
          bo.createdAt = ca;
          changed = true;
        }
      } catch (_) {}

      // updatedAt (si tu modelo lo tiene)
      try {
        final ua = _asDateTime(bo.updatedAt);
        if (ua == null) {
          bo.updatedAt = bo.createdAt ?? bo.fechaSiembra;
          changed = true;
        } else if (bo.updatedAt is! DateTime) {
          bo.updatedAt = ua;
          changed = true;
        }
      } catch (_) {}

      if (changed) {
        await box.putAt(i, bo);
      }

      if (i % 200 == 0) {
        await Future.delayed(Duration.zero);
      }
    }
  }

  Future<void> _cargarVariedades() async {
    final boxVariedades = await Hive.openBox<Variedad>('variedades');
    setState(() {
      _mapVariedades = {for (var v in boxVariedades.values) v.id: v.nombre};
    });
  }

  // --- Ciclo de vida ---
  @override
  void initState() {
    super.initState();
    _boxFuture = _ensureBoletasBox();
    _cargarVariedades();
    WidgetsBinding.instance.addObserver(this);
    _initPeriodoPorDefecto();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      OutboxService.trySyncAll();
      _cargarVariedades(); // refresca variedades si sincronizaste offline
    }
  }

  Future<Box<Boleta>> _ensureBoletasBox() async {
    try {
      if (Hive.isBoxOpen('boletas')) {
        final b = Hive.box<Boleta>('boletas');
        if (b.isOpen) {
          await _sanitizeBoletas(b);
          return b;
        }
        await b.close();
      }
      final opened = await Hive.openBox<Boleta>('boletas');
      await _sanitizeBoletas(opened);
      return opened;
    } catch (e, st) {
      debugPrint('[BOLETAS] Error al abrir box tipada: $e\n$st');
      try {
        final raw = await Hive.openBox('boletas');
        debugPrint('[BOLETAS] Raw box abierta. length=${raw.length}');
        final limit = raw.length < 10 ? raw.length : 10;
        for (var i = 0; i < limit; i++) {
          final v = raw.getAt(i);
          debugPrint('[BOLETAS] raw[$i] type=${v.runtimeType} value=$v');
        }
        await raw.close();
      } catch (e2, st2) {
        debugPrint('[BOLETAS] No se pudo abrir raw box: $e2\n$st2');
      }
      rethrow;
    }
  }

  void _initPeriodoPorDefecto() {
    final hoy = DateTime.now();
    switch (_periodo) {
      case Periodo.semana:
        final inicioSemana = DateTime(
          hoy.year,
          hoy.month,
          hoy.day,
        ).subtract(Duration(days: hoy.weekday - 1));
        _desde = inicioSemana;
        _hasta = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59, 999);
        break;
      case Periodo.mes:
        final inicioMes = DateTime(hoy.year, hoy.month, 1);
        _desde = inicioMes;
        _hasta = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59, 999);
        break;
      case Periodo.rango:
        final d = hoy.subtract(const Duration(days: 6));
        _desde = DateTime(d.year, d.month, d.day);
        _hasta = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59, 999);
        break;
    }
  }

  Future<void> _pickFecha({required bool esDesde}) async {
    final hoy = DateTime.now();
    final initial = (esDesde ? _desde : _hasta) ?? hoy;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(hoy.year - 5),
      lastDate: DateTime(hoy.year + 1),
    );
    if (picked != null) {
      setState(() {
        if (esDesde) {
          _desde = DateTime(picked.year, picked.month, picked.day);
          if (_hasta != null && _hasta!.isBefore(_desde!)) {
            _hasta = DateTime(
              _desde!.year,
              _desde!.month,
              _desde!.day,
              23,
              59,
              59,
              999,
            );
          }
        } else {
          _hasta = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            59,
            999,
          );
          if (_desde != null && _hasta!.isBefore(_desde!)) {
            _desde = DateTime(_hasta!.year, _hasta!.month, _hasta!.day);
          }
        }
      });
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /*String _fmtDateTime(DateTime? d) {
    if (d == null) return 'N/D';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${_fmt(d)} $h:$m';
  }*/

  /*bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }*/

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final bool offline = (args?['offline'] as bool?) ?? false;

    final theme = Theme.of(context);
    const brand = Color(0xFF8ABA15);

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: brand),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Menú',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Crear Boleta'),
              onTap: () async {
                final r = await Navigator.pushNamed(
                  context,
                  '/crear_boleta',
                  arguments: {
                    'token': widget.token,
                    'productorId': widget.productorId,
                  },
                );
                if (r == true && mounted) setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Ver Boletas'),
              onTap: () async {
                final r = await Navigator.pushNamed(
                  context,
                  '/ver_boletas',
                  arguments: {
                    'token': widget.token,
                    'productorId': widget.productorId,
                  },
                );
                if (r == true && mounted) setState(() {});
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.power_settings_new, color: Colors.red),
              title: const Text('Salir'),
              onTap: () async {
                Navigator.of(context).pop();
                await Future.delayed(const Duration(milliseconds: 120));
                SystemNavigator.pop();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(title: const Text('Dashboard')),
      body: Column(
        children: [
          if (offline)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 18),
                  SizedBox(width: 8),
                  Text('Modo offline: usando datos locales'),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<Box<Boleta>>(
              future: _boxFuture,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Error abriendo boletas: ${snap.error}'),
                  );
                }

                final box = snap.data!;

                return RefreshIndicator(
                  onRefresh: () async {
                    await OutboxService.trySyncAll();
                    if (mounted) {
                      await _cargarVariedades();
                      setState(() {});
                    }
                  },
                  child: ValueListenableBuilder<Box<Boleta>>(
                    valueListenable: box.listenable(),
                    builder: (_, b, __) {
                      if (_desde == null || _hasta == null)
                        _initPeriodoPorDefecto();
                      final desde = _desde!;
                      final hasta = _hasta!;
                      final pid = widget.productorId;

                      final todas = b.values.where((bo) {
                        if (bo.productorId != pid) return false;
                        final f = _asDateTime(bo.fechaSiembra);
                        return f != null;
                      }).toList();

                      bool inRange(DateTime d) =>
                          !d.isBefore(desde) && !d.isAfter(hasta);

                      final enRango = todas.where((bo) {
                        final f = _asDateTime(bo.fechaSiembra)!;
                        return inRange(f);
                      }).toList();

                      final totalBoletasRango = enRango.length;
                      final double totalAreaRango = enRango.fold(
                        0.0,
                        (sum, bo) => sum + bo.areaReal,
                      );

                      final totalBoletasAll = todas.length;
                      final double totalAreaAll = todas.fold(
                        0.0,
                        (sum, bo) => sum + bo.areaReal,
                      );

                      // --- Agrupa por variedadId (y luego busca el nombre)
                      final Map<int, double> areaPorVariedad = {};
                      for (final bo in enRango) {
                        final vId = bo.variedadId;
                        if (vId == null) continue;
                        areaPorVariedad[vId] =
                            (areaPorVariedad[vId] ?? 0) + bo.areaReal;
                      }
                      final double maxVarArea = areaPorVariedad.values.isEmpty
                          ? 0.0
                          : areaPorVariedad.values.reduce(
                              (a, b) => a > b ? a : b,
                            );

                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Botones arriba
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      backgroundColor: brand,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      final r = await Navigator.pushNamed(
                                        context,
                                        '/crear_boleta',
                                        arguments: {
                                          'token': widget.token,
                                          'productorId': widget.productorId,
                                        },
                                      );
                                      if (r == true && mounted) setState(() {});
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Nueva boleta'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: const BorderSide(color: brand),
                                      foregroundColor: brand,
                                    ),
                                    onPressed: () async {
                                      final r = await Navigator.pushNamed(
                                        context,
                                        '/ver_boletas',
                                        arguments: {
                                          'token': widget.token,
                                          'productorId': widget.productorId,
                                        },
                                      );
                                      if (r == true && mounted) setState(() {});
                                    },
                                    icon: const Icon(Icons.list),
                                    label: const Text('Ver boletas'),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Selector de periodo
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Periodo',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<Periodo>(
                                                value: _periodo,
                                                decoration:
                                                    const InputDecoration(
                                                      isDense: true,
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: Periodo.semana,
                                                    child: Text('Semana'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: Periodo.mes,
                                                    child: Text('Mes'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: Periodo.rango,
                                                    child: Text(
                                                      'Rango personalizado',
                                                    ),
                                                  ),
                                                ],
                                                onChanged: (p) {
                                                  if (p == null) return;
                                                  setState(() {
                                                    _periodo = p;
                                                    _initPeriodoPorDefecto();
                                                  });
                                                },
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _periodo == Periodo.rango
                                                ? () =>
                                                      _pickFecha(esDesde: true)
                                                : null,
                                            child: Text(
                                              _desde == null
                                                  ? 'Desde'
                                                  : _fmt(_desde!),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _periodo == Periodo.rango
                                                ? () =>
                                                      _pickFecha(esDesde: false)
                                                : null,
                                            child: Text(
                                              _hasta == null
                                                  ? 'Hasta'
                                                  : _fmt(_hasta!),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_desde != null && _hasta != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Mostrando: ${_fmt(_desde!)}  –  ${_fmt(_hasta!)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: theme.hintColor),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // KPIs oscuros
                            GridView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.25,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              children: [
                                _StatCard(
                                  title: 'Boletas (rango)',
                                  valueWidget: _AnimatedCountInt(
                                    end: totalBoletasRango,
                                  ),
                                  backgroundColor: Colors.black.withAlpha(200),
                                  icon: Icons.assignment_turned_in,
                                  footerWidget: _AnimatedCountDoubleLabel(
                                    labelPrefix: 'Área: ',
                                    end: totalAreaRango,
                                    suffix: ' ha',
                                  ),
                                ),
                                _StatCard(
                                  title: 'Boletas (total)',
                                  valueWidget: _AnimatedCountInt(
                                    end: totalBoletasAll,
                                  ),
                                  backgroundColor: Colors.black.withAlpha(200),
                                  icon: Icons.fact_check,
                                  footerWidget: _AnimatedCountDoubleLabel(
                                    labelPrefix: 'Área: ',
                                    end: totalAreaAll,
                                    suffix: ' ha',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Área por variedad (rango)
                            Text(
                              'Área por variedad (rango)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            if (areaPorVariedad.isEmpty)
                              Card(
                                elevation: 0,
                                color: theme.colorScheme.surfaceVariant
                                    .withAlpha(100),
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: Text('Sin registros en el periodo'),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: [
                                  ...areaPorVariedad.entries.map((e) {
                                    final nombreVariedad =
                                        _mapVariedades[e.key] ??
                                        'Variedad ${e.key}';
                                    final propor = maxVarArea == 0
                                        ? 0.0
                                        : (e.value / maxVarArea)
                                              .clamp(0.0, 1.0)
                                              .toDouble();
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    nombreVariedad,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  '${e.value.toStringAsFixed(2)} ha',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: _AnimatedLinearProgress(
                                                value: propor,
                                                minHeight: 8,
                                                backgroundColor: theme
                                                    .colorScheme
                                                    .surfaceVariant
                                                    .withAlpha(150),
                                                valueColor: brand,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Total boletas en el periodo: $totalBoletasRango',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --------- Widgets de apoyo ---------
class _StatCard extends StatelessWidget {
  final String title;
  final Widget valueWidget;
  final Color backgroundColor;
  final IconData icon;
  final Widget? footerWidget;

  const _StatCard({
    required this.title,
    required this.valueWidget,
    required this.backgroundColor,
    required this.icon,
    this.footerWidget,
  });

  @override
  Widget build(BuildContext context) {
    const double valueAreaHeight = 36;
    const double footerAreaHeight = 28;
    const double pad = 12;
    const double iconSize = 22;

    return Container(
      padding: const EdgeInsets.fromLTRB(pad, pad, pad, pad),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 8,
            spreadRadius: 0.3,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: iconSize, color: Colors.white.withAlpha(240)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: valueAreaHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: valueWidget),
              ),
            ),
            if (footerWidget != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: footerAreaHeight,
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: _FooterWrapper(child: footerWidget!),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FooterWrapper extends StatelessWidget {
  final Widget child;
  const _FooterWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    if (child is Text) {
      final t = child as Text;
      return Text(
        t.data ?? '',
        maxLines: t.maxLines ?? 2,
        overflow: t.overflow ?? TextOverflow.ellipsis,
        softWrap: true,
        style: t.style,
      );
    }
    return child;
  }
}

class _AnimatedCountInt extends StatefulWidget {
  final int end;
  final Duration duration;
  const _AnimatedCountInt({
    required this.end,
    this.duration = const Duration(milliseconds: 600),
    Key? key,
  }) : super(key: key);

  @override
  State<_AnimatedCountInt> createState() => _AnimatedCountIntState();
}

class _AnimatedCountIntState extends State<_AnimatedCountInt> {
  int _old = 0;
  @override
  void didUpdateWidget(covariant _AnimatedCountInt oldWidget) {
    _old = oldWidget.end;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _old.toDouble(), end: widget.end.toDouble()),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => Text(
        value.round().toString(),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AnimatedCountDoubleLabel extends StatefulWidget {
  final String labelPrefix;
  final double end;
  final String suffix;
  final int decimals;
  final Duration duration;

  const _AnimatedCountDoubleLabel({
    required this.labelPrefix,
    required this.end,
    required this.suffix,
    this.decimals = 2,
    this.duration = const Duration(milliseconds: 700),
    Key? key,
  }) : super(key: key);

  @override
  State<_AnimatedCountDoubleLabel> createState() =>
      _AnimatedCountDoubleLabelState();
}

class _AnimatedCountDoubleLabelState extends State<_AnimatedCountDoubleLabel> {
  double _old = 0;
  @override
  void didUpdateWidget(covariant _AnimatedCountDoubleLabel oldWidget) {
    _old = oldWidget.end;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _old, end: widget.end),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => Text(
        '${widget.labelPrefix}${value.toStringAsFixed(widget.decimals)}${widget.suffix}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _AnimatedLinearProgress extends StatelessWidget {
  final double value;
  final double minHeight;
  final Color backgroundColor;
  final Color valueColor;
  final Duration duration;

  const _AnimatedLinearProgress({
    required this.value,
    this.minHeight = 8,
    required this.backgroundColor,
    required this.valueColor,
    this.duration = const Duration(milliseconds: 500),
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => LinearProgressIndicator(
        value: v,
        minHeight: minHeight,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation<Color>(valueColor),
      ),
    );
  }
}
