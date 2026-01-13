import 'package:puro_sidekick_plugin/src/puro.dart';
import 'package:test/test.dart';

void main() {
  group('parsePuroEnvironments', () {
    test('parses environment names from puro ls output', () {
      const output = '''
[i] Environments:
    ~ stable    (stable / 3.38.5 / f6ff1529fd)
      beta      (beta / 3.40.0-0.2.pre / ebde138e38)
      master    (3.33.0-1.0.pre-1465 / 1e1908dc28)
      3.10.6    (stable / 3.10.6 / f468f3366c)
      3.35.7    (stable / 3.35.7 / adc9010625)
      3.10.0    (stable / 3.10.0 / 84a1e904f4)
    * 3.27.4    (stable / 3.27.4 / d8a9f9a52e)
      noa       (stable / 3.10.2 / 9cd3d0d9ff)
      dart_3-5  (stable / 3.24.5 / dec2ee5c1f)
      eurowings (stable / 3.7.12 / 4d9e56e694)
      3.32.8    (stable / 3.32.8 / edada7c56e)
      3.38.6    (stable / 3.38.6 / 8b87286849)
      3.24.5    (stable / 3.24.5 / dec2ee5c1f)
      3.35.2    (stable / 3.35.2 / 05db968908)
      3.38.4    (stable / 3.38.4 / 66dd93f9a2)
      dart_3-6  (stable / 3.27.4 / d8a9f9a52e)
      3.38.3    (stable / 3.38.3 / 19074d12f7)
      dart_3-8  (stable / 3.32.5 / fcf2c11572)
      3.38.2    (stable / 3.38.2 / f5a8537f90)
      dart_3-7  (stable / 3.29.3 / ea121f8859)
      3.0.5     (stable / 3.0.5 / f1875d570e)
      3.24.0    (stable / 3.24.0 / 80c2e84975)
      3.24.1    (stable / 3.24.1 / 5874a72aa4)

    Use `puro create <name>` to create an environment, or `puro use <name>` to switch
''';

      final envs = parsePuroEnvironments(output);

      expect(envs, contains('stable'));
      expect(envs, contains('beta'));
      expect(envs, contains('master'));
      expect(envs, contains('3.10.6'));
      expect(envs, contains('3.27.4'));
      expect(envs, contains('3.38.6'));
      expect(envs, contains('noa'));
      expect(envs, contains('dart_3-5'));
      expect(envs, contains('eurowings'));

      // Total environments
      expect(envs.length, 23);
    });

    test('handles environment with ~ prefix', () {
      const output = '''
[i] Environments:
    ~ stable    (stable / 3.38.5 / f6ff1529fd)
''';

      final envs = parsePuroEnvironments(output);

      expect(envs, contains('stable'));
      expect(envs.length, 1);
    });

    test('handles environment with * prefix', () {
      const output = '''
[i] Environments:
    * 3.27.4    (stable / 3.27.4 / d8a9f9a52e)
''';

      final envs = parsePuroEnvironments(output);

      expect(envs, contains('3.27.4'));
      expect(envs.length, 1);
    });

    test('handles environment without prefix', () {
      const output = '''
[i] Environments:
      beta      (beta / 3.40.0-0.2.pre / ebde138e38)
''';

      final envs = parsePuroEnvironments(output);

      expect(envs, contains('beta'));
      expect(envs.length, 1);
    });

    test('does not match version numbers inside parentheses', () {
      const output = '''
[i] Environments:
    ~ stable    (stable / 3.38.5 / f6ff1529fd)
''';

      final envs = parsePuroEnvironments(output);

      // Should only match 'stable', not '3.38.5'
      expect(envs, contains('stable'));
      expect(envs, isNot(contains('3.38.5')));
      expect(envs.length, 1);
    });

    test('returns empty set for empty output', () {
      const output = '';

      final envs = parsePuroEnvironments(output);

      expect(envs, isEmpty);
    });

    test('returns empty set when no environments exist', () {
      const output = '''
[i] Environments:

    Use `puro create <name>` to create an environment, or `puro use <name>` to switch
''';

      final envs = parsePuroEnvironments(output);

      expect(envs, isEmpty);
    });

    test('handles environments with varying spacing', () {
      const output = '''
[i] Environments:
  ~ stable    (stable / 3.38.5 / f6ff1529fd)
    beta      (beta / 3.40.0-0.2.pre / ebde138e38)
      * master    (3.33.0-1.0.pre-1465 / 1e1908dc28)
''';

      final envs = parsePuroEnvironments(output);

      expect(envs, contains('stable'));
      expect(envs, contains('beta'));
      expect(envs, contains('master'));
      expect(envs.length, 3);
    });
  });
}
