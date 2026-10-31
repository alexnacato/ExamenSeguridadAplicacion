import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<AuthChallenge> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post('/api/auth/login', {
      'email': email.trim().toLowerCase(),
      'pass': password,
    });

    final challenge = response['challenge']?.toString();
    if (challenge == null || challenge.isEmpty) {
      throw StateError('El servidor no devolvió un desafío de verificación.');
    }

    return AuthChallenge(
      challenge: challenge,
      devOtp: response['otp']?.toString(),
    );
  }

  @override
  Future<Session> verifyOtp({
    required String challenge,
    required String code,
  }) async {
    final response = await _api.post('/api/auth/verify', {
      'challenge': challenge,
      'otp': code.trim(),
    });

    final token = response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('El servidor no devolvió un token válido.');
    }

    final user = response['user'];
    final claims = _decodeJwt(token);
    final map = user is Map<String, dynamic> ? user : const <String, dynamic>{};

    final email =
        map['email']?.toString() ?? claims['email']?.toString() ?? 'cuenta';
    final role = map['role']?.toString() ?? claims['role']?.toString() ?? 'cliente';
    final name = map['name']?.toString() ?? _nameFromEmail(email);

    return Session(
      token: token,
      name: name,
      email: email,
      role: role,
      cedula: map['cedula_last4']?.toString(),
    );
  }

  @override
  Future<void> register({
    required String name,
    required String cedula,
    required String email,
    required String password,
  }) async {
    await _api.post('/api/auth/register', {
      'name': name.trim(),
      'cedula': cedula.trim(),
      'email': email.trim().toLowerCase(),
      'pass': password,
    });
  }

  @override
  Future<void> logout() async {
    await _api.post('/api/auth/logout');
  }
}

String _nameFromEmail(String email) {
  final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
  if (local.trim().isEmpty) return 'Usuario';
  return local
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

Map<String, dynamic> _decodeJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return const {};
    final payload = base64Url.normalize(parts[1]);
    final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
    return decoded is Map<String, dynamic> ? decoded : const {};
  } catch (_) {
    return const {};
  }
}
