import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';

/// Placeholder that previews the type scale and colour tokens. Replaced by
/// the streak cards and year grid in UI step 3.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('GymGrid', style: text.header),
            Text(
              'Type scale preview',
              style: text.badge.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'CURRENT STREAK',
              style: text.badge.copyWith(color: colors.textSecondary),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '14 ', style: text.stat),
                  TextSpan(
                    text: 'days',
                    style: text.monoBody.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Card title in Inter semibold', style: text.bodyStrong),
            Text(
              'Body copy in Inter regular. Notes and supporting text use '
              'this style.',
              style: text.body.copyWith(color: colors.textBody),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (name, color) in [
                  ('bgSecondary', colors.bgSecondary),
                  ('border', colors.borderDefault),
                  ('gridEmpty', colors.gridEmpty),
                  ('gridFilled', colors.gridFilled),
                  ('action', colors.actionGreen),
                  ('danger', colors.dangerRed),
                  ('warning', colors.warning),
                ])
                  _Swatch(name: name, color: color),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () =>
                  context.push(AppRoutes.dayDetail(DateTime.now())),
              child: const Text("Open today's detail"),
            ),
            TextButton(
              onPressed: () => showLicensePage(context: context),
              child: const Text('Licences'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.xl),
        child: FilledButton.icon(
          onPressed: () => context.push(AppRoutes.checkIn),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Check in'),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: context.colors.borderDefault),
          ),
          child: const SizedBox.square(dimension: 32),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          name,
          style: context.textStyles.badge.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
