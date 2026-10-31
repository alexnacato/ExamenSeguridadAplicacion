import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../domain/entities/ticket_models.dart';
import '../controllers/tickets_controller.dart';

class TransferDialog extends StatefulWidget {
  const TransferDialog({super.key, required this.ticket});

  final Ticket ticket;

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  late TicketsController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppScope.of(context).tickets;
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              color: scheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Transferir boleto',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
        ],
      ),
      content: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Asiento ${widget.ticket.seat} · ID ${shortId(widget.ticket.id)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                if (_controller.error != null) ...[
                  ErrorBanner(message: _controller.error!),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: validateEmail,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Correo del destinatario',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                const InfoBanner(
                  message:
                      'El QR anterior se invalida al transferir. El destinatario debe ser cliente y no puede superar 4 boletos.',
                  icon: Icons.security_outlined,
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _controller.transferring
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _controller.transferring ? null : _submit,
          child: _controller.transferring
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Text('Transferir'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await _controller.transfer(
      ticketId: widget.ticket.id,
      email: _email.text,
    );

    if (!mounted || !ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Boleto transferido correctamente.')),
    );
    Navigator.of(context).pop();
  }
}
