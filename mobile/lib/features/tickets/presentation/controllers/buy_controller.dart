import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/gateway_client.dart';
import '../../domain/entities/ticket_models.dart';
import '../../domain/repositories/tickets_repository.dart';

class BuyController extends ChangeNotifier {
  BuyController(this._repository, this._gateway);

  final TicketsRepository _repository;
  final GatewayClient _gateway;

  SeatMap? _seatMap;
  final Set<String> _selected = {};
  bool _loading = false;
  bool _entering = false;
  bool _admitted = false;
  bool _purchasing = false;
  bool _seatBusy = false;
  bool _started = false;
  bool _disposed = false;
  int _position = 0;
  String? _error;
  String? _notice;
  PurchaseResult? _lastPurchase;
  Timer? _poll;

  SeatMap? get seatMap => _seatMap;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get loading => _loading;
  bool get entering => _entering;
  bool get admitted => _admitted;
  bool get purchasing => _purchasing;
  bool get seatBusy => _seatBusy;
  int get position => _position;
  String? get error => _error;
  String? get notice => _notice;
  PurchaseResult? get lastPurchase => _lastPurchase;
  double get total => (_seatMap?.price ?? 0) * _selected.length;
  bool get canPay =>
      _admitted && _selected.isNotEmpty && !_purchasing && !_seatBusy;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await enterQueue();
  }

  Future<void> enterQueue() async {
    if (_entering) return;

    _entering = true;
    _error = null;
    _notice = null;
    _notify();

    try {
      final status = await _repository.joinQueue();
      _admitted = status.admitted;
      _position = status.position;

      if (_admitted) {
        await _loadSeats();
      } else {
        _startPolling();
      }
    } on AppFailure catch (failure) {
      _error = failure.message;
    } catch (_) {
      _error = 'No se pudo entrar a la sala de espera.';
    } finally {
      _entering = false;
      _notify();
    }
  }

  Future<void> refreshSeats() => _loadSeats();

  Future<void> _loadSeats() async {
    _loading = true;
    _notify();

    try {
      final map = await _repository.fetchSeats();
      _seatMap = map;
      _selected.removeWhere(
        (seat) => map.seats[seat] == SeatState.sold,
      );
    } on AppFailure catch (failure) {
      _error = failure.message;
    } catch (_) {
      _error = 'No se pudo cargar el mapa de asientos.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_disposed || _admitted) return;

      try {
        final status = await _repository.queueStatus();
        _position = status.position;
        _admitted = status.admitted;

        if (_admitted) {
          _poll?.cancel();
          await _loadSeats();
        }
        _notify();
      } catch (_) {
        // La cola se reintenta en el siguiente ciclo.
      }
    });
  }

  Future<void> toggleSeat(String seat) async {
    if (_seatBusy || _purchasing || _loading) return;

    final state = _seatMap?.seats[seat];
    if (state == SeatState.locked || state == SeatState.sold) return;

    if (_selected.contains(seat)) {
      _seatBusy = true;
      _notify();
      try {
        await _repository.unlockSeat(seat);
        _selected.remove(seat);
        await _loadSeats();
      } on AppFailure catch (failure) {
        _error = failure.message;
        await _loadSeats();
      } finally {
        _seatBusy = false;
        _notify();
      }
      return;
    }

    if (_selected.length >= 4) {
      _error = 'Solo puedes comprar hasta 4 boletos por cuenta.';
      _notify();
      return;
    }

    if (state == SeatState.mine) {
      _selected.add(seat);
      _notify();
      return;
    }

    _seatBusy = true;
    _error = null;
    _notify();

    try {
      await _repository.lockSeat(seat);
      _selected.add(seat);
      await _loadSeats();
    } on AppFailure catch (failure) {
      _error = failure.message;
      await _loadSeats();
    } catch (_) {
      _error = 'No se pudo bloquear el asiento.';
    } finally {
      _seatBusy = false;
      _notify();
    }
  }

  Future<bool> pay({
    required String pan,
    required String exp,
    required String cvv,
  }) async {
    if (_selected.isEmpty) {
      _error = 'Selecciona al menos un asiento.';
      _notify();
      return false;
    }

    _purchasing = true;
    _error = null;
    _notice = null;
    _notify();

    try {
      final payment = await _gateway.tokenize(pan: pan, exp: exp, cvv: cvv);
      final result = await _repository.buy(
        seats: _selected.toList(),
        payToken: payment.token,
      );

      _lastPurchase = result;
      _selected.clear();
      _notice = 'Pago aprobado. ${result.ids.length} boleto(s) emitido(s).';
      await _loadSeats();
      return true;
    } on AppFailure catch (failure) {
      _error = failure.message;
      return false;
    } catch (_) {
      _error = 'No se pudo completar la compra.';
      return false;
    } finally {
      _purchasing = false;
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
    _poll?.cancel();
    _poll = null;
    _started = false;
    _admitted = false;
    _position = 0;
    _selected.clear();
    _seatMap = null;
    _error = null;
    _notice = null;
    _lastPurchase = null;
    _entering = false;
    _purchasing = false;
    _seatBusy = false;
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
