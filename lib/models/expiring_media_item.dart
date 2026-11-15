class ExpiringMediaItem {
  final String localId;
  final DateTime expiresAt;
  final DateTime createdAt;
  final int durationSeconds;

  const ExpiringMediaItem({
    required this.localId,
    required this.expiresAt,
    required this.createdAt,
    required this.durationSeconds,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingDuration {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  String get formattedTimeRemaining {
    final remaining = remainingDuration;
    if (remaining.inSeconds <= 0) return 'Expired';
    if (remaining.inDays > 0) {
      final days = remaining.inDays;
      final hours = remaining.inHours % 24;
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    }
    if (remaining.inHours > 0) {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m';
    }
    return '${remaining.inSeconds}s';
  }

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'expires_at': expiresAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'duration_seconds': durationSeconds,
    };
  }

  factory ExpiringMediaItem.fromMap(Map<String, dynamic> map) {
    return ExpiringMediaItem(
      localId: map['local_id'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      durationSeconds: map['duration_seconds'] as int,
    );
  }
}

