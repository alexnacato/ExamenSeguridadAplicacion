import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/loading_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../controllers/buy_controller.dart';
import '../widgets/seat_grid.dart';

class BuyPage extends StatefulWidget {
  const BuyPage({super.key, this.onViewTickets});

  final VoidCallback? onViewTickets;

  @override
  State<BuyPage> createState() => _BuyPageState();
}

class _BuyPageState extends State<BuyPage> {
  final _formKey = GlobalKey<FormState>();
  final _pan = TextEditingController();
  final _exp = TextEditingController();
  final _cvv = TextEditingController();

  @override
  void dispose() {
    _pan.dispose();
    _exp.dispose();
    _cvv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).buy;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            SectionHeader(
              title: 'Comprar boletos',
              subtitle:
                  'Sala de espera, bloqueo de asiento por 2 minutos y pago tokenizado.',
              trailing: IconButton(
                tooltip: 'Actualizar asientos',
                onPressed: controller.admitted && !controller.loading
                    ? controller.refreshSeats
                    : null,
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
            if (!controller.admitted)
              _QueueCard(controller: controller)
            else if (controller.seatMap == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final map = _SeatMapCard(controller: controller);
                  final checkout = _CheckoutCard(
                    controller: controller,
                    formKey: _formKey,
                    pan: _pan,
                    exp: _exp,
                    cvv: _cvv,
                    onPay: () => _pay(controller),
                  );

                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        map,
                        const SizedBox(height: 16),
                        checkout,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: map),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: checkout),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _pay(BuyController controller) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await controller.pay(
      pan: onlyDigits(_pan.text),
      exp: _exp.text,
      cvv: _cvv.text,
    );

    if (!mounted || !ok) return;

    _pan.clear();
    _exp.clear();
    _cvv.clear();

    final purchase = controller.lastPurchase;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.check_circle_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 44,
        ),
        title: const Text('Compra confirmada'),
        content: Text(
          purchase == null
              ? 'Tus boletos ya están disponibles.'
              : 'Emitimos ${purchase.ids.length} boleto(s) por ${money(purchase.total)}. Ya puedes mostrar tu QR dinámico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Seguir comprando'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onViewTickets?.call();
            },
            child: const Text('Ver mis boletos'),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.controller});

  final BuyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final waiting = controller.position > 0 || controller.entering;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  waiting
                      ? Icons.hourglass_top_rounded
                      : Icons.groups_2_outlined,
                  color: scheme.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiting ? 'Buscando tu turno' : 'Sala de espera virtual',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      waiting
                          ? 'Te admitiremos automáticamente. No cierres esta pantalla.'
                          : 'Protegemos el inventario admitiendo hasta 5 personas por segundo.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (waiting) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              borderRadius: BorderRadius.circular(999),
              minHeight: 6,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  controller.position > 0
                      ? 'Posición en la cola: #${controller.position}'
                      : 'Verificando admisión…',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  'Actualiza cada 3 s',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 18),
            LoadingButton(
              label: 'Entrar a la sala',
              icon: Icons.login_rounded,
              loading: controller.entering,
              onPressed: controller.enterQueue,
            ),
          ],
          const SizedBox(height: 16),
          const InfoBanner(
            message:
                'Al entrar podrás bloquear hasta 4 asientos durante 2 minutos. El bloqueo se libera automáticamente si no completas el pago.',
            icon: Icons.timer_outlined,
          ),
        ],
      ),
    );
  }
}

class _SeatMapCard extends StatelessWidget {
  const _SeatMapCard({required this.controller});

  final BuyController controller;

  @override
  Widget build(BuildContext context) {
    final map = controller.seatMap!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Mapa de asientos',
            subtitle: 'Precio por boleto: ${money(map.price)}',
            trailing: controller.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 18),
          SeatGrid(
            seatMap: map,
            selected: controller.selected,
            enabled: !controller.seatBusy && !controller.purchasing,
            onTap: controller.toggleSeat,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _Legend(
                color: scheme.surface,
                border: scheme.outlineVariant,
                label: 'Libre',
              ),
              _Legend(
                color: scheme.primaryContainer,
                border: scheme.primary.withValues(alpha: .45),
                label: 'Tu bloqueo',
              ),
              _Legend(
                color: scheme.primary,
                border: scheme.primary,
                label: 'Seleccionado',
              ),
              _Legend(
                color: scheme.tertiaryContainer.withValues(alpha: .65),
                border: scheme.tertiary.withValues(alpha: .35),
                label: 'Bloqueado',
              ),
              _Legend(
                color: scheme.surfaceContainerHighest,
                border: scheme.outlineVariant,
                label: 'Vendido',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({
    required this.controller,
    required this.formKey,
    required this.pan,
    required this.exp,
    required this.cvv,
    required this.onPay,
  });

  final BuyController controller;
  final GlobalKey<FormState> formKey;
  final TextEditingController pan;
  final TextEditingController exp;
  final TextEditingController cvv;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = controller.selected.toList()..sort();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Pago',
            subtitle: 'La tarjeta se tokeniza en la pasarela; el API nunca ve el PAN.',
          ),
          const SizedBox(height: 16),
          if (selected.isEmpty)
            InfoBanner(
              message:
                  'Selecciona hasta 4 asientos en el mapa para continuar.',
              icon: Icons.touch_app_outlined,
              color: scheme.primary,
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final seat in selected)
                  Chip(
                    label: Text(seat),
                    avatar: Icon(
                      Icons.event_seat_rounded,
                      size: 15,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '${selected.length} boleto(s)',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  money(controller.total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: pan,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: validateCardNumber,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19),
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) {
                          final text = maskCardInput(newValue.text);
                          return TextEditingValue(
                            text: text,
                            selection: TextSelection.collapsed(
                              offset: text.length,
                            ),
                          );
                        },
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Número de tarjeta',
                      prefixIcon: Icon(Icons.credit_card_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: exp,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: validateExpiry,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) {
                                final text = formatExpiry(newValue.text);
                                return TextEditingValue(
                                  text: text,
                                  selection: TextSelection.collapsed(
                                    offset: text.length,
                                  ),
                                );
                              },
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'MM/AA',
                            prefixIcon: Icon(Icons.event_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: cvv,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: validateCvv,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'CVV',
                            prefixIcon: Icon(Icons.password_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const InfoBanner(
                    message:
                        'Prueba: 4242 4242 4242 4242 · 12/30 · 123 (pasarela simulada)',
                    icon: Icons.science_outlined,
                  ),
                  const SizedBox(height: 14),
                  LoadingButton(
                    label: 'Pagar ${money(controller.total)}',
                    icon: Icons.lock_rounded,
                    loading: controller.purchasing,
                    onPressed: controller.canPay ? onPay : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.border,
    required this.label,
  });

  final Color color;
  final Color border;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
