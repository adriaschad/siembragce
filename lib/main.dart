import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show FlutterError, PlatformDispatcher;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart' show TypeAdapter;

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/crear_boleta_screen.dart';
import 'screens/lista_boletas_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'services/outbox_service.dart';

// Modelos / Adapters
import 'models/finca.dart';
import 'models/lote.dart';
import 'models/boleta.dart';
import 'models/distancia_planta.dart';
import 'models/distancia_cama.dart';
import 'models/valvula.dart';
import 'models/variedad.dart';
import 'models/variedad_productor.dart';
import 'models/productor_distancia_cama.dart';
import 'models/productor_distancia_planta.dart';

// ---------- util ----------
void unawaited(Future<void> f) {}

void _registerAdapterSafe<T>(TypeAdapter<T> a) {
  if (!Hive.isAdapterRegistered(a.typeId)) {
    Hive.registerAdapter<T>(a);
  }
}

Future<void> _earlyInit() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Registro idempotente (no revienta si reintentas)
  _registerAdapterSafe(FincaAdapter());
  _registerAdapterSafe(LoteAdapter());
  _registerAdapterSafe(BoletaAdapter());
  _registerAdapterSafe(DistanciaPlantaAdapter());
  _registerAdapterSafe(DistanciaCamaAdapter());
  _registerAdapterSafe(ValvulaAdapter());
  _registerAdapterSafe(VariedadAdapter());
  _registerAdapterSafe(VariedadProductorAdapter());
  _registerAdapterSafe(ProductorDistanciaCamaAdapter());
  _registerAdapterSafe(ProductorDistanciaPlantaAdapter());

  // ⚠️ No abras cajas pesadas aquí para no bloquear el primer frame.
}

Future<void> _postFrameInit() async {
  try {
    // Opcional: “calentar” cajas en background (no es obligatorio)
    // unawaited(Hive.openBox<Lote>('lotes'));
    // unawaited(Hive.openBox<Valvula>('valvulas'));
    // unawaited(Hive.openBox<Boleta>('boletas'));

    final prefs = await SharedPreferences.getInstance();
    final hasToken = (prefs.getString('user_token') ?? '').isNotEmpty;

    if (hasToken) {
      unawaited(OutboxService.trySyncAll());
    }
    unawaited(OutboxService.startConnectivitySync());
  } catch (e, st) {
    // No bloquees la UI por esto
    // ignore: avoid_print
    print('postFrame init error: $e\n$st');
  }
}

Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: avoid_print
    print('Zoned error: $error\n$stack');
    return false;
  };

  await _earlyInit();

  runApp(const MyApp());

  // Haz el resto después del primer frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_postFrameInit());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Intención Siembra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8ABA15)),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return HomeScreen(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
          );
        },
        '/crear_boleta': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return CrearBoletaScreen(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
          );
        },
        '/ver_boletas': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return ListaBoletasScreen(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
          );
        },
      },
    );
  }
}
