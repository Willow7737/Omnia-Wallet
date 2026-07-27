import 'package:dio/dio.dart';

/// What a link turns out to be about.
class LinkPreview {
  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  /// The host, which is what a reader checks before tapping — it is the one
  /// part of a preview that cannot be dressed up by the page itself.
  String get host {
    final parsed = Uri.tryParse(url);
    final h = parsed?.host ?? '';
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  /// Whether there is enough here to be worth showing. A card with only a
  /// host is just the link again, in a box.
  bool get isUseful => (title ?? '').trim().isNotEmpty;

  @override
  String toString() => 'LinkPreview($url, title: $title, image: $imageUrl)';
}

/// Finds links in post text and reads their Open Graph metadata.
///
/// Deliberately small: no HTML parser dependency, because the only things
/// needed are a handful of `<meta>` tags in `<head>`, and the parse stops
/// there. A full DOM for four attributes would be a lot of dependency for a
/// decoration.
class LinkPreviewService {
  LinkPreviewService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              followRedirects: true,
              maxRedirects: 4,
              // Anything that is not HTML is not previewable, and a 4xx page
              // often still carries usable metadata, so accept broadly and
              // decide from the body.
              validateStatus: (code) => code != null && code < 500,
            )),
        _cache = {};

  final Dio _dio;
  final Map<String, LinkPreview?> _cache;

  /// Matches bare and scheme-qualified links. Trailing punctuation is left
  /// out on purpose — "see https://omnia.example." must not include the full
  /// stop that ends the sentence.
  static final RegExp _urlPattern = RegExp(
    r'(?:https?://|www\.)[^\s<>"' r"'" r']+',
    caseSensitive: false,
  );

  /// The first link in [text], normalised, or null.
  ///
  /// Only the first: a post with five links wants to be read, not turned into
  /// a stack of cards.
  static String? firstUrl(String text) {
    final match = _urlPattern.firstMatch(text);
    if (match == null) return null;

    var url = match.group(0)!;
    // Strip punctuation that belongs to the sentence rather than the link,
    // and unbalanced closing brackets from "(see https://x/y)".
    while (url.isNotEmpty && '.,;:!?"\''.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    while (url.endsWith(')') &&
        ')'.allMatches(url).length > '('.allMatches(url).length) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return null;

    final withScheme =
        url.toLowerCase().startsWith('http') ? url : 'https://$url';
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null || parsed.host.isEmpty) return null;
    return withScheme;
  }

  /// Fetch metadata for [url]. Results — including "nothing useful" — are
  /// cached for the session, so scrolling a feed past the same post does not
  /// refetch.
  Future<LinkPreview?> fetch(String url) async {
    if (_cache.containsKey(url)) return _cache[url];

    LinkPreview? preview;
    try {
      final res = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            // Servers hand a bare client the mobile page or nothing at all;
            // asking as a browser is what makes og: tags show up.
            'user-agent':
                'Mozilla/5.0 (compatible; OmniaWallet/1.0; +https://omnia)',
            'accept': 'text/html,application/xhtml+xml',
          },
        ),
      );

      final contentType =
          res.headers.value('content-type')?.toLowerCase() ?? '';
      final body = res.data;
      if (body != null && contentType.contains('html')) {
        preview = parse(url, body);
      }
    } catch (_) {
      // A link that will not load is not an error worth showing — the post
      // still reads fine with the bare URL in it.
      preview = null;
    }

    _cache[url] = preview;
    return preview;
  }

  /// Read Open Graph (and Twitter card, and plain `<title>`) metadata out of
  /// an HTML document.
  ///
  /// Split out from [fetch] so the parsing can be tested against fixtures
  /// without a network.
  static LinkPreview parse(String url, String html) {
    // Everything of interest is in <head>; parsing the whole body of a large
    // page to find four tags is wasted work.
    final headEnd = html.toLowerCase().indexOf('</head>');
    final head = headEnd == -1 ? html : html.substring(0, headEnd);

    String? meta(List<String> names) {
      for (final name in names) {
        final escaped = RegExp.escape(name);
        // property/name may come before or after content, and quoting varies.
        final patterns = [
          '<meta[^>]+(?:property|name)\\s*=\\s*["\']$escaped["\'][^>]*'
              'content\\s*=\\s*["\']([^"\']*)["\']',
          '<meta[^>]+content\\s*=\\s*["\']([^"\']*)["\'][^>]*'
              '(?:property|name)\\s*=\\s*["\']$escaped["\']',
        ];
        for (final pattern in patterns) {
          final match = RegExp(pattern, caseSensitive: false).firstMatch(head);
          final value = match?.group(1)?.trim();
          if (value != null && value.isNotEmpty) return _unescape(value);
        }
      }
      return null;
    }

    final title = meta(['og:title', 'twitter:title']) ??
        _unescape(
          RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
                  .firstMatch(head)
                  ?.group(1)
                  ?.trim() ??
              '',
        );

    final image = meta(['og:image', 'og:image:url', 'twitter:image']);

    return LinkPreview(
      url: url,
      title: title.isEmpty ? null : title,
      description:
          meta(['og:description', 'twitter:description', 'description']),
      // Sites routinely give a root-relative or protocol-relative image path.
      imageUrl:
          image == null ? null : Uri.tryParse(url)?.resolve(image).toString(),
      siteName: meta(['og:site_name', 'application-name']),
    );
  }

  /// The handful of HTML entities that actually turn up in titles. Anything
  /// numeric is decoded too; anything else is left alone rather than guessed.
  static String _unescape(String value) {
    var out = value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–');
    out = out.replaceAllMapped(
      RegExp(r'&#(x?)([0-9a-fA-F]+);'),
      (m) {
        final code = int.tryParse(
          m.group(2)!,
          radix: m.group(1)!.isEmpty ? 10 : 16,
        );
        return code == null ? m.group(0)! : String.fromCharCode(code);
      },
    );
    // Titles frequently arrive with newlines and runs of spaces from the
    // template that produced them.
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
