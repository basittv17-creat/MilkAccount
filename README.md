# Milk Account — دودھ کا کھاتہ

Offline-first dairy customer ledger app built with Flutter and Dart.

## Phase 2: Approved multilingual dashboard design
This update aligns the starter dashboard with the user's approved three-language visual reference: deep blue branded header, compact advertisement banner, blue Milk Entry card, yellow Advance card, green Accounts card, and four-item bottom navigation. First-launch language selection and dashboard copy now support Urdu (Pakistan), English, and Hindi, with RTL direction for Urdu and LTR direction for English/Hindi.

The action cards remain visual entry points. Customer records, milk transactions, advance accounting, database persistence, and financial workflows are not implemented in this design update. Do not enter real customer or financial data until those phases are completed and tested.

## Run locally
1. Install Flutter stable.
2. Run `bash tool/prepare_platforms.sh` to generate missing Android and Web platform folders.
3. Run `flutter pub get`.
4. Run `flutter run`.

## Validation
GitHub Actions generates missing Android/Web platform scaffolding, then runs Dart formatting, Flutter analysis, widget tests, Android release APK build, and Web release build on pushes to `main`.

See [Phase 2 visual scope](docs/PHASE_1_SCOPE.md).
