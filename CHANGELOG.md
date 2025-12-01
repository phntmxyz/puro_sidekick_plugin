# Changelog

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