# Classe

A local-first Flutter reminders app with:

- Local account creation and login (no backend, no network calls).
- A reminders home screen with scheduled **device notifications**.
- All data stored on the device with `shared_preferences`.
- [Shorebird](https://shorebird.dev) Code Push support with a mandatory
  update/restart flow.

## Features

- **Create an account / log in** — passwords are salted and SHA-256 hashed
  before they are stored. The session persists between launches, and you can
  log out at any time.
- **Reminders** — add a title, optional notes, date and time. Each reminder is
  scheduled with `flutter_local_notifications` so it alerts you at the chosen
  time, even when the app is closed.
- **Home dashboard** — today/upcoming/done counters, upcoming and completed
  sections, tap a card to mark it done, swipe-free delete with confirmation.
- **Notification permission handling** — the app asks for permission and shows
  an inline banner with a "Turn on" action if it was denied.
- **Update gate** — on launch the app checks Shorebird for a patch. If one
  exists the app is blocked by an "Update required" dialog, then a "Restart
  required" dialog after downloading.

## Design

The UI uses an **ink & citrus** palette: near-black `#101312` surfaces, warm
paper `#F5F5F0` backgrounds, white cards, and electric lime `#D9FF57` accents.
No purple anywhere.

- Auth screens sit on a dark ink canvas with a lime brand mark and a lifted
  white card.
- Home opens with a floating dark hero card (date, greeting, today/later/done
  counters) above white reminder cards with lime completion indicators.
- Type is heavy and tight (`w800`, negative letter spacing) for headings, with
  muted grey body copy.
- Shared tokens live in `lib/theme/app_theme.dart`; the auth layout lives in
  `lib/widgets/auth_shell.dart`.

## Project structure

```
lib/
  main.dart                    # Entry point + MaterialApp
  app_root.dart                # Session restore + login/signup/home routing
  screens/
    login_screen.dart          # Login form
    signup_screen.dart         # Create-account form
    home_screen.dart           # Reminder dashboard + add-reminder sheet
  data/
    local_store.dart           # SharedPreferences JSON persistence
    auth_service.dart          # Local account/session logic + hashing
    reminder_service.dart      # Reminder CRUD + notification scheduling
  models/
    account.dart
    reminder.dart
  services/
    notification_service.dart  # flutter_local_notifications wrapper
  theme/app_theme.dart         # Colors, typography, shared widget styles
  widgets/auth_shell.dart      # Shared auth screen layout
  app_updater.dart             # Shorebird update check/download wrapper
  update_gate.dart             # Mandatory update + restart dialogs
```

## Run

```sh
flutter pub get
flutter run
```

Accounts and reminders are stored per device. Deleting the app also deletes
the data.

## Notifications

- **Android**: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` and
  `SCHEDULE_EXACT_ALARM` are declared in
  `android/app/src/main/AndroidManifest.xml`, along with the plugin's
  scheduled-notification receivers. Core library desugaring is enabled in
  `android/app/build.gradle.kts` as required by the plugin.
- **iOS/macOS**: notification permission is requested from Dart, and
  `AppDelegate` sets the `UNUserNotificationCenter` delegate so notifications
  also appear while the app is in the foreground.

Exact alarms are requested first and fall back to inexact alarms if the device
does not allow them. Scheduled notifications are restored after a reboot by the
plugin's boot receiver.

## Shorebird (code push)

`shorebird.yaml` already contains the project's `app_id`. The CLI is installed
at `%USERPROFILE%\.shorebird\bin\shorebird.bat` (add it to `PATH` if needed).

Check what is installed and build a new release:

```sh
shorebird releases list
shorebird release android
```

Ship Dart-only changes afterwards:

```sh
shorebird patch android
```

Notes:

- Patches only cover Dart code and Dart dependencies. Changes to assets or
  native code (including adding/updating plugins) require a new
  `shorebird release`, not a patch.
- `auto_update` is disabled in `shorebird.yaml` so the app controls the flow.
  `lib/update_gate.dart` checks on startup and, when a patch exists, blocks the
  app with a non-dismissible "Update required" dialog. After the download it
  shows a "Restart required" dialog. On Android the restart button uses a small
  native method channel (`android/app/src/main/kotlin/.../MainActivity.kt`) to
  relaunch the app and kill the process, so Shorebird loads the patch on the
  next cold start. All of this is a safe no-op in normal `flutter run` builds.
- Icon-only UI changes can still alter the tree-shaken
  `MaterialIcons-Regular.otf`, which Shorebird treats as an asset change. Make
  sure every glyph used already exists in the published release, then patch
  with `shorebird patch android --release-version=<version> --allow-asset-diffs`.
## In-app APK releases (ReVanced Manager-style)

`lib/update_gate.dart` checks for full app releases before the Shorebird patch
flow:

1. On Android, it fetches the latest GitHub release for
   `SohailDev7/Android-App` and compares its tag/version to the installed app
   version (`package_info_plus`).
2. If a newer release with an `.apk` asset is found, the app shows a
   non-dismissible **"New release detected"** dialog.
3. Tapping **Download & install** downloads the APK into the app cache with
   progress, then launches the Android package installer.
4. Android 8+ requires "Install unknown apps" permission for Classe; the app
   opens that settings screen when needed, then the user taps **Install update**.
5. After installation completes in the system installer, the user opens the new
   build.

Publishing a release for this flow:

```sh
# Bump pubspec version (versionName+buildNumber), then build:
flutter build apk --release
# or create a Shorebird release + extract/distribute APK as needed:
shorebird release android
```

Create a GitHub Release (e.g. tag `v1.2.0`) and attach the APK asset (filename
ending in `.apk`). The in-app updater uses the latest release tag and its APK
asset.

Important:

- Users must install one build that contains this updater/native install
  plumbing. Existing installs without `REQUEST_INSTALL_PACKAGES`, the
  `FileProvider`, and the `classe/restart` install methods cannot receive those
  native changes via a Shorebird Dart patch.
- Use normal Android signing for distributed APKs (not debug signing) so updates
  can install over the same app id.
- Shorebird patch flow still runs when no newer APK release is detected, so
  Dart-only fixes can continue to ship as patches after users are on a
  compatible release.

