import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui_media/src/media_kind.dart';

void main() {
  group('inferMediaKind', () {
    test('AE1: recognized video extensions -> video', () {
      for (final u in ['a.mp4', 'a.mov', 'a.webm', 'a.m4v', 'A.MP4']) {
        expect(inferMediaKind(u), MediaKind.video, reason: u);
      }
    });

    test('AE2: image and extensionless -> image', () {
      for (final u in ['a.png', 'a.jpg', 'a.webp', 'noext', '']) {
        expect(inferMediaKind(u), MediaKind.image, reason: u);
      }
    });

    test('AE3: kind override beats extension', () {
      expect(inferMediaKind('noext', kind: 'video'), MediaKind.video);
      expect(inferMediaKind('a.mp4', kind: 'image'), MediaKind.image);
      expect(inferMediaKind('a.mp4', kind: 'VIDEO'), MediaKind.video);
    });

    test('query string is stripped before extension match', () {
      expect(inferMediaKind('https://x/clip.mp4?token=abc'), MediaKind.video);
    });

    test('unknown kind falls back to extension inference', () {
      expect(inferMediaKind('a.mp4', kind: 'gif'), MediaKind.video);
      expect(inferMediaKind('a.png', kind: ''), MediaKind.image);
    });
  });

  group('hasRecognizedExtension', () {
    test('known image/video extensions -> true', () {
      for (final u in ['a.png', 'a.jpg', 'a.mp4', 'x/y/clip.MOV?t=1']) {
        expect(hasRecognizedExtension(u), isTrue, reason: u);
      }
    });

    test('extensionless or opaque/tokenized -> false', () {
      for (final u in ['noext', 'https://h/o/videos%2Fintro?tok=1', '']) {
        expect(hasRecognizedExtension(u), isFalse, reason: u);
      }
    });
  });
}
