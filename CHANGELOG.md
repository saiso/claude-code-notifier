# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-04-28

### Added

- README documentation of the Anthropic Claude Code VS Code extension
  regression (anthropics/claude-code#8985), where `Notification` event hooks
  no longer fire when a permission dialog appears. Includes a workaround
  recipe that routes notifications through the `PreToolUse` Bash matcher
  instead, with a clear callout to remove the workaround once the upstream
  fix ships to avoid double-firing. Terminal launches are unaffected and
  continue to use the regular `Notification` event hooks.

## [1.0.1] - 2026-04-28

### Fixed

- README hook configuration example: replaced the separate
  `PermissionRequest` event entry with a `permission_prompt` matcher under
  the existing `Notification` event. Both events fire at the same moment
  when a permission dialog appears, and configuring both caused the
  notification sound to play twice.

## [1.0.0] - 2026-04-22

### Added

- Initial public release.
- Swift-based `.app` bundle that fires macOS notifications via the
  UserNotifications framework.
- Custom icon derived from the Heroicons bell-solid SVG (MIT License),
  rasterized at build time and rendered in Claude brand colors
  (Crail `#C15F3C` background, Cream `#f0eee6` bell).
- Configuration file at `~/.config/claude-code-notifier/config.json` with
  sound label mapping (`default` / `permission` / `idle`), default title,
  and activate target bundle ID.
- Click-through to a configurable application (default: Visual Studio Code)
  via its bundle identifier, so notifications bring the IDE to focus.
- Input sanitization for CLI arguments: allowlist for sound names and bundle
  identifiers, body length cap at 500 characters, control-character removal.
- Universal binary build (arm64 + x86_64), macOS 12.0 Monterey or later.
- `CCN_APP_DIR` environment variable to override the install location.
- `install.sh` and `uninstall.sh` helpers.
- Sample Claude Code hook configurations in the README.
