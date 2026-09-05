import 'package:flutter_test/flutter_test.dart';
import 'package:praise/features/songs/presentation/metronome_controller.dart';

void main() {
  test('clamps tempo to the supported practice range', () {
    final controller = MetronomeController(
      playTick: (_) async {},
      playAccent: () async {},
      playBeatHaptic: () async {},
    );

    controller.setBpm(12);
    expect(controller.bpm, MetronomeController.minBpm);

    controller.setBpm(400);
    expect(controller.bpm, MetronomeController.maxBpm);

    controller.dispose();
  });

  test('advances beats within the selected bar length', () {
    final controller = MetronomeController(
      playTick: (_) async {},
      playAccent: () async {},
      playBeatHaptic: () async {},
    )..setBeatsPerBar(3);

    controller.tickForTest();
    expect(controller.currentBeat, 1);

    controller.tickForTest();
    expect(controller.currentBeat, 2);

    controller.tickForTest();
    expect(controller.currentBeat, 3);

    controller.tickForTest();
    expect(controller.currentBeat, 1);

    controller.dispose();
  });

  test('starts, stops, and resets the current beat', () {
    final controller = MetronomeController(
      playTick: (_) async {},
      playAccent: () async {},
      playBeatHaptic: () async {},
    );

    controller.start();
    expect(controller.isRunning, isTrue);
    expect(controller.currentBeat, 1);

    controller.stop();
    expect(controller.isRunning, isFalse);
    expect(controller.currentBeat, 0);

    controller.dispose();
  });
}
