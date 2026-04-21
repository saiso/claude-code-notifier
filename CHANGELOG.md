# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
