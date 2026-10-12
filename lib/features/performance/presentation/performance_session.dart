import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class ScreenAwake {
  Future<void> setEnabled(bool enabled);
}

class PlatformScreenAwake implements ScreenAwake {
  @override
  Future<void> setEnabled(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Keep awake is available on Android');
    }
    await WakelockPlus.toggle(enable: enabled);
  }
}

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => PlatformScreenAwake(),
);

/// Serializes native calls so a late enable can never outlive cleanup.
class PerformanceSession extends ChangeNotifier {
  PerformanceSession(this.awake);
  final ScreenAwake awake;
  Future<void> _pending = Future<void>.value();
  bool _closed = false;
  bool keepAwake = true;
  bool awakeUnavailable = false;
  bool _foreground = true;
  final Map<String, double> offsets = {};

  Future<void> sync() {
    final enabled = !_closed && _foreground && keepAwake;
    _pending = _pending.then((_) async {
      try {
        await awake.setEnabled(enabled);
        if (!_closed && awakeUnavailable) {
          awakeUnavailable = false;
          notifyListeners();
        }
      } catch (_) {
        if (!_closed) {
          awakeUnavailable = true;
          notifyListeners();
        }
      }
    });
    return _pending;
  }

  void lifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    sync();
  }

  void toggleAwake() {
    keepAwake = !keepAwake;
    notifyListeners();
    sync();
  }

  Future<void> close() {
    _closed = true;
    return sync();
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

String? adjacentSong(List<String> ids, String current, int direction) {
  final index = ids.indexOf(current);
  if (index < 0) return null;
  final next = index + direction;
  return next >= 0 && next < ids.length ? ids[next] : null;
}
