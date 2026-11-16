import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/qr_code_generator.dart';
import '../../models/media_item.dart';
import '../../services/ghost_drop_service.dart';

class GhostDropSheet extends StatefulWidget {
  final List<MediaItem> items;

  const GhostDropSheet({super.key, required this.items});

  static Future<void> show(BuildContext context, {required List<MediaItem> items}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GhostDropSheet(items: items),
    );
  }

  @override
  State<GhostDropSheet> createState() => _GhostDropSheetState();
}

class _GhostDropSheetState extends State<GhostDropSheet> {
  final GhostDropService _ghostDrop = GhostDropService.instance;

  @override
  void initState() {
    super.initState();
    _ghostDrop.startSession(items: widget.items);
  }

  @override
  void dispose() {
    _ghostDrop.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    return ListenableBuilder(
      listenable: _ghostDrop,
      builder: (context, _) {
        final url = _ghostDrop.serverUrl;
        final isRunning = _ghostDrop.isRunning;
        final totalSize = _ghostDrop.formattedTotalSize;
        final count = widget.items.length;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              decoration: BoxDecoration(
                color: c.isDark
                    ? const Color(0xF5141416)
                    : const Color(0xF8F7F7F8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: c.textTertiary.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: c.primary.withOpacity(0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: c.primary, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          'GHOSTDROP P2P BEAM',
                          style: TextStyle(
                            color: c.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Instant Local Transfer',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sharing $count files ($totalSize) · Zero Internet required',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // QR Code Container
                  if (isRunning && url != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: c.primary.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrCodeWidget(
                        data: url,
                        size: 200,
                        darkColor: const Color(0xFF0F172A),
                        lightColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Copyable URL Pill
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied link: $url'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: c.surfaceElevated,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.glassBorderSubtle, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.link, size: 14, color: c.primary),
                            const SizedBox(width: 8),
                            Text(
                              url,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(CupertinoIcons.doc_on_doc, size: 13, color: c.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 60),
                    CircularProgressIndicator(color: c.primary),
                    const SizedBox(height: 16),
                    Text(
                      _ghostDrop.activeStatus,
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 60),
                  ],

                  const SizedBox(height: 20),

                  // Realtime Status Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.glassBorderSubtle, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _ghostDrop.connectedClients > 0
                                ? c.accentTeal
                                : c.accentAmber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _ghostDrop.activeStatus,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_ghostDrop.downloadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_ghostDrop.downloadCount} delivered',
                              style: TextStyle(
                                color: c.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Instructions
                  Text(
                    'Point any iPhone, Android, or laptop camera at this QR code to download the original full-res files instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stop Beam Button
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: c.isDark
                          ? const Color(0xFF27272A)
                          : const Color(0xFFE4E4E7),
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Done · Stop Beam',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
  },
);
  }
}

