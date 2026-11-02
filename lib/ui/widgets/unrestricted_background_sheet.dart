import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  bool _isUnrestricted = false;
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
    }
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final isIgnored = await DeviceSettingsHelper.isIgnoringBatteryOptimizations();
    final manufacturer = await DeviceSettingsHelper.getDeviceManufacturer();
    final tips = DeviceSettingsHelper.getOEMGuidanceTips(manufacturer);

    if (mounted) {
      setState(() {
        _isUnrestricted = isIgnored;
        _manufacturer = manufacturer;
        _guidanceTips = tips;
        _isLoading = false;
      });
      widget.onSettingsChanged?.call();
    }
  }

  Future<void> _requestUnrestricted() async {
    await DeviceSettingsHelper.requestIgnoreBatteryOptimizations();
    // Re-check after native system dialog resolves
    await Future.delayed(const Duration(milliseconds: 1000));
    await _checkStatus();
  }

  Future<void> _openOEMSettings() async {
    await DeviceSettingsHelper.openAutostartSettings();
  }

  Future<void> _openAppInfo() async {
    await DeviceSettingsHelper.openAppInfoSettings();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
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

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isUnrestricted
                            ? const Color(0xFF2E7D32).withOpacity(0.14)
                            : Colors.orange.withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isUnrestricted
                            ? CupertinoIcons.bolt_fill
                            : CupertinoIcons.bolt_slash_fill,
                        color: _isUnrestricted
                            ? const Color(0xFF2E7D32)
                            : Colors.orangeAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unrestricted Background Run',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Prevent Android from stopping backup after 15 min',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Live status card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _isUnrestricted
                        ? const Color(0xFF2E7D32).withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isUnrestricted
                          ? const Color(0xFF2E7D32).withOpacity(0.4)
                          : Colors.orange.withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isUnrestricted
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.exclamationmark_triangle_fill,
                        color: _isUnrestricted
                            ? const Color(0xFF2E7D32)
                            : Colors.orangeAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isLoading
                              ? 'Checking background permissions...'
                              : (_isUnrestricted
                                  ? 'Unrestricted Active: Continuous 24/7 background backup enabled without time limits.'
                                  : 'Restricted: Android will pause or kill background sync after ~15 minutes.'),
                          style: TextStyle(
                            color: _isUnrestricted
                                ? (_isDark(context)
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF1B5E20))
                                : (_isDark(context)
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

                const SizedBox(height: 14),

                // Explanation
                Text(
                  'By default, Android Doze mode and task killers suspend background network activity and kill services after 15 minutes of screen-off time. Allowing unrestricted background running exempts the app so your photos & videos sync continuously.',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 18),

                // Primary Request Button
                if (!_isUnrestricted) ...[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _requestUnrestricted,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: c.primary.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.bolt_badge_automatic,
                              color: Colors.white, size: 19),
                          SizedBox(width: 8),
                          Text(
                            'Allow Unrestricted Background Run',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // OEM Instructions Section (if Samsung, Xiaomi, Realme, Oppo, Vivo, OnePlus)
                if (Platform.isAndroid && _guidanceTips.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surfaceElevated.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.glassBorder, width: 0.6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(CupertinoIcons.device_phone_portrait,
                                color: c.primary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '$_manufacturer Device Optimization Tips',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._guidanceTips.map(
                          (tip) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: TextStyle(
                                        color: c.primary,
                                        fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 12.2,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _openOEMSettings,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: c.surfaceGlass,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: c.primary.withOpacity(0.4),
                                width: 0.7,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.tune_rounded,
                                    color: c.primary, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Open $_manufacturer Autostart & Battery Settings',
                                  style: TextStyle(
                                    color: c.primary,
                                    fontSize: 12.5,
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
                  const SizedBox(height: 12),
                ],

                // App Info Settings button
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _openAppInfo,
                        icon: Icon(Icons.settings_outlined,
                            size: 16, color: c.textSecondary),
                        label: Text(
                          'Open App Info',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: c.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

