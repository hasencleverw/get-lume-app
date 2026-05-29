#!/bin/bash
# Lume for Mac — build script (SPM)
# Uso: ./build.sh [debug|release] [--no-pkg] [--no-universal]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="release"
MAKE_PKG=true
MAKE_UNIVERSAL=true

for arg in "$@"; do
  case "$arg" in
    debug)        CONFIG="debug" ;;
    --no-pkg)     MAKE_PKG=false ;;
    --no-universal) MAKE_UNIVERSAL=false ;;
  esac
done

APP_NAME="Lume"
BUNDLE_ID="com.lume.mac"
VERSION="1.0.0"
VERSION_LABEL="Beta 1.0.0"
APP_DIR="/tmp/LumeApp/${APP_NAME}.app"
ICON_SRC="$SCRIPT_DIR/../Icone.png"
ICON_ICNS="/tmp/AppIcon.icns"

# ─────────────────────────────────────────────
# 1. Build binary
# ─────────────────────────────────────────────
cd "$SCRIPT_DIR"

if [ "$MAKE_UNIVERSAL" = true ] && [ "$CONFIG" = "release" ]; then
  echo "→ Build universal (arm64 + x86_64)…"
  swift build -c release --arch arm64  2>&1 | grep -v "^warning"
  swift build -c release --arch x86_64 2>&1 | grep -v "^warning"
  BINARY="/tmp/Lume_universal"
  lipo -create \
    ".build/arm64-apple-macosx/release/Lume" \
    ".build/x86_64-apple-macosx/release/Lume" \
    -output "$BINARY"
  echo "  → Universal binary criado ($(lipo -info "$BINARY" | sed 's/.*are://'))"
else
  ARCH="$(uname -m)"
  echo "→ Build $CONFIG ($ARCH)…"
  swift build -c "$CONFIG" --arch "$ARCH" 2>&1 | grep -v "^warning"
  BINARY=".build/${ARCH}-apple-macosx/${CONFIG}/Lume"
fi

# ─────────────────────────────────────────────
# 2. Generate AppIcon.icns
# ─────────────────────────────────────────────
echo "→ Gerando ícone…"
if python3 -c "from PIL import Image" 2>/dev/null && [ -f "$ICON_SRC" ]; then
python3 - "$ICON_SRC" "$ICON_ICNS" <<'PYEOF'
import sys, os, subprocess
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
iconset = dst.replace(".icns", ".iconset")
os.makedirs(iconset, exist_ok=True)
img = Image.open(src).convert("RGBA")
for size in [16,32,64,128,256,512,1024]:
    img.resize((size, size), Image.LANCZOS).save(f"{iconset}/icon_{size}x{size}.png")
    if size <= 512:
        img.resize((size*2, size*2), Image.LANCZOS).save(f"{iconset}/icon_{size}x{size}@2x.png")
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", dst], check=True)
PYEOF
else
  echo "  (PIL não disponível — usando ícone anterior)"
fi

# ─────────────────────────────────────────────
# 3. Assemble .app bundle
# ─────────────────────────────────────────────
echo "→ Montando bundle…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Icon
[ -f "$ICON_ICNS" ] && cp "$ICON_ICNS" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Icone.png (needed by sidebar loadLumeIcon and MenuBarView header)
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$APP_DIR/Contents/Resources/Icone.png"

MENUBAR_ICON="$SCRIPT_DIR/../Icone menu bar.png"

# Resources from SPM bundle (mainaudio.mp3, Icone.png, etc.)
for arch in arm64 x86_64 "$(uname -m)"; do
  RSRC=".build/${arch}-apple-macosx/${CONFIG}/Lume_Lume.bundle/Contents/Resources"
  if [ -d "$RSRC" ]; then
    cp -Rn "$RSRC/"* "$APP_DIR/Contents/Resources/" 2>/dev/null || true
    break
  fi
done
# Fallback: copy directly from project Resources
cp "$SCRIPT_DIR/Lume/Resources/Sounds/mainaudio.mp3" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp "$SCRIPT_DIR/Lume/Resources/Icone.png"    "$APP_DIR/Contents/Resources/" 2>/dev/null || true

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>                     <string>Lume</string>
  <key>CFBundleDisplayName</key>              <string>Lume</string>
  <key>CFBundleIdentifier</key>               <string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key>               <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>                 <string>AppIcon</string>
  <key>CFBundleShortVersionString</key>       <string>${VERSION}</string>
  <key>CFBundleVersion</key>                  <string>${VERSION}</string>
  <key>CFBundlePackageType</key>              <string>APPL</string>
  <key>LSMinimumSystemVersion</key>           <string>13.0</string>
  <key>NSPrincipalClass</key>                 <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>          <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key> <true/>
  <key>LSUIElement</key>                      <false/>
  <key>NSDesktopFolderUsageDescription</key>      <string>Para analisar arquivos.</string>
  <key>NSDocumentsFolderUsageDescription</key>    <string>Para analisar arquivos.</string>
  <key>NSDownloadsFolderUsageDescription</key>    <string>Para analisar arquivos.</string>
  <key>NSMusicUsageDescription</key>              <string>Para analisar arquivos.</string>
  <key>NSPicturesUsageDescription</key>           <string>Para analisar arquivos.</string>
  <key>NSMoviesUsageDescription</key>             <string>Para analisar arquivos.</string>
  <key>NSRemovableVolumesUsageDescription</key>   <string>Para analisar discos.</string>
  <key>NSSystemAdministrationUsageDescription</key> <string>Para tarefas de manutenção.</string>
  <key>NSAppleEventsUsageDescription</key>        <string>Para tarefas de manutenção.</string>
</dict>
</plist>
PLIST

# Beside the .app (sidebar fallback path for dev/DMG layout)
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$(dirname "$APP_DIR")/Icone.png" 2>/dev/null || true

echo "→ Assinando ad-hoc…"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

# ─────────────────────────────────────────────
# 4. DMG
# ─────────────────────────────────────────────
DMG_PATH="$SCRIPT_DIR/${APP_NAME}.dmg"
echo "→ Criando DMG…"
rm -f "$DMG_PATH"
TMP_DMG_DIR="/tmp/LumeDMGSrc"
rm -rf "$TMP_DMG_DIR"; mkdir -p "$TMP_DMG_DIR"
cp -R "$APP_DIR" "$TMP_DMG_DIR/"
ln -s /Applications "$TMP_DMG_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DMG_DIR" \
  -ov -format UDZO -imagekey zlib-level=9 "$DMG_PATH" > /dev/null

# ─────────────────────────────────────────────
# 5. PKG installer (release only)
# ─────────────────────────────────────────────
if [ "$MAKE_PKG" = true ] && [ "$CONFIG" = "release" ]; then
  PKG_PATH="$SCRIPT_DIR/${APP_NAME}_Installer.pkg"
  COMPONENT_PKG="/tmp/Lume_component.pkg"
  DIST_XML="/tmp/Lume_distribution.xml"
  INSTALLER_RSRC="$SCRIPT_DIR/installer"

  echo "→ Criando PKG instalador…"

  pkgbuild \
    --install-location /Applications \
    --component "$APP_DIR" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    "$COMPONENT_PKG"

  cat > "$DIST_XML" <<DISTXML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Lume for Mac</title>
    <organization>com.lume.mac</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <welcome    file="welcome.html"    mime-type="text/html"/>
    <license    file="eula.html"       mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
    <pkg-ref id="${BUNDLE_ID}"/>
    <choices-outline>
        <line choice="default">
            <line choice="${BUNDLE_ID}"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="${BUNDLE_ID}" visible="false">
        <pkg-ref id="${BUNDLE_ID}"/>
    </choice>
    <pkg-ref id="${BUNDLE_ID}" version="${VERSION}" onConclusion="none">Lume_component.pkg</pkg-ref>
</installer-gui-script>
DISTXML

  productbuild \
    --distribution "$DIST_XML" \
    --resources "$INSTALLER_RSRC" \
    --package-path "$(dirname "$COMPONENT_PKG")" \
    --sign - \
    "$PKG_PATH" 2>/dev/null || \
  productbuild \
    --distribution "$DIST_XML" \
    --resources "$INSTALLER_RSRC" \
    --package-path "$(dirname "$COMPONENT_PKG")" \
    "$PKG_PATH"

  echo "✅ PKG: $PKG_PATH"
fi

echo ""
echo "✅ App: $APP_DIR"
echo "✅ DMG: $DMG_PATH"
open "$(dirname "$APP_DIR")"
