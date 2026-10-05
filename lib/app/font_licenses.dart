import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled fonts' SIL Open Font Licences to Flutter's licence
/// registry, which the OFL requires and which `showLicensePage` displays.
///
/// Package licences are collected automatically; bundled asset fonts are not.
void registerFontLicenses() {
  Future<LicenseEntry> load(String font, String path) async {
    final text = await rootBundle.loadString(path);
    return LicenseEntryWithLineBreaks([font], text);
  }

  LicenseRegistry.addLicense(() async* {
    yield await load('Inter', 'assets/fonts/inter/OFL.txt');
    yield await load('JetBrains Mono', 'assets/fonts/jetbrains_mono/OFL.txt');
  });
}
