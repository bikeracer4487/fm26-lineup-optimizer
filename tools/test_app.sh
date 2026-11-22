#!/bin/bash
# Run the app's tests from an optimized build, which is about twelve times quicker than
# `swift test` in LineupApp.
#
#   tools/test_app.sh                           run from the repository root; every test
#   tools/test_app.sh --filter ScoutingTests    one suite or test, as `swift test --filter` takes it
#
# Any other argument is passed to `swift test` as it is.
#
# Why it is quicker. Most of the app's tests plan, and a plan of the sample squad takes about
# 0.9 seconds in an unoptimized build of the engine and under 0.1 optimized. Every suite runs on
# the main actor, so the tests run one at a time and that cost is paid in full: 973 tests took
# 470 seconds unoptimized and 40 from this script on 22 November 2026. The same tests run, and
# nothing about them is changed.
#
# How. The debug configuration with the compiler's optimizer switched on (-O) for the engine,
# the app's code and the tests. It is still a debug build, so `@testable import` works and
# files are compiled one by one: after a change the rebuild takes seconds. (A release build
# ran the tests no faster and took over a minute to rebuild after a change to one test.)
#
# The build is kept in LineupApp/.build/tests, apart from the unoptimized build that `swift
# test`, `swift run` and the picture runs use and from the release build tools/build_app.sh
# installs, so none of them makes another build again. The first run builds everything, which
# took 42 seconds, and then runs the tests.
#
# `cd LineupApp && swift test` still works and is the unoptimized run: slower, and with the
# assertions an optimized build leaves out. Run it once before work is called finished.
set -euo pipefail

ROOT="$(pwd)"
if [ ! -f "$ROOT/LineupApp/Package.swift" ]; then
    echo "Run this from the repository root: LineupApp/Package.swift is not in $ROOT." >&2
    exit 1
fi

exec swift test --package-path "$ROOT/LineupApp" --scratch-path "$ROOT/LineupApp/.build/tests" \
    -Xswiftc -O "$@"
