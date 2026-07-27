import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/features/news/video_attachment.dart';

/// Media type is decided from the URL, so the decision is worth pinning: get
/// it wrong and a video renders as a broken image, or a photo gets a play
/// button that never plays.
void main() {
  const bucket =
      'https://iyajzmgnykgkivabxiuw.supabase.co/storage/v1/object/public/'
      'news-media';

  group('isVideoUrl', () {
    test('recognises the formats the app uploads', () {
      expect(isVideoUrl('$bucket/welcome/omnia-welcome.mp4'), isTrue);
      expect(isVideoUrl('$bucket/a/clip.mov'), isTrue);
      expect(isVideoUrl('$bucket/a/clip.m4v'), isTrue);
      expect(isVideoUrl('$bucket/a/clip.webm'), isTrue);
    });

    test('is not fooled by case', () {
      // iOS hands back .MOV from the camera roll.
      expect(isVideoUrl('$bucket/a/CLIP.MOV'), isTrue);
      expect(isVideoUrl('$bucket/a/Clip.Mp4'), isTrue);
    });

    test('ignores a query string', () {
      // A signed URL puts ?token=… after the extension, which a naive
      // endsWith on the whole URL would miss.
      expect(isVideoUrl('$bucket/a/clip.mp4?token=abc&x=1'), isTrue);
      expect(isVideoUrl('$bucket/a/photo.jpg?token=abc'), isFalse);
    });

    test('leaves pictures alone', () {
      expect(isVideoUrl('$bucket/replies/1-photo.jpg'), isFalse);
      expect(isVideoUrl('$bucket/replies/1-photo.png'), isFalse);
      expect(isVideoUrl('$bucket/replies/1-photo.webp'), isFalse);
    });

    test('says no rather than throwing on nonsense', () {
      expect(isVideoUrl(''), isFalse);
      expect(isVideoUrl('not a url at all'), isFalse);
      // "mp4" in the middle of a name is not an extension.
      expect(isVideoUrl('$bucket/a/mp4-explained.png'), isFalse);
    });
  });
}
