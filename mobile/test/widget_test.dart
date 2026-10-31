import 'package:flutter_test/flutter_test.dart';
import 'package:ticketsec_mobile/app/app.dart';

void main() {
  testWidgets('shows sign-in and account creation forms', (tester) async {
    await tester.pumpWidget(const TicketSecApp());

    expect(find.text('TicketSec'), findsOneWidget);
    expect(find.text('Ingresar'), findsNWidgets(2));

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Cédula (10 dígitos)'), findsOneWidget);
  });
}
