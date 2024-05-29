import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:puro_sidekick_plugin/src/semantic_version.dart';
import 'package:sidekick_core/sidekick_core.dart';
import 'package:yaml/yaml.dart';

/// `VersionParser` is a class that helps in parsing Flutter and Dart versions.
///
/// It takes in a `packagePath` which is the directory of the package,
/// a `useBeta` flag to determine if beta versions should be used.
/// The `puroLsVersionsProvider` function that provides the versions. It is only used for testing.
class VersionParser {
  VersionParser({
    required this.packagePath,
    this.useBeta = false,
    this.puroLsVersionsProvider,
  });

  final Directory packagePath;
  bool useBeta;
  String Function()? puroLsVersionsProvider;

  /// Reads the minimum flutter version from pubspec.yaml if available
  /// If the flutter version is not available, it reads the dart sdk version
  /// and returns the flutter version of the lower bound of the dart version constraint
  /// Returns null if the version is not found
  String? getMinSdkVersionFromPubspec() {
    try {
      final package = DartPackage.fromDirectory(packagePath);
      final pubspecFile = package?.pubspec;
      if (pubspecFile == null || !pubspecFile.existsSync()) {
        return null;
      }
      final pubspecYamlContent = pubspecFile.readAsStringSync();

      // Check for valid package name
      final doc = loadYamlDocument(pubspecYamlContent);
      final pubspec = doc.contents.value as YamlMap;
      final packageName = pubspec['name'] as String?;
      if (packageName == null) {
        return null;
      }

      // Check for environment
      final environment = pubspec['environment'] as YamlMap?;

      // Get flutter version if available
      final flutterConstraint = environment?['flutter'] as String?;
      if (flutterConstraint != null) {
        try {
          // Get version by Caret syntax
          final lowerFlutterBound = flutterConstraint.split('^')[1];
          return lowerFlutterBound;
        } catch (_) {}
      }

      // Get dart sdk version if flutter version is not available
      final dartConstraint = environment?['sdk'] as String?;
      String? lowerDartBound;
      try {
        lowerDartBound = dartConstraint?.split('>=')[1].split('<')[0];
      } catch (_) {}

      try {
        // Get version by Caret syntax
        lowerDartBound ??= dartConstraint?.split('^')[1];
      } catch (_) {}

      if (lowerDartBound == null) {
        return null;
      }

      return _getBestFlutterVersion(lowerDartBound);
    } on FileSystemException catch (e) {
      print('Error reading pubspec.yaml: $e');
      return '';
    } on YamlException catch (e) {
      print('Error parsing pubspec.yaml: $e');
      return '';
    } catch (e) {
      print('Unexpected error: $e');
      return '';
    }
  }

  String _getBestFlutterVersion(String dartVersion) {
    if (puroLsVersionsProvider != null) {
      final puroLsVersions = puroLsVersionsProvider!();
      return _parseFlutterVersionToDartVersion(puroLsVersions, dartVersion);
    }

    final lines = <String>[];

    try {
      // List all available flutter and dart versions
      puro(
        ['ls-versions'],
        progress: Progress((line) {
          if (line.isNotEmpty) lines.add(line);
        }),
      );
    } catch (e) {
      print('Error getting flutter versions: $e');
    }

    final allVersions = lines.join('\n');
    return _parseFlutterVersionToDartVersion(allVersions, dartVersion);
  }

  String testParseFlutterVersionToDartVersion(String dartVersion) {
    if (puroLsVersionsProvider == null) {
      throw Exception('puroLsVersionsProvider is not set');
    }
    return _parseFlutterVersionToDartVersion(puroLsVersionsProvider!(), dartVersion);
  }

  String _parseFlutterVersionToDartVersion(String versions, String dartVersion) {
    final semanticDartVersion = SemanticVersion.fromString(dartVersion);

    final lines = versions.split('\n');

    // Map off dart version to flutter version
    final versionMap = <SemanticVersion, SemanticVersion>{};
    final betaVersionMap = <SemanticVersion, SemanticVersion>{};

    bool isBetaRelease = false;

    // Parse the version list
    for (final line in lines) {
      if (line.contains('beta')) {
        isBetaRelease = true;
      }

      final parts = line.split('|');
      if (parts.length >= 3) {
        final flutterVersion = SemanticVersion.fromString(parts[0].replaceAll('Flutter', '').trim());
        final listedDartVersion = SemanticVersion.fromString(parts[3].replaceAll('Dart', '').trim());

        // Only add the latest version for each dart version
        if (isBetaRelease) {
          if (!betaVersionMap.containsKey(listedDartVersion)) {
            betaVersionMap[listedDartVersion] = flutterVersion;
          }
        } else {
          if (!versionMap.containsKey(listedDartVersion)) {
            versionMap[listedDartVersion] = flutterVersion;
          }
        }
      }
    }

    if (useBeta) {
      final bestDartVersion = getBestMatchingVersion(betaVersionMap.keys.toList(), semanticDartVersion);
      return betaVersionMap[bestDartVersion].toString();
    } else {
      final bestDartVersion = getBestMatchingVersion(versionMap.keys.toList(), semanticDartVersion);
      return versionMap[bestDartVersion].toString();
    }
  }
}
