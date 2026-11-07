import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoButton, CupertinoIcons;
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Stands in for Flutter's own Cupertino back button, whose tappable part
/// has no label and whose label can't be tapped. VoiceOver gets one control
/// here, named and usable.
class NavigationBackButton extends StatelessWidget {
  const NavigationBackButton({super.key});

  void _goBack(BuildContext context) {
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Back',
      onTap: () => _goBack(context),
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _goBack(context),
        child: Icon(CupertinoIcons.back, color: context.colors.actionGreen),
      ),
    );
  }
}
