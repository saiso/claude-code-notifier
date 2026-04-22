# claude-code-notifier

[English README](README.md) / 日本語

Claude Code 向けの macOS 通知ツール。アイコン付きのネイティブ通知を表示し、クリックで IDE を前面に戻せる。Claude Code の hook 経由で出る確認ダイアログやアイドル通知が「Script Editor から来たように見える」状態を解消するために作った。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![macOS](https://img.shields.io/badge/macOS-12.0%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)

## このツールがある理由

`osascript -e 'display notification ...'` 経由の通知は Script Editor 名義で発火するので、アイコンもクリック先も思い通りにできない。macOS Monterey 以降、`terminal-notifier` の `-sender` による差し替えもほぼ効かなくなった。

本ツールは小さな署名済み `.app` を用意し、`UNUserNotificationCenter` で通知を出す。

- カスタムアイコン（Heroicons のベル、Claude ブランドカラー）
- クリックで任意のアプリ（既定: Visual Studio Code）を前面に
- イベント種別（label）ごとにサウンドを切り替え
- 入力検証を含む安全な動作（サウンド名・bundle ID の allowlist、本文の長さ制限）

## 類似プロジェクト

同じ目的で作られているツールは他にもあります。好みに合わなければそちらも検討してほしい。

- [dazuiba/CCNotify](https://github.com/dazuiba/CCNotify) — Python 製、VS Code を前面に
- [wyattjoh/claude-code-notification](https://github.com/wyattjoh/claude-code-notification) — Rust 製、シンプルな通知
- [polyphilz/ccnotifs](https://github.com/polyphilz/ccnotifs) — Shell + 独自 `.app`、tmux pane まで teleport
- [splazapp/claude-code-notification](https://github.com/splazapp/claude-code-notification) — Bash + Swift、複数 IDE click-through
- [Naveenxyz/claude-code-notifier](https://github.com/Naveenxyz/claude-code-notifier) — Shell、IDE / Terminal を 10 種以上自動検出

### 本プロジェクトの違い

- 攻撃面を明示的に絞ってある: サウンド名と bundle ID に allowlist、通知本文に長さ制限、制御文字の除去。`config.json` と CLI 引数の値を無条件に信頼しない設計
- Swift 単一バイナリ。Python / Node / Rust のランタイム依存なし
- ライセンスクリーンなアイコン（Heroicons MIT から生成、SF Symbols を使わない）
- `config.json` のサウンドラベルで hook とサウンドを分離（音変更で hook 側を書き換えない）
- universal binary（arm64 + x86_64）、macOS 12.0 以降
- 英語 + 日本語の README
- OSS 配布ボイラープレート完備（LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT / TRADEMARKS）

## 必要なもの

- macOS 12.0 Monterey 以降（arm64 / x86_64 の universal binary）
- Xcode Command Line Tools（`xcode-select --install`）
- Homebrew の `librsvg`（ビルド時に SVG をラスタライズするのに使う）

## インストール

### Homebrew tap から

```sh
brew install saiso/tap/claude-code-notifier
```

Homebrew の管理下でソースビルドされる。`.app` は `$(brew --prefix)/opt/claude-code-notifier/libexec/Claude Code Notifier.app` に配置され、`$(brew --prefix)/bin/` に `claude-code-notifier` のラッパースクリプトが作られるので、`claude-code-notifier "メッセージ" "タイトル" "サウンド"` としても呼び出せる。

依存（`librsvg` と Xcode Command Line Tools）は Homebrew 側で可能な範囲で解決される。初回通知時に macOS が通知許可ダイアログを出す。

### ソースから

```sh
git clone https://github.com/saiso/claude-code-notifier.git
cd claude-code-notifier
./install.sh
```

インストーラが依存を確認し、`.app` をビルドして `~/.claude/apps/Claude Code Notifier.app` に配置する。別の場所に置きたい場合は `CCN_APP_DIR=/some/other/path ./install.sh`。

初回の通知発火時に macOS が通知許可ダイアログを出す。許可すれば以降はそのまま通知される。

> 注意: 両方のインストール方法を同時に走らせると、同一の bundle identifier を持つ `.app` が 2 箇所に置かれる。macOS はどちらのインスタンスがクリックスルー対象になるかを保証しないため、どちらか片方を選び他方は消すこと。

## クイックスタート

```sh
open "$HOME/.claude/apps/Claude Code Notifier.app" \
  --args "Hello from claude-code-notifier" "Claude Code" "default"
```

引数は `message`、`title`、`sound-name-or-label`、`activate-bundle-id` の順。`message` 以外は省略可。空文字を渡せば設定ファイルの値で補完される。

## 使い方

```sh
open "$HOME/.claude/apps/Claude Code Notifier.app" \
  --args "<message>" "<title>" "<sound>" "<activate-bundle-id>"
```

アプリが空メッセージで起動された場合（通知をクリックしたときの挙動）は、設定済みの `activate-bundle-id` を前面にしてから終了する。

サウンドの解決順：

1. 値が `config.json` の `sounds` のキーと一致すれば、そこに書かれたサウンド名を使う（例: `permission` → `Purr`）。
2. 一致しなければ、macOS のシステムサウンド名として扱う（allowlist 検証あり。例: `Glass`、`Hero`、`Funk`）。
3. どちらでも解決できなければ `sounds.default` を使う。

bundle ID は `^[a-zA-Z0-9.\-]+$` と 255 文字以内で検証する。

## 設定

初回起動時に以下のファイルがデフォルト値で作られる。

```
~/.config/claude-code-notifier/config.json
```

```json
{
  "activateBundleID": "com.microsoft.VSCode",
  "defaultTitle": "Claude Code",
  "sounds": {
    "default": "Glass",
    "idle": "Glass",
    "permission": "Purr"
  }
}
```

サウンド名は `/System/Library/Sounds` 配下にあるファイル名の拡張子を除いたもの（例: `Glass`、`Hero`、`Funk`、`Purr`、`Pop`、`Ping`、`Blow`、`Bottle`、`Frog`、`Morse`、`Sosumi`、`Submarine`、`Tink`）。

### サウンドラベルの考え方

通知ツールの第 3 引数はラベルとして解釈される。以下の順で解決する。

1. `config.json` の `sounds` にキーとして存在すれば、そのサウンド名を使う（例: `permission` → `Purr`）。
2. 存在しなければリテラルのサウンド名として扱う（allowlist 検証あり）。
3. それでも不明なら `sounds.default` にフォールバックする。

この間接参照のおかげで、イベント種別ごとのサウンドを変えたいときに `settings.json` の hook を全部書き換える必要がなくなる。`idle` と `permission` はデフォルトとして用意してあるラベル名で、任意の名前に変えたり新しく追加したりしてよい。

### シナリオ A: デフォルトのまま使う

`./install.sh` を実行し、後述の [Claude Code との連携](#claude-code-との連携) のスニペットをそのまま `~/.claude/settings.json` に貼る。`permission` イベントでは `Purr`、`idle` イベントでは `Glass` が鳴る。それで終わり。

### シナリオ B: 確認ダイアログの音をやさしくしたい

`config.json` の `permission` の値だけ差し替える。

```json
{
  "sounds": {
    "default": "Glass",
    "idle": "Glass",
    "permission": "Pop"
  }
}
```

`settings.json` は触らない。次に確認ダイアログが出ると `Purr` ではなく `Pop` が鳴る。

### シナリオ C: 独自ラベルを追加する

ビルド完了通知に別の音を当てたいとする。新しいラベル（例: `build_done`）を `config.json` に足す。

```json
{
  "sounds": {
    "default": "Glass",
    "idle": "Glass",
    "permission": "Purr",
    "build_done": "Hero"
  }
}
```

そのラベルを渡して通知を発火する。

```sh
open "$HOME/.claude/apps/Claude Code Notifier.app" \
  --args "Build finished" "My Project" "build_done"
```

Claude Code の `settings.json` からも、任意のイベントに紐づくコマンドでこのラベルを参照できる。ツール側はラベルの由来を気にせず、`config.json` から対応するサウンドを引くだけ。

### シナリオ D: VS Code 以外の IDE を使う

`config.json` の `activateBundleID` を書き換える。

```json
{
  "activateBundleID": "com.todesktop.230313mzl4w4u92"
}
```

これで通知クリック時のアクティブ化対象が Cursor になる。主な IDE の bundle ID は以下のとおり。

| IDE | Bundle ID |
| --- | --- |
| Visual Studio Code | `com.microsoft.VSCode` |
| VS Code Insiders | `com.microsoft.VSCodeInsiders` |
| Cursor | `com.todesktop.230313mzl4w4u92` |
| Windsurf | `com.exafunction.windsurf` |
| JetBrains IntelliJ IDEA | `com.jetbrains.intellij` |
| Terminal.app | `com.apple.Terminal` |
| iTerm2 | `com.googlecode.iterm2` |

## Claude Code との連携

`brew install saiso/tap/claude-code-notifier` でインストールした場合は、下記スニペットの `$HOME/.claude/apps/` を `$(brew --prefix)/opt/claude-code-notifier/libexec/` に置き換える。同じスニペットは `brew install` 直後の caveats にも表示される。

`~/.claude/settings.json` の `hooks` セクションに以下を追加する。

```json
{
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
}
```

`title` を空にすると `config.json` の `defaultTitle` が使われる。第 3 引数は `config.json` から対応するサウンドを引くラベル。

## トラブルシューティング

### 最初の通知が出てこない

初回起動時、macOS が通知許可ダイアログを出す。見逃した場合はシステム設定 → 通知 で「Claude Code Notifier」を探し、通知を有効化する。項目自体がなければ権限をリセットして再試行する。

```sh
tccutil reset Notifications io.github.saiso.claude-code-notifier
open "$HOME/.claude/apps/Claude Code Notifier.app" --args "test" "" "default"
```

### アイコンキャッシュに古い画像が残る

通知センターのキャッシュを更新する。

```sh
killall usernotificationsd
```

### デバッグログ

```sh
CLAUDE_CODE_NOTIFIER_DEBUG=1 open "$HOME/.claude/apps/Claude Code Notifier.app" \
  --args "debug test" "" "default"
tail -f ~/.claude/apps/notifier.log
```

## アンインストール

```sh
./uninstall.sh
```

アプリ本体を削除し、対話的に設定ディレクトリ（`~/.config/claude-code-notifier/`）と通知権限記録の削除も選べる。

通知権限の記録だけ明示的にリセットしたいとき。

```sh
tccutil reset Notifications io.github.saiso.claude-code-notifier
```

## コントリビュート

Issue と Pull Request を歓迎する。手順やスコープの指針は [CONTRIBUTING.md](CONTRIBUTING.md)、コミュニティ運営の考え方は [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) を参照。大きめの変更を始める前に Issue を立てて方向性を共有してほしい。

## セキュリティ

脆弱性は公開 Issue ではなく、[SECURITY.md](SECURITY.md) に書いた private 報告経路で連絡してほしい。

## ライセンス

MIT。[LICENSE](LICENSE) を参照。

## 商標

Claude と Claude Code は Anthropic, PBC の商標。本プロジェクトは Anthropic との関連はなく、公式の承認を受けているものでもない。同梱アセット（Heroicons、Apple の SF 等）の商標表示とライセンスは [TRADEMARKS.md](TRADEMARKS.md) を参照。

## Author

Made by saiso.

ブログ・他のプロジェクトは https://saiso.jp を参照。
