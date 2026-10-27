import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'telugu_font.dart';

enum LyricsDisplayMode { primary, english, both }

abstract interface class SettingsRepository {
  Stream<String?> watchThemeMode();

  Stream<double> watchLyricsFontSize();

  Stream<LyricsDisplayMode> watchLyricsDisplayMode();

  Stream<TeluguFont> watchTeluguFont();

  Future<void> setThemeMode(String value);

  Future<void> setLyricsFontSize(double value);

  Future<void> setLyricsDisplayMode(LyricsDisplayMode value);

  Future<void> setTeluguFont(TeluguFont value);
}

class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this._database);

  static const _themeModeKey = 'setting_theme_mode';
  static const _lyricsFontSizeKey = 'setting_lyrics_font_size';
  static const _lyricsDisplayModeKey = 'setting_lyrics_display_mode';
  static const _teluguFontKey = 'setting_telugu_font';

  final AppDatabase _database;

  Stream<String?> _watchValue(String key) {
    return (_database.select(_database.appMetadata)
          ..where((row) => row.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> _setValue(String key, String value) async {
    await _database
        .into(_database.appMetadata)
        .insert(
          AppMetadataCompanion.insert(
            key: key,
            value: value,
            updatedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Stream<String?> watchThemeMode() => _watchValue(_themeModeKey);

  @override
  Stream<double> watchLyricsFontSize() {
    return _watchValue(_lyricsFontSizeKey).map((value) {
      final parsed = double.tryParse(value ?? '');
      return (parsed ?? 19).clamp(16, 38).toDouble();
    });
  }

  @override
  Stream<LyricsDisplayMode> watchLyricsDisplayMode() {
    return _watchValue(_lyricsDisplayModeKey).map(
      (value) => LyricsDisplayMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => LyricsDisplayMode.both,
      ),
    );
  }

  @override
  Stream<TeluguFont> watchTeluguFont() {
    return _watchValue(_teluguFontKey).map(
      (value) => TeluguFont.values.firstWhere(
        (font) => font.name == value,
        orElse: () => TeluguFont.system,
      ),
    );
  }

  @override
  Future<void> setThemeMode(String value) => _setValue(_themeModeKey, value);

  @override
  Future<void> setLyricsFontSize(double value) {
    final safeValue = value.clamp(16, 38).toDouble();
    return _setValue(_lyricsFontSizeKey, safeValue.toStringAsFixed(1));
  }

  @override
  Future<void> setLyricsDisplayMode(LyricsDisplayMode value) {
    return _setValue(_lyricsDisplayModeKey, value.name);
  }

  @override
  Future<void> setTeluguFont(TeluguFont value) {
    return _setValue(_teluguFontKey, value.name);
  }
}
