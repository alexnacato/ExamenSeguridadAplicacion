class AdminReport {
  const AdminReport({
    required this.sold,
    required this.revenue,
    required this.checkedIn,
  });

  final int sold;
  final double revenue;
  final int checkedIn;

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    final sold = json['vendidos'];
    final revenue = json['ingresos'];
    final checkedIn = json['ingresaron'];

    return AdminReport(
      sold: sold is num ? sold.toInt() : 0,
      revenue: revenue is num ? revenue.toDouble() : 0,
      checkedIn: checkedIn is num ? checkedIn.toInt() : 0,
    );
  }
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.timestamp,
    required this.event,
    required this.actor,
    required this.detail,
  });

  final String id;
  final String timestamp;
  final String event;
  final String actor;
  final String detail;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id']?.toString() ?? '',
        timestamp: json['ts']?.toString() ?? '',
        event: json['event']?.toString() ?? '',
        actor: json['actor']?.toString() ?? '',
        detail: json['detail']?.toString() ?? '',
      );
}

class AuditSnapshot {
  const AuditSnapshot({required this.brokenAt, required this.entries});

  final int brokenAt;
  final List<AuditEntry> entries;

  bool get intact => brokenAt == 0;
}
