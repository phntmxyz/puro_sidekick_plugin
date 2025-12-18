import 'dart:io';

import 'package:puro_sidekick_plugin/src/install_puro.dart';
import 'package:test/test.dart';

void main() {
  group('getLatestPuroVersion', () {
    late Directory tempDir;
    late File cacheFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('puro_test_');
      cacheFile = File('${tempDir.path}/puro_latest_version.txt');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('parses valid GitHub releases response', () {
      const validResponse = '''
[
  {
    "tag_name": "1.5.0",
    "name": "1.5.0",
    "draft": false,
    "prerelease": false
  }
]
''';
      final version = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: () => validResponse,
      );
      expect(version, '1.5.0');
    });

    test('parses response with multiple releases (takes first)', () {
      const multipleReleases = '''
[
  {"tag_name": "2.0.0"},
  {"tag_name": "1.5.0"},
  {"tag_name": "1.4.0"}
]
''';
      final version = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: () => multipleReleases,
      );
      expect(version, '2.0.0');
    });

    test('returns fallback for rate limit error response (Map instead of List)',
        () {
      const rateLimitResponse = '''
{
  "message": "API rate limit exceeded for 192.168.1.1.",
  "documentation_url": "https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"
}
''';
      final version = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: () => rateLimitResponse,
      );
      expect(version, puroFallbackVersion);
    });

    test('returns fallback for empty array response', () {
      const emptyArray = '[]';
      final version = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: () => emptyArray,
      );
      expect(version, puroFallbackVersion);
    });

    test('returns fallback for invalid JSON', () {
      const invalidJson = 'not valid json';
      final version = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: () => invalidJson,
      );
      expect(version, puroFallbackVersion);
    });

    test('returns fallback for missing tag_name field', () {
      const missingTagName = '''
[
  {
    "name": "1.5.0",
    "draft": false
  }
]
''';
      final version = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: () => missingTagName,
      );
      expect(version, puroFallbackVersion);
    });

    test('returns fallback for null tag_name', () {
      const nullTagName = '''
[
  {
    "tag_name": null,
    "name": "1.5.0"
  }
]
''';
      final version = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: () => nullTagName,
      );
      expect(version, puroFallbackVersion);
    });

    test('returns fallback when provider throws', () {
      final version = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: () => throw Exception('Network error'),
      );
      expect(version, puroFallbackVersion);
    });

    test('handles HTML error page response', () {
      const htmlResponse = '''
<!DOCTYPE html>
<html>
<head><title>503 Service Unavailable</title></head>
<body>Service Unavailable</body>
</html>
''';
      final version = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: () => htmlResponse,
      );
      expect(version, puroFallbackVersion);
    });

    test('caches result to file and returns cached version on subsequent calls',
        () {
      var callCount = 0;
      String provider() {
        callCount++;
        return '[{"tag_name": "1.5.0"}]';
      }

      // First call - fetches and caches
      final version1 = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: provider,
      );
      expect(version1, '1.5.0');
      expect(callCount, 1);
      expect(cacheFile.existsSync(), isTrue);
      expect(cacheFile.readAsStringSync(), '1.5.0');

      // Second call - should use cache, provider not called
      final version2 = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: provider,
      );
      expect(version2, '1.5.0');
      expect(callCount, 1); // Still 1, provider wasn't called
    });

    test('clearing cache by deleting file forces new fetch', () {
      var callCount = 0;
      String provider() {
        callCount++;
        return '[{"tag_name": "1.${callCount}.0"}]';
      }

      // First call
      final version1 = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: provider,
      );
      expect(version1, '1.1.0');
      expect(callCount, 1);

      // Delete cache file
      cacheFile.deleteSync();

      // Second call - should fetch again
      final version2 = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: provider,
      );
      expect(version2, '1.2.0');
      expect(callCount, 2);
    });

    test('expired cache (older than 24h) triggers new fetch', () {
      var callCount = 0;
      String provider() {
        callCount++;
        return '[{"tag_name": "1.${callCount}.0"}]';
      }

      // First call - creates cache
      final version1 = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: provider,
      );
      expect(version1, '1.1.0');
      expect(callCount, 1);

      // Simulate expired cache by setting last modified to 25 hours ago
      final expiredTime = DateTime.now().subtract(const Duration(hours: 25));
      cacheFile.setLastModifiedSync(expiredTime);

      // Second call - should fetch again because cache expired
      final version2 = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: provider,
      );
      expect(version2, '1.2.0');
      expect(callCount, 2);
    });

    test('valid cache (less than 24h old) does not trigger fetch', () {
      var callCount = 0;
      String provider() {
        callCount++;
        return '[{"tag_name": "1.${callCount}.0"}]';
      }

      // First call - creates cache
      final version1 = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: provider,
      );
      expect(version1, '1.1.0');
      expect(callCount, 1);

      // Simulate cache that's 23 hours old (still valid)
      final validTime = DateTime.now().subtract(const Duration(hours: 23));
      cacheFile.setLastModifiedSync(validTime);

      // Second call - should use cache
      final version2 = getLatestPuroVersion(
        cacheFile: cacheFile,
        githubReleasesProvider: provider,
      );
      expect(version2, '1.1.0');
      expect(callCount, 1); // Still 1, provider wasn't called
    });
  });
}
