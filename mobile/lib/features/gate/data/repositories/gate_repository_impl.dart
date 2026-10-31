import '../../../../core/network/api_client.dart';
import '../../domain/repositories/gate_repository.dart';

class GateRepositoryImpl implements GateRepository {
  GateRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<String> publicKey() => _api.getText('/api/gate/pubkey');

  @override
  Future<String> scan(String qr) async {
    final response = await _api.post('/api/gate/scan', {'qr': qr.trim()});
    return response['seat']?.toString() ?? '';
  }
}
