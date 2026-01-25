import 'package:flutter_test/flutter_test.dart';
import 'package:clipsync/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ClipSyncApp());

    // Verify that the Live screen is displayed
    expect(find.text('Live Clipboard'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
  });
}
