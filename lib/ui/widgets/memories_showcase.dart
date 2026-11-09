import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/memories_service.dart';
import '../screens/memories_story_screen.dart';
import 'cached_thumbnail_image.dart';

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
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.primary, c.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'On This Day',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.primary.withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  'Throwback',
                  style: TextStyle(
                    color: c.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Story Cards
        SizedBox(
          height: 165,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
        const SizedBox(height: 12),
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
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 116,
          height: 165,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.primary.withOpacity(0.4),
                c.accent.withOpacity(0.2),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: c.primary.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2), // Outer glowing gradient border
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Thumbnail Image
                CachedThumbnailImage(
                  localId: cover.localId,
                  filePath: cover.localFilePath,
                  isVideo: cover.mediaType.name == 'video',
                  size: 320,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: c.surfaceElevated,
                    child: Center(
                      child: Icon(Icons.image, color: c.textTertiary, size: 28),
                    ),
                  ),
                ),

                // Scrim Gradient for Legibility
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black54,
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black87,
                      ],
                      stops: [0.0, 0.3, 0.55, 1.0],
                    ),
                  ),
                ),

                // Top Badge: "1Y AGO"
                Positioned(
                  top: 8,
                  left: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        color: Colors.black.withOpacity(0.45),
                        child: Text(
                          widget.memory.yearsAgo == 1
                              ? '1Y AGO'
                              : '${widget.memory.yearsAgo}Y AGO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Titles
                Positioned(
                  left: 8,
                  right: 8,
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
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.memory.items.length} moments',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 10,
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
