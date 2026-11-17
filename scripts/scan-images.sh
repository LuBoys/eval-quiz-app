#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo 'Usage : scripts/scan-images.sh IMAGE [IMAGE ...]' >&2
  exit 2
fi

scan_dir=$(mktemp -d)
trap 'rm -rf "$scan_dir"' EXIT
trivy_image='aquasec/trivy:0.76.2@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb'
status=0
for image in "$@"; do
  printf '\nScan Trivy de %s\n' "$image"
  docker image save --output "$scan_dir/image.tar" "$image"
  if ! docker run --rm --user "$(id -u):$(id -g)" --env HOME=/scan \
    --mount "type=bind,source=$scan_dir,target=/scan" "$trivy_image" \
    image --cache-dir /scan/cache --scanners vuln --input /scan/image.tar \
    --no-progress --severity CRITICAL --exit-code 1; then
    status=1
  fi
done
exit "$status"
