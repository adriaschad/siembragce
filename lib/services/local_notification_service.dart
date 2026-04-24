import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Inicializa el plugin de notificaciones (llamar una vez al inicio).
  static Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Aquí puedes manejar taps en la notificación si quieres
      },
    );

    _initialized = true;
  }

  /// Muestra una notificación simple.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await init();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'cosechas_channel', // id del canal
          'Próximas cosechas', // nombre del canal
          channelDescription: 'Alertas de próximas cosechas',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, platformDetails);
  }
}
