import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../domain/entities/ticket_models.dart';

class TicketQrSheet extends StatefulWidget {
  const TicketQrSheet({
    super.key,
    required this.qrLoader,
    required this.ticketId,
    required this.seat,
  });

  final Future<DynamicQr> Function(String ticketId) qrLoader;
  final String ticketId;
  final String seat;

  @override
  State<TicketQrSheet> createState() => _TicketQrSheetState();
}

class _TicketQrSheetState extends State<TicketQrSheet> {
  Timer? _timer;
  bool _loading = true;
  DynamicQr? _qr;
  String? _error;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        return;
      }
      _fetch();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;

    setState(() {
      if (_qr == null) _loading = true;
      _error = null;
    });

    try {
      final qr = await widget.qrLoader(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _secondsLeft = qr.rotateSeconds;
        _loading = false;
        _error = null;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo generar el código QR.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
              'Tu código de ingreso',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width - 40,
        child: _QrContent(
          seat: widget.seat,
          ticketId: widget.ticketId,
          loading: _loading,
          qr: _qr,
          error: _error,
          secondsLeft: _secondsLeft,
          onCopy: _copyToClipboard,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _copyToClipboard(String value) async {
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Código QR copiado.')),
    );
  }
}

class _QrContent extends StatelessWidget {
  const _QrContent({
    required this.seat,
    required this.ticketId,
    required this.loading,
    required this.qr,
    required this.error,
    required this.secondsLeft,
    required this.onCopy,
  });

  final String seat;
  final String ticketId;
  final bool loading;
  final DynamicQr? qr;
  final String? error;
  final int secondsLeft;
  final void Function(String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dialogMaxWidth = MediaQuery.of(context).size.width - 40;
    final qrSize = (dialogMaxWidth - 28).clamp(220.0, 300.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Asiento $seat',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              'ID ${shortId(ticketId)}',
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
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: qrSize,
                  height: qrSize,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.autorenew_rounded,
                        size: 46,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Generando código…',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : qr == null
                  ? SizedBox(
                      width: qrSize,
                      height: qrSize,
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          size: 64,
                          color: Colors.black26,
                        ),
                      ),
                    )
                  : SizedBox(
                      width: qrSize,
                      height: qrSize,
                      child: CustomPaint(
                        painter: QrPainter(
                          data: qr!.value,
                          version: QrVersions.auto,
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
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              secondsLeft > 0
                  ? Icons.autorenew_rounded
                  : Icons.sync_rounded,
              size: 16,
              color: scheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              secondsLeft > 0
                  ? 'Se renueva en ${secondsLeft}s'
                  : 'Renovando código…',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (error != null) ...[
          ErrorBanner(message: error!),
          const SizedBox(height: 12),
        ],
        const InfoBanner(
          message:
              'Muestra este código en la puerta. Se renueva solo y no lo compartas.',
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: qr == null
              ? null
              : () => onCopy(qr!.value),
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copiar código QR'),
        ),
      ],
    );
  }
}
