import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/nakama_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_flappy_bird/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    final mockNakamaManager = NakamaManager();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(nakamaManager: mockNakamaManager));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
