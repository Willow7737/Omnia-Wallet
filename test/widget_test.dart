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

  testWidgets('Onboarding shows slides, then methods after Skip',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Phase 1: slides with Skip + Next.
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Meet your Omnia wallet'), findsOneWidget);

    // Skip jumps straight to the method cards.
    await tester.tap(find.text('Skip'));
    // First pump builds the methods phase (scheduling the staggered
    // FadeSlideIn timers); the second elapses past them so no timers remain
    // pending at the end of the test.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Create a new wallet'), findsOneWidget);
    expect(find.text('Import from recovery phrase'), findsOneWidget);
    expect(find.text('Sign in with your Omnia account'), findsOneWidget);
  });
}
