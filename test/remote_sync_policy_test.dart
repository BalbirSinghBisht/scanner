import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/remote_sync_policy.dart';

void main() {
  final now = DateTime(2026, 11, 26, 12);

  test('defaults to a rolling ten-day window', () {
    final bounds = const RemoteSyncPolicy().boundsAt(now);
    expect(bounds.minimum, DateTime(2026, 11, 16, 12));
    expect(bounds.maximumExclusive, isNull);
  });

  test('supports rolling months and years', () {
    final month = const RemoteSyncPolicy(
      amount: 3,
      unit: SyncWindowUnit.months,
    ).boundsAt(now);
    final year = const RemoteSyncPolicy(
      amount: 2,
      unit: SyncWindowUnit.years,
    ).boundsAt(now);
    expect(month.minimum, DateTime(2026, 8, 26, 12));
    expect(year.minimum, DateTime(2024, 11, 26, 12));
  });

  test('supports an inclusive exact date range', () {
    final bounds = RemoteSyncPolicy(
      mode: 'range',
      rangeStart: DateTime(2025, 1, 1),
      rangeEnd: DateTime(2025, 1, 31),
    ).boundsAt(now);
    expect(bounds.minimum, DateTime(2025, 1, 1));
    expect(bounds.maximumExclusive, DateTime(2025, 1, 31, 0, 1));
  });
}
