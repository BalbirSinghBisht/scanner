import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../models/paper_trail_doc.dart';
import '../../providers/backup_provider.dart';
import '../../services/paper_trail_service.dart';
import '../widgets/cached_thumbnail_image.dart';
import '../widgets/haikei_background.dart';
import '../widgets/paper_trail_form_sheet.dart';
import 'media_preview_screen.dart';

enum PaperTrailFilter {
  all,
  active,
  expiringSoon,
  expired,
}

class PaperTrailScreen extends StatefulWidget {
  const PaperTrailScreen({super.key});

  @override
  State<PaperTrailScreen> createState() => _PaperTrailScreenState();
}

class _PaperTrailScreenState extends State<PaperTrailScreen> {
  PaperTrailFilter _filter = PaperTrailFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final paperTrail = context.watch<PaperTrailService>();
    final backup = context.watch<BackupProvider>();
    final docs = paperTrail.allDocs;

    // Filter documents
    final filteredDocs = docs.where((doc) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matches = doc.title.toLowerCase().contains(query) ||
            (doc.storeName?.toLowerCase().contains(query) ?? false) ||
            doc.category.toLowerCase().contains(query);
        if (!matches) return false;
      }

      switch (_filter) {
        case PaperTrailFilter.active:
          return doc.hasWarranty && !doc.isWarrantyExpired;
        case PaperTrailFilter.expiringSoon:
          return doc.isExpiringSoon;
        case PaperTrailFilter.expired:
          return doc.hasWarranty && doc.isWarrantyExpired;
        case PaperTrailFilter.all:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: HaikeiBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(c),
                _buildStatsHeader(paperTrail, c),
                _buildFilterChips(c),
                Expanded(
                  child: filteredDocs.isEmpty
                      ? _buildEmptyState(c)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final mediaItem = backup.mediaItems.firstWhere(
                              (it) => it.localId == doc.localId,
                              orElse: () => MediaItem(
                                localId: doc.localId,
                                fileName: doc.title,
                                mediaType: AppMediaType.image,
                                mimeType: 'image/jpeg',
                                fileSize: 0,
                                createdAt: doc.purchaseDate,
                              ),
                            );

                            return _buildDocCard(doc, mediaItem, c);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppThemeColors c) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: AppTheme.appleBlurBar(context: context),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: () => Navigator.of(context).pop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.chevron_back, color: c.primary, size: 22),
                    Text('Albums', style: TextStyle(color: c.primary, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paper Trail & Warranties',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader(PaperTrailService paperTrail, AppThemeColors c) {
    final activeCount = paperTrail.activeWarranties.length;
    final expiringCount = paperTrail.expiringSoonWarranties.length;
    final totalSpent = paperTrail.totalTrackedSpending;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.glassBorderSubtle, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('$activeCount', 'Active Warranties', c.accentTeal, c),
          Container(width: 1, height: 36, color: c.glassBorderSubtle),
          _buildStatColumn('$expiringCount', 'Expiring <30d', c.accentAmber, c),
          Container(width: 1, height: 36, color: c.glassBorderSubtle),
          _buildStatColumn('\$${totalSpent.toStringAsFixed(0)}', 'Total Tracked', c.primary, c),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String val, String label, Color accent, AppThemeColors c) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(AppThemeColors c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip('All Documents', PaperTrailFilter.all, c),
          _buildChip('Active Warranties', PaperTrailFilter.active, c),
          _buildChip('Expiring Soon', PaperTrailFilter.expiringSoon, c),
          _buildChip('Expired', PaperTrailFilter.expired, c),
        ],
      ),
    );
  }

  Widget _buildChip(String label, PaperTrailFilter filter, AppThemeColors c) {
    final isSelected = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? c.primary
              : (c.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? c.primary : c.glassBorderSubtle,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : c.textPrimary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDocCard(PaperTrailDoc doc, MediaItem mediaItem, AppThemeColors c) {
    final df = DateFormat('MMM d, yyyy');
    final hasWarranty = doc.hasWarranty;
    final isExpired = doc.isWarrantyExpired;
    final isExpiringSoon = doc.isExpiringSoon;

    Color badgeColor = c.accentTeal;
    if (isExpired) {
      badgeColor = c.accentRose;
    } else if (isExpiringSoon) {
      badgeColor = c.accentAmber;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.glassBorderSubtle, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaPreviewScreen.single(item: mediaItem),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: CachedThumbnailImage(
                      localId: mediaItem.localId,
                      filePath: mediaItem.localFilePath,
                      isVideo: mediaItem.isVideo,
                      fit: BoxFit.cover,
                      size: 200,
                      placeholder: Container(
                        color: c.surfaceElevated,
                        child: Center(
                          child: Icon(Icons.receipt_long, color: c.textTertiary, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              doc.title,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (doc.amount != null)
                            Text(
                              doc.formattedAmount,
                              style: TextStyle(
                                color: c.primary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Store & Category
                      Row(
                        children: [
                          if (doc.storeName != null && doc.storeName!.isNotEmpty) ...[
                            Text(
                              doc.storeName!,
                              style: TextStyle(color: c.textSecondary, fontSize: 12),
                            ),
                            const Text(' · ', style: TextStyle(color: Colors.grey)),
                          ],
                          Text(
                            doc.category,
                            style: TextStyle(color: c.textTertiary, fontSize: 11.5),
                          ),
                          const Spacer(),
                          Text(
                            df.format(doc.purchaseDate),
                            style: TextStyle(color: c.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Warranty Status Pill
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: badgeColor.withOpacity(0.3), width: 0.6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasWarranty
                                      ? (isExpired ? CupertinoIcons.shield_slash : CupertinoIcons.shield_fill)
                                      : CupertinoIcons.doc_text,
                                  size: 11,
                                  color: badgeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  doc.formattedWarrantyStatus,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: () {
                              PaperTrailFormSheet.show(
                                context,
                                item: mediaItem,
                                existingDoc: doc,
                              );
                            },
                            child: Icon(CupertinoIcons.ellipsis, size: 16, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppThemeColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: c.accentTeal.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined, size: 48, color: c.accentTeal),
            ),
            const SizedBox(height: 18),
            Text(
              'No Tracked Documents',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Snap or open any receipt, invoice, or warranty card in your gallery and tap "Track in Paper Trail".',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
