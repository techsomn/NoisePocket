import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pocket/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every pad has a bundled, non-silent PCM WAV sound', () async {
    expect(sounds, hasLength(6));
    expect(sounds.map((s) => s.file).toSet(), hasLength(6));
    for (final sound in sounds) {
      final wav = await rootBundle.load('assets/sounds/${sound.file}');
      final bytes = wav.buffer.asUint8List();
      expect(
        String.fromCharCodes(bytes.sublist(0, 4)),
        'RIFF',
        reason: sound.title,
      );
      expect(
        String.fromCharCodes(bytes.sublist(8, 12)),
        'WAVE',
        reason: sound.title,
      );
      expect(bytes.length, greaterThan(10000), reason: sound.title);
      expect(bytes.skip(44).any((b) => b != 0), isTrue, reason: sound.title);
    }
  });

  test('speed choices have distinct, ordered values', () {
    expect(PlaybackSpeed.slow.rate, lessThan(PlaybackSpeed.normal.rate));
    expect(PlaybackSpeed.normal.rate, 1);
    expect(PlaybackSpeed.fast.rate, greaterThan(PlaybackSpeed.normal.rate));
  });
}
