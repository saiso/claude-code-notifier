#!/bin/bash
# claude-code-notifier.app をビルドして配置する。
# Swift + UserNotifications framework による macOS 通知アプリ。
# Heroicons の bell-solid（MIT License, Copyright (c) 2020 Refactoring UI Inc.）を
# ベル形状の mask として使用し、Claude ブランドカラーで描画した icns を埋め込む。
#
# 環境変数:
#   CCN_APP_DIR  アプリ配置先。デフォルト ~/.claude/apps

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWIFT_SRC="$SCRIPT_DIR/claude-code-notifier.swift"
ICON_GEN="$SCRIPT_DIR/generate-notifier-icon.swift"

APP_NAME="Claude Code Notifier"
BUNDLE_ID="io.github.saiso.claude-code-notifier"
BUNDLE_VERSION="1.0.0"
APP_DIR="${CCN_APP_DIR:-$HOME/.claude/apps}"
APP_PATH="$APP_DIR/$APP_NAME.app"

BUILD_TMP="$(mktemp -d -t ccn-build)"
trap "rm -rf '$BUILD_TMP'" EXIT

if [ ! -f "$SWIFT_SRC" ]; then
  echo "エラー: Swift ソースが見つからない: $SWIFT_SRC" >&2
  exit 1
fi
if [ ! -f "$ICON_GEN" ]; then
  echo "エラー: アイコン生成スクリプトが見つからない: $ICON_GEN" >&2
  exit 1
fi
if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "エラー: rsvg-convert が見つからない。'brew install librsvg' でインストールしてください。" >&2
  exit 1
fi

mkdir -p "$APP_DIR"

if [ -d "$APP_PATH" ]; then
  rm -rf "$APP_PATH"
fi

CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 1. アイコン生成
echo "[1/6] アイコンを生成中..."
BELL_SVG="$SCRIPT_DIR/../assets/heroicons-bell-solid.svg"
if [ ! -f "$BELL_SVG" ]; then
  # リポジトリに同梱されていない場合は一時ディレクトリにダウンロード
  BELL_SVG="$BUILD_TMP/bell.svg"
  curl -sL https://raw.githubusercontent.com/tailwindlabs/heroicons/master/src/24/solid/bell.svg -o "$BELL_SVG"
fi
BELL_PNG="$BUILD_TMP/bell.png"
rsvg-convert -w 600 -h 600 "$BELL_SVG" -o "$BELL_PNG"

BASE_PNG="$BUILD_TMP/icon.png"
swift "$ICON_GEN" "$BELL_PNG" "$BASE_PNG" >/dev/null

ICONSET_DIR="$BUILD_TMP/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512; do
  sips -z $size $size "$BASE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  sips -z $retina_size $retina_size "$BASE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

# 2. Swift をコンパイル（universal binary: arm64 + x86_64）
echo "[2/6] Swift バイナリをコンパイル中 (arm64 + x86_64)..."
BINARY_NAME="claude-code-notifier"
ARM64_BIN="$BUILD_TMP/notifier-arm64"
X86_BIN="$BUILD_TMP/notifier-x86_64"

swiftc -O -target arm64-apple-macos12.0 -o "$ARM64_BIN" "$SWIFT_SRC"
swiftc -O -target x86_64-apple-macos12.0 -o "$X86_BIN" "$SWIFT_SRC"
lipo -create -output "$MACOS_DIR/$BINARY_NAME" "$ARM64_BIN" "$X86_BIN"

# 3. Info.plist
echo "[3/6] Info.plist を生成..."
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$BINARY_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>
	<string>Claude Code</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleVersion</key>
	<string>$BUNDLE_VERSION</string>
	<key>CFBundleShortVersionString</key>
	<string>$BUNDLE_VERSION</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026 saiso. MIT License.</string>
	<key>LSUIElement</key>
	<true/>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
</dict>
</plist>
EOF

echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# 4. ad-hoc 署名（配布時は Developer ID 署名・notarization を推奨）
echo "[4/6] ad-hoc 署名..."
codesign --force --sign - --options runtime --timestamp=none "$MACOS_DIR/$BINARY_NAME"
codesign --force --sign - --options runtime --timestamp=none "$APP_PATH"

# 5. Launch Services 登録
echo "[5/6] Launch Services 登録..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_PATH" 2>/dev/null || true

# 6. アイコンキャッシュのリフレッシュヒント（Dock 再起動はしない、利用者の作業を中断させるため）
echo "[6/6] 完了ヒント..."
touch "$APP_PATH"

echo ""
echo "[OK] $APP_NAME.app をビルドしました: $APP_PATH"
echo ""
echo "使い方:"
echo "  open \"$APP_PATH\" --args \"メッセージ\" \"タイトル\" \"サウンド名 or ラベル\" \"activate bundle ID\""
echo ""
echo "設定ファイル: ~/.config/claude-code-notifier/config.json"
echo "  初回実行時に自動生成されます"
echo ""
echo "デバッグ: CLAUDE_CODE_NOTIFIER_DEBUG=1 で ~/.claude/apps/notifier.log に動作ログを書き出します"
