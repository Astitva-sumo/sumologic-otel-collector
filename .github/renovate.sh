#!/usr/bin/env bash
set -e

# This script updates version references in project files based on the latest commit message.
# Usage:
#   ./renovate.sh [--dry-run] [--msg "Updated from va.b.c to vx.y.z"]
# Options:
#   --dry-run   Only print extracted versions, do not modify any files.
#   --msg       Provide a custom commit message instead of using the latest git commit.

DRY_RUN=0
MSG_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --msg)
            MSG_ARG="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Extract versions from latest commit message
if [[ -n "$MSG_ARG" ]]; then
    msg="$MSG_ARG"
else
    msg="$(git log -1 --pretty=%B)"
fi
echo "$msg"
FROM_VER="$(echo "$msg" | sed -n 's/.*Updated from v\([0-9.]*\) to v[0-9.]*.*/\1/p')"
TO_VER="$(echo "$msg" | sed -n 's/.*Updated from v[0-9.]* to v\([0-9.]*\).*/\1/p')"

if [[ -z "$FROM_VER" || -z "$TO_VER" ]]; then
    echo "ERROR: Commit message not in expected format: 'Updated from va.b.c to vx.y.z'"
    exit 1
fi

echo "FROM_VER=$FROM_VER"
echo "TO_VER=$TO_VER"

# If dry run, exit after printing versions
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Dry run enabled. No files will be changed."
    exit 0
fi

# Update version references in otelcol-builder.yaml
yq e ".dist.version = \"${TO_VER}\"" -i otelcolbuilder/.otelcol-builder.yaml
yq -i '(.. | select(tag=="!!str")) |= sub("(go\.opentelemetry\.io/collector.*) v'"${FROM_VER}"'", "$1 v'"${TO_VER}"'")' otelcolbuilder/.otelcol-builder.yaml
yq -i '(.. | select(tag=="!!str")) |= sub("(github\.com/open-telemetry/opentelemetry-collector-contrib.*) v'"${FROM_VER}"'", "$1 v'"${TO_VER}"'")' otelcolbuilder/.otelcol-builder.yaml

# Update version references in otelcol-builder Makefile and all other md files
sed -i "s/${FROM_VER}/${TO_VER}/" otelcolbuilder/Makefile
sed -i "s/\(collector\/\(blob\|tree\)\/v\)${FROM_VER}/\1${TO_VER}/" \
    README.md \
    docs/configuration.md \
    docs/migration.md \
    docs/performance.md
sed -i "s/\(contrib\/\(blob\|tree\)\/v\)${FROM_VER}/\1${TO_VER}/" \
    README.md \
    docs/configuration.md \
    docs/migration.md \
    docs/performance.md \
    pkg/receiver/telegrafreceiver/README.md
