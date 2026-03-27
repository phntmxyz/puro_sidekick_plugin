# Changelog

## 1.4.0

- **Fix** Global puro install failing because `~/.puro/bin` was not added to the process PATH after installation
- Update `dcli` to `8.2.0` and `sidekick_core` to `3.1.0`
- Add missing `awaits` in install script

## 1.3.3
- **Optimize** `puro`/`flutter` calls by constructing SDK paths directly instead of calling `puro flutter --version` (#11)
- **Improve** Parsing of `puro ls` output (#11)
- **Fix** Disable IDE configuration to prevent version conflicts when commands are run from different packages (#10)

## 1.3.2
- Cache GitHub API responses for puro version checks (24h TTL) to avoid rate limiting
- Bump `puro` fallback version to `1.5.0`
- Print "Using Dart X.Y.Z (via Flutter A.B.C)" for pure Dart packages instead of "Using Flutter..."

## 1.3.1
- Move puro configuration from `environment` to `sidekick.puro` section in pubspec.yaml
  - `environment.preferFlutter` is now `sidekick.puro.useFlutterSdk`
  - `environment.preferDart` is now `sidekick.puro.useDartSdk`
  - This fixes compatibility issues with pub.dev validation (environment only allows standard keys)
  ```yaml
  environment:
    flutter: '>=3.0.0 <4.0.0'  # Broad support for users
    sdk: '>=3.0.0 <4.0.0'
  
  sidekick:
    puro:
      useFlutterSdk: '3.22.1'  # Used by puro_sidekick_plugin
      useDartSdk: '3.4.1'      
  ```

## 1.3.0 (retracted)
- Retracted: `environment` section in pubspec.yaml doesn't allow custom keys like `environment.preferFlutter`

## 1.2.1
- Check all published Flutter+Dart combinations when selecting a Flutter SDK (including beta)

## 1.2.0
- Fix multiple `initializePuro` calls setting up *different* puro environments, actually using the correct environment and do not use the env from the previous `initializePuro` call
- Reduce version print to a single line, enable debug logging with `export PURO_SIDEKICK_PLUGIN_VERBOSE=true`

## 1.1.2
- Await all `puro` calls
- Make `puroFlutterSdkPath` return a `Future`

## 1.1.1
- Fix a Bug in Puro update check

## 1.1.0
- Update to Sidekick 3.0.0-preview.5
- Add Puro update check
- Min Dart version is now 3.5.0

## 1.0.0

- Update to Sidekick 3.0
- Update dcli to 4.0.4
- Min Dart version is now 3.3.0

## 0.1.0

- Initial plugin version installing `puro`