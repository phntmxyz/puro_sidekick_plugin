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
  String getMaxFlutterSdkVersionFromPubspec() {
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

      // Get flutter version if available
      final flutterConstraint = environment?['flutter'] as String?;

      // Get dart sdk version if flutter version is not available
      final dartConstraint = environment?['sdk'] as String?;

      final availableVersions = _parseAvailableVersions();

      if (flutterConstraint != null) {
        final flutterVersion = VersionConstraint.parse(flutterConstraint);
        print('Found flutter version constraint: $flutterVersion');
        for (final version in availableVersions.values) {
          if (flutterVersion.allows(version)) {
            return version.toString();
          }
        }
      } else if (dartConstraint != null) {
        final dartVersion = VersionConstraint.parse(dartConstraint);
        print('Found dart version constraint: $dartVersion');
        for (final version in availableVersions.keys) {
          if (dartVersion.allows(version)) {
            return availableVersions[version].toString();
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
  List<String> _provideAvailableVersions() {
    final lines = <String>[];

    if (puroLsVersionsProvider != null) {
      lines.addAll(puroLsVersionsProvider!().split('\n'));
    } else {
      try {
        // List all available flutter and dart versions
        puro(
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
  Map<Version, Version> _parseAvailableVersions() {
    // Map off dart version to flutter version
    final versionMap = <Version, Version>{};
    final betaVersionMap = <Version, Version>{};

    bool isBetaRelease = false;

    // puro stdout lines
    final lines = _provideAvailableVersions();

    // Parse the version list
    for (final line in lines) {
      if (line.contains('beta')) {
        isBetaRelease = true;
      }

      final parts = line.split('|');
      if (parts.length >= 3) {
        try {
          final flutterVersion =
              Version.parse(parts[0].replaceAll('Flutter', '').trim());
          final listedDartVersion =
              Version.parse(parts[3].replaceAll('Dart', '').trim());

          // Only add the latest version for each dart version
          if (isBetaRelease) {
            betaVersionMap[listedDartVersion] = flutterVersion;
          } else {
            versionMap[listedDartVersion] = flutterVersion;
          }
        } catch (_) {}
      }
    }

    final SplayTreeMap<Version, Version> sortedVersions;
    if (useBeta) {
      sortedVersions = SplayTreeMap<Version, Version>.from(
        betaVersionMap,
        (key1, key2) => betaVersionMap[key1]!.compareTo(betaVersionMap[key2]!),
      );
    } else {
      sortedVersions = SplayTreeMap<Version, Version>.from(
        versionMap,
        (key1, key2) => versionMap[key1]!.compareTo(versionMap[key2]!),
      );
    }

    return sortedVersions;
  }

  String? _getBestFlutterVersion(
    Map<Version, Version> versions,
    String? dartConstraint,
    String? flutterConstraint,
  ) {
    final availableVersions = _parseAvailableVersions();

    if (flutterConstraint != null) {
      final flutterVersion = VersionConstraint.parse(flutterConstraint);
      for (final version in availableVersions.values) {
        if (flutterVersion.allows(version)) {
          return version.toString();
        }
      }
    } else if (dartConstraint != null) {
      final dartVersion = VersionConstraint.parse(dartConstraint);
      for (final version in versions.keys) {
        if (dartVersion.allows(version)) {
          return versions[version].toString();
        }
      }
    }
    return null;
  }

  /// Test method to get the best flutter version for the given dart and flutter constraints
  String? testGetBestFlutterVersion({
    String? dartConstraint,
    String? flutterConstraint,
  }) {
    final availableVersions = _parseAvailableVersions();
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
