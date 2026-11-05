# Google Play Console readiness checklist

## Verified in the repository / CI

- App name: Milk Account.
- Android application ID and namespace: `com.awasigogera.milkaccount`.
- Current Flutter version: `0.3.0+3` (version name `0.3.0`, version code `3`).
- Android `compileSdk` and `targetSdk`: 36. CI checks the generated Android target SDK.
- CI builds an Android APK for device testing, an Android App Bundle, and the Web build.
- The Play App Bundle is deliberately built unsigned so the owner can sign it with a private upload key. The test APK is signed with the temporary Android debug certificate and is not a Play upload.
- The app does not need the restricted `SEND_SMS` permission to open the Android SMS composer. The app uses external SMS/WhatsApp intents instead.
- Customer and ledger records are stored locally. Backup export, report sharing, and Nearby transfer are user-initiated.
- The app's Settings screen links to the privacy policy.

## Privacy and Data Safety declarations to complete in Play Console

Review the final release artifact and every included SDK before completing the Data safety form. The current code handles customer names, father's names, phone numbers, account notes, milk ledger entries, advances, and related financial records on-device. Users can choose to export/share backups or reports, open an SMS/WhatsApp message composer, or transfer selected account records to another nearby device.

The project currently has no implemented advertising network or analytics SDK. The visual advertisement placeholder is not a live ad integration. Re-check this if any SDK or service is added later. Google Play services may support Nearby Connections and barcode scanning; review the current third-party SDK disclosures before making the final Data safety declarations.

In Play Console, complete the required Data safety, Ads, App content, content rating, target audience, app access, and store-listing declarations accurately. The developer must confirm these answers; repository code cannot submit these forms on their behalf.

## Remaining release work outside GitHub

1. Enable GitHub Pages once in **Repository Settings → Pages → Build and deployment → Source → GitHub Actions** if the Pages workflow reports that Pages is not enabled. After deployment, verify that `https://basittv17-creat.github.io/MilkAccount/` opens without signing in and use that page URL in Play Console.
2. Confirm the developer name shown in Play Console matches the developer name shown in the privacy policy.
3. Create and securely store an Android upload keystore. Keep the keystore and passwords out of Git and public files. The `.gitignore` already excludes common keystore/key files.
4. Sign the unsigned AAB with the upload key, then verify the certificate before uploading. Enrol in Play App Signing when prompted by Play Console.
5. Prepare the store listing assets and details: 512 × 512 app icon, feature graphic, phone screenshots, app description, category, contact details, and a support website/email.
6. Complete any testing-track or developer-account verification requirements displayed in the Play Console account.

A successful CI build confirms that the project compiles and packages. It does not guarantee Play policy approval or replace the Play Console declarations and signing steps.
