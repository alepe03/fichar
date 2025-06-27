import 'package:flutter_test/flutter_test.dart';
import 'package:fichar/main.dart';

void main() {
  testWidgets('FichadorApp loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const FichadorApp());
    expect(find.byType(FichadorApp), findsOneWidget);
  });
}
