import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/app_failure.dart';

typedef TokenProvider = String? Function();
typedef UnauthorizedHandler = void Function();

class ApiClient {
  ApiClient({
    required this.baseUri,
    required this.tokenProvider,
    this.onUnauthorized,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final Uri baseUri;
  final TokenProvider tokenProvider;
  final UnauthorizedHandler? onUnauthorized;
  final http.Client _http;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) =>
      _request('POST', path, body: body);

  Future<String> getText(String path) async {
    final response = await _send('GET', path);
    _checkUnauthorized(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppFailure(
        'No se pudo obtener el recurso (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return response.body;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(method, path, body: body);
    _checkUnauthorized(response);

    dynamic decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw const AppFailure('El servidor devolvió una respuesta inválida.');
    }

    final result = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppFailure(
        result['error']?.toString() ??
            'Error del servidor (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return result;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = baseUri.resolve(path);
      final token = tokenProvider();
      final headers = <String, String>{
        'content-type': 'application/json',
        if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
      };

      final request = method == 'GET'
          ? _http.get(uri, headers: headers)
          : _http.post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? const <String, dynamic>{}),
            );

      return await request.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AppFailure('El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw const AppFailure(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }
  }

  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) onUnauthorized?.call();
  }

  void close() => _http.close();
}
