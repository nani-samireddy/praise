import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/songs/presentation/chord_transposer.dart';

void main() {
  test('transposes major and minor chord roots', () {
    expect(transposeChord('C', 2), 'D');
    expect(transposeChord('Em', 2), 'F#m');
  });

  test('transposes slash bass notes independently', () {
    expect(transposeChord('D/F#', 2), 'E/G#');
  });

  test('uses the target key accidental preference', () {
    expect(transposeChord('C', 1, targetKey: 'Bb'), 'Db');
    expect(transposeChord('C', 1, targetKey: 'C#'), 'C#');
  });

  test('transposes keys while preserving the mode', () {
    expect(transposeKey('Em', 2), 'F#m');
    expect(transposeKey('Bb', -2), 'Ab');
  });

  test('leaves unsupported chord tokens unchanged', () {
    expect(transposeChord('N.C.', 2), 'N.C.');
  });
}
