import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../domain/entities/ticket_models.dart';
import '../controllers/tickets_controller.dart';

class QrDialog extends StatefulWidget {
  const QrDialog({super.key, required this.ticket});

  final Ticket ticket;

  @override
  State<QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<QrDialog> {
  late TicketsController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppScope.of(context).tickets;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.openQr(widget.ticket);
    });
  }

  @override
  void dispose() {
    _controller.closeQr();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              Icons.qr_code_2_rounded,
              color: scheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Código QR dinámico',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final qr = _controller.qr;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Asiento ${widget.ticket.seat}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    'ID ${shortId(widget.ticket.id)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Center(
                  child: _controller.qrLoading
                      ? const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : qr == null
                          ? const SizedBox(
                              width: 220,
                              height: 220,
                              child: Center(
                                child: Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 64,
                                  color: Colors.black26,
                                ),
                              ),
                            )
                          : QrImageView(
                              data: qr.value,
                              version: QrVersions.auto,
                              size: 220,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 12),
              if (_controller.qrError != null) ...[
                ErrorBanner(message: _controller.qrError!),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(
                    Icons.autorenew_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _controller.qrSecondsLeft > 0
                        ? 'Se renueva en ${_controller.qrSecondsLeft}s'
                        : 'Renovando código…',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rotación 15 s',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const InfoBanner(
                message:
                    'Muestra este código en la puerta. No lo compartas: el validador lo consume una sola vez.',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: qr == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: qr.value),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Código QR copiado.'),
                          ),
                        );
                      },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar código QR'),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
