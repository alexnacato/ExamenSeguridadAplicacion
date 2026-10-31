import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/session_store.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository, this._sessionStore);

  final AuthRepository _repository;
  final SessionStore _sessionStore;

  bool _loading = false;
  String? _error;
  String? _notice;
  AuthChallenge? _challenge;
  String _pendingEmail = '';
  String? _lastRegisteredEmail;

  bool get loading => _loading;
  String? get error => _error;
  String? get notice => _notice;
  bool get awaitingOtp => _challenge != null;
  String get pendingEmail => _pendingEmail;
  String? get devOtp => _challenge?.devOtp;
  String? get lastRegisteredEmail => _lastRegisteredEmail;

  Future<bool> login({required String email, required String password}) async {
    _loading = true;
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      final challenge = await _repository.login(
        email: email,
        password: password,
      );
      _challenge = challenge;
      _pendingEmail = email.trim();
      _notice = challenge.devOtp == null
          ? null
          : 'Código OTP de demostración: ${challenge.devOtp}';
      return true;
    } on AppFailure catch (failure) {
      _error = failure.message;
      return false;
    } catch (_) {
      _error = 'No se pudo iniciar sesión. Intenta de nuevo.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String code) async {
    final challenge = _challenge;
    if (challenge == null) {
      _error = 'El desafío expiró. Vuelve a iniciar sesión.';
      notifyListeners();
      return false;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _repository.verifyOtp(
        challenge: challenge.challenge,
        code: code,
      );
      _sessionStore.set(session);
      _challenge = null;
      _notice = null;
      _error = null;
      return true;
    } on AppFailure catch (failure) {
      _error = failure.message;
      return false;
    } catch (_) {
      _error = 'No se pudo verificar el código.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String cedula,
    required String email,
    required String password,
  }) async {
    _loading = true;
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      await _repository.register(
        name: name,
        cedula: cedula,
        email: email,
        password: password,
      );
      _lastRegisteredEmail = email.trim().toLowerCase();
      _notice = 'Cuenta creada. Inicia sesión con tu correo y contraseña.';
      return true;
    } on AppFailure catch (failure) {
      _error = failure.message;
      return false;
    } catch (_) {
      _error = 'No se pudo crear la cuenta.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void cancelOtp() {
    _challenge = null;
    _pendingEmail = '';
    _error = null;
    _notice = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // La sesión local se limpia aunque el servidor no responda.
    } finally {
      _sessionStore.clear();
      _challenge = null;
      _pendingEmail = '';
      _error = null;
      _notice = null;
      notifyListeners();
    }
  }

  void clearMessages() {
    if (_error == null && _notice == null) return;
    _error = null;
    _notice = null;
    notifyListeners();
  }
}
