import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/loading_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/support_ticket.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _id = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).support;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const SectionHeader(
              title: 'Soporte N1',
              subtitle:
                  'Consulta el estado de un boleto con el ID exacto. El titular se muestra enmascarado.',
            ),
            const SizedBox(height: 16),
            if (controller.error != null) ...[
              ErrorBanner(message: controller.error!),
              const SizedBox(height: 12),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _id,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _lookup(),
                    decoration: const InputDecoration(
                      labelText: 'ID del boleto',
                      hintText: '00000000-0000-0000-0000-000000000000',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  LoadingButton(
                    label: 'Consultar boleto',
                    icon: Icons.manage_search_rounded,
                    loading: controller.loading,
                    onPressed: _lookup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (controller.result != null)
              _ResultCard(ticket: controller.result!)
            else
              AppCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      size: 42,
                      color: scheme.primary.withValues(alpha: .7),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sin consultas todavía',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ingresa el ID de un boleto para ver su asiento, estado y titular enmascarado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const InfoBanner(
              message:
                  'Esta consulta queda registrada en el log WORM como SUPPORT_VIEW. No se exponen correos completos ni datos de pago.',
              icon: Icons.privacy_tip_outlined,
            ),
          ],
        );
      },
    );
  }

  Future<void> _lookup() async {
    FocusScope.of(context).unfocus();
    await AppScope.of(context).support.lookup(_id.text);
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valid = ticket.status.toLowerCase().contains('válido');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Boleto ${ticket.seat}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              StatusBadge(
                label: ticket.status,
                color: valid ? scheme.primary : scheme.tertiary,
                icon: valid
                    ? Icons.verified_outlined
                    : Icons.how_to_reg_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Row(label: 'ID', value: ticket.id),
          const SizedBox(height: 10),
          _Row(label: 'Asiento', value: ticket.seat),
          const SizedBox(height: 10),
          _Row(label: 'Estado', value: ticket.status),
          const SizedBox(height: 10),
          _Row(label: 'Titular', value: ticket.holder),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
