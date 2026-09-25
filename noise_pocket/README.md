# Noise Pocket

An offline Flutter soundboard with six original, synthesized sound effects. One AdMob banner may appear on Android after Google's consent flow permits ads; sounds always work without internet. Web preview deliberately runs without the native ad SDK.

The screen keeps the supplied Noise Pocket look: bright orange, purple, blue, yellow, green, and pink pads on charcoal, lime active outline and Surprise Me button, and a dark Playback Settings sheet. The pads now have clear icons and left-aligned labels. Open settings with the sliders icon beside the logo. The first-use hint disappears after a sound is played. Ads are rendered only from AdMob; no ad artwork is hardcoded into the screen.

## Build and install

Use Flutter **3.38.1+**, Android SDK, and Java 17. From this directory:

```sh
flutter pub get
flutter build apk --release --dart-define-from-file=config/admob.json
```

The resulting file is `build/app/outputs/flutter-apk/app-release.apk`. Copy it to your Android phone and open it to install (allow installation from this source if Android asks). For quick testing, use `flutter run` with a connected phone, or `flutter run -d chrome` for a browser preview (no ads). Flutter's default release APK is signed with the debug key in this project; for distribution or Play Store upload, configure a private release signing key and replace the example application ID (`com.example.noisepocket`) first. Play Store generally requires an Android App Bundle: `flutter build appbundle --release --dart-define-from-file=config/admob.json`.

## AdMob production configuration

**One location:** [`config/admob.json`](config/admob.json) contains both Google's official Android **test app ID** and **test banner unit ID**. Do not publish with test IDs. Create an AdMob account and app, create one banner unit, then replace both values in that file with your own. Always pass `--dart-define-from-file=config/admob.json` to builds. The Gradle Android manifest reads `ADMOB_APP_ID` from the same JSON file, and Dart reads `ADMOB_BANNER_ID`. Ads never request on web; the Android app and all sounds work offline when ads are unavailable.

In AdMob > Privacy & messaging, create and publish the applicable consent messages (including EEA/UK/Switzerland and other regions you serve). The app calls Google's UMP at each Android launch, shows its form if required, checks `canRequestAds` before loading its banner, and exposes **Privacy choices** if UMP requires that entry point. Supply a public privacy policy and complete Play Console data safety and audience declarations. If this app is aimed at children, review Google Play Families and AdMob child treatment requirements before advertising. Finish account verification, payment and tax details, app review, store listing, signing, and device testing. Google requires the AdMob and Play Console account holder to be at least 18; a parent or guardian can apply using their own account for an underage developer. Ads and earnings are never guaranteed.

## Sounds

`assets/sounds/*.wav` contains 18 original, fixed recordings: each of the six effects has Slow, Normal, and Fast versions. All six were rebuilt for this version; Fart has stronger midrange so it is audible on small phone speakers. The speed setting selects a bundled file with the same musical pitch; it never changes playback rate or generates a random sound at tap time. The effects are granted for commercial reuse without attribution. Recreate them using `python3 tool/generate_sounds.py` with NumPy and SciPy, then check them with `python3 tool/check_sounds.py`. The launcher icon is original and can be regenerated with `python3 tool/generate_icon.py` using Pillow.

## Verification

Run `python3 tool/check_sounds.py`, `flutter analyze`, `flutter test` and `flutter build apk --release --dart-define-from-file=config/admob.json`. On a real Android phone, tap each of the six pads at each speed, especially Fart on the phone speaker, rapidly alternate them, try Surprise Me, Stop, and Volume, relaunch to verify saved settings, background during a sound to verify stop, then test with airplane mode and with/without consent. Switching speed while playing restarts the current effect using the selected recording. A browser preview verifies visuals and audio but cannot validate native AdMob or Android haptics. These changes have not been compiled or listened to on a device in this workspace; build and test the new version before distributing it.
