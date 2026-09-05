import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MetronomeController extends ChangeNotifier {
  MetronomeController({
    Future<void> Function()? playClick,
    Future<void> Function()? playAccent,
    Future<void> Function()? playBeatHaptic,
  }) : _playClick =
           playClick ?? (() => SystemSound.play(SystemSoundType.click)),
       _playAccent = playAccent ?? HapticFeedback.mediumImpact,
       _playBeatHaptic = playBeatHaptic ?? HapticFeedback.selectionClick;

  static const minBpm = 40;
  static const maxBpm = 240;

  final Future<void> Function() _playClick;
  final Future<void> Function() _playAccent;
  final Future<void> Function() _playBeatHaptic;

  Timer? _timer;
  int _bpm = 90;
  int _beatsPerBar = 4;
  int _currentBeat = 0;
  bool _accentFirstBeat = true;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _isRunning = false;

  int get bpm => _bpm;
  int get beatsPerBar => _beatsPerBar;
  int get currentBeat => _currentBeat;
  bool get accentFirstBeat => _accentFirstBeat;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get isRunning => _isRunning;

  Duration get beatInterval =>
      Duration(milliseconds: (Duration.millisecondsPerMinute / _bpm).round());

  void setBpm(int value) {
    final next = value.clamp(minBpm, maxBpm);
    if (next == _bpm) return;
    _bpm = next;
    if (_isRunning) _restartTimer();
    notifyListeners();
  }

  void setBeatsPerBar(int value) {
    if (value == _beatsPerBar) return;
    _beatsPerBar = value.clamp(1, 12);
    _currentBeat = 0;
    notifyListeners();
  }

  void setAccentFirstBeat(bool value) {
    if (value == _accentFirstBeat) return;
    _accentFirstBeat = value;
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    if (value == _soundEnabled) return;
    _soundEnabled = value;
    notifyListeners();
  }

  void setHapticsEnabled(bool value) {
    if (value == _hapticsEnabled) return;
    _hapticsEnabled = value;
    notifyListeners();
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _currentBeat = 0;
    notifyListeners();
    tickForTest();
    _restartTimer();
  }

  void stop() {
    if (!_isRunning && _timer == null) return;
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _currentBeat = 0;
    notifyListeners();
  }

  void toggle() => _isRunning ? stop() : start();

  @visibleForTesting
  void tickForTest() {
    _currentBeat = (_currentBeat % _beatsPerBar) + 1;
    final isAccent = _currentBeat == 1 && _accentFirstBeat;
    if (_soundEnabled) {
      unawaited(_playClick());
    }
    if (_hapticsEnabled) {
      unawaited(isAccent ? _playAccent() : _playBeatHaptic());
    }
    notifyListeners();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(beatInterval, (_) => tickForTest());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
