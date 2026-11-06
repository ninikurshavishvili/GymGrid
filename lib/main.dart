import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'app/router.dart';

Future<void> main() async {
  // Platform plugins, such as path_provider, need the binding before
  // `runApp`.
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(GymGridApp(router: createRouter()));
}
