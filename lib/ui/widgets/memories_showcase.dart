import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/memories_service.dart';
import '../screens/memories_story_screen.dart';
import 'cached_thumbnail_image.dart';

/// Apple Photos Memories & "On This Day" Showcase:
/// Presents Apple Photos story cards with authentic iOS typography,
/// delicate gradient scrims, year badges, and smooth interactive scale physics.
class MemoriesShowcase extends StatelessWidget {
  final List<MemoryGroup> memories;

  const MemoriesShowcase({
    super.key,
    required this.memories,
  });

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) {
      return const SizedBox.shrink();
    }

    final c = AppTheme.colors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Apple Photos Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Text(
                'Memories',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'On This Day',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Apple Memories Cards
        SizedBox(
          height: 170,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: memories.length,
            separatorBuilder: (_, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final memory = memories[index];
              return _MemoryCard(
                memory: memory,
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => MemoriesStoryScreen(
                        memories: memories,
                        initialGroupIndex: index,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _MemoryCard extends StatefulWidget {
  final MemoryGroup memory;
  final VoidCallback onTap;

  const _MemoryCard({
    required this.memory,
    required this.onTap,
  });

  @override
  State<_MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<_MemoryCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final cover = widget.memory.coverItem;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 120,
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c.isDark
                    ? const Color(0x66000000)
                    : const Color(0x1A000000),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Thumbnail Image
                CachedThumbnailImage(
                  localId: cover.localId,
                  filePath: cover.localFilePath,
                  isVideo: cover.mediaType.name == 'video',
                  size: 360,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: c.surfaceElevated,
                    child: Center(
                      child: Icon(CupertinoIcons.photo, color: c.textTertiary, size: 28),
                    ),
                  ),
                ),

                // Apple Scrim Gradient for Legibility
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x59000000),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xCC000000),
                      ],
                      stops: [0.0, 0.25, 0.50, 1.0],
                    ),
                  ),
                ),

                // Top Badge: "1Y AGO"
                Positioned(
                  top: 8,
                  left: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        color: Colors.black.withOpacity(0.40),
                        child: Text(
                          widget.memory.yearsAgo == 1
                              ? '1Y AGO'
                              : '${widget.memory.yearsAgo}Y AGO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Titles
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.memory.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(color: Color(0x99000000), blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${widget.memory.items.length} items',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
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
}
