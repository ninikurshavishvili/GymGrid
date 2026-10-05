import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'bordered_card.dart';

/// A button drawn over the bottom-end corner of a [PhotoFrame], e.g. Retake.
@immutable
class PhotoFrameAction {
  const PhotoFrameAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// A 4:3 rounded photo with optional overlays.
///
/// With an [image] it shows the photo cropped to fill, an optional [caption]
/// pill and an optional [action] button. Without one it shows a dashed
/// placeholder that calls [onTapEmpty], used before a photo is taken. A photo
/// that fails to load (for example, its file was removed) shows an
/// "unavailable" state rather than an error.
class PhotoFrame extends StatelessWidget {
  const PhotoFrame({
    required this.image,
    required this.semanticLabel,
    super.key,
    this.caption,
    this.captionAlignment = AlignmentDirectional.bottomStart,
    this.action,
    this.onTapEmpty,
    this.emptyLabel = 'Take a photo',
  });

  /// The photo, or null for the empty placeholder.
  final ImageProvider? image;

  /// Describes the photo to screen readers, e.g. "Check-in photo, Oct 24".
  final String semanticLabel;

  /// Short overlay text such as the check-in time.
  final String? caption;

  /// Where [caption] sits. Keep it away from the bottom-end corner when an
  /// [action] is shown.
  final AlignmentGeometry captionAlignment;

  final PhotoFrameAction? action;
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
            if (action case final action?)
              Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Padding(
                  padding: const EdgeInsets.all(_overlayInset),
                  child: _OverlayPill(
                    onTap: action.onPressed,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          action.icon,
                          size: MediaQuery.textScalerOf(context).scale(14),
                          color: colors.textPrimary,
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Flexible(
                          child: Text(
                            action.label,
                            style: context.textStyles.bodyStrong.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
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
              Icons.broken_image_outlined,
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
    return BorderedCard.dashed(
      onTap: onTap,
      semanticLabel: label,
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: PhotoFrame._aspectRatio,
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
                      Icons.photo_camera_outlined,
                      size: MediaQuery.textScalerOf(context).scale(20),
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodyStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Blurred, translucent pill for text and buttons laid over a photo.
class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(
      onTap == null ? AppRadius.sm : AppRadius.md,
    );

    final pill = ClipRRect(
      borderRadius: radius,
      // Equivalent of a UIVisualEffectView behind the label.
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Material(
          color: colors.overlayScrim,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.overlayBorder),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: onTap == null
                  ? const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 1,
                      vertical: AppSpacing.xs + 1,
                    )
                  : const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md + 1,
                      vertical: AppSpacing.sm - 1,
                    ),
              child: child,
            ),
          ),
        ),
      ),
    );

    return onTap == null ? pill : Semantics(button: true, child: pill);
  }
}
