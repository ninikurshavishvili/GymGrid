import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/check_in_photo.dart';

/// The photos of a check-in being edited: a sideways strip with a remove
/// button on each, ending in a tile that adds another.
class PhotoStrip extends StatefulWidget {
  const PhotoStrip({
    required this.photos,
    required this.imageOf,
    required this.canAdd,
    required this.isAdding,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<CheckInPhoto> photos;
  final ImageProvider Function(CheckInPhoto photo) imageOf;

  /// Whether there's room for another photo.
  final bool canAdd;

  /// Whether a picked photo is on its way.
  final bool isAdding;

  final VoidCallback onAdd;
  final ValueChanged<CheckInPhoto> onRemove;

  /// Taller than wide, like most photos taken at a gym.
  static const double _height = 200;
  static const double _tileWidth = 140;

  /// Narrow, so it's still in view beside two photos.
  static const double _addTileWidth = 64;

  @override
  State<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends State<PhotoStrip> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(PhotoStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photos.length > oldWidget.photos.length) {
      // After this frame, when the new tile has been laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealNewest());
    }
  }

  void _revealNewest() {
    if (!mounted || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    final duration = context.motionDuration;
    if (duration == Duration.zero) {
      _scrollController.jumpTo(position.maxScrollExtent);
    } else {
      unawaited(
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: duration,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return SizedBox(
      height: PhotoStrip._height,
      child: ListView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        children: [
          for (final (index, photo) in photos.indexed)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: _PhotoTile(
                key: ValueKey(photo),
                image: widget.imageOf(photo),
                semanticLabel: 'Photo ${index + 1} of ${photos.length}',
                onRemove: () => widget.onRemove(photo),
              ),
            ),
          if (widget.canAdd || widget.isAdding)
            _AddTile(isAdding: widget.isAdding, onTap: widget.onAdd),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.image,
    required this.semanticLabel,
    required this.onRemove,
    super.key,
  });

  final ImageProvider image;
  final String semanticLabel;
  final VoidCallback onRemove;

  /// Large enough to tap comfortably, though the badge drawn is smaller.
  static const double _removeTarget = 44;
  static const double _removeBadge = 26;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // A new photo settles into place instead of just appearing.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: context.motionDuration,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: SizedBox(
          width: PhotoStrip._tileWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: colors.bgSecondary),
              Image(
                image: ResizeImage.resizeIfNeeded(
                  (PhotoStrip._tileWidth *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  null,
                  image,
                ),
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Semantics(
                  container: true,
                  button: true,
                  label: 'Remove ${semanticLabel.toLowerCase()}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: SizedBox.square(
                      dimension: _removeTarget,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.overlayScrim,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: _removeBadge,
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 13,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.isAdding, required this.onTap});

  final bool isAdding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: isAdding ? 'Loading photo' : 'Add a photo',
      // Excluding the children also drops their tap action, so the node
      // declares it again, to stay usable with VoiceOver.
      onTap: isAdding ? null : onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isAdding ? null : onTap,
          child: SizedBox(
            width: PhotoStrip._addTileWidth,
            child: Center(
              child: isAdding
                  ? const CupertinoActivityIndicator()
                  : Icon(CupertinoIcons.plus, color: colors.actionGreen),
            ),
          ),
        ),
      ),
    );
  }
}
