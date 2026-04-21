# Security Policy

## Supported versions

Only the latest released version receives security updates. Older versions are
unsupported.

| Version | Supported |
| --- | --- |
| Latest release | Yes |
| Older | No |

## Reporting a vulnerability

Please **do not** open public issues for security vulnerabilities.

If you believe you have found a security issue in claude-code-notifier,
report it privately through GitHub:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Describe the issue in as much detail as you can (affected version,
   reproduction steps, suspected impact).

GitHub's private vulnerability reporting keeps the report hidden from the
public while it is being triaged.

You can expect:

- Acknowledgement within 5 business days.
- A fix or mitigation plan within 30 days for confirmed issues.
- Credit in the release notes for the reporter, if desired.

## Threat model boundaries

claude-code-notifier is a small macOS notification tool. The threat model
is limited accordingly:

- The app runs locally with user privileges. It does not listen on the
  network or accept remote input.
- Inputs are CLI arguments and a local JSON config file
  (`~/.config/claude-code-notifier/config.json`).
- Out of scope: full-disk access restrictions, sandbox escape, keychain
  access. The app does not read secrets.

Vulnerabilities of interest include:

- Ways to trick the app into launching arbitrary applications via the
  `activateBundleID` path.
- Ways to bypass the sound name allowlist to reference files outside
  `/System/Library/Sounds`.
- Ways to inject control characters or unexpectedly long strings into
  notification bodies that could affect the notification system.
- Issues that lead to code execution via a malicious `config.json`.

## Out of scope

- Issues that require the attacker to already have arbitrary code execution
  on the machine (e.g. tampering with the app bundle directly).
- Social-engineering-only issues against the user.
- Denial of service that requires filling disk / memory on the local machine.
