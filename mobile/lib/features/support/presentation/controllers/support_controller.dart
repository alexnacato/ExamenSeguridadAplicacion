import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_repository.dart';

class SupportController extends ChangeNotifier {
  SupportController(this._repository);

  final SupportRepository _repository;

  SupportTicket? _result;
  bool _loading = false;
  String? _error;

  SupportTicket? get result => _result;
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> lookup(String ticketId) async {
    if (ticketId.trim().isEmpty) {
      _error = 'Ingresa el ID del boleto.';
      notifyListeners();
      return false;
    }

    _loading = true;
    _result = null;
    _error = null;
    notifyListeners();

    try {
      _result = await _repository.lookup(ticketId);
      return true;
    } on AppFailure catch (failure) {
      _error = failure.message;
      return false;
    } catch (_) {
      _error = 'No se pudo consultar el boleto.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _result = null;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _result = null;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
