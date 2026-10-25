#!/usr/bin/env bash
# Import, run every test, then export the Web preset: the steps the Pages workflow runs.
# Usage: tools/web_build.sh <godot binary> <output folder>
# Run from the project root. Stops at the first failing step.
set -euo pipefail

godot="$1"
out="$2"
mkdir -p build "$out"
touch build/.gdignore

echo "== first import, unchecked"
# On a machine with no Godot editor settings yet (a fresh CI runner), the first
# import creates them, and Dialogue Manager's editor theme reads its font size
# before it exists, printing errors that do not touch the game. The checked
# import below runs with the settings in place.
"$godot" --headless --path . --import > /dev/null 2>&1 || true

echo "== import"
"$godot" --headless --path . --import 2>&1 | tee "$out.import.log"
if grep -q 'ERROR:' "$out.import.log"; then
	echo "The import printed errors." >&2
	exit 1
fi

# Godot exits 0 when a test script fails to compile, so a script error fails the step too.
run_test() {
	echo "== $1"
	shift
	"$godot" --headless --path . "$@" 2>&1 | tee "$out.test.log"
	local status=${PIPESTATUS[0]}
	if [ "$status" -ne 0 ] || grep -q 'SCRIPT ERROR' "$out.test.log"; then
		echo "The test failed." >&2
		exit 1
	fi
}

run_test "story test" -s tests/story_test.gd
run_test "flow test" -s tests/flow_test.gd
run_test "route test" --fixed-fps 60 -s tests/route_test.gd
run_test "content test" -s tests/content_test.gd
run_test "contrast test" -s tests/contrast_test.gd
run_test "spacing test" -s tests/spacing_test.gd
run_test "sound test" -s tests/sound_test.gd
run_test "controls test" -s tests/controls_test.gd

echo "== export"
"$godot" --headless --path . --export-release Web "$out/index.html"
for file in index.html index.wasm index.pck index.js; do
	if [ ! -s "$out/$file" ]; then
		echo "The export did not write $file." >&2
		exit 1
	fi
done
echo "== built $out"
