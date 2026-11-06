import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isMediaGranted = true;
  bool _isAllFilesGranted = true;
  bool _isUnrestricted = false;
  bool _isNotificationGranted = true;
  bool _isOEM = false;
  bool _isAutostartConfigured = false;
  String _manufacturer = 'Android';
  List<String> _guidanceTips = [];

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
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _checkStatus();
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _checkStatus();
      });
    }
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;

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
    final tips = DeviceSettingsHelper.getOEMGuidanceTips(manufacturer);

    if (mounted) {
      setState(() {
        _isMediaGranted = mediaOk;
        _isAllFilesGranted = allFilesOk;
        _isUnrestricted = isIgnored;
        _isNotificationGranted = notifOk;
        _isOEM = isOemDevice;
        _isAutostartConfigured = autostartDone;
        _manufacturer = manufacturer;
        _guidanceTips = tips;
        _isLoading = false;
      });
      widget.onSettingsChanged?.call();
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

  Future<void> _openXiaomiBatterySaver() async {
    await DeviceSettingsHelper.openXiaomiBatterySaver();
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

  Future<void> _toggleAutostartConfigured(bool value) async {
    HapticFeedback.lightImpact();
    await DeviceSettingsHelper.setAutostartConfigured(value);
    if (mounted) {
      setState(() => _isAutostartConfigured = value);
    }
    widget.onSettingsChanged?.call();
  }

  Future<void> _openAppInfo() async {
    await DeviceSettingsHelper.openAppInfoSettings();
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
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please enable all permissions above to proceed ($_remainingPermissionsCount remaining).',
              ),
              backgroundColor: c.surfaceElevated,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: c.surfaceGlassFloating,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: c.glassBorder, width: 0.6),
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

                // Header with live refresh button
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isAllConfigured
                            ? const Color(0xFF2E7D32).withOpacity(0.14)
                            : c.primary.withOpacity(0.14),
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
                    // Quick Refresh Button
                    CupertinoButton(
                      padding: const EdgeInsets.all(6),
                      minSize: 0,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _checkStatus();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                          shape: BoxShape.circle,
                          border: Border.all(color: c.glassBorder, width: 0.6),
                        ),
                        child: Icon(
                          CupertinoIcons.arrow_clockwise,
                          color: c.primary,
                          size: 17,
                        ),
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
                        ? const Color(0xFF2E7D32).withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAllConfigured
                          ? const Color(0xFF2E7D32).withOpacity(0.4)
                          : Colors.orange.withOpacity(0.4),
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
                                  : 'Configuration Needed: Enable missing permissions below. You can tap "Open Settings" on any item at any time.'),
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
                  secondaryActionText: 'Manage in Settings',
                  onSecondaryAction: _requestAllFilesAccess,
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
                  secondaryActionText: 'App Settings',
                  onSecondaryAction: _openAppInfo,
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
                      : 'Prevents Android from putting the app to sleep or stopping background indexing after 15 minutes.',
                  isGranted: _isUnrestricted,
                  actionText: 'Allow Unrestricted Run',
                  onAction: _requestUnrestrictedBattery,
                  secondaryActionText: _manufacturer.toLowerCase().contains('xiaomi') ||
                          _manufacturer.toLowerCase().contains('redmi') ||
                          _manufacturer.toLowerCase().contains('poco')
                      ? 'Battery Saver (No Restrictions)'
                      : 'Battery Settings',
                  onSecondaryAction: () {
                    if (_manufacturer.toLowerCase().contains('xiaomi') ||
                        _manufacturer.toLowerCase().contains('redmi') ||
                        _manufacturer.toLowerCase().contains('poco')) {
                      _openXiaomiBatterySaver();
                    } else {
                      DeviceSettingsHelper.openBatteryOptimizationSettings();
                    }
                  },
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
                    secondaryActionText: 'Notification Settings',
                    onSecondaryAction: _openAppInfo,
                    c: c,
                  ),
                ],

                const SizedBox(height: 18),

                // Bottom Action Button: Next / Continue to Gallery (Disabled until all permissions granted)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isAllConfigured ? () => Navigator.pop(context) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isAllConfigured
                          ? const Color(0xFF2E7D32)
                          : (c.isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06)),
                      borderRadius: BorderRadius.circular(16),
                      border: _isAllConfigured
                          ? null
                          : Border.all(color: c.glassBorder, width: 0.8),
                      boxShadow: _isAllConfigured
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
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
                          color:
                              _isAllConfigured ? Colors.white : c.textTertiary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAllConfigured
                              ? 'Continue to Gallery'
                              : 'Enable All Permissions to Continue ($_remainingPermissionsCount left)',
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

                const SizedBox(height: 8),

                // Secondary button: App Info
                Center(
                  child: TextButton.icon(
                    onPressed: _openAppInfo,
                    icon: Icon(Icons.settings_outlined,
                        size: 16, color: c.textSecondary),
                    label: Text(
                      'Open System App Settings',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    String? secondaryActionText,
    VoidCallback? onSecondaryAction,
    required AppThemeColors c,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceGlass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF2E7D32).withOpacity(0.35)
              : c.glassBorder,
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
                      ? const Color(0xFF2E7D32).withOpacity(0.14)
                      : c.primary.withOpacity(0.12),
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
          const SizedBox(height: 12),
          // Action Buttons: ALWAYS available so the user is never locked out
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isGranted
                          ? c.surfaceGlass
                          : c.primary,
                      borderRadius: BorderRadius.circular(12),
                      border: isGranted
                          ? Border.all(color: c.glassBorder, width: 0.8)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isGranted ? 'Open Settings' : actionText,
                          style: TextStyle(
                            color: isGranted ? c.textPrimary : Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isGranted
                              ? CupertinoIcons.arrow_up_right_square
                              : CupertinoIcons.chevron_right,
                          color: isGranted ? c.textPrimary : Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (secondaryActionText != null && onSecondaryAction != null) ...[
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onSecondaryAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.surfaceGlass,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.glassBorder, width: 0.8),
                    ),
                    child: Text(
                      secondaryActionText,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
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
        color: c.surfaceGlass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF2E7D32).withOpacity(0.35)
              : c.glassBorder,
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
                      ? const Color(0xFF2E7D32).withOpacity(0.14)
                      : c.primary.withOpacity(0.12),
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
              CupertinoSwitch(
                value: isGranted,
                activeColor: const Color(0xFF2E7D32),
                onChanged: (val) => _toggleAutostartConfigured(val),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _guidanceTips.isNotEmpty
                ? _guidanceTips.join('\n')
                : 'Allow Autostart so new media from Camera or WhatsApp triggers real-time syncing even when the app is closed.',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openOEMAutostartSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isGranted
                          ? c.surfaceGlass
                          : c.primary,
                      borderRadius: BorderRadius.circular(12),
                      border: isGranted
                          ? Border.all(color: c.glassBorder, width: 0.8)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.gear_alt_fill,
                          color: isGranted ? c.textPrimary : Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Open Autostart Settings',
                          style: TextStyle(
                            color: isGranted ? c.textPrimary : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _toggleAutostartConfigured(!isGranted),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isGranted
                        ? c.surfaceGlass
                        : const Color(0xFF2E7D32).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isGranted
                          ? c.glassBorder
                          : const Color(0xFF2E7D32).withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isGranted ? 'Disable' : 'I\'ve Enabled It',
                    style: TextStyle(
                      color: isGranted
                          ? c.textSecondary
                          : const Color(0xFF2E7D32),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
