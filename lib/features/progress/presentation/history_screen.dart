import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoSliverNavigationBar;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/navigation_back_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../check_in/domain/entities/check_in.dart';
import '../../check_in/domain/repositories/photo_locator.dart';
import '../../check_in/presentation/check_in_display.dart';
import '../../check_in/presentation/workout_type_labels.dart';
import '../domain/entities/history_month.dart';
import 'history_cubit.dart';
import 'history_state.dart';
import 'widgets/check_in_summary.dart';

/// Every check-in there has been, newest first, in a section per month.
///
/// Laid out like an iOS inset grouped list under a large title. Each row
/// opens that day, and the list follows edits and deletions made there.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({required this.photoLocator, super.key});

  final PhotoLocator photoLocator;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                leading: const NavigationBackButton(),
                automaticallyImplyLeading: false,
                largeTitle: const Text('History'),
                // The small title appears only once the large one has
                // scrolled away.
                middle: const Text('History'),
                alwaysShowMiddle: false,
                backgroundColor: context.colors.bgPrimary,
                border: null,
                transitionBetweenRoutes: false,
              ),
              switch (state) {
                HistoryLoading() => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CupertinoActivityIndicator()),
                ),
                HistoryLoaded(:final months) when months.isEmpty =>
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Message(text: 'No check-ins yet'),
                  ),
                HistoryLoaded(:final months) => SliverSafeArea(
                  top: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    // Built as they scroll in, so years of check-ins don't
                    // all decode their photos at once.
                    sliver: SliverList.separated(
                      itemCount: months.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.xl),
                      itemBuilder: (context, index) => _MonthSection(
                        month: months[index],
                        photoLocator: photoLocator,
                      ),
                    ),
                  ),
                ),
                HistoryFailure() => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(
                    text: "Couldn't load your check-ins",
                    canRetry: true,
                  ),
                ),
              },
            ],
          );
        },
      ),
    );
  }
}

/// A month's heading and its check-ins in one grouped card.
class _MonthSection extends StatelessWidget {
  const _MonthSection({required this.month, required this.photoLocator});

  final HistoryMonth month;
  final PhotoLocator photoLocator;

  /// Where a row's text starts: the row's padding, the photo, and the gap
  /// after it. Separators start there, as in iOS lists.
  static const double _textInset =
      AppSpacing.md + CheckInSummary.photoSize + AppSpacing.md;

  void _open(BuildContext context, CheckIn checkIn) {
    unawaited(context.push(AppRoutes.dayDetail(checkIn.date)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;
    final title = MaterialLocalizations.of(
      context,
    ).formatMonthYear(DateTime(month.year, month.month));
    final count = month.checkIns.length;
    final countLabel = count == 1 ? '1 check-in' : '$count check-ins';
    // At accessibility sizes the photo sits above the text, so separators
    // run the width of the card instead.
    final separatorInset = context.usesAccessibilityTextSize
        ? AppSpacing.md
        : _textInset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        Semantics(
          container: true,
          header: true,
          label: '$title, $countLabel',
          excludeSemantics: true,
          // A Wrap so the count moves to its own line at large text sizes.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: text.bodyStrong.copyWith(color: colors.textPrimary),
              ),
              Text(
                countLabel,
                style: text.footnote.copyWith(color: colors.gridFilled),
              ),
            ],
          ),
        ),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, checkIn) in month.checkIns.indexed) ...[
                if (index > 0) Divider(indent: separatorInset),
                _HistoryRow(
                  checkIn: checkIn,
                  cover: photoLocator.imageOf(checkIn.coverPhotoPath),
                  onTap: () => _open(context, checkIn),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.checkIn,
    required this.cover,
    required this.onTap,
  });

  final CheckIn checkIn;
  final ImageProvider cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final date = checkIn.date.toLocalDateTime();
    final time = checkIn.timeLabel(context);

    return Semantics(
      container: true,
      button: true,
      label: [
        checkIn.title,
        localizations.formatFullDate(date),
        time,
        ?checkIn.notePreview,
      ].join(', '),
      // Excluding the children also drops the InkWell's tap action, so the
      // node declares it again, to stay usable with VoiceOver.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: CheckInSummary(
            checkIn: checkIn,
            cover: cover,
            when: '${localizations.formatMediumDate(date)} · $time',
            whenColor: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.canRetry = false});

  final String text;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyStrong.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            if (canRetry)
              TextButton(
                onPressed: context.read<HistoryCubit>().watch,
                child: const Text('Try again'),
              ),
          ],
        ),
      ),
    );
  }
}
