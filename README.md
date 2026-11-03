# Milk Account — دودھ کا کھاتہ

Offline-first dairy customer ledger app built with Flutter and Dart.

## Phase 1: UI and project foundation
This release establishes the app theme, Urdu/English first-launch language selection, the starter dashboard, bottom navigation, and automated CI checks. The approved Urdu roadmap screenshot is the visual source of truth for the layout and color direction.

**Important:** Phase 1 is not yet a production accounting app. Customer data, ledger math, database persistence, backup/restore, and financial workflows are not implemented yet. Do not enter real customer or financial data.

## Run locally
1. Install Flutter stable.
2. Run `flutter pub get`.
3. Run `flutter run`.

## Validation
GitHub Actions runs Dart formatting, Flutter analysis, widget tests, Android release APK build, and Web release build on pushes to `main`.

See [Phase 1 scope](docs/PHASE_1_SCOPE.md).
