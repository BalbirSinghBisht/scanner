import 'media_item.dart';

class DuplicateGroup {
  final String signature;
  final List<MediaItem> items;

  const DuplicateGroup({
    required this.signature,
    required this.items,
  });

  int get totalSizeBytes => items.fold(0, (sum, item) => sum + item.fileSize);
  int get potentialSavingsBytes => items.length > 1
      ? items.sublist(1).fold(0, (sum, item) => sum + item.fileSize)
      : 0;

  String get formattedPotentialSavings {
    final bytes = potentialSavingsBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
