import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart'; // debugPrint
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'package:http/http.dart' as http;

import 'dart:io';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static const Duration _timeout = Duration(seconds: 20);

  static String get baseUrl => AppConfig.apiBaseUrl;

  static Map<String, String> _jsonHeaders({String? token}) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// LOGINs
  /// Devuelve un mapa con token y productorId si fue exitoso; null si credenciales inválidas/otro error.
  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    final uri = Uri.parse('$baseUrl/api/login');

    debugPrint('[LOGIN] POST $uri');
    debugPrint('[LOGIN] Body: {"email": "$email", "password": "***"}');
    final resp = await http
        .post(
          uri,
          headers: _jsonHeaders(),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);

    debugPrint('[LOGIN] Status: ${resp.statusCode}');
    debugPrint('[LOGIN] Response: ${resp.body}');

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      // Normalizamos productorId por si viene como productor_id
      if (data['user'] is Map<String, dynamic>) {
        final user = data['user'] as Map<String, dynamic>;
        if (user.containsKey('productor_id') &&
            !user.containsKey('productorId')) {
          user['productorId'] = user['productor_id'];
        }
        // Normalizar can_create_invernadero -> canCreateInvernadero (camelCase)
        if (user.containsKey('can_create_invernadero') &&
            !user.containsKey('canCreateInvernadero')) {
          user['canCreateInvernadero'] = user['can_create_invernadero'];
        }
      }

      // Persistimos token + user en SharedPreferences para que HomeScreen pueda leerlo
      try {
        final prefs = await SharedPreferences.getInstance();
        // token
        if (data.containsKey('token') && data['token'] is String) {
          await prefs.setString('user_token', data['token'] as String);
        }
        // current_user json (guardamos el mapa normalizado)
        if (data['user'] is Map<String, dynamic>) {
          final userJson = jsonEncode(data['user']);
          await prefs.setString('current_user', userJson);
          // remembered email (ayuda a compatibilidad con offline_userId_ keys)
          if ((data['user'] as Map<String, dynamic>).containsKey('email')) {
            final remEmail =
                (data['user'] as Map<String, dynamic>)['email'] as String?;
            if (remEmail != null && remEmail.isNotEmpty) {
              await prefs.setString('remembered_email', remEmail);
              // guardamos offline_userId_<email> para compatibilidad con tu código
              final uid = (data['user'] as Map<String, dynamic>)['id'];
              if (uid is int) {
                await prefs.setInt('offline_userId_$remEmail', uid);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[LOGIN] Error persisting login data: $e');
      }

      return data;
    }

    if (resp.statusCode == 401) {
      // Credenciales inválidas
      return null;
    }

    throw ApiException(
      'Error ${resp.statusCode} al iniciar sesión',
      statusCode: resp.statusCode,
    );
  }

  /// GET protegido
  static Future<dynamic> get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final resp = await http
        .get(uri, headers: _jsonHeaders(token: token))
        .timeout(_timeout);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
    }

    if (resp.statusCode == 401) {
      throw ApiException('No autorizado', statusCode: 401);
    }

    throw ApiException(
      'Error ${resp.statusCode} en GET $path',
      statusCode: resp.statusCode,
    );
  }

  /// POST protegido (por si lo necesitas)
  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http
        .post(
          uri,
          headers: _jsonHeaders(token: token),
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
    }

    if (resp.statusCode == 401) {
      throw ApiException('No autorizado', statusCode: 401);
    }

    throw ApiException(
      'Error ${resp.statusCode} en POST $path',
      statusCode: resp.statusCode,
    );
  }

  static Future<dynamic> postMultipart(
    String path,
    Map<String, dynamic> fields,
    List<Map<String, String>> files, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    // Encabezados
    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // campos simples (stringify lists/maps)
    fields.forEach((k, v) {
      if (v == null) return;
      if (v is String) {
        request.fields[k] = v;
      } else {
        request.fields[k] = jsonEncode(v);
      }
    });

    for (final f in files) {
      final pathStr = f['path'];
      if (pathStr == null) continue;
      final field = f['field'] ?? 'files[]';
      final filename =
          f['filename'] ?? pathStr.split(Platform.pathSeparator).last;
      final file = File(pathStr);
      if (!file.existsSync()) continue;
      final mimeType = lookupMimeType(pathStr) ?? 'application/octet-stream';
      final parts = mimeType.split('/');
      final contentType = MediaType(
        parts[0],
        parts.length > 1 ? parts[1] : 'octet-stream',
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          field,
          file.readAsBytesSync(),
          filename: filename,
          contentType: contentType,
        ),
      );
    }

    final streamed = await request.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      try {
        return jsonDecode(resp.body);
      } catch (_) {
        return resp.body;
      }
    } else {
      // lanzar excepción con el mismo esquema que el resto del ApiService
      throw ApiException(resp.body, statusCode: resp.statusCode);
    }
  }
}
