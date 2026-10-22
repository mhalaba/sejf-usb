#!/bin/zsh
# Buduje "Sejf USB.app" (bez Xcode — wystarczą Command Line Tools).
#   ./build.sh            -> buduje aplikację i instaluje ją w ~/Applications (na Macu — NIE na pendrivie,
#                            gdzie ktoś mógłby ją podmienić)
#   ./build.sh test       -> uruchamia testy rdzenia kryptograficznego
set -euo pipefail
cd "${0:A:h}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
CORE=(Sources/Core/*.swift)
FLAGS=(-O -swift-version 5)
# Ostrzeżenia jako błędy lokalnie; w CI (inna wersja kompilatora) można wyłączyć: STRICT=0 ./build.sh
[[ "${STRICT:-1}" == "1" ]] && FLAGS+=(-warnings-as-errors)

if [[ "${1:-}" == "test" ]]; then
  swiftc "${FLAGS[@]}" -target arm64-apple-macos14.0 "${CORE[@]}" Tests/main.swift -o "$WORK/tests"
  "$WORK/tests" "$WORK"
  exit $?
fi

APP="$WORK/Sejf USB.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc "${FLAGS[@]}" -parse-as-library -target $arch-apple-macos14.0 \
    "${CORE[@]}" Sources/App/*.swift -o "$WORK/SejfUSB-$arch"
done
lipo -create "$WORK"/SejfUSB-arm64 "$WORK"/SejfUSB-x86_64 -output "$APP/Contents/MacOS/SejfUSB"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - --options runtime --entitlements Resources/Entitlements.plist "$APP"

DEST="${DEST:-$HOME/Applications}"
mkdir -p "$DEST"
rm -rf "$DEST/Sejf USB.app"
ditto --norsrc --noextattr "$APP" "$DEST/Sejf USB.app"
echo "Gotowe: $(cd "$DEST" && pwd)/Sejf USB.app"
