import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/gateway_client.dart';
import '../features/admin/data/repositories/admin_repository_impl.dart';
import '../features/admin/presentation/controllers/admin_controller.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/session_store.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/gate/data/repositories/gate_repository_impl.dart';
import '../features/gate/presentation/controllers/gate_controller.dart';
import '../features/support/data/repositories/support_repository_impl.dart';
import '../features/support/presentation/controllers/support_controller.dart';
import '../features/tickets/data/repositories/tickets_repository_impl.dart';
import '../features/tickets/presentation/controllers/buy_controller.dart';
import '../features/tickets/presentation/controllers/tickets_controller.dart';
import 'theme/theme_controller.dart';

class AppDependencies {
  AppDependencies._({
    required this.config,
    required this.sessionStore,
    required this.api,
    required this.gateway,
    required this.auth,
    required this.buy,
    required this.tickets,
    required this.gate,
    required this.support,
    required this.admin,
    required this.theme,
  });

  final AppConfig config;
  final SessionStore sessionStore;
  final ApiClient api;
  final GatewayClient gateway;
  final AuthController auth;
  final BuyController buy;
  final TicketsController tickets;
  final GateController gate;
  final SupportController support;
  final AdminController admin;
  final ThemeController theme;

  factory AppDependencies.create() {
    final config = AppConfig.fromEnvironment();
    final sessionStore = SessionStore();

    final api = ApiClient(
      baseUri: Uri.parse(config.apiBaseUrl),
      tokenProvider: () => sessionStore.token,
      onUnauthorized: sessionStore.clear,
    );
    final gateway = GatewayClient(
      baseUri: Uri.parse(config.gatewayBaseUrl),
    );

    final ticketsRepository = TicketsRepositoryImpl(api);
    final auth = AuthController(AuthRepositoryImpl(api), sessionStore);
    final buy = BuyController(ticketsRepository, gateway);
    final tickets = TicketsController(ticketsRepository);
    final gate = GateController(GateRepositoryImpl(api));
    final support = SupportController(SupportRepositoryImpl(api));
    final admin = AdminController(AdminRepositoryImpl(api));

    sessionStore.addListener(() {
      if (sessionStore.isAuthenticated) return;
      buy.reset();
      tickets.reset();
      gate.reset();
      support.reset();
      admin.reset();
    });

    return AppDependencies._(
      config: config,
      sessionStore: sessionStore,
      api: api,
      gateway: gateway,
      auth: auth,
      buy: buy,
      tickets: tickets,
      gate: gate,
      support: support,
      admin: admin,
      theme: ThemeController(),
    );
  }

  void dispose() {
    auth.dispose();
    buy.dispose();
    tickets.dispose();
    gate.dispose();
    support.dispose();
    admin.dispose();
    theme.dispose();
    api.close();
    gateway.close();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no encontrado en el árbol de widgets.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
