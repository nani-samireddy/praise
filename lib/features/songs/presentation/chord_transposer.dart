const _sharpNames = <String>[
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

const _flatNames = <String>[
  'C',
  'Db',
  'D',
  'Eb',
  'E',
  'F',
  'Gb',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];

final _chordPattern = RegExp(
  r'^([A-Ga-g])([#b]?)(sus2|sus4|maj|min|dim|aug|m)?'
  r'(2|4|5|6|7|9|11|13)?(?:/([A-Ga-g])([#b]?))?$',
);

final _keyPattern = RegExp(r'^([A-Ga-g])([#b]?)(m|min|maj)?$');

String transposeChord(String chord, int semitones, {String? targetKey}) {
  if (semitones == 0) return chord;
  final match = _chordPattern.firstMatch(chord.trim());
  if (match == null) return chord;

  final names = _usesFlats(targetKey) ? _flatNames : _sharpNames;
  final root = _transposeNote(
    match.group(1)!,
    match.group(2)!,
    semitones,
    names,
  );
  final quality = match.group(3) ?? '';
  final extension = match.group(4) ?? '';
  final bass = match.group(5);
  final bassAccidental = match.group(6);
  final bassPart = bass == null
      ? ''
      : '/${_transposeNote(bass, bassAccidental ?? '', semitones, names)}';
  return '$root$quality$extension$bassPart';
}

String transposeKey(String key, int semitones) {
  if (semitones == 0) return key;
  final match = _keyPattern.firstMatch(key.trim());
  if (match == null) return key;
  final names = _usesFlats(key) ? _flatNames : _sharpNames;
  final root = _transposeNote(
    match.group(1)!,
    match.group(2)!,
    semitones,
    names,
  );
  return '$root${match.group(3) ?? ''}';
}

String _transposeNote(
  String letter,
  String accidental,
  int semitones,
  List<String> names,
) {
  final pitchClass = _pitchClass(letter, accidental);
  if (pitchClass == null) return '$letter$accidental';
  final shifted = (pitchClass + semitones) % 12;
  return names[shifted < 0 ? shifted + 12 : shifted];
}

int? _pitchClass(String letter, String accidental) {
  const naturalPitches = <String, int>{
    'A': 9,
    'B': 11,
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
  };
  final natural = naturalPitches[letter.toUpperCase()];
  if (natural == null) return null;
  final adjustment = accidental == '#'
      ? 1
      : accidental == 'b'
      ? -1
      : 0;
  return (natural + adjustment + 12) % 12;
}

bool _usesFlats(String? key) {
  if (key == null) return false;
  final normalized = key.trim();
  if (normalized.contains('b')) return true;
  const flatKeys = <String>{
    'F',
    'Dm',
    'Bb',
    'Gm',
    'Eb',
    'Cm',
    'Ab',
    'Fm',
    'Db',
    'Bbm',
    'Gb',
    'Ebm',
    'Cb',
    'Abm',
  };
  return flatKeys.contains(normalized);
}
