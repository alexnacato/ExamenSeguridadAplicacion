import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/app_failure.dart';

class PaymentToken {
  const PaymentToken({required this.token, required this.last4});

  final String token;
  final String last4;
}

class GatewayClient {
  GatewayClient({required this.baseUri, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final Uri baseUri;
  final http.Client _http;

  Future<PaymentToken> tokenize({
    required String pan,
    required String exp,
    required String cvv,
  }) async {
    try {
      final response = await _http
          .post(
            baseUri.resolve('/tokenize'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'pan': pan, 'exp': exp, 'cvv': cvv}),
          )
          .timeout(const Duration(seconds: 15));

      dynamic decoded;
      try {
        decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
      } on FormatException {
        throw const AppFailure('La pasarela devolvió una respuesta inválida.');
      }

      final result = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppFailure(
          result['error']?.toString() ?? 'Tarjeta rechazada.',
          statusCode: response.statusCode,
        );
      }

      final token = result['token']?.toString();
      if (token == null || token.isEmpty) {
        throw const AppFailure('La pasarela no devolvió un token válido.');
      }

      return PaymentToken(
        token: token,
        last4: result['last4']?.toString() ?? '',
      );
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw const AppFailure('La pasarela tardó demasiado en responder.');
    } on http.ClientException {
      throw const AppFailure('No se pudo conectar con la pasarela de pagos.');
    }
  }

  void close() => _http.close();
}
