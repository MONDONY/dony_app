#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/perf.sh [env-file]
# Default env file: env.dev.json
#
# Runs the Flutter perf + stress integration suites in --profile mode,
# then generates the markdown reports.

ENV="${1:-env.dev.json}"

echo "=== dony perf harness ==="
echo "Env file: $ENV"
echo ""

echo "--- [1/4] Perf scenarios ---"
flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf/perf_scenarios_test.dart \
  --profile \
  --dart-define-from-file="$ENV"

echo ""
echo "--- [2/4] Stress scenarios ---"
flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf/stress_scenarios_test.dart \
  --profile \
  --dart-define-from-file="$ENV"

echo ""
echo "--- [3/4] Parse timeline + FPS report ---"
dart run tool/parse_timeline.dart

echo ""
echo "--- [4/5] Network audit report ---"
dart run tool/network_audit.dart

echo ""
echo "--- [5/5] Waterfall detection ---"
dart run tool/waterfall.dart

echo ""
echo "Rapports: reports/perf-report.md, reports/network-report.md, reports/waterfall-report.md"
