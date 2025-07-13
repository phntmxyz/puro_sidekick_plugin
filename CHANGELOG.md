# Changelog

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