import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/admin_models.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminController extends ChangeNotifier {
  AdminController(this._repository);

  final AdminRepository _repository;

  AdminReport? _report;
  AuditSnapshot? _audit;
  bool _loading = false;
  bool _exporting = false;
  bool _testing = false;
  String? _error;
  String? _notice;

  AdminReport? get report => _report;
  AuditSnapshot? get audit => _audit;
  bool get loading => _loading;
  bool get exporting => _exporting;
  bool get testing => _testing;
  String? get error => _error;
  String? get notice => _notice;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();

    try {
      final results = await Future.wait<Object>([
        _repository.report(),
        _repository.audit(),
      ]);
      _report = results[0] as AdminReport;
      _audit = results[1] as AuditSnapshot;
    } on AppFailure catch (failure) {
      _error = failure.message;
    } catch (_) {
      _error = 'No se pudo cargar el panel administrativo.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> requestExport() async {
    _exporting = true;
    _error = null;
    _notice = null;
    _notify();

    try {
      _notice = await _repository.requestExport();
    } on AppFailure catch (failure) {
      _error = failure.message;
    } catch (_) {
      _error = 'No se pudo solicitar la exportación.';
    } finally {
      _exporting = false;
      _notify();
    }
  }

  Future<void> testWorm() async {
    _testing = true;
    _error = null;
    _notice = null;
    _notify();

    try {
      await _repository.attemptAuditEdit();
      _error = 'Alerta: el log WORM permitió una modificación.';
    } on AppFailure catch (failure) {
      if (failure.statusCode == 403) {
        _notice = 'WORM activo: la modificación fue bloqueada.';
      } else {
        _error = failure.message;
      }
    } catch (_) {
      _error = 'No se pudo ejecutar la prueba WORM.';
    } finally {
      _testing = false;
      _notify();
    }
  }

  void clearMessages() {
    if (_error == null && _notice == null) return;
    _error = null;
    _notice = null;
    _notify();
  }

  void reset() {
    _report = null;
    _audit = null;
    _loading = false;
    _exporting = false;
    _testing = false;
    _error = null;
    _notice = null;
    _notify();
  }

  void _notify() => notifyListeners();
}
