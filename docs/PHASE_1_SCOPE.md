# Milk Account — Phase 1

## Approved visual direction
Use the supplied Urdu roadmap screenshot as the visual reference: dairy-blue gradient branding, white rounded cards, green confirmation/action accents, blue/yellow/green dashboard action cards, and a compact top advertisement reservation. Preserve the approved screen hierarchy and RTL alignment for Urdu.

## Included in this foundation
- Flutter/Dart application entry point and Material 3 theme.
- First-launch language selection with Urdu (Pakistan) and English.
- Persisted language choice; language can be changed from the menu.
- Responsive starter dashboard with Milk Entry, Advance, and Accounts action cards.
- Bottom navigation: Home, Accounts, Reports, Settings.
- Reserved compact ad banner area; no interstitial or full-screen ads.
- Reproducible Flutter platform bootstrap script for Android and Web.
- GitHub Actions checks for formatting, analysis, tests, Android APK, and Web build.

## Platform generation
The repository currently stores the Flutter application source, not generated Android or Web platform scaffolding. Before building, `tool/prepare_platforms.sh` runs `flutter create --platforms=android,web` using the same stable Flutter SDK as CI. This avoids hand-written or SDK-mismatched Gradle files and creates the required platform files in a clean checkout. Run the script locally once after installing Flutter, or let CI run it automatically.

## Not yet implemented
Customer records, ledger calculations, advances, milk transactions, Naga days, rate history, database migrations, backup/restore, data transfer, PDF/Excel exports, SMS/WhatsApp delivery, and production AdMob integration are deliberately deferred. They require dedicated data-model design and tests before storing real customer/accounting data.

## Data safety statement
This phase is a UI/architecture foundation only. It must not be used for real customer or financial records. No persistent accounting database is created in this phase.
