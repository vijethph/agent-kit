#!/usr/bin/env bash
# Writes the resolved version into pyproject.toml and Chart.yaml.
# Usage: set-versions.sh <app-version> [chart-version]
set -euo pipefail

APP_VERSION="$1"
CHART_VERSION="${2:-$1}"
CHART_FILE="helm/testapp/Chart.yaml"

python - "$APP_VERSION" <<'PY'
import re, sys, pathlib
v = sys.argv[1]
p = pathlib.Path("pyproject.toml")
s = p.read_text()
s = re.sub(r'(?m)^version\s*=\s*".*"$', f'version = "{v}"', s, count=1)
p.write_text(s)
PY

# Chart.yaml: `version` must be SemVer; `appVersion` is a free-form string.
sed -i -E "s|^version:.*|version: ${CHART_VERSION}|"        "$CHART_FILE"
sed -i -E "s|^appVersion:.*|appVersion: \"${APP_VERSION}\"|" "$CHART_FILE"

echo "--- pyproject.toml ---"; grep -m1 '^version' pyproject.toml
echo "--- ${CHART_FILE} ---";  grep -E '^(version|appVersion):' "$CHART_FILE"
