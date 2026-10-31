import '../entities/support_ticket.dart';

abstract class SupportRepository {
  Future<SupportTicket> lookup(String ticketId);
}
