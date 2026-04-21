#!/bin/bash
# claude-code-notifier のインストーラ
# 依存チェック → ビルド → 配置 まで行う。
# 環境変数 CCN_APP_DIR でインストール先を上書きできる（デフォルト ~/.claude/apps）。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_SCRIPT="$ROOT_DIR/scripts/build.sh"

echo "claude-code-notifier をインストールします。"
echo ""

# 依存チェック
missing=()
if ! command -v swiftc >/dev/null 2>&1; then
  missing+=("swiftc (Xcode Command Line Tools)")
fi
if ! command -v rsvg-convert >/dev/null 2>&1; then
  missing+=("rsvg-convert (brew install librsvg)")
fi
if ! command -v iconutil >/dev/null 2>&1; then
  missing+=("iconutil (macOS 付属)")
fi
if ! command -v sips >/dev/null 2>&1; then
  missing+=("sips (macOS 付属)")
fi

if [ ${#missing[@]} -gt 0 ]; then
  echo "エラー: 以下の依存が見つかりません。" >&2
  for m in "${missing[@]}"; do
    echo "  - $m" >&2
  done
  echo "" >&2
  echo "インストール方法:" >&2
  echo "  xcode-select --install" >&2
  echo "  brew install librsvg" >&2
  exit 1
fi

# macOS バージョン確認（12.0 以上）
os_version="$(sw_vers -productVersion)"
major="$(echo "$os_version" | cut -d. -f1)"
if [ "$major" -lt 12 ] 2>/dev/null; then
  echo "警告: macOS 12.0 以降を推奨。現在のバージョン: $os_version" >&2
fi

# ビルド実行
if [ ! -x "$BUILD_SCRIPT" ]; then
  chmod +x "$BUILD_SCRIPT"
fi
bash "$BUILD_SCRIPT"

echo ""
echo "インストール完了。"
echo ""
echo "Claude Code の hook から使うには ~/.claude/settings.json に以下を追加してください:"
cat <<'JSON'

  "hooks": {
    "Notification": [
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "open \"$HOME/.claude/apps/Claude Code Notifier.app\" --args \"返信待ちです\" \"\" \"idle\""
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "open \"$HOME/.claude/apps/Claude Code Notifier.app\" --args \"コマンド確認が必要です\" \"\" \"permission\""
          }
        ]
      }
    ]
  }

JSON

echo "初回通知時に macOS から通知許可ダイアログが出ます。許可してください。"
