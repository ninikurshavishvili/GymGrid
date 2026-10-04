import 'package:get_it/get_it.dart';

/// The app's service locator, the composition root for dependencies.
///
/// Only the `app` layer touches [getIt]. Screens receive their Cubits from
/// the router, and Cubits receive use cases through their constructors, so
/// features never depend on the container directly.
final GetIt getIt = GetIt.instance;

/// Registers all dependencies. Called once from `main` before `runApp`.
void configureDependencies() {
  // Database, photo storage, repositories and use cases are registered here
  // as each layer is implemented.
}
