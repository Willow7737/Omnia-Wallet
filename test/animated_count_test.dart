import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/widgets/animated_count.dart';

void main() {
  testWidgets('AnimatedCount settles on the final formatted value',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedCount(value: 1000, format: (v) => '$v UBC'),
        ),
      ),
    );

    // Mid-flight it should be counting up (not yet at the target).
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('1000 UBC'), findsNothing);

    // After the animation completes it shows the final value.
    await tester.pumpAndSettle();
    expect(find.text('1000 UBC'), findsOneWidget);
  });
}
