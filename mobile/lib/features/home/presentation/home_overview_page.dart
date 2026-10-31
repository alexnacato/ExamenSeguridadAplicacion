import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../auth/domain/entities/session.dart';

class HomeOverviewPage extends StatelessWidget {
  const HomeOverviewPage({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  final Session session;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: .2),
                    child: Text(
                      session.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, ${session.name.split(' ').first}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .8),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .3),
                      ),
                    ),
                    child: Text(
                      roleLabel(session.role),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _headline(session.role),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .92),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeader(
          title: 'Accesos rápidos',
          subtitle: 'Todo lo que necesitas según tu rol.',
        ),
        const SizedBox(height: 12),
        ..._actions(session.role).map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              onTap: () => onNavigate(action.index),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(action.icon, color: scheme.primary, size: 23),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          action.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SectionHeader(
          title: 'Tu cuenta',
          subtitle: 'Sesión protegida y revocable.',
          trailing: StatusBadge(
            label: 'Activa',
            color: scheme.primary,
            icon: Icons.lock_outline_rounded,
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              _InfoRow(label: 'Correo', value: session.email),
              const SizedBox(height: 12),
              _InfoRow(label: 'Rol', value: roleLabel(session.role)),
              if (session.cedula != null) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Cédula',
                  value: '••••••${session.cedula}',
                ),
              ],
              const SizedBox(height: 12),
              const _InfoRow(
                label: 'Dispositivos',
                value: 'Máximo 2 sesiones simultáneas',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const InfoBanner(
          message:
              'Tu sesión se cierra automáticamente al salir. Si inicias sesión en otro dispositivo, la sesión más antigua se cierra.',
          icon: Icons.stay_current_portrait_outlined,
        ),
      ],
    );
  }

  String _headline(String role) {
    switch (role) {
      case 'cliente':
        return 'Compra, recibe y transfiere boletos. Tu tarjeta nunca se guarda en el sistema.';
      case 'validador':
        return 'Valida los ingresos en segundos: cada QR es único y se rechaza si se intenta reutilizar.';
      case 'soporte':
        return 'Consulta el estado de los boletos. Cada acceso queda registrado.';
      case 'admin':
        return 'Supervisa ventas, ingresos y la auditoría desde un solo panel.';
      default:
        return 'Bienvenido a TicketSec.';
    }
  }

  List<_QuickAction> _actions(String role) {
    switch (role) {
      case 'cliente':
        return const [
          _QuickAction(
            index: 1,
            icon: Icons.shopping_cart_outlined,
            title: 'Comprar boletos',
            subtitle: 'Sala de espera, mapa de asientos y pago seguro.',
          ),
          _QuickAction(
            index: 2,
            icon: Icons.confirmation_number_outlined,
            title: 'Mis boletos',
            subtitle: 'Consulta tus boletos, muestra tu QR y transfiere entradas.',
          ),
        ];
      case 'validador':
        return const [
          _QuickAction(
            index: 1,
            icon: Icons.qr_code_scanner_rounded,
            title: 'Validar QR',
            subtitle: 'Valida cada ingreso en la puerta del estadio.',
          ),
        ];
      case 'soporte':
        return const [
          _QuickAction(
            index: 1,
            icon: Icons.manage_search_rounded,
            title: 'Consultar boleto',
            subtitle: 'Busca por ID y revisa estado y titular con correo protegido.',
          ),
        ];
      case 'admin':
        return const [
          _QuickAction(
            index: 1,
            icon: Icons.insights_outlined,
            title: 'Panel administrativo',
            subtitle: 'Métricas, exportación y auditoría.',
          ),
        ];
      default:
        return const [];
    }
  }
}

class _QuickAction {
  const _QuickAction({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
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
          child: Text(
            value,
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}
