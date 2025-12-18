import 'package:puro_sidekick_plugin/src/install_puro.dart';
import 'package:test/test.dart';

void main() {
  group('getLatestPuroVersion', () {
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
        githubReleasesProvider: () => multipleReleases,
      );
      expect(version, '2.0.0');
    });

    test('returns fallback for rate limit error response (Map instead of List)', () {
      const rateLimitResponse = '''
{
  "message": "API rate limit exceeded for 192.168.1.1.",
  "documentation_url": "https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"
}
''';
      final version = getLatestPuroVersion(
        githubReleasesProvider: () => rateLimitResponse,
      );
      expect(version, puroFallbackVersion);
    });

    test('returns fallback for empty array response', () {
      const emptyArray = '[]';
      final version = getLatestPuroVersion(
        githubReleasesProvider: () => emptyArray,
      );
      expect(version, puroFallbackVersion);
    });

    test('returns fallback for invalid JSON', () {
      const invalidJson = 'not valid json';
      final version = getLatestPuroVersion(
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
        githubReleasesProvider: () => nullTagName,
      );
      expect(version, puroFallbackVersion);
    });

    test('returns fallback when provider returns null', () {
      final version = getLatestPuroVersion(
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
        githubReleasesProvider: () => htmlResponse,
      );
      expect(version, puroFallbackVersion);
    });
  });
}
