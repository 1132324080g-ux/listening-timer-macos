#!/bin/zsh
set -euo pipefail

readonly project_root="$(cd "$(dirname "$0")/.." && pwd)"
readonly dist_dir="${DIST_DIR:-$project_root/dist}"
readonly scratch_dir="$project_root/.build-universal"
readonly app_path="$dist_dir/听鉴.app"
readonly dmg_path="$dist_dir/ListeningTimer.dmg"

export CLANG_MODULE_CACHE_PATH="$scratch_dir/clang-module-cache"
export SWIFT_MODULE_CACHE_PATH="$scratch_dir/swift-module-cache"
export TMPDIR="${TMPDIR:-/private/tmp}"

mkdir -p "$dist_dir"
mkdir -p "$scratch_dir"

echo "Running core self-tests…"
swift run \
    --disable-sandbox \
    --scratch-path "$project_root/.build" \
    -c debug \
    CoreSelfTests

echo "Building Universal release…"
swift build \
    --disable-sandbox \
    --scratch-path "$scratch_dir" \
    -c release \
    --arch arm64 \
    --arch x86_64 \
    --product ListeningTimer \
    -debug-info-format none

readonly bin_dir="$(
    swift build \
        --disable-sandbox \
        --scratch-path "$scratch_dir" \
        -c release \
        --arch arm64 \
        --arch x86_64 \
        --show-bin-path
)"
readonly binary="$bin_dir/ListeningTimer"

if [[ ! -x "$binary" ]]; then
    echo "Expected binary was not produced: $binary" >&2
    exit 1
fi

rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS"
mkdir -p "$app_path/Contents/Resources"

cp "$binary" "$app_path/Contents/MacOS/ListeningTimer"
cp "$project_root/Packaging/Info.plist" "$app_path/Contents/Info.plist"

readonly iconset="$scratch_dir/AppIcon.iconset"
rm -rf "$iconset"
swift "$project_root/Scripts/make-icon.swift" "$iconset"
swift \
    "$project_root/Scripts/make-icns.swift" \
    "$iconset" \
    "$app_path/Contents/Resources/AppIcon.icns"

chmod +x "$app_path/Contents/MacOS/ListeningTimer"
xattr -cr "$app_path" 2>/dev/null || true
codesign \
    --force \
    --deep \
    --sign - \
    --timestamp=none \
    "$app_path"
codesign --verify --deep --strict "$app_path"

echo "Creating disk image…"
readonly staging="$scratch_dir/dmg-staging"
rm -rf "$staging"
mkdir -p "$staging"
cp -R "$app_path" "$staging/听鉴.app"
ln -s /Applications "$staging/Applications"
if [[ "${SKIP_DMG:-0}" != "1" ]]; then
    rm -f "$dmg_path"
    diskutil image create from \
        --volumeName "听鉴" \
        --format UDZO \
        "$staging" \
        "$dmg_path"
fi

echo
echo "Built:"
echo "  $app_path"
if [[ "${SKIP_DMG:-0}" != "1" ]]; then
    echo "  $dmg_path"
fi
echo
lipo -info "$app_path/Contents/MacOS/ListeningTimer"
du -sh "$app_path"
if [[ "${SKIP_DMG:-0}" != "1" ]]; then
    du -sh "$dmg_path"
fi
