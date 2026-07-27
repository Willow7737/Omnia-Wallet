import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/link_preview.dart';

/// Link previews are parsed out of whatever HTML a site happens to serve, so
/// the failure modes are all about untidy input: attributes in the other
/// order, single quotes, entities, a relative image path. Each of these was
/// taken from a real page shape rather than invented.
void main() {
  group('firstUrl', () {
    test('leaves the sentence out of the link', () {
      expect(
        LinkPreviewService.firstUrl('read https://omnia.example/page.'),
        'https://omnia.example/page',
      );
      expect(
        LinkPreviewService.firstUrl('is it https://omnia.example/x?'),
        'https://omnia.example/x',
      );
    });

    test('drops a closing bracket it never opened', () {
      expect(
        LinkPreviewService.firstUrl('(see https://a.example/x) now'),
        'https://a.example/x',
      );
      // …but keeps one that belongs to the URL.
      expect(
        LinkPreviewService.firstUrl('https://en.example/wiki/Swan_(bird)'),
        'https://en.example/wiki/Swan_(bird)',
      );
    });

    test('gives a bare www link a scheme', () {
      expect(
        LinkPreviewService.firstUrl('visit www.example.com today'),
        'https://www.example.com',
      );
    });

    test('takes only the first link', () {
      // A post with five links wants to be read, not turned into five cards.
      expect(
        LinkPreviewService.firstUrl(
            'a https://one.example b https://two.example'),
        'https://one.example',
      );
    });

    test('finds nothing in text with no link', () {
      expect(LinkPreviewService.firstUrl('no links here'), isNull);
      expect(LinkPreviewService.firstUrl(''), isNull);
      // "www" alone is not a host.
      expect(LinkPreviewService.firstUrl('talk about http:// stuff'), isNull);
    });
  });

  group('parse', () {
    test('reads Open Graph tags', () {
      const html = '''
<html><head>
<meta property="og:title" content="Omnia Protocol">
<meta property="og:description" content="Causal graph consensus.">
<meta property="og:image" content="https://cdn.example/card.png">
<meta property="og:site_name" content="Omnia">
</head><body>ignored</body></html>''';

      final preview = LinkPreviewService.parse('https://omnia.example/', html);
      expect(preview.title, 'Omnia Protocol');
      expect(preview.description, 'Causal graph consensus.');
      expect(preview.imageUrl, 'https://cdn.example/card.png');
      expect(preview.siteName, 'Omnia');
      expect(preview.isUseful, isTrue);
    });

    test('handles content before property, and single quotes', () {
      // Both orderings are common, and plenty of templates emit single quotes.
      const html = """
<head><meta content='Reordered' property='og:title'></head>""";
      expect(
        LinkPreviewService.parse('https://x.example/', html).title,
        'Reordered',
      );
    });

    test('falls back to <title> when there is no og:title', () {
      const html = '<html><head><title>Mute swan - Wikipedia</title></head>';
      expect(
        LinkPreviewService.parse('https://en.example/', html).title,
        'Mute swan - Wikipedia',
      );
    });

    test('accepts a Twitter card when Open Graph is absent', () {
      const html = '''
<head><meta name="twitter:title" content="From Twitter tags">
<meta name="twitter:image" content="https://cdn.example/t.png"></head>''';
      final preview = LinkPreviewService.parse('https://x.example/', html);
      expect(preview.title, 'From Twitter tags');
      expect(preview.imageUrl, 'https://cdn.example/t.png');
    });

    test('resolves a relative image against the page', () {
      const html =
          '<head><meta property="og:image" content="/assets/card.png"></head>';
      expect(
        LinkPreviewService.parse('https://x.example/blog/post', html).imageUrl,
        'https://x.example/assets/card.png',
      );
    });

    test('decodes entities and collapses template whitespace', () {
      const html = '''
<head><title>
    Swans &amp; Geese &#8212; a study &#x2014; part 2
</title></head>''';
      expect(
        LinkPreviewService.parse('https://x.example/', html).title,
        'Swans & Geese — a study — part 2',
      );
    });

    test('ignores tags outside the head', () {
      // A page that mentions og:title in body copy must not hijack the card.
      const html = '''
<head><title>Real title</title></head>
<body><meta property="og:title" content="Injected"></body>''';
      expect(
        LinkPreviewService.parse('https://x.example/', html).title,
        'Real title',
      );
    });

    test('is not useful when the page says nothing', () {
      final preview =
          LinkPreviewService.parse('https://x.example/', '<html></html>');
      expect(preview.isUseful, isFalse);
      expect(preview.title, isNull);
    });
  });

  group('host', () {
    test('drops the www a reader does not need', () {
      const preview = LinkPreview(url: 'https://www.example.com/a/b');
      expect(preview.host, 'example.com');
    });

    test('survives a url that will not parse', () {
      const preview = LinkPreview(url: '::::');
      expect(preview.host, isEmpty);
    });
  });
}
