# Contributing to claude-code-notifier

Thanks for your interest. This is a small, opinionated tool. Contributions are
welcome when they keep the project scope tight.

## Scope

This project does one thing: emit macOS notifications with a custom icon and
click-through, wired for Claude Code hooks. Changes that expand the scope
(extra platforms, GUI configuration, network features) will likely be declined
unless discussed in an issue first.

## Before you start

For anything more than a typo fix, please open an issue and describe:

- What problem you want to solve.
- Your proposed approach.
- Any trade-offs you see.

This avoids the case where a polished pull request cannot be merged because
the approach does not fit the project direction.

## Development setup

```sh
git clone https://github.com/saiso/claude-code-notifier.git
cd claude-code-notifier
brew install librsvg
./install.sh
```

Verify the build produced a working `.app`:

```sh
open "$HOME/.claude/apps/Claude Code Notifier.app" --args "test" "" "default"
```

With `CLAUDE_CODE_NOTIFIER_DEBUG=1` set, runtime events are appended to
`~/.claude/apps/notifier.log`.

## Coding guidelines

- Swift: keep it small. Prefer explicit `if let` over force unwraps. Avoid
  adding external dependencies.
- Shell: `set -euo pipefail`. Quote variables. Prefer long-form flags.
- Validate every input that comes from outside the binary (CLI args, config
  file). Use the existing allowlist helpers.
- Do not ship binaries in the repository. Icons are regenerated at build time.

## Testing changes

- Run `./install.sh` on a clean directory.
- Fire each of the example commands in the README's Configuration section.
- Run `./uninstall.sh` and verify the app bundle, config dir, and tcc entry
  are all removed when the user opts in.
- Test on both arm64 and x86_64 if possible.

## Submitting a pull request

- Reference the related issue in the description.
- Keep each pull request focused on a single change.
- Update `CHANGELOG.md` under `[Unreleased]` with a short bullet.
- If you add user-facing behavior, update `README.md` and `README.ja.md`.

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
