enum TeluguFont {
  system,
  notoSansTelugu,
  notoSerifTelugu,
  mandali,
  ramabhadra;

  String get label => switch (this) {
    TeluguFont.system => 'System default',
    TeluguFont.notoSansTelugu => 'Noto Sans Telugu',
    TeluguFont.notoSerifTelugu => 'Noto Serif Telugu',
    TeluguFont.mandali => 'Mandali',
    TeluguFont.ramabhadra => 'Ramabhadra',
  };

  String? get fontFamily => switch (this) {
    TeluguFont.system => null,
    TeluguFont.notoSansTelugu => 'NotoSansTelugu',
    TeluguFont.notoSerifTelugu => 'NotoSerifTelugu',
    TeluguFont.mandali => 'Mandali',
    TeluguFont.ramabhadra => 'Ramabhadra',
  };
}
