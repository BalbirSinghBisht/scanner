import '../models/media_item.dart';

class MemoryGroup {
  final String title;
  final String subtitle;
  final int yearsAgo;
  final List<MediaItem> items;
  final DateTime date;

  const MemoryGroup({
    required this.title,
    required this.subtitle,
    required this.yearsAgo,
    required this.items,
    required this.date,
  });

  MediaItem get coverItem => items.first;
}

class MemoriesService {
  static final MemoriesService instance = MemoriesService._init();
  MemoriesService._init();

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  /// Discovers "On This Day" and historical throwback memory groups
  List<MemoryGroup> findMemories(
    List<MediaItem> allItems, {
    DateTime? referenceDate,
  }) {
    if (allItems.isEmpty) return [];

    final today = referenceDate ?? DateTime.now();
    final currentYear = today.year;
    final currentMonth = today.month;
    final currentDay = today.day;

    // Filter out locked or junk items
    final validItems = allItems.where((it) => !it.isLockedFolder).toList();

    // Group items by year
    final Map<int, List<MediaItem>> exactDayByYear = {};
    final Map<int, List<MediaItem>> windowDayByYear = {};
    final Map<int, List<MediaItem>> monthByYear = {};

    for (final item in validItems) {
      final created = item.createdAt;
      final year = created.year;

      // Only past years count as "Throwback"
      if (year >= currentYear) continue;

      if (created.month == currentMonth) {
        // 1. Exact day match
        if (created.day == currentDay) {
          exactDayByYear.putIfAbsent(year, () => []).add(item);
        }
        // 2. Window match (+/- 2 days around today)
        else if ((created.day - currentDay).abs() <= 2) {
          windowDayByYear.putIfAbsent(year, () => []).add(item);
        }
        // 3. Same month match
        monthByYear.putIfAbsent(year, () => []).add(item);
      }
    }

    final List<MemoryGroup> memories = [];
    final Set<int> usedYears = {};

    // 1. Prioritize Exact "On This Day" matches
    final exactYears = exactDayByYear.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final year in exactYears) {
      final items = exactDayByYear[year]!;
      if (items.isNotEmpty) {
        final diff = currentYear - year;
        final title = diff == 1 ? '1 Year Ago Today' : '$diff Years Ago Today';
        final subtitle = '${_monthNames[currentMonth - 1]} $currentDay, $year';
        memories.add(MemoryGroup(
          title: title,
          subtitle: subtitle,
          yearsAgo: diff,
          items: items,
          date: DateTime(year, currentMonth, currentDay),
        ));
        usedYears.add(year);
      }
    }

    // 2. Add Window "This Week in Past Years" matches if we have few memories
    if (memories.length < 3) {
      final windowYears = windowDayByYear.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final year in windowYears) {
        if (usedYears.contains(year)) continue;
        final items = windowDayByYear[year]!;
        if (items.length >= 2) {
          final diff = currentYear - year;
          final title = diff == 1 ? '1 Year Ago This Week' : '$diff Years Ago This Week';
          final subtitle = '${_monthNames[currentMonth - 1]} $year';
          memories.add(MemoryGroup(
            title: title,
            subtitle: subtitle,
            yearsAgo: diff,
            items: items,
            date: DateTime(year, currentMonth, currentDay),
          ));
          usedYears.add(year);
        }
      }
    }

    // 3. If still needed, add Monthly Throwback highlights
    if (memories.length < 2) {
      final monthYears = monthByYear.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final year in monthYears) {
        if (usedYears.contains(year)) continue;
        final items = monthByYear[year]!;
        if (items.length >= 3) {
          final diff = currentYear - year;
          final title = '${_monthNames[currentMonth - 1]} $year';
          final subtitle = '$diff years ago • ${items.length} moments';
          memories.add(MemoryGroup(
            title: title,
            subtitle: subtitle,
            yearsAgo: diff,
            items: items.take(12).toList(),
            date: DateTime(year, currentMonth, 1),
          ));
          usedYears.add(year);
        }
      }
    }

    return memories;
  }
}

