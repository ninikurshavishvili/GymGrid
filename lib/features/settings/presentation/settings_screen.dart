import 'dart:async';

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        CupertinoIcons,
        CupertinoSliverNavigationBar,
        showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/navigation_back_button.dart';
import '../../../core/widgets/surface_card.dart';
import 'settings_cubit.dart';
import 'settings_state.dart';

/// Privacy, the user's data, and what's in the app, as one short iOS-style
/// grouped list. Opened from the gear on the home screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.version, this.privacyPolicy, super.key});

  /// The app's version as shown, such as "1.0.0 (1)".
  final String version;

  /// Null until the policy is published, which leaves its row out.
  final Uri? privacyPolicy;

  void _onStateChanged(BuildContext context, SettingsState state) {
    if (state.deletion == DataDeletion.done) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            previous.deletion != current.deletion,
        listener: _onStateChanged,
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                leading: const NavigationBackButton(),
                automaticallyImplyLeading: false,
                largeTitle: const Text('Settings'),
                // The small title appears only once the large one has
                // scrolled away.
                middle: const Text('Settings'),
                alwaysShowMiddle: false,
                backgroundColor: context.colors.bgPrimary,
                border: null,
                transitionBetweenRoutes: false,
              ),
              SliverSafeArea(
                top: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _PrivacySection(
                        privacyPolicy: privacyPolicy,
                        couldNotOpenLink: state.couldNotOpenLink,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      _DataSection(state: state),
                      const SizedBox(height: AppSpacing.xxl),
                      _AboutSection(version: version),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Made by Nini Kurshavishvili',
                        textAlign: TextAlign.center,
                        style: context.textStyles.footnote.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.privacyPolicy,
    required this.couldNotOpenLink,
  });

  final Uri? privacyPolicy;
  final bool couldNotOpenLink;

  @override
  Widget build(BuildContext context) {
    final privacyPolicy = this.privacyPolicy;

    return _Section(
      title: 'Privacy',
      footer: couldNotOpenLink
          ? const _Footer(
              text: "Couldn't open the privacy policy. Try again.",
              isError: true,
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          // Device backups made by iOS include app data, so the wording
          // promises only what GymGrid itself does.
          child: Text(
            'GymGrid keeps your check-ins and photos on this device. '
            "There's no account and no server, so nothing is sent anywhere.",
            style: context.textStyles.body.copyWith(
              color: context.colors.textBody,
            ),
          ),
        ),
        if (privacyPolicy != null)
          _Row(
            label: 'Privacy policy',
            showsDisclosure: true,
            onTap: () => unawaited(
              context.read<SettingsCubit>().openLink(privacyPolicy),
            ),
          ),
      ],
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection({required this.state});

  final SettingsState state;

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'Every check-in and photo will be removed from this device. '
          "This can't be undone.",
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await cubit.deleteAllData();
  }

  @override
  Widget build(BuildContext context) {
    final footer = switch (state.deletion) {
      DataDeletion.notStarted || DataDeletion.inProgress => const _Footer(
        text:
            'Removes every check-in and photo from this device. This '
            "can't be undone.",
      ),
      DataDeletion.done => const _Footer(
        text: 'All check-ins and photos have been deleted.',
        announces: true,
      ),
      DataDeletion.failed => const _Footer(
        text: "Some data couldn't be deleted. Try again.",
        isError: true,
        announces: true,
      ),
    };

    return _Section(
      title: 'Your data',
      footer: footer,
      children: [
        _Row(
          icon: CupertinoIcons.trash,
          label: 'Delete all data',
          color: context.colors.dangerRed,
          isLoading: state.isDeleting,
          onTap: state.isDeleting
              ? null
              : () => unawaited(_confirmDeleteAll(context)),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'About',
      children: [
        _Row(label: 'Version', value: version),
        _Row(
          label: 'Licenses',
          showsDisclosure: true,
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'GymGrid',
            applicationVersion: version,
          ),
        ),
      ],
    );
  }
}

/// A heading, its rows in one grouped card, and an optional note under it,
/// like a section of an iOS inset grouped list.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(
            title,
            style: context.textStyles.bodyStrong.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const Divider(indent: AppSpacing.lg),
                child,
              ],
            ],
          ),
        ),
        ?footer,
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.text,
    this.isError = false,
    this.announces = false,
  });

  final String text;
  final bool isError;

  /// Whether VoiceOver reads it out as soon as it appears, for news such as
  /// the data having been deleted.
  final bool announces;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      container: true,
      liveRegion: announces,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text(
          text,
          style: context.textStyles.footnote.copyWith(
            color: isError ? colors.dangerRed : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One row of a grouped list: an action, a link, or a label with a value.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.icon,
    this.color,
    this.value,
    this.showsDisclosure = false,
    this.isLoading = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;

  /// The label's colour, and the icon's. Defaults to the body text colour.
  final Color? color;

  /// Shown after the label, as in "Version 1.0.0 (1)".
  final String? value;

  /// Whether to show the iOS chevron, for rows that open something.
  final bool showsDisclosure;

  /// Shows a spinner in place of [icon] while the action runs.
  final bool isLoading;

  /// Null for a row that only shows something, or an action that's busy.
  final VoidCallback? onTap;

  /// Apple's minimum tap target.
  static const double _minHeight = 44;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;
    final textScaler = MediaQuery.textScalerOf(context);
    final color = this.color ?? colors.textBody;
    final icon = this.icon;
    final value = this.value;
    final iconSize = textScaler.scale(18);

    final labelText = Text(label, style: text.body.copyWith(color: color));
    final valueText = value == null
        ? null
        : Text(value, style: text.body.copyWith(color: colors.textSecondary));
    // At accessibility sizes the value moves under the label, as in the
    // Settings app, so neither has to break mid-word.
    final Widget labelAndValue = valueText == null
        ? labelText
        : context.usesAccessibilityTextSize
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelText, valueText],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: AppSpacing.sm,
            children: [
              Flexible(child: labelText),
              valueText,
            ],
          );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          spacing: AppSpacing.md,
          children: [
            if (isLoading)
              SizedBox.square(
                dimension: iconSize,
                child: const CupertinoActivityIndicator(),
              )
            else if (icon != null)
              Icon(icon, size: iconSize, color: color),
            Expanded(child: labelAndValue),
            if (showsDisclosure)
              Icon(
                CupertinoIcons.chevron_forward,
                size: textScaler.scale(14),
                color: colors.textMuted,
              ),
          ],
        ),
      ),
    );

    final isButton = onTap != null || isLoading;
    return Semantics(
      // Its own node, rather than merged into the card or its neighbours.
      container: true,
      button: isButton,
      enabled: isButton ? onTap != null : null,
      label: value == null ? label : '$label, $value',
      // Excluding the children also drops the InkWell's tap action, so the
      // node declares it again, to stay usable with VoiceOver.
      onTap: onTap,
      excludeSemantics: true,
      child: onTap == null ? row : InkWell(onTap: onTap, child: row),
    );
  }
}
