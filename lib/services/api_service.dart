import 'dart:convert';
import 'dart:async';
import '../config.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static const Duration _timeout = Duration(seconds: 15);

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

    print('[LOGIN] POST $uri');
    print('[LOGIN] Body: {"email": "$email", "password": "***"}');
    final resp = await http
        .post(
          uri,
          headers: _jsonHeaders(),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);

    print('[LOGIN] Status: ${resp.statusCode}');
    print('[LOGIN] Response: ${resp.body}');

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      // Normalizamos productorId por si viene como productor_id
      if (data['user'] is Map<String, dynamic>) {
        final user = data['user'] as Map<String, dynamic>;
        if (user.containsKey('productor_id') &&
            !user.containsKey('productorId')) {
          user['productorId'] = user['productor_id'];
        }
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
        .timeout(const Duration(seconds: 20));

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
        .timeout(const Duration(seconds: 20));

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

  /*
  static Future<List<dynamic>> getUsers(String token, int productorId) async {
    final url = Uri.parse('$baseUrl/api/users?productor_id=$productorId');
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<List<dynamic>> getProductores(
    String token,
    int productorId,
  ) async {
    final url = Uri.parse('$baseUrl/api/productores?productor_id=$productorId');
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<List<dynamic>> getFincas(String token, int productorId) async {
    final url = Uri.parse('$baseUrl/api/fincas?productor_id=$productorId');
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<List<dynamic>> getLotes(String token, int productorId) async {
    final url = Uri.parse('$baseUrl/api/lotes?productor_id=$productorId');
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<List<dynamic>> getValvulas(
    String token,
    int productorId,
  ) async {
    final url = Uri.parse('$baseUrl/api/valvulas?productor_id=$productorId');
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<List<dynamic>> getVariedades(
    String token,
    int productorId,
  ) async {
    final url = Uri.parse('$baseUrl/api/variedades?productor_id=$productorId');
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<List<dynamic>> getVariedadProductor(
    String token,
    int productorId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/api/variedad_productor?productor_id=$productorId',
    );
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<List<dynamic>> getDistanciasCama(String token) async {
    final url = Uri.parse('$baseUrl/api/distancias_cama');
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<List<dynamic>> getDistanciasPlanta(String token) async {
    final url = Uri.parse('$baseUrl/api/distancias_planta');
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }*/
}
