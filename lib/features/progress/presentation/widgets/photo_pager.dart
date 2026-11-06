import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/photo_frame.dart';

/// A check-in's photos, one at a time: swipe to move between them.
///
/// Dots show the position when there's more than one, and a newly added
/// photo slides into view, so adding one visibly does something.
class PhotoPager extends StatefulWidget {
  const PhotoPager({required this.images, this.caption, super.key});

  /// Never empty.
  final List<ImageProvider> images;

  /// Short overlay text such as the check-in time.
  final String? caption;

  @override
  State<PhotoPager> createState() => _PhotoPagerState();
}

class _PhotoPagerState extends State<PhotoPager> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void didUpdateWidget(PhotoPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final count = widget.images.length;

    if (count > oldWidget.images.length) {
      // After this frame, when the new page exists to move to.
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLastPage());
    } else if (_page >= count) {
      // The photo on show was removed.
      _page = count - 1;
    }
  }

  void _showLastPage() {
    if (!mounted || !_pageController.hasClients) return;

    final last = widget.images.length - 1;
    final duration = context.motionDuration;
    if (duration == Duration.zero) {
      _pageController.jumpToPage(last);
    } else {
      unawaited(
        _pageController.animateToPage(
          last,
          duration: duration,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return Column(
      spacing: AppSpacing.sm,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => PhotoFrame(
              image: images[index],
              semanticLabel: 'Photo ${index + 1} of ${images.length}',
              caption: widget.caption,
            ),
          ),
        ),
        if (images.length > 1) _PageDots(count: images.length, page: _page),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.page});

  final int count;
  final int page;

  static const double _size = 7;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = context.motionDuration;

    // The photos announce their own position.
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.sm - 2,
        children: [
          for (var index = 0; index < count; index++)
            AnimatedContainer(
              duration: duration,
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == page ? colors.textPrimary : colors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
