import 'package:flutter/material.dart';

import 'app/startup.dart';

Future<void> main() async {
  // Platform plugins, such as path_provider, need the binding before
  // `runApp`.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await buildApp());
}
