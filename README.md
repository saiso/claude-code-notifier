# claude-code-notifier

English / [日本語](README.ja.md)

A macOS notifier for Claude Code. Fires native macOS notifications with a
custom icon and click-through to your IDE, so the permission prompts and
idle reminders Claude Code raises do not look like they came from Script Editor.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![macOS](https://img.shields.io/badge/macOS-12.0%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)

## Why this exists

By default, hooks invoked through `osascript -e 'display notification ...'`
surface under the Script Editor identity. The icon is wrong, the click target
is wrong, and there is no way to override either with the standard tooling
because macOS has restricted the `-sender` override since Monterey.

This tool ships a small signed `.app` bundle whose sole job is to emit
`UNUserNotificationCenter` notifications with:

- a custom icon (Heroicons bell, Claude brand colors)
- a click-through that activates your IDE bundle (defaults to Visual Studio Code)
- configurable sounds per event label (`permission`, `idle`, `default`)
- safe input handling (length caps, allowlisted sound names and bundle IDs)

## Requirements

- macOS 12.0 Monterey or later (arm64 / x86_64 universal)
- Xcode Command Line Tools (`xcode-select --install`)
- Homebrew formulae for the build step:
  - `librsvg` — rasterizes the Heroicons SVG at build time

## Installation

### From source

```sh
git clone https://github.com/saiso/claude-code-notifier.git
cd claude-code-notifier
./install.sh
```

The installer verifies dependencies, builds the `.app`, and places it under
`~/.claude/apps/Claude Code Notifier.app`. Override the destination with
`CCN_APP_DIR=/some/other/path ./install.sh`.

The first time a notification fires, macOS will ask for notification permission.
Approve it once and future notifications will show immediately.

## Quick Start

```sh
# Simple test
open "$HOME/.claude/apps/Claude Code Notifier.app" \
  --args "Hello from claude-code-notifier" "Claude Code" "default"
```

Arguments: `message`, `title`, `sound-name-or-label`, `activate-bundle-id`.
All are optional except `message`. Empty values fall back to the configuration
file.

## Usage

```sh
open "$HOME/.claude/apps/Claude Code Notifier.app" \
  --args "<message>" "<title>" "<sound>" "<activate-bundle-id>"
```

When the app is launched with an empty message (which is also what happens
when a user clicks an already-delivered notification), it activates the
configured `activate-bundle-id` and exits.

Sound is resolved in this order:

1. If the given value matches a key in `config.json` under `sounds`, the
   mapped sound name is used (e.g. `permission` → `Purr`).
2. Otherwise the value is taken as a literal macOS system sound name (e.g.
   `Glass`, `Hero`, `Funk`) after allowlist validation (`^[A-Za-z0-9_]+$`).
3. Otherwise the `default` entry in `config.json` is used.

Bundle ID is validated against `^[a-zA-Z0-9.\-]+$` and limited to 255 chars.

## Configuration

On first launch, the following file is created with defaults:

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

Sound names are the stems of files in `/System/Library/Sounds` (without
`.aiff`). Typical values: `Glass`, `Hero`, `Funk`, `Purr`, `Pop`, `Ping`,
`Blow`, `Bottle`, `Frog`, `Morse`, `Sosumi`, `Submarine`, `Tink`.

### Understanding "sound labels"

The third positional argument to the notifier is a label. It is resolved in
this order:

1. If it matches a key under `sounds` in `config.json`, the mapped sound is
   used. For example `permission` → `Purr`.
2. Otherwise it is treated as a literal sound name after allowlist check.
3. If still unresolved, `sounds.default` is used as the fallback.

This indirection lets you change the sound for an event type without touching
every `settings.json` hook. `idle` and `permission` are just the default label
names; you can rename them or add your own.

### Scenario A: use defaults as-is

Run `./install.sh`, paste the hook snippet from the [Integration with Claude
Code](#integration-with-claude-code) section into `~/.claude/settings.json`.
`permission` events play `Purr`, `idle` events play `Glass`. Done.

### Scenario B: change the sound for permission prompts

You want a softer sound for permission prompts. Edit `config.json`:

```json
{
  "sounds": {
    "default": "Glass",
    "idle": "Glass",
    "permission": "Pop"
  }
}
```

The hook configuration in `settings.json` does not change. The next time a
permission prompt fires, you hear `Pop` instead of `Purr`.

### Scenario C: add a custom label for your own hook

You want a distinct sound when a build finishes. Pick a new label (e.g.
`build_done`) and add it to `config.json`:

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

Call the notifier with the new label:

```sh
open "$HOME/.claude/apps/Claude Code Notifier.app" \
  --args "Build finished" "My Project" "build_done"
```

Or wire it into Claude Code `settings.json` as a hook for whatever event you
like (e.g. a post-build script). The notifier does not care where the label
comes from; it just looks it up in `config.json`.

### Scenario D: use with an IDE other than VS Code

Change `activateBundleID` in `config.json`:

```json
{
  "activateBundleID": "com.todesktop.230313mzl4w4u92"
}
```

Now the click-through target of every notification is Cursor. Common IDE
bundle identifiers:

| IDE | Bundle ID |
| --- | --- |
| Visual Studio Code | `com.microsoft.VSCode` |
| VS Code Insiders | `com.microsoft.VSCodeInsiders` |
| Cursor | `com.todesktop.230313mzl4w4u92` |
| Windsurf | `com.exafunction.windsurf` |
| JetBrains IntelliJ IDEA | `com.jetbrains.intellij` |
| Terminal.app | `com.apple.Terminal` |
| iTerm2 | `com.googlecode.iterm2` |

## Integration with Claude Code

Add the following to `~/.claude/settings.json` under `hooks`:

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

The empty `title` slot lets `config.json` decide; the third argument is a
label that resolves to a sound per `config.json`.

## Troubleshooting

### The first notification never shows up

On first launch macOS presents an approval dialog. If you dismissed it, open
System Settings → Notifications, find "Claude Code Notifier", and enable
notifications. If the entry is missing, reset the permission and try again:

```sh
tccutil reset All io.github.saiso.claude-code-notifier
open "$HOME/.claude/apps/Claude Code Notifier.app" --args "test" "" "default"
```

### Gatekeeper refuses to launch the app

Because the distributed binary is ad-hoc signed (not notarized), Gatekeeper
may quarantine it on first download. Remove the quarantine attribute:

```sh
xattr -dr com.apple.quarantine "$HOME/.claude/apps/Claude Code Notifier.app"
```

### Icon cache shows the old icon after rebuilds

Quit Notification Center so the icon cache refreshes:

```sh
killall usernotificationsd
```

### Debug logs

```sh
CLAUDE_CODE_NOTIFIER_DEBUG=1 open "$HOME/.claude/apps/Claude Code Notifier.app" \
  --args "debug test" "" "default"
tail -f ~/.claude/apps/notifier.log
```

## Uninstall

```sh
./uninstall.sh
```

This removes the application bundle and (with confirmation) the configuration
directory at `~/.config/claude-code-notifier/`.

To revoke the notification permission entirely:

```sh
tccutil reset All io.github.saiso.claude-code-notifier
```

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
for guidelines and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community
expectations. Please open an issue before starting substantial work so the
scope can be agreed on.

## Security

To report a security issue, follow the private disclosure process in
[SECURITY.md](SECURITY.md). Please do not open public issues for
vulnerabilities.

## License

MIT. See [LICENSE](LICENSE).

## Trademarks

Claude and Claude Code are trademarks of Anthropic, PBC.
This project is not affiliated with, endorsed by, or sponsored by Anthropic.
See [TRADEMARKS.md](TRADEMARKS.md) for third-party trademark notices and
attributions for bundled assets (Heroicons, Apple SF, etc.).
