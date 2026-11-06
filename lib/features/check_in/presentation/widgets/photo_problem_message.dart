import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../photo_picker.dart';

/// Explains why a photo couldn't be had, and what to do about it.
class PhotoProblemMessage extends StatelessWidget {
  const PhotoProblemMessage({
    required this.problem,
    required this.onOpenSettings,
    super.key,
  });

  final PhotoProblem problem;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final message = switch (problem) {
      PhotoProblem.cameraUnavailable =>
        'Camera access is off. Enable it in Settings, or choose a photo from '
            'your library.',
      PhotoProblem.libraryUnavailable =>
        "That photo couldn't be opened. Try another one.",
    };

    return Column(
      children: [
        // A live region, so VoiceOver reads this out when it appears.
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: context.textStyles.footnote.copyWith(
              color: context.colors.warning,
            ),
          ),
        ),
        if (problem == PhotoProblem.cameraUnavailable)
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Open Settings'),
          ),
      ],
    );
  }
}
