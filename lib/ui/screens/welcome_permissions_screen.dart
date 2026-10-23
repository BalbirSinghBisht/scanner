import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../services/media_scanner_service.dart';

class WelcomePermissionsScreen extends StatefulWidget {
  final VoidCallback? onContinue;

  const WelcomePermissionsScreen({super.key, this.onContinue});

  @override
  State<WelcomePermissionsScreen> createState() =>
      _WelcomePermissionsScreenState();
}

class _WelcomePermissionsScreenState extends State<WelcomePermissionsScreen> {
  final MediaScannerService _scanner = MediaScannerService.instance;
  PermissionState _currentPermission = PermissionState.notDetermined;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _isChecking = true);
    final state = await _scanner.requestPermission();
    setState(() {
      _currentPermission = state;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGranted = _currentPermission == PermissionState.authorized ||
        _currentPermission == PermissionState.limited;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome & Permissions'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Icon / Header
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryAccent, width: 2),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 40,
                    color: AppTheme.primaryAccent,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: Text(
                  'Private Cloud Media Backup',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),

              Center(
                child: Text(
                  'Direct Flutter-to-Google Drive synchronization. No third-party servers, no telemetry, no intermediate proxies.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Permission Features
              _permissionFeatureTile(
                icon: Icons.photo_library_outlined,
                title: 'Media Library Access',
                description:
                    'Discovers camera photos, screenshots, videos, and downloaded media on your device for scheduled backup.',
              ),
              const SizedBox(height: 16),
              _permissionFeatureTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Google Drive Scopes',
                description:
                    'Operates exclusively within app-created folders (https://www.googleapis.com/auth/drive.file). Never accesses your personal files outside this app.',
              ),
              const SizedBox(height: 16),
              _permissionFeatureTile(
                icon: Icons.lock_outline_rounded,
                title: 'Strict Local Processing',
                description:
                    'All metadata analysis, duplicate hashing (SHA-256), and categorization run strictly on your device.',
              ),
              const SizedBox(height: 24),

              // Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isGranted ? AppTheme.emeraldGreen : AppTheme.amberWarning,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isGranted ? Icons.check_circle : Icons.info_outline,
                      color: isGranted
                          ? AppTheme.emeraldGreen
                          : AppTheme.amberWarning,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGranted
                                ? (_currentPermission == PermissionState.limited
                                    ? 'Selected-Media Access'
                                    : 'Full Library Access Granted')
                                : 'Permission Needed',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isGranted
                                ? 'Media library can be scanned for backup.'
                                : 'Please grant photo and video access to proceed.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Actions
              if (!isGranted) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _checkPermission,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Grant Media Permission'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _scanner.openSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('Open System Settings'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (widget.onContinue != null) {
                        widget.onContinue!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Continue to App'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionFeatureTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryAccent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
