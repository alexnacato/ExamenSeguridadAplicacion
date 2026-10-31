import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/ticket_models.dart';
import '../../domain/repositories/tickets_repository.dart';

class TicketsController extends ChangeNotifier {
  TicketsController(this._repository);

  final TicketsRepository _repository;

  List<Ticket> _tickets = const [];
  bool _loading = false;
  String? _error;
  String? _notice;
  bool _transferring = false;

  Ticket? _qrTicket;
  DynamicQr? _qr;
  bool _qrLoading = false;
  bool _qrFetching = false;
  String? _qrError;
  int _qrSecondsLeft = 0;
  Timer? _qrTimer;
  bool _disposed = false;

  List<Ticket> get tickets => _tickets;
  bool get loading => _loading;
  String? get error => _error;
  String? get notice => _notice;
  bool get transferring => _transferring;
  Ticket? get qrTicket => _qrTicket;
  DynamicQr? get qr => _qr;
  bool get qrLoading => _qrLoading;
  String? get qrError => _qrError;
  int get qrSecondsLeft => _qrSecondsLeft;

  Future<DynamicQr> fetchQr(String ticketId) => _repository.qr(ticketId);

  int get available => _tickets.where((ticket) => !ticket.used).length;
  int get used => _tickets.where((ticket) => ticket.used).length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();

    try {
      _tickets = await _repository.mine();
    } on AppFailure catch (failure) {
      _error = failure.message;
    } catch (_) {
      _error = 'No se pudieron cargar tus boletos.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> openQr(Ticket ticket) async {
    _qrTicket = ticket;
    _qr = null;
    _qrError = null;
    _qrLoading = true;
    _qrSecondsLeft = 0;
    _qrTimer?.cancel();
    _notify();

    await _fetchQr();

    _qrTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || _qrTicket == null) return;

      if (_qrSecondsLeft > 1) {
        _qrSecondsLeft--;
        _notify();
        return;
      }

      _fetchQr();
    });
  }

  void closeQr() {
    _qrTimer?.cancel();
    _qrTimer = null;
    _qrTicket = null;
    _qr = null;
    _qrError = null;
    _qrLoading = false;
    _qrSecondsLeft = 0;
    _notify();
  }

  Future<void> _fetchQr() async {
    final ticket = _qrTicket;
    if (ticket == null || _qrFetching) return;

    _qrFetching = true;
    _qrLoading = _qr == null;
    _qrError = null;
    _notify();

    try {
      final qr = await _repository.qr(ticket.id);
      _qr = qr;
      _qrSecondsLeft = qr.rotateSeconds;
      _qrError = null;
    } on AppFailure catch (failure) {
      _qrError = failure.message;
    } catch (_) {
      _qrError = 'No se pudo generar el código QR.';
    } finally {
      _qrFetching = false;
      _qrLoading = false;
      _notify();
    }
  }

  Future<bool> transfer({
    required String ticketId,
    required String email,
  }) async {
    _transferring = true;
    _error = null;
    _notice = null;
    _notify();

    try {
      await _repository.transfer(ticketId: ticketId, email: email);
      _notice = 'Boleto transferido correctamente.';
      await load();
      return true;
    } on AppFailure catch (failure) {
      _error = failure.message;
      return false;
    } catch (_) {
      _error = 'No se pudo transferir el boleto.';
      return false;
    } finally {
      _transferring = false;
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
    closeQr();
    _tickets = const [];
    _loading = false;
    _error = null;
    _notice = null;
    _transferring = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _qrTimer?.cancel();
    super.dispose();
  }
}
