import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/performance/presentation/performance_session.dart';

class FakeAwake implements ScreenAwake {
  final calls = <bool>[];
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add(enabled);
    await gate?.future;
    if (fail) throw StateError('unavailable');
  }
}

void main() {
  test('foreground, user toggle, and cleanup release awake', () async {
    final fake = FakeAwake();
    final session = PerformanceSession(fake);
    await session.sync();
    session.lifecycle(AppLifecycleState.inactive);
    await session.sync();
    session.lifecycle(AppLifecycleState.resumed);
    await session.sync();
    session.toggleAwake();
    await session.sync();
    session.lifecycle(AppLifecycleState.paused);
    session.lifecycle(AppLifecycleState.resumed);
    await session.close();
    expect(fake.calls.first, true);
    expect(fake.calls, contains(false));
    expect(fake.calls.last, false);
    expect(fake.calls.sublist(fake.calls.length - 3), everyElement(false));
    session.dispose();
  });
  test('pending native enable cannot race disposal', () async {
    final fake = FakeAwake()..gate = Completer<void>();
    final session = PerformanceSession(fake);
    final enabling = session.sync();
    await Future<void>.delayed(Duration.zero);
    session.dispose();
    fake.gate!.complete();
    await enabling;
    await session.close();
    expect(fake.calls, [true, false, false]);
  });
  test('unsupported capability is reported without breaking cleanup', () async {
    final fake = FakeAwake()..fail = true;
    final session = PerformanceSession(fake);
    await session.sync();
    expect(session.awakeUnavailable, true);
    fake.fail = false;
    await session.sync();
    expect(session.awakeUnavailable, false);
    await session.close();
    expect(fake.calls.last, false);
    session.dispose();
  });
  test(
    'navigation follows current order and never wraps or guesses removed IDs',
    () {
      expect(adjacentSong(['a', 'b', 'c'], 'b', 1), 'c');
      expect(adjacentSong(['c', 'b', 'a'], 'b', 1), 'a');
      expect(adjacentSong(['a', 'c'], 'b', 1), isNull);
      expect(adjacentSong(['a'], 'a', -1), isNull);
      expect(adjacentSong(['a'], 'a', 1), isNull);
      expect(adjacentSong([], 'a', 1), isNull);
    },
  );
}
