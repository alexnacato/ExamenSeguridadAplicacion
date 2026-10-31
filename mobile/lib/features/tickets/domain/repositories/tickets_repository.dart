import '../entities/queue_status.dart';
import '../entities/ticket_models.dart';

abstract class TicketsRepository {
  Future<QueueStatus> joinQueue();

  Future<QueueStatus> queueStatus();

  Future<SeatMap> fetchSeats();

  Future<void> lockSeat(String seat);

  Future<void> unlockSeat(String seat);

  Future<PurchaseResult> buy({
    required List<String> seats,
    required String payToken,
  });

  Future<List<Ticket>> mine();

  Future<DynamicQr> qr(String ticketId);

  Future<void> transfer({required String ticketId, required String email});
}
