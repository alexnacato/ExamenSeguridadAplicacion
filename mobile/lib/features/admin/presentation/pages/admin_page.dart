import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/admin_models.dart';
import '../controllers/admin_controller.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).admin.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).admin;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              SectionHeader(
                title: 'Panel administrativo',
                subtitle:
                    'Métricas en tiempo real, auditoría y operaciones sensibles.',
                trailing: IconButton(
                  tooltip: 'Actualizar',
                  onPressed: controller.loading ? null : controller.load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const SizedBox(height: 16),
              if (controller.error != null) ...[
                ErrorBanner(
                  message: controller.error!,
                  onDismiss: controller.clearMessages,
                ),
                const SizedBox(height: 12),
              ],
              if (controller.notice != null) ...[
                InfoBanner(message: controller.notice!),
                const SizedBox(height: 12),
              ],
              if (controller.loading &&
                  controller.report == null &&
                  controller.audit == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (controller.report != null)
                  _Metrics(report: controller.report!),
                const SizedBox(height: 16),
                _ActionsCard(controller: controller),
                const SizedBox(height: 16),
                if (controller.audit != null)
                  _AuditCard(snapshot: controller.audit!),
                const SizedBox(height: 16),
                const InfoBanner(
                  message:
                      'La exportación masiva requiere aprobación gerencial y verificación adicional. Cada intento queda registrado.',
                  icon: Icons.admin_panel_settings_outlined,
                ),
                if (controller.audit != null &&
                    controller.audit!.intact) ...[
                  const SizedBox(height: 12),
                  InfoBanner(
                    message:
                        'Cadena de auditoría íntegra: ${controller.audit!.entries.length} eventos verificados.',
                    icon: Icons.verified_user_outlined,
                    color: scheme.primary,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        final cards = [
          _MetricCard(
            icon: Icons.confirmation_number_outlined,
            label: 'Boletos vendidos',
            value: '${report.sold}',
            color: scheme.primary,
          ),
          _MetricCard(
            icon: Icons.payments_outlined,
            label: 'Ingresos',
            value: money(report.revenue),
            color: scheme.tertiary,
          ),
          _MetricCard(
            icon: Icons.how_to_reg_outlined,
            label: 'Ingresaron',
            value: '${report.checkedIn}',
            color: scheme.secondary,
          ),
        ];

        if (!wide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.controller});

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Operaciones sensibles',
            subtitle:
                'Exportación con aprobación y verificación de la auditoría.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      controller.exporting ? null : controller.requestExport,
                  icon: controller.exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Exportar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.testing ? null : controller.testWorm,
                  icon: controller.testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Probar auditoría'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.snapshot});

  final AuditSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = snapshot.entries.take(12).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Auditoría',
            subtitle: 'Últimos eventos registrados.',
            trailing: StatusBadge(
              label: snapshot.intact ? 'Íntegra' : 'Alterada',
              color: snapshot.intact ? scheme.primary : scheme.error,
              icon: snapshot.intact
                  ? Icons.verified_outlined
                  : Icons.report_gmailerrorred_rounded,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              'No hay eventos todavía.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              _AuditRow(entry: entries[i]),
              if (i != entries.length - 1)
                Divider(
                  height: 18,
                  color: scheme.outlineVariant.withValues(alpha: .5),
                ),
            ],
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAlert = entry.event.startsWith('ALERT') ||
        entry.event.contains('FAIL') ||
        entry.event.contains('DENIED');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: isAlert ? scheme.error : scheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _eventLabel(entry.event),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: entry.event.startsWith('ALERT')
                              ? 'monospace'
                              : null,
                          color: isAlert ? scheme.error : scheme.onSurface,
                        ),
                      ),
                    ),
                  Text(
                    _shortDate(entry.timestamp),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${entry.actor} · ${entry.detail}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _eventLabel(String event) {
    const labels = {
      'LOGIN_OK': 'Ingreso de usuario',
      'LOGIN_FAIL': 'Intento fallido de ingreso',
      'ACCOUNT_LOCK': 'Cuenta bloqueada temporalmente',
      'ACCESS_DENIED': 'Acceso denegado',
      'QUEUE_JOIN': 'Ingresó a la sala de espera',
      'SEAT_LOCK': 'Reservó un asiento',
      'PURCHASE': 'Compra realizada',
      'TRANSFER': 'Boleto transferido',
      'SCAN_REJECT': 'Código QR rechazado',
      'ENTRY': 'Ingreso al estadio',
      'SUPPORT_VIEW': 'Consulta de soporte',
      'ALERT_EXPORT_REQUEST': 'Solicitud de exportación',
      'ALERT_TAMPER_ATTEMPT': 'Intento de alteración de registros',
      'IDOR_BLOCKED': 'Acceso a boleto ajeno bloqueado',
      'REGISTER': 'Cuenta creada',
      'LOGOUT': 'Cierre de sesión',
      'SEED': 'Datos iniciales',
    };
    return labels[event] ?? event;
  }

  String _shortDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.length > 16 ? value.substring(11, 16) : value;
    final local = date.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
