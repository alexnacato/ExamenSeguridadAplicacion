import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/auth_page.dart';
import '../features/home/presentation/home_shell.dart';
import 'app_scope.dart';
import 'theme/app_theme.dart';

class TicketSecApp extends StatefulWidget {
  const TicketSecApp({super.key});

  @override
  State<TicketSecApp> createState() => _TicketSecAppState();
}

class _TicketSecAppState extends State<TicketSecApp> {
  late final AppDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = AppDependencies.create();
  }

  @override
  void dispose() {
    _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: _dependencies,
      child: AnimatedBuilder(
        animation: _dependencies.theme,
        builder: (context, _) {
          return MaterialApp(
            title: 'TicketSec',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _dependencies.theme.mode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final sessionStore = AppScope.of(context).sessionStore;

    return AnimatedBuilder(
      animation: sessionStore,
      builder: (context, _) {
        return sessionStore.isAuthenticated
            ? const HomeShell()
            : const AuthPage();
      },
    );
  }
}
