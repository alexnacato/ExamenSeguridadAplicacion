import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/ticket_models.dart';
import '../widgets/qr_dialog.dart';
import '../widgets/transfer_dialog.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).tickets.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).tickets;
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
                title: 'Mis boletos',
                subtitle:
                    'Cada boleto tiene un QR firmado que rota cada 15 segundos.',
                trailing: IconButton(
                  tooltip: 'Actualizar',
                  onPressed: controller.loading ? null : controller.load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.confirmation_number_outlined,
                      value: '${controller.available}',
                      label: 'Disponibles',
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.how_to_reg_outlined,
                      value: '${controller.used}',
                      label: 'Utilizados',
                      color: scheme.tertiary,
                    ),
                  ),
                ],
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
              if (controller.loading && controller.tickets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (controller.tickets.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Aún no tienes boletos',
                    message:
                        'Compra tu primer boleto desde la pestaña Comprar. El QR aparecerá aquí automáticamente.',
                  ),
                )
              else ...[
                for (final ticket in controller.tickets) ...[
                  _TicketCard(ticket: ticket),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                const InfoBanner(
                  message:
                      'Si transfieres un boleto, el QR anterior queda invalidado al instante. El límite es de 4 boletos por cuenta.',
                  icon: Icons.shield_outlined,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disabled = ticket.used;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  ticket.seat,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -.4,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asiento ${ticket.seat}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID ${shortId(ticket.id)} · ****${ticket.last4}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: ticket.used ? 'Usado' : 'Válido',
                color: ticket.used ? scheme.onSurfaceVariant : scheme.primary,
                icon: ticket.used
                    ? Icons.check_circle_outline_rounded
                    : Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: scheme.outlineVariant.withValues(alpha: .6)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: disabled
                      ? null
                      : () => showDialog<void>(
                            context: context,
                            builder: (_) => QrDialog(ticket: ticket),
                          ),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Ver QR'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: disabled
                      ? null
                      : () => showDialog<void>(
                            context: context,
                            builder: (_) => TransferDialog(ticket: ticket),
                          ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Transferir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
