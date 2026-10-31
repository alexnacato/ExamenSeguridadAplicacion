import '../../../../core/network/api_client.dart';
import '../../domain/entities/admin_models.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<AdminReport> report() async {
    final response = await _api.get('/api/admin/report');
    return AdminReport.fromJson(response);
  }

  @override
  Future<AuditSnapshot> audit() async {
    final response = await _api.get('/api/audit');
    final raw = response['entries'];
    final entries = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => AuditEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <AuditEntry>[];

    final brokenAt = response['broken'];

    return AuditSnapshot(
      brokenAt: brokenAt is num ? brokenAt.toInt() : 0,
      entries: entries,
    );
  }

  @override
  Future<String> requestExport() async {
    final response = await _api.get('/api/admin/export');
    return response['msg']?.toString() ?? 'Exportación pendiente de aprobación.';
  }

  @override
  Future<void> attemptAuditEdit() async {
    await _api.post('/api/audit/edit');
  }
}
