import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PermissionBanner extends StatelessWidget {
  final bool isPartialAccess;
  final VoidCallback onManagePermissions;

  const PermissionBanner({
    super.key,
    required this.isPartialAccess,
    required this.onManagePermissions,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPartialAccess) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.amberWarning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.amberWarning.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.amberWarning,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected-Media Access Granted',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.amberWarning,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The application can only see and backup the photos and videos you explicitly selected. Grant full library access to automatically back up all phone media.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onManagePermissions,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Manage Permissions in Settings →',
                    style: TextStyle(
                      color: AppTheme.primaryAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
