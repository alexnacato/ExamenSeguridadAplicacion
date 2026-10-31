import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ticketsec_mobile/app/app_scope.dart';
import 'package:ticketsec_mobile/app/theme/theme_controller.dart';
import 'package:ticketsec_mobile/core/config/app_config.dart';
import 'package:ticketsec_mobile/core/network/api_client.dart';
import 'package:ticketsec_mobile/core/network/gateway_client.dart';
import 'package:ticketsec_mobile/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:ticketsec_mobile/features/admin/presentation/controllers/admin_controller.dart';
import 'package:ticketsec_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ticketsec_mobile/features/auth/domain/session_store.dart';
import 'package:ticketsec_mobile/features/auth/presentation/auth_controller.dart';
import 'package:ticketsec_mobile/features/gate/data/repositories/gate_repository_impl.dart';
import 'package:ticketsec_mobile/features/gate/presentation/controllers/gate_controller.dart';
import 'package:ticketsec_mobile/features/support/data/repositories/support_repository_impl.dart';
import 'package:ticketsec_mobile/features/support/presentation/controllers/support_controller.dart';
import 'package:ticketsec_mobile/features/tickets/data/repositories/tickets_repository_impl.dart';
import 'package:ticketsec_mobile/features/tickets/domain/entities/queue_status.dart';
import 'package:ticketsec_mobile/features/tickets/domain/entities/ticket_models.dart';
import 'package:ticketsec_mobile/features/tickets/domain/repositories/tickets_repository.dart';
import 'package:ticketsec_mobile/features/tickets/presentation/controllers/buy_controller.dart';
import 'package:ticketsec_mobile/features/tickets/presentation/controllers/tickets_controller.dart';
import 'package:ticketsec_mobile/features/tickets/presentation/pages/tickets_page.dart';

class FakeTicketsRepository implements TicketsRepository {
  FakeTicketsRepository({this.rotateSeconds = 2, this.latency = const Duration(milliseconds: 150)});

  final int rotateSeconds;
  final Duration latency;
  int _fetches = 0;

  @override
  Future<QueueStatus> joinQueue() async =>
      const QueueStatus(admitted: true, position: 0);

  @override
  Future<QueueStatus> queueStatus() async =>
      const QueueStatus(admitted: true, position: 0);

  @override
  Future<SeatMap> fetchSeats() async => const SeatMap(price: 25, seats: {});

  @override
  Future<void> lockSeat(String seat) async {}

  @override
  Future<void> unlockSeat(String seat) async {}

  @override
  Future<PurchaseResult> buy({
    required List<String> seats,
    required String payToken,
  }) async =>
      const PurchaseResult(ids: [], total: 0);

  @override
  Future<List<Ticket>> mine() async => const [
        Ticket(
          id: 'bf3f9c1e-1111-2222-3333-444455556666',
          seat: 'A10',
          used: false,
          last4: '4242',
        ),
      ];

  @override
  Future<DynamicQr> qr(String ticketId) async {
    await Future<void>.delayed(latency);
    final payload = 'a' * 120;
    final signature = 'b' * 86;
    final value = '$payload.$signature-$_fetches';
    _fetches++;
    return DynamicQr(value: value, rotateSeconds: rotateSeconds);
  }

  @override
  Future<void> transfer({required String ticketId, required String email}) async {}
}

AppDependencies buildTestDependencies(
  FakeTicketsRepository fakeRepo,
) {
  const config = AppConfig(
    apiBaseUrl: 'http://localhost:3000',
    gatewayBaseUrl: 'http://localhost:4001',
    fallbackPrice: 25,
    devShowOtp: true,
  );
  final sessionStore = SessionStore();
  final api = ApiClient(
    baseUri: Uri.parse(config.apiBaseUrl),
    tokenProvider: () => sessionStore.token,
  );
  final gateway = GatewayClient(baseUri: Uri.parse(config.gatewayBaseUrl));
  final realRepository = TicketsRepositoryImpl(api);

  return AppDependencies(
    config: config,
    sessionStore: sessionStore,
    api: api,
    gateway: gateway,
    auth: AuthController(AuthRepositoryImpl(api), sessionStore),
    buy: BuyController(realRepository, gateway),
    tickets: TicketsController(fakeRepo),
    gate: GateController(GateRepositoryImpl(api)),
    support: SupportController(SupportRepositoryImpl(api)),
    admin: AdminController(AdminRepositoryImpl(api)),
    theme: ThemeController(),
  );
}

void main() {
  testWidgets(
    'QR dialog survives ticks, rotations, latency and reopen cycles (phone viewport)',
    (tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      addTearDown(tester.view.reset);

      final deps = buildTestDependencies(
        FakeTicketsRepository(rotateSeconds: 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            dependencies: deps,
            child: const Scaffold(body: TicketsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // ignore: avoid_print
      print(
        'tickets=${deps.tickets.tickets.length} loading=${deps.tickets.loading} error=${deps.tickets.error}',
      );
      expect(find.widgetWithText(OutlinedButton, 'Ver QR'), findsOneWidget);

      for (var cycle = 0; cycle < 3; cycle++) {
        await tester.tap(find.widgetWithText(OutlinedButton, 'Ver QR').first);
        await tester.pump();
        await tester.pump();

        // One full rotation: QR lasts 2 s, fetch has latency.
        for (var s = 0; s < 7; s++) {
          await tester.pump(const Duration(seconds: 1));
        }

        // Close the dialog while timers are running.
        await tester.tap(find.widgetWithText(TextButton, 'Cerrar').first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
      }

      expect(tester.takeException(), isNull);
    },
  );
}
