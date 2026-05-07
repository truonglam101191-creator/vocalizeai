import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocalizeai/main.dart';
import 'package:vocalizeai/features/home/presentation/controllers/home_controller.dart';

class MockHomeController extends HomeController {
  MockHomeController(super.ref);

  @override
  Future<void> initBackend() async {
    // Mock initialization: Do nothing to prevent actual HTTP calls during test.
  }
}

void main() {
  testWidgets('VocalizeAI app smoke test - renders HomePage and Tabs',
      (WidgetTester tester) async {
    // Build our app and trigger a frame with Mocked dependencies.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeControllerProvider.overrideWith((ref) => MockHomeController(ref)),
          isBackendReadyProvider.overrideWith((ref) => true),
        ],
        child: const VocalizeAIApp(),
      ),
    );

    // Wait for go_router to settle
    await tester.pumpAndSettle();

    // Verify app title exists
    expect(find.text('VocalizeAI'), findsOneWidget);

    // Verify the three tabs exist
    expect(find.text('STT'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('TTS'), findsOneWidget);

    // Verify STT tab content is visible (default tab)
    expect(find.text('Extract Text (STT)'), findsOneWidget);

    // Tap Translate tab
    await tester.tap(find.text('Translate'));
    await tester.pumpAndSettle();

    // Verify Translate tab content is visible
    expect(find.text('Translate Text'), findsOneWidget);
  });
}
