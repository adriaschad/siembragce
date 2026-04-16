import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show FlutterError, PlatformDispatcher;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart' show TypeAdapter;

import 'package:shared_preferences/shared_preferences.dart';

import 'models/boleta_resiembra.dart';
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
import 'models/boleta_invernadero.dart';
import 'models/caracteristica_siembra.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/crear_boleta_screen.dart';
import 'screens/lista_boletas_screen.dart';
import 'screens/crear_boleta_invernadero_screen.dart';
import 'screens/ver_boletas_invernadero_screen.dart';
import 'screens/editar_boleta_invernadero_screen.dart';
import 'screens/crear_boleta_resiembra_screen.dart';
import 'screens/ver_boletas_resiembra_screen.dart';
import 'screens/editar_boleta_resiembra_screen.dart';
import 'screens/proximas_cosechas_screen.dart'; // IMPORT NUEVO

import 'pages/boleta_muestreo/boleta_muestreo_form.dart';
import 'pages/boleta_muestreo/ver_boletas_muestreo.dart';

import 'services/outbox_service.dart';
import 'services/harvest_notification_service.dart';
import 'services/local_notification_service.dart';

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
  _registerAdapterSafe(BoletaInvernaderoAdapter());
  _registerAdapterSafe(BoletaResiembraAdapter());
  _registerAdapterSafe(CaracteristicaSiembraAdapter());

  // Inicializar notificaciones locales
  //await LocalNotificationService.init();
}

Future<void> _postFrameInit() async {
  try {
    await LocalNotificationService.init();

    final prefs = await SharedPreferences.getInstance();
    final hasToken = (prefs.getString('user_token') ?? '').isNotEmpty;

    if (hasToken) {
      unawaited(OutboxService.trySyncAll());
    }
    unawaited(OutboxService.startConnectivitySync());
    unawaited(HarvestNotificationService.checkAndNotify());
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
    print('Zoned error: $error\n$stack');
    return false;
  };

  try {
    await _earlyInit();
  } catch (e, st) {
    print('earlyInit error: $e\n$st');
  }

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_postFrameInit());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF8ABA15);

    return MaterialApp(
      title: 'Intención Siembra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
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
        '/crear_boleta_invernadero': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return CrearBoletaInvernaderoScreen(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
          );
        },
        '/ver_boletas_invernadero': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return VerBoletasInvernaderoScreen(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
          );
        },
        '/editar_boleta_invernadero': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return EditarBoletaInvernaderoScreen(
            boleta: args['boleta'],
            token: args['token'] as String?,
          );
        },

        // Boleta muestreo: crear + ver
        '/crear_boleta_muestreo': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return BoletaMuestreoForm(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
            boletaMuestreo: args['boletaMuestreo'],
          );
        },
        '/boleta_muestreo_form': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return BoletaMuestreoForm(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
            boletaMuestreo: args['boletaMuestreo'],
          );
        },
        '/ver_boletas_muestreo': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return VerBoletasMuestreoScreen(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
          );
        },

        // NUEVA: Boleta resiembra
        '/crear_boleta_resiembra': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return CrearBoletaResiembraScreen(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
          );
        },
        '/ver_boletas_resiembra': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return VerBoletasResiembraScreen(
            token: args['token'] as String?,
            productorId: (args['productorId'] as int?) ?? 0,
          );
        },
        '/editar_boleta_resiembra': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          final boletaArg = args['boletaResiembra'];
          return EditarBoletaResiembraScreen(
            boleta: boletaArg as BoletaResiembra,
            token: args['token'] as String?,
          );
        },
        '/proximas_cosechas': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return ProximasCosechasScreen(
            productorId: (args['productorId'] as int?),
          );
        },
      },
    );
  }
}
