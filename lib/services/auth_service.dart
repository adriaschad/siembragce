// lib/services/auth_service.dart
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class LoginResult {
  final String? token;
  final int userId;
  final int? productorId;
  final bool offline;

  LoginResult({
    required this.token,
    required this.userId,
    required this.productorId,
    required this.offline,
  });
}

class AuthService {
  static const _kTokenKey = 'user_token';
  static String _kHashKey(String email) => 'offline_hash_$email';
  static String _kUserKey(String email) => 'offline_userId_$email';
  static String _kProdKey(String email) => 'offline_productorId_$email';

  /// Intenta login online; si falla por red, intenta offline.
  static Future<LoginResult?> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1) Intento ONLINE
      final res = await ApiService.login(email, password);
      if (res == null) return null;

      final token = res['token'] as String?;
      final user = (res['user'] as Map?) ?? {};
      final userId = user['id'] as int;
      final productorId = user['productorId'] as int?;

      if (token == null || productorId == null) {
        throw ApiException('Respuesta de login inválida.');
      }

      // Guardar token y email recordado
      await prefs.setString(_kTokenKey, token);
      await prefs.setString('remembered_email', email);

      // Generar/verificar hash OFFLINE (bcrypt local)
      final newHash = BCrypt.hashpw(password, BCrypt.gensalt());
      await prefs.setString(_kHashKey(email), newHash);
      await prefs.setInt(_kUserKey(email), userId);
      await prefs.setInt(_kProdKey(email), productorId);

      return LoginResult(
        token: token,
        userId: userId,
        productorId: productorId,
        offline: false,
      );
    } on ApiException catch (e) {
      // Si es 401/403 -> credenciales incorrectas: no habilitamos offline
      if (e.statusCode == 401 || e.statusCode == 403) rethrow;

      // Cualquier otro error de API lo tratamos abajo como "posible offline"
      return _tryOffline(email, password, prefs);
    } on SocketException {
      // Sin red
      return _tryOffline(email, password, prefs);
    } on HandshakeException {
      // Problema TLS
      return _tryOffline(email, password, prefs);
    } catch (_) {
      // Errores genéricos de red
      return _tryOffline(email, password, prefs);
    }
  }

  static Future<LoginResult?> _tryOffline(
    String email,
    String password,
    SharedPreferences prefs,
  ) async {
    final stored = prefs.getString(_kHashKey(email));
    if (stored == null)
      return null; // nunca hizo login online en este dispositivo

    final ok = BCrypt.checkpw(password, stored);
    if (!ok)
      throw ApiException(
        'Credenciales incorrectas (modo offline).',
        statusCode: 401,
      );

    final userId = prefs.getInt_notnull(_kUserKey(email));
    final productorId = prefs.getInt(_kProdKey(email));

    return LoginResult(
      token: null, // sin token en offline
      userId: userId,
      productorId: productorId,
      offline: true,
    );
  }

  static Future<void> logout({
    required String email,
    bool forgetDevice = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);

    if (forgetDevice) {
      await prefs.remove(_kHashKey(email));
      await prefs.remove(_kUserKey(email));
      await prefs.remove(_kProdKey(email));
      await prefs.remove('remembered_email');
    }
  }

  static Future<String?> currentToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }
}
