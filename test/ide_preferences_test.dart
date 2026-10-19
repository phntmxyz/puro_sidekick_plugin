import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:puro_sidekick_plugin/src/ide/ide_preferences.dart';
import 'package:sidekick_core/sidekick_core.dart' hide isEmpty;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory storage;
  late DartPackage app;
  late DartPackage other;
  late IdePreferences preferences;
  late Map<String, String> versions;
  late List<String> writes;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ide_policy_');
    storage = Directory.systemTemp.createTempSync('ide_preferences_');
    addTearDown(() => root.deleteSync(recursive: true));
    addTearDown(() => storage.deleteSync(recursive: true));
    DartPackage package(String name) {
      final dir = root.directory('packages/$name')..createSync(recursive: true);
      dir
          .file('pubspec.yaml')
          .writeAsStringSync('name: $name\nenvironment:\n  sdk: ^3.6.0\n');
      return DartPackage.fromDirectory(dir)!;
    }

    app = package('app');
    other = package('other');
    versions = {'app': '3.32.8', 'other': '3.27.4'};
    writes = [];
    root.directory('.vscode').createSync();
    preferences = IdePreferences(
      projectRoot: root,
      mainPackage: app,
      packages: [other, app],
      storage: storage,
      resolvePackageSdk: (p) async => versions[p.name]!,
      writeConfiguration: (workspace, sdk, editors) async {
        writes.add('${workspace.path}:$sdk');
        workspace.file('.vscode/settings.json')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('{"dart.flutterSdkPath":"/envs/$sdk/flutter"}');
      },
    );
  });

  test('deps hook skips IDE setup after a failed run', () async {
    // No Sidekick runner is initialized: the guard must return before accessing
    // project context or attempting any IDE configuration.
    await configurePuroIde(AfterDepsContext(results: [
      DepsPackageResult.failure(app,
          error: StateError('pub get failed'), stackTrace: StackTrace.current),
    ]));
    expect(writes, isEmpty);
  });

  test('root follows main package regardless of dependency order', () async {
    await preferences.apply(root);
    expect(writes, ['${root.path}:3.32.8']);
    versions['app'] = '3.38.10';
    await preferences.apply(root);
    expect(writes.last, '${root.path}:3.38.10');
  });

  test('personal SDK remains pinned across deps runs and reset follows main',
      () async {
    await preferences.apply(root,
        selection:
            IdeSelection(mode: 'sdk', value: '3.47.1', editors: {'vscode'}));
    versions['app'] = '3.38.10';
    await preferences.apply(root);
    expect(writes.last, '${root.path}:3.47.1');
    await preferences.apply(root, selection: IdeSelection(editors: {'vscode'}));
    expect(writes.last, '${root.path}:3.38.10');
  });

  test('package choice follows changes to its requirements', () async {
    await preferences.apply(root,
        selection: IdeSelection(
            mode: 'package', value: 'packages/other', editors: {'vscode'}));
    versions['other'] = '3.38.10';
    await preferences.apply(root);
    expect(writes.last, '${root.path}:3.38.10');
  });

  test('standalone package and root choices are independent', () async {
    other.root.directory('.vscode').createSync();
    expect(preferences.workspaceFor(other.root).resolveSymbolicLinksSync(),
        other.root.resolveSymbolicLinksSync());
    await preferences.apply(other.root);
    await preferences.apply(root);
    expect(writes, ['${other.root.path}:3.27.4', '${root.path}:3.32.8']);
    expect(preferences.stateFile(root).path,
        isNot(preferences.stateFile(other.root).path));
  });

  test('preserves existing unmanaged SDK configuration', () async {
    root
        .file('.vscode/settings.json')
        .writeAsStringSync('{"dart.flutterSdkPath":"/my/personal/sdk"}');
    await preferences.apply(root);
    expect(writes, isEmpty);
    expect(preferences.read(root), isNull);
  });

  test('preserves manual edits made after managed setup', () async {
    await preferences.apply(root);
    root.file('.vscode/settings.json').writeAsStringSync('{"manual":"edit"}');
    await preferences.apply(root);
    expect(writes, hasLength(1));
  });

  test('does not save selection if configuring the IDE fails', () async {
    final failing = IdePreferences(
        projectRoot: root,
        mainPackage: app,
        packages: [app],
        storage: storage,
        resolvePackageSdk: (p) async => '3.32.8',
        writeConfiguration: (_, __, ___) async {
          await Future<void>.error(StateError('failed'));
        });
    await expectLater(failing.apply(root), throwsStateError);
    expect(failing.read(root), isNull);
  });

  test('ambiguous root does not silently choose the first package', () async {
    final ambiguous = IdePreferences(
        projectRoot: root,
        mainPackage: null,
        packages: [other, app],
        storage: storage,
        resolvePackageSdk: (p) async => versions[p.name]!,
        writeConfiguration: (_, __, ___) async {
          await Future<void>.error(StateError('Must not write'));
        });
    await ambiguous.apply(root);
    expect(ambiguous.read(root), isNull);
  });

  test('unconfigured headless workspace does not create IDE folders', () async {
    root.directory('.vscode').deleteSync();
    await preferences.apply(root);
    expect(writes, isEmpty);
  });
}
