import 'package:sidekick_core/sidekick_core.dart';
import 'package:test/test.dart';

import '../tool/src/main_file_modifiers.dart';
import '../tool/src/modifiable_source_file.dart';

void main() {
  test('installer adds a global hook without changing command registrations',
      () {
    final dir = Directory.systemTemp.createTempSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = dir.file('main.dart')..writeAsStringSync('''
void main() {
  final runner = initializeSidekick();
  addDepsHook(existingSetup);
  runner.addCommand(DepsCommand(excludeGlob: ['**/example/**']));
}
''');
    final source = ModifiableSourceFile(file);
    addTearDown(source.dispose);
    source.registerInitializer('addDepsHook(configurePuroIde);');
    expect(source.content, contains('addDepsHook(configurePuroIde);'));
    expect(source.content, contains('addDepsHook(existingSetup);'));
    expect(source.content,
        contains("DepsCommand(excludeGlob: ['**/example/**'])"));
    source.flush();
    source.registerInitializer('addDepsHook(configurePuroIde);');
    expect(RegExp('configurePuroIde').allMatches(source.content), hasLength(1));
  });

  test('registration does not require deps to be constructed in the main file',
      () {
    final dir = Directory.systemTemp.createTempSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = dir.file('main.dart')..writeAsStringSync('''
void main() {
  final runner = initializeSidekick();
  registerCommands(runner);
}
''');
    final source = ModifiableSourceFile(file);
    addTearDown(source.dispose);
    source.registerInitializer('addSdkInitializer(initializePuro);');
    source.registerInitializer('addDepsHook(configurePuroIde);');
    expect(source.content, contains('addSdkInitializer(initializePuro);'));
    expect(source.content, contains('addDepsHook(configurePuroIde);'));
    expect(source.content, contains('registerCommands(runner);'));
  });
}
