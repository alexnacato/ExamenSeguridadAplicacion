import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../admin/presentation/pages/admin_page.dart';
import '../../auth/domain/entities/session.dart';
import '../../gate/presentation/pages/gate_page.dart';
import '../../support/presentation/pages/support_page.dart';
import '../../tickets/presentation/pages/buy_page.dart';
import '../../tickets/presentation/pages/tickets_page.dart';
import 'home_overview_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final session = deps.sessionStore.session;
    if (session == null) return const SizedBox.shrink();

    final tabs = _tabsFor(session.role);
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(compact: true),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          for (final tab in tabs) _pageFor(tab.key, session),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _selectTab,
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }

  Widget _pageFor(String key, Session session) {
    switch (key) {
      case 'buy':
        return BuyPage(onViewTickets: () => _selectKey('tickets'));
      case 'tickets':
        return const TicketsPage();
      case 'gate':
        return const GatePage();
      case 'support':
        return const SupportPage();
      case 'admin':
        return const AdminPage();
      case 'home':
      default:
        return HomeOverviewPage(
          session: session,
          onNavigate: _selectTab,
        );
    }
  }

  void _selectTab(int index) {
    final deps = AppScope.of(context);
    final tabs = _tabsFor(deps.sessionStore.session?.role ?? 'cliente');
    final target = index.clamp(0, tabs.length - 1);
    setState(() => _index = target);
    _onTabSelected(tabs[target].key);
  }

  void _selectKey(String key) {
    final deps = AppScope.of(context);
    final tabs = _tabsFor(deps.sessionStore.session?.role ?? 'cliente');
    final target = tabs.indexWhere((tab) => tab.key == key);
    if (target < 0) return;
    setState(() => _index = target);
    _onTabSelected(key);
  }

  void _onTabSelected(String key) {
    final deps = AppScope.of(context);
    switch (key) {
      case 'tickets':
        deps.tickets.load();
        break;
      case 'admin':
        deps.admin.load();
        break;
      case 'gate':
        if (deps.gate.publicKey == null) deps.gate.loadPublicKey();
        break;
    }
  }

  Future<void> _logout() async {
    final deps = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Deseas salir de tu cuenta en este dispositivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    deps.buy.reset();
    deps.tickets.reset();
    deps.gate.reset();
    deps.support.reset();
    deps.admin.reset();
    await deps.auth.logout();
  }

  List<_Tab> _tabsFor(String role) {
    switch (role) {
      case 'validador':
        return const [
          _Tab(
            key: 'home',
            label: 'Inicio',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
          ),
          _Tab(
            key: 'gate',
            label: 'Puerta',
            icon: Icons.qr_code_scanner_outlined,
            selectedIcon: Icons.qr_code_scanner_rounded,
          ),
        ];
      case 'soporte':
        return const [
          _Tab(
            key: 'home',
            label: 'Inicio',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
          ),
          _Tab(
            key: 'support',
            label: 'Soporte',
            icon: Icons.support_agent_outlined,
            selectedIcon: Icons.support_agent_rounded,
          ),
        ];
      case 'admin':
        return const [
          _Tab(
            key: 'home',
            label: 'Inicio',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
          ),
          _Tab(
            key: 'admin',
            label: 'Panel',
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights_rounded,
          ),
        ];
      case 'cliente':
      default:
        return const [
          _Tab(
            key: 'home',
            label: 'Inicio',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
          ),
          _Tab(
            key: 'buy',
            label: 'Comprar',
            icon: Icons.shopping_cart_outlined,
            selectedIcon: Icons.shopping_cart_rounded,
          ),
          _Tab(
            key: 'tickets',
            label: 'Boletos',
            icon: Icons.confirmation_number_outlined,
            selectedIcon: Icons.confirmation_number_rounded,
          ),
        ];
    }
  }
}

class _Tab {
  const _Tab({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
