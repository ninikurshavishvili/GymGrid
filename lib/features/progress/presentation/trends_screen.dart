import 'dart:async';

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoSliverNavigationBar,
        CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/navigation_back_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../domain/entities/trends.dart';
import 'trends_cubit.dart';
import 'trends_labels.dart';
import 'trends_state.dart';
import 'widgets/trends_chart.dart';

/// How effort and energy have gone over the past month, 3 months or year.
///
/// Laid out like a chart screen in Apple Health: a range control, the
/// chart, and a plain-language summary under it, which is also what
/// VoiceOver reads for the chart.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<TrendsCubit, TrendsState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                leading: const NavigationBackButton(),
                automaticallyImplyLeading: false,
                largeTitle: const Text('Trends'),
                // The small title appears only once the large one has
                // scrolled away.
                middle: const Text('Trends'),
                alwaysShowMiddle: false,
                backgroundColor: context.colors.bgPrimary,
                border: null,
                transitionBetweenRoutes: false,
              ),
              switch ((state.status, state.trends)) {
                (TrendsStatus.failure, _) => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(
                    title: "Couldn't load your trends",
                    canRetry: true,
                  ),
                ),
                (_, null) => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CupertinoActivityIndicator()),
                ),
                (_, final trends?) when !trends.hasRatings =>
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Message(
                      title: 'No ratings yet',
                      text:
                          'Rate your effort and energy when you check in, '
                          "and you'll see how they change here.",
                    ),
                  ),
                (_, final trends?) => _Content(state: state, trends: trends),
              },
            ],
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.trends});

  final TrendsState state;
  final Trends trends;

  /// Apple's minimum tap target.
  static const double _minTapHeight = 44;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TrendsCubit>();
    final colors = context.colors;
    final text = context.textStyles;
    final isEmpty =
        trends.effort.points.isEmpty && trends.energy.points.isEmpty;

    return SliverSafeArea(
      top: false,
      sliver: SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        sliver: SliverList.list(
          children: [
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<TrendRange>(
                groupValue: state.range,
                // Segments sized to their words, so "3 Months" keeps to
                // one line at large text sizes.
                proportionalWidth: true,
                onValueChanged: (range) {
                  if (range != null) cubit.selectRange(range);
                },
                children: {
                  for (final range in TrendRange.values)
                    // Taller than UIKit's segmented control, to reach
                    // Apple's minimum tap size.
                    range: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _minTapHeight,
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Text(range.title, textAlign: TextAlign.center),
                      ),
                    ),
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _LineToggle(
                  name: 'Effort',
                  color: colors.chartEffort,
                  isOn: state.showsEffort,
                  onToggle: cubit.toggleEffort,
                ),
                _LineToggle(
                  name: 'Energy',
                  color: colors.chartEnergy,
                  dashes: TrendsChart.energyDashes,
                  isOn: state.showsEnergy,
                  onToggle: cubit.toggleEnergy,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              // One stop for VoiceOver: what the chart shows, in words.
              semanticLabel: trends.chartLabel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.lg,
                children: [
                  if (isEmpty)
                    SizedBox(
                      height: TrendsChart.plotHeight,
                      child: Center(
                        child: Text(
                          'No ratings in ${trends.range.period}',
                          textAlign: TextAlign.center,
                          style: text.bodyStrong.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    TrendsChart(
                      trends: trends,
                      showsEffort: state.showsEffort,
                      showsEnergy: state.showsEnergy,
                    ),
                  for (final summary in trends.summaries)
                    Text(
                      summary,
                      style: text.body.copyWith(color: colors.textBody),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows or hides one line, with a sample of how that line is drawn, like
/// a chart legend you can tap.
class _LineToggle extends StatelessWidget {
  const _LineToggle({
    required this.name,
    required this.color,
    required this.isOn,
    required this.onToggle,
    this.dashes,
  });

  final String name;
  final Color color;
  final bool isOn;
  final VoidCallback onToggle;

  /// Null for a solid line.
  final List<int>? dashes;

  /// Apple's minimum tap target. The capsule drawn inside it is smaller.
  static const double _minTapHeight = 44;

  /// The sample line's length.
  static const double _sampleLength = 20;

  void _toggle() {
    unawaited(HapticFeedback.selectionClick());
    onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      container: true,
      button: true,
      toggled: isOn,
      label: '$name line',
      // Excluding the children also drops their tap action, so the node
      // declares it again, to stay usable with VoiceOver.
      onTap: _toggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTapHeight),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: context.motionDuration,
              curve: Curves.easeOut,
              decoration: ShapeDecoration(
                color: isOn ? colors.bgSecondary : colors.bgPrimary,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isOn ? colors.bgSecondary : colors.borderDefault,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.sm,
                children: [
                  CustomPaint(
                    size: const Size(_sampleLength, AppSpacing.xxs),
                    painter: _LineSamplePainter(
                      color: isOn ? color : colors.textMuted,
                      dashes: dashes,
                    ),
                  ),
                  Text(
                    name,
                    style: context.textStyles.footnote.copyWith(
                      color: isOn ? colors.textBody : colors.textSecondary,
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

/// A short stretch of line, solid or dashed, as the chart draws it.
class _LineSamplePainter extends CustomPainter {
  const _LineSamplePainter({required this.color, this.dashes});

  final Color color;
  final List<int>? dashes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    final dashes = this.dashes;
    if (dashes == null) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    var x = 0.0;
    for (var index = 0; x < size.width; index++) {
      final length = dashes[index % dashes.length].toDouble();
      if (index.isEven) {
        final end = (x + length).clamp(0.0, size.width);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      }
      x += length;
    }
  }

  @override
  bool shouldRepaint(_LineSamplePainter oldDelegate) =>
      color != oldDelegate.color || dashes != oldDelegate.dashes;
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.text, this.canRetry = false});

  final String title;
  final String? text;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    final text = this.text;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyStrong.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            if (text != null)
              Text(
                text,
                textAlign: TextAlign.center,
                style: context.textStyles.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            if (canRetry)
              TextButton(
                onPressed: context.read<TrendsCubit>().watch,
                child: const Text('Try again'),
              ),
          ],
        ),
      ),
    );
  }
}
