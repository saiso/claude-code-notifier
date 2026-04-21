#!/bin/bash
# claude-code-notifier のアンインストーラ
# アプリバンドルを削除し、設定ディレクトリの削除はユーザー確認の上で実施する。

set -euo pipefail

APP_DIR="${CCN_APP_DIR:-$HOME/.claude/apps}"
APP_PATH="$APP_DIR/Claude Code Notifier.app"
CONFIG_DIR="$HOME/.config/claude-code-notifier"
BUNDLE_ID="io.github.saiso.claude-code-notifier"
LOG_FILE="$HOME/.claude/apps/notifier.log"

echo "claude-code-notifier をアンインストールします。"
echo ""

# アプリ削除
if [ -d "$APP_PATH" ]; then
  rm -rf "$APP_PATH"
  echo "[OK] アプリを削除: $APP_PATH"
else
  echo "[INFO] アプリは存在しませんでした: $APP_PATH"
fi

# デバッグログ削除
if [ -f "$LOG_FILE" ]; then
  rm -f "$LOG_FILE"
  echo "[OK] デバッグログを削除: $LOG_FILE"
fi

# 設定ディレクトリの削除確認
if [ -d "$CONFIG_DIR" ]; then
  echo ""
  read -r -p "設定ディレクトリ $CONFIG_DIR も削除しますか？ [y/N]: " answer
  case "$answer" in
    [yY]|[yY][eE][sS])
      rm -rf "$CONFIG_DIR"
      echo "[OK] 設定ディレクトリを削除: $CONFIG_DIR"
      ;;
    *)
      echo "[INFO] 設定ディレクトリは残しました: $CONFIG_DIR"
      ;;
  esac
fi

# 通知権限の記録をリセット
echo ""
read -r -p "通知権限の記録をリセットしますか？ (再インストール時に再び許可ダイアログが出ます) [y/N]: " answer
case "$answer" in
  [yY]|[yY][eE][sS])
    tccutil reset All "$BUNDLE_ID" 2>/dev/null || true
    echo "[OK] 通知権限の記録をリセット"
    ;;
  *)
    echo "[INFO] 通知権限の記録は残しました"
    ;;
esac

echo ""
echo "アンインストール完了。"
echo ""
echo "Claude Code の hook 設定 (~/.claude/settings.json) は自動では変更しません。"
echo "必要に応じて、手動で Notification / PermissionRequest の hook を削除してください。"
