import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/features/send/scan_did_screen.dart';

void main() {
  group('parseScannedDid', () {
    const did = 'did:omnia:4bb06f8e4e3a7715d201d573d0aa4237';

    test('accepts a bare DID', () {
      expect(parseScannedDid(did), did);
    });

    test('trims surrounding whitespace', () {
      expect(parseScannedDid('  $did \n'), did);
    });

    test('extracts a DID embedded in a URI', () {
      expect(parseScannedDid('omnia:$did'), did);
    });

    test('lower-cases hex so it matches the node derivation', () {
      expect(
        parseScannedDid('DID:OMNIA:4BB06F8E4E3A7715D201D573D0AA4237'),
        did,
      );
    });

    test('accepts short web-account DIDs (8 hex)', () {
      // Web/Supabase signups get did:omnia:<8 hex> — the QR scanner
      // must recognize those too.
      expect(parseScannedDid('did:omnia:933eaf87'), 'did:omnia:933eaf87');
    });

    test('rejects a DID with too short an id', () {
      expect(parseScannedDid('did:omnia:dead'), isNull);
    });

    test('rejects non-omnia payloads', () {
      expect(parseScannedDid('https://example.com'), isNull);
      expect(parseScannedDid('did:key:z6Mk...'), isNull);
      expect(parseScannedDid(null), isNull);
      expect(parseScannedDid(''), isNull);
    });
  });
}
