import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Checks the dependency rules between layers by reading import directives.
///
/// The analyzer can't express these rules within one package. Splitting the
/// domain into its own pure-Dart package would let pub enforce them, as a
/// separate Swift package target does; for an app this size, one package
/// and this test are simpler.
void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => p.normalize(file.path))
      .where((path) => path.endsWith('.dart'))
      .toList();

  test('domain code depends only on Dart, equatable and pure core code', () {
    final pureFiles = libFiles.where(_isPure).toList();
    expect(pureFiles, isNotEmpty, reason: 'no domain files found');

    final violations = [
      for (final file in pureFiles)
        for (final uri in _importsOf(file))
          if (!_pureFileMayImport(file, uri)) '$file imports $uri',
    ];

    expect(violations, isEmpty);
  });

  test('presentation never imports the data layer', () {
    final violations = [
      for (final file in libFiles.where((f) => _isLayer(f, 'presentation')))
        for (final uri in _importsOf(file))
          if (_resolveInPackage(file, uri) case final target?
              when _isLayer(target, 'data'))
            '$file imports $uri',
    ];

    expect(violations, isEmpty);
  });
}

/// Core Dart libraries with no I/O and no Flutter.
const _pureDartLibraries = {
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:core',
  'dart:math',
  'dart:typed_data',
};

/// Parts of `core` that domain code may use.
const _pureCoreDirectories = ['lib/core/date', 'lib/core/errors'];

bool _isPure(String path) =>
    _isLayer(path, 'domain') ||
    _pureCoreDirectories.any((dir) => p.isWithin(dir, path));

bool _pureFileMayImport(String file, String uri) {
  if (_pureDartLibraries.contains(uri)) return true;
  if (uri.startsWith('package:equatable/')) return true;
  final target = _resolveInPackage(file, uri);
  return target != null && _isPure(target);
}

/// Whether [path] is in [layer] of a feature, e.g.
/// `lib/features/check_in/domain/...` for `domain`.
bool _isLayer(String path, String layer) {
  final parts = p.split(path);
  return parts.length > 4 &&
      parts[0] == 'lib' &&
      parts[1] == 'features' &&
      parts[3] == layer;
}

final _directive = RegExp(r"^(?:import|export) '([^']+)'", multiLine: true);

List<String> _importsOf(String path) => [
  for (final match in _directive.allMatches(File(path).readAsStringSync()))
    match[1]!,
];

/// The file under `lib/` that [uri], imported from [fromFile], refers to,
/// or null if it's outside this package.
String? _resolveInPackage(String fromFile, String uri) {
  const self = 'package:gym_grid/';
  if (uri.startsWith(self)) return p.join('lib', uri.substring(self.length));
  if (uri.contains(':')) return null;
  return p.normalize(p.join(p.dirname(fromFile), uri));
}
