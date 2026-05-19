// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('EcoPulse App smoke test', (WidgetTester tester) async {
    // Construimos nuestra aplicación de EcoPulse
    await tester.pumpWidget(const EcoPulseApp());

    // Verificamos que se muestre el título principal en la barra superior
    expect(find.text('EcoPulse - Calidad del Aire'), findsOneWidget);

    // Verificamos que el indicador de carga o el texto del estado inicial aparezca
    expect(find.text('Estado: Cargando datos...'), findsOneWidget);
  });
}