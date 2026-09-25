# Noise Pocket

An offline Flutter soundboard with 26 original, synthesized sound effects. One AdMob banner may appear on Android after Google's consent flow permits ads; sounds always work without internet. The web preview runs without requesting native ads.

Version **2.1.0** adds 20 sounds to the original six while keeping the charcoal, bright two-column pads, lime highlight, and dark Playback Settings sheet. Filter the grid with **All**, **Reactions**, **Cartoon**, **Arcade**, and **World**. **Surprise Me** selects a different pad from the visible category; **Stop** and **Surprise Me** stay at the bottom while browsing. The fixed status card names the sound being played. A new tap stops the previous sound. Ads are rendered only from AdMob.

| Reactions (8) | Cartoon (6) | Arcade (6) | World (6) |
| --- | --- | --- | --- |
| Air horn, Fart, Sad trombone, Ba dum tss, Crickets, Applause, Boo, Whistle | Boing, Squeak, Pop, Record scratch, Whoosh, Splash | Laser / pew pew, Coin, Power up, Error buzz, Robot beep, Game over | Doorbell, Knock knock, Camera, Thunder, Ghost, Snore |

## Build and install

Use Flutter **3.38.1+**, Android SDK, and Java 17. From this directory:

```sh
flutter pub get
flutter build apk --release --dart-define-from-file=config/admob.json
```

The resulting file is `build/app/outputs/flutter-apk/app-release.apk`. Copy it to your Android phone and open it to install (allow installation from this source if Android asks). **Build this 2.1.0 source and install its new APK; older APKs do not update from the source ZIP.** For quick testing, use `flutter run` with a connected phone, or `flutter run -d chrome` for a browser preview (no ads). This project has no private release signing key; for distribution or Play Store upload, configure one and replace the example application ID (`com.example.noisepocket`) first. For Play Store, build an Android App Bundle: `flutter build appbundle --release --dart-define-from-file=config/admob.json`.

### Build online with Codemagic

Put [`codemagic.yaml`](codemagic.yaml) at the **repository root** and select **Noise Pocket v2.1 test APK** in Codemagic. The workflow accepts the app either at the repository root or inside `noise_pocket/`, then puts an installable `app-debug.apk` in the build's Artifacts. It uses test ad IDs and debug signing; it is for phone testing, not Play Store publishing. If a previously installed APK was signed with a different key, uninstall it before installing this test APK (that clears saved settings).

## AdMob production configuration

**One location:** [`config/admob.json`](config/admob.json) contains both Google's official Android **test app ID** and **test banner unit ID**. Do not publish with test IDs. Create an AdMob account and app, create one banner unit, then replace both values in that file with your own. Always pass `--dart-define-from-file=config/admob.json` to builds. The Gradle Android manifest reads `ADMOB_APP_ID` from the same JSON file, and Dart reads `ADMOB_BANNER_ID`. Ads never request on web; the Android app and all sounds work offline when ads are unavailable.

In AdMob > Privacy & messaging, create and publish the applicable consent messages (including EEA/UK/Switzerland and other regions you serve). The app calls Google's UMP at each Android launch, shows its form if required, checks `canRequestAds` before loading its banner, and exposes **Privacy choices** if UMP requires that entry point. Supply a public privacy policy and complete Play Console data safety and audience declarations. If this app is aimed at children, review Google Play Families and AdMob child treatment requirements before advertising. Finish account verification, payment and tax details, app review, store listing, signing, and device testing. Google requires the AdMob and Play Console account holder to be at least 18; a parent or guardian can apply using their own account for an underage developer. Ads and earnings are never guaranteed.

## Sounds

`assets/sounds/*.wav` contains 78 original, fixed PCM recordings: 26 effects × Slow, Normal, and Fast. The 20 additions were synthesized for this project; Fart has strong midrange for small phone speakers. Each speed setting selects its own bundled file at essentially the same musical pitch; it does not pitch-shift audio at playback or randomly generate it. All 78 work offline. These original effects are granted for commercial reuse without attribution. Recreate them using `python3 tool/generate_sounds.py` with NumPy and SciPy, then check them with `python3 tool/check_sounds.py`. The original launcher icon can be regenerated with `python3 tool/generate_icon.py` using Pillow.

## Verification

Run `python3 tool/check_sounds.py`, `flutter analyze`, `flutter test` and `flutter build apk --release --dart-define-from-file=config/admob.json`. On a real Android phone, tap **all 26 pads** at every speed, especially Fart on the phone speaker; rapidly alternate them; check category filters, Surprise Me, Stop, and Volume; relaunch to verify saved settings; background during a sound to verify stop; then test with airplane mode and with/without consent. Switching speed while playing restarts the current effect using the selected recording. A browser preview verifies visuals and audio but cannot validate native AdMob or Android haptics. The source and WAV files were checked in this workspace, but the 2.1.0 app was not compiled or device-tested here; build and test this new version before distributing it.
