import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/duplicate_group.dart';
import '../../providers/backup_provider.dart';
import '../widgets/media_item_tile.dart';
import '../widgets/stat_card.dart';

class AnalysisDashboardScreen extends StatefulWidget {
  const AnalysisDashboardScreen({super.key});

  @override
  State<AnalysisDashboardScreen> createState() =>
      _AnalysisDashboardScreenState();
}

class _AnalysisDashboardScreenState extends State<AnalysisDashboardScreen> {
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    final backup = Provider.of<BackupProvider>(context, listen: false);
    if (backup.analysisReport == null && backup.mediaItems.isNotEmpty) {
      backup.runAnalysis();
    }
  }

  Future<void> _triggerAnalysis() async {
    setState(() => _isAnalyzing = true);
    final backup = Provider.of<BackupProvider>(context, listen: false);
    await backup.runAnalysis();
    setState(() => _isAnalyzing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backup = context.watch<BackupProvider>();
    final report = backup.analysisReport;
    final stats = backup.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Analysis'),
        actions: [
          IconButton(
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.analytics_outlined),
            onPressed: _isAnalyzing ? null : _triggerAnalysis,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Library Intelligence',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Local metadata & SHA-256 duplicate analysis',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _triggerAnalysis,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Analyze'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Overview Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Duplicates Found',
                        value: stats.duplicateCount.toString(),
                        icon: Icons.copy_all_rounded,
                        iconColor: AppTheme.amberWarning,
                        subtitle: 'Redundant items',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Large Files',
                        value: (report?.largeFiles.length ?? 0).toString(),
                        icon: Icons.folder_zip_outlined,
                        iconColor: AppTheme.roseDanger,
                        subtitle: '> 50 MB each',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Duplicates Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.copy_all_rounded,
                      color: AppTheme.amberWarning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Detected Duplicate Sets (${backup.duplicateGroups.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (backup.duplicateGroups.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.darkCardBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'No duplicate files detected. All scanned files have unique hashes and metadata.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: backup.duplicateGroups.length,
                  itemBuilder: (context, index) {
                    final group = backup.duplicateGroups[index];
                    return _buildDuplicateGroupCard(group);
                  },
                ),

              const SizedBox(height: 24),

              // Large Files Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storage_rounded,
                      color: AppTheme.roseDanger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Large Media Files (> 50 MB)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (report == null || report.largeFiles.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.darkCardBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'No large files over 50 MB found in library.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: report.largeFiles.length,
                    itemBuilder: (context, index) {
                      final item = report.largeFiles[index];
                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        child: MediaItemTile(item: item),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 24),

              // Monthly Timeline Breakdown
              if (report != null && report.monthlyDistribution.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Timeline Breakdown',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.darkCardBorder),
                  ),
                  child: Column(
                    children: report.monthlyDistribution.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${entry.value} files',
                                style: const TextStyle(
                                  color: AppTheme.primaryAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDuplicateGroupCard(DuplicateGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.amberWarning.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${group.items.length} Duplicate Copies',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.amberWarning,
                ),
              ),
              Text(
                'Saves: ${group.formattedPotentialSavings}',
                style: const TextStyle(
                  color: AppTheme.emeraldGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Signature: ${group.signature}',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.white54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: group.items.length,
              itemBuilder: (context, idx) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: MediaItemTile(item: group.items[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
