#!/usr/bin/env bash
# Import, run every test, then export the Web preset: the steps the Pages workflow runs.
# Usage: tools/web_build.sh <godot binary> <output folder>
# Run from the project root. Stops at the first failing step.
set -euo pipefail

godot="$1"
out="$2"
mkdir -p build "$out"
touch build/.gdignore

echo "== import"
"$godot" --headless --path . --import 2>&1 | tee "$out.import.log"
if grep -q 'ERROR:' "$out.import.log"; then
	echo "The import printed errors." >&2
	exit 1
fi

echo "== story test"
"$godot" --headless --path . -s tests/story_test.gd
echo "== flow test"
"$godot" --headless --path . -s tests/flow_test.gd
echo "== route test"
"$godot" --headless --path . --fixed-fps 60 -s tests/route_test.gd
echo "== content test"
"$godot" --headless --path . -s tests/content_test.gd
echo "== contrast test"
"$godot" --headless --path . -s tests/contrast_test.gd
echo "== spacing test"
"$godot" --headless --path . -s tests/spacing_test.gd

echo "== export"
"$godot" --headless --path . --export-release Web "$out/index.html"
for file in index.html index.wasm index.pck index.js; do
	if [ ! -s "$out/$file" ]; then
		echo "The export did not write $file." >&2
		exit 1
	fi
done
echo "== built $out"
