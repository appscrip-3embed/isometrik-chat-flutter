#!/usr/bin/env bash
# Runs the whole test suite with coverage and enforces the business-logic
# coverage gate (see tool/coverage.dart for what is in scope).
#
#   tool/coverage.sh            # gate at 100%
#   MIN=90 tool/coverage.sh     # custom threshold
#   tool/coverage.sh --all      # also list fully covered files
set -euo pipefail
cd "$(dirname "$0")/.."

# TEST_PATHS (optional, space separated) limits the run to some test files.
# shellcheck disable=SC2086
flutter test --coverage -r failures-only ${TEST_PATHS:-}
dart run tool/coverage.dart coverage/lcov.info --min="${MIN:-100}" "$@"
