#!/bin/bash
# Puts a Godot binary on PATH so the smoke suites can run in this session.
#
# Without one, the only local check is gdparse, which reads syntax and nothing
# else: an undeclared identifier, a renamed method, a wrong argument count and a
# stale test assumption all parse clean and all fail in the engine. Every one of
# those then costs a push and a CI round. The suites take about a minute all
# told, so having the engine here turns most of those rounds into seconds.
set -euo pipefail

# Web sessions start from a fresh container; a local checkout has its own Godot.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

# The workflow holds a prefix — GODOT_VERSION: "4.6" — and asks the releases
# API for the newest build matching it. This cannot (see install_engine), so it
# names one build outright. Bump it when that resolution moves on, or the engine
# here drifts behind the one the push is checked against.
readonly VERSION="4.6.3-stable"
readonly WANT="4.6.3.stable.official"
readonly DIR="$HOME/godot-bin"
readonly BIN="$DIR/godot"

say() { printf '  %s\n' "$*" >&2; }

# Why that version is pinned rather than resolved: the releases API is not
# reachable from a session container — it answers 403 for any repository the
# session holds no grant on, godotengine/godot among them — while the release
# *download* path is. So the URL is built by hand out of one version string.
install_engine() {
	local url="https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
	local zip
	zip="$(mktemp -t godot-XXXXXX.zip)"
	say "fetching Godot ${VERSION}"
	if ! curl -fsSL --retry 3 --retry-delay 2 -o "$zip" "$url"; then
		rm -f "$zip"
		say "could not download the engine — gdparse and tools/check_tabs.py still work,"
		say "and the push will still be checked by .github/workflows/tests.yml"
		return 1
	fi
	mkdir -p "$DIR"
	unzip -qq -j -o "$zip" -d "$DIR"
	# The zip holds one binary under a version-stamped name.
	mv "$DIR"/Godot_v*_linux.x86_64 "$BIN"
	chmod +x "$BIN"
	# Deleted straight away: session disk is a fixed allowance and this is 70MB
	# of it that has already served its purpose.
	rm -f "$zip"
}

# Idempotent, and cheap on a cached container: an engine already here at the
# right version is left alone.
if [ -x "$BIN" ] && "$BIN" --headless --version 2>/dev/null | grep -q "$WANT"; then
	say "Godot $("$BIN" --headless --version 2>/dev/null | head -1) already installed"
else
	rm -f "$BIN"
	install_engine || true
fi

# gdparse and gdlint come with the image today. Installed here anyway so the hook
# does not quietly stop being enough if that changes.
if ! command -v gdparse >/dev/null 2>&1; then
	say "installing gdtoolkit for gdparse and gdlint"
	pip3 install --quiet gdtoolkit==4.5.0 || say "gdtoolkit install failed — skipping"
fi

if [ ! -x "$BIN" ]; then
	exit 0
fi

echo "export GODOT=\"$BIN\"" >> "$CLAUDE_ENV_FILE"
echo "export PATH=\"$DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# Imported now rather than on the first test run, which otherwise pays twelve
# seconds for it and prints a wall of progress over the first checks. The first
# pass is allowed to fail the way the workflow allows it: on a cold project it
# exits non-zero having still done most of the work, and the second pass settles
# it.
cd "$CLAUDE_PROJECT_DIR"
say "importing the project"
"$BIN" --headless --path . --import >/dev/null 2>&1 || true
"$BIN" --headless --path . --import >/dev/null 2>&1 || say "import reported a problem"

cat <<INFO
Godot $VERSION is on PATH as \`godot\` (also \$GODOT), and the project is imported.

Run the checks the way CI does, in this order — the first two are fast and catch
most mistakes, the suites are the only thing that catches the rest:

    python3 tools/check_tabs.py
    gdparse <file>.gd
    godot --headless --path . --script res://tests/web_smoke_test.gd    # ~31s
    godot --headless --path . --script res://tests/climb_smoke_test.gd  # ~26s
    godot --headless --path . --script res://tests/world_smoke_test.gd  # ~7s

Each suite prints a line per check and exits non-zero if any fail.
INFO
