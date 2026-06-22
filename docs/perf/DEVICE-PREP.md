# Device Prep — dony Perf Harness

Follow these steps before running `scripts/perf.sh`. Skip steps you have already completed.

---

## 1. Android Emulator — GPU + RAM

Open your AVD in Android Studio (or `~/.android/avd/<name>.avd/config.ini`) and set:

```
hw.gpu.mode=host
hw.ramSize=4096
```

Restart the AVD after saving. Using `host` GPU prevents the compositing-layer freeze
that occurs with software rendering on complex Flutter widgets (InteractiveViewer,
Opacity, RepaintBoundary).

> For WSL2 users: `hw.gpu.mode=host` requires a Windows host with Hyper-V acceleration.
> If unavailable, use a physical Android device instead (recommended for accurate numbers).

---

## 2. First-Run Sign-In + PIN

Run the app once in non-profile mode to persist auth and PIN:

```bash
flutter run --dart-define-from-file=env.dev.json
```

Inside the app:
1. Sign in with the test Firebase account (phone + OTP via emulator or test number).
2. When prompted for PIN setup, enter `123456`. This PIN is stored in
   `flutter_secure_storage` and reused by the perf scenarios without re-prompting.

You only need to do this once per device/emulator wipe.

---

## 3. Verify the Device is Visible

```bash
flutter devices
```

You should see your emulator or physical device listed. Note its device ID if you
have multiple devices connected (pass `-d <id>` to `flutter drive` if needed).

---

## 4. Run the Harness

```bash
bash scripts/perf.sh
# Or with a custom env file:
bash scripts/perf.sh env.staging.json
```

This will:
1. Run `integration_test/perf/perf_scenarios_test.dart` in `--profile` mode.
2. Run `integration_test/perf/stress_scenarios_test.dart` in `--profile` mode.
3. Generate `reports/perf-report.md` (FPS / jank per scenario).
4. Generate `reports/network-report.md` (static network anti-pattern audit).
5. Generate `reports/waterfall-report.md` (sequential network chain detection).
6. Generate `reports/PRODUCTION-READINESS.md` (consolidated report assembling all sub-reports).

---

## Emulator vs Real Device Caveat

| Metric | Emulator reliability | Real device |
|--------|---------------------|-------------|
| FAIL verdict (jank > threshold) | Reliable | Reliable |
| PASS / WARN verdicts | Unreliable — too slow or too fast | Required for confirmation |
| Network timing | Not representative | Required for waterfall detection |

**Rule:** use the emulator to catch regressions (FAIL is trustworthy). Always
re-confirm PASS/WARN results on a real device before marking a perf story complete.

---

## Waterfall Detection

The `tool/waterfall.dart` tool detects sequential network chains from raw per-request
samples in `build/perf/raw-<scenario>.json`. Raw sample emission is wired: the
`dumpNetwork` helper emits both aggregated metrics and raw per-request samples, which
`waterfall.dart` reads from `build/perf/raw-<scenario>.json`. This step is run
automatically by `scripts/perf.sh` — no manual invocation needed.

To run it standalone:

```bash
dart run tool/waterfall.dart
```
