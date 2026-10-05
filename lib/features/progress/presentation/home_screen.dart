import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/bordered_card.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/photo_frame.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/streak_card.dart';

/// Placeholder that previews the shared widgets. Replaced by the streak
/// cards and year grid in UI step 3.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _workouts = ['Strength', 'Cardio', 'Mobility', 'Other'];

  String? _workout = _workouts.first;
  bool _isSaving = false;
  ImageProvider? _samplePhoto;

  @override
  void initState() {
    super.initState();
    _drawSamplePhoto().then((photo) {
      if (mounted) setState(() => _samplePhoto = photo);
    }).ignore();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('Shared widgets', style: text.header),
            const _Section('StreakCard'),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StreakCard(
                    label: 'Current streak',
                    days: 14,
                    icon: Icons.local_fire_department,
                  ),
                ),
                SizedBox(width: AppSpacing.sm + 2),
                Expanded(child: StreakCard(label: 'Longest streak', days: 42)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StreakCard(
                    label: 'Current streak',
                    days: 14,
                    icon: Icons.local_fire_department,
                    isAtRisk: true,
                  ),
                ),
                SizedBox(width: AppSpacing.sm + 2),
                Expanded(child: StreakCard(label: 'Longest streak', days: 0)),
              ],
            ),
            const _Section('BorderedCard'),
            BorderedCard(
              onTap: () => _toast('Card tapped'),
              semanticLabel: 'Tappable card',
              child: Text('Tappable card', style: text.bodyStrong),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            BorderedCard.dashed(
              child: Text(
                'Dashed card for empty states',
                textAlign: TextAlign.center,
                style: text.body,
              ),
            ),
            const _Section('ChipSelector'),
            ChipSelector<String>(
              options: _workouts,
              selected: _workout,
              labelOf: (workout) => workout,
              onSelected: (workout) => setState(() => _workout = workout),
            ),
            const _Section('PrimaryButton'),
            PrimaryButton(
              label: _isSaving ? 'Saving…' : 'Tap to toggle loading',
              icon: Icons.photo_camera_outlined,
              isLoading: _isSaving,
              onPressed: () async {
                setState(() => _isSaving = true);
                await Future<void>.delayed(const Duration(seconds: 2));
                if (mounted) setState(() => _isSaving = false);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const PrimaryButton(label: 'Disabled', onPressed: null),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Delete check-in',
              tone: PrimaryButtonTone.danger,
              onPressed: () => _toast('Danger pressed'),
            ),
            const _Section('PhotoFrame'),
            PhotoFrame(
              image: null,
              semanticLabel: 'Check-in photo',
              onTapEmpty: () => _toast('Open camera'),
            ),
            const SizedBox(height: AppSpacing.md),
            PhotoFrame(
              image: _samplePhoto,
              semanticLabel: 'Sample check-in photo',
              caption: '07:42 AM',
              captionAlignment: AlignmentDirectional.topStart,
              action: PhotoFrameAction(
                icon: Icons.refresh,
                label: 'Retake',
                onPressed: () => _toast('Retake'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PhotoFrame(
              image: MemoryImage(Uint8List(4)),
              semanticLabel: 'Missing photo',
            ),
            const _Section('Navigation'),
            TextButton(
              onPressed: () =>
                  context.push(AppRoutes.dayDetail(DateTime.now())),
              child: const Text("Open today's detail"),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.checkIn),
              child: const Text('Open check-in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxl,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title.toUpperCase(),
        style: context.textStyles.badge.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// Paints a gradient stand-in for a camera photo until check-in exists.
Future<ImageProvider> _drawSamplePhoto() async {
  const width = 800;
  const height = 600;
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 800, 600),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(800, 600), [
        AppColors.dark.successSubtle,
        AppColors.dark.gridFilled,
      ]),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return MemoryImage(bytes!.buffer.asUint8List());
}
