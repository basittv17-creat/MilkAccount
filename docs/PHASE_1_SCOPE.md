# Milk Account — Phase 2 visual alignment

## Approved visual reference
The user's latest three-language dashboard screenshot is the authoritative design reference. Preserve its structure and visual language: dairy-blue branded header, milk/cow theme, compact advertisement banner, three large action cards in blue/yellow/green, and bottom navigation with Home, Accounts, Reports, Settings.

## Delivered in this update
- Reworked the app header and brand treatment to a deep-blue dairy-themed presentation.
- Reworked the ad placeholder to match the compact banner position and style in the reference. It remains a placeholder, not a live AdMob integration.
- Reworked Milk Entry, Advance, and Accounts cards with the reference's blue, yellow, and green palette, rounded borders, icon badges, and chevrons.
- Preserved the four destinations in bottom navigation.
- Added Hindi to first-launch language selection and dashboard copy alongside Urdu and English.
- Applied RTL direction for Urdu and LTR direction for English and Hindi.
- Added widget coverage for all three language choices and Urdu/Hindi dashboard labels.

## Not included in this visual update
The action cards remain placeholders. Customer database, customer create/edit flows, ledger calculations, milk entries, advance transactions, Naga days, rate management, backup/restore, exports, and production AdMob are not implemented here. These require separate data-model and workflow phases with dedicated tests.

## Visual accuracy note
This commit aligns the Flutter layout, hierarchy, and color palette with the approved reference, but it is not yet a pixel-perfect reproduction. The original standalone cow/logo/background artwork and font files were not supplied separately; current branding uses Flutter iconography and subtle emoji decoration, and Urdu/Hindi glyph appearance can vary by Android device. A final screenshot comparison on target Android sizes is still required before claiming exact visual parity.
