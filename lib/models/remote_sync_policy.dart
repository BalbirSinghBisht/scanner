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
      final start = DateTime(
        rangeStart!.year,
        rangeStart!.month,
        rangeStart!.day,
      );
      final endExclusive = DateTime(
        rangeEnd!.year,
        rangeEnd!.month,
        rangeEnd!.day + 1,
      );
      return SyncDateBounds(minimum: start, maximumExclusive: endExclusive);
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
