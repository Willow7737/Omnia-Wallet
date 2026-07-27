import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/news.dart';
import 'package:omnia_wallet/features/news/share_card.dart';

/// The share card is the only part of the app that leaves the device looking
/// like the app — it lands in someone else's timeline. So the failure modes
/// worth pinning are the embarrassing ones: a blank picture, or text running
/// off the bottom because the measuring pass and the painting pass disagreed.
void main() {
  NewsPost post({
    String title = 'Omnia mainnet is live',
    String body = 'The network is now open.',
    List<String> tags = const ['network'],
  }) =>
      NewsPost(
        id: 'p1',
        title: title,
        body: body,
        tags: tags,
        author: 'omnia',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        replyCount: 4,
      );

  Future<ui.Image> decode(List<int> png) async {
    final codec = await ui.instantiateImageCodec(
      Uint8List.fromList(png),
    );
    return (await codec.getNextFrame()).image;
  }

  test('renders a PNG at the declared width', () async {
    final bytes = await PostShareCard.render(
      post: post(),
      link: 'https://example.com/',
    );
    expect(bytes, isNotEmpty);

    final image = await decode(bytes);
    addTearDown(image.dispose);
    expect(image.width, (PostShareCard.width * PostShareCard.scale).round());
    expect(image.height, greaterThan(0));
  });

  test('grows to fit a longer post rather than clipping it', () async {
    // The measuring pass and the painting pass share one body precisely so
    // this holds; if they ever drift, a long post loses its footer.
    final short = await decode(
      await PostShareCard.render(post: post(body: 'One line.'), link: 'x'),
    );
    final long = await decode(
      await PostShareCard.render(
        post: post(body: List.filled(40, 'a sentence of body text.').join(' ')),
        link: 'x',
      ),
    );
    addTearDown(short.dispose);
    addTearDown(long.dispose);

    expect(long.height, greaterThan(short.height));
  });

  test('clamps a runaway post instead of producing an endless image', () async {
    final huge = await decode(
      await PostShareCard.render(
        post: post(body: List.filled(4000, 'word').join(' ')),
        link: 'x',
      ),
    );
    addTearDown(huge.dispose);
    // The body is limited to a fixed number of lines, so the card stays a
    // card. Without the clamp this would be tens of thousands of pixels tall
    // and rejected by every share target.
    expect(huge.height, lessThan(2400));
  });

  test('survives a post with no title, body, tags or picture', () async {
    final bytes = await PostShareCard.render(
      post: post(title: '', body: '', tags: const []),
      link: 'https://example.com/',
    );
    final image = await decode(bytes);
    addTearDown(image.dispose);
    expect(image.height, greaterThan(0));
  });

  test('paints something — the card is not blank', () async {
    final bytes = await PostShareCard.render(
      post: post(),
      link: 'https://example.com/',
    );
    final image = await decode(bytes);
    addTearDown(image.dispose);

    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = data!.buffer.asUint8List();
    final distinct = <int>{};
    for (var i = 0; i < pixels.length; i += 4) {
      distinct.add(
        pixels[i] << 16 | pixels[i + 1] << 8 | pixels[i + 2],
      );
      if (distinct.length > 4) break;
    }
    // A background and nothing else would give one colour.
    expect(distinct.length, greaterThan(1), reason: 'the card came out blank');
  });
}
