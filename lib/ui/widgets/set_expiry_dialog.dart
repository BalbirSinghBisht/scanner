import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/expiring_media_service.dart';

class SetExpiryDialog {
  static Future<void> show(
    BuildContext context, {
    required List<String> localIds,
    String? currentExpiryText,
    VoidCallback? onCompleted,
  }) async {
    if (localIds.isEmpty) return;
    final c = AppTheme.colors(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: c.isDark
                  ? const Color(0xF51C1C1E)
                  : const Color(0xF8FFFFFF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: c.glassBorderSubtle, width: 0.5),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: 12,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.textTertiary.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.accentAmber.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.timer,
                        color: c.accentAmber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localIds.length > 1
                                ? 'Auto-Expire ${localIds.length} Items'
                                : 'Self-Destructing Media',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Frees up device storage automatically when the timer ends.',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildOptionTile(
                  context,
                  title: '1 Hour',
                  subtitle: 'For OTPs, passwords & immediate verification',
                  icon: CupertinoIcons.flame,
                  color: c.accentRose,
                  c: c,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    for (final id in localIds) {
                      await ExpiringMediaService.instance.setExpiry(
                        id,
                        const Duration(hours: 1),
                      );
                    }
                    onCompleted?.call();
                  },
                ),
                _buildOptionTile(
                  context,
                  title: '24 Hours (1 Day)',
                  subtitle: 'Ideal for parking spots, receipts & whiteboard notes',
                  icon: CupertinoIcons.clock,
                  color: c.accentAmber,
                  c: c,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    for (final id in localIds) {
                      await ExpiringMediaService.instance.setExpiry(
                        id,
                        const Duration(hours: 24),
                      );
                    }
                    onCompleted?.call();
                  },
                ),
                _buildOptionTile(
                  context,
                  title: '3 Days',
                  subtitle: 'For shopping ideas, weekend trips & errands',
                  icon: CupertinoIcons.calendar,
                  color: c.primary,
                  c: c,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    for (final id in localIds) {
                      await ExpiringMediaService.instance.setExpiry(
                        id,
                        const Duration(days: 3),
                      );
                    }
                    onCompleted?.call();
                  },
                ),
                _buildOptionTile(
                  context,
                  title: '7 Days (1 Week)',
                  subtitle: 'Temporary work documents & weekly reminders',
                  icon: CupertinoIcons.calendar_today,
                  color: c.accentTeal,
                  c: c,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    for (final id in localIds) {
                      await ExpiringMediaService.instance.setExpiry(
                        id,
                        const Duration(days: 7),
                      );
                    }
                    onCompleted?.call();
                  },
                ),
                _buildOptionTile(
                  context,
                  title: '30 Days (1 Month)',
                  subtitle: 'Month-end bills and temporary project assets',
                  icon: CupertinoIcons.archivebox,
                  color: c.accentViolet,
                  c: c,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    for (final id in localIds) {
                      await ExpiringMediaService.instance.setExpiry(
                        id,
                        const Duration(days: 30),
                      );
                    }
                    onCompleted?.call();
                  },
                ),
                const SizedBox(height: 6),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    for (final id in localIds) {
                      await ExpiringMediaService.instance.removeExpiry(id);
                    }
                    onCompleted?.call();
                  },
                  child: Text(
                    'Keep Forever (Remove Timer)',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  static Widget _buildOptionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required AppThemeColors c,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.glassBorderSubtle, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

