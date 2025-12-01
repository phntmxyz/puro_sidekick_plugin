import 'dart:io';

import 'package:puro_sidekick_plugin/src/version_parser.dart';
import 'package:test/test.dart';

const String _puroLsVersions = '''
[i] Latest stable releases:
    Flutter 3.22.1          | 7d   | a14f74ff3a | Dart 3.4.1 
    Flutter 3.22.0          | 2w   | 5dcb86f68f | Dart 3.4.0 
    Flutter 3.19.6          | 1mo  | 54e66469a9 | Dart 3.3.4 
    Flutter 3.19.5          | 2mo  | 300451adae | Dart 3.3.3 
    Flutter 3.19.4          | 2mo  | 68bfaea224 | Dart 3.3.2 
    Flutter 3.16.9          | 4mo  | 41456452f2 | Dart 3.2.6 
    Flutter 3.13.9          | 7mo  | d211f42860 | Dart 3.1.5 
    Flutter 3.10.6          | 11mo | f468f3366c | Dart 3.0.6 
    Flutter 3.7.12          | 1y   | 4d9e56e694 | Dart 2.19.6
    Flutter 3.3.10          | 1y   | 135454af32 | Dart 2.18.6
    
    Latest beta releases:
    Flutter 3.22.0-0.3.pre  | 1mo  | 87b652410d | Dart 3.4.0 
    Flutter 3.22.0-0.2.pre  | 1mo  | 312b9e81e9 | Dart 3.4.0 
    Flutter 3.22.0-0.1.pre  | 2mo  | 29babcb32a | Dart 3.4.0 
    Flutter 3.21.0-0.0.pre  | 3mo  | c398442c35 | Dart 3.4.0 
    Flutter 3.20.0-1.2.pre  | 3mo  | 1751123cde | Dart 3.4.0 
    Flutter 3.19.0-0.4.pre  | 4mo  | b7e7d46a04 | Dart 3.3.0 
    Flutter 3.18.0-0.2.pre  | 5mo  | fed06b31d9 | Dart 3.3.0 
    Flutter 3.17.0-0.0.pre  | 6mo  | 12b47270b7 | Dart 3.3.0 
    Flutter 3.16.0-0.5.pre  | 7mo  | adc7dfe87e | Dart 3.2.0 
    Flutter 3.15.0-15.2.pre | 8mo  | 0d074ced6c | Dart 3.2.0
''';

void main() {
  test('get flutter version for exact matching dart version', () async {
    final parser = VersionParser(
      packagePath: Directory.current,
      puroLsVersionsProvider: () => _puroLsVersions,
    );
    expect(
      await parser.testGetBestFlutterVersion(dartConstraint: '3.4.1'),
      '3.22.1',
    );
    expect(
      await parser.testGetBestFlutterVersion(dartConstraint: '3.4.0'),
      '3.22.0',
    );
    expect(
      await parser.testGetBestFlutterVersion(dartConstraint: '3.2.6'),
      '3.16.9',
    );
    expect(
      await parser.testGetBestFlutterVersion(dartConstraint: '2.18.6'),
      '3.3.10',
    );

    final betaParser = VersionParser(
      packagePath: Directory.current,
      puroLsVersionsProvider: () => _puroLsVersions,
      useBeta: true,
    );
    expect(
      await betaParser.testGetBestFlutterVersion(dartConstraint: '3.3.0'),
      '3.19.0-0.4.pre', // only beta available
    );
    expect(
      await betaParser.testGetBestFlutterVersion(dartConstraint: '3.4.0'),
      '3.22.0', // stable wins
    );
  });

  test('get min flutter version for closest matching flutter version',
      () async {
    final parser = VersionParser(
      packagePath: Directory.current,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    // 3.16.9 is exact match
    expect(
      await parser.testGetBestFlutterVersion(flutterConstraint: '3.16.9'),
      '3.16.9',
    );

    // ^3.2.0 which is min Flutter 3.3.10
    expect(
      await parser.testGetBestFlutterVersion(flutterConstraint: '^3.7.0'),
      '3.7.12',
    );

    // >=3.0.0 <4.0.0 is min version 3.0.0 and max version <4 which is Flutter 3.3.10
    expect(
      await parser.testGetBestFlutterVersion(
          flutterConstraint: '>=3.0.0 <4.0.0'),
      '3.3.10',
    );

    // <4.0.0 is min Flutter 3.3.10
    expect(
      await parser.testGetBestFlutterVersion(flutterConstraint: '<4.0.0'),
      '3.3.10',
    );
  });

  test('get min flutter version for dart version constraint', () async {
    final parser = VersionParser(
      packagePath: Directory.current,
      puroLsVersionsProvider: () => _puroLsVersions,
    );
    // ^3.0.0 is max minor version = 3.4.1 which is Flutter 3.10.6
    expect(
      await parser.testGetBestFlutterVersion(dartConstraint: '^3.0.0'),
      '3.10.6',
    );

    // >=3.0.0 <4.0.0 is max version <4 =  3.4.1 which is Flutter 3.10.6
    expect(
      await parser.testGetBestFlutterVersion(dartConstraint: '>=3.0.0 <4.0.0'),
      '3.10.6',
    );

    // <3.4.0 is closest to 3.3.4 which is Flutter 3.3.10
    expect(
      await parser.testGetBestFlutterVersion(dartConstraint: '<3.4.0'),
      '3.3.10',
    );

    final betaParser = VersionParser(
      packagePath: Directory.current,
      puroLsVersionsProvider: () => _puroLsVersions,
      useBeta: true,
    );
    // ^3.3.0 is max minor version = 3.4.0 which is Flutter 3.22.0-0.3.pre
    expect(
      await betaParser.testGetBestFlutterVersion(dartConstraint: '^3.3.0'),
      '3.19.0-0.4.pre',
    );
  });

  test('return null when no matching version is available', () async {
    final parser = VersionParser(
      packagePath: Directory.current,
      puroLsVersionsProvider: () => _puroLsVersions,
    );
    expect(await parser.testGetBestFlutterVersion(dartConstraint: '>=4.0.0'),
        null);
  });

  test('get min flutter version for sdk based pubspec', () async {
    const pubspecYamlConstraint = '''
name: puro_sidekick_plugin

environment:
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYamlConstraint);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    // >=3.0.0 <4.0.0 which is min sdk 3.0.6 which is Flutter 3.10.6
    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.10.6', '3.0.6'),
    );
  });

  test('get min flutter version for caret sdk based pubspec', () async {
    const pubspecYamlCaretConstraint = '''
name: puro_sidekick_plugin

environment:
  sdk: '^3.0.0'
''';

    final tempDir = _createPubspec(pubspecYamlCaretConstraint);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    // ^3.0.0 is min sdk 3.0.6 which is Flutter 3.10.6
    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.10.6', '3.0.6'),
    );
  });

  test('get exact flutter version for flutter based pubspec', () async {
    const pubspecYamlFlutterConstraint = '''
name: puro_sidekick_plugin

environment:
  flutter: '^3.16.9'
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYamlFlutterConstraint);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.16.9', '3.2.6'),
    );
  });

  test('get max flutter version for flutter based pubspec', () async {
    const pubspecYamlFlutterConstraint = '''
name: puro_sidekick_plugin

environment:
  flutter: '>=3.0.0 <4.0.0'
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYamlFlutterConstraint);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.3.10', '2.18.6'),
    );
  });

  test('useFlutterSdk overrides both flutter and sdk constraints', () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

sidekick:
  puro:
    useFlutterSdk: '3.22.1'

environment:
  flutter: '>=3.0.0 <4.0.0'
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    // useFlutterSdk: 3.22.1 should be used instead of flutter or sdk constraints
    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.22.1', '3.4.1'),
    );
  });

  test('useFlutterSdk overrides sdk constraint when flutter is not present',
      () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

sidekick:
  puro:
    useFlutterSdk: '3.19.4'

environment:
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    // useFlutterSdk: 3.19.4 should be used instead of sdk constraint
    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.19.4', '3.3.2'),
    );
  });

  test('flutter constraint is used when useFlutterSdk is not present',
      () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

environment:
  flutter: '3.22.1'
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    // Should still work when useFlutterSdk is not present
    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.22.1', '3.4.1'),
    );
  });

  test('useDartSdk overrides sdk constraint', () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

sidekick:
  puro:
    useDartSdk: '3.4.1'

environment:
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    // useDartSdk: 3.4.1 should be used instead of sdk constraint
    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.22.1', '3.4.1'),
    );
  });

  test('useFlutterSdk takes priority over useDartSdk', () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

sidekick:
  puro:
    useFlutterSdk: '3.22.1'
    useDartSdk: '3.2.6'

environment:
  flutter: '>=3.0.0 <4.0.0'
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    // useFlutterSdk should take priority over useDartSdk
    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.22.1', '3.4.1'),
    );
  });

  test('sdk constraint is used when useDartSdk is not present', () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

environment:
  sdk: '3.4.1'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    // Should still work when useDartSdk is not present
    expect(
      await parser.getMaxFlutterSdkVersionFromPubspec(),
      FlutterSdkVersions.fromString('3.22.1', '3.4.1'),
    );
  });

  test('useFlutterSdk throws when given a range constraint', () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

sidekick:
  puro:
    useFlutterSdk: '>=3.19.0 <4.0.0'

environment:
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    expect(
      () => parser.getMaxFlutterSdkVersionFromPubspec(),
      throwsA(
        isA<VersionParserException>().having(
          (e) => e.msg,
          'msg',
          contains('useFlutterSdk must be an exact version'),
        ),
      ),
    );
  });

  test('useFlutterSdk throws when given a caret constraint', () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

sidekick:
  puro:
    useFlutterSdk: '^3.19.0'

environment:
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    expect(
      () => parser.getMaxFlutterSdkVersionFromPubspec(),
      throwsA(
        isA<VersionParserException>().having(
          (e) => e.msg,
          'msg',
          contains('useFlutterSdk must be an exact version'),
        ),
      ),
    );
  });

  test('useDartSdk throws when given a range constraint', () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

sidekick:
  puro:
    useDartSdk: '>=3.3.0 <4.0.0'

environment:
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    expect(
      () => parser.getMaxFlutterSdkVersionFromPubspec(),
      throwsA(
        isA<VersionParserException>().having(
          (e) => e.msg,
          'msg',
          contains('useDartSdk must be an exact version'),
        ),
      ),
    );
  });

  test('useDartSdk throws when given a caret constraint', () async {
    const pubspecYaml = '''
name: puro_sidekick_plugin

sidekick:
  puro:
    useDartSdk: '^3.3.0'

environment:
  sdk: '>=3.0.0 <4.0.0'
''';

    final tempDir = _createPubspec(pubspecYaml);
    final parser = VersionParser(
      packagePath: tempDir,
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    expect(
      () => parser.getMaxFlutterSdkVersionFromPubspec(),
      throwsA(
        isA<VersionParserException>().having(
          (e) => e.msg,
          'msg',
          contains('useDartSdk must be an exact version'),
        ),
      ),
    );
  });
}

Directory _createPubspec(String pubspecContent) {
  final tempDir =
      Directory.systemTemp.createTempSync('puro_sidekick_plugin_test');
  addTearDown(() => tempDir.deleteSync(recursive: true));

  final pubspecFile = File('${tempDir.path}/pubspec.yaml');
  pubspecFile.writeAsStringSync(pubspecContent);

  return tempDir;
}
