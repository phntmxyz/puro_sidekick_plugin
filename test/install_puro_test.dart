import 'dart:ffi' show Abi;

import 'package:puro_sidekick_plugin/src/install_puro.dart';
import 'package:test/test.dart';

void main() {
  group('puro2Download', () {
    test('Apple Silicon picks the darwin-arm64 build', () {
      final download = puro2Download(Abi.macosArm64)!;
      expect(
        download.url.toString(),
        'https://github.com/phntmxyz/puro2/releases/download/2.0.0/puro2-darwin-arm64',
      );
      expect(download.fileName, 'puro2');
    });

    test('Intel Mac picks the darwin-x64 build', () {
      final download = puro2Download(Abi.macosX64)!;
      expect(
        download.url.toString(),
        'https://github.com/phntmxyz/puro2/releases/download/2.0.0/puro2-darwin-x64',
      );
      expect(download.fileName, 'puro2');
    });

    test('Linux x64 picks the linux-x64 build', () {
      final download = puro2Download(Abi.linuxX64)!;
      expect(
        download.url.toString(),
        'https://github.com/phntmxyz/puro2/releases/download/2.0.0/puro2-linux-x64',
      );
      expect(download.fileName, 'puro2');
    });

    test('Windows x64 picks the windows-x64 build (.exe)', () {
      final download = puro2Download(Abi.windowsX64)!;
      expect(
        download.url.toString(),
        'https://github.com/phntmxyz/puro2/releases/download/2.0.0/puro2-windows-x64.exe',
      );
      expect(download.fileName, 'puro2.exe');
    });

    test('returns null for architectures puro2 does not publish', () {
      // puro2 does not ship linux-arm64 or windows-arm64 builds.
      expect(puro2Download(Abi.linuxArm64), isNull);
      expect(puro2Download(Abi.windowsArm64), isNull);
    });
  });
}
