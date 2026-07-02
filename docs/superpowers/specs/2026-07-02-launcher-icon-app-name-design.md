# Launcher Icon + App Name — Design

**Date:** 2026-07-02
**Status:** Approved
**Scope:** Replace the default Flutter launcher icon with the SpendWise logo
(proper Android adaptive icon + iOS icon) and correct the app display name to
"SpendWise" on both platforms. No splash screen, no in-app logo placement, no
Dart/logic changes.

## Problem

The app ships with the **default Flutter launcher icon** (the stock icon; the
`ic_launcher.png` files are 442–1443 bytes, i.e. Flutter's placeholders) and a
lowercase/mis-cased display name (`android:label="spendwise"`,
`CFBundleDisplayName="Spendwise"`, `CFBundleName="spendwise"`). The SpendWise
logo already exists as `branding/spendwise_icon.svg` and as the `LogoMark`
`CustomPainter`, but it only appears inside the onboarding screen — never as the
home-screen app icon. On the device the app looks unbranded.

## Decisions (locked)

- **Scope:** launcher icon + app-name casing only. Splash screen and in-app
  `LogoMark` placement are explicitly out of scope.
- **Android:** proper **adaptive icon** — gradient background layer + white "S"
  foreground layer inset into the safe zone — so it renders correctly under any
  launcher mask (circle, squircle, teardrop).
- **iOS:** the full rounded-tile logo (iOS applies its own corner mask).

## Approach

`flutter_launcher_icons` is the standard, well-maintained generator; it produces
all Android mipmap densities, the `mipmap-anydpi-v26/ic_launcher.xml` adaptive
descriptor with background/foreground drawables, and the iOS
`AppIcon.appiconset` from source PNGs. It only needs raster PNG inputs, so the
one real task is producing those from the existing vector logo.

### Producing the source PNGs

The logo is vector (`branding/spendwise_icon.svg`, with linear + radial
gradients). ImageMagick's SVG support in this environment is unreliable for
gradients (no rsvg/inkscape delegate), so the PNGs are rendered by loading SVGs
in the headless browser (Playwright, already available this session) at a
1024×1024 viewport and screenshotting. Browsers render SVG gradients exactly.

Three source PNGs, all 1024×1024, committed under `branding/`:

1. **`branding/icon_full_1024.png`** — the existing `spendwise_icon.svg`
   verbatim (rounded orange tile + gradient + sheen + white S). Opaque, no
   alpha. Used for the iOS icon and the Android legacy fallback (`image_path`).

2. **`branding/icon_bg_1024.png`** — the Android adaptive **background** layer:
   the same linear gradient filling a full-bleed 1024×1024 square, **no rounded
   corners and no S** (the system mask handles the shape). Rendered from a
   minimal SVG containing only the `linearGradient` rect.

3. **`branding/icon_fg_1024.png`** — the Android adaptive **foreground** layer:
   the white "S" monogram on a **transparent** background, inset to ~62% of the
   canvas so it sits inside Android's adaptive safe zone (outer ~⅓ may be
   clipped). Rendered from an SVG that wraps the existing S path in
   `transform="translate(512,512) scale(0.62) translate(-512,-512)"` (scales the
   S about the canvas centre), with the browser screenshot taken with
   transparency preserved (`omitBackground`).

### flutter_launcher_icons config (in `pubspec.yaml`)

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  image_path: "branding/icon_full_1024.png"
  android: true
  ios: true
  adaptive_icon_background: "branding/icon_bg_1024.png"
  adaptive_icon_foreground: "branding/icon_fg_1024.png"
  remove_alpha_ios: true
  min_sdk_android: 21
```

Running `dart run flutter_launcher_icons` regenerates:
- `android/app/src/main/res/mipmap-*/ic_launcher.png` (all densities)
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` + the
  foreground/background drawables it references
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`

### App-name casing

- `android/app/src/main/AndroidManifest.xml`: `android:label="SpendWise"`.
- `ios/Runner/Info.plist`: `CFBundleDisplayName` → `SpendWise`, `CFBundleName` →
  `SpendWise` (well under the 15-char limit).

## Components / files

- **New (committed):** `branding/icon_full_1024.png`, `branding/icon_bg_1024.png`,
  `branding/icon_fg_1024.png`. The SVG wrappers used to render the background and
  foreground are also kept, for reproducibility: `branding/icon_bg.svg`
  (gradient-only square) and `branding/icon_fg.svg` (inset white S on
  transparent). `icon_full_1024.png` is rendered from the existing
  `branding/spendwise_icon.svg`.
- **Edit:** `pubspec.yaml` (dev dep + `flutter_launcher_icons` config).
- **Generated (committed):** all Android mipmaps, the adaptive XML + drawables,
  the iOS appiconset — produced by the tool, not hand-written.
- **Edit:** `android/app/src/main/AndroidManifest.xml` (`android:label`).
- **Edit:** `ios/Runner/Info.plist` (`CFBundleDisplayName`, `CFBundleName`).

No `lib/` changes.

## Error handling

Not applicable — this is a build-time asset/config change with no runtime code
path. The failure mode is "the generator errors or the build fails," caught by
verification below.

## Testing / verification

No automated unit/widget tests apply (assets + native config only). Verification:

1. `dart run flutter_launcher_icons` completes without error.
2. The regenerated `mipmap-*/ic_launcher.png` files are real icons (kilobytes,
   not the ~500-byte defaults), and `mipmap-anydpi-v26/ic_launcher.xml` plus its
   referenced foreground/background drawables exist.
3. The iOS `AppIcon.appiconset` contains the generated sizes and its
   `Contents.json` references them.
4. `flutter analyze` stays clean (no Dart changed, so this just confirms nothing
   else broke).
5. `flutter build apk --debug` succeeds — the authoritative check that the icon
   config, adaptive XML, and manifest label are all valid. (Requires the Android
   toolchain; if unavailable in the environment, note it and rely on the
   generator output + XML/asset presence.)
6. Manual (device): the SpendWise icon and the name "SpendWise" appear on the
   home screen and app switcher.

## Out of scope

Splash screen (`flutter_native_splash`), placing `LogoMark` in the in-app
Home/Settings headers, removing the now-reference-only
`branding/spendwise_logo*.svg`, and any Dart/business-logic change.
