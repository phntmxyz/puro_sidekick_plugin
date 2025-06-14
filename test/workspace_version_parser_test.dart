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
  test('get root flutter version when project resolution is workspace',
      () async {
    const rootPubspec = '''
name: root_pubspec

environment:
  flutter: '3.19.6'
  sdk: '>=3.0.0 <4.0.0'
''';

    const packagePubspec = '''
name: package_pubspec

environment:
  flutter: '3.16.9'
  sdk: '>=3.0.0 <4.0.0'
  
resolution: workspace
''';

    final tempDir = _createWorkspacePubspec(rootPubspec, packagePubspec);
    final parser = VersionParser(
      projectRoot: tempDir,
      packagePath: Directory('${tempDir.path}/package'),
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    expect(await parser.getMaxFlutterSdkVersionFromPubspec(), '3.19.6');
  });

  test('get root flutter version when project resolution is local', () async {
    const rootPubspec = '''
name: root_pubspec

environment:
  flutter: '3.19.6'
  sdk: '>=3.0.0 <4.0.0'
''';

    const packagePubspec = '''
name: package_pubspec

environment:
  flutter: '3.16.9'
  sdk: '>=3.0.0 <4.0.0'
  
resolution: local
''';

    final tempDir = _createWorkspacePubspec(rootPubspec, packagePubspec);
    final parser = VersionParser(
      packagePath: Directory('${tempDir.path}/package'),
      puroLsVersionsProvider: () => _puroLsVersions,
    );

    expect(await parser.getMaxFlutterSdkVersionFromPubspec(), '3.16.9');
  });
}

Directory _createWorkspacePubspec(
  String rootPubspecContent,
  String packagePubspecContent,
) {
  final tempDir =
      Directory.systemTemp.createTempSync('puro_sidekick_plugin_test');
  addTearDown(() => tempDir.deleteSync(recursive: true));

  final pubspecFile = File('${tempDir.path}/pubspec.yaml');
  pubspecFile.writeAsStringSync(rootPubspecContent);

  final packageDir = Directory('${tempDir.path}/package');
  packageDir.createSync();
  final packagePubspecFile = File('${packageDir.path}/pubspec.yaml');
  packagePubspecFile.writeAsStringSync(packagePubspecContent);

  return tempDir;
}
