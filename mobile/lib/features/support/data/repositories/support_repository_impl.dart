import '../../../../core/network/api_client.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_repository.dart';

class SupportRepositoryImpl implements SupportRepository {
  SupportRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<SupportTicket> lookup(String ticketId) async {
    final response = await _api.post('/api/support/ticket', {'id': ticketId.trim()});
    return SupportTicket(
      id: response['id']?.toString() ?? ticketId,
      seat: response['seat']?.toString() ?? '',
      status: response['estado']?.toString() ?? '',
      holder: response['titular']?.toString() ?? '',
    );
  }
}
