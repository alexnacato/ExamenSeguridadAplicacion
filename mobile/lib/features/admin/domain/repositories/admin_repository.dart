import '../entities/admin_models.dart';

abstract class AdminRepository {
  Future<AdminReport> report();

  Future<AuditSnapshot> audit();

  Future<String> requestExport();

  Future<void> attemptAuditEdit();
}
