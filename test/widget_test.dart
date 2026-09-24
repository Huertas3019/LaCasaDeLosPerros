import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lacasa_perros_pos/main.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Carga inicial de la App POS', (WidgetTester tester) async {
    await tester.pumpWidget(const LaCasaDeLosPerrosApp());
    expect(find.text('LA CASA DE LOS PERROS'), findsOneWidget);
  });
}
