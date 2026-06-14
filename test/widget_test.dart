import 'package:flutter_test/flutter_test.dart';
import 'package:photopedia/main.dart';
import 'package:photopedia/models/photo_state.dart';

void main() {
  testWidgets('App should launch without errors', (WidgetTester tester) async {
    final appState = AppState();
    await tester.pumpWidget(PhotopediaApp(appState: appState));
    // Verify app renders the navigation bar
    expect(find.text('Beranda'), findsOneWidget);
  });
}
