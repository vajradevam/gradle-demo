#!/usr/bin/env bash
#
# bootstrap.sh — clone gradle-demo (optional) and verify SYSTEM gradle works.
#
# This script deliberately uses the SYSTEM `gradle` binary, never ./gradlew.
# There is no wrapper checked into the repo yet. The script generates it
# on the machine where the project was cloned via `gradle wrapper`.
#
# How Gradle knows "this is the project":
#   You don't register the project anywhere. Just `cd` into the folder that
#   contains `settings.gradle` + `build.gradle`. Whatever `gradle <task>`
#   you run from there automatically uses that folder as the project root.
#   Running `gradle wrapper` in that folder writes gradlew / gradlew.bat /
#   gradle/wrapper/ right there, bound to your system Gradle version.
#
# Usage:
#   # 1) Fresh machine, no clone yet (does clone + check + wrapper init):
#   bash bootstrap.sh --clone [target-dir]
#   # e.g. bash <(curl -fsSL https://raw.githubusercontent.com/vajradevam/gradle-demo/main/bootstrap.sh) --clone
#
#   # 2) Already cloned (just check + wrapper init, run from project root):
#   ./bootstrap.sh
#
set -euo pipefail

REPO_URL="https://github.com/vajradevam/gradle-demo.git"
DEFAULT_DIR="gradle-demo"

MODE="local"
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --clone) MODE="clone" ;;
    -h|--help)
      sed -n '2,/^set /p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) TARGET="$arg" ;;
  esac
done

pass() { printf '  [PASS] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

# --- 1. Clone if asked (or if we are clearly NOT inside the project) ---
if [ "$MODE" = "clone" ]; then
  TARGET="${TARGET:-$DEFAULT_DIR}"
  if [ -e "$TARGET" ]; then
    fail "'$TARGET' already exists. rm -rf it, or cd into it and run ./bootstrap.sh"
  fi
  info "Cloning $REPO_URL into $TARGET ..."
  git clone "$REPO_URL" "$TARGET"
  cd "$TARGET"
else
  # local mode: make sure we are at the project root
  if [ ! -f "settings.gradle" ] || [ ! -f "build.gradle" ]; then
    cat >&2 <<EOF
Not at the project root (no settings.gradle + build.gradle here).
Either:
  cd gradle-demo && ./bootstrap.sh
or:
  bash bootstrap.sh --clone [target-dir]
EOF
    exit 1
  fi
fi

echo
info "Project root: $(pwd)"
ls settings.gradle build.gradle >/dev/null \
  && pass "project detected (settings.gradle + build.gradle present — no registration needed, gradle uses the current directory)"

# --- 2. Check SYSTEM gradle (explicitly NOT ./gradlew) ---
echo
info "Checking system toolchain (git / java / gradle) ..."
command -v git >/dev/null    || fail "git not found on PATH"
pass "$(git --version)"
command -v java >/dev/null   || fail "java not found on PATH"
pass "$(java -version 2>&1 | head -n 1)"
command -v gradle >/dev/null || fail "'gradle' not found on PATH — install system Gradle 9.x first (this script tests SYSTEM gradle, not the wrapper)"
pass "system gradle binary: $(command -v gradle)"

info "Running 'gradle --version' (proves system gradle launches) ..."
gradle --version || fail "system 'gradle --version' failed"
pass "system gradle launches"

# --- 3. Prove system gradle can build THIS project ---
echo
info "Building with SYSTEM gradle: 'gradle build' ..."
gradle build || fail "'gradle build' failed with system gradle"
pass "system gradle built the project (BUILD SUCCESSFUL)"

# --- 4. Init the wrapper ON THIS MACHINE with the system gradle ---
echo
info "Initialising the wrapper on this machine: 'gradle wrapper' ..."
gradle wrapper || fail "'gradle wrapper' failed"
pass "wrapper generated: gradlew + gradlew.bat + gradle/wrapper/"

echo
info "Verifying the freshly generated wrapper ..."
test -x gradlew || fail "gradlew was not created/executable"
pass "gradlew exists and is executable"
./gradlew --version || fail "'./gradlew --version' failed"
pass "wrapper launches (bound to $(grep -h distributionUrl gradle/wrapper/gradle-wrapper.properties 2>/dev/null || echo 'see gradle/wrapper/gradle-wrapper.properties'))"

echo
echo "ALL DONE. Summary:"
echo "  - Cloned/used project at: $(pwd)"
echo "  - System gradle works:    yes (gradle build passed)"
echo "  - Wrapper initialised:    yes (gradlew now exists on THIS machine)"
echo "  - From here use either:   gradle <task>   (system gradle)"
echo "                            ./gradlew <task> (pinned wrapper gradle)"
