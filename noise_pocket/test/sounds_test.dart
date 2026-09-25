import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pocket/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every pad has three bundled, non-silent PCM WAV sounds', () async {
    expect(sounds, hasLength(6));
    expect(sounds.map((s) => s.file).toSet(), hasLength(6));
    for (final sound in sounds) {
      final durations = <double>[];
      for (final speed in PlaybackSpeed.values) {
        final asset = soundAsset(sound, speed);
        final wav = await rootBundle.load('assets/$asset');
        final bytes = wav.buffer.asUint8List();
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: asset);
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE', reason: asset);
        expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ', reason: asset);
        expect(wav.getUint16(20, Endian.little), 1, reason: asset); // PCM
        expect(wav.getUint16(22, Endian.little), 1, reason: asset); // mono
        expect(wav.getUint32(24, Endian.little), 44100, reason: asset);
        expect(wav.getUint16(34, Endian.little), 16, reason: asset);
        expect(bytes.length, greaterThan(10000), reason: asset);
        expect(bytes.skip(44).any((b) => b != 0), isTrue, reason: asset);
        durations.add((bytes.length - 44) / (44100 * 2));
      }
      expect(durations[0], greaterThan(durations[1]), reason: sound.title);
      expect(durations[1], greaterThan(durations[2]), reason: sound.title);
    }
  });

  test('speed choices have distinct, ordered values', () {
    expect(PlaybackSpeed.slow.rate, lessThan(PlaybackSpeed.normal.rate));
    expect(PlaybackSpeed.normal.rate, 1);
    expect(PlaybackSpeed.fast.rate, greaterThan(PlaybackSpeed.normal.rate));
  });
}
