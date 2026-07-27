# New Splash Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the native and Flutter splash visuals with the new dony app icon and horizontal logo while keeping the existing startup behavior responsive on iOS and Android.

**Architecture:** Generate deterministic, splash-specific PNG derivatives from the source branding files, then let `flutter_launcher_icons` and `flutter_native_splash` produce the platform resources. Keep startup and routing logic inside the existing `SplashScreen`; only extract its responsive visual composition into a focused private widget that can be exercised by widget tests.

**Tech Stack:** Flutter/Dart, Material 3, `flutter_native_splash`, `flutter_launcher_icons`, `flutter_animate`, Pillow for deterministic image preprocessing, `flutter_test`.

## Global Constraints

- Preserve the existing health check, authentication resolution, retry behavior, and GoRouter destinations.
- Use a uniform `#FFFFFF` background for the native splash and first Flutter frame.
- Use `assets/new_assets/app-icon.png` for the launcher icon and native splash derivative.
- Use `assets/new_assets/logo-name.png` for the Flutter splash derivative.
- Preserve image aspect ratios and Android 12 mask-safe margins.
- Support small phones, tall phones, tablets, large text, display cutouts, and reduced motion.
- Keep `Livrez vos colis en confiance`, `v1.0.0`, loading dots, connection error, and `Réessayer`.
- Do not add a custom analytics event because no business action is added and `/splash` remains automatically tracked.

---

### Task 1: Deterministic Brand Asset Derivatives

**Files:**
- Create: `tool/generate_new_brand_assets.py`
- Create: `assets/splash/app_icon_native.png`
- Create: `assets/splash/app_icon_android12.png`
- Create: `assets/splash/logo_name.png`
- Modify: `assets/logos/app_icon_source.png`
- Modify: `pubspec.yaml:153-185`

**Interfaces:**
- Consumes: `assets/new_assets/app-icon.png` and `assets/new_assets/logo-name.png`.
- Produces: opaque 1024x1024 launcher source, native splash image, Android 12 mask-safe image, and transparent tightly cropped horizontal Flutter logo.

- [ ] **Step 1: Add the asset generator**

Create `tool/generate_new_brand_assets.py` with Pillow. It must:

```python
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "new_assets"
SPLASH = ROOT / "assets" / "splash"
LOGOS = ROOT / "assets" / "logos"
WHITE = (255, 255, 255, 255)


def trim_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("Image source entièrement transparente")
    return rgba.crop(bbox)


def contain(image: Image.Image, size: int, inset: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), WHITE)
    content_size = size - (inset * 2)
    fitted = image.copy()
    fitted.thumbnail((content_size, content_size), Image.Resampling.LANCZOS)
    x = (size - fitted.width) // 2
    y = (size - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def main() -> None:
    SPLASH.mkdir(parents=True, exist_ok=True)
    icon = Image.open(SOURCE / "app-icon.png").convert("RGBA")
    logo = trim_alpha(Image.open(SOURCE / "logo-name.png"))

    contain(icon, 1024, 0).convert("RGB").save(
        LOGOS / "app_icon_source.png", optimize=True
    )
    contain(icon, 1024, 96).save(SPLASH / "app_icon_native.png", optimize=True)
    contain(icon, 1152, 288).save(
        SPLASH / "app_icon_android12.png", optimize=True
    )

    logo.thumbnail((1200, 420), Image.Resampling.LANCZOS)
    logo.save(SPLASH / "logo_name.png", optimize=True)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Generate the derivatives**

Run:

```bash
python3 tool/generate_new_brand_assets.py
```

Expected: the four output files exist, `logo_name.png` has alpha, and every square icon derivative has a white corner pixel.

- [ ] **Step 3: Validate dimensions and color modes**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
from PIL import Image

expected = {
    "assets/logos/app_icon_source.png": ((1024, 1024), "RGB"),
    "assets/splash/app_icon_native.png": ((1024, 1024), "RGBA"),
    "assets/splash/app_icon_android12.png": ((1152, 1152), "RGBA"),
}
for path, value in expected.items():
    image = Image.open(Path(path))
    assert (image.size, image.mode) == value, (path, image.size, image.mode)
logo = Image.open("assets/splash/logo_name.png")
assert logo.mode == "RGBA"
assert logo.width > logo.height
print("brand assets valid")
PY
```

Expected: `brand assets valid`.

- [ ] **Step 4: Point Flutter generators and runtime assets to the derivatives**

In `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logos/app_icon_source.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/logos/app_icon_source.png"

flutter_native_splash:
  color: "#FFFFFF"
  image: assets/splash/app_icon_native.png
  android_12:
    color: "#FFFFFF"
    icon_background_color: "#FFFFFF"
    image: assets/splash/app_icon_android12.png
  ios: true
  android: true

flutter:
  assets:
    - assets/splash/
```

Keep the existing asset declarations and add `assets/splash/`; do not bundle `.DS_Store`.

- [ ] **Step 5: Resolve dependencies and check configuration**

Run:

```bash
flutter pub get
dart format tool/generate_new_brand_assets.py
```

Expected: dependency resolution succeeds. If Dart rejects the Python formatter target, format only Dart files later; the Python script must remain PEP 8 formatted.

- [ ] **Step 6: Commit the asset pipeline**

```bash
git add tool/generate_new_brand_assets.py assets/logos/app_icon_source.png assets/splash/app_icon_native.png assets/splash/app_icon_android12.png assets/splash/logo_name.png pubspec.yaml pubspec.lock
git commit -m "chore: prepare new dony brand assets"
```

### Task 2: Native Splash and Launcher Resources

**Files:**
- Modify: generated files under `android/app/src/main/res/`
- Modify: generated files under `ios/Runner/Assets.xcassets/`
- Modify: `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- Modify: generated launcher icon resources for Android, iOS, and web

**Interfaces:**
- Consumes: paths and colors declared in `pubspec.yaml`.
- Produces: native startup screens and launcher icons used before the Flutter engine renders.

- [ ] **Step 1: Generate launcher icons**

Run:

```bash
dart run flutter_launcher_icons
```

Expected: command exits successfully and platform launcher resources contain the new blue parcel icon.

- [ ] **Step 2: Generate native splash resources**

Run:

```bash
dart run flutter_native_splash:create
```

Expected: command exits successfully; Android styles use `#FFFFFF`, Android 12 references the generated icon, and iOS LaunchScreen references the new splash image.

- [ ] **Step 3: Verify generated platform references**

Run:

```bash
rg -n "windowSplashScreenBackground|windowSplashScreenAnimatedIcon|splashBackground" android/app/src/main/res
rg -n "LaunchImage|LaunchScreen" ios/Runner
```

Expected: Android 12 uses the generated `android12splash` resource on white and iOS keeps `LaunchScreen` as the launch storyboard.

- [ ] **Step 4: Inspect representative generated PNGs**

Open the Android 12 splash icon, one Android mipmap, the iOS launch image, and one iOS AppIcon image. Confirm:

- the parcel remains fully visible;
- no system mask cuts the parcel or orange band;
- no off-white rectangle appears on the white background;
- the launcher icon is legible at small size.

- [ ] **Step 5: Commit generated native resources**

```bash
git add android/app/src/main/res ios/Runner ios/Runner.xcworkspace web
git commit -m "feat: update native splash and app icon"
```

Only stage paths actually changed by the two generators.

### Task 3: Responsive Flutter Splash Composition

**Files:**
- Create: `test/features/splash/presentation/splash_screen_test.dart`
- Modify: `lib/features/splash/presentation/splash_screen.dart:134-282`

**Interfaces:**
- Consumes: `assets/splash/logo_name.png`, the current theme, `MediaQuery`, and `_hasError`.
- Produces: `_SplashContent({required bool hasError, required VoidCallback onRetry})`, preserving all startup methods unchanged.

- [ ] **Step 1: Write failing responsive widget tests**

Create `test/features/splash/presentation/splash_screen_test.dart`. Pump `_SplashContent` through a public test seam named `SplashContent` annotated `@visibleForTesting`:

```dart
testWidgets('fits a small screen with large text', (tester) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(body: SplashContent(hasError: false)),
      ),
    ),
  );

  expect(find.byKey(const Key('splash-brand-logo')), findsOneWidget);
  expect(find.text('Livrez vos colis en confiance'), findsOneWidget);
  expect(tester.takeException(), isNull);
});

testWidgets('caps the logo width on a tablet', (tester) async {
  tester.view.physicalSize = const Size(1024, 1366);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: SplashContent(hasError: false)),
    ),
  );

  final size = tester.getSize(find.byKey(const Key('splash-brand-logo')));
  expect(size.width, lessThanOrEqualTo(560));
  expect(tester.takeException(), isNull);
});

testWidgets('shows a reachable retry action in error state', (tester) async {
  var retried = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SplashContent(
          hasError: true,
          onRetry: () => retried = true,
        ),
      ),
    ),
  );

  await tester.tap(find.text('Réessayer'));
  expect(retried, isTrue);
  expect(find.text('Impossible de se connecter'), findsOneWidget);
});
```

`SplashContent.onRetry` defaults to a no-op so the const loading-state examples compile.

- [ ] **Step 2: Run the new tests and verify failure**

Run:

```bash
flutter test test/features/splash/presentation/splash_screen_test.dart
```

Expected: FAIL because `SplashContent` does not exist.

- [ ] **Step 3: Implement the responsive composition**

In `splash_screen.dart`:

- keep `_checkAndNavigate`, `_navigateNext`, and `_retry` unchanged;
- set the `Scaffold` background to `const Color(0xFFFFFFFF)`;
- replace the current `Stack` body with:

```dart
SplashContent(hasError: _hasError, onRetry: _retry)
```

Implement:

```dart
@visibleForTesting
class SplashContent extends StatelessWidget {
  const SplashContent({
    required this.hasError,
    this.onRetry = _noop,
    super.key,
  });

  final bool hasError;
  final VoidCallback onRetry;

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logoWidth =
              (constraints.maxWidth * 0.78).clamp(240.0, 560.0);
          final availableLogoHeight =
              (constraints.maxHeight * 0.30).clamp(112.0, 260.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.xl,
              vertical: DonySpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - (DonySpacing.xl * 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/splash/logo_name.png',
                    key: const Key('splash-brand-logo'),
                    width: logoWidth,
                    height: availableLogoHeight,
                    fit: BoxFit.contain,
                    semanticLabel: 'dony',
                  ),
                  const SizedBox(height: DonySpacing.xxl),
                  Text(
                    'Livrez vos colis en confiance',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  const Text('v1.0.0', textAlign: TextAlign.center),
                  const SizedBox(height: DonySpacing.xxl),
                  if (hasError)
                    _SplashError(onRetry: onRetry)
                  else
                    _LoadingDots(disableAnimation: reduceMotion),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

Apply the existing typography colors. Add `flutter_animate` fade/slide effects only when `reduceMotion == false`; return the unanimated child otherwise. Move the existing error UI into `_SplashError` and ensure `OutlinedButton.icon` has a minimum height of 44.

- [ ] **Step 4: Make loading dots respect reduced motion**

Change `_LoadingDots` to:

```dart
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.disableAnimation});

  final bool disableAnimation;
```

Build each dot normally and return it directly when `disableAnimation` is true. Otherwise retain the existing repeating scale and fade animation.

- [ ] **Step 5: Run focused tests**

Run:

```bash
dart format lib/features/splash/presentation/splash_screen.dart test/features/splash/presentation/splash_screen_test.dart
flutter test test/features/splash/presentation/splash_screen_test.dart
flutter analyze lib/features/splash/presentation/splash_screen.dart test/features/splash/presentation/splash_screen_test.dart
```

Expected: formatting succeeds, all splash tests pass, and analysis reports no issue.

- [ ] **Step 6: Run broader verification**

Run:

```bash
flutter test
flutter analyze
```

Expected: all tests pass and analysis introduces no new issue. Report pre-existing failures separately without changing unrelated code.

- [ ] **Step 7: Perform visual viewport checks**

Launch the app or a test harness and capture these logical viewports:

- 320x568 with text scale 2.0;
- 390x844 with text scale 1.0;
- 1024x1366 with text scale 1.0;
- 390x844 with animations disabled;
- error state at 320x568.

Confirm no overflow, centered logo, readable copy, visible loading/error state, and a smooth white transition from the native splash.

- [ ] **Step 8: Commit the Flutter splash**

```bash
git add lib/features/splash/presentation/splash_screen.dart test/features/splash/presentation/splash_screen_test.dart
git commit -m "feat: refresh responsive Flutter splash"
```

### Task 4: Final Consistency Review

**Files:**
- Verify: `CLAUDE.md`
- Verify: `lib/app/router.dart`
- Verify: all files changed on `feature/new-splash-branding`

**Interfaces:**
- Consumes: all outputs from Tasks 1-3.
- Produces: a review-ready branch with no unrelated files staged.

- [ ] **Step 1: Verify analytics and routing remain unchanged**

Run:

```bash
git diff main...HEAD -- lib/app/router.dart CLAUDE.md lib/core/services/analytics_events.dart
```

Expected: no changes. The existing `/splash` automatic screen tracking is sufficient.

- [ ] **Step 2: Review the complete diff**

Run:

```bash
git status --short
git diff --check main...HEAD
git diff --stat main...HEAD
```

Expected: no whitespace errors and no unrelated local files staged or committed.

- [ ] **Step 3: Confirm platform deliverables**

Verify the final branch contains:

- new launcher resources for Android and iOS;
- native splash resources for pre-Android 12, Android 12+, and iOS;
- responsive Flutter logo splash;
- focused widget coverage;
- the reproducible image generator and its source-independent derivatives.
