#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/perf.sh [env-file]
# Default env file: env.dev.json
#
# Runs the Flutter perf + stress integration suites in --profile mode,
# then generates the markdown reports.
#
# The two flutter drive steps are non-fatal: if a drive partially fails the
# report-generation steps still run so partial data is not lost.

ENV="${1:-env.dev.json}"

echo "=== dony perf harness ==="
echo "Env file: $ENV"
echo ""

echo "--- [1/6] Perf scenarios ---"
flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf/perf_scenarios_test.dart \
  --profile \
  --dart-define-from-file="$ENV" \
  || echo "[warn] drive perf_scenarios failed; continuing with report generation"

echo ""
echo "--- [2/6] Stress scenarios ---"
flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf/stress_scenarios_test.dart \
  --profile \
  --dart-define-from-file="$ENV" \
  || echo "[warn] drive stress_scenarios failed; continuing with report generation"

echo ""
echo "--- [3/6] Parse timeline + FPS report ---"
dart run tool/parse_timeline.dart

echo ""
echo "--- [4/6] Network audit report ---"
dart run tool/network_audit.dart

echo ""
echo "--- [5/6] Waterfall detection ---"
dart run tool/waterfall.dart

echo ""
echo "--- [6/6] Assemble production-readiness report ---"
dart run tool/build_readiness_report.dart

echo ""
echo "Rapports: reports/perf-report.md, reports/network-report.md, reports/waterfall-report.md, reports/PRODUCTION-READINESS.md"
