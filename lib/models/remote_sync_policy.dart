enum SyncWindowUnit { days, months, years }

class SyncDateBounds {
  final DateTime? minimum;
  final DateTime? maximumExclusive;
  const SyncDateBounds({this.minimum, this.maximumExclusive});
}

class RemoteSyncPolicy {
  final String mode;
  final int amount;
  final SyncWindowUnit unit;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  const RemoteSyncPolicy({
    this.mode = 'rolling',
    this.amount = 10,
    this.unit = SyncWindowUnit.days,
    this.rangeStart,
    this.rangeEnd,
  });

  SyncDateBounds boundsAt(DateTime now) {
    if (mode == 'range' && rangeStart != null && rangeEnd != null) {
      // The admin picker has minute precision. Make the selected end minute
      // inclusive while retaining an exclusive database upper bound.
      return SyncDateBounds(
        minimum: rangeStart,
        maximumExclusive: rangeEnd!.add(const Duration(minutes: 1)),
      );
    }
    final safeAmount = amount.clamp(1, 1000);
    final minimum = switch (unit) {
      SyncWindowUnit.days => now.subtract(Duration(days: safeAmount)),
      SyncWindowUnit.months => DateTime(
        now.year,
        now.month - safeAmount,
        now.day,
        now.hour,
        now.minute,
        now.second,
      ),
      SyncWindowUnit.years => DateTime(
        now.year - safeAmount,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      ),
    };
    return SyncDateBounds(minimum: minimum);
  }
}
