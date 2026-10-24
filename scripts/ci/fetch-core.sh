#!/bin/sh
set -eu

workspace=${ET_CORE_WORKSPACE:-$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)}
core_version=$(tr -d '\r\n' < "$workspace/CORE_VERSION")
expected_sha=$(tr -d '\r\n' < "$workspace/CORE_ASSET_SHA256")
printf '%s\n' "$core_version" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || {
  echo 'Invalid CORE_VERSION' >&2; exit 1;
}
printf '%s\n' "$expected_sha" | grep -Eq '^[0-9a-f]{64}$' || {
  echo 'Invalid CORE_ASSET_SHA256' >&2; exit 1;
}

cache_dir="$workspace/.cache/core"
mkdir -p "$cache_dir"
archive="$cache_dir/easytier-linux-aarch64-${core_version}.zip"
work_dir=$(mktemp -d "$cache_dir/.fetch.XXXXXX")
cleanup() { rm -rf "$work_dir"; }
trap cleanup 0 1 2 15

verify_archive() {
  [ -f "$1" ] && [ "$(sha256sum "$1" | cut -d ' ' -f1)" = "$expected_sha" ]
}

if ! verify_archive "$archive"; then
  url="https://github.com/EasyTier/EasyTier/releases/download/${core_version}/easytier-linux-aarch64-${core_version}.zip"
  curl --fail --location --retry 3 --connect-timeout 15 --max-time 180 \
    "$url" --output "$work_dir/download.zip"
  if ! verify_archive "$work_dir/download.zip"; then
    echo 'EasyTier archive SHA256 mismatch; refusing to install tools' >&2
    exit 1
  fi
  mv -f "$work_dir/download.zip" "$archive"
fi

for tool in easytier-core easytier-cli; do
  member=$(unzip -Z -1 "$archive" | awk -v tool="$tool" '
    { n = split($0, parts, "/"); if (parts[n] == tool) print }
  ')
  if [ -z "$member" ] || [ "$(printf '%s\n' "$member" | wc -l)" -ne 1 ]; then
    echo "Expected exactly one $tool in the archive" >&2
    exit 1
  fi
  unzip -p "$archive" "$member" > "$work_dir/$tool"
  if ! file -b "$work_dir/$tool" | grep -Eq 'ELF 64-bit.*ARM aarch64.*statically linked'; then
    echo "Unexpected $tool architecture or linkage" >&2
    exit 1
  fi
  chmod 755 "$work_dir/$tool"
done

for tool in easytier-core easytier-cli; do
  mv -f "$work_dir/$tool" "$workspace/$tool"
done
echo "Verified official EasyTier ${core_version} ARM64 tools"
