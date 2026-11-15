import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/expiring_media_item.dart';

class ExpiringTimerBadge extends StatelessWidget {
  final ExpiringMediaItem expiringItem;
  final bool compact;

  const ExpiringTimerBadge({
    super.key,
    required this.expiringItem,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final remaining = expiringItem.remainingDuration;
    final isUrgent = remaining.inHours < 2;

    final bgColor = isUrgent
        ? c.accentRose.withOpacity(0.9)
        : const Color(0xE6000000);
    const textColor = Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUrgent ? c.accentRose : Colors.white.withOpacity(0.2),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? CupertinoIcons.timer_fill : CupertinoIcons.timer,
            size: compact ? 10 : 12,
            color: isUrgent ? Colors.white : c.accentAmber,
          ),
          const SizedBox(width: 3.5),
          Text(
            expiringItem.formattedTimeRemaining,
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
