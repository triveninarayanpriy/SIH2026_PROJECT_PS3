import 'package:cognicare_ner/core/ai/anomaly_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no drop below 8 samples', () {
    expect(
      AnomalyDetector.detectDrop(<double>[1, 1, 1, 1, 1, 0, 0]),
      isNull,
    );
  });

  test('detects a clear decline', () {
    final DropResult? d = AnomalyDetector.detectDrop(
      <double>[1, 1, 1, 1, 1, 0.4, 0.4, 0.4],
    );
    expect(d, isNotNull);
    // baseline 1.0, recent 0.4 -> 60% drop.
    expect(d!.deltaPct, closeTo(60, 0.001));
  });

  test('no drop when steady', () {
    expect(
      AnomalyDetector.detectDrop(<double>[0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9]),
      isNull,
    );
  });

  test('a decline under the 22% threshold does not fire', () {
    // baseline 1.0, recent 0.80 -> ratio 0.20, below threshold.
    expect(
      AnomalyDetector.detectDrop(<double>[1, 1, 1, 1, 1, 0.80, 0.80, 0.80]),
      isNull,
    );
  });

  test('a decline just over the threshold fires', () {
    // baseline 1.0, recent 0.74 -> ratio 0.26, above threshold.
    final DropResult? d =
        AnomalyDetector.detectDrop(<double>[1, 1, 1, 1, 1, 0.74, 0.74, 0.74]);
    expect(d, isNotNull);
  });

  test('handles a zero baseline safely', () {
    expect(
      AnomalyDetector.detectDrop(<double>[0, 0, 0, 0, 0, 0, 0, 0]),
      isNull,
    );
  });
}
