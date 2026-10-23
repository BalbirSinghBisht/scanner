import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../widgets/media_item_tile.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  String _activeFilter = 'All'; // All, Photos, Videos, Uploaded, Pending, Failed, Large
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MediaItem> _filterItems(List<MediaItem> items) {
    return items.where((item) {
      // Filter by type or state
      if (_activeFilter == 'Photos' && item.mediaType != AppMediaType.image) {
        return false;
      }
      if (_activeFilter == 'Videos' && item.mediaType != AppMediaType.video) {
        return false;
      }
      if (_activeFilter == 'Uploaded' && item.uploadState != UploadState.UPLOADED) {
        return false;
      }
      if (_activeFilter == 'Pending' &&
          item.uploadState != UploadState.READY_TO_UPLOAD &&
          item.uploadState != UploadState.RETRY_PENDING) {
        return false;
      }
      if (_activeFilter == 'Failed' && item.uploadState != UploadState.FAILED) {
        return false;
      }
      if (_activeFilter == 'Large' &&
          item.fileSize < AppConstants.defaultLargeFileThresholdBytes) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty &&
          !item.fileName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();
    final filteredItems = _filterItems(backup.mediaItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => backup.refreshData(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search files by name...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.darkCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.darkCardBorder),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),

            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _filterChip('All'),
                  _filterChip('Photos'),
                  _filterChip('Videos'),
                  _filterChip('Uploaded'),
                  _filterChip('Pending'),
                  _filterChip('Failed'),
                  _filterChip('Large'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Grid or Empty State
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.perm_media_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            backup.mediaItems.isEmpty
                                ? 'No media discovered yet'
                                : 'No items match your filter',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            backup.mediaItems.isEmpty
                                ? 'Run a scan to index photos and videos from your device.'
                                : 'Try changing or clearing your search filters.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (backup.mediaItems.isEmpty) ...[
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => backup.startScan(),
                              icon: const Icon(Icons.sync),
                              label: const Text('Start Library Scan'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        return MediaItemTile(item: filteredItems[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _activeFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() => _activeFilter = label);
        },
        selectedColor: AppTheme.primaryBlue.withOpacity(0.3),
        checkmarkColor: AppTheme.primaryAccent,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryAccent : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        backgroundColor: AppTheme.darkCard,
        side: BorderSide(
          color: isSelected ? AppTheme.primaryAccent : AppTheme.darkCardBorder,
        ),
      ),
    );
  }
}
