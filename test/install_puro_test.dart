import 'dart:ffi' show Abi;

import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
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
      expect(
        download.sha256,
        '09118b9933b528eaf2976e7a901aa83f31a819ba19e1e3dc144addd8e8bdf89c',
      );
      expect(download.fileName, 'puro2');
    });

    test('Intel Mac picks the darwin-x64 build', () {
      final download = puro2Download(Abi.macosX64)!;
      expect(
        download.url.toString(),
        'https://github.com/phntmxyz/puro2/releases/download/2.0.0/puro2-darwin-x64',
      );
      expect(
        download.sha256,
        '03e958a9e378f886767c91315eb1b251f3eebb0148f8413caf8a4a57618155ea',
      );
      expect(download.fileName, 'puro2');
    });

    test('Linux x64 picks the linux-x64 build', () {
      final download = puro2Download(Abi.linuxX64)!;
      expect(
        download.url.toString(),
        'https://github.com/phntmxyz/puro2/releases/download/2.0.0/puro2-linux-x64',
      );
      expect(
        download.sha256,
        '73345cb486a03a844238a213b035a87b37f71dbcab4ff3ffd5a60a290eeaf118',
      );
      expect(download.fileName, 'puro2');
    });

    test('Windows x64 picks the windows-x64 build (.exe)', () {
      final download = puro2Download(Abi.windowsX64)!;
      expect(
        download.url.toString(),
        'https://github.com/phntmxyz/puro2/releases/download/2.0.0/puro2-windows-x64.exe',
      );
      expect(
        download.sha256,
        'e138361f150bda416c546b21e4450b9f240c39978ce7cdac68679405cfa3e732',
      );
      expect(download.fileName, 'puro2.exe');
    });

    test('returns null for architectures puro2 does not publish', () {
      // puro2 does not ship linux-arm64 or windows-arm64 builds.
      expect(puro2Download(Abi.linuxArm64), isNull);
      expect(puro2Download(Abi.windowsArm64), isNull);
    });
  });

  group('verifyPuro2Checksum', () {
    // sha256 of the empty input
    const emptySha256 =
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

    Puro2Download downloadWithSha256(String sha256) {
      return Puro2Download(
        url: Uri.parse('https://example.com/puro2'),
        sha256: sha256,
        fileName: 'puro2',
      );
    }

    test('accepts bytes with the pinned sha256', () {
      verifyPuro2Checksum([], downloadWithSha256(emptySha256));
    });

    test('rejects bytes with a different sha256', () {
      expect(
        () => verifyPuro2Checksum([1, 2, 3], downloadWithSha256(emptySha256)),
        throwsA(isA<PuroInstallationFailedException>()),
      );
    });
  });
}
