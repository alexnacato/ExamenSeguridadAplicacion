import '../entities/session.dart';

class AuthChallenge {
  const AuthChallenge({required this.challenge, this.devOtp});

  final String challenge;
  final String? devOtp;
}

abstract class AuthRepository {
  Future<AuthChallenge> login({required String email, required String password});

  Future<Session> verifyOtp({required String challenge, required String code});

  Future<void> register({
    required String name,
    required String cedula,
    required String email,
    required String password,
  });

  Future<void> logout();
}
