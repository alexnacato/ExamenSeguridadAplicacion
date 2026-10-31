import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/repositories/gate_repository.dart';

class GateController extends ChangeNotifier {
  GateController(this._repository);

  final GateRepository _repository;

  String? _publicKey;
  String? _scannedSeat;
  bool _loadingKey = false;
  bool _scanning = false;
  String? _error;
  String? _notice;

  String? get publicKey => _publicKey;
  String? get scannedSeat => _scannedSeat;
  bool get loadingKey => _loadingKey;
  bool get scanning => _scanning;
  String? get error => _error;
  String? get notice => _notice;

  Future<void> loadPublicKey() async {
    if (_loadingKey) return;

    _loadingKey = true;
    _error = null;
    notifyListeners();

    try {
      _publicKey = await _repository.publicKey();
    } on AppFailure catch (failure) {
      _error = failure.message;
    } catch (_) {
      _error = 'No se pudo obtener la llave pública.';
    } finally {
      _loadingKey = false;
      notifyListeners();
    }
  }

  Future<bool> scan(String qr) async {
    if (qr.trim().isEmpty) {
      _error = 'Pega o escanea el código QR.';
      notifyListeners();
      return false;
    }

    _scanning = true;
    _scannedSeat = null;
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      _scannedSeat = await _repository.scan(qr);
      _notice = 'Acceso autorizado. Asiento $_scannedSeat.';
      return true;
    } on AppFailure catch (failure) {
      _error = failure.message;
      return false;
    } catch (_) {
      _error = 'No se pudo validar el código QR.';
      return false;
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    if (_error == null && _notice == null) return;
    _error = null;
    _notice = null;
    notifyListeners();
  }

  void reset() {
    _scannedSeat = null;
    _scanning = false;
    _error = null;
    _notice = null;
    notifyListeners();
  }
}
