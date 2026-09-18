# Localization

AirMic supports English (`en`) and Korean (`ko`). macOS selects the first supported preferred language, including regional variants such as `ko-KR`. When no preferred language is supported, the bundle's development language is English. A language change takes effect after normal quit and relaunch.

## Resources

```text
Resources/
  en.lproj/
    Localizable.strings   # Menus, window, help, errors
    InfoPlist.strings     # System microphone permission purpose
  ko.lproj/
    Localizable.strings
    InfoPlist.strings
```

`L(@"state.muted")` resolves stable keys through `NSLocalizedString`. Device names and errors supplied by macOS retain the system-provided text. CLI option names, help, version, and diagnostic field names remain in English for reproducible terminal use. The product name remains AirMic.

## Add or update a language

1. Copy `Resources/en.lproj` to a supported language-code folder, such as `fr.lproj`.
2. Translate the values in both `.strings` files; preserve keys and the meaning of privacy/restoration limits.
3. Preserve format tokens **and their order**: `%@` is the device name, `%lu` is the callback count, and `%d` is an audio status code. A callback is not necessarily a physical button press. Keep paragraph breaks in the help text.
4. Run `bash scripts/check.sh`. Every bundled language must have the same keys and format tokens as English. Add a `check_language` case in `scripts/check-localizations.sh` for the new language; replace the unsupported-language fallback case if it is now supported.
5. Inspect window, menu, help, and long error text. Update the supported-language list in both READMEs and this guide, and note the contribution in the changelog.

The build automatically copies `.lproj` resources; no new runtime package or language-selection preference is needed. Keep the English `NSMicrophoneUsageDescription` in `Source/Info.plist` aligned with `en.lproj/InfoPlist.strings`.

## Preview without microphone access

After `bash scripts/check.sh`, the test bundle can show a read-only preview of the production window:

```sh
open -n build/LocalizationChecks.app --args \
  -AppleLanguages '(en)' -ExpectedLanguage en \
  -SourcePath "$PWD/Source/main.m" -ShowPreview YES
```

Use `(ko)` and `ko` for Korean. This is a developer test bundle with disabled controls and sample state, not the working audio app. Quit the preview process when finished. It never starts microphone I/O or writes the app's mute snapshots. The actual system permission dialog is not opened by these tests; the localized purpose string is verified through bundle lookup.

For the real app, use **System Settings → General → Language & Region → Applications** to select its language, then relaunch. Do not reset system microphone permissions merely to review wording.
