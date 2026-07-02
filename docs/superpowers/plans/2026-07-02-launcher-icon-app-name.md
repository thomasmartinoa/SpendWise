# Launcher Icon + App Name Implementation Plan

> **For agentic workers:** This plan is intended for INLINE execution (superpowers:executing-plans) by an operator with a headless browser (Playwright) available, because rendering the PNGs from SVG and visually verifying the icon require it. Steps use checkbox (`- [ ]`) syntax for tracking. There are no automated unit tests — this is an asset/native-config change — so each task ends with concrete verification commands + a visual check instead of a test cycle.

**Goal:** Replace the default Flutter launcher icon with the SpendWise logo (proper Android adaptive icon + iOS icon) and correct the app display name to "SpendWise" on both platforms.

**Architecture:** Render three 1024×1024 source PNGs from the existing vector logo (full tile, gradient-only background, white-S foreground) via a headless browser, then let `flutter_launcher_icons` generate all Android mipmaps + adaptive descriptor and the iOS appiconset. Finally correct the app-name strings in the Android manifest and iOS Info.plist.

**Tech Stack:** `flutter_launcher_icons` (dev dependency), Playwright headless Chromium (for SVG→PNG rendering), ImageMagick `identify` (dimension checks).

## Global Constraints

- Scope is launcher icon + app-name casing ONLY. No splash screen, no in-app `LogoMark` placement, no Dart/logic changes.
- App display name must be exactly **`SpendWise`** (both platforms).
- Android icon must be a proper **adaptive icon**: gradient background layer + white "S" foreground layer.
- Source PNGs are all **1024×1024**; the foreground PNG must have a **transparent** background; the full-tile and background PNGs are **opaque**.
- Brand gradient stops (verbatim): `#EE6A4E` at 0, `#E0533D` at 0.5, `#C53F29` at 1, along the top-left→bottom-right diagonal.
- `flutter analyze` must stay clean (no Dart changes, so this only confirms nothing else broke).
- Generated PNGs and the SVG wrappers are committed so the icons are reproducible.

---

### Task 1: Render the three source PNGs from the logo

**Files:**
- Create: `branding/icon_bg.svg` (gradient-only square)
- Create: `branding/icon_fg.svg` (white S on transparent)
- Create (rendered): `branding/icon_full_1024.png`, `branding/icon_bg_1024.png`, `branding/icon_fg_1024.png`

**Interfaces:**
- Consumes: existing `branding/spendwise_icon.svg`.
- Produces: the three 1024×1024 PNGs that Task 2's `flutter_launcher_icons` config references by path.

- [ ] **Step 1: Create `branding/icon_bg.svg`** (gradient fills the full square; no rounded corners, no S — the launcher mask handles the shape)

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <linearGradient id="tile" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#EE6A4E"/>
      <stop offset="0.5" stop-color="#E0533D"/>
      <stop offset="1" stop-color="#C53F29"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#tile)"/>
</svg>
```

- [ ] **Step 2: Create `branding/icon_fg.svg`** (white S at the logo's original geometry — it already sits inside Android's adaptive safe zone; farthest stroke extent ≈242px from centre vs a ≈312px safe radius — on a fully transparent background)

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <path d="M 648 360
           C 648 312 596 286 524 286
           C 442 286 392 330 392 388
           C 392 446 438 474 524 496
           C 610 518 656 546 656 606
           C 656 666 600 712 520 712
           C 446 712 392 684 388 628"
        fill="none" stroke="#ffffff" stroke-width="96"
        stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

- [ ] **Step 3: Render all three SVGs to 1024×1024 PNGs via the headless browser**

Using the Playwright MCP `browser_run_code_unsafe` tool, run (adjust the repo path if different; note `omitBackground: true` ONLY for the foreground):

```js
async (page) => {
  await page.setViewportSize({ width: 1024, height: 1024 });
  const base = 'file:///f:/SpendWise/branding/';
  // full tile — opaque
  await page.goto(base + 'spendwise_icon.svg');
  await page.screenshot({ path: 'f:/SpendWise/branding/icon_full_1024.png',
    clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  // gradient background — opaque
  await page.goto(base + 'icon_bg.svg');
  await page.screenshot({ path: 'f:/SpendWise/branding/icon_bg_1024.png',
    clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  // S foreground — transparent
  await page.goto(base + 'icon_fg.svg');
  await page.screenshot({ path: 'f:/SpendWise/branding/icon_fg_1024.png',
    clip: { x: 0, y: 0, width: 1024, height: 1024 }, omitBackground: true });
  return 'rendered';
}
```

- [ ] **Step 4: Verify dimensions and that the files are non-trivial**

Run: `cd f:/SpendWise && for f in branding/icon_full_1024.png branding/icon_bg_1024.png branding/icon_fg_1024.png; do echo "$f: $(identify -format '%wx%h' "$f") $(stat -c%s "$f") bytes"; done`
Expected: each reports `1024x1024` and a size of many kilobytes (not a few hundred bytes).

- [ ] **Step 5: Visual check (read each PNG and confirm)**

Read `branding/icon_full_1024.png`, `branding/icon_bg_1024.png`, `branding/icon_fg_1024.png` with the Read tool. Confirm:
- full = the rounded orange tile with the white S;
- bg = a full-bleed orange gradient square with square (un-rounded) corners;
- fg = a white S with the rest fully transparent (the Read preview shows a checkerboard/blank around the S).

If the foreground S looks too large (its stroke visually reaches the outer ~⅕ edge of the square) or too small (lost in the middle), adjust by wrapping the `<path>` in `branding/icon_fg.svg` with `transform="translate(512,512) scale(K) translate(-512,-512)"` (K≈0.85 to shrink, K≈1.1 to enlarge), re-render Step 3 for the foreground, and re-check. Default (no transform) is the expected correct result.

- [ ] **Step 6: Commit**

```bash
cd f:/SpendWise && git add branding/icon_bg.svg branding/icon_fg.svg branding/icon_full_1024.png branding/icon_bg_1024.png branding/icon_fg_1024.png && git commit -m "assets: render SpendWise launcher-icon source PNGs (full, adaptive bg, adaptive fg)"
```

---

### Task 2: Generate launcher icons with flutter_launcher_icons

**Files:**
- Modify: `pubspec.yaml` (add dev dependency + `flutter_launcher_icons` config block)
- Generated (committed): `android/app/src/main/res/mipmap-*/ic_launcher.png`, `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` + referenced drawables, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`

**Interfaces:**
- Consumes: the three PNGs from Task 1.
- Produces: the generated native icon assets referenced by the OS at install time.

- [ ] **Step 1: Add the dev dependency**

In `pubspec.yaml`, under `dev_dependencies:` (alongside `flutter_lints`, `drift_dev`, `build_runner`), add:

```yaml
  flutter_launcher_icons: ^0.14.1
```

- [ ] **Step 2: Add the generator config**

In `pubspec.yaml`, add a top-level block (after the `flutter:` section is fine; it must be at column 0, not nested under `flutter:`):

```yaml
flutter_launcher_icons:
  image_path: "branding/icon_full_1024.png"
  android: true
  ios: true
  adaptive_icon_background: "branding/icon_bg_1024.png"
  adaptive_icon_foreground: "branding/icon_fg_1024.png"
  remove_alpha_ios: true
  min_sdk_android: 21
```

- [ ] **Step 3: Fetch the package**

Run: `cd f:/SpendWise && flutter pub get`
Expected: resolves without error; `flutter_launcher_icons` appears in `pubspec.lock`.

- [ ] **Step 4: Generate the icons**

Run: `cd f:/SpendWise && dart run flutter_launcher_icons`
Expected: output ending in success (e.g. `✓ Successfully generated launcher icons`), no errors.

- [ ] **Step 5: Verify the generated assets exist and are real**

Run: `cd f:/SpendWise && echo "=== android mipmaps ===" && for f in android/app/src/main/res/mipmap-*/ic_launcher.png; do echo "$f: $(stat -c%s "$f") bytes"; done && echo "=== adaptive xml ===" && ls android/app/src/main/res/mipmap-anydpi-v26/ && echo "=== ios appiconset ===" && ls ios/Runner/Assets.xcassets/AppIcon.appiconset/ | head`
Expected: each `ic_launcher.png` is now several KB (not the ~500-byte defaults); `mipmap-anydpi-v26/` contains `ic_launcher.xml`; the iOS appiconset lists multiple generated PNGs.

- [ ] **Step 6: Visual check**

Read one representative generated icon, e.g. `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`, and confirm it shows the SpendWise logo (orange tile + white S), not the default Flutter icon.

- [ ] **Step 7: Confirm analyze is still clean**

Run: `cd f:/SpendWise && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
cd f:/SpendWise && git add pubspec.yaml pubspec.lock android/app/src/main/res ios/Runner/Assets.xcassets && git commit -m "feat: generate SpendWise launcher icons (Android adaptive + iOS) via flutter_launcher_icons"
```

---

### Task 3: Correct the app display name

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:3` (`android:label`)
- Modify: `ios/Runner/Info.plist` (`CFBundleDisplayName`, `CFBundleName`)

**Interfaces:**
- Consumes: nothing.
- Produces: the home-screen / switcher app name "SpendWise".

- [ ] **Step 1: Fix the Android label**

In `android/app/src/main/AndroidManifest.xml`, change:

```xml
        android:label="spendwise"
```
to:
```xml
        android:label="SpendWise"
```

- [ ] **Step 2: Fix the iOS display name and bundle name**

In `ios/Runner/Info.plist`, change the value under `CFBundleDisplayName` from `Spendwise` to `SpendWise`, and the value under `CFBundleName` from `spendwise` to `SpendWise`. Concretely, the two `<string>` lines become:

```xml
	<key>CFBundleDisplayName</key>
	<string>SpendWise</string>
```
and
```xml
	<key>CFBundleName</key>
	<string>SpendWise</string>
```

- [ ] **Step 3: Verify the exact strings**

Run: `cd f:/SpendWise && grep -n 'android:label' android/app/src/main/AndroidManifest.xml && grep -A1 'CFBundleDisplayName\|CFBundleName' ios/Runner/Info.plist`
Expected: `android:label="SpendWise"`, and both plist values read `SpendWise`.

- [ ] **Step 4: Commit**

```bash
cd f:/SpendWise && git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist && git commit -m "fix: correct app display name to SpendWise on Android and iOS"
```

---

## Final verification (after all tasks)

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → all 55 tests still pass (nothing here touches Dart, but confirm no regression).
- [ ] If the Android toolchain is available: `flutter build apk --debug` succeeds — the authoritative check that the icon config, adaptive XML, and manifest label are all valid. If unavailable, rely on the generator's success output + the asset/XML presence checks above.
- [ ] Manual (device/emulator, owed by the user): install and confirm the SpendWise icon and the name "SpendWise" appear on the home screen and app switcher, and that the adaptive icon looks correct under a circular mask.
