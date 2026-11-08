import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../services/device_settings_helper.dart';

class UnrestrictedBackgroundSheet extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const UnrestrictedBackgroundSheet({
    super.key,
    this.onSettingsChanged,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onSettingsChanged}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => UnrestrictedBackgroundSheet(
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  State<UnrestrictedBackgroundSheet> createState() =>
      _UnrestrictedBackgroundSheetState();
}

class _UnrestrictedBackgroundSheetState
    extends State<UnrestrictedBackgroundSheet> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  bool _isMediaGranted = true;
  bool _isAllFilesGranted = true;
  bool _isUnrestricted = false;
  bool _isNotificationGranted = true;
  bool _isOEM = false;
  bool _isAutostartConfigured = false;
  String _manufacturer = 'Android';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    if (!mounted || _isCheckingStatus) return;
    _isCheckingStatus = true;

    try {
      bool mediaOk = true;
      try {
        final perm = await PhotoManager.requestPermissionExtend();
        mediaOk = perm.hasAccess;
      } catch (_) {}

      final allFilesOk = await DeviceSettingsHelper.isAllFilesAccessGranted();
      final isIgnored = await DeviceSettingsHelper.isIgnoringBatteryOptimizations();
      final notifOk = await DeviceSettingsHelper.isNotificationPermissionGranted();
      final isOemDevice = await DeviceSettingsHelper.isStrictOEMDevice();
      final autostartDone = await DeviceSettingsHelper.isAutostartConfigured();
      final manufacturer = await DeviceSettingsHelper.getDeviceManufacturer();

      if (mounted) {
        setState(() {
          _isMediaGranted = mediaOk;
          _isAllFilesGranted = allFilesOk;
          _isUnrestricted = isIgnored;
          _isNotificationGranted = notifOk;
          _isOEM = isOemDevice;
          _isAutostartConfigured = autostartDone;
          _manufacturer = manufacturer;
          _isLoading = false;
        });
        widget.onSettingsChanged?.call();
      }
    } finally {
      _isCheckingStatus = false;
    }
  }

  Future<void> _requestMediaAccess() async {
    try {
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.hasAccess) {
        await PhotoManager.openSetting();
      }
    } catch (_) {
      await DeviceSettingsHelper.openAppInfoSettings();
    }
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkStatus();
  }

  Future<void> _requestAllFilesAccess() async {
    await DeviceSettingsHelper.requestAllFilesAccess();
    await Future.delayed(const Duration(milliseconds: 600));
    await _checkStatus();
  }

  Future<void> _requestUnrestrictedBattery() async {
    await DeviceSettingsHelper.requestIgnoreBatteryOptimizations();
    await Future.delayed(const Duration(milliseconds: 800));
    await _checkStatus();
  }

  Future<void> _requestNotification() async {
    await DeviceSettingsHelper.requestNotificationPermission();
    await Future.delayed(const Duration(milliseconds: 600));
    await _checkStatus();
  }

  Future<void> _openOEMAutostartSettings() async {
    // Only opens settings screen, does NOT mark as configured automatically
    await DeviceSettingsHelper.openAutostartSettings();
  }

  bool get _isAllConfigured {
    if (!_isMediaGranted) return false;
    if (!_isAllFilesGranted) return false;
    if (!_isUnrestricted) return false;
    if (!_isNotificationGranted) return false;
    if (_isOEM && !_isAutostartConfigured) return false;
    return true;
  }

  int get _remainingPermissionsCount {
    int count = 0;
    if (!_isMediaGranted) count++;
    if (!_isAllFilesGranted) count++;
    if (!_isUnrestricted) count++;
    if (!_isNotificationGranted) count++;
    if (_isOEM && !_isAutostartConfigured) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _isAllConfigured,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          decoration: BoxDecoration(
            color: c.bgSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: c.glassBorder, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 14,
            left: 20,
            right: 20,
            bottom: bottomPadding + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
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

                // Header with live status icon
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isAllConfigured
                            ? const Color(0xFF2E7D32).withOpacity(0.18)
                            : c.primary.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isAllConfigured
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.sparkles,
                        color: _isAllConfigured
                            ? const Color(0xFF2E7D32)
                            : c.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Permissions & Background Setup',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enable permissions so gallery and deletion work smoothly',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Dynamic Live Status Card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _isAllConfigured
                        ? const Color(0xFF142417)
                        : const Color(0xFF26190B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAllConfigured
                          ? const Color(0xFF2E7D32).withOpacity(0.5)
                          : Colors.orange.withOpacity(0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAllConfigured
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.exclamationmark_triangle_fill,
                        color: _isAllConfigured
                            ? const Color(0xFF2E7D32)
                            : Colors.orangeAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isLoading
                              ? 'Checking device permissions...'
                              : (_isAllConfigured
                                  ? 'Fully Configured: All permissions are active. Media will sync and delete seamlessly.'
                                  : 'Configuration Needed: Please enable the required permissions below to proceed.'),
                          style: TextStyle(
                            color: _isAllConfigured
                                ? (isDark
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF1B5E20))
                                : (isDark
                                    ? Colors.orange[200]
                                    : Colors.orange[900]),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Card 1: All Files & Deletion Management (Essential for deletion on Android 11+)
                _buildPermissionCard(
                  context: context,
                  icon: CupertinoIcons.folder_badge_plus,
                  title: 'All Files Access (Delete & Move)',
                  subtitle: _isAllFilesGranted
                      ? 'Full file management access is granted. Photos and videos can be permanently deleted and moved.'
                      : 'Required to permanently delete and modify photos/videos from Camera, WhatsApp, and downloads on Android 11+.',
                  isGranted: _isAllFilesGranted,
                  actionText: 'Allow All Files Access',
                  onAction: _requestAllFilesAccess,
                  c: c,
                ),

                const SizedBox(height: 12),

                // Card 2: Media Library Access
                _buildPermissionCard(
                  context: context,
                  icon: CupertinoIcons.photo_on_rectangle,
                  title: 'Photos & Videos Access',
                  subtitle: _isMediaGranted
                      ? 'Media library read permission is active.'
                      : 'Required to read, index, and organize your media.',
                  isGranted: _isMediaGranted,
                  actionText: 'Grant Media Access',
                  onAction: _requestMediaAccess,
                  c: c,
                ),

                const SizedBox(height: 12),

                // Card 3: Unrestricted Battery
                _buildPermissionCard(
                  context: context,
                  icon: CupertinoIcons.bolt_fill,
                  title: 'Unrestricted Battery',
                  subtitle: _isUnrestricted
                      ? 'Battery optimization is disabled. Gallery can run continuously in the background.'
                      : 'Allows background sync to run continuously without being paused or put to sleep by the operating system.',
                  isGranted: _isUnrestricted,
                  actionText: 'Allow Unrestricted Run',
                  onAction: _requestUnrestrictedBattery,
                  c: c,
                ),

                // Card 4: OEM Autostart (Xiaomi / Redmi / POCO, Samsung, Oppo, Vivo, Realme, OnePlus)
                if (_isOEM) ...[
                  const SizedBox(height: 12),
                  _buildOEMAutostartCard(c: c),
                ],

                // Card 5: Notification Permission (Android 13+)
                if (!_isNotificationGranted) ...[
                  const SizedBox(height: 12),
                  _buildPermissionCard(
                    context: context,
                    icon: CupertinoIcons.bell_fill,
                    title: 'Background Notifications',
                    subtitle:
                        'Allows persistent background services so Android keeps sync active without killing the process.',
                    isGranted: _isNotificationGranted,
                    actionText: 'Enable Notifications',
                    onAction: _requestNotification,
                    c: c,
                  ),
                ],

                const SizedBox(height: 18),

                // Bottom Action Button: Strictly locked until all permissions granted
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isAllConfigured ? () => Navigator.of(context).pop() : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isAllConfigured
                          ? const Color(0xFF2E7D32)
                          : c.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: _isAllConfigured
                          ? null
                          : Border.all(color: c.glassBorder, width: 0.8),
                      boxShadow: _isAllConfigured
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isAllConfigured
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.lock_fill,
                          color: _isAllConfigured
                              ? Colors.white
                              : c.textTertiary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAllConfigured
                              ? 'Continue to Gallery'
                              : 'Enable All Permissions to Continue ($_remainingPermissionsCount remaining)',
                          style: TextStyle(
                            color: _isAllConfigured
                                ? Colors.white
                                : c.textTertiary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required String actionText,
    required VoidCallback onAction,
    required AppThemeColors c,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGranted
            ? const Color(0xFF131F17)
            : c.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF2E7D32).withOpacity(0.4)
              : c.glassBorderSubtle,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFF2E7D32).withOpacity(0.18)
                      : c.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isGranted ? const Color(0xFF2E7D32) : c.primary,
                  size: 20,
                ),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGranted ? 'Enabled & Active' : 'Action Required',
                      style: TextStyle(
                        color: isGranted
                            ? const Color(0xFF2E7D32)
                            : Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isGranted)
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: Color(0xFF2E7D32),
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onAction,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      actionText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      color: Colors.white,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOEMAutostartCard({required AppThemeColors c}) {
    final isGranted = _isAutostartConfigured;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGranted
            ? const Color(0xFF131F17)
            : c.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF2E7D32).withOpacity(0.4)
              : c.glassBorderSubtle,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFF2E7D32).withOpacity(0.18)
                      : c.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.arrow_2_circlepath_circle_fill,
                  color: isGranted ? const Color(0xFF2E7D32) : c.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_manufacturer Autostart & Launch',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGranted ? 'Enabled & Active' : 'Action Required',
                      style: TextStyle(
                        color: isGranted
                            ? const Color(0xFF2E7D32)
                            : Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isGranted)
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: Color(0xFF2E7D32),
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isGranted
                ? 'Autostart is enabled. Background sync will run reliably.'
                : 'Allows automatic background backup to start and resume reliably.',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _openOEMAutostartSettings,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.play_circle_fill,
                      color: Colors.white,
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Enable Autostart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
