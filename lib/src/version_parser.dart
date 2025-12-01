import 'dart:collection';

import 'package:pub_semver/pub_semver.dart';
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart' hide Version;
import 'package:yaml/yaml.dart';

/// `VersionParser` is a class that helps in parsing Flutter and Dart versions.
///
/// It takes in a `packagePath` which is the directory of the package,
/// a `useBeta` flag to determine if beta versions should be used.
/// The `puroLsVersionsProvider` function that provides the versions. It is only used for testing.
class VersionParser {
  VersionParser({
    required this.packagePath,
    this.projectRoot,
    this.useBeta = false,
    this.puroLsVersionsProvider,
  });

  final Directory packagePath;
  final Directory? projectRoot;
  final bool useBeta;
  final String Function()? puroLsVersionsProvider;

  /// Reads the maximum flutter version from pubspec.yaml if available
  /// If the flutter version is not available, it reads the dart sdk version
  /// and returns the flutter version of the upper bound dart version constraint
  /// Returns null if the version is not found
  Future<FlutterSdkVersions> getMaxFlutterSdkVersionFromPubspec() async {
    try {
      YamlMap? pubspec = _readPubspecFile(packagePath);
      if (pubspec == null) {
        throw VersionParserException(
          msg: 'No pubspec.yaml found in the package directory: $packagePath',
        );
      }

      // Check if the package is part of a workspace
      final isInWorkspace = (pubspec['resolution'] as String?) == 'workspace';
      if (isInWorkspace &&
          projectRoot != null &&
          projectRoot!.existsSync() &&
          projectRoot!.absolute.path != packagePath.absolute.path) {
        print(
          'Package is part of a workspace. Use the root package pubspec.yaml to get the flutter version.',
        );
        final newPubspec = _readPubspecFile(projectRoot!);
        if (newPubspec != null) {
          pubspec = newPubspec;
        }
      }

      // Check for environment
      final environment = pubspec['environment'] as YamlMap?;

      // Check for sidekick.puro configuration (preferred SDK versions)
      final sidekick = pubspec['sidekick'] as YamlMap?;
      final puroConfig = sidekick?['puro'] as YamlMap?;

      // Get useFlutterSdk version if available (highest priority override)
      // Must be an exact version, not a range
      final useFlutterSdk = puroConfig?['useFlutterSdk'] as String?;
      if (useFlutterSdk != null) {
        _validateExactVersion(useFlutterSdk, 'useFlutterSdk');
      }

      // Get flutter version if available
      final flutterConstraint = environment?['flutter'] as String?;

      // Get useDartSdk version if available (overrides sdk)
      // Must be an exact version, not a range
      final useDartSdk = puroConfig?['useDartSdk'] as String?;
      if (useDartSdk != null) {
        _validateExactVersion(useDartSdk, 'useDartSdk');
      }

      // Get dart sdk version if flutter version is not available
      final dartConstraint = environment?['sdk'] as String?;

      /// Dart Version => Flutter Version
      final availableVersions = await _parseAvailableVersions();

      // useFlutterSdk takes priority over flutter and sdk constraints
      // useDartSdk takes priority over sdk constraint
      // This is useful for packages that support multiple versions but want
      // to use a specific version for linting and formatting as default
      final effectiveFlutterConstraint = useFlutterSdk ?? flutterConstraint;
      final effectiveDartConstraint = useDartSdk ?? dartConstraint;

      if (effectiveFlutterConstraint != null) {
        final flutterVersion =
            VersionConstraint.parse(effectiveFlutterConstraint);
        if (useFlutterSdk != null) {
          printVerbose(
            'Found useFlutterSdk version: $flutterVersion (overrides flutter/sdk)',
          );
        } else {
          printVerbose('Found flutter version constraint: $flutterVersion');
        }
        for (final entry in availableVersions.entries) {
          final fVersions = entry.value;
          final dVersion = entry.key;
          for (final fVersion in fVersions) {
            if (flutterVersion.allows(fVersion)) {
              // Due to sorting, picking the first returns the latest matching
              return FlutterSdkVersions(
                dartVersion: dVersion,
                flutterVersion: fVersion,
              );
            }
          }
        }
      } else if (effectiveDartConstraint != null) {
        final dartVersion = VersionConstraint.parse(effectiveDartConstraint);
        if (useDartSdk != null) {
          printVerbose(
            'Found useDartSdk version: $dartVersion (overrides sdk)',
          );
        } else {
          printVerbose('Found dart version constraint: $dartVersion');
        }
        for (final entry in availableVersions.entries) {
          final fVersions = entry.value;
          final dVersion = entry.key;
          for (final fVersion in fVersions) {
            if (dartVersion.allows(dVersion)) {
              // Due to sorting, picking the first returns the latest matching
              return FlutterSdkVersions(
                dartVersion: dVersion,
                flutterVersion: fVersion,
              );
            }
          }
        }
      }
      throw VersionParserException(
        msg:
            'No valid flutter or dart version constraint found in pubspec.yaml',
      );
    } on FileSystemException catch (e) {
      throw VersionParserException(
        msg: 'Error reading pubspec.yaml',
        innerException: e,
      );
    } on YamlException catch (e) {
      throw VersionParserException(
        msg: 'Error parsing pubspec.yaml',
        innerException: e,
      );
    } catch (e) {
      throw VersionParserException(
        msg: 'Unexpected error: $e',
      );
    }
  }

  /// Provides the available versions from puro ls-versions command
  /// If the `puroLsVersionsProvider` is provided, it uses that to get the versions
  /// Returns all stdout lines from the command as a list
  Future<List<String>> _provideAvailableVersions() async {
    final lines = <String>[];

    if (puroLsVersionsProvider != null) {
      lines.addAll(puroLsVersionsProvider!().split('\n'));
    } else {
      try {
        // List all available flutter and dart versions
        await puro(
          ['ls-versions', '--full'],
          progress: Progress((line) {
            if (line.trim().isNotEmpty) lines.add(line);
          }),
        );
      } catch (e) {
        print('Error getting flutter versions: $e');
      }
    }
    return lines;
  }

  /// Validates that the given version string is an exact version, not a range.
  /// Throws [VersionParserException] if the version is a range.
  void _validateExactVersion(String version, String fieldName) {
    final constraint = VersionConstraint.parse(version);
    if (constraint is! Version) {
      throw VersionParserException(
        msg:
            '$fieldName must be an exact version (e.g., "3.22.1"), not a range. Got: "$version"',
      );
    }
  }

  YamlMap? _readPubspecFile(Directory packagePath) {
    try {
      final normalizedDir = Directory(normalize(packagePath.path));
      final pubspecFile = normalizedDir.file('pubspec.yaml');
      if (!pubspecFile.existsSync()) {
        print('pubspec.yaml not found in the package directory');
        return null;
      }
      final pubspecYamlContent = pubspecFile.readAsStringSync();

      // Check for valid package name
      final doc = loadYamlDocument(pubspecYamlContent);
      final pubspec = doc.contents.value as YamlMap;
      final packageName = pubspec['name'] as String?;
      if (packageName != null) {
        return pubspec;
      }
    } catch (_) {}
    return null;
  }

  /// Parses the available versions from the `puro ls-versions` command
  /// Returns a map of dart version to flutter version
  Future<Map<Version, List<Version>>> _parseAvailableVersions() async {
    final versionMap = <Version, List<Version>>{};

    // puro stdout lines
    final lines = await _provideAvailableVersions();

    // Parse the version list
    for (final line in lines) {
      if (line.contains('beta') && useBeta) {
        continue; // Skip beta versions if not requested
      }

      final parts = line.split('|');
      if (parts.length >= 3) {
        try {
          final flutterVersion =
              Version.parse(parts[0].replaceAll('Flutter', '').trim());
          final listedDartVersion =
              Version.parse(parts[3].replaceAll('Dart', '').trim());

          final List<Version> existing = versionMap[listedDartVersion] ?? [];
          existing.add(flutterVersion);
          versionMap[listedDartVersion] = existing;
        } catch (_) {
          // ignore
        }
      }
    }

    final SplayTreeMap<Version, List<Version>> sortedVersions =
        SplayTreeMap<Version, List<Version>>.from(
      versionMap,
      (key1, key2) => key1.compareTo(key2),
    );

    return sortedVersions;
  }

  Future<String?> _getBestFlutterVersion(
    Map<Version, List<Version>> versions,
    String? dartConstraint,
    String? flutterConstraint,
  ) async {
    // key Dart version, value List<Flutter version>
    final availableVersions = await _parseAvailableVersions();

    if (flutterConstraint != null) {
      final flutterVersion = VersionConstraint.parse(flutterConstraint);
      for (final List<Version> versions in availableVersions.values) {
        for (final Version version in versions) {
          if (flutterVersion.allows(version)) {
            return version.toString();
          }
        }
      }
    } else if (dartConstraint != null) {
      final dartVersion = VersionConstraint.parse(dartConstraint);
      for (final version in versions.keys) {
        if (dartVersion.allows(version)) {
          final List<Version> flutterVersions = versions[version]!;
          return flutterVersions.first.toString();
        }
      }
    }
    return null;
  }

  /// Test method to get the best flutter version for the given dart and flutter constraints
  Future<String?> testGetBestFlutterVersion({
    String? dartConstraint,
    String? flutterConstraint,
  }) async {
    final availableVersions = await _parseAvailableVersions();
    return _getBestFlutterVersion(
      availableVersions,
      dartConstraint,
      flutterConstraint,
    );
  }
}

class VersionParserException implements Exception {
  VersionParserException({
    this.msg,
    this.innerException,
  });

  String? msg;
  Exception? innerException;

  @override
  String toString() {
    return 'Error parsing SDK versions: $msg ${innerException != null ? '\n$innerException' : ''}';
  }
}

class FlutterSdkVersions {
  FlutterSdkVersions({
    required this.dartVersion,
    required this.flutterVersion,
  });

  factory FlutterSdkVersions.fromString(String flutter, String dart) {
    return FlutterSdkVersions(
      dartVersion: Version.parse(dart),
      flutterVersion: Version.parse(flutter),
    );
  }

  final Version dartVersion;
  final Version flutterVersion;

  @override
  String toString() {
    return 'FlutterSdkVersions(dartVersion: $dartVersion, flutterVersion: $flutterVersion)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlutterSdkVersions &&
          runtimeType == other.runtimeType &&
          dartVersion == other.dartVersion &&
          flutterVersion == other.flutterVersion;

  @override
  int get hashCode => Object.hash(dartVersion, flutterVersion);
}
