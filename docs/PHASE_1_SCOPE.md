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
- GitHub Actions checks for formatting, analysis, tests, Android APK, and Web build.

## Not yet implemented
Customer records, ledger calculations, advances, milk transactions, Naga days, rate history, database migrations, backup/restore, data transfer, PDF/Excel exports, SMS/WhatsApp delivery, and production AdMob integration are deliberately deferred. They require dedicated data-model design and tests before storing real customer/accounting data.

## Data safety statement
This phase is a UI/architecture foundation only. It must not be used for real customer or financial records. No persistent accounting database is created in this phase.
