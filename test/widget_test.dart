import 'package:flutter_test/flutter_test.dart';
import 'package:notex/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NoteXApp());
    expect(find.text('NoteX'), findsOneWidget);
  });
}
