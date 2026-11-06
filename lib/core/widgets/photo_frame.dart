import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'surface_card.dart';

/// A 4:3 rounded photo with optional overlays.
///
/// With an [image] it shows the photo cropped to fill and an optional
/// [caption] pill. Without one it shows a dashed placeholder that calls
/// [onTapEmpty], used before a photo is taken. A photo
/// that fails to load (for example, its file was removed) shows an
/// "unavailable" state rather than an error.
class PhotoFrame extends StatelessWidget {
  const PhotoFrame({
    required this.image,
    required this.semanticLabel,
    super.key,
    this.caption,
    this.captionAlignment = AlignmentDirectional.bottomStart,
    this.onTapEmpty,
    this.emptyLabel = 'Take a photo',
  });

  /// The photo, or null for the empty placeholder.
  final ImageProvider? image;

  /// Describes the photo to screen readers, e.g. "Check-in photo, Oct 24".
  final String semanticLabel;

  /// Short overlay text such as the check-in time.
  final String? caption;

  /// Where [caption] sits.
  final AlignmentGeometry captionAlignment;

  final VoidCallback? onTapEmpty;
  final String emptyLabel;

  static const double _aspectRatio = 4 / 3;
  static const double _overlayInset = 10;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image == null) return _EmptyFrame(label: emptyLabel, onTap: onTapEmpty);

    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.xl);

    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.bgPrimary,
          borderRadius: radius,
        ),
        // Drawn on top of the photo so the outline isn't covered by it.
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: colors.borderDefault),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ResizedPhoto(image: image, semanticLabel: semanticLabel),
            if (caption case final caption?)
              Align(
                alignment: captionAlignment,
                child: Padding(
                  padding: const EdgeInsets.all(_overlayInset),
                  child: _OverlayPill(
                    child: Text(
                      caption,
                      style: context.textStyles.badge.copyWith(
                        color: colors.textBody,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Decodes the photo at the size it is displayed rather than at full camera
/// resolution, which for a 12 MP photo saves around 45 MB of memory.
class _ResizedPhoto extends StatelessWidget {
  const _ResizedPhoto({required this.image, required this.semanticLabel});

  final ImageProvider image;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        // Width alone keeps the photo's aspect ratio. For camera photos (4:3
        // or 3:4) in a 4:3 frame, width is the dimension that must cover.
        final decodeWidth = (constraints.maxWidth * pixelRatio).round();

        return Image(
          image: ResizeImage.resizeIfNeeded(decodeWidth, null, image),
          fit: BoxFit.cover,
          semanticLabel: semanticLabel,
          // Keeps the old photo on screen while a retaken one decodes.
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              const _UnavailablePhoto(),
        );
      },
    );
  }
}

class _UnavailablePhoto extends StatelessWidget {
  const _UnavailablePhoto();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.bgSecondary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: MediaQuery.textScalerOf(context).scale(20),
              color: colors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Photo unavailable',
              style: context.textStyles.badge.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFrame extends StatelessWidget {
  const _EmptyFrame({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SurfaceCard.dashed(
      onTap: onTap,
      semanticLabel: label,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          // At least the shape of the photo that replaces it, but free to
          // grow when large text needs more room.
          constraints: BoxConstraints(
            minHeight: constraints.maxWidth / PhotoFrame._aspectRatio,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.bgTertiary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Icon(
                        CupertinoIcons.camera,
                        size: MediaQuery.textScalerOf(context).scale(20),
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: context.textStyles.bodyStrong.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blurred, translucent pill for text laid over a photo.
class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.sm);

    return ClipRRect(
      borderRadius: radius,
      // Equivalent of a UIVisualEffectView behind the label.
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.overlayScrim,
            borderRadius: radius,
            border: Border.all(color: colors.overlayBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 1,
              vertical: AppSpacing.xs + 1,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
