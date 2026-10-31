import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/loading_button.dart';
import '../auth_controller.dart';

enum _AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _loginKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _cedula = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _showLoginPassword = false;
  bool _showRegisterPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _cedula.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: theme.brightness == Brightness.dark ? .16 : .08),
              theme.scaffoldBackgroundColor,
              scheme.tertiary.withValues(alpha: theme.brightness == Brightness.dark ? .12 : .06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final hero = _AuthHero(compact: !wide);
                    final card = _buildCard(context, auth);

                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          hero,
                          const SizedBox(height: 24),
                          card,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 6, child: hero),
                        const SizedBox(width: 48),
                        Expanded(flex: 5, child: card),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, AuthController auth) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: auth,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        auth.awaitingOtp ? 'Verificación 2FA' : 'Acceso seguro',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cambiar tema',
                      onPressed: () => AppScope.of(context).theme.toggle(
                            theme.brightness,
                          ),
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  auth.awaitingOtp
                      ? 'Confirma el código enviado a ${auth.pendingEmail}.'
                      : 'Boletos con QR dinámico, pagos tokenizados y auditoría WORM.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (auth.error != null) ...[
                  ErrorBanner(
                    message: auth.error!,
                    onDismiss: auth.clearMessages,
                  ),
                  const SizedBox(height: 14),
                ],
                if (auth.notice != null) ...[
                  InfoBanner(message: auth.notice!),
                  const SizedBox(height: 14),
                ],
                if (auth.awaitingOtp)
                  _buildOtp(context, auth)
                else ...[
                  _ModeSwitch(
                    mode: _mode,
                    onChanged: (mode) {
                      setState(() => _mode = mode);
                      auth.clearMessages();
                    },
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _mode == _AuthMode.login
                        ? _buildLogin(context, auth)
                        : _buildRegister(context, auth),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Máximo 2 dispositivos por cuenta · sesiones revocables',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogin(BuildContext context, AuthController auth) {
    return Form(
      key: _loginKey,
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: validateEmail,
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: !_showLoginPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: (value) =>
                requiredField(value, 'tu contraseña'),
            onFieldSubmitted: (_) => _submitLogin(auth),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _showLoginPassword = !_showLoginPassword,
                ),
                icon: Icon(
                  _showLoginPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          LoadingButton(
            label: 'Ingresar',
            icon: Icons.login_rounded,
            loading: auth.loading,
            onPressed: () => _submitLogin(auth),
          ),
          const SizedBox(height: 18),
          _DemoAccounts(onSelected: _fillDemo),
        ],
      ),
    );
  }

  Widget _buildRegister(BuildContext context, AuthController auth) {
    return Form(
      key: _registerKey,
      child: Column(
        key: const ValueKey('register'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: validateName,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cedula,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: validateCedula,
            decoration: const InputDecoration(
              labelText: 'Cédula (10 dígitos)',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _regEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: validateEmail,
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _regPassword,
            obscureText: !_showRegisterPassword,
            textInputAction: TextInputAction.next,
            validator: validatePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              helperText: '10+ caracteres con mayúscula, número y símbolo',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _showRegisterPassword = !_showRegisterPassword,
                ),
                icon: Icon(
                  _showRegisterPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirm,
            obscureText: !_showConfirm,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value != _regPassword.text) {
                return 'Las contraseñas no coinciden.';
              }
              return requiredField(value, 'la confirmación');
            },
            onFieldSubmitted: (_) => _submitRegister(auth),
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
                icon: Icon(
                  _showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          LoadingButton(
            label: 'Crear cuenta',
            icon: Icons.person_add_alt_1_rounded,
            loading: auth.loading,
            onPressed: () => _submitRegister(auth),
          ),
        ],
      ),
    );
  }

  Widget _buildOtp(BuildContext context, AuthController auth) {
    final theme = Theme.of(context);

    return Form(
      key: _otpKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (auth.devOtp != null) ...[
            InfoBanner(
              message: 'Modo demo · OTP: ${auth.devOtp}',
              icon: Icons.vpn_key_outlined,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _otp,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: validateOtp,
            onFieldSubmitted: (_) => _submitOtp(auth),
            decoration: const InputDecoration(
              labelText: 'Código de 6 dígitos',
              counterText: '',
            ),
            maxLength: 6,
          ),
          const SizedBox(height: 18),
          LoadingButton(
            label: 'Verificar código',
            icon: Icons.verified_user_outlined,
            loading: auth.loading,
            onPressed: () => _submitOtp(auth),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: auth.loading ? null : auth.cancelOtp,
            child: const Text('Usar otra cuenta'),
          ),
          Text(
            'El código expira en 2 minutos y admite 3 intentos.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitLogin(AuthController auth) async {
    FocusScope.of(context).unfocus();
    if (!(_loginKey.currentState?.validate() ?? false)) return;

    final ok = await auth.login(
      email: _email.text,
      password: _password.text,
    );

    if (!mounted) return;
    if (ok) {
      _otp.clear();
      _password.clear();
    }
  }

  Future<void> _submitRegister(AuthController auth) async {
    FocusScope.of(context).unfocus();
    if (!(_registerKey.currentState?.validate() ?? false)) return;

    final ok = await auth.register(
      name: _name.text,
      cedula: _cedula.text,
      email: _regEmail.text,
      password: _regPassword.text,
    );

    if (!mounted || !ok) return;

    setState(() {
      _mode = _AuthMode.login;
      _email.text = auth.lastRegisteredEmail ?? _regEmail.text.trim();
      _name.clear();
      _cedula.clear();
      _regEmail.clear();
      _regPassword.clear();
      _confirm.clear();
    });
  }

  Future<void> _submitOtp(AuthController auth) async {
    FocusScope.of(context).unfocus();
    if (!(_otpKey.currentState?.validate() ?? false)) return;

    await auth.verifyOtp(_otp.text);
  }

  void _fillDemo(String email, String password) {
    final auth = AppScope.of(context).auth;
    setState(() {
      _mode = _AuthMode.login;
      _email.text = email;
      _password.text = password;
    });
    auth.clearMessages();
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ModeTab(
            label: 'Ingresar',
            selected: mode == _AuthMode.login,
            onTap: () => onChanged(_AuthMode.login),
          ),
          _ModeTab(
            label: 'Crear cuenta',
            selected: mode == _AuthMode.register,
            onTap: () => onChanged(_AuthMode.register),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({required this.onSelected});

  final void Function(String email, String password) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = <(String, String, String)>[
      ('Cliente', 'cliente@demo.com', 'Cliente#2026'),
      ('Validador', 'validador@demo.com', 'Validador#2026'),
      ('Soporte', 'soporte@demo.com', 'Soporte#2026'),
      ('Admin', 'admin@demo.com', 'Admin#2026'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.science_outlined,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Cuentas de demostración',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final account in accounts)
              ActionChip(
                label: Text(account.$1),
                onPressed: () => onSelected(account.$2, account.$3),
              ),
          ],
        ),
      ],
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLogo(),
        SizedBox(height: compact ? 24 : 40),
        Text(
          'Tu entrada,\nverificada en segundos.',
          style: TextStyle(
            fontSize: compact ? 32 : 48,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.4,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            'Compra boletos con pago tokenizado, recibe un QR firmado que rota cada 15 segundos y audita cada evento con logs inmutables.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 34),
          const _Feature(
            icon: Icons.qr_code_2_rounded,
            title: 'QR dinámico firmado',
            text: 'ECDSA P-256 y rotación de 15 s contra capturas y replay.',
          ),
          const SizedBox(height: 16),
          const _Feature(
            icon: Icons.credit_card_rounded,
            title: 'Pago tokenizado',
            text: 'La tarjeta nunca toca el servidor: solo viaja un token de un uso.',
          ),
          const SizedBox(height: 16),
          const _Feature(
            icon: Icons.lock_clock_rounded,
            title: 'Auditoría WORM',
            text: 'Cadena de hashes inmutable para cada compra, acceso y bloqueo.',
          ),
        ],
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.primary.withValues(alpha: .2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_outlined, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'MITRE ATT&CK · PCI-DSS · OWASP',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scheme.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
