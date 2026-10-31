import '../../../../core/network/api_client.dart';
import '../../domain/entities/queue_status.dart';
import '../../domain/entities/ticket_models.dart';
import '../../domain/repositories/tickets_repository.dart';

class TicketsRepositoryImpl implements TicketsRepository {
  TicketsRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<QueueStatus> joinQueue() async {
    final response = await _api.post('/api/queue/join');
    return _queue(response);
  }

  @override
  Future<QueueStatus> queueStatus() async {
    final response = await _api.get('/api/queue/status');
    return _queue(response);
  }

  @override
  Future<SeatMap> fetchSeats() async {
    final response = await _api.get('/api/seats');
    final rawSeats = response['seats'];
    final seats = <String, SeatState>{};

    if (rawSeats is Map) {
      for (final entry in rawSeats.entries) {
        seats[entry.key.toString()] = seatStateFrom(entry.value.toString());
      }
    }

    final price = response['price'];
    return SeatMap(
      price: price is num ? price.toDouble() : 25,
      seats: seats,
    );
  }

  @override
  Future<void> lockSeat(String seat) async {
    await _api.post('/api/seats/lock', {'seat': seat});
  }

  @override
  Future<void> unlockSeat(String seat) async {
    await _api.post('/api/seats/unlock', {'seat': seat});
  }

  @override
  Future<PurchaseResult> buy({
    required List<String> seats,
    required String payToken,
  }) async {
    final response = await _api.post('/api/tickets/buy', {
      'seats': seats,
      'payToken': payToken,
    });

    final rawIds = response['ids'];
    final ids = rawIds is List ? rawIds.map((id) => id.toString()).toList() : <String>[];
    final total = response['total'];

    return PurchaseResult(
      ids: ids,
      total: total is num ? total.toDouble() : 0,
    );
  }

  @override
  Future<List<Ticket>> mine() async {
    final response = await _api.get('/api/tickets/mine');
    final raw = response['tickets'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<DynamicQr> qr(String ticketId) async {
    final response = await _api.post('/api/tickets/qr', {'id': ticketId});
    final rotate = response['rotateSeconds'];
    return DynamicQr(
      value: response['qr']?.toString() ?? '',
      rotateSeconds: rotate is num ? rotate.toInt() : 15,
    );
  }

  @override
  Future<void> transfer({
    required String ticketId,
    required String email,
  }) async {
    await _api.post('/api/tickets/transfer', {
      'id': ticketId,
      'to': email.trim().toLowerCase(),
    });
  }

  QueueStatus _queue(Map<String, dynamic> response) {
    final pos = response['pos'];
    return QueueStatus(
      admitted: response['ok'] == true,
      position: pos is num ? pos.toInt() : 0,
    );
  }
}
