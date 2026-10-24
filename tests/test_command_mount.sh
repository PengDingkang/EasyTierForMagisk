#!/bin/sh
set -eu
repo_dir=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
module_id=$(sed -n 's/^id=//p' "$repo_dir/module.prop")
case "$module_id" in
  EasyTierForMagisk) wrapper=easytier; native_tools="easytier-core easytier-cli" ;;
  ZeroTier-KSU) wrapper=zerotier; native_tools=zerotier-one ;;
  *) echo "Unknown fixture module: $module_id" >&2; exit 1 ;;
esac
test_tmp=$(mktemp -d)
test_data="$test_tmp/data"
test_module="$test_tmp/modules/$module_id"
cleanup() { rm -rf "$test_tmp"; }
trap cleanup 0 1 2 15
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$test_data/config" "$test_module" "$test_tmp/bin"
printf 'instance_name = "fixture"\n' > "$test_data/config/config.toml"
printf 'test identity\n' > "$test_data/identity.secret"
printf 'test planet\n' > "$test_data/planet"
cat > "$test_tmp/native-tool" <<'EOF'
#!/bin/sh
if [ -n "${TEST_TRACE:-}" ]; then printf '%s\n' "$0" > "$TEST_TRACE"; fi
printf 'private tool %s\n' "${0##*/}"
EOF
chmod 755 "$test_tmp/native-tool"
sed -e "s|^path=.*|path=\"$test_data\"|" \
    -e "s|^module_dir=.*|module_dir=\"$test_module\"|" \
    "$repo_dir/$wrapper" > "$test_tmp/$wrapper"
sed -e "s|^et_data=.*|et_data=\"$test_data\"|" \
    -e "s|^zt_data=.*|zt_data=\"$test_data\"|" \
    "$repo_dir/customize.sh" > "$test_tmp/customize.sh"
install_fixture() {
  stage="$test_tmp/$1"
  test_ksu=false
  test_apatch=false
  case "${2:-magisk}" in
    kernelsu) test_ksu=true ;;
    apatch) test_apatch=true ;;
  esac
  mkdir -p "$stage"
  for tool in $native_tools; do cp "$test_tmp/native-tool" "$stage/$tool"; done
  cp "$test_tmp/$wrapper" "$stage/$wrapper"
  if [ "$wrapper" = easytier ]; then cp "$repo_dir/config.toml" "$stage/config.toml"; fi
  BOOTMODE=true KSU="$test_ksu" KSU_VER=test KSU_VER_CODE=30000 APATCH="$test_apatch" \
    API=36 MAGISK_VER=test MAGISK_VER_CODE=30000 MODPATH="$stage" sh -c '
      ui_print() { :; }
      abort() { echo "$*" >&2; exit 1; }
      set_perm() { chmod "$4" "$1"; }
      set_perm_recursive() { :; }
      . "$1"
    ' sh "$test_tmp/customize.sh"
}
control() { sh "$test_data/$wrapper" mount "$1"; }
install_fixture fresh
[ -f "$stage/skip_mount" ] || fail "fresh install enables mounting"
[ "$(cat "$test_data/mount_enabled")" = 0 ] || fail "default is not disabled"
[ ! -d "$stage/system/bin" ] || fail "mountless install stores duplicate tools"
cp "$stage/skip_mount" "$test_module/skip_mount"
[ "$(control status)" = 0 ] || fail "default status is not disabled"
[ "$(control supported)" = 1 ] || fail "Magisk requires a metamodule"
control enable >/dev/null
for tool in $native_tools "$wrapper"; do
  cmp "$test_data/$tool" "$test_module/system/bin/$tool" || fail "enabled mount payload mismatch"
done
[ ! -e "$test_module/skip_mount" ] || fail "enable left skip_mount"
install_fixture enabled-upgrade
[ ! -e "$stage/skip_mount" ] || fail "upgrade lost enabled preference"
control disable >/dev/null
[ ! -d "$test_module/system/bin" ] || fail "disable kept duplicate tools"
install_fixture disabled-upgrade
[ -f "$stage/skip_mount" ] || fail "upgrade lost disabled preference"

# A choice made after an upgrade is staged must survive the reboot switch.
pending="$test_tmp/modules_update/$module_id"
mkdir -p "$pending"
touch "$pending/skip_mount"
control enable >/dev/null
[ ! -e "$pending/skip_mount" ] || fail "staged update lost enabled choice"
for tool in $native_tools "$wrapper"; do
  cmp "$test_data/$tool" "$pending/system/bin/$tool" || fail "staged payload mismatch"
done
control disable >/dev/null
[ -f "$pending/skip_mount" ] || fail "staged update lost disabled choice"
[ ! -d "$pending/system/bin" ] || fail "staged update keeps duplicate tools"
rm -rf "$pending"

# Legacy installs switch to mountless without touching configuration/identity.
rm "$test_data/mount_enabled" "$test_module/skip_mount"
install_fixture legacy-upgrade kernelsu
[ -f "$stage/skip_mount" ] || fail "legacy upgrade enables mounting"
cp "$stage/skip_mount" "$test_module/skip_mount"
[ "$(control supported)" = 0 ] || fail "KernelSU without a provider supports mounting"
if control enable >/dev/null 2>&1; then fail "enabled without a provider"; fi
[ -f "$test_module/skip_mount" ] || fail "rejected enable changed skip_mount"
[ "$(cat "$test_data/mount_enabled")" = 0 ] || fail "rejected enable changed preference"
provider="$test_tmp/modules/custom-provider"
mkdir -p "$provider"
printf 'metamodule=true\n' > "$provider/module.prop"
[ "$(control supported)" = 0 ] || fail "install-only metamodule was accepted"
touch "$provider/metamount.sh"
[ "$(control supported)" = 1 ] || fail "custom mounting provider not detected"
control enable >/dev/null
install_fixture ksu-enabled-upgrade kernelsu
[ ! -e "$stage/skip_mount" ] || fail "KernelSU upgrade lost saved choice"
touch "$provider/disable"
[ "$(control supported)" = 0 ] || fail "disabled provider accepted"
control disable >/dev/null
rm "$provider/disable"
touch "$provider/remove"
[ "$(control supported)" = 0 ] || fail "removed provider accepted"
rm "$provider/remove"
ln -s "$provider" "$test_tmp/metamodule"
[ "$(control supported)" = 1 ] || fail "selected provider not detected"
touch "$provider/disable"
mkdir -p "$test_tmp/modules/other-provider"
printf 'metamodule=1\n' > "$test_tmp/modules/other-provider/module.prop"
touch "$test_tmp/modules/other-provider/metamount.sh"
[ "$(control supported)" = 0 ] || fail "bypassed disabled selected provider"
install_fixture apatch-upgrade apatch
[ "$(control supported)" = 1 ] || fail "APatch requires a metamodule"
if control invalid >/dev/null 2>&1; then fail "invalid subcommand succeeded"; fi
[ "$(cat "$test_data/identity.secret")" = 'test identity' ] || fail "identity changed"
[ "$(cat "$test_data/planet")" = 'test planet' ] || fail "planet changed"
grep -q 'instance_name = "fixture"' "$test_data/config/config.toml" || fail "config changed"

# Failure to rebuild a missing payload must keep the disabled choice intact.
first_tool=${native_tools%% *}
mv "$test_data/$first_tool" "$test_data/$first_tool.saved"
if control enable >/dev/null 2>&1; then fail "enabled with a missing private tool"; fi
[ -f "$test_module/skip_mount" ] || fail "failed payload rebuild changed skip_mount"
[ "$(cat "$test_data/mount_enabled")" = 0 ] || fail "failed payload rebuild changed preference"
[ ! -d "$test_module/system/bin" ] || fail "failed payload rebuild left duplicate tools"
mv "$test_data/$first_tool.saved" "$test_data/$first_tool"

# A PATH tool cannot replace private binaries, even with command mounts off.
for tool in $native_tools; do
  printf '#!/bin/sh\nexit 77\n' > "$test_tmp/bin/$tool"
  chmod 755 "$test_tmp/bin/$tool"
done
TEST_TRACE="$test_tmp/core-trace"
export TEST_TRACE
if [ "$wrapper" = easytier ]; then
  output=$(PATH="$test_tmp/bin:$PATH" sh "$test_data/$wrapper" cli --version)
  [ "$output" = 'private tool easytier-cli' ] || fail "CLI uses the PATH tool"
else
  for tool in zerotier-cli zerotier-idtool; do
    [ -L "$test_data/$tool" ] && [ -x "$test_data/$tool" ] || fail "$tool missing without mounts"
    [ "$(readlink "$test_data/$tool")" = zerotier-one ] || fail "$tool points outside data directory"
  done
fi
rm -f "$TEST_TRACE"
awk '$0 == "case \"$1\" in" { exit } { print }' "$test_data/$wrapper" > "$test_tmp/functions.sh"
PATH="$test_tmp/bin:$PATH" sh -c '
  busybox=busybox
  . "$1"
  bin_status() { [ -f "$TEST_TRACE" ]; }
  hostname() { :; }
  ip() { :; }
  sleep() { /bin/sleep 0.1; }
  start_service
' sh "$test_tmp/functions.sh" >/dev/null
first_tool=${native_tools%% *}
[ "$(cat "$TEST_TRACE")" = "$test_data/$first_tool" ] || fail "daemon uses the PATH tool"

# Boot must use the data-directory entrypoint when no short command exists.
mkdir -p "$test_tmp/boot-bin"
printf '#!/bin/sh\necho 1\n' > "$test_tmp/boot-bin/getprop"
printf '#!/bin/sh\nexit 0\n' > "$test_tmp/boot-bin/sleep"
printf '#!/bin/sh\nexit 0\n' > "$test_tmp/boot-bin/hostname"
printf '#!/bin/sh\nexit 77\n' > "$test_tmp/boot-bin/$wrapper"
cat > "$test_data/$wrapper" <<'EOF'
#!/bin/sh
[ "$1" = start ] || exit 1
printf 'private boot entry\n' > "$TEST_TRACE"
EOF
chmod 755 "$test_tmp/boot-bin/"* "$test_data/$wrapper"
sed "s|/data/adb/$wrapper|$test_data|g" "$repo_dir/boot-completed.sh" > "$test_tmp/boot.sh"
rm -f "$TEST_TRACE" "$test_data/.not_configured"
PATH="$test_tmp/boot-bin:$PATH" sh "$test_tmp/boot.sh"
tries=0
until [ -f "$TEST_TRACE" ]; do
  tries=$((tries + 1))
  [ "$tries" -lt 50 ] || fail "boot did not call the private entrypoint"
  /bin/sleep 0.05
done
[ "$(cat "$TEST_TRACE")" = 'private boot entry' ] || fail "boot used the PATH wrapper"
echo "$module_id mount defaults, providers, upgrades, private tools and boot tests passed"
