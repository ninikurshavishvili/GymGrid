import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/app/theme/app_text_styles.dart';

/// Runs once before every test file in this directory tree.
///
/// Loads a stand-in for the system font so widget tests measure text about
/// the way the app renders it. San Francisco isn't available to tests, and
/// without this they use a placeholder font whose glyphs are all a full em
/// wide, which makes layout and overflow checks inaccurate. Inter is drawn
/// to similar proportions, and runs slightly wider, which errs on the safe
/// side for overflow checks.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadStandInFont();
  await testMain();
}

Future<void> _loadStandInFont() async {
  final fontFiles = Directory(
    'test/fonts',
  ).listSync().whereType<File>().where((file) => file.path.endsWith('.ttf'));

  for (final family in [AppFonts.text, AppFonts.display]) {
    final loader = FontLoader(family);
    for (final file in fontFiles) {
      loader.addFont(file.readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
}
