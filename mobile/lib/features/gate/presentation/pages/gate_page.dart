import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/loading_button.dart';
import '../../../../shared/widgets/section_header.dart';

class GatePage extends StatefulWidget {
  const GatePage({super.key});

  @override
  State<GatePage> createState() => _GatePageState();
}

class _GatePageState extends State<GatePage> {
  final _qr = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).gate.loadPublicKey();
    });
  }

  @override
  void dispose() {
    _qr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).gate;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const SectionHeader(
              title: 'Validación en puerta',
              subtitle:
                  'Valida el QR del asistente y confirma su ingreso al estadio.',
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
              InfoBanner(
                message: controller.notice!,
                icon: Icons.check_circle_outline_rounded,
                color: scheme.primary,
              ),
              const SizedBox(height: 12),
            ],
            if (controller.scannedSeat != null) ...[
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: scheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Acceso autorizado',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Asiento ${controller.scannedSeat} · boleto consumido',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                    title: 'Escanear o pegar QR',
                    subtitle: 'Pega el contenido del QR del boleto del asistente.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _qr,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Contenido del QR',
                      alignLabelWithHint: true,
                      hintText: 'Contenido del QR…',
                    ),
                  ),
                  const SizedBox(height: 14),
                  LoadingButton(
                    label: 'Validar QR',
                    icon: Icons.qr_code_scanner_rounded,
                    loading: controller.scanning,
                    onPressed: () async {
                      final ok = await controller.scan(_qr.text);
                      if (ok) _qr.clear();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'Clave del validador',
                    subtitle:
                        'Clave oficial del estadio para validar los boletos.',
                    trailing: IconButton(
                      tooltip: 'Copiar clave',
                      onPressed: controller.publicKey == null
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: controller.publicKey!),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Llave pública copiada.'),
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (controller.loadingKey)
                    const Center(child: CircularProgressIndicator())
                  else if (controller.publicKey == null)
                    Text(
                      'No se pudo cargar la llave pública.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: SelectableText(
                        controller.publicKey!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const InfoBanner(
              message:
                  'Un QR es válido solo por unos segundos y se invalida si el boleto fue transferido o ya se usó. En estos casos el acceso se rechaza.',
              icon: Icons.event_busy_outlined,
            ),
          ],
        );
      },
    );
  }
}
