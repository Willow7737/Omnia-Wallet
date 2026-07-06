import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/format.dart';
import 'package:omnia_wallet/features/onboarding/onboarding_screen.dart';

void main() {
  group('Fmt', () {
    test('ubc and number formatting', () {
      expect(Fmt.ubc(1000), '1,000 UBC');
      expect(Fmt.number(2500), '2,500');
    });

    test('shortDid abbreviates long DIDs', () {
      expect(
        Fmt.shortDid('did:omnia:1a2b3c4d5e6f7a8b'),
        'did:omnia:1a2b…7a8b',
      );
      // Non-omnia strings are returned as-is.
      expect(Fmt.shortDid('something-else'), 'something-else');
    });
  });

  testWidgets('Onboarding renders create/import actions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingScreen()),
      ),
    );
    // Advance past the staggered FadeSlideIn entrance delays/animations so no
    // timers remain pending at the end of the test.
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Create a new wallet'), findsOneWidget);
    expect(find.text('Import from recovery phrase'), findsOneWidget);
    expect(find.text('Sign in with your Omnia account'), findsOneWidget);
  });
}
