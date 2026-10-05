import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'app/font_licenses.dart';
import 'app/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  configureDependencies();
  runApp(GymGridApp(router: createRouter()));
}
