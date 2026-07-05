import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/brand/identicon.dart';

void main() {
  testWidgets('Identicon renders for a DID seed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child:
                Identicon(seed: 'did:omnia:4bb06f8e4e3a7715d201d573d0aa4237'),
          ),
        ),
      ),
    );
    expect(find.byType(Identicon), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Identicon handles an empty seed without throwing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Identicon(seed: '')),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
