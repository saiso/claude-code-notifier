# claude-code-notifier

## 概要

macOS 向け通知ツール。Claude Code の hook（idle_prompt / PermissionRequest）から呼び出されることを想定したが、一般の macOS CLI としても動く。Swift + UserNotifications framework で書かれた .app バンドル。

## プロジェクト構成

```
claude-code-notifier/
├── LICENSE                # MIT
├── README.md              # ユーザー向けドキュメント
├── CHANGELOG.md           # バージョン履歴
├── TRADEMARKS.md          # 商標・第三者ライセンス
├── CLAUDE.md              # このファイル、プロジェクト運用メモ
├── install.sh             # ビルド + 配置
├── uninstall.sh           # 削除
├── scripts/
│   ├── claude-code-notifier.swift    # アプリ本体
│   ├── generate-notifier-icon.swift  # アイコン合成
│   └── build.sh                      # ビルド本体
└── assets/
    └── heroicons-bell-solid.svg      # Heroicons MIT
```

## 技術スタック

- Swift（UserNotifications + AppKit）
- 依存: librsvg（ビルド時の SVG → PNG 変換）
- 最低対応: macOS 12.0 Monterey
- ビルド: universal binary（arm64 + x86_64）
- 署名: ad-hoc（配布時は Developer ID 署名・notarization を推奨）

## 運用ルール

### バージョニング

SemVer。`scripts/build.sh` の `BUNDLE_VERSION` と `CHANGELOG.md` を同時更新する。リリース時は `git tag v1.0.0` 形式でタグを打ち、GitHub Releases に zip を添付する。

### アイコン素材の取り扱い

Heroicons の SVG は `assets/heroicons-bell-solid.svg` にリポジトリ同梱。MIT License なので再配布可。更新時は `TRADEMARKS.md` の著作権表記を確認する。

Apple SF Symbols は使わない。アプリアイコンへの使用が SF Symbols License Agreement で禁止されているため。

### セキュリティ・品質の担保

過去の empirical-prompt-tuning 評価で指摘された項目は全て対応済み（2026-04-22）。変更を加える際は以下を意識する。

- CLI 引数のサニタイズ（soundName allowlist、bundleID allowlist、body 長さ制限、制御文字除去）
- 設定ファイル破損時のデフォルト fallback
- ログは CLAUDE_CODE_NOTIFIER_DEBUG=1 のときのみ
- 署名後に plist を変更しない（codesign 検証が失敗するため）
- Dock / Finder の無用な再起動をユーザーに押し付けない

### 配布の流れ

1. `git tag vX.Y.Z && git push --tags`
2. GitHub Releases で zip（tarball）を公開
3. 将来的に Homebrew tap（`saiso/tap`）で `brew install` 対応を検討

## 今後の拡張候補

- Homebrew tap の作成
- Developer ID 署名と notarization（配布物の Gatekeeper 警告をなくす）
- 設定 CLI サブコマンド（`claude-code-notifier config set idle-sound Hero` など）
- 他の OS（Linux）対応は対象外（macOS 固有ツール）

## 参考

- Anthropic Claude Code: https://claude.com/product/claude-code
- Heroicons: https://heroicons.com
- UserNotifications framework: https://developer.apple.com/documentation/usernotifications
